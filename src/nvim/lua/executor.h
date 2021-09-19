#ifndef NVIM_LUA_EXECUTOR_H
#define NVIM_LUA_EXECUTOR_H

#include <lua.h>
#include <lauxlib.h>

#include "nvim/api/private/defs.h"
#include "nvim/func_attr.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/lua/converter.h"

// Generated by msgpack-gen.lua
void nlua_add_api_functions(lua_State *lstate) REAL_FATTR_NONNULL_ALL;

EXTERN LuaRef nlua_nil_ref INIT(= LUA_NOREF);
EXTERN LuaRef nlua_empty_dict_ref INIT(= LUA_NOREF);

EXTERN int nlua_refcount INIT(= 0);

#define set_api_error(s, err) \
    do { \
      Error *err_ = (err); \
      err_->type = kErrorTypeException; \
      err_->set = true; \
      memcpy(&err_->msg[0], s, sizeof(s)); \
    } while (0)

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
#endif  // NVIM_LUA_EXECUTOR_H
