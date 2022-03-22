#ifndef NVIM_LUA_EXECUTOR_H
#define NVIM_LUA_EXECUTOR_H

#include <lauxlib.h>
#include <lua.h>

#include "nvim/api/private/defs.h"
#include "nvim/assert.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/func_attr.h"
#include "nvim/lua/converter.h"

// Generated by msgpack-gen.lua
void nlua_add_api_functions(lua_State *lstate) REAL_FATTR_NONNULL_ALL;

typedef struct {
  LuaRef nil_ref;
  LuaRef empty_dict_ref;
  int ref_count;
#if __has_feature(address_sanitizer)
  PMap(handle_T) ref_markers;
#endif
} nlua_ref_state_t;

#define NLUA_CLEAR_REF(x) \
  do { \
    /* Take the address to avoid double evaluation. #1375 */ \
    if ((x) != LUA_NOREF) { \
      api_free_luaref(x); \
      (x) = LUA_NOREF; \
    } \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/executor.h.generated.h"
#endif

EXTERN nlua_ref_state_t *nlua_global_refs INIT(= NULL);
EXTERN bool nlua_disable_preload INIT(= false);

#endif  // NVIM_LUA_EXECUTOR_H
