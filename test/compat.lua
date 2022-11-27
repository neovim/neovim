-- Lua 5.1 forward-compatibility layer.
-- For background see https://github.com/neovim/neovim/pull/9280
--
-- Reference the lua-compat-5.2 project for hints:
--    https://github.com/keplerproject/lua-compat-5.2/blob/c164c8f339b95451b572d6b4b4d11e944dc7169d/compat52/mstrict.lua
--    https://github.com/keplerproject/lua-compat-5.2/blob/c164c8f339b95451b572d6b4b4d11e944dc7169d/tests/test.lua

local lua_version = _VERSION:sub(-3)

if lua_version >= '5.2' then
  unpack = table.unpack -- luacheck: ignore 121 143
end
