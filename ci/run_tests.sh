#!/usr/bin/env bash

set -e
set -o pipefail

print_core() {
  local app="$1"
  local core="$2"
  echo "======= Core file $core ======="
  if test "${CI_OS_NAME}" = osx; then
    lldb -Q -o "bt all" -f "${app}" -c "${core}"
  else
    gdb -n -batch -ex 'thread apply all bt full' "${app}" -c "${core}"
  fi
}

check_core_dumps() {
  local app="${1:-${BUILD_DIR}/bin/nvim}"
  local cores
  if test "${CI_OS_NAME}" = osx; then
    cores="$(find /cores/ -type f -print)"
  else
    cores="$(find ./ -type f \( -name 'core.*' -o -name core -o -name nvim.core \) -print)"
  fi

  if test -z "${cores}"; then
    return
  fi
  local core
  for core in $cores; do
    print_core "$app" "$core"
  done
  echo 'Core dumps found'
  exit 1
}

unittests() {(
  ulimit -c unlimited || true
  ninja -C "${BUILD_DIR}" unittest || exit
  check_core_dumps "$(command -v luajit)"
)}

functionaltests() {(
  ulimit -c unlimited || true
  ninja -C "${BUILD_DIR}" "${FUNCTIONALTEST}" || exit
  check_core_dumps
)}

oldtests() {(
  ulimit -c unlimited || true
  if ! make oldtest; then
    reset
    exit 1
  fi
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

eval "$*" || exit
