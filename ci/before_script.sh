#!/usr/bin/env bash

set -e
set -o pipefail

# Test some of the configuration variables.
if [[ -n "${GCOV}" ]] && [[ ! $(type -P "${GCOV}") ]]; then
  echo "\$GCOV: '${GCOV}' is not executable."
  exit 1
fi

if test "${FUNCTIONALTEST}" = "functionaltest-lua" ; then
  DEPS_CMAKE_FLAGS="${DEPS_CMAKE_FLAGS} -D USE_BUNDLED_LUA=ON"
fi

mkdir -p "${DEPS_BUILD_DIR}"
cd "${DEPS_BUILD_DIR}"
echo "Configuring with '${DEPS_CMAKE_FLAGS}'."
# shellcheck disable=SC2086
cmake -G Ninja ${DEPS_CMAKE_FLAGS} "${CI_BUILD_DIR}/cmake.deps/"

ninja || exit 1

cd "${CI_BUILD_DIR}"

# Install cluacov for Lua coverage.
if [[ "$USE_LUACOV" == 1 ]]; then
  "${DEPS_BUILD_DIR}/usr/bin/luarocks" install cluacov
fi

rm -rf "${LOG_DIR}"
mkdir -p "${LOG_DIR}"
