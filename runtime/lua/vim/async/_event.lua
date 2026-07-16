-- LuaLS cannot model the generic annotations used by this vendored implementation.
---@diagnostic disable: no-unknown, undefined-doc-name, luadoc-miss-symbol, missing-return, missing-return-value, param-type-mismatch, return-type-mismatch, redundant-return-value, undefined-field, need-check-nil, await-in-sync

local async = require('vim.async._core')
local runtime = require('vim.async._runtime')

local Event = {}
Event.__index = Event

local function has_waiters(waiters)
  for _, waiter in ipairs(waiters) do
    if waiter then
      return true
    end
  end
  return false
end

function Event:set(max_woken)
  if self._is_set then
    return
  end

  local limited = max_woken ~= nil
  if not has_waiters(self._waiters) then
    self._is_set = true
    return
  end

  self._is_set = true
  if limited then
    -- The signal is reserved for existing waiters and will be assigned on the
    -- scheduled turn. New waiters must not consume it first.
    self._is_set = false
  end

  runtime.schedule(function()
    local waiters = self._waiters
    local waiters_to_notify = {}
    local limit = max_woken or math.huge
    while #waiters > 0 and #waiters_to_notify < limit do
      local waiter = table.remove(waiters, 1)
      if waiter then
        waiters_to_notify[#waiters_to_notify + 1] = waiter
      end
    end

    if limited and #waiters_to_notify == 0 and not has_waiters(waiters) then
      self._is_set = true
    end

    for _, waiter in ipairs(waiters_to_notify) do
      waiter()
    end
  end)
end

function Event:wait()
  async.await(function(callback)
    if self._is_set then
      callback()
    else
      table.insert(self._waiters, callback)
      return {
        close = function(_, on_close)
          -- set() compacts the waiter list, so cancellation cannot rely on the
          -- original insertion index still pointing at this callback.
          for i, waiter in ipairs(self._waiters) do
            if waiter == callback then
              self._waiters[i] = false
              break
            end
          end
          if on_close then
            on_close()
          end
        end,
      }
    end
  end)
end

function Event:clear()
  self._is_set = false
end

return function()
  return setmetatable({
    _waiters = {},
    _is_set = false,
  }, Event)
end
