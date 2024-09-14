default: check_lua check_lua_spec busted

check_lua:
	luacheck --no-color --no-self --formatter plain --std luajit *.lua --exclude-files '*_spec.lua' 

check_lua_spec:
	luacheck --no-color --formatter plain --std luajit+busted  *_spec.lua

busted:
	busted .
