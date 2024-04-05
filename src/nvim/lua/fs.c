#include <assert.h>
#include <lauxlib.h>
#include <stdlib.h>

#include "nvim/lua/fs.h"
#include "nvim/vim_defs.h"

#ifdef MSWIN
// uncrustify:off
# include <windows.h>  // NOLINT(llvm-include-order)
# include <fileapi.h>
// uncrustify:on
#endif

/// Get the current directory of a drive in Windows.
int fslua_get_drive_cwd(lua_State *L)
{
#ifdef MSWIN
  const char *drive = luaL_checkstring(L, 1);
  assert(isupper(drive[0]) && drive[1] == ':' && drive[2] == '\0');

  char buf[MAX_PATH];
  size_t len = GetFullPathNameA(drive, sizeof(buf), buf, NULL);

  lua_pushlstring(L, buf, len);
  return 1;
#else
  luaL_error(L, "Drive CWD is only supported on Windows");
  return 0;
#endif
}
