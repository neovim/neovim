#!/usr/bin/env bash

set -e
set -o pipefail
set -x

if [[ -n "${GCOV_ERROR_FILE}" ]]; then
  ls -l "${GCOV_ERROR_FILE}" || true
  if [[ -s "${GCOV_ERROR_FILE}" ]]; then
    echo '=== Unexpected gcov errors: ==='
    cat "${GCOV_ERROR_FILE}"
    exit 1
  fi
fi
