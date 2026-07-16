local core = require('vim.async._core')
local validate = vim.validate
local new_queue = require('vim.async._queue')
local runtime = require('vim.async._runtime')
local util = require('vim.async._util')

--- Structured async API for Lua code that waits on event-loop work.
---
--- `vim.async` lets Lua code wait for timers, callbacks, and other tasks
--- without blocking Nvim's event loop. Async work runs inside tasks. A task can
--- pause at checkpoints, resume on a later event-loop turn, and manage child
--- tasks created while it is running.
---
--- Start async work with [vim.async.run()]. Inside a task, use
--- [vim.async.await()] to wait for callback-style APIs or other tasks without
--- blocking the event loop. Use [vim.async.pawait()] when an awaited operation
--- can fail and the current task should continue.
---
--- Examples in this help use `local async = vim.async` for brevity.
---
--- Example: run async work without blocking Nvim:
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   vim.notify('waiting...')
---   async.sleep(1000)
---   vim.notify('done')
--- end)
--- ```
---
--- Example: await a callback-style API. Callback results are returned
--- unchanged, so an error-first callback still returns `err, value`:
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local path = vim.api.nvim_buf_get_name(0)
---   local err, stat = async.await(2, vim.uv.fs_stat, path)
---
---   if err then
---     vim.notify(err, vim.log.levels.ERROR)
---     return
---   end
---
---   vim.notify(('current buffer is %d bytes'):format(stat.size))
--- end)
--- ```
---
--- A task has two roles:
---
--- - it is a handle that can be awaited, waited for, or closed
--- - it is a scope for child tasks created while the task is running
---
--- [vim.async.run()] creates a task. A top-level task starts immediately. A
--- task created while another task is running becomes a child of that task, and
--- its function starts when the parent reaches its next checkpoint. A parent
--- task finishes only after its attached children finish. If a child fails
--- without being handled, the parent fails and closes the remaining children.
---
--- Use [Task:detach()] for background work that should keep running after the
--- current task finishes. A detached task becomes top-level work; the original
--- parent no longer waits for it or closes it.
---
--- Awaiting a task observes that task's result; it does not attach the task to
--- the awaiter or change which task owns it. Ownership is decided when the task
--- is created.
---
--- Scheduling is cooperative. When a task awaits a timer, I/O operation,
--- callback, or another task, `vim.async` saves the Lua stack and returns
--- control to the event loop. Other callbacks can run while the task is
--- paused, and the task resumes on a later event-loop turn. Nothing interrupts
--- synchronous Lua code in the middle of a stack frame.
---
--- Checkpoints are the places where a task can pause, start pending child
--- tasks, observe cancellation, and receive unhandled child failures. Inside a
--- task, these operations are checkpoints:
---
--- - `vim.async.await(...)`
--- - `vim.async.pawait(...)`
--- - `vim.async.checkpoint()`
--- - successful return from the task function, which is the final checkpoint
---   for child management
---
--- Convenience APIs such as [vim.async.sleep()] and [vim.async.timeout()] can
--- also checkpoint because they call checkpointing APIs internally.
---
--- Closing a task closes its attached children. Cancellation is cooperative:
--- [Task:close()] marks a task as closing, and the task observes that state at
--- a checkpoint. If a task is suspended on a closable operation such as a timer
--- or child task, `vim.async` closes that operation before reporting the
--- cancellation.
---
--- Use [vim.async.await()] inside a task to suspend until work completes. It
--- accepts a task, a callback-taking function, or an argument position plus a
--- callback-taking function. `await(task)` returns the task result or raises
--- the task failure. [vim.async.pawait()] is the async counterpart to `pcall()`
--- for recoverable awaited-operation failures; it returns `ok, ...` instead of
--- failing the current task for that awaited operation. It does not suppress
--- cancellation or a failure already pending on the current task.
---
--- From synchronous code, use [Task:wait()] or [Task:pwait()] to pump the event
--- loop until the task completes. Use [Task:on_complete()] to observe
--- completion without blocking.
---
--- Coordination helpers work with task handles. [vim.async.iter()] yields
--- completed task handles in completion order, [vim.async.timeout()] awaits a
--- task with a deadline, and `vim.async.semaphore(permits)` creates a
--- [vim.async.Semaphore] that limits how many tasks can hold a permit for a
--- section at once.
--- @class vim.async: vim.async._core
local M = setmetatable({}, { __index = core })

M.semaphore = require('vim.async._semaphore')

--- @param unsubscribe fun()[]
local function unsubscribe_all(unsubscribe)
  for _, unsub in ipairs(unsubscribe) do
    unsub()
  end
end

--- Create an async function from a callback-style function.
---
--- The callback is inserted at argument position `argc`. If `func` returns a
--- closable handle, it is closed when the awaiting task is cancelled.
---
--- This is a reusable wrapper around [vim.async.await()]. Use it when the same
--- callback API is awaited from more than one place.
---
--- ```lua
--- local async = vim.async
--- local fs_stat = async.wrap(2, vim.uv.fs_stat)
---
--- async.run(function()
---   local err, stat = fs_stat(vim.api.nvim_buf_get_name(0))
---   if not err and stat then
---     print(stat.size)
---   end
--- end)
--- ```
---
--- @generic T, R
--- @param argc integer
--- @param func fun(...: T..., callback: fun(...: R...)): vim.async.Closable?
--- @return async fun(...: T...): R...
function M.wrap(argc, func)
  validate('argc', argc, 'number')
  validate('func', func, 'callable')
  --- @async
  return function(...)
    return M.await(argc, func, ...)
  end
end

--- Iterate completed tasks in completion order.
---
--- The iterator yields task handles, not task results. Use
--- [vim.async.await()] or [vim.async.pawait()] to retrieve each result. The
--- tasks are observed in the order they complete, regardless of the order in
--- the input list.
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local tasks = {
---     async.run(function() return 'cache', read_cache() end):detach(),
---     async.run(function() return 'disk', read_file() end):detach(),
---   }
---
---   for task in async.iter(tasks) do
---     local ok, source, text = async.pawait(task)
---     if ok then
---       for _, other in ipairs(tasks) do
---         if other ~= task then
---           other:close()
---         end
---       end
---       print(('loaded from %s'):format(source))
---       return text
---     end
---   end
--- end)
--- ```
---
--- If code must support PUC Lua 5.1, use the direct-call form instead of a
--- generic `for` loop. The iterator may need to suspend while waiting for the
--- next completed task, and PUC Lua 5.1 cannot yield from a generic-for
--- iterator call.
---
--- ```lua
--- local next_task = async.iter(tasks)
--- while true do
---   local task = next_task()
---   if task == nil then
---     break
---   end
---   async.await(task)
--- end
--- ```
--- @async
--- @generic R
--- @param tasks vim.async.Task<R>[] A list of tasks to wait for and iterate over.
--- @return async fun(): vim.async.Task<R>? iterator that yields each completed task.
function M.iter(tasks)
  validate('tasks', tasks, 'table')

  local remaining = #tasks
  local queue = new_queue()
  local unsubscribe = {} --- @type fun()[]

  if remaining == 0 then
    queue:put_nowait()
  else
    for _, task in ipairs(tasks) do
      unsubscribe[#unsubscribe + 1] = task:on_complete(function()
        remaining = remaining - 1
        queue:put_nowait(task)
        if remaining == 0 then
          queue:put_nowait()
        end
      end)
    end
  end

  --- @async
  local function next_task()
    return queue:get()
  end

  return util.gc_fun(next_task, function()
    unsubscribe_all(unsubscribe)
  end)
end

--- Asynchronously sleep for a given duration.
---
--- Suspends the current task for the given duration, but does not block Nvim's
--- main loop.
---
--- ```lua
--- vim.async.run(function()
---   vim.async.sleep(100)
---   vim.notify('resumed later')
--- end)
--- ```
--- @async
--- @param duration integer ms
function M.sleep(duration)
  validate('duration', duration, 'number')
  M.await(function(callback)
    local timer = runtime.new_timer()
    timer:start(duration, 0, callback)
    return timer
  end)
end

--- Await a task with a timeout.
---
--- If the task completes first, returns or raises the task result as
--- [vim.async.await()] would. If the deadline wins, closes the task and raises
--- `"timeout"` after the target task finishes cancellation cleanup.
---
--- ```lua
--- local async = vim.async
---
--- async.run(function()
---   local task = async.run(read_file, 'notes.txt')
---   local text = async.timeout(5000, task)
---   show_buffer(text)
--- end)
--- ```
--- @async
--- @generic R
--- @param duration integer Timeout duration in milliseconds
--- @param task vim.async.Task<R>
--- @return R
function M.timeout(duration, task)
  validate('duration', duration, 'number')
  validate('task', task, 'table')

  local timed_out = false
  local timer = M.run('__timeout', function()
    M.sleep(duration)
    timed_out = true
    task:close()
  end)
  --- @diagnostic disable-next-line: invisible
  timer._hidden = true

  local result = util.pack_len(M.pawait(task))
  timer:close()
  M.pawait(timer)

  if timed_out then
    error('timeout', 0)
  end

  if not result[1] then
    error(result[2], 0)
  end

  return util.unpack_len(result, 2)
end

if type(vim) == 'table' then
  runtime.config({
    wait = vim.wait,
    schedule = vim.schedule,
    new_timer = vim.uv.new_timer,
  })
end

return M
