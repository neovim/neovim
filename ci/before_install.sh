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
