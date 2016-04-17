#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "nvim/misc1.h"
#include "nvim/getchar.h"
#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/vim.h"
#include "nvim/vim.h"
#include "nvim/message.h"

#include "nvim/viml/executor/executor.h"
#include "nvim/viml/executor/converter.h"


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
    lua_pushcfunction(lstate, &function); \
    lua_call(lstate, 0, numret)
/// Call C function which expects four arguments
///
/// @param  function  Called function
/// @param  numret    Number of returned arguments
/// @param  a…        Supplied argument (should be a void* pointer)
#define NLUA_CALL_C_FUNCTION_3(lstate, function, numret, a1, a2, a3) \
    lua_pushcfunction(lstate, &function); \
    lua_pushlightuserdata(lstate, a1); \
    lua_pushlightuserdata(lstate, a2); \
    lua_pushlightuserdata(lstate, a3); \
    lua_call(lstate, 3, numret)

static void set_lua_error(lua_State *lstate, Error *err) FUNC_ATTR_NONNULL_ALL
{
  size_t len;
  const char *str;
  str = lua_tolstring(lstate, -1, &len);
  lua_pop(lstate, 1);

  // FIXME? More specific error?
  set_api_error("Error while executing lua code", err);

  // FIXME!! Print error message
  fputs(str, stderr);
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
static int nlua_eval_lua_string(lua_State *lstate) FUNC_ATTR_NONNULL_ALL
{
  String *str = (String *) lua_touserdata(lstate, 1);
  Object *obj = (Object *) lua_touserdata(lstate, 2);
  Error *err = (Error *) lua_touserdata(lstate, 3);
  lua_pop(lstate, 3);

  if (luaL_loadbuffer(lstate, str->data, str->size, NLUA_EVAL_NAME)) {
    set_lua_error(lstate, err);
    return 0;
  }
  if (lua_pcall(lstate, 0, 1, 0)) {
    set_lua_error(lstate, err);
    return 0;
  }
  *obj = nlua_pop_Object(lstate, err);
  return 0;
}

/// Initialize lua interpreter state
///
/// Called by lua interpreter itself to initialize state.
static int nlua_state_init(lua_State *lstate) FUNC_ATTR_NONNULL_ALL
{
  lua_pushcfunction(lstate, &nlua_stricmp);
  lua_setglobal(lstate, "stricmp");
  if (luaL_dostring(lstate, ((char *) &(vim_module[0])))) {
    Error err;
    set_lua_error(lstate, &err);
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
    EMSG("Vim: Error: Failed to initialize lua interpreter.\n");
    preserve_exit();
  }
  luaL_openlibs(lstate);
  NLUA_CALL_C_FUNCTION_0(lstate, nlua_state_init, 0);
  return lstate;
}

static Object eval_lua_string(lua_State *lstate, String str, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  Object ret = { kObjectTypeNil, { false } };
  NLUA_CALL_C_FUNCTION_3(lstate, nlua_eval_lua_string, 0, &str, &ret, err);
  return ret;
}

static lua_State *global_lstate = NULL;

Object eval_lua(String str, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }

  return eval_lua_string(global_lstate, str, err);
}
