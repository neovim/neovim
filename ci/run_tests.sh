#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"
source "${CI_DIR}/common/suite.sh"

set -x

enter_suite tests

check_core_dumps --delete quiet

prepare_build
build_nvim

if [ "$CLANG_SANITIZER" != "TSAN" ]; then
  # Additional threads are only created when the builtin UI starts, which
  # doesn't happen in the unit/functional tests
  run_test run_unittests
  run_test run_functionaltests
fi
run_test run_oldtests

run_test install_nvim

end_tests
