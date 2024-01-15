#!/bin/bash -e
shopt -s extglob

readonly temp_dir="$(mktemp -d)"

# macOS Monterey, v12, is the earliest macOS version with bottles in brew.
# See https://github.com/Homebrew/homebrew-core/blob/master/Formula/g/gettext.rb
readonly arm64_bottle="arm64_monterey"
readonly x86_64_bottle="monterey"
readonly MACOSX_DEPLOYMENT_TARGET="12"

prepare_universal_libintl() {
  # We assume that we're in the project root already.
  declare -r gettext_version="$(brew info gettext --json | jq -r ".[0].versions.stable")"

  echo "Using gettext bottles from brew: ${arm64_bottle} for ARM and ${x86_64_bottle} for Intel"
  echo "Using temp dir: ${temp_dir}"

  brew fetch --bottle-tag="${arm64_bottle}" gettext
  brew fetch --bottle-tag="${x86_64_bottle}" gettext

  pushd "${temp_dir}" >/dev/null
    mkdir "${arm64_bottle}"
    pushd "${arm64_bottle}" >/dev/null
      tar xf "$(brew --cache)"/**/*--gettext--${gettext_version}.${arm64_bottle}*.tar.gz
    popd >/dev/null

    mkdir "${x86_64_bottle}"
    pushd "${x86_64_bottle}" >/dev/null
      tar xf "$(brew --cache)"/**/*--gettext--${gettext_version}.${x86_64_bottle}*.tar.gz
    popd >/dev/null

    mkdir universal
    cp -r "${arm64_bottle}/gettext/${gettext_version}/include" ./universal/
    mkdir universal/lib
    lipo "${arm64_bottle}/gettext/${gettext_version}/lib/libintl.a" "${x86_64_bottle}/gettext/${gettext_version}/lib/libintl.a" -create -output ./universal/lib/libintl.a

    echo "Prepared universal libintl in ${temp_dir}/universal"
  popd >/dev/null
}

prepare_universal_libintl

cmake -S cmake.deps -B .deps -G Ninja \
  -D CMAKE_BUILD_TYPE=${NVIM_BUILD_TYPE} \
  -D CMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
  -D CMAKE_OSX_ARCHITECTURES=arm64\;x86_64 \
  -D CMAKE_FIND_FRAMEWORK=NEVER
cmake --build .deps
cmake -B build -G Ninja \
  -D CMAKE_BUILD_TYPE=${NVIM_BUILD_TYPE} \
  -D CMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
  -D CMAKE_OSX_ARCHITECTURES=arm64\;x86_64 \
  -D LIBINTL_INCLUDE_DIR="${temp_dir}/universal/include" \
  -D LIBINTL_LIBRARY="${temp_dir}/universal/lib/libintl.a" \
  -D CMAKE_FIND_FRAMEWORK=LAST
cmake --build build
# Make sure we build everything for M1 as well
for macho in build/bin/* build/lib/nvim/parser/*.so; do
  lipo -info "$macho" | grep -q arm64 || exit 1
done
cpack --config build/CPackConfig.cmake
