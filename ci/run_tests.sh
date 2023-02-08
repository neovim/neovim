#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/test.sh"

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
