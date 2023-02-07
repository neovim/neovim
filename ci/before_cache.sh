#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/suite.sh"

mkdir -p "${HOME}/.cache"

echo "before_cache.sh: cache size"
du -chd 1 "${HOME}/.cache" | sort -rh | head -20

# Update the third-party dependency cache only if the build was successful.
if ended_successfully && [ -d "${DEPS_BUILD_DIR}" ]; then
  # Do not cache downloads.  They should not be needed with up-to-date deps.
  rm -rf "${DEPS_BUILD_DIR}/build/downloads"
  rm -rf "${CACHE_NVIM_DEPS_DIR}"
  mv "${DEPS_BUILD_DIR}" "${CACHE_NVIM_DEPS_DIR}"

  touch "${CACHE_MARKER}"
  echo "Updated third-party dependencies."
fi
