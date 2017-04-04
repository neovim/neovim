#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

enter_suite 'lint'

set -x

csi_clean() {
  find "${BUILD_DIR}/bin" -name 'test-includes-*' -delete
  find "${BUILD_DIR}" -name '*test-include*.o' -delete
}

run_test 'top_make clint-full' clint
run_test 'top_make testlint' testlint
CLICOLOR_FORCE=1 run_test_wd \
  5s \
  'top_make check-single-includes' \
  'csi_clean' \
  single-includes

end_tests
