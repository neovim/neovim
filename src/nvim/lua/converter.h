#ifndef NVIM_LUA_CONVERTER_H
#define NVIM_LUA_CONVERTER_H

#include <lua.h>
#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/func_attr.h"

#define nlua_pop_Buffer nlua_pop_handle
#define nlua_pop_Window nlua_pop_handle
#define nlua_pop_Tabpage nlua_pop_handle

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/converter.h.generated.h"
#endif
#endif  // NVIM_LUA_CONVERTER_H
