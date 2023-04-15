#include <lua.h>

#ifdef NLUA_WIN32
  __declspec(dllexport)
#endif
int luaopen_mpack(lua_State *L);
