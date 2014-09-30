. "$CI_SCRIPTS/common.sh"

set_environment /opt/neovim-deps/64

install_functional_test_deps

sudo pip install cpp-coveralls

sudo apt-get install valgrind

export VALGRIND=1
export VALGRIND_LOG="$tmpdir/valgrind-%p.log"
CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON -DUSE_GCOV=ON"

$MAKE_CMD CMAKE_EXTRA_FLAGS="${CMAKE_EXTRA_FLAGS}" unittest
$MAKE_CMD test
valgrind_check "$tmpdir"
$MAKE_CMD oldtest

coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'
