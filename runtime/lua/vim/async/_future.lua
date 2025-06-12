-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local util = require('vim.async._util')
local errors = require('vim.async._errors')

local Future = {}
Future.__index = Future

function Future:completed()
  return self._err ~= nil or self._result ~= nil
end

function Future:result()
  if not self:completed() then
    error('Future has not completed', 2)
  end
  if self._err ~= nil then
    return false, self._err
  else
    return true, util.unpack_len(self._result)
  end
end

function Future:on_complete(callback)
  if self:completed() then
    -- Already completed or closed
    callback(self._err, util.unpack_len(self._result))
    return function() end
  end

  local id = self._callback_pos
  self._callback_pos = id + 1
  self._callbacks[id] = callback

  return function()
    self._callbacks[id] = nil
  end
end

function Future:complete(err, ...)
  if self:completed() then
    error('Future is already completed', 2)
  end

  if err ~= nil then
    self._err = err
  else
    self._result = util.pack_len(...)
  end

  local callbacks = self._callbacks
  self._callbacks = {}

  local errs = {} -- Need to use pairs to avoid gaps caused by removed callbacks
  for _, cb in pairs(callbacks) do
    local ok, cb_err = pcall(cb, err, ...)
    if not ok then
      errs[#errs + 1] = tostring(errors.normalize(cb_err))
    end
  end

  if #errs > 0 then
    error(table.concat(errs, '\n'), 0)
  end
end

return function()
  return setmetatable({
    _callbacks = {},
    _callback_pos = 1,
  }, Future)
end
