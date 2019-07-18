. "${CI_DIR}/common/build.sh"
. "${CI_DIR}/common/suite.sh"

submit_coverage() {
  if [ -n "${GCOV}" ]; then
    "${CI_DIR}/common/submit_coverage.sh" "$@" || echo 'codecov upload failed.'
  fi
}

print_core() {
  local app="$1"
  local core="$2"
  if test "$app" = quiet ; then
    echo "Found core $core"
    return 0
  fi
  echo "======= Core file $core ======="
  if test "${TRAVIS_OS_NAME}" = osx ; then
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
  local cores
  if test "${TRAVIS_OS_NAME}" = osx ; then
    cores="$(find /cores/ -type f -print)"
    local _sudo='sudo'
  else
    cores="$(find ./ -type f -name 'core.*' -print)"
    local _sudo=
  fi

  if test -z "${cores}" ; then
    return
  fi
  local core
  for core in $cores; do
    if test "$del" = "1" ; then
      print_core "$app" "$core" >&2
      "$_sudo" rm "$core"
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
  if test -n "${err}" ; then
    fail 'logs' E 'Runtime errors detected.'
  fi
}

valgrind_check() {
  check_logs "${1}" "valgrind-*"
}

asan_check() {
  if test "${CLANG_SANITIZER}" = "ASAN_UBSAN" ; then
    check_logs "${1}" "*san.*" | asan_symbolize
  fi
}

run_unittests() {(
  enter_suite unittests
  ulimit -c unlimited || true
  if ! build_make unittest ; then
    fail 'unittests' F 'Unit tests failed'
  fi
  submit_coverage unittest
  check_core_dumps "$(command -v luajit)"
  exit_suite
)}

run_functionaltests() {(
  enter_suite functionaltests
  ulimit -c unlimited || true
  if ! build_make ${FUNCTIONALTEST}; then
    fail 'functionaltests' F 'Functional tests failed'
  fi
  submit_coverage functionaltest
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
  exit_suite
)}

run_oldtests() {(
  enter_suite oldtests
  ulimit -c unlimited || true
  if ! make -C "${TRAVIS_BUILD_DIR}/src/nvim/testdir"; then
    reset
    fail 'oldtests' F 'Legacy tests failed'
  fi
  submit_coverage oldtest
  asan_check "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
  exit_suite
)}

check_runtime_files() {(
  set +x
  local test_name="$1" ; shift
  local message="$1" ; shift
  local tst="$1" ; shift

  cd runtime
  for file in $(git ls-files "$@") ; do
    # Check that test is not trying to work with files with spaces/etc
    # Prefer failing the build over using more robust construct because files
    # with IFS are not welcome.
    if ! test -e "$file" ; then
      fail "$test_name" E \
        "It appears that $file is only a part of the file name"
    fi
    if ! test "$tst" "$INSTALL_PREFIX/share/nvim/runtime/$file" ; then
      fail "$test_name" F "$(printf "$message" "$file")"
    fi
  done
)}

install_nvim() {(
  enter_suite 'install_nvim'
  if ! build_make install ; then
    fail 'install' E 'make install failed'
    exit_suite
  fi

  "${INSTALL_PREFIX}/bin/nvim" --version
  if ! "${INSTALL_PREFIX}/bin/nvim" -u NONE -e -c ':help' -c ':qall' ; then
    echo "Running ':help' in the installed nvim failed."
    echo "Maybe the helptags have not been generated properly."
    fail 'help' F 'Failed running :help'
  fi

  # Check that all runtime files were installed
  check_runtime_files \
    'runtime-install' \
    'It appears that %s is not installed.' \
    -e \
    '*.vim' '*.ps' '*.dict' '*.py' '*.tutor'

  # Check that some runtime files are installed and are executables
  check_runtime_files \
    'not-exe' \
    'It appears that %s is not installed or is not executable.' \
    -x \
    '*.awk' '*.sh' '*.bat'

  # Check that generated syntax file has function names, #5060.
  local genvimsynf=syntax/vim/generated.vim
  local gpat='syn keyword vimFuncName .*eval'
  if ! grep -q "$gpat" "${INSTALL_PREFIX}/share/nvim/runtime/$genvimsynf" ; then
    fail 'funcnames' F "It appears that $genvimsynf does not contain $gpat."
  fi

  exit_suite
)}

csi_clean() {
  find "${BUILD_DIR}/bin" -name 'test-includes-*' -delete
  find "${BUILD_DIR}" -name '*test-include*.o' -delete
}
