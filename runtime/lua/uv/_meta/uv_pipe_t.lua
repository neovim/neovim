---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Pipe handles provide an abstraction over local domain sockets on Unix and named pipes on Windows.
---
--- ```lua
--- local pipe = uv.new_pipe(false)
---
--- pipe:bind('/tmp/sock.test')
---
--- pipe:listen(128, function()
---   local client = uv.new_pipe(false)
---   pipe:accept(client)
---   client:write("hello!\n")
---   client:close()
--- end)
--- ```
---
---@class uv.uv_pipe_t : uv.uv_stream_t
---
local pipe = {} -- luacheck: no unused

--- Bind the pipe to a file path (Unix) or a name (Windows).
---
--- **Note**: Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
---
---@param  name       string
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function pipe:bind(name) end

--- Alters pipe permissions, allowing it to be accessed from processes run by different users.
---
--- Makes the pipe writable or readable by all users. `flags` are: `"r"`, `"w"`, `"rw"`, or `"wr"`
--- where `r` is `READABLE` and `w` is `WRITABLE`.
---
--- This function is blocking.
---
---@param  flags      uv.pipe_chmod.flags
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function pipe:chmod(flags) end

--- Connect to the Unix domain socket or the named pipe.
---
--- **Note**: Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
---
---@param  name                string
---@param  callback?           uv.pipe_connect.callback
---@return uv.uv_connect_t|nil conn
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function pipe:connect(name, callback) end

--- Get the name of the Unix domain socket or the named pipe to which the handle is
--- connected.
---
---@return string|nil peername
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function pipe:getpeername() end

--- Get the name of the Unix domain socket or the named pipe.
---
---@return string|nil sockname
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function pipe:getsockname() end

--- Open an existing file descriptor or `uv_handle_t` as a pipe.
---
--- **Note**: The file descriptor is set to non-blocking mode.
---
---@param  fd         integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function pipe:open(fd) end

--- Returns the pending pipe count for the named pipe.
---
---@return integer count
function pipe:pending_count() end

--- Set the number of pending pipe instance handles when the pipe server is waiting
--- for connections.
---
--- **Note**: This setting applies to Windows only.
---
---@param count integer
function pipe:pending_instances(count) end

--- Used to receive handles over IPC pipes.
---
--- First - call `uv.pipe_pending_count()`, if it's > 0 then initialize a handle of
--- the given type, returned by `uv.pipe_pending_type()` and call
--- `uv.accept(pipe, handle)`.
---
---@return string
function pipe:pending_type() end
