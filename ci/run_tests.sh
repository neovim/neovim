#!/usr/bin/env bash

set -e
set -o pipefail

run_tests(){
  if test "$CLANG_SANITIZER" != "TSAN"; then
    # Additional threads are only created when the builtin UI starts, which
    # doesn't happen in the unit/functional tests
    if test "${FUNCTIONALTEST}" != "functionaltest-lua"; then
      run_test run_unittests unittests
    fi
    run_test run_functionaltests functionaltests
  fi
  run_test run_oldtests oldtests
  run_test install_nvim install_nvim
}

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"
source "${CI_DIR}/common/suite.sh"

run_suite 'build_nvim' 'build'
run_suite 'run_tests' 'tests'

end_tests
