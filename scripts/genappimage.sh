#!/bin/sh

########################################################################
# Package the binaries built as an AppImage
# By Simon Peter 2016
# For more information, see http://appimage.org/
########################################################################

if [ -z "$ARCH" ]; then
  export ARCH="$(arch)"
fi

APP=Neovim
ROOT_DIR="$(git rev-parse --show-toplevel)"
APP_BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$APP_BUILD_DIR/$APP.AppDir"

GIT_REV="$(git rev-parse --short HEAD)"

# Get the version string of nvim
VIM_VER="$("$ROOT_DIR"/build/bin/nvim --version | head -n 1 | grep -o 'v.*')"
# Get the date of the latest commit
COMMIT_DATE="$(git show --no-patch --date='short' --format='%cd')"

########################################################################
# Compile Neovim and install it into AppDir
########################################################################

# make deps

# Install runtime files and nvim binary into the AppImage
make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=${APP_DIR}/usr"

make install

########################################################################
# Get helper functions and move to AppDir
########################################################################

cd "$APP_BUILD_DIR"

curl -Lo "$APP_BUILD_DIR"/appimage_functions.sh https://github.com/probonopd/AppImages/raw/master/functions.sh
. ./appimage_functions.sh

cd "$APP".AppDir

########################################################################
# Copy desktop and icon file to AppDir for AppRun to pick them up
########################################################################

# Download AppRun and make it executable
# get_apprun

# get_desktop

cp "$ROOT_DIR"/runtime/nvim.desktop "$APP_DIR"

cp "$ROOT_DIR"/runtime/nvim.png "$APP_DIR"

# copy dependencies
copy_deps

# Move the libraries to usr/bin
move_lib

########################################################################
# Delete stuff that should not go into the AppImage
########################################################################

# Delete dangerous libraries; see
# https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted

########################################################################
# Determine the version of the app; For use in file filename
########################################################################

VERSION="$COMMIT_DATE-$VIM_VER"

########################################################################
# AppDir complete
# Now packaging it as an AppImage
########################################################################


# No need for a fancy script. AppRun can just be a symlink to nvim.
ln -s usr/bin/nvim "$APP_DIR"/AppRun

cd .. # Go out of AppImage

# Build the AppImage executable.
# Name format is"NeoVim-${COMMIT_DATE}-${NEOVIM_VERSION}-glibc${GLIBC_VERSION}-${ARCHITECTURE}.AppImage"
generate_appimage

# NOTE: There is currently a bug in the `generate_appimage` function (see
# https://github.com/probonopd/AppImages/issues/228) that causes repeate builds
# that result in the same name to fail.
# Moving the final executable to a different folder gets around this issue.

mv "$ROOT_DIR"/out/*.AppImage "$ROOT_DIR"/build/bin
# Remove the (now empty) folder the AppImage was built in
rm -r "$ROOT_DIR"/out
