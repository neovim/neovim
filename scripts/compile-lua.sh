. scripts/common.sh

lua_dir="$pkgroot/third-party/luajit"

cd "$lua_dir"
make PREFIX="$prefix" install
