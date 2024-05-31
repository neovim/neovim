---@meta

--- Timer handles are used to schedule callbacks to be called in the future.
---
---@class uv.uv_timer_t : uv.uv_handle_t
local timer

--- Stop the timer, and if it is repeating restart it using the repeat value as the
--- timeout. If the timer has never been started before it raises `EINVAL`.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function timer:again() end

--- Get the timer due value or 0 if it has expired. The time is relative to `uv.now()`.
---
--- **Note**: New in libuv version 1.40.0.
---
---@return integer
function timer:get_due_in() end

--- Get the timer repeat value.
---
---@return integer
function timer:get_repeat() end

--- Set the repeat interval value in milliseconds. The timer will be scheduled to
--- run on the given interval, regardless of the callback execution duration, and
--- will follow normal timer semantics in the case of a time-slice overrun.
---
--- For example, if a 50 ms repeating timer first runs for 17 ms, it will be
--- scheduled to run again 33 ms later. If other tasks consume more than the 33 ms
--- following the first timer callback, then the callback will run as soon as
--- possible.
---
---@param repeat_ integer
function timer:set_repeat(repeat_) end

--- Start the timer. `timeout` and `repeat_` are in milliseconds.
---
---@param  timeout    integer # Timeout, in milliseconds. If timeout is zero, the callback fires on the next event loop iteration.
---@param  repeat_    integer # Repeat interval, in milliseconds. If non-zero, the callback fires after `timeout` milliseconds and then repeatedly after `repeat_` milliseconds.
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function timer:start(timeout, repeat_, callback) end

--- Stop the timer, the callback will not be called anymore.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function timer:stop() end