// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include "cjson/lua_cjson.h"
#include "luv/luv.h"
#include "mpack/lmpack.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/cursor.h"
#include "nvim/eval/userfunc.h"
#include "nvim/event/loop.h"
#include "nvim/event/time.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/func_attr.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/spell.h"
#include "nvim/lua/stdlib.h"
#include "nvim/lua/treesitter.h"
#include "nvim/lua/xdiff.h"
#include "nvim/macros.h"
#include "nvim/map.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/os/os.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/screen.h"
#include "nvim/types.h"
#include "nvim/undo.h"
#include "nvim/version.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/stdlib.c.generated.h"
#endif

static int regex_match(lua_State *lstate, regprog_T **prog, char_u *str)
{
  regmatch_T rm;
  rm.regprog = *prog;
  rm.rm_ic = false;
  bool match = vim_regexec(&rm, str, 0);
  *prog = rm.regprog;

  if (match) {
    lua_pushinteger(lstate, (lua_Integer)(rm.startp[0] - str));
    lua_pushinteger(lstate, (lua_Integer)(rm.endp[0] - str));
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

  char_u *line = ml_get_buf(buf, rownr + 1, false);
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

  int nret = regex_match(lstate, prog, line + start);

  if (end >= 0) {
    line[end] = save;
  }

  if (!*prog) {
    return luaL_error(lstate, "regex: internal error");
  }

  return nret;
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

static struct luaL_Reg regex_meta[] = {
  { "__gc", regex_gc },
  { "__tostring", regex_tostring },
  { "match_str", regex_match_str },
  { "match_line", regex_match_line },
  { NULL, NULL }
};

/// convert byte index to UTF-32 and UTF-16 indices
///
/// Expects a string and an optional index. If no index is supplied, the length
/// of the string is returned.
///
/// Returns two values: the UTF-32 and UTF-16 indices.
int nlua_str_utfindex(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  size_t s1_len;
  const char *s1 = luaL_checklstring(lstate, 1, &s1_len);
  intptr_t idx;
  if (lua_isnoneornil(lstate, 2)) {
    idx = (intptr_t)s1_len;
  } else {
    idx = luaL_checkinteger(lstate, 2);
    if (idx < 0 || idx > (intptr_t)s1_len) {
      return luaL_error(lstate, "index out of range");
    }
  }

  size_t codepoints = 0, codeunits = 0;
  mb_utflen((const char_u *)s1, (size_t)idx, &codepoints, &codeunits);

  lua_pushinteger(lstate, (long)codepoints);
  lua_pushinteger(lstate, (long)codeunits);

  return 2;
}

/// return byte indices of codepoints in a string (only supports utf-8 currently).
///
/// Expects a string.
///
/// Returns a list of codepoints.
static int nlua_str_utf_pos(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  size_t s1_len;
  const char *s1 = luaL_checklstring(lstate, 1, &s1_len);
  lua_newtable(lstate);

  size_t idx = 1;
  size_t clen;
  for (size_t i = 0; i < s1_len && s1[i] != NUL; i += clen) {
    clen = (size_t)utf_ptr2len_len((const char_u *)(s1) + i, (int)(s1_len - i));
    lua_pushinteger(lstate, (long)i + 1);
    lua_rawseti(lstate, -2, (int)idx);
    idx++;
  }

  return 1;
}

/// Return the offset from the 1-indexed byte position to the first byte of the
/// current character.
///
/// Expects a string and an int.
///
/// Returns the byte offset to the first byte of the current character
/// pointed into by the offset.
static int nlua_str_utf_start(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  size_t s1_len;
  const char *s1 = luaL_checklstring(lstate, 1, &s1_len);
  long offset = luaL_checkinteger(lstate, 2);
  if (offset < 0 || offset > (intptr_t)s1_len) {
    return luaL_error(lstate, "index out of range");
  }
  int head_offset = mb_head_off((char_u *)s1, (char_u *)s1 + offset - 1);
  lua_pushinteger(lstate, head_offset);
  return 1;
}

/// Return the offset from the 1-indexed byte position to the last
/// byte of the current character.
///
/// Expects a string and an int.
///
/// Returns the byte offset to the last byte of the current character
/// pointed into by the offset.
static int nlua_str_utf_end(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
{
  size_t s1_len;
  const char *s1 = luaL_checklstring(lstate, 1, &s1_len);
  long offset = luaL_checkinteger(lstate, 2);
  if (offset < 0 || offset > (intptr_t)s1_len) {
    return luaL_error(lstate, "index out of range");
  }
  int tail_offset = mb_tail_off((char_u *)s1, (char_u *)s1 + offset - 1);
  lua_pushinteger(lstate, tail_offset);
  return 1;
}

/// convert UTF-32 or UTF-16 indices to byte index.
///
/// Expects up to three args: string, index and use_utf16.
/// If use_utf16 is not supplied it defaults to false (use UTF-32)
///
/// Returns the byte index.
int nlua_str_byteindex(lua_State *const lstate) FUNC_ATTR_NONNULL_ALL
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

int nlua_regex(lua_State *lstate)
{
  Error err = ERROR_INIT;
  const char *text = luaL_checkstring(lstate, 1);
  regprog_T *prog = NULL;

  TRY_WRAP({
    try_start();
    prog = vim_regcomp((char *)text, RE_AUTO | RE_MAGIC | RE_STRICT);
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

static dict_T *nlua_get_var_scope(lua_State *lstate)
{
  const char *scope = luaL_checkstring(lstate, 1);
  handle_T handle = (handle_T)luaL_checkinteger(lstate, 2);
  dict_T *dict = NULL;
  Error err = ERROR_INIT;
  if (strequal(scope, "g")) {
    dict = &globvardict;
  } else if (strequal(scope, "v")) {
    dict = &vimvardict;
  } else if (strequal(scope, "b")) {
    buf_T *buf = find_buffer_by_handle(handle, &err);
    if (buf) {
      dict = buf->b_vars;
    }
  } else if (strequal(scope, "w")) {
    win_T *win = find_window_by_handle(handle, &err);
    if (win) {
      dict = win->w_vars;
    }
  } else if (strequal(scope, "t")) {
    tabpage_T *tabpage = find_tab_by_handle(handle, &err);
    if (tabpage) {
      dict = tabpage->tp_vars;
    }
  } else {
    luaL_error(lstate, "invalid scope", err.msg);
    return NULL;
  }

  if (ERROR_SET(&err)) {
    luaL_error(lstate, "FAIL: %s", err.msg);
    return NULL;
  }
  return dict;
}

int nlua_setvar(lua_State *lstate)
{
  // non-local return if not found
  dict_T *dict = nlua_get_var_scope(lstate);
  String key;
  key.data = (char *)luaL_checklstring(lstate, 3, &key.size);

  bool del = (lua_gettop(lstate) < 4) || lua_isnil(lstate, 4);

  Error err = ERROR_INIT;
  dictitem_T *di = dict_check_writable(dict, key, del, &err);
  if (ERROR_SET(&err)) {
    return 0;
  }

  if (del) {
    // Delete the key
    if (di == NULL) {
      // Doesn't exist, nothing to do
      return 0;
    } else {
      // Delete the entry
      tv_dict_item_remove(dict, di);
    }
  } else {
    // Update the key
    typval_T tv;

    // Convert the lua value to a vimscript type in the temporary variable
    lua_pushvalue(lstate, 4);
    if (!nlua_pop_typval(lstate, &tv)) {
      return luaL_error(lstate, "Couldn't convert lua value");
    }

    if (di == NULL) {
      // Need to create an entry
      di = tv_dict_item_alloc_len(key.data, key.size);
      tv_dict_add(dict, di);
    } else {
      // Clear the old value
      tv_clear(&di->di_tv);
    }

    // Update the value
    tv_copy(&tv, &di->di_tv);
    // Clear the temporary variable
    tv_clear(&tv);
  }
  return 0;
}

int nlua_getvar(lua_State *lstate)
{
  // non-local return if not found
  dict_T *dict = nlua_get_var_scope(lstate);
  size_t len;
  const char *name = luaL_checklstring(lstate, 3, &len);

  dictitem_T *di = tv_dict_find(dict, name, (ptrdiff_t)len);
  if (di == NULL && dict == &globvardict) {  // try to autoload script
    if (!script_autoload(name, len, false) || aborting()) {
      return 0;  // nil
    }
    di = tv_dict_find(dict, name, (ptrdiff_t)len);
  }
  if (di == NULL) {
    return 0;  // nil
  }
  nlua_push_typval(lstate, &di->di_tv, false);
  return 1;
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

void nlua_state_add_stdlib(lua_State *const lstate, bool is_thread)
{
  if (!is_thread) {
    // TODO(bfredl): some of basic string functions should already be
    // (or be easy to make) threadsafe

    // stricmp
    lua_pushcfunction(lstate, &nlua_stricmp);
    lua_setfield(lstate, -2, "stricmp");
    // str_utfindex
    lua_pushcfunction(lstate, &nlua_str_utfindex);
    lua_setfield(lstate, -2, "str_utfindex");
    // str_byteindex
    lua_pushcfunction(lstate, &nlua_str_byteindex);
    lua_setfield(lstate, -2, "str_byteindex");
    // str_utf_pos
    lua_pushcfunction(lstate, &nlua_str_utf_pos);
    lua_setfield(lstate, -2, "str_utf_pos");
    // str_utf_start
    lua_pushcfunction(lstate, &nlua_str_utf_start);
    lua_setfield(lstate, -2, "str_utf_start");
    // str_utf_end
    lua_pushcfunction(lstate, &nlua_str_utf_end);
    lua_setfield(lstate, -2, "str_utf_end");
    // regex
    lua_pushcfunction(lstate, &nlua_regex);
    lua_setfield(lstate, -2, "regex");
    luaL_newmetatable(lstate, "nvim_regex");
    luaL_register(lstate, NULL, regex_meta);

    lua_pushvalue(lstate, -1);  // [meta, meta]
    lua_setfield(lstate, -2, "__index");  // [meta]
    lua_pop(lstate, 1);  // don't use metatable now

    // _getvar
    lua_pushcfunction(lstate, &nlua_getvar);
    lua_setfield(lstate, -2, "_getvar");

    // _setvar
    lua_pushcfunction(lstate, &nlua_setvar);
    lua_setfield(lstate, -2, "_setvar");

    // vim.spell
    luaopen_spell(lstate);
    lua_setfield(lstate, -2, "spell");
  }

  // vim.mpack
  luaopen_mpack(lstate);
  lua_pushvalue(lstate, -1);
  lua_setfield(lstate, -3, "mpack");

  // package.loaded.mpack = vim.mpack
  // otherwise luv will be reinitialized when require'mpack'
  lua_getglobal(lstate, "package");
  lua_getfield(lstate, -1, "loaded");
  lua_pushvalue(lstate, -3);
  lua_setfield(lstate, -2, "mpack");
  lua_pop(lstate, 3);

  // vim.diff
  lua_pushcfunction(lstate, &nlua_xdl_diff);
  lua_setfield(lstate, -2, "diff");

  // vim.json
  lua_cjson_new(lstate);
  lua_setfield(lstate, -2, "json");
}
