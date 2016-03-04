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
/// Call C function which expects four arguments
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

static void set_lua_error(lua_State *lstate, LuaError *lerr)
  FUNC_ATTR_NONNULL_ALL
{
  const char *const str = lua_tolstring(lstate, -1, &lerr->lua_err_str.size);
  lerr->lua_err_str.data = xmemdupz(str, lerr->lua_err_str.size);
  lua_pop(lstate, 1);

  // FIXME? More specific error?
  set_api_error("Error while executing lua code", &lerr->err);
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
  lua_pushnumber(lstate, (lua_Number) ((ret > 0) - (ret < 0)));
  return 1;
}

/// Evaluate lua string
///
/// Expects three values on the stack: string to evaluate, pointer to the
/// location where result is saved, pointer to the location where error is
/// saved. Always returns nothing (from the lua point of view).
static int nlua_exec_lua_string(lua_State *lstate) FUNC_ATTR_NONNULL_ALL
{
  String *str = (String *) lua_touserdata(lstate, 1);
  Object *obj = (Object *) lua_touserdata(lstate, 2);
  LuaError *lerr = (LuaError *) lua_touserdata(lstate, 3);
  lua_pop(lstate, 3);

  if (luaL_loadbuffer(lstate, str->data, str->size, NLUA_EVAL_NAME)) {
    set_lua_error(lstate, lerr);
    return 0;
  }
  if (lua_pcall(lstate, 0, 1, 0)) {
    set_lua_error(lstate, lerr);
    return 0;
  }
  *obj = nlua_pop_Object(lstate, &lerr->err);
  return 0;
}

/// Initialize lua interpreter state
///
/// Called by lua interpreter itself to initialize state.
static int nlua_state_init(lua_State *lstate) FUNC_ATTR_NONNULL_ALL
{
  lua_pushcfunction(lstate, &nlua_stricmp);
  lua_setglobal(lstate, "stricmp");
  if (luaL_dostring(lstate, (char *) &vim_module[0])) {
    LuaError lerr;
    set_lua_error(lstate, &lerr);
    return 1;
  }
  nlua_add_api_functions(lstate);
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

static Object exec_lua_string(lua_State *lstate, String str, LuaError *lerr)
  FUNC_ATTR_NONNULL_ALL
{
  Object ret = { kObjectTypeNil, { false } };
  NLUA_CALL_C_FUNCTION_3(lstate, nlua_exec_lua_string, 0, &str, &ret, lerr);
  return ret;
}

static lua_State *global_lstate = NULL;

/// Execute lua string
///
/// Used for :lua.
///
/// @param[in]  str  String to execute.
/// @param[out]  err  Location where error will be saved.
/// @param[out]  err_str  Location where lua error string will be saved, if any.
///
/// @return Result of the execution.
Object executor_exec_lua(String str, Error *err, String *err_str)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }

  LuaError lerr = {
    .err = { .set = false },
    .lua_err_str = STRING_INIT,
  };

  Object ret = exec_lua_string(global_lstate, str, &lerr);

  *err = lerr.err;
  *err_str = lerr.lua_err_str;

  return ret;
}

/// Evaluate lua string
///
/// Used for luaeval(). Expects three values on the stack:
///
/// 1. String to evaluate.
/// 2. _A value.
/// 3. Pointer to location where result is saved.
/// 4. Pointer to location where error will be saved.
///
/// @param[in,out]  lstate  Lua interpreter state.
static int nlua_eval_lua_string(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  String *str = (String *) lua_touserdata(lstate, 1);
  Object *arg = (Object *) lua_touserdata(lstate, 2);
  Object *ret = (Object *) lua_touserdata(lstate, 3);
  LuaError *lerr = (LuaError *) lua_touserdata(lstate, 4);

  garray_T str_ga;
  ga_init(&str_ga, 1, 80);
#define EVALHEADER "local _A=select(1,...) return "
  ga_concat_len(&str_ga, EVALHEADER, sizeof(EVALHEADER) - 1);
#undef EVALHEADER
  ga_concat_len(&str_ga, str->data, str->size);
  if (luaL_loadbuffer(lstate, str_ga.ga_data, (size_t) str_ga.ga_len,
                      NLUA_EVAL_NAME)) {
    set_lua_error(lstate, lerr);
    return 0;
  }
  ga_clear(&str_ga);

  nlua_push_Object(lstate, *arg);
  if (lua_pcall(lstate, 1, 1, 0)) {
    set_lua_error(lstate, lerr);
    return 0;
  }
  *ret = nlua_pop_Object(lstate, &lerr->err);

  return 0;
}

static Object eval_lua_string(lua_State *lstate, String str, Object arg,
                              LuaError *lerr)
  FUNC_ATTR_NONNULL_ALL
{
  Object ret = { kObjectTypeNil, { false } };
  NLUA_CALL_C_FUNCTION_4(lstate, nlua_eval_lua_string, 0,
                         &str, &arg, &ret, lerr);
  return ret;
}

/// Evaluate lua string
///
/// Used for luaeval().
///
/// @param[in]  str  String to execute.
/// @param[out]  err  Location where error will be saved.
/// @param[out]  err_str  Location where lua error string will be saved, if any.
///
/// @return Result of the execution.
Object executor_eval_lua(String str, Object arg, Error *err, String *err_str)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }

  LuaError lerr = {
    .err = { .set = false },
    .lua_err_str = STRING_INIT,
  };

  Object ret = eval_lua_string(global_lstate, str, arg, &lerr);

  *err = lerr.err;
  *err_str = lerr.lua_err_str;

  return ret;
}
