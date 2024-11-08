#include <assert.h>
#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/ascii_defs.h"
#include "nvim/fileio.h"
#include "nvim/globals.h"
#include "nvim/memory.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/path.h"
#include "nvim/strings.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/stdpaths.c.generated.h"
#endif

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

/// Gets the value of $NVIM_APPNAME, or "nvim" if not set.
///
/// @param namelike Write "name-like" value (no path separators) in `NameBuff`.
///
/// @return $NVIM_APPNAME value
const char *get_appname(bool namelike)
{
  const char *env_val = os_getenv("NVIM_APPNAME");
  if (env_val == NULL || *env_val == NUL) {
    env_val = "nvim";
  }

  if (namelike) {
    // Appname may be a relative path, replace slashes to make it name-like.
    xstrlcpy(NameBuff, env_val, sizeof(NameBuff));
    memchrsub(NameBuff, '/', '-', sizeof(NameBuff));
    memchrsub(NameBuff, '\\', '-', sizeof(NameBuff));
  }

  return env_val;
}

/// Ensure that APPNAME is valid. Must be a name or relative path.
bool appname_is_valid(void)
{
  const char *appname = get_appname(false);
  if (path_is_absolute(appname)
      // TODO(justinmk): on Windows, path_is_absolute says "/" is NOT absolute. Should it?
      || strequal(appname, "/")
      || strequal(appname, "\\")
      || strequal(appname, ".")
      || strequal(appname, "..")
#ifdef BACKSLASH_IN_FILENAME
      || strstr(appname, "\\..") != NULL
      || strstr(appname, "..\\") != NULL
#endif
      || strstr(appname, "/..") != NULL
      || strstr(appname, "../") != NULL) {
    return false;
  }
  return true;
}

/// Remove duplicate directories in the given XDG directory.
/// @param[in]  List of directories possibly with duplicates
/// @param[out]  List of directories without duplicates
static char *xdg_remove_duplicate(char *ret, const char *sep)
{
  kvec_t(char *) data = KV_INITIAL_VALUE;
  char *saveptr;

  char *token = os_strtok(ret, sep, &saveptr);
  while (token != NULL) {
    // Check if the directory is not already in the list
    bool is_duplicate = false;
    for (size_t i = 0; i < data.size; i++) {
      if (path_fnamecmp(kv_A(data, i), token) == 0) {
        is_duplicate = true;
        break;
      }
    }
    // If it's not a duplicate, add it to the list
    if (!is_duplicate) {
      kv_push(data, token);
    }
    token = os_strtok(NULL, sep, &saveptr);
  }

  StringBuilder result = KV_INITIAL_VALUE;

  for (size_t i = 0; i < data.size; i++) {
    if (i == 0) {
      kv_printf(result, "%s", kv_A(data, i));
    } else {
      kv_printf(result, "%s%s", sep, kv_A(data, i));
    }
  }

  kv_destroy(data);
  xfree(ret);
  return result.items;
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
    ret = xmemdupz(ret, len >= 2 ? len - 1 : 0);  // Trim trailing slash.
  }

  if ((idx == kXDGDataDirs || idx == kXDGConfigDirs) && ret != NULL) {
    ret = xdg_remove_duplicate(ret, ENV_SEPSTR);
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
  const char *appname = get_appname(false);
  size_t appname_len = strlen(appname);
  assert(appname_len < (IOSIZE - sizeof("-data")));

  if (dir) {
    xmemcpyz(IObuff, appname, appname_len);
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
