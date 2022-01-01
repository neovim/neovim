#!/usr/bin/env bash

set -e
set -o pipefail

ci/run_${CI_TARGET}.sh

if [[ -s "${GCOV_ERROR_FILE}" ]]; then
  echo '=== Unexpected gcov errors: ==='
  cat "${GCOV_ERROR_FILE}"
  exit 1
fi
