. "$CI_SCRIPTS/common.sh"

set_environment /opt/neovim-deps/64

sudo apt-get install expect valgrind

$MAKE_CMD

git clone --depth=1 -b master git://github.com/neovim/python-client
cd python-client
sudo pip install .
sudo pip install nose
# We run the tests twice:
# - First by connecting with an nvim instance spawned by "expect"
# - Second by starting nvim in embedded mode through the python client
# This is required until nvim is mature enough to always run in embedded mode
test_cmd="nosetests --verbosity=2 --nologcapture"
nvim_cmd="valgrind -q --track-origins=yes --leak-check=yes --suppressions=$suppressions --log-file=$tmpdir/valgrind-%p.log ../build/bin/nvim -u NONE"
if ! ../scripts/run-api-tests.exp "$test_cmd" "$nvim_cmd"; then
	valgrind_check "$tmpdir"
	exit 1
fi

valgrind_check "$tmpdir"

export NVIM_SPAWN_ARGV="[\"valgrind\", \"-q\", \"--track-origins=yes\", \"--leak-check=yes\", \"--suppressions=$suppressions\", \"--log-file=$tmpdir/valgrind-%p.log\", \"../build/bin/nvim\", \"-u\", \"NONE\", \"--embed\"]"
if ! nosetests --verbosity=2 --nologcapture; then
	valgrind_check "$tmpdir"
	exit 1
fi

valgrind_check "$tmpdir"
