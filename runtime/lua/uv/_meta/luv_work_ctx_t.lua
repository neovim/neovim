---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- luv_work_ctx_t
---
---@class uv.luv_work_ctx_t : userdata
local work_ctx = {} -- luacheck: no unused

--- Queues a work request which will run `work_callback` in a new Lua state in a
--- thread from the threadpool with any additional arguments from `...`. Values
--- returned from `work_callback` are passed to `after_work_callback`, which is
--- called in the main loop thread.
---
---@param  ...         uv.threadargs
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function work_ctx:queue(...) end
