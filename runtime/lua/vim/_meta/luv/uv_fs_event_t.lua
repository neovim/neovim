---@meta

--- FS Event handles allow the user to monitor a given path for changes, for
--- example, if the file was renamed or there was a generic change in it. This
--- handle uses the best backend for the job on each platform.
---
---@class uv.uv_fs_event_t : uv.uv_handle_t
local fs_event

--- Get the path being monitored by the handle.
---
---@return string|nil path
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function fs_event:getpath() end

--- Start the handle with the given callback, which will watch the specified path
--- for changes.
---
---@param  path       string
---@param  flags      uv.fs_event_start.flags
---@param  callback   uv.fs_event_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function fs_event:start(path, flags, callback) end

--- Stop the handle, the callback will no longer be called.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function fs_event:stop() end