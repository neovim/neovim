#pragma once

#include <lua.h>  // IWYU pragma: keep
#include <stdint.h>

#include "nvim/macros_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/treesitter.h.generated.h"
#endif

EXTERN uint64_t tslua_query_parse_count INIT( = 0);
