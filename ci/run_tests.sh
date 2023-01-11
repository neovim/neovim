#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/build.sh"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/test.sh"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/suite.sh"

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

end_tests

if [[ -s "${GCOV_ERROR_FILE}" ]]; then
  echo '=== Unexpected gcov errors: ==='
  cat "${GCOV_ERROR_FILE}"
  exit 1
fi
