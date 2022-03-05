#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

rm -f "$END_MARKER"

if [[ "$GITHUB_ACTIONS" != "true" ]]; then
  make clint-full || fail 'clint'
  make lualint || fail 'lualint'
  make pylint || fail 'pylint'
  make shlint || fail 'shlint'
  make check-single-includes || fail 'single-includes'

  end_tests
else
  case "$1" in
    clint)
      make clint-full || fail 'clint'
      ;;
    lualint)
      make lualint || fail 'lualint'
      ;;
    pylint)
      make pylint || fail 'pylint'
      ;;
    shlint)
      make shlint || fail 'shlint'
      ;;
    single-includes)
      make check-single-includes || fail 'single-includes'
      ;;
    *)
      :;;
  esac

  end_tests
fi
