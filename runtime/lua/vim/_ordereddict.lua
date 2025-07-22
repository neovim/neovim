-- other names: indexmap (rust), or just "dict" ...
local M = {}
M.__index = M

-- Creates a new ordered dict.
function M.new()
  return setmetatable({
    _keys = {}, -- Ordered keys.
    _vals = {}, -- Unordered key-value pairs.
  }, M)
end

function M:set(key, value)
  if self._vals[key] == nil then
    table.insert(self._keys, key)
  end
  self._vals[key] = value
end

function M:get(key)
  return self._vals[key]
end

function M:remove(key)
  if self._vals[key] == nil then
    return false
  end
  -- Remove the value.
  self._vals[key] = nil
  -- Remove from _keys
  for i, k in ipairs(self._keys) do
    if k == key then
      table.remove(self._keys, i)
      return true
    end
  end
  return false
end

function M:pop()
  local key = self._keys[#self._keys]
  if not key then
    return nil
  end
  local val = self._vals[key]
  self._vals[key] = nil
  table.remove(self._keys)
  return key, val
end

--- Gets the item count.
function M:len()
  return #self._keys
end

-- Iterates over key-value pairs in insertion order.
function M:__call()
  local i = 0
  local keys = self._keys
  local vals = self._vals
  return function()
    i = i + 1
    local k = keys[i]
    if k ~= nil then
      return k, vals[k]
    end
    return nil
  end
end

return M
