build_nvim() {
  check_core_dumps --delete quiet

  if test -n "${CLANG_SANITIZER}" ; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -DCLANG_${CLANG_SANITIZER}=ON"
  fi

  mkdir -p "${BUILD_DIR}"
  cd "${BUILD_DIR}"
  echo "Configuring with '${CMAKE_FLAGS} $*'."
  # shellcheck disable=SC2086
  cmake -G Ninja ${CMAKE_FLAGS} "$@" "${CI_BUILD_DIR}"

  echo "Building nvim."
  if ! ninja nvim ; then
    exit 1
  fi

  if test "$CLANG_SANITIZER" != "TSAN" ; then
    echo "Building libnvim."
    if ! ninja libnvim ; then
      exit 1
    fi

    if test "${FUNCTIONALTEST}" != "functionaltest-lua"; then
      echo "Building nvim-test."
      if ! ninja nvim-test ; then
        exit 1
      fi
    fi
  fi

  # Invoke nvim to trigger *San early.
  if ! (bin/nvim --version && bin/nvim -u NONE -e -cq | cat -vet) ; then
    check_sanitizer "${LOG_DIR}"
    exit 1
  fi
  check_sanitizer "${LOG_DIR}"

  cd "${CI_BUILD_DIR}"
}
