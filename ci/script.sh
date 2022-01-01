#!/usr/bin/env bash

set -e
set -o pipefail

# This will pass the environment variables down to a bash process which runs
# as $USER, while retaining the environment variables defined and belonging
# to secondary groups given above in usermod.
ci/run_${CI_TARGET}.sh

if [[ -s "${GCOV_ERROR_FILE}" ]]; then
  echo '=== Unexpected gcov errors: ==='
  cat "${GCOV_ERROR_FILE}"
  exit 1
fi
