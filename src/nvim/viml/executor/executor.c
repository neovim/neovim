#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "nvim/misc1.h"
#include "nvim/getchar.h"
#include "nvim/garray.h"
#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/vim.h"
#include "nvim/vim.h"
#include "nvim/message.h"

#include "nvim/viml/executor/executor.h"
#include "nvim/viml/executor/converter.h"

typedef struct {
  Error err;
  String lua_err_str;
} LuaError;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/executor/vim_module.generated.h"
# include "viml/executor/executor.c.generated.h"
#endif

/// Name of the run code for use in messages
#define NLUA_EVAL_NAME "<VimL compiled string>"

/// Call C function which does not expect any arguments
///
/// @param  function  Called function
/// @param  numret    Number of returned arguments
#define NLUA_CALL_C_FUNCTION_0(lstate, function, numret) \
    do { \
      lua_pushcfunction(lstate, &function); \
      lua_call(lstate, 0, numret); \
    } while (0)
/// Call C function which expects two arguments
///
/// @param  function  Called function
/// @param  numret    Number of returned arguments
/// @param  a…        Supplied argument (should be a void* pointer)
#define NLUA_CALL_C_FUNCTION_2(lstate, function, numret, a1, a2) \
    do { \
      lua_pushcfunction(lstate, &function); \
      lua_pushlightuserdata(lstate, a1); \
      lua_pushlightuserdata(lstate, a2); \
      lua_call(lstate, 2, numret); \
    } while (0)
/// Call C function which expects three arguments
///
/// @param  function  Called function
/// @param  numret    Number of returned arguments
/// @param  a…        Supplied argument (should be a void* pointer)
#define NLUA_CALL_C_FUNCTION_3(lstate, function, numret, a1, a2, a3) \
    do { \
      lua_pushcfunction(lstate, &function); \
      lua_pushlightuserdata(lstate, a1); \
      lua_pushlightuserdata(lstate, a2); \
      lua_pushlightuserdata(lstate, a3); \
      lua_call(lstate, 3, numret); \
    } while (0)
/// Call C function which expects five arguments
///
/// @param  function  Called function
/// @param  numret    Number of returned arguments
/// @param  a…        Supplied argument (should be a void* pointer)
#define NLUA_CALL_C_FUNCTION_4(lstate, function, numret, a1, a2, a3, a4) \
    do { \
      lua_pushcfunction(lstate, &function); \
      lua_pushlightuserdata(lstate, a1); \
      lua_pushlightuserdata(lstate, a2); \
      lua_pushlightuserdata(lstate, a3); \
      lua_pushlightuserdata(lstate, a4); \
      lua_call(lstate, 4, numret); \
    } while (0)

/// Convert lua error into a Vim error message
///
/// @param  lstate  Lua interpreter state.
/// @param[in]  msg  Message base, must contain one `%s`.
static void nlua_error(lua_State *const lstate, const char *const msg)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len;
  const char *const str = lua_tolstring(lstate, -1, &len);

  emsgf(msg, (int)len, str);

  lua_pop(lstate, 1);
}

/// Compare two strings, ignoring case
///
/// Expects two values on the stack: compared strings. Returns one of the
/// following numbers: 0, -1 or 1.
///
/// Does no error handling: never call it with non-string or with some arguments
/// omitted.
static int nlua_stricmp(lua_State *lstate) FUNC_ATTR_NONNULL_ALL
{
  const char *s1 = luaL_checklstring(lstate, 1, NULL);
  const char *s2 = luaL_checklstring(lstate, 2, NULL);
  const int ret = STRICMP(s1, s2);
  lua_pop(lstate, 2);
  lua_pushnumber(lstate, (lua_Number)((ret > 0) - (ret < 0)));
  return 1;
}

/// Evaluate lua string
///
/// Expects two values on the stack: string to evaluate, pointer to the
/// location where result is saved. Always returns nothing (from the lua point
/// of view).
static int nlua_exec_lua_string(lua_State *lstate) FUNC_ATTR_NONNULL_ALL
{
  String *str = (String *)lua_touserdata(lstate, 1);
  typval_T *ret_tv = (typval_T *)lua_touserdata(lstate, 2);
  lua_pop(lstate, 2);

  if (luaL_loadbuffer(lstate, str->data, str->size, NLUA_EVAL_NAME)) {
    nlua_error(lstate, _("E5104: Error while creating lua chunk: %.*s"));
    return 0;
  }
  if (lua_pcall(lstate, 0, 1, 0)) {
    nlua_error(lstate, _("E5105: Error while calling lua chunk: %.*s"));
    return 0;
  }
  if (!nlua_pop_typval(lstate, ret_tv)) {
    return 0;
  }
  return 0;
}

/// Initialize lua interpreter state
///
/// Called by lua interpreter itself to initialize state.
static int nlua_state_init(lua_State *lstate) FUNC_ATTR_NONNULL_ALL
{
  lua_pushcfunction(lstate, &nlua_stricmp);
  lua_setglobal(lstate, "stricmp");
  if (luaL_dostring(lstate, (char *)&vim_module[0])) {
    nlua_error(lstate, _("E5106: Error while creating vim module: %.*s"));
    return 1;
  }
  nlua_add_api_functions(lstate);
  nlua_init_types(lstate);
  lua_setglobal(lstate, "vim");
  return 0;
}

/// Initialize lua interpreter
///
/// Crashes NeoVim if initialization fails. Should be called once per lua
/// interpreter instance.
static lua_State *init_lua(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  lua_State *lstate = luaL_newstate();
  if (lstate == NULL) {
    EMSG(_("E970: Failed to initialize lua interpreter"));
    preserve_exit();
  }
  luaL_openlibs(lstate);
  NLUA_CALL_C_FUNCTION_0(lstate, nlua_state_init, 0);
  return lstate;
}

static lua_State *global_lstate = NULL;

/// Execute lua string
///
/// Used for :lua.
///
/// @param[in]  str  String to execute.
/// @param[out]  ret_tv  Location where result will be saved.
///
/// @return Result of the execution.
void executor_exec_lua(String str, typval_T *ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }

  NLUA_CALL_C_FUNCTION_2(global_lstate, nlua_exec_lua_string, 0, &str, ret_tv);
}

/// Evaluate lua string
///
/// Used for luaeval(). Expects three values on the stack:
///
/// 1. String to evaluate.
/// 2. _A value.
/// 3. Pointer to location where result is saved.
///
/// @param[in,out]  lstate  Lua interpreter state.
static int nlua_eval_lua_string(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  String *str = (String *)lua_touserdata(lstate, 1);
  typval_T *arg = (typval_T *)lua_touserdata(lstate, 2);
  typval_T *ret_tv = (typval_T *)lua_touserdata(lstate, 3);
  lua_pop(lstate, 3);

  garray_T str_ga;
  ga_init(&str_ga, 1, 80);
#define EVALHEADER "local _A=select(1,...) return ("
  const size_t lcmd_len = sizeof(EVALHEADER) - 1 + str->size + 1;
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = (char *)IObuff;
  } else {
    lcmd = xmalloc(lcmd_len);
  }
  memcpy(lcmd, EVALHEADER, sizeof(EVALHEADER) - 1);
  memcpy(lcmd + sizeof(EVALHEADER) - 1, str->data, str->size);
  lcmd[lcmd_len - 1] = ')';
#undef EVALHEADER
  if (luaL_loadbuffer(lstate, lcmd, lcmd_len, NLUA_EVAL_NAME)) {
    nlua_error(lstate,
               _("E5107: Error while creating lua chunk for luaeval(): %.*s"));
    return 0;
  }
  if (lcmd != (char *)IObuff) {
    xfree(lcmd);
  }

  if (arg == NULL || arg->v_type == VAR_UNKNOWN) {
    lua_pushnil(lstate);
  } else {
    nlua_push_typval(lstate, arg);
  }
  if (lua_pcall(lstate, 1, 1, 0)) {
    nlua_error(lstate,
               _("E5108: Error while calling lua chunk for luaeval(): %.*s"));
    return 0;
  }
  if (!nlua_pop_typval(lstate, ret_tv)) {
    return 0;
  }

  return 0;
}

/// Evaluate lua string
///
/// Used for luaeval().
///
/// @param[in]  str  String to execute.
/// @param[in]  arg  Second argument to `luaeval()`.
/// @param[out]  ret_tv  Location where result will be saved.
///
/// @return Result of the execution.
void executor_eval_lua(const String str, typval_T *const arg,
                       typval_T *const ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }

  NLUA_CALL_C_FUNCTION_3(global_lstate, nlua_eval_lua_string, 0,
                         (void *)&str, arg, ret_tv);
}
