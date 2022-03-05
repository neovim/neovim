#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/test.sh"
source "${CI_DIR}/common/suite.sh"

rm -f "$END_MARKER"

if [[ "$GITHUB_ACTIONS" != "true" ]]; then
  build_nvim || fail 'build'

  if test "$CLANG_SANITIZER" != "TSAN"; then
    # Additional threads are only created when the builtin UI starts, which
    # doesn't happen in the unit/functional tests
    if test "${FUNCTIONALTEST}" != "functionaltest-lua"; then
      run_unittests || fail 'unittests'
    fi
    run_functionaltests || fail 'functionaltests'
  fi
  run_oldtests || fail 'oldtests'
  install_nvim || fail 'install_nvim'

  end_tests
else
  case "$1" in
    build)
      build_nvim || fail 'build'
      ;;
    unittests)
      run_unittests || fail 'unittests'
      ;;
    functionaltests)
      run_functionaltests || fail 'functionaltests'
      ;;
    oldtests)
      run_oldtests || fail 'oldtests'
      ;;
    install_nvim)
      install_nvim || fail 'install_nvim'
      ;;
    *)
      :;;
  esac

  end_tests
fi
