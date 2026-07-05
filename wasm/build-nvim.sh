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


# -----------------------------------------------------------------------------
# Runtime data packages (file_packager): the shared nvim.wasm is RUNTIME-AGNOSTIC
# (the --preload-file of the runtime was removed from src/nvim/CMakeLists.txt).
# The runtime is instead packaged OUT-OF-BAND here into one (data + loader) pair
# per VARIANT, all resolving the SAME nvim.wasm via locateFile. No per-variant
# relink: file_packager just stages a runtime subtree -> .data + a .data.js loader.
#
#   full    - the entire runtime/ (today's complete ~22M runtime; the default).
#   core    - boots + edits + filetype + indent + a CURATED syntax slice for
#             common languages + treesitter queries/ (the builtin grammars'
#             highlight queries -- the lua/markdown/help ftplugins start
#             treesitter unconditionally). Drops doc/, tutor/, spell/, and the
#             bulk of syntax/.  Target a few MB.
#   minimal - strictly what nvim needs to boot `--embed` and edit: lua/ (the vim.*
#             stdlib -- MANDATORY, nvim won't boot without it), plugin/, scripts/,
#             and the top-level boot .vim/.lua. No syntax, ftplugin, indent, doc.
#             Target ~3.5-4M.
#
# NOTE: these .data packages are a BROWSER concern. Under Node the runtime is read
# straight from the on-disk runtime/ tree via the NODEFS mount (wasm/pre.js points
# $VIMRUNTIME at ../../runtime), so Node needs no .data at all.
RT="${ROOT}/runtime"
STAGE_ROOT="${BUILD}/.runtime-stage"
FILE_PACKAGER="$(command -v file_packager || true)"
# Locate file_packager.py relative to emcc, which is correct on BOTH the emsdk
# layout (CI: emcc lives at <root>/emcc with tools/ alongside) and the Debian apt
# layout (dev box: /usr/bin/emcc is a symlink into /usr/share/emscripten, where
# tools/ also sits). `command -v file_packager` is empty under emsdk and
# EMSCRIPTEN_ROOT is unset there, so the old /usr/share/emscripten fallback failed
# in CI -- resolving from the real emcc fixes both.
EMCC_REAL="$(readlink -f "$(command -v emcc 2>/dev/null)" 2>/dev/null || true)"
PY_PACKAGER="${EMSCRIPTEN_ROOT:-$(dirname "${EMCC_REAL:-/usr/share/emscripten/x}")}/tools/file_packager.py"

run_file_packager() {  # <data-out> <stage-dir>
  local data_out="$1" stage="$2"
  if [ -n "${FILE_PACKAGER}" ]; then
    "${FILE_PACKAGER}" "${data_out}" \
      --preload "${stage}@/usr/share/nvim/runtime" \
      --js-output="${data_out}.js" >/dev/null
  else
    python3 "${PY_PACKAGER}" "${data_out}" \
      --preload "${stage}@/usr/share/nvim/runtime" \
      --js-output="${data_out}.js" >/dev/null
  fi
}

# Copy a list of top-level runtime entries (files or whole dirs) into a stage dir.
stage_entries() {  # <stage-dir> <entry...>
  local stage="$1"; shift
  local e
  for e in "$@"; do
    if [ -e "${RT}/${e}" ]; then
      mkdir -p "${stage}/$(dirname "${e}")"
      cp -R "${RT}/${e}" "${stage}/${e}"
    fi
  done
}

# IMPORTANT -- each staged subset MUST be internally CONSISTENT: it has to boot
# under `-n` (plugins ON) with NO startup E### error and NO "Press ENTER" prompt.
# A prompt blocks ALL subsequent RPC, so a variant that prompts on every boot is
# unusable. This is verified headlessly by verify_variant() below (the gate that
# was missing originally). Two startup traps the trimmed variants must avoid:
#   * pack/ packadd scripts: plugin/netrwPlugin.vim packadds pack/dist/opt/netrw
#     and plugin/matchit.vim packadds pack/dist/opt/matchit. If pack/ is trimmed
#     but those scripts are staged, nvim errors E919 at startup -> prompt.
#   * default `syntax on`: nvim enables syntax by default (under -n), which sources
#     syntax/syntax.vim. If syntax/ is trimmed entirely, nvim errors E484 -> prompt.
#     So even "no highlighting" variants must ship the tiny syntax FRAMEWORK.

# The minimal/core syntax FRAMEWORK (the loader/dispatch files default `syntax on`
# sources). These are tiny (~16K) and carry NO per-language highlighting -- so a
# variant with the framework but no language files boots clean and simply shows no
# colour. (syncolor.vim/synmenu.vim do not live under syntax/ -- the top-level
# synmenu.vim is a separate menu def; stage_entries skips anything absent.)
SYNTAX_FRAMEWORK=( syntax.vim synload.vim nosyntax.vim manual.vim )

# The two bundled plugin/ scripts that packadd a pack/ package. A variant that
# trims pack/ but stages plugin/ must DELETE these or it errors at startup.
PACKADD_PLUGINS=( plugin/netrwPlugin.vim plugin/matchit.vim )

# Top-level boot files CORE needs (the filetype/indent/syntax/menu togglers nvim
# sources during startup). minimal stages only filetype.lua + the syntax framework.
CORE_BOOT_FILES=(
  filetype.lua
  filetype.vim ftplugin.vim ftplugof.vim ftoff.vim
  indent.vim indoff.vim
  delmenu.vim menu.vim makemenu.vim synmenu.vim
)

# CORE: a curated syntax slice. The framework above + a per-language list covering
# common languages. Many syntax files do `runtime! syntax/<other>.vim` (e.g. cpp ->
# c, the *complete autoloads), so we keep the autoload/ tree wholesale (what
# completion + many ft scripts call) and the whole pack/ (so the bundled plugins
# resolve their packadds).
SYNTAX_LANGS=( c cpp lua vim python javascript typescript html css scss less
               json json5 jsonc yaml toml xml markdown sh bash zsh rust go
               java kotlin ruby php perl sql diff git gitcommit gitconfig
               gitrebase make cmake dockerfile dosini conf text help
               query treesitter )

# Copy the syntax framework + a language slice into <stage>/syntax.
# NB: every `[ -e X ] && cp` is wrapped so a MISSING entry yields exit 0 -- under
# `set -e` a bare `[ -e X ] && cp` would abort the script when X is absent (a
# language in the list with no syntax/<lang>.vim, e.g. a meta entry).
stage_syntax() {  # <stage-dir> [extra-lang...]
  local stage="$1"; shift
  mkdir -p "${stage}/syntax"
  local f lang
  for f in "${SYNTAX_FRAMEWORK[@]}"; do
    if [ -e "${RT}/syntax/${f}" ]; then cp "${RT}/syntax/${f}" "${stage}/syntax/"; fi
  done
  # README.txt + shared/ are referenced by some language files; cheap, keep them
  # whenever any language is staged.
  if [ "$#" -gt 0 ]; then
    if [ -e "${RT}/syntax/README.txt" ]; then cp "${RT}/syntax/README.txt" "${stage}/syntax/"; fi
    if [ -d "${RT}/syntax/shared" ]; then cp -R "${RT}/syntax/shared" "${stage}/syntax/"; fi
  fi
  for lang in "$@"; do
    if [ -e "${RT}/syntax/${lang}.vim" ]; then cp "${RT}/syntax/${lang}.vim" "${stage}/syntax/"; fi
    if [ -d "${RT}/syntax/${lang}" ]; then cp -R "${RT}/syntax/${lang}" "${stage}/syntax/"; fi
  done
}

# --- assemble the three stages -----------------------------------------------
rm -rf "${STAGE_ROOT}"

echo "==> Staging runtime variants for file_packager"

# full: the whole runtime/, verbatim. (Self-consistent: it has pack/ + syntax/.)
mkdir -p "${STAGE_ROOT}/full"
cp -R "${RT}/." "${STAGE_ROOT}/full/"

# Generate the help-tag database (doc/tags) for the full variant. The native
# build produces this via a `helptags` install step (runtime/CMakeLists.txt), but
# the wasm build packages runtime/ directly and runtime/doc/tags is gitignored --
# so a fresh checkout (CI) ships doc/*.txt with NO tags, and :help <topic> fails
# with E149. Regenerate it deterministically by running the just-built engine
# under Node with `:helptags` (the same node nvim.js the verify gate uses; helptags
# is pure editor file IO, no spawning, so it works in wasm). full is the only
# variant that ships doc/ (core/minimal drop it), so it's the only one tagged.
echo "==> Generating help tags for the full runtime variant (doc/tags)"
rm -f "${STAGE_ROOT}/full/doc/tags"
helptags_err="${BUILD}/.helptags.err"
node "${BUILD}/bin/nvim.js" -- -u NONE -i NONE -e --headless \
  -c "helptags ++t ${STAGE_ROOT}/full/doc" -c quit >"${helptags_err}" 2>&1 || true
if [ ! -s "${STAGE_ROOT}/full/doc/tags" ]; then
  echo "ERROR: failed to generate doc/tags for the full variant (:help would be broken)." >&2
  echo "       engine output (node $(node --version)):" >&2
  sed 's/^/       | /' "${helptags_err}" >&2 || true
  exit 1
fi
rm -f "${helptags_err}"
echo "    doc/tags ($(wc -l < "${STAGE_ROOT}/full/doc/tags") tags)"

# minimal: boot + the vim.* stdlib only. Stages lua/, plugin/, scripts/ and
# filetype.lua, PLUS the tiny syntax framework so default `syntax on` succeeds
# (no language files => no actual highlighting). Drops the pack-dependent plugins
# (pack/ is not staged), so nothing packadds a missing package.
MIN="${STAGE_ROOT}/minimal"
mkdir -p "${MIN}"
stage_entries "${MIN}" lua plugin scripts filetype.lua
rm -f "${MIN}/${PACKADD_PLUGINS[0]}" "${MIN}/${PACKADD_PLUGINS[1]}"
stage_syntax "${MIN}"   # framework only, no languages

# core: minimal + filetype/indent editing support + curated syntax + the WHOLE
# pack/ (so the bundled plugin/ scripts' packadds resolve -> clean boot).
# queries/ (~116K) must ride along with ftplugin/: the lua/markdown/help
# ftplugins vim.treesitter.start() unconditionally, and the statically linked
# builtin grammars need their highlight queries or start() errors.
COR="${STAGE_ROOT}/core"
mkdir -p "${COR}"
stage_entries "${COR}" lua plugin scripts autoload colors compiler keymap \
  ftplugin indent pack queries "${CORE_BOOT_FILES[@]}"
stage_syntax "${COR}" "${SYNTAX_LANGS[@]}"

# --- verify each staged variant boots CLEAN (the gate) -----------------------
# Point $VIMRUNTIME at the staged subset and boot nvim under Node with plugins
# LOADED (-n, NOT -u NONE -- -u NONE skips plugin loading and would hide a missing
# packadd/syntax dependency). We isolate from the host's personal nvim config
# (empty HOME/XDG_*) so only the staged runtime drives startup, mirroring the
# browser's empty FS. Then assert the captured :messages + stderr contain no E###
# error and no "Press ENTER" prompt. A failure fails the build.
VERIFY_HOME="${BUILD}/.verify-home"
verify_variant() {  # <variant> <stage-dir>
  local v="$1" stage="$2"
  local msgs="${BUILD}/.verify-${v}.msgs" errf="${BUILD}/.verify-${v}.err"
  rm -rf "${VERIFY_HOME}"; mkdir -p "${VERIFY_HOME}/.config" "${VERIFY_HOME}/.local"
  rm -f "${msgs}" "${errf}"
  HOME="${VERIFY_HOME}" \
  XDG_CONFIG_HOME="${VERIFY_HOME}/.config" \
  XDG_DATA_HOME="${VERIFY_HOME}/.local/share" \
  XDG_STATE_HOME="${VERIFY_HOME}/.local/state" \
  XDG_CACHE_HOME="${VERIFY_HOME}/.cache" \
  VIMRUNTIME="${stage}" \
    node "${BUILD}/bin/nvim.js" -- -n -i NONE --headless \
      +'redir => g:m | silent messages | redir END' \
      +"call writefile(split(g:m,\"\n\",1), \"${msgs}\")" \
      +qa >/dev/null 2>"${errf}" || true
  # Combine captured :messages and stderr (drop the benign NODEFS log-path notice).
  local combined
  combined="$( { cat "${msgs}" 2>/dev/null; grep -v '^log:' "${errf}" 2>/dev/null; } )"
  if printf '%s\n' "${combined}" | grep -qE 'E[0-9]{2,}:|Press ENTER'; then
    echo "    !! ${v}: STARTUP NOT CLEAN -- variant would block on a hit-enter prompt:"
    printf '%s\n' "${combined}" | grep -vE '^[[:space:]]*$' | sed 's/^/       /'
    rm -rf "${VERIFY_HOME}"; rm -f "${msgs}" "${errf}"
    return 1
  fi
  echo "    ok ${v}: boots clean (no E### error, no hit-enter prompt)"
  rm -f "${msgs}" "${errf}"
}

echo "==> Verifying each staged variant boots clean (-n, plugins loaded)"
verify_failed=0
for v in full core minimal; do
  verify_variant "${v}" "${STAGE_ROOT}/${v}" || verify_failed=1
done
rm -rf "${VERIFY_HOME}"
if [ "${verify_failed}" -ne 0 ]; then
  echo "ERROR: a staged runtime variant does not boot clean (see above). Aborting." >&2
  exit 1
fi

# --- package each stage -> nvim-<variant>.data + nvim-<variant>.data.js -------
echo "==> Packaging runtime variants (file_packager)"
for v in full core minimal; do
  run_file_packager "${BUILD}/bin/nvim-${v}.data" "${STAGE_ROOT}/${v}"
  sz="$(du -h "${BUILD}/bin/nvim-${v}.data" | cut -f1)"
  echo "    nvim-${v}.data  (${sz})"
done
rm -rf "${STAGE_ROOT}"

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
