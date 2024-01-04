#include <lauxlib.h>
#include <lua.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "luaconf.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/linematch.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/xdiff.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/pos_defs.h"
#include "xdiff/xdiff.h"

#define COMPARED_BUFFER0 (1 << 0)
#define COMPARED_BUFFER1 (1 << 1)

typedef enum {
  kNluaXdiffModeUnified = 0,
  kNluaXdiffModeOnHunkCB,
  kNluaXdiffModeLocations,
} NluaXdiffMode;

typedef struct {
  lua_State *lstate;
  Error *err;
  mmfile_t *ma;
  mmfile_t *mb;
  int64_t linematch;
  bool iwhite;
} hunkpriv_t;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/xdiff.c.generated.h"
#endif

static void lua_pushhunk(lua_State *lstate, long start_a, long count_a, long start_b, long count_b)
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
  lua_createtable(lstate, 0, 0);
  lua_pushinteger(lstate, start_a);
  lua_rawseti(lstate, -2, 1);
  lua_pushinteger(lstate, count_a);
  lua_rawseti(lstate, -2, 2);
  lua_pushinteger(lstate, start_b);
  lua_rawseti(lstate, -2, 3);
  lua_pushinteger(lstate, count_b);
  lua_rawseti(lstate, -2, 4);
  lua_rawseti(lstate, -2, (signed)lua_objlen(lstate, -2) + 1);
}

static void get_linematch_results(lua_State *lstate, mmfile_t *ma, mmfile_t *mb, int start_a,
                                  int count_a, int start_b, int count_b, bool iwhite)
{
  // get the pointer to char of the start of the diff to pass it to linematch algorithm
  const char *diff_begin[2] = { ma->ptr, mb->ptr };
  int diff_length[2] = { count_a, count_b };

  fastforward_buf_to_lnum(&diff_begin[0], (linenr_T)start_a + 1);
  fastforward_buf_to_lnum(&diff_begin[1], (linenr_T)start_b + 1);

  int *decisions = NULL;
  size_t decisions_length = linematch_nbuffers(diff_begin, diff_length, 2, &decisions, iwhite);

  int lnuma = start_a;
  int lnumb = start_b;

  int hunkstarta = lnuma;
  int hunkstartb = lnumb;
  int hunkcounta = 0;
  int hunkcountb = 0;
  for (size_t i = 0; i < decisions_length; i++) {
    if (i && (decisions[i - 1] != decisions[i])) {
      lua_pushhunk(lstate, hunkstarta, hunkcounta, hunkstartb, hunkcountb);

      hunkstarta = lnuma;
      hunkstartb = lnumb;
      hunkcounta = 0;
      hunkcountb = 0;
      // create a new hunk
    }
    if (decisions[i] & COMPARED_BUFFER0) {
      lnuma++;
      hunkcounta++;
    }
    if (decisions[i] & COMPARED_BUFFER1) {
      lnumb++;
      hunkcountb++;
    }
  }
  lua_pushhunk(lstate, hunkstarta, hunkcounta, hunkstartb, hunkcountb);
  xfree(decisions);
}

static int write_string(void *priv, mmbuffer_t *mb, int nbuf)
{
  luaL_Buffer *buf = (luaL_Buffer *)priv;
  for (int i = 0; i < nbuf; i++) {
    const int size = mb[i].size;
    for (int total = 0; total < size; total += LUAL_BUFFERSIZE) {
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
static int hunk_locations_cb(int start_a, int count_a, int start_b, int count_b, void *cb_data)
{
  hunkpriv_t *priv = (hunkpriv_t *)cb_data;
  lua_State *lstate = priv->lstate;
  if (priv->linematch > 0 && count_a + count_b <= priv->linematch) {
    get_linematch_results(lstate, priv->ma, priv->mb, start_a, count_a, start_b, count_b,
                          priv->iwhite);
  } else {
    lua_pushhunk(lstate, start_a, count_a, start_b, count_b);
  }

  return 0;
}

// hunk_func callback used when opts.on_hunk is given
static int call_on_hunk_cb(int start_a, int count_a, int start_b, int count_b, void *cb_data)
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
  lua_State *lstate = priv->lstate;
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
    const char *type_str =
      expType == kObjectTypeString
      ? "string" : (expType == kObjectTypeInteger
                    ? "integer" : (expType == kObjectTypeBoolean
                                   ? "boolean" : (expType == kObjectTypeLuaRef
                                                  ? "function" : "NA")));

    api_set_error(err, kErrorTypeValidation, "%s is not a %s", name,
                  type_str);
    return true;
  }

  return false;
}

static NluaXdiffMode process_xdl_diff_opts(lua_State *lstate, xdemitconf_t *cfg, xpparam_t *params,
                                           int64_t *linematch, Error *err)
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
        // the default
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
        params->flags |= XDF_NEED_MINIMAL;
      } else if (strequal("patience", v->data.string.data)) {
        params->flags |= XDF_PATIENCE_DIFF;
      } else if (strequal("histogram", v->data.string.data)) {
        params->flags |= XDF_HISTOGRAM_DIFF;
      } else {
        api_set_error(err, kErrorTypeValidation, "not a valid algorithm");
        goto exit_1;
      }
    } else if (strequal("ctxlen", k.data)) {
      if (check_xdiff_opt(v->type, kObjectTypeInteger, "ctxlen", err)) {
        goto exit_1;
      }
      cfg->ctxlen = (long)v->data.integer;
    } else if (strequal("interhunkctxlen", k.data)) {
      if (check_xdiff_opt(v->type, kObjectTypeInteger, "interhunkctxlen",
                          err)) {
        goto exit_1;
      }
      cfg->interhunkctxlen = (long)v->data.integer;
    } else if (strequal("linematch", k.data)) {
      if (v->type == kObjectTypeBoolean) {
        *linematch = v->data.boolean ? INT64_MAX : 0;
      } else if (v->type == kObjectTypeInteger) {
        *linematch = v->data.integer;
      } else {
        api_set_error(err, kErrorTypeValidation, "linematch must be a boolean or integer");
        goto exit_1;
      }
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
  } else if (had_result_type_indices) {
    mode = kNluaXdiffModeLocations;
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
  int64_t linematch = 0;

  CLEAR_FIELD(cfg);
  CLEAR_FIELD(params);
  CLEAR_FIELD(ecb);

  NluaXdiffMode mode = kNluaXdiffModeUnified;

  if (lua_gettop(lstate) == 3) {
    if (lua_type(lstate, 3) != LUA_TTABLE) {
      return luaL_argerror(lstate, 3, "expected table");
    }

    mode = process_xdl_diff_opts(lstate, &cfg, &params, &linematch, &err);

    if (ERROR_SET(&err)) {
      goto exit_0;
    }
  }

  luaL_Buffer buf;
  hunkpriv_t priv;
  switch (mode) {
  case kNluaXdiffModeUnified:
    luaL_buffinit(lstate, &buf);
    ecb.priv = &buf;
    ecb.out_line = write_string;
    break;
  case kNluaXdiffModeOnHunkCB:
    cfg.hunk_func = call_on_hunk_cb;
    priv = (hunkpriv_t) {
      .lstate = lstate,
      .err = &err,
    };
    ecb.priv = &priv;
    break;
  case kNluaXdiffModeLocations:
    cfg.hunk_func = hunk_locations_cb;
    priv = (hunkpriv_t) {
      .lstate = lstate,
      .ma = &ma,
      .mb = &mb,
      .linematch = linematch,
      .iwhite = (params.flags & XDF_IGNORE_WHITESPACE) > 0
    };
    ecb.priv = &priv;
    lua_createtable(lstate, 0, 0);
    break;
  }

  if (xdl_diff(&ma, &mb, &params, &cfg, &ecb) == -1) {
    if (!ERROR_SET(&err)) {
      api_set_error(&err, kErrorTypeException,
                    "Error while performing diff operation");
    }
  }

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
