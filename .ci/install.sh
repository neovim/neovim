#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${CI_TARGET}" ]]; then
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  brew install gettext
  brew reinstall -s libtool
fi

# Use default CC to avoid compilation problems when installing Python modules.
echo "Install neovim module and coveralls for Python 2."
CC=cc pip2.7 -q install --user --upgrade neovim cpp-coveralls

echo "Install neovim module for Python 3."
if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  CC=cc pip3 -q install --user --upgrade neovim
else
  CC=cc pip3.3 -q install --user --upgrade neovim
fi

echo "Install neovim RubyGem."
gem install --no-document --version ">= 0.2.0" neovim
