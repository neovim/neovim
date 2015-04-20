. "$CI_SCRIPTS/common.sh"

CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON \
	-DCMAKE_SYSTEM_PROCESSOR=i386 \
	-DCMAKE_SYSTEM_LIBRARY_PATH=/lib32:/usr/lib32:/usr/local/lib32 \
	-DFIND_LIBRARY_USE_LIB64_PATHS=OFF \
	-DCMAKE_IGNORE_PATH=/lib:/usr/lib:/usr/local/lib \
	-DCMAKE_TOOLCHAIN_FILE=$TRAVIS_BUILD_DIR/cmake/i386-linux-gnu.toolchain.cmake \
	-DBUSTED_OUTPUT_TYPE=plainTerminal"

# Build and output version info.
$MAKE_CMD DEPS_CMAKE_FLAGS="$CMAKE_EXTRA_FLAGS" \
	CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS" nvim
build/bin/nvim --version

# Build library.
$MAKE_CMD CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS" libnvim

# Run unittests.
$MAKE_CMD unittest

# Run functional tests.
$MAKE_CMD test
check_core_dumps

# Run legacy tests.
$MAKE_CMD oldtest
check_core_dumps

# Test if correctly installed.
$MAKE_CMD DESTDIR="$HOME/neovim-install" install
$HOME/neovim-install/usr/local/bin/nvim --version
$HOME/neovim-install/usr/local/bin/nvim -e -c "quit"
