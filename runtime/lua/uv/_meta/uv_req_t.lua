---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Base request
---
--- `uv_req_t` is the base type for all libuv request types.
---
---@class uv.uv_req_t : table
---
local req = {} -- luacheck: no unused

--- Cancel a pending request. Fails if the request is executing or has finished
--- executing. Only cancellation of `uv_fs_t`, `uv_getaddrinfo_t`,
--- `uv_getnameinfo_t` and `uv_work_t` requests is currently supported.
---
---@return 0|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function req:cancel() end

--- Returns the name of the struct for a given request (e.g. `"fs"` for `uv_fs_t`)
--- and the libuv enum integer for the request's type (`uv_req_type`).
---
---@return string type
---@return integer enum
function req:get_type() end
