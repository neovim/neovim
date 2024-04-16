#pragma once

#include <lua.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep

#define nlua_pop_Buffer nlua_pop_handle
#define nlua_pop_Window nlua_pop_handle
#define nlua_pop_Tabpage nlua_pop_handle

/// Flags for nlua_push_*() functions.
enum {
  kNluaPushSpecial = 0x01,   ///< Use lua-special-tbl when necessary
  kNluaPushFreeRefs = 0x02,  ///< Free luarefs to elide an api_luarefs_free_*() later
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/converter.h.generated.h"
#endif
