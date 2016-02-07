build_deps() {
  if [[ "${BUILD_32BIT}" == ON ]]; then
    DEPS_CMAKE_FLAGS="${DEPS_CMAKE_FLAGS} ${CMAKE_FLAGS_32BIT}"
  fi
  if [[ "${BUILD_MINGW}" == ON ]]; then
    DEPS_CMAKE_FLAGS="${DEPS_CMAKE_FLAGS} ${CMAKE_FLAGS_MINGW}"
  fi

  rm -rf "${DEPS_BUILD_DIR}"

  # If there is a valid cache and we're not forced to recompile,
  # use cached third-party dependencies.
  if [[ -f "${CACHE_MARKER}" ]] && [[ "${BUILD_NVIM_DEPS}" != true ]]; then
    echo "Using third-party dependencies from Travis's cache (last updated: $(stat -c '%y' "${CACHE_MARKER}"))."

     mkdir -p "$(dirname "${DEPS_BUILD_DIR}")"
     mv -T "${HOME}/.cache/nvim-deps" "${DEPS_BUILD_DIR}"
  else
    mkdir -p "${DEPS_BUILD_DIR}"
  fi

  # Even if we're using cached dependencies, run CMake and make to
  # update CMake configuration and update to newer deps versions.
  cd "${DEPS_BUILD_DIR}"
  echo "Configuring with '${DEPS_CMAKE_FLAGS}'."
  cmake ${DEPS_CMAKE_FLAGS} "${TRAVIS_BUILD_DIR}/third-party/"

  if ! ${MAKE_CMD}; then
    exit 1
  fi

  cd "${TRAVIS_BUILD_DIR}"
}

build_nvim() {
  if [[ -n "${CLANG_SANITIZER}" ]]; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCLANG_${CLANG_SANITIZER}=ON"
  fi
  if [[ "${BUILD_32BIT}" == ON ]]; then
    CMAKE_FLAGS="${CMAKE_FLAGS} ${CMAKE_FLAGS_32BIT}"
  fi
  if [[ "${BUILD_MINGW}" == ON ]]; then
    CMAKE_FLAGS="${CMAKE_FLAGS} ${CMAKE_FLAGS_MINGW}"
  fi

  mkdir -p "${BUILD_DIR}"
  cd "${BUILD_DIR}"
  echo "Configuring with '${CMAKE_FLAGS}'."
  cmake ${CMAKE_FLAGS} "${TRAVIS_BUILD_DIR}"

  echo "Building nvim."
  if ! ${MAKE_CMD} nvim; then
    exit 1
  fi

  if [ "$CLANG_SANITIZER" != "TSAN" ]; then
    echo "Building libnvim."
    if ! ${MAKE_CMD} libnvim; then
      exit 1
    fi

    echo "Building nvim-test."
    if ! ${MAKE_CMD} nvim-test; then
      exit 1
    fi
  fi

  # Invoke nvim to trigger *San early.
  if ! (bin/nvim --version && bin/nvim -u NONE -e -c ':qall'); then
    asan_check "${LOG_DIR}"
    exit 1
  fi
  asan_check "${LOG_DIR}"


  cd "${TRAVIS_BUILD_DIR}"
}
