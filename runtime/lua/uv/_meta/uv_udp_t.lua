---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- UDP handles encapsulate UDP communication for both clients and servers.
---
---@class uv.uv_udp_t : uv.uv_handle_t
local udp = {} -- luacheck: no unused

--- Bind the UDP handle to an IP address and port. Any `flags` are set with a table
--- with fields `reuseaddr` or `ipv6only` equal to `true` or `false`.
---
---@param  host       string
---@param  port       integer
---@param  flags?     uv.udp_bind.flags
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:bind(host, port, flags) end

--- Associate the UDP handle to a remote address and port, so every message sent by
--- this handle is automatically sent to that destination.
--
--- Calling this function with a NULL addr disconnects the handle. Trying to call `udp:connect()` on an already connected handle will result in an `EISCONN` error. Trying to disconnect a handle that is not connected will return an `ENOTCONN` error.
---
---@param  host       string
---@param  port       integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:connect(host, port) end

--- Returns the handle's send queue count.
---
---@return integer count
function udp:get_send_queue_count() end

--- Returns the handle's send queue size.
---
---@return integer size
function udp:get_send_queue_size() end

--- Get the remote IP and port of the UDP handle on connected UDP handles.
---
---@return uv.udp.sockname|nil peername
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:getpeername() end

--- Get the local IP and port of the UDP handle.
---
---@return uv.udp.sockname|nil sockname
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:getsockname() end

--- Opens an existing file descriptor or Windows SOCKET as a UDP handle.
---
--- Unix only: The only requirement of the sock argument is that it follows the
--- datagram contract (works in unconnected mode, supports sendmsg()/recvmsg(),
--- etc). In other words, other datagram-type sockets like raw sockets or netlink
--- sockets can also be passed to this function.
---
--- The file descriptor is set to non-blocking mode.
---
--- Note: The passed file descriptor or SOCKET is not checked for its type, but
--- it's required that it represents a valid datagram socket.
---
---@param  fd         integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:open(fd) end

--- Prepare for receiving data.
---
--- If the socket has not previously been bound with `udp:bind()` it is bound to `0.0.0.0` (the "all interfaces" IPv4 address) and a random port number.
---
---@param  callback   uv.udp_recv_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:recv_start(callback) end

--- Stop listening for incoming datagrams.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:recv_stop() end

--- Send data over the UDP socket.
---
--- If the socket has not previously been bound with `udp:bind()` it will be bound to `0.0.0.0` (the "all interfaces" IPv4 address) and a random port number.
---
---@param  data                 uv.buffer
---@param  host                 string
---@param  port                 integer
---@param  callback             uv.udp_send.callback
---@return uv.uv_udp_send_t|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:send(data, host, port, callback) end

--- Set broadcast on or off.
---
---@param  on         boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:set_broadcast(on) end

--- Set membership for a multicast address.
---
---@param  multicast_addr string          # multicast address to set membership for
---@param  interface_addr string          # interface address
---@param  membership     "leave"|"join"  # membership intent
---@return 0|nil          success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:set_membership(multicast_addr, interface_addr, membership) end

--- Set the multicast interface to send or receive data on.
---
---@param interface_addr string
---@return 0|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:set_multicast_interface(interface_addr) end

--- Set IP multicast loop flag. Makes multicast packets loop back to local
--- sockets.
---
---@param on boolean
---@return 0|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:set_multicast_loop(on) end

--- Set the multicast ttl.
---
---@param  ttl        integer # an integer 1 through 255
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:set_multicast_ttl(ttl) end

--- Set membership for a source-specific multicast group.
---
---@param  multicast_addr  string         # multicast address to set membership for
---@param  interface_addr? string         # interface address
---@param  source_addr     string         # source address
---@param  membership      "leave"|"join" # membership intent
---@return 0|nil           success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:set_source_membership(multicast_addr, interface_addr, source_addr, membership) end

--- Set the time to live.
---
---@param  ttl        integer # integer 1 through 255
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:set_ttl(ttl) end

--- Same as `udp:send()`, but won't queue a send request if it can't be
--- completed immediately.
---
---@param  data        uv.buffer
---@param  host        string
---@param  port        integer
---@return integer|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function udp:try_send(data, host, port) end
