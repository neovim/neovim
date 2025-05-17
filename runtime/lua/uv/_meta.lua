--- @meta
--- @class uv
local uv = {}
uv.constants = {}

--- # LibUV in Lua
---
--- The [luv][] project provides access to the multi-platform support library
--- [libuv][] in Lua code. It was primarily developed for the [luvit][] project as
--- the built-in `uv` module, but can be used in other Lua environments.
---
--- More information about the core libuv library can be found at the original
--- [libuv documentation page][].


--- # TCP Echo Server Example
---
--- Here is a small example showing a TCP echo server:
---
--- ```lua
--- local uv = require("luv") -- "luv" when stand-alone, "uv" in luvi apps
---
--- local server = uv.new_tcp()
--- server:bind("127.0.0.1", 1337)
--- server:listen(128, function (err)
---   assert(not err, err)
---   local client = uv.new_tcp()
---   server:accept(client)
---   client:read_start(function (err, chunk)
---     assert(not err, err)
---     if chunk then
---       client:write(chunk)
---     else
---       client:shutdown()
---       client:close()
---     end
---   end)
--- end)
--- print("TCP server listening at 127.0.0.1 port 1337")
--- uv.run() -- an explicit run call is necessary outside of luvit
--- ```

--- # Module Layout
---
--- The luv library contains a single Lua module referred to hereafter as `uv` for
--- simplicity. This module consists mostly of functions with names corresponding to
--- their original libuv versions. For example, the libuv function `uv_tcp_bind` has
--- a luv version at `uv.tcp_bind`. Currently, only two non-function fields exists:
--- `uv.constants` and `uv.errno`, which are tables.

--- # Functions vs Methods
---
--- In addition to having simple functions, luv provides an optional method-style
--- API. For example, `uv.tcp_bind(server, host, port)` can alternatively be called
--- as `server:bind(host, port)`. Note that the first argument `server` becomes the
--- object and `tcp_` is removed from the function name. Method forms are
--- documented below where they exist.

--- # Synchronous vs Asynchronous Functions
---
--- Functions that accept a callback are asynchronous. These functions may
--- immediately return results to the caller to indicate their initial status, but
--- their final execution is deferred until at least the next libuv loop iteration.
--- After completion, their callbacks are executed with any results passed to it.
---
--- Functions that do not accept a callback are synchronous. These functions
--- immediately return their results to the caller.
---
--- Some (generally FS and DNS) functions can behave either synchronously or
--- asynchronously. If a callback is provided to these functions, they behave
--- asynchronously; if no callback is provided, they behave synchronously.

--- # Pseudo-Types
---
--- Some unique types are defined. These are not actual types in Lua, but they are
--- used here to facilitate documenting consistent behavior:
--- - `fail`: an assertable `nil, string, string` tuple (see [Error Handling][])
--- - `callable`: a `function`; or a `table` or `userdata` with a `__call`
---   metamethod
--- - `buffer`: a `string` or a sequential `table` of `string`s
--- - `threadargs`: variable arguments (`...`) of type `nil`, `boolean`, `number`,
---   `string`, or `userdata`, numbers of argument limited to 9.


--- # Contents
---
--- This documentation is mostly a retelling of the [libuv API documentation][]
--- within the context of luv's Lua API. Low-level implementation details and
--- unexposed C functions and types are not documented here except for when they
--- are relevant to behavior seen in the Lua module.
---
--- - [Constants][]
--- - [Error Handling][]
--- - [Version Checking][]
--- - [`uv_loop_t`][] — Event loop
--- - [`uv_req_t`][] — Base request
--- - [`uv_handle_t`][] — Base handle
---   - [`uv_timer_t`][] — Timer handle
---   - [`uv_prepare_t`][] — Prepare handle
---   - [`uv_check_t`][] — Check handle
---   - [`uv_idle_t`][] — Idle handle
---   - [`uv_async_t`][] — Async handle
---   - [`uv_poll_t`][] — Poll handle
---   - [`uv_signal_t`][] — Signal handle
---   - [`uv_process_t`][] — Process handle
---   - [`uv_stream_t`][] — Stream handle
---     - [`uv_tcp_t`][] — TCP handle
---     - [`uv_pipe_t`][] — Pipe handle
---     - [`uv_tty_t`][] — TTY handle
---   - [`uv_udp_t`][] — UDP handle
---   - [`uv_fs_event_t`][] — FS Event handle
---   - [`uv_fs_poll_t`][] — FS Poll handle
--- - [File system operations][]
--- - [Thread pool work scheduling][]
--- - [DNS utility functions][]
--- - [Threading and synchronization utilities][]
--- - [Miscellaneous utilities][]
--- - [Metrics operations][]

--- # Constants
---
--- As a Lua library, luv supports and encourages the use of lowercase strings to
--- represent options. For example:
--- ```lua
--- -- signal start with string input
--- uv.signal_start("sigterm", function(signame)
---   print(signame) -- string output: "sigterm"
--- end)
--- ```
---
--- However, luv also superficially exposes libuv constants in a Lua table at
--- `uv.constants` where its keys are uppercase constant names and their associated
--- values are integers defined internally by libuv. The values from this table may
--- be supported as function arguments, but their use may not change the output
--- type. For example:
---
--- ```lua
--- -- signal start with integer input
--- uv.signal_start(uv.constants.SIGTERM, function(signame)
---   print(signame) -- string output: "sigterm"
--- end)
--- ```
---
--- The uppercase constants defined in `uv.constants` that have associated
--- lowercase option strings are listed below.

--- # Address Families
uv.constants.AF_UNIX = 'unix'
uv.constants.AF_INET = 'inet'
uv.constants.AF_INET6 = 'inet6'
uv.constants.AF_IPX = 'ipx'
uv.constants.AF_NETLINK = 'netlink'
uv.constants.AF_X25 = 'x25'
uv.constants.AF_AX25 = 'as25'
uv.constants.AF_ATMPVC = 'atmpvc'
uv.constants.AF_APPLETALK = 'appletalk'
uv.constants.AF_PACKET = 'packet'

--- # Signals
uv.constants.SIGHUP = 'sighup'
uv.constants.SIGINT = 'sigint'
uv.constants.SIGQUIT = 'sigquit'
uv.constants.SIGILL = 'sigill'
uv.constants.SIGTRAP = 'sigtrap'
uv.constants.SIGABRT = 'sigabrt'
uv.constants.SIGIOT = 'sigiot'
uv.constants.SIGBUS = 'sigbus'
uv.constants.SIGFPE = 'sigfpe'
uv.constants.SIGKILL = 'sigkill'
uv.constants.SIGUSR1 = 'sigusr1'
uv.constants.SIGSEGV = 'sigsegv'
uv.constants.SIGUSR2 = 'sigusr2'
uv.constants.SIGPIPE = 'sigpipe'
uv.constants.SIGALRM = 'sigalrm'
uv.constants.SIGTERM = 'sigterm'
uv.constants.SIGCHLD = 'sigchld'
uv.constants.SIGSTKFLT = 'sigstkflt'
uv.constants.SIGCONT = 'sigcont'
uv.constants.SIGSTOP = 'sigstop'
uv.constants.SIGTSTP = 'sigtstp'
uv.constants.SIGBREAK = 'sigbreak'
uv.constants.SIGTTIN = 'sigttin'
uv.constants.SIGTTOU = 'sigttou'
uv.constants.SIGURG = 'sigurg'
uv.constants.SIGXCPU = 'sigxcpu'
uv.constants.SIGXFSZ = 'sigxfsz'
uv.constants.SIGVTALRM = 'sigvtalrm'
uv.constants.SIGPROF = 'sigprof'
uv.constants.SIGWINCH = 'sigwinch'
uv.constants.SIGIO = 'sigio'
uv.constants.SIGPOLL = 'sigpoll'
uv.constants.SIGLOST = 'siglost'
uv.constants.SIGPWR = 'sigpwr'
uv.constants.SIGSYS = 'sigsys'

--- # Socket Types
uv.constants.SOCK_STREAM = 'stream'
uv.constants.SOCK_DGRAM = 'dgram'
uv.constants.SOCK_SEQPACKET = 'seqpacket'
uv.constants.SOCK_RAW = 'raw'
uv.constants.SOCK_RDM = 'rdm'

--- # TTY Modes
uv.constants.TTY_MODE_NORMAL = 'normal'
uv.constants.TTY_MODE_RAW = 'raw'
uv.constants.TTY_MODE_IO = 'io'
uv.constants.TTY_MODE_RAW_VT = 'raw_vt'

--- # FS Modification Times
uv.constants.FS_UTIME_NOW = 'now'
uv.constants.FS_UTIME_OMIT = 'omit'


--- # Error Handling
---
--- In libuv, errors are represented by negative numbered constants. While these
--- constants are made available in the `uv.errno` table, they are not returned by
--- luv functions and the libuv functions used to handle them are not exposed.
--- Instead, if an internal error is encountered, the failing luv function will
--- return to the caller an assertable `nil, err, name` tuple:
---
--- - `nil` idiomatically indicates failure
--- - `err` is a string with the format `{name}: {message}`
---   - `{name}` is the error name provided internally by `uv_err_name`
---   - `{message}` is a human-readable message provided internally by `uv_strerror`
--- - `name` is the same string used to construct `err`
---
--- This tuple is referred to below as the `fail` pseudo-type.
---
--- When a function is called successfully, it will return either a value that is
--- relevant to the operation of the function, or the integer `0` to indicate
--- success, or sometimes nothing at all. These cases are documented below.
---
--- Below is a list of known error names and error strings. See libuv's
--- [error constants][] page for an original source.

--- @alias uv.error_name
--- | 'E2BIG' # argument list too long.
--- | 'EACCES' # permission denied.
--- | 'EADDRINUSE' # address already in use.
--- | 'EADDRNOTAVAIL' # address not available.
--- | 'EAFNOSUPPORT' # address family not supported.
--- | 'EAGAIN' # resource temporarily unavailable.
--- | 'EAI_ADDRFAMILY' # address family not supported.
--- | 'EAI_AGAIN' # temporary failure.
--- | 'EAI_BADFLAGS' # bad ai_flags value.
--- | 'EAI_BADHINTS' # invalid value for hints.
--- | 'EAI_CANCELED' # request canceled.
--- | 'EAI_FAIL' # permanent failure.
--- | 'EAI_FAMILY' # ai_family not supported.
--- | 'EAI_MEMORY' # out of memory.
--- | 'EAI_NODATA' # no address.
--- | 'EAI_NONAME' # unknown node or service.
--- | 'EAI_OVERFLOW' # argument buffer overflow.
--- | 'EAI_PROTOCOL' # resolved protocol is unknown.
--- | 'EAI_SERVICE' # service not available for socket type.
--- | 'EAI_SOCKTYPE' # socket type not supported.
--- | 'EALREADY' # connection already in progress.
--- | 'EBADF' # bad file descriptor.
--- | 'EBUSY' # resource busy or locked.
--- | 'ECANCELED' # operation canceled.
--- | 'ECHARSET' # invalid Unicode character.
--- | 'ECONNABORTED' # software caused connection abort.
--- | 'ECONNREFUSED' # connection refused.
--- | 'ECONNRESET' # connection reset by peer.
--- | 'EDESTADDRREQ' # destination address required.
--- | 'EEXIST' # file already exists.
--- | 'EFAULT' # bad address in system call argument.
--- | 'EFBIG' # file too large.
--- | 'EHOSTUNREACH' # host is unreachable.
--- | 'EINTR' # interrupted system call.
--- | 'EINVAL' # invalid argument.
--- | 'EIO' # i/o error.
--- | 'EISCONN' # socket is already connected.
--- | 'EISDIR' # illegal operation on a directory.
--- | 'ELOOP' # too many symbolic links encountered.
--- | 'EMFILE' # too many open files.
--- | 'EMSGSIZE' # message too long.
--- | 'ENAMETOOLONG' # name too long.
--- | 'ENETDOWN' # network is down.
--- | 'ENETUNREACH' # network is unreachable.
--- | 'ENFILE' # file table overflow.
--- | 'ENOBUFS' # no buffer space available.
--- | 'ENODEV' # no such device.
--- | 'ENOENT' # no such file or directory.
--- | 'ENOMEM' # not enough memory.
--- | 'ENONET' # machine is not on the network.
--- | 'ENOPROTOOPT' # protocol not available.
--- | 'ENOSPC' # no space left on device.
--- | 'ENOSYS' # function not implemented.
--- | 'ENOTCONN' # socket is not connected.
--- | 'ENOTDIR' # not a directory.
--- | 'ENOTEMPTY' # directory not empty.
--- | 'ENOTSOCK' # socket operation on non-socket.
--- | 'ENOTSUP' # operation not supported on socket.
--- | 'EOVERFLOW' # value too large for defined data type.
--- | 'EPERM' # operation not permitted.
--- | 'EPIPE' # broken pipe.
--- | 'EPROTO' # protocol error.
--- | 'EPROTONOSUPPORT' # protocol not supported.
--- | 'EPROTOTYPE' # protocol wrong type for socket.
--- | 'ERANGE' # result too large.
--- | 'EROFS' # read-only file system.
--- | 'ESHUTDOWN' # cannot send after transport endpoint shutdown.
--- | 'ESPIPE' # invalid seek.
--- | 'ESRCH' # no such process.
--- | 'ETIMEDOUT' # connection timed out.
--- | 'ETXTBSY' # text file is busy.
--- | 'EXDEV' # cross-device link not permitted.
--- | 'UNKNOWN' # unknown error.
--- | 'EOF' # end of file.
--- | 'ENXIO' # no such device or address.
--- | 'EMLINK' # too many links.
--- | 'ENOTTY' # inappropriate ioctl for device.
--- | 'EFTYPE' # inappropriate file type or format.
--- | 'EILSEQ' # illegal byte sequence.
--- | 'ESOCKTNOSUPPORT' # socket type not supported.

--- # Version Checking

--- Returns the libuv version packed into a single integer. 8 bits are used for each
--- component, with the patch number stored in the 8 least significant bits. For
--- example, this would be 0x010203 in libuv 1.2.3.
--- @return integer
function uv.version() end

--- Returns the libuv version number as a string. For example, this would be "1.2.3"
--- in libuv 1.2.3. For non-release versions, the version suffix is included.
--- @return string
function uv.version_string() end


--- # `uv_loop_t` - Event loop
---
--- The event loop is the central part of libuv's functionality. It takes care of
--- polling for I/O and scheduling callbacks to be run based on different sources of
--- events.
---
--- In luv, there is an implicit uv loop for every Lua state that loads the library.
--- You can use this library in an multi-threaded environment as long as each thread
--- has it's own Lua state with its corresponding own uv loop. This loop is not
--- directly exposed to users in the Lua module.

--- Closes all internal loop resources. In normal execution, the loop will
--- automatically be closed when it is garbage collected by Lua, so it is not
--- necessary to explicitly call `loop_close()`. Call this function only after the
--- loop has finished executing and all open handles and requests have been closed,
--- or it will return `EBUSY`.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.loop_close() end

--- This function runs the event loop. It will act differently depending on the
--- specified mode:
---
---   - `"default"`: Runs the event loop until there are no more active and
---   referenced handles or requests. Returns `true` if `uv.stop()` was called and
---   there are still active handles or requests. Returns `false` in all other
---   cases.
---
---   - `"once"`: Poll for I/O once. Note that this function blocks if there are no
---   pending callbacks. Returns `false` when done (no active handles or requests
---   left), or `true` if more callbacks are expected (meaning you should run the
---   event loop again sometime in the future).
---
---   - `"nowait"`: Poll for I/O once but don't block if there are no pending
---   callbacks. Returns `false` if done (no active handles or requests left),
---   or `true` if more callbacks are expected (meaning you should run the event
---   loop again sometime in the future).
--- **Note**:
--- Luvit will implicitly call `uv.run()` after loading user code, but if
--- you use the luv bindings directly, you need to call this after registering
--- your initial set of event callbacks to start the event loop.
--- @param mode string?
--- @return boolean? running
--- @return string? err
--- @return uv.error_name? err_name
function uv.run(mode) end

--- Set additional loop options. You should normally call this before the first call
--- to uv_run() unless mentioned otherwise.
---
--- Supported options:
---
---   - `"block_signal"`: Block a signal when polling for new events. The second argument
---   to loop_configure() is the signal name (as a lowercase string) or the signal number.
---   This operation is currently only implemented for `"sigprof"` signals, to suppress
---   unnecessary wakeups when using a sampling profiler. Requesting other signals will
---   fail with `EINVAL`.
---   - `"metrics_idle_time"`: Accumulate the amount of idle time the event loop spends
---   in the event provider. This option is necessary to use `metrics_idle_time()`.
---
--- An example of a valid call to this function is:
---
--- ```lua
--- uv.loop_configure("block_signal", "sigprof")
--- ```
--- **Note**:
--- Be prepared to handle the `ENOSYS` error; it means the loop option is
--- not supported by the platform.
--- @param option string
--- @param ... any depends on `option`
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.loop_configure(option, ...) end

--- If the loop is running, returns a string indicating the mode in use. If the loop
--- is not running, `nil` is returned instead.
--- @return string?
function uv.loop_mode() end

--- Returns `true` if there are referenced active handles, active requests, or
--- closing handles in the loop; otherwise, `false`.
--- @return boolean? alive
--- @return string? err
--- @return uv.error_name? err_name
function uv.loop_alive() end

--- Stop the event loop, causing `uv.run()` to end as soon as possible. This
--- will happen not sooner than the next loop iteration. If this function was called
--- before blocking for I/O, the loop won't block for I/O on this iteration.
function uv.stop() end

--- Get backend file descriptor. Only kqueue, epoll, and event ports are supported.
---
--- This can be used in conjunction with `uv.run("nowait")` to poll in one thread
--- and run the event loop's callbacks in another
--- **Note**:
--- Embedding a kqueue fd in another kqueue pollset doesn't work on all
--- platforms. It's not an error to add the fd but it never generates events.
--- @return integer?
function uv.backend_fd() end

--- Get the poll timeout. The return value is in milliseconds, or -1 for no timeout.
--- @return integer
function uv.backend_timeout() end

--- Returns the current timestamp in milliseconds. The timestamp is cached at the
--- start of the event loop tick, see `uv.update_time()` for details and rationale.
---
--- The timestamp increases monotonically from some arbitrary point in time. Don't
--- make assumptions about the starting point, you will only get disappointed.
--- **Note**:
--- Use `uv.hrtime()` if you need sub-millisecond granularity.
--- @return integer
function uv.now() end

--- Update the event loop's concept of "now". Libuv caches the current time at the
--- start of the event loop tick in order to reduce the number of time-related
--- system calls.
---
--- You won't normally need to call this function unless you have callbacks that
--- block the event loop for longer periods of time, where "longer" is somewhat
--- subjective but probably on the order of a millisecond or more.
function uv.update_time() end

--- Walk the list of handles: `callback` will be executed with each handle.
--- Example
--- ```lua
--- -- Example usage of uv.walk to close all handles that aren't already closing.
--- uv.walk(function (handle)
---   if not handle:is_closing() then
---     handle:close()
---   end
--- end)
--- ```
--- @param callback fun(handle: uv.uv_handle_t)
function uv.walk(callback) end


--- # `uv_req_t` - Base request
---
--- `uv_req_t` is the base type for all libuv request types.
--- @class uv.uv_req_t : userdata
local uv_req_t = {}

--- Cancel a pending request. Fails if the request is executing or has finished
--- executing. Only cancellation of `uv_fs_t`, `uv_getaddrinfo_t`,
--- `uv_getnameinfo_t` and `uv_work_t` requests is currently supported.
--- @param req uv.uv_req_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.cancel(req) end

--- Cancel a pending request. Fails if the request is executing or has finished
--- executing. Only cancellation of `uv_fs_t`, `uv_getaddrinfo_t`,
--- `uv_getnameinfo_t` and `uv_work_t` requests is currently supported.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_req_t:cancel() end

--- Returns the name of the struct for a given request (e.g. `"fs"` for `uv_fs_t`)
--- and the libuv enum integer for the request's type (`uv_req_type`).
--- @param req uv.uv_req_t
--- @return string type
--- @return integer enum
function uv.req_get_type(req) end

--- Returns the name of the struct for a given request (e.g. `"fs"` for `uv_fs_t`)
--- and the libuv enum integer for the request's type (`uv_req_type`).
--- @return string type
--- @return integer enum
function uv_req_t:get_type() end


--- # `uv_handle_t` - Base handle
---
--- `uv_handle_t` is the base type for all libuv handle types. All API functions
--- defined here work with any handle type.
--- @class uv.uv_handle_t : userdata
local uv_handle_t = {}

--- Returns `true` if the handle is active, `false` if it's inactive. What "active”
--- means depends on the type of handle:
---
---   - A [`uv_async_t`][] handle is always active and cannot be deactivated, except
---   by closing it with `uv.close()`.
---
---   - A [`uv_pipe_t`][], [`uv_tcp_t`][], [`uv_udp_t`][], etc. handle - basically
---   any handle that deals with I/O - is active when it is doing something that
---   involves I/O, like reading, writing, connecting, accepting new connections,
---   etc.
---
---   - A [`uv_check_t`][], [`uv_idle_t`][], [`uv_timer_t`][], etc. handle is active
---   when it has been started with a call to `uv.check_start()`, `uv.idle_start()`,
---   `uv.timer_start()` etc. until it has been stopped with a call to its
---   respective stop function.
--- @param handle uv.uv_handle_t
--- @return boolean? active
--- @return string? err
--- @return uv.error_name? err_name
function uv.is_active(handle) end

--- Returns `true` if the handle is active, `false` if it's inactive. What "active”
--- means depends on the type of handle:
---
---   - A [`uv_async_t`][] handle is always active and cannot be deactivated, except
---   by closing it with `uv.close()`.
---
---   - A [`uv_pipe_t`][], [`uv_tcp_t`][], [`uv_udp_t`][], etc. handle - basically
---   any handle that deals with I/O - is active when it is doing something that
---   involves I/O, like reading, writing, connecting, accepting new connections,
---   etc.
---
---   - A [`uv_check_t`][], [`uv_idle_t`][], [`uv_timer_t`][], etc. handle is active
---   when it has been started with a call to `uv.check_start()`, `uv.idle_start()`,
---   `uv.timer_start()` etc. until it has been stopped with a call to its
---   respective stop function.
--- @return boolean? active
--- @return string? err
--- @return uv.error_name? err_name
function uv_handle_t:is_active() end

--- Returns `true` if the handle is closing or closed, `false` otherwise.
--- **Note**:
--- This function should only be used between the initialization of the
--- handle and the arrival of the close callback.
--- @param handle uv.uv_handle_t
--- @return boolean? closing
--- @return string? err
--- @return uv.error_name? err_name
function uv.is_closing(handle) end

--- Returns `true` if the handle is closing or closed, `false` otherwise.
--- **Note**:
--- This function should only be used between the initialization of the
--- handle and the arrival of the close callback.
--- @return boolean? closing
--- @return string? err
--- @return uv.error_name? err_name
function uv_handle_t:is_closing() end

--- Request handle to be closed. `callback` will be called asynchronously after this
--- call. This MUST be called on each handle before memory is released.
---
--- Handles that wrap file descriptors are closed immediately but `callback` will
--- still be deferred to the next iteration of the event loop. It gives you a chance
--- to free up any resources associated with the handle.
---
--- In-progress requests, like `uv_connect_t` or `uv_write_t`, are cancelled and
--- have their callbacks called asynchronously with `ECANCELED`.
--- @param handle uv.uv_handle_t
--- @param callback fun()?
function uv.close(handle, callback) end

--- Request handle to be closed. `callback` will be called asynchronously after this
--- call. This MUST be called on each handle before memory is released.
---
--- Handles that wrap file descriptors are closed immediately but `callback` will
--- still be deferred to the next iteration of the event loop. It gives you a chance
--- to free up any resources associated with the handle.
---
--- In-progress requests, like `uv_connect_t` or `uv_write_t`, are cancelled and
--- have their callbacks called asynchronously with `ECANCELED`.
--- @param callback fun()?
function uv_handle_t:close(callback) end

--- Reference the given handle. References are idempotent, that is, if a handle is
--- already referenced calling this function again will have no effect.
--- @param handle uv.uv_handle_t
function uv.ref(handle) end

--- Reference the given handle. References are idempotent, that is, if a handle is
--- already referenced calling this function again will have no effect.
function uv_handle_t:ref() end

--- Un-reference the given handle. References are idempotent, that is, if a handle
--- is not referenced calling this function again will have no effect.
--- @param handle uv.uv_handle_t
function uv.unref(handle) end

--- Un-reference the given handle. References are idempotent, that is, if a handle
--- is not referenced calling this function again will have no effect.
function uv_handle_t:unref() end

--- Returns `true` if the handle referenced, `false` if not.
--- @param handle uv.uv_handle_t
--- @return boolean? has_ref
--- @return string? err
--- @return uv.error_name? err_name
function uv.has_ref(handle) end

--- Returns `true` if the handle referenced, `false` if not.
--- @return boolean? has_ref
--- @return string? err
--- @return uv.error_name? err_name
function uv_handle_t:has_ref() end

--- Gets or sets the size of the send buffer that the operating system uses for the
--- socket.
---
--- If `size` is omitted (or `0`), this will return the current send buffer size; otherwise, this will use `size` to set the new send buffer size.
---
--- This function works for TCP, pipe and UDP handles on Unix and for TCP and UDP
--- handles on Windows.
--- **Note**:
--- Linux will set double the size and return double the size of the
--- original set value.
--- @param handle uv.uv_handle_t
--- @param size integer?
--- @return integer? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.send_buffer_size(handle, size) end

--- Gets or sets the size of the send buffer that the operating system uses for the
--- socket.
---
--- If `size` is omitted (or `0`), this will return the current send buffer size; otherwise, this will use `size` to set the new send buffer size.
---
--- This function works for TCP, pipe and UDP handles on Unix and for TCP and UDP
--- handles on Windows.
--- **Note**:
--- Linux will set double the size and return double the size of the
--- original set value.
--- @param size integer?
--- @return integer? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_handle_t:send_buffer_size(size) end

--- Gets or sets the size of the receive buffer that the operating system uses for
--- the socket.
---
--- If `size` is omitted (or `0`), this will return the current send buffer size; otherwise, this will use `size` to set the new send buffer size.
---
--- This function works for TCP, pipe and UDP handles on Unix and for TCP and UDP
--- handles on Windows.
--- **Note**:
--- Linux will set double the size and return double the size of the
--- original set value.
--- @param handle uv.uv_handle_t
--- @param size integer?
--- @return integer? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.recv_buffer_size(handle, size) end

--- Gets or sets the size of the receive buffer that the operating system uses for
--- the socket.
---
--- If `size` is omitted (or `0`), this will return the current send buffer size; otherwise, this will use `size` to set the new send buffer size.
---
--- This function works for TCP, pipe and UDP handles on Unix and for TCP and UDP
--- handles on Windows.
--- **Note**:
--- Linux will set double the size and return double the size of the
--- original set value.
--- @param size integer?
--- @return integer? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_handle_t:recv_buffer_size(size) end

--- Gets the platform dependent file descriptor equivalent.
---
--- The following handles are supported: TCP, pipes, TTY, UDP and poll. Passing any
--- other handle type will fail with `EINVAL`.
---
--- If a handle doesn't have an attached file descriptor yet or the handle itself
--- has been closed, this function will return `EBADF`.
--- **Warning**:
--- Be very careful when using this function. libuv assumes it's in
--- control of the file descriptor so any change to it may lead to malfunction.
--- @param handle uv.uv_handle_t
--- @return integer? fileno
--- @return string? err
--- @return uv.error_name? err_name
function uv.fileno(handle) end

--- Gets the platform dependent file descriptor equivalent.
---
--- The following handles are supported: TCP, pipes, TTY, UDP and poll. Passing any
--- other handle type will fail with `EINVAL`.
---
--- If a handle doesn't have an attached file descriptor yet or the handle itself
--- has been closed, this function will return `EBADF`.
--- **Warning**:
--- Be very careful when using this function. libuv assumes it's in
--- control of the file descriptor so any change to it may lead to malfunction.
--- @return integer? fileno
--- @return string? err
--- @return uv.error_name? err_name
function uv_handle_t:fileno() end

--- Returns the name of the struct for a given handle (e.g. `"pipe"` for `uv_pipe_t`)
--- and the libuv enum integer for the handle's type (`uv_handle_type`).
--- @param handle uv.uv_handle_t
--- @return string type
--- @return integer enum
function uv.handle_get_type(handle) end

--- Returns the name of the struct for a given handle (e.g. `"pipe"` for `uv_pipe_t`)
--- and the libuv enum integer for the handle's type (`uv_handle_type`).
--- @return string type
--- @return integer enum
function uv_handle_t:get_type() end


--- # Reference counting
---
--- The libuv event loop (if run in the default mode) will run until there are no
--- active and referenced handles left. The user can force the loop to exit early by
--- unreferencing handles which are active, for example by calling `uv.unref()`
--- after calling `uv.timer_start()`.
---
--- A handle can be referenced or unreferenced, the refcounting scheme doesn't use a
--- counter, so both operations are idempotent.
---
--- All handles are referenced when active by default, see `uv.is_active()` for a
--- more detailed explanation on what being active involves.

--- # `uv_timer_t` - Timer handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Timer handles are used to schedule callbacks to be called in the future.
--- @class uv.uv_timer_t : uv.uv_handle_t
local uv_timer_t = {}

--- Creates and initializes a new `uv_timer_t`. Returns the Lua userdata wrapping
--- it.
--- Example
--- ```lua
--- -- Creating a simple setTimeout wrapper
--- local function setTimeout(timeout, callback)
---   local timer = uv.new_timer()
---   timer:start(timeout, 0, function ()
---     timer:stop()
---     timer:close()
---     callback()
---   end)
---   return timer
--- end
---
--- -- Creating a simple setInterval wrapper
--- local function setInterval(interval, callback)
---   local timer = uv.new_timer()
---   timer:start(interval, interval, function ()
---     callback()
---   end)
---   return timer
--- end
---
--- -- And clearInterval
--- local function clearInterval(timer)
---   timer:stop()
---   timer:close()
--- end
--- ```
--- @return uv.uv_timer_t? timer
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_timer() end

--- Start the timer. `timeout` and `repeat` are in milliseconds.
---
--- If `timeout` is zero, the callback fires on the next event loop iteration. If
--- `repeat` is non-zero, the callback fires first after `timeout` milliseconds and
--- then repeatedly after `repeat` milliseconds.
--- @param timer uv.uv_timer_t
--- @param timeout integer
--- @param repeat_ integer
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.timer_start(timer, timeout, repeat_, callback) end

--- Start the timer. `timeout` and `repeat` are in milliseconds.
---
--- If `timeout` is zero, the callback fires on the next event loop iteration. If
--- `repeat` is non-zero, the callback fires first after `timeout` milliseconds and
--- then repeatedly after `repeat` milliseconds.
--- @param timeout integer
--- @param repeat_ integer
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_timer_t:start(timeout, repeat_, callback) end

--- Stop the timer, the callback will not be called anymore.
--- @param timer uv.uv_timer_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.timer_stop(timer) end

--- Stop the timer, the callback will not be called anymore.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_timer_t:stop() end

--- Stop the timer, and if it is repeating restart it using the repeat value as the
--- timeout. If the timer has never been started before it raises `EINVAL`.
--- @param timer uv.uv_timer_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.timer_again(timer) end

--- Stop the timer, and if it is repeating restart it using the repeat value as the
--- timeout. If the timer has never been started before it raises `EINVAL`.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_timer_t:again() end

--- Set the repeat interval value in milliseconds. The timer will be scheduled to
--- run on the given interval, regardless of the callback execution duration, and
--- will follow normal timer semantics in the case of a time-slice overrun.
---
--- For example, if a 50 ms repeating timer first runs for 17 ms, it will be
--- scheduled to run again 33 ms later. If other tasks consume more than the 33 ms
--- following the first timer callback, then the callback will run as soon as
--- possible.
--- @param timer uv.uv_timer_t
--- @param repeat_ integer
function uv.timer_set_repeat(timer, repeat_) end

--- Set the repeat interval value in milliseconds. The timer will be scheduled to
--- run on the given interval, regardless of the callback execution duration, and
--- will follow normal timer semantics in the case of a time-slice overrun.
---
--- For example, if a 50 ms repeating timer first runs for 17 ms, it will be
--- scheduled to run again 33 ms later. If other tasks consume more than the 33 ms
--- following the first timer callback, then the callback will run as soon as
--- possible.
--- @param repeat_ integer
function uv_timer_t:set_repeat(repeat_) end

--- Get the timer repeat value.
--- @param timer uv.uv_timer_t
--- @return integer repeat_
function uv.timer_get_repeat(timer) end

--- Get the timer repeat value.
--- @return integer repeat_
function uv_timer_t:get_repeat() end

--- Get the timer due value or 0 if it has expired. The time is relative to `uv.now()`.
--- @param timer uv.uv_timer_t
--- @return integer due_in
function uv.timer_get_due_in(timer) end

--- Get the timer due value or 0 if it has expired. The time is relative to `uv.now()`.
--- @return integer due_in
function uv_timer_t:get_due_in() end


--- # `uv_prepare_t` - Prepare handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Prepare handles will run the given callback once per loop iteration, right
--- before polling for I/O.
---
--- ```lua
--- local prepare = uv.new_prepare()
--- prepare:start(function()
---   print("Before I/O polling")
--- end)
--- ```
--- @class uv.uv_prepare_t : uv.uv_handle_t
local uv_prepare_t = {}

--- Creates and initializes a new `uv_prepare_t`. Returns the Lua userdata wrapping
--- it.
--- @return uv.uv_prepare_t
function uv.new_prepare() end

--- Start the handle with the given callback.
--- @param prepare uv.uv_prepare_t
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.prepare_start(prepare, callback) end

--- Start the handle with the given callback.
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_prepare_t:start(callback) end

--- Stop the handle, the callback will no longer be called.
--- @param prepare uv.uv_prepare_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.prepare_stop(prepare) end

--- Stop the handle, the callback will no longer be called.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_prepare_t:stop() end


--- # `uv_check_t` - Check handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Check handles will run the given callback once per loop iteration, right after
--- polling for I/O.
---
--- ```lua
--- local check = uv.new_check()
--- check:start(function()
---   print("After I/O polling")
--- end)
--- ```
--- @class uv.uv_check_t : uv.uv_handle_t
local uv_check_t = {}

--- Creates and initializes a new `uv_check_t`. Returns the Lua userdata wrapping
--- it.
--- @return uv.uv_check_t
function uv.new_check() end

--- Start the handle with the given callback.
--- @param check uv.uv_check_t
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.check_start(check, callback) end

--- Start the handle with the given callback.
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_check_t:start(callback) end

--- Stop the handle, the callback will no longer be called.
--- @param check uv.uv_check_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.check_stop(check) end

--- Stop the handle, the callback will no longer be called.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_check_t:stop() end


--- # `uv_idle_t` - Idle handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Idle handles will run the given callback once per loop iteration, right before
--- the [`uv_prepare_t`][] handles.
---
--- **Note**: The notable difference with prepare handles is that when there are
--- active idle handles, the loop will perform a zero timeout poll instead of
--- blocking for I/O.
---
--- **Warning**: Despite the name, idle handles will get their callbacks called on
--- every loop iteration, not when the loop is actually "idle".
---
--- ```lua
--- local idle = uv.new_idle()
--- idle:start(function()
---   print("Before I/O polling, no blocking")
--- end)
--- ```
--- @class uv.uv_idle_t : uv.uv_handle_t
local uv_idle_t = {}

--- Creates and initializes a new `uv_idle_t`. Returns the Lua userdata wrapping
--- it.
--- @return uv.uv_idle_t
function uv.new_idle() end

--- Start the handle with the given callback.
--- @param idle uv.uv_idle_t
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.idle_start(idle, callback) end

--- Start the handle with the given callback.
--- @param callback fun()
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_idle_t:start(callback) end

--- Stop the handle, the callback will no longer be called.
--- @param idle uv.uv_idle_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.idle_stop(idle) end

--- Stop the handle, the callback will no longer be called.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_idle_t:stop() end


--- # `uv_async_t` - Async handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Async handles allow the user to "wakeup" the event loop and get a callback
--- called from another thread.
---
--- ```lua
--- local async
--- async = uv.new_async(function()
---   print("async operation ran")
---   async:close()
--- end)
---
--- async:send()
--- ```
--- @class uv.uv_async_t : uv.uv_handle_t
local uv_async_t = {}

--- Creates and initializes a new `uv_async_t`. Returns the Lua userdata wrapping
--- it.
--- **Note**:
--- Unlike other handle initialization functions, this immediately starts
--- the handle.
--- @param callback fun(...: uv.threadargs)
--- @return uv.uv_async_t? async
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_async(callback) end

--- Wakeup the event loop and call the async handle's callback.
--- **Note**:
--- It's safe to call this function from any thread. The callback will be
--- called on the loop thread.
--- **Warning**:
--- libuv will coalesce calls to `uv.async_send(async)`, that is, not
--- every call to it will yield an execution of the callback. For example: if
--- `uv.async_send()` is called 5 times in a row before the callback is called, the
--- callback will only be called once. If `uv.async_send()` is called again after
--- the callback was called, it will be called again.
--- @param async uv.uv_async_t
--- @param ... uv.threadargs
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.async_send(async, ...) end

--- Wakeup the event loop and call the async handle's callback.
--- **Note**:
--- It's safe to call this function from any thread. The callback will be
--- called on the loop thread.
--- **Warning**:
--- libuv will coalesce calls to `uv.async_send(async)`, that is, not
--- every call to it will yield an execution of the callback. For example: if
--- `uv.async_send()` is called 5 times in a row before the callback is called, the
--- callback will only be called once. If `uv.async_send()` is called again after
--- the callback was called, it will be called again.
--- @param ... uv.threadargs
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_async_t:send(...) end


--- # `uv_poll_t` - Poll handle
---
--- > [`uv_handle_t`][] functions also apply.
---
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
--- immediately after a call to `uv.poll_stop()` or `uv.close()`.
---
--- **Note**: On windows only sockets can be polled with poll handles. On Unix any
--- file descriptor that would be accepted by poll(2) can be used.
--- @class uv.uv_poll_t : uv.uv_handle_t
local uv_poll_t = {}

--- Initialize the handle using a file descriptor.
---
--- The file descriptor is set to non-blocking mode.
--- @param fd integer
--- @return uv.uv_poll_t? poll
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_poll(fd) end

--- Initialize the handle using a socket descriptor. On Unix this is identical to
--- `uv.new_poll()`. On windows it takes a SOCKET handle.
---
--- The socket is set to non-blocking mode.
--- @param fd integer
--- @return uv.uv_poll_t? poll
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_socket_poll(fd) end

--- Starts polling the file descriptor. `events` are: `"r"`, `"w"`, `"rw"`, `"d"`,
--- `"rd"`, `"wd"`, `"rwd"`, `"p"`, `"rp"`, `"wp"`, `"rwp"`, `"dp"`, `"rdp"`,
--- `"wdp"`, or `"rwdp"` where `r` is `READABLE`, `w` is `WRITABLE`, `d` is
--- `DISCONNECT`, and `p` is `PRIORITIZED`. As soon as an event is detected
--- the callback will be called with status set to 0, and the detected events set on
--- the events field.
---
--- The user should not close the socket while the handle is active. If the user
--- does that anyway, the callback may be called reporting an error status, but this
--- is not guaranteed.
--- **Note**:
--- Calling `uv.poll_start()` on a handle that is already active is fine.
--- Doing so will update the events mask that is being watched for.
--- @param poll uv.uv_poll_t
--- @param events string?
--- @param callback fun(err: string?, events: string?)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.poll_start(poll, events, callback) end

--- Starts polling the file descriptor. `events` are: `"r"`, `"w"`, `"rw"`, `"d"`,
--- `"rd"`, `"wd"`, `"rwd"`, `"p"`, `"rp"`, `"wp"`, `"rwp"`, `"dp"`, `"rdp"`,
--- `"wdp"`, or `"rwdp"` where `r` is `READABLE`, `w` is `WRITABLE`, `d` is
--- `DISCONNECT`, and `p` is `PRIORITIZED`. As soon as an event is detected
--- the callback will be called with status set to 0, and the detected events set on
--- the events field.
---
--- The user should not close the socket while the handle is active. If the user
--- does that anyway, the callback may be called reporting an error status, but this
--- is not guaranteed.
--- **Note**:
--- Calling `uv.poll_start()` on a handle that is already active is fine.
--- Doing so will update the events mask that is being watched for.
--- @param events string?
--- @param callback fun(err: string?, events: string?)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_poll_t:start(events, callback) end

--- Stop polling the file descriptor, the callback will no longer be called.
--- @param poll uv.uv_poll_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.poll_stop(poll) end

--- Stop polling the file descriptor, the callback will no longer be called.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_poll_t:stop() end


--- # `uv_signal_t` - Signal handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Signal handles implement Unix style signal handling on a per-event loop bases.
---
--- **Windows Notes:**
---
--- Reception of some signals is emulated on Windows:
---   - SIGINT is normally delivered when the user presses CTRL+C. However, like on
---   Unix, it is not generated when terminal raw mode is enabled.
---   - SIGBREAK is delivered when the user pressed CTRL + BREAK.
---   - SIGHUP is generated when the user closes the console window. On SIGHUP the
---   program is given approximately 10 seconds to perform cleanup. After that
---   Windows will unconditionally terminate it.
---   - SIGWINCH is raised whenever libuv detects that the console has been resized.
---   SIGWINCH is emulated by libuv when the program uses a uv_tty_t handle to write
---   to the console. SIGWINCH may not always be delivered in a timely manner; libuv
---   will only detect size changes when the cursor is being moved. When a readable
---   [`uv_tty_t`][] handle is used in raw mode, resizing the console buffer will
---   also trigger a SIGWINCH signal.
---   - Watchers for other signals can be successfully created, but these signals
---   are never received. These signals are: SIGILL, SIGABRT, SIGFPE, SIGSEGV,
---   SIGTERM and SIGKILL.
---   - Calls to raise() or abort() to programmatically raise a signal are not
---   detected by libuv; these will not trigger a signal watcher.
---
--- **Unix Notes:**
---
---   - SIGKILL and SIGSTOP are impossible to catch.
---   - Handling SIGBUS, SIGFPE, SIGILL or SIGSEGV via libuv results into undefined
---   behavior.
---   - SIGABRT will not be caught by libuv if generated by abort(), e.g. through
---   assert().
---   - On Linux SIGRT0 and SIGRT1 (signals 32 and 33) are used by the NPTL pthreads
---   library to manage threads. Installing watchers for those signals will lead to
---   unpredictable behavior and is strongly discouraged. Future versions of libuv
---   may simply reject them.
---
--- ```lua
--- -- Create a new signal handler
--- local signal = uv.new_signal()
--- -- Define a handler function
--- uv.signal_start(signal, "sigint", function(signame)
---   print("got " .. signame .. ", shutting down")
---   os.exit(1)
--- end)
--- ```
--- @class uv.uv_signal_t : uv.uv_handle_t
local uv_signal_t = {}

--- Creates and initializes a new `uv_signal_t`. Returns the Lua userdata wrapping
--- it.
--- @return uv.uv_signal_t? signal
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_signal() end

--- Start the handle with the given callback, watching for the given signal.
---
--- See [Constants][] for supported `signame` input and output values.
--- @param signal uv.uv_signal_t
--- @param signame string|integer
--- @param callback fun(signame: string)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.signal_start(signal, signame, callback) end

--- Start the handle with the given callback, watching for the given signal.
---
--- See [Constants][] for supported `signame` input and output values.
--- @param signame string|integer
--- @param callback fun(signame: string)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_signal_t:start(signame, callback) end

--- Same functionality as `uv.signal_start()` but the signal handler is reset the moment the signal is received.
---
--- See [Constants][] for supported `signame` input and output values.
--- @param signal uv.uv_signal_t
--- @param signame string|integer
--- @param callback fun(signame: string)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.signal_start_oneshot(signal, signame, callback) end

--- Same functionality as `uv.signal_start()` but the signal handler is reset the moment the signal is received.
---
--- See [Constants][] for supported `signame` input and output values.
--- @param signame string|integer
--- @param callback fun(signame: string)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_signal_t:start_oneshot(signame, callback) end

--- Stop the handle, the callback will no longer be called.
--- @param signal uv.uv_signal_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.signal_stop(signal) end

--- Stop the handle, the callback will no longer be called.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_signal_t:stop() end


--- # `uv_process_t` - Process handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Process handles will spawn a new process and allow the user to control it and
--- establish communication channels with it using streams.
--- @class uv.uv_process_t : uv.uv_handle_t
local uv_process_t = {}

--- Disables inheritance for file descriptors / handles that this process inherited
--- from its parent. The effect is that child processes spawned by this process
--- don't accidentally inherit these handles.
---
--- It is recommended to call this function as early in your program as possible,
--- before the inherited file descriptors can be closed or duplicated.
--- **Note**:
--- This function works on a best-effort basis: there is no guarantee that
--- libuv can discover all file descriptors that were inherited. In general it does
--- a better job on Windows than it does on Unix.
function uv.disable_stdio_inheritance() end

--- @class uv.spawn.options
---
--- Command line arguments as a list of strings. The first
--- string should *not* be the path to the program, since that is already
--- provided via `path`. On Windows, this uses CreateProcess which concatenates
--- the arguments into a string. This can cause some strange errors
--- (see `options.verbatim` below for Windows).
--- @field args string[]?
---
--- Set the file descriptors that will be made available to
--- the child process. The convention is that the first entries are stdin, stdout,
--- and stderr.
---
--- The entries can take many shapes.
--- - If `integer`, then the child process inherits that same zero-indexed
---   fd from the parent process.
--- - If `uv_stream_t` handles are passed in, those are used as a read-write pipe
---   or inherited stream depending if the stream has a valid fd.
--- - If `nil`, means to ignore that fd in the child process.
---
--- **Note**: On Windows, file descriptors after the third are
--- available to the child process only if the child processes uses the MSVCRT
--- runtime.
--- @field stdio table<integer, integer|uv.uv_stream_t?>?
---
--- Set environment variables for the new process.
--- @field env table<string, string>?
---
--- Set the current working directory for the sub-process.
--- @field cwd string?
---
--- Set the child process' user id.
--- @field uid string?
---
--- Set the child process' group id.
--- @field gid string?
---
--- If true, do not wrap any arguments in quotes, or
--- perform any other escaping, when converting the argument list into a command
--- line string. This option is only meaningful on Windows systems. On Unix it is
--- silently ignored.
--- @field verbatim boolean?
---
--- If true, spawn the child process in a detached state -
--- this will make it a process group leader, and will effectively enable the
--- child to keep running after the parent exits. Note that the child process
--- will still keep the parent's event loop alive unless the parent process calls
--- `uv.unref()` on the child's process handle.
--- @field detached boolean?
---
--- If true, hide the subprocess console window that would
--- normally be created. This option is only meaningful on Windows systems. On
--- Unix it is silently ignored.
--- @field hide boolean?

--- Initializes the process handle and starts the process. If the process is
--- successfully spawned, this function will return the handle and pid of the child
--- process.
---
--- Possible reasons for failing to spawn would include (but not be limited to) the
--- file to execute not existing, not having permissions to use the setuid or setgid
--- specified, or not having enough memory to allocate for the new process.
---
--- ```lua
--- local stdin = uv.new_pipe()
--- local stdout = uv.new_pipe()
--- local stderr = uv.new_pipe()
---
--- print("stdin", stdin)
--- print("stdout", stdout)
--- print("stderr", stderr)
---
--- local handle, pid = uv.spawn("cat", {
---   stdio = {stdin, stdout, stderr}
--- }, function(code, signal) -- on exit
---   print("exit code", code)
---   print("exit signal", signal)
--- end)
---
--- print("process opened", handle, pid)
---
--- uv.read_start(stdout, function(err, data)
---   assert(not err, err)
---   if data then
---     print("stdout chunk", stdout, data)
---   else
---     print("stdout end", stdout)
---   end
--- end)
---
--- uv.read_start(stderr, function(err, data)
---   assert(not err, err)
---   if data then
---     print("stderr chunk", stderr, data)
---   else
---     print("stderr end", stderr)
---   end
--- end)
---
--- uv.write(stdin, "Hello World")
---
--- uv.shutdown(stdin, function()
---   print("stdin shutdown", stdin)
---   uv.close(handle, function()
---     print("process closed", handle, pid)
---   end)
--- end)
--- ```
---
--- When the child process exits, `on_exit` is called with an exit code and signal.
--- @param path string
--- @param options uv.spawn.options
--- @param on_exit fun(code: integer, signal: integer)
--- @return uv.uv_process_t handle
--- @return integer pid
function uv.spawn(path, options, on_exit) end

--- Sends the specified signal to the given process handle. Check the documentation
--- on `uv_signal_t` for signal support, specially on Windows.
---
--- See [Constants][] for supported `signame` input values.
--- @param process uv.uv_process_t
--- @param signame string|integer?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.process_kill(process, signame) end

--- Sends the specified signal to the given process handle. Check the documentation
--- on `uv_signal_t` for signal support, specially on Windows.
---
--- See [Constants][] for supported `signame` input values.
--- @param signame string|integer?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_process_t:kill(signame) end

--- Sends the specified signal to the given PID. Check the documentation on
--- `uv_signal_t` for signal support, specially on Windows.
---
--- See [Constants][] for supported `signame` input values.
--- @param pid integer
--- @param signame string|integer?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.kill(pid, signame) end

--- Returns the handle's pid.
--- @param process uv.uv_process_t
--- @return integer
function uv.process_get_pid(process) end

--- Returns the handle's pid.
--- @return integer
function uv_process_t:get_pid() end


--- # `uv_stream_t` - Stream handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- Stream handles provide an abstraction of a duplex communication channel.
--- [`uv_stream_t`][] is an abstract type, libuv provides 3 stream implementations
--- in the form of [`uv_tcp_t`][], [`uv_pipe_t`][] and [`uv_tty_t`][].
--- @class uv.uv_stream_t : uv.uv_handle_t
local uv_stream_t = {}

--- Shutdown the outgoing (write) side of a duplex stream. It waits for pending
--- write requests to complete. The callback is called after shutdown is complete.
--- @param stream uv.uv_stream_t
--- @param callback fun(err: string?)?
--- @return uv.uv_shutdown_t? shutdown
--- @return string? err
--- @return uv.error_name? err_name
function uv.shutdown(stream, callback) end

--- Shutdown the outgoing (write) side of a duplex stream. It waits for pending
--- write requests to complete. The callback is called after shutdown is complete.
--- @param callback fun(err: string?)?
--- @return uv.uv_shutdown_t? shutdown
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:shutdown(callback) end

--- Start listening for incoming connections. `backlog` indicates the number of
--- connections the kernel might queue, same as `listen(2)`. When a new incoming
--- connection is received the callback is called.
--- @param stream uv.uv_stream_t
--- @param backlog integer
--- @param callback fun(err: string?)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.listen(stream, backlog, callback) end

--- Start listening for incoming connections. `backlog` indicates the number of
--- connections the kernel might queue, same as `listen(2)`. When a new incoming
--- connection is received the callback is called.
--- @param backlog integer
--- @param callback fun(err: string?)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:listen(backlog, callback) end

--- This call is used in conjunction with `uv.listen()` to accept incoming
--- connections. Call this function after receiving a callback to accept the
--- connection.
---
--- When the connection callback is called it is guaranteed that this function
--- will complete successfully the first time. If you attempt to use it more than
--- once, it may fail. It is suggested to only call this function once per
--- connection call.
--- Example
--- ```lua
--- server:listen(128, function (err)
---   local client = uv.new_tcp()
---   server:accept(client)
--- end)
--- ```
--- @param stream uv.uv_stream_t
--- @param client_stream uv.uv_stream_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.accept(stream, client_stream) end

--- This call is used in conjunction with `uv.listen()` to accept incoming
--- connections. Call this function after receiving a callback to accept the
--- connection.
---
--- When the connection callback is called it is guaranteed that this function
--- will complete successfully the first time. If you attempt to use it more than
--- once, it may fail. It is suggested to only call this function once per
--- connection call.
--- Example
--- ```lua
--- server:listen(128, function (err)
---   local client = uv.new_tcp()
---   server:accept(client)
--- end)
--- ```
--- @param client_stream uv.uv_stream_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:accept(client_stream) end

--- Read data from an incoming stream. The callback will be made several times until
--- there is no more data to read or `uv.read_stop()` is called. When we've reached
--- EOF, `data` will be `nil`.
--- Example
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
--- @param stream uv.uv_stream_t
--- @param callback fun(err: string?, data: string?)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.read_start(stream, callback) end

--- Read data from an incoming stream. The callback will be made several times until
--- there is no more data to read or `uv.read_stop()` is called. When we've reached
--- EOF, `data` will be `nil`.
--- Example
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
--- @param callback fun(err: string?, data: string?)
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:read_start(callback) end

--- Stop reading data from the stream. The read callback will no longer be called.
---
--- This function is idempotent and may be safely called on a stopped stream.
--- @param stream uv.uv_stream_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.read_stop(stream) end

--- Stop reading data from the stream. The read callback will no longer be called.
---
--- This function is idempotent and may be safely called on a stopped stream.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:read_stop() end

--- Write data to stream.
---
--- `data` can either be a Lua string or a table of strings. If a table is passed
--- in, the C backend will use writev to send all strings in a single system call.
---
--- The optional `callback` is for knowing when the write is complete.
--- @param stream uv.uv_stream_t
--- @param data uv.buffer
--- @param callback fun(err: string?)?
--- @return uv.uv_write_t? write
--- @return string? err
--- @return uv.error_name? err_name
function uv.write(stream, data, callback) end

--- Write data to stream.
---
--- `data` can either be a Lua string or a table of strings. If a table is passed
--- in, the C backend will use writev to send all strings in a single system call.
---
--- The optional `callback` is for knowing when the write is complete.
--- @param data uv.buffer
--- @param callback fun(err: string?)?
--- @return uv.uv_write_t? write
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:write(data, callback) end

--- Extended write function for sending handles over a pipe. The pipe must be
--- initialized with `ipc` option `true`.
--- **Note**:
--- `send_handle` must be a TCP socket or pipe, which is a server or a
--- connection (listening or connected state). Bound sockets or pipes will be
--- assumed to be servers.
--- @param stream uv.uv_stream_t
--- @param data uv.buffer
--- @param send_handle uv.uv_stream_t
--- @param callback fun(err: string?)?
--- @return uv.uv_write_t? write
--- @return string? err
--- @return uv.error_name? err_name
function uv.write2(stream, data, send_handle, callback) end

--- Extended write function for sending handles over a pipe. The pipe must be
--- initialized with `ipc` option `true`.
--- **Note**:
--- `send_handle` must be a TCP socket or pipe, which is a server or a
--- connection (listening or connected state). Bound sockets or pipes will be
--- assumed to be servers.
--- @param data uv.buffer
--- @param send_handle uv.uv_stream_t
--- @param callback fun(err: string?)?
--- @return uv.uv_write_t? write
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:write2(data, send_handle, callback) end

--- Same as `uv.write()`, but won't queue a write request if it can't be completed
--- immediately.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
--- @param stream uv.uv_stream_t
--- @param data uv.buffer
--- @return integer? bytes_written
--- @return string? err
--- @return uv.error_name? err_name
function uv.try_write(stream, data) end

--- Same as `uv.write()`, but won't queue a write request if it can't be completed
--- immediately.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
--- @param data uv.buffer
--- @return integer? bytes_written
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:try_write(data) end

--- Like `uv.write2()`, but with the properties of `uv.try_write()`. Not supported on Windows, where it returns `UV_EAGAIN`.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
--- @param stream uv.uv_stream_t
--- @param data uv.buffer
--- @param send_handle uv.uv_stream_t
--- @return integer? bytes_written
--- @return string? err
--- @return uv.error_name? err_name
function uv.try_write2(stream, data, send_handle) end

--- Like `uv.write2()`, but with the properties of `uv.try_write()`. Not supported on Windows, where it returns `UV_EAGAIN`.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
--- @param data uv.buffer
--- @param send_handle uv.uv_stream_t
--- @return integer? bytes_written
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:try_write2(data, send_handle) end

--- Returns `true` if the stream is readable, `false` otherwise.
--- @param stream uv.uv_stream_t
--- @return boolean
function uv.is_readable(stream) end

--- Returns `true` if the stream is readable, `false` otherwise.
--- @return boolean
function uv_stream_t:is_readable() end

--- Returns `true` if the stream is writable, `false` otherwise.
--- @param stream uv.uv_stream_t
--- @return boolean
function uv.is_writable(stream) end

--- Returns `true` if the stream is writable, `false` otherwise.
--- @return boolean
function uv_stream_t:is_writable() end

--- Enable or disable blocking mode for a stream.
---
--- When blocking mode is enabled all writes complete synchronously. The interface
--- remains unchanged otherwise, e.g. completion or failure of the operation will
--- still be reported through a callback which is made asynchronously.
--- **Warning**:
--- Relying too much on this API is not recommended. It is likely to
--- change significantly in the future. Currently this only works on Windows and
--- only for `uv_pipe_t` handles. Also libuv currently makes no ordering guarantee
--- when the blocking mode is changed after write requests have already been
--- submitted. Therefore it is recommended to set the blocking mode immediately
--- after opening or creating the stream.
--- @param stream uv.uv_stream_t
--- @param blocking boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.stream_set_blocking(stream, blocking) end

--- Enable or disable blocking mode for a stream.
---
--- When blocking mode is enabled all writes complete synchronously. The interface
--- remains unchanged otherwise, e.g. completion or failure of the operation will
--- still be reported through a callback which is made asynchronously.
--- **Warning**:
--- Relying too much on this API is not recommended. It is likely to
--- change significantly in the future. Currently this only works on Windows and
--- only for `uv_pipe_t` handles. Also libuv currently makes no ordering guarantee
--- when the blocking mode is changed after write requests have already been
--- submitted. Therefore it is recommended to set the blocking mode immediately
--- after opening or creating the stream.
--- @param blocking boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_stream_t:set_blocking(blocking) end

--- Returns the stream's write queue size.
--- @param stream uv.uv_stream_t
--- @return integer
function uv.stream_get_write_queue_size(stream) end

--- Returns the stream's write queue size.
--- @return integer
function uv_stream_t:get_write_queue_size() end


--- # `uv_tcp_t` - TCP handle
---
--- > [`uv_handle_t`][] and [`uv_stream_t`][] functions also apply.
---
--- TCP handles are used to represent both TCP streams and servers.
--- @class uv.uv_tcp_t : uv.uv_stream_t
local uv_tcp_t = {}

--- Creates and initializes a new `uv_tcp_t`. Returns the Lua userdata wrapping it.
---
--- If set, `flags` must be a valid address family. See [Constants][] for supported
--- address family input values.
--- @param flags string|integer?
--- @return uv.uv_tcp_t? tcp
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_tcp(flags) end

--- Open an existing file descriptor or SOCKET as a TCP handle.
--- **Note**:
--- The passed file descriptor or SOCKET is not checked for its type, but it's required that it represents a valid stream socket.
--- @param tcp uv.uv_tcp_t
--- @param sock integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_open(tcp, sock) end

--- Open an existing file descriptor or SOCKET as a TCP handle.
--- **Note**:
--- The passed file descriptor or SOCKET is not checked for its type, but it's required that it represents a valid stream socket.
--- @param sock integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:open(sock) end

--- Enable / disable Nagle's algorithm.
--- @param tcp uv.uv_tcp_t
--- @param enable boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_nodelay(tcp, enable) end

--- Enable / disable Nagle's algorithm.
--- @param enable boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:nodelay(enable) end

--- Enable / disable TCP keep-alive. `delay` is the initial delay in seconds,
--- ignored when enable is `false`.
--- @param tcp uv.uv_tcp_t
--- @param enable boolean
--- @param delay integer?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_keepalive(tcp, enable, delay) end

--- Enable / disable TCP keep-alive. `delay` is the initial delay in seconds,
--- ignored when enable is `false`.
--- @param enable boolean
--- @param delay integer?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:keepalive(enable, delay) end

--- Enable / disable simultaneous asynchronous accept requests that are queued by
--- the operating system when listening for new TCP connections.
---
--- This setting is used to tune a TCP server for the desired performance. Having
--- simultaneous accepts can significantly improve the rate of accepting connections
--- (which is why it is enabled by default) but may lead to uneven load distribution
--- in multi-process setups.
--- @param tcp uv.uv_tcp_t
--- @param enable boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_simultaneous_accepts(tcp, enable) end

--- Enable / disable simultaneous asynchronous accept requests that are queued by
--- the operating system when listening for new TCP connections.
---
--- This setting is used to tune a TCP server for the desired performance. Having
--- simultaneous accepts can significantly improve the rate of accepting connections
--- (which is why it is enabled by default) but may lead to uneven load distribution
--- in multi-process setups.
--- @param enable boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:simultaneous_accepts(enable) end

--- Bind the handle to an host and port. `host` should be an IP address and
--- not a domain name. Any `flags` are set with a table with field `ipv6only`
--- equal to `true` or `false`.
---
--- When the port is already taken, you can expect to see an `EADDRINUSE` error
--- from either `uv.tcp_bind()`, `uv.listen()` or `uv.tcp_connect()`. That is, a
--- successful call to this function does not guarantee that the call to `uv.listen()`
--- or `uv.tcp_connect()` will succeed as well.
---
--- Use a port of `0` to let the OS assign an ephemeral port.  You can look it up
--- later using `uv.tcp_getsockname()`.
--- @param tcp uv.uv_tcp_t
--- @param host string
--- @param port integer
--- @param flags { ipv6only: boolean }?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_bind(tcp, host, port, flags) end

--- Bind the handle to an host and port. `host` should be an IP address and
--- not a domain name. Any `flags` are set with a table with field `ipv6only`
--- equal to `true` or `false`.
---
--- When the port is already taken, you can expect to see an `EADDRINUSE` error
--- from either `uv.tcp_bind()`, `uv.listen()` or `uv.tcp_connect()`. That is, a
--- successful call to this function does not guarantee that the call to `uv.listen()`
--- or `uv.tcp_connect()` will succeed as well.
---
--- Use a port of `0` to let the OS assign an ephemeral port.  You can look it up
--- later using `uv.tcp_getsockname()`.
--- @param host string
--- @param port integer
--- @param flags { ipv6only: boolean }?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:bind(host, port, flags) end

--- Get the address of the peer connected to the handle.
---
--- See [Constants][] for supported address `family` output values.
--- @param tcp uv.uv_tcp_t
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_getpeername(tcp) end

--- Get the address of the peer connected to the handle.
---
--- See [Constants][] for supported address `family` output values.
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:getpeername() end

--- Get the current address to which the handle is bound.
---
--- See [Constants][] for supported address `family` output values.
--- @param tcp uv.uv_tcp_t
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_getsockname(tcp) end

--- Get the current address to which the handle is bound.
---
--- See [Constants][] for supported address `family` output values.
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:getsockname() end

--- Establish an IPv4 or IPv6 TCP connection.
--- Example
--- ```lua
--- local client = uv.new_tcp()
--- client:connect("127.0.0.1", 8080, function (err)
---   -- check error and carry on.
--- end)
--- ```
--- @param tcp uv.uv_tcp_t
--- @param host string
--- @param port integer
--- @param callback fun(err: string?)
--- @return uv.uv_connect_t? connect
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_connect(tcp, host, port, callback) end

--- Establish an IPv4 or IPv6 TCP connection.
--- Example
--- ```lua
--- local client = uv.new_tcp()
--- client:connect("127.0.0.1", 8080, function (err)
---   -- check error and carry on.
--- end)
--- ```
--- @param host string
--- @param port integer
--- @param callback fun(err: string?)
--- @return uv.uv_connect_t? connect
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:connect(host, port, callback) end

--- @deprecated Please use `uv.stream_get_write_queue_size()` instead.
--- @param tcp uv.uv_tcp_t
function uv.tcp_write_queue_size(tcp) end

--- @deprecated Please use `uv.stream_get_write_queue_size()` instead.
function uv_tcp_t:write_queue_size() end

--- Resets a TCP connection by sending a RST packet. This is accomplished by setting
--- the SO_LINGER socket option with a linger interval of zero and then calling
--- `uv.close()`. Due to some platform inconsistencies, mixing of `uv.shutdown()`
--- and `uv.tcp_close_reset()` calls is not allowed.
--- @param tcp uv.uv_tcp_t
--- @param callback fun()?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tcp_close_reset(tcp, callback) end

--- Resets a TCP connection by sending a RST packet. This is accomplished by setting
--- the SO_LINGER socket option with a linger interval of zero and then calling
--- `uv.close()`. Due to some platform inconsistencies, mixing of `uv.shutdown()`
--- and `uv.tcp_close_reset()` calls is not allowed.
--- @param callback fun()?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_tcp_t:close_reset(callback) end

--- Create a pair of connected sockets with the specified properties. The resulting handles can be passed to `uv.tcp_open`, used with `uv.spawn`, or for any other purpose.
---
--- See [Constants][] for supported `socktype` input values.
---
--- When `protocol` is set to 0 or nil, it will be automatically chosen based on the socket's domain and type. When `protocol` is specified as a string, it will be looked up using the `getprotobyname(3)` function (examples: `"ip"`, `"icmp"`, `"tcp"`, `"udp"`, etc).
---
--- Flags:
---  - `nonblock`: Opens the specified socket handle for `OVERLAPPED` or `FIONBIO`/`O_NONBLOCK` I/O usage. This is recommended for handles that will be used by libuv, and not usually recommended otherwise.
---
--- Equivalent to `socketpair(2)` with a domain of `AF_UNIX`.
--- Example
--- ```lua
--- -- Simple read/write with tcp
--- local fds = uv.socketpair(nil, nil, {nonblock=true}, {nonblock=true})
---
--- local sock1 = uv.new_tcp()
--- sock1:open(fds[1])
---
--- local sock2 = uv.new_tcp()
--- sock2:open(fds[2])
---
--- sock1:write("hello")
--- sock2:read_start(function(err, chunk)
---   assert(not err, err)
---   print(chunk)
--- end)
--- ```
--- @param socktype string|integer?
--- @param protocol string|integer?
--- @param flags1 { nonblock: boolean }?
--- @param flags2 { nonblock: boolean }?
--- @return [integer, integer]? fds
--- @return string? err
--- @return uv.error_name? err_name
function uv.socketpair(socktype, protocol, flags1, flags2) end


--- # `uv_pipe_t` - Pipe handle
---
--- > [`uv_handle_t`][] and [`uv_stream_t`][] functions also apply.
---
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
--- @class uv.uv_pipe_t : uv.uv_stream_t
local uv_pipe_t = {}

--- Creates and initializes a new `uv_pipe_t`. Returns the Lua userdata wrapping
--- it. The `ipc` argument is a boolean to indicate if this pipe will be used for
--- handle passing between processes.
--- @param ipc boolean?
--- @return uv.uv_pipe_t? pipe
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_pipe(ipc) end

--- Open an existing file descriptor or [`uv_handle_t`][] as a pipe.
--- **Note**:
--- The file descriptor is set to non-blocking mode.
--- @param pipe uv.uv_pipe_t
--- @param fd integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_open(pipe, fd) end

--- Open an existing file descriptor or [`uv_handle_t`][] as a pipe.
--- **Note**:
--- The file descriptor is set to non-blocking mode.
--- @param fd integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:open(fd) end

--- Bind the pipe to a file path (Unix) or a name (Windows).
--- **Note**:
--- Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- @param pipe uv.uv_pipe_t
--- @param name string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_bind(pipe, name) end

--- Bind the pipe to a file path (Unix) or a name (Windows).
--- **Note**:
--- Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- @param name string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:bind(name) end

--- Connect to the Unix domain socket or the named pipe.
--- **Note**:
--- Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- @param pipe uv.uv_pipe_t
--- @param name string
--- @param callback fun(err: string?)?
--- @return uv.uv_connect_t? connect
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_connect(pipe, name, callback) end

--- Connect to the Unix domain socket or the named pipe.
--- **Note**:
--- Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- @param name string
--- @param callback fun(err: string?)?
--- @return uv.uv_connect_t? connect
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:connect(name, callback) end

--- Get the name of the Unix domain socket or the named pipe.
--- @param pipe uv.uv_pipe_t
--- @return string? name
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_getsockname(pipe) end

--- Get the name of the Unix domain socket or the named pipe.
--- @return string? name
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:getsockname() end

--- Get the name of the Unix domain socket or the named pipe to which the handle is
--- connected.
--- @param pipe uv.uv_pipe_t
--- @return string? name
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_getpeername(pipe) end

--- Get the name of the Unix domain socket or the named pipe to which the handle is
--- connected.
--- @return string? name
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:getpeername() end

--- Set the number of pending pipe instance handles when the pipe server is waiting
--- for connections.
--- **Note**:
--- This setting applies to Windows only.
--- @param pipe uv.uv_pipe_t
--- @param count integer
function uv.pipe_pending_instances(pipe, count) end

--- Set the number of pending pipe instance handles when the pipe server is waiting
--- for connections.
--- **Note**:
--- This setting applies to Windows only.
--- @param count integer
function uv_pipe_t:pending_instances(count) end

--- Returns the pending pipe count for the named pipe.
--- @param pipe uv.uv_pipe_t
--- @return integer
function uv.pipe_pending_count(pipe) end

--- Returns the pending pipe count for the named pipe.
--- @return integer
function uv_pipe_t:pending_count() end

--- Used to receive handles over IPC pipes.
---
--- First - call `uv.pipe_pending_count()`, if it's > 0 then initialize a handle of
--- the given type, returned by `uv.pipe_pending_type()` and call
--- `uv.accept(pipe, handle)`.
--- @param pipe uv.uv_pipe_t
--- @return string
function uv.pipe_pending_type(pipe) end

--- Used to receive handles over IPC pipes.
---
--- First - call `uv.pipe_pending_count()`, if it's > 0 then initialize a handle of
--- the given type, returned by `uv.pipe_pending_type()` and call
--- `uv.accept(pipe, handle)`.
--- @return string
function uv_pipe_t:pending_type() end

--- Alters pipe permissions, allowing it to be accessed from processes run by different users.
--- Makes the pipe writable or readable by all users. `flags` are: `"r"`, `"w"`, `"rw"`, or `"wr"`
--- where `r` is `READABLE` and `w` is `WRITABLE`. This function is blocking.
--- @param pipe uv.uv_pipe_t
--- @param flags string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_chmod(pipe, flags) end

--- Alters pipe permissions, allowing it to be accessed from processes run by different users.
--- Makes the pipe writable or readable by all users. `flags` are: `"r"`, `"w"`, `"rw"`, or `"wr"`
--- where `r` is `READABLE` and `w` is `WRITABLE`. This function is blocking.
--- @param flags string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:chmod(flags) end

--- @class uv.pipe.fds
---
--- (file descriptor)
--- @field read integer
---
--- (file descriptor)
--- @field write integer

--- Create a pair of connected pipe handles. Data may be written to the `write` fd and read from the `read` fd. The resulting handles can be passed to `pipe_open`, used with `spawn`, or for any other purpose.
---
--- Flags:
---  - `nonblock`: Opens the specified socket handle for `OVERLAPPED` or `FIONBIO`/`O_NONBLOCK` I/O usage. This is recommended for handles that will be used by libuv, and not usually recommended otherwise.
---
--- Equivalent to `pipe(2)` with the `O_CLOEXEC` flag set.
--- Example
--- ```lua
--- -- Simple read/write with pipe_open
--- local fds = uv.pipe({nonblock=true}, {nonblock=true})
---
--- local read_pipe = uv.new_pipe()
--- read_pipe:open(fds.read)
---
--- local write_pipe = uv.new_pipe()
--- write_pipe:open(fds.write)
---
--- write_pipe:write("hello")
--- read_pipe:read_start(function(err, chunk)
---   assert(not err, err)
---   print(chunk)
--- end)
--- ```
--- @param read_flags { nonblock: boolean }?
--- @param write_flags { nonblock: boolean }?
--- @return uv.pipe.fds? fds
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe(read_flags, write_flags) end

--- Bind the pipe to a file path (Unix) or a name (Windows).
---
--- `Flags`:
---
--- - If `type(flags)` is `number`, it must be `0` or `uv.constants.PIPE_NO_TRUNCATE`.
--- - If `type(flags)` is `table`, it must be `{}` or `{ no_truncate = true|false }`.
--- - If `type(flags)` is `nil`, it use default value `0`.
--- - Returns `EINVAL` for unsupported flags without performing the bind operation.
---
--- Supports Linux abstract namespace sockets. namelen must include the leading '\0' byte but not the trailing nul byte.
--- **Note**:
--- 1. Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- 2. New in version 1.46.0.
--- @param pipe uv.uv_pipe_t
--- @param name string
--- @param flags integer|table?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_bind2(pipe, name, flags) end

--- Bind the pipe to a file path (Unix) or a name (Windows).
---
--- `Flags`:
---
--- - If `type(flags)` is `number`, it must be `0` or `uv.constants.PIPE_NO_TRUNCATE`.
--- - If `type(flags)` is `table`, it must be `{}` or `{ no_truncate = true|false }`.
--- - If `type(flags)` is `nil`, it use default value `0`.
--- - Returns `EINVAL` for unsupported flags without performing the bind operation.
---
--- Supports Linux abstract namespace sockets. namelen must include the leading '\0' byte but not the trailing nul byte.
--- **Note**:
--- 1. Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- 2. New in version 1.46.0.
--- @param name string
--- @param flags integer|table?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:bind2(name, flags) end

--- Connect to the Unix domain socket or the named pipe.
---
--- `Flags`:
---
--- - If `type(flags)` is `number`, it must be `0` or `uv.constants.PIPE_NO_TRUNCATE`.
--- - If `type(flags)` is `table`, it must be `{}` or `{ no_truncate = true|false }`.
--- - If `type(flags)` is `nil`, it use default value `0`.
--- - Returns `EINVAL` for unsupported flags without performing the bind operation.
---
--- Supports Linux abstract namespace sockets. namelen must include the leading nul byte but not the trailing nul byte.
--- **Note**:
--- 1. Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- 2. New in version 1.46.0.
--- @param pipe uv.uv_pipe_t
--- @param name string
--- @param flags integer|table?
--- @param callback fun(err: string?)?
--- @return uv.uv_connect_t? connect
--- @return string? err
--- @return uv.error_name? err_name
function uv.pipe_connect2(pipe, name, flags, callback) end

--- Connect to the Unix domain socket or the named pipe.
---
--- `Flags`:
---
--- - If `type(flags)` is `number`, it must be `0` or `uv.constants.PIPE_NO_TRUNCATE`.
--- - If `type(flags)` is `table`, it must be `{}` or `{ no_truncate = true|false }`.
--- - If `type(flags)` is `nil`, it use default value `0`.
--- - Returns `EINVAL` for unsupported flags without performing the bind operation.
---
--- Supports Linux abstract namespace sockets. namelen must include the leading nul byte but not the trailing nul byte.
--- **Note**:
--- 1. Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
--- 2. New in version 1.46.0.
--- @param name string
--- @param flags integer|table?
--- @param callback fun(err: string?)?
--- @return uv.uv_connect_t? connect
--- @return string? err
--- @return uv.error_name? err_name
function uv_pipe_t:connect2(name, flags, callback) end


--- # `uv_tty_t` - TTY handle
---
--- > [`uv_handle_t`][] and [`uv_stream_t`][] functions also apply.
---
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
--- @class uv.uv_tty_t : uv.uv_stream_t
local uv_tty_t = {}

--- Initialize a new TTY stream with the given file descriptor. Usually the file
--- descriptor will be:
---
---  - 0 - stdin
---  - 1 - stdout
---  - 2 - stderr
---
--- On Unix this function will determine the path of the fd of the terminal using
--- ttyname_r(3), open it, and use it if the passed file descriptor refers to a TTY.
--- This lets libuv put the tty in non-blocking mode without affecting other
--- processes that share the tty.
---
--- This function is not thread safe on systems that don’t support ioctl TIOCGPTN or TIOCPTYGNAME, for instance OpenBSD and Solaris.
--- **Note**:
--- If reopening the TTY fails, libuv falls back to blocking writes.
--- @param fd integer
--- @param readable boolean
--- @return uv.uv_tty_t? tty
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_tty(fd, readable) end

--- Set the TTY using the specified terminal mode.
---
--- See [Constants][] for supported TTY mode input values.
--- @param tty uv.uv_tty_t
--- @param mode string|integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tty_set_mode(tty, mode) end

--- Set the TTY using the specified terminal mode.
---
--- See [Constants][] for supported TTY mode input values.
--- @param mode string|integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_tty_t:set_mode(mode) end

--- To be called when the program exits. Resets TTY settings to default values for
--- the next process to take over.
---
--- This function is async signal-safe on Unix platforms but can fail with error
--- code `EBUSY` if you call it when execution is inside `uv.tty_set_mode()`.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.tty_reset_mode() end

--- Gets the current Window width and height.
--- @param tty uv.uv_tty_t
--- @return integer? width
--- @return integer|string height_or_err
--- @return uv.error_name? err_name
function uv.tty_get_winsize(tty) end

--- Gets the current Window width and height.
--- @return integer? width
--- @return integer|string height_or_err
--- @return uv.error_name? err_name
function uv_tty_t:get_winsize() end

--- Controls whether console virtual terminal sequences are processed by libuv or
--- console. Useful in particular for enabling ConEmu support of ANSI X3.64 and
--- Xterm 256 colors. Otherwise Windows10 consoles are usually detected
--- automatically. State should be one of: `"supported"` or `"unsupported"`.
---
--- This function is only meaningful on Windows systems. On Unix it is silently
--- ignored.
--- @param state string
function uv.tty_set_vterm_state(state) end

--- Get the current state of whether console virtual terminal sequences are handled
--- by libuv or the console. The return value is `"supported"` or `"unsupported"`.
---
--- This function is not implemented on Unix, where it returns `ENOTSUP`.
--- @return string? state
--- @return string? err
--- @return uv.error_name? err_name
function uv.tty_get_vterm_state() end


--- # `uv_udp_t` - UDP handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- UDP handles encapsulate UDP communication for both clients and servers.
--- @class uv.uv_udp_t : uv.uv_handle_t
local uv_udp_t = {}

--- Creates and initializes a new `uv_udp_t`. Returns the Lua userdata wrapping
--- it. The actual socket is created lazily.
---
--- See [Constants][] for supported address `family` input values.
---
--- When specified, `mmsgs` determines the number of messages able to be received
--- at one time via `recvmmsg(2)` (the allocated buffer will be sized to be able
--- to fit the specified number of max size dgrams). Only has an effect on
--- platforms that support `recvmmsg(2)`.
---
--- **Note:** For backwards compatibility reasons, `flags` can also be a string or
--- integer. When it is a string, it will be treated like the `family` key above.
--- When it is an integer, it will be used directly as the `flags` parameter when
--- calling `uv_udp_init_ex`.
--- @param flags { family: string?, mmsgs: integer? }?
--- @return uv.uv_udp_t? udp
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_udp(flags) end

--- Returns the handle's send queue size.
--- @param udp uv.uv_udp_t
--- @return integer
function uv.udp_get_send_queue_size(udp) end

--- Returns the handle's send queue size.
--- @return integer
function uv_udp_t:get_send_queue_size() end

--- Returns the handle's send queue count.
--- @param udp uv.uv_udp_t
--- @return integer
function uv.udp_get_send_queue_count(udp) end

--- Returns the handle's send queue count.
--- @return integer
function uv_udp_t:get_send_queue_count() end

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
--- @param udp uv.uv_udp_t
--- @param fd integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_open(udp, fd) end

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
--- @param fd integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:open(fd) end

--- Bind the UDP handle to an IP address and port. Any `flags` are set with a table
--- with fields `reuseaddr` or `ipv6only` equal to `true` or `false`.
--- @param udp uv.uv_udp_t
--- @param host string
--- @param port number
--- @param flags { ipv6only: boolean?, reuseaddr: boolean? }?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_bind(udp, host, port, flags) end

--- Bind the UDP handle to an IP address and port. Any `flags` are set with a table
--- with fields `reuseaddr` or `ipv6only` equal to `true` or `false`.
--- @param host string
--- @param port number
--- @param flags { ipv6only: boolean?, reuseaddr: boolean? }?
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:bind(host, port, flags) end

--- Get the local IP and port of the UDP handle.
--- @param udp uv.uv_udp_t
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_getsockname(udp) end

--- Get the local IP and port of the UDP handle.
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:getsockname() end

--- Get the remote IP and port of the UDP handle on connected UDP handles.
--- @param udp uv.uv_udp_t
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_getpeername(udp) end

--- Get the remote IP and port of the UDP handle on connected UDP handles.
--- @return uv.socketinfo? address
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:getpeername() end

--- Set membership for a multicast address. `multicast_addr` is multicast address to
--- set membership for. `interface_addr` is interface address. `membership` can be
--- the string `"leave"` or `"join"`.
--- @param udp uv.uv_udp_t
--- @param multicast_addr string
--- @param interface_addr string?
--- @param membership string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_set_membership(udp, multicast_addr, interface_addr, membership) end

--- Set membership for a multicast address. `multicast_addr` is multicast address to
--- set membership for. `interface_addr` is interface address. `membership` can be
--- the string `"leave"` or `"join"`.
--- @param multicast_addr string
--- @param interface_addr string?
--- @param membership string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:set_membership(multicast_addr, interface_addr, membership) end

--- Set membership for a source-specific multicast group. `multicast_addr` is multicast
--- address to set membership for. `interface_addr` is interface address. `source_addr`
--- is source address. `membership` can be the string `"leave"` or `"join"`.
--- @param udp uv.uv_udp_t
--- @param multicast_addr string
--- @param interface_addr string?
--- @param source_addr string
--- @param membership string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_set_source_membership(udp, multicast_addr, interface_addr, source_addr, membership) end

--- Set membership for a source-specific multicast group. `multicast_addr` is multicast
--- address to set membership for. `interface_addr` is interface address. `source_addr`
--- is source address. `membership` can be the string `"leave"` or `"join"`.
--- @param multicast_addr string
--- @param interface_addr string?
--- @param source_addr string
--- @param membership string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:set_source_membership(multicast_addr, interface_addr, source_addr, membership) end

--- Set IP multicast loop flag. Makes multicast packets loop back to local
--- sockets.
--- @param udp uv.uv_udp_t
--- @param on boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_set_multicast_loop(udp, on) end

--- Set IP multicast loop flag. Makes multicast packets loop back to local
--- sockets.
--- @param on boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:set_multicast_loop(on) end

--- Set the multicast ttl.
---
--- `ttl` is an integer 1 through 255.
--- @param udp uv.uv_udp_t
--- @param ttl integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_set_multicast_ttl(udp, ttl) end

--- Set the multicast ttl.
---
--- `ttl` is an integer 1 through 255.
--- @param ttl integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:set_multicast_ttl(ttl) end

--- Set the multicast interface to send or receive data on.
--- @param udp uv.uv_udp_t
--- @param interface_addr string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_set_multicast_interface(udp, interface_addr) end

--- Set the multicast interface to send or receive data on.
--- @param interface_addr string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:set_multicast_interface(interface_addr) end

--- Set broadcast on or off.
--- @param udp uv.uv_udp_t
--- @param on boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_set_broadcast(udp, on) end

--- Set broadcast on or off.
--- @param on boolean
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:set_broadcast(on) end

--- Set the time to live.
---
--- `ttl` is an integer 1 through 255.
--- @param udp uv.uv_udp_t
--- @param ttl integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_set_ttl(udp, ttl) end

--- Set the time to live.
---
--- `ttl` is an integer 1 through 255.
--- @param ttl integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:set_ttl(ttl) end

--- Send data over the UDP socket. If the socket has not previously been bound
--- with `uv.udp_bind()` it will be bound to `0.0.0.0` (the "all interfaces" IPv4
--- address) and a random port number.
--- @param udp uv.uv_udp_t
--- @param data uv.buffer
--- @param host string
--- @param port integer
--- @param callback fun(err: string?)
--- @return uv.uv_udp_send_t? send
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_send(udp, data, host, port, callback) end

--- Send data over the UDP socket. If the socket has not previously been bound
--- with `uv.udp_bind()` it will be bound to `0.0.0.0` (the "all interfaces" IPv4
--- address) and a random port number.
--- @param data uv.buffer
--- @param host string
--- @param port integer
--- @param callback fun(err: string?)
--- @return uv.uv_udp_send_t? send
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:send(data, host, port, callback) end

--- Same as `uv.udp_send()`, but won't queue a send request if it can't be
--- completed immediately.
--- @param udp uv.uv_udp_t
--- @param data uv.buffer
--- @param host string
--- @param port integer
--- @return integer? bytes_sent
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_try_send(udp, data, host, port) end

--- Same as `uv.udp_send()`, but won't queue a send request if it can't be
--- completed immediately.
--- @param data uv.buffer
--- @param host string
--- @param port integer
--- @return integer? bytes_sent
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:try_send(data, host, port) end

--- Like `uv.udp_try_send()`, but can send multiple datagrams.
--- Lightweight abstraction around `sendmmsg(2)`, with a `sendmsg(2)` fallback loop
--- for platforms that do not support the former. The `udp` handle must be fully
--- initialized, either from a `uv.udp_bind` call, another call that will bind
--- automatically (`udp_send`, `udp_try_send`, etc), or from `uv.udp_connect`.
---
--- `messages` should be an array-like table, where `addr` must be specified
--- if the `udp` has not been connected via `udp_connect`. Otherwise, `addr`
--- must be `nil`.
---
--- `flags` is reserved for future extension and must currently be `nil` or `0` or
--- `{}`.
---
--- Returns the number of messages sent successfully. An error will only be returned
--- if the first datagram failed to be sent.
--- Example
--- ```lua
--- -- If client:connect(...) was not called
--- local addr = { ip = "127.0.0.1", port = 1234 }
--- client:try_send2({
---   { data = "Message 1", addr = addr },
---   { data = "Message 2", addr = addr },
--- })
---
--- -- If client:connect(...) was called
--- client:try_send2({
---   { data = "Message 1" },
---   { data = "Message 2" },
--- })
--- ```
--- @param udp uv.uv_udp_t
--- @param messages table<integer, { data: uv.buffer, addr: { ip: string, port: integer } }>
--- @param flags 0|{}?
--- @param port integer
--- @return integer? messages_sent
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_try_send2(udp, messages, flags, port) end

--- Like `uv.udp_try_send()`, but can send multiple datagrams.
--- Lightweight abstraction around `sendmmsg(2)`, with a `sendmsg(2)` fallback loop
--- for platforms that do not support the former. The `udp` handle must be fully
--- initialized, either from a `uv.udp_bind` call, another call that will bind
--- automatically (`udp_send`, `udp_try_send`, etc), or from `uv.udp_connect`.
---
--- `messages` should be an array-like table, where `addr` must be specified
--- if the `udp` has not been connected via `udp_connect`. Otherwise, `addr`
--- must be `nil`.
---
--- `flags` is reserved for future extension and must currently be `nil` or `0` or
--- `{}`.
---
--- Returns the number of messages sent successfully. An error will only be returned
--- if the first datagram failed to be sent.
--- Example
--- ```lua
--- -- If client:connect(...) was not called
--- local addr = { ip = "127.0.0.1", port = 1234 }
--- client:try_send2({
---   { data = "Message 1", addr = addr },
---   { data = "Message 2", addr = addr },
--- })
---
--- -- If client:connect(...) was called
--- client:try_send2({
---   { data = "Message 1" },
---   { data = "Message 2" },
--- })
--- ```
--- @param messages table<integer, { data: uv.buffer, addr: { ip: string, port: integer } }>
--- @param flags 0|{}?
--- @param port integer
--- @return integer? messages_sent
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:try_send2(messages, flags, port) end

--- @alias uv.udp_recv_start.callback
--- | fun(err: string?, data: string?, addr: uv.udp_recv_start.callback.addr?, flags: { partial: boolean?, mmsg_chunk: boolean? })

--- @class uv.udp_recv_start.callback.addr
--- @field ip string
--- @field port integer
--- @field family string

--- Prepare for receiving data. If the socket has not previously been bound with
--- `uv.udp_bind()` it is bound to `0.0.0.0` (the "all interfaces" IPv4 address)
--- and a random port number.
---
--- See [Constants][] for supported address `family` output values.
--- @param udp uv.uv_udp_t
--- @param callback uv.udp_recv_start.callback
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_recv_start(udp, callback) end

--- Prepare for receiving data. If the socket has not previously been bound with
--- `uv.udp_bind()` it is bound to `0.0.0.0` (the "all interfaces" IPv4 address)
--- and a random port number.
---
--- See [Constants][] for supported address `family` output values.
--- @param callback uv.udp_recv_start.callback
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:recv_start(callback) end

--- Stop listening for incoming datagrams.
--- @param udp uv.uv_udp_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_recv_stop(udp) end

--- Stop listening for incoming datagrams.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:recv_stop() end

--- Associate the UDP handle to a remote address and port, so every message sent by
--- this handle is automatically sent to that destination. Calling this function
--- with a NULL addr disconnects the handle. Trying to call `uv.udp_connect()` on an
--- already connected handle will result in an `EISCONN` error. Trying to disconnect
--- a handle that is not connected will return an `ENOTCONN` error.
--- @param udp uv.uv_udp_t
--- @param host string
--- @param port integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.udp_connect(udp, host, port) end

--- Associate the UDP handle to a remote address and port, so every message sent by
--- this handle is automatically sent to that destination. Calling this function
--- with a NULL addr disconnects the handle. Trying to call `uv.udp_connect()` on an
--- already connected handle will result in an `EISCONN` error. Trying to disconnect
--- a handle that is not connected will return an `ENOTCONN` error.
--- @param host string
--- @param port integer
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_udp_t:connect(host, port) end


--- # `uv_fs_event_t` - FS Event handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- FS Event handles allow the user to monitor a given path for changes, for
--- example, if the file was renamed or there was a generic change in it. This
--- handle uses the best backend for the job on each platform.
--- @class uv.uv_fs_event_t : uv.uv_handle_t
local uv_fs_event_t = {}

--- Creates and initializes a new `uv_fs_event_t`. Returns the Lua userdata wrapping
--- it.
--- @return uv.uv_fs_event_t? fs_event
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_fs_event() end

--- @alias uv.fs_event_start.callback
--- | fun(err: string?, filename: string, events: { change: boolean?, rename: boolean? })

--- @class uv.fs_event_start.flags
--- @field watch_entry boolean?
--- @field stat boolean?
--- @field recursive boolean?

--- Start the handle with the given callback, which will watch the specified path
--- for changes.
--- @param fs_event uv.uv_fs_event_t
--- @param path string
--- @param flags uv.fs_event_start.flags
--- @param callback uv.fs_event_start.callback
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.fs_event_start(fs_event, path, flags, callback) end

--- Start the handle with the given callback, which will watch the specified path
--- for changes.
--- @param path string
--- @param flags uv.fs_event_start.flags
--- @param callback uv.fs_event_start.callback
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_fs_event_t:start(path, flags, callback) end

--- Stop the handle, the callback will no longer be called.
--- @param fs_event uv.uv_fs_event_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.fs_event_stop(fs_event) end

--- Stop the handle, the callback will no longer be called.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_fs_event_t:stop() end

--- Get the path being monitored by the handle.
--- @param fs_event uv.uv_fs_event_t
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv.fs_event_getpath(fs_event) end

--- Get the path being monitored by the handle.
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv_fs_event_t:getpath() end


--- # `uv_fs_poll_t` - FS Poll handle
---
--- > [`uv_handle_t`][] functions also apply.
---
--- FS Poll handles allow the user to monitor a given path for changes. Unlike
--- `uv_fs_event_t`, fs poll handles use `stat` to detect when a file has changed so
--- they can work on file systems where fs event handles can't.
--- @class uv.uv_fs_poll_t : uv.uv_handle_t
local uv_fs_poll_t = {}

--- Creates and initializes a new `uv_fs_poll_t`. Returns the Lua userdata wrapping
--- it.
--- @return uv.uv_fs_poll_t? fs_poll
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_fs_poll() end

--- @alias uv.fs_poll_start.callback
--- | fun(err: string?, prev: table?, curr: table?)

--- Check the file at `path` for changes every `interval` milliseconds.
---
--- **Note:** For maximum portability, use multi-second intervals. Sub-second
--- intervals will not detect all changes on many file systems.
--- @param fs_poll uv.uv_fs_poll_t
--- @param path string
--- @param interval integer
--- @param callback uv.fs_poll_start.callback
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.fs_poll_start(fs_poll, path, interval, callback) end

--- Check the file at `path` for changes every `interval` milliseconds.
---
--- **Note:** For maximum portability, use multi-second intervals. Sub-second
--- intervals will not detect all changes on many file systems.
--- @param path string
--- @param interval integer
--- @param callback uv.fs_poll_start.callback
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_fs_poll_t:start(path, interval, callback) end

--- Stop the handle, the callback will no longer be called.
--- @param fs_poll uv.uv_fs_poll_t
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.fs_poll_stop(fs_poll) end

--- Stop the handle, the callback will no longer be called.
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv_fs_poll_t:stop() end

--- Get the path being monitored by the handle.
--- @param fs_poll uv.uv_fs_poll_t
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv.fs_poll_getpath(fs_poll) end

--- Get the path being monitored by the handle.
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv_fs_poll_t:getpath() end


--- # File system operations
---
--- Most file system functions can operate synchronously or asynchronously. When a synchronous version is called (by omitting a callback), the function will
--- immediately return the results of the FS call. When an asynchronous version is
--- called (by providing a callback), the function will immediately return a
--- `uv_fs_t userdata` and asynchronously execute its callback; if an error is encountered, the first and only argument passed to the callback will be the `err` error string; if the operation completes successfully, the first argument will be `nil` and the remaining arguments will be the results of the FS call.
---
--- Synchronous and asynchronous versions of `readFile` (with naive error handling)
--- are implemented below as an example:
---
--- ```lua
--- local function readFileSync(path)
---   local fd = assert(uv.fs_open(path, "r", 438))
---   local stat = assert(uv.fs_fstat(fd))
---   local data = assert(uv.fs_read(fd, stat.size, 0))
---   assert(uv.fs_close(fd))
---   return data
--- end
---
--- local data = readFileSync("main.lua")
--- print("synchronous read", data)
--- ```
---
--- ```lua
--- local function readFile(path, callback)
---   uv.fs_open(path, "r", 438, function(err, fd)
---     assert(not err, err)
---     uv.fs_fstat(fd, function(err, stat)
---       assert(not err, err)
---       uv.fs_read(fd, stat.size, 0, function(err, data)
---         assert(not err, err)
---         uv.fs_close(fd, function(err)
---           assert(not err, err)
---           return callback(data)
---         end)
---       end)
---     end)
---   end)
--- end
---
--- readFile("main.lua", function(data)
---   print("asynchronous read", data)
--- end)
--- ```

--- Equivalent to `close(2)`.
--- @param fd integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_close(fd) end

--- Equivalent to `open(2)`. Access `flags` may be an integer or one of: `"r"`,
--- `"rs"`, `"sr"`, `"r+"`, `"rs+"`, `"sr+"`, `"w"`, `"wx"`, `"xw"`, `"w+"`,
--- `"wx+"`, `"xw+"`, `"a"`, `"ax"`, `"xa"`, `"a+"`, `"ax+"`, or "`xa+`".
--- **Note**:
--- On Windows, libuv uses `CreateFileW` and thus the file is always
--- opened in binary mode. Because of this, the `O_BINARY` and `O_TEXT` flags are
--- not supported.
--- @param path string
--- @param flags string|integer
--- @param mode integer (octal `chmod(1)` mode, e.g. `tonumber('644', 8)`)
--- @return integer? fd
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, flags: string|integer, mode: integer, callback: fun(err: string?, fd: integer?)): uv.uv_fs_t
function uv.fs_open(path, flags, mode) end

--- Equivalent to `preadv(2)`. Returns any data. An empty string indicates EOF.
---
--- If `offset` is nil or omitted, it will default to `-1`, which indicates 'use and update the current file offset.'
---
--- **Note:** When `offset` is >= 0, the current file offset will not be updated by the read.
--- @param fd integer
--- @param size integer
--- @param offset integer?
--- @return string? data
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, size: integer, offset: integer?, callback: fun(err: string?, data: string?)): uv.uv_fs_t
function uv.fs_read(fd, size, offset) end

--- Equivalent to `unlink(2)`.
--- @param path string
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_unlink(path) end

--- Equivalent to `pwritev(2)`. Returns the number of bytes written.
---
--- If `offset` is nil or omitted, it will default to `-1`, which indicates 'use and update the current file offset.'
---
--- **Note:** When `offset` is >= 0, the current file offset will not be updated by the write.
--- @param fd integer
--- @param data uv.buffer
--- @param offset integer?
--- @return integer? bytes_written
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, data: uv.buffer, offset: integer?, callback: fun(err: string?, bytes: integer?)): uv.uv_fs_t
function uv.fs_write(fd, data, offset) end

--- Equivalent to `mkdir(2)`.
--- @param path string
--- @param mode integer (octal `chmod(1)` mode, e.g. `tonumber('755', 8)`)
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, mode: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_mkdir(path, mode) end

--- Equivalent to `mkdtemp(3)`.
--- @param template string
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(template: string, callback: fun(err: string?, path: string?)): uv.uv_fs_t
function uv.fs_mkdtemp(template) end

--- @alias uv.fs_mkstemp.callback
--- | fun(err: string?, fd: integer?, path: string?)

--- Equivalent to `mkstemp(3)`. Returns a temporary file handle and filename.
--- @param template string
--- @return integer? fd
--- @return string path_or_err
--- @return uv.error_name? err_name
--- @overload fun(template: string, callback: uv.fs_mkstemp.callback): uv.uv_fs_t
function uv.fs_mkstemp(template) end

--- Equivalent to `rmdir(2)`.
--- @param path string
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_rmdir(path) end

--- Equivalent to `scandir(3)`, with a slightly different API. Returns a handle that
--- the user can pass to `uv.fs_scandir_next()`.
---
--- **Note:** This function can be used synchronously or asynchronously. The request
--- userdata is always synchronously returned regardless of whether a callback is
--- provided and the same userdata is passed to the callback if it is provided.
--- @param path string
--- @param callback fun(err: string?, success: uv.uv_fs_t?)?
--- @return uv.uv_fs_t? handle
--- @return string? err
--- @return uv.error_name? err_name
function uv.fs_scandir(path, callback) end

--- Called on a `uv_fs_t` returned by `uv.fs_scandir()` to get the next directory
--- entry data as a `name, type` pair. When there are no more entries, `nil` is
--- returned.
---
--- **Note:** This function only has a synchronous version. See `uv.fs_opendir` and
--- its related functions for an asynchronous version.
--- @param fs uv.uv_fs_t
--- @return string? name
--- @return string type_or_err
--- @return uv.error_name? err_name
function uv.fs_scandir_next(fs) end

--- @class uv.fs_stat.result
--- @field dev integer
--- @field mode integer
--- @field nlink integer
--- @field uid integer
--- @field gid integer
--- @field rdev integer
--- @field ino integer
--- @field size integer
--- @field blksize integer
--- @field blocks integer
--- @field flags integer
--- @field gen integer
--- @field atime uv.fs_stat.result.time
--- @field mtime uv.fs_stat.result.time
--- @field ctime uv.fs_stat.result.time
--- @field birthtime uv.fs_stat.result.time
--- @field type string

--- @class uv.fs_stat.result.time
--- @field sec integer
--- @field nsec integer

--- @class uv.fs_statfs.result
--- @field type integer
--- @field bsize integer
--- @field blocks integer
--- @field bfree integer
--- @field bavail integer
--- @field files integer
--- @field ffree integer

--- Equivalent to `stat(2)`.
--- @param path string
--- @return uv.fs_stat.result? stat
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, stat: uv.fs_stat.result?)): uv.uv_fs_t
function uv.fs_stat(path) end

--- Equivalent to `fstat(2)`.
--- @param fd integer
--- @return uv.fs_stat.result? stat
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, callback: fun(err: string?, stat: uv.fs_stat.result?)): uv.uv_fs_t
function uv.fs_fstat(fd) end

--- Equivalent to `lstat(2)`.
--- @param path string
--- @return uv.fs_stat.result? stat
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, stat: uv.fs_stat.result?)): uv.uv_fs_t
function uv.fs_lstat(path) end

--- Equivalent to `rename(2)`.
--- @param path string
--- @param new_path string
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, new_path: string, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_rename(path, new_path) end

--- Equivalent to `fsync(2)`.
--- @param fd integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_fsync(fd) end

--- Equivalent to `fdatasync(2)`.
--- @param fd integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_fdatasync(fd) end

--- Equivalent to `ftruncate(2)`.
--- @param fd integer
--- @param offset integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, offset: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_ftruncate(fd, offset) end

--- Limited equivalent to `sendfile(2)`. Returns the number of bytes written.
--- @param out_fd integer
--- @param in_fd integer
--- @param in_offset integer
--- @param size integer
--- @return integer? bytes
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(out_fd: integer, in_fd: integer, in_offset: integer, size: integer, callback: fun(err: string?, bytes: integer?)): uv.uv_fs_t
function uv.fs_sendfile(out_fd, in_fd, in_offset, size) end

--- Equivalent to `access(2)` on Unix. Windows uses `GetFileAttributesW()`. Access
--- `mode` can be an integer or a string containing `"R"` or `"W"` or `"X"`.
--- Returns `true` or `false` indicating access permission.
--- @param path string
--- @param mode string (a combination of the `'r'`, `'w'` and `'x'` characters denoting the symbolic mode as per `chmod(1)`)
--- @return boolean? permission
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, mode: string, callback: fun(err: string?, permission: boolean?)): uv.uv_fs_t
function uv.fs_access(path, mode) end

--- Equivalent to `chmod(2)`.
--- @param path string
--- @param mode integer (octal `chmod(1)` mode, e.g. `tonumber('644', 8)`)
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, mode: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_chmod(path, mode) end

--- Equivalent to `fchmod(2)`.
--- @param fd integer
--- @param mode integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, mode: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_fchmod(fd, mode) end

--- Equivalent to `utime(2)`.
---
--- See [Constants][] for supported FS Modification Time constants.
---
--- Passing `"now"` or `uv.constants.FS_UTIME_NOW` as the atime or mtime sets the timestamp to the
--- current time.
---
--- Passing `nil`, `"omit"`, or `uv.constants.FS_UTIME_OMIT` as the atime or mtime leaves the timestamp
--- untouched.
--- @param path string
--- @param atime number|string?
--- @param mtime number|string?
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, atime: number|string?, mtime: number|string?, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_utime(path, atime, mtime) end

--- Equivalent to `futimes(3)`.
---
--- See [Constants][] for supported FS Modification Time constants.
---
--- Passing `"now"` or `uv.constants.FS_UTIME_NOW` as the atime or mtime sets the timestamp to the
--- current time.
---
--- Passing `nil`, `"omit"`, or `uv.constants.FS_UTIME_OMIT` as the atime or mtime leaves the timestamp
--- untouched.
--- @param fd integer
--- @param atime number|string?
--- @param mtime number|string?
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, atime: number|string?, mtime: number|string?, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_futime(fd, atime, mtime) end

--- Equivalent to `lutimes(3)`.
---
--- See [Constants][] for supported FS Modification Time constants.
---
--- Passing `"now"` or `uv.constants.FS_UTIME_NOW` as the atime or mtime sets the timestamp to the
--- current time.
---
--- Passing `nil`, `"omit"`, or `uv.constants.FS_UTIME_OMIT` as the atime or mtime leaves the timestamp
--- untouched.
--- @param path string
--- @param atime number|string?
--- @param mtime number|string?
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, atime: number|string?, mtime: number|string?, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_lutime(path, atime, mtime) end

--- Equivalent to `link(2)`.
--- @param path string
--- @param new_path string
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, new_path: string, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_link(path, new_path) end

--- Equivalent to `symlink(2)`. If the `flags` parameter is omitted, then the 3rd parameter will be treated as the `callback`.
--- @param path string
--- @param new_path string
--- @param flags integer|{ dir: boolean?, junction: boolean? }?
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, new_path: string, flags: integer|{ dir: boolean?, junction: boolean? }?, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_symlink(path, new_path, flags) end

--- Equivalent to `readlink(2)`.
--- @param path string
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, path: string?)): uv.uv_fs_t
function uv.fs_readlink(path) end

--- Equivalent to `realpath(3)`.
--- @param path string
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, path: string?)): uv.uv_fs_t
function uv.fs_realpath(path) end

--- Equivalent to `chown(2)`.
--- @param path string
--- @param uid integer
--- @param gid integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, uid: integer, gid: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_chown(path, uid, gid) end

--- Equivalent to `fchown(2)`.
--- @param fd integer
--- @param uid integer
--- @param gid integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, uid: integer, gid: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_fchown(fd, uid, gid) end

--- Equivalent to `lchown(2)`.
--- @param fd integer
--- @param uid integer
--- @param gid integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(fd: integer, uid: integer, gid: integer, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_lchown(fd, uid, gid) end

--- @class uv.fs_copyfile.flags
--- @field excl boolean?
--- @field ficlone boolean?
--- @field ficlone_force boolean?

--- Copies a file from path to new_path. If the `flags` parameter is omitted, then the 3rd parameter will be treated as the `callback`.
--- @param path string
--- @param new_path string
--- @param flags integer|uv.fs_copyfile.flags?
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, new_path: string, flags: integer|uv.fs_copyfile.flags?, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_copyfile(path, new_path, flags) end

--- Opens path as a directory stream. Returns a handle that the user can pass to
--- `uv.fs_readdir()`. The `entries` parameter defines the maximum number of entries
--- that should be returned by each call to `uv.fs_readdir()`.
--- @param path string
--- @param entries integer?
--- @return uv.luv_dir_t? dir
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, dir: uv.luv_dir_t?), entries: integer?): uv.uv_fs_t
function uv.fs_opendir(path, entries) end

--- Iterates over the directory stream `luv_dir_t` returned by a successful
--- `uv.fs_opendir()` call. A table of data tables is returned where the number
--- of entries `n` is equal to or less than the `entries` parameter used in
--- the associated `uv.fs_opendir()` call.
--- @param dir uv.luv_dir_t
--- @return table<integer, { name: string, type: string  }>? entries
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(dir: uv.luv_dir_t, callback: fun(err: string?, entries: table<integer, { name: string, type: string }>?)): uv.uv_fs_t
function uv.fs_readdir(dir) end

--- @class uv.luv_dir_t : userdata
local luv_dir_t = {}

--- Iterates over the directory stream `luv_dir_t` returned by a successful
--- `uv.fs_opendir()` call. A table of data tables is returned where the number
--- of entries `n` is equal to or less than the `entries` parameter used in
--- the associated `uv.fs_opendir()` call.
--- @return table<integer, { name: string, type: string  }>? entries
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(dir: uv.luv_dir_t, callback: fun(err: string?, entries: table<integer, { name: string, type: string }>?)): uv.uv_fs_t
function luv_dir_t:readdir() end

--- Closes a directory stream returned by a successful `uv.fs_opendir()` call.
--- @param dir uv.luv_dir_t
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(dir: uv.luv_dir_t, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function uv.fs_closedir(dir) end

--- Closes a directory stream returned by a successful `uv.fs_opendir()` call.
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(dir: uv.luv_dir_t, callback: fun(err: string?, success: boolean?)): uv.uv_fs_t
function luv_dir_t:closedir() end

--- Equivalent to `statfs(2)`.
--- @param path string
--- @return uv.fs_statfs.result? stat
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(path: string, callback: fun(err: string?, stat: uv.fs_statfs.result?)): uv.uv_fs_t
function uv.fs_statfs(path) end


--- # Thread pool work scheduling
---
--- Libuv provides a threadpool which can be used to run user code and get notified
--- in the loop thread. This threadpool is internally used to run all file system
--- operations, as well as `getaddrinfo` and `getnameinfo` requests.
---
--- ```lua
--- local function work_callback(a, b)
---   return a + b
--- end
---
--- local function after_work_callback(c)
---   print("The result is: " .. c)
--- end
---
--- local work = uv.new_work(work_callback, after_work_callback)
---
--- work:queue(1, 2)
---
--- -- output: "The result is: 3"
--- ```

--- Creates and initializes a new `luv_work_ctx_t` (not `uv_work_t`).
--- `work_callback` is a Lua function or a string containing Lua code or bytecode dumped from a function.
--- Returns the Lua userdata wrapping it.
--- @param work_callback string|fun(...: uv.threadargs)
--- @param after_work_callback fun(...: uv.threadargs)
--- @return uv.luv_work_ctx_t
function uv.new_work(work_callback, after_work_callback) end

--- Queues a work request which will run `work_callback` in a new Lua state in a
--- thread from the threadpool with any additional arguments from `...`. Values
--- returned from `work_callback` are passed to `after_work_callback`, which is
--- called in the main loop thread.
--- @param work_ctx uv.luv_work_ctx_t
--- @param ... uv.threadargs
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.queue_work(work_ctx, ...) end

--- @class uv.luv_work_ctx_t : userdata
local luv_work_ctx_t = {}

--- Queues a work request which will run `work_callback` in a new Lua state in a
--- thread from the threadpool with any additional arguments from `...`. Values
--- returned from `work_callback` are passed to `after_work_callback`, which is
--- called in the main loop thread.
--- @param ... uv.threadargs
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function luv_work_ctx_t:queue(...) end


--- # DNS utility functions

--- @class uv.getaddrinfo.hints
--- @field family string|integer?
--- @field socktype string|integer?
--- @field protocol string|integer?
--- @field addrconfig boolean?
--- @field v4mapped boolean?
--- @field all boolean?
--- @field numerichost boolean?
--- @field passive boolean?
--- @field numericserv boolean?
--- @field canonname boolean?

--- Equivalent to `getaddrinfo(3)`. Either `node` or `service` may be `nil` but not
--- both.
---
--- See [Constants][] for supported address `family` input and output values.
---
--- See [Constants][] for supported `socktype` input and output values.
---
--- When `protocol` is set to 0 or nil, it will be automatically chosen based on the
--- socket's domain and type. When `protocol` is specified as a string, it will be
--- looked up using the `getprotobyname(3)` function. Examples: `"ip"`, `"icmp"`,
--- `"tcp"`, `"udp"`, etc.
--- @param host string?
--- @param service string?
--- @param hints uv.getaddrinfo.hints?
--- @return table<integer, uv.address>? addresses
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(host: string?, service: string?, hints: uv.getaddrinfo.hints?, callback: fun(err: string?, addresses: table<integer, uv.address>?)): uv.uv_getaddrinfo_t?, string?, uv.error_name?
function uv.getaddrinfo(host, service, hints) end

--- @class uv.getnameinfo.address
--- @field ip string?
--- @field port integer?
--- @field family string|integer?

--- @alias uv.getnameinfo.callback
--- | fun(err: string?, host: string?, service: string?)

--- Equivalent to `getnameinfo(3)`.
---
--- See [Constants][] for supported address `family` input values.
--- @param address uv.getnameinfo.address
--- @return string? host
--- @return string service_or_err
--- @return uv.error_name? err_name
--- @overload fun(address: uv.getnameinfo.address, callback: uv.getnameinfo.callback): uv.uv_getnameinfo_t?, string?, uv.error_name?
function uv.getnameinfo(address) end


--- # Threading and synchronization utilities
---
--- Libuv provides cross-platform implementations for multiple threading and
---  synchronization primitives. The API largely follows the pthreads API.

--- Creates and initializes a `luv_thread_t` (not `uv_thread_t`). Returns the Lua
--- userdata wrapping it and asynchronously executes `entry`, which can be either
--- a Lua function or a string containing Lua code or bytecode dumped from a function. Additional arguments `...`
--- are passed to the `entry` function and an optional `options` table may be
--- provided. Currently accepted `option` fields are `stack_size`.
--- **Note**:
--- unsafe, please make sure the thread end of life before Lua state close.
--- @param options { stack_size: integer? }?
--- @param entry function|string
--- @param ... uv.threadargs passed to `entry`
--- @return uv.luv_thread_t? thread
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_thread(options, entry, ...) end

--- Returns a boolean indicating whether two threads are the same. This function is
--- equivalent to the `__eq` metamethod.
--- @param thread uv.luv_thread_t
--- @param other_thread uv.luv_thread_t
--- @return boolean
function uv.thread_equal(thread, other_thread) end

--- @class uv.luv_thread_t : userdata
local luv_thread_t = {}

--- Returns a boolean indicating whether two threads are the same. This function is
--- equivalent to the `__eq` metamethod.
--- @param other_thread uv.luv_thread_t
--- @return boolean
function luv_thread_t:equal(other_thread) end

--- Sets the specified thread's affinity setting.
---
--- `affinity` must be a table where each of the keys are a CPU number and the
--- values are booleans that represent whether the `thread` should be eligible to
--- run on that CPU. If the length of the `affinity` table is not greater than or
--- equal to `uv.cpumask_size()`, any CPU numbers missing from the table will have
--- their affinity set to `false`. If setting the affinity of more than
--- `uv.cpumask_size()` CPUs is desired, `affinity` must be an array-like table
--- with no gaps, since `#affinity` will be used as the `cpumask_size` if it is
--- greater than `uv.cpumask_size()`.
---
--- If `get_old_affinity` is `true`, the previous affinity settings for the `thread`
--- will be returned. Otherwise, `true` is returned after a successful call.
---
--- **Note:** Thread affinity setting is not atomic on Windows. Unsupported on macOS.
--- @param thread uv.luv_thread_t
--- @param affinity table<integer, boolean>
--- @param get_old_affinity boolean?
--- @return table<integer, boolean>? affinity
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_setaffinity(thread, affinity, get_old_affinity) end

--- Sets the specified thread's affinity setting.
---
--- `affinity` must be a table where each of the keys are a CPU number and the
--- values are booleans that represent whether the `thread` should be eligible to
--- run on that CPU. If the length of the `affinity` table is not greater than or
--- equal to `uv.cpumask_size()`, any CPU numbers missing from the table will have
--- their affinity set to `false`. If setting the affinity of more than
--- `uv.cpumask_size()` CPUs is desired, `affinity` must be an array-like table
--- with no gaps, since `#affinity` will be used as the `cpumask_size` if it is
--- greater than `uv.cpumask_size()`.
---
--- If `get_old_affinity` is `true`, the previous affinity settings for the `thread`
--- will be returned. Otherwise, `true` is returned after a successful call.
---
--- **Note:** Thread affinity setting is not atomic on Windows. Unsupported on macOS.
--- @param affinity table<integer, boolean>
--- @param get_old_affinity boolean?
--- @return table<integer, boolean>? affinity
--- @return string? err
--- @return uv.error_name? err_name
function luv_thread_t:setaffinity(affinity, get_old_affinity) end

--- Gets the specified thread's affinity setting.
---
--- If `mask_size` is provided, it must be greater than or equal to
--- `uv.cpumask_size()`. If the `mask_size` parameter is omitted, then the return
--- of `uv.cpumask_size()` will be used. Returns an array-like table where each of
--- the keys correspond to a CPU number and the values are booleans that represent
--- whether the `thread` is eligible to run on that CPU.
---
--- **Note:** Thread affinity getting is not atomic on Windows. Unsupported on macOS.
--- @param thread uv.luv_thread_t
--- @param mask_size integer?
--- @return table<integer, boolean>? affinity
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_getaffinity(thread, mask_size) end

--- Gets the specified thread's affinity setting.
---
--- If `mask_size` is provided, it must be greater than or equal to
--- `uv.cpumask_size()`. If the `mask_size` parameter is omitted, then the return
--- of `uv.cpumask_size()` will be used. Returns an array-like table where each of
--- the keys correspond to a CPU number and the values are booleans that represent
--- whether the `thread` is eligible to run on that CPU.
---
--- **Note:** Thread affinity getting is not atomic on Windows. Unsupported on macOS.
--- @param mask_size integer?
--- @return table<integer, boolean>? affinity
--- @return string? err
--- @return uv.error_name? err_name
function luv_thread_t:getaffinity(mask_size) end

--- Gets the CPU number on which the calling thread is running.
---
--- **Note:** The first CPU will be returned as the number 1, not 0. This allows for
--- the number to correspond with the table keys used in `uv.thread_getaffinity` and
--- `uv.thread_setaffinity`.
--- @return integer? cpu
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_getcpu() end

--- Sets the specified thread's scheduling priority setting. It requires elevated
--- privilege to set specific priorities on some platforms.
---
--- The priority can be set to the following constants.
---
--- - uv.constants.THREAD_PRIORITY_HIGHEST
--- - uv.constants.THREAD_PRIORITY_ABOVE_NORMAL
--- - uv.constants.THREAD_PRIORITY_NORMAL
--- - uv.constants.THREAD_PRIORITY_BELOW_NORMAL
--- - uv.constants.THREAD_PRIORITY_LOWEST
--- @param thread uv.luv_thread_t
--- @param priority integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_setpriority(thread, priority) end

--- Sets the specified thread's scheduling priority setting. It requires elevated
--- privilege to set specific priorities on some platforms.
---
--- The priority can be set to the following constants.
---
--- - uv.constants.THREAD_PRIORITY_HIGHEST
--- - uv.constants.THREAD_PRIORITY_ABOVE_NORMAL
--- - uv.constants.THREAD_PRIORITY_NORMAL
--- - uv.constants.THREAD_PRIORITY_BELOW_NORMAL
--- - uv.constants.THREAD_PRIORITY_LOWEST
--- @param priority integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function luv_thread_t:setpriority(priority) end

--- Gets the  thread's priority setting.
---
--- Retrieves the scheduling priority of the specified thread. The returned priority
--- value is platform dependent.
---
--- For Linux, when schedule policy is SCHED_OTHER (default), priority is 0.
--- @param thread uv.luv_thread_t
--- @return integer? priority
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_getpriority(thread) end

--- Gets the  thread's priority setting.
---
--- Retrieves the scheduling priority of the specified thread. The returned priority
--- value is platform dependent.
---
--- For Linux, when schedule policy is SCHED_OTHER (default), priority is 0.
--- @return integer? priority
--- @return string? err
--- @return uv.error_name? err_name
function luv_thread_t:getpriority() end

--- Returns the handle for the thread in which this is called.
--- @return uv.luv_thread_t
function uv.thread_self() end

--- Waits for the `thread` to finish executing its entry function.
--- @param thread uv.luv_thread_t
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_join(thread) end

--- Waits for the `thread` to finish executing its entry function.
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function luv_thread_t:join() end

--- Detaches a thread. Detached threads automatically release their resources upon
--- termination, eliminating the need for the application to call `uv.thread_join`.
--- @param thread uv.luv_thread_t
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_detach(thread) end

--- Detaches a thread. Detached threads automatically release their resources upon
--- termination, eliminating the need for the application to call `uv.thread_join`.
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function luv_thread_t:detach() end

--- Sets the name of the current thread. Different platforms define different limits
--- on the max number of characters a thread name can be: Linux, IBM i (16), macOS
--- (64), Windows (32767), and NetBSD (32), etc. The name will be truncated
--- if `name` is larger than the limit of the platform.
--- @param name string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_setname(name) end

--- Gets the name of the thread specified by `thread`.
--- @param thread uv.luv_thread_t
--- @return string? name
--- @return string? err
--- @return uv.error_name? err_name
function uv.thread_getname(thread) end

--- Gets the name of the thread specified by `thread`.
--- @return string? name
--- @return string? err
--- @return uv.error_name? err_name
function luv_thread_t:getname() end

--- Pauses the thread in which this is called for a number of milliseconds.
--- @param msec integer
function uv.sleep(msec) end

--- Creates a new semaphore with the specified initial value. A semaphore is safe to
--- share across threads. It represents an unsigned integer value that can incremented
--- and decremented atomically but any attempt to make it negative will "wait" until
--- the value can be decremented by another thread incrementing it.
---
--- The initial value must be a non-negative integer.
--- **Note**:
--- A semaphore must be shared between threads, any `uv.sem_wait()` on a single thread that blocks will deadlock.
--- @param value integer?
--- @return uv.luv_sem_t? sem
--- @return string? err
--- @return uv.error_name? err_name
function uv.new_sem(value) end

--- Increments (unlocks) a semaphore, if the semaphore's value consequently becomes
--- greater than zero then another thread blocked in a sem_wait call will be woken
--- and proceed to decrement the semaphore.
--- @param sem uv.luv_sem_t
function uv.sem_post(sem) end

--- @class uv.luv_sem_t : userdata
local luv_sem_t = {}

--- Increments (unlocks) a semaphore, if the semaphore's value consequently becomes
--- greater than zero then another thread blocked in a sem_wait call will be woken
--- and proceed to decrement the semaphore.
function luv_sem_t:post() end

--- Decrements (locks) a semaphore, if the semaphore's value is greater than zero
--- then the value is decremented and the call returns immediately. If the semaphore's
--- value is zero then the call blocks until the semaphore's value rises above zero or
--- the call is interrupted by a signal.
--- @param sem uv.luv_sem_t
function uv.sem_wait(sem) end

--- Decrements (locks) a semaphore, if the semaphore's value is greater than zero
--- then the value is decremented and the call returns immediately. If the semaphore's
--- value is zero then the call blocks until the semaphore's value rises above zero or
--- the call is interrupted by a signal.
function luv_sem_t:wait() end

--- The same as `uv.sem_wait()` but returns immediately if the semaphore is not available.
---
--- If the semaphore's value was decremented then `true` is returned, otherwise the semaphore
--- has a value of zero and `false` is returned.
--- @param sem uv.luv_sem_t
--- @return boolean
function uv.sem_trywait(sem) end

--- The same as `uv.sem_wait()` but returns immediately if the semaphore is not available.
---
--- If the semaphore's value was decremented then `true` is returned, otherwise the semaphore
--- has a value of zero and `false` is returned.
--- @return boolean
function luv_sem_t:trywait() end


--- # Miscellaneous utilities

--- Returns the executable path.
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv.exepath() end

--- Returns the current working directory.
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv.cwd() end

--- Sets the current working directory with the string `cwd`.
--- @param cwd string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.chdir(cwd) end

--- Returns the title of the current process.
--- @return string? title
--- @return string? err
--- @return uv.error_name? err_name
function uv.get_process_title() end

--- Sets the title of the current process with the string `title`.
--- @param title string
--- @return 0? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.set_process_title(title) end

--- Returns the current total system memory in bytes.
--- @return number
function uv.get_total_memory() end

--- Returns the current free system memory in bytes.
--- @return number
function uv.get_free_memory() end

--- Gets the amount of memory available to the process in bytes based on limits
--- imposed by the OS. If there is no such constraint, or the constraint is unknown,
--- 0 is returned. Note that it is not unusual for this value to be less than or
--- greater than the total system memory.
--- @return number
function uv.get_constrained_memory() end

--- Gets the amount of free memory that is still available to the process (in
--- bytes). This differs from `uv.get_free_memory()` in that it takes into account
--- any limits imposed by the OS. If there is no such constraint, or the constraint
--- is unknown, the amount returned will be identical to `uv.get_free_memory()`.
--- @return number
function uv.get_available_memory() end

--- Returns the resident set size (RSS) for the current process.
--- @return integer? rss
--- @return string? err
--- @return uv.error_name? err_name
function uv.resident_set_memory() end

--- @class uv.getrusage.result
---
--- (user CPU time used)
--- @field utime uv.getrusage.result.time
---
--- (system CPU time used)
--- @field stime uv.getrusage.result.time
---
--- (maximum resident set size)
--- @field maxrss integer
---
--- (integral shared memory size)
--- @field ixrss integer
---
--- (integral unshared data size)
--- @field idrss integer
---
--- (integral unshared stack size)
--- @field isrss integer
---
--- (page reclaims (soft page faults))
--- @field minflt integer
---
--- (page faults (hard page faults))
--- @field majflt integer
---
--- (swaps)
--- @field nswap integer
---
--- (block input operations)
--- @field inblock integer
---
--- (block output operations)
--- @field oublock integer
---
--- (IPC messages sent)
--- @field msgsnd integer
---
--- (IPC messages received)
--- @field msgrcv integer
---
--- (signals received)
--- @field nsignals integer
---
--- (voluntary context switches)
--- @field nvcsw integer
---
--- (involuntary context switches)
--- @field nivcsw integer

--- @class uv.getrusage.result.time
--- @field sec integer
--- @field usec integer

--- Returns the resource usage.
--- @return uv.getrusage.result? rusage
--- @return string? err
--- @return uv.error_name? err_name
function uv.getrusage() end

--- Gets the resource usage measures for the calling thread.
---
--- **Note** Not supported on all platforms. May return `ENOTSUP`.
--- On macOS and Windows not all fields are set (the unsupported fields are filled
--- with zeroes).
--- @return uv.getrusage.result? rusage
--- @return string? err
--- @return uv.error_name? err_name
function uv.getrusage_thread() end

--- Returns an estimate of the default amount of parallelism a program should use. Always returns a non-zero value.
---
--- On Linux, inspects the calling thread’s CPU affinity mask to determine if it has been pinned to specific CPUs.
---
--- On Windows, the available parallelism may be underreported on systems with more than 64 logical CPUs.
---
--- On other platforms, reports the number of CPUs that the operating system considers to be online.
--- @return integer
function uv.available_parallelism() end

--- @class uv.cpu_info.cpu_info
--- @field model string
--- @field speed integer
--- @field times uv.cpu_info.cpu_info.times

--- @class uv.cpu_info.cpu_info.times
--- @field user integer
--- @field nice integer
--- @field sys integer
--- @field idle integer
--- @field irq integer

--- Returns information about the CPU(s) on the system as a table of tables for each
--- CPU found.
--- @return table<integer, uv.cpu_info.cpu_info>? cpu_info
--- @return string? err
--- @return uv.error_name? err_name
function uv.cpu_info() end

--- Returns the maximum size of the mask used for process/thread affinities, or
--- `ENOTSUP` if affinities are not supported on the current platform.
--- @return integer? size
--- @return string? err
--- @return uv.error_name? err_name
function uv.cpumask_size() end

--- @deprecated Please use `uv.os_getpid()` instead.
--- @return integer
function uv.getpid() end

--- Returns the user ID of the process.
--- **Note**:
--- This is not a libuv function and is not supported on Windows.
--- @return integer
function uv.getuid() end

--- Returns the group ID of the process.
--- **Note**:
--- This is not a libuv function and is not supported on Windows.
--- @return integer
function uv.getgid() end

--- Sets the user ID of the process with the integer `id`.
--- **Note**:
--- This is not a libuv function and is not supported on Windows.
--- @param id integer
function uv.setuid(id) end

--- Sets the group ID of the process with the integer `id`.
--- **Note**:
--- This is not a libuv function and is not supported on Windows.
--- @param id integer
function uv.setgid(id) end

--- Returns a current high-resolution time in nanoseconds as a number. This is
--- relative to an arbitrary time in the past. It is not related to the time of day
--- and therefore not subject to clock drift. The primary use is for measuring
--- time between intervals.
--- @return number
function uv.hrtime() end

--- Obtain the current system time from a high-resolution real-time or monotonic
--- clock source. `clock_id` can be the string `"monotonic"` or `"realtime"`.
---
--- The real-time clock counts from the UNIX epoch (1970-01-01) and is subject
--- to time adjustments; it can jump back in time.
---
--- The monotonic clock counts from an arbitrary point in the past and never
--- jumps back in time.
--- @param clock_id string
--- @return { sec: integer, nsec: integer }? time
--- @return string? err
--- @return uv.error_name? err_name
function uv.clock_gettime(clock_id) end

--- Returns the current system uptime in seconds.
--- @return number? uptime
--- @return string? err
--- @return uv.error_name? err_name
function uv.uptime() end

--- Prints all handles associated with the main loop to stderr. The format is
--- `[flags] handle-type handle-address`. Flags are `R` for referenced, `A` for
--- active and `I` for internal.
--- **Note**:
--- This is not available on Windows.
--- **Warning**:
--- This function is meant for ad hoc debugging, there are no API/ABI
--- stability guarantees.
function uv.print_all_handles() end

--- The same as `uv.print_all_handles()` except only active handles are printed.
--- **Note**:
--- This is not available on Windows.
--- **Warning**:
--- This function is meant for ad hoc debugging, there are no API/ABI
--- stability guarantees.
function uv.print_active_handles() end

--- Used to detect what type of stream should be used with a given file
--- descriptor `fd`. Usually this will be used during initialization to guess the
--- type of the stdio streams.
--- @param fd integer
--- @return string
function uv.guess_handle(fd) end

--- Cross-platform implementation of `gettimeofday(2)`. Returns the seconds and
--- microseconds of a unix time as a pair.
--- @return integer? seconds
--- @return integer|string microseconds_or_err
--- @return uv.error_name? err_name
function uv.gettimeofday() end

--- @class uv.interface_addresses.addresses
--- @field ip string
--- @field family string
--- @field netmask string
--- @field internal boolean
--- @field mac string

--- Returns address information about the network interfaces on the system in a
--- table. Each table key is the name of the interface while each associated value
--- is an array of address information where fields are `ip`, `family`, `netmask`,
--- `internal`, and `mac`.
---
--- See [Constants][] for supported address `family` output values.
--- @return table<string, uv.interface_addresses.addresses> addresses
function uv.interface_addresses() end

--- IPv6-capable implementation of `if_indextoname(3)`.
--- @param ifindex integer
--- @return string? name
--- @return string? err
--- @return uv.error_name? err_name
function uv.if_indextoname(ifindex) end

--- Retrieves a network interface identifier suitable for use in an IPv6 scoped
--- address. On Windows, returns the numeric `ifindex` as a string. On all other
--- platforms, `uv.if_indextoname()` is used.
--- @param ifindex integer
--- @return string? iid
--- @return string? err
--- @return uv.error_name? err_name
function uv.if_indextoiid(ifindex) end

--- Returns the load average as a triad. Not supported on Windows.
--- @return number, number, number
function uv.loadavg() end

--- @class uv.os_uname.info
--- @field sysname string
--- @field release string
--- @field version string
--- @field machine string

--- Returns system information.
--- @return uv.os_uname.info info
function uv.os_uname() end

--- Returns the hostname.
--- @return string
function uv.os_gethostname() end

--- Returns the environment variable specified by `name` as string. The internal
--- buffer size can be set by defining `size`. If omitted, `LUAL_BUFFERSIZE` is
--- used. If the environment variable exceeds the storage available in the internal
--- buffer, `ENOBUFS` is returned. If no matching environment variable exists,
--- `ENOENT` is returned.
--- **Warning**:
--- This function is not thread-safe.
--- @param name string
--- @param size integer?
--- @return string? value
--- @return string? err
--- @return uv.error_name? err_name
function uv.os_getenv(name, size) end

--- Sets the environmental variable specified by `name` with the string `value`.
--- **Warning**:
--- This function is not thread-safe.
--- @param name string
--- @param value string
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.os_setenv(name, value) end

--- Unsets the environmental variable specified by `name`.
--- **Warning**:
--- This function is not thread-safe.
--- @param name string
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.os_unsetenv(name) end

--- Returns all environmental variables as a dynamic table of names associated with
--- their corresponding values.
--- **Warning**:
--- This function is not thread-safe.
--- @return table
function uv.os_environ() end

--- Returns the home directory.
--- **Warning**:
--- This function is not thread-safe.
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv.os_homedir() end

--- Returns a temporary directory.
--- **Warning**:
--- This function is not thread-safe.
--- @return string? path
--- @return string? err
--- @return uv.error_name? err_name
function uv.os_tmpdir() end

--- @class uv.os_get_passwd.passwd
--- @field username string
--- @field uid integer
--- @field gid integer
--- @field shell string
--- @field homedir string

--- Returns password file information.
--- @return uv.os_get_passwd.passwd passwd
function uv.os_get_passwd() end

--- Returns the current process ID.
--- @return number
function uv.os_getpid() end

--- Returns the parent process ID.
--- @return number
function uv.os_getppid() end

--- Returns the scheduling priority of the process specified by `pid`.
--- @param pid integer
--- @return integer? priority
--- @return string? err
--- @return uv.error_name? err_name
function uv.os_getpriority(pid) end

--- Sets the scheduling priority of the process specified by `pid`. The `priority`
--- range is between -20 (high priority) and 19 (low priority).
--- @param pid integer
--- @param priority integer
--- @return boolean? success
--- @return string? err
--- @return uv.error_name? err_name
function uv.os_setpriority(pid, priority) end

--- Fills a string of length `len` with cryptographically strong random bytes
--- acquired from the system CSPRNG. `flags` is reserved for future extension
--- and must currently be `nil` or `0` or `{}`.
---
--- Short reads are not possible. When less than `len` random bytes are available,
--- a non-zero error value is returned or passed to the callback. If the callback
--- is omitted, this function is completed synchronously.
---
--- The synchronous version may block indefinitely when not enough entropy is
--- available. The asynchronous version may not ever finish when the system is
--- low on entropy.
--- @param len integer
--- @param flags 0|{}?
--- @return string? bytes
--- @return string? err
--- @return uv.error_name? err_name
--- @overload fun(len: integer, flags: 0|{}?, callback: fun(err: string?, bytes: string?)): 0?, string?, uv.error_name?
function uv.random(len, flags) end

--- Returns the libuv error message and error name (both in string form, see [`err` and `name` in Error Handling](#error-handling)) equivalent to the given platform dependent error code: POSIX error codes on Unix (the ones stored in errno), and Win32 error codes on Windows (those returned by GetLastError() or WSAGetLastError()).
--- @param errcode integer
--- @return string? message
--- @return string? name
function uv.translate_sys_error(errcode) end


--- # Metrics operations

--- Retrieve the amount of time the event loop has been idle in the kernel’s event
--- provider (e.g. `epoll_wait`). The call is thread safe.
---
--- The return value is the accumulated time spent idle in the kernel’s event
--- provider starting from when the [`uv_loop_t`][] was configured to collect the idle time.
---
--- **Note:** The event loop will not begin accumulating the event provider’s idle
--- time until calling `loop_configure` with `"metrics_idle_time"`.
--- @return number
function uv.metrics_idle_time() end

--- @class uv.metrics_info.info
--- @field loop_count number
--- @field events integer
--- @field events_waiting number

--- Get the metrics table from current set of event loop metrics. It is recommended
--- to retrieve these metrics in a `prepare` callback (see `uv.new_prepare`,
--- `uv.prepare_start`) in order to make sure there are no inconsistencies with the
--- metrics counters.
--- @return uv.metrics_info.info info
function uv.metrics_info() end


--- # String manipulation functions
---
--- These string utilities are needed internally for dealing with Windows, and are exported to allow clients to work uniformly with this data when the libuv API is not complete.
---
--- **Notes**:
---
--- 1. New in luv version 1.49.0.
--- 2. See [the WTF-8 spec](https://simonsapin.github.io/wtf-8/) for information about WTF-8.
--- 3. Luv uses Lua-style strings, which means that all inputs and return values (UTF-8 or UTF-16 strings) do not include a NUL terminator.

--- Get the length (in bytes) of a UTF-16 (or UCS-2) string `utf16` value after converting it to WTF-8.
--- @param utf16 string
--- @return integer
function uv.utf16_length_as_wtf8(utf16) end

--- Convert UTF-16 (or UCS-2) string `utf16` to WTF-8 string. The endianness of the UTF-16 (or UCS-2) string is assumed to be the same as the native endianness of the platform.
--- @param utf16 string
--- @return string
function uv.utf16_to_wtf8(utf16) end

--- Get the length (in UTF-16 code units) of a WTF-8 `wtf8` value after converting it to UTF-16 (or UCS-2). Note: The number of bytes needed for a UTF-16 (or UCS-2) string is `<number of code units> * 2`.
--- @param wtf8 string
--- @return integer
function uv.wtf8_length_as_utf16(wtf8) end

--- Convert WTF-8 string in `wtf8` to UTF-16 (or UCS-2) string. The endianness of the UTF-16 (or UCS-2) string will be the same as the native endianness of the platform.
--- @param wtf8 string
--- @return string
function uv.wtf8_to_utf16(wtf8) end


--- ---
---
--- [luv]: https://github.com/luvit/luv
--- [luvit]: https://github.com/luvit/luvit
--- [libuv]: https://github.com/libuv/libuv
--- [libuv documentation page]: http://docs.libuv.org/
--- [libuv API documentation]: http://docs.libuv.org/en/v1.x/api.html
--- [error constants]: https://docs.libuv.org/en/v1.x/errors.html#error-constants


--- @class uv.address
--- @field addr string
--- @field family string
--- @field port integer?
--- @field socktype string
--- @field protocol string
--- @field canonname string?

--- @alias uv.buffer
--- | string
--- | string[]

--- @class uv.socketinfo
--- @field ip string
--- @field family string
--- @field port integer

--- @alias uv.threadargs
--- | number
--- | boolean
--- | string
--- | userdata

--- @class uv.uv_connect_t : uv.uv_req_t

--- @class uv.uv_fs_t : uv.uv_req_t

--- @class uv.uv_getaddrinfo_t : uv.uv_req_t

--- @class uv.uv_getnameinfo_t : uv.uv_req_t

--- @class uv.uv_shutdown_t : uv.uv_req_t

--- @class uv.uv_udp_send_t : uv.uv_req_t

--- @class uv.uv_work_t : uv.uv_req_t

--- @class uv.uv_write_t : uv.uv_req_t
