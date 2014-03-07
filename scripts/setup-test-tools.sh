. scripts/common.sh

luarocks_ver=v2.1.2
luarocks_repo=keplerproject/luarocks
luarocks_sha1=69ea9b641a5066b1f316847494d8c63a4693977d
luarocks_dir="$pkgroot/third-party/luarocks"

github_download "$luarocks_repo" "$luarocks_ver" "$luarocks_dir" \
	"$luarocks_sha1"

cd "$luarocks_dir"

./configure --prefix="$prefix" --force-config --with-lua="$prefix" \
	--with-lua-include="$prefix/include/luajit-2.0" \
	--lua-suffix="jit"

make bootstrap

echo 'rocks_servers = {
   "http://luarocks.giga.puc-rio.br/";
}' >> "$prefix/etc/luarocks/config-5.1.lua"

# install tools for testing
luarocks install moonrocks --server=http://rocks.moonscript.org
moonrocks install moonscript
moonrocks install busted
