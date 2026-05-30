--- @brief
---
--- `vim.async` provides primitives for coroutine-based asynchronous
--- programming in Lua. It includes:
---
--- - `RingQueue` and `ListQueue`: bounded and unbounded first-in-first-out
---   queue data structures with `push`/`pop` operations.
--- - `spawn()`: run a function in a detached coroutine that is tracked so
---   yielding across resume boundaries is safe.
--- - `spawn_wrap()`: wrap a function so it runs in a spawned coroutine
---   each time it is called.
--- - `chan()`: create a communication channel with a bounded buffer for
---   passing messages between coroutines, with support for backpressure
---   and graceful close.
--- - `await()`: invoke a callback-style async function and synchronously
---   return its results, either by yielding (in a spawned coroutine) or
---   via `vim.wait` (in other contexts).
---
local function class(body)
  return setmetatable(body or {}, {
    __call = function(cls, ...)
      local object = setmetatable({}, {
        __index = cls,
        __call = function(obj, ...) return obj:__call(...) end
      })
      if object.__init then object:__init(...) end
      return object
    end
  })
end

---@class vim.async.RingQueue<T>
---@field _capacity number
---@field _size number
---@field _idx number
---@field _items T[]
---@overload fun(capacity: number): vim.async.RingQueue<T>
local RingQueue = class {}

---@param capacity number
function RingQueue:__init(capacity)
  self._capacity = capacity
  self._size = 0
  self._idx = 1
  self._items = {}
end

---@return boolean
function RingQueue:is_empty()
  return self._size == 0
end

---@return boolean
function RingQueue:is_full()
  return self._size == self._capacity
end

--- Pushes item to queue. Returns false if queue is full, and true otherwise.
---@param item T
---@return boolean
function RingQueue:push(item)
  if self:is_full() then return false end

  local idx = ((self._idx - 1 + self._size) % self._capacity) + 1
  self._items[idx] = item

  self._size = self._size + 1
  return true
end

--- Removes and returns first queue item. Returns nil if queue is empty.
---@return T?
function RingQueue:pop()
  if self:is_empty() then return nil end

  local item = self._items[self._idx]
  self._items[self._idx] = nil

  self._idx = (self._idx % self._capacity) + 1
  self._size = self._size - 1

  return item
end

--- Alias for vim.async.RingQueue.pop()
---@return T?
function RingQueue:__call()
  return self:pop()
end

---@class vim.async.ListQueueNode<T>
---@field value T
---@field next vim.async.ListQueueNode?

---@class vim.async.ListQueue<T>
---@field _size number
---@field _start vim.async.ListQueueNode?
---@field _end vim.async.ListQueueNode?
---@overload fun(): vim.async.ListQueue<T>
local ListQueue = class {}

function ListQueue:__init()
  self._size = 0
  self._start = nil
  self._end = nil
end

---@return boolean
function ListQueue:is_empty()
  return self._size == 0
end

---@param item T
function ListQueue:push(item)
  local node = { _value = item }
  if self:is_empty() then
    self._start = node
    self._end = node
  else
    self._end.next = node
    self._end = node
  end
  self._size = self._size + 1
end

---@return T?
function ListQueue:pop()
  if self:is_empty() then return nil end

  local item = self._start.value
  self._start = self._start.next
  self._size = self._size - 1

  if not self._start then self._end = nil end

  return item
end

---@return T?
function ListQueue:__call()
  return self:pop()
end

local M = {}

M.ringqueue = RingQueue
M.listqueue = ListQueue

--- Tracks coroutines created by `M.spawn`. Yielding from them is safe
--- because they are resumed from Lua callbacks rather than from C.
--- @type table<thread, boolean>
local spawned = setmetatable({}, { __mode = 'k' })

---@param coro thread
local function safe_resume(coro)
  local ok, err = coroutine.resume(coro)
  if not ok then
    spawned[coro] = nil
    vim.schedule(function()
      vim.notify(
        string.format("Coroutine resume failed: %s", debug.traceback(coro, err)),
        vim.log.levels.ERROR)
    end)
  end
end

--- Spawn a detached coroutine that runs a function.
---
--- The coroutine is tracked so `M.await` knows yielding across its
--- resume is safe.
---
--- @param func fun(...): any Function to run in a coroutine
--- @param ... any Arguments forwarded to `func`
function M.spawn(func, ...)
  local args = { ... }

  local coro
  coro = coroutine.create(function()
    local ok, err = xpcall(function() func(unpack(args)) end, debug.traceback)

    spawned[coro] = nil

    if not ok then
      vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end)
    end
  end)
  spawned[coro] = true

  safe_resume(coro)
end

local TIMEOUT = 1000

--- Creates a channel for coroutine-safe communication.
---@generic T
---@param max? number
---@return fun(...: T) send
---@return fun(): T... recv
---@return fun(): boolean close
function M.chan(max)
  local message_queue = RingQueue(max or 1)
  local recv_queue = ListQueue()
  local send_queue = ListQueue()
  local closed = false

  local function send(...)
    if closed then error("Send on closed channel") end

    local message = { ... }

    while true do
      if message_queue:push(message) then
        for coro in recv_queue do
          if coroutine.status(coro) ~= 'dead' then
            safe_resume(coro)
            break
          end
        end
        return
      end

      if closed then error("Send on closed channel") end

      local coro = coroutine.running()
      if coro and spawned[coro] then
        send_queue:push(coro)
        coroutine.yield()
        if closed then error("Send on closed channel") end
      else
        error("Channel queue is full, send from non-spawned context")
      end
    end
  end

  local function recv()
    while true do
      local message = message_queue:pop()
      if message then
        for coro in send_queue do
          if coroutine.status(coro) ~= 'dead' then
            safe_resume(coro)
            break
          end
        end
        return unpack(message)
      end

      if closed then return nil end

      local coro = coroutine.running()
      if coro and spawned[coro] then
        recv_queue:push(coro)
        coroutine.yield()
      else
        local ok = vim.wait(TIMEOUT,
          function() return not message_queue:is_empty() end, nil, true)
        if not ok then error("Exceeded maximum coroutine waiting time.") end
      end
    end
  end

  local function close()
    if closed then return false end

    closed = true

    for coro in recv_queue do
      if coroutine.status(coro) ~= 'dead' then
        safe_resume(coro)
      end
    end

    for coro in send_queue do
      if coroutine.status(coro) ~= 'dead' then
        safe_resume(coro)
      end
    end

    return true
  end

  return send, recv, close
end

--- Wraps `func` so each call runs it in a spawned coroutine.
---
--- Equivalent to `function(...) vim.async.spawn(func, ...) end`.
--- Useful for passing a function that should run asynchronously
--- as a callback (e.g. to event handlers).
---
---@param func fun(...: any) Function to run in a spawned coroutine
---@return fun(...: any) Wrapped function that spawns `func` with given args
function M.spawn_wrap(func)
  return function(...) return M.spawn(func, ...) end
end

--- Await a callback-style async function and return its results synchronously.
---
--- Appends a synthetic callback, calls `func`, then waits until it fires.
--- If called from a spawned coroutine it yields (safe); otherwise it uses
--- `vim.wait` to avoid 'yield across C-Call boundary' errors in
--- Neovim-managed coroutines.
---
--- The callback is expected to pass its results as normal return values:
---   callback(...)
--- which will be returned by `await`.
---
--- @generic R
--- @param func fun(..., callback: fun(...: R))
--- @param ... any Arguments forwarded to `func` (before the callback)
--- @return ... R Results passed to the callback
function M.await(func, ...)
  local send, recv = M.chan()
  local args = { ... }
  table.insert(args, send)
  func(unpack(args))
  return recv()
end

return M
