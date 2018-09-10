// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * os_unix.c -- code for all flavors of Unix (BSD, SYSV, SVR4, POSIX, ...)
 *
 * A lot of this file was originally written by Juergen Weigert and later
 * changed beyond recognition.
 */

#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/api/private/handle.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/os_unix.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/mouse.h"
#include "nvim/garray.h"
#include "nvim/path.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui.h"
#include "nvim/types.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/os/shell.h"
#include "nvim/os/signal.h"
#include "nvim/msgpack_rpc/helpers.h"

#ifdef HAVE_SELINUX
# include <selinux/selinux.h>
static int selinux_enabled = -1;
#endif


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os_unix.c.generated.h"
#endif

#if defined(HAVE_ACL)
# ifdef HAVE_SYS_ACL_H
#  include <sys/acl.h>
# endif
# ifdef HAVE_SYS_ACCESS_H
#  include <sys/access.h>
# endif


#if defined(HAVE_SELINUX)
// Copy security info from "from_file" to "to_file".
void mch_copy_sec(char_u *from_file, char_u *to_file)
{
  if (from_file == NULL)
    return;

  if (selinux_enabled == -1)
    selinux_enabled = is_selinux_enabled();

  if (selinux_enabled > 0) {
    security_context_t from_context = NULL;
    security_context_t to_context = NULL;

    if (getfilecon((char *)from_file, &from_context) < 0) {
      // If the filesystem doesn't support extended attributes,
      // the original had no special security context and the
      // target cannot have one either.
      if (errno == EOPNOTSUPP) {
        return;
      }

      MSG_PUTS(_("\nCould not get security context for "));
      msg_outtrans(from_file);
      msg_putchar('\n');
      return;
    }
    if (getfilecon((char *)to_file, &to_context) < 0) {
      MSG_PUTS(_("\nCould not get security context for "));
      msg_outtrans(to_file);
      msg_putchar('\n');
      freecon (from_context);
      return;
    }
    if (strcmp(from_context, to_context) != 0) {
      if (setfilecon((char *)to_file, from_context) < 0) {
        MSG_PUTS(_("\nCould not set security context for "));
        msg_outtrans(to_file);
        msg_putchar('\n');
      }
    }
    freecon(to_context);
    freecon(from_context);
  }
}
#endif  // HAVE_SELINUX

// Return a pointer to the ACL of file "fname" in allocated memory.
// Return NULL if the ACL is not available for whatever reason.
vim_acl_T mch_get_acl(const char_u *fname)
{
  vim_acl_T ret = NULL;
  return ret;
}

// Set the ACL of file "fname" to "acl" (unless it's NULL).
void mch_set_acl(const char_u *fname, vim_acl_T aclent)
{
  if (aclent == NULL)
    return;
}

void mch_free_acl(vim_acl_T aclent)
{
  if (aclent == NULL)
    return;
}
#endif

void mch_exit(int r)
  FUNC_ATTR_NORETURN
{
  exiting = true;

  ui_flush();
  ui_builtin_stop();
  ml_close_all(true);           // remove all memfiles

  if (!event_teardown() && r == 0) {
    r = 1;  // Exit with error if main_loop did not teardown gracefully.
  }
  if (input_global_fd() >= 0) {
    stream_set_blocking(input_global_fd(), true);  // normalize stream (#2598)
  }

#ifdef EXITFREE
  free_all_mem();
#endif

  exit(r);
}

#define SHELL_SPECIAL (char_u *)"\t \"&'$;<>()\\|"

/// Does wildcard pattern matching using the shell.
///
/// @param      num_pat  is the number of input patterns.
/// @param      pat      is an array of pointers to input patterns.
/// @param[out] num_file is pointer to number of matched file names.
///                      Set to the number of pointers in *file.
/// @param[out] file     is pointer to array of pointers to matched file names.
///                      Memory pointed to by the initial value of *file will
///                      not be freed.
///                      Set to NULL if FAIL is returned. Otherwise points to
///                      allocated memory.
/// @param      flags    is a combination of EW_* flags used in
///                      expand_wildcards().
///                      If matching fails but EW_NOTFOUND is set in flags or
///                      there are no wildcards, the patterns from pat are
///                      copied into *file.
///
/// @returns             OK for success or FAIL for error.
int mch_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                         char_u ***file, int flags) FUNC_ATTR_NONNULL_ARG(3)
  FUNC_ATTR_NONNULL_ARG(4)
{
  int i;
  size_t len;
  char_u      *p;
  bool dir;
  char_u *extra_shell_arg = NULL;
  ShellOpts shellopts = kShellOptExpand | kShellOptSilent;
  int j;
  char_u      *tempname;
  char_u      *command;
  FILE        *fd;
  char_u      *buffer;
#define STYLE_ECHO      0       /* use "echo", the default */
#define STYLE_GLOB      1       /* use "glob", for csh */
#define STYLE_VIMGLOB   2       /* use "vimglob", for Posix sh */
#define STYLE_PRINT     3       /* use "print -N", for zsh */
#define STYLE_BT        4       /* `cmd` expansion, execute the pattern
                                 * directly */
  int shell_style = STYLE_ECHO;
  int check_spaces;
  static bool did_find_nul = false;
  bool ampersent = false;
  // vimglob() function to define for Posix shell
  static char *sh_vimglob_func =
    "vimglob() { while [ $# -ge 1 ]; do echo \"$1\"; shift; done }; vimglob >";

  bool is_fish_shell =
#if defined(UNIX)
    STRNCMP(invocation_path_tail(p_sh, NULL), "fish", 4) == 0;
#else
    false;
#endif

  *num_file = 0;        // default: no files found
  *file = NULL;

  // If there are no wildcards, just copy the names to allocated memory.
  // Saves a lot of time, because we don't have to start a new shell.
  if (!have_wildcard(num_pat, pat)) {
    save_patterns(num_pat, pat, num_file, file);
    return OK;
  }

  // Don't allow any shell command in the sandbox.
  if (sandbox != 0 && check_secure()) {
    return FAIL;
  }

  // Don't allow the use of backticks in secure and restricted mode.
  if (secure || restricted) {
    for (i = 0; i < num_pat; i++) {
      if (vim_strchr(pat[i], '`') != NULL
          && (check_restricted() || check_secure())) {
        return FAIL;
      }
    }
  }

  // get a name for the temp file
  if ((tempname = vim_tempname()) == NULL) {
    EMSG(_(e_notmp));
    return FAIL;
  }

  // Let the shell expand the patterns and write the result into the temp
  // file.
  // STYLE_BT:         NL separated
  //       If expanding `cmd` execute it directly.
  // STYLE_GLOB:       NUL separated
  //       If we use *csh, "glob" will work better than "echo".
  // STYLE_PRINT:      NL or NUL separated
  //       If we use *zsh, "print -N" will work better than "glob".
  // STYLE_VIMGLOB:    NL separated
  //       If we use *sh*, we define "vimglob()".
  // STYLE_ECHO:       space separated.
  //       A shell we don't know, stay safe and use "echo".
  if (num_pat == 1 && *pat[0] == '`'
      && (len = STRLEN(pat[0])) > 2
      && *(pat[0] + len - 1) == '`') {
    shell_style = STYLE_BT;
  } else if ((len = STRLEN(p_sh)) >= 3) {
    if (STRCMP(p_sh + len - 3, "csh") == 0) {
      shell_style = STYLE_GLOB;
    } else if (STRCMP(p_sh + len - 3, "zsh") == 0) {
      shell_style = STYLE_PRINT;
    }
  }
  if (shell_style == STYLE_ECHO && strstr((char *)path_tail(p_sh),
          "sh") != NULL)
    shell_style = STYLE_VIMGLOB;

  // Compute the length of the command.  We need 2 extra bytes: for the
  // optional '&' and for the NUL.
  // Worst case: "unset nonomatch; print -N >" plus two is 29
  len = STRLEN(tempname) + 29;
  if (shell_style == STYLE_VIMGLOB)
    len += STRLEN(sh_vimglob_func);

  for (i = 0; i < num_pat; i++) {
    // Count the length of the patterns in the same way as they are put in
    // "command" below.
    len++;                              // add space
    for (j = 0; pat[i][j] != NUL; j++) {
      if (vim_strchr(SHELL_SPECIAL, pat[i][j]) != NULL) {
        len++;                  // may add a backslash
      }
      len++;
    }
  }

  if (is_fish_shell) {
    len += sizeof("egin;"" end") - 1;
  }

  command = xmalloc(len);

  // Build the shell command:
  // - Set $nonomatch depending on EW_NOTFOUND (hopefully the shell
  //    recognizes this).
  // - Add the shell command to print the expanded names.
  // - Add the temp file name.
  // - Add the file name patterns.
  if (shell_style == STYLE_BT) {
    // change `command; command& ` to (command; command )
    if (is_fish_shell) {
      STRCPY(command, "begin; ");
    } else {
      STRCPY(command, "(");
    }
    STRCAT(command, pat[0] + 1);                // exclude first backtick
    p = command + STRLEN(command) - 1;
    if (is_fish_shell) {
      *p-- = ';';
      STRCAT(command, " end");
    } else {
      *p-- = ')';                                 // remove last backtick
    }
    while (p > command && ascii_iswhite(*p)) {
      p--;
    }
    if (*p == '&') {                            // remove trailing '&'
      ampersent = true;
      *p = ' ';
    }
    STRCAT(command, ">");
  } else {
    if (flags & EW_NOTFOUND)
      STRCPY(command, "set nonomatch; ");
    else
      STRCPY(command, "unset nonomatch; ");
    if (shell_style == STYLE_GLOB)
      STRCAT(command, "glob >");
    else if (shell_style == STYLE_PRINT)
      STRCAT(command, "print -N >");
    else if (shell_style == STYLE_VIMGLOB)
      STRCAT(command, sh_vimglob_func);
    else
      STRCAT(command, "echo >");
  }

  STRCAT(command, tempname);

  if (shell_style != STYLE_BT) {
    for (i = 0; i < num_pat; i++) {
      // Put a backslash before special
      // characters, except inside ``.
      bool intick = false;

      p = command + STRLEN(command);
      *p++ = ' ';
      for (j = 0; pat[i][j] != NUL; j++) {
        if (pat[i][j] == '`') {
          intick = !intick;
        } else if (pat[i][j] == '\\' && pat[i][j + 1] != NUL) {
          // Remove a backslash, take char literally.  But keep
          // backslash inside backticks, before a special character
          // and before a backtick.
          if (intick
              || vim_strchr(SHELL_SPECIAL, pat[i][j + 1]) != NULL
              || pat[i][j + 1] == '`') {
            *p++ = '\\';
          }
          j++;
        } else if (!intick
                   && ((flags & EW_KEEPDOLLAR) == 0 || pat[i][j] != '$')
                   && vim_strchr(SHELL_SPECIAL, pat[i][j]) != NULL) {
          // Put a backslash before a special character, but not
          // when inside ``. And not for $var when EW_KEEPDOLLAR is
          // set.
          *p++ = '\\';
        }

        // Copy one character.
        *p++ = pat[i][j];
      }
      *p = NUL;
    }
  }

  if (flags & EW_SILENT) {
    shellopts |= kShellOptHideMess;
  }

  if (ampersent) {
    STRCAT(command, "&");               // put the '&' after the redirection
  }

  // Using zsh -G: If a pattern has no matches, it is just deleted from
  // the argument list, otherwise zsh gives an error message and doesn't
  // expand any other pattern.
  if (shell_style == STYLE_PRINT) {
    extra_shell_arg = (char_u *)"-G";       // Use zsh NULL_GLOB option

  // If we use -f then shell variables set in .cshrc won't get expanded.
  // vi can do it, so we will too, but it is only necessary if there is a "$"
  // in one of the patterns, otherwise we can still use the fast option.
  } else if (shell_style == STYLE_GLOB && !have_dollars(num_pat, pat)) {
    extra_shell_arg = (char_u *)"-f";           // Use csh fast option
  }

  // execute the shell command
  i = call_shell(
      command,
      shellopts,
      extra_shell_arg
      );

  // When running in the background, give it some time to create the temp
  // file, but don't wait for it to finish.
  if (ampersent) {
    os_delay(10L, true);
  }

  xfree(command);

  if (i) {                         // os_call_shell() failed
    os_remove((char *)tempname);
    xfree(tempname);
    // With interactive completion, the error message is not printed.
    if (!(flags & EW_SILENT)) {
      msg_putchar('\n');                // clear bottom line quickly
#if SIZEOF_LONG > SIZEOF_INT
      assert(Rows <= (long)INT_MAX + 1);
#endif
      cmdline_row = (int)(Rows - 1);           // continue on last line
      MSG(_(e_wildexpand));
      msg_start();                    // don't overwrite this message
    }

    // If a `cmd` expansion failed, don't list `cmd` as a match, even when
    // EW_NOTFOUND is given
    if (shell_style == STYLE_BT) {
      return FAIL;
    }
    goto notfound;
  }

  // read the names from the file into memory
  fd = fopen((char *)tempname, READBIN);
  if (fd == NULL) {
    // Something went wrong, perhaps a file name with a special char.
    if (!(flags & EW_SILENT)) {
      MSG(_(e_wildexpand));
      msg_start();                      // don't overwrite this message
    }
    xfree(tempname);
    goto notfound;
  }
  int fseek_res = fseek(fd, 0L, SEEK_END);
  if (fseek_res < 0) {
    xfree(tempname);
    fclose(fd);
    return FAIL;
  }
  int64_t templen = ftell(fd);        // get size of temp file
  if (templen < 0) {
    xfree(tempname);
    fclose(fd);
    return FAIL;
  }
#if SIZEOF_LONG_LONG > SIZEOF_SIZE_T
  assert(templen <= (long long)SIZE_MAX);
#endif
  len = (size_t)templen;
  fseek(fd, 0L, SEEK_SET);
  buffer = xmalloc(len + 1);
  // fread() doesn't terminate buffer with NUL;
  // appropiate termination (not always NUL) is done below.
  size_t readlen = fread((char *)buffer, 1, len, fd);
  fclose(fd);
  os_remove((char *)tempname);
  if (readlen != len) {
    // unexpected read error
    EMSG2(_(e_notread), tempname);
    xfree(tempname);
    xfree(buffer);
    return FAIL;
  }
  xfree(tempname);

  // file names are separated with Space
  if (shell_style == STYLE_ECHO) {
    buffer[len] = '\n';                 // make sure the buffer ends in NL
    p = buffer;
    for (i = 0; *p != '\n'; i++) {      // count number of entries
      while (*p != ' ' && *p != '\n') {
        p++;
      }
      p = skipwhite(p);                 // skip to next entry
    }
  // file names are separated with NL
  } else if (shell_style == STYLE_BT || shell_style == STYLE_VIMGLOB) {
    buffer[len] = NUL;                  // make sure the buffer ends in NUL
    p = buffer;
    for (i = 0; *p != NUL; i++) {       // count number of entries
      while (*p != '\n' && *p != NUL) {
        p++;
      }
      if (*p != NUL) {
        p++;
      }
      p = skipwhite(p);                 // skip leading white space
    }
  // file names are separated with NUL
  } else {
    // Some versions of zsh use spaces instead of NULs to separate
    // results.  Only do this when there is no NUL before the end of the
    // buffer, otherwise we would never be able to use file names with
    // embedded spaces when zsh does use NULs.
    // When we found a NUL once, we know zsh is OK, set did_find_nul and
    // don't check for spaces again.
    check_spaces = false;
    if (shell_style == STYLE_PRINT && !did_find_nul) {
      // If there is a NUL, set did_find_nul, else set check_spaces
      buffer[len] = NUL;
      if (len && (int)STRLEN(buffer) < (int)len)
        did_find_nul = true;
      else
        check_spaces = true;
    }

    // Make sure the buffer ends with a NUL.  For STYLE_PRINT there
    // already is one, for STYLE_GLOB it needs to be added.
    if (len && buffer[len - 1] == NUL) {
      len--;
    } else {
      buffer[len] = NUL;
    }
    i = 0;
    for (p = buffer; p < buffer + len; p++) {
      if (*p == NUL || (*p == ' ' && check_spaces)) {       // count entry
        i++;
        *p = NUL;
      }
    }
    if (len) {
      i++;                              // count last entry
    }
  }
  assert(buffer[len] == NUL || buffer[len] == '\n');

  if (i == 0) {
    // Can happen when using /bin/sh and typing ":e $NO_SUCH_VAR^I".
    // /bin/sh will happily expand it to nothing rather than returning an
    // error; and hey, it's good to check anyway -- webb.
    xfree(buffer);
    goto notfound;
  }
  *num_file = i;
  *file = xmalloc(sizeof(char_u *) * (size_t)i);

  // Isolate the individual file names.
  p = buffer;
  for (i = 0; i < *num_file; ++i) {
    (*file)[i] = p;
    // Space or NL separates
    if (shell_style == STYLE_ECHO || shell_style == STYLE_BT
        || shell_style == STYLE_VIMGLOB) {
      while (!(shell_style == STYLE_ECHO && *p == ' ')
             && *p != '\n' && *p != NUL) {
        p++;
      }
      if (p == buffer + len) {                  // last entry
        *p = NUL;
      } else {
        *p++ = NUL;
        p = skipwhite(p);                       // skip to next entry
      }
    } else {          // NUL separates
      while (*p && p < buffer + len) {          // skip entry
        p++;
      }
      p++;                                      // skip NUL
    }
  }

  // Move the file names to allocated memory.
  for (j = 0, i = 0; i < *num_file; i++) {
    // Require the files to exist. Helps when using /bin/sh
    if (!(flags & EW_NOTFOUND) && !os_path_exists((*file)[i])) {
      continue;
    }

    // check if this entry should be included
    dir = (os_isdir((*file)[i]));
    if ((dir && !(flags & EW_DIR)) || (!dir && !(flags & EW_FILE)))
      continue;

    // Skip files that are not executable if we check for that.
    if (!dir && (flags & EW_EXEC)
        && !os_can_exe((*file)[i], NULL, !(flags & EW_SHELLCMD))) {
      continue;
    }

    p = xmalloc(STRLEN((*file)[i]) + 1 + dir);
    STRCPY(p, (*file)[i]);
    if (dir) {
      add_pathsep((char *)p);             // add '/' to a directory name
    }
    (*file)[j++] = p;
  }
  xfree(buffer);
  *num_file = j;

  if (*num_file == 0) {     // rejected all entries
    xfree(*file);
    *file = NULL;
    goto notfound;
  }

  return OK;

notfound:
  if (flags & EW_NOTFOUND) {
    save_patterns(num_pat, pat, num_file, file);
    return OK;
  }
  return FAIL;

}


static void save_patterns(int num_pat, char_u **pat, int *num_file,
                          char_u ***file)
{
  int i;
  char_u      *s;

  *file = xmalloc((size_t)num_pat * sizeof(char_u *));

  for (i = 0; i < num_pat; i++) {
    s = vim_strsave(pat[i]);
    // Be compatible with expand_filename(): halve the number of
    // backslashes.
    backslash_halve(s);
    (*file)[i] = s;
  }
  *num_file = num_pat;
}

static bool have_wildcard(int num, char_u **file)
{
  int i;

  for (i = 0; i < num; i++)
    if (path_has_wildcard(file[i]))
      return true;
  return false;
}

static bool have_dollars(int num, char_u **file)
{
  int i;

  for (i = 0; i < num; i++)
    if (vim_strchr(file[i], '$') != NULL)
      return true;
  return false;
}
