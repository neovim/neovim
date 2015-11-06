#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${CI_TARGET}" ]]; then
  exit
fi

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  brew install gettext
elif [[ "${BUILD_MINGW}" == ON ]]; then
  # TODO: When Travis gets a recent version of Mingw-w64 use packages:
  # binutils-mingw-w64-i686 gcc-mingw-w64-i686 g++-mingw-w64-i686 mingw-w64-dev mingw-w64-tools

  echo "Downloading MinGW..."
  curl -sSL "http://downloads.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Personal%20Builds/rubenvb/gcc-4.8-release/i686-w64-mingw32-gcc-4.8.0-linux64_rubenvb.tar.xz" | tar xJf - -C "${HOME}/.local"
fi

# Set CC to default to avoid compilation problems
# when installing Python modules.
echo "Install neovim module and coveralls for Python 2."
CC=cc pip2.7 install --user --upgrade neovim cpp-coveralls

echo "Install neovim module for Python 3."
if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  CC=cc pip3 install --user --upgrade neovim
else
  CC=cc pip3.3 install --user --upgrade neovim
fi
