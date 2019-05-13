#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  exit
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

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  echo "Upgrade Python 3 pip"
  python3 -m pip -q install --user --upgrade pip
else
  echo "Upgrade Python 2 pip"
  python2.7 -m pip -q install --user --upgrade pip
  echo "Upgrade Python 3 pip"
  # Allow failure. pyenv pip3 on travis is broken:
  # https://github.com/travis-ci/travis-ci/issues/8363
  python3 -m pip -q install --user --upgrade pip || true
fi

echo "Install node (LTS)"

if [[ "${TRAVIS_OS_NAME}" == osx ]] || [ ! -f ~/.nvm/nvm.sh ]; then
  curl -o ~/.nvm/nvm.sh https://raw.githubusercontent.com/creationix/nvm/master/nvm.sh
fi

source ~/.nvm/nvm.sh
nvm install --lts
nvm use --lts
