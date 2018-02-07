#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${GCOV}" ]]; then
  bash <(curl -s https://codecov.io/bash) || echo 'codecov upload failed.'
fi
