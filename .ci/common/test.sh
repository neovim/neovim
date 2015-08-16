check_core_dumps() {
  sleep 2

  if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
    local cores="$(find /cores/ -type f -print)"
    local dbg_cmd="lldb -Q -o bt -f ${BUILD_DIR}/bin/nvim -c"
  else
    # FIXME (fwalch): Will trigger if a file named core.* exists outside of $DEPS_BUILD_DIR.
    local cores="$(find ./ -type f -not -path "*${DEPS_BUILD_DIR}*" -name 'core.*' -print)"
    local dbg_cmd="gdb -n -batch -ex bt ${BUILD_DIR}/bin/nvim"
  fi

  if [ -z "${cores}" ]; then
    return
  fi
  for core in $cores; do
    ${dbg_cmd} "${core}"
  done
  exit 1
}

check_logs() {
  # Iterate through each log to remove an useless warning.
  for log in $(find "${1}" -type f -name "${2}"); do
    sed -i "${log}" \
      -e '/Warning: noted but unhandled ioctl/d' \
      -e '/could cause spurious value errors to appear/d' \
      -e '/See README_MISSING_SYSCALL_OR_IOCTL for guidance/d'
  done

  # Now do it again, but only consider files with size > 0.
  local err=""
  for log in $(find "${1}" -type f -name "${2}" -size +0); do
    cat "${log}"
    err=1
  done
  if [[ -n "${err}" ]]; then
    echo "Runtime errors detected."
    exit 1
  fi
}

valgrind_check() {
  check_logs "${1}" "valgrind-*"
}

asan_check() {
  check_logs "${1}" "*san.*"
}

run_unittests() {
  ${MAKE_CMD} -C "${BUILD_DIR}" unittest
}

run_functionaltests() {
  if ! ${MAKE_CMD} -C "${BUILD_DIR}" functionaltest; then
    asan_check "${LOG_DIR}"
    valgrind_check "${LOG_DIR}"
    exit 1
  fi
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
}

run_oldtests() {
  if ! make -C "${TRAVIS_BUILD_DIR}/src/nvim/testdir"; then
    reset
    asan_check "${LOG_DIR}"
    valgrind_check "${LOG_DIR}"
    exit 1
  fi
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
}

install_nvim() {
  ${MAKE_CMD} -C "${BUILD_DIR}" install

  "${INSTALL_PREFIX}/bin/nvim" --version
  "${INSTALL_PREFIX}/bin/nvim" -u NONE -e -c ':help' -c ':qall' || {
    echo "Running ':help' in the installed nvim failed."
    echo "Maybe the helptags have not been generated properly."
    exit 1
  }

  # Check that all runtime files were installed
  for file in doc/tags syntax/vim/generated.vim $(
    cd runtime ; git ls-files | grep -e '.vim$' -e '.ps$' -e '.dict$' -e '.py$' -e '.tutor$'
  ) ; do
    if ! test -e "${INSTALL_PREFIX}/share/nvim/runtime/$file" ; then
      echo "It appears that $file is not installed."
      exit 1
    fi
  done

  for file in $(
    cd runtime ; git ls-files | grep -e '.awk$' -e '.sh$' -e '.bat$'
  ) ; do
    if ! test -x "${INSTALL_PREFIX}/share/nvim/runtime/$file" ; then
      echo "It appears that $file is not installed or is not executable."
      exit 1
    fi
  done
}
