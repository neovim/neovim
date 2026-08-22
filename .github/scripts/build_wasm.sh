#!/usr/bin/env bash

# Build nvim.wasm

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTDIR="$ROOT/build-wasm"

source "$ROOT/.emsdk/emsdk_env.sh"

mkdir -p "$OUTDIR"

if ! command -v emcc >/dev/null 2>&1; then
  echo "ERROR: emcc not found"
  exit 1
fi

if ! command -v zig >/dev/null 2>&1; then
  echo "ERROR: zig not found"
  exit 1
fi

emcc --version
zig version

# Install Binaryen if it is not already available.
BINARYEN_VERSION=132
BINARYEN_DIR="$ROOT/.binaryen"
BINARYEN_BIN="$BINARYEN_DIR/binaryen-version_${BINARYEN_VERSION}/bin"

if [ ! -x "$BINARYEN_BIN/wasm-opt" ]; then
  echo "Installing Binaryen ${BINARYEN_VERSION}..."

  mkdir -p "$BINARYEN_DIR"

  curl -L \
    "https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-x86_64-linux.tar.gz" \
    -o /tmp/binaryen.tar.gz

  tar -xf /tmp/binaryen.tar.gz -C "$BINARYEN_DIR"
fi

export PATH="$BINARYEN_BIN:$PATH"

wasm-opt --version

zig build nvim_bin \
  -Dtarget=wasm32-emscripten \
  -Dcpu=generic+atomics+bulk_memory+mutable_globals \
  -Demscripten-sysroot="$EMSDK/upstream/emscripten/cache/sysroot" \
  -Doptimize=ReleaseSmall

ZIG_OUT="$ROOT/zig-out/bin"

# Optimize the final WASM artifact with Binaryen.
wasm-opt -Oz -o "$ZIG_OUT/nvim.wasm" "$ZIG_OUT/nvim.wasm"

required=(
  nvim.wasm
  nvim.js
  nvim.data
)

missing=()

for name in "${required[@]}"; do
  if [ -f "$ZIG_OUT/$name" ]; then
    cp "$ZIG_OUT/$name" "$OUTDIR/$name"
  else
    missing+=("$name")
  fi
done

if [ "${#missing[@]}" -ne 0 ]; then
  echo "ERROR: Missing required WASM artifacts: ${missing[*]}"
  ls -la "$ZIG_OUT" || true
  exit 2
fi

echo "build-wasm.sh finished successfully."

if [ "${BUNDLE_WASM:-0}" = "1" ]; then
  BUNDLE_DIR="$ROOT/bundle-wasm"
  ZIP_PATH="$ROOT/nvim-wasm-emscripten.zip"

  rm -rf "$BUNDLE_DIR" "$ZIP_PATH"
  mkdir -p "$BUNDLE_DIR"

  cp "$OUTDIR"/nvim.wasm "$OUTDIR"/nvim.js "$OUTDIR"/nvim.data "$BUNDLE_DIR"/

  cp "$ROOT"/src/wasm/*.py "$ROOT"/src/wasm/*.html "$ROOT"/src/wasm/*.js "$ROOT"/src/wasm/*.css "$BUNDLE_DIR"/

  # Rewrite repo relative paths for the flat bundle layout
  sed -i 's#\.\./\.\./zig-out/bin/#./#g' "$BUNDLE_DIR/nvim-worker.js"
  sed -i 's#Path(__file__)\.resolve()\.parents\[2\]#Path(__file__).resolve().parent#' "$BUNDLE_DIR/serve.py"

  ( cd "$BUNDLE_DIR" && zip -r "$ZIP_PATH" . )
  rm -rf "$BUNDLE_DIR"

  echo "Created $ZIP_PATH"
fi
