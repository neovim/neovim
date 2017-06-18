#!/bin/bash

########################################################################
# Package the binaries built as an AppImage
# By Simon Peter 2016
# For more information, see http://appimage.org/
########################################################################

# App arch, used by generate_appimage.
if [ -z "$ARCH" ]; then
  export ARCH="$(arch)"
fi

# App name, used by generate_appimage.
APP=nvim

ROOT_DIR="$(git rev-parse --show-toplevel)"
APP_BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$APP.AppDir"

########################################################################
# Compile nvim and install it into AppDir
########################################################################

# Build and install nvim into the AppImage
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=${APP_DIR}/usr -DCMAKE_INSTALL_MANDIR=man"
make install

########################################################################
# Get helper functions and move to AppDir
########################################################################

# App version, used by generate_appimage.
VERSION=$("$ROOT_DIR"/build/bin/nvim --version | head -n 1 | grep -o 'v.*')

cd "$APP_BUILD_DIR"

curl -Lo "$APP_BUILD_DIR"/appimage_functions.sh https://github.com/probonopd/AppImages/raw/master/functions.sh
. ./appimage_functions.sh

# Copy desktop and icon file to AppDir for AppRun to pick them up.
# get_apprun
# get_desktop
cp "$ROOT_DIR/runtime/nvim.desktop" "$APP_DIR/"
cp "$ROOT_DIR/runtime/nvim.png" "$APP_DIR/"

cd "$APP_DIR"

# copy dependencies
copy_deps
# Move the libraries to usr/bin
move_lib

# Delete stuff that should not go into the AppImage.
# Delete dangerous libraries; see
# https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted

########################################################################
# AppDir complete. Now package it as an AppImage.
########################################################################

# No need for a fancy script. AppRun can just be a symlink to nvim.
ln -s usr/bin/nvim AppRun

cd "$APP_BUILD_DIR" # Get out of AppImage directory.

# Generate AppImage.
#   - Expects: $ARCH, $APP, $VERSION env vars
#   - Expects: ./$APP.AppDir/ directory
#   - Produces: ../out/$APP-$VERSION.glibc$GLIBC_NEEDED-$ARCH.AppImage
generate_appimage

# NOTE: There is currently a bug in the `generate_appimage` function (see
# https://github.com/probonopd/AppImages/issues/228) that causes repeated builds
# that result in the same name to fail.
# Moving the final executable to a different folder gets around this issue.

mv "$ROOT_DIR"/out/*.AppImage "$ROOT_DIR"/build/bin
# Remove the (now empty) folder the AppImage was built in
rmdir "$ROOT_DIR"/out

echo 'genappimage.sh: finished'
