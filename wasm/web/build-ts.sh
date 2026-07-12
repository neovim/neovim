#!/usr/bin/env bash
# wasm/web/build-ts.sh - compile the TypeScript sources in src/ into the
# distributable JS the rest of the toolchain consumes (dist/, gitignored).
#
# The TypeScript in src/ is the SOURCE OF TRUTH. From it this produces, in dist/:
#
#   neovim.js  neovim-ui.js  neovim-ui-pre.js    UMD (globalThis.<Name> via a
#                                                <script>, or require() in Node)
#   neovim.d.ts (+ ui/ui-pre)                    type declarations
#   app.js                                       page glue (classic <script>)
#   engine-worker.js                             Web Worker engine host
#
# HOW: three `tsc` passes (no bundler) with per-target libs/module settings, then
# a small wrap step. The core modules are compiled to CommonJS and wrapped into
# UMD-that-sets-a-global by tools/umd-wrap.mjs (tsc's own deprecated `module: umd`
# does not assign a browser global). app.ts (DOM) and engine-worker.ts (WebWorker)
# need different libs, so each gets its own pass.
#
#   Usage:  wasm/web/build-ts.sh            (writes wasm/web/dist/)
#
# Prereq: `npm install` under wasm/web (provides the `typescript` devDependency).
set -euo pipefail

WEB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${WEB}"

TSC="${WEB}/node_modules/.bin/tsc"
[ -x "${TSC}" ] || { echo "missing ${TSC} (run: cd wasm/web && npm install)"; exit 1; }

DIST="${WEB}/dist"
TMP_LIB="${WEB}/dist-lib"
TMP_APP="${WEB}/dist-app"
TMP_WORKER="${WEB}/dist-worker"

rm -rf "${DIST}" "${TMP_LIB}" "${TMP_APP}" "${TMP_WORKER}"
mkdir -p "${DIST}"

echo "==> tsc: library modules (CJS cores + .d.ts)"
"${TSC}" -p "${WEB}/tsconfig.lib.json"
echo "==> tsc: page glue (app.js)"
"${TSC}" -p "${WEB}/tsconfig.app.json"
echo "==> tsc: engine worker (engine-worker.js)"
"${TSC}" -p "${WEB}/tsconfig.worker.json"

echo "==> wrap CommonJS cores into UMD-with-global"
node "${WEB}/tools/umd-wrap.mjs" "${TMP_LIB}/neovim.js"        "${DIST}/neovim.js"        Neovim
node "${WEB}/tools/umd-wrap.mjs" "${TMP_LIB}/neovim-ui.js"     "${DIST}/neovim-ui.js"     NeovimUI
node "${WEB}/tools/umd-wrap.mjs" "${TMP_LIB}/neovim-ui-pre.js" "${DIST}/neovim-ui-pre.js" NeovimUIPre \
  --dep ./neovim-ui.js=NeovimUI

echo "==> assemble dist/ (declarations, page glue, worker)"
# type declarations (for require()/UMD consumers)
cp "${TMP_LIB}"/*.d.ts "${DIST}/"
# Declare the UMD <script> global on each core .d.ts (the `export as namespace`
# that may only live in a declaration file), so a <script src="neovim.js">
# consumer gets a typed globalThis.<Name>.
printf '\nexport as namespace Neovim;\n'      >> "${DIST}/neovim.d.ts"
printf '\nexport as namespace NeovimUI;\n'    >> "${DIST}/neovim-ui.d.ts"
printf '\nexport as namespace NeovimUIPre;\n' >> "${DIST}/neovim-ui-pre.d.ts"
# page glue + worker
cp "${TMP_APP}/app.js" "${DIST}/"
cp "${TMP_WORKER}/engine-worker.js" "${DIST}/"

rm -rf "${TMP_LIB}" "${TMP_APP}" "${TMP_WORKER}"

echo "==> dist/ assembled:"
ls -la "${DIST}"
