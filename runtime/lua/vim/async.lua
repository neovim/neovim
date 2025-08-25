--- This module implements an asynchronous programming library for Neovim,
--- enabling developers to write non-blocking, coroutine-based code. Below is a
--- summary of its key features and components:
---
--- 1. Async Contexts:
---    - Functions can run asynchronously using Lua coroutines.
---    - Async functions are annotated with `@async` and must run within an async context.
---
--- 2. Task Management:
---    - Create tasks with `vim.async.run()`.
---    - Tasks be awaited, canceled, or waited synchronously.
---
--- 3. Awaiting:
---    - [vim.async.await()]: Allows blocking on asynchronous operations, such as
---      tasks or callback-based functions.
---    - Supports overloads for tasks, and callback functions.
---
--- 4. Task Wrapping:
---    - [vim.async.wrap()]: Converts any callback-based functions into async functions.
---
--- 5. Concurrency Utilities:
---    - [vim.async.iter()]: Iterates over multiple tasks, yielding their results as
---      they complete.
---    - [vim.async.join()]: Waits for all tasks to complete and collects their
---      results.
---    - [vim.async.joinany()]: Waits for the first task to complete and returns its
---      result.
---
--- 6. Synchronization Primitives:
---    - [vim.async.event()]: Implements an event signaling mechanism for tasks to
---      wait and notify.
---    - [vim.async.queue()]: A thread-safe FIFO queue for producer-consumer patterns.
---    - [vim.async.semaphore()]: Limits concurrent access to shared resources.
---
--- 7. Error Handling:
---    - Errors in async tasks are propagated and can be raised or handled explicitly.
---    - Provides methods like [vim.async.Task:traceback()] for debugging.
---
--- Examples:
--- ```lua
---
---   -- Create an async version of vim.system
---   local system = vim.async.wrap(3, vim.system)
---
---   -- Create an async-context using run
---   vim.async.run(function()
---     local obj_ls = system({'ls'})
---     vim.async.sleep(200)
---     local obj_cat = system({'cat', 'file'})
---   end)
--- ```
---
--- ### async-function
---
--- Async functions are functions that must run in an [async-context] because
--- they contain at least one call to `async.await()`` that yields to event
--- loop.
---
--- These functions can be executed directly using `async.run()` which runs the
--- function in an async context.
---
--- Use the `@async` annotation to mark a function as an async function.
---
--- ### async-context
---
--- An async-context is an execution context managed by `vim.async` and is
--- implemented via [lua-coroutine]s. Only [async-functions] can run in an
--- async-context.
---
--- ### async-error-handling
---
--- Errors are handled differently depending on whether a function is called in
--- a blocking or non-blocking manner.
---
--- If a function is waited in a blocking call (via [async.await()] or
--- [async.Task:wait()] with `nil` or a timeout), errors are raised in the
--- calling thread.
---
--- If a function is waited in a non-blocking way (via [async.Task:wait()] with
--- a callback), errors are passed as part of the result in the form of `(err?,
--- ...)`, where `err` is the error message and `...` are the results of the
--- function when there is no error.
---
--- To run a Task without waiting for the result while still raising
--- any errors, use [async.Task:raise_on_error()].
---
--- ### async-task-ownership
---
--- Tasks are owned by the async context they are created in.
---
--- ```lua
--- local t1 = async.run(function() ... end)
---
--- local main = async.run(function()
---   local child = async.run(function() ... end)
---
---   -- child created in the main async context, owned by main.
---   -- Calls to `main:close()` will propagate to child.
---   async.await(child)
---
---   -- t1 created outside of the main async context.
---   async.await(t1)
--- end)
---
--- main:close() -- calls `child:close()` but not `t1:close()`
--- ```
---
--- When a parent task finishes, if finishes normally without an error, it will
--- await all of its children tasks before it completes. If it finishes with an
--- error, it close all of its children tasks.
---
--- ```lua
--- local main = async.run(function()
---   local child1 = async.run(function() ... end)
---   local child2 = async.run(function() ... end)
---   -- as neither child1 or child2 are awaited, they will be closed
---   -- when main finishes.
--- end)
--- ```
---
--- @class vim.async
local M = {}

--- @param ... any
--- @return {[integer]: any, n: integer}
local function pack_len(...)
  return { n = select('#', ...), ... }
end

--- like unpack() but use the length set by F.pack_len if present
--- @param t? { [integer]: any, n?: integer }
--- @param first? integer
--- @return any...
local function unpack_len(t, first)
  if t then
    return unpack(t, first or 1, t.n or table.maxn(t))
  end
end

--- @return_cast obj function
local function is_callable(obj)
  return vim.is_callable(obj)
end

--- Create a function that runs a function when it is garbage collected.
--- @generic F : function
--- @param f F
--- @param gc fun()
--- @return F
local function gc_fun(f, gc)
  local proxy = newproxy(true)
  local proxy_mt = getmetatable(proxy)
  proxy_mt.__gc = gc
  proxy_mt.__call = function(_, ...)
    return f(...)
  end

  return proxy
end

--- Weak table to keep track of running tasks
--- @type table<thread,vim.async.Task<any>?>
local threads = setmetatable({}, { __mode = 'k' })

--- @return vim.async.Task<any>?
local function running()
  local task = threads[coroutine.running()]
  -- TODO(lewis6991): condition needs a test
  if task and not (task:completed() or task._closing) then
    return task
  end
end

--- Internal marker used to identify that a yielded value is an asynchronous yielding.
local yield_marker = {}
local resume_marker = {}

--- @generic T
--- @param err? any
--- @param ... T...
--- @return T...
local function check_yield(marker, err, ...)
  if marker ~= resume_marker then
    -- This will leave the task in a dead (and unfinshed) state
    error('Unexpected coroutine.resume()', 2)
  elseif err then
    error(err, 0)
  end
  return ...
end

--- @generic T
--- @param thread thread
--- @return 'finished'|'error'|'ok' status
--- @param ... T...
--- @return T...
local function check_resume(thread, stat, ...)
  if not stat or coroutine.status(thread) == 'dead' then
    return stat and 'finished' or 'error', ...
  end

  local marker, fn = ...

  if marker ~= yield_marker or not is_callable(fn) then
    return 'error', 'Unexpected coroutine.yield()'
  end

  return 'ok', fn
end

--- @class vim.async.Closable
--- @field close fun(self, callback?: fun())

--- @param obj any
--- @return boolean
--- @return_cast obj vim.async.Closable
local function is_closable(obj)
  local ty = type(obj)
  return (ty == 'table' or ty == 'userdata') and vim.is_callable(obj.close)
end

--- Tasks are used to run coroutines in event loops. If a coroutine needs to
--- wait on the event loop, the Task suspends the execution of the coroutine and
--- waits for event loop to restart it.
---
--- Use the [vim.async.run()] to create Tasks.
---
--- To cancel a running Task use the `close()` method. Calling it will cause the
--- Task to throw a "closed" error in the wrapped coroutine.
---
--- Note a Task can be waited on via more than one waiter.
---
--- @class vim.async.Task<R>: vim.async.Closable
--- @field package _thread thread
--- @field package _future vim.async.Future<R>
--- @field package _closing boolean
---
--- Reference to parent to handle attaching/detaching.
--- @field package _parent? vim.async.Task<any>
--- @field package _parent_children_idx? integer
---
--- Maintain children as an array to preserve closure order.
--- @field package _children table<integer, vim.async.Task<any>?>
---
--- Pointer to last child in children
--- @field package _children_idx integer
---
--- Tasks can await other async functions (task of callback functions)
--- when we are waiting on a child, we store the handle to it here so we can
--- cancel it.
--- @field package _awaiting? vim.async.Task|vim.async.Closable
local Task = {}

do --- Task
  Task.__index = Task
  --- @package
  --- @param func function
  --- @return vim.async.Task
  function Task._new(func)
    local thread = coroutine.create(function(marker, ...)
      check_yield(marker)
      return func(...)
    end)

    local self = setmetatable({
      _closing = false,
      _thread = thread,
      _future = M.future(),
      _children = {},
      _children_idx = 0,
    }, Task)

    threads[thread] = self

    return self
  end

  --- @package
  function Task:_unwait(cb)
    return self._future:_remove_cb(cb)
  end

  --- Returns whether the Task has completed.
  --- @return boolean
  function Task:completed()
    return self._future:completed()
  end

  --- Add a callback to be run when the Task has completed.
  ---
  --- - If a timeout or `nil` is provided, the Task will synchronously wait for the
  ---   task to complete for the given time in milliseconds.
  ---
  ---   ```lua
  ---   local result = task:wait(10) -- wait for 10ms or else error
  ---
  ---   local result = task:wait() -- wait indefinitely
  ---   ```
  ---
  --- - If a function is provided, it will be called when the Task has completed
  ---   with the arguments:
  ---   - (`err: string`) - if the Task completed with an error.
  ---   - (`nil`, `...:any`) - the results of the Task if it completed successfully.
  ---
  ---
  --- If the Task is already done when this method is called, the callback is
  --- called immediately with the results.
  --- @param callback_or_timeout integer|fun(err?: any, ...: R...)?
  --- @overload fun(timeout?: integer): R...
  function Task:wait(callback_or_timeout)
    if is_callable(callback_or_timeout) then
      if self._closing then
        callback_or_timeout('Task is closing or closed')
      else
        self._future:wait(callback_or_timeout)
      end
      return
    end

    if
      not vim.wait(callback_or_timeout or vim._maxint, function()
        return self:completed()
      end)
    then
      error('timeout', 2)
    end

    local res = pack_len(self._future:result())

    assert(self:status() == 'dead' or res[2] == 'Unexpected coroutine.yield()')

    if not res[1] then
      error(res[2], 2)
    end

    return unpack_len(res, 2)
  end

  --- @param timeout integer?
  function Task:pwait(timeout)
    vim.validate('timeout', timeout, 'number', true)
    return pcall(self.wait, self, timeout)
  end

  --- @package
  --- @param parent? vim.async.Task
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

  --- @return vim.async.Task
  function Task:detach()
    if self._parent then
      self._parent._children[self._parent_children_idx] = nil
      self._parent = nil
      self._parent_children_idx = nil
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

    local thread = ('[%s] '):format(self._thread)

    local awaiting = self._awaiting
    if getmetatable(awaiting) == Task then
      --- @cast awaiting vim.async.Task
      msg = awaiting:traceback(msg, level + 1)
    end

    local tblvl = getmetatable(awaiting) == Task and 2 or nil
    msg = (tostring(msg) or '')
      .. debug.traceback(self._thread, '', tblvl):gsub('\n\t', '\n\t' .. thread)

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
  --- @return vim.async.Task self
  function Task:raise_on_error()
    self:wait(function(err)
      if err then
        error(self:traceback(err), 0)
      end
    end)
    return self
  end

  --- Close the task and all of its children.
  --- If callback is provided it will run asynchronously,
  --- else it will run synchronously.
  ---
  --- @param callback? fun()
  function Task:close(callback)
    local awaiting = getmetatable(self._awaiting) ~= Task and self._awaiting or nil

    local function close0()
      if self:completed() or self._closing then
        return
      end

      self._closing = true

      if awaiting then
        M.await(function(on_child_close)
          awaiting:close(on_child_close)
        end)
      end

      -- raised 'closed' error in the coroutine
      self:_resume('closed')

      return
    end

    -- perf: avoid run() if there are no callbacks or awaiting
    if callback or awaiting then
      return M.run(close0):wait(callback)
    else
      return close0()
    end
  end

  do -- Task:_resume()
    --- Should only be called in Task:_resume_co()
    --- @param task vim.async.Task
    --- @param stat boolean
    --- @param ... any result
    local function finish(task, stat, ...)
      local has_children = next(task._children) ~= nil

      local function finish0(...)
        -- Keep hold of the child tasks so we can use `task:traceback()`
        -- `task:traceback()`
        if stat or getmetatable(task._awaiting) ~= Task then
          task._awaiting = nil
        end

        if not stat then
          -- Task had an error, close all children
          for _, child in pairs(task._children) do
            child:close()
          end
        end

        for _, child in pairs(task._children) do
          M.await(child)
        end

        task:detach()

        threads[task._thread] = nil

        if not stat then
          task._future:complete((...))
        else
          task._future:complete(nil, ...)
        end
      end

      -- Only run finish0() if there are children, otherwise
      -- this will cause infinite recursion:
      --   M.run() -> task:_resume() -> resume_co() -> finish() -> M.run()
      if has_children then
        M.run(finish0, ...)
      else
        finish0(...)
      end
    end

    --- @private
    --- @param task vim.async.Task
    --- @param status 'finished'|'error'|'ok'
    --- @return fun(callback: fun(...:any...): vim.async.Closable?)?
    local function resume_co(task, status, ...)
      if status ~= 'ok' then
        finish(task, status == 'finished', ...)
        return
      end
      return (...)
    end

    --- @param task vim.async.Task
    --- @param awaitable fun(callback: fun(...:any...): vim.async.Closable?)
    local function handle_awaitable(task, awaitable)
      local ok, r
      local settled = false
      local next_args
      ok, r = pcall(awaitable, function(...)
        if settled then
          -- error here?
          return
        end
        settled = true

        if task:completed() then
          return
        end

        if ok == nil then
          next_args = pack_len(...)
        elseif is_closable(r) then
          -- We must close the closable child before we resume to ensure
          -- all resources are collected.
          local cargs = pack_len(...)

          local close_ok, close_err = pcall(r.close, r, function()
            task:_resume(unpack_len(cargs))
          end)

          if not close_ok then
            task:_resume(close_err)
          end
        else
          task:_resume(...)
        end
      end)

      if not ok then
        task:_resume(r)
      elseif is_closable(r) then
        task._awaiting = r
      end

      return next_args
    end

    --- @package
    --- @param ... any the first argument is the error, except for when the coroutine begins
    function Task:_resume(...)
      --- @type {[integer]: any, n: integer}?
      local args = pack_len(...)

      while args do
        if coroutine.status(self._thread) ~= 'suspended' then
          -- Can only happen if coroutine.resume() is called outside of this
          -- function. When that happens check_yield() will error the coroutine
          -- which puts it in the 'dead' state.
          finish(self, false, 'Unexpected coroutine.resume()')
          return
        end
        local awaitable = resume_co(
          self,
          check_resume(
            self._thread,
            coroutine.resume(self._thread, resume_marker, unpack_len(args))
          )
        )
        if not awaitable then
          return
        end
        args = handle_awaitable(self, awaitable)
      end
    end
  end

  --- @package
  function Task:_log(...)
    print(tostring(self._thread), ...)
  end

  --- Returns the status of tasks thread. See [coroutine.status()].
  --- @return 'running'|'suspended'|'normal'|'dead'?
  function Task:status()
    return coroutine.status(self._thread)
  end
end

--- Run a function in an async context, asynchronously.
---
--- Returns an [vim.async.Task] object which can be used to wait or await the result
--- of the function.
---
--- Examples:
--- ```lua
--- -- Run a uv function and wait for it
--- local stat = vim.async.run(function()
---     return vim.async.await(2, vim.uv.fs_stat, 'foo.txt')
--- end):wait()
---
--- -- Since uv functions have sync versions, this is the same as:
--- local stat = vim.fs_stat('foo.txt')
--- ```
--- @generic T, R
--- @param func async fun(...:T...): R... Function to run in an async context
--- @param ... T... Arguments to pass to the function
--- @return vim.async.Task<R>
function M.run(func, ...)
  -- TODO(lewis6991): add task names
  local task = Task._new(func)
  task:_attach(running())
  task:_resume(...)
  return task
end

do --- M.await()
  --- @generic T, R
  --- @param argc integer
  --- @param fun fun(...: T, callback: fun(...: R...))
  --- @param ... any func arguments
  --- @return fun(callback: fun(...: R...))
  local function norm_cb_fun(argc, fun, ...)
    local args = pack_len(...)

    --- @param callback fun(...:any)
    --- @return any?
    return function(callback)
      args[argc] = function(...)
        callback(nil, ...)
      end
      args.n = math.max(args.n, argc)
      return fun(unpack_len(args))
    end
  end

  --- Asynchronous blocking wait
  ---
  --- Example:
  --- ```lua
  --- local task = vim.async.run(function()
  ---    return 1, 'a'
  --- end)
  ---
  --- local task_fun = vim.async.async(function(arg)
  ---    return 2, 'b', arg
  --- end)
  ---
  --- vim.async.run(function()
  ---   do -- await a callback function
  ---     vim.async.await(1, vim.schedule)
  ---   end
  ---
  ---   do -- await a callback function (if function only has a callback argument)
  ---     vim.async.await(vim.schedule)
  ---   end
  ---
  ---   do -- await a task (new async context)
  ---     local n, s = vim.async.await(task)
  ---     assert(n == 1 and s == 'a')
  ---   end
  ---
  --- end)
  --- ```
  --- @async
  --- @generic T, R
  --- @param ... any see overloads
  --- @overload fun(func: (fun(callback: fun(...:R...)): vim.async.Closable?)): R...
  --- @overload fun(argc: integer, func: (fun(...:T..., callback: fun(...:R...)): vim.async.Closable?), ...:T...): R...
  --- @overload fun(task: vim.async.Task<R>): R...
  function M.await(...)
    assert(running(), 'Not in async context')

    local arg1 = select(1, ...)

    local fn --- @type fun(...:R...): vim.async.Closable?
    if type(arg1) == 'number' then
      fn = norm_cb_fun(...)
    elseif type(arg1) == 'function' then
      fn = norm_cb_fun(1, arg1)
    elseif getmetatable(arg1) == Task then
      fn = function(callback)
        arg1:wait(callback)
        return arg1
      end
    else
      error('Invalid arguments, expected Task or (argc, func) got: ' .. vim.inspect(arg1), 2)
    end

    return check_yield(coroutine.yield(yield_marker, fn))
  end
end

--- Creates an async function with a callback style function.
---
--- `func` can optionally return an object with a close method to clean up
--- resources. Note this method will be called when the task finishes or
--- interrupted.
---
--- Example:
---
--- ```lua
--- --- Note the callback argument is not present in the return function
--- --- @type async fun(timeout: integer)
--- local sleep = vim.async.wrap(2, function(timeout, callback)
---   local timer = vim.uv.new_timer()
---   timer:start(timeout * 1000, 0, callback)
---   -- uv_timer_t provides a close method so timer will be
---   -- cleaned up when this function finishes
---   return timer
--- end)
---
--- vim.async.run(function()
---   print('hello')
---   sleep(2)
---   print('world')
--- end)
--- ```
---
--- @generic T, R
--- @param argc integer
--- @param func fun(...: T, callback: fun(...: R)): vim.async.Closable?
--- @return async fun(...:T): R
function M.wrap(argc, func)
  assert(type(argc) == 'number')
  assert(type(func) == 'function')
  --- @async
  return function(...)
    return M.await(argc, func, ...)
  end
end

--- Waits for multiple tasks to finish and iterates over their results.
---
--- This function allows you to run multiple asynchronous tasks concurrently and
--- process their results as they complete. It returns an iterator function that
--- yields the index of the task, any error encountered, and the results of the
--- task.
---
--- If a task completes with an error, the error is returned as the second
--- value. Otherwise, the results of the task are returned as subsequent values.
---
--- Example:
--- ```lua
--- local task1 = vim.async.run(function()
---   return 1, 'a'
--- end)
---
--- local task2 = vim.async.run(function()
---   return 2, 'b'
--- end)
---
--- local task3 = vim.async.run(function()
---   error('task3 error')
--- end)
---
--- vim.async.run(function()
---   for i, err, r1, r2 in vim.async.iter({task1, task2, task3}) do
---     print(i, err, r1, r2)
---   end
--- end)
--- ```
---
--- Prints:
--- ```
--- 1 nil 1 'a'
--- 2 nil 2 'b'
--- 3 'task3 error' nil nil
--- ```
---
--- @async
--- @param tasks vim.async.Task<any>[] A list of tasks to wait for and iterate over.
--- @return async fun(): (integer?, any?, ...any) iterator that yields the index, error, and results of each task.
function M.iter(tasks)
  -- TODO(lewis6991): do not return err, instead raise any errors as they occur
  assert(running(), 'Not in async context')

  local results = {} --- @type [integer, any, ...any][]

  -- Iter blocks in an async context so only one waiter is needed
  local waiter = nil --- @type fun(index: integer?, err?: any, ...: any)?

  local remaining = #tasks

  -- Keep track of the callbacks so we can remove them when the iterator
  -- is garbage collected.
  --- @type table<vim.async.Task<any>,function>
  local task_cbs = setmetatable({}, { __mode = 'v' })

  --- If can_gc_cbs is true, then the iterator function has been garbage
  --- collected and means any awaiters can also be garbage collected. The
  --- only time we can't do this is if with the special case when iter() is
  --- called anonymously (`local i = vim.async.iter(tasks)()`), so we should not
  --- garbage collect the callbacks until at least one awaiter is called.
  local can_gc_cbs = false

  -- Wait on all the tasks. Keep references to the task futures and wait
  -- callbacks so we can remove them when the iterator is garbage collected.
  for i, task in ipairs(tasks) do
    local function cb(err, ...)
      if can_gc_cbs then
        for t, tcb in pairs(task_cbs) do
          t:_unwait(tcb)
        end
      end

      local callback = waiter

      -- Clear waiter before calling it
      waiter = nil

      remaining = remaining - 1
      if callback then
        -- Iterator is waiting, yield to it
        callback(i, err, ...)
      else
        -- Task finished before Iterator was called. Store results.
        table.insert(results, pack_len(i, err, ...))
      end
    end

    task_cbs[task] = cb
    task:wait(cb)
  end

  return gc_fun(
    M.wrap(1, function(callback)
      if next(results) then
        local res = table.remove(results, 1)
        callback(unpack_len(res))
      elseif remaining == 0 then
        callback() -- finish
      else
        assert(not waiter, 'internal error: waiter already set')
        waiter = callback
      end
    end),
    function()
      -- Don't gc callbacks just yet. Wait until at least one of them is called.
      can_gc_cbs = true
    end
  )
end

--- Wait for all tasks to finish and return their results.
---
--- Example:
--- ```lua
--- local task1 = vim.async.run(function()
---   return 1, 'a'
--- end)
---
--- local task2 = vim.async.run(function()
---   return 1, 'a'
--- end)
---
--- local task3 = vim.async.run(function()
---   error('task3 error')
--- end)
---
--- vim.async.run(function()
---   local results = vim.async.join({task1, task2, task3})
---   print(vim.inspect(results))
--- end)
--- ```
---
--- Prints:
--- ```
--- {
---   [1] = { nil, 1, 'a' },
---   [2] = { nil, 2, 'b' },
---   [3] = { 'task2 error' },
--- }
--- ```
--- @async
--- @param tasks vim.async.Task<any>[]
--- @return table<integer,[any?,...?]>
function M.join(tasks)
  assert(running(), 'Not in async context')
  local iter = M.iter(tasks)
  local results = {} --- @type table<integer,table>

  local function collect(i, ...)
    if i then
      results[i] = pack_len(...)
    end
    return i ~= nil
  end

  while collect(iter()) do
  end

  return results
end

--- @async
--- @param tasks vim.async.Task<any>[]
--- @return integer? index
--- @return any? err
--- @return any ... results
function M.joinany(tasks)
  return M.iter(tasks)()
end

--- @async
--- @param duration integer ms
function M.sleep(duration)
  M.await(1, function(callback)
    -- TODO(lewis6991): should return the result of defer_fn here.
    vim.defer_fn(callback, duration)
  end)
end

--- Run a task with a timeout.
---
--- If the task does not complete within the specified duration, it is cancelled
--- and an error is thrown.
--- @async
--- @generic R
--- @param task vim.async.Task<R>
function M.timeout(duration, task)
  local timer = M.run(M.await, 2, vim.defer_fn, duration)
  if M.joinany({ task, timer }) == 2 then
    -- Timer finished first, cancel the task
    task:close()
    error('timeout')
  end
  return M.await(task)
end

do --- M.future()
  --- Future objects are used to bridge low-level callback-based code with
  --- high-level async/await code.
  --- @class vim.async.Future<R>
  --- @field private _callbacks table<integer,fun(err?: any, ...: R...)>
  --- @field private _callback_pos integer
  --- Error result of the task is an error occurs.
  --- Must use `await` to get the result.
  --- @field private _err? any
  ---
  --- Result of the task.
  --- Must use `await` to get the result.
  --- @field private _result? R[]
  local Future = {}
  Future.__index = Future

  --- Return `true` if the Future is completed.
  --- @return boolean
  function Future:completed()
    return (self._err or self._result) ~= nil
  end

  --- Return the result of the Future.
  ---
  --- If the Future is done and has a result set by the `complete()` method, the
  --- result is returned.
  ---
  --- If the Future’s result isn’t yet available, this method raises a
  --- "Future has not completed" error.
  --- @return boolean stat
  --- @return any ... error or result
  function Future:result()
    if not self:completed() then
      error('Future has not completed', 2)
    end
    if self._err then
      return false, self._err
    else
      return true, unpack_len(self._result)
    end
  end

  --- Add a callback to be run when the Future is done.
  ---
  --- The callback is called with the arguments:
  --- - (`err: string`) - if the Future completed with an error.
  --- - (`nil`, `...:any`) - the results of the Future if it completed successfully.
  ---
  --- If the Future is already done when this method is called, the callback is
  --- called immediately with the results.
  --- @param callback fun(err?: any, ...: any)
  function Future:wait(callback)
    if self:completed() then
      -- Already finished or closed
      callback(self._err, unpack_len(self._result))
    else
      self._callbacks[self._callback_pos] = callback
      self._callback_pos = self._callback_pos + 1
    end
  end

  -- Mark the Future as complete and set its err or result.
  --- @param err? string
  --- @param ... any result
  function Future:complete(err, ...)
    if err ~= nil then
      self._err = err
    else
      self._result = pack_len(...)
    end

    local errs = {} --- @type string[]
    -- Need to use pairs to avoid gaps caused by removed callbacks
    for _, cb in pairs(self._callbacks) do
      local ok, cb_err = pcall(cb, err, ...)
      if not ok then
        errs[#errs + 1] = cb_err
      end
    end

    if #errs > 0 then
      error(table.concat(errs, '\n'), 0)
    end
  end

  --- @param cb fun(err?: any, ...: any)
  function Future:_remove_cb(cb)
    for j, fcb in pairs(self._callbacks) do
      if fcb == cb then
        self._callbacks[j] = nil
        break
      end
    end
  end

  --- Create a new future
  --- @return vim.async.Future
  function M.future()
    return setmetatable({
      _callbacks = {},
      _callback_pos = 1,
    }, Future)
  end
end

do --- M.event()
  --- An event can be used to notify multiple tasks that some event has
  --- happened. An Event object manages an internal flag that can be set to true
  --- with the `set()` method and reset to `false` with the `clear()` method.
  --- The `wait()` method blocks until the flag is set to `true`. The flag is
  --- set to `false` initially.
  --- @class vim.async.Event
  --- @field private _is_set boolean
  --- @field private _waiters function[]
  local Event = {}
  Event.__index = Event

  --- Set the event.
  ---
  --- All tasks waiting for event to be set will be immediately awakened.
  --- @param max_woken? integer
  function Event:set(max_woken)
    if self._is_set then
      return
    end
    self._is_set = true
    local waiters = self._waiters
    local waiters_to_notify = {} --- @type function[]
    max_woken = max_woken or #waiters
    while #waiters > 0 and #waiters_to_notify < max_woken do
      waiters_to_notify[#waiters_to_notify + 1] = table.remove(waiters, 1)
    end
    if #waiters > 0 then
      self._is_set = false
    end
    for _, waiter in ipairs(waiters_to_notify) do
      waiter()
    end
  end

  --- Wait until the event is set.
  ---
  --- If the event is set, return `true` immediately. Otherwise block until
  --- another task calls set().
  --- @async
  function Event:wait()
    M.await(function(callback)
      if self._is_set then
        callback()
      else
        table.insert(self._waiters, callback)
      end
    end)
  end

  --- Clear (unset) the event.
  ---
  --- Tasks awaiting on wait() will now block until the set() method is called
  --- again.
  function Event:clear()
    self._is_set = false
  end

  --- Create a new event
  ---
  --- An event can signal to multiple listeners to resume execution
  --- The event can be set from a non-async context.
  ---
  --- ```lua
  ---  local event = vim.async.event()
  ---
  ---  local worker = vim.async.run(function()
  ---    sleep(1000)
  ---    event.set()
  ---  end)
  ---
  ---  local listeners = {
  ---    vim.async.run(function()
  ---      event.wait()
  ---      print("First listener notified")
  ---    end),
  ---    vim.async.run(function()
  ---      event.wait()
  ---      print("Second listener notified")
  ---    end),
  ---  }
  --- ```
  --- @return vim.async.Event
  function M.event()
    return setmetatable({
      _waiters = {},
      _is_set = false,
    }, Event)
  end
end

do --- M.queue()
  --- @class vim.async.Queue
  --- @field private _non_empty vim.async.Event
  --- @field package _non_full vim.async.Event
  --- @field private _max_size? integer
  --- @field private _items integer[]
  --- @field private _right_i integer
  --- @field private _left_i integer
  local Queue = {}
  Queue.__index = Queue

  --- Returns the number of items in the queue
  function Queue:size()
    return self._right_i - self._left_i
  end

  --- Returns the maximum number of items in the queue
  function Queue:max_size()
    return self._max_size
  end

  --- Put a value into the queue
  --- @async
  --- @param value any
  function Queue:put(value)
    self._non_full:wait()
    self:put_nowait(value)
  end

  --- Get a value from the queue, blocking if the queue is empty
  --- @async
  function Queue:get()
    self._non_empty:wait()
    return self:get_nowait()
  end

  --- Get a value from the queue, erroring if queue is empty.
  --- If the queue is empty, raise "Queue is empty" error.
  function Queue:get_nowait()
    if self:size() == 0 then
      error('Queue is empty', 2)
    end
    -- TODO(lewis6991): For a long_running queue, _left_i might overflow.
    self._left_i = self._left_i + 1
    local item = self._items[self._left_i]
    self._items[self._left_i] = nil
    if self._left_i == self._right_i then
      self._non_empty:clear()
    end
    self._non_full:set(1)
    return item
  end

  --- Put an item into the queue without blocking.
  --- If no free slot is immediately available, raise "Queue is full" error.
  --- @param value any
  function Queue:put_nowait(value)
    if self:size() == self:max_size() then
      error('Queue is full', 2)
    end
    self._right_i = self._right_i + 1
    self._items[self._right_i] = value
    self._non_empty:set(1)
    if self:size() == self.max_size then
      self._non_full:clear()
    end
  end

  --- Create a new FIFO queue with async support.
  --- ```lua
  ---  local queue = vim.async.queue()
  ---
  ---  local producer = vim.async.run(function()
  ---    for i = 1, 10 do
  ---      sleep(100)
  ---      queue:put(i)
  ---    end
  ---    queue:put(nil)
  ---  end)
  ---
  ---  while true do
  ---    local value = queue:get()
  ---    if value == nil then
  ---      break
  ---    end
  ---    print(value)
  ---  end
  ---  print("Done")
  --- ```
  --- @param max_size? integer The maximum number of items in the queue, defaults to no limit
  --- @return vim.async.Queue
  function M.queue(max_size)
    local self = setmetatable({
      _items = {},
      _left_i = 0,
      _right_i = 0,
      _max_size = max_size,
      _non_empty = M.event(),
      _non_full = M.event(),
    }, Queue)

    self._non_full:set()

    return self
  end
end

do --- M.semaphore()
  --- A semaphore manages an internal counter which is decremented by each
  --- `acquire()` call and incremented by each `release()` call. The counter can
  --- never go below zero; when `acquire()` finds that it is zero, it blocks,
  --- waiting until some task calls `release()`.
  ---
  --- The preferred way to use a Semaphore is with the `with()` method, which
  --- automatically acquires and releases the semaphore around a function call.
  --- @class vim.async.Semaphore
  --- @field private _permits integer
  --- @field private _max_permits integer
  --- @field package _event vim.async.Event
  local Semaphore = {}
  Semaphore.__index = Semaphore

  --- Executes the given function within the semaphore's context, ensuring
  --- that the semaphore's constraints are respected.
  --- @async
  --- @generic R
  --- @param fn async fun(): R... # Function to execute within the semaphore's context.
  --- @return R... # Result(s) of the executed function.
  function Semaphore:with(fn)
    self:acquire()
    local r = pack_len(pcall(fn))
    self:release()
    local stat = r[1]
    if not stat then
      local err = r[2]
      error(err)
    end
    return unpack_len(r, 2)
  end

  --- Acquire a semaphore.
  ---
  --- If the internal counter is greater than zero, decrement it by `1` and
  --- return immediately. If it is `0`, wait until a `release()` is called.
  --- @async
  function Semaphore:acquire()
    self._event:wait()
    self._permits = self._permits - 1
    assert(self._permits >= 0, 'Semaphore value is negative')
    if self._permits == 0 then
      self._event:clear()
    end
  end

  --- Release a semaphore.
  ---
  --- Increments the internal counter by `1`. Can wake
  --- up a task waiting to acquire the semaphore.
  function Semaphore:release()
    if self._permits >= self._max_permits then
      error('Semaphore value is greater than max permits', 2)
    end
    self._permits = self._permits + 1
    self._event:set(1)
  end

  --- Create an async semaphore that allows up to a given number of acquisitions.
  ---
  --- ```lua
  --- vim.async.run(function()
  ---   local semaphore = vim.async.semaphore(2)
  ---
  ---   local tasks = {}
  ---
  ---   local value = 0
  ---   for i = 1, 10 do
  ---     tasks[i] = vim.async.run(function()
  ---       semaphore:with(function()
  ---         value = value + 1
  ---         sleep(10)
  ---         print(value) -- Never more than 2
  ---         value = value - 1
  ---       end)
  ---     end)
  ---   end
  ---
  ---   vim.async.join(tasks)
  ---   assert(value <= 2)
  --- end)
  --- ```
  --- @param permits? integer (default: 1)
  --- @return vim.async.Semaphore
  function M.semaphore(permits)
    permits = permits or 1
    local obj = setmetatable({
      _max_permits = permits,
      _permits = permits,
      _event = M.event(),
    }, Semaphore)
    obj._event:set()
    return obj
  end
end

return M
