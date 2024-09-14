#!/bin/bash
hererocks env -j 2.0.4 -r 2.4
source env/bin/activate
luarocks install luv
luarocks install mpack
luarocks install busted
luarocks install luacheck
luarocks install lua-cjson
luarocks install inspect
