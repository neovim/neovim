#!/bin/bash -e

echo "Provision universal libintl"
GETTEXT_PREFIX="$(brew --prefix gettext)"
printf 'GETTEXT_PREFIX=%s\n' "$GETTEXT_PREFIX" >> $GITHUB_ENV
bottle_tag="arm64_big_sur"
brew fetch --bottle-tag="$bottle_tag" gettext
cd "$(mktemp -d)"
tar xf "$(brew --cache)"/**/*gettext*${bottle_tag}*.tar.gz
lipo gettext/*/lib/libintl.a "${GETTEXT_PREFIX}/lib/libintl.a" -create -output libintl.a
mv -f libintl.a /usr/local/lib/

echo "Ensure static linkage to libintl"
# We're about to mangle `gettext`, so let's remove any potentially broken
# installs (e.g. curl, git) as those could interfere with our build.
brew uninstall $(brew uses --installed --recursive gettext)
brew unlink gettext
ln -sf "$(brew --prefix)/opt/$(readlink "${GETTEXT_PREFIX}")/bin"/* /usr/local/bin/
ln -sf "$(brew --prefix)/opt/$(readlink "${GETTEXT_PREFIX}")/include"/* /usr/local/include/
rm -f "$GETTEXT_PREFIX"

echo "Build release"
cd "$GITHUB_WORKSPACE"
MACOSX_DEPLOYMENT_TARGET="$(sw_vers -productVersion | cut -f1 -d.)"
export MACOSX_DEPLOYMENT_TARGET
cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=${NVIM_BUILD_TYPE} -D CMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} -D CMAKE_OSX_ARCHITECTURES=arm64\;x86_64
cmake --build .deps
cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=${NVIM_BUILD_TYPE} -D CMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} -D CMAKE_OSX_ARCHITECTURES=arm64\;x86_64 -D CI_BUILD=OFF
cmake --build build
cmake --install build --prefix build/release/nvim-macos
cd build
# Make sure we build everything for M1 as well
for macho in bin/* lib/nvim/parser/*.so; do
  lipo -info "$macho" | grep -q arm64 || exit 1
done
cpack -C "$NVIM_BUILD_TYPE"
