#!/usr/bin/env bash

set -e
set -o pipefail

mkdir -p "$CACHE_DIR"

# Update the third-party dependency cache only if the build was successful.
if [ -d "${DEPS_BUILD_DIR}" ]; then
  # Do not cache downloads.  They should not be needed with up-to-date deps.
  rm -rf "${DEPS_BUILD_DIR}/build/downloads"
  rm -rf "${CACHE_NVIM_DEPS_DIR}"
  mv "${DEPS_BUILD_DIR}" "${CACHE_NVIM_DEPS_DIR}"

  touch "${CACHE_MARKER}"
  echo "Updated third-party dependencies."
fi
