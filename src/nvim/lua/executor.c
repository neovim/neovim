#include <assert.h>
#include <inttypes.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tree_sitter/api.h>
#include <uv.h>

#include "klib/kvec.h"
#include "luv/luv.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/ui.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/time.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_getln.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/keycodes.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/stdlib.h"
#include "nvim/lua/treesitter.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/message_defs.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/option_vars.h"
#include "nvim/os/fileio.h"
#include "nvim/os/fileio_defs.h"
#include "nvim/os/os.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/usercmd.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifndef MSWIN
# include <pthread.h>
#endif

static int in_fast_callback = 0;
static bool in_script = false;

// Initialized in nlua_init().
static lua_State *global_lstate = NULL;

static LuaRef require_ref = LUA_REFNIL;

static uv_thread_t main_thread;

typedef struct {
  Error err;
  String lua_err_str;
} LuaError;

typedef struct {
  char *name;
  const uint8_t *data;
  size_t size;
} ModuleDef;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/executor.c.generated.h"
# include "lua/vim_module.generated.h"
#endif

#define PUSH_ALL_TYPVALS(lstate, args, argcount, special) \
  for (int i = 0; i < argcount; i++) { \
    if (args[i].v_type == VAR_UNKNOWN) { \
      lua_pushnil(lstate); \
    } else { \
      nlua_push_typval(lstate, &args[i], (special) ? kNluaPushSpecial : 0); \
    } \
  }

#if __has_feature(address_sanitizer)
static bool nlua_track_refs = false;
# define NLUA_TRACK_REFS
#endif

typedef enum luv_err_type {
  kCallback,
  kThread,
  kThreadCallback,
} luv_err_t;

lua_State *get_global_lstate(void)
{
  return global_lstate;
}

/// Convert lua error into a Vim error message
///
/// @param  lstate  Lua interpreter state.
/// @param[in]  msg  Message base, must contain one `%.*s`.
void nlua_error(lua_State *const lstate, const char *const msg)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len;
  const char *str = NULL;

  if (luaL_getmetafield(lstate, -1, "__tostring")) {
    if (lua_isfunction(lstate, -1) && luaL_callmeta(lstate, -2, "__tostring")) {
      // call __tostring, convert the result and pop result.
      str = lua_tolstring(lstate, -1, &len);
      lua_pop(lstate, 1);
    }
    // pop __tostring.
    lua_pop(lstate, 1);
  }

  if (!str) {
    // defer to lua default conversion, this will render tables as [NULL].
    str = lua_tolstring(lstate, -1, &len);
  }

  if (in_script) {
    fprintf(stderr, msg, (int)len, str);
    fprintf(stderr, "\n");
  } else {
    msg_ext_set_kind("lua_error");
    semsg_multiline(msg, (int)len, str);
  }

  lua_pop(lstate, 1);
}

/// Like lua_pcall, but use debug.traceback as errfunc.
///
/// @param lstate Lua interpreter state
/// @param[in] nargs Number of arguments expected by the function being called.
/// @param[in] nresults Number of results the function returns.
int nlua_pcall(lua_State *lstate, int nargs, int nresults)
{
  lua_getglobal(lstate, "debug");
  lua_getfield(lstate, -1, "traceback");
  lua_remove(lstate, -2);
  lua_insert(lstate, -2 - nargs);
  int status = lua_pcall(lstate, nargs, nresults, -2 - nargs);
  if (status) {
    lua_remove(lstate, -2);
  } else {
    lua_remove(lstate, -1 - nresults);
  }
  return status;
}

static void nlua_luv_error_event(void **argv)
{
  char *error = (char *)argv[0];
  luv_err_t type = (luv_err_t)(intptr_t)argv[1];
  msg_ext_set_kind("lua_error");
  switch (type) {
  case kCallback:
    semsg_multiline("Error executing callback:\n%s", error);
    break;
  case kThread:
    semsg_multiline("Error in luv thread:\n%s", error);
    break;
  case kThreadCallback:
    semsg_multiline("Error in luv callback, thread:\n%s", error);
    break;
  default:
    break;
  }
  xfree(error);
}

/// Execute callback in "fast" context. Used for luv and some vim.ui_event
/// callbacks where using the API directly is not safe.
static int nlua_fast_cfpcall(lua_State *lstate, int nargs, int nresult, int flags)
  FUNC_ATTR_NONNULL_ALL
{
  int retval;

  in_fast_callback++;

  int top = lua_gettop(lstate);
  int status = nlua_pcall(lstate, nargs, nresult);
  if (status) {
    if (status == LUA_ERRMEM && !(flags & LUVF_CALLBACK_NOEXIT)) {
      // consider out of memory errors unrecoverable, just like xmalloc()
      preserve_exit(e_outofmem);
    }
    const char *error = lua_tostring(lstate, -1);

    multiqueue_put(main_loop.events, nlua_luv_error_event,
                   error != NULL ? xstrdup(error) : NULL, (void *)(intptr_t)kCallback);
    lua_pop(lstate, 1);  // error message
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

static int nlua_luv_thread_cb_cfpcall(lua_State *lstate, int nargs, int nresult, int flags)
{
  return nlua_luv_thread_common_cfpcall(lstate, nargs, nresult, flags, true);
}

static int nlua_luv_thread_cfpcall(lua_State *lstate, int nargs, int nresult, int flags)
  FUNC_ATTR_NONNULL_ALL
{
  return nlua_luv_thread_common_cfpcall(lstate, nargs, nresult, flags, false);
}

static int nlua_luv_thread_cfcpcall(lua_State *lstate, lua_CFunction func, void *ud, int flags)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  lua_pushcfunction(lstate, func);
  lua_pushlightuserdata(lstate, ud);
  int retval = nlua_luv_thread_cfpcall(lstate, 1, 0, flags);
  return retval;
}

static int nlua_luv_thread_common_cfpcall(lua_State *lstate, int nargs, int nresult, int flags,
                                          bool is_callback)
  FUNC_ATTR_NONNULL_ALL
{
  int retval;

  int top = lua_gettop(lstate);
  int status = lua_pcall(lstate, nargs, nresult, 0);
  if (status) {
    if (status == LUA_ERRMEM && !(flags & LUVF_CALLBACK_NOEXIT)) {
      // Terminate this thread, as the main thread may be able to continue
      // execution.
      fprintf(stderr, "%s\n", e_outofmem);
      lua_close(lstate);
#ifdef MSWIN
      ExitThread(0);
#else
      pthread_exit(0);
#endif
    }
    const char *error = lua_tostring(lstate, -1);
    loop_schedule_deferred(&main_loop,
                           event_create(nlua_luv_error_event,
                                        error != NULL ? xstrdup(error) : NULL,
                                        (void *)(intptr_t)(is_callback
                                                           ? kThreadCallback
                                                           : kThread)));
    lua_pop(lstate, 1);  // error message
    retval = -status;
  } else {  // LUA_OK
    if (nresult == LUA_MULTRET) {
      nresult = lua_gettop(lstate) - top + nargs + 1;
    }
    retval = nresult;
  }

  return retval;
}

static int nlua_thr_api_nvim__get_runtime(lua_State *lstate)
{
  if (lua_gettop(lstate) != 3) {
    return luaL_error(lstate, "Expected 3 arguments");
  }

  luaL_checktype(lstate, -1, LUA_TTABLE);
  lua_getfield(lstate, -1, "is_lua");
  if (!lua_isboolean(lstate, -1)) {
    return luaL_error(lstate, "is_lua is not a boolean");
  }
  bool is_lua = lua_toboolean(lstate, -1);
  lua_pop(lstate, 2);

  luaL_checktype(lstate, -1, LUA_TBOOLEAN);
  bool all = lua_toboolean(lstate, -1);
  lua_pop(lstate, 1);

  Error err = ERROR_INIT;
  // TODO(bfredl): we could use an arena here for both "pat" and "ret", but then
  // we need a path to not use the freelist but a private block local to the thread.
  // We do not want mutex contentionery for the main arena freelist.
  const Array pat = nlua_pop_Array(lstate, NULL, &err);
  if (ERROR_SET(&err)) {
    luaL_where(lstate, 1);
    lua_pushstring(lstate, err.msg);
    api_clear_error(&err);
    lua_concat(lstate, 2);
    return lua_error(lstate);
  }

  ArrayOf(String) ret = runtime_get_named_thread(is_lua, pat, all);
  nlua_push_Array(lstate, ret, kNluaPushSpecial);
  api_free_array(ret);
  api_free_array(pat);

  return 1;
}

/// Copies args starting at `lua_arg0` to Lua `_G.arg`, and sets `_G.arg[0]` to the scriptname.
///
/// Example (arg[0] => "foo.lua", arg[1] => "--arg1", …):
///     nvim -l foo.lua --arg1 --arg2
///
/// @note Lua CLI sets args before "-e" as _negative_ `_G.arg` indices, but we currently don't.
///
/// @see https://www.lua.org/pil/1.4.html
/// @see https://github.com/premake/premake-core/blob/1c1304637f4f5e50ba8c57aae8d1d80ec3b7aaf2/src/host/premake.c#L563-L594
///
/// @returns number of args
static int nlua_init_argv(lua_State *const L, char **argv, int argc, int lua_arg0)
{
  int i = 0;
  lua_newtable(L);  // _G.arg

  if (lua_arg0 > 0) {
    lua_pushstring(L, argv[lua_arg0 - 1]);
    lua_rawseti(L, -2, 0);  // _G.arg[0] = "foo.lua"

    for (; i + lua_arg0 < argc; i++) {
      lua_pushstring(L, argv[i + lua_arg0]);
      lua_rawseti(L, -2, i + 1);  // _G.arg[i+1] = "--foo"
    }
  }

  lua_setglobal(L, "arg");
  return i;
}

static void nlua_schedule_event(void **argv)
{
  LuaRef cb = (LuaRef)(ptrdiff_t)argv[0];
  uint32_t ns_id = (uint32_t)(ptrdiff_t)argv[1];
  lua_State *const lstate = global_lstate;
  nlua_pushref(lstate, cb);
  nlua_unref_global(lstate, cb);
  if (nlua_pcall(lstate, 0, 0)) {
    nlua_error(lstate, _("Error executing vim.schedule lua callback: %.*s"));
    ui_remove_cb(ns_id, true);
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

  // If main_loop is closing don't schedule tasks to run in the future,
  // otherwise any refs allocated here will not be cleaned up.
  if (main_loop.closing) {
    return 0;
  }

  LuaRef cb = nlua_ref_global(lstate, 1);
  // Pass along UI event handler to disable on error.
  multiqueue_put(main_loop.events, nlua_schedule_event, (void *)(ptrdiff_t)cb,
                 (void *)(ptrdiff_t)ui_event_ns_id);
  return 0;
}

// Dummy timer callback. Used by f_wait().
static void dummy_timer_due_cb(TimeWatcher *tw, void *data)
{
}

// Dummy timer close callback. Used by f_wait().
static void dummy_timer_close_cb(TimeWatcher *tw, void *data)
{
  xfree(tw);
}

static bool nlua_wait_condition(lua_State *lstate, int *status, bool *callback_result)
{
  lua_pushvalue(lstate, 2);
  *status = nlua_pcall(lstate, 0, 1);
  if (*status) {
    return true;  // break on error, but keep error on stack
  }
  *callback_result = lua_toboolean(lstate, -1);
  lua_pop(lstate, 1);
  return *callback_result;  // break if true
}

/// "vim.wait(timeout, condition[, interval])" function
static int nlua_wait(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  if (in_fast_callback) {
    return luaL_error(lstate, e_fast_api_disabled, "vim.wait");
  }

  intptr_t timeout = luaL_checkinteger(lstate, 1);
  if (timeout < 0) {
    return luaL_error(lstate, "timeout must be >= 0");
  }

  int lua_top = lua_gettop(lstate);

  // Check if condition can be called.
  bool is_function = false;
  if (lua_top >= 2 && !lua_isnil(lstate, 2)) {
    is_function = (lua_type(lstate, 2) == LUA_TFUNCTION);

    // Check if condition is callable table
    if (!is_function && luaL_getmetafield(lstate, 2, "__call") != 0) {
      is_function = (lua_type(lstate, -1) == LUA_TFUNCTION);
      lua_pop(lstate, 1);
    }

    if (!is_function) {
      lua_pushliteral(lstate,
                      "vim.wait: if passed, condition must be a function");
      return lua_error(lstate);
    }
  }

  intptr_t interval = 200;
  if (lua_top >= 3 && !lua_isnil(lstate, 3)) {
    interval = luaL_checkinteger(lstate, 3);
    if (interval < 0) {
      return luaL_error(lstate, "interval must be >= 0");
    }
  }

  bool fast_only = false;
  if (lua_top >= 4) {
    fast_only = lua_toboolean(lstate, 4);
  }

  MultiQueue *loop_events = fast_only ? main_loop.fast_events : main_loop.events;

  TimeWatcher *tw = xmalloc(sizeof(TimeWatcher));

  // Start dummy timer.
  time_watcher_init(&main_loop, tw, NULL);
  tw->events = loop_events;
  tw->blockable = true;
  time_watcher_start(tw,
                     dummy_timer_due_cb,
                     (uint64_t)interval,
                     (uint64_t)interval);

  int pcall_status = 0;
  bool callback_result = false;

  // Flush screen updates before blocking.
  ui_flush();

  LOOP_PROCESS_EVENTS_UNTIL(&main_loop,
                            loop_events,
                            (int)timeout,
                            got_int || (is_function ? nlua_wait_condition(lstate,
                                                                          &pcall_status,
                                                                          &callback_result)
                                                    : false));

  // Stop dummy timer
  time_watcher_stop(tw);
  time_watcher_close(tw, dummy_timer_close_cb);

  if (pcall_status) {
    return lua_error(lstate);
  } else if (callback_result) {
    lua_pushboolean(lstate, 1);
    lua_pushnil(lstate);
  } else if (got_int) {
    got_int = false;
    vgetc();
    lua_pushboolean(lstate, 0);
    lua_pushinteger(lstate, -2);
  } else {
    lua_pushboolean(lstate, 0);
    lua_pushinteger(lstate, -1);
  }

  return 2;
}

static nlua_ref_state_t *nlua_new_ref_state(lua_State *lstate, bool is_thread)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_ref_state_t *ref_state = lua_newuserdata(lstate, sizeof(*ref_state));
  CLEAR_POINTER(ref_state);
  ref_state->nil_ref = LUA_NOREF;
  ref_state->empty_dict_ref = LUA_NOREF;
  if (!is_thread) {
    nlua_global_refs = ref_state;
  }
  return ref_state;
}

static nlua_ref_state_t *nlua_get_ref_state(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  lua_getfield(lstate, LUA_REGISTRYINDEX, "nlua.ref_state");
  nlua_ref_state_t *ref_state = lua_touserdata(lstate, -1);
  lua_pop(lstate, 1);

  return ref_state;
}

LuaRef nlua_get_nil_ref(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_ref_state_t *ref_state = nlua_get_ref_state(lstate);
  return ref_state->nil_ref;
}

LuaRef nlua_get_empty_dict_ref(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_ref_state_t *ref_state = nlua_get_ref_state(lstate);
  return ref_state->empty_dict_ref;
}

int nlua_get_global_ref_count(void)
{
  return nlua_global_refs->ref_count;
}

static void nlua_common_vim_init(lua_State *lstate, bool is_thread, bool is_standalone)
  FUNC_ATTR_NONNULL_ARG(1)
{
  nlua_ref_state_t *ref_state = nlua_new_ref_state(lstate, is_thread);
  lua_setfield(lstate, LUA_REGISTRYINDEX, "nlua.ref_state");

  // vim.is_thread
  lua_pushboolean(lstate, is_thread);
  lua_setfield(lstate, LUA_REGISTRYINDEX, "nvim.thread");
  lua_pushcfunction(lstate, &nlua_is_thread);
  lua_setfield(lstate, -2, "is_thread");

  // vim.NIL
  lua_newuserdata(lstate, 0);
  lua_createtable(lstate, 0, 0);
  lua_pushcfunction(lstate, &nlua_nil_tostring);
  lua_setfield(lstate, -2, "__tostring");
  lua_setmetatable(lstate, -2);
  ref_state->nil_ref = nlua_ref(lstate,  ref_state, -1);
  lua_pushvalue(lstate, -1);
  lua_setfield(lstate, LUA_REGISTRYINDEX, "mpack.NIL");
  lua_setfield(lstate, -2, "NIL");

  // vim._empty_dict_mt
  lua_createtable(lstate, 0, 0);
  lua_pushcfunction(lstate, &nlua_empty_dict_tostring);
  lua_setfield(lstate, -2, "__tostring");
  ref_state->empty_dict_ref = nlua_ref(lstate, ref_state, -1);
  lua_pushvalue(lstate, -1);
  lua_setfield(lstate, LUA_REGISTRYINDEX, "mpack.empty_dict");
  lua_setfield(lstate, -2, "_empty_dict_mt");

  // vim.uv
  if (is_standalone) {
    // do nothing, use libluv like in a standalone interpreter
  } else if (is_thread) {
    luv_set_callback(lstate, nlua_luv_thread_cb_cfpcall);
    luv_set_thread(lstate, nlua_luv_thread_cfpcall);
    luv_set_cthread(lstate, nlua_luv_thread_cfcpcall);
  } else {
    luv_set_loop(lstate, &main_loop.uv);
    luv_set_callback(lstate, nlua_fast_cfpcall);
  }
  luaopen_luv(lstate);
  lua_pushvalue(lstate, -1);
  lua_setfield(lstate, -3, "uv");

  lua_pushvalue(lstate, -1);
  lua_setfield(lstate, -3, "loop");  // deprecated

  // package.loaded.luv = vim.uv
  // otherwise luv will be reinitialized when require'luv'
  lua_getglobal(lstate, "package");
  lua_getfield(lstate, -1, "loaded");
  lua_pushvalue(lstate, -3);
  lua_setfield(lstate, -2, "luv");
  lua_pop(lstate, 3);
}

static int nlua_module_preloader(lua_State *lstate)
{
  size_t i = (size_t)lua_tointeger(lstate, lua_upvalueindex(1));
  ModuleDef def = builtin_modules[i];
  char name[256];
  name[0] = '@';
  size_t off = xstrlcpy(name + 1, def.name, (sizeof name) - 2);
  strchrsub(name + 1, '.', '/');
  xstrlcpy(name + 1 + off, ".lua", (sizeof name) - 2 - off);

  if (luaL_loadbuffer(lstate, (const char *)def.data, def.size - 1, name)) {
    return lua_error(lstate);
  }

  lua_call(lstate, 0, 1);  // propagates error to caller
  return 1;
}

static bool nlua_init_packages(lua_State *lstate, bool is_standalone)
  FUNC_ATTR_NONNULL_ALL
{
  // put builtin packages in preload
  lua_getglobal(lstate, "package");  // [package]
  lua_getfield(lstate, -1, "preload");  // [package, preload]
  for (size_t i = 0; i < ARRAY_SIZE(builtin_modules); i++) {
    ModuleDef def = builtin_modules[i];
    lua_pushinteger(lstate, (lua_Integer)i);  // [package, preload, i]
    lua_pushcclosure(lstate, nlua_module_preloader, 1);  // [package, preload, cclosure]
    lua_setfield(lstate, -2, def.name);  // [package, preload]

    if ((nlua_disable_preload && !is_standalone) && strequal(def.name, "vim.inspect")) {
      break;
    }
  }

  lua_pop(lstate, 2);  // []

  lua_getglobal(lstate, "require");
  lua_pushstring(lstate, "vim._init_packages");
  if (nlua_pcall(lstate, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(lstate, -1));
    return false;
  }

  return true;
}

/// "vim.ui_attach(ns_id, {ext_foo=true}, cb)" function
static int nlua_ui_attach(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  uint32_t ns_id = (uint32_t)luaL_checkinteger(lstate, 1);

  if (!ns_initialized(ns_id)) {
    return luaL_error(lstate, "invalid ns_id");
  }
  if (!lua_istable(lstate, 2)) {
    return luaL_error(lstate, "ext_widgets must be a table");
  }
  if (!lua_isfunction(lstate, 3)) {
    return luaL_error(lstate, "callback must be a Lua function");
  }

  bool ext_widgets[kUIGlobalCount] = { false };
  bool tbl_has_true_val = false;

  lua_pushvalue(lstate, 2);
  lua_pushnil(lstate);
  while (lua_next(lstate, -2)) {
    // [dict, key, val]
    size_t len;
    const char *s = lua_tolstring(lstate, -2, &len);
    bool val = lua_toboolean(lstate, -1);

    for (size_t i = 0; i < kUIGlobalCount; i++) {
      if (strequal(s, ui_ext_names[i])) {
        if (val) {
          tbl_has_true_val = true;
        }
        ext_widgets[i] = val;
        goto ok;
      }
    }

    return luaL_error(lstate, "Unexpected key: %s", s);
ok:
    lua_pop(lstate, 1);
  }

  if (!tbl_has_true_val) {
    return luaL_error(lstate, "ext_widgets table must contain at least one 'true' value");
  }

  LuaRef ui_event_cb = nlua_ref_global(lstate, 3);
  ui_add_cb(ns_id, ui_event_cb, ext_widgets);
  return 0;
}

/// "vim.ui_detach(ns_id)" function
static int nlua_ui_detach(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  uint32_t ns_id = (uint32_t)luaL_checkinteger(lstate, 1);

  if (!ns_initialized(ns_id)) {
    return luaL_error(lstate, "invalid ns_id");
  }

  ui_remove_cb(ns_id, false);
  return 0;
}

/// Initialize lua interpreter state
///
/// Called by lua interpreter itself to initialize state.
static bool nlua_state_init(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  // print
  lua_pushcfunction(lstate, &nlua_print);
  lua_setglobal(lstate, "print");

  // debug.debug
  lua_getglobal(lstate, "debug");
  lua_pushcfunction(lstate, &nlua_debug);
  lua_setfield(lstate, -2, "debug");
  lua_pop(lstate, 1);

#ifdef MSWIN
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

  // schedule
  lua_pushcfunction(lstate, &nlua_schedule);
  lua_setfield(lstate, -2, "schedule");

  // in_fast_event
  lua_pushcfunction(lstate, &nlua_in_fast_event);
  lua_setfield(lstate, -2, "in_fast_event");

  // call
  lua_pushcfunction(lstate, &nlua_call);
  lua_setfield(lstate, -2, "call");

  // rpcrequest
  lua_pushcfunction(lstate, &nlua_rpcrequest);
  lua_setfield(lstate, -2, "rpcrequest");

  // rpcnotify
  lua_pushcfunction(lstate, &nlua_rpcnotify);
  lua_setfield(lstate, -2, "rpcnotify");

  // wait
  lua_pushcfunction(lstate, &nlua_wait);
  lua_setfield(lstate, -2, "wait");

  // ui_attach
  lua_pushcfunction(lstate, &nlua_ui_attach);
  lua_setfield(lstate, -2, "ui_attach");

  // ui_detach
  lua_pushcfunction(lstate, &nlua_ui_detach);
  lua_setfield(lstate, -2, "ui_detach");

  nlua_common_vim_init(lstate, false, false);

  // patch require() (only for --startuptime)
  if (time_fd != NULL) {
    lua_getglobal(lstate, "require");
    // Must do this after nlua_common_vim_init where nlua_global_refs is initialized.
    require_ref = nlua_ref_global(lstate, -1);
    lua_pop(lstate, 1);
    lua_pushcfunction(lstate, &nlua_require);
    lua_setglobal(lstate, "require");
  }

  // internal vim._treesitter... API
  nlua_add_treesitter(lstate);

  nlua_state_add_stdlib(lstate, false);

  lua_setglobal(lstate, "vim");

  if (!nlua_init_packages(lstate, false)) {
    return false;
  }

  return true;
}

/// Initializes global Lua interpreter, or exits Nvim on failure.
void nlua_init(char **argv, int argc, int lua_arg0)
{
#ifdef NLUA_TRACK_REFS
  const char *env = os_getenv("NVIM_LUA_NOTRACK");
  if (!env || !*env) {
    nlua_track_refs = true;
  }
#endif

  lua_State *lstate = luaL_newstate();
  if (lstate == NULL) {
    fprintf(stderr, _("E970: Failed to initialize lua interpreter\n"));
    os_exit(1);
  }
  luaL_openlibs(lstate);
  if (!nlua_state_init(lstate)) {
    fprintf(stderr, _("E970: Failed to initialize builtin lua modules\n"));
#ifdef EXITFREE
    nlua_common_free_all_mem(lstate);
#endif
    os_exit(1);
  }

  luv_set_thread_cb(nlua_thread_acquire_vm, nlua_common_free_all_mem);
  global_lstate = lstate;
  main_thread = uv_thread_self();
  nlua_init_argv(lstate, argv, argc, lua_arg0);
}

static lua_State *nlua_thread_acquire_vm(void)
{
  return nlua_init_state(true);
}

void nlua_run_script(char **argv, int argc, int lua_arg0)
  FUNC_ATTR_NORETURN
{
  in_script = true;
  global_lstate = nlua_init_state(false);
  luv_set_thread_cb(nlua_thread_acquire_vm, nlua_common_free_all_mem);
  nlua_init_argv(global_lstate, argv, argc, lua_arg0);
  bool lua_ok = nlua_exec_file(argv[lua_arg0 - 1]);
#ifdef EXITFREE
  nlua_free_all_mem();
#endif
  exit(lua_ok ? 0 : 1);
}

static lua_State *nlua_init_state(bool thread)
{
  // If it is called from the main thread, it will attempt to rebuild the cache.
  const uv_thread_t self = uv_thread_self();
  if (!in_script && uv_thread_equal(&main_thread, &self)) {
    runtime_search_path_validate();
  }

  lua_State *lstate = luaL_newstate();

  // Add in the lua standard libraries
  luaL_openlibs(lstate);

  if (!in_script) {
    // print
    lua_pushcfunction(lstate, &nlua_print);
    lua_setglobal(lstate, "print");
  }

  lua_pushinteger(lstate, 0);
  lua_setfield(lstate, LUA_REGISTRYINDEX, "nlua.refcount");

  // vim
  lua_newtable(lstate);

  nlua_common_vim_init(lstate, thread, in_script);

  nlua_state_add_stdlib(lstate, true);

  if (!in_script) {
    lua_createtable(lstate, 0, 0);
    lua_pushcfunction(lstate, nlua_thr_api_nvim__get_runtime);
    lua_setfield(lstate, -2, "nvim__get_runtime");
    lua_setfield(lstate, -2, "api");
  }

  lua_setglobal(lstate, "vim");

  nlua_init_packages(lstate, in_script);

  lua_getglobal(lstate, "package");
  lua_getfield(lstate, -1, "loaded");
  lua_getglobal(lstate, "vim");
  lua_setfield(lstate, -2, "vim");
  lua_pop(lstate, 2);

  return lstate;
}

void nlua_free_all_mem(void)
{
  if (!global_lstate) {
    return;
  }
  lua_State *lstate = global_lstate;
  nlua_unref_global(lstate, require_ref);
  nlua_common_free_all_mem(lstate);
  tslua_free();
}

static void nlua_common_free_all_mem(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_ref_state_t *ref_state = nlua_get_ref_state(lstate);
  nlua_unref(lstate, ref_state, ref_state->nil_ref);
  nlua_unref(lstate, ref_state, ref_state->empty_dict_ref);

#ifdef NLUA_TRACK_REFS
  if (ref_state->ref_count) {
    fprintf(stderr, "%d lua references were leaked!", ref_state->ref_count);
  }

  if (nlua_track_refs) {
    // in case there are leaked luarefs, leak the associated memory
    // to get LeakSanitizer stacktraces on exit
    map_destroy(int, &ref_state->ref_markers);
  }
#endif

  lua_close(lstate);
}

static void nlua_print_event(void **argv)
{
  HlMessage msg = KV_INITIAL_VALUE;
  HlMessageChunk chunk = { { .data = argv[0], .size = (size_t)(intptr_t)argv[1] - 1 }, 0 };
  kv_push(msg, chunk);
  msg_multihl(msg, "lua_print", true, false);
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
    // Do not use nlua_pcall here to avoid duplicate stack trace information
    if (lua_pcall(lstate, 1, 1, 0)) {
      errmsg = lua_tolstring(lstate, -1, &errmsg_len);
      goto nlua_print_error;
    }
    size_t len;
    const char *const s = lua_tolstring(lstate, -1, &len);
    if (s == NULL) {
      PRINT_ERROR("<Unknown error: lua_tolstring returned NULL for tostring result>");
    }
    ga_concat_len(&msg_ga, s, len);
    if (curargidx < nargs) {
      ga_append(&msg_ga, ' ');
    }
    lua_pop(lstate, 1);
  }
#undef PRINT_ERROR
  ga_append(&msg_ga, NUL);

  lua_getfield(lstate, LUA_REGISTRYINDEX, "nvim.thread");
  bool is_thread = lua_toboolean(lstate, -1);
  lua_pop(lstate, 1);

  if (is_thread) {
    loop_schedule_deferred(&main_loop,
                           event_create(nlua_print_event,
                                        msg_ga.ga_data,
                                        (void *)(intptr_t)msg_ga.ga_len));
  } else if (in_fast_callback) {
    multiqueue_put(main_loop.events, nlua_print_event,
                   msg_ga.ga_data, (void *)(intptr_t)msg_ga.ga_len);
  } else {
    nlua_print_event((void *[]){ msg_ga.ga_data, (void *)(intptr_t)msg_ga.ga_len });
  }
  return 0;

nlua_print_error:
  ga_clear(&msg_ga);
  char *buff = xmalloc(IOSIZE);
  const char *fmt = _("E5114: Error while converting print argument #%i: %.*s");
  size_t len = (size_t)vim_snprintf(buff, IOSIZE, fmt, curargidx,
                                    (int)errmsg_len, errmsg);
  lua_pushlstring(lstate, buff, len);
  xfree(buff);
  return lua_error(lstate);
}

/// require() for --startuptime
///
/// @param  lstate  Lua interpreter state.
static int nlua_require(lua_State *const lstate)
  FUNC_ATTR_NONNULL_ALL
{
  const char *name = luaL_checkstring(lstate, 1);
  lua_settop(lstate, 1);
  // [ name ]

  // try cached module from package.loaded first
  lua_getfield(lstate, LUA_REGISTRYINDEX, "_LOADED");
  lua_getfield(lstate, 2, name);
  // [ name package.loaded module ]
  if (lua_toboolean(lstate, -1)) {
    return 1;
  }
  lua_pop(lstate, 2);
  // [ name ]

  // push original require below the module name
  nlua_pushref(lstate, require_ref);
  lua_insert(lstate, 1);
  // [ require name ]

  if (time_fd == NULL) {
    // after log file was closed, try to restore
    // global require to the original function...
    lua_getglobal(lstate, "require");
    // ...only if it's still referencing this wrapper,
    // to not overwrite it in case someone happened to
    // patch it in the meantime...
    if (lua_iscfunction(lstate, -1) && lua_tocfunction(lstate, -1) == nlua_require) {
      lua_pushvalue(lstate, 1);
      lua_setglobal(lstate, "require");
    }
    lua_pop(lstate, 1);

    // ...and then call require directly.
    lua_call(lstate, 1, 1);
    return 1;
  }

  proftime_T rel_time;
  proftime_T start_time;
  time_push(&rel_time, &start_time);
  int status = lua_pcall(lstate, 1, 1, 0);
  if (status == 0) {
    vim_snprintf(IObuff, IOSIZE, "require('%s')", name);
    time_msg(IObuff, &start_time);
  }
  time_pop(rel_time);

  return status == 0 ? 1 : lua_error(lstate);
}

/// debug.debug: interaction with user while debugging.
///
/// @param  lstate  Lua interpreter state.
static int nlua_debug(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  const typval_T input_args[] = {
    {
      .v_lock = VAR_FIXED,
      .v_type = VAR_STRING,
      .vval.v_string = "lua_debug> ",
    },
    {
      .v_type = VAR_UNKNOWN,
    },
  };
  while (true) {
    lua_settop(lstate, 0);
    typval_T input;
    get_user_input(input_args, &input, false, false);
    msg_putchar('\n');  // Avoid outputting on input line.
    if (input.v_type != VAR_STRING
        || input.vval.v_string == NULL
        || *input.vval.v_string == NUL
        || strcmp(input.vval.v_string, "cont") == 0) {
      tv_clear(&input);
      return 0;
    }
    if (luaL_loadbuffer(lstate, input.vval.v_string,
                        strlen(input.vval.v_string), "=(debug command)")) {
      nlua_error(lstate, _("E5115: Error while loading debug string: %.*s"));
    } else if (nlua_pcall(lstate, 0, 0)) {
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

static bool viml_func_is_fast(const char *name)
{
  const EvalFuncDef *const fdef = find_internal_func(name);
  if (fdef) {
    return fdef->fast;
  }
  // Not a Vimscript function
  return false;
}

int nlua_call(lua_State *lstate)
{
  Error err = ERROR_INIT;
  size_t name_len;
  const char *name = luaL_checklstring(lstate, 1, &name_len);
  if (!nlua_is_deferred_safe() && !viml_func_is_fast(name)) {
    return luaL_error(lstate, e_fast_api_disabled, "Vimscript function");
  }

  int nargs = lua_gettop(lstate) - 1;
  if (nargs > MAX_FUNC_ARGS) {
    return luaL_error(lstate, "Function called with too many arguments");
  }

  typval_T vim_args[MAX_FUNC_ARGS + 1];
  int i = 0;  // also used for freeing the variables
  for (; i < nargs; i++) {
    lua_pushvalue(lstate, i + 2);
    if (!nlua_pop_typval(lstate, &vim_args[i])) {
      api_set_error(&err, kErrorTypeException,
                    "error converting argument %d", i + 1);
      goto free_vim_args;
    }
  }

  // TODO(bfredl): this should be simplified in error handling refactor
  force_abort = false;
  suppress_errthrow = false;
  did_throw = false;
  did_emsg = false;

  typval_T rettv;
  funcexe_T funcexe = FUNCEXE_INIT;
  funcexe.fe_firstline = curwin->w_cursor.lnum;
  funcexe.fe_lastline = curwin->w_cursor.lnum;
  funcexe.fe_evaluate = true;

  TRY_WRAP(&err, {
    // call_func() retval is deceptive, ignore it.  Instead we set `msg_list`
    // (TRY_WRAP) to capture abort-causing non-exception errors.
    (void)call_func(name, (int)name_len, &rettv, nargs, vim_args, &funcexe);
  });

  if (!ERROR_SET(&err)) {
    nlua_push_typval(lstate, &rettv, 0);
  }
  tv_clear(&rettv);

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
  if (!nlua_is_deferred_safe()) {
    return luaL_error(lstate, e_fast_api_disabled, "rpcrequest");
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
  int nargs = lua_gettop(lstate) - 2;
  Error err = ERROR_INIT;
  Arena arena = ARENA_EMPTY;

  Array args = arena_array(&arena, (size_t)nargs);
  for (int i = 0; i < nargs; i++) {
    lua_pushvalue(lstate, i + 3);
    ADD(args, nlua_pop_Object(lstate, false, &arena, &err));
    if (ERROR_SET(&err)) {
      goto check_err;
    }
  }

  if (request) {
    ArenaMem res_mem = NULL;
    Object result = rpc_send_call(chan_id, name, args, &res_mem, &err);
    if (!ERROR_SET(&err)) {
      nlua_push_Object(lstate, &result, 0);
      arena_mem_free(res_mem);
    }
  } else {
    if (!rpc_send_event(chan_id, name, args)) {
      api_set_error(&err, kErrorTypeValidation,
                    "Invalid channel: %" PRIu64, chan_id);
    }
  }

check_err:
  arena_mem_free(arena_finish(&arena));

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

#ifdef MSWIN
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
/// The current implementation does not support calls from threads.
LuaRef nlua_ref(lua_State *lstate, nlua_ref_state_t *ref_state, int index)
{
  lua_pushvalue(lstate, index);
  LuaRef ref = luaL_ref(lstate, LUA_REGISTRYINDEX);
  if (ref > 0) {
    ref_state->ref_count++;
#ifdef NLUA_TRACK_REFS
    if (nlua_track_refs) {
      // dummy allocation to make LeakSanitizer track our luarefs
      pmap_put(int)(&ref_state->ref_markers, ref, xmalloc(3));
    }
#endif
  }
  return ref;
}

// TODO(lewis6991): Currently cannot be run in __gc metamethods as they are
// invoked in lua_close() which can be invoked after the ref_markers map is
// destroyed in nlua_common_free_all_mem.
LuaRef nlua_ref_global(lua_State *lstate, int index)
{
  return nlua_ref(lstate, nlua_global_refs, index);
}

/// remove the value from the registry
void nlua_unref(lua_State *lstate, nlua_ref_state_t *ref_state, LuaRef ref)
{
  if (ref > 0) {
    ref_state->ref_count--;
#ifdef NLUA_TRACK_REFS
    // NB: don't remove entry from map to track double-unref
    if (nlua_track_refs) {
      xfree(pmap_get(int)(&ref_state->ref_markers, ref));
    }
#endif
    luaL_unref(lstate, LUA_REGISTRYINDEX, ref);
  }
}

void nlua_unref_global(lua_State *lstate, LuaRef ref)
{
  nlua_unref(lstate, nlua_global_refs, ref);
}

void api_free_luaref(LuaRef ref)
{
  nlua_unref_global(global_lstate, ref);
}

/// push a value referenced in the registry
void nlua_pushref(lua_State *lstate, LuaRef ref)
{
  lua_rawgeti(lstate, LUA_REGISTRYINDEX, ref);
}

/// Gets a new reference to an object stored at original_ref
///
/// NOTE: It does not copy the value, it creates a new ref to the lua object.
///       Leaves the stack unchanged.
LuaRef api_new_luaref(LuaRef original_ref)
{
  if (original_ref == LUA_NOREF) {
    return LUA_NOREF;
  }

  lua_State *const lstate = global_lstate;
  nlua_pushref(lstate, original_ref);
  LuaRef new_ref = nlua_ref_global(lstate,  -1);
  lua_pop(lstate, 1);
  return new_ref;
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
void nlua_typval_eval(const String str, typval_T *const arg, typval_T *const ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
#define EVALHEADER "local _A=select(1,...) return ("
  const size_t lcmd_len = sizeof(EVALHEADER) - 1 + str.size + 1;
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = IObuff;
  } else {
    lcmd = xmalloc(lcmd_len);
  }
  memcpy(lcmd, EVALHEADER, sizeof(EVALHEADER) - 1);
  memcpy(lcmd + sizeof(EVALHEADER) - 1, str.data, str.size);
  lcmd[lcmd_len - 1] = ')';
#undef EVALHEADER
  nlua_typval_exec(lcmd, lcmd_len, "luaeval()", arg, 1, true, ret_tv);

  if (lcmd != IObuff) {
    xfree(lcmd);
  }
}

void nlua_typval_call(const char *str, size_t len, typval_T *const args, int argcount,
                      typval_T *ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
#define CALLHEADER "return "
#define CALLSUFFIX "(...)"
  const size_t lcmd_len = sizeof(CALLHEADER) - 1 + len + sizeof(CALLSUFFIX) - 1;
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = IObuff;
  } else {
    lcmd = xmalloc(lcmd_len);
  }
  memcpy(lcmd, CALLHEADER, sizeof(CALLHEADER) - 1);
  memcpy(lcmd + sizeof(CALLHEADER) - 1, str, len);
  memcpy(lcmd + sizeof(CALLHEADER) - 1 + len, CALLSUFFIX,
         sizeof(CALLSUFFIX) - 1);
#undef CALLHEADER
#undef CALLSUFFIX

  nlua_typval_exec(lcmd, lcmd_len, "v:lua", args, argcount, false, ret_tv);

  if (lcmd != IObuff) {
    xfree(lcmd);
  }
}

void nlua_call_user_expand_func(expand_T *xp, typval_T *ret_tv)
  FUNC_ATTR_NONNULL_ALL
{
  lua_State *const lstate = global_lstate;

  nlua_pushref(lstate, xp->xp_luaref);
  lua_pushstring(lstate, xp->xp_pattern);
  lua_pushstring(lstate, xp->xp_line);
  lua_pushinteger(lstate, xp->xp_col);

  if (nlua_pcall(lstate, 3, 1)) {
    nlua_error(lstate, _("E5108: Error executing Lua function: %.*s"));
    return;
  }

  nlua_pop_typval(lstate, ret_tv);
}

static void nlua_typval_exec(const char *lcmd, size_t lcmd_len, const char *name,
                             typval_T *const args, int argcount, bool special, typval_T *ret_tv)
{
  if (check_secure()) {
    if (ret_tv) {
      ret_tv->v_type = VAR_NUMBER;
      ret_tv->vval.v_number = 0;
    }
    return;
  }

  lua_State *const lstate = global_lstate;
  if (luaL_loadbuffer(lstate, lcmd, lcmd_len, name)) {
    nlua_error(lstate, _("E5107: Error loading lua %.*s"));
    return;
  }

  PUSH_ALL_TYPVALS(lstate, args, argcount, special);

  if (nlua_pcall(lstate, argcount, ret_tv ? 1 : 0)) {
    nlua_error(lstate, _("E5108: Error executing lua %.*s"));
    return;
  }

  if (ret_tv) {
    nlua_pop_typval(lstate, ret_tv);
  }
}

void nlua_exec_ga(garray_T *ga, char *name)
{
  char *code = ga_concat_strings_sep(ga, "\n");
  size_t len = strlen(code);
  nlua_typval_exec(code, len, name, NULL, 0, false, NULL);
  xfree(code);
}

/// Call a LuaCallable given some typvals
///
/// Used to call any Lua callable passed from Lua into Vimscript.
///
/// @param[in]  lstate Lua State
/// @param[in]  lua_cb Lua Callable
/// @param[in]  argcount Count of typval arguments
/// @param[in]  argvars Typval Arguments
/// @param[out] rettv The return value from the called function.
int typval_exec_lua_callable(LuaRef lua_cb, int argcount, typval_T *argvars, typval_T *rettv)
{
  lua_State *lstate = global_lstate;

  nlua_pushref(lstate, lua_cb);

  PUSH_ALL_TYPVALS(lstate, argvars, argcount, false);

  if (nlua_pcall(lstate, argcount, 1)) {
    nlua_print(lstate);
    return FCERR_OTHER;
  }

  nlua_pop_typval(lstate, rettv);

  return FCERR_NONE;
}

/// Execute Lua string
///
/// Used for nvim_exec_lua() and internally to execute a lua string.
///
/// @param[in]  str  String to execute.
/// @param[in]  args array of ... args
/// @param[in]  mode Whether and how the the return value should be converted to Object
/// @param[in] arena  can be NULL, then nested allocations are used
/// @param[out]  err  Location where error will be saved.
///
/// @return Return value of the execution.
Object nlua_exec(const String str, const Array args, LuaRetMode mode, Arena *arena, Error *err)
{
  lua_State *const lstate = global_lstate;

  if (luaL_loadbuffer(lstate, str.data, str.size, "<nvim>")) {
    size_t len;
    const char *errstr = lua_tolstring(lstate, -1, &len);
    api_set_error(err, kErrorTypeValidation,
                  "Error loading lua: %.*s", (int)len, errstr);
    return NIL;
  }

  for (size_t i = 0; i < args.size; i++) {
    nlua_push_Object(lstate, &args.items[i], 0);
  }

  if (nlua_pcall(lstate, (int)args.size, 1)) {
    size_t len;
    const char *errstr = lua_tolstring(lstate, -1, &len);
    api_set_error(err, kErrorTypeException,
                  "Error executing lua: %.*s", (int)len, errstr);
    return NIL;
  }

  return nlua_call_pop_retval(lstate, mode, arena, err);
}

bool nlua_ref_is_function(LuaRef ref)
{
  lua_State *const lstate = global_lstate;
  nlua_pushref(lstate, ref);

  // TODO(tjdevries): This should probably check for callable tables as well.
  //                    We should put some work maybe into simplifying how all of that works
  bool is_function = (lua_type(lstate, -1) == LUA_TFUNCTION);
  lua_pop(lstate, 1);

  return is_function;
}

/// call a LuaRef as a function (or table with __call metamethod)
///
/// @param ref     the reference to call (not consumed)
/// @param name    if non-NULL, sent to callback as first arg
///                if NULL, only args are used
/// @param mode    Whether and how the the return value should be converted to Object
/// @param arena   can be NULL, then nested allocations are used
/// @param err     Error details, if any (if NULL, errors are echoed)
/// @return        Return value of function, as per mode
Object nlua_call_ref(LuaRef ref, const char *name, Array args, LuaRetMode mode, Arena *arena,
                     Error *err)
{
  return nlua_call_ref_ctx(false, ref, name, args, mode, arena, err);
}

Object nlua_call_ref_ctx(bool fast, LuaRef ref, const char *name, Array args, LuaRetMode mode,
                         Arena *arena, Error *err)
{
  lua_State *const lstate = global_lstate;
  nlua_pushref(lstate, ref);
  int nargs = (int)args.size;
  if (name != NULL) {
    lua_pushstring(lstate, name);
    nargs++;
  }
  for (size_t i = 0; i < args.size; i++) {
    nlua_push_Object(lstate, &args.items[i], 0);
  }

  if (fast) {
    if (nlua_fast_cfpcall(lstate, nargs, 1, -1) < 0) {
      // error is already scheduled, set anyways to convey failure.
      api_set_error(err, kErrorTypeException, "fast context failure");
      return NIL;
    }
  } else if (nlua_pcall(lstate, nargs, 1)) {
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

  return nlua_call_pop_retval(lstate, mode, arena, err);
}

static Object nlua_call_pop_retval(lua_State *lstate, LuaRetMode mode, Arena *arena, Error *err)
{
  if (lua_isnil(lstate, -1)) {
    lua_pop(lstate, 1);
    return NIL;
  }
  Error dummy = ERROR_INIT;

  switch (mode) {
  case kRetNilBool: {
    bool bool_value = lua_toboolean(lstate, -1);
    lua_pop(lstate, 1);

    return BOOLEAN_OBJ(bool_value);
  }
  case kRetLuaref: {
    LuaRef ref = nlua_ref_global(lstate, -1);
    lua_pop(lstate, 1);

    return LUAREF_OBJ(ref);
  }
  case kRetObject:
    return nlua_pop_Object(lstate, false, arena, err ? err : &dummy);
  }
  UNREACHABLE;
}

/// check if the current execution context is safe for calling deferred API
/// methods. Luv callbacks are unsafe as they are called inside the uv loop.
bool nlua_is_deferred_safe(void)
{
  return in_fast_callback == 0;
}

/// Executes Lua code.
///
/// Implements `:lua` and `:lua ={expr}`.
///
/// @param  eap  Vimscript `:lua {code}`, `:{range}lua`, or `:lua ={expr}` command.
void ex_lua(exarg_T *const eap)
  FUNC_ATTR_NONNULL_ALL
{
  // ":{range}lua", only if no {code}
  if (*eap->arg == NUL) {
    if (eap->addr_count > 0) {
      cmd_source_buffer(eap, true);
    } else {
      emsg(_(e_argreq));
    }
    return;
  }

  size_t len;
  char *code = script_get(eap, &len);
  if (eap->skip || code == NULL) {
    xfree(code);
    return;
  }

  // ":lua {code}", ":={expr}" or ":lua ={expr}"
  //
  // When "=expr" is used transform it to "vim.print(expr)".
  if (eap->cmdidx == CMD_equal || code[0] == '=') {
    size_t off = (eap->cmdidx == CMD_equal) ? 0 : 1;
    len += sizeof("vim.print()") - 1 - off;
    // `nlua_typval_exec` doesn't expect NUL-terminated string so `len` must end before NUL byte.
    char *code_buf = xmallocz(len);
    vim_snprintf(code_buf, len + 1, "vim.print(%s)", code + off);
    xfree(code);
    code = code_buf;
  }

  nlua_typval_exec(code, len, ":lua", NULL, 0, false, NULL);

  xfree(code);
}

/// Executes Lua code for-each line in a buffer range.
///
/// Implements `:luado`.
///
/// @param  eap  Vimscript `:luado {code}` command.
void ex_luado(exarg_T *const eap)
  FUNC_ATTR_NONNULL_ALL
{
  if (u_save(eap->line1 - 1, eap->line2 + 1) == FAIL) {
    emsg(_("cannot save undo information"));
    return;
  }
  const char *const cmd = eap->arg;
  const size_t cmd_len = strlen(cmd);

  lua_State *const lstate = global_lstate;

#define DOSTART "return function(line, linenr) "
#define DOEND " end"
  const size_t lcmd_len = (cmd_len
                           + (sizeof(DOSTART) - 1)
                           + (sizeof(DOEND) - 1));
  char *lcmd;
  if (lcmd_len < IOSIZE) {
    lcmd = IObuff;
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
  if (nlua_pcall(lstate, 0, 1)) {
    nlua_error(lstate, _("E5110: Error executing lua: %.*s"));
    return;
  }

  buf_T *const was_curbuf = curbuf;

  for (linenr_T l = eap->line1; l <= eap->line2; l++) {
    // Check the line number, the command may have deleted lines.
    if (l > curbuf->b_ml.ml_line_count) {
      break;
    }

    lua_pushvalue(lstate, -1);
    const char *const old_line = ml_get_buf(curbuf, l);
    // Get length of old_line here as calling Lua code may free it.
    const colnr_T old_line_len = ml_get_buf_len(curbuf, l);
    lua_pushstring(lstate, old_line);
    lua_pushnumber(lstate, (lua_Number)l);
    if (nlua_pcall(lstate, 2, 1)) {
      nlua_error(lstate, _("E5111: Error calling lua: %.*s"));
      break;
    }

    // Catch the command switching to another buffer.
    // Check the line number, the command may have deleted lines.
    if (curbuf != was_curbuf || l > curbuf->b_ml.ml_line_count) {
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
      ml_replace(l, new_line_transformed, false);
      inserted_bytes(l, 0, old_line_len, (int)new_line_len);
    }
    lua_pop(lstate, 1);
  }

  lua_pop(lstate, 1);
  check_cursor(curwin);
  redraw_curbuf_later(UPD_NOT_VALID);
}

/// Executes Lua code from a file location.
///
/// Implements `:luafile`.
///
/// @param  eap  Vimscript `:luafile {file}` command.
void ex_luafile(exarg_T *const eap)
  FUNC_ATTR_NONNULL_ALL
{
  nlua_exec_file(eap->arg);
}

/// Executes Lua code from a file or "-" (stdin).
///
/// Calls the Lua `loadfile` global as opposed to `luaL_loadfile` in case `loadfile` was overridden
/// in the user environment.
///
/// @param path Path to the file, may be "-" (stdin) during startup.
///
/// @return true on success, false on error (echoed) or user canceled (CTRL-c) while reading "-"
/// (stdin).
bool nlua_exec_file(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  lua_State *const lstate = global_lstate;
  if (!strequal(path, "-")) {
    lua_getglobal(lstate, "loadfile");
    lua_pushstring(lstate, path);
  } else {
    FileDescriptor stdin_dup;
    int error = file_open_stdin(&stdin_dup);
    if (error) {
      return false;
    }

    StringBuilder sb = KV_INITIAL_VALUE;
    kv_resize(sb, 64);
    // Read all input from stdin, unless interrupted (ctrl-c).
    while (true) {
      if (got_int) {  // User canceled.
        return false;
      }
      ptrdiff_t read_size = file_read(&stdin_dup, IObuff, 64);
      if (read_size < 0) {  // Error.
        return false;
      }
      if (read_size > 0) {
        kv_concat_len(sb, IObuff, (size_t)read_size);
      }
      if (read_size < 64) {  // EOF.
        break;
      }
    }
    kv_push(sb, NUL);
    file_close(&stdin_dup, false);

    lua_getglobal(lstate, "loadstring");
    lua_pushstring(lstate, sb.items);
    kv_destroy(sb);
  }

  if (nlua_pcall(lstate, 1, 2)) {
    nlua_error(lstate, _("E5111: Error calling lua: %.*s"));
    return false;
  }

  // loadstring() returns either:
  //  1. nil, error
  //  2. chunk, nil

  if (lua_isnil(lstate, -2)) {
    // 1
    nlua_error(lstate, _("E5112: Error while creating lua chunk: %.*s"));
    assert(lua_isnil(lstate, -1));
    lua_pop(lstate, 1);
    return false;
  }

  // 2
  assert(lua_isnil(lstate, -1));
  lua_pop(lstate, 1);

  if (nlua_pcall(lstate, 0, 0)) {
    nlua_error(lstate, _("E5113: Error while calling lua chunk: %.*s"));
    return false;
  }

  return true;
}

int tslua_get_language_version(lua_State *L)
{
  lua_pushnumber(L, TREE_SITTER_LANGUAGE_VERSION);
  return 1;
}

int tslua_get_minimum_language_version(lua_State *L)
{
  lua_pushnumber(L, TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION);
  return 1;
}

static void nlua_add_treesitter(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  tslua_init(lstate);

  lua_pushcfunction(lstate, tslua_push_parser);
  lua_setfield(lstate, -2, "_create_ts_parser");

  lua_pushcfunction(lstate, tslua_push_querycursor);
  lua_setfield(lstate, -2, "_create_ts_querycursor");

  lua_pushcfunction(lstate, tslua_add_language_from_object);
  lua_setfield(lstate, -2, "_ts_add_language_from_object");

#ifdef HAVE_WASMTIME
  lua_pushcfunction(lstate, tslua_add_language_from_wasm);
  lua_setfield(lstate, -2, "_ts_add_language_from_wasm");
#endif

  lua_pushcfunction(lstate, tslua_has_language);
  lua_setfield(lstate, -2, "_ts_has_language");

  lua_pushcfunction(lstate, tslua_remove_lang);
  lua_setfield(lstate, -2, "_ts_remove_language");

  lua_pushcfunction(lstate, tslua_inspect_lang);
  lua_setfield(lstate, -2, "_ts_inspect_language");

  lua_pushcfunction(lstate, tslua_parse_query);
  lua_setfield(lstate, -2, "_ts_parse_query");

  lua_pushcfunction(lstate, tslua_get_language_version);
  lua_setfield(lstate, -2, "_ts_get_language_version");

  lua_pushcfunction(lstate, tslua_get_minimum_language_version);
  lua_setfield(lstate, -2, "_ts_get_minimum_language_version");
}

static garray_T expand_result_array = GA_EMPTY_INIT_VALUE;

/// Finds matches for Lua cmdline completion and advances xp->xp_pattern after prefix.
/// This should be called before xp->xp_pattern is first used.
void nlua_expand_pat(expand_T *xp)
{
  lua_State *const lstate = global_lstate;
  int status = FAIL;

  // [ vim ]
  lua_getglobal(lstate, "vim");

  // [ vim, vim._expand_pat ]
  lua_getfield(lstate, -1, "_expand_pat");
  luaL_checktype(lstate, -1, LUA_TFUNCTION);

  // [ vim, vim._expand_pat, pat ]
  const char *pat = xp->xp_pattern;
  assert(xp->xp_line + xp->xp_col >= pat);
  ptrdiff_t patlen = xp->xp_line + xp->xp_col - pat;
  lua_pushlstring(lstate, pat, (size_t)patlen);

  if (nlua_pcall(lstate, 1, 2) != 0) {
    nlua_error(lstate, _("Error executing vim._expand_pat: %.*s"));
    return;
  }

  Error err = ERROR_INIT;

  Arena arena = ARENA_EMPTY;
  ptrdiff_t prefix_len = nlua_pop_Integer(lstate, &arena, &err);
  if (ERROR_SET(&err) || prefix_len > patlen) {
    goto cleanup;
  }

  Array completions = nlua_pop_Array(lstate, &arena, &err);
  if (ERROR_SET(&err)) {
    goto cleanup_array;
  }

  ga_clear(&expand_result_array);
  ga_init(&expand_result_array, (int)sizeof(char *), 80);

  for (size_t i = 0; i < completions.size; i++) {
    Object v = completions.items[i];
    if (v.type != kObjectTypeString) {
      goto cleanup_array;
    }
    GA_APPEND(char *, &expand_result_array, string_to_cstr(v.data.string));
  }

  xp->xp_pattern += prefix_len;
  status = OK;

cleanup_array:
  arena_mem_free(arena_finish(&arena));

cleanup:
  if (status == FAIL) {
    ga_clear(&expand_result_array);
  }
}

int nlua_expand_get_matches(int *num_results, char ***results)
{
  *results = expand_result_array.ga_data;
  *num_results = expand_result_array.ga_len;
  expand_result_array = (garray_T)GA_EMPTY_INIT_VALUE;
  return *num_results > 0;
}

static int nlua_is_thread(lua_State *lstate)
{
  lua_getfield(lstate, LUA_REGISTRYINDEX, "nvim.thread");

  return 1;
}

bool nlua_is_table_from_lua(const typval_T *const arg)
{
  if (arg->v_type == VAR_DICT) {
    return arg->vval.v_dict->lua_table_ref != LUA_NOREF;
  } else if (arg->v_type == VAR_LIST) {
    return arg->vval.v_list->lua_table_ref != LUA_NOREF;
  } else {
    return false;
  }
}

char *nlua_register_table_as_callable(const typval_T *const arg)
{
  LuaRef table_ref = LUA_NOREF;
  if (arg->v_type == VAR_DICT) {
    table_ref = arg->vval.v_dict->lua_table_ref;
  } else if (arg->v_type == VAR_LIST) {
    table_ref = arg->vval.v_list->lua_table_ref;
  }

  if (table_ref == LUA_NOREF) {
    return NULL;
  }

  lua_State *const lstate = global_lstate;

#ifndef NDEBUG
  int top = lua_gettop(lstate);
#endif

  nlua_pushref(lstate, table_ref);  // [table]
  if (!lua_getmetatable(lstate, -1)) {
    lua_pop(lstate, 1);
    assert(top == lua_gettop(lstate));
    return NULL;
  }  // [table, mt]

  lua_getfield(lstate, -1, "__call");  // [table, mt, mt.__call]
  if (!lua_isfunction(lstate, -1)) {
    lua_pop(lstate, 3);
    assert(top == lua_gettop(lstate));
    return NULL;
  }
  lua_pop(lstate, 2);  // [table]

  LuaRef func = nlua_ref_global(lstate, -1);

  char *name = register_luafunc(func);

  lua_pop(lstate, 1);  // []
  assert(top == lua_gettop(lstate));

  return name;
}

/// @return true to discard the key
bool nlua_execute_on_key(int c, char *typed_buf)
{
  static bool recursive = false;

  if (recursive) {
    return false;
  }
  recursive = true;

  char buf[MB_MAXBYTES * 3 + 4];
  size_t buf_len = special_to_buf(c, mod_mask, false, buf);
  vim_unescape_ks(typed_buf);

  lua_State *const lstate = global_lstate;

#ifndef NDEBUG
  int top = lua_gettop(lstate);
#endif

  // [ vim ]
  lua_getglobal(lstate, "vim");

  // [ vim, vim._on_key ]
  lua_getfield(lstate, -1, "_on_key");
  luaL_checktype(lstate, -1, LUA_TFUNCTION);

  // [ vim, vim._on_key, buf ]
  lua_pushlstring(lstate, buf, buf_len);

  // [ vim, vim._on_key, buf, typed_buf ]
  lua_pushstring(lstate, typed_buf);

  int save_got_int = got_int;
  got_int = false;  // avoid interrupts when the key typed is Ctrl-C
  bool discard = false;
  // Do not use nlua_pcall here to avoid duplicate stack trace information
  if (lua_pcall(lstate, 2, 1, 0)) {
    nlua_error(lstate, _("Error executing vim.on_key() callbacks: %.*s"));
  } else {
    if (lua_isboolean(lstate, -1)) {
      discard = lua_toboolean(lstate, -1);
    }
    lua_pop(lstate, 1);
  }
  got_int |= save_got_int;

  // [ vim ]
  lua_pop(lstate, 1);

#ifndef NDEBUG
  // [ ]
  assert(top == lua_gettop(lstate));
#endif

  recursive = false;
  return discard;
}

/// Sets the editor "script context" during Lua execution. Used by :verbose.
/// @param[out] current
void nlua_set_sctx(sctx_T *current)
{
  if (!script_is_lua(current->sc_sid)) {
    return;
  }

  // This function is called after adding SOURCING_LNUM to sc_lnum.
  // SOURCING_LNUM can sometimes be non-zero (e.g. with ETYPE_UFUNC),
  // but it's unrelated to the line number in Lua scripts.
  current->sc_lnum = 0;

  if (p_verbose <= 0) {
    return;
  }
  lua_State *const lstate = global_lstate;
  lua_Debug *info = (lua_Debug *)xmalloc(sizeof(lua_Debug));

  // Files where internal wrappers are defined so we can ignore them
  // like vim.o/opt etc are defined in _options.lua
  char *ignorelist[] = {
    "vim/_editor.lua",
    "vim/_options.lua",
    "vim/keymap.lua",
  };
  int ignorelist_size = sizeof(ignorelist) / sizeof(ignorelist[0]);

  for (int level = 1; true; level++) {
    if (lua_getstack(lstate, level, info) != 1) {
      goto cleanup;
    }
    if (lua_getinfo(lstate, "nSl", info) == 0) {
      goto cleanup;
    }

    bool is_ignored = false;
    if (info->what[0] == 'C' || info->source[0] != '@') {
      is_ignored = true;
    } else {
      for (int i = 0; i < ignorelist_size; i++) {
        if (strncmp(ignorelist[i], info->source + 1, strlen(ignorelist[i])) == 0) {
          is_ignored = true;
          break;
        }
      }
    }
    if (is_ignored) {
      continue;
    }
    break;
  }
  char *source_path = fix_fname(info->source + 1);
  int sid = find_script_by_name(source_path);
  if (sid > 0) {
    xfree(source_path);
  } else {
    scriptitem_T *si = new_script_item(source_path, &sid);
    si->sn_lua = true;
  }
  current->sc_sid = sid;
  current->sc_seq = -1;
  current->sc_lnum = info->currentline;

cleanup:
  xfree(info);
}

/// @param preview Invoke the callback as a |:command-preview| handler.
int nlua_do_ucmd(ucmd_T *cmd, exarg_T *eap, bool preview)
{
  lua_State *const lstate = global_lstate;

  nlua_pushref(lstate, preview ? cmd->uc_preview_luaref : cmd->uc_luaref);

  lua_newtable(lstate);
  lua_pushstring(lstate, cmd->uc_name);
  lua_setfield(lstate, -2, "name");

  lua_pushboolean(lstate, eap->forceit == 1);
  lua_setfield(lstate, -2, "bang");

  lua_pushinteger(lstate, eap->line1);
  lua_setfield(lstate, -2, "line1");

  lua_pushinteger(lstate, eap->line2);
  lua_setfield(lstate, -2, "line2");

  lua_newtable(lstate);  // f-args table
  lua_pushstring(lstate, eap->arg);
  lua_pushvalue(lstate, -1);  // Reference for potential use on f-args
  lua_setfield(lstate, -4, "args");

  // Split args by unescaped whitespace |<f-args>| (nargs dependent)
  if (cmd->uc_argt & EX_NOSPC) {
    if ((cmd->uc_argt & EX_NEEDARG) || strlen(eap->arg)) {
      // For commands where nargs is 1 or "?" and argument is passed, fargs = { args }
      lua_rawseti(lstate, -2, 1);
    } else {
      // if nargs = "?" and no argument is passed, fargs = {}
      lua_pop(lstate, 1);  // Pop the reference of opts.args
    }
  } else if (eap->args == NULL) {
    // For commands with more than one possible argument, split if argument list isn't available.
    lua_pop(lstate, 1);  // Pop the reference of opts.args
    size_t length = strlen(eap->arg);
    size_t end = 0;
    size_t len = 0;
    int i = 1;
    char *buf = xcalloc(length, sizeof(char));
    bool done = false;
    while (!done) {
      done = uc_split_args_iter(eap->arg, length, &end, buf, &len);
      if (len > 0) {
        lua_pushlstring(lstate, buf, len);
        lua_rawseti(lstate, -2, i);
        i++;
      }
    }
    xfree(buf);
  } else {
    // If argument list is available, just use it.
    lua_pop(lstate, 1);
    for (size_t i = 0; i < eap->argc; i++) {
      lua_pushlstring(lstate, eap->args[i], eap->arglens[i]);
      lua_rawseti(lstate, -2, (int)i + 1);
    }
  }
  lua_setfield(lstate, -2, "fargs");

  char reg[2] = { (char)eap->regname, NUL };
  lua_pushstring(lstate, reg);
  lua_setfield(lstate, -2, "reg");

  lua_pushinteger(lstate, eap->addr_count);
  lua_setfield(lstate, -2, "range");

  if (eap->addr_count > 0) {
    lua_pushinteger(lstate, eap->line2);
  } else {
    lua_pushinteger(lstate, cmd->uc_def);
  }
  lua_setfield(lstate, -2, "count");

  // The size of this buffer is chosen empirically to be large enough to hold
  // every possible modifier (with room to spare). If the list of possible
  // modifiers grows this may need to be updated.
  char buf[200] = { 0 };
  uc_mods(buf, &cmdmod, false);
  lua_pushstring(lstate, buf);
  lua_setfield(lstate, -2, "mods");

  lua_newtable(lstate);  // smods table

  lua_pushinteger(lstate, cmdmod.cmod_tab - 1);
  lua_setfield(lstate, -2, "tab");

  lua_pushinteger(lstate, cmdmod.cmod_verbose - 1);
  lua_setfield(lstate, -2, "verbose");

  if (cmdmod.cmod_split & WSP_ABOVE) {
    lua_pushstring(lstate, "aboveleft");
  } else if (cmdmod.cmod_split & WSP_BELOW) {
    lua_pushstring(lstate, "belowright");
  } else if (cmdmod.cmod_split & WSP_TOP) {
    lua_pushstring(lstate, "topleft");
  } else if (cmdmod.cmod_split & WSP_BOT) {
    lua_pushstring(lstate, "botright");
  } else {
    lua_pushstring(lstate, "");
  }
  lua_setfield(lstate, -2, "split");

  lua_pushboolean(lstate, cmdmod.cmod_split & WSP_VERT);
  lua_setfield(lstate, -2, "vertical");
  lua_pushboolean(lstate, cmdmod.cmod_split & WSP_HOR);
  lua_setfield(lstate, -2, "horizontal");
  lua_pushboolean(lstate, cmdmod.cmod_flags & CMOD_SILENT);
  lua_setfield(lstate, -2, "silent");
  lua_pushboolean(lstate, cmdmod.cmod_flags & CMOD_ERRSILENT);
  lua_setfield(lstate, -2, "emsg_silent");
  lua_pushboolean(lstate, cmdmod.cmod_flags & CMOD_UNSILENT);
  lua_setfield(lstate, -2, "unsilent");
  lua_pushboolean(lstate, cmdmod.cmod_flags & CMOD_SANDBOX);
  lua_setfield(lstate, -2, "sandbox");
  lua_pushboolean(lstate, cmdmod.cmod_flags & CMOD_NOAUTOCMD);
  lua_setfield(lstate, -2, "noautocmd");

  typedef struct {
    int flag;
    char *name;
  } mod_entry_T;
  static mod_entry_T mod_entries[] = {
    { CMOD_BROWSE, "browse" },
    { CMOD_CONFIRM, "confirm" },
    { CMOD_HIDE, "hide" },
    { CMOD_KEEPALT, "keepalt" },
    { CMOD_KEEPJUMPS, "keepjumps" },
    { CMOD_KEEPMARKS, "keepmarks" },
    { CMOD_KEEPPATTERNS, "keeppatterns" },
    { CMOD_LOCKMARKS, "lockmarks" },
    { CMOD_NOSWAPFILE, "noswapfile" }
  };

  // The modifiers that are simple flags
  for (size_t i = 0; i < ARRAY_SIZE(mod_entries); i++) {
    lua_pushboolean(lstate, cmdmod.cmod_flags & mod_entries[i].flag);
    lua_setfield(lstate, -2, mod_entries[i].name);
  }

  lua_setfield(lstate, -2, "smods");

  if (preview) {
    lua_pushinteger(lstate, cmdpreview_get_ns());

    handle_T cmdpreview_bufnr = cmdpreview_get_bufnr();
    if (cmdpreview_bufnr != 0) {
      lua_pushinteger(lstate, cmdpreview_bufnr);
    } else {
      lua_pushnil(lstate);
    }
  }

  if (nlua_pcall(lstate, preview ? 3 : 1, preview ? 1 : 0)) {
    nlua_error(lstate, _("Error executing Lua callback: %.*s"));
    return 0;
  }

  int retv = 0;

  if (preview) {
    if (lua_isnumber(lstate, -1) && (retv = (int)lua_tointeger(lstate, -1)) >= 0 && retv <= 2) {
      lua_pop(lstate, 1);
    } else {
      retv = 0;
    }
  }

  return retv;
}

/// String representation of a Lua function reference
///
/// @return Allocated string
char *nlua_funcref_str(LuaRef ref, Arena *arena)
{
  lua_State *const lstate = global_lstate;

  if (!lua_checkstack(lstate, 1)) {
    goto plain;
  }
  nlua_pushref(lstate, ref);
  if (!lua_isfunction(lstate, -1)) {
    lua_pop(lstate, 1);
    goto plain;
  }

  lua_Debug ar;
  if (lua_getinfo(lstate, ">S", &ar) && *ar.source == '@' && ar.linedefined >= 0) {
    char *src = home_replace_save(NULL, ar.source + 1);
    String str = arena_printf(arena, "<Lua %d: %s:%d>", ref, src, ar.linedefined);
    xfree(src);
    return str.data;
  }

plain: {}
  return arena_printf(arena, "<Lua %d>", ref).data;
}

/// Execute the vim._defaults module to set up default mappings and autocommands
void nlua_init_defaults(void)
{
  lua_State *const L = global_lstate;
  assert(L);

  lua_getglobal(L, "require");
  lua_pushstring(L, "vim._defaults");
  if (nlua_pcall(L, 1, 0)) {
    fprintf(stderr, "%s\n", lua_tostring(L, -1));
  }
}

/// check lua function exist
bool nlua_func_exists(const char *lua_funcname)
{
  MAXSIZE_TEMP_ARRAY(args, 1);
  size_t length = strlen(lua_funcname) + 8;
  char *str = xmalloc(length);
  vim_snprintf(str, length, "return %s", lua_funcname);
  ADD_C(args, CSTR_AS_OBJ(str));
  Error err = ERROR_INIT;
  Object result = NLUA_EXEC_STATIC("return type(loadstring(...)()) == 'function'", args,
                                   kRetNilBool, NULL, &err);
  xfree(str);

  api_clear_error(&err);
  return LUARET_TRUTHY(result);
}
