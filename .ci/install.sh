#!/usr/bin/env bash

set -e
set -o pipefail

if [[ -n "${CI_TARGET}" ]]; then
  exit
fi

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${TRAVIS_OS_NAME}" == osx ]]; then
  brew install gettext
elif [[ "${BUILD_MINGW}" == ON ]]; then
  # TODO: When Travis gets a recent version of Mingw-w64 use packages:
  # binutils-mingw-w64-i686 gcc-mingw-w64-i686 g++-mingw-w64-i686 mingw-w64-dev mingw-w64-tools

  echo "Downloading MinGW..."
  wget -q -O - "http://downloads.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win32/Personal%20Builds/rubenvb/gcc-4.8-release/i686-w64-mingw32-gcc-4.8.0-linux64_rubenvb.tar.xz" | tar xJf - -C "${HOME}/.local"
fi

pip install --user --upgrade cpp-coveralls neovim

echo "Downloading plugins..."
while read line; do
  if [[ -z "${line}" ]]; then
    continue
  fi

  plugin="$(echo "${line}" | cut -d ' ' -f 1)"
  revision="$(echo "${line}" | cut -d ' ' -f 2)"

  if [[ -d "${PLUGIN_DIR}/${plugin}/.git" ]]; then
    git --git-dir="${PLUGIN_DIR}/${plugin}/.git" fetch
  else
    mkdir -p "${PLUGIN_DIR}/${plugin}"
    git clone -q --recursive "https://github.com/${plugin}" "${PLUGIN_DIR}/${plugin}" || {
      # Something went wrong, delete to make sure the directory isn't cached.
      rm -rf "${PLUGIN_DIR}/${plugin}"
      exit 1
    }
  fi
  git --git-dir="${PLUGIN_DIR}/${plugin}/.git" reset --hard "${revision}" -- >/dev/null
done < "${CI_DIR}/common/plugins.txt"
