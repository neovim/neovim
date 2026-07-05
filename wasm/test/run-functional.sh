#!/usr/bin/env bash
# wasm/test/run-functional.sh - run Neovim's functional test suite against the
# wasm build.
#
# Mirrors cmake/RunTests.cmake's environment setup, but splits the two roles
# that cmake conflates in $NVIM_PRG:
#   * the harness RUNNER (`nvim -ll test/runner.lua`) stays the NATIVE binary
#     (it spawns child processes via uv.spawn, which the wasm build cannot);
#   * the nvim each test spawns and drives over msgpack-RPC is the WASM engine,
#     via the wasm/test/nvim shim ($NVIM_PRG).
#
# Usage:
#   wasm/test/run-functional.sh [test path] [extra runner args...]
#     e.g. wasm/test/run-functional.sh test/functional/api/version_spec.lua
#          wasm/test/run-functional.sh test/functional/api
#          wasm/test/run-functional.sh test/functional/lua --filter=vim.fs
#   Default test path: test/functional
#
# Env:
#   RUNNER_NVIM  native nvim hosting the harness (default: build/bin/nvim)
#   NVIM_PRG     the binary under test (default: wasm/test/nvim shim)
#   TEST_TIMEOUT seconds before the whole run is killed (default: 1200)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT/build"
RUNNER_NVIM="${RUNNER_NVIM:-$BUILD_DIR/bin/nvim}"

if [ ! -x "$RUNNER_NVIM" ]; then
  echo "run-functional.sh: no native nvim at $RUNNER_NVIM (build it: cmake --build build)" >&2
  exit 1
fi
TEST_PATH="${1:-test/functional}"
shift || true

# The binary under test. Defaults to the wasm shim; point NVIM_PRG at a native
# nvim to collect a baseline run with the identical environment (needed to
# tell wasm regressions apart from checkout/environment-caused failures).
export NVIM_PRG="${NVIM_PRG:-$ROOT/wasm/test/nvim}"
case "$NVIM_PRG" in
*/wasm/test/nvim)
  if [ ! -f "$ROOT/build-wasm/bin/nvim.js" ]; then
    echo "run-functional.sh: no wasm engine at build-wasm/bin/nvim.js (build it: wasm/build-nvim.sh)" >&2
    exit 1
  fi
  # The wasm-mode switch: drives source-mode exec_lua in
  # test/functional/testnvim/exec_lua.lua and is_wasm()-guarded skips.
  export NVIM_TEST_WASM=1
  ;;
esac

# --- environment, mirroring cmake/RunTests.cmake ---
# TEST_SUFFIX isolates this run's XDG/TMPDIR/log state; parallel runs (e.g. the
# triage driver) must pass distinct suffixes or they clobber each other.
SUFFIX="_wasm${TEST_SUFFIX:-}"
export NVIM_TEST=1
export LC_ALL=en_US.UTF-8
export VIMRUNTIME="$ROOT/runtime"
XDG="$BUILD_DIR/Xtest_xdg$SUFFIX"
export XDG_CONFIG_HOME="$XDG/config"
export XDG_DATA_HOME="$XDG/share"
export XDG_STATE_HOME="$XDG/state"
# Isolate the runtime dir too: relative `--listen NAME` addresses resolve under
# stdpath('run'); the inherited XDG_RUNTIME_DIR may be unwritable (sandboxes)
# and is SHARED across parallel runs (triage.sh workers would collide on the
# harness's fixed T<n> server names).
export XDG_RUNTIME_DIR="$XDG/run"
export NVIM_RPLUGIN_MANIFEST="$BUILD_DIR/Xtest_rplugin_manifest$SUFFIX"
unset XDG_DATA_DIRS NVIM TMUX
export NVIM_LOG_FILE="${NVIM_LOG_FILE:-$BUILD_DIR/nvim.log}$SUFFIX"
export TMPDIR="$BUILD_DIR/Xtest_tmpdir$SUFFIX"
export HISTFILE=/dev/null
export SHELL=sh
export SYSTEM_NAME="$(uname -s)"
export TEST_TIMEOUT="${TEST_TIMEOUT:-1200}"

rm -rf "$XDG" "$TMPDIR"
mkdir -p "$XDG" "$TMPDIR" "$XDG_RUNTIME_DIR"
ln -sfn "$ROOT/runtime" "$XDG/runtime"
ln -sfn "$ROOT/src" "$XDG/src"
ln -sfn "$ROOT/test" "$XDG/test"
ln -sfn "$ROOT/README.md" "$XDG/README.md"

cd "$XDG"
exec timeout "$TEST_TIMEOUT" "$RUNNER_NVIM" -ll "$ROOT/test/runner.lua" -v \
  --helper="$ROOT/test/functional/preload.lua" \
  --lpath="$BUILD_DIR/?.lua" \
  --lpath="$ROOT/src/?.lua" \
  --lpath="$ROOT/runtime/lua/?.lua" \
  --lpath='?.lua' \
  "$@" \
  "$TEST_PATH"
