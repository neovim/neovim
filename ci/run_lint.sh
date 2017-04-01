#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

enter_suite 'lint'

set -x

run_test 'top_make clint-full' clint
run_test 'top_make testlint' testlint
run_test_wd 5s 'top_make check-single-includes' single-includes

exit_suite
