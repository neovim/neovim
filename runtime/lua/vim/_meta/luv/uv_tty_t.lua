---@meta

--- TTY handles represent a stream for the console.
---
--- ```lua
--- -- Simple echo program
--- local stdin = uv.new_tty(0, true)
--- local stdout = uv.new_tty(1, false)
---
--- stdin:read_start(function (err, data)
---   assert(not err, err)
---   if data then
---     stdout:write(data)
---   else
---     stdin:close()
---     stdout:close()
---   end
--- end)
--- ```
---
---@class uv.uv_tty_t : uv.uv_stream_t
local tty

--- Gets the current Window width and height.
---
---@return integer|nil    width
---@return integer|uv.error.message height_or_err
---@return uv.error.name|nil err_name
function tty:get_winsize() end

--- Set the TTY using the specified terminal mode.
---
--- Parameter `mode` is a C enum with the following values:
---
---   - 0 - UV_TTY_MODE_NORMAL: Initial/normal terminal mode
---   - 1 - UV_TTY_MODE_RAW: Raw input mode (On Windows, ENABLE_WINDOW_INPUT is
---   also enabled)
---   - 2 - UV_TTY_MODE_IO: Binary-safe I/O mode for IPC (Unix-only)
---
---@param  mode       uv.tty.mode
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tty:set_mode(mode) end