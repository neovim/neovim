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
#include "nvim/api/private/handle.h"
#include "nvim/api/vim.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/vim.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_cmds2.h"
#include "nvim/message.h"
#include "nvim/memline.h"
#include "nvim/buffer_defs.h"
#include "nvim/regexp.h"
#include "nvim/macros.h"
#include "nvim/screen.h"
#include "nvim/cursor.h"
#include "nvim/undo.h"
#include "nvim/ascii.h"
#include "nvim/change.h"

#ifdef WIN32
#include "nvim/os/os.h"
#endif

#include "nvim/lua/executor.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/treesitter.h"

#include "luv/luv.h"

static int in_fast_callback = 0;

typedef struct {
  Error err;
  String lua_err_str;
} LuaError;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/vim_module.generated.h"
# include "lua/executor.c.generated.h"
#endif

/// Convert lua error into a Vim error message
///
/// @param  lstate  Lua interpreter state.
/// @param[in]  msg  Message base, must contain one `%s`.
static void nlua_error(lua_State *const lstate, const char *const msg)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len;
  const char *const str = lua_tolstring(lstate, -1, &len);

  msg_ext_set_kind("lua_error");
  emsgf_multiline(msg, (int)len, str);

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
  size_t s1_len;
  size_t s2_len;
  const char *s1 = luaL_checklstring(lstate, 1, &s1_len);
  const char *s2 = luaL_checklstring(lstate, 2, &s2_len);
  char *nul1;
  char *nul2;
  int ret = 0;
  assert(s1[s1_len] == NUL);
  assert(s2[s2_len] == NUL);
  do {
    nul1 = memchr(s1, NUL, s1_len);
    nul2 = memchr(s2, NUL, s2_len);
    ret = STRICMP(s1, s2);
    if (ret == 0) {
      // Compare "a\0" greater then "a".
      if ((nul1 == NULL) != (nul2 == NULL)) {
        ret = ((nul1 != NULL) - (nul2 != NULL));
        break;
      }
      if (nul1 != NULL) {
        assert(nul2 != NULL);
        // Can't shift both strings by the same amount of bytes: lowercase
        // letter may have different byte-length than uppercase.
        s1_len -= (size_t)(nul1 - s1) + 1;
        s2_len -= (size_t)(nul2 - s2) + 1;
        s1 = nul1 + 1;
        s2 = nul2 + 1;
      } else {
        break;
      }
    } else {
      break;
    }
  } while (true);
  lua_pop(lstate, 2);
  lua_pushnumber(lstate, (lua_Number)((ret > 0) - (ret < 0)));
  return 1;
}

/// convert byte index to UTF-32 and UTF-16 indicies
///
/// Expects a string and an optional index. If no index is supplied, the length
/// of the string is returned.
///
/// Returns two values: the UTF-32 and UTF-16 indicies.
static int nlua_str_utfindex(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  size_t s1_len;
  const char *s1 = luaL_checklstring(lstate, 1, &s1_len);
  intptr_t idx;
  if (lua_gettop(lstate) >= 2) {
    idx = luaL_checkinteger(lstate, 2);
    if (idx < 0 || idx > (intptr_t)s1_len) {
      return luaL_error(lstate, "index out of range");
    }
  } else {
    idx = (intptr_t)s1_len;
  }

  size_t codepoints = 0, codeunits = 0;
  mb_utflen((const char_u *)s1, (size_t)idx, &codepoints, &codeunits);

  lua_pushinteger(lstate, (long)codepoints);
  lua_pushinteger(lstate, (long)codeunits);

  return 2;
}

/// convert UTF-32 or UTF-16 indicies to byte index.
///
/// Expects up to three args: string, index and use_utf16.
/// If use_utf16 is not supplied it defaults to false (use UTF-32)
///
/// Returns the byte index.
static int nlua_str_byteindex(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  size_t s1_len;
  const char *s1 = luaL_checklstring(lstate, 1, &s1_len);
  intptr_t idx = luaL_checkinteger(lstate, 2);
  if (idx < 0) {
    return luaL_error(lstate, "index out of range");
  }
  bool use_utf16 = false;
  if (lua_gettop(lstate) >= 3) {
    use_utf16 = lua_toboolean(lstate, 3);
  }

  ssize_t byteidx = mb_utf_index_to_bytes((const char_u *)s1, s1_len,
                                          (size_t)idx, use_utf16);
  if (byteidx == -1) {
    return luaL_error(lstate, "index out of range");
  }

  lua_pushinteger(lstate, (long)byteidx);

  return 1;
}

static void nlua_luv_error_event(void **argv)
{
  char *error = (char *)argv[0];
  msg_ext_set_kind("lua_error");
  emsgf_multiline("Error executing luv callback:\n%s", error);
  xfree(error);
}

static int nlua_luv_cfpcall(lua_State *lstate, int nargs, int nresult,
                            int flags)
  FUNC_ATTR_NONNULL_ALL
{
  int retval;

  // luv callbacks might be executed at any os_breakcheck/line_breakcheck
  // call, so using the API directly here is not safe.
  in_fast_callback++;

  int top = lua_gettop(lstate);
  int status = lua_pcall(lstate, nargs, nresult, 0);
  if (status) {
    if (status == LUA_ERRMEM && !(flags & LUVF_CALLBACK_NOEXIT)) {
      // consider out of memory errors unrecoverable, just like xmalloc()
      mch_errmsg(e_outofmem);
      mch_errmsg("\n");
      preserve_exit();
    }
    const char *error = lua_tostring(lstate, -1);

    multiqueue_put(main_loop.events, nlua_luv_error_event,
                   1, xstrdup(error));
    lua_pop(lstate, 1);  // error mesage
    retval = -status;
  } else {  // LUA_OK
    if (nresult == LUA_MULTRET) {
      nresult = lua_gettop(lstate) - top + nargs + 1;
    }
    retval = nresult;
  }

  in_fast_callback--;
  return retval;
}

static void nlua_schedule_event(void **argv)
{
  LuaRef cb = (LuaRef)(ptrdiff_t)argv[0];
  lua_State *const lstate = nlua_enter();
  nlua_pushref(lstate, cb);
  nlua_unref(lstate, cb);
  if (lua_pcall(lstate, 0, 0, 0)) {
    nlua_error(lstate, _("Error executing vim.schedule lua callback: %.*s"));
  }
}

/// Schedule Lua callback on main loop's event queue
///
/// @param  lstate  Lua interpreter state.
static int nlua_schedule(lua_State *const lstate)
  FUNC_ATTR_NONNULL_ALL
{
  if (lua_type(lstate, 1) != LUA_TFUNCTION) {
    lua_pushliteral(lstate, "vim.schedule: expected function");
    return lua_error(lstate);
  }

  LuaRef cb = nlua_ref(lstate, 1);

  multiqueue_put(main_loop.events, nlua_schedule_event,
                 1, (void *)(ptrdiff_t)cb);
  return 0;
}

static struct luaL_Reg regex_meta[] = {
  { "__gc", regex_gc },
  { "__tostring", regex_tostring },
  { "match_str", regex_match_str },
  { "match_line", regex_match_line },
  { NULL, NULL }
};

/// Initialize lua interpreter state
///
/// Called by lua interpreter itself to initialize state.
static int nlua_state_init(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  // print
  lua_pushcfunction(lstate, &nlua_print);
  lua_setglobal(lstate, "print");

  // debug.debug
  lua_getglobal(lstate, "debug");
  lua_pushcfunction(lstate, &nlua_debug);
  lua_setfield(lstate, -2, "debug");
  lua_pop(lstate, 1);

#ifdef WIN32
  // os.getenv
  lua_getglobal(lstate, "os");
  lua_pushcfunction(lstate, &nlua_getenv);
  lua_setfield(lstate, -2, "getenv");
  lua_pop(lstate, 1);
#endif

  // vim
  lua_newtable(lstate);
  // vim.api
  nlua_add_api_functions(lstate);
  // vim.types, vim.type_idx, vim.val_idx
  nlua_init_types(lstate);
  // stricmp
  lua_pushcfunction(lstate, &nlua_stricmp);
  lua_setfield(lstate, -2, "stricmp");
  // str_utfindex
  lua_pushcfunction(lstate, &nlua_str_utfindex);
  lua_setfield(lstate, -2, "str_utfindex");
  // str_byteindex
  lua_pushcfunction(lstate, &nlua_str_byteindex);
  lua_setfield(lstate, -2, "str_byteindex");
  // schedule
  lua_pushcfunction(lstate, &nlua_schedule);
  lua_setfield(lstate, -2, "schedule");
  // in_fast_event
  lua_pushcfunction(lstate, &nlua_in_fast_event);
  lua_setfield(lstate, -2, "in_fast_event");
  // call
  lua_pushcfunction(lstate, &nlua_call);
  lua_setfield(lstate, -2, "call");
  // regex
  lua_pushcfunction(lstate, &nlua_regex);
  lua_setfield(lstate, -2, "regex");

  luaL_newmetatable(lstate, "nvim_regex");
  luaL_register(lstate, NULL, regex_meta);
  lua_pushvalue(lstate, -1);  // [meta, meta]
  lua_setfield(lstate, -2, "__index");  // [meta]
  lua_pop(lstate, 1);  // don't use metatable now

  // rpcrequest
  lua_pushcfunction(lstate, &nlua_rpcrequest);
  lua_setfield(lstate, -2, "rpcrequest");

  // rpcnotify
  lua_pushcfunction(lstate, &nlua_rpcnotify);
  lua_setfield(lstate, -2, "rpcnotify");

  // vim.loop
  luv_set_loop(lstate, &main_loop.uv);
  luv_set_callback(lstate, nlua_luv_cfpcall);
  luaopen_luv(lstate);
  lua_pushvalue(lstate, -1);
  lua_setfield(lstate, -3, "loop");

  // package.loaded.luv = vim.loop
  // otherwise luv will be reinitialized when require'luv'
  lua_getglobal(lstate, "package");
  lua_getfield(lstate, -1, "loaded");
  lua_pushvalue(lstate, -3);
  lua_setfield(lstate, -2, "luv");
  lua_pop(lstate, 3);

  // vim.NIL
  lua_newuserdata(lstate, 0);
  lua_createtable(lstate, 0, 0);
  lua_pushcfunction(lstate, &nlua_nil_tostring);
  lua_setfield(lstate, -2, "__tostring");
  lua_setmetatable(lstate, -2);
  nlua_nil_ref = nlua_ref(lstate, -1);
  lua_setfield(lstate, -2, "NIL");

  // vim._empty_dict_mt
  lua_createtable(lstate, 0, 0);
  lua_pushcfunction(lstate, &nlua_empty_dict_tostring);
  lua_setfield(lstate, -2, "__tostring");
  nlua_empty_dict_ref = nlua_ref(lstate, -1);
  lua_setfield(lstate, -2, "_empty_dict_mt");

  // internal vim._treesitter... API
  nlua_add_treesitter(lstate);

  lua_setglobal(lstate, "vim");

  {
    const char *code = (char *)&shared_module[0];
    if (luaL_loadbuffer(lstate, code, strlen(code), "@shared.lua")
        || lua_pcall(lstate, 0, 0, 0)) {
      nlua_error(lstate, _("E5106: Error while creating shared module: %.*s"));
      return 1;
    }
  }

  {
    const char *code = (char *)&vim_module[0];
    if (luaL_loadbuffer(lstate, code, strlen(code), "@vim.lua")
        || lua_pcall(lstate, 0, 0, 0)) {
      nlua_error(lstate, _("E5106: Error while creating vim module: %.*s"));
      return 1;
    }
  }

  return 0;
}

/// Initialize lua interpreter
///
/// Crashes Nvim if initialization fails. Should be called once per lua
/// interpreter instance.
///
/// @return New lua interpreter instance.
static lua_State *nlua_init(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  lua_State *lstate = luaL_newstate();
  if (lstate == NULL) {
    EMSG(_("E970: Failed to initialize lua interpreter"));
    preserve_exit();
  }
  luaL_openlibs(lstate);
  nlua_state_init(lstate);
  return lstate;
}

/// Enter lua interpreter
///
/// Calls nlua_init() if needed. Is responsible for pre-lua call initalization
/// like updating `package.[c]path` with directories derived from &runtimepath.
///
/// @return Interpreter instance to use. Will either be initialized now or
///         taken from previous initialization.
static lua_State *nlua_enter(void)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT
{
  static lua_State *global_lstate = NULL;
  if (global_lstate == NULL) {
    global_lstate = nlua_init();
  }
  lua_State *const lstate = global_lstate;
  // Last used p_rtp value. Must not be dereferenced because value pointed to
  // may already be freed. Used to check whether &runtimepath option value
  // changed.
  static const void *last_p_rtp = NULL;
  if (last_p_rtp != (const void *)p_rtp) {
    // stack: (empty)
    lua_getglobal(lstate, "vim");
    // stack: vim
    lua_getfield(lstate, -1, "_update_package_paths");
    // stack: vim, vim._update_package_paths
    if (lua_pcall(lstate, 0, 0, 0)) {
      // stack: vim, error
      nlua_error(lstate, _("E5117: Error while updating package paths: %.*s"));
      // stack: vim
    }
    // stack: vim
    lua_pop(lstate, 1);
    // stack: (empty)
    last_p_rtp = (const void *)p_rtp;
  }
  return lstate;
}

static void nlua_print_event(void **argv)
{
  char *str = argv[0];
  const size_t len = (size_t)(intptr_t)argv[1]-1;  // exclude final NUL

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
          // TODO(bfredl): use proper multiline msg? Probably should implement
          // print() in lua in terms of nvim_message(), when it is available.
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
  if (len && str[len - 1] == NUL) {  // Last was newline
    msg((char_u *)"");
  }
  xfree(str);
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
  ga_append(&msg_ga, NUL);

  if (in_fast_callback) {
    multiqueue_put(main_loop.events, nlua_print_event,
                   2, msg_ga.ga_data, msg_ga.ga_len);
  } else {
    nlua_print_event((void *[]){ msg_ga.ga_data,
                                 (void *)(intptr_t)msg_ga.ga_len });
  }
  return 0;

nlua_print_error:
  ga_clear(&msg_ga);
  const char *fmt = _("E5114: Error while converting print argument #%i: %.*s");
  size_t len = (size_t)vim_snprintf((char *)IObuff, IOSIZE, fmt, curargidx,
                                    (int)errmsg_len, errmsg);
  lua_pushlstring(lstate, (char *)IObuff, len);
  return lua_error(lstate);
}

/// debug.debug: interaction with user while debugging.
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
    get_user_input(input_args, &input, false, false);
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
    } else if (lua_pcall(lstate, 0, 0, 0)) {
      nlua_error(lstate, _("E5116: Error while calling debug string: %.*s"));
    }
    tv_clear(&input);
  }
  return 0;
}

int nlua_in_fast_event(lua_State *lstate)
{
  lua_pushboolean(lstate, in_fast_callback > 0);
  return 1;
}

int nlua_call(lua_State *lstate)
{
  Error err = ERROR_INIT;
  size_t name_len;
  const char_u *name = (const char_u *)luaL_checklstring(lstate, 1, &name_len);
  if (!nlua_is_deferred_safe(lstate)) {
    return luaL_error(lstate, e_luv_api_disabled, "vimL function");
  }

  int nargs = lua_gettop(lstate)-1;
  if (nargs > MAX_FUNC_ARGS) {
    return luaL_error(lstate, "Function called with too many arguments");
  }

  typval_T vim_args[MAX_FUNC_ARGS + 1];
  int i = 0;  // also used for freeing the variables
  for (; i < nargs; i++) {
    lua_pushvalue(lstate, (int)i+2);
    if (!nlua_pop_typval(lstate, &vim_args[i])) {
      api_set_error(&err, kErrorTypeException,
                    "error converting argument %d", i+1);
      goto free_vim_args;
    }
  }

  TRY_WRAP({
  // TODO(bfredl): this should be simplified in error handling refactor
  force_abort = false;
  suppress_errthrow = false;
  current_exception = NULL;
  did_emsg = false;

  try_start();
  typval_T rettv;
  int dummy;
  // call_func() retval is deceptive, ignore it.  Instead we set `msg_list`
  // (TRY_WRAP) to capture abort-causing non-exception errors.
  (void)call_func(name, (int)name_len, &rettv, nargs,
                  vim_args, NULL, curwin->w_cursor.lnum, curwin->w_cursor.lnum,
                  &dummy, true, NULL, NULL);
  if (!try_end(&err)) {
    nlua_push_typval(lstate, &rettv, false);
  }
  tv_clear(&rettv);
  });

free_vim_args:
  while (i > 0) {
    tv_clear(&vim_args[--i]);
  }
  if (ERROR_SET(&err)) {
    lua_pushstring(lstate, err.msg);
    api_clear_error(&err);
    return lua_error(lstate);
  }
  return 1;
}

static int nlua_rpcrequest(lua_State *lstate)
{
  if (!nlua_is_deferred_safe(lstate)) {
    return luaL_error(lstate, e_luv_api_disabled, "rpcrequest");
  }
  return nlua_rpc(lstate, true);
}

static int nlua_rpcnotify(lua_State *lstate)
{
  return nlua_rpc(lstate, false);
}

static int nlua_rpc(lua_State *lstate, bool request)
{
  size_t name_len;
  uint64_t chan_id = (uint64_t)luaL_checkinteger(lstate, 1);
  const char *name = luaL_checklstring(lstate, 2, &name_len);
  int nargs = lua_gettop(lstate)-2;
  Error err = ERROR_INIT;
  Array args = ARRAY_DICT_INIT;

  for (int i = 0; i < nargs; i++) {
    lua_pushvalue(lstate, (int)i+3);
    ADD(args, nlua_pop_Object(lstate, false, &err));
    if (ERROR_SET(&err)) {
      api_free_array(args);
      goto check_err;
    }
  }

  if (request) {
    Object result = rpc_send_call(chan_id, name, args, &err);
    if (!ERROR_SET(&err)) {
      nlua_push_Object(lstate, result, false);
      api_free_object(result);
    }
  } else {
    if (!rpc_send_event(chan_id, name, args)) {
      api_set_error(&err, kErrorTypeValidation,
                    "Invalid channel: %"PRIu64, chan_id);
    }
  }

check_err:
  if (ERROR_SET(&err)) {
    lua_pushstring(lstate, err.msg);
    api_clear_error(&err);
    return lua_error(lstate);
  }

  return request ? 1 : 0;
}

static int nlua_nil_tostring(lua_State *lstate)
{
  lua_pushstring(lstate, "vim.NIL");
  return 1;
}

static int nlua_empty_dict_tostring(lua_State *lstate)
{
  lua_pushstring(lstate, "vim.empty_dict()");
  return 1;
}


#ifdef WIN32
/// os.getenv: override os.getenv to maintain coherency. #9681
///
/// uv_os_setenv uses SetEnvironmentVariableW which does not update _environ.
///
/// @param  lstate  Lua interpreter state.
static int nlua_getenv(lua_State *lstate)
{
  lua_pushstring(lstate, os_getenv(luaL_checkstring(lstate, 1)));
  return 1;
}
#endif

/// add the value to the registry
LuaRef nlua_ref(lua_State *lstate, int index)
{
  lua_pushvalue(lstate, index);
  return luaL_ref(lstate, LUA_REGISTRYINDEX);
}

/// remove the value from the registry
void nlua_unref(lua_State *lstate, LuaRef ref)
{
  if (ref > 0) {
    luaL_unref(lstate, LUA_REGISTRYINDEX, ref);
  }
}

void executor_free_luaref(LuaRef ref)
{
  lua_State *const lstate = nlua_enter();
  nlua_unref(lstate, ref);
}

/// push a value referenced in the regirstry
void nlua_pushref(lua_State *lstate, LuaRef ref)
{
  lua_rawgeti(lstate, LUA_REGISTRYINDEX, ref);
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
#define EVALHEADER "local _A=select(1,...) return ("
  const size_t lcmd_len = sizeof(EVALHEADER) - 1 + str.size + 1;
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = (char *)IObuff;
  } else {
    lcmd = xmalloc(lcmd_len);
  }
  memcpy(lcmd, EVALHEADER, sizeof(EVALHEADER) - 1);
  memcpy(lcmd + sizeof(EVALHEADER) - 1, str.data, str.size);
  lcmd[lcmd_len - 1] = ')';
#undef EVALHEADER
  typval_exec_lua(lcmd, lcmd_len, "luaeval()", arg, 1, true, ret_tv);

  if (lcmd != (char *)IObuff) {
    xfree(lcmd);
  }
}

void executor_call_lua(const char *str, size_t len, typval_T *const args,
                       int argcount, typval_T *ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
#define CALLHEADER "return "
#define CALLSUFFIX "(...)"
  const size_t lcmd_len = sizeof(CALLHEADER) - 1 + len + sizeof(CALLSUFFIX) - 1;
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = (char *)IObuff;
  } else {
    lcmd = xmalloc(lcmd_len);
  }
  memcpy(lcmd, CALLHEADER, sizeof(CALLHEADER) - 1);
  memcpy(lcmd + sizeof(CALLHEADER) - 1, str, len);
  memcpy(lcmd + sizeof(CALLHEADER) - 1 + len, CALLSUFFIX,
         sizeof(CALLSUFFIX) - 1);
#undef CALLHEADER
#undef CALLSUFFIX

  typval_exec_lua(lcmd, lcmd_len, "v:lua", args, argcount, false, ret_tv);

  if (lcmd != (char *)IObuff) {
    xfree(lcmd);
  }
}

static void typval_exec_lua(const char *lcmd, size_t lcmd_len, const char *name,
                            typval_T *const args, int argcount, bool special,
                            typval_T *ret_tv)
{
  if (check_restricted() || check_secure()) {
    if (ret_tv) {
      ret_tv->v_type = VAR_NUMBER;
      ret_tv->vval.v_number = 0;
    }
    return;
  }

  lua_State *const lstate = nlua_enter();
  if (luaL_loadbuffer(lstate, lcmd, lcmd_len, name)) {
    nlua_error(lstate, _("E5107: Error loading lua %.*s"));
    return;
  }

  for (int i = 0; i < argcount; i++) {
    if (args[i].v_type == VAR_UNKNOWN) {
      lua_pushnil(lstate);
    } else {
      nlua_push_typval(lstate, &args[i], special);
    }
  }
  if (lua_pcall(lstate, argcount, ret_tv ? 1 : 0, 0)) {
    nlua_error(lstate, _("E5108: Error executing lua %.*s"));
    return;
  }

  if (ret_tv) {
    nlua_pop_typval(lstate, ret_tv);
  }
}

/// Execute Lua string
///
/// Used for nvim_exec_lua().
///
/// @param[in]  str  String to execute.
/// @param[in]  args array of ... args
/// @param[out]  err  Location where error will be saved.
///
/// @return Return value of the execution.
Object executor_exec_lua_api(const String str, const Array args, Error *err)
{
  lua_State *const lstate = nlua_enter();

  if (luaL_loadbuffer(lstate, str.data, str.size, "<nvim>")) {
    size_t len;
    const char *errstr = lua_tolstring(lstate, -1, &len);
    api_set_error(err, kErrorTypeValidation,
                  "Error loading lua: %.*s", (int)len, errstr);
    return NIL;
  }

  for (size_t i = 0; i < args.size; i++) {
    nlua_push_Object(lstate, args.items[i], false);
  }

  if (lua_pcall(lstate, (int)args.size, 1, 0)) {
    size_t len;
    const char *errstr = lua_tolstring(lstate, -1, &len);
    api_set_error(err, kErrorTypeException,
                  "Error executing lua: %.*s", (int)len, errstr);
    return NIL;
  }

  return nlua_pop_Object(lstate, false, err);
}

Object executor_exec_lua_cb(LuaRef ref, const char *name, Array args,
                            bool retval, Error *err)
{
  lua_State *const lstate = nlua_enter();
  nlua_pushref(lstate, ref);
  lua_pushstring(lstate, name);
  for (size_t i = 0; i < args.size; i++) {
    nlua_push_Object(lstate, args.items[i], false);
  }

  if (lua_pcall(lstate, (int)args.size+1, retval ? 1 : 0, 0)) {
    // if err is passed, the caller will deal with the error.
    if (err) {
      size_t len;
      const char *errstr = lua_tolstring(lstate, -1, &len);
      api_set_error(err, kErrorTypeException,
                    "Error executing lua: %.*s", (int)len, errstr);
    } else {
      nlua_error(lstate, _("Error executing lua callback: %.*s"));
    }
    return NIL;
  }

  if (retval) {
    Error dummy = ERROR_INIT;
    if (err == NULL) {
      err = &dummy;
    }
    return nlua_pop_Object(lstate, false, err);
  } else {
    return NIL;
  }
}

/// check if the current execution context is safe for calling deferred API
/// methods. Luv callbacks are unsafe as they are called inside the uv loop.
bool nlua_is_deferred_safe(lua_State *lstate)
{
  return in_fast_callback == 0;
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
  typval_exec_lua(code, len, ":lua", NULL, 0, false, NULL);

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
  if (u_save(eap->line1 - 1, eap->line2 + 1) == FAIL) {
    EMSG(_("cannot save undo information"));
    return;
  }
  const char *const cmd = (const char *)eap->arg;
  const size_t cmd_len = strlen(cmd);

  lua_State *const lstate = nlua_enter();

#define DOSTART "return function(line, linenr) "
#define DOEND " end"
  const size_t lcmd_len = (cmd_len
                           + (sizeof(DOSTART) - 1)
                           + (sizeof(DOEND) - 1));
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = (char *)IObuff;
  } else {
    lcmd = xmalloc(lcmd_len + 1);
  }
  memcpy(lcmd, DOSTART, sizeof(DOSTART) - 1);
  memcpy(lcmd + sizeof(DOSTART) - 1, cmd, cmd_len);
  memcpy(lcmd + sizeof(DOSTART) - 1 + cmd_len, DOEND, sizeof(DOEND) - 1);
#undef DOSTART
#undef DOEND

  if (luaL_loadbuffer(lstate, lcmd, lcmd_len, ":luado")) {
    nlua_error(lstate, _("E5109: Error loading lua: %.*s"));
    if (lcmd_len >= IOSIZE) {
      xfree(lcmd);
    }
    return;
  }
  if (lcmd_len >= IOSIZE) {
    xfree(lcmd);
  }
  if (lua_pcall(lstate, 0, 1, 0)) {
    nlua_error(lstate, _("E5110: Error executing lua: %.*s"));
    return;
  }
  for (linenr_T l = eap->line1; l <= eap->line2; l++) {
    if (l > curbuf->b_ml.ml_line_count) {
      break;
    }
    lua_pushvalue(lstate, -1);
    lua_pushstring(lstate, (const char *)ml_get_buf(curbuf, l, false));
    lua_pushnumber(lstate, (lua_Number)l);
    if (lua_pcall(lstate, 2, 1, 0)) {
      nlua_error(lstate, _("E5111: Error calling lua: %.*s"));
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
}

/// Run lua file
///
/// Used for :luafile.
///
/// @param  eap  VimL command being run.
void ex_luafile(exarg_T *const eap)
  FUNC_ATTR_NONNULL_ALL
{
  lua_State *const lstate = nlua_enter();

  if (luaL_loadfile(lstate, (const char *)eap->arg)) {
    nlua_error(lstate, _("E5112: Error while creating lua chunk: %.*s"));
    return;
  }

  if (lua_pcall(lstate, 0, 0, 0)) {
    nlua_error(lstate, _("E5113: Error while calling lua chunk: %.*s"));
    return;
  }
}

static int create_tslua_parser(lua_State *L)
{
  if (lua_gettop(L) < 1 || !lua_isstring(L, 1)) {
    return luaL_error(L, "string expected");
  }

  const char *lang_name = lua_tostring(L, 1);
  return tslua_push_parser(L, lang_name);
}

static void nlua_add_treesitter(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  tslua_init(lstate);

  lua_pushcfunction(lstate, create_tslua_parser);
  lua_setfield(lstate, -2, "_create_ts_parser");

  lua_pushcfunction(lstate, tslua_add_language);
  lua_setfield(lstate, -2, "_ts_add_language");

  lua_pushcfunction(lstate, tslua_has_language);
  lua_setfield(lstate, -2, "_ts_has_language");

  lua_pushcfunction(lstate, tslua_inspect_lang);
  lua_setfield(lstate, -2, "_ts_inspect_language");

  lua_pushcfunction(lstate, ts_lua_parse_query);
  lua_setfield(lstate, -2, "_ts_parse_query");
}

static int nlua_regex(lua_State *lstate)
{
  Error err = ERROR_INIT;
  const char *text = luaL_checkstring(lstate, 1);
  regprog_T *prog = NULL;

  TRY_WRAP({
    try_start();
    prog = vim_regcomp((char_u *)text, RE_AUTO | RE_MAGIC | RE_STRICT);
    try_end(&err);
  });

  if (ERROR_SET(&err)) {
    return luaL_error(lstate, "couldn't parse regex: %s", err.msg);
  }
  assert(prog);

  regprog_T **p = lua_newuserdata(lstate, sizeof(regprog_T *));
  *p = prog;

  lua_getfield(lstate, LUA_REGISTRYINDEX, "nvim_regex");  // [udata, meta]
  lua_setmetatable(lstate, -2);  // [udata]
  return 1;
}

static regprog_T **regex_check(lua_State *L)
{
  return luaL_checkudata(L, 1, "nvim_regex");
}


static int regex_gc(lua_State *lstate)
{
  regprog_T **prog = regex_check(lstate);
  vim_regfree(*prog);
  return 0;
}

static int regex_tostring(lua_State *lstate)
{
  lua_pushstring(lstate, "<regex>");
  return 1;
}

static int regex_match(lua_State *lstate, regprog_T **prog, char_u *str)
{
  regmatch_T rm;
  rm.regprog = *prog;
  rm.rm_ic = false;
  bool match = vim_regexec(&rm, str, 0);
  *prog = rm.regprog;

  if (match) {
    lua_pushinteger(lstate, (lua_Integer)(rm.startp[0]-str));
    lua_pushinteger(lstate, (lua_Integer)(rm.endp[0]-str));
    return 2;
  }
  return 0;
}

static int regex_match_str(lua_State *lstate)
{
  regprog_T **prog = regex_check(lstate);
  const char *str = luaL_checkstring(lstate, 2);
  int nret = regex_match(lstate, prog, (char_u *)str);

  if (!*prog) {
    return luaL_error(lstate, "regex: internal error");
  }

  return nret;
}

static int regex_match_line(lua_State *lstate)
{
  regprog_T **prog = regex_check(lstate);

  int narg = lua_gettop(lstate);
  if (narg < 3) {
    return luaL_error(lstate, "not enough args");
  }

  long bufnr = luaL_checkinteger(lstate, 2);
  long rownr = luaL_checkinteger(lstate, 3);
  long start = 0, end = -1;
  if (narg >= 4) {
    start = luaL_checkinteger(lstate, 4);
  }
  if (narg >= 5) {
    end = luaL_checkinteger(lstate, 5);
    if (end < 0) {
      return luaL_error(lstate, "invalid end");
    }
  }

  buf_T *buf = bufnr ? handle_get_buffer((int)bufnr) : curbuf;
  if (!buf || buf->b_ml.ml_mfp == NULL) {
    return luaL_error(lstate, "invalid buffer");
  }

  if (rownr >= buf->b_ml.ml_line_count) {
    return luaL_error(lstate, "invalid row");
  }

  char_u *line = ml_get_buf(buf, rownr+1, false);
  size_t len = STRLEN(line);

  if (start < 0 || (size_t)start > len) {
    return luaL_error(lstate, "invalid start");
  }

  char_u save = NUL;
  if (end >= 0) {
    if ((size_t)end > len || end < start) {
      return luaL_error(lstate, "invalid end");
    }
    save = line[end];
    line[end] = NUL;
  }

  int nret = regex_match(lstate, prog, line+start);

  if (end >= 0) {
    line[end] = save;
  }

  if (!*prog) {
    return luaL_error(lstate, "regex: internal error");
  }

  return nret;
}
