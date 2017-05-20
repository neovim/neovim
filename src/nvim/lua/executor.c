// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "nvim/misc1.h"
#include "nvim/getchar.h"
#include "nvim/garray.h"
#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/vim.h"
#include "nvim/ex_getln.h"
#include "nvim/message.h"
#include "nvim/memline.h"
#include "nvim/buffer_defs.h"
#include "nvim/macros.h"
#include "nvim/screen.h"
#include "nvim/cursor.h"
#include "nvim/undo.h"
#include "nvim/ascii.h"

#include "nvim/lua/executor.h"
#include "nvim/lua/converter.h"

typedef struct {
  Error err;
  String lua_err_str;
} LuaError;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/vim_module.generated.h"
# include "lua/executor.c.generated.h"
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
/// Call C function which expects one argument
///
/// @param  function  Called function
/// @param  numret    Number of returned arguments
/// @param  a…        Supplied argument (should be a void* pointer)
#define NLUA_CALL_C_FUNCTION_1(lstate, function, numret, a1) \
    do { \
      lua_pushcfunction(lstate, &function); \
      lua_pushlightuserdata(lstate, a1); \
      lua_call(lstate, 1, numret); \
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
  const char *str = lua_tolstring(lstate, -1, &len);

  char errbuf[IOSIZE];
  // vim_vsnprintf special case to make tests happy
  if (str == NULL) {
    str = "[NULL]";
    len = 6;
  }
  snprintf(errbuf, ARRAY_SIZE(errbuf), msg, (int)len, str);
  emsg((const char_u *)errbuf);

  lua_pop(lstate, 1);
}

/// Compare two strings, ignoring case
///
/// Expects two values on the stack: compared strings. Returns one of the
/// following numbers: 0, -1 or 1.
///
/// Does no error handling: never call it with non-string or with some arguments
/// omitted.
static int nlua_stricmp(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
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
static int nlua_exec_lua_string(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  const String *const str = (const String *)lua_touserdata(lstate, 1);
  typval_T *const ret_tv = (typval_T *)lua_touserdata(lstate, 2);
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

/// Evaluate lua string for each line in range
///
/// Expects two values on the stack: string to evaluate and pointer to integer
/// array with line range. Always returns nothing (from the lua point of view).
static int nlua_exec_luado_string(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  const String *const str = (const String *)lua_touserdata(lstate, 1);
  const linenr_T *const range = (const linenr_T *)lua_touserdata(lstate, 2);
  lua_pop(lstate, 2);

#define DOSTART "return function(line, linenr) "
#define DOEND " end"
  const size_t lcmd_len = (str->size
                           + (sizeof(DOSTART) - 1)
                           + (sizeof(DOEND) - 1));
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = (char *)IObuff;
  } else {
    lcmd = xmalloc(lcmd_len + 1);
  }
  memcpy(lcmd, DOSTART, sizeof(DOSTART) - 1);
  memcpy(lcmd + sizeof(DOSTART) - 1, str->data, str->size);
  memcpy(lcmd + sizeof(DOSTART) - 1 + str->size, DOEND, sizeof(DOEND) - 1);
#undef DOSTART
#undef DOEND

  if (luaL_loadbuffer(lstate, lcmd, lcmd_len, NLUA_EVAL_NAME)) {
    nlua_error(lstate, _("E5109: Error while creating lua chunk: %.*s"));
    if (lcmd_len >= IOSIZE) {
      xfree(lcmd);
    }
    return 0;
  }
  if (lcmd_len >= IOSIZE) {
    xfree(lcmd);
  }
  if (lua_pcall(lstate, 0, 1, 0)) {
    nlua_error(lstate, _("E5110: Error while creating lua function: %.*s"));
    return 0;
  }
  for (linenr_T l = range[0]; l <= range[1]; l++) {
    if (l > curbuf->b_ml.ml_line_count) {
      break;
    }
    lua_pushvalue(lstate, -1);
    lua_pushstring(lstate, (const char *)ml_get_buf(curbuf, l, false));
    lua_pushnumber(lstate, (lua_Number)l);
    if (lua_pcall(lstate, 2, 1, 0)) {
      nlua_error(lstate, _("E5111: Error while calling lua function: %.*s"));
      break;
    }
    if (lua_isstring(lstate, -1)) {
      size_t new_line_len;
      const char *const new_line = lua_tolstring(lstate, -1, &new_line_len);
      char *const new_line_transformed = xmemdupz(new_line, new_line_len);
      for (size_t i = 0; i < new_line_len; i++) {
        if (new_line_transformed[i] == NUL) {
          new_line_transformed[i] = '\n';
        }
      }
      ml_replace(l, (char_u *)new_line_transformed, false);
      changed_bytes(l, 0);
    }
    lua_pop(lstate, 1);
  }
  lua_pop(lstate, 1);
  check_cursor();
  update_screen(NOT_VALID);
  return 0;
}

/// Evaluate lua file
///
/// Expects one value on the stack: file to evaluate. Always returns nothing
/// (from the lua point of view).
static int nlua_exec_lua_file(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  const char *const filename = (const char *)lua_touserdata(lstate, 1);
  lua_pop(lstate, 1);

  if (luaL_loadfile(lstate, filename)) {
    nlua_error(lstate, _("E5112: Error while creating lua chunk: %.*s"));
    return 0;
  }
  if (lua_pcall(lstate, 0, 0, 0)) {
    nlua_error(lstate, _("E5113: Error while calling lua chunk: %.*s"));
    return 0;
  }
  return 0;
}

/// Initialize lua interpreter state
///
/// Called by lua interpreter itself to initialize state.
static int nlua_state_init(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  // stricmp
  lua_pushcfunction(lstate, &nlua_stricmp);
  lua_setglobal(lstate, "stricmp");

  // print
  lua_pushcfunction(lstate, &nlua_print);
  lua_setglobal(lstate, "print");

  // debug.debug
  lua_getglobal(lstate, "debug");
  lua_pushcfunction(lstate, &nlua_debug);
  lua_setfield(lstate, -2, "debug");
  lua_pop(lstate, 1);

  // vim
  if (luaL_dostring(lstate, (char *)&vim_module[0])) {
    nlua_error(lstate, _("E5106: Error while creating vim module: %.*s"));
    return 1;
  }
  // vim.api
  nlua_add_api_functions(lstate);
  // vim.types, vim.type_idx, vim.val_idx
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
/// @param[in]  str  String to execute.
/// @param[out]  ret_tv  Location where result will be saved.
///
/// @return Result of the execution.
void executor_exec_lua(const String str, typval_T *const ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }

  NLUA_CALL_C_FUNCTION_2(global_lstate, nlua_exec_lua_string, 0,
                         (void *)&str, ret_tv);
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
static int nlua_eval_lua_string(lua_State *const lstate)
  FUNC_ATTR_NONNULL_ALL
{
  const String *const str = (const String *)lua_touserdata(lstate, 1);
  typval_T *const arg = (typval_T *)lua_touserdata(lstate, 2);
  typval_T *const ret_tv = (typval_T *)lua_touserdata(lstate, 3);
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
    if (lcmd != (char *)IObuff) {
      xfree(lcmd);
    }
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
/// Expects four values on the stack: string to evaluate, pointer to args array,
/// and locations where result and error are saved, respectively. Always
/// returns nothing (from the lua point of view).
static int nlua_exec_lua_string_api(lua_State *const lstate)
    FUNC_ATTR_NONNULL_ALL
{
  const String *str = (const String *)lua_touserdata(lstate, 1);
  const Array *args = (const Array *)lua_touserdata(lstate, 2);
  Object *retval = (Object *)lua_touserdata(lstate, 3);
  Error *err = (Error *)lua_touserdata(lstate, 4);

  lua_pop(lstate, 4);

  if (luaL_loadbuffer(lstate, str->data, str->size, "<nvim>")) {
    size_t len;
    const char *str = lua_tolstring(lstate, -1, &len);
    api_set_error(err, kErrorTypeValidation,
                  "Error loading lua: %.*s", (int)len, str);
    return 0;
  }

  for (size_t i = 0; i < args->size; i++) {
    nlua_push_Object(lstate, args->items[i]);
  }

  if (lua_pcall(lstate, (int)args->size, 1, 0)) {
    size_t len;
    const char *str = lua_tolstring(lstate, -1, &len);
    api_set_error(err, kErrorTypeException,
                  "Error executing lua: %.*s", (int)len, str);
    return 0;
  }

  *retval = nlua_pop_Object(lstate, err);

  return 0;
}

/// Print as a Vim message
///
/// @param  lstate  Lua interpreter state.
static int nlua_print(lua_State *const lstate)
  FUNC_ATTR_NONNULL_ALL
{
#define PRINT_ERROR(msg) \
  do { \
    errmsg = msg; \
    errmsg_len = sizeof(msg) - 1; \
    goto nlua_print_error; \
  } while (0)
  const int nargs = lua_gettop(lstate);
  lua_getglobal(lstate, "tostring");
  const char *errmsg = NULL;
  size_t errmsg_len = 0;
  garray_T msg_ga;
  ga_init(&msg_ga, 1, 80);
  int curargidx = 1;
  for (; curargidx <= nargs; curargidx++) {
    lua_pushvalue(lstate, -1);  // tostring
    lua_pushvalue(lstate, curargidx);  // arg
    if (lua_pcall(lstate, 1, 1, 0)) {
      errmsg = lua_tolstring(lstate, -1, &errmsg_len);
      goto nlua_print_error;
    }
    size_t len;
    const char *const s = lua_tolstring(lstate, -1, &len);
    if (s == NULL) {
      PRINT_ERROR(
          "<Unknown error: lua_tolstring returned NULL for tostring result>");
    }
    ga_concat_len(&msg_ga, s, len);
    if (curargidx < nargs) {
      ga_append(&msg_ga, ' ');
    }
    lua_pop(lstate, 1);
  }
#undef PRINT_ERROR
  lua_pop(lstate, nargs + 1);
  ga_append(&msg_ga, NUL);
  {
    const size_t len = (size_t)msg_ga.ga_len - 1;
    char *const str = (char *)msg_ga.ga_data;

    for (size_t i = 0; i < len;) {
      const size_t start = i;
      while (i < len) {
        switch (str[i]) {
          case NUL: {
            str[i] = NL;
            i++;
            continue;
          }
          case NL: {
            str[i] = NUL;
            i++;
            break;
          }
          default: {
            i++;
            continue;
          }
        }
        break;
      }
      msg((char_u *)str + start);
    }
    if (str[len - 1] == NUL) {  // Last was newline
      msg((char_u *)"");
    }
  }
  ga_clear(&msg_ga);
  return 0;
nlua_print_error:
  ;
  char errbuf[IOSIZE];
  // vim_vsnprintf special case to make tests happy
  if (errmsg == NULL) {
    errmsg = "[NULL]";
    errmsg_len = 6;
  }
  snprintf(errbuf, ARRAY_SIZE(errbuf),
           _("E5114: Error while converting print argument #%i: %.*s"),
           curargidx, (int)errmsg_len, errmsg);
  emsg((const char_u *)errbuf);
  ga_clear(&msg_ga);
  lua_pop(lstate, lua_gettop(lstate));
  return 0;
}

/// debug.debug implementation: interaction with user while debugging
///
/// @param  lstate  Lua interpreter state.
int nlua_debug(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  const typval_T input_args[] = {
    {
      .v_lock = VAR_FIXED,
      .v_type = VAR_STRING,
      .vval.v_string = (char_u *)"lua_debug> ",
    },
    {
      .v_type = VAR_UNKNOWN,
    },
  };
  for (;;) {
    lua_settop(lstate, 0);
    typval_T input;
    get_user_input(input_args, &input, false);
    msg_putchar('\n');  // Avoid outputting on input line.
    if (input.v_type != VAR_STRING
        || input.vval.v_string == NULL
        || *input.vval.v_string == NUL
        || STRCMP(input.vval.v_string, "cont") == 0) {
      tv_clear(&input);
      return 0;
    }
    if (luaL_loadbuffer(lstate, (const char *)input.vval.v_string,
                        STRLEN(input.vval.v_string), "=(debug command)")) {
      nlua_error(lstate, _("E5115: Error while loading debug string: %.*s"));
    }
    tv_clear(&input);
    if (lua_pcall(lstate, 0, 0, 0)) {
      nlua_error(lstate, _("E5116: Error while calling debug string: %.*s"));
    }
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

/// Execute lua string
///
/// Used for nvim_execute_lua().
///
/// @param[in]  str  String to execute.
/// @param[in]  args array of ... args
/// @param[out]  err  Location where error will be saved.
///
/// @return Return value of the execution.
Object executor_exec_lua_api(const String str, const Array args, Error *err)
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }

  Object retval = NIL;
  NLUA_CALL_C_FUNCTION_4(global_lstate, nlua_exec_lua_string_api, 0,
                         (void *)&str, (void *)&args, &retval, err);
  return retval;
}


/// Run lua string
///
/// Used for :lua.
///
/// @param  eap  VimL command being run.
void ex_lua(exarg_T *const eap)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len;
  char *const code = script_get(eap, &len);
  if (eap->skip) {
    xfree(code);
    return;
  }
  typval_T tv = { .v_type = VAR_UNKNOWN };
  executor_exec_lua((String) { .data = code, .size = len }, &tv);
  tv_clear(&tv);
  xfree(code);
}

/// Run lua string for each line in range
///
/// Used for :luado.
///
/// @param  eap  VimL command being run.
void ex_luado(exarg_T *const eap)
  FUNC_ATTR_NONNULL_ALL
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }
  if (u_save(eap->line1 - 1, eap->line2 + 1) == FAIL) {
    EMSG(_("cannot save undo information"));
    return;
  }
  const String cmd = {
    .size = STRLEN(eap->arg),
    .data = (char *)eap->arg,
  };
  const linenr_T range[] = { eap->line1, eap->line2 };
  NLUA_CALL_C_FUNCTION_2(global_lstate, nlua_exec_luado_string, 0,
                         (void *)&cmd, (void *)range);
}

/// Run lua file
///
/// Used for :luafile.
///
/// @param  eap  VimL command being run.
void ex_luafile(exarg_T *const eap)
  FUNC_ATTR_NONNULL_ALL
{
  if (global_lstate == NULL) {
    global_lstate = init_lua();
  }
  NLUA_CALL_C_FUNCTION_1(global_lstate, nlua_exec_lua_file, 0,
                         (void *)eap->arg);
}
