#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

rm -f "$END_MARKER"

# Run all tests if no input argument is given
if (($# == 0)); then
  tests=('clint-full' 'lualint' 'pylint' 'shlint' 'check-single-includes')
else
  tests=("$@")
fi

for i in "${tests[@]}"; do
  make "$i" || fail "$i"
done

end_tests
