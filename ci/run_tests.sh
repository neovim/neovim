#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"
source "${CI_DIR}/common/suite.sh"

rm -f "$END_MARKER"

# Run all tests (with some caveats) if no input argument is given
if (($# == 0)); then
  tests=('build_nvim')

  if test "$CLANG_SANITIZER" != "TSAN"; then
    # Additional threads are only created when the builtin UI starts, which
    # doesn't happen in the unit/functional tests
    if test "${FUNCTIONALTEST}" != "functionaltest-lua"; then
      tests+=('unittests')
    fi
    tests+=('functionaltests')
  fi

  tests+=('oldtests' 'install_nvim')
else
  tests=("$@")
fi

for i in "${tests[@]}"; do
  eval "$i" || fail "$i"
done

end_tests
