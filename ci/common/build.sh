top_make() {
  ${MAKE_CMD} "$@"
}

build_make() {
  top_make -C "${BUILD_DIR}" "$@"
}

build_deps() {
  if test "x${BUILD_32BIT}" = xON ; then
    DEPS_CMAKE_FLAGS="${DEPS_CMAKE_FLAGS} ${CMAKE_FLAGS_32BIT}"
  fi
  if test "x${FUNCTIONALTEST}" = "xfunctionaltest-lua" ; then
    DEPS_CMAKE_FLAGS="${DEPS_CMAKE_FLAGS} -DUSE_BUNDLED_LUA=ON"
  fi

  rm -rf "${DEPS_BUILD_DIR}"

  # If there is a valid cache and we're not forced to recompile,
  # use cached third-party dependencies.
  if test -f "${CACHE_MARKER}" && test "x${BUILD_NVIM_DEPS}" != xtrue ; then
    local statcmd="stat -c '%y'"
    if test "x${TRAVIS_OS_NAME}" = xosx ; then
      statcmd="stat -f '%Sm'"
    fi
    echo "Using third-party dependencies from Travis's cache (last updated: $(${statcmd} "${CACHE_MARKER}"))."

    mkdir -p "$(dirname "${DEPS_BUILD_DIR}")"
    mv "${HOME}/.cache/nvim-deps" "${DEPS_BUILD_DIR}"
  else
    mkdir -p "${DEPS_BUILD_DIR}"
  fi

  # Even if we're using cached dependencies, run CMake and make to
  # update CMake configuration and update to newer deps versions.
  cd "${DEPS_BUILD_DIR}"
  echo "Configuring with '${DEPS_CMAKE_FLAGS}'."
  CC= cmake ${DEPS_CMAKE_FLAGS} "${TRAVIS_BUILD_DIR}/third-party/"

  if ! top_make; then
    exit 1
  fi

  cd "${TRAVIS_BUILD_DIR}"
}

prepare_build() {
  if test -n "${CLANG_SANITIZER}" ; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCLANG_${CLANG_SANITIZER}=ON"
  fi
  if test "x${BUILD_32BIT}" = xON ; then
    CMAKE_FLAGS="${CMAKE_FLAGS} ${CMAKE_FLAGS_32BIT}"
  fi

  mkdir -p "${BUILD_DIR}"
  cd "${BUILD_DIR}"
  echo "Configuring with '${CMAKE_FLAGS} $@'."
  cmake ${CMAKE_FLAGS} "$@" "${TRAVIS_BUILD_DIR}"
}

build_nvim() {
  echo "Building nvim."
  if ! top_make nvim ; then
    exit 1
  fi

  if test "x$CLANG_SANITIZER" != xTSAN ; then
    echo "Building libnvim."
    if ! top_make libnvim ; then
      exit 1
    fi

    echo "Building nvim-test."
    if ! top_make nvim-test ; then
      exit 1
    fi
  fi

  # Invoke nvim to trigger *San early.
  if ! (bin/nvim --version && bin/nvim -u NONE -e -c ':qall') ; then
    asan_check "${LOG_DIR}"
    exit 1
  fi
  asan_check "${LOG_DIR}"


  cd "${TRAVIS_BUILD_DIR}"
}
