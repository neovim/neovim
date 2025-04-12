---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- Base handle
---
--- `uv_handle_t` is the base type for all libuv handle types. All API functions
--- defined here work with any handle type.
---
---@class uv.uv_handle_t : table
---
local handle = {} -- luacheck: no unused

--- Request handle to be closed.
---
--- The `callback` will be called asynchronously after this call.
---
--- This MUST be called on each handle before memory is released.
---
--- Handles that wrap file descriptors are closed immediately but `callback` will
--- still be deferred to the next iteration of the event loop. It gives you a chance
--- to free up any resources associated with the handle.
---
--- In-progress requests, like `uv_connect_t` or `uv_write_t`, are cancelled and
--- have their callbacks called asynchronously with `ECANCELED`.
---
---@param callback? function
function handle:close(callback) end

--- Gets the platform dependent file descriptor equivalent.
---
--- The following handles are supported: TCP, pipes, TTY, UDP and poll. Calling
--- this method on other handle type will fail with `EINVAL`.
---
--- If a handle doesn't have an attached file descriptor yet or the handle itself
--- has been closed, this function will return `EBADF`.
---
--- **Warning**: Be very careful when using this function. libuv assumes it's in
--- control of the file descriptor so any change to it may lead to malfunction.
---
---@return integer|nil fileno
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function handle:fileno() end

--- Returns the name of the struct for a given handle (e.g. `"pipe"` for `uv_pipe_t`)
--- and the libuv enum integer for the handle's type (`uv_handle_type`).
---
---@return string type
---@return integer enum
function handle:get_type() end

--- Returns `true` if the handle referenced, `false` if not.
---
---@return boolean|nil has_ref
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function handle:has_ref() end

--- Returns `true` if the handle is active, `false` if it's inactive.
---
--- What "active” means depends on the type of handle:
---
--- - A `uv_async_t` handle is always active and cannot be deactivated, except by closing it with `uv.close()`.
---
--- - A `uv_pipe_t`, `uv_tcp_t`, `uv_udp_t`, etc. handle - basically any handle that deals with I/O - is active when it is doing something that involves I/O, like reading, writing, connecting, accepting new connections, etc.
---
--- - A `uv_check_t`, `uv_idle_t`, `uv_timer_t`, etc. handle is active when it has been started with a call to `uv.check_start()`, `uv.idle_start()`, `uv.timer_start()` etc. until it has been stopped with a call to its respective stop function.
---
---@return boolean|nil active
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function handle:is_active() end

--- Returns `true` if the handle is closing or closed, `false` otherwise.
---
--- **Note**: This function should only be used between the initialization of the
--- handle and the arrival of the close callback.
---
---@return boolean|nil closing
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function handle:is_closing() end

--- Gets or sets the size of the receive buffer that the operating system uses for
--- the socket.
---
--- If `size` is omitted (or `0`), this will return the current send buffer size; otherwise, this will use `size` to set the new send buffer size.
---
--- This function works for TCP, pipe and UDP handles on Unix and for TCP and UDP
--- handles on Windows.
---
--- **Note**: Linux will set double the size and return double the size of the
--- original set value.
---
---@param  size       integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(self):(current_size:integer|nil, err:uv.error.message|nil, err_name:uv.error.name|nil)
---@overload fun(self, size: 0):(current_size:integer|nil, err:uv.error.message|nil, err_name:uv.error.name|nil)
function handle:recv_buffer_size(size) end

--- Reference the given handle.
---
--- References are idempotent, that is, if a handle is already referenced calling this function again will have no effect.
function handle:ref() end

--- Gets or sets the size of the send buffer that the operating system uses for the
--- socket.
---
--- If `size` is omitted (or `0`), this will return the current send buffer size; otherwise, this will use `size` to set the new send buffer size.
---
--- This function works for TCP, pipe and UDP handles on Unix and for TCP and UDP
--- handles on Windows.
---
--- **Note**: Linux will set double the size and return double the size of the
--- original set value.
---
---@param  size        integer
---@return integer|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(self):(current_size:integer|nil, err:uv.error.message|nil, err_name:uv.error.name|nil)
---@overload fun(self, size: 0):(current_size:integer|nil, err:uv.error.message|nil, err_name:uv.error.name|nil)
function handle:send_buffer_size(size) end

--- Un-reference the given handle. References are idempotent, that is, if a handle
--- is not referenced calling this function again will have no effect.
function handle:unref() end
