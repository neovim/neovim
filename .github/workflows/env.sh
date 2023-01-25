#!/bin/bash
set -e -u

FLAVOR=${1:-}

cat <<EOF >> "$GITHUB_PATH"
$HOME/.local/bin
EOF

cat <<EOF >> "$GITHUB_ENV"
CI_BUILD_DIR=$GITHUB_WORKSPACE
BUILD_DIR=$GITHUB_WORKSPACE/build
DEPS_BUILD_DIR=$HOME/nvim-deps
INSTALL_PREFIX=$HOME/nvim-install
LOG_DIR=$GITHUB_WORKSPACE/build/log
NVIM_LOG_FILE=$GITHUB_WORKSPACE/build/.nvimlog
VALGRIND_LOG=$GITHUB_WORKSPACE/build/log/valgrind-%p.log
CACHE_NVIM_DEPS_DIR=$HOME/.cache/nvim-deps
CACHE_MARKER=$HOME/.cache/nvim-deps/.ci_cache_marker
CACHE_UNCRUSTIFY=$HOME/.cache/uncrustify
EOF

DEPS_CMAKE_FLAGS=
FUNCTIONALTEST=functionaltest
BUILD_FLAGS="CMAKE_FLAGS=-DCI_BUILD=ON -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX:PATH=$HOME/nvim-install -DBUSTED_OUTPUT_TYPE=nvim -DDEPS_PREFIX=$HOME/nvim-deps/usr -DMIN_LOG_LEVEL=3"

case "$FLAVOR" in
  asan)
    BUILD_FLAGS="$BUILD_FLAGS -DPREFER_LUA=ON"
    cat <<EOF >> "$GITHUB_ENV"
CLANG_SANITIZER=ASAN_UBSAN
ASAN_OPTIONS=detect_leaks=1:check_initialization_order=1:log_path=$GITHUB_WORKSPACE/build/log/asan:intercept_tls_get_addr=0
UBSAN_OPTIONS=print_stacktrace=1 log_path=$GITHUB_WORKSPACE/build/log/ubsan
EOF
    ;;
  tsan)
    cat <<EOF >> "$GITHUB_ENV"
TSAN_OPTIONS=log_path=$GITHUB_WORKSPACE/build/log/tsan
CLANG_SANITIZER=TSAN
EOF
    ;;
  uchar)
    cat <<EOF >> "$GITHUB_ENV"
BUILD_UCHAR=1
EOF
    ;;
  lintc)
# Re-enable once system deps are available
#    BUILD_FLAGS="$BUILD_FLAGS -DLIBLUV_LIBRARY:FILEPATH=/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/lua/5.1/luv.so -DLIBLUV_INCLUDE_DIR:PATH=/usr/include/lua5.1"

    # Ideally all dependencies should external for this job, but some
    # dependencies don't have the required version available. We use the
    # bundled versions for these with the hopes of being able to remove them
    # later on.
    DEPS_CMAKE_FLAGS="$DEPS_CMAKE_FLAGS -DUSE_BUNDLED=OFF -DUSE_BUNDLED_LUV=ON -DUSE_BUNDLED_LIBVTERM=ON"
    ;;
  functionaltest-lua)
    BUILD_FLAGS="$BUILD_FLAGS -DPREFER_LUA=ON"
    FUNCTIONALTEST=functionaltest-lua
    DEPS_CMAKE_FLAGS="$DEPS_CMAKE_FLAGS -DUSE_BUNDLED_LUAJIT=OFF"
    ;;
  *)
    ;;
esac

cat <<EOF >> "$GITHUB_ENV"
$BUILD_FLAGS
DEPS_CMAKE_FLAGS=$DEPS_CMAKE_FLAGS
FUNCTIONALTEST=$FUNCTIONALTEST
EOF
