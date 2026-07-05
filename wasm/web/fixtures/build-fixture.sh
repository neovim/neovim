#!/usr/bin/env bash
# Regenerate luadyn.wasm - the DYNAMIC tree-sitter grammar test fixture.
#
# It is the bundled lua grammar compiled as an emscripten SIDE MODULE (the
# same artifact shape `tree-sitter build --wasm` publishes) with its entry
# point renamed tree_sitter_lua -> tree_sitter_luadyn, so tests can register
# it under the NON-builtin language name 'luadyn' (the statically linked
# builtin registry can never satisfy it) and runtimepath discovery / dlsym
# work without a symbol_name override. The internal scanner symbols keep
# their tree_sitter_lua_* names; dlsym only ever looks up the entry point.
#
# The binary is CHECKED IN (56 KB) so `npm test` needs no emcc; rerun this
# after an emscripten major upgrade if the dylink ABI moves (needs the wasm
# deps CONFIGURE TREE, i.e. a non-cache-hit wasm/build-deps.sh run).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="${ROOT}/.deps-wasm/build/src/treesitter_lua/src"
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SRC}/parser.c" ] || { echo "missing ${SRC}/parser.c (run wasm/build-deps.sh from scratch; the configure tree must exist)"; exit 1; }

emcc -O2 -sSIDE_MODULE=2 -sSUPPORT_LONGJMP=wasm \
  -Dtree_sitter_lua=tree_sitter_luadyn \
  -sEXPORTED_FUNCTIONS=_tree_sitter_luadyn \
  -I "${SRC}" "${SRC}/parser.c" "${SRC}/scanner.c" \
  -o "${OUT}/luadyn.wasm"
echo "built ${OUT}/luadyn.wasm ($(stat -c%s "${OUT}/luadyn.wasm") bytes)"
