. "$CI_SCRIPTS/common.sh"

set_environment /opt/neovim-deps/64

install_functional_test_deps

sudo pip install cpp-coveralls

sudo apt-get install valgrind

export VALGRIND=1
export VALGRIND_LOG="$tmpdir/valgrind-%p.log"
mkdir build
cd build
cmake -DTRAVIS_CI_BUILD=ON -DUSE_GCOV=ON
$MAKE_CMD unittest
$MAKE_CMD test
valgrind_check "$tmpdir"
$MAKE_CMD oldtest
cd ..

coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'
