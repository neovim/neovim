// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/ascii.h"
#include "nvim/fileio.h"
#include "nvim/lib/kvec.h"
#include "nvim/log.h"
#include "nvim/event/loop.h"
#include "nvim/event/libuv_process.h"
#include "nvim/event/rstream.h"
#include "nvim/ex_cmds.h"
#include "nvim/misc1.h"
#include "nvim/os/shell.h"
#include "nvim/os/signal.h"
#include "nvim/path.h"
#include "nvim/types.h"
#include "nvim/main.h"
#include "nvim/vim.h"
#include "nvim/message.h"
#include "nvim/memory.h"
#include "nvim/ui.h"
#include "nvim/screen.h"
#include "nvim/memline.h"
#include "nvim/option_defs.h"
#include "nvim/charset.h"
#include "nvim/strings.h"

#define DYNAMIC_BUFFER_INIT { NULL, 0, 0 }
#define NS_1_SECOND         1000000000U     // 1 second, in nanoseconds
#define OUT_DATA_THRESHOLD  1024 * 10U      // 10KB, "a few screenfuls" of data.

#define SHELL_SPECIAL (char_u *)"\t \"&'$;<>()\\|"

typedef struct {
  char *data;
  size_t cap, len;
} DynamicBuffer;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/shell.c.generated.h"
#endif

static void save_patterns(int num_pat, char_u **pat, int *num_file,
                          char_u ***file)
{
  *file = xmalloc((size_t)num_pat * sizeof(char_u *));
  for (int i = 0; i < num_pat; i++) {
    char_u *s = vim_strsave(pat[i]);
    // Be compatible with expand_filename(): halve the number of
    // backslashes.
    backslash_halve(s);
    (*file)[i] = s;
  }
  *num_file = num_pat;
}

static bool have_wildcard(int num, char_u **file)
{
  for (int i = 0; i < num; i++) {
    if (path_has_wildcard(file[i])) {
      return true;
    }
  }
  return false;
}

static bool have_dollars(int num, char_u **file)
{
  for (int i = 0; i < num; i++) {
    if (vim_strchr(file[i], '$') != NULL) {
      return true;
    }
  }
  return false;
}

/// Performs wildcard pattern matching using the shell.
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
int os_expand_wildcards(int num_pat, char_u **pat, int *num_file,
                        char_u ***file, int flags)
  FUNC_ATTR_NONNULL_ARG(3)
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
#define STYLE_ECHO      0       // use "echo", the default
#define STYLE_GLOB      1       // use "glob", for csh
#define STYLE_VIMGLOB   2       // use "vimglob", for Posix sh
#define STYLE_PRINT     3       // use "print -N", for zsh
#define STYLE_BT        4       // `cmd` expansion, execute the pattern directly
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
  if (shell_style == STYLE_ECHO
      && strstr((char *)path_tail(p_sh), "sh") != NULL) {
    shell_style = STYLE_VIMGLOB;
  }

  // Compute the length of the command.  We need 2 extra bytes: for the
  // optional '&' and for the NUL.
  // Worst case: "unset nonomatch; print -N >" plus two is 29
  len = STRLEN(tempname) + 29;
  if (shell_style == STYLE_VIMGLOB) {
    len += STRLEN(sh_vimglob_func);
  }

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
    if (flags & EW_NOTFOUND) {
      STRCPY(command, "set nonomatch; ");
    } else {
      STRCPY(command, "unset nonomatch; ");
    }
    if (shell_style == STYLE_GLOB) {
      STRCAT(command, "glob >");
    } else if (shell_style == STYLE_PRINT) {
      STRCAT(command, "print -N >");
    } else if (shell_style == STYLE_VIMGLOB) {
      STRCAT(command, sh_vimglob_func);
    } else {
      STRCAT(command, "echo >");
    }
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
  i = call_shell(command, shellopts, extra_shell_arg);

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
      cmdline_row = Rows - 1;           // continue on last line
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
  assert(templen <= (long long)SIZE_MAX);  // NOLINT(runtime/int)
#endif
  len = (size_t)templen;
  fseek(fd, 0L, SEEK_SET);
  buffer = xmalloc(len + 1);
  // fread() doesn't terminate buffer with NUL;
  // appropriate termination (not always NUL) is done below.
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
      if (len && (int)STRLEN(buffer) < (int)len) {
        did_find_nul = true;
      } else {
        check_spaces = true;
      }
    }

    // Make sure the buffer ends with a NUL.  For STYLE_PRINT there
    // already is one, for STYLE_GLOB it needs to be added.
    if (len && buffer[len - 1] == NUL) {
      len--;
    } else {
      buffer[len] = NUL;
    }
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
  for (i = 0; i < *num_file; i++) {
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
    if ((dir && !(flags & EW_DIR)) || (!dir && !(flags & EW_FILE))) {
      continue;
    }

    // Skip files that are not executable if we check for that.
    if (!dir && (flags & EW_EXEC)
        && !os_can_exe((char *)(*file)[i], NULL, !(flags & EW_SHELLCMD))) {
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
    XFREE_CLEAR(*file);
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

/// Builds the argument vector for running the user-configured 'shell' (p_sh)
/// with an optional command prefixed by 'shellcmdflag' (p_shcf). E.g.:
///
///   ["shell", "-extra_args", "-shellcmdflag", "command with spaces"]
///
/// @param cmd Command string, or NULL to run an interactive shell.
/// @param extra_args Extra arguments to the shell, or NULL.
/// @return Newly allocated argument vector. Must be freed with shell_free_argv.
char **shell_build_argv(const char *cmd, const char *extra_args)
  FUNC_ATTR_NONNULL_RET
{
  size_t argc = tokenize(p_sh, NULL) + (cmd ? tokenize(p_shcf, NULL) : 0);
  char **rv = xmalloc((argc + 4) * sizeof(*rv));

  // Split 'shell'
  size_t i = tokenize(p_sh, rv);

  if (extra_args) {
    rv[i++] = xstrdup(extra_args);        // Push a copy of `extra_args`
  }

  if (cmd) {
    i += tokenize(p_shcf, rv + i);        // Split 'shellcmdflag'
    rv[i++] = shell_xescape_xquote(cmd);  // Copy (and escape) `cmd`.
  }

  rv[i] = NULL;

  assert(rv[0]);

  return rv;
}

/// Releases the memory allocated by `shell_build_argv`.
///
/// @param argv The argument vector.
void shell_free_argv(char **argv)
{
  char **p = argv;
  if (p == NULL) {
    // Nothing was allocated, return
    return;
  }
  while (*p != NULL) {
    // Free each argument
    xfree(*p);
    p++;
  }
  xfree(argv);
}

/// Joins shell arguments from `argv` into a new string.
/// If the result is too long it is truncated with ellipsis ("...").
///
/// @returns[allocated] `argv` joined to a string.
char *shell_argv_to_str(char **const argv)
  FUNC_ATTR_NONNULL_ALL
{
  size_t n = 0;
  char **p = argv;
  char *rv = xcalloc(256, sizeof(*rv));
  const size_t maxsize = (256 * sizeof(*rv));
  if (*p == NULL) {
    return rv;
  }
  while (*p != NULL) {
    xstrlcat(rv, "'", maxsize);
    xstrlcat(rv, *p, maxsize);
    n = xstrlcat(rv,  "' ", maxsize);
    if (n >= maxsize) {
      break;
    }
    p++;
  }
  if (n < maxsize) {
    rv[n - 1] = '\0';
  } else {
    // Command too long, show ellipsis: "/bin/bash 'foo' 'bar'..."
    rv[maxsize - 4] = '.';
    rv[maxsize - 3] = '.';
    rv[maxsize - 2] = '.';
    rv[maxsize - 1] = '\0';
  }
  return rv;
}

/// Calls the user-configured 'shell' (p_sh) for running a command or wildcard
/// expansion.
///
/// @param cmd The command to execute, or NULL to run an interactive shell.
/// @param opts Options that control how the shell will work.
/// @param extra_args Extra arguments to the shell, or NULL.
///
/// @return shell command exit code
int os_call_shell(char_u *cmd, ShellOpts opts, char_u *extra_args)
{
  DynamicBuffer input = DYNAMIC_BUFFER_INIT;
  char *output = NULL, **output_ptr = NULL;
  int current_state = State;
  bool forward_output = true;

  // While the child is running, ignore terminating signals
  signal_reject_deadly();

  if (opts & (kShellOptHideMess | kShellOptExpand)) {
    forward_output = false;
  } else {
    State = EXTERNCMD;

    if (opts & kShellOptWrite) {
      read_input(&input);
    }

    if (opts & kShellOptRead) {
      output_ptr = &output;
      forward_output = false;
    } else if (opts & kShellOptDoOut) {
      // Caller has already redirected output
      forward_output = false;
    }
  }

  size_t nread;
  int exitcode = do_os_system(shell_build_argv((char *)cmd, (char *)extra_args),
                              input.data, input.len, output_ptr, &nread,
                              emsg_silent, forward_output);
  xfree(input.data);

  if (output) {
    (void)write_output(output, nread, true);
    xfree(output);
  }

  if (!emsg_silent && exitcode != 0 && !(opts & kShellOptSilent)) {
    MSG_PUTS(_("\nshell returned "));
    msg_outnum(exitcode);
    msg_putchar('\n');
  }

  State = current_state;
  signal_accept_deadly();

  return exitcode;
}

/// os_system - synchronously execute a command in the shell
///
/// example:
///   char *output = NULL;
///   size_t nread = 0;
///   char *argv[] = {"ls", "-la", NULL};
///   int exitcode = os_sytem(argv, NULL, 0, &output, &nread);
///
/// @param argv The commandline arguments to be passed to the shell. `argv`
///             will be consumed.
/// @param input The input to the shell (NULL for no input), passed to the
///              stdin of the resulting process.
/// @param len The length of the input buffer (not used if `input` == NULL)
/// @param[out] output Pointer to a location where the output will be
///                    allocated and stored. Will point to NULL if the shell
///                    command did not output anything. If NULL is passed,
///                    the shell output will be ignored.
/// @param[out] nread the number of bytes in the returned buffer (if the
///             returned buffer is not NULL)
/// @return the return code of the process, -1 if the process couldn't be
///         started properly
int os_system(char **argv,
              const char *input,
              size_t len,
              char **output,
              size_t *nread) FUNC_ATTR_NONNULL_ARG(1)
{
  return do_os_system(argv, input, len, output, nread, true, false);
}

static int do_os_system(char **argv,
                        const char *input,
                        size_t len,
                        char **output,
                        size_t *nread,
                        bool silent,
                        bool forward_output)
{
  out_data_decide_throttle(0);  // Initialize throttle decider.
  out_data_ring(NULL, 0);       // Initialize output ring-buffer.
  bool has_input = (input != NULL && input[0] != '\0');

  // the output buffer
  DynamicBuffer buf = DYNAMIC_BUFFER_INIT;
  stream_read_cb data_cb = system_data_cb;
  if (nread) {
    *nread = 0;
  }

  if (forward_output) {
    data_cb = out_data_cb;
  } else if (!output) {
    data_cb = NULL;
  }

  // Copy the program name in case we need to report an error.
  char prog[MAXPATHL];
  xstrlcpy(prog, argv[0], MAXPATHL);

  LibuvProcess uvproc = libuv_process_init(&main_loop, &buf);
  Process *proc = &uvproc.process;
  MultiQueue *events = multiqueue_new_child(main_loop.events);
  proc->events = events;
  proc->argv = argv;
  int status = process_spawn(proc, has_input, true, true);
  if (status) {
    loop_poll_events(&main_loop, 0);
    // Failed, probably 'shell' is not executable.
    if (!silent) {
      MSG_PUTS(_("\nshell failed to start: "));
      msg_outtrans((char_u *)os_strerror(status));
      MSG_PUTS(": ");
      msg_outtrans((char_u *)prog);
      msg_putchar('\n');
    }
    multiqueue_free(events);
    return -1;
  }

  // Note: unlike process events, stream events are not queued, as we want to
  // deal with stream events as fast a possible.  It prevents closing the
  // streams while there's still data in the OS buffer (due to the process
  // exiting before all data is read).
  if (has_input) {
    wstream_init(&proc->in, 0);
  }
  rstream_init(&proc->out, 0);
  rstream_start(&proc->out, data_cb, &buf);
  rstream_init(&proc->err, 0);
  rstream_start(&proc->err, data_cb, &buf);

  // write the input, if any
  if (has_input) {
    WBuffer *input_buffer = wstream_new_buffer((char *)input, len, 1, NULL);

    if (!wstream_write(&proc->in, input_buffer)) {
      // couldn't write, stop the process and tell the user about it
      process_stop(proc);
      return -1;
    }
    // close the input stream after everything is written
    wstream_set_write_cb(&proc->in, shell_write_cb, NULL);
  }

  // Invoke busy_start here so LOOP_PROCESS_EVENTS_UNTIL will not change the
  // busy state.
  ui_busy_start();
  ui_flush();
  if (forward_output) {
    msg_sb_eol();
    msg_start();
    msg_no_more = true;
    lines_left = -1;
  }
  int exitcode = process_wait(proc, -1, NULL);
  if (!got_int && out_data_decide_throttle(0)) {
    // Last chunk of output was skipped; display it now.
    out_data_ring(NULL, SIZE_MAX);
  }
  if (forward_output) {
    // caller should decide if wait_return is invoked
    no_wait_return++;
    msg_end();
    no_wait_return--;
    msg_no_more = false;
  }

  ui_busy_stop();

  // prepare the out parameters if requested
  if (output) {
    if (buf.len == 0) {
      // no data received from the process, return NULL
      *output = NULL;
      xfree(buf.data);
    } else {
      // NUL-terminate to make the output directly usable as a C string
      buf.data[buf.len] = NUL;
      *output = buf.data;
    }

    if (nread) {
      *nread = buf.len;
    }
  }

  assert(multiqueue_empty(events));
  multiqueue_free(events);

  return exitcode;
}

///  - ensures at least `desired` bytes in buffer
///
/// TODO(aktau): fold with kvec/garray
static void dynamic_buffer_ensure(DynamicBuffer *buf, size_t desired)
{
  if (buf->cap >= desired) {
    assert(buf->data);
    return;
  }

  buf->cap = desired;
  kv_roundup32(buf->cap);
  buf->data = xrealloc(buf->data, buf->cap);
}

static void system_data_cb(Stream *stream, RBuffer *buf, size_t count,
    void *data, bool eof)
{
  DynamicBuffer *dbuf = data;

  size_t nread = buf->size;
  dynamic_buffer_ensure(dbuf, dbuf->len + nread + 1);
  rbuffer_read(buf, dbuf->data + dbuf->len, nread);
  dbuf->len += nread;
}

/// Tracks output received for the current executing shell command, and displays
/// a pulsing "..." when output should be skipped. Tracking depends on the
/// synchronous/blocking nature of ":!".
///
/// Purpose:
///   1. CTRL-C is more responsive. #1234 #5396
///   2. Improves performance of :! (UI, esp. TUI, is the bottleneck).
///   3. Avoids OOM during long-running, spammy :!.
///
/// Vim does not need this hack because:
///   1. :! in terminal-Vim runs in cooked mode, so CTRL-C is caught by the
///      terminal and raises SIGINT out-of-band.
///   2. :! in terminal-Vim uses a tty (Nvim uses pipes), so commands
///      (e.g. `git grep`) may page themselves.
///
/// @param size Length of data, used with internal state to decide whether
///             output should be skipped. size=0 resets the internal state and
///             returns the previous decision.
///
/// @returns true if output should be skipped and pulse was displayed.
///          Returns the previous decision if size=0.
static bool out_data_decide_throttle(size_t size)
{
  static uint64_t   started     = 0;  // Start time of the current throttle.
  static size_t     received    = 0;  // Bytes observed since last throttle.
  static size_t     visit       = 0;  // "Pulse" count of the current throttle.
  static char       pulse_msg[] = { ' ', ' ', ' ', '\0' };

  if (!size) {
    bool previous_decision = (visit > 0);
    started = received = visit = 0;
    return previous_decision;
  }

  received += size;
  if (received < OUT_DATA_THRESHOLD
      // Display at least the first chunk of output even if it is big.
      || (!started && received < size + 1000)) {
    return false;
  } else if (!visit) {
    started = os_hrtime();
  } else {
    uint64_t since = os_hrtime() - started;
    if (since < (visit * 0.1L * NS_1_SECOND)) {
      return true;
    }
    if (since > (3 * NS_1_SECOND)) {
      received = visit = 0;
      return false;
    }
  }

  visit++;
  // Pulse "..." at the bottom of the screen.
  size_t tick = visit % 4;
  pulse_msg[0] = (tick > 0) ? '.' : ' ';
  pulse_msg[1] = (tick > 1) ? '.' : ' ';
  pulse_msg[2] = (tick > 2) ? '.' : ' ';
  if (visit == 1) {
    msg_puts("...\n");
  }
  msg_putchar('\r');  // put cursor at start of line
  msg_puts(pulse_msg);
  msg_putchar('\r');
  ui_flush();
  return true;
}

/// Saves output in a quasi-ringbuffer. Used to ensure the last ~page of
/// output for a shell-command is always displayed.
///
/// Init mode: Resets the internal state.
///   output = NULL
///   size   = 0
/// Print mode: Displays the current saved data.
///   output = NULL
///   size   = SIZE_MAX
///
/// @param  output  Data to save, or NULL to invoke a special mode.
/// @param  size    Length of `output`.
static void out_data_ring(char *output, size_t size)
{
#define MAX_CHUNK_SIZE (OUT_DATA_THRESHOLD / 2)
  static char    last_skipped[MAX_CHUNK_SIZE];  // Saved output.
  static size_t  last_skipped_len = 0;

  assert(output != NULL || (size == 0 || size == SIZE_MAX));

  if (output == NULL && size == 0) {          // Init mode
    last_skipped_len = 0;
    return;
  }

  if (output == NULL && size == SIZE_MAX) {   // Print mode
    out_data_append_to_screen(last_skipped, &last_skipped_len, true);
    return;
  }

  // This is basically a ring-buffer...
  if (size >= MAX_CHUNK_SIZE) {               // Save mode
    size_t start = size - MAX_CHUNK_SIZE;
    memcpy(last_skipped, output + start, MAX_CHUNK_SIZE);
    last_skipped_len = MAX_CHUNK_SIZE;
  } else if (size > 0) {
    // Length of the old data that can be kept.
    size_t keep_len   = MIN(last_skipped_len, MAX_CHUNK_SIZE - size);
    size_t keep_start = last_skipped_len - keep_len;
    // Shift the kept part of the old data to the start.
    if (keep_start) {
      memmove(last_skipped, last_skipped + keep_start, keep_len);
    }
    // Copy the entire new data to the remaining space.
    memcpy(last_skipped + keep_len, output, size);
    last_skipped_len = keep_len + size;
  }
}

/// Continue to append data to last screen line.
///
/// @param output       Data to append to screen lines.
/// @param remaining    Size of data.
/// @param new_line     If true, next data output will be on a new line.
static void out_data_append_to_screen(char *output, size_t *count, bool eof)
  FUNC_ATTR_NONNULL_ALL
{
  char *p = output, *end = output + *count;
  while (p < end) {
    if (*p == '\n' || *p == '\r' || *p == TAB || *p == BELL) {
      msg_putchar_attr((uint8_t)(*p), 0);
      p++;
    } else {
      // Note: this is not 100% precise:
      // 1. we don't check if received continuation bytes are already invalid
      //    and we thus do some buffering that could be avoided
      // 2. we don't compose chars over buffer boundaries, even if we see an
      //    incomplete UTF-8 sequence that could be composing with the last
      //    complete sequence.
      // This will be corrected when we switch to vterm based implementation
      int i = *p ? utfc_ptr2len_len((char_u *)p, (int)(end-p)) : 1;
      if (!eof && i == 1 && utf8len_tab_zero[*(uint8_t *)p] > (end-p)) {
        *count = (size_t)(p - output);
        goto end;
      }

      (void)msg_outtrans_len_attr((char_u *)p, i, 0);
      p += i;
    }
  }

end:
  ui_flush();
}

static void out_data_cb(Stream *stream, RBuffer *buf, size_t count, void *data,
    bool eof)
{
  size_t cnt;
  char *ptr = rbuffer_read_ptr(buf, &cnt);

  if (ptr != NULL && cnt > 0
      && out_data_decide_throttle(cnt)) {  // Skip output above a threshold.
    // Save the skipped output. If it is the final chunk, we display it later.
    out_data_ring(ptr, cnt);
  } else if (ptr != NULL) {
    out_data_append_to_screen(ptr, &cnt, eof);
  }

  if (cnt) {
    rbuffer_consumed(buf, cnt);
  }

  // Move remaining data to start of buffer, so the buffer can never
  // wrap around.
  rbuffer_reset(buf);
}

/// Parses a command string into a sequence of words, taking quotes into
/// consideration.
///
/// @param str The command string to be parsed
/// @param argv The vector that will be filled with copies of the parsed
///        words. It can be NULL if the caller only needs to count words.
/// @return The number of words parsed.
static size_t tokenize(const char_u *const str, char **const argv)
  FUNC_ATTR_NONNULL_ARG(1)
{
  size_t argc = 0;
  const char *p = (const char *) str;

  while (*p != NUL) {
    const size_t len = word_length((const char_u *) p);

    if (argv != NULL) {
      // Fill the slot
      argv[argc] = vim_strnsave_unquoted(p, len);
    }

    argc++;
    p = (const char *) skipwhite((char_u *) (p + len));
  }

  return argc;
}

/// Calculates the length of a shell word.
///
/// @param str A pointer to the first character of the word
/// @return The offset from `str` at which the word ends.
static size_t word_length(const char_u *str)
{
  const char_u *p = str;
  bool inquote = false;
  size_t length = 0;

  // Move `p` to the end of shell word by advancing the pointer while it's
  // inside a quote or it's a non-whitespace character
  while (*p && (inquote || (*p != ' ' && *p != TAB))) {
    if (*p == '"') {
      // Found a quote character, switch the `inquote` flag
      inquote = !inquote;
    } else if (*p == '\\' && inquote) {
      p++;
      length++;
    }

    p++;
    length++;
  }

  return length;
}

/// To remain compatible with the old implementation (which forked a process
/// for writing) the entire text is copied to a temporary buffer before the
/// event loop starts. If we don't (by writing in chunks returned by `ml_get`)
/// the buffer being modified might get modified by reading from the process
/// before we finish writing.
static void read_input(DynamicBuffer *buf)
{
  size_t written = 0, l = 0, len = 0;
  linenr_T lnum = curbuf->b_op_start.lnum;
  char_u *lp = ml_get(lnum);

  for (;;) {
    l = strlen((char *)lp + written);
    if (l == 0) {
      len = 0;
    } else if (lp[written] == NL) {
      // NL -> NUL translation
      len = 1;
      dynamic_buffer_ensure(buf, buf->len + len);
      buf->data[buf->len++] = NUL;
    } else {
      char_u  *s = vim_strchr(lp + written, NL);
      len = s == NULL ? l : (size_t)(s - (lp + written));
      dynamic_buffer_ensure(buf, buf->len + len);
      memcpy(buf->data + buf->len, lp + written, len);
      buf->len += len;
    }

    if (len == l) {
      // Finished a line, add a NL, unless this line should not have one.
      if (lnum != curbuf->b_op_end.lnum
          || (!curbuf->b_p_bin && curbuf->b_p_fixeol)
          || (lnum != curbuf->b_no_eol_lnum
              && (lnum != curbuf->b_ml.ml_line_count || curbuf->b_p_eol))) {
        dynamic_buffer_ensure(buf, buf->len + 1);
        buf->data[buf->len++] = NL;
      }
      ++lnum;
      if (lnum > curbuf->b_op_end.lnum) {
        break;
      }
      lp = ml_get(lnum);
      written = 0;
    } else if (len > 0) {
      written += len;
    }
  }
}

static size_t write_output(char *output, size_t remaining, bool eof)
{
  if (!output) {
    return 0;
  }

  char *start = output;
  size_t off = 0;
  while (off < remaining) {
    if (output[off] == NL) {
      // Insert the line
      output[off] = NUL;
      ml_append(curwin->w_cursor.lnum++, (char_u *)output, (int)off + 1,
                false);
      size_t skip = off + 1;
      output += skip;
      remaining -= skip;
      off = 0;
      continue;
    }

    if (output[off] == NUL) {
      // Translate NUL to NL
      output[off] = NL;
    }
    off++;
  }

  if (eof) {
    if (remaining) {
      // append unfinished line
      ml_append(curwin->w_cursor.lnum++, (char_u *)output, 0, false);
      // remember that the NL was missing
      curbuf->b_no_eol_lnum = curwin->w_cursor.lnum;
      output += remaining;
    } else {
      curbuf->b_no_eol_lnum = 0;
    }
  }

  ui_flush();

  return (size_t)(output - start);
}

static void shell_write_cb(Stream *stream, void *data, int status)
{
  if (status) {
    // Can happen if system() tries to send input to a shell command that was
    // backgrounded (:call system("cat - &", "foo")). #3529 #5241
    msg_schedule_emsgf(_("E5677: Error writing input to shell-command: %s"),
                       uv_err_name(status));
  }
  stream_close(stream, NULL, NULL);
}

/// Applies 'shellxescape' (p_sxe) and 'shellxquote' (p_sxq) to a command.
///
/// @param cmd Command string
/// @return    Escaped/quoted command string (allocated).
static char *shell_xescape_xquote(const char *cmd)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (*p_sxq == NUL) {
    return xstrdup(cmd);
  }

  const char *ecmd = cmd;
  if (*p_sxe != NUL && STRCMP(p_sxq, "(") == 0) {
    ecmd = (char *)vim_strsave_escaped_ext((char_u *)cmd, p_sxe, '^', false);
  }
  size_t ncmd_size = strlen(ecmd) + STRLEN(p_sxq) * 2 + 1;
  char *ncmd = xmalloc(ncmd_size);

  // When 'shellxquote' is ( append ).
  // When 'shellxquote' is "( append )".
  if (STRCMP(p_sxq, "(") == 0) {
    vim_snprintf(ncmd, ncmd_size, "(%s)", ecmd);
  } else if (STRCMP(p_sxq, "\"(") == 0) {
    vim_snprintf(ncmd, ncmd_size, "\"(%s)\"", ecmd);
  } else {
    vim_snprintf(ncmd, ncmd_size, "%s%s%s", p_sxq, ecmd, p_sxq);
  }

  if (ecmd != cmd) {
    xfree((void *)ecmd);
  }

  return ncmd;
}

