#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CI_DIR}/common/commands.sh"

# Don't cache pip's log and selfcheck.
rm -rf "${HOME}/.cache/pip/log"
rm -f "${HOME}/.cache/pip/selfcheck.json"

# Update the third-party dependency cache only if the build was successful.
if [[ -f "${SUCCESS_MARKER}" ]]; then
  rm -rf "${HOME}/.cache/nvim-deps"
  mv "${DEPS_BUILD_DIR}" "${HOME}/.cache/nvim-deps"
  touch "${CACHE_MARKER}"
  echo "Updated third-party dependencies (timestamp: $(statcmd "${CACHE_MARKER}"))."
fi
