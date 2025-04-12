---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- luv_thread_t
---
---@class uv.luv_thread_t : userdata
local thread = {} -- luacheck: no unused

--- Returns a boolean indicating whether two threads are the same. This function is
--- equivalent to the `__eq` metamethod.
---
---@param other_thread uv.luv_thread_t
---@return boolean
function thread:equal(other_thread) end

--- Waits for the `thread` to finish executing its entry function.
---
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function thread:join() end
