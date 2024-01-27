#!/bin/bash -e

MACOSX_DEPLOYMENT_TARGET="$(sw_vers -productVersion | cut -f1 -d.)"
export MACOSX_DEPLOYMENT_TARGET
cmake -S cmake.deps -B .deps -G Ninja \
  -D CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
  -D CMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
  -D CMAKE_OSX_ARCHITECTURES=arm64\;x86_64 \
  -D CMAKE_FIND_FRAMEWORK=NEVER
cmake --build .deps
cmake -B build -G Ninja \
  -D CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
  -D CMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
  -D CMAKE_OSX_ARCHITECTURES=arm64\;x86_64 \
  -D ENABLE_LIBINTL=OFF \
  -D CMAKE_FIND_FRAMEWORK=NEVER
cmake --build build
# Make sure we build everything for M1 as well
for macho in build/bin/* build/lib/nvim/parser/*.so; do
  lipo -info "$macho" | grep -q arm64 || exit 1
done
cpack --config build/CPackConfig.cmake
