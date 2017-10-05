#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  brew update
fi

echo 'python info:'
(
  2>&1 python --version || true
  2>&1 python2 --version || true
  2>&1 python3 --version || true
  2>&1 pip --version || true
  2>&1 pip2 --version || true
  2>&1 pip3 --version || true
  echo 'pyenv versions:'
  2>&1 pyenv versions || true
) | sed 's/^/  /'

echo "Upgrade Python 2 pip."
pip2.7 -q install --user --upgrade pip

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  echo "Install Python 3."
  brew install python3
  echo "Upgrade Python 3 pip."
  pip3 -q install --user --upgrade pip
else
  echo "Upgrade Python 3 pip."
  # Allow failure. pyenv pip3 on travis is broken:
  # https://github.com/travis-ci/travis-ci/issues/8363
  pip3 -q install --user --upgrade pip || true
fi
