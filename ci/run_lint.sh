#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

enter_suite 'clint'

run_test 'top_make clint-full' clint

exit_suite --continue

enter_suite 'testlint'

run_test 'top_make testlint' testlint

exit_suite --continue

enter_suite single-includes

CLICOLOR_FORCE=1 run_test_wd \
  --allow-hang \
  10s \
  'top_make check-single-includes' \
  'csi_clean' \
  single-includes

exit_suite --continue

end_tests
