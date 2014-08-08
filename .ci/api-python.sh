. "$CI_SCRIPTS/common.sh"

set_environment /opt/neovim-deps

sudo apt-get install expect valgrind

$MAKE_CMD

git clone --depth=1 -b master git://github.com/neovim/python-client
cd python-client
sudo pip install .
sudo pip install nose
test_cmd="nosetests --verbosity=2"
nvim_cmd="valgrind -q --track-origins=yes --leak-check=yes --suppressions=$suppressions --log-file=$tmpdir/valgrind-%p.log ../build/bin/nvim -u NONE"
if ! ../scripts/run-api-tests.exp "$test_cmd" "$nvim_cmd"; then
	valgrind_check "$tmpdir"
	exit 1
fi
valgrind_check "$tmpdir"
