. "$CI_SCRIPTS/common.sh"

sudo pip install cpp-coveralls

if [ "$TRAVIS_OS_NAME" = "linux" ]; then
	sudo apt-get install valgrind
	export VALGRIND=1
	export VALGRIND_LOG="$tmpdir/valgrind-%p.log"
fi

setup_deps x64

CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON \
	-DUSE_GCOV=ON \
	-DBUSTED_OUTPUT_TYPE=plainTerminal"

# Build and output version info.
$MAKE_CMD CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS" nvim
build/bin/nvim --version

# Build library.
$MAKE_CMD CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS" libnvim

# Run unittests.
make unittest

# Run functional tests.
if ! $MAKE_CMD test; then
	valgrind_check "$tmpdir"
	exit 1
fi
valgrind_check "$tmpdir"

# Run legacy tests.
if ! $MAKE_CMD oldtest; then
	valgrind_check "$tmpdir"
	exit 1
fi
valgrind_check "$tmpdir"

coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'
