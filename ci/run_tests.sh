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

run_test run_oldtests

exit_suite --continue

end_tests
