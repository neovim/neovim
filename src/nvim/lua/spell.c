#include <assert.h>
#include <lauxlib.h>
#include <limits.h>
#include <lua.h>
#include <stdbool.h>
#include <stddef.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/errors.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_defs.h"
#include "nvim/lua/spell.h"
#include "nvim/message.h"
#include "nvim/spell.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/spell.c.generated.h"  // IWYU pragma: keep
#endif

int nlua_spell_check(lua_State *lstate)
  FUNC_ATTR_NONNULL_ALL
{
  if (lua_gettop(lstate) < 1) {
    return luaL_error(lstate, "Expected 1 argument");
  }

  if (lua_type(lstate, 1) != LUA_TSTRING) {
    luaL_argerror(lstate, 1, "expected string");
  }

  const char *str = lua_tolstring(lstate, 1, NULL);

  // spell.c requires that 'spell' is enabled, so we need to temporarily enable
  // it before we can call spell functions.
  const int wo_spell_save = curwin->w_p_spell;

  if (!curwin->w_p_spell) {
    parse_spelllang(curwin);
    curwin->w_p_spell = true;
  }

  // Check 'spelllang'
  if (*curwin->w_s->b_p_spl == NUL) {
    emsg(_(e_no_spell));
    curwin->w_p_spell = wo_spell_save;
    return 0;
  }

  hlf_T attr = HLF_COUNT;
  size_t pos = 0;
  int capcol = -1;
  int no_res = 0;
  const char *result;

  lua_createtable(lstate, 0, 0);

  while (*str != NUL) {
    attr = HLF_COUNT;
    size_t len = spell_check(curwin, (char *)str, &attr, &capcol, false);
    assert(len <= INT_MAX);

    if (attr != HLF_COUNT) {
      lua_createtable(lstate, 3, 0);

      lua_pushlstring(lstate, str, len);
      lua_rawseti(lstate, -2, 1);

      result = attr == HLF_SPB
               ? "bad" : (attr == HLF_SPR
                          ? "rare" : (attr == HLF_SPL
                                      ? "local" : (attr == HLF_SPC
                                                   ? "caps" : NULL)));

      assert(result != NULL);

      lua_pushstring(lstate, result);
      lua_rawseti(lstate, -2, 2);

      // +1 for 1-indexing
      lua_pushinteger(lstate, (lua_Integer)pos + 1);
      lua_rawseti(lstate, -2, 3);

      lua_rawseti(lstate, -2, ++no_res);
    }

    str += len;
    pos += len;
    capcol -= (int)len;
  }

  // Restore 'spell'
  curwin->w_p_spell = wo_spell_save;
  return 1;
}

static const luaL_Reg spell_functions[] = {
  { "check", nlua_spell_check },
  { NULL, NULL }
};

int luaopen_spell(lua_State *L)
  FUNC_ATTR_NONNULL_ALL
{
  lua_newtable(L);
  luaL_register(L, NULL, spell_functions);
  return 1;
}
