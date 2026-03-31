#!/bin/bash

# Helper script to build and run neovim with Address Sanitizer enabled.
# You may read more information in src/nvim/README.md in the section "Build
# with ASAN".

shopt -s nullglob

root_path=$(git rev-parse --show-toplevel)
log_path=$(mktemp -d)
export CC='clang'

# Change to detect_leaks=1 to detect memory leaks (slower).
export ASAN_OPTIONS="detect_leaks=0:log_path=$log_path/asan"

make -C "$root_path" CMAKE_EXTRA_FLAGS="-DENABLE_ASAN_UBSAN=ON"
VIMRUNTIME="$root_path"/runtime "$root_path"/build/bin/nvim

# Need to manually reset terminal to avoid mangled output, nvim does not
# properly restore the terminal when it crashes.
tput reset

for i in "$log_path"/*; do
  cat "$i"
done
