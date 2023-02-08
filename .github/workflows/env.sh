#!/bin/bash
set -e -u

FLAVOR=${1:-}

BUILD_DIR=$CI_BUILD_DIR/build
BIN_DIR=$CI_BUILD_DIR/bin
DEPS_BUILD_DIR=$HOME/nvim-deps
INSTALL_PREFIX=$CI_BUILD_DIR/nvim-install
LOG_DIR=$BUILD_DIR/log
NVIM_LOG_FILE=$BUILD_DIR/.nvimlog
VALGRIND_LOG=$LOG_DIR/valgrind-%p.log
CACHE_DIR=$CI_BUILD_DIR/.cache
CACHE_UNCRUSTIFY=$CACHE_DIR/uncrustify
DEPS_CMAKE_FLAGS=
FUNCTIONALTEST=functionaltest
CMAKE_FLAGS="-D CI_BUILD=ON -D CMAKE_INSTALL_PREFIX:PATH=$INSTALL_PREFIX -D MIN_LOG_LEVEL=3"
CLANG_SANITIZER=
ASAN_OPTIONS=
UBSAN_OPTIONS=
TSAN_OPTIONS=

case "$FLAVOR" in
  asan)
    CLANG_SANITIZER=ASAN_UBSAN
    ASAN_OPTIONS="detect_leaks=1:check_initialization_order=1:log_path=$LOG_DIR/asan:intercept_tls_get_addr=0"
    UBSAN_OPTIONS="print_stacktrace=1 log_path=$LOG_DIR/ubsan"
    ;;
  tsan)
    TSAN_OPTIONS=log_path=$LOG_DIR/tsan
    CLANG_SANITIZER=TSAN
    ;;
  uchar)
    CMAKE_FLAGS+=" -D UNSIGNED_CHAR=ON"
    ;;
  lintc)
    # Re-enable once system deps are available
    #    CMAKE_FLAGS+=" -D LIBLUV_LIBRARY:FILEPATH=/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/lua/5.1/luv.so -D LIBLUV_INCLUDE_DIR:PATH=/usr/include/lua5.1"

    # Ideally all dependencies should external for this job, but some
    # dependencies don't have the required version available. We use the
    # bundled versions for these with the hopes of being able to remove them
    # later on.
    DEPS_CMAKE_FLAGS+=" -D USE_BUNDLED=OFF -D USE_BUNDLED_LUV=ON -D USE_BUNDLED_LIBVTERM=ON"
    ;;
  functionaltest-lua)
    CMAKE_FLAGS+=" -D PREFER_LUA=ON"
    FUNCTIONALTEST=functionaltest-lua
    DEPS_CMAKE_FLAGS+=" -D USE_BUNDLED_LUAJIT=OFF"
    ;;
  *)
    ;;
esac

cat <<EOF >> "$GITHUB_ENV"
CMAKE_FLAGS=$CMAKE_FLAGS
BUILD_DIR=$BUILD_DIR
BIN_DIR=$BIN_DIR
DEPS_BUILD_DIR=$DEPS_BUILD_DIR
DEPS_CMAKE_FLAGS=$DEPS_CMAKE_FLAGS
FUNCTIONALTEST=$FUNCTIONALTEST
INSTALL_PREFIX=$INSTALL_PREFIX
LOG_DIR=$LOG_DIR
NVIM_LOG_FILE=$NVIM_LOG_FILE
VALGRIND_LOG=$VALGRIND_LOG
CACHE_DIR=$CACHE_DIR
CACHE_UNCRUSTIFY=$CACHE_UNCRUSTIFY
CLANG_SANITIZER=$CLANG_SANITIZER
ASAN_OPTIONS=$ASAN_OPTIONS
UBSAN_OPTIONS=$UBSAN_OPTIONS
TSAN_OPTIONS=$TSAN_OPTIONS
EOF

cat <<EOF >> "$GITHUB_PATH"
$BIN_DIR
EOF
