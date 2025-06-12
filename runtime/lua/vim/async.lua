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
--- they contain at least one call that interacts with the event loop.
---
--- These functions can be executed directly using `async.run()` which runs the
--- function in an async context.
---
--- Use the `@async` annotation to designate a function as an async function.
---
--- ### async-context
---
--- An async-context is an executation context managed by `vim.async` and is
--- implemented via [lua-coroutine]s. Many of the functions and methods in
--- `vim.async` can only run when within this context.
---
--- ### async-error-handling
---
--- Errors are handled differently depending on whether a function is called in
--- a blocking or non-blocking manner.
---
--- If a function is waited in a blocking call (via [async.await()] or [async.Task:wait()]),
--- errors are raised immediately.
---
--- If a function is waited in a non-blocking way (via [async.Task:wait()]),
--- errors are passed as part of the result in the form of `(err?, ...)`, where
--- `err` is the error message and `...` are the results of the function when
--- there is no error.
---
--- To run a Task without waiting for the result while still raising
--- any errors, use [async.Task:raise_on_error()].
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
  if task and not (task._future:completed() or task._closing) then
    return task
  end
end

--- @class vim.async.Closable
--- @field close fun(self, callback?: fun())

--- Tasks are used to run coroutines in event loops. If a coroutine needs to
--- wait on the event loop, the Task suspends the execution of the coroutine and
--- waits for event loop to restart it.
---
--- Use the [vim.async.run()] to create Tasks.
---
--- To cancel a running Task use the `close()` method. Calling it will cause the
--- Task to throw a "Task is closing or closed" error into the wrapped coroutine.
---
--- Note a Task can be waited on via more than one waiter.
---
--- -- If a
--- -- coroutine is awaiting on a Future object during cancellation, the Future
--- -- object will be cancelled.
--- @class vim.async.Task<R>: vim.async.Closable
--- @field private _thread thread
--- @field package _future vim.async.Future<R>
--- @field package _closing boolean
---
--- Tasks can await other async functions (task of callback functions)
--- when we are waiting on a child, we store the handle to it here so we can
--- cancel it.
--- @field private _child? vim.async.Task|vim.async.Closable
local Task = {}
Task.__index = Task

--- @package
--- @param func function
--- @return vim.async.Task
function Task._new(func)
  local thread = coroutine.create(func)

  local self = setmetatable({
    _closing = false,
    _thread = thread,
    _future = M.future(),
  }, Task)

  --- @diagnostic disable-next-line: assign-type-mismatch
  threads[thread] = self

  return self
end

--- @return_cast obj function
local function is_callable(obj)
  return vim.is_callable(obj)
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
      return self._future:completed()
    end)
  then
    error('timeout', 2)
  end

  local res = pack_len(self._future:result())

  if not res[1] then
    error(res[2], 2)
  end

  return unpack_len(res, 2)
end

--- @private
--- @param msg? string
--- @param _lvl? integer
--- @return string
function Task:_traceback(msg, _lvl)
  _lvl = _lvl or 0

  local thread = ('[%s] '):format(self._thread)

  local child = self._child
  if getmetatable(child) == Task then
    --- @cast child vim.async.Task
    msg = child:_traceback(msg, _lvl + 1)
  end

  local tblvl = getmetatable(child) == Task and 2 or nil
  msg = (msg or '') .. debug.traceback(self._thread, '', tblvl):gsub('\n\t', '\n\t' .. thread)

  if _lvl == 0 then
    --- @type string
    msg = msg
      :gsub('\nstack traceback:\n', '\nSTACK TRACEBACK:\n', 1)
      :gsub('\nstack traceback:\n', '\n')
      :gsub('\nSTACK TRACEBACK:\n', '\nstack traceback:\n', 1)
  end

  return msg
end

--- Get the traceback of a task when it is not active.
--- Will also get the traceback of nested tasks.
---
--- @param msg? string
--- @return string traceback
function Task:traceback(msg)
  return self:_traceback(msg)
end

--- If a task completes with an error, raise the error
--- @return vim.async.Task self
function Task:raise_on_error()
  self:wait(function(err)
    if err then
      error(self:_traceback(err), 0)
    end
  end)
  return self
end

--- @private
--- @param err? any
--- @param result? {[integer]: any, n: integer}
function Task:_finish(err, result)
  -- Keep hold of the child tasks so we can use `task:traceback()`
  -- `task:traceback()`
  if not err or getmetatable(self._child) ~= Task then
    self._child = nil
  end
  threads[self._thread] = nil
  self._future:complete(err, unpack_len(result))
end

--- Close the task and all of its children.
--- If callback is provided it will run asynchronously,
--- else it will run synchronously.
---
--- @param callback? fun(closed: boolean)
--- @overload fun(): boolean
--- @overload fun(callback: fun(closed: boolean))
function Task:close(callback)
  return M.run(function()
    if self._future:completed() or self._closing then
      return false
    end

    self._closing = true

    if self._child then
      M.await(1, function(on_child_close)
        self._child:close(on_child_close)
      end)
    end
    self:_finish('closed')
    return true
  end):wait(callback)
end

--- @param obj any
--- @return boolean
--- @return_cast obj vim.async.Closable
local function is_closable(obj)
  local ty = type(obj)
  return (ty == 'table' or ty == 'userdata') and vim.is_callable(obj.close)
end

--- Internal marker used to identify that a yielded value is an asynchronous yielding.
local yield_marker = {}

--- @package
--- @param ... any
function Task:_resume(...)
  local args = pack_len(...)

  while true do
    --- @diagnostic disable-next-line: assign-type-mismatch
    --- @type [boolean, string|{}, fun(...:R...): vim.async.Closable?]
    local ret = pack_len(coroutine.resume(self._thread, unpack_len(args)))

    local stat = ret[1]

    if not stat then
      -- Coroutine had error
      return self:_finish(ret[2])
    elseif coroutine.status(self._thread) == 'dead' then
      -- Coroutine finished
      local result = pack_len(unpack_len(ret, 2))
      return self:_finish(nil, result)
    end

    local marker, fn = ret[2], ret[3]

    if marker ~= yield_marker or not is_callable(fn) then
      return self:_finish('Unexpected coroutine.yield')
    end

    local ok, r
    local settled = false
    local is_continuation_deferred = true
    ok, r = pcall(fn, function(...)
      if settled then
        -- error here?
        return
      end
      settled = true

      if ok == nil then
        is_continuation_deferred = false
        args = pack_len(...)
      elseif is_closable(r) then
        -- We must close the closable child before we resume to ensure
        -- all resources are collected.
        local cargs = pack_len(...)

        local close_ok, close_err = pcall(r.close, r, function()
          self:_resume(unpack_len(cargs))
        end)

        if not close_ok then
          self:_finish(close_err)
        end
      else
        self:_resume(...)
      end
    end)

    if not ok then
      self:_finish(r)
    elseif is_closable(r) then
      self._child = r
    end

    if is_continuation_deferred then
      break
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
  local task = Task._new(func)
  task:_resume(...)
  return task
end

--- @async
--- @generic R
--- @param fun fun(...:R...): vim.async.Closable?
--- @return R...
local function yield(fun)
  assert(type(fun) == 'function', 'Expected function')
  return coroutine.yield(yield_marker, fun)
end

--- @async
--- @param task vim.async.Task
--- @return any ...
local function await_task(task)
  --- @param callback fun(err?: string, ...: any)
  local res = pack_len(yield(function(callback)
    task:wait(callback)
    return task
  end))

  local err = res[1]

  if err then
    -- TODO(lewis6991): what is the correct level to pass?
    error(err, 0)
  end

  return unpack_len(res, 2)
end

--- Asynchronous blocking wait
--- @async
--- @generic T, R
--- @param argc integer
--- @param fun fun(...: T, callback: fun(...: R))
--- @param ... any func arguments
--- @return any ...
local function await_cbfun(argc, fun, ...)
  local args = pack_len(...)

  --- @param callback fun(...:any)
  --- @return any?
  return yield(function(callback)
    args[argc] = callback
    args.n = math.max(args.n, argc)
    return fun(unpack_len(args))
  end)
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

  if type(arg1) == 'number' then
    return await_cbfun(...)
  elseif type(arg1) == 'function' then
    return await_cbfun(1, arg1)
  elseif getmetatable(arg1) == Task then
    return await_task(...)
  end

  error('Invalid arguments, expected Task or (argc, func) got: ' .. vim.inspect(arg1), 2)
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
--- yields the index of the task, any error encountered, and the results of the task.
---
--- If a task completes with an error, the error is returned as the second value.
--- Otherwise, the results of the task are returned as subsequent values.
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
  assert(running(), 'Not in async context')

  local results = {} --- @type [integer, any, ...any][]

  -- Iter blocks in an async context so only one waiter is needed
  local waiter = nil --- @type fun(index: integer?, err?: any, ...: any)?

  local remaining = #tasks

  -- Keep track of the callbacks so we can remove them when the iterator
  -- is garbage collected.
  --- @type table<vim.async.Future<any>,function>
  local futs = setmetatable({}, { __mode = 'v' })

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
        for fut, tcb in pairs(futs) do
          fut:_remove_cb(tcb)
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

    futs[task._future] = cb
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

do --- future()
  --- Future objects are used to bridge low-level callback-based code with
  --- high-level async/await code.
  --- @class vim.vim.async.Future<R>
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
    if self:completed() then -- TODO(lewis6991): test
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

do --- event()
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
    M.await(1, function(callback)
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

do --- queue()
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

do --- semaphore()
  --- A semaphore manages an internal counter which is decremented by each
  --- `acquire()` call and incremented by each `release()` call. The counter can
  --- never go below zero; when `acquire()` finds that it is zero, it blocks,
  --- waiting until some task calls `release()`.
  ---
  --- The preferred way to use a Semaphore is with the `with()` method, which
  --- automatically acquires and releases the semaphore around a function call.
  --- @class vim.async.Semaphore
  --- @field private _permits integer
  --- @field private _queue table<integer, thread>
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
  --- @param permits integer
  --- @return vim.async.Semaphore
  function M.semaphore(permits)
    local obj = setmetatable({
      _permits = permits or 1,
      _queue = {},
      _event = M.event(),
    }, Semaphore)
    obj._event:set()
    return obj
  end
end

return M
