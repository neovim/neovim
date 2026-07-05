#!/usr/bin/env bash
# wasm/build-nvim.sh - Cross-compile the Neovim executable to WebAssembly.
#
# Prereqs:
#   * wasm/build-deps.sh has been run (produces .deps-wasm/usr/...).
#   * A native build exists in build/ providing the host codegen helper
#     build/lib/libnlua0.so (run: cmake --build build --target nlua0).
#
# Cross-compilation strategy
# --------------------------
# Neovim's build generates a lot of C from Lua at build time. Those generators
# are host-architecture-independent (they parse C/Lua source), but they need a
# host Lua interpreter + the `nlua0` Lua C-module. When cross-compiling, the
# upstream build already supports pointing at a prebuilt host nlua0 via
# NLUA0_HOST_PRG (see src/nvim/CMakeLists.txt). We reuse the LuaJIT-built host
# nlua0 from the native build and drive codegen with the bundled host luajit.
#
#   * PREFER_LUA=ON     -> link PUC Lua 5.1 (LuaJIT can't target wasm).
#   * COMPILE_LUA=OFF   -> embed Lua *source* not bytecode. Lua 5.1 bytecode is
#                          word-size/endianness dependent, so host (64-bit)
#                          bytecode would not load in the wasm32 runtime.
#   * CMAKE_FIND_ROOT_PATH_MODE_*=BOTH -> the emscripten toolchain otherwise
#                          confines find_package to its sysroot and can't see
#                          our cross-compiled deps under .deps-wasm/usr.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${ROOT}/build-wasm"
DEPS="${ROOT}/.deps-wasm/usr"
NLUA0_HOST="${ROOT}/build/lib/libnlua0.so"
HOST_LUA="${ROOT}/.deps/usr/bin/luajit"

[ -f "${NLUA0_HOST}" ] || { echo "Missing host nlua0: ${NLUA0_HOST} (run: cmake --build build --target nlua0)"; exit 1; }
[ -x "${HOST_LUA}" ]   || { echo "Missing host lua: ${HOST_LUA}"; exit 1; }
[ -d "${DEPS}" ]       || { echo "Missing wasm deps: ${DEPS} (run wasm/build-deps.sh)"; exit 1; }

# Force-include the wasm shim, and use wasm-native setjmp/longjmp (required for
# JSPI; see wasm/build-deps.sh for the rationale). Must match the deps build.
export EMCC_CFLAGS="-include ${ROOT}/wasm/shim.h -sSUPPORT_LONGJMP=wasm ${EMCC_CFLAGS:-}"

echo "==> Configuring wasm nvim (build-wasm)"
emcmake cmake \
  -S "${ROOT}" \
  -B "${BUILD}" \
  -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D PREFER_LUA=ON \
  -D COMPILE_LUA=OFF \
  -D ENABLE_WASMTIME=OFF \
  -D ENABLE_LIBINTL=OFF \
  -D DEPS_PREFIX="${DEPS}" \
  -D CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
  -D CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
  -D CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
  -D LUA_PRG="${HOST_LUA}" \
  -D LUA_GEN_PRG="${HOST_LUA}" \
  -D NLUA0_HOST_PRG="${NLUA0_HOST}" \
  -D LUA_LIBRARY="${DEPS}/lib/liblua.a" \
  -D LUA_INCLUDE_DIR="${DEPS}/include" \
  `# CMake's FindLua searches for libm on UNIX (true under emscripten), but` \
  `# there is no separate libm (math lives in libc). Point it at a real,` \
  `# harmless archive so LUA_LIBRARIES isn't poisoned with a -NOTFOUND/bogus` \
  `# bare name. Duplicate static linkage of liblua.a is a no-op.` \
  -D LUA_MATH_LIBRARY="${DEPS}/lib/liblua.a" \
  "$@"

echo "==> Building nvim_bin (the executable; runtime bundling handled separately)"
cmake --build "${BUILD}" --target nvim_bin


# Boot smoke: prove the engine actually starts under Node. Node >= 24 has JSPI
# on by default (22/23 need --experimental-wasm-jspi); anything older can't run
# the engine, so skip the check rather than fail the build there.
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  if [ "${NODE_MAJOR}" -ge 24 ]; then
    echo "==> Boot check: nvim --version under Node"
    node "${BUILD}/bin/nvim.js" -- --version | head -1
  else
    echo "==> Skipping boot check (Node ${NODE_MAJOR} < 24 lacks default-on JSPI)"
  fi
fi

echo "==> Done. Run: node ${BUILD}/bin/nvim.js -- --headless ..."
