#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${CI_TARGET}" ]]; then
  exit
fi

coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'
