#!/usr/bin/env bash
# wasm/build-deps.sh - Cross-compile Neovim's bundled dependencies to
# WebAssembly with Emscripten.
#
# Produces static wasm libraries + headers under .deps-wasm/usr:
#   libuv, lua (PUC 5.1), lpeg, luv, unibilium, utf8proc, tree-sitter
#   and the bundled tree-sitter parsers.
#
# Key differences from the native deps build (cmake.deps):
#   * USE_BUNDLED_LUAJIT=OFF / USE_BUNDLED_LUA=ON
#       LuaJIT cannot target wasm; we use portable PUC Lua 5.1 instead. This is
#       exactly what Neovim's PREFER_LUA mode expects.
#   * ENABLE_WASMTIME=OFF
#       The tree-sitter wasm-parser feature needs wasmtime (a native runtime);
#       irrelevant when nvim itself is wasm.
#   * EMCC_CFLAGS force-includes wasm/shim.h into every compile (see that file).
#
# Run from anywhere; paths are resolved relative to the repo root.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_BIN="${ROOT}/.deps-wasm"
DEPS_USR="${DEPS_BIN}/usr"
DOWNLOADS="${DEPS_BIN}/build/downloads"
# Fast path: reuse a previously built install. In CI only .deps-wasm/usr is
# cached (the path-independent libs + headers) -- never the CMake configure
# tree, which embeds emsdk's absolute path and goes stale when emsdk is
# reinstalled to a new temp dir. If the install is already present, there is
# nothing to do; build-nvim.sh consumes only ${DEPS_USR}.
if [ -f "${DEPS_USR}/lib/liblua.a" ] && [ -d "${DEPS_USR}/include" ]; then
  # The engine links -sMAIN_MODULE=2 (dynamic tree-sitter grammar loading), so
  # every object in every archive must be PIC -- a non-PIC install fails the
  # nvim link with "relocation R_WASM_MEMORY_ADDR_* ...; recompile with -fPIC".
  # The marker distinguishes a PIC install from a stale pre-PIC one (which must
  # be rebuilt, not reused).
  if [ ! -f "${DEPS_USR}/.built-with-fpic" ]; then
    echo "==> Existing install predates the -fPIC requirement (MAIN_MODULE); rebuilding"
    rm -rf "${DEPS_BIN}"
  else
    echo "==> Reusing existing wasm deps under ${DEPS_USR} (skipping build)"
    ls -la "${DEPS_USR}/lib" || true
    exit 0
  fi
fi

# Force-include the wasm shim into every emcc invocation, and use wasm-native
# setjmp/longjmp. The latter is REQUIRED for JSPI: the default emscripten
# setjmp/longjmp uses JS `invoke_*` trampolines, and those JS stack frames make
# JSPI suspension fail with "trying to suspend JS frames". Lua (and nvim) use
# longjmp for error handling, so deps must be built with the same model as nvim.
# -fPIC: the engine links -sMAIN_MODULE=2 (so third-party tree-sitter grammars
# can be dlopen'd as emscripten side modules), which makes the main module
# itself relocatable -- every object linked into it must be position-independent.
export EMCC_CFLAGS="-include ${ROOT}/wasm/shim.h -sSUPPORT_LONGJMP=wasm -fPIC ${EMCC_CFLAGS:-}"

echo "==> Seeding download cache (reuse native deps tarballs, no network needed)"
mkdir -p "${DOWNLOADS}"
if [ -d "${ROOT}/.deps/build/downloads" ]; then
  cp -rn "${ROOT}/.deps/build/downloads/." "${DOWNLOADS}/" 2>/dev/null || true
fi

echo "==> Configuring wasm deps (.deps-wasm)"
emcmake cmake \
  -S "${ROOT}/cmake.deps" \
  -B "${DEPS_BIN}" \
  -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D USE_BUNDLED_LUAJIT=OFF \
  -D USE_BUNDLED_LUA=ON \
  -D ENABLE_WASMTIME=OFF

echo "==> Building wasm deps"
cmake --build "${DEPS_BIN}"

# Mark the install as PIC-built (see the fast-path check above).
touch "${DEPS_USR}/.built-with-fpic"

echo "==> Done. Wasm deps installed under ${DEPS_BIN}/usr"
ls -la "${DEPS_BIN}/usr/lib" || true
