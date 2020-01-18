#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

echo "before_cache.sh: cache size"
du -chd 1 "${HOME}/.cache" | sort -rh | head -20

echo "before_cache.sh: ccache stats"
ccache -s 2>/dev/null || true
# Do not keep ccache stats (uploaded to cache otherwise; reset initially anyway).
find "${HOME}/.ccache" -name stats -delete

# Update the third-party dependency cache only if the build was successful.
if ended_successfully; then
  # Do not cache downloads.  They should not be needed with up-to-date deps.
  rm -rf "${DEPS_BUILD_DIR}/build/downloads"
  rm -rf "${CACHE_NVIM_DEPS_DIR}"
  mv "${DEPS_BUILD_DIR}" "${CACHE_NVIM_DEPS_DIR}"

  touch "${CACHE_MARKER}"
  echo "Updated third-party dependencies (timestamp: $(_stat "${CACHE_MARKER}"))."
fi
