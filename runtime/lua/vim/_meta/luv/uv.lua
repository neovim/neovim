---@meta

--- The luv project provides access to the multi-platform support library
--- libuv in Lua code. It was primarily developed for the luvit project as
--- the built-in `uv` module, but can be used in other Lua environments.
---
--- More information about the core libuv library can be found at the original
--- libuv documentation page.
---
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
---
---
--- The luv library contains a single Lua module referred to hereafter as `uv` for
--- simplicity. This module consists mostly of functions with names corresponding to
--- their original libuv versions. For example, the libuv function `uv_tcp_bind` has
--- a luv version at `uv.tcp_bind`. Currently, only one non-function field exists:
--- `uv.constants`, which is a table.
---
---
--- In addition to having simple functions, luv provides an optional method-style
--- API. For example, `uv.tcp_bind(server, host, port)` can alternatively be called
--- as `server:bind(host, port)`. Note that the first argument `server` becomes the
--- object and `tcp_` is removed from the function name. Method forms are
--- documented below where they exist.
---
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
---
---
--- Some unique types are defined. These are not actual types in Lua, but they are
--- used here to facilitate documenting consistent behavior:
--- - `fail`: an assertable `nil, string, string` tuple (see Error handling)
--- - `callable`: a `function`; or a `table` or `userdata` with a `__call`
---   metamethod
--- - `buffer`: a `string` or a sequential `table` of `string`s
--- - `threadargs`: variable arguments (`...`) of type `nil`, `boolean`, `number`,
---   `string`, or `userdata`
---
---
--- This documentation is mostly a retelling of the libuv API documentation
--- within the context of luv's Lua API. Low-level implementation details and
--- unexposed C functions and types are not documented here except for when they
--- are relevant to behavior seen in the Lua module.
---
--- [Error handling]: #error-handling
---
--- In libuv, errors are negative numbered constants; however, these errors and the
--- functions used to handle them are not exposed to luv users. Instead, if an
--- internal error is encountered, the luv function will return to the caller an
--- assertable `nil, err, name` tuple.
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
---
--- [reference counting]: #reference-counting
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
---
---
--- [File system operations]: #file-system-operations
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
---
---
--- [Thread pool work scheduling]: #thread-pool-work-scheduling
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
---
---
--- [DNS utility functions]: #dns-utility-functions
---
---
--- [Threading and synchronization utilities]: #threading-and-synchronization-utilities
---
--- Libuv provides cross-platform implementations for multiple threading an
---  synchronization primitives. The API largely follows the pthreads API.
---
---
--- [Miscellaneous utilities]: #miscellaneous-utilities
---
---
--- [Metrics operations]: #metrics-operations
---
---@class uv
---
---@field errno uv.errno
---
local uv


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
---@param  stream        uv.uv_stream_t
---@param  client_stream uv.uv_stream_t
---@return 0|nil         success
---@return uv.error.message|nil    err
---@return uv.error.name|nil    err_name
function uv.accept(stream, client_stream) end


--- Wakeup the event loop and call the async handle's callback.
---
--- **Note**: It's safe to call this function from any thread. The callback will be
--- called on the loop thread.
---
--- **Warning**: libuv will coalesce calls to `uv.async_send(async)`, that is, not
--- every call to it will yield an execution of the callback. For example: if
--- `uv.async_send()` is called 5 times in a row before the callback is called, the
--- callback will only be called once. If `uv.async_send()` is called again after
--- the callback was called, it will be called again.
---
---@param  async      uv.uv_async_t
---@param  ...        uv.threadargs
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.async_send(async, ...) end



--- Returns an estimate of the default amount of parallelism a program should use. Always returns a non-zero value.
---
--- On Linux, inspects the calling thread’s CPU affinity mask to determine if it has been pinned to specific CPUs.
---
--- On Windows, the available parallelism may be underreported on systems with more than 64 logical CPUs.
---
--- On other platforms, reports the number of CPUs that the operating system considers to be online.
---
---@return integer
function uv.available_parallelism() end



--- Get backend file descriptor. Only kqueue, epoll, and event ports are supported.
---
--- This can be used in conjunction with `uv.run("nowait")` to poll in one thread
--- and run the event loop's callbacks in another
---
--- **Note**: Embedding a kqueue fd in another kqueue pollset doesn't work on all
--- platforms. It's not an error to add the fd but it never generates events.
---
---@return integer|nil fd
function uv.backend_fd() end



--- Get the poll timeout. The return value is in milliseconds, or -1 for no timeout.
---
---@return integer
function uv.backend_timeout() end


--- Cancel a pending request. Fails if the request is executing or has finished
--- executing. Only cancellation of `uv_fs_t`, `uv_getaddrinfo_t`,
--- `uv_getnameinfo_t` and `uv_work_t` requests is currently supported.
---
---@param  req        uv.uv_req_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.cancel(req) end



--- Sets the current working directory with the string `cwd`.
---
---@param  cwd        string
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.chdir(cwd) end


--- Start the handle with the given callback.
---
---@param  check      uv.uv_check_t
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.check_start(check, callback) end


--- Stop the handle, the callback will no longer be called.
---
---@param  check      uv.uv_check_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.check_stop(check) end


--- Request handle to be closed. `callback` will be called asynchronously after this
--- call. This MUST be called on each handle before memory is released.
---
--- Handles that wrap file descriptors are closed immediately but `callback` will
--- still be deferred to the next iteration of the event loop. It gives you a chance
--- to free up any resources associated with the handle.
---
--- In-progress requests, like `uv_connect_t` or `uv_write_t`, are cancelled and
--- have their callbacks called asynchronously with `ECANCELED`.
---
---@param handle uv.uv_handle_t
---@param callback? function
function uv.close(handle, callback) end



--- Returns information about the CPU(s) on the system as a table of tables for each
--- CPU found.
---
--- **Returns:** `table` or `fail`
--- - `[1, 2, 3, ..., n]` : `table`
---   - `model` : `string`
---   - `speed` : `number`
---   - `times` : `table`
---     - `user` : `number`
---     - `nice` : `number`
---     - `sys` : `number`
---     - `idle` : `number`
---     - `irq` : `number`
---
---@return uv.cpu_info.cpu[]|nil info
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.cpu_info() end



--- Returns the current working directory.
---
---@return string|nil cwd
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.cwd() end



--- Disables inheritance for file descriptors / handles that this process inherited
--- from its parent. The effect is that child processes spawned by this process
--- don't accidentally inherit these handles.
---
--- It is recommended to call this function as early in your program as possible,
--- before the inherited file descriptors can be closed or duplicated.
---
--- **Note:** This function works on a best-effort basis: there is no guarantee that
--- libuv can discover all file descriptors that were inherited. In general it does
--- a better job on Windows than it does on Unix.
function uv.disable_stdio_inheritance() end



--- Returns the executable path.
---
---@return string|nil exepath
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.exepath() end


--- Gets the platform dependent file descriptor equivalent.
---
--- The following handles are supported: TCP, pipes, TTY, UDP and poll. Passing any
--- other handle type will fail with `EINVAL`.
---
--- If a handle doesn't have an attached file descriptor yet or the handle itself
--- has been closed, this function will return `EBADF`.
---
--- **Warning**: Be very careful when using this function. libuv assumes it's in
--- control of the file descriptor so any change to it may lead to malfunction.
---
---@param  handle      uv.uv_handle_t
---@return integer|nil fileno
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fileno(handle) end



--- Equivalent to `access(2)` on Unix. Windows uses `GetFileAttributesW()`. Access
--- `mode` can be an integer or a string containing `"R"` or `"W"` or `"X"`.
--- Returns `true` or `false` indicating access permission.
---
---@param  path        string
---@param  mode        integer|string
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, mode:integer|string, callback:uv.fs_access.callback):uv.uv_fs_t
function uv.fs_access(path, mode) end



--- Equivalent to `chmod(2)`.
---
---@param  path        string
---@param  mode        integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, mode:integer, callback:uv.fs_chmod.callback):uv.uv_fs_t
function uv.fs_chmod(path, mode) end



--- Equivalent to `chown(2)`.
---
---@param  path        string
---@param  uid         integer
---@param  gid         integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, uid:integer, gid:integer, callback:uv.fs_chown.callback):uv.uv_fs_t
function uv.fs_chown(path, uid, gid) end



--- Equivalent to `close(2)`.
---
---@param  fd          integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, callback:uv.fs_close.callback):uv.uv_fs_t
function uv.fs_close(fd) end


--- Closes a directory stream returned by a successful `uv.fs_opendir()` call.
---
---@param  dir         uv.luv_dir_t
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(dir:uv.luv_dir_t, callback:uv.fs_closedir.callback):uv.uv_fs_t
function uv.fs_closedir(dir) end



--- Copies a file from path to new_path. If the `flags` parameter is omitted, then the 3rd parameter will be treated as the `callback`.
---
--- **Returns (sync version):** `boolean` or `fail`
---
--- **Returns (async version):** `uv_fs_t userdata`
---
---@param  path        string
---@param  new_path    string
---@param  flags?      uv.fs_copyfile.flags
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, new_path:string, flags?:uv.fs_copyfile.flags, callback:uv.fs_copyfile.callback):uv.uv_fs_t
---@overload fun(path:string, new_path:string, callback:uv.fs_copyfile.callback):uv.uv_fs_t
function uv.fs_copyfile(path, new_path, flags) end


--- Get the path being monitored by the handle.
---
---@param  fs_event   uv.uv_fs_event_t
---@return string|nil path
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fs_event_getpath(fs_event) end


--- Start the handle with the given callback, which will watch the specified path
--- for changes.
---
---@param  fs_event   uv.uv_fs_event_t
---@param  path       string
---@param  flags      uv.fs_event_start.flags
---@param  callback   uv.fs_event_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fs_event_start(fs_event, path, flags, callback) end


--- Stop the handle, the callback will no longer be called.
---
---@param  fs_event   uv.uv_fs_event_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fs_event_stop(fs_event) end



--- Equivalent to `fchmod(2)`.
---
---@param  fd          integer
---@param  mode        integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, mode:integer, callback:uv.fs_fchmod.callback):uv.uv_fs_t
function uv.fs_fchmod(fd, mode) end



--- Equivalent to `fchown(2)`.
---
---@param  fd          integer
---@param  uid         integer
---@param  gid         integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, uid:integer, gid:integer, callback:uv.fs_fchown.callback):uv.uv_fs_t
function uv.fs_fchown(fd, uid, gid) end



--- Equivalent to `fdatasync(2)`.
---
---@param  fd          integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, callback:uv.fs_fdatasync.callback):uv.uv_fs_t
function uv.fs_fdatasync(fd) end



--- Equivalent to `fstat(2)`.
---
--- **Returns (sync version):** `table` or `fail` (see `uv.fs_stat`)
---
--- **Returns (async version):** `uv_fs_t userdata`
---
---@param  fd                    integer
---@return uv.fs_stat.result|nil stat
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, callback:uv.fs_fstat.callback):uv.uv_fs_t
function uv.fs_fstat(fd) end



--- Equivalent to `fsync(2)`.
---
---@param  fd          integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, callback:uv.fs_fsync.callback):uv.uv_fs_t
function uv.fs_fsync(fd) end



--- Equivalent to `ftruncate(2)`.
---
---@param  fd          integer
---@param  offset      integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, offset:integer, callback:uv.fs_ftruncate.callback):uv.uv_fs_t
function uv.fs_ftruncate(fd, offset) end



--- Equivalent to `futime(2)`.
---
---@param  fd          integer
---@param  atime       number
---@param  mtime       number
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, atime:number, mtime:number, callback:uv.fs_futime.callback):uv.uv_fs_t
function uv.fs_futime(fd, atime, mtime) end



--- Equivalent to `lchown(2)`.
---
---@param  fd          integer
---@param  uid         integer
---@param  gid         integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, uid:integer, gid:integer, callback:uv.fs_lchown.callback):uv.uv_fs_t
function uv.fs_lchown(fd, uid, gid) end



--- Equivalent to `link(2)`.
---
--- **Returns (sync version):** `boolean` or `fail`
---
--- **Returns (async version):** `uv_fs_t userdata`
---
---@param  path        string
---@param  new_path    string
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, new_path:string, callback:uv.fs_link.callback):uv.uv_fs_t
function uv.fs_link(path, new_path) end



--- Equivalent to `lstat(2)`.
---
--- **Returns (sync version):** `table` or `fail` (see `uv.fs_stat`)
---
--- **Returns (async version):** `uv_fs_t userdata`
---
---@param  path                  integer
---@return uv.fs_stat.result|nil stat
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:integer, callback:uv.fs_lstat.callback):uv.uv_fs_t
function uv.fs_lstat(path) end



--- Equivalent to `lutime(2)`.
---
---@param  path        string
---@param  atime       number
---@param  mtime       number
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, atime:number, mtime:number, callback:uv.fs_lutime.callback):uv.uv_fs_t
function uv.fs_lutime(path, atime, mtime) end



--- Equivalent to `mkdir(2)`.
---
---@param  path        string
---@param  mode        integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, mode:integer, callback:uv.fs_mkdir.callback):uv.uv_fs_t
function uv.fs_mkdir(path, mode) end



--- Equivalent to `mkdtemp(3)`.
---
---@param  template   string
---@return string|nil path
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(template:string, callback:uv.fs_mkdtemp.callback):uv.uv_fs_t
function uv.fs_mkdtemp(template) end



--- Equivalent to `mkstemp(3)`. Returns a temporary file handle and filename.
---
---@param  template    string
---@return integer|nil fd
---@return string      path_or_errmsg
---@return uv.error.name|nil err_name
---
---@overload fun(template:string, callback:uv.fs_mkstemp.callback):uv.uv_fs_t
function uv.fs_mkstemp(template) end



--- Equivalent to `open(2)`. Access `flags` may be an integer or one of: `"r"`,
--- `"rs"`, `"sr"`, `"r+"`, `"rs+"`, `"sr+"`, `"w"`, `"wx"`, `"xw"`, `"w+"`,
--- `"wx+"`, `"xw+"`, `"a"`, `"ax"`, `"xa"`, `"a+"`, `"ax+"`, or "`xa+`".
---
--- **Returns (sync version):** `integer` or `fail`
---
--- **Returns (async version):** `uv_fs_t userdata`
---
--- **Note:** On Windows, libuv uses `CreateFileW` and thus the file is always
--- opened in binary mode. Because of this, the `O_BINARY` and `O_TEXT` flags are
--- not supported.
---
---@param  path        string
---@param  flags       uv.fs_open.flags
---@param  mode        integer
---@return integer|nil fd
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, flags:uv.fs_open.flags, mode:integer, callback:uv.fs_open.callback):uv.uv_fs_t
function uv.fs_open(path, flags, mode) end



--- Opens path as a directory stream. Returns a handle that the user can pass to
--- `uv.fs_readdir()`. The `entries` parameter defines the maximum number of entries
--- that should be returned by each call to `uv.fs_readdir()`.
---
--- **Returns (sync version):** `luv_dir_t userdata` or `fail`
---
--- **Returns (async version):** `uv_fs_t userdata`
---
---@param  path             string
---@return uv.luv_dir_t|nil dir
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path: string, callback: uv.fs_opendir.callback, entries?: integer):uv.uv_fs_t
function uv.fs_opendir(path) end


--- Get the path being monitored by the handle.
---
---@param  fs_poll    uv.uv_fs_poll_t
---@return string|nil path
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fs_poll_getpath(fs_poll) end


--- Check the file at `path` for changes every `interval` milliseconds.
---
--- **Note:** For maximum portability, use multi-second intervals. Sub-second
--- intervals will not detect all changes on many file systems.
---
---@param  fs_poll    uv.uv_fs_poll_t
---@param  path       string
---@param  interval   integer
---@param  callback   uv.fs_poll_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fs_poll_start(fs_poll, path, interval, callback) end


--- Stop the handle, the callback will no longer be called.
---
---@param fs_poll uv.uv_fs_poll_t
---@return 0|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fs_poll_stop(fs_poll) end



--- Equivalent to `preadv(2)`. Returns any data. An empty string indicates EOF.
---
--- If `offset` is nil or omitted, it will default to `-1`, which indicates 'use and update the current file offset.'
---
--- **Note:** When `offset` is >= 0, the current file offset will not be updated by the read.
---
---@param  fd         integer
---@param  size       integer
---@param  offset?    integer
---@return string|nil data
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, size:integer, offset?:integer, callback:uv.fs_read.callback):uv.uv_fs_t
function uv.fs_read(fd, size, offset) end


--- Iterates over the directory stream `luv_dir_t` returned by a successful
--- `uv.fs_opendir()` call. A table of data tables is returned where the number
--- of entries `n` is equal to or less than the `entries` parameter used in
--- the associated `uv.fs_opendir()` call.
---
---@param  dir                       uv.luv_dir_t
---@return uv.fs_readdir.entry[]|nil entries
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(dir:uv.luv_dir_t, callback:uv.fs_readdir.callback):uv.uv_fs_t
function uv.fs_readdir(dir) end



--- Equivalent to `readlink(2)`.
---
---@param  path       string
---@return string|nil path
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, callback:uv.fs_readlink.callback):uv.uv_fs_t
function uv.fs_readlink(path) end



--- Equivalent to `realpath(3)`.
---
---@param  path       string
---@return string|nil realpath
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, callback:uv.fs_realpath.callback):uv.uv_fs_t
function uv.fs_realpath(path) end



--- Equivalent to `rename(2)`.
---
---@param  path        string
---@param  new_path    string
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, new_path:string, callback:uv.fs_rename.callback):uv.uv_fs_t
function uv.fs_rename(path, new_path) end



--- Equivalent to `rmdir(2)`.
---
---@param  path        string
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, callback:uv.fs_rmdir.callback):uv.uv_fs_t
function uv.fs_rmdir(path) end



--- Equivalent to `scandir(3)`, with a slightly different API. Returns a handle that
--- the user can pass to `uv.fs_scandir_next()`.
---
--- **Note:** This function can be used synchronously or asynchronously. The request
--- userdata is always synchronously returned regardless of whether a callback is
--- provided and the same userdata is passed to the callback if it is provided.
---
---@param  path           string
---@param  callback?      uv.fs_scandir.callback
---@return uv.uv_fs_t|nil fs
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.fs_scandir(path, callback) end



--- Called on a `uv_fs_t` returned by `uv.fs_scandir()` to get the next directory
--- entry data as a `name, type` pair. When there are no more entries, `nil` is
--- returned.
---
--- **Note:** This function only has a synchronous version. See `uv.fs_opendir` and
--- its related functions for an asynchronous version.
---
---@param  fs         uv.uv_fs_t
---@return string|nil name
---@return string     type_or_errmsg
---@return uv.error.name|nil err_name
function uv.fs_scandir_next(fs) end



--- Limited equivalent to `sendfile(2)`. Returns the number of bytes written.
---
---@param  out_fd      integer
---@param  in_fd       integer
---@param  in_offset   integer
---@param  size        integer
---@return integer|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(out_fd:integer, in_fd:integer, in_offset:integer, size:integer, callback:uv.fs_sendfile.callback):uv.uv_fs_t
function uv.fs_sendfile(out_fd, in_fd, in_offset, size) end



--- Equivalent to `stat(2)`.
---
--- **Returns (sync version):** `table` or `fail`
--- - `dev` : `integer`
--- - `mode` : `integer`
--- - `nlink` : `integer`
--- - `uid` : `integer`
--- - `gid` : `integer`
--- - `rdev` : `integer`
--- - `ino` : `integer`
--- - `size` : `integer`
--- - `blksize` : `integer`
--- - `blocks` : `integer`
--- - `flags` : `integer`
--- - `gen` : `integer`
--- - `atime` : `table`
---   - `sec` : `integer`
---   - `nsec` : `integer`
--- - `mtime` : `table`
---   - `sec` : `integer`
---   - `nsec` : `integer`
--- - `ctime` : `table`
---   - `sec` : `integer`
---   - `nsec` : `integer`
--- - `birthtime` : `table`
---   - `sec` : `integer`
---   - `nsec` : `integer`
--- - `type` : `string`
---
--- **Returns (async version):** `uv_fs_t userdata`
---
---@param path string
---@return uv.fs_stat.result|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, callback:uv.fs_stat.callback):uv.uv_fs_t
function uv.fs_stat(path) end


--- Equivalent to `statfs(2)`.
---
--- **Returns** `table` or `nil`
--- - `type` : `integer`
--- - `bsize` : `integer`
--- - `blocks` : `integer`
--- - `bfree` : `integer`
--- - `bavail` : `integer`
--- - `files` : `integer`
--- - `ffree` : `integer`
---
---@param path string
---@return uv.fs_statfs.result|nil stat
---
---@overload fun(path: string, callback: uv.fs_statfs.callback)
function uv.fs_statfs(path) end



--- Equivalent to `symlink(2)`. If the `flags` parameter is omitted, then the 3rd parameter will be treated as the `callback`.
---
---
---@param  path        string
---@param  new_path    string
---@param  flags?      uv.fs_symlink.flags|integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, new_path:string, flags?:uv.fs_symlink.flags|integer, callback:uv.fs_symlink.callback):uv.uv_fs_t
---@overload fun(path:string, new_path:string, callback:uv.fs_symlink.callback):uv.uv_fs_t
function uv.fs_symlink(path, new_path, flags) end



--- Equivalent to `unlink(2)`.
---
---@param  path        string
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, callback:uv.fs_unlink.callback):uv.uv_fs_t
function uv.fs_unlink(path) end



--- Equivalent to `utime(2)`.
---
---@param  path        string
---@param  atime       number
---@param  mtime       number
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(path:string, atime:number, mtime:number, callback:uv.fs_utime.callback):uv.uv_fs_t
function uv.fs_utime(path, atime, mtime) end



--- Equivalent to `pwritev(2)`. Returns the number of bytes written.
---
--- If `offset` is nil or omitted, it will default to `-1`, which indicates 'use and update the current file offset.'
---
--- **Note:** When `offset` is >= 0, the current file offset will not be updated by the write.
---
---@param  fd          integer
---@param  data        uv.buffer
---@param  offset?     integer
---@return integer|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(fd:integer, data:uv.buffer, offset?:integer, callback:uv.fs_write.callback):uv.uv_fs_t
function uv.fs_write(fd, data, offset) end



--- Gets the amount of memory available to the process in bytes based on limits
--- imposed by the OS. If there is no such constraint, or the constraint is unknown,
--- 0 is returned. Note that it is not unusual for this value to be less than or
--- greater than the total system memory.
---
---@return number
function uv.get_constrained_memory() end



--- Returns the current free system memory in bytes.
---
---@return number
function uv.get_free_memory() end



--- Returns the title of the current process.
---
---@return string|nil title
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.get_process_title() end



--- Returns the current total system memory in bytes.
---
--- **Returns:** `number`
---
---@return number
function uv.get_total_memory() end



--- Equivalent to `getaddrinfo(3)`. Either `node` or `service` may be `nil` but not
--- both.
---
--- Valid hint strings for the keys that take a string:
--- - `family`: `"unix"`, `"inet"`, `"inet6"`, `"ipx"`,
--- `"netlink"`, `"x25"`, `"ax25"`, `"atmpvc"`, `"appletalk"`, or `"packet"`
--- - `socktype`: `"stream"`, `"dgram"`, `"raw"`,
--- `"rdm"`, or `"seqpacket"`
--- - `protocol`: will be looked up using the `getprotobyname(3)` function (examples: `"ip"`, `"icmp"`, `"tcp"`, `"udp"`, etc)
---
--- **Returns (sync version):** `table` or `fail`
--- - `[1, 2, 3, ..., n]` : `table`
---   - `addr` : `string`
---   - `family` : `string`
---   - `port` : `integer` or `nil`
---   - `socktype` : `string`
---   - `protocol` : `string`
---   - `canonname` : `string` or `nil`
---
--- **Returns (async version):** `uv_getaddrinfo_t userdata` or `fail`
---
---@param  host                        string
---@param  service                     string
---@param  hints?                      uv.getaddrinfo.hints
---@return uv.getaddrinfo.result[]|nil info
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(host:string, service:string, hints?:uv.getaddrinfo.hints, callback:uv.getaddrinfo.callback):uv.uv_getaddrinfo_t userdata|nil, string?, string?
function uv.getaddrinfo(host, service, hints) end



--- Returns the group ID of the process.
---
--- **Note:** This is not a libuv function and is not supported on Windows.
---
---@return integer
function uv.getgid() end



--- Equivalent to `getnameinfo(3)`.
---
--- When specified, `family` must be one of `"unix"`, `"inet"`, `"inet6"`, `"ipx"`,
--- `"netlink"`, `"x25"`, `"ax25"`, `"atmpvc"`, `"appletalk"`, or `"packet"`.
---
--- **Returns (sync version):** `string, string` or `fail`
---
--- **Returns (async version):** `uv_getnameinfo_t userdata` or `fail`
---
---@param  address    uv.getnameinfo.address
---@return string|nil host
---@return string     service_or_errmsg
---@return uv.error.name|nil err_name
---
---@overload fun(address:uv.getnameinfo.address, callback:uv.getnameinfo.callback):uv.uv_getnameinfo_t|nil, string|nil, string|nil
function uv.getnameinfo(address) end



--- **Deprecated:** Please use `uv.os_getpid()` instead.
---
function uv.getpid() end



--- Returns the resource usage.
---
--- **Returns:** `table` or `fail`
--- - `utime` : `table` (user CPU time used)
---   - `sec` : `integer`
---   - `usec` : `integer`
--- - `stime` : `table` (system CPU time used)
---   - `sec` : `integer`
---   - `usec` : `integer`
--- - `maxrss` : `integer` (maximum resident set size)
--- - `ixrss` : `integer` (integral shared memory size)
--- - `idrss` : `integer` (integral unshared data size)
--- - `isrss` : `integer` (integral unshared stack size)
--- - `minflt` : `integer` (page reclaims (soft page faults))
--- - `majflt` : `integer` (page faults (hard page faults))
--- - `nswap` : `integer` (swaps)
--- - `inblock` : `integer` (block input operations)
--- - `oublock` : `integer` (block output operations)
--- - `msgsnd` : `integer` (IPC messages sent)
--- - `msgrcv` : `integer` (IPC messages received)
--- - `nsignals` : `integer` (signals received)
--- - `nvcsw` : `integer` (voluntary context switches)
--- - `nivcsw` : `integer` (involuntary context switches)
---
---@return uv.getrusage.result|nil usage
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.getrusage() end



--- Cross-platform implementation of `gettimeofday(2)`. Returns the seconds and
--- microseconds of a unix time as a pair.
---
---@return integer|nil    seconds
---@return integer|string usecs_or_errmsg
---@return uv.error.name|nil err_name
function uv.gettimeofday() end



--- Returns the user ID of the process.
---
--- **Note:** This is not a libuv function and is not supported on Windows.
---
---@return integer
function uv.getuid() end



--- Used to detect what type of stream should be used with a given file
--- descriptor `fd`. Usually this will be used during initialization to guess the
--- type of the stdio streams.
---
---@param fd integer
---@return string
function uv.guess_handle(fd) end


--- Returns the name of the struct for a given handle (e.g. `"pipe"` for `uv_pipe_t`)
--- and the libuv enum integer for the handle's type (`uv_handle_type`).
---
---@param  handle  uv.uv_handle_t
---@return string  type
---@return integer enum
function uv.handle_get_type(handle) end


--- Returns `true` if the handle referenced, `false` if not.
---
--- See [Reference counting][].
---
---@param  handle      uv.uv_handle_t
---@return boolean|nil has_ref
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.has_ref(handle) end



--- Returns a current high-resolution time in nanoseconds as a number. This is
--- relative to an arbitrary time in the past. It is not related to the time of day
--- and therefore not subject to clock drift. The primary use is for measuring
--- time between intervals.
---
--- **Returns:** `number`
---
---@return number
function uv.hrtime() end


--- Start the handle with the given callback.
---
---@param  idle       uv.uv_idle_t
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.idle_start(idle, callback) end


--- Stop the handle, the callback will no longer be called.
---
---@param  idle       uv.uv_idle_t
---@param  check      any
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.idle_stop(idle, check) end



--- Retrieves a network interface identifier suitable for use in an IPv6 scoped
--- address. On Windows, returns the numeric `ifindex` as a string. On all other
--- platforms, `uv.if_indextoname()` is used.
---
---@param  ifindex    integer
---@return string|nil id
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.if_indextoiid(ifindex) end



--- IPv6-capable implementation of `if_indextoname(3)`.
---
---@param  ifindex    integer
---@return string|nil name
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.if_indextoname(ifindex) end


--- Returns address information about the network interfaces on the system in a
--- table. Each table key is the name of the interface while each associated value
--- is an array of address information where fields are `ip`, `family`, `netmask`,
--- `internal`, and `mac`.
---
---@return table<string, uv.interface_addresses.addr>
function uv.interface_addresses() end


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
---
---@param  handle      uv.uv_handle_t
---@return boolean|nil active
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.is_active(handle) end


--- Returns `true` if the handle is closing or closed, `false` otherwise.
---
--- **Note**: This function should only be used between the initialization of the
--- handle and the arrival of the close callback.
---
---@param  handle      uv.uv_handle_t
---@return boolean|nil closing
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.is_closing(handle) end


--- Returns `true` if the stream is readable, `false` otherwise.
---
---@param stream uv.uv_stream_t
---@return boolean
function uv.is_readable(stream) end


--- Returns `true` if the stream is writable, `false` otherwise.
---
---@param stream uv.uv_stream_t
---@return boolean
function uv.is_writable(stream) end


--- Sends the specified signal to the given PID. Check the documentation on
--- `uv_signal_t` for signal support, specially on Windows.
---
---@param  pid        integer
---@param  signum     integer|string
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.kill(pid, signum) end


--- Start listening for incoming connections. `backlog` indicates the number of
--- connections the kernel might queue, same as `listen(2)`. When a new incoming
--- connection is received the callback is called.
---
--- **Returns:** `0` or `fail`
---
---@param  stream     uv.uv_stream_t
---@param  backlog    integer
---@param  callback   uv.listen.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.listen(stream, backlog, callback) end


--- Returns the load average as a triad. Not supported on Windows.
---
---@return number
---@return number
---@return number
function uv.loadavg() end



--- Returns `true` if there are referenced active handles, active requests, or
--- closing handles in the loop; otherwise, `false`.
---
---@return boolean|nil alive
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.loop_alive() end



--- Closes all internal loop resources. In normal execution, the loop will
--- automatically be closed when it is garbage collected by Lua, so it is not
--- necessary to explicitly call `loop_close()`. Call this function only after the
--- loop has finished executing and all open handles and requests have been closed,
--- or it will return `EBUSY`.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.loop_close() end



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
---
--- **Note:** Be prepared to handle the `ENOSYS` error; it means the loop option is
--- not supported by the platform.
---
---@param  option     "block_signal"
---@param  value      "sigprof"
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(option: "metrics_idle_time"):(success:0|nil, err:uv.error.message|nil, err_name:uv.error.name|nil)
function uv.loop_configure(option, value) end


--- If the loop is running, returns a string indicating the mode in use. If the loop
--- is not running, `nil` is returned instead.
---
---@return string|nil
function uv.loop_mode() end


--- Retrieve the amount of time the event loop has been idle in the kernel’s event
--- provider (e.g. `epoll_wait`). The call is thread safe.
---
--- The return value is the accumulated time spent idle in the kernel’s event
--- provider starting from when the [`uv_loop_t`][] was configured to collect the idle time.
---
--- **Note:** The event loop will not begin accumulating the event provider’s idle
--- time until calling `loop_configure` with `"metrics_idle_time"`.
---
--- **Returns:** `number`
---
--- ---
---
--- [luv]: https://github.com/luvit/luv
--- [luvit]: https://github.com/luvit/luvit
--- [libuv]: https://github.com/libuv/libuv
--- [libuv documentation page]: http://docs.libuv.org/
--- [libuv API documentation]: http://docs.libuv.org/en/v1.x/api.html
---
---@return number
function uv.metrics_idle_time() end


--- Creates and initializes a new `uv_async_t`. Returns the Lua userdata wrapping
--- it. A `nil` callback is allowed.
---
--- **Note**: Unlike other handle initialization functions, this immediately starts
--- the handle.
---
---@param  callback?         uv.new_async.callback
---@return uv.uv_async_t|nil async
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_async(callback) end


--- Creates and initializes a new `uv_check_t`. Returns the Lua userdata wrapping
--- it.
---
---@return uv.uv_check_t|nil check
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_check() end


--- Creates and initializes a new `uv_fs_event_t`. Returns the Lua userdata wrapping
--- it.
---
---@return uv.uv_fs_event_t|nil fs_event
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_fs_event() end


--- Creates and initializes a new `uv_fs_poll_t`. Returns the Lua userdata wrapping
--- it.
---
---@return uv.uv_fs_poll_t|nil fs_poll
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_fs_poll() end


--- Creates and initializes a new `uv_idle_t`. Returns the Lua userdata wrapping
--- it.
---
---@return uv.uv_idle_t|nil idle
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_idle() end


--- Creates and initializes a new `uv_pipe_t`. Returns the Lua userdata wrapping
--- it. The `ipc` argument is a boolean to indicate if this pipe will be used for
--- handle passing between processes.
---
---@param  ipc?             boolean|false
---@return uv.uv_pipe_t|nil pipe
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_pipe(ipc) end


--- Initialize the handle using a file descriptor.
---
--- The file descriptor is set to non-blocking mode.
---
---@param  fd               integer
---@return uv.uv_poll_t|nil poll
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_poll(fd) end


--- Creates and initializes a new `uv_prepare_t`. Returns the Lua userdata wrapping
--- it.
---
---@return uv.uv_prepare_t|nil prepare
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_prepare() end


--- Creates and initializes a new `uv_signal_t`. Returns the Lua userdata wrapping
--- it.
---
---@return uv.uv_signal_t|nil signal
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_signal() end


--- Initialize the handle using a socket descriptor. On Unix this is identical to
--- `uv.new_poll()`. On windows it takes a SOCKET handle.
---
--- The socket is set to non-blocking mode.
---
---@param  fd               integer
---@return uv.uv_poll_t|nil poll
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_socket_poll(fd) end


--- Creates and initializes a new `uv_tcp_t`. Returns the Lua userdata wrapping it.
--- Flags may be a family string: `"unix"`, `"inet"`, `"inet6"`, `"ipx"`,
--- `"netlink"`, `"x25"`, `"ax25"`, `"atmpvc"`, `"appletalk"`, or `"packet"`.
---
---@param  flags?          uv.socket.family
---@return uv.uv_tcp_t|nil tcp
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_tcp(flags) end



--- Creates and initializes a `luv_thread_t` (not `uv_thread_t`). Returns the Lua
--- userdata wrapping it and asynchronously executes `entry`, which can be either
--- a Lua function or a Lua function dumped to a string. Additional arguments `...`
--- are passed to the `entry` function and an optional `options` table may be
--- provided. Currently accepted `option` fields are `stack_size`.
---
---@param  options?            uv.new_thread.options
---@param  entry               function
---@param  ...                 uv.threadargs
---@return uv.luv_thread_t|nil thread
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_thread(options, entry, ...) end



--- Creates and initializes a new `uv_timer_t`. Returns the Lua userdata wrapping
--- it.
---
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
---
---@return uv.uv_timer_t|nil timer
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_timer() end



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
---
--- **Note:** If reopening the TTY fails, libuv falls back to blocking writes.
---
---@param  fd              integer
---@param  readable        boolean
---@return uv.uv_tty_t|nil tty
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_tty(fd, readable) end



--- Creates and initializes a new `uv_udp_t`. Returns the Lua userdata wrapping
--- it. The actual socket is created lazily.
---
--- When specified, `family` must be one of `"unix"`, `"inet"`, `"inet6"`,
--- `"ipx"`, `"netlink"`, `"x25"`, `"ax25"`, `"atmpvc"`, `"appletalk"`, or
--- `"packet"`.
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
---
--- **Returns:** `uv_udp_t userdata` or `fail`
---
---@param  flags?          uv.new_udp.flags|uv.new_udp.flags.family|integer
---@return uv.uv_udp_t|nil udp
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.new_udp(flags) end



--- Creates and initializes a new `luv_work_ctx_t` (not `uv_work_t`). Returns the
--- Lua userdata wrapping it.
---
--- **Parameters:**
--- - `work_callback`: `function`
---   - `...`: `threadargs` passed to/from `uv.queue_work(work_ctx, ...)`
--- - `after_work_callback`: `function`
---   - `...`: `threadargs` returned from `work_callback`
---
---@param work_callback uv.new_work.work_callback
---@param after_work_callback uv.new_work.after_work_callback
---@return uv.luv_work_ctx_t
function uv.new_work(work_callback, after_work_callback) end



--- Returns the current timestamp in milliseconds. The timestamp is cached at the
--- start of the event loop tick, see `uv.update_time()` for details and rationale.
---
--- The timestamp increases monotonically from some arbitrary point in time. Don't
--- make assumptions about the starting point, you will only get disappointed.
---
--- **Note**: Use `uv.hrtime()` if you need sub-millisecond granularity.
---
---@return integer
function uv.now() end



--- Returns all environmental variables as a dynamic table of names associated with
--- their corresponding values.
---
--- **Warning:** This function is not thread safe.
---
---@return table<string, string>
function uv.os_environ() end



--- Returns password file information.
---
---@return uv.os_get_passwd.info
function uv.os_get_passwd() end



--- Returns the environment variable specified by `name` as string. The internal
--- buffer size can be set by defining `size`. If omitted, `LUAL_BUFFERSIZE` is
--- used. If the environment variable exceeds the storage available in the internal
--- buffer, `ENOBUFS` is returned. If no matching environment variable exists,
--- `ENOENT` is returned.
---
--- **Warning:** This function is not thread safe.
---
---@param name string
---@param size? integer # (default = `LUAL_BUFFERSIZE`)
---@return string|nil value
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.os_getenv(name, size) end



--- Returns the hostname.
---
---@return string
function uv.os_gethostname() end



--- Returns the current process ID.
---
---@return number
function uv.os_getpid() end



--- Returns the parent process ID.
---
---@return number
function uv.os_getppid() end



--- Returns the scheduling priority of the process specified by `pid`.
---
---@param  pid        integer
---@return number|nil priority
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.os_getpriority(pid) end



--- **Warning:** This function is not thread safe.
---
---@return string|nil homedir
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.os_homedir() end


--- Sets the environmental variable specified by `name` with the string `value`.
---
--- **Warning:** This function is not thread safe.
---
---@param  name        string
---@param  value       string
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.os_setenv(name, value) end


--- Sets the scheduling priority of the process specified by `pid`. The `priority`
--- range is between -20 (high priority) and 19 (low priority).
---
---@param  pid         integer
---@param  priority    integer
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.os_setpriority(pid, priority) end


--- **Warning:** This function is not thread safe.
---
---@return string|nil tmpdir
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.os_tmpdir() end



--- Returns system information.
---
---@return uv.os_uname.info
function uv.os_uname() end



--- **Warning:** This function is not thread safe.
---
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.os_unsetenv() end



--- Create a pair of connected pipe handles. Data may be written to the `write` fd and read from the `read` fd. The resulting handles can be passed to `pipe_open`, used with `spawn`, or for any other purpose.
---
--- Flags:
---  - `nonblock`: Opens the specified socket handle for `OVERLAPPED` or `FIONBIO`/`O_NONBLOCK` I/O usage. This is recommended for handles that will be used by libuv, and not usually recommended otherwise.
---
--- Equivalent to `pipe(2)` with the `O_CLOEXEC` flag set.
---
--- **Returns:** `table` or `fail`
--- - `read` : `integer` (file descriptor)
--- - `write` : `integer` (file descriptor)
---
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
---
---@param  read_flags      uv.pipe.read_flags
---@param  write_flags     uv.pipe.write_flags
---@return uv.pipe.fds|nil fds
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.pipe(read_flags, write_flags) end


--- Bind the pipe to a file path (Unix) or a name (Windows).
---
--- **Note**: Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
---
---@param  pipe       uv.uv_pipe_t
---@param  name       string
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.pipe_bind(pipe, name) end


--- Alters pipe permissions, allowing it to be accessed from processes run by different users.
--- Makes the pipe writable or readable by all users. `flags` are: `"r"`, `"w"`, `"rw"`, or `"wr"`
--- where `r` is `READABLE` and `w` is `WRITABLE`. This function is blocking.
---
---@param  pipe       uv.uv_pipe_t
---@param  flags      uv.pipe_chmod.flags
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.pipe_chmod(pipe, flags) end


--- Connect to the Unix domain socket or the named pipe.
---
--- **Note**: Paths on Unix get truncated to sizeof(sockaddr_un.sun_path) bytes,
--- typically between 92 and 108 bytes.
---
---@param  pipe                uv.uv_pipe_t
---@param  name                string
---@param  callback?           uv.pipe_connect.callback
---@return uv.uv_connect_t|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.pipe_connect(pipe, name, callback) end


--- Get the name of the Unix domain socket or the named pipe to which the handle is
--- connected.
---
---@param  pipe       uv.uv_pipe_t
---@return string|nil peername
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.pipe_getpeername(pipe) end


--- Get the name of the Unix domain socket or the named pipe.
---
---@param  pipe       uv.uv_pipe_t
---@return string|nil sockname
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.pipe_getsockname(pipe) end


--- Open an existing file descriptor or [`uv_handle_t`][] as a pipe.
---
--- **Note**: The file descriptor is set to non-blocking mode.
---
---@param  pipe       uv.uv_pipe_t
---@param  fd         integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.pipe_open(pipe, fd) end


--- Returns the pending pipe count for the named pipe.
---
---@param pipe uv.uv_pipe_t
---@return integer
function uv.pipe_pending_count(pipe) end


--- Set the number of pending pipe instance handles when the pipe server is waiting
--- for connections.
---
--- **Note**: This setting applies to Windows only.
---
---@param pipe uv.uv_pipe_t
---@param count integer
function uv.pipe_pending_instances(pipe, count) end


--- Used to receive handles over IPC pipes.
---
--- First - call `uv.pipe_pending_count()`, if it's > 0 then initialize a handle of
--- the given type, returned by `uv.pipe_pending_type()` and call
--- `uv.accept(pipe, handle)`.
---
---@param pipe uv.uv_pipe_t
---@return string
function uv.pipe_pending_type(pipe) end


--- Starts polling the file descriptor.
---
--- `events` are: `"r"`, `"w"`, `"rw"`, `"d"`,
--- `"rd"`, `"wd"`, `"rwd"`, `"p"`, `"rp"`, `"wp"`, `"rwp"`, `"dp"`, `"rdp"`,
--- `"wdp"`, or `"rwdp"` where `r` is `READABLE`, `w` is `WRITABLE`, `d` is
--- `DISCONNECT`, and `p` is `PRIORITIZED`. As soon as an event is detected
--- the callback will be called with status set to 0, and the detected events set on
--- the events field.
---
--- The user should not close the socket while the handle is active. If the user
--- does that anyway, the callback may be called reporting an error status, but this
--- is not guaranteed.
---
--- **Note** Calling `uv.poll_start()` on a handle that is already active is fine.
--- Doing so will update the events mask that is being watched for.
---
---@param  poll       uv.uv_poll_t
---@param  events     uv.poll.eventspec
---@param  callback   uv.poll_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.poll_start(poll, events, callback) end


--- Stop polling the file descriptor, the callback will no longer be called.
---
---@param  poll       uv.uv_poll_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.poll_stop(poll) end


--- Start the handle with the given callback.
---
---@param  prepare    uv.uv_prepare_t
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.prepare_start(prepare, callback) end


--- Stop the handle, the callback will no longer be called.
---
---@param  prepare    uv.uv_prepare_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.prepare_stop(prepare) end


--- The same as `uv.print_all_handles()` except only active handles are printed.
---
--- **Note:** This is not available on Windows.
---
--- **Warning:** This function is meant for ad hoc debugging, there are no API/ABI
--- stability guarantees.
function uv.print_active_handles() end


--- Prints all handles associated with the main loop to stderr. The format is
--- `[flags] handle-type handle-address`. Flags are `R` for referenced, `A` for
--- active and `I` for internal.
---
--- **Note:** This is not available on Windows.
---
--- **Warning:** This function is meant for ad hoc debugging, there are no API/ABI
--- stability guarantees.
function uv.print_all_handles() end


--- Returns the handle's pid.
---
---@param process uv.uv_process_t
---@return integer pid
function uv.process_get_pid(process) end


--- Sends the specified signal to the given process handle. Check the documentation
--- on `uv_signal_t` for signal support, specially on Windows.
---
---@param  process    uv.uv_process_t
---@param  signum     integer|string
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.process_kill(process, signum) end


--- Queues a work request which will run `work_callback` in a new Lua state in a
--- thread from the threadpool with any additional arguments from `...`. Values
--- returned from `work_callback` are passed to `after_work_callback`, which is
--- called in the main loop thread.
---
---@param  work_ctx    uv.luv_work_ctx_t
---@param  ...         uv.threadargs
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.queue_work(work_ctx, ...) end


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
---
--- **Returns (sync version):** `string` or `fail`
---
--- **Returns (async version):** `0` or `fail`
---
---@param  len        integer
---@param  flags?     nil|0|{}
---@return string|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
---
---@overload fun(len:integer, flags?:nil, callback:uv.random.callback):0|nil, string?, string?
function uv.random(len, flags) end


--- Read data from an incoming stream. The callback will be made several times until
--- there is no more data to read or `uv.read_stop()` is called. When we've reached
--- EOF, `data` will be `nil`.
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
---@param  stream     uv.uv_stream_t
---@param  callback   uv.read_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.read_start(stream, callback) end


--- Stop reading data from the stream. The read callback will no longer be called.
---
--- This function is idempotent and may be safely called on a stopped stream.
---
---@param  stream     uv.uv_stream_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.read_stop(stream) end


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
---@param  handle      uv.uv_handle_t
---@param  size?       integer  # default is `0`
---@return integer|nil size_or_ok
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.recv_buffer_size(handle, size) end


--- Reference the given handle. References are idempotent, that is, if a handle is
--- already referenced calling this function again will have no effect.
---
--- See [Reference counting][].
---
---@param handle uv.uv_handle_t
function uv.ref(handle) end


--- Returns the name of the struct for a given request (e.g. `"fs"` for `uv_fs_t`)
--- and the libuv enum integer for the request's type (`uv_req_type`).
---
---@param  req              uv.uv_req_t
---@return uv.req_type.name type
---@return uv.req_type.enum enum
function uv.req_get_type(req) end


--- Returns the resident set size (RSS) for the current process.
---
---@return integer|nil rss
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.resident_set_memory() end


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
---
--- **Note:** Luvit will implicitly call `uv.run()` after loading user code, but if
--- you use the luv bindings directly, you need to call this after registering
--- your initial set of event callbacks to start the event loop.
---
---@param mode? uv.run.mode
---@return boolean
function uv.run(mode) end


--- Gets or sets the size of the send buffer that the operating system uses for the
--- socket.
---
--- If `size` is omitted (or `0`), this will return the current send buffer size; otherwise, this will use `size` to set the new send buffer size.
---
--- This function works for TCP, pipe and UDP handles on Unix and for TCP and UDP
--- handles on Windows.
---
--- **Returns:**
--- - `integer` or `fail` (if `size` is `nil` or `0`)
--- - `0` or `fail` (if `size` is not `nil` and not `0`)
---
--- **Note**: Linux will set double the size and return double the size of the
--- original set value.
---
---@param  handle               uv.uv_handle_t
---@param  size?                integer|0
---@return integer|nil          success
---@return uv.error.message|nil err
---@return uv.error.name|nil    err_name
---
---@overload fun(handle: uv.uv_handle_t):(size:integer|nil, err:uv.error.message|nil, err_name:uv.error.name|nil)
---@overload fun(handle: uv.uv_handle_t, size:0):(size:integer|nil, err:uv.error.message|nil, err_name:uv.error.name|nil)
function uv.send_buffer_size(handle, size) end


--- Sets the title of the current process with the string `title`.
---
---@param  title      string
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.set_process_title(title) end


--- Sets the group ID of the process with the integer `id`.
---
--- **Note:** This is not a libuv function and is not supported on Windows.
---
---@param id integer
function uv.setgid(id) end


--- Sets the user ID of the process with the integer `id`.
---
--- **Note:** This is not a libuv function and is not supported on Windows.
---
---@param id integer
function uv.setuid(id) end


--- Shutdown the outgoing (write) side of a duplex stream. It waits for pending
--- write requests to complete. The callback is called after shutdown is complete.
---
---@param  stream               uv.uv_stream_t
---@param  callback?            uv.shutdown.callback
---@return uv.uv_shutdown_t|nil shutdown
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.shutdown(stream, callback) end


--- Start the handle with the given callback, watching for the given signal.
---
---@param  signal     uv.uv_signal_t
---@param  signum     integer|string
---@param  callback   uv.signal_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.signal_start(signal, signum, callback) end


--- Same functionality as `uv.signal_start()` but the signal handler is reset the moment the signal is received.
---
---@param  signal     uv.uv_signal_t
---@param  signum     integer|string
---@param  callback   uv.signal_start_oneshot.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.signal_start_oneshot(signal, signum, callback) end


--- Stop the handle, the callback will no longer be called.
---@param  signal     uv.uv_signal_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.signal_stop(signal) end


--- Pauses the thread in which this is called for a number of milliseconds.
---@param msec integer
function uv.sleep(msec) end


--- Create a pair of connected sockets with the specified properties. The resulting handles can be passed to `uv.tcp_open`, used with `uv.spawn`, or for any other purpose.
---
--- When specified as a string, `socktype` must be one of `"stream"`, `"dgram"`, `"raw"`,
--- `"rdm"`, or `"seqpacket"`.
---
--- When `protocol` is set to 0 or nil, it will be automatically chosen based on the socket's domain and type. When `protocol` is specified as a string, it will be looked up using the `getprotobyname(3)` function (examples: `"ip"`, `"icmp"`, `"tcp"`, `"udp"`, etc).
---
--- Flags:
---  - `nonblock`: Opens the specified socket handle for `OVERLAPPED` or `FIONBIO`/`O_NONBLOCK` I/O usage. This is recommended for handles that will be used by libuv, and not usually recommended otherwise.
---
--- Equivalent to `socketpair(2)` with a domain of `AF_UNIX`.
---
--- **Returns:** `table` or `fail`
--- - `[1, 2]` : `integer` (file descriptor)
---
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
---
---@param  socktype?  uv.socketpair.socktype
---@param  protocol?  uv.socketpair.protocol
---@param  flags1?    uv.socketpair.flags
---@param  flags2?    uv.socketpair.flags
---@return uv.socketpair.fds|nil fds
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.socketpair(socktype, protocol, flags1, flags2) end


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
--- The `options` table accepts the following fields:
---
---   - `options.args` - Command line arguments as a list of string. The first
---   string should be the path to the program. On Windows, this uses CreateProcess
---   which concatenates the arguments into a string. This can cause some strange
---   errors. (See `options.verbatim` below for Windows.)
---   - `options.stdio` - Set the file descriptors that will be made available to
---   the child process. The convention is that the first entries are stdin, stdout,
---   and stderr. (**Note**: On Windows, file descriptors after the third are
---   available to the child process only if the child processes uses the MSVCRT
---   runtime.)
---   - `options.env` - Set environment variables for the new process.
---   - `options.cwd` - Set the current working directory for the sub-process.
---   - `options.uid` - Set the child process' user id.
---   - `options.gid` - Set the child process' group id.
---   - `options.verbatim` - If true, do not wrap any arguments in quotes, or
---   perform any other escaping, when converting the argument list into a command
---   line string. This option is only meaningful on Windows systems. On Unix it is
---   silently ignored.
---   - `options.detached` - If true, spawn the child process in a detached state -
---   this will make it a process group leader, and will effectively enable the
---   child to keep running after the parent exits. Note that the child process
---   will still keep the parent's event loop alive unless the parent process calls
---   `uv.unref()` on the child's process handle.
---   - `options.hide` - If true, hide the subprocess console window that would
---   normally be created. This option is only meaningful on Windows systems. On
---   Unix it is silently ignored.
---
--- The `options.stdio` entries can take many shapes.
---
---   - If they are numbers, then the child process inherits that same zero-indexed
---   fd from the parent process.
---   - If `uv_stream_t` handles are passed in, those are used as a read-write pipe
---   or inherited stream depending if the stream has a valid fd.
---   - Including `nil` placeholders means to ignore that fd in the child process.
---
--- When the child process exits, `on_exit` is called with an exit code and signal.
---
---@param  path            string
---@param  options         uv.spawn.options
---@param  on_exit         uv.spawn.on_exit
---@return uv.uv_process_t proc
---@return integer         pid
function uv.spawn(path, options, on_exit) end


--- Stop the event loop, causing `uv.run()` to end as soon as possible. This
--- will happen not sooner than the next loop iteration. If this function was called
--- before blocking for I/O, the loop won't block for I/O on this iteration.
function uv.stop() end


--- Returns the stream's write queue size.
---
---@param stream uv.uv_stream_t
---@return integer
function uv.stream_get_write_queue_size(stream) end


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
---@param  stream     uv.uv_stream_t
---@param  blocking   boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.stream_set_blocking(stream, blocking) end


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
---
---@param  tcp        uv.uv_tcp_t
---@param  host       string
---@param  port       integer
---@param  flags?     uv.tcp_bind.flags
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_bind(tcp, host, port, flags) end


--- Resets a TCP connection by sending a RST packet. This is accomplished by setting
--- the SO_LINGER socket option with a linger interval of zero and then calling
--- `uv.close()`. Due to some platform inconsistencies, mixing of `uv.shutdown()`
--- and `uv.tcp_close_reset()` calls is not allowed.
---
---@param  tcp        uv.uv_tcp_t
---@param  callback?  function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_close_reset(tcp, callback) end


--- Establish an IPv4 or IPv6 TCP connection.
---
--- ```lua
--- local client = uv.new_tcp()
--- client:connect("127.0.0.1", 8080, function (err)
---   -- check error and carry on.
--- end)
--- ```
---
---@param  tcp                 uv.uv_tcp_t
---@param  host                string
---@param  port                integer
---@param  callback            uv.tcp_connect.callback
---@return uv.uv_connect_t|nil conn
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_connect(tcp, host, port, callback) end


--- Get the address of the peer connected to the handle.
---
---@param  tcp               uv.uv_tcp_t
---@return uv.socketinfo|nil sockname
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_getpeername(tcp) end


--- Get the current address to which the handle is bound.
---
---@param  tcp               uv.uv_tcp_t
---@return uv.socketinfo|nil sockname
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_getsockname(tcp) end


--- Enable / disable TCP keep-alive. `delay` is the initial delay in seconds,
--- ignored when enable is `false`.
---
---@param  tcp        uv.uv_tcp_t
---@param  enable     boolean
---@param  delay?     integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_keepalive(tcp, enable, delay) end


--- Enable / disable Nagle's algorithm.
---
---@param  tcp        uv.uv_tcp_t
---@param  enable     boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_nodelay(tcp, enable) end


--- Open an existing file descriptor or SOCKET as a TCP handle.
---
--- **Note:** The passed file descriptor or SOCKET is not checked for its type, but it's required that it represents a valid stream socket.
---
---@param  tcp        uv.uv_tcp_t
---@param  sock       integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_open(tcp, sock) end


--- Enable / disable simultaneous asynchronous accept requests that are queued by
--- the operating system when listening for new TCP connections.
---
--- This setting is used to tune a TCP server for the desired performance. Having
--- simultaneous accepts can significantly improve the rate of accepting connections
--- (which is why it is enabled by default) but may lead to uneven load distribution
--- in multi-process setups.
---
---@param  tcp        uv.uv_tcp_t
---@param  enable     boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tcp_simultaneous_accepts(tcp, enable) end


--- **Deprecated:** Please use `uv.stream_get_write_queue_size()` instead.
---
---@param tcp uv.uv_tcp_t
function uv.tcp_write_queue_size(tcp) end


--- Returns a boolean indicating whether two threads are the same. This function is
--- equivalent to the `__eq` metamethod.
---
---@param  thread       uv.luv_thread_t
---@param  other_thread uv.luv_thread_t
---@return boolean      equal
function uv.thread_equal(thread, other_thread) end


--- Waits for the `thread` to finish executing its entry function.
---
---@param  thread      uv.luv_thread_t
---@return boolean|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.thread_join(thread) end


--- Returns the handle for the thread in which this is called.
---
---@return uv.luv_thread_t
function uv.thread_self() end


--- Stop the timer, and if it is repeating restart it using the repeat value as the
--- timeout. If the timer has never been started before it raises `EINVAL`.
---
---@param  timer      uv.uv_timer_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.timer_again(timer) end


--- Get the timer due value or 0 if it has expired. The time is relative to `uv.now()`.
---
--- **Note**: New in libuv version 1.40.0.
---
---@param timer uv.uv_timer_t
---@return integer
function uv.timer_get_due_in(timer) end


--- Get the timer repeat value.
---
---@param timer uv.uv_timer_t
---@return integer
function uv.timer_get_repeat(timer) end


--- Set the repeat interval value in milliseconds. The timer will be scheduled to
--- run on the given interval, regardless of the callback execution duration, and
--- will follow normal timer semantics in the case of a time-slice overrun.
---
--- For example, if a 50 ms repeating timer first runs for 17 ms, it will be
--- scheduled to run again 33 ms later. If other tasks consume more than the 33 ms
--- following the first timer callback, then the callback will run as soon as
--- possible.
---
---@param timer uv.uv_timer_t
---@param repeat_ integer
function uv.timer_set_repeat(timer, repeat_) end


--- Start the timer. `timeout` and `repeat` are in milliseconds.
---
--- If `timeout` is zero, the callback fires on the next event loop iteration. If
--- `repeat` is non-zero, the callback fires first after `timeout` milliseconds and
--- then repeatedly after `repeat` milliseconds.
---
---@param  timer      uv.uv_timer_t
---@param  timeout    integer
---@param  repeat_    integer
---@param  callback   function
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.timer_start(timer, timeout, repeat_, callback) end


--- Stop the timer, the callback will not be called anymore.
---
---@param  timer      uv.uv_timer_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.timer_stop(timer) end


--- Returns the libuv error message and error name (both in string form, see [`err` and `name` in Error Handling](#error-handling)) equivalent to the given platform dependent error code: POSIX error codes on Unix (the ones stored in errno), and Win32 error codes on Windows (those returned by GetLastError() or WSAGetLastError()).
---
---@param errcode integer
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.translate_sys_error(errcode) end


--- Same as `uv.write()`, but won't queue a write request if it can't be completed
--- immediately.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
---
---@param  stream      uv.uv_stream_t
---@param  data        uv.buffer
---@return integer|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.try_write(stream, data) end


--- Like `uv.write2()`, but with the properties of `uv.try_write()`. Not supported on Windows, where it returns `UV_EAGAIN`.
---
--- Will return number of bytes written (can be less than the supplied buffer size).
---
--- **Returns:** `integer` or `fail`
---
---@param  stream      uv.uv_stream_t
---@param  data        uv.buffer
---@param  send_handle uv.uv_stream_t
---@return integer|nil bytes
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.try_write2(stream, data, send_handle) end


--- Get the current state of whether console virtual terminal sequences are handled
--- by libuv or the console. The return value is `"supported"` or `"unsupported"`.
---
--- This function is not implemented on Unix, where it returns `ENOTSUP`.
---
---@return "supported"|"unsupported"|nil state
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tty_get_vterm_state() end


--- Gets the current Window width and height.
---
--- **Returns:** `integer, integer` or `fail`
---
---@param  tty            uv.uv_tty_t
---@return integer|nil    width
---@return integer|string height_or_errmsg
---@return uv.error.name|nil err_name
function uv.tty_get_winsize(tty) end


--- To be called when the program exits. Resets TTY settings to default values for
--- the next process to take over.
---
--- This function is async signal-safe on Unix platforms but can fail with error
--- code `EBUSY` if you call it when execution is inside `uv.tty_set_mode()`.
---
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tty_reset_mode() end


--- Set the TTY using the specified terminal mode.
---
--- Parameter `mode` is a C enum with the following values:
---
---   - 0 - UV_TTY_MODE_NORMAL: Initial/normal terminal mode
---   - 1 - UV_TTY_MODE_RAW: Raw input mode (On Windows, ENABLE_WINDOW_INPUT is
---   also enabled)
---   - 2 - UV_TTY_MODE_IO: Binary-safe I/O mode for IPC (Unix-only)
---
---@param  tty        uv.uv_tty_t
---@param  mode       uv.tty.mode
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.tty_set_mode(tty, mode) end


--- Controls whether console virtual terminal sequences are processed by libuv or
--- console. Useful in particular for enabling ConEmu support of ANSI X3.64 and
--- Xterm 256 colors. Otherwise Windows10 consoles are usually detected
--- automatically. State should be one of: `"supported"` or `"unsupported"`.
---
--- This function is only meaningful on Windows systems. On Unix it is silently
--- ignored.
---
---@param state "supported"|"unsupported"
function uv.tty_set_vterm_state(state) end


--- Bind the UDP handle to an IP address and port. Any `flags` are set with a table
--- with fields `reuseaddr` or `ipv6only` equal to `true` or `false`.
---
---@param  udp        uv.uv_udp_t
---@param  host       string
---@param  port       integer
---@param  flags?     uv.udp_bind.flags
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_bind(udp, host, port, flags) end


--- Associate the UDP handle to a remote address and port, so every message sent by
--- this handle is automatically sent to that destination. Calling this function
--- with a NULL addr disconnects the handle. Trying to call `uv.udp_connect()` on an
--- already connected handle will result in an `EISCONN` error. Trying to disconnect
--- a handle that is not connected will return an `ENOTCONN` error.
---
---@param udp uv.uv_udp_t
---@param host string
---@param port integer
---@return 0|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_connect(udp, host, port) end


--- Returns the handle's send queue count.
---
---@param  udp     uv.uv_udp_t
---@return integer count
function uv.udp_get_send_queue_count(udp) end


--- Returns the handle's send queue size.
---
---@param  udp     uv.uv_udp_t
---@return integer size
function uv.udp_get_send_queue_size(udp) end


--- Get the remote IP and port of the UDP handle on connected UDP handles.
---
---@param  udp                 uv.uv_udp_t
---@return uv.udp.sockname|nil peername
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_getpeername(udp) end


--- Get the local IP and port of the UDP handle.
---
---@param  udp                 uv.uv_udp_t
---@return uv.udp.sockname|nil sockname
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_getsockname(udp) end


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
---@param  udp        uv.uv_udp_t
---@param  fd         integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_open(udp, fd) end


--- Prepare for receiving data. If the socket has not previously been bound with
--- `uv.udp_bind()` it is bound to `0.0.0.0` (the "all interfaces" IPv4 address)
--- and a random port number.
---
---@param  udp        uv.uv_udp_t
---@param  callback   uv.udp_recv_start.callback
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_recv_start(udp, callback) end


--- Stop listening for incoming datagrams.
---
---@param  udp        uv.uv_udp_t
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_recv_stop(udp) end


--- Send data over the UDP socket. If the socket has not previously been bound
--- with `uv.udp_bind()` it will be bound to `0.0.0.0` (the "all interfaces" IPv4
--- address) and a random port number.
---
---@param  udp                  uv.uv_udp_t
---@param  data                 uv.buffer
---@param  host                 string
---@param  port                 integer
---@param  callback             uv.udp_send.callback
---@return uv.uv_udp_send_t|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_send(udp, data, host, port, callback) end


--- Set broadcast on or off.
---
---@param  udp        uv.uv_udp_t
---@param  on         boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_set_broadcast(udp, on) end


--- Set membership for a multicast address. `multicast_addr` is multicast address to
--- set membership for. `interface_addr` is interface address. `membership` can be
--- the string `"leave"` or `"join"`.
---
---@param  udp            uv.uv_udp_t
---@param  multicast_addr string
---@param  interface_addr string
---@param  membership     "leave"|"join"
---@return 0|nil          success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_set_membership(udp, multicast_addr, interface_addr, membership) end


--- Set the multicast interface to send or receive data on.
---
---@param  udp            uv.uv_udp_t
---@param  interface_addr string
---@return 0|nil          success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_set_multicast_interface(udp, interface_addr) end


--- Set IP multicast loop flag. Makes multicast packets loop back to local
--- sockets.
---
---@param  udp        uv.uv_udp_t
---@param  on         boolean
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_set_multicast_loop(udp, on) end


--- Set the multicast ttl.
---
--- `ttl` is an integer 1 through 255.
---
---@param  udp        uv.uv_udp_t
---@param  ttl        integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_set_multicast_ttl(udp, ttl) end


--- Set membership for a source-specific multicast group. `multicast_addr` is multicast
--- address to set membership for. `interface_addr` is interface address. `source_addr`
--- is source address. `membership` can be the string `"leave"` or `"join"`.
---
---@param  udp            uv.uv_udp_t
---@param  multicast_addr string
---@param  interface_addr string|nil
---@param  source_addr    string
---@param  membership     "leave"|"join"
---@return 0|nil          success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_set_source_membership(udp, multicast_addr, interface_addr, source_addr, membership) end


--- Set the time to live.
---
--- `ttl` is an integer 1 through 255.
---
---@param  udp        uv.uv_udp_t
---@param  ttl        integer
---@return 0|nil      success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_set_ttl(udp, ttl) end


--- Same as `uv.udp_send()`, but won't queue a send request if it can't be
--- completed immediately.
---
---@param  udp         uv.uv_udp_t
---@param  data        uv.buffer
---@param  host        string
---@param  port        integer
---@return integer|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.udp_try_send(udp, data, host, port) end


--- Un-reference the given handle. References are idempotent, that is, if a handle
--- is not referenced calling this function again will have no effect.
---
--- See [Reference counting][].
---
---@param handle uv.uv_handle_t
function uv.unref(handle) end


--- Update the event loop's concept of "now". Libuv caches the current time at the
--- start of the event loop tick in order to reduce the number of time-related
--- system calls.
---
--- You won't normally need to call this function unless you have callbacks that
--- block the event loop for longer periods of time, where "longer" is somewhat
--- subjective but probably on the order of a millisecond or more.
function uv.update_time() end


--- Returns the current system uptime in seconds.
---
---@return number|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.uptime() end


--- Returns the libuv version packed into a single integer. 8 bits are used for each
--- component, with the patch number stored in the 8 least significant bits. For
--- example, this would be 0x010203 in libuv 1.2.3.
---
---@return integer
function uv.version() end


--- Returns the libuv version number as a string. For example, this would be "1.2.3"
--- in libuv 1.2.3. For non-release versions, the version suffix is included.
---
---@return string
function uv.version_string() end


--- Walk the list of handles: `callback` will be executed with each handle.
---
--- ```lua
--- -- Example usage of uv.walk to close all handles that aren't already closing.
--- uv.walk(function (handle)
---   if not handle:is_closing() then
---     handle:close()
---   end
--- end)
--- ```
---
---@param callback uv.walk.callback
function uv.walk(callback) end


--- Write data to stream.
---
--- `data` can either be a Lua string or a table of strings. If a table is passed
--- in, the C backend will use writev to send all strings in a single system call.
---
--- The optional `callback` is for knowing when the write is complete.
---
---@param  stream            uv.uv_stream_t
---@param  data              uv.buffer
---@param  callback?         uv.write.callback
---@return uv.uv_write_t|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.write(stream, data, callback) end

--- Extended write function for sending handles over a pipe. The pipe must be
--- initialized with `ipc` option `true`.
---
--- **Note:** `send_handle` must be a TCP socket or pipe, which is a server or a
--- connection (listening or connected state). Bound sockets or pipes will be
--- assumed to be servers.
---
---@param  stream            uv.uv_stream_t
---@param  data              uv.buffer
---@param  send_handle       uv.uv_stream_t
---@param  callback?         uv.write2.callback
---@return uv.uv_write_t|nil success
---@return uv.error.message|nil err
---@return uv.error.name|nil err_name
function uv.write2(stream, data, send_handle, callback) end