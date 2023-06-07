// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/fileio.h"
#include "nvim/memory.h"
#include "nvim/os/os.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/path.h"

/// Names of the environment variables, mapped to XDGVarType values
static const char *xdg_env_vars[] = {
  [kXDGConfigHome] = "XDG_CONFIG_HOME",
  [kXDGDataHome] = "XDG_DATA_HOME",
  [kXDGCacheHome] = "XDG_CACHE_HOME",
  [kXDGStateHome] = "XDG_STATE_HOME",
  [kXDGRuntimeDir] = "XDG_RUNTIME_DIR",
  [kXDGConfigDirs] = "XDG_CONFIG_DIRS",
  [kXDGDataDirs] = "XDG_DATA_DIRS",
};

#ifdef MSWIN
static const char *const xdg_defaults_env_vars[] = {
  [kXDGConfigHome] = "LOCALAPPDATA",
  [kXDGDataHome] = "LOCALAPPDATA",
  [kXDGCacheHome] = "TEMP",
  [kXDGStateHome] = "LOCALAPPDATA",
  [kXDGRuntimeDir] = NULL,  // Decided by vim_mktempdir().
  [kXDGConfigDirs] = NULL,
  [kXDGDataDirs] = NULL,
};
#endif

/// Defaults for XDGVarType values
///
/// Used in case environment variables contain nothing. Need to be expanded.
static const char *const xdg_defaults[] = {
#ifdef MSWIN
  [kXDGConfigHome] = "~\\AppData\\Local",
  [kXDGDataHome] = "~\\AppData\\Local",
  [kXDGCacheHome] = "~\\AppData\\Local\\Temp",
  [kXDGStateHome] = "~\\AppData\\Local",
  [kXDGRuntimeDir] = NULL,  // Decided by vim_mktempdir().
  [kXDGConfigDirs] = NULL,
  [kXDGDataDirs] = NULL,
#else
  [kXDGConfigHome] = "~/.config",
  [kXDGDataHome] = "~/.local/share",
  [kXDGCacheHome] = "~/.cache",
  [kXDGStateHome] = "~/.local/state",
  [kXDGRuntimeDir] = NULL,  // Decided by vim_mktempdir().
  [kXDGConfigDirs] = "/etc/xdg/",
  [kXDGDataDirs] = "/usr/local/share/:/usr/share/",
#endif
};

/// Get the value of $NVIM_APPNAME or "nvim" if not set.
///
/// @return $NVIM_APPNAME value
const char *get_appname(void)
{
  const char *env_val = os_getenv("NVIM_APPNAME");
  if (env_val == NULL || *env_val == '\0') {
    env_val = "nvim";
  }
  return env_val;
}

/// Ensure that APPNAME is valid. In particular, it cannot contain directory separators.
bool appname_is_valid(void)
{
  const char *appname = get_appname();
  const size_t appname_len = strlen(appname);
  for (size_t i = 0; i < appname_len; i++) {
    if (appname[i] == PATHSEP) {
      return false;
    }
  }
  return true;
}

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

  const char *env_val = os_getenv(env);

#ifdef MSWIN
  if (env_val == NULL && xdg_defaults_env_vars[idx] != NULL) {
    env_val = os_getenv(xdg_defaults_env_vars[idx]);
  }
#else
  if (env_val == NULL && os_env_exists(env)) {
    env_val = "";
  }
#endif

  char *ret = NULL;
  if (env_val != NULL) {
    ret = xstrdup(env_val);
  } else if (fallback) {
    ret = expand_env_save((char *)fallback);
  } else if (idx == kXDGRuntimeDir) {
    // Special-case: stdpath('run') is defined at startup.
    ret = vim_gettempdir();
    if (ret == NULL) {
      ret = "/tmp/";
    }
    size_t len = strlen(ret);
    ret = xstrndup(ret, len >= 2 ? len - 1 : 0);  // Trim trailing slash.
  }

  return ret;
}

/// Return Nvim-specific XDG directory subpath.
///
/// Windows: Uses "…/$NVIM_APPNAME-data" for kXDGDataHome to avoid storing
/// configuration and data files in the same path. #4403
///
/// @param[in]  idx  XDG directory to use.
///
/// @return [allocated] "{xdg_directory}/$NVIM_APPNAME"
char *get_xdg_home(const XDGVarType idx)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *dir = stdpaths_get_xdg_var(idx);
  const char *appname = get_appname();
  size_t appname_len = strlen(appname);
  assert(appname_len < (IOSIZE - sizeof("-data")));

  if (dir) {
    xstrlcpy(IObuff, appname, appname_len + 1);
#if defined(MSWIN)
    if (idx == kXDGDataHome || idx == kXDGStateHome) {
      xstrlcat(IObuff, "-data", IOSIZE);
    }
#endif
    dir = concat_fnames_realloc(dir, IObuff, true);

#ifdef BACKSLASH_IN_FILENAME
    slash_adjust(dir);
#endif
  }
  return dir;
}

/// Return subpath of $XDG_CACHE_HOME
///
/// @param[in]  fname  New component of the path.
///
/// @return [allocated] `$XDG_CACHE_HOME/$NVIM_APPNAME/{fname}`
char *stdpaths_user_cache_subpath(const char *fname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  return concat_fnames_realloc(get_xdg_home(kXDGCacheHome), fname, true);
}

/// Return subpath of $XDG_CONFIG_HOME
///
/// @param[in]  fname  New component of the path.
///
/// @return [allocated] `$XDG_CONFIG_HOME/$NVIM_APPNAME/{fname}`
char *stdpaths_user_conf_subpath(const char *fname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  return concat_fnames_realloc(get_xdg_home(kXDGConfigHome), fname, true);
}

/// Return subpath of $XDG_DATA_HOME
///
/// @param[in]  fname  New component of the path.
///
/// @return [allocated] `$XDG_DATA_HOME/$NVIM_APPNAME/{fname}`
char *stdpaths_user_data_subpath(const char *fname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  return concat_fnames_realloc(get_xdg_home(kXDGDataHome), fname, true);
}

/// Return subpath of $XDG_STATE_HOME
///
/// @param[in]  fname  New component of the path.
/// @param[in]  trailing_pathseps  Amount of trailing path separators to add.
/// @param[in]  escape_commas  If true, all commas will be escaped.
///
/// @return [allocated] `$XDG_STATE_HOME/$NVIM_APPNAME/{fname}`.
char *stdpaths_user_state_subpath(const char *fname, const size_t trailing_pathseps,
                                  const bool escape_commas)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  char *ret = concat_fnames_realloc(get_xdg_home(kXDGStateHome), fname, true);
  const size_t len = strlen(ret);
  const size_t numcommas = (escape_commas ? memcnt(ret, ',', len) : 0);
  if (numcommas || trailing_pathseps) {
    ret = xrealloc(ret, len + trailing_pathseps + numcommas + 1);
    for (size_t i = 0; i < len + numcommas; i++) {
      if (ret[i] == ',') {
        memmove(ret + i + 1, ret + i, len - i + numcommas);
        ret[i] = '\\';
        i++;
      }
    }
    if (trailing_pathseps) {
      memset(ret + len + numcommas, PATHSEP, trailing_pathseps);
    }
    ret[len + trailing_pathseps + numcommas] = NUL;
  }
  return ret;
}
