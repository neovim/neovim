#ifndef CJSON_LUACJSON_H
#define CJSON_LUACJSON_H

#include "lua.h"

int lua_cjson_new(lua_State *l);
int luaopen_cjson(lua_State *l);
int luaopen_cjson_safe(lua_State *l);

#endif  // CJSON_LUACJSON_H
