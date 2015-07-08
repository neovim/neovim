#!/usr/bin/env bash

set -e
set -o pipefail

if [[ "${TRAVIS_OS_NAME}" != linux ]]; then
  # Caches are only enabled for Travis's Linux container infrastructure,
  # but this script is still executed on OS X.
  exit
fi

# Don't cache pip's log and selfcheck.
rm -rf "${HOME}/.cache/pip/log"
rm -f "${HOME}/.cache/pip/selfcheck.json"

# Update the third-party dependency cache only if the build was successful.
if [[ -f "${SUCCESS_MARKER}" ]]; then
  if [[ ! -f "${CACHE_MARKER}" ]] || [[ "${BUILD_NVIM_DEPS}" == true ]]; then
    echo "Updating third-party dependency cache."
    rm -rf "${HOME}/.cache/nvim-deps"
    mv -T "${DEPS_INSTALL_PREFIX}" "${HOME}/.cache/nvim-deps"
    touch "${CACHE_MARKER}"
  fi
fi
