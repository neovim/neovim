#!/usr/bin/env bash

set -e
set -o pipefail

# TODO: Stop here for MinGW builds,
#       building Neovim doesn't work yet.
if [[ "${BUILD_MINGW}" == ON ]]; then
  echo "Neovim doesn't build on MinGW yet; stopping build."
  touch "${SUCCESS_MARKER}"
  exit
fi

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"

build_nvim

if [ "$CLANG_SANITIZER" != "TSAN" ]; then
  # Additional threads are only created when the builtin UI starts, which
  # doesn't happen in the unit/functional tests
  run_unittests
  run_functionaltests
fi
run_oldtests

install_nvim

touch "${SUCCESS_MARKER}"
