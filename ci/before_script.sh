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
  echo "Using third-party dependencies from cache (last update: $(_stat "${CACHE_MARKER}"))."
  cp -a "${CACHE_NVIM_DEPS_DIR}"/. "${DEPS_BUILD_DIR}"
fi

# Even if we're using cached dependencies, run CMake and make to
# update CMake configuration and update to newer deps versions.
cd "${DEPS_BUILD_DIR}"
# shellcheck disable=SC2086
cmake -G Ninja ${DEPS_CMAKE_FLAGS} "${CI_BUILD_DIR}/cmake.deps/"

if ! ninja; then
  exit 1
fi

cd "${CI_BUILD_DIR}"

rm -rf "${LOG_DIR}"
mkdir -p "${LOG_DIR}"
