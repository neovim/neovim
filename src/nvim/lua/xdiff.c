#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/xdiff/xdiff.h"
#include "nvim/lua/xdiff.h"
#include "nvim/lua/converter.h"
#include "nvim/lua/executor.h"
#include "nvim/api/private/helpers.h"

#ifndef MIN
#define MIN(X,Y) ((X) < (Y) ? (X) : (Y))
#endif // MIN

static int write_string(void *priv, mmbuffer_t *mb, int nbuf) {
  luaL_Buffer *buf = (luaL_Buffer*)priv;
  for (int i = 0; i < nbuf; i++) {
    long size = mb[i].size;
    for (long total = 0; total < size; total += LUAL_BUFFERSIZE) {
      int tocopy = MIN((int)(size - total), LUAL_BUFFERSIZE);
      char* p = luaL_prepbuffer(buf);
      if (!p) {
        return -1;
      }
      memcpy(p, mb[i].ptr + total, tocopy);
      luaL_addsize(buf, tocopy);
    }
  }
  return 0;
}

static int hunk_func(long start_a, long count_a, long start_b, long count_b, void *cb_data) {
  lua_State *lstate = (lua_State*)cb_data;
  int fidx = lua_gettop(lstate);
  lua_pushvalue(lstate, fidx);
  lua_pushnumber(lstate, start_a);
  lua_pushnumber(lstate, count_a);
  lua_pushnumber(lstate, start_b);
  lua_pushnumber(lstate, count_b);

  if (lua_pcall(lstate, 4, 1, 0) != 0) {
    luaL_error(lstate, "error running function hunk_func': %s", lua_tostring(lstate, -1));
  }

  int r = 0;
  if (lua_isnumber(lstate, -1)) {
    r = (int)lua_tonumber(lstate, -1);
  }

  lua_pop(lstate, 1);
  lua_settop(lstate, fidx);
  return r;
}

static mmfile_t get_string_arg(lua_State *lstate, int idx) {
  if (lua_type(lstate, idx) != LUA_TSTRING) {
    luaL_argerror(lstate, idx, "expected string");
  }
  mmfile_t mf;
  mf.ptr = (char*)lua_tolstring(lstate, idx, (size_t*)&mf.size);
  return mf;
}

int nlua_xdl_diff(lua_State *lstate) {
  mmfile_t ma = get_string_arg(lstate, 1);
  mmfile_t mb = get_string_arg(lstate, 2);

  Error err = ERROR_INIT;

  xdemitconf_t cfg;
  xpparam_t    params;
  xdemitcb_t   ecb;

  memset(&cfg   , 0, sizeof(cfg));
  memset(&params, 0, sizeof(params));
  memset(&ecb   , 0, sizeof(ecb));

  if (lua_gettop(lstate) == 3) {
    if (lua_type(lstate, 3) != LUA_TTABLE) {
      return luaL_argerror(lstate, 3, "expected table");
    }

    struct {
      const char *name;
      unsigned long value;
    } flags[] = {
      {"ignore_whitespace"              , XDF_IGNORE_WHITESPACE},
      {"ignore_whitespace_change"       , XDF_IGNORE_WHITESPACE_CHANGE},
      {"ignore_whitespace_change_at_eol", XDF_IGNORE_WHITESPACE_AT_EOL},
      {"ignore_cr_at_eol"               , XDF_IGNORE_CR_AT_EOL},
    };

    const DictionaryOf(LuaRef) opts = nlua_pop_Dictionary(lstate, true, &err);

    for (size_t i = 0; i < opts.size; i++) {
      String k = opts.items[i].key;
      Object *v = &opts.items[i].value;
      if (strequal("hunk_func", k.data)) {
        if (v->type != kObjectTypeLuaRef) {
          api_set_error(&err, kErrorTypeValidation, "hunk_func is not a function");
          goto exit_0;
        }
        nlua_pushref(lstate, v->data.luaref);
        cfg.hunk_func = hunk_func;
      } else if (strequal("ctxlen", k.data)) {
        if (v->type != kObjectTypeInteger) {
          api_set_error(&err, kErrorTypeValidation, "ctxlen is not an integer");
          goto exit_0;
        }
        cfg.ctxlen = v->data.integer;
      } else if (strequal("interhunkctxlen", k.data)) {
        if (v->type != kObjectTypeInteger) {
          api_set_error(&err, kErrorTypeValidation, "interhunkctxlen is not an integer");
          goto exit_0;
        }
        cfg.interhunkctxlen = v->data.integer;
      } else if (strequal("emit_funcnames", k.data)) {
        if (v->type != kObjectTypeBoolean) {
          api_set_error(&err, kErrorTypeValidation, "emit_funcnames is not a boolean");
          goto exit_0;
        }
        if (v->data.boolean) {
          cfg.flags |= XDL_EMIT_FUNCNAMES;
        }
      } else if (strequal("emit_funccontext", k.data)) {
        if (v->type != kObjectTypeBoolean) {
          api_set_error(&err, kErrorTypeValidation, "emit_funccontext is not a boolean");
          goto exit_0;
        }
        if (v->data.boolean) {
          cfg.flags |= XDL_EMIT_FUNCCONTEXT;
        }
      } else {
        bool key_used = false;
        for (size_t j = 0; flags[j].name; j++) {
          if (strequal(flags[j].name, k.data)) {
            if (v->type != kObjectTypeBoolean) {
              api_set_error(&err, kErrorTypeValidation,
                            "%s is not a boolean", flags[j].name);
              goto exit_0;
            }
            if (v->data.boolean) {
              params.flags |= flags[j].value;
            }
            key_used = true;
            break;
          }
        }

        if (key_used) {
          continue;
        }

        api_set_error(&err, kErrorTypeValidation, "unexpected key: %s", k.data);
        goto exit_0;
      }
    }
    api_free_dictionary(opts);
  }

  luaL_Buffer buf;
  if (cfg.hunk_func == NULL) {
    luaL_buffinit(lstate, &buf);
    ecb.priv = &buf;
    ecb.outf = write_string;
  } else {
    ecb.priv = lstate;
  }

  if (xdl_diff(&ma, &mb, &params, &cfg, &ecb) == -1) {
    return luaL_error(lstate, "Error while performing diff operation");
  }

  if (cfg.hunk_func == NULL) {
    luaL_pushresult(&buf);
    return 1;
  }

exit_0:
  if (ERROR_SET(&err)) {
    luaL_where(lstate, 1);
    lua_pushstring(lstate, err.msg);
    api_clear_error(&err);
    lua_concat(lstate, 2);
    return lua_error(lstate);
  }
  return 0;
}
