#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${CI_TARGET}" ]]; then
  exit
fi

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  # Adds user to a dummy group.
  # That allows to test changing the group of the file by `os_fchown`.
  sudo dscl . -create /Groups/chown_test
  sudo dscl . -append /Groups/chown_test GroupMembership "${USER}"
else
  # Compile dependencies.
  build_deps
fi

rm -rf "${LOG_DIR}"
mkdir -p "${LOG_DIR}"
