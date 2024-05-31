---@meta

--- Check handles will run the given callback once per loop iteration, right after
--- polling for I/O.
---
--- ```lua
--- local check = uv.new_check()
--- check:start(function()
---   print("After I/O polling")
--- end)
--- ```
---
---@class uv.uv_check_t : uv.uv_handle_t
local check

--- Start the handle with the given callback.
---
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function check:start(callback) end

--- Stop the handle, the callback will no longer be called.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function check:stop() end