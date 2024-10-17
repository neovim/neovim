# lua-client

Lua-Client is a Neovim client and remote plugin host.

### Setup

1. Install this repo as a Neovim plugin using your plugin manager of choice.
1. Install the lua modules: luv mpack

### Development

The development environment requires the following rocks: busted, luacheck

The script setup.sh sets up a development environment using [hererocks](https://github.com/mpeterv/hererocks#readme).

### Example

See [garyburd/neols](https://github.com/garyburd/neols#readme).

# Documentation

## Module neovim

### Type Nvim

The `Nvim` type is an Nvim client.

Nvim API functions are exposed as methods on the Nvim type with the `nvim_`
prefix removed. Example: `nvim_buf_get_var` function is exposed as
`Nvim:buf_get_var(name) -> value`.

The buf, win and tabpage types are returned by several Nvim client methods.
Applications can construct values of these types using the `Nvim:buf(id) ->
buf`, `Nvim:win(id) -> win` and `Nvim:tabpage(id) -> tabpage` methods.

The buf, win and tabpage types also expose API methods with the `nvim_type` prefix removed.
Example: `nvim_buf_get_var` function is exposed as `buf:get_var(name) -> value`.

### Nvim:request(method, ...) --> result

Send RPC API request to Nvim. Normally a blocking request is sent. If the last
argument is the sentinel value Nvim.notify, then an asynchronous notification
is sent instead and any error returned from the method is ignored.

The following calls are identical:

    nvim:request('nvim_buf_set_var', buf, 'x', 1)
    nvim:buf_set_var(buf, 'x', 1)   -- call method with nvim_ prefix removed
    buf:set_var('x', 1)             -- call method with nvim_buf_ prefix removed.

### new(w, r) -> Nvim

Creates a new client given a write and read
[uv\_stream\_t](https://github.com/luvit/luv/blob/master/docs.md#uv_stream_t--stream-handle)
handles.

### new\_child(cmd, [args, [env]]) --> Nvim

Creates a child process running the command `cmd` and returns a client connected
to the child. Call `Nvim:close()` to end the child process. Use array `args` to
specify the command line arguments and table `env` to specify the environment.
The `args` array should typically include `--embed`. If `env` is not set, then
the child process environment is inherited from the current process.

### new\_stdio() --> Nvim

Create client connected to stdin and stdout of the current process.

### Nvim.handlers

The client dispatches incoming requests and notifications using this table. The
keys are method names and the values are the function to call.

### Nvim:buf(id) --> buffer

Return a buffer given the buffer's integer id.

### Nvim:win(id) --> window

Return a window given the window's integer id.

### Nvim:tabpage(id) --> tabpage

Return a tabpage given the tabpage's integer id.

### Nvim:request(method, ...) --> result

Send RPC API request to Nvim. Normally a blocking request is sent. If the last
argument is the sentinel value `Nvim.notify`, then an asynchronous
notification is sent instead and any error returned from the method is ignored.

Nvim RPC API methods can also be called as methods on the Nvim, Buffer, Window
and Tabpage types. The following calls are identical:

    nvim:request('nvim_buf_set_var', buf, 'x', 1)
    nvim:buf_set_var(buf, 'x', 1)   -- call method with nvim_ prefix removed
    buf:set_var('x', 1)             -- call method with nvim_buf_ prefix removed.

### Nvim:call(funcname, ...) --> result

Call vim function `funcname` with args `...` and return the result. This method
is a helper for the following where `args` is an array:

    nvim:call_function(funcname, args)

### Nvim:close()

Close the connection to Nvim. If the nvim process was started by `new_child()`,
then the child process is closed.

## Module Plugin

This module and pmain.lua implement a Nvim plugin host. The host loads plugins
from rplugin/lua/\*.lua with the following globals:

- **nvim** - An Nvim client
- **plugin** - A table with functions autocmd, command and func for declaring plugin handlers.

### Type Host

Host is the remote plugin host.

### Type Plugin

Plugin represents an individual plugin.

### new\_host(Nvim) -> Host

### Host:get\_plugin(path) -> Plugin

### Plugin:load\_script(path) -> specs, handlers

# Credits

Originally written by @garyburd (Gary Burd).
