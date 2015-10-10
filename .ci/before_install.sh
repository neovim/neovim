#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${CI_TARGET}" ]]; then
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  brew update
fi

echo "Upgrade Python 2's pip."
pip2.7 install --user --upgrade pip

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  echo "Install Python 3."
  brew install python3
  echo "Upgrade Python 3's pip."
  pip3 install --user --upgrade pip
else
  # TODO: Replace with upgrade when Travis gets python3-pip package.
  echo "Install pip for Python 3."
  curl -sSL https://bootstrap.pypa.io/get-pip.py -o "${HOME}/get-pip.py"
  # After this, pip in PATH will refer to Python 3's pip.
  python3.3 "${HOME}/get-pip.py" --user --upgrade
fi
