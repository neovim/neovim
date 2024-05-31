---@meta

--- Process handles will spawn a new process and allow the user to control it and
--- establish communication channels with it using streams.
---
---@class uv.uv_process_t : uv.uv_handle_t
local process

--- Returns the handle's pid.
---
---@return integer pid
function process:get_pid() end

--- Sends the specified signal to the given process handle.
---
--- Check the documentation on `uv_signal_t` for signal support, specially on Windows.
---
---@param  signum     integer|string
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function process:kill(signum) end