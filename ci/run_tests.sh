#!/usr/bin/env bash

set -e
set -o pipefail

fail() {
  local test_name="$1"
  local message="$2"

  : "${message:=Test $test_name failed}"

  local full_msg="$test_name :: $message"
  echo "Failed: $full_msg"
  exit 1
}

print_core() {
  local app="$1"
  local core="$2"
  if test "$app" = quiet ; then
    echo "Found core $core"
    return 0
  fi
  echo "======= Core file $core ======="
  if test "${CI_OS_NAME}" = osx ; then
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
  if test "${CI_OS_NAME}" = osx ; then
    cores="$(find /cores/ -type f -print)"
    local _sudo='sudo'
  else
    cores="$(find ./ -type f \( -name 'core.*' -o -name core -o -name nvim.core \) -print)"
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
    fail 'cores' 'Core dumps found'
  fi
}

check_logs() {
  # Iterate through each log to remove an useless warning.
  # shellcheck disable=SC2044
  for log in $(find "${1}" -type f -name "${2}"); do
    sed -i "${log}" \
      -e '/Warning: noted but unhandled ioctl/d' \
      -e '/could cause spurious value errors to appear/d' \
      -e '/See README_MISSING_SYSCALL_OR_IOCTL for guidance/d'
  done

  # Now do it again, but only consider files with size > 0.
  local err=""
  # shellcheck disable=SC2044
  for log in $(find "${1}" -type f -name "${2}" -size +0); do
    cat "${log}"
    err=1
    rm "${log}"
  done
  if test -n "${err}" ; then
    fail 'logs' 'Runtime errors detected.'
  fi
}

valgrind_check() {
  check_logs "${1}" "valgrind-*"
}

check_sanitizer() {
  if test -n "${CLANG_SANITIZER}"; then
    check_logs "${1}" "*san.*" | cat
  fi
}

unittests() {(
  ulimit -c unlimited || true
  if ! ninja -C "${BUILD_DIR}" unittest; then
    fail 'unittests' 'Unit tests failed'
  fi
  check_core_dumps "$(command -v luajit)"
)}

functionaltests() {(
  ulimit -c unlimited || true
  if ! ninja -C "${BUILD_DIR}" "${FUNCTIONALTEST}"; then
    fail 'functionaltests' 'Functional tests failed'
  fi
  check_sanitizer "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
)}

oldtests() {(
  ulimit -c unlimited || true
  if ! make oldtest; then
    reset
    fail 'oldtests' 'Legacy tests failed'
  fi
  check_sanitizer "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
)}

check_runtime_files() {(
  local test_name="$1" ; shift
  local message="$1" ; shift
  local tst="$1" ; shift

  cd runtime || exit
  for file in $(git ls-files "$@") ; do
    # Check that test is not trying to work with files with spaces/etc
    # Prefer failing the build over using more robust construct because files
    # with IFS are not welcome.
    if ! test -e "$file" ; then
      fail "$test_name" "It appears that $file is only a part of the file name"
    fi
    if ! test "$tst" "$INSTALL_PREFIX/share/nvim/runtime/$file" ; then
      fail "$test_name" "$(printf "%s%s" "$message" "$file")"
    fi
  done
)}

install_nvim() {(
  if ! ninja -C "${BUILD_DIR}" install; then
    fail 'install' 'make install failed'
  fi

  "${INSTALL_PREFIX}/bin/nvim" --version
  if ! "${INSTALL_PREFIX}/bin/nvim" -u NONE -e -c ':help' -c ':qall' ; then
    echo "Running ':help' in the installed nvim failed."
    echo "Maybe the helptags have not been generated properly."
    fail 'help' 'Failed running :help'
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
    fail 'funcnames' "It appears that $genvimsynf does not contain $gpat."
  fi
)}

build_nvim() {
  check_core_dumps --delete quiet

  if test -n "${CLANG_SANITIZER}" ; then
    CMAKE_FLAGS="${CMAKE_FLAGS} -D CLANG_${CLANG_SANITIZER}=ON"
  fi

  mkdir -p "${BUILD_DIR}"
  cd "${BUILD_DIR}"
  echo "Configuring with '${CMAKE_FLAGS} $*'."
  # shellcheck disable=SC2086
  cmake -G Ninja ${CMAKE_FLAGS} "$@" "${CI_BUILD_DIR}"

  echo "Building nvim."
  ninja nvim || exit 1

  # Invoke nvim to trigger *San early.
  if ! (bin/nvim --version && bin/nvim -u NONE -e -cq | cat -vet) ; then
    check_sanitizer "${LOG_DIR}"
    exit 1
  fi
  check_sanitizer "${LOG_DIR}"

  cd "${CI_BUILD_DIR}"
}

# Run all tests (with some caveats) if no input argument is given
if (($# == 0)); then
  tests=('build_nvim')

  # Additional threads aren't created in the unit/old tests
  if test "$CLANG_SANITIZER" != "TSAN"; then
    if test "${FUNCTIONALTEST}" != "functionaltest-lua"; then
      tests+=('unittests')
    fi
    tests+=('oldtests')
  fi

  tests+=('functionaltests' 'install_nvim')
else
  tests=("$@")
fi

for i in "${tests[@]}"; do
  eval "$i" || exit
done

if [[ -s "${GCOV_ERROR_FILE}" ]]; then
  echo '=== Unexpected gcov errors: ==='
  cat "${GCOV_ERROR_FILE}"
  exit 1
fi
