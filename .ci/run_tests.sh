#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"

check_core_dumps --delete quiet

prepare_build
build_nvim
run_single_includes_tests

if [ "$CLANG_SANITIZER" != "TSAN" ]; then
  # Additional threads are only created when the builtin UI starts, which
  # doesn't happen in the unit/functional tests
  run_unittests
  run_functionaltests
fi
run_oldtests

install_nvim

touch "${SUCCESS_MARKER}"
