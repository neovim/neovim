#include "nvim/lua/perf_annotations.h"
#include "nvim/perf_annotations.h"

int nlua_perf_range_push(lua_State *L)
{
  const char *range_name = luaL_checkstring(L, 1);
  perf_range_push(range_name);
  return 0;
}

int nlua_perf_range_pop(lua_State *L)
{
  perf_range_pop();
  return 0;
}

int nlua_perf_event(lua_State *L)
{
  const char *event_name = luaL_checkstring(L, 1);
  perf_range_push(event_name);
  return 0;
}

