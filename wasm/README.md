# Neovim → WebAssembly

This directory contains the build scripts and host glue for compiling the core
Neovim engine to WebAssembly with [Emscripten](https://emscripten.org/). The
resulting `nvim.js` / `nvim.wasm` pair runs the real editor — the full C core,
PUC Lua 5.1, the bundled runtime — as an `nvim --embed` msgpack-RPC server,
under Node.js and (with a host page) in the browser.

Everything here is **additive and `EMSCRIPTEN`-guarded**: the native build is
unaffected, and all native tests pass unchanged.

## Prerequisites

| Need | Why |
|---|---|
| `emcc` (Emscripten) ≥ 3.1.6x | must support `-sJSPI` |
| `cmake` + `ninja` | the usual Neovim build drivers |
| A native build in `build/` | provides the host codegen helper `build/lib/libnlua0.so` (`cmake --build build --target nlua0`) and the host LuaJIT at `.deps/usr/bin/luajit` |
| Node ≥ 24 | runs the engine (JSPI on by default; 22/23 need `--experimental-wasm-jspi`) |

## Building

```sh
# one-time: the native codegen helper
cmake --build build --target nlua0

wasm/build-deps.sh   # cross-compile bundled deps -> .deps-wasm/usr  (slow; cached)
wasm/build-nvim.sh   # cross-compile nvim         -> build-wasm/bin/nvim.{js,wasm}
```

## Running (headless, under Node)

```sh
node build-wasm/bin/nvim.js -- --version
node build-wasm/bin/nvim.js -- -u NONE --headless -l script.lua
node build-wasm/bin/nvim.js -- --embed          # msgpack-RPC server on stdin/stdout
```

Everything after the literal `--` is ordinary nvim argv. Under Node the
`$VIMRUNTIME` is read from the in-tree `runtime/` directory through a NODEFS
mount — no packaging step is needed.

## How the cross-compile works

Neovim generates a lot of C from Lua at build time. Those generators are
host-architecture-independent, but need a host Lua plus the `nlua0` C module.
The upstream build already supports a prebuilt host nlua0 via `NLUA0_HOST_PRG`
when cross-compiling, so the wasm build is a normal two-stage cross build:
the native `build/` supplies codegen, `build-wasm/` compiles the C with emcc.

Key choices (see `wasm/build-nvim.sh` and the `if(EMSCRIPTEN)` block in
`src/nvim/CMakeLists.txt`):

- **PUC Lua 5.1, from source** (`PREFER_LUA=ON`, `COMPILE_LUA=OFF`): LuaJIT
  cannot target wasm, and Lua 5.1 bytecode is word-size-dependent, so the
  runtime's Lua is embedded as source rather than host bytecode.
- **JSPI + wasm setjmp/longjmp** (`-sJSPI`, `-sSUPPORT_LONGJMP=wasm`): the
  libuv event loop blocks in `poll()`; under wasm that "block" is an async
  suspend via JavaScript Promise Integration. The default Emscripten longjmp
  uses JS trampolines that JSPI cannot suspend across, so the wasm-native
  model is used everywhere (deps included — the models must match).
- **libuv's portable poll backend**: libuv has no wasm target; a small patch
  (`cmake.deps/cmake/PatchLibuvEmscripten.cmake`) compiles its generic
  `poll(2)` backend. The handful of symbols that build omits are stubbed in
  `wasm/uv_stubs.c`.
- **MEMFS + NODEFS, not NODERAWFS** (`-sFORCE_FILESYSTEM -lnodefs.js`):
  fd 0/1 stay first-class virtual streams, so `wasm/nvim_io.js` can back them
  with a postMessage RPC channel when the engine runs in a worker with no
  real stdio. Under Node the host filesystem is NODEFS-mounted at the same
  paths, so absolute paths and the on-disk runtime resolve unchanged.

## What works / what doesn't

Works: the full editor headless — `vim.api`, Lua, the bundled runtime,
`--embed` RPC, real file editing under Node.

Not available in the wasm sandbox (the relevant `uv_*` calls return
`ENOSYS`, and features degrade the way they do on any platform without the
capability): child processes (`:!`, `jobstart()`, `:terminal`, `vim.system()`),
sockets (`--listen`, `sockconnect()`), filesystem watching, threads
(`vim.uv.new_thread`).

## File map

| File | Role |
|---|---|
| `build-deps.sh` | cross-compile bundled deps → `.deps-wasm/usr` |
| `build-nvim.sh` | configure + build nvim → `build-wasm/bin/nvim.{js,wasm}` |
| `shim.h` | force-included into every emcc compile; libc gap-fills |
| `uv_stubs.c` | libuv symbols the Emscripten build omits (linked into nvim only) |
| `pre.js` | `--pre-js`: argv convention, `$VIMRUNTIME`, env, FS mounts, worker channel overrides |
| `extern-pre.js` | `--extern-pre-js`: `locateFile` fix so artifacts resolve from any cwd |
| `nvim_io.js` | `--js-library`: JSPI-suspending `__syscall_poll` + postMessage-backed fd 0/1 |
