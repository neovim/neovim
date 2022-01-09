#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CI_DIR/common/build.sh"
source "$CI_DIR/common/suite.sh"

run_suite 'clint-full' 'make clint-full'
run_suite 'lualint' 'make lualint'
run_suite 'pylint' 'make pylint'
run_suite 'shlint' 'make shlint'
run_suite 'check-single-includes' 'make check-single-includes'

end_tests
