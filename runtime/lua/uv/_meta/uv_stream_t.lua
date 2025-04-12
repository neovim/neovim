---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Stream handles provide an abstraction of a duplex communication channel.
--- `uv_stream_t` is an abstract type, libuv provides 3 stream implementations
--- in the form of `uv_tcp_t`, `uv_pipe_t` and `uv_tty_t`.
---
---@class uv.uv_stream_t : uv.uv_handle_t
---
local stream = {} -- luacheck: no unused

--- This call is used in conjunction with `uv.listen()` to accept incoming
--- connections. Call this function after receiving a callback to accept the
--- connection.
---
--- When the connection callback is called it is guaranteed that this function
--- will complete successfully the first time. If you attempt to use it more than
--- once, it may fail. It is suggested to only call this function once per
--- connection call.
---
--- ```lua
--- server:listen(128, function (err)
---   local client = uv.new_tcp()
---   server:accept(client)
--- end)
--- ```
---
---@param  client_stream uv.uv_stream_t
---@return 0|nil         success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:accept(client_stream) end

--- Returns the stream's write queue size.
---
---@return integer size
function stream:get_write_queue_size() end

--- Returns `true` if the stream is readable, `false` otherwise.
---
---@return boolean readable
function stream:is_readable() end

--- Returns `true` if the stream is writable, `false` otherwise.
---
---@return boolean writable
function stream:is_writable() end

--- Start listening for incoming connections.
---
--- `backlog` indicates the number of connections the kernel might queue, same as `listen(2)`.
---
--- When a new incoming connection is received the callback is called.
---
---@param  backlog    integer
---@param  callback   uv.listen.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:listen(backlog, callback) end

--- Read data from an incoming stream.
---
--- The callback will be made several times until there is no more data to read or `stream:read_stop()` is called.
---
--- When we've reached EOF, `data` will be `nil`.
---
--- ```lua
--- stream:read_start(function (err, chunk)
---   if err then
---     -- handle read error
---   elseif chunk then
---     -- handle data
---   else
---     -- handle disconnect
---   end
--- end)
--- ```
---
---@param  callback   uv.read_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:read_start(callback) end

--- Stop reading data from the stream.
---
--- The read callback will no longer be called.
---
--- This function is idempotent and may be safely called on a stopped stream.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:read_stop() end

--- Enable or disable blocking mode for a stream.
---
--- When blocking mode is enabled all writes complete synchronously. The interface
--- remains unchanged otherwise, e.g. completion or failure of the operation will
--- still be reported through a callback which is made asynchronously.
---
--- **Warning**: Relying too much on this API is not recommended. It is likely to
--- change significantly in the future. Currently this only works on Windows and
--- only for `uv_pipe_t` handles. Also libuv currently makes no ordering guarantee
--- when the blocking mode is changed after write requests have already been
--- submitted. Therefore it is recommended to set the blocking mode immediately
--- after opening or creating the stream.
---
---@param  blocking   boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:set_blocking(blocking) end

--- Shutdown the outgoing (write) side of a duplex stream. It waits for pending
--- write requests to complete. The callback is called after shutdown is complete.
---
---@param  callback?            uv.shutdown.callback
---@return uv.uv_shutdown_t|nil shutdown
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:shutdown(callback) end

--- Same as `stream:write()`, but won't queue a write request if it can't be completed
--- immediately.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
---
---@param  data        uv.buffer
---@return integer|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:try_write(data) end

--- Like `stream:write2()`, but with the properties of `stream:try_write()`. Not supported on Windows, where it returns `UV_EAGAIN`.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
---
---@param  data        uv.buffer
---@param  send_handle uv.uv_stream_t
---@return integer|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:try_write2(data, send_handle) end

--- Write data to stream.
---
--- `data` can either be a Lua string or a table of strings. If a table is passed
--- in, the C backend will use writev to send all strings in a single system call.
---
--- The optional `callback` is for knowing when the write is complete.
---
---@param  data              uv.buffer
---@param  callback?         uv.write.callback
---@return uv.uv_write_t|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:write(data, callback) end

--- Extended write function for sending handles over a pipe. The pipe must be
--- initialized with `ipc` option `true`.
---
--- **Note:** `send_handle` must be a TCP socket or pipe, which is a server or a
--- connection (listening or connected state). Bound sockets or pipes will be
--- assumed to be servers.
---
---@param  data              uv.buffer
---@param  send_handle       uv.uv_stream_t
---@param  callback?         uv.write2.callback
---@return uv.uv_write_t|nil write
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function stream:write2(data, send_handle, callback) end
