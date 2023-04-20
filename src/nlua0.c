#include <lua.h>

#include "mpack/lmpack.h"

LUA_API int luaopen_nlua0(lua_State* L);

LUA_API int luaopen_nlua0(lua_State* L) {
  lua_getglobal(L, "vim");
  luaopen_mpack(L);
  lua_setfield(L, -2, "mpack");

  return 1;
}
