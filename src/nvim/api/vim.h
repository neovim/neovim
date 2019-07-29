#ifndef NVIM_API_VIM_H
#define NVIM_API_VIM_H

#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/map.h"

EXTERN Map(String, handle_T) *namespace_ids INIT(= NULL);
EXTERN handle_T next_namespace_id INIT(= 1);

/// Executes a static Lua chunk.
///
/// @see nvim_execute_lua
///
/// @param[in]   code  String literal with Lua code to execute.
/// @param[in]   args  Array object of arguments to the code.
/// @param[out]  err   Details of an error encountered while parsing
///                    or executing the Lua code.
///
/// @return Return value of lua code if present or NIL.
#define EXEC_LUA_STATIC(code, args, err) \
  nvim_execute_lua(STATIC_CSTR_AS_STRING(code), args, err)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/vim.h.generated.h"
#endif
#endif  // NVIM_API_VIM_H
