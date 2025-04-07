---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Idle handles will run the given callback once per loop iteration, right before
--- the `uv_prepare_t` handles.
---
--- **Note**: The notable difference with prepare handles is that when there are
--- active idle handles, the loop will perform a zero timeout poll instead of
--- blocking for I/O.
---
--- **Warning**: Despite the name, idle handles will get their callbacks called on
--- every loop iteration, not when the loop is actually "idle".
---
--- ```lua
--- local idle = uv.new_idle()
--- idle:start(function()
---   print("Before I/O polling, no blocking")
--- end)
--- ```
---
---@class uv.uv_idle_t : uv.uv_handle_t
---
local idle = {} -- luacheck: no unused

--- Start the handle with the given callback.
---
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function idle:start(callback) end

--- Stop the handle, the callback will no longer be called.
---
---@param  check      any
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function idle:stop(check) end
