#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  brew install gettext
  brew reinstall -s libtool
fi

# Use default CC to avoid compilation problems when installing Python modules.
echo "Install neovim module for Python 2."
CC=cc pip2.7 -q install --user --upgrade neovim

echo "Install neovim module for Python 3."
# Allow failure. pyenv pip3 on travis is broken:
# https://github.com/travis-ci/travis-ci/issues/8363
CC=cc pip3 -q install --user --upgrade neovim || true

if ! [ "${TRAVIS_OS_NAME}" = osx ] ; then
  echo "Install neovim RubyGem."
  gem install --no-document --version ">= 0.2.0" neovim
fi

echo "Install neovim npm package"
npm install -g neovim
