#!/usr/bin/env bash

set -e
set -o pipefail

echo 'Python info:'
(
  set -x
  python3 --version
  python2 --version
  python --version
  pip3 --version
  pip2 --version
  pip --version

  pyenv --version
  pyenv versions
) 2>&1 | sed 's/^/  /' || true

# Use pyenv, but not for OSX on Travis, where it only has the "system" version.
if [[ "${TRAVIS_OS_NAME}" != osx ]] && command -v pyenv; then
  echo 'Setting Python versions via pyenv'

  # Prefer Python 2 over 3 (more conservative).
  pyenv global 2.7:3.8

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
nvm install 10
