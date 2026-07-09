#pragma once

#include <lua.h>  // IWYU pragma: keep
#include <stdbool.h>

int nlua_with_internal_sctx(lua_State *L);

#include "lua/stdlib.h.generated.h"
