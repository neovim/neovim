. scripts/common.sh

uv_dir="third-party/libuv"

cd "$uv_dir"
sh autogen.sh
./configure --prefix="$prefix" --with-pic
make
make install
rm "$prefix/lib/"libuv*.{so,dylib} "$prefix/lib/"libuv*.{so,dylib}.* || true
