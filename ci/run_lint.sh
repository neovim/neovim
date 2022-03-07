#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

if [[ "$GITHUB_ACTIONS" != "true" ]]; then
  run_suite 'make clint-full' 'clint'
  run_suite 'make lualint' 'lualint'
  run_suite 'make pylint' 'pylint'
  run_suite 'make shlint' 'shlint'
  run_suite 'make check-single-includes' 'single-includes'

  end_tests
else
  case "$1" in
    clint)
      run_suite 'make clint-full' 'clint'
      ;;
    lualint)
      run_suite 'make lualint' 'lualint'
      ;;
    pylint)
      run_suite 'make pylint' 'pylint'
      ;;
    shlint)
      run_suite 'make shlint' 'shlint'
      ;;
    single-includes)
      run_suite 'make check-single-includes' 'single-includes'
      ;;
    *)
      :;;
  esac

  end_tests
fi
