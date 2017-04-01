#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  brew update
fi

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
