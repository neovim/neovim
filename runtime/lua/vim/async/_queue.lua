-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local new_event = require('vim.async._event')

--- An optionally bounded FIFO queue for passing values between async tasks.
---
--- `put()` suspends the current task while the queue is full, and `get()`
--- suspends it while the queue is empty. The `put_nowait()` and `get_nowait()`
--- variants never suspend and raise an error when the operation cannot proceed.
--- @class vim.async.Queue<R>
--- @field private _non_empty vim.async.Event
--- @field package _non_full vim.async.Event
--- @field private _max_size? integer
--- @field private _items R[]
--- @field private _right_i integer
--- @field private _left_i integer
local Queue = {}
Queue.__index = Queue

--- Returns the number of items in the queue.
--- @return integer
function Queue:size()
  return self._right_i - self._left_i
end

--- Returns the maximum number of items in the queue.
--- @return integer?
function Queue:max_size()
  return self._max_size
end

--- Put an item into the queue.
---
--- If the queue is full, wait until a free slot is available.
--- @async
--- @param value any
function Queue:put(value)
  while self:size() == self:max_size() do
    self._non_full:wait()
  end
  self:put_nowait(value)
end

--- Get an item from the queue.
---
--- If the queue is empty, wait until an item is available.
--- @async
--- @return any
function Queue:get()
  while self:size() == 0 do
    self._non_empty:wait()
  end
  return self:get_nowait()
end

--- Get an item from the queue without blocking.
---
--- If the queue is empty, raise an error.
--- @return any
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
  if self:size() == self:max_size() then
    self._non_full:clear()
  end
end

--- Create a new FIFO queue with async support.
--- @param max_size? integer The maximum number of items in the queue, defaults to no limit
--- @return vim.async.Queue<any>
return function(max_size)
  local self = setmetatable({
    _items = {},
    _left_i = 0,
    _right_i = 0,
    _max_size = max_size,
    _non_empty = new_event(),
    _non_full = new_event(),
  }, Queue)

  self._non_full:set()

  return self
end
