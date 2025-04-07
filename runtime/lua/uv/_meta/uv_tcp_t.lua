---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- TCP handles are used to represent both TCP streams and servers.
---
---@class uv.uv_tcp_t : uv.uv_stream_t
local tcp = {} -- luacheck: no unused

--- Bind the handle to an host and port.
---
--- Any `flags` are set with a table with field `ipv6only` equal to `true` or `false`.
---
--- When the port is already taken, you can expect to see an `EADDRINUSE` error
--- from either `tcp:bind()`, `uv.listen()` or `tcp:connect()`. That is, a
--- successful call to this function does not guarantee that the call to `uv.listen()`
--- or `tcp:connect()` will succeed as well.
---
--- Use a port of `0` to let the OS assign an ephemeral port.  You can look it up
--- later using `tcp:getsockname()`.
---
---@param  addr       string            # must be an IP address and not a hostname
---@param  port       integer           # set to `0` to allow the OS to assign an ephemeral port
---@param  flags?     uv.tcp_bind.flags
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:bind(addr, port, flags) end

--- Resets a TCP connection by sending a RST packet. This is accomplished by setting
--- the SO_LINGER socket option with a linger interval of zero and then calling
--- `uv.close()`. Due to some platform inconsistencies, mixing of `uv.shutdown()`
--- and `tcp:close_reset()` calls is not allowed.
---
---@param  callback?  function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:close_reset(callback) end

--- Establish an IPv4 or IPv6 TCP connection.
---
--- ```lua
--- local client = uv.new_tcp()
--- client:connect("127.0.0.1", 8080, function (err)
---   -- check error and carry on.
--- end)
--- ```
---
---@param  host                string
---@param  port                integer
---@param  callback            uv.tcp_connect.callback
---@return uv.uv_connect_t|nil conn
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:connect(host, port, callback) end

--- Get the address of the peer connected to the handle.
---
---@return uv.socketinfo|nil peername
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:getpeername() end

--- Get the current address to which the handle is bound.
---
---@return uv.socketinfo|nil sockname
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:getsockname() end

--- Enable / disable TCP keep-alive.
---
---@param  enable     boolean
---@param  delay?     integer # initial delay, in seconds
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:keepalive(enable, delay) end

--- Enable / disable Nagle's algorithm.
---
---@param  enable     boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:nodelay(enable) end

--- Open an existing file descriptor or SOCKET as a TCP handle.
---
--- **Note:** The passed file descriptor or SOCKET is not checked for its type, but it's required that it represents a valid stream socket.
---
---@param  sock       integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:open(sock) end

--- Enable / disable simultaneous asynchronous accept requests that are queued by
--- the operating system when listening for new TCP connections.
---
--- This setting is used to tune a TCP server for the desired performance. Having
--- simultaneous accepts can significantly improve the rate of accepting connections
--- (which is why it is enabled by default) but may lead to uneven load distribution
--- in multi-process setups.
---
---@param  enable     boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function tcp:simultaneous_accepts(enable) end

--- **Deprecated:** Please use `uv.stream_get_write_queue_size()` instead.
function tcp:write_queue_size() end
