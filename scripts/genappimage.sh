#!/bin/sh

########################################################################
# Package the baries built on Travis-CI as an AppImage
# By Simon Peter 2016
# For more information, see http://appimage.org/
########################################################################

if [ -z "$ARCH" ]; then
  export ARCH="$(arch)"
fi

APP=NeoVim
ROOT_DIR="$(git rev-parse --show-toplevel)"
APP_BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$APP_BUILD_DIR/$APP.AppDir"

GIT_REV="$(git rev-parse --short HEAD)"

# Get the version string of nvim
VIM_VER="$("$ROOT_DIR"/build/bin/nvim --version | head -n 1 | grep -o 'v.*')"
# Get the date of the latest commit
COMMIT_DATE="$(git show --no-patch --date='short' --format='%cd')"


# make deps
# Install runtime files and nvim binary into the AppImage
make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=${APP_DIR}/usr"
make install

# Move runtime from /usr/local to /usr
mv "$APP_DIR"/usr/local/* "$APP_DIR/usr/"

cd "$APP_BUILD_DIR"

curl -Lo "$APP_BUILD_DIR"/appimage_functions.sh https://github.com/probonopd/AppImages/raw/master/functions.sh
. ./appimage_functions.sh

cd "$APP".AppDir

# # Also needs grep for gvim.wrapper
# cp /bin/grep ./usr/bin
#
# # install additional dependencies for python
# # this makes the image too big, so skip it
# # and depend on the host where the image is run to fulfill those dependencies
#
# #URL=$(apt-get install -qq --yes --no-download --reinstall --print-uris libpython2.7 libpython3.2 libperl5.14 liblua5.1-0 libruby1.9.1| cut -d' ' -f1 | tr -d "'")
# #wget -c $URL
# #for package in *.deb; do
# #    dpkg -x $package .
# #done
# #rm -f *.deb


########################################################################
# Copy desktop and icon file to AppDir for AppRun to pick them up
########################################################################

# Download AppRun and make it executable
#get_apprun

# get_desktop

cp "$ROOT_DIR"/runtime/nvim.desktop "$APP_DIR"

cp "$ROOT_DIR"/runtime/nvim.png "$APP_DIR"

# mkdir -p ./usr/lib/x86_64-linux-gnu
# copy custom libruby.so 1.9
# find "$HOME/.rvm/" -name "libruby.so.1.9" -xdev -exec cp {} ./usr/lib/x86_64-linux-gnu/ \; || true
# add libncurses5
# find /lib -name "libncurses.so.5" -xdev -exec cp -v -rfL {} ./usr/lib/x86_64-linux-gnu/ \; || true

# copy dependencies
copy_deps

# Move the libraries to usr/bin
move_lib

########################################################################
# Delete stuff that should not go into the AppImage
########################################################################

# if those libraries are present, there will be a pango problem
# find . -name "libpango*" -delete
# find . -name "libfreetype*" -delete
# find . -name "libX*" -delete

# Delete dangerous libraries; see
# https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted

########################################################################
# desktopintegration asks the user on first run to install a menu item
########################################################################

# get_desktopintegration "$LOWERAPP"

########################################################################
# Determine the version of the app; For use in file filename
########################################################################

VERSION="Nightly-$COMMIT_DATE-$VIM_VER"

########################################################################
########################################################################
# Patch away absolute paths; it would be nice if they were relative
########################################################################

# patch_strings_in_file "$APP_DIR"/usr/bin/nvim '/usr/local/nvim' '$APPDIR/usr/nvim'

# remove unneeded stuff
# rmdir ./usr/lib64 || true
# rm -rf ./usr/bin/*tutor* || true
# rm -rf ./usr/share/doc || true
#rm -rf ./usr/bin/vim || true
# remove unneded links
# find ./usr/bin -type l \! -name "gvim" -delete || true

########################################################################
# AppDir complete
# Now packaging it as an AppImage
########################################################################


cd "$APP_DIR"
# No need for a fancy script. AppRun can just be a symlink to nvim.
ln -s ./usr/bin/nvim AppRun
cd -

cd .. # Go out of AppImage

# Build the AppImage executable.
# Name format is"NeoVim-Nightly-${COMMIT_DATE}-${NEOVIM_VERSION}-glibc${GLIBC_VERSION}-${ARCHITECTURE}.AppImage"
generate_appimage

mv "$ROOT_DIR"/out/*.AppImage "$ROOT_DIR"/build/bin
# Remove the (now empty) folder the AppImage was built in
rm -r "$ROOT_DIR"/out
# cp ../out/*.AppImage "$TRAVIS_BUILD_DIR"

########################################################################
# Upload the AppDir
########################################################################

#transfer ../out/*
