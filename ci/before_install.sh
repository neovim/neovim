#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${CI_TARGET}" == lint ]]; then
  exit
fi

echo 'Python info:'
(
  set -x
  python3 --version
  python2 --version
  python --version
  pip3 --version
  pip2 --version
  pip --version
  pyenv versions
) 2>&1 | sed 's/^/  /' || true

# Use pyenv, but not for OSX on Travis, where it only has the "system" version.
if [[ "${TRAVIS_OS_NAME}" != osx ]] && command -v pyenv; then
  echo 'Setting Python versions via pyenv'
  # Prefer python2 as python for /usr/bin/asan_symbolize-4.0.
  pyenv global 2.7.15:3.7

  echo 'Updated Python info:'
  (
    set -x
    python3 --version
    python2 --version
    python --version

    python3 -m pip --version
    python2 -m pip --version
  ) 2>&1 | sed 's/^/  /'
fi

echo "Install node (LTS)"

if [[ "${TRAVIS_OS_NAME}" == osx ]] || [ ! -f ~/.nvm/nvm.sh ]; then
  curl -o ~/.nvm/nvm.sh https://raw.githubusercontent.com/creationix/nvm/master/nvm.sh
fi

source ~/.nvm/nvm.sh
nvm install --lts
nvm use --lts

if [[ -n "$CMAKE_URL" ]]; then
  echo "Installing custom CMake: $CMAKE_URL"
  curl --retry 5 --silent --fail -o /tmp/cmake-installer.sh "$CMAKE_URL"
  mkdir -p "$HOME/.local/bin" /opt/cmake-custom
  bash /tmp/cmake-installer.sh --prefix=/opt/cmake-custom --skip-license
  ln -sfn /opt/cmake-custom/bin/cmake "$HOME/.local/bin/cmake"
  cmake_version="$(cmake --version)"
  echo "$cmake_version" | grep -qF '2.8.12' || {
    echo "Unexpected CMake version: $cmake_version"
    exit 1
  }
fi
