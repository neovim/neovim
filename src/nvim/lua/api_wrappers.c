#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/func_attr.h"
#include "nvim/globals.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua_api_c_bindings.generated.h"
#endif
