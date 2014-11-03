. "$CI_SCRIPTS/common.sh"

set_environment /opt/neovim-deps/64

sudo pip install cpp-coveralls

sudo apt-get install valgrind

export VALGRIND=1
export VALGRIND_LOG="$tmpdir/valgrind-%p.log"
CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON -DUSE_GCOV=ON"

$MAKE_CMD CMAKE_EXTRA_FLAGS="${CMAKE_EXTRA_FLAGS}" unittest
build/bin/nvim --version
if ! $MAKE_CMD test; then
	valgrind_check "$tmpdir"
	exit 1
fi
valgrind_check "$tmpdir"

if ! $MAKE_CMD oldtest; then
	valgrind_check "$tmpdir"
	exit 1
fi
valgrind_check "$tmpdir"

coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'
