#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${GCOV}" ]]; then
  coveralls --gcov "$(which "${GCOV}")" --encoding iso-8859-1 || echo 'coveralls upload failed.'
fi
