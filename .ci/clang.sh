. "$CI_SCRIPTS/common.sh"

sudo pip install cpp-coveralls

# Use custom Clang and enable sanitizers on Linux.
if [ "$TRAVIS_OS_NAME" = "linux" ]; then
	if [ -z "$CLANG_SANITIZER" ]; then
		echo "CLANG_SANITIZER not set."
		exit 1
	fi

	clang_version=3.6
	echo "Installing Clang $clang_version..."

	sudo add-apt-repository "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu precise main"
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys BA9EF27F

	sudo add-apt-repository "deb http://llvm.org/apt/precise/ llvm-toolchain-precise-$clang_version main"
	wget -q -O - http://llvm.org/apt/llvm-snapshot.gpg.key | sudo apt-key add -

	sudo apt-get update -qq
	sudo apt-get install -y -q clang-$clang_version

	export CC=/usr/bin/clang-$clang_version
	symbolizer=/usr/bin/llvm-symbolizer-$clang_version
	export ASAN_SYMBOLIZER_PATH=$symbolizer
	export MSAN_SYMBOLIZER_PATH=$symbolizer
	export ASAN_OPTIONS="detect_leaks=1:log_path=$tmpdir/asan"
	export TSAN_OPTIONS="external_symbolizer_path=$symbolizer log_path=$tmpdir/tsan"
	export UBSAN_OPTIONS="log_path=$tmpdir/ubsan" # not sure if this works
	CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON \
		-DUSE_GCOV=ON \
		-DBUSTED_OUTPUT_TYPE=plainTerminal \
		-DCLANG_${CLANG_SANITIZER}=ON"
else
	CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON \
		-DUSE_GCOV=ON \
		-DBUSTED_OUTPUT_TYPE=plainTerminal"
fi

setup_deps x64

# Build and output version info.
$MAKE_CMD CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS" nvim
build/bin/nvim --version

# Run unittests.
make unittest

# Run functional tests.
# FIXME (fwalch): Disabled for MSAN because of SIGPIPE error.
if [ "$TRAVIS_OS_NAME" = linux ] && ! [ "$CLANG_SANITIZER" = MSAN ]; then
	if ! $MAKE_CMD test; then
		asan_check "$tmpdir"
		exit 1
	fi
	asan_check "$tmpdir"
fi

# Run legacy tests.
if ! $MAKE_CMD oldtest; then
	reset
	asan_check "$tmpdir"
	exit 1
fi
asan_check "$tmpdir"

coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'

# Test if correctly installed.
sudo -E $MAKE_CMD install
/usr/local/bin/nvim --version
/usr/local/bin/nvim -e -c "quit"
