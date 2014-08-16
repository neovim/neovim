. "$CI_SCRIPTS/common.sh"

install_vroom

set_environment /opt/neovim-deps

sudo pip install cpp-coveralls

clang_version=3.4
if [ ! -d /usr/local/clang-$clang_version ]; then
	echo "Downloading clang $clang_version..."
	sudo mkdir /usr/local/clang-$clang_version
	wget -q -O - http://llvm.org/releases/$clang_version/clang+llvm-$clang_version-x86_64-unknown-ubuntu12.04.xz \
		| sudo tar xJf - --strip-components=1 -C /usr/local/clang-$clang_version
fi
export CC=/usr/local/clang-$clang_version/bin/clang
symbolizer=/usr/local/clang-$clang_version/bin/llvm-symbolizer

export SANITIZE=1
export ASAN_SYMBOLIZER_PATH=$symbolizer
export ASAN_OPTIONS="detect_leaks=1:log_path=$tmpdir/asan"
export TSAN_OPTIONS="external_symbolizer_path=$symbolizer:log_path=$tmpdir/tsan"

export SKIP_UNITTEST=1
export UBSAN_OPTIONS="log_path=$tmpdir/ubsan" # not sure if this works

install_dir="$(pwd)/dist"
$MAKE_CMD cmake CMAKE_EXTRA_FLAGS="-DTRAVIS_CI_BUILD=ON -DCMAKE_INSTALL_PREFIX=$install_dir -DUSE_GCOV=ON"
$MAKE_CMD
if ! $MAKE_CMD test; then
	reset
	asan_check "$tmpdir"
	exit 1
fi

asan_check "$tmpdir"
coveralls --encoding iso-8859-1 || echo 'coveralls upload failed.'

$MAKE_CMD install
