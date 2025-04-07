---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Prepare handles will run the given callback once per loop iteration, right
--- before polling for I/O.
---
--- ```lua
--- local prepare = uv.new_prepare()
--- prepare:start(function()
---   print("Before I/O polling")
--- end)
--- ```
---
---@class uv.uv_prepare_t : uv.uv_handle_t
---
local prepare = {} -- luacheck: no unused

--- Start the handle with the given callback.
---
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function prepare:start(callback) end

--- Stop the handle, the callback will no longer be called.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function prepare:stop() end
