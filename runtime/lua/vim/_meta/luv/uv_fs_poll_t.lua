---@meta

--- FS Poll handles allow the user to monitor a given path for changes. Unlike
--- `uv_fs_event_t`, fs poll handles use `stat` to detect when a file has changed so
--- they can work on file systems where fs event handles can't.
---
---@class uv.uv_fs_poll_t : uv.uv_handle_t
local fs_poll

--- Get the path being monitored by the handle.
---
---@return string|nil path
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function fs_poll:getpath() end

--- Check the file at `path` for changes every `interval` milliseconds.
---
--- **Note:** For maximum portability, use multi-second intervals. Sub-second
--- intervals will not detect all changes on many file systems.
---
---@param  path       string
---@param  interval   integer
---@param  callback   uv.fs_poll_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function fs_poll:start(path, interval, callback) end

--- Stop the handle, the callback will no longer be called.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function fs_poll:stop() end