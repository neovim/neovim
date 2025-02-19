#include <lauxlib.h>  // IWYU pragma: keep
#include <lua.h>  // IWYU pragma: keep
#include <lualib.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/api/private/dispatch.h"  // IWYU pragma: keep
#include "nvim/api/private/helpers.h"  // IWYU pragma: keep
#include "nvim/errors.h"  // IWYU pragma: keep
#include "nvim/ex_docmd.h"  // IWYU pragma: keep
#include "nvim/ex_getln.h"  // IWYU pragma: keep
#include "nvim/func_attr.h"  // IWYU pragma: keep
#include "nvim/globals.h"  // IWYU pragma: keep
#include "nvim/lua/converter.h"  // IWYU pragma: keep
#include "nvim/lua/executor.h"  // IWYU pragma: keep
#include "nvim/memory.h"  // IWYU pragma: keep

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua_api_c_bindings.generated.h"  // IWYU pragma: keep
#endif
