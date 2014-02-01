. scripts/common.sh

uv_repo=joyent/libuv
uv_ver=v0.11.19
uv_dir="$deps/uv-$uv_ver"
uv_sha1=5539d8e99e22b438cf4a412d4cec70ac6bb519fc

rm -rf "$uv_dir"

github_download "$uv_repo" "$uv_ver" "$uv_dir" "$uv_sha1"
cd "$uv_dir"
sh autogen.sh
./configure --prefix="$prefix"
make
make install
rm "$prefix/lib/"libuv*.so "$prefix/lib/"libuv*.so.*
