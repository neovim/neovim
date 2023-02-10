#!/usr/bin/env bash

set -e
set -o pipefail

print_core() {
  local app="$1"
  local core="$2"
  if test "$app" = quiet; then
    echo "Found core $core"
    return 0
  fi
  echo "======= Core file $core ======="
  if test "${CI_OS_NAME}" = osx; then
    lldb -Q -o "bt all" -f "${app}" -c "${core}"
  else
    gdb -n -batch -ex 'thread apply all bt full' "${app}" -c "${core}"
  fi
}

check_core_dumps() {
  local del=
  if test "$1" = "--delete"; then
    del=1
    shift
  fi
  local app="${1:-${BUILD_DIR}/bin/nvim}"
  local cores
  if test "${CI_OS_NAME}" = osx; then
    cores="$(find /cores/ -type f -print)"
    local _sudo='sudo'
  else
    cores="$(find ./ -type f \( -name 'core.*' -o -name core -o -name nvim.core \) -print)"
    local _sudo=
  fi

  if test -z "${cores}"; then
    return
  fi
  local core
  for core in $cores; do
    if test "$del" = "1"; then
      print_core "$app" "$core" >&2
      "$_sudo" rm "$core"
    else
      print_core "$app" "$core"
    fi
  done
  if test "$app" != quiet; then
    echo 'Core dumps found'
    exit 1
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
  if test -n "${err}"; then
    echo 'Runtime errors detected.'
    exit 1
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
  ninja -C "${BUILD_DIR}" unittest || exit
  check_core_dumps "$(command -v luajit)"
)}

functionaltests() {(
  ulimit -c unlimited || true
  ninja -C "${BUILD_DIR}" "${FUNCTIONALTEST}" || exit
  check_sanitizer "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
)}

oldtests() {(
  ulimit -c unlimited || true
  if ! make oldtest; then
    reset
    exit 1
  fi
  check_sanitizer "${LOG_DIR}"
  valgrind_check "${LOG_DIR}"
  check_core_dumps
)}

check_runtime_files() {(
  local message="$1"; shift
  local tst="$1"; shift

  for file in $(git -C runtime ls-files "$@"); do
    # Check that test is not trying to work with files with spaces/etc
    # Prefer failing the build over using more robust construct because files
    # with IFS are not welcome.
    if ! test -e "$file"; then
      echo "It appears that $file is only a part of the file name"
      exit 1
    fi
    if ! test "$tst" "$INSTALL_PREFIX/share/nvim/runtime/$file"; then
      printf "%s%s" "$message" "$file"
      exit 1
    fi
  done
)}

installtests() {(
  "${INSTALL_PREFIX}/bin/nvim" --version
  if ! "${INSTALL_PREFIX}/bin/nvim" -u NONE -e -c ':help' -c ':qall'; then
    echo "Running ':help' in the installed nvim failed."
    echo "Maybe the helptags have not been generated properly."
    echo 'Failed running :help'
    exit 1
  fi

  # Check that all runtime files were installed
  check_runtime_files \
    'It appears that %s is not installed.' \
    -e \
    '*.vim' '*.ps' '*.dict' '*.py' '*.tutor'

  # Check that some runtime files are installed and are executables
  check_runtime_files \
    'It appears that %s is not installed or is not executable.' \
    -x \
    '*.awk' '*.sh' '*.bat'

  # Check that generated syntax file has function names, #5060.
  local genvimsynf=syntax/vim/generated.vim
  local gpat='syn keyword vimFuncName .*eval'
  if ! grep -q "$gpat" "${INSTALL_PREFIX}/share/nvim/runtime/$genvimsynf"; then
    echo "It appears that $genvimsynf does not contain $gpat."
    exit 1
  fi
)}

prepare_sanitizer() {
  check_core_dumps --delete quiet
  # Invoke nvim to trigger *San early.
  if ! ("${BUILD_DIR}"/bin/nvim --version && "${BUILD_DIR}"/bin/nvim -u NONE -e -cq | cat -vet); then
    check_sanitizer "${LOG_DIR}"
    exit 1
  fi
  check_sanitizer "${LOG_DIR}"
}

rm -rf "${LOG_DIR}"
mkdir -p "${LOG_DIR}"

eval "$*" || exit
