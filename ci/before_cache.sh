#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/build.sh"
source "${CI_DIR}/common/suite.sh"

# Don't cache pip's log and selfcheck.
rm -rf "${HOME}/.cache/pip/log"
rm -f "${HOME}/.cache/pip/selfcheck.json"

echo "before_cache.sh: cache size"
du -d 2 "${HOME}/.cache" | sort -n

echo "before_cache.sh: ccache stats"
ccache -s 2>/dev/null || true

# Update the third-party dependency cache only if the build was successful.
if ended_successfully; then
  rm -rf "${HOME}/.cache/nvim-deps"
  mv "${DEPS_BUILD_DIR}" "${HOME}/.cache/nvim-deps"

  rm -rf "${HOME}/.cache/nvim-deps-downloads"
  mv "${DEPS_DOWNLOAD_DIR}" "${HOME}/.cache/nvim-deps-downloads"

  touch "${CACHE_MARKER}"
  echo "Updated third-party dependencies (timestamp: $(_stat "${CACHE_MARKER}"))."
fi
