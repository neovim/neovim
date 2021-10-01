// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <errno.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/helpers.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/xdiff.h"
#include "nvim/vim.h"
#include "xdiff/xdiff.h"

typedef enum {
  kNluaXdiffModeUnified =  0,
  kNluaXdiffModeOnHunkCB,
  kNluaXdiffModeLocations,
} NluaXdiffMode;

typedef struct {
  lua_State *lstate;
  Error *err;
} hunkpriv_t;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/xdiff.c.generated.h"
#endif

static int write_string(void *priv, mmbuffer_t *mb, int nbuf)
{
  luaL_Buffer *buf = (luaL_Buffer *)priv;
  for (int i = 0; i < nbuf; i++) {
    const long size = mb[i].size;
    for (long total = 0; total < size; total += LUAL_BUFFERSIZE) {
      const int tocopy = MIN((int)(size - total), LUAL_BUFFERSIZE);
      char *p = luaL_prepbuffer(buf);
      if (!p) {
        return -1;
      }
      memcpy(p, mb[i].ptr + total, (unsigned)tocopy);
      luaL_addsize(buf, (unsigned)tocopy);
    }
  }
  return 0;
}

// hunk_func callback used when opts.hunk_lines = true
static int hunk_locations_cb(long start_a, long count_a, long start_b, long count_b, void *cb_data)
{
  // Mimic extra offsets done by xdiff, see:
  // src/xdiff/xemit.c:284
  // src/xdiff/xutils.c:(356,368)
  if (count_a > 0) {
    start_a += 1;
  }
  if (count_b > 0) {
    start_b += 1;
  }

  lua_State * lstate = (lua_State *)cb_data;
  lua_createtable(lstate, 0, 0);

  lua_pushinteger(lstate, start_a);
  lua_rawseti(lstate, -2, 1);
  lua_pushinteger(lstate, count_a);
  lua_rawseti(lstate, -2, 2);
  lua_pushinteger(lstate, start_b);
  lua_rawseti(lstate, -2, 3);
  lua_pushinteger(lstate, count_b);
  lua_rawseti(lstate, -2, 4);

  lua_rawseti(lstate, -2, (signed)lua_objlen(lstate, -2)+1);

  return 0;
}

// hunk_func callback used when opts.on_hunk is given
static int call_on_hunk_cb(long start_a, long count_a, long start_b, long count_b, void *cb_data)
{
  // Mimic extra offsets done by xdiff, see:
  // src/xdiff/xemit.c:284
  // src/xdiff/xutils.c:(356,368)
  if (count_a > 0) {
    start_a += 1;
  }
  if (count_b > 0) {
    start_b += 1;
  }

  hunkpriv_t *priv = (hunkpriv_t *)cb_data;
  lua_State * lstate = priv->lstate;
  Error *err = priv->err;
  const int fidx = lua_gettop(lstate);
  lua_pushvalue(lstate, fidx);
  lua_pushinteger(lstate, start_a);
  lua_pushinteger(lstate, count_a);
  lua_pushinteger(lstate, start_b);
  lua_pushinteger(lstate, count_b);

  if (lua_pcall(lstate, 4, 1, 0) != 0) {
    api_set_error(err, kErrorTypeException,
                  "error running function on_hunk: %s",
                  lua_tostring(lstate, -1));
    return -1;
  }

  int r = 0;
  if (lua_isnumber(lstate, -1)) {
    r = (int)lua_tonumber(lstate, -1);
  }

  lua_pop(lstate, 1);
  lua_settop(lstate, fidx);
  return r;
}

static mmfile_t get_string_arg(lua_State *lstate, int idx)
{
  if (lua_type(lstate, idx) != LUA_TSTRING) {
    luaL_argerror(lstate, idx, "expected string");
  }
  mmfile_t mf;
  mf.ptr = (char *)lua_tolstring(lstate, idx, (size_t *)&mf.size);
  return mf;
}

// Helper function for validating option types
static bool check_xdiff_opt(ObjectType actType, ObjectType expType, const char *name, Error *err)
{
  if (actType != expType) {
    const char * type_str =
      expType == kObjectTypeString  ? "string"   :
      expType == kObjectTypeInteger ? "integer"  :
      expType == kObjectTypeBoolean ? "boolean"  :
      expType == kObjectTypeLuaRef  ? "function" :
      "NA";

    api_set_error(err, kErrorTypeValidation, "%s is not a %s", name,
                  type_str);
    return true;
  }

  return false;
}

static NluaXdiffMode process_xdl_diff_opts(lua_State *lstate, xdemitconf_t *cfg, xpparam_t *params,
                                           Error *err)
{
  const DictionaryOf(LuaRef) opts = nlua_pop_Dictionary(lstate, true, err);

  NluaXdiffMode mode = kNluaXdiffModeUnified;

  bool had_on_hunk = false;
  bool had_result_type_indices = false;
  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;
    if (strequal("on_hunk", k.data)) {
      if (check_xdiff_opt(v->type, kObjectTypeLuaRef, "on_hunk", err)) {
        goto exit_1;
      }
      had_on_hunk = true;
      nlua_pushref(lstate, v->data.luaref);
    } else if (strequal("result_type", k.data)) {
      if (check_xdiff_opt(v->type, kObjectTypeString, "result_type", err)) {
        goto exit_1;
      }
      if (strequal("unified", v->data.string.data)) {
      } else if (strequal("indices", v->data.string.data)) {
        had_result_type_indices = true;
      } else {
        api_set_error(err, kErrorTypeValidation, "not a valid result_type");
        goto exit_1;
      }
    } else if (strequal("algorithm", k.data)) {
      if (check_xdiff_opt(v->type, kObjectTypeString, "algorithm", err)) {
        goto exit_1;
      }
      if (strequal("myers", v->data.string.data)) {
        // default
      } else if (strequal("minimal", v->data.string.data)) {
        cfg->flags |= XDF_NEED_MINIMAL;
      } else if (strequal("patience", v->data.string.data)) {
        cfg->flags |= XDF_PATIENCE_DIFF;
      } else if (strequal("histogram", v->data.string.data)) {
        cfg->flags |= XDF_HISTOGRAM_DIFF;
      } else {
        api_set_error(err, kErrorTypeValidation, "not a valid algorithm");
        goto exit_1;
      }
    } else if (strequal("ctxlen", k.data)) {
      if (check_xdiff_opt(v->type, kObjectTypeInteger, "ctxlen", err)) {
        goto exit_1;
      }
      cfg->ctxlen = v->data.integer;
    } else if (strequal("interhunkctxlen", k.data)) {
      if (check_xdiff_opt(v->type, kObjectTypeInteger, "interhunkctxlen",
                          err)) {
        goto exit_1;
      }
      cfg->interhunkctxlen = v->data.integer;
    } else {
      struct {
        const char *name;
        unsigned long value;
      } flags[] = {
        { "ignore_whitespace", XDF_IGNORE_WHITESPACE },
        { "ignore_whitespace_change", XDF_IGNORE_WHITESPACE_CHANGE },
        { "ignore_whitespace_change_at_eol", XDF_IGNORE_WHITESPACE_AT_EOL },
        { "ignore_cr_at_eol", XDF_IGNORE_CR_AT_EOL },
        { "ignore_blank_lines", XDF_IGNORE_BLANK_LINES },
        { "indent_heuristic", XDF_INDENT_HEURISTIC },
        {  NULL, 0 },
      };
      bool key_used = false;
      for (size_t j = 0; flags[j].name; j++) {
        if (strequal(flags[j].name, k.data)) {
          if (check_xdiff_opt(v->type, kObjectTypeBoolean, flags[j].name,
                              err)) {
            goto exit_1;
          }
          if (v->data.boolean) {
            params->flags |= flags[j].value;
          }
          key_used = true;
          break;
        }
      }

      if (key_used) {
        continue;
      }

      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      goto exit_1;
    }
  }

  if (had_on_hunk) {
    mode = kNluaXdiffModeOnHunkCB;
    cfg->hunk_func = call_on_hunk_cb;
  } else if (had_result_type_indices) {
    mode = kNluaXdiffModeLocations;
    cfg->hunk_func = hunk_locations_cb;
  }

exit_1:
  api_free_dictionary(opts);
  return mode;
}

int nlua_xdl_diff(lua_State *lstate)
{
  if (lua_gettop(lstate) < 2) {
    return luaL_error(lstate, "Expected at least 2 arguments");
  }
  mmfile_t ma = get_string_arg(lstate, 1);
  mmfile_t mb = get_string_arg(lstate, 2);

  Error err = ERROR_INIT;

  xdemitconf_t cfg;
  xpparam_t params;
  xdemitcb_t ecb;

  memset(&cfg, 0, sizeof(cfg));
  memset(&params, 0, sizeof(params));
  memset(&ecb, 0, sizeof(ecb));

  NluaXdiffMode mode = kNluaXdiffModeUnified;

  if (lua_gettop(lstate) == 3) {
    if (lua_type(lstate, 3) != LUA_TTABLE) {
      return luaL_argerror(lstate, 3, "expected table");
    }

    mode = process_xdl_diff_opts(lstate, &cfg, &params, &err);

    if (ERROR_SET(&err)) {
      goto exit_0;
    }
  }

  luaL_Buffer buf;
  hunkpriv_t *priv = NULL;
  switch (mode) {
  case kNluaXdiffModeUnified:
    luaL_buffinit(lstate, &buf);
    ecb.priv = &buf;
    ecb.out_line = write_string;
    break;
  case kNluaXdiffModeOnHunkCB:
    priv = xmalloc(sizeof(*priv));
    priv->lstate = lstate;
    priv->err = &err;
    ecb.priv = priv;
    break;
  case kNluaXdiffModeLocations:
    lua_createtable(lstate, 0, 0);
    ecb.priv = lstate;
    break;
  }

  if (xdl_diff(&ma, &mb, &params, &cfg, &ecb) == -1) {
    if (!ERROR_SET(&err)) {
      api_set_error(&err, kErrorTypeException,
                    "Error while performing diff operation");
    }
  }

  XFREE_CLEAR(priv);

exit_0:
  if (ERROR_SET(&err)) {
    luaL_where(lstate, 1);
    lua_pushstring(lstate, err.msg);
    api_clear_error(&err);
    lua_concat(lstate, 2);
    return lua_error(lstate);
  } else if (mode == kNluaXdiffModeUnified) {
    luaL_pushresult(&buf);
    return 1;
  } else if (mode == kNluaXdiffModeLocations) {
    return 1;
  }
  return 0;
}
