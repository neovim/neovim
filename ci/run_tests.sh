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

# Ensure that Python support is available.
# XXX: move to build_nvim?  Why is build_nvim in run_tests?!
env | sort
command -v python
python -c 'print(__import__("vim"))'
build/bin/nvim -u NONE -c 'exe !has("python")."cq"' || { echo "Python 2 is not available"; exit 1;}
build/bin/nvim -u NONE -c 'exe !has("python3")."cq"' || { echo "Python 3 is not available"; exit 1;}

exit_suite --continue

enter_suite tests

run_test run_oldtests

exit_suite --continue

end_tests
