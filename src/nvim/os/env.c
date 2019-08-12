// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Environment inspection

#include <assert.h>
#include <uv.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/fileio.h"
#include "nvim/os/os.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/path.h"
#include "nvim/macros.h"
#include "nvim/strings.h"
#include "nvim/eval.h"
#include "nvim/ex_getln.h"
#include "nvim/version.h"
#include "nvim/map.h"

#ifdef WIN32
#include "nvim/mbyte.h"  // for utf8_to_utf16, utf16_to_utf8
#endif

#ifdef HAVE__NSGETENVIRON
#include <crt_externs.h>
#endif

#ifdef HAVE_SYS_UTSNAME_H
#include <sys/utsname.h>
#endif

// Because `uv_os_getenv` requires allocating, we must manage a map to maintain
// the behavior of `os_getenv`.
static PMap(cstr_t) *envmap;
static uv_mutex_t mutex;

void env_init(void)
{
  envmap = pmap_new(cstr_t)();
  uv_mutex_init(&mutex);
}

/// Like getenv(), but returns NULL if the variable is empty.
/// @see os_env_exists
const char *os_getenv(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  char *e;
  size_t size = 64;
  if (name[0] == '\0') {
    return NULL;
  }
  uv_mutex_lock(&mutex);
  if (pmap_has(cstr_t)(envmap, name)
      && !!(e = (char *)pmap_get(cstr_t)(envmap, name))) {
    if (e[0] != '\0') {
      // Found non-empty cached env var.
      // NOTE: This risks incoherence if an in-process library changes the
      //       environment without going through our os_setenv() wrapper.  If
      //       that turns out to be a problem, we can just remove this codepath.
      goto end;
    }
    pmap_del2(envmap, name);
  }
  e = xmalloc(size);
  int r = uv_os_getenv(name, e, &size);
  if (r == UV_ENOBUFS) {
    e = xrealloc(e, size);
    r = uv_os_getenv(name, e, &size);
  }
  if (r != 0 || size == 0 || e[0] == '\0') {
    xfree(e);
    e = NULL;
    if (r != 0 && r != UV_ENOENT && r != UV_UNKNOWN) {
      ELOG("uv_os_getenv(%s) failed: %d %s", name, r, uv_err_name(r));
    }
    goto end;
  }
  pmap_put(cstr_t)(envmap, xstrdup(name), e);
end:
  uv_mutex_unlock(&mutex);
  return (e == NULL || size == 0 || e[0] == '\0') ? NULL : e;
}

/// Returns true if environment variable `name` is defined (even if empty).
/// Returns false if not found (UV_ENOENT) or other failure.
bool os_env_exists(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  if (name[0] == '\0') {
    return false;
  }
  // Use a tiny buffer because we don't care about the value: if uv_os_getenv()
  // returns UV_ENOBUFS, the env var was found.
  char buf[1];
  size_t size = sizeof(buf);
  int r = uv_os_getenv(name, buf, &size);
  assert(r != UV_EINVAL);
  if (r != 0 && r != UV_ENOENT && r != UV_ENOBUFS) {
    ELOG("uv_os_getenv(%s) failed: %d %s", name, r, uv_err_name(r));
#ifdef WIN32
    return (r == UV_UNKNOWN);
#endif
  }
  return (r == 0 || r == UV_ENOBUFS);
}

/// Sets an environment variable.
///
/// Windows (Vim-compat): Empty string (:let $FOO="") undefines the env var.
///
/// @warning Existing pointers to the result of os_getenv("foo") are
///          INVALID after os_setenv("foo", …).
int os_setenv(const char *name, const char *value, int overwrite)
  FUNC_ATTR_NONNULL_ALL
{
  if (name[0] == '\0') {
    return -1;
  }
#ifdef WIN32
  if (!overwrite && os_getenv(name) != NULL) {
    return 0;
  }
  if (value[0] == '\0') {
    // Windows (Vim-compat): Empty string undefines the env var.
    return os_unsetenv(name);
  }
#else
  if (!overwrite && os_env_exists(name)) {
    return 0;
  }
#endif
  uv_mutex_lock(&mutex);
  int r = uv_os_setenv(name, value);
  assert(r != UV_EINVAL);
  // Destroy the old map item. Do this AFTER uv_os_setenv(), because `value`
  // could be a previous os_getenv() result.
  pmap_del2(envmap, name);
  if (r != 0) {
    ELOG("uv_os_setenv(%s) failed: %d %s", name, r, uv_err_name(r));
  }
  uv_mutex_unlock(&mutex);
  return r == 0 ? 0 : -1;
}

/// Unset environment variable
int os_unsetenv(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  if (name[0] == '\0') {
    return -1;
  }
  uv_mutex_lock(&mutex);
  pmap_del2(envmap, name);
  int r = uv_os_unsetenv(name);
  if (r != 0) {
    ELOG("uv_os_unsetenv(%s) failed: %d %s", name, r, uv_err_name(r));
  }
  uv_mutex_unlock(&mutex);
  return r == 0 ? 0 : -1;
}

char *os_getenvname_at_index(size_t index)
{
#ifdef _WIN32
  wchar_t *env = GetEnvironmentStringsW();
  if (!env) {
    return NULL;
  }
  char *name = NULL;
  size_t current_index = 0;
  // GetEnvironmentStringsW() result has this format:
  //    var1=value1\0var2=value2\0...varN=valueN\0\0
  for (wchar_t *it = env; *it != L'\0' || *(it + 1) != L'\0'; it++) {
    if (index == current_index) {
      char *utf8_str;
      int conversion_result = utf16_to_utf8(it, &utf8_str);
      if (conversion_result != 0) {
        EMSG2("utf16_to_utf8 failed: %d", conversion_result);
        break;
      }
      size_t namesize = 0;
      while (utf8_str[namesize] != '=' && utf8_str[namesize] != NUL) {
        namesize++;
      }
      name = (char *)vim_strnsave((char_u *)utf8_str, namesize);
      xfree(utf8_str);
      break;
    }
    if (*it == L'\0') {
      current_index++;
    }
  }

  FreeEnvironmentStringsW(env);
  return name;
#else
# if defined(HAVE__NSGETENVIRON)
  char **environ = *_NSGetEnviron();
# else
  extern char         **environ;
# endif
  // Check if index is inside the environ array and is not the last element.
  for (size_t i = 0; i <= index; i++) {
    if (environ[i] == NULL) {
      return NULL;
    }
  }
  char *str = environ[index];
  size_t namesize = 0;
  while (str[namesize] != '=' && str[namesize] != NUL) {
    namesize++;
  }
  char *name = (char *)vim_strnsave((char_u *)str, namesize);
  return name;
#endif
}

/// Get the process ID of the Neovim process.
///
/// @return the process ID.
int64_t os_get_pid(void)
{
#ifdef _WIN32
  return (int64_t)GetCurrentProcessId();
#else
  return (int64_t)getpid();
#endif
}

/// Gets the hostname of the current machine.
///
/// @param hostname   Buffer to store the hostname.
/// @param size       Size of `hostname`.
void os_get_hostname(char *hostname, size_t size)
{
#ifdef HAVE_SYS_UTSNAME_H
  struct utsname vutsname;

  if (uname(&vutsname) < 0) {
    *hostname = '\0';
  } else {
    xstrlcpy(hostname, vutsname.nodename, size);
  }
#elif defined(WIN32)
  wchar_t host_utf16[MAX_COMPUTERNAME_LENGTH + 1];
  DWORD host_wsize = sizeof(host_utf16) / sizeof(host_utf16[0]);
  if (GetComputerNameW(host_utf16, &host_wsize) == 0) {
    *hostname = '\0';
    DWORD err = GetLastError();
    EMSG2("GetComputerNameW failed: %d", err);
    return;
  }
  host_utf16[host_wsize] = '\0';

  char *host_utf8;
  int conversion_result = utf16_to_utf8(host_utf16, &host_utf8);
  if (conversion_result != 0) {
    EMSG2("utf16_to_utf8 failed: %d", conversion_result);
    return;
  }
  xstrlcpy(hostname, host_utf8, size);
  xfree(host_utf8);
#else
  EMSG("os_get_hostname failed: missing uname()");
  *hostname = '\0';
#endif
}

/// To get the "real" home directory:
///   - get value of $HOME
/// For Unix:
///   - go to that directory
///   - do os_dirname() to get the real name of that directory.
/// This also works with mounts and links.
/// Don't do this for Windows, it will change the "current dir" for a drive.
static char *homedir = NULL;

void init_homedir(void)
{
  // In case we are called a second time.
  xfree(homedir);
  homedir = NULL;

  const char *var = os_getenv("HOME");

#ifdef WIN32
  // Typically, $HOME is not defined on Windows, unless the user has
  // specifically defined it for Vim's sake. However, on Windows NT
  // platforms, $HOMEDRIVE and $HOMEPATH are automatically defined for
  // each user. Try constructing $HOME from these.
  if (var == NULL) {
    const char *homedrive = os_getenv("HOMEDRIVE");
    const char *homepath = os_getenv("HOMEPATH");
    if (homepath == NULL) {
      homepath = "\\";
    }
    if (homedrive != NULL
        && strlen(homedrive) + strlen(homepath) < MAXPATHL) {
      snprintf(os_buf, MAXPATHL, "%s%s", homedrive, homepath);
      if (os_buf[0] != NUL) {
        var = os_buf;
      }
    }
  }
  if (var == NULL) {
    var = os_getenv("USERPROFILE");
  }

  // Weird but true: $HOME may contain an indirect reference to another
  // variable, esp. "%USERPROFILE%".  Happens when $USERPROFILE isn't set
  // when $HOME is being set.
  if (var != NULL && *var == '%') {
    const char *p = strchr(var + 1, '%');
    if (p != NULL) {
      vim_snprintf(os_buf, (size_t)(p - var), "%s", var + 1);
      const char *exp = os_getenv(os_buf);
      if (exp != NULL && *exp != NUL
          && STRLEN(exp) + STRLEN(p) < MAXPATHL) {
        vim_snprintf(os_buf, MAXPATHL, "%s%s", exp, p + 1);
        var = os_buf;
      }
    }
  }

  // Default home dir is C:/
  // Best assumption we can make in such a situation.
  if (var == NULL
      // Empty means "undefined"
      || *var == NUL) {
    var = "C:/";
  }
#endif

  if (var != NULL) {
#ifdef UNIX
    // Change to the directory and get the actual path.  This resolves
    // links.  Don't do it when we can't return.
    if (os_dirname((char_u *)os_buf, MAXPATHL) == OK && os_chdir(os_buf) == 0) {
      if (!os_chdir(var) && os_dirname(IObuff, IOSIZE) == OK) {
        var = (char *)IObuff;
      }
      if (os_chdir(os_buf) != 0) {
        EMSG(_(e_prev_dir));
      }
    }
#endif
    homedir = xstrdup(var);
  }
}

#if defined(EXITFREE)

void free_homedir(void)
{
  xfree(homedir);
}

#endif

/// Call expand_env() and store the result in an allocated string.
/// This is not very memory efficient, this expects the result to be freed
/// again soon.
/// @param src String containing environment variables to expand
/// @see {expand_env}
char_u *expand_env_save(char_u *src)
{
  return expand_env_save_opt(src, false);
}

/// Similar to expand_env_save() but when "one" is `true` handle the string as
/// one file name, i.e. only expand "~" at the start.
/// @param src String containing environment variables to expand
/// @param one Should treat as only one file name
/// @see {expand_env}
char_u *expand_env_save_opt(char_u *src, bool one)
{
  char_u *p = xmalloc(MAXPATHL);
  expand_env_esc(src, p, MAXPATHL, false, one, NULL);
  return p;
}

/// Expand environment variable with path name.
/// "~/" is also expanded, using $HOME. For Unix "~user/" is expanded.
/// Skips over "\ ", "\~" and "\$" (not for Win32 though).
/// If anything fails no expansion is done and dst equals src.
///
/// @param src        Input string e.g. "$HOME/vim.hlp"
/// @param dst[out]   Where to put the result
/// @param dstlen     Maximum length of the result
void expand_env(char_u *src, char_u *dst, int dstlen)
{
  expand_env_esc(src, dst, dstlen, false, false, NULL);
}

/// Expand environment variable with path name and escaping.
/// @see expand_env
///
/// @param srcp       Input string e.g. "$HOME/vim.hlp"
/// @param dst[out]   Where to put the result
/// @param dstlen     Maximum length of the result
/// @param esc        Escape spaces in expanded variables
/// @param one        `srcp` is a single filename
/// @param prefix     Start again after this (can be NULL)
void expand_env_esc(char_u *restrict srcp,
                    char_u *restrict dst,
                    int dstlen,
                    bool esc,
                    bool one,
                    char_u *prefix)
{
  char_u      *tail;
  char_u      *var;
  bool copy_char;
  bool mustfree;  // var was allocated, need to free it later
  bool at_start = true;  // at start of a name

  int prefix_len = (prefix == NULL) ? 0 : (int)STRLEN(prefix);

  char_u *src = skipwhite(srcp);
  dstlen--;  // leave one char space for "\,"
  while (*src && dstlen > 0) {
    // Skip over `=expr`.
    if (src[0] == '`' && src[1] == '=') {
      var = src;
      src += 2;
      (void)skip_expr(&src);
      if (*src == '`') {
        src++;
      }
      size_t len = (size_t)(src - var);
      if (len > (size_t)dstlen) {
        len = (size_t)dstlen;
      }
      memcpy((char *)dst, (char *)var, len);
      dst += len;
      dstlen -= (int)len;
      continue;
    }

    copy_char = true;
    if ((*src == '$') || (*src == '~' && at_start)) {
      mustfree = false;

      // The variable name is copied into dst temporarily, because it may
      // be a string in read-only memory and a NUL needs to be appended.
      if (*src != '~') {  // environment var
        tail = src + 1;
        var = dst;
        int c = dstlen - 1;

#ifdef UNIX
        // Unix has ${var-name} type environment vars
        if (*tail == '{' && !vim_isIDc('{')) {
          tail++;               // ignore '{'
          while (c-- > 0 && *tail != NUL && *tail != '}') {
            *var++ = *tail++;
          }
        } else // NOLINT
#endif
        {
          while (c-- > 0 && *tail != NUL && vim_isIDc(*tail)) {
            *var++ = *tail++;
          }
        }

#if defined(UNIX)
        // Verify that we have found the end of a Unix ${VAR} style variable
        if (src[1] == '{' && *tail != '}') {
          var = NULL;
        } else {
          if (src[1] == '{') {
            tail++;
          }
#endif
        *var = NUL;
        var = (char_u *)vim_getenv((char *)dst);
        mustfree = true;
#if defined(UNIX)
        }
#endif
      } else if (src[1] == NUL  // home directory
                 || vim_ispathsep(src[1])
                 || vim_strchr((char_u *)" ,\t\n", src[1]) != NULL) {
        var = (char_u *)homedir;
        tail = src + 1;
      } else {  // user directory
#if defined(UNIX)
        // Copy ~user to dst[], so we can put a NUL after it.
        tail = src;
        var = dst;
        int c = dstlen - 1;
        while (c-- > 0
               && *tail
               && vim_isfilec(*tail)
               && !vim_ispathsep(*tail)) {
          *var++ = *tail++;
        }
        *var = NUL;
        // Get the user directory. If this fails the shell is used to expand
        // ~user, which is slower and may fail on old versions of /bin/sh.
        var = (*dst == NUL) ? NULL
                            : (char_u *)os_get_user_directory((char *)dst + 1);
        mustfree = true;
        if (var == NULL) {
          expand_T xpc;

          ExpandInit(&xpc);
          xpc.xp_context = EXPAND_FILES;
          var = ExpandOne(&xpc, dst, NULL,
              WILD_ADD_SLASH|WILD_SILENT, WILD_EXPAND_FREE);
          mustfree = true;
        }
#else
        // cannot expand user's home directory, so don't try
        var = NULL;
        tail = (char_u *)"";  // for gcc
#endif  // UNIX
      }

#ifdef BACKSLASH_IN_FILENAME
      // If 'shellslash' is set change backslashes to forward slashes.
      // Can't use slash_adjust(), p_ssl may be set temporarily.
      if (p_ssl && var != NULL && vim_strchr(var, '\\') != NULL) {
        char_u  *p = vim_strsave(var);

        if (mustfree) {
          xfree(var);
        }
        var = p;
        mustfree = true;
        forward_slash(var);
      }
#endif

      // If "var" contains white space, escape it with a backslash.
      // Required for ":e ~/tt" when $HOME includes a space.
      if (esc && var != NULL && vim_strpbrk(var, (char_u *)" \t") != NULL) {
        char_u  *p = vim_strsave_escaped(var, (char_u *)" \t");

        if (mustfree) {
          xfree(var);
        }
        var = p;
        mustfree = true;
      }

      if (var != NULL && *var != NUL
          && (STRLEN(var) + STRLEN(tail) + 1 < (unsigned)dstlen)) {
        STRCPY(dst, var);
        dstlen -= (int)STRLEN(var);
        int c = (int)STRLEN(var);
        // if var[] ends in a path separator and tail[] starts
        // with it, skip a character
        if (*var != NUL && after_pathsep((char *)dst, (char *)dst + c)
#if defined(BACKSLASH_IN_FILENAME)
            && dst[-1] != ':'
#endif
            && vim_ispathsep(*tail))
          ++tail;
        dst += c;
        src = tail;
        copy_char = false;
      }
      if (mustfree) {
        xfree(var);
      }
    }

    if (copy_char) {  // copy at least one char
      // Recognize the start of a new name, for '~'.
      // Don't do this when "one" is true, to avoid expanding "~" in
      // ":edit foo ~ foo".
      at_start = false;
      if (src[0] == '\\' && src[1] != NUL) {
        *dst++ = *src++;
        --dstlen;
      } else if ((src[0] == ' ' || src[0] == ',') && !one) {
        at_start = true;
      }
      if (dstlen > 0) {
        *dst++ = *src++;
        dstlen--;

        if (prefix != NULL
            && src - prefix_len >= srcp
            && STRNCMP(src - prefix_len, prefix, prefix_len) == 0) {
          at_start = true;
        }
      }
    }
  }
  *dst = NUL;
}

/// Check if the directory "vimdir/<version>" or "vimdir/runtime" exists.
/// Return NULL if not, return its name in allocated memory otherwise.
/// @param vimdir directory to test
static char *vim_version_dir(const char *vimdir)
{
  if (vimdir == NULL || *vimdir == NUL) {
    return NULL;
  }
  char *p = concat_fnames(vimdir, VIM_VERSION_NODOT, true);
  if (os_isdir((char_u *)p)) {
    return p;
  }
  xfree(p);
  p = concat_fnames(vimdir, RUNTIME_DIRNAME, true);
  if (os_isdir((char_u *)p)) {
    return p;
  }
  xfree(p);
  return NULL;
}

/// If `dirname + "/"` precedes `pend` in the path, return the pointer to
/// `dirname + "/" + pend`.  Otherwise return `pend`.
///
/// Examples (path = /usr/local/share/nvim/runtime/doc/help.txt):
///
///   pend    = help.txt
///   dirname = doc
///   -> doc/help.txt
///
///   pend    = doc/help.txt
///   dirname = runtime
///   -> runtime/doc/help.txt
///
///   pend    = runtime/doc/help.txt
///   dirname = vim74
///   -> runtime/doc/help.txt
///
/// @param path    Path to a file
/// @param pend    A suffix of the path
/// @param dirname The immediate path fragment before the pend
/// @return The new pend including dirname or just pend
static char *remove_tail(char *path, char *pend, char *dirname)
{
  size_t len = STRLEN(dirname);
  char *new_tail = pend - len - 1;

  if (new_tail >= path
      && fnamencmp((char_u *)new_tail, (char_u *)dirname, len) == 0
      && (new_tail == path || after_pathsep(path, new_tail))) {
    return new_tail;
  }
  return pend;
}

/// Iterates $PATH-like delimited list `val`.
///
/// @note Environment variables must not be modified during iteration.
///
/// @param[in]   delim Delimiter character.
/// @param[in]   val   Value of the environment variable to iterate over.
/// @param[in]   iter  Pointer used for iteration. Must be NULL on first
///                    iteration.
/// @param[out]  dir   Location where pointer to the start of the current
///                    directory name should be saved. May be set to NULL.
/// @param[out]  len   Location where current directory length should be saved.
///
/// @return Next iter argument value or NULL when iteration should stop.
const void *vim_env_iter(const char delim,
                         const char *const val,
                         const void *const iter,
                         const char **const dir,
                         size_t *const len)
  FUNC_ATTR_NONNULL_ARG(2, 4, 5) FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *varval = (const char *) iter;
  if (varval == NULL) {
    varval = val;
  }
  *dir = varval;
  const char *const dirend = strchr(varval, delim);
  if (dirend == NULL) {
    *len = strlen(varval);
    return NULL;
  } else {
    *len = (size_t) (dirend - varval);
    return dirend + 1;
  }
}

/// Iterates $PATH-like delimited list `val` in reverse order.
///
/// @note Environment variables must not be modified during iteration.
///
/// @param[in]   delim Delimiter character.
/// @param[in]   val   Value of the environment variable to iterate over.
/// @param[in]   iter  Pointer used for iteration. Must be NULL on first
///                    iteration.
/// @param[out]  dir   Location where pointer to the start of the current
///                    directory name should be saved. May be set to NULL.
/// @param[out]  len   Location where current directory length should be saved.
///
/// @return Next iter argument value or NULL when iteration should stop.
const void *vim_env_iter_rev(const char delim,
                             const char *const val,
                             const void *const iter,
                             const char **const dir,
                             size_t *const len)
  FUNC_ATTR_NONNULL_ARG(2, 4, 5) FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *varend = (const char *) iter;
  if (varend == NULL) {
    varend = val + strlen(val) - 1;
  }
  const size_t varlen = (size_t)(varend - val) + 1;
  const char *const colon = xmemrchr(val, (uint8_t)delim, varlen);
  if (colon == NULL) {
    *len = varlen;
    *dir = val;
    return NULL;
  } else {
    *dir = colon + 1;
    *len = (size_t) (varend - colon);
    return colon - 1;
  }
}

/// Vim getenv() wrapper with special handling of $HOME, $VIM, $VIMRUNTIME,
/// allowing the user to override the Nvim runtime directory at runtime.
/// Result must be freed by the caller.
///
/// @param name Environment variable to expand
/// @return [allocated] Expanded environment variable, or NULL
char *vim_getenv(const char *name)
{
  // init_path() should have been called before now.
  assert(get_vim_var_str(VV_PROGPATH)[0] != NUL);

#ifdef WIN32
  if (strcmp(name, "HOME") == 0) {
    return xstrdup(homedir);
  }
#endif

  const char *kos_env_path = os_getenv(name);
  if (kos_env_path != NULL) {
    return xstrdup(kos_env_path);
  }

  bool vimruntime = (strcmp(name, "VIMRUNTIME") == 0);
  if (!vimruntime && strcmp(name, "VIM") != 0) {
    return NULL;
  }

  // When expanding $VIMRUNTIME fails, try using $VIM/vim<version> or $VIM.
  // Don't do this when default_vimruntime_dir is non-empty.
  char *vim_path = NULL;
  if (vimruntime
#ifdef HAVE_PATHDEF
      && *default_vimruntime_dir == NUL
#endif
      ) {
    kos_env_path = os_getenv("VIM");
    if (kos_env_path != NULL) {
      vim_path = vim_version_dir(kos_env_path);
      if (vim_path == NULL) {
        vim_path = xstrdup(kos_env_path);
      }
    }
  }

  // When expanding $VIM or $VIMRUNTIME fails, try using:
  // - the directory name from 'helpfile' (unless it contains '$')
  // - the executable name from argv[0]
  if (vim_path == NULL) {
    if (p_hf != NULL && vim_strchr(p_hf, '$') == NULL) {
      vim_path = (char *)p_hf;
    }

    char exe_name[MAXPATHL];
    // Find runtime path relative to the nvim binary: ../share/nvim/runtime
    if (vim_path == NULL) {
      xstrlcpy(exe_name, (char *)get_vim_var_str(VV_PROGPATH),
               sizeof(exe_name));
      char *path_end = (char *)path_tail_with_sep((char_u *)exe_name);
      *path_end = '\0';  // remove the trailing "nvim.exe"
      path_end = (char *)path_tail((char_u *)exe_name);
      *path_end = '\0';  // remove the trailing "bin/"
      if (append_path(
          exe_name,
          "share" _PATHSEPSTR "nvim" _PATHSEPSTR "runtime" _PATHSEPSTR,
          MAXPATHL) == OK) {
        vim_path = exe_name;  // -V507
      }
    }

    if (vim_path != NULL) {
      // remove the file name
      char *vim_path_end = (char *)path_tail((char_u *)vim_path);

      // remove "doc/" from 'helpfile', if present
      if (vim_path == (char *)p_hf) {
        vim_path_end = remove_tail(vim_path, vim_path_end, "doc");
      }

      // for $VIM, remove "runtime/" or "vim54/", if present
      if (!vimruntime) {
        vim_path_end = remove_tail(vim_path, vim_path_end, RUNTIME_DIRNAME);
        vim_path_end = remove_tail(vim_path, vim_path_end, VIM_VERSION_NODOT);
      }

      // remove trailing path separator
      if (vim_path_end > vim_path && after_pathsep(vim_path, vim_path_end)) {
        vim_path_end--;
      }

      // check that the result is a directory name
      assert(vim_path_end >= vim_path);
      vim_path = xstrndup(vim_path, (size_t)(vim_path_end - vim_path));

      if (!os_isdir((char_u *)vim_path)) {
        xfree(vim_path);
        vim_path = NULL;
      }
    }
    assert(vim_path != exe_name);
  }

#ifdef HAVE_PATHDEF
  // When there is a pathdef.c file we can use default_vim_dir and
  // default_vimruntime_dir
  if (vim_path == NULL) {
    // Only use default_vimruntime_dir when it is not empty
    if (vimruntime && *default_vimruntime_dir != NUL) {
      vim_path = xstrdup(default_vimruntime_dir);
    } else if (*default_vim_dir != NUL) {
      if (vimruntime
          && (vim_path = vim_version_dir(default_vim_dir)) == NULL) {
        vim_path = xstrdup(default_vim_dir);
      }
    }
  }
#endif

  // Set the environment variable, so that the new value can be found fast
  // next time, and others can also use it (e.g. Perl).
  if (vim_path != NULL) {
    if (vimruntime) {
      os_setenv("VIMRUNTIME", vim_path, 1);
      didset_vimruntime = true;
    } else {
      os_setenv("VIM", vim_path, 1);
      didset_vim = true;
    }
  }
  return vim_path;
}

/// Replace home directory by "~" in each space or comma separated file name in
/// 'src'.
///
/// Replace home directory with tilde in each file name
///
/// If anything fails (except when out of space) dst equals src.
///
/// @param[in]  buf  When not NULL, uses this buffer to check whether it is
///                  a help file. If it is then path to file is removed
///                  completely, `one` is ignored and assumed to be true.
/// @param[in]  src  Input file names. Assumed to be a space/comma separated
///                  list unless `one` is true.
/// @param[out]  dst  Where to put the result.
/// @param[in]  dstlen  Destination length.
/// @param[in]  one  If true, assumes source is a single file name and not
///                  a list of them.
///
/// @return length of the string put into dst, does not include NUL byte.
size_t home_replace(const buf_T *const buf, const char_u *src,
                    char_u *const dst, size_t dstlen, const bool one)
  FUNC_ATTR_NONNULL_ARG(3)
{
  size_t dirlen = 0;
  size_t envlen = 0;

  if (src == NULL) {
    *dst = NUL;
    return 0;
  }

  if (buf != NULL && buf->b_help) {
    const size_t dlen = xstrlcpy((char *)dst, (char *)path_tail(src), dstlen);
    return MIN(dlen, dstlen - 1);
  }

  // We check both the value of the $HOME environment variable and the
  // "real" home directory.
  if (homedir != NULL) {
    dirlen = strlen(homedir);
  }

  const char *homedir_env = os_getenv("HOME");
#ifdef WIN32
  if (homedir_env == NULL) {
    homedir_env = os_getenv("USERPROFILE");
  }
#endif
  char *homedir_env_mod = (char *)homedir_env;
  bool must_free = false;

  if (homedir_env_mod != NULL && *homedir_env_mod == '~') {
    must_free = true;
    size_t usedlen = 0;
    size_t flen = strlen(homedir_env_mod);
    char_u *fbuf = NULL;
    (void)modify_fname((char_u *)":p", false, &usedlen,
                       (char_u **)&homedir_env_mod, &fbuf, &flen);
    flen = strlen(homedir_env_mod);
    assert(homedir_env_mod != homedir_env);
    if (vim_ispathsep(homedir_env_mod[flen - 1])) {
      // Remove the trailing / that is added to a directory.
      homedir_env_mod[flen - 1] = NUL;
    }
  }

  if (homedir_env_mod != NULL) {
    envlen = strlen(homedir_env_mod);
  }

  if (!one) {
    src = skipwhite(src);
  }
  char *dst_p = (char *)dst;
  while (*src && dstlen > 0) {
    // Here we are at the beginning of a file name.
    // First, check to see if the beginning of the file name matches
    // $HOME or the "real" home directory. Check that there is a '/'
    // after the match (so that if e.g. the file is "/home/pieter/bla",
    // and the home directory is "/home/piet", the file does not end up
    // as "~er/bla" (which would seem to indicate the file "bla" in user
    // er's home directory)).
    char *p = homedir;
    size_t len = dirlen;
    for (;;) {
      if (len
          && fnamencmp(src, (char_u *)p, len) == 0
          && (vim_ispathsep(src[len])
              || (!one && (src[len] == ',' || src[len] == ' '))
              || src[len] == NUL)) {
        src += len;
        if (--dstlen > 0) {
          *dst_p++ = '~';
        }

        // If it's just the home directory, add  "/".
        if (!vim_ispathsep(src[0]) && --dstlen > 0) {
          *dst_p++ = '/';
        }
        break;
      }
      if (p == homedir_env_mod) {
        break;
      }
      p = homedir_env_mod;
      len = envlen;
    }

    // if (!one) skip to separator: space or comma.
    while (*src && (one || (*src != ',' && *src != ' ')) && --dstlen > 0) {
      *dst_p++ = (char)(*src++);
    }
    // Skip separator.
    while ((*src == ' ' || *src == ',') && --dstlen > 0) {
      *dst_p++ = (char)(*src++);
    }
  }
  // If (dstlen == 0) out of space, what to do???

  *dst_p = NUL;

  if (must_free) {
    xfree(homedir_env_mod);
  }
  return (size_t)(dst_p - (char *)dst);
}

/// Like home_replace, store the replaced string in allocated memory.
/// @param buf When not NULL, check for help files
/// @param src Input file name
char_u * home_replace_save(buf_T *buf, char_u *src) FUNC_ATTR_NONNULL_RET
{
  size_t len = 3;             // space for "~/" and trailing NUL
  if (src != NULL) {          // just in case
    len += STRLEN(src);
  }
  char_u *dst = xmalloc(len);
  home_replace(buf, src, dst, len, true);
  return dst;
}


/// Function given to ExpandGeneric() to obtain an environment variable name.
char_u *get_env_name(expand_T *xp, int idx)
{
# define ENVNAMELEN 100
  // this static buffer is needed to avoid a memory leak in ExpandGeneric
  static char_u name[ENVNAMELEN];
  assert(idx >= 0);
  char *envname = os_getenvname_at_index((size_t)idx);
  if (envname) {
    STRLCPY(name, envname, ENVNAMELEN);
    xfree(envname);
    return name;
  }
  return NULL;
}

/// Appends the head of `fname` to $PATH and sets it in the environment.
///
/// @param fname  Full path whose parent directory will be appended to $PATH.
///
/// @return true if `path` was appended-to
bool os_setenv_append_path(const char *fname)
  FUNC_ATTR_NONNULL_ALL
{
#ifdef WIN32
// 8191 (plus NUL) is considered the practical maximum.
# define MAX_ENVPATHLEN 8192
#else
// No prescribed maximum on unix.
# define MAX_ENVPATHLEN INT_MAX
#endif
  if (!path_is_absolute((char_u *)fname)) {
    internal_error("os_setenv_append_path()");
    return false;
  }
  const char *tail = (char *)path_tail_with_sep((char_u *)fname);
  size_t dirlen = (size_t)(tail - fname);
  assert(tail >= fname && dirlen + 1 < sizeof(os_buf));
  xstrlcpy(os_buf, fname, dirlen + 1);
  const char *path = os_getenv("PATH");
  const size_t pathlen = path ? strlen(path) : 0;
  const size_t newlen = pathlen + dirlen + 2;
  if (newlen < MAX_ENVPATHLEN) {
    char *temp = xmalloc(newlen);
    if (pathlen == 0) {
      temp[0] = NUL;
    } else {
      xstrlcpy(temp, path, newlen);
      xstrlcat(temp, ENV_SEPSTR, newlen);
    }
    xstrlcat(temp, os_buf, newlen);
    os_setenv("PATH", temp, 1);
    xfree(temp);
    return true;
  }
  return false;
}

/// Returns true if `sh` looks like it resolves to "cmd.exe".
bool os_shell_is_cmdexe(const char *sh)
  FUNC_ATTR_NONNULL_ALL
{
  if (*sh == NUL) {
    return false;
  }
  if (striequal(sh, "$COMSPEC")) {
    const char *comspec = os_getenv("COMSPEC");
    return striequal("cmd.exe", (char *)path_tail((char_u *)comspec));
  }
  if (striequal(sh, "cmd.exe") || striequal(sh, "cmd")) {
    return true;
  }
  return striequal("cmd.exe", (char *)path_tail((char_u *)sh));
}
