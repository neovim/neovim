#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/test.sh"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/suite.sh"

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

rm -f "$END_MARKER"

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
  eval "$i" || fail "$i"
done

touch "${END_MARKER}"
ended_successfully
