. "$CI_SCRIPTS/common.sh"

sudo pip install cpp-coveralls

if [ "$TRAVIS_OS_NAME" = "linux" ]; then
	clang_version=3.4.2
	clang_suffix=x86_64-unknown-ubuntu12.04.xz
elif [ "$TRAVIS_OS_NAME" = "osx" ]; then
	clang_version=3.5.0
	clang_suffix=macosx-apple-darwin.tar.xz
else
	echo "Unknown OS '$TRAVIS_OS_NAME'."
	exit 1
fi

if [ ! -d /usr/local/clang-$clang_version ]; then
	echo "Downloading clang $clang_version..."
	sudo mkdir /usr/local/clang-$clang_version
	wget -q -O - http://llvm.org/releases/$clang_version/clang+llvm-$clang_version-$clang_suffix \
		| sudo tar xJf - --strip-components=1 -C /usr/local/clang-$clang_version
fi

export CC=/usr/local/clang-$clang_version/bin/clang
symbolizer=/usr/local/clang-$clang_version/bin/llvm-symbolizer

setup_deps x64

export ASAN_SYMBOLIZER_PATH=$symbolizer
export ASAN_OPTIONS="detect_leaks=1:log_path=$tmpdir/asan"
export TSAN_OPTIONS="external_symbolizer_path=$symbolizer:log_path=$tmpdir/tsan"

export UBSAN_OPTIONS="log_path=$tmpdir/ubsan" # not sure if this works

CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON \
	-DUSE_GCOV=ON \
	-DBUSTED_OUTPUT_TYPE=plainTerminal"

# Build and output version info.
$MAKE_CMD CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DSANITIZE=ON" nvim
build/bin/nvim --version

# Run functional tests.
if ! $MAKE_CMD test; then
	asan_check "$tmpdir"
	exit 1
fi
asan_check "$tmpdir"

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
