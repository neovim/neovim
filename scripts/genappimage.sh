#!/bin/bash -e

########################################################################
# Package the binaries built as an AppImage
# By Simon Peter 2016
# For more information, see http://appimage.org/
########################################################################

# App arch, used by generate_appimage.
if [ -z "$ARCH" ]; then
  ARCH="$(arch)"
  export ARCH
fi
ARCH_ORIGINAL=$ARCH

TAG=$1

# App name, used by generate_appimage.
APP=nvim

ROOT_DIR="$(git rev-parse --show-toplevel)"
APP_BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$APP.AppDir"

########################################################################
# Compile nvim and install it into AppDir
########################################################################

# Build and install nvim into the AppImage
make CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
cmake --install build --prefix="$APP_BUILD_DIR/${APP_DIR}/usr"

########################################################################
# Get helper functions and move to AppDir
########################################################################

# App version, used by generate_appimage.
VERSION=$("$ROOT_DIR"/build/bin/nvim --version | head -n 1 | grep -o 'v.*')
export VERSION

cd "$APP_BUILD_DIR" || exit

# Only downloads linuxdeploy if the remote file is different from local
if [ -e "$APP_BUILD_DIR"/linuxdeploy-"$ARCH".AppImage ]; then
  curl -Lo "$APP_BUILD_DIR"/linuxdeploy-"$ARCH".AppImage \
    -z "$APP_BUILD_DIR"/linuxdeploy-"$ARCH".AppImage \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage  
else
  curl -Lo "$APP_BUILD_DIR"/linuxdeploy-"$ARCH".AppImage \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage
fi

chmod +x "$APP_BUILD_DIR"/linuxdeploy-"$ARCH".AppImage

# metainfo is not packaged automatically by linuxdeploy
mkdir -p "$APP_DIR/usr/share/metainfo/"
cp "$ROOT_DIR/runtime/nvim.appdata.xml" "$APP_DIR/usr/share/metainfo/"

cd "$APP_DIR" || exit

########################################################################
# AppDir complete. Now package it as an AppImage.
########################################################################

# Appimage set the ARGV0 environment variable. This causes problems in zsh.
# To prevent this, we use wrapper script to unset ARGV0 as AppRun.
# See https://github.com/AppImage/AppImageKit/issues/852
#
cat << 'EOF' > AppRun
#!/bin/bash

unset ARGV0
exec "$(dirname "$(readlink  -f "${0}")")/usr/bin/nvim" ${@+"$@"}
EOF
chmod 755 AppRun

cd "$APP_BUILD_DIR" || exit # Get out of AppImage directory.

# We want to be consistent, so always use arm64 over aarch64
if [[ "$ARCH" == 'aarch64' ]]; then
  ARCH="arm64"
  export ARCH
fi

# Set the name of the file generated by appimage
export OUTPUT=nvim-linux-"$ARCH".appimage

# If it's a release generate the zsync file
if [ -n "$TAG" ]; then
  export UPDATE_INFORMATION="gh-releases-zsync|neovim|neovim|$TAG|nvim-linux-$ARCH.appimage.zsync"
fi

# Generate AppImage.
#   - Expects: $ARCH, $APP, $VERSION env vars
#   - Expects: ./$APP.AppDir/ directory
#   - Produces: ./nvim-linux-$ARCH.appimage
./linuxdeploy-"$ARCH_ORIGINAL".AppImage --appdir $APP.AppDir -d "$ROOT_DIR"/runtime/nvim.desktop -i \
"$ROOT_DIR/runtime/nvim.png" --output appimage

# Moving the final executable to a different folder so it isn't in the
# way for a subsequent build.

mv "$ROOT_DIR"/build/nvim-linux-"$ARCH".appimage* "$ROOT_DIR"/build/bin

echo 'genappimage.sh: finished'
