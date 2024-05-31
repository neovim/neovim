---@meta

---@class uv.getrusage.result.time_t
---@field sec integer
---@field usec integer

---@class uv.getrusage.result
---
---@field utime    uv.getrusage.result.time_t # user CPU time used
---@field stime    uv.getrusage.result.time_t # system CPU time used
---@field maxrss   integer                    # maximum resident set size
---@field ixrss    integer                    # integral shared memory size
---@field idrss    integer                    # integral unshared data size
---@field isrss    integer                    # integral unshared stack size
---@field minflt   integer                    # page reclaims (soft page faults)
---@field majflt   integer                    # page faults (hard page faults)
---@field nswap    integer                    # swaps
---@field inblock  integer                    # block input operations
---@field oublock  integer                    # block output operations
---@field msgsnd   integer                    # IPC messages sent
---@field msgrcv   integer                    # IPC messages received
---@field nsignals integer                    # signals received
---@field nvcsw    integer                    # voluntary context switches
---@field nivcsw   integer                    # involuntary context switches


---@alias uv.spawn.options.stdio.fd integer

---@alias uv.spawn.options.stdio.stream uv.uv_stream_t


--- The `options.stdio` entries can take many shapes.
---
---   - If they are numbers, then the child process inherits that same zero-indexed fd from the parent process.
---   - If `uv_stream_t` handles are passed in, those are used as a read-write pipe or inherited stream depending if the stream has a valid fd.
---   - Including `nil` placeholders means to ignore that fd in the child process.
---
---@alias uv.spawn.options.stdio
---| integer
---| uv.uv_stream_t
---| nil


---@class uv.spawn.options : table
---
--- Command line arguments as a list of strings. The first string should be the path to the program. On Windows, this uses CreateProcess which concatenates the arguments into a string. This can cause some strange errors. (See `options.verbatim` below for Windows.)
---@field args string[]
---
--- Set environment variables for the new process.
---@field env table<string, string>
---
--- Set the current working directory for the sub-process.
---@field cwd string
---
--- Set the child process' user id.
---@field uid string
---
--- Set the child process' group id.
---@field gid string
---
--- If true, do not wrap any arguments in quotes, or perform any other escaping, when converting the argument list into a command line string. This option is only meaningful on Windows systems. On Unix it is silently ignored.
---@field verbatim boolean
---
--- If true, spawn the child process in a detached state - this will make it a process group leader, and will effectively enable the child to keep running after the parent exits. Note that the child process will still keep the parent's event loop alive unless the parent process calls `uv.unref()` on the child's process handle.
---@field detached boolean
---
--- If true, hide the subprocess console window that would normally be created. This option is only meaningful on Windows systems. On Unix it is silently ignored.
---@field hide boolean
---
--- Set the file descriptors that will be made available to the child process. The convention is that the first entries are stdin, stdout, and stderr. (**Note**: On Windows, file descriptors after the third are available to the child process only if the child processes uses the MSVCRT runtime.)
---@field stdio { [1]: uv.spawn.options.stdio, [2]: uv.spawn.options.stdio, [3]: uv.spawn.options.stdio }


---@class uv.fs_stat.result.time
---@field sec integer
---@field nsec integer

---@class uv.fs_stat.result
---
---@field dev       integer
---@field mode      integer
---@field nlink     integer
---@field uid       integer
---@field gid       integer
---@field rdev      integer
---@field ino       integer
---@field size      integer
---@field blksize   integer
---@field blocks    integer
---@field flags     integer
---@field gen       integer
---@field atime     uv.fs_stat.result.time
---@field mtime     uv.fs_stat.result.time
---@field ctime     uv.fs_stat.result.time
---@field birthtime uv.fs_stat.result.time
---@field type      string


---@class uv.fs_statfs.result
---
---@field type   integer
---@field bsize  integer
---@field blocks integer
---@field bfree  integer
---@field bavail integer
---@field files  integer
---@field ffree  integer



---@class uv.getaddrinfo.hints : table
---@field family      string|integer|uv.socket.family
---@field socktype    string|integer|uv.socket.type
---@field protocol    string|integer|uv.socket.protocol
---@field addrconfig  boolean
---@field v4mapped    boolean
---@field all         boolean
---@field numerichost boolean
---@field passive     boolean
---@field numericserv boolean
---@field canonname   boolean


--- uv.getnameinfo.address
---
---@class uv.getnameinfo.address : table
---@field ip     string
---@field port   integer
---@field family string|integer


--- uv.new_thread.options
---
---@class uv.new_thread.options : table
---@field stack_size integer


--- uv.pipe.read_flags
---
---@class uv.pipe.read_flags : table
---@field nonblock boolean|false


--- uv.pipe.write_flags
---
---@class uv.pipe.write_flags : table
---@field nonblock boolean|false

---@alias uv.socketpair.fds { [1]: integer, [2]: integer }

--- uv.socketpair.flags
---
---@class uv.socketpair.flags : table
---
--- Opens the specified socket handle for `OVERLAPPED` or `FIONBIO`/`O_NONBLOCK` I/O usage. This is recommended for handles that will be used by libuv, and not usually recommended otherwise.
---@field nonblock true|false

---@alias uv.socket.protocol
---| string
---| "ip"
---| "icmp"
---| "tcp"
---| "udp"

---@alias uv.socket.type
---| "stream"
---| "dgram"
---| "raw"
---| "rdm"
---| "seqpacket"

--- When `protocol` is set to 0 or nil, it will be automatically chosen based on the socket's domain and type.
---
--- When `protocol` is specified as a string, it will be looked up using the `getprotobyname(3)` function (examples: `"ip"`, `"icmp"`, `"tcp"`, `"udp"`, etc).
---
---@alias uv.socketpair.protocol
---| 0   # automatically choose based on socket domain/type
---| nil # automatically choose based on socket domain/type
---| uv.socket.protocol

---@alias uv.socketpair.socktype
---| uv.socket.type
---| integer
---| nil

--- uv.tcp_bind.flags
---
---@class uv.tcp_bind.flags : table
---@field ipv6only boolean


--- uv.udp_bind.flags
---
---
---@class uv.udp_bind.flags : table
---@field ipv6only boolean
---@field reuseaddr boolean

--- TTY mode is a C enum with the following values:
---
---@alias uv.tty.mode
---| 0 # UV_TTY_MODE_NORMAL: Initial/normal terminal mode
---| 1 # UV_TTY_MODE_RAW: Raw input mode (On Windows, ENABLE_WINDOW_INPUT is also enabled)
---| 2 # UV_TTY_MODE_IO: Binary-safe I/O mode for IPC (Unix-only)


--- uv.run() modes:
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
---@alias uv.run.mode
---| "default" # Runs the event loop until there are no more active and referenced handles or requests.
---| "once" # Poll for I/O once.
---| "nowait" # Poll for I/O once but don't block if there are no pending callbacks.


---@class uv.interface_addresses.addr
---
---@field ip       string
---@field family   string
---@field netmask  string
---@field internal boolean
---@field mac      string

---@class uv.new_udp.flags
---
--- When specified, `mmsgs` determines the number of messages able to be received at one time via `recvmmsg(2)` (the allocated buffer will be sized to be able to fit the specified number of max size dgrams). Only has an effect on platforms that support `recvmmsg(2)`.
---@field mmsgs integer|nil # default `1`
---
---@field family uv.new_udp.flags.family|nil

---@alias uv.new_udp.flags.family uv.socket.family

---@alias uv.socket.family
---| "unix"
---| "inet"
---| "inet6"
---| "ipx"
---| "netlink"
---| "x25"
---| "ax25"
---| "atmpvc"
---| "appletalk"
---| "packet"


---@class uv.os_get_passwd.info
---@field username string
---@field uid integer
---@field gid integer
---@field shell string
---@field homedir string

---@class uv.os_uname.info
---@field sysname string
---@field release string
---@field version string
---@field machine string

---@alias uv.pipe_chmod.flags
---| "r"
---| "rw"
---| "w"
---| "wr"

--- `r` is `READABLE`
--- `w` is `WRITABLE`
--- `d` is `DISCONNECT`
--- `p` is `PRIORITIZED`
---
---@alias uv.poll.eventspec
---| "r"
---| "rd"
---| "rw"
---| "rp"
---| "rdp"
---| "rwd"
---| "rwp"
---| "rwdp"
---| "d"
---| "dp"
---| "w"
---| "wd"
---| "wp"
---| "wdp"
---| "p"



--- socket info
---
---@class uv.socketinfo : table
---@field ip string
---@field family string|uv.socket.family
---@field port integer


--- uv.udp.sockname
---
---@alias uv.udp.sockname uv.socketinfo


---@class uv.uv_fs_t          : uv.uv_req_t
---@class uv.uv_write_t       : uv.uv_req_t
---@class uv.uv_connect_t     : uv.uv_req_t
---@class uv.uv_shutdown_t    : uv.uv_req_t
---@class uv.uv_udp_send_t    : uv.uv_req_t
---@class uv.uv_getaddrinfo_t : uv.uv_req_t
---@class uv.uv_getnameinfo_t : uv.uv_req_t
---@class uv.uv_work_t        : uv.uv_req_t

---@class uv.pipe.fds
---@field read integer
---@field write integer

---@class uv.fs_copyfile.flags_t : table
---@field excl          boolean
---@field ficlone       boolean
---@field ficlone_force boolean

---@alias uv.fs_copyfile.flags
---| uv.fs_copyfile.flags_t
---| integer


---@class uv.fs_event_start.flags : table
---@field watch_entry boolean|nil # default: false
---@field stat        boolean|nil # default: false
---@field recursive   boolean|nil # default: false

---@class uv.fs_event_start.callback.events : table
---@field change boolean|nil
---@field rename boolean|nil

--- Event loop
---
--- The event loop is the central part of libuv's functionality. It takes care of
--- polling for I/O and scheduling callbacks to be run based on different sources of
--- events.
---
--- In luv, there is an implicit uv loop for every Lua state that loads the library.
--- You can use this library in an multi-threaded environment as long as each thread
--- has it's own Lua state with its corresponding own uv loop. This loop is not
--- directly exposed to users in the Lua module.
---
---@class uv.uv_loop_t : table

---@alias uv.threadargs any

--- Luv APIS that accept a "buffer" type will accept either a string or an array-like table of strings
---@alias uv.buffer string|string[]

---@alias uv.fs_mkdtemp.callback           fun(err: uv.callback.err, path?:string)
---@alias uv.fs_access.callback            fun(err: uv.callback.err, permission?:boolean)
---@alias uv.fs_event_start.callback       fun(err: uv.callback.err, filename:string, events:uv.fs_event_start.callback.events)
---@alias uv.fs_poll_start.callback        fun(err: uv.callback.err, prev:uv.fs_stat.result|nil, curr:uv.fs_stat.result|nil)
---@alias uv.fs_fstat.callback             fun(err: uv.callback.err, stat:uv.fs_stat.result|nil)
---@alias uv.fs_lstat.callback             fun(err: uv.callback.err, stat:uv.fs_stat.result|nil)
---@alias uv.fs_mkstemp.callback           fun(err: uv.callback.err, fd?:integer, path?:string)
---@alias uv.fs_opendir.callback           fun(err: uv.callback.err, dir?:uv.luv_dir_t)
---@alias uv.fs_open.callback              fun(err: uv.callback.err, fd?:integer)
---@alias uv.fs_read.callback              fun(err: uv.callback.err, data?:string)
---@alias uv.fs_scandir.callback           fun(err: uv.callback.err, success?:uv.uv_fs_t)
---@alias uv.fs_sendfile.callback          fun(err: uv.callback.err, bytes?:integer)
---@alias uv.fs_stat.callback              fun(err: uv.callback.err, stat: uv.fs_stat.result|nil)
---@alias uv.getaddrinfo.callback          fun(err: uv.callback.err, addresses:uv.getaddrinfo.result[]|nil)
---@alias uv.getnameinfo.callback          fun(err: uv.callback.err, host?:string, service?:string)
---@alias uv.fs_write.callback             fun(err: uv.callback.err, bytes?:integer)
---@alias uv.new_async.callback            fun(...:uv.threadargs)
---@alias uv.new_work.after_work_callback  fun(...:uv.threadargs)
---@alias uv.new_work.work_callback        fun(...:uv.threadargs)
---@alias uv.poll_start.callback           fun(err: uv.callback.err, events?:string)
---@alias uv.random.callback               fun(err: uv.callback.err, bytes?:string)
---@alias uv.read_start.callback           fun(err: uv.callback.err, data?:string)
---@alias uv.signal_start.callback         fun(signum:string)
---@alias uv.signal_start_oneshot.callback fun(signum:string)
---@alias uv.spawn.on_exit                 fun(code:integer, signal:integer)
---@alias uv.fs_readlink.callback          fun(err: uv.callback.err, path?:string)
---@alias uv.fs_realpath.callback          fun(err: uv.callback.err, path?:string)
---@alias uv.fs_readdir.callback           fun(err: uv.callback.err, entries: uv.fs_readdir.entry[]|nil)


---@class uv.fs_readdir.entry : table
---@field name string
---@field type string


---@class uv.udp_recv_start.callback.addr : table
---@field ip string
---@field port integer
---@field family uv.socket.family|string

---@class uv.udp_recv_start.callback.flags : table
---@field partial boolean|nil
---@field mmsg_chunk boolean|nil

---@alias uv.udp_recv_start.callback fun(err:string|nil, data:string|nil, addr:uv.udp_recv_start.callback.addr|nil, flags:uv.udp_recv_start.callback.flags)

---@alias uv.walk.callback fun(handle:uv.uv_handle_t)

---@alias uv.fs_statfs.callback    fun(err: uv.callback.err, stat: uv.fs_statfs.result|nil)

---@alias uv.pipe_connect.callback uv.callback
---@alias uv.shutdown.callback     uv.callback
---@alias uv.tcp_connect.callback  uv.callback
---@alias uv.udp_send.callback     uv.callback
---@alias uv.write.callback        uv.callback
---@alias uv.write2.callback       uv.callback
---@alias uv.listen.callback       uv.callback

---@alias uv.fs_closedir.callback  uv.callback_with_success
---@alias uv.fs_copyfile.callback  uv.callback_with_success
---@alias uv.fs_symlink.callback   uv.callback_with_success
---@alias uv.fs_unlink.callback    uv.callback_with_success
---@alias uv.fs_utime.callback     uv.callback_with_success
---@alias uv.fs_chmod.callback     uv.callback_with_success
---@alias uv.fs_chown.callback     uv.callback_with_success
---@alias uv.fs_close.callback     uv.callback_with_success
---@alias uv.fs_fchmod.callback    uv.callback_with_success
---@alias uv.fs_fchown.callback    uv.callback_with_success
---@alias uv.fs_fdatasync.callback uv.callback_with_success
---@alias uv.fs_fsync.callback     uv.callback_with_success
---@alias uv.fs_ftruncate.callback uv.callback_with_success
---@alias uv.fs_futime.callback    uv.callback_with_success
---@alias uv.fs_lchown.callback    uv.callback_with_success
---@alias uv.fs_link.callback      uv.callback_with_success
---@alias uv.fs_lutime.callback    uv.callback_with_success
---@alias uv.fs_mkdir.callback     uv.callback_with_success
---@alias uv.fs_rename.callback    uv.callback_with_success
---@alias uv.fs_rmdir.callback     uv.callback_with_success

---@class uv.fs_symlink.flags : table
---@field dir boolean
---@field junction boolean

---@class uv.getaddrinfo.result : table
---
---@field addr      string
---@field family    uv.socket.family|string
---@field port      integer|nil
---@field socktype  string
---@field protocol  string
---@field canonname string|nil

---@alias uv.callback.err string|nil

---@alias uv.callback.success boolean|nil

---@alias uv.callback fun(err: uv.callback.err)

---@alias uv.callback_with_success fun(err: uv.callback.err, success: uv.callback.success)


---@alias uv.fs_open.flags string
---| "r"
---| "rs"
---| "sr"
---| "r+"
---| "rs+"
---| "sr+"
---| "w"
---| "wx"
---| "xw"
---| "w+"
---| "wx+"
---| "xw+"
---| "a"
---| "ax"
---| "xa"
---| "a+"
---| "ax+"
---| "xa+"
---| integer


---@class uv.cpu_info.cpu : table
---@field model string
---@field speed number
---@field times uv.cpu_info.cpu.times

---@class uv.cpu_info.cpu.times : table
---@field user number
---@field nice number
---@field sys  number
---@field idle number
---@field irq  number


--- The name of the struct for a given request (e.g. `"fs"` for `uv_fs_t`)
--- and the libuv enum integer for the request's type (`uv_req_type`).
---
---@alias uv.req_type.name
---| "async"
---| "check"
---| "fs_event"
---| "fs_poll"
---| "handle"
---| "idle"
---| "pipe"
---| "poll"
---| "prepare"
---| "process"
---| "req"
---| "signal"
---| "stream"
---| "tcp"
---| "timer"
---| "tty"
---| "udp"


--- The libuv enum integer for the request's type (`uv_req_type`).
---@alias uv.req_type.enum integer
