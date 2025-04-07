---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- luv_dir_t
---
---@class uv.luv_dir_t : userdata
local dir = {} -- luacheck: no unused

--- Closes a directory stream returned by a successful `uv.fs_opendir()` call.
---
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(self:uv.luv_dir_t, callback:uv.fs_closedir.callback):uv.uv_fs_t
function dir:closedir() end

--- Iterates over the directory stream `luv_dir_t` returned by a successful
--- `uv.fs_opendir()` call. A table of data tables is returned where the number
--- of entries `n` is equal to or less than the `entries` parameter used in
--- the associated `uv.fs_opendir()` call.
---
--- **Returns (sync version):** `table` or `fail`
--- - `[1, 2, 3, ..., n]` : `table`
---   - `name` : `string`
---   - `type` : `string`
---
--- **Returns (async version):** `uv_fs_t userdata`
---
---@return uv.fs_readdir.entry[]|nil entries
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(self:uv.luv_dir_t, callback:uv.fs_readdir.callback):uv.uv_fs_t
function dir:readdir() end
