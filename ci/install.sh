#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  python -m pip -q install --user --upgrade flake8
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  export PATH="/usr/local/opt/ccache/libexec:$PATH"
fi

# Use default CC to avoid compilation problems when installing Python modules.
echo "Install neovim module for Python 3."
CC=cc python3 -m pip -q install --upgrade pynvim
echo "Install neovim module for Python 2."
CC=cc python2 -m pip -q install --upgrade pynvim

echo "Install neovim RubyGem."
gem install --no-document --version ">= 0.8.0" neovim

echo "Install neovim npm package"
npm install -g neovim
npm link neovim
