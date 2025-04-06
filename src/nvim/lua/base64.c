#include <assert.h>
#include <lauxlib.h>
#include <lua.h>
#include <stddef.h>

#include "nvim/base64.h"
#include "nvim/lua/base64.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/base64.c.generated.h"
#endif

static int nlua_base64_encode(lua_State *L)
{
  if (lua_gettop(L) < 1) {
    return luaL_error(L, "Expected 1 argument");
  }

  if (lua_type(L, 1) != LUA_TSTRING) {
    luaL_argerror(L, 1, "expected string");
  }

  size_t src_len = 0;
  const char *src = lua_tolstring(L, 1, &src_len);

  const char *ret = base64_encode(src, src_len);
  assert(ret != NULL);
  lua_pushstring(L, ret);
  xfree((void *)ret);

  return 1;
}

static int nlua_base64_decode(lua_State *L)
{
  if (lua_gettop(L) < 1) {
    return luaL_error(L, "Expected 1 argument");
  }

  if (lua_type(L, 1) != LUA_TSTRING) {
    luaL_argerror(L, 1, "expected string");
  }

  size_t src_len = 0;
  const char *src = lua_tolstring(L, 1, &src_len);

  size_t out_len = 0;
  const char *ret = base64_decode(src, src_len, &out_len);
  if (ret == NULL) {
    return luaL_error(L, "Invalid input");
  }

  lua_pushlstring(L, ret, out_len);
  xfree((void *)ret);

  return 1;
}

static const luaL_Reg base64_functions[] = {
  { "encode", nlua_base64_encode },
  { "decode", nlua_base64_decode },
  { NULL, NULL },
};

int luaopen_base64(lua_State *L)
{
  lua_newtable(L);
  luaL_register(L, NULL, base64_functions);
  return 1;
}
