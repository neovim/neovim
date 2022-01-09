#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CI_DIR/common/build.sh"
source "$CI_DIR/common/test.sh"
source "$CI_DIR/common/suite.sh"

run_suite "build" "build_nvim"

if test "$CLANG_SANITIZER" != "TSAN"; then
  # Additional threads are only created when the builtin UI starts, which
  # doesn't happen in the unit/functional tests
  if test "$FUNCTIONALTEST" != "functionaltest-lua"; then
    run_suite 'unittests' 'run_unittests'
  fi
  run_suite 'functionaltests' 'run_functionaltests'
fi

run_suite 'oldtests' 'run_oldtests'
run_suite 'install_nvim' 'install_nvim'

end_tests
