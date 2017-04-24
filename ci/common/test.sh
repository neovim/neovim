source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

print_core() {
  local app="$1"
  local core="$2"
  if test "$app" = quiet ; then
    echo "Found core $core"
    return 0
  fi
  echo "======= Core file $core ======="
  if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
    lldb -Q -o "bt all" -f "${app}" -c "${core}"
  else
    gdb -n -batch -ex 'thread apply all bt full' "${app}" -c "${core}"
  fi
}

check_core_dumps() {
  local del=
  if test "$1" = "--delete" ; then
    del=1
    shift
  fi
  local app="${1:-${BUILD_DIR}/bin/nvim}"
  if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
    local cores="$(find /cores/ -type f -print)"
  else
    local cores="$(find ./ -type f -name 'core.*' -print)"
  fi

  if [ -z "${cores}" ]; then
    return
  fi
  local core
  for core in $cores; do
    if test "$del" = "1" ; then
      print_core "$app" "$core" >&2
      rm "$core"
    else
      print_core "$app" "$core"
    fi
  done
  if test "$app" != quiet ; then
    fail 'cores' E 'Core dumps found'
  fi
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
    fail 'logs' E 'Runtime errors detected.'
  fi
}

valgrind_check() {
  check_logs "${1}" "valgrind-*"
}

asan_check() {
  check_logs "${1}" "*san.*"
}

run_unittests() {(
  enter_suite unittests
  ulimit -c unlimited
  if ! build_make unittest ; then
    fail 'unittests' F 'Unit tests failed'
  fi
  check_core_dumps "$(which luajit)"
  exit_suite
)}

run_functionaltests() {(
  enter_suite functionaltests
  ulimit -c unlimited
  if ! build_make ${FUNCTIONALTEST}; then
    fail 'functionaltests' F 'Functional tests failed'
  fi
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
  exit_suite
)}

run_oldtests() {(
  enter_suite oldtests
  ulimit -c unlimited
  if ! make -C "${TRAVIS_BUILD_DIR}/src/nvim/testdir"; then
    reset
    fail 'oldtests' F 'Legacy tests failed'
  fi
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
  exit_suite
)}

install_nvim() {(
  enter_suite 'install_nvim'
  if ! build_make install ; then
    fail 'install' E 'make install failed'
    exit_suite
  fi

  "${INSTALL_PREFIX}/bin/nvim" --version
  "${INSTALL_PREFIX}/bin/nvim" -u NONE -e -c ':help' -c ':qall' || {
    echo "Running ':help' in the installed nvim failed."
    echo "Maybe the helptags have not been generated properly."
    fail 'help' F 'Failed running :help'
  }

  local genvimsynf=syntax/vim/generated.vim
  # Check that all runtime files were installed
  for file in doc/tags $genvimsynf $(
    cd runtime ; git ls-files | grep -e '.vim$' -e '.ps$' -e '.dict$' -e '.py$' -e '.tutor$'
  ) ; do
    if ! test -e "${INSTALL_PREFIX}/share/nvim/runtime/$file" ; then
      fail 'runtime-install' F "It appears that $file is not installed."
    fi
  done

  # Check that generated syntax file has function names, #5060.
  local gpat='syn keyword vimFuncName .*eval'
  if ! grep -q "$gpat" "${INSTALL_PREFIX}/share/nvim/runtime/$genvimsynf"; then
    fail 'funcnames' F "It appears that $genvimsynf does not contain $gpat."
  fi

  for file in $(
    cd runtime ; git ls-files | grep -e '.awk$' -e '.sh$' -e '.bat$'
  ) ; do
    if ! test -x "${INSTALL_PREFIX}/share/nvim/runtime/$file" ; then
      fail 'not-exe' F "It appears that $file is not installed or is not executable."
    fi
  done
  exit_suite
)}
