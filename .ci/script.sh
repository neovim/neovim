#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${CI_TARGET}" ]]; then
  make "${CI_TARGET}"
  exit 0
fi

# This will pass the environment variables down to a bash process which runs
# as $USER, while retaining the environment variables defined and belonging
# to secondary groups given above in usermod.
if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  # Set up precompiled third-party dependencies.
  eval "$(curl -Ss https://raw.githubusercontent.com/neovim/bot-ci/master/scripts/travis-setup.sh) deps-x64"

  sudo -E su "${USER}" -c ".ci/run_tests.sh"
else
  .ci/run_tests.sh
fi
