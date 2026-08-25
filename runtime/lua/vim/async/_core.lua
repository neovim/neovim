-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local util = require('vim._core.util')
local future = require('vim.async._future')
local runtime = require('vim.async._runtime')

local is_callable = vim.is_callable
local validate = vim.validate
local pcall = pcall
local coroutine_running = coroutine.running
do
  local ok, coxpcall = pcall(require, 'coxpcall')
  if ok and type(coxpcall) == 'table' then
    if type(coxpcall.pcall) == 'function' then
      pcall = coxpcall.pcall
    end
    if type(coxpcall.running) == 'function' then
      coroutine_running = coxpcall.running
    end
  end
end
local maxint = 2 ^ 32 - 1
local pack_len = vim.F.pack_len
local unpack_len = vim.F.unpack_len

--- @class vim.async._core
--- @nodoc
local M = {}

--- Weak table to keep track of running tasks
--- @type table<thread, vim.async.Task<any>?>
local threads = setmetatable({}, { __mode = 'k' })

--- Returns the currently running task.
--- @return vim.async.Task<any>?
local function running()
  --- @diagnostic disable-next-line: invisible, undefined-field
  local task = threads[coroutine_running()]
  if task and not task:completed() then
    return task
  end
end

--- Internal marker used to identify that a yielded value is an asynchronous yielding.
local yield_marker = {}
local resume_marker = {}

local resume_error = 'Unexpected coroutine.resume()'
local yield_error = 'Unexpected coroutine.yield()'

--- @return vim.async.Task<any>
local function current_task()
  return (assert(running(), 'Not in async context'))
end

--- Checks the arguments of a `coroutine.resume`.
--- This is used to ensure that a resume is expected.
--- @generic T
--- @param marker any
--- @param err? any
--- @param ... T...
--- @return T...
local function check_yield(marker, err, ...)
  if marker ~= resume_marker then
    current_task():_raise(resume_error)
    -- Return an error to the caller. This will also leave the task in a dead
    -- and unfinished state.
    error(resume_error, 0)
  elseif err ~= nil then
    error(err, 0)
  end
  return ...
end

--- @class vim.async.Closable
--- @field close fun(self, callback?: fun())
--- @field is_closing? fun(self): boolean

--- A coroutine-backed async operation and concurrency scope.
---
--- Use [vim.async.run()] to create tasks. A task may be awaited by more than
--- one waiter. When a task is created inside another task, it is attached to
--- that parent and becomes part of the parent's concurrency scope.
---
--- @class vim.async.Task<R>: vim.async.Closable
--- @field package _thread thread
--- @field package _future vim.async.Future<R>
--- @field package _closing boolean
--- @field package _error? any
--- @field package _finalizing_children boolean
--- @field package _started boolean
---
--- Reference to parent to handle attaching/detaching.
--- @field package _parent? vim.async.Task<any>
--- @field package _parent_children_idx? integer
---
--- Name of the task
--- @field name? string
---
--- Hide implementation tasks from user-facing inspection output.
--- @field package _hidden? boolean
---
--- The source line that created this task, used for inspect().
--- @field package _caller? string
---
--- Maintain children as an array to preserve closure order.
--- @field package _children table<integer, vim.async.Task<any>?>
---
--- Pointer to last child in children
--- @field package _children_idx integer
---
--- Tasks can await other async functions (task of callback functions)
--- when we are waiting on a child, we store the handle to it here so we can
--- close it.
--- @field package _awaiting? vim.async.Task<any> | vim.async.Closable
--- Removes the completion callback when a Task await is abandoned.
--- @field package _awaiting_unsubscribe? fun()
local Task = {}

--- @return_cast x vim.async.Task<any>
local function is_task(x)
  return getmetatable(x) == Task
end

do --- Task
  Task.__index = Task

  --- @package
  --- @param name? string
  --- @param func async fun(...: any)
  --- @return vim.async.Task<any>
  function Task._new(name, func, ...)
    local func_args = pack_len(...) --[[@as any[]? ]]
    local thread = coroutine.create(function(marker, err)
      -- Drop the packed vararg table before user code can suspend; otherwise
      -- the coroutine closure retains it for the task lifetime.
      local args = func_args
      func_args = nil
      check_yield(marker, err)
      return func(unpack_len(args))
    end)

    local self = setmetatable({
      name = name,
      _closing = false,
      _finalizing_children = false,
      _started = false,
      _thread = thread,
      _future = future(),
      _children = {},
      _children_idx = 0,
    }, Task)

    threads[thread] = self

    return self
  end

  --- Returns whether the Task has completed.
  --- @return boolean
  function Task:completed()
    return self._future:completed()
  end

  --- Add a callback to be run when the Task has completed.
  ---
  --- If the Task is already done when this method is called, the callback is
  --- called immediately with the results.
  ---
  --- This only observes completion. It does not start a pending task.
  --- @param callback fun(err?: any, ...: R...)
  --- @return fun() unsubscribe
  function Task:on_complete(callback)
    validate('callback', callback, 'callable')
    return self._future:on_complete(callback)
  end

  --- Synchronously wait for the Task to complete.
  ---
  --- If a timeout is provided, waits for the given time in milliseconds before
  --- failing with `"timeout"`. With no timeout, waits indefinitely.
  ---
  --- This is for synchronous code. Inside a task, prefer [vim.async.await()] so
  --- the current task suspends instead of pumping the event loop itself.
  ---
  --- ```lua
  --- local result = task:wait(10) -- wait for 10ms or raise "timeout"
  ---
  --- local result = task:wait() -- wait indefinitely
  --- ```
  --- @param timeout integer?
  --- @return R...
  function Task:wait(timeout)
    validate('timeout', timeout, 'number', true)
    self:_start()

    if not runtime.wait(timeout or maxint, function()
      return self:completed()
    end) then
      error('timeout', 2)
    end
    local res = pack_len(self._future:result())

    assert(self:status() == 'completed' or res[2] == yield_error)

    if not res[1] then
      error(res[2], 2)
    end

    return unpack(res, 2, res.n)
  end

  --- Protected-call version of [Task:wait()].
  ---
  --- Equivalent to `pcall(task.wait, task, timeout)`.
  ---
  --- ```lua
  --- local ok, result_or_err = task:pwait(1000)
  --- if not ok then
  ---   vim.notify(tostring(result_or_err), vim.log.levels.ERROR)
  --- end
  --- ```
  --- @param timeout integer?
  --- @return boolean, R...
  function Task:pwait(timeout)
    validate('timeout', timeout, 'number', true)
    return pcall(self.wait, self, timeout)
  end

  --- @package
  --- @param parent? vim.async.Task<any>
  function Task:_attach(parent)
    if parent then
      -- Attach to parent
      parent._children_idx = parent._children_idx + 1
      parent._children[parent._children_idx] = self

      -- Keep track of the parent and this tasks index so we can detach
      self._parent = parent
      self._parent_children_idx = parent._children_idx
    end
  end

  --- Remove this task from its parent without changing execution state.
  --- @private
  --- @return boolean removed
  function Task:_detach()
    if not self._parent then
      return false
    end

    self._parent._children[self._parent_children_idx] = nil
    self._parent = nil
    self._parent_children_idx = nil
    return true
  end

  --- Detach a task from its parent.
  ---
  --- The task becomes a top-level task.
  --- If it was waiting for a parent checkpoint, it is scheduled to start.
  ---
  --- Use this for background work that should not be cancelled when the
  --- current task finishes. Detached task failures no longer fail the original
  --- parent, so observe them explicitly with [Task:on_complete()],
  --- [Task:wait()], or [vim.async.await()].
  ---
  --- ```lua
  --- vim.async.run(function()
  ---   while true do
  ---     refresh_index()
  ---     vim.async.sleep(1000)
  ---   end
  --- end):detach()
  --- ```
  --- @return vim.async.Task<R>
  function Task:detach()
    local should_start = self._parent and not self._started and not self:completed()
    self:_detach()
    if should_start then
      runtime.schedule(function()
        self:_start()
      end)
    end
    return self
  end

  --- Get the traceback of a task when it is not active.
  --- Will also get the traceback of nested tasks.
  ---
  --- @param msg? string
  --- @param level? integer
  --- @return string traceback
  function Task:traceback(msg, level)
    level = level or 0

    local thread = '[' .. tostring(self._thread) .. '] '

    local awaiting = self._awaiting
    if is_task(awaiting) then
      msg = awaiting:traceback(msg, level + 1)
    end

    local tblvl = is_task(awaiting) and 2 or nil
    local tb = debug.traceback(self._thread, '', tblvl) or ''
    msg = (msg == nil and '' or tostring(msg)) .. tb:gsub('\n\t', '\n\t' .. thread)

    if level == 0 then
      --- @type string
      msg = msg
        :gsub('\nstack traceback:\n', '\nSTACK TRACEBACK:\n', 1)
        :gsub('\nstack traceback:\n', '\n')
        :gsub('\nSTACK TRACEBACK:\n', '\nstack traceback:\n', 1)
    end

    return msg
  end

  --- Raise this task's error when it completes.
  ---
  --- Use this for detached or top-level fire-and-forget tasks whose completion
  --- will not otherwise be observed. Attached task errors already propagate to
  --- their parent.
  ---
  --- Detached tasks do not raise errors automatically. Detaching changes
  --- ownership only; their completion can still be handled with
  --- [vim.async.await()], [Task:wait()], [Task:pwait()], or [Task:on_complete()].
  --- @return vim.async.Task<R> self
  function Task:raise_on_error()
    self:on_complete(function(err)
      if err ~= nil then
        error(self:traceback(err), 0)
      end
    end)
    return self
  end

  --- @package
  function Task:_start()
    if self._started or self:completed() then
      return
    end

    self._started = true
    self:_resume()
  end

  --- Start children whose first resume was deferred by `run()`.
  ---
  --- Deferring child start lets `await()` or `pawait()` claim the task boundary
  --- before child code runs. At await checkpoints and successful parent finish,
  --- any remaining pending children must start so implicit waits, cancellation,
  --- and inspection see the full task tree.
  --- @package
  function Task:_start_pending_children()
    for i = 1, self._children_idx do
      local child = self._children[i]
      if child then
        child:_start()
      end
    end
  end

  --- @private
  function Task:_close_children()
    for i = 1, self._children_idx do
      local child = self._children[i]
      if child then
        child:close()
      end
    end
  end

  --- Keep the first task error. The error can be any non-nil Lua value.
  --- @package
  --- @param err any
  --- @return any
  function Task:_set_error(err)
    if self._error == nil then
      self._error = err
    end
    return self._error
  end

  --- @package
  --- @param err any
  function Task:_raise(err)
    if self:status() == 'running' then
      -- A running coroutine cannot be resumed recursively, so deliver the
      -- error on a later event-loop turn after the current stack unwinds.
      runtime.schedule(function()
        if not self:completed() then
          self:_resume(err)
        end
      end)
    else
      self:_resume(err)
    end
  end

  --- Request cooperative close for the task and all of its children.
  ---
  --- The optional callback observes task completion and may run immediately if
  --- the task has already completed.
  ---
  --- Closing is cooperative. The task observes the close request at a
  --- checkpoint such as [vim.async.await()] or [vim.async.checkpoint()]. If the
  --- task is suspended on an owned closable operation, that operation is closed
  --- before the task reports `"closed"`.
  ---
  --- @param callback? fun()
  function Task:close(callback)
    if not self:completed() and not self._closing then
      self._closing = true
      self:_raise('closed')
    end
    if callback then
      self:on_complete(function()
        callback()
      end)
    end
  end

  --- Record a child failure on this task and either deliver it to a live
  --- parent or close sibling children during finalization.
  --- @package
  --- @param child vim.async.Task<any>
  --- @param err any
  --- @param child_was_awaited boolean?
  function Task:_child_failed(child, err, child_was_awaited)
    -- A parent close turns child "closed" results into cleanup, not failure.
    if child._closing or child_was_awaited or (self._closing and err == 'closed') then
      return
    end

    local task_err = self:_set_error('child error: ' .. util._stringify_error(err))
    if self._finalizing_children then
      -- The parent coroutine is already dead, so sibling cleanup must wake the
      -- finalizer instead of trying to resume the parent.
      self:_close_children()
    else
      self:_raise(task_err)
    end
  end

  --- Checks if an object is closable, i.e., has a `close` method.
  --- @param obj any
  --- @return boolean
  --- @return_cast obj vim.async.Closable
  local function is_closable(obj)
    local ty = type(obj)
    return (ty == 'table' or ty == 'userdata') and is_callable(obj.close)
  end

  do -- Task:_resume()
    --- Complete this task with an error and propagate it to the parent if the
    --- parent did not explicitly await this task.
    --- @param parent? vim.async.Task<any>
    --- @param err any
    function Task:_finish_error(parent, err)
      if err == nil then
        err = self._error
      end
      err = util._normalize_error(err)
      if parent then
        parent:_child_failed(self, err, parent._awaiting == self)
      end
      self._future:complete(err)
    end

    --- @private
    --- @param stat boolean
    --- @param ... R... result
    function Task:_finish(stat, ...)
      if self:completed() then
        return
      end

      local parent = self._parent
      self:_detach()

      threads[self._thread] = nil

      if not stat then
        self:_finish_error(parent, ...)
      else
        if self._error ~= nil then
          self:_finish_error(parent, self._error)
        else
          self._future:complete(nil, ...)
        end
      end
    end

    --- @package
    --- @param stat boolean
    --- @param ... R... result
    function Task:_finalize(stat, ...)
      if next(self._children) == nil then
        self:_finish(stat, ...)
        return
      end

      local finish_args = pack_len(stat, ...)
      self._finalizing_children = true
      -- Only spawn the helper after the no-child path; an empty helper task
      -- would otherwise finalize by recursively spawning another helper.
      local await_children = Task._new('await_children', function()
        -- TODO(lewis6991): should we collect all errors?
        local close_remaining = not stat

        if close_remaining then
          self:_close_children()
        else
          self:_start_pending_children()
        end

        for i = 1, self._children_idx do
          local child = self._children[i]
          if child then
            -- Child failures are recorded on `self`. Protect this helper so one
            -- failed child cannot stop it awaiting the remaining cleanup.
            local ok, err = M.pawait(child)
            -- A close can arrive while normal finalization is awaiting
            -- children; from that point child errors are cleanup results.
            if not close_remaining and not self._closing and not ok and not child._closing then
              self:_set_error('child error: ' .. util._stringify_error(err))
              close_remaining = true
              self:_close_children()
            end
          end
        end

        self._finalizing_children = false
        if stat and self._closing and self._error == nil then
          self:_finish(false, 'closed')
        else
          self:_finish(unpack_len(finish_args))
        end
      end)
      await_children._hidden = true
      await_children:_start()
    end

    --- Resume a task with the raw or protected result of an await.
    --- @param task vim.async.Task<any>
    --- @param yielded vim.async.Task<any>|fun(callback: fun(err?: any, ...: any)): vim.async.Closable?
    --- @param protected boolean?
    --- @param err? any
    --- @param ... any
    local function resume_from_await(task, yielded, protected, err, ...)
      -- An error from `await(task)` also marks the waiting task as failed, even
      -- if the error raised by `await()` is caught.
      if not protected and is_task(yielded) and err ~= nil then
        task:_set_error(err)
      end

      if protected then
        if err ~= nil then
          return task:_resume(nil, false, err)
        end
        return task:_resume(nil, true, ...)
      end

      return task:_resume(err, ...)
    end

    --- Begin waiting on a yielded awaitable.
    --- @param task vim.async.Task<any>
    --- @param yielded vim.async.Task<any>|fun(callback: fun(err?: any, ...: any)): vim.async.Closable?
    --- @param protected boolean?
    local function start_await(task, yielded, protected)
      -- TODO(#36): Defer task control until setup returns its cleanup handle.
      -- The first callback or setup failure settles the await.
      -- Ignore any callback that arrives afterwards.
      local settled = false
      local setup_ok --- @type boolean?

      -- Await setup may invoke the callback before `_awaiting` is installed.
      -- Save those arguments so the task resumes only after setup finishes.
      -- `sync_args` has three states:
      -- - `nil`: the callback did not fire during setup;
      -- - `false`: `callback(nil)`, the common no-error/no-result case,
      --   avoiding a table allocation;
      -- - a table: every other argument list, packed to preserve nils.
      local sync_args --- @type false|{[integer]: any, n: integer}?
      local awaiting --- @type vim.async.Task<any>|vim.async.Closable?

      local function complete_await(err, ...)
        -- Cancellation and child failures resume through `_raise()`. Ignore a
        -- racing result so `_resume()` can finish awaitable cleanup first.
        if settled or task._closing or task._error ~= nil then
          return
        end
        settled = true

        if setup_ok == nil then
          if err == nil and select('#', ...) == 0 then
            sync_args = false
          else
            sync_args = pack_len(err, ...)
          end
        else
          -- The callback has fired. Keep `_awaiting` so `_resume()` can close a
          -- callback-style handle or retain a failed Task for its traceback.
          task._awaiting_unsubscribe = nil

          if not task:completed() then
            return resume_from_await(task, yielded, protected, err, ...)
          end
        end
      end

      local unsubscribe
      local task_await --- @type boolean
      local setup_result
      -- Either call below may invoke `complete_await()` before returning. In that
      -- case, `unsubscribe` or `awaiting` has not yet received the returned cleanup
      -- handle. While `setup_ok` is nil, `complete_await()` saves its arguments
      -- in `sync_args`. This lets the code below handle setup errors and install the
      -- cleanup state before using the buffered result.
      if is_task(yielded) then
        task_await = true
        --- @diagnostic disable-next-line: cast-local-type
        awaiting = yielded
        setup_ok, setup_result = pcall(yielded._future.on_complete, yielded._future, complete_await)
      else
        task_await = false
        -- Callback setup has one result: the optional closable.
        --- @type fun(callback: fun(err?: any, ...: any)): vim.async.Closable?
        local awaitable = yielded
        setup_ok, setup_result = pcall(awaitable, complete_await)
      end

      if not setup_ok then
        local err = util._normalize_error(setup_result)
        if protected and settled then
          -- The first synchronous callback wins over a later setup error.
          awaiting = nil
        else
          settled = true
          return resume_from_await(task, yielded, protected, err)
        end
      elseif task_await then
        unsubscribe = setup_result
      else
        awaiting = setup_result
      end

      if not is_closable(awaiting) then
        awaiting = nil
      end
      --- @diagnostic disable-next-line: assign-type-mismatch
      task._awaiting = awaiting

      if is_task(awaiting) then
        if not settled and unsubscribe then
          --- @diagnostic disable-next-line: assign-type-mismatch
          task._awaiting_unsubscribe = unsubscribe
        end
        awaiting:_start()
      end

      if task:completed() then
        return
      end

      task:_start_pending_children()

      if sync_args == false then
        return resume_from_await(task, yielded, protected)
      elseif sync_args then
        return resume_from_await(task, yielded, protected, unpack_len(sync_args))
      end
    end

    --- Finalize a completed coroutine or start its yielded await.
    --- Keep results in varargs to preserve nils without packing them.
    --- @param task vim.async.Task<any>
    --- @param stat boolean
    --- @param ... any
    local function handle_resume(task, stat, ...)
      if coroutine.status(task._thread) == 'dead' then
        -- The coroutine finished during resume. A normal return must not
        -- overwrite a pending task failure.
        if task._error ~= nil and stat then
          task:_finalize(false, task._error)
        elseif task._closing and stat then
          task:_finalize(false, 'closed')
        else
          task:_finalize(stat, ...)
        end
        return
      end

      local marker, yielded, protected = ...
      if marker ~= yield_marker or (not is_task(yielded) and not is_callable(yielded)) then
        task:_finalize(false, yield_error)
        return
      end

      return start_await(task, yielded, protected)
    end

    --- Clear an await boundary and remove its Task completion callback.
    --- @param task vim.async.Task<any>
    local function clear_awaiting(task)
      local unsubscribe = task._awaiting_unsubscribe
      task._awaiting = nil
      task._awaiting_unsubscribe = nil
      if unsubscribe then
        unsubscribe()
      end
    end

    --- @package
    --- @param err? any
    --- @param ... any resume values
    function Task:_resume(err, ...)
      -- Clear self._awaiting when either:
      -- - this task resumes before a non-child finishes, so its callback
      --   cannot retain this task; or
      -- - there is no raw error needing its traceback frames and
      --   self._awaiting is finished.
      if
        is_task(self._awaiting)
        and (
          (self._awaiting._parent ~= self and self._awaiting_unsubscribe)
          or (err == nil and self._awaiting:completed())
        )
      then
        clear_awaiting(self)
      end

      local awaiting = self._awaiting
      -- Only close awaitables owned by this task; external tasks are observed.
      if awaiting and (not is_task(awaiting) or awaiting._parent == self) then
        local already_closing = false
        if type(awaiting.is_closing) == 'function' then
          already_closing = awaiting:is_closing()
        end

        if already_closing then
          clear_awaiting(self)
          return self:_resume(err, ...)
        end

        local args = pack_len(err, ...)
        -- We must close the closable child before we resume to ensure
        -- all resources are collected.
        --- @diagnostic disable-next-line: param-type-mismatch
        local close_ok, close_err = pcall(awaiting.close, awaiting, function()
          clear_awaiting(self)
          return self:_resume(unpack_len(args))
        end)

        if close_ok then
          return
        end
        clear_awaiting(self)
        return self:_resume(util._normalize_error(close_err))
      end

      -- An external coroutine.resume() may have already killed the coroutine.
      -- Finalize its pending failure instead of trying to resume it again.
      if coroutine.status(self._thread) == 'dead' then
        self:_finalize(false, err, ...)
        return
      end

      return handle_resume(self, coroutine.resume(self._thread, resume_marker, err, ...))
    end
  end

  --- @package
  function Task:_log(...)
    print(tostring(self._thread), ...)
  end

  --- Returns the status of the task:
  ---
  --- - `"running"`: task is currently executing Lua code
  --- - `"normal"`: task is active but another coroutine is running
  --- - `"awaiting"`: task is suspended at a checkpoint or waiting for children
  --- - `"completed"`: task and all attached children have completed
  --- @return "running" | "awaiting" | "normal" | "completed"
  function Task:status()
    if self:completed() then
      return 'completed'
    end

    local co_status = coroutine.status(self._thread)
    if co_status == 'dead' then
      return 'awaiting'
    elseif co_status == 'suspended' then
      return 'awaiting'
    elseif co_status == 'normal' then
      -- TODO(lewis6991): This state is a bit ambiguous. If all tasks
      -- are started from the main thread, then we can remove this state.
      -- Though it still may be possible if the user resumes a non-task
      -- coroutine.
      return 'normal'
    end
    assert(co_status == 'running')
    return 'running'
  end
end

--- @generic T, R
--- @param name? string
--- @param func async fun(...: T...): R... Function to run in an async context
--- @param ... T... Arguments to pass to the function
--- @return vim.async.Task<R...>
local function run(name, func, ...)
  validate('func', func, 'callable')
  local task = Task._new(name, func, ...)
  task:_attach(running())
  if runtime.debug then
    local info = debug.getinfo(2, 'Sl')
    if info and info.currentline then
      task._caller = ('%s:%d'):format(info.source, info.currentline)
    end
  end

  -- Top-level tasks have no parent checkpoint to start them, so they start
  -- immediately. Attached children start when their parent next reaches an
  -- await checkpoint, or when the parent finishes successfully and implicitly
  -- waits for its children. If the parent errors or closes, pending children
  -- are closed without running user code.
  if not task._parent then
    task:_start()
  end

  return task
end

--- Create a task from an async function.
---
--- Top-level tasks start immediately. Child tasks are attached immediately and
--- first run when their parent reaches a checkpoint.
---
--- Creating a task decides ownership. Awaiting the task later only observes
--- its result; it does not attach the task to the awaiter.
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local child = async.run(function()
---     return read_file('notes.txt')
---   end)
---
---   local text = async.await(child)
---   show_buffer(text)
--- end)
--- ```
---
--- A task created from synchronous code is top-level:
---
--- ```lua
--- local task = vim.async.run(function()
---   vim.async.sleep(100)
---   return 'done'
--- end)
---
--- print(task:wait())
--- ```
--- @generic T, R
--- @param func async fun(...: T...): R...
--- @param ... T... Arguments to pass to the function
--- @return vim.async.Task<R...>
--- @overload fun(name: string, func: async fun(...: T...), ...: T...): vim.async.Task<R...>
function M.run(func, ...)
  if type(func) == 'string' then
    return run(func, ...)
  elseif is_callable(func) then
    return run(nil, func, ...)
  end
  error('Invalid arguments')
end

--- @generic T, R
--- @param argc integer
--- @param fun fun(...: T..., callback: fun(...: R...))
--- @param ... T... func arguments
--- @return fun(callback: fun(...: R...))
local function norm_cb_fun(argc, fun, ...)
  if argc == 1 and select('#', ...) == 0 then
    -- Avoid allocating an empty argument table for the common await(func) shape.
    local cb_fun = fun
    --- @cast cb_fun fun(callback: fun(...: any)): any?
    --- @param callback fun(...: any)
    --- @return any?
    return function(callback)
      return cb_fun(function(...)
        callback(nil, ...)
      end)
    end
  end

  local args = pack_len(...)

  --- @param callback fun(...: any)
  --- @return any?
  return function(callback)
    args[argc] = function(...)
      callback(nil, ...)
    end
    args.n = math.max(args.n, argc)
    return fun(unpack_len(args))
  end
end

--- Get the current task, failing before an operation yields if it is closing or
--- failed.
--- @return vim.async.Task<any>
local function check_current_task()
  local task = current_task()

  if task._closing then
    error('closed', 0)
  elseif task._error ~= nil then
    error(task._error, 0)
  end

  return task
end

--- Convert the public await forms into a Task or callback awaitable.
---
--- Callback-style APIs do not have an error slot, so `norm_cb_fun()` inserts
--- `nil`; the scheduler observes Task futures directly.
--- @param ... any
--- @return vim.async.Task<any>|fun(callback: fun(err?: any, ...: any)): vim.async.Closable?
local function to_awaitable(...)
  local arg1 = select(1, ...)

  if type(arg1) == 'number' then
    return norm_cb_fun(...)
  elseif type(arg1) == 'function' then
    return norm_cb_fun(1, arg1)
  elseif is_task(arg1) then
    return arg1
  else
    error('Invalid arguments, expected Task or (argc, func) got: ' .. tostring(arg1), 2)
  end
end

--- Suspend the current task until an awaitable completes.
---
--- Accepts a task, a callback-taking function, or an argument position plus a
--- callback-taking function. Raises awaited errors and current task-control
--- errors.
---
--- The callback forms return callback arguments unchanged:
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local err, stat = async.await(2, vim.uv.fs_stat, 'notes.txt')
---   if err then
---     error(err, 0)
---   end
---   print(stat.size)
--- end)
--- ```
---
--- If a callback API starts cancellable work, return a closable handle from the
--- await callback. [Task:close()] will close that handle if cancellation
--- arrives while the task is suspended there.
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local lines = async.await(function(done)
---     return start_read_lines('notes.txt', done)
---   end)
---   render(lines)
--- end)
--- ```
--- @async
--- @generic T, R
--- @param ... any see overloads
--- @overload async fun(func: (fun(callback: fun(...: R...)): vim.async.Closable?)): R...
--- @overload async fun(argc: integer, func: (fun(...: T..., callback: fun(...: R...)): vim.async.Closable?), ...: T...): R...
--- @overload async fun(task: vim.async.Task<R>): R...
--- @return R...
function M.await(...)
  check_current_task()
  return check_yield(coroutine.yield(yield_marker, to_awaitable(...)))
end

--- Protected await.
---
--- Async counterpart to `pcall()`. Accepts the same forms as
--- [vim.async.await()], but returns a leading `ok` boolean for
--- awaited-operation failures.
---
--- Use this when the awaited task or operation is allowed to fail and the
--- current task should continue. Cancellation or already pending failure from
--- the current task is not protected.
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local ok, text_or_err = async.pawait(async.run(read_file, 'notes.txt'))
---   if not ok then
---     text_or_err = ''
---   end
---
---   show_buffer(text_or_err)
--- end)
--- ```
--- @async
--- @generic T, R
--- @param ... any see overloads
--- @overload async fun(func: (fun(callback: fun(...: R...)): vim.async.Closable?)): boolean, R...
--- @overload async fun(argc: integer, func: (fun(...: T..., callback: fun(...: R...)): vim.async.Closable?), ...: T...): boolean, R...
--- @overload async fun(task: vim.async.Task<R>): boolean, R...
--- @return boolean ok
--- @return R... ... result or error
--- @return_overload true, R...
--- @return_overload false, any
function M.pawait(...)
  check_current_task()
  return check_yield(coroutine.yield(yield_marker, to_awaitable(...), true))
end

--- Start pending child tasks and deliver pending cancellation or task failure
--- from the current task.
---
--- This does not yield to the event loop.
---
--- Use this after cleanup code that catches an async failure or close signal,
--- so persistent task state is delivered again before normal execution
--- continues.
---
--- ```lua
--- local ok, err = pcall(cleanup_sensitive_work)
--- cleanup_resources()
--- vim.async.checkpoint()
--- if not ok then
---   error(err, 0)
--- end
--- ```
--- @async
function M.checkpoint()
  M.await(function(callback)
    callback()
  end)
end

--- Returns true if the current task has been closed.
---
--- Can be used in an async function to do cleanup when a task is closing.
---
--- ```lua
--- while not vim.async.is_closing() do
---   poll_once()
---   vim.async.sleep(1000)
--- end
--- ```
--- @return boolean
function M.is_closing()
  local task = running()
  return task and task._closing or false
end

--- @private
--- @param parent? vim.async.Task<any>
--- @param prefix? string
--- @return string[]
local function inspect(parent, prefix)
  local tasks = {} --- @type table<any, vim.async.Task<any>?>
  if parent then
    for _, task in pairs(parent._children) do
      if not task._hidden then
        tasks[#tasks + 1] = task
      end
    end
  else
    -- Gather for all detached tasks
    for _, task in pairs(threads) do
      if not task._parent and not task._hidden then
        tasks[#tasks + 1] = task
      end
    end
  end

  local r = {} --- @type string[]
  for i, task in ipairs(tasks) do
    local last = i == #tasks
    local label = task.name or ''
    if task._caller then
      label = label .. task._caller
    end
    if label ~= '' then
      label = label .. ' '
    end
    r[#r + 1] = ('%s%s%s[%s]'):format(
      prefix or '',
      parent and (last and '└─ ' or '├─ ') or '',
      label,
      task:status()
    )
    local child_prefix = (prefix or '') .. (parent and (last and '   ' or '│  ') or '')
    for _, line in ipairs(inspect(task, child_prefix)) do
      r[#r + 1] = line
    end
  end
  return r
end

--- Inspect the current async task tree.
---
--- Returns a string representation of the task tree, showing the names and
--- statuses of each task.
--- @return string
function M._inspect_tree()
  -- Inspired by https://docs.python.org/3.14/whatsnew/3.14.html#asyncio-introspection-capabilities
  return table.concat(inspect(), '\n')
end

return M
