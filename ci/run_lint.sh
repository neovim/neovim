#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

run_suite 'make clint-full' 'clint'
run_suite 'make lualint' 'lualint'
run_suite 'make pylint' 'pylint'
run_suite 'make shlint' 'shlint'
run_suite 'make check-single-includes' 'single-includes'

end_tests
