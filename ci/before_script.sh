#!/usr/bin/env bash

set -e
set -o pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "${CI_DIR}/common/build.sh"

if test "${FUNCTIONALTEST}" = "functionaltest-lua" \
   || test "${CLANG_SANITIZER}" = "ASAN_UBSAN" ; then
  DEPS_CMAKE_FLAGS="${DEPS_CMAKE_FLAGS} -DUSE_BUNDLED_LUA=ON"
fi

mkdir -p "${DEPS_BUILD_DIR}"

# Use cached dependencies if $CACHE_MARKER exists.
if test -f "${CACHE_MARKER}"; then
  echo "Using third-party dependencies from cache."
  cp -a "${CACHE_NVIM_DEPS_DIR}"/. "${DEPS_BUILD_DIR}"
fi

make deps CMAKE_FLAGS="$DEPS_CMAKE_FLAGS"

rm -rf "${LOG_DIR}"
mkdir -p "${LOG_DIR}"
