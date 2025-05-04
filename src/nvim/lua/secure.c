#include <lua.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/errors.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/lua/secure.h"
#include "nvim/memory.h"
#include "nvim/message.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "lua/secure.c.generated.h"
#endif

char *nlua_read_secure(const char *path)
{
  lua_State *const lstate = get_global_lstate();
  const int top = lua_gettop(lstate);

  lua_getglobal(lstate, "vim");
  lua_getfield(lstate, -1, "secure");
  lua_getfield(lstate, -1, "read");
  lua_pushstring(lstate, path);
  if (nlua_pcall(lstate, 1, 1)) {
    nlua_error(lstate, _("vim.secure.read: %.*s"));
    lua_settop(lstate, top);
    return NULL;
  }

  size_t len = 0;
  const char *contents = lua_tolstring(lstate, -1, &len);
  char *buf = NULL;
  if (contents != NULL) {
    // Add one to include trailing null byte
    buf = xcalloc(len + 1, sizeof(char));
    memcpy(buf, contents, len + 1);
  }

  lua_settop(lstate, top);
  return buf;
}

static bool nlua_trust(const char *action, const char *path)
{
  lua_State *const lstate = get_global_lstate();
  const int top = lua_gettop(lstate);

  lua_getglobal(lstate, "vim");
  lua_getfield(lstate, -1, "secure");
  lua_getfield(lstate, -1, "trust");

  lua_newtable(lstate);
  lua_pushstring(lstate, "action");
  lua_pushstring(lstate, action);
  lua_settable(lstate, -3);
  if (path == NULL) {
    lua_pushstring(lstate, "bufnr");
    lua_pushnumber(lstate, 0);
    lua_settable(lstate, -3);
  } else {
    lua_pushstring(lstate, "path");
    lua_pushstring(lstate, path);
    lua_settable(lstate, -3);
  }

  if (nlua_pcall(lstate, 1, 2)) {
    nlua_error(lstate, _("vim.secure.trust: %.*s"));
    lua_settop(lstate, top);
    return false;
  }

  bool success = lua_toboolean(lstate, -2);
  const char *msg = lua_tostring(lstate, -1);
  if (msg != NULL) {
    if (success) {
      if (strcmp(action, "allow") == 0) {
        smsg(0, "Allowed \"%s\" in trust database.", msg);
      } else if (strcmp(action, "deny") == 0) {
        smsg(0, "Denied \"%s\" in trust database.", msg);
      } else if (strcmp(action, "remove") == 0) {
        smsg(0, "Removed \"%s\" from trust database.", msg);
      }
    } else {
      semsg(e_trustfile, msg);
    }
  }

  lua_settop(lstate, top);
  return success;
}

void ex_trust(exarg_T *eap)
{
  const char *const p = skiptowhite(eap->arg);
  char *arg1 = xmemdupz(eap->arg, (size_t)(p - eap->arg));
  const char *action = "allow";
  const char *path = skipwhite(p);

  if (strcmp(arg1, "++deny") == 0) {
    action = "deny";
  } else if (strcmp(arg1, "++remove") == 0) {
    action = "remove";
  } else if (*arg1 != NUL) {
    semsg(e_invarg2, arg1);
    goto theend;
  }

  if (path[0] == NUL) {
    path = NULL;
  }

  nlua_trust(action, path);

theend:
  xfree(arg1);
}
