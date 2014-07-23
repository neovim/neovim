#ifndef NVIM_VIML_EXECUTOR_EXECUTOR_H
#define NVIM_VIML_EXECUTOR_EXECUTOR_H

#include <lua.h>

#include "nvim/api/private/defs.h"
#include "nvim/func_attr.h"

// Generated by msgpack-gen.lua
void nlua_add_api_functions(lua_State *lstate) REAL_FATTR_NONNULL_ALL;

#define set_api_error(s, err) \
    do { \
      err->type = kErrorTypeException; \
      err->set = true; \
      memcpy(&(err->msg[0]), s, sizeof(s)); \
    } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/executor/executor.h.generated.h"
#endif
#endif  // NVIM_VIML_EXECUTOR_EXECUTOR_H
