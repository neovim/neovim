#!/bin/bash
set -e -u

FLAVOR=${1:-}

cat <<EOF >> "$GITHUB_PATH"
$HOME/.local/bin
EOF

cat <<EOF >> "$GITHUB_ENV"
CACHE_ENABLE=true
CI_TARGET=tests
CI_BUILD_DIR=$GITHUB_WORKSPACE
BUILD_DIR=$GITHUB_WORKSPACE/build
DEPS_BUILD_DIR=$HOME/nvim-deps
INSTALL_PREFIX=$HOME/nvim-install
LOG_DIR=$GITHUB_WORKSPACE/build/log
NVIM_LOG_FILE=$GITHUB_WORKSPACE/build/.nvimlog
VALGRIND_LOG=$GITHUB_WORKSPACE/build/log/valgrind-%p.log
CACHE_NVIM_DEPS_DIR=$HOME/.cache/nvim-deps
CACHE_MARKER=$HOME/.cache/nvim-deps/.ci_cache_marker
CCACHE_BASEDIR=$GITHUB_WORKSPACE
DEPS_CMAKE_FLAGS=-DUSE_BUNDLED_GPERF=OFF
FUNCTIONALTEST=functionaltest
CCACHE_COMPRESS=1
CCACHE_SLOPPINESS=time_macros,file_macro
CCACHE_DIR=$HOME/.ccache
EOF

BUILD_FLAGS="CMAKE_FLAGS=-DCI_BUILD=ON -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX:PATH=$HOME/nvim-install -DBUSTED_OUTPUT_TYPE=nvim -DDEPS_PREFIX=$HOME/nvim-deps/usr -DMIN_LOG_LEVEL=3"

case "$FLAVOR" in
  asan)
    BUILD_FLAGS="$BUILD_FLAGS -DPREFER_LUA=ON"
    cat <<EOF >> "$GITHUB_ENV"
CLANG_SANITIZER=ASAN_UBSAN
SYMBOLIZER=asan_symbolize-11
ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:log_path=$GITHUB_WORKSPACE/build/log/asan
UBSAN_OPTIONS=print_stacktrace=1 log_path=$GITHUB_WORKSPACE/build/log/ubsan
EOF
    ;;
  tsan)
    cat <<EOF >> "$GITHUB_ENV"
TSAN_OPTIONS=log_path=$GITHUB_WORKSPACE/build/log/tsan
EOF
    ;;
  lint)
    cat <<EOF >> "$GITHUB_ENV"
CI_TARGET=lint
EOF
    ;;
  *)
    ;;
esac

cat <<EOF >> "$GITHUB_ENV"
$BUILD_FLAGS
EOF
