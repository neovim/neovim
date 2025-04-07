---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Poll handles are used to watch file descriptors for readability and writability,
--- similar to the purpose of [poll(2)](http://linux.die.net/man/2/poll).
---
--- The purpose of poll handles is to enable integrating external libraries that
--- rely on the event loop to signal it about the socket status changes, like c-ares
--- or libssh2. Using `uv_poll_t` for any other purpose is not recommended;
--- `uv_tcp_t`, `uv_udp_t`, etc. provide an implementation that is faster and more
--- scalable than what can be achieved with `uv_poll_t`, especially on Windows.
---
--- It is possible that poll handles occasionally signal that a file descriptor is
--- readable or writable even when it isn't. The user should therefore always be
--- prepared to handle EAGAIN or equivalent when it attempts to read from or write
--- to the fd.
---
--- It is not okay to have multiple active poll handles for the same socket, this
--- can cause libuv to busyloop or otherwise malfunction.
---
--- The user should not close a file descriptor while it is being polled by an
--- active poll handle. This can cause the handle to report an error, but it might
--- also start polling another socket. However the fd can be safely closed
--- immediately after a call to `poll:stop()` or `uv.close()`.
---
--- **Note**: On windows only sockets can be polled with poll handles. On Unix any
--- file descriptor that would be accepted by poll(2) can be used.
---
---@class uv.uv_poll_t : uv.uv_handle_t
local poll = {} -- luacheck: no unused

--- Starts polling the file descriptor.
---
--- `events` are: `"r"`, `"w"`, `"rw"`, `"d"`, `"rd"`, `"wd"`, `"rwd"`, `"p"`, `"rp"`, `"wp"`, `"rwp"`, `"dp"`, `"rdp"`, `"wdp"`, or `"rwdp"` where `r` is `READABLE`, `w` is `WRITABLE`, `d` is `DISCONNECT`, and `p` is `PRIORITIZED`.
---
--- As soon as an event is detected the callback will be called with status set to 0, and the detected events set on the events field.
---
--- The user should not close the socket while the handle is active. If the user
--- does that anyway, the callback may be called reporting an error status, but this
--- is not guaranteed.
---
--- **Note** Calling `poll:start()` on a handle that is already active is fine.
--- Doing so will update the events mask that is being watched for.
---
---@param  events     uv.poll.eventspec
---@param  callback   uv.poll_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function poll:start(events, callback) end

--- Stop polling the file descriptor, the callback will no longer be called.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function poll:stop() end
