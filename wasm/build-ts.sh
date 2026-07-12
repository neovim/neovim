#!/usr/bin/env bash
# wasm/build-ts.sh - compile the wasm/ TypeScript sources (src/) into the JS the
# Node hosts consume. Mirrors wasm/web/build-ts.sh.
#
# The TypeScript in src/ is the SOURCE OF TRUTH. From it this produces, IN PLACE
# at the wasm/ root (gitignored):
#
#   worker.js           Node worker_thread engine host (CommonJS).
#
# The Emscripten engine-build inputs in wasm/ (pre.js, extern-pre.js,
# nvim_io.js, nvim_ts_dl.js) are NOT built here -- they are hand-written
# Emscripten library/pre-js DSL, linked into nvim.js by src/nvim/CMakeLists.txt,
# and stay committed JS.
#
#   Usage:  wasm/build-ts.sh            (writes wasm/worker.js)
#
# Prereq: `npm install` under wasm/ (provides the typescript + @types/node devDeps).
set -euo pipefail

WASM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${WASM}"

TSC="${WASM}/node_modules/.bin/tsc"
[ -x "${TSC}" ] || { echo "missing ${TSC} (run: cd wasm && npm install)"; exit 1; }

TMP_WORKER="${WASM}/dist-worker"

rm -rf "${TMP_WORKER}"

echo "==> tsc: node worker host"
"${TSC}" -p "${WASM}/tsconfig.worker.json"

echo "==> emit node worker host"
cp "${TMP_WORKER}/worker.js" "${WASM}/worker.js"

rm -rf "${TMP_WORKER}"

echo "==> built: worker.js"
