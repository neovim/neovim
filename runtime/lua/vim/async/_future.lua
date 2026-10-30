local F = vim.F
local util = require('vim._core.util')
local runtime = require('vim.async._runtime')

--- Future objects are used to bridge low-level callback-based code with
--- high-level async/await code.
--- @class (internal) vim.async.Future<R>
--- @field private _callbacks table<integer, fun(err?: any, ...: R...)>
--- @field private _callback_pos integer
--- Error result of the task is an error occurs.
--- Must use `await` to get the result.
--- @field package _err? any
---
--- Result of the task.
--- Must use `await` to get the result.
--- @field private _result? R[] & { n: integer }
local Future = {}
Future.__index = Future

--- Return `true` if the Future is completed.
--- @return boolean
function Future:completed()
  return self._err ~= nil or self._result ~= nil
end

--- Return the result of the Future.
---
--- If the Future is done and has a result set by the `complete()` method, the
--- result is returned.
---
--- If the Future’s result isn’t yet available, this method raises a
--- "Future has not completed" error.
--- @return boolean stat true if the Future completed successfully, false otherwise.
--- @return any ... error or result
function Future:result()
  if not self:completed() then
    error('Future has not completed', 2)
  end
  if self._err ~= nil then
    return false, self._err
  else
    assert(self._result)
    return true, F.unpack_len(self._result)
  end
end

--- Invoke an observer without letting its error escape through completion.
--- @private
--- @param callback fun(err?: any, ...: R...)
function Future:_invoke(callback)
  local ok, traceback = xpcall(function()
    if self._err ~= nil then
      callback(self._err)
    else
      assert(self._result)
      callback(nil, F.unpack_len(self._result))
    end
  end, function(err)
    return debug.traceback(util._stringify_error(util._normalize_error(err)), 2)
  end)
  if not ok then
    runtime.schedule(function()
      error(traceback, 0)
    end)
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
--- Callback errors are reported through the runtime scheduler with their
--- traceback. Other observers still run and the Future's result is unchanged.
--- @param callback fun(err?: any, ...: R...)
--- @return fun() unsubscribe
function Future:on_complete(callback)
  if self:completed() then
    -- Already completed or closed
    self:_invoke(callback)
    return function() end
  end

  local id = self._callback_pos
  self._callback_pos = id + 1
  self._callbacks[id] = callback

  return function()
    self._callbacks[id] = nil
  end
end

--- Mark the Future as complete and set its result.
---
--- If an error is provided, the Future is marked as failed. Otherwise, it is
--- marked as successful with the provided result.
---
--- A Future can only be completed once.
---
--- This will trigger any callbacks that are waiting on the Future.
--- @param err? any
--- @param ... R... result
function Future:complete(err, ...)
  if self:completed() then
    error('Future is already completed', 2)
  end

  if err ~= nil then
    self._err = err
  else
    self._result = F.pack_len(...)
  end

  local callbacks = self._callbacks
  self._callbacks = {}

  -- Need to use pairs to avoid gaps caused by removed callbacks
  for _, cb in pairs(callbacks) do
    self:_invoke(cb)
  end
end

--- Create a new future.
---
--- A Future is a low-level awaitable that is not intended to be used in
--- application-level code.
--- @return vim.async.Future<any>
return function()
  return setmetatable({
    _callbacks = {},
    _callback_pos = 1,
  }, Future)
end
