#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  # Workaround for https://github.com/travis-ci/travis-ci/issues/8552
  brew update
else
  # Workaround for https://github.com/travis-ci/travis-ci/issues/8363
  pyenv global 2.7 3.6
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
  pip3 -q install --user --upgrade pip
fi

echo "Install node (LTS)"

if [[ "${TRAVIS_OS_NAME}" == osx ]] || [ ! -f ~/.nvm/nvm.sh ]; then
  curl -o ~/.nvm/nvm.sh https://raw.githubusercontent.com/creationix/nvm/master/nvm.sh
fi

source ~/.nvm/nvm.sh
nvm install --lts
nvm use --lts
