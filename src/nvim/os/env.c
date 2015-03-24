// env.c -- environment variable access

#include <assert.h>
#include <uv.h>

// vim.h must be included before charset.h (and possibly others) or things
// blow up
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/os/os.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc2.h"
#include "nvim/path.h"
#include "nvim/strings.h"
#include "nvim/eval.h"
#include "nvim/ex_getln.h"
#include "nvim/version.h"

#ifdef HAVE__NSGETENVIRON
#include <crt_externs.h>
#endif

#ifdef HAVE_SYS_UTSNAME_H
#include <sys/utsname.h>
#endif

const char *os_getenv(const char *name)
{
  return getenv(name);
}

int os_setenv(const char *name, const char *value, int overwrite)
{
  return setenv(name, value, overwrite);
}

char *os_getenvname_at_index(size_t index)
{
# if defined(HAVE__NSGETENVIRON)
  char **environ = *_NSGetEnviron();
# elif !defined(__WIN32__)
  // Borland C++ 5.2 has this in a header file.
  extern char         **environ;
# endif
  // check if index is inside the environ array
  for (size_t i = 0; i < index; i++) {
    if (environ[i] == NULL) {
      return NULL;
    }
  }
  char *str = environ[index];
  if (str == NULL) {
    return NULL;
  }
  size_t namesize = 0;
  while (str[namesize] != '=' && str[namesize] != NUL) {
    namesize++;
  }
  char *name = (char *)vim_strnsave((char_u *)str, namesize);
  return name;
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

/// Get the hostname of the machine running Neovim.
///
/// @param hostname Buffer to store the hostname.
/// @param len Length of `hostname`.
void os_get_hostname(char *hostname, size_t len)
{
#ifdef HAVE_SYS_UTSNAME_H
  struct utsname vutsname;

  if (uname(&vutsname) < 0) {
    *hostname = '\0';
  } else {
    strncpy(hostname, vutsname.nodename, len - 1);
    hostname[len - 1] = '\0';
  }
#else
  // TODO(unknown): Implement this for windows.
  // See the implementation used in vim:
  // https://code.google.com/p/vim/source/browse/src/os_win32.c?r=6b69d8dde19e32909f4ee3a6337e6a2ecfbb6f72#2899
  *hostname = '\0';
#endif
}

/// To get the "real" home directory:
///   - get value of $HOME
/// For Unix:
///   - go to that directory
///   - do os_dirname() to get the real name of that directory.
/// This also works with mounts and links.
/// Don't do this for MS-DOS, it will change the "current dir" for a drive.
static char_u   *homedir = NULL;

void init_homedir(void)
{
  char_u  *var;

  /* In case we are called a second time (when 'encoding' changes). */
  free(homedir);
  homedir = NULL;

  var = (char_u *)os_getenv("HOME");

  if (var != NULL && *var == NUL)       /* empty is same as not set */
    var = NULL;


  if (var != NULL) {
#ifdef UNIX
    /*
     * Change to the directory and get the actual path.  This resolves
     * links.  Don't do it when we can't return.
     */
    if (os_dirname(NameBuff, MAXPATHL) == OK
        && os_chdir((char *)NameBuff) == 0) {
      if (!os_chdir((char *)var) && os_dirname(IObuff, IOSIZE) == OK)
        var = IObuff;
      if (os_chdir((char *)NameBuff) != 0)
        EMSG(_(e_prev_dir));
    }
#endif
    homedir = vim_strsave(var);
  }
}

#if defined(EXITFREE)

void free_homedir(void)
{
  free(homedir);
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
/// @param src Input string e.g. "$HOME/vim.hlp"
/// @param dst Where to put the result
/// @param dstlen Maximum length of the result
void expand_env(char_u *src, char_u *dst, int dstlen)
{
  expand_env_esc(src, dst, dstlen, false, false, NULL);
}

/// Expand environment variable with path name and escaping.
/// "~/" is also expanded, using $HOME. For Unix "~user/" is expanded.
/// Skips over "\ ", "\~" and "\$" (not for Win32 though).
/// If anything fails no expansion is done and dst equals src.
/// startstr recognize the start of a new name, for '~' expansion.
/// @param srcp Input string e.g. "$HOME/vim.hlp"
/// @param dst Where to put the result
/// @param dstlen Maximum length of the result
/// @param esc Should we escape spaces in expanded variables?
/// @param one Should we expand more than one '~'?
/// @param startstr Common prefix for paths, can be NULL
void expand_env_esc(char_u *srcp, char_u *dst, int dstlen, bool esc, bool one,
                    char_u *startstr)
{
  char_u      *src;
  char_u      *tail;
  int c;
  char_u      *var;
  bool copy_char;
  bool mustfree;                 /* var was allocated, need to free it later */
  bool at_start = true;           /* at start of a name */
  int startstr_len = 0;

  if (startstr != NULL)
    startstr_len = (int)STRLEN(startstr);

  src = skipwhite(srcp);
  --dstlen;                 /* leave one char space for "\," */
  while (*src && dstlen > 0) {
    copy_char = true;
    if ((*src == '$') || (*src == '~' && at_start)) {
      mustfree = false;

      /*
       * The variable name is copied into dst temporarily, because it may
       * be a string in read-only memory and a NUL needs to be appended.
       */
      if (*src != '~') {                                /* environment var */
        tail = src + 1;
        var = dst;
        c = dstlen - 1;

#ifdef UNIX
        /* Unix has ${var-name} type environment vars */
        if (*tail == '{' && !vim_isIDc('{')) {
          tail++;               /* ignore '{' */
          while (c-- > 0 && *tail && *tail != '}')
            *var++ = *tail++;
        } else // NOLINT
#endif
        {
          while (c-- > 0 && *tail != NUL && vim_isIDc(*tail)) {
            *var++ = *tail++;
          }
        }

#if defined(UNIX)
        // Verify that we have found the end of a UNIX ${VAR} style variable
        if (src[1] == '{' && *tail != '}') {
          var = NULL;
        } else if (src[1] == '{') {
          ++tail;
        }
#elif defined(MSWIN)
        // Verify that we have found the end of a Windows %VAR% style variable
        if (src[0] == '%' && *tail != '%') {
          var = NULL;
        } else if (src[0] == '%') {
          ++tail;
        }
#endif
        *var = NUL;
        var = vim_getenv(dst, &mustfree);
      } else if (  src[1] == NUL /* home directory */
                 || vim_ispathsep(src[1])
                 || vim_strchr((char_u *)" ,\t\n", src[1]) != NULL) {
        var = homedir;
        tail = src + 1;
      } else {                                        /* user directory */
#if defined(UNIX)
        /*
         * Copy ~user to dst[], so we can put a NUL after it.
         */
        tail = src;
        var = dst;
        c = dstlen - 1;
        while (    c-- > 0
                   && *tail
                   && vim_isfilec(*tail)
                   && !vim_ispathsep(*tail))
          *var++ = *tail++;
        *var = NUL;
        /*
         * Use os_get_user_directory() to get the user directory.
         * If this function fails, the shell is used to
         * expand ~user. This is slower and may fail if the shell
         * does not support ~user (old versions of /bin/sh).
         */
        var = (char_u *)os_get_user_directory((char *)dst + 1);
        mustfree = true;
        if (var == NULL)
        {
          expand_T xpc;

          ExpandInit(&xpc);
          xpc.xp_context = EXPAND_FILES;
          var = ExpandOne(&xpc, dst, NULL,
              WILD_ADD_SLASH|WILD_SILENT, WILD_EXPAND_FREE);
          mustfree = true;
        }
#else
        /* cannot expand user's home directory, so don't try */
        var = NULL;
        tail = (char_u *)"";            /* for gcc */
#endif /* UNIX */
      }

#ifdef BACKSLASH_IN_FILENAME
      /* If 'shellslash' is set change backslashes to forward slashes.
       * Can't use slash_adjust(), p_ssl may be set temporarily. */
      if (p_ssl && var != NULL && vim_strchr(var, '\\') != NULL) {
        char_u  *p = vim_strsave(var);

        if (mustfree) {
          free(var);
        }
        var = p;
        mustfree = true;
        forward_slash(var);
      }
#endif

      /* If "var" contains white space, escape it with a backslash.
       * Required for ":e ~/tt" when $HOME includes a space. */
      if (esc && var != NULL && vim_strpbrk(var, (char_u *)" \t") != NULL) {
        char_u  *p = vim_strsave_escaped(var, (char_u *)" \t");

        if (mustfree)
          free(var);
        var = p;
        mustfree = true;
      }

      if (var != NULL && *var != NUL
          && (STRLEN(var) + STRLEN(tail) + 1 < (unsigned)dstlen)) {
        STRCPY(dst, var);
        dstlen -= (int)STRLEN(var);
        c = (int)STRLEN(var);
        /* if var[] ends in a path separator and tail[] starts
         * with it, skip a character */
        if (*var != NUL && after_pathsep(dst, dst + c)
#if defined(BACKSLASH_IN_FILENAME)
            && dst[-1] != ':'
#endif
            && vim_ispathsep(*tail))
          ++tail;
        dst += c;
        src = tail;
        copy_char = false;
      }
      if (mustfree)
        free(var);
    }

    if (copy_char) {        /* copy at least one char */
      /*
       * Recognize the start of a new name, for '~'.
       * Don't do this when "one" is true, to avoid expanding "~" in
       * ":edit foo ~ foo".
       */
      at_start = false;
      if (src[0] == '\\' && src[1] != NUL) {
        *dst++ = *src++;
        --dstlen;
      } else if ((src[0] == ' ' || src[0] == ',') && !one) {
        at_start = true;
      }
      *dst++ = *src++;
      --dstlen;

      if (startstr != NULL && src - startstr_len >= srcp
          && STRNCMP(src - startstr_len, startstr, startstr_len) == 0)
        at_start = true;
    }
  }
  *dst = NUL;
}

/// Check if the directory "vimdir/<version>" or "vimdir/runtime" exists.
/// Return NULL if not, return its name in allocated memory otherwise.
/// @param vimdir directory to test
static char_u *vim_version_dir(char_u *vimdir)
{
  char_u      *p;

  if (vimdir == NULL || *vimdir == NUL)
    return NULL;
  p = concat_fnames(vimdir, (char_u *)VIM_VERSION_NODOT, true);
  if (os_isdir(p))
    return p;
  free(p);
  p = concat_fnames(vimdir, (char_u *)RUNTIME_DIRNAME, true);
  if (os_isdir(p))
    return p;
  free(p);
  return NULL;
}

/// If the string between "p" and "pend" ends in "name/", return "pend" minus
/// the length of "name/".  Otherwise return "pend".
static char_u *remove_tail(char_u *p, char_u *pend, char_u *name)
{
  int len = (int)STRLEN(name) + 1;
  char_u      *newend = pend - len;

  if (newend >= p
      && fnamencmp(newend, name, len - 1) == 0
      && (newend == p || after_pathsep(p, newend)))
    return newend;
  return pend;
}

/// Vim's version of getenv().
/// Special handling of $HOME, $VIM and $VIMRUNTIME, allowing the user to
/// override the vim runtime directory at runtime.  Also does ACP to 'enc'
/// conversion for Win32.
/// @param name Name of environment variable to expand
/// @param[out] mustfree Ouput parameter for the caller to determine if they are
///           responsible for releasing memory. Must be initialized to false
///           by the caller.
char_u *vim_getenv(char_u *name, bool *mustfree)
{
  char_u      *p;
  char_u      *pend;
  int vimruntime;


  p = (char_u *)os_getenv((char *)name);
  if (p != NULL && *p == NUL)       /* empty is the same as not set */
    p = NULL;

  if (p != NULL) {
    return p;
  }

  vimruntime = (STRCMP(name, "VIMRUNTIME") == 0);
  if (!vimruntime && STRCMP(name, "VIM") != 0)
    return NULL;

  /*
   * When expanding $VIMRUNTIME fails, try using $VIM/vim<version> or $VIM.
   * Don't do this when default_vimruntime_dir is non-empty.
   */
  if (vimruntime
#ifdef HAVE_PATHDEF
      && *default_vimruntime_dir == NUL
#endif
      ) {
    p = (char_u *)os_getenv("VIM");
    if (p != NULL && *p == NUL)             /* empty is the same as not set */
      p = NULL;
    if (p != NULL) {
      p = vim_version_dir(p);
      if (p != NULL)
        *mustfree = true;
      else
        p = (char_u *)os_getenv("VIM");
    }
  }

  /*
   * When expanding $VIM or $VIMRUNTIME fails, try using:
   * - the directory name from 'helpfile' (unless it contains '$')
   * - the executable name from argv[0]
   */
  if (p == NULL) {
    if (p_hf != NULL && vim_strchr(p_hf, '$') == NULL)
      p = p_hf;
    if (p != NULL) {
      /* remove the file name */
      pend = path_tail(p);

      /* remove "doc/" from 'helpfile', if present */
      if (p == p_hf)
        pend = remove_tail(p, pend, (char_u *)"doc");

      /* for $VIM, remove "runtime/" or "vim54/", if present */
      if (!vimruntime) {
        pend = remove_tail(p, pend, (char_u *)RUNTIME_DIRNAME);
        pend = remove_tail(p, pend, (char_u *)VIM_VERSION_NODOT);
      }

      /* remove trailing path separator */
      /* With MacOS path (with  colons) the final colon is required */
      /* to avoid confusion between absolute and relative path */
      if (pend > p && after_pathsep(p, pend))
        --pend;

      // check that the result is a directory name
      assert(pend > p);
      p = vim_strnsave(p, (size_t)(pend - p));

      if (!os_isdir(p)) {
        free(p);
        p = NULL;
      } else {
        *mustfree = true;
      }
    }
  }

#ifdef HAVE_PATHDEF
  /* When there is a pathdef.c file we can use default_vim_dir and
   * default_vimruntime_dir */
  if (p == NULL) {
    /* Only use default_vimruntime_dir when it is not empty */
    if (vimruntime && *default_vimruntime_dir != NUL) {
      p = default_vimruntime_dir;
      *mustfree = false;
    } else if (*default_vim_dir != NUL) {
      if (vimruntime && (p = vim_version_dir(default_vim_dir)) != NULL) {
        *mustfree = true;
      } else {
        p = default_vim_dir;
        *mustfree = false;
      }
    }
  }
#endif

  /*
   * Set the environment variable, so that the new value can be found fast
   * next time, and others can also use it (e.g. Perl).
   */
  if (p != NULL) {
    if (vimruntime) {
      vim_setenv((char_u *)"VIMRUNTIME", p);
      didset_vimruntime = true;
    } else {
      vim_setenv((char_u *)"VIM", p);
      didset_vim = true;
    }
  }
  return p;
}

/// Replace home directory by "~" in each space or comma separated file name in
/// 'src'.
/// If anything fails (except when out of space) dst equals src.
/// @param buf When not NULL, check for help files
/// @param src Input file name
/// @param dst Where to put the result
/// @param dstlen Maximum length of the result
/// @param one If true, only replace one file name, includeing spaces and commas
///           in the file name
void home_replace(buf_T *buf, char_u *src, char_u *dst, int dstlen, bool one)
{
  size_t dirlen = 0, envlen = 0;
  size_t len;
  char_u      *homedir_env, *homedir_env_orig;
  char_u      *p;

  if (src == NULL) {
    *dst = NUL;
    return;
  }

  /*
   * If the file is a help file, remove the path completely.
   */
  if (buf != NULL && buf->b_help) {
    STRCPY(dst, path_tail(src));
    return;
  }

  /*
   * We check both the value of the $HOME environment variable and the
   * "real" home directory.
   */
  if (homedir != NULL)
    dirlen = STRLEN(homedir);

  homedir_env_orig = homedir_env = (char_u *)os_getenv("HOME");
  /* Empty is the same as not set. */
  if (homedir_env != NULL && *homedir_env == NUL)
    homedir_env = NULL;

  if (homedir_env != NULL && vim_strchr(homedir_env, '~') != NULL) {
    int usedlen = 0;
    int flen;
    char_u  *fbuf = NULL;

    flen = (int)STRLEN(homedir_env);
    (void)modify_fname((char_u *)":p", &usedlen,
        &homedir_env, &fbuf, &flen);
    flen = (int)STRLEN(homedir_env);
    if (flen > 0 && vim_ispathsep(homedir_env[flen - 1]))
      /* Remove the trailing / that is added to a directory. */
      homedir_env[flen - 1] = NUL;
  }

  if (homedir_env != NULL)
    envlen = STRLEN(homedir_env);

  if (!one)
    src = skipwhite(src);
  while (*src && dstlen > 0) {
    /*
     * Here we are at the beginning of a file name.
     * First, check to see if the beginning of the file name matches
     * $HOME or the "real" home directory. Check that there is a '/'
     * after the match (so that if e.g. the file is "/home/pieter/bla",
     * and the home directory is "/home/piet", the file does not end up
     * as "~er/bla" (which would seem to indicate the file "bla" in user
     * er's home directory)).
     */
    p = homedir;
    len = dirlen;
    for (;; ) {
      if (   len
             && fnamencmp(src, p, len) == 0
             && (vim_ispathsep(src[len])
                 || (!one && (src[len] == ',' || src[len] == ' '))
                 || src[len] == NUL)) {
        src += len;
        if (--dstlen > 0)
          *dst++ = '~';

        /*
         * If it's just the home directory, add  "/".
         */
        if (!vim_ispathsep(src[0]) && --dstlen > 0)
          *dst++ = '/';
        break;
      }
      if (p == homedir_env)
        break;
      p = homedir_env;
      len = envlen;
    }

    /* if (!one) skip to separator: space or comma */
    while (*src && (one || (*src != ',' && *src != ' ')) && --dstlen > 0)
      *dst++ = *src++;
    /* skip separator */
    while ((*src == ' ' || *src == ',') && --dstlen > 0)
      *dst++ = *src++;
  }
  /* if (dstlen == 0) out of space, what to do??? */

  *dst = NUL;

  if (homedir_env != homedir_env_orig)
    free(homedir_env);
}

/// Like home_replace, store the replaced string in allocated memory.
/// @param buf When not NULL, check for help files
/// @param src Input file name
char_u * home_replace_save(buf_T *buf, char_u *src) FUNC_ATTR_NONNULL_RET
{
  size_t len = 3;                      /* space for "~/" and trailing NUL */
  if (src != NULL)              /* just in case */
    len += STRLEN(src);
  char_u *dst = xmalloc(len);
  home_replace(buf, src, dst, (int)len, true);
  return dst;
}

/// Our portable version of setenv.
/// Has special handling for $VIMRUNTIME to keep the localization machinery
/// sane.
void vim_setenv(char_u *name, char_u *val)
{
  os_setenv((char *)name, (char *)val, 1);
  /*
   * When setting $VIMRUNTIME adjust the directory to find message
   * translations to $VIMRUNTIME/lang.
   */
  if (*val != NUL && STRICMP(name, "VIMRUNTIME") == 0) {
    char_u  *buf = concat_str(val, (char_u *)"/lang");
    bindtextdomain(VIMPACKAGE, (char *)buf);
    free(buf);
  }
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
    free(envname);
    return name;
  } else {
    return NULL;
  }
}

