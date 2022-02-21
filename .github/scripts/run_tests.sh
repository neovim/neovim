#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"
source "${CI_DIR}/common/suite.sh"


if [[ "$GITHUB_ACTIONS" != "true" ]]; then
  run_suite 'build_nvim' 'build'

  if test "$CLANG_SANITIZER" != "TSAN"; then
    # Additional threads are only created when the builtin UI starts, which
    # doesn't happen in the unit/functional tests
    if test "${FUNCTIONALTEST}" != "functionaltest-lua"; then
      run_suite run_unittests unittests
    fi
    run_suite run_functionaltests functionaltests
  fi
  run_suite run_oldtests oldtests
  run_suite install_nvim install_nvim

  end_tests
else
  case "$1" in
    build)
      run_suite 'build_nvim' 'build'
      ;;
    unittests)
      run_suite 'run_unittests' 'unittests'
      ;;
    functionaltests)
      run_suite 'run_functionaltests' 'functionaltests'
      ;;
    oldtests)
      run_suite 'run_oldtests' 'oldtests'
      ;;
    install_nvim)
      run_suite 'install_nvim' 'install_nvim'
      ;;
    *)
      :;;
  esac

  end_tests
fi
