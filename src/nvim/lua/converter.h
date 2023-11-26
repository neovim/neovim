#pragma once

#include <lua.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep

#define nlua_pop_Buffer nlua_pop_handle
#define nlua_pop_Window nlua_pop_handle
#define nlua_pop_Tabpage nlua_pop_handle

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/converter.h.generated.h"
#endif
