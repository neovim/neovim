. "$CI_SCRIPTS/common.sh"

# To install lupa, a temporarary functional test dependency, we require the
# 64-bit luajit since travis version of python is 64-bit.
export PKG_CONFIG_PATH="/opt/neovim-deps/64/usr/lib/pkgconfig"
install_functional_test_deps

set_environment /opt/neovim-deps/32

# Need this to keep apt-get from removing gcc when installing libncurses
# below.
sudo apt-get install libc6-dev libc6-dev:i386

# Do this separately so that things get configured correctly, otherwise
# libncurses fails to install.
sudo apt-get install gcc-multilib g++-multilib

# Install the dev version to get the pkg-config and symlinks installed
# correctly.
sudo apt-get install libncurses5-dev:i386

CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON \
	-DCMAKE_SYSTEM_PROCESSOR=i386 \
	-DCMAKE_SYSTEM_LIBRARY_PATH=/lib32:/usr/lib32:/usr/local/lib32 \
	-DFIND_LIBRARY_USE_LIB64_PATHS=OFF \
	-DCMAKE_IGNORE_PATH=/lib:/usr/lib:/usr/local/lib \
	-DCMAKE_TOOLCHAIN_FILE=cmake/i386-linux-gnu.toolchain.cmake"

$MAKE_CMD CMAKE_EXTRA_FLAGS="${CMAKE_EXTRA_FLAGS}" unittest
$MAKE_CMD test
$MAKE_CMD oldtest
