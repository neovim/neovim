#include <stdbool.h>

#include "nvim/os/stdpaths_defs.h"
#include "nvim/os/os.h"
#include "nvim/path.h"
#include "nvim/memory.h"
#include "nvim/ascii.h"

/// Names of the environment variables, mapped to XDGVarType values
static const char *xdg_env_vars[] = {
  [kXDGConfigHome] = "XDG_CONFIG_HOME",
  [kXDGDataHome] = "XDG_DATA_HOME",
  [kXDGCacheHome] = "XDG_CACHE_HOME",
  [kXDGRuntimeDir] = "XDG_RUNTIME_DIR",
  [kXDGConfigDirs] = "XDG_CONFIG_DIRS",
  [kXDGDataDirs] = "XDG_DATA_DIRS",
};

/// Defaults for XDGVarType values
///
/// Used in case environment variables contain nothing. Need to be expanded.
static const char *const xdg_defaults[] = {
#ifdef WIN32
  // Windows
  [kXDGConfigHome] = "$LOCALAPPDATA",
  [kXDGDataHome]   = "$LOCALAPPDATA",
  [kXDGCacheHome]  = "$TEMP",
  [kXDGRuntimeDir] = NULL,
  [kXDGConfigDirs] = NULL,
  [kXDGDataDirs] = NULL,
#else
  // Linux, BSD, CYGWIN, Apple
  [kXDGConfigHome] = "~/.config",
  [kXDGDataHome] = "~/.local/share",
  [kXDGCacheHome] = "~/.cache",
  [kXDGRuntimeDir] = NULL,
  [kXDGConfigDirs] = "/etc/xdg/",
  [kXDGDataDirs] = "/usr/local/share/:/usr/share/",
#endif
};

/// Return XDG variable value
///
/// @param[in]  idx  XDG variable to use.
///
/// @return [allocated] variable value.
char *stdpaths_get_xdg_var(const XDGVarType idx)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *const env = xdg_env_vars[idx];
  const char *const fallback = xdg_defaults[idx];

  const char *const env_val = os_getenv(env);
  char *ret = NULL;
  if (env_val != NULL) {
    ret = xstrdup(env_val);
  } else if (fallback) {
    ret = (char *) expand_env_save((char_u *)fallback);
  }

  return ret;
}

/// Return nvim-specific XDG directory subpath
///
/// @param[in]  idx  XDG directory to use.
///
/// @return [allocated] `{xdg_directory}/nvim`
static char *get_xdg_home(const XDGVarType idx)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *dir = stdpaths_get_xdg_var(idx);
  if (dir) {
    dir = concat_fnames_realloc(dir, "nvim", true);
  }
  return dir;
}

/// Return subpath of $XDG_CONFIG_HOME
///
/// @param[in]  fname  New component of the path.
///
/// @return [allocated] `$XDG_CONFIG_HOME/nvim/{fname}`
char *stdpaths_user_conf_subpath(const char *fname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  return concat_fnames_realloc(get_xdg_home(kXDGConfigHome), fname, true);
}

/// Return subpath of $XDG_DATA_HOME
///
/// @param[in]  fname  New component of the path.
/// @param[in]  trailing_pathseps  Amount of trailing path separators to add.
///
/// @return [allocated] `$XDG_DATA_HOME/nvim/{fname}`
char *stdpaths_user_data_subpath(const char *fname,
                                 const size_t trailing_pathseps)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  char *ret = concat_fnames_realloc(get_xdg_home(kXDGDataHome), fname, true);
  if (trailing_pathseps) {
    const size_t len = strlen(ret);
    ret = xrealloc(ret, len + trailing_pathseps + 1);
    memset(ret + len, PATHSEP, trailing_pathseps);
    ret[len + trailing_pathseps] = NUL;
  }
  return ret;
}
