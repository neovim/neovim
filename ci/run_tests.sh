#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"
source "${CI_DIR}/common/suite.sh"

enter_suite build

check_core_dumps --delete quiet

prepare_build
build_nvim

exit_suite --continue

enter_suite tests

if test "$CLANG_SANITIZER" != "TSAN" ; then
  # Additional threads are only created when the builtin UI starts, which
  # doesn't happen in the unit/functional tests
  run_test run_unittests
  NODE_PATH=~/.node_modules
  run_test run_functionaltests
  NODE_PATH=
fi
run_test run_oldtests

run_test install_nvim

exit_suite --continue

end_tests
