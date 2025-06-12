-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local new_event = require('vim.async._event')

local Queue = {}
Queue.__index = Queue

function Queue:size()
  return self._right_i - self._left_i
end

function Queue:max_size()
  return self._max_size
end

function Queue:put(value)
  while self:size() == self:max_size() do
    self._non_full:wait()
  end
  self:put_nowait(value)
end

function Queue:get()
  while self:size() == 0 do
    self._non_empty:wait()
  end
  return self:get_nowait()
end

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
