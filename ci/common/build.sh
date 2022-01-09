#!/usr/bin/env bash

_stat() {
  if test "$CI_OS_NAME" = osx; then
    stat -f %Sm "$@"
  else
    stat -c %y "$@"
  fi
}

build_make() {
  ninja -C "$BUILD_DIR" "$@"
}

build_deps() {
  if test "$FUNCTIONALTEST" = "functionaltest-lua" ||
    test "$CLANG_SANITIZER" = "ASAN_UBSAN"; then
    DEPS_CMAKE_FLAGS="$DEPS_CMAKE_FLAGS -DUSE_BUNDLED_LUA=ON"
  fi

  mkdir -p "$DEPS_BUILD_DIR"

  # Use cached dependencies if $CACHE_MARKER exists.
  if test "$CACHE_ENABLE" = "false"; then
    export CCACHE_RECACHE=1
  elif test -f "$CACHE_MARKER"; then
    echo "Using third-party dependencies from cache (last update: $(_stat "$CACHE_MARKER"))."
    cp -a "$CACHE_NVIM_DEPS_DIR"/. "$DEPS_BUILD_DIR"
  fi

  # Even if we're using cached dependencies, run CMake and make to
  # update CMake configuration and update to newer deps versions.
  cd "$DEPS_BUILD_DIR"
  echo "Configuring with '$DEPS_CMAKE_FLAGS'."
  CC= cmake -G Ninja $DEPS_CMAKE_FLAGS "$CI_BUILD_DIR/third-party/"

  ninja || exit

  cd "$CI_BUILD_DIR"
}

build_nvim() {
  check_core_dumps --delete quiet

  if test -n "$CLANG_SANITIZER"; then
    CMAKE_FLAGS="$CMAKE_FLAGS -DCLANG_$CLANG_SANITIZER=ON"
  fi

  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"
  echo "Configuring with '$CMAKE_FLAGS $@'."
  cmake -G Ninja $CMAKE_FLAGS "$@" "$CI_BUILD_DIR"

  echo "Building nvim."
  ninja nvim || exit

  if test "$CLANG_SANITIZER" != "TSAN"; then
    echo "Building libnvim."
    ninja libnvim || exit

    if test "$FUNCTIONALTEST" != "functionaltest-lua"; then
      echo "Building nvim-test."
      ninja nvim-test || exit
    fi
  fi

  # Invoke nvim to trigger *San early.
  if ! (bin/nvim --version && bin/nvim -u NONE -e -cq | cat -vet); then
    check_sanitizer "$LOG_DIR"
    exit 1
  fi

  check_sanitizer "$LOG_DIR"

  cd "$CI_BUILD_DIR"
}
