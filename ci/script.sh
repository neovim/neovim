#!/usr/bin/env bash

set -e
set -o pipefail

# This will pass the environment variables down to a bash process which runs
# as $USER, while retaining the environment variables defined and belonging
# to secondary groups given above in usermod.
if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  sudo -E su "${USER}" -c "ci/run_${CI_TARGET}.sh"
else
  ci/run_${CI_TARGET}.sh
fi
