#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

enter_suite 'clint'
run_test 'make clint-full' clint
exit_suite --continue

enter_suite 'lualint'
run_test 'make lualint' lualint
exit_suite --continue

enter_suite 'pylint'
run_test 'make pylint' pylint
exit_suite --continue

enter_suite 'shlint'
run_test 'make shlint' shlint
exit_suite --continue

enter_suite single-includes
run_test 'make check-single-includes' single-includes
exit_suite --continue

end_tests
