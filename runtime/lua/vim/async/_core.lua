-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local util = require('vim.async._util')
local errors = require('vim.async._errors')
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
local pack_len = util.pack_len
local unpack_len = util.unpack_len

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

    return unpack_len(res, 2)
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

  --- If a task completes with an error, raise the error
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
      -- error on the next event-loop turn after the current stack unwinds.
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

    local task_err = self:_set_error('child error: ' .. tostring(err))
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
      err = errors.normalize(err)
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
            -- Finalization owns child failures here; don't let them re-enter
            -- the dead parent coroutine and complete the future twice.
            local ok, err = pcall(M.await, child)
            -- A close can arrive while normal finalization is awaiting
            -- children; from that point child errors are cleanup results.
            if not close_remaining and not self._closing and not ok and not child._closing then
              self:_set_error('child error: ' .. tostring(err))
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

    --- @param task vim.async.Task<any>
    --- @param stat boolean
    --- @param ... any
    local function finalize_resume(task, stat, ...)
      -- If pcall swallowed a child error or close signal, don't let a later
      -- normal return overwrite the pending task failure.
      if task._error ~= nil and stat then
        task:_finalize(false, task._error)
      elseif task._closing and stat then
        task:_finalize(false, 'closed')
      else
        task:_finalize(stat, ...)
      end
    end

    --- @param task vim.async.Task<any>
    --- @param stat boolean
    --- @param ... any
    local function handle_resume_result(task, stat, ...)
      if coroutine.status(task._thread) == 'dead' then
        finalize_resume(task, stat, ...)
        return
      end

      local marker, awaitable = ...
      if marker ~= yield_marker or not is_callable(awaitable) then
        finalize_resume(task, false, yield_error)
        return
      end

      local settled = false
      local in_setup = true
      local sync_n, sync_arg
      --- @type {[integer]: any, n: integer}?
      local sync_args

      local ok, awaiting_or_err
      ok, awaiting_or_err = pcall(awaitable, function(...)
        if settled then
          return
        end
        settled = true

        -- If the callback runs before pcall() returns, tail-call the next
        -- step after setup finishes. Otherwise resume from the callback turn.
        if in_setup then
          sync_n = select('#', ...)
          if sync_n == 1 then
            sync_arg = ...
          elseif sync_n > 1 then
            sync_args = pack_len(...)
          end
        else
          if is_task(awaiting_or_err) and select(1, ...) ~= nil then
            task:_set_error(select(1, ...))
          end
          if not task:completed() then
            return task:_resume(...)
          end
        end
      end)
      in_setup = false

      if not ok then
        return task:_resume(errors.normalize(awaiting_or_err))
      elseif is_closable(awaiting_or_err) then
        task._awaiting = awaiting_or_err
      else
        task._awaiting = nil
      end

      if is_task(task._awaiting) then
        task._awaiting:_start()
      end
      if task:completed() then
        return
      end
      task:_start_pending_children()
      if sync_n ~= nil then
        if is_task(task._awaiting) then
          if sync_n == 1 then
            task:_set_error(sync_arg)
          elseif sync_n > 1 then
            --- @cast sync_args -nil
            task:_set_error(sync_args[1])
          end
        end

        if sync_n == 0 then
          return task:_resume()
        elseif sync_n == 1 then
          return task:_resume(sync_arg)
        end

        --- @cast sync_args -nil
        return task:_resume(unpack_len(sync_args))
      end
    end

    --- @package
    --- @param ... any the first argument is the error, except for when the coroutine begins
    function Task:_resume(...)
      if select(1, ...) == nil and is_task(self._awaiting) and self._awaiting:completed() then
        -- A completed child is traceback context only while its error is
        -- being delivered through raw await(). Successful and protected
        -- resumes must not let that old child hide this task's own frames.
        self._awaiting = nil
      end

      local awaiting = self._awaiting
      -- Only close awaitables owned by this task; external tasks are observed.
      if awaiting and (not is_task(awaiting) or awaiting._parent == self) then
        local already_closing = false
        if type(awaiting.is_closing) == 'function' then
          already_closing = awaiting:is_closing()
        end

        if already_closing then
          self._awaiting = nil
          return self:_resume(...)
        end

        local args = pack_len(...)
        -- We must close the closable child before we resume to ensure
        -- all resources are collected.
        --- @diagnostic disable-next-line: param-type-mismatch
        local close_ok, close_err = pcall(awaiting.close, awaiting, function()
          self._awaiting = nil
          return self:_resume(unpack_len(args))
        end)

        if close_ok then
          return
        end
        self._awaiting = nil
        return self:_resume(errors.normalize(close_err))
      end

      -- Check the coroutine is still alive before trying to resume it
      if coroutine.status(self._thread) == 'dead' then
        -- Can only happen if coroutine.resume() is called outside of this
        -- function. When that happens check_yield() will error the coroutine
        -- which puts it in the 'dead' state.
        self:_finalize(false, ...)
        return
      end

      return handle_resume_result(self, coroutine.resume(self._thread, resume_marker, ...))
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

--- Convert the public await forms into the shape consumed by `_resume()`.
---
--- The scheduler expects an awaitable to call `callback(err, ...)` and may use
--- its returned closable for cancellation cleanup. Callback-style APIs do not
--- have an error slot, so `norm_cb_fun()` inserts `nil`; task futures already
--- use this convention.
--- @param ... any
--- @return fun(callback: fun(err?: any, ...: any)): vim.async.Closable?
local function to_awaitable(...)
  local arg1 = select(1, ...)

  if type(arg1) == 'number' then
    return norm_cb_fun(...)
  elseif type(arg1) == 'function' then
    return norm_cb_fun(1, arg1)
  elseif is_task(arg1) then
    --- @param callback fun(err?: any, ...: any)
    return function(callback)
      arg1._future:on_complete(callback)
      return arg1
    end
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
  local awaitable = to_awaitable(...)

  --- @param callback fun(err?: any, ok?: boolean, ...: any)
  local function protected_awaitable(callback)
    -- Keep the scheduler error slot empty; `ok, ...` is the protected result.
    local ok, closable_or_err = pcall(awaitable, function(err, ...)
      if err ~= nil then
        callback(nil, false, err)
      else
        callback(nil, true, ...)
      end
    end)

    if not ok then
      callback(nil, false, errors.normalize(closable_or_err))
      return
    end

    return closable_or_err
  end

  return check_yield(coroutine.yield(yield_marker, protected_awaitable))
end

--- Explicitly yield at a task checkpoint.
---
--- This starts pending child tasks and delivers pending cancellation or task
--- failure from the current task.
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

do --- M._inspect_tree()
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
end

return M
