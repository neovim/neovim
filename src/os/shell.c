#include <string.h>
#include <stdbool.h>

#include "os/shell.h"
#include "types.h"
#include "vim.h"
#include "ascii.h"
#include "misc2.h"
#include "option_defs.h"
#include "charset.h"

static int tokenize(char_u *str, char **argv);
static int word_length(char_u *command);

/// Builds the argument vector for running the shell configured in `sh`
/// ('shell' option), optionally with a command that will be passed with `shcf`
/// ('shellcmdflag').
///
/// @param  cmd Command string. If NULL it will run an interactive shell.
/// @param  extra_shell_opt Extra argument to the shell (Optional).
/// @return A newly allocated argument vector. It must be freed with
///         `shell_free_argv` when no longer needed.
char ** shell_build_argv(char_u *cmd, char_u *extra_shell_opt)
{
  int i;
  char **rv;
  int argc = tokenize(p_sh, NULL) + tokenize(p_shcf, NULL);

  rv = (char **)alloc((unsigned)((argc + 4) * sizeof(char *)));

  if (rv == NULL) {
    // out of memory
    return NULL;
  }
  
  // Split 'shell'
  i = tokenize(p_sh, rv);

  if (extra_shell_opt != NULL) {
    // Push a copy of `extra_shell_opt`
    rv[i++] = strdup((char *)extra_shell_opt);
  }

  if (cmd != NULL) {
    // Split 'shellcmdflag'
    i += tokenize(p_shcf, rv + i);
    rv[i++] = strdup((char *)cmd);
  }

  rv[i] = NULL;

  return rv;
}

/// Release the memory allocated by `shell_build_argv`.
///
/// @param  argv The argument vector.
void shell_free_argv(char **argv)
{
  char **p = argv;

  if (p == NULL) {
    // Nothing was allocated, return
    return;
  }

  while (*p != NULL) {
    // Free each argument 
    free(*p);
    p++;
  }

  free(argv);
}

/// Parse a command string into a sequence of words, taking quotes into
/// consideration.
///
/// @param  str The command string to be parsed
/// @param  argv The vector that will be filled with copies of the parsed
///         words. It can be NULL if the caller only needs to count words.
/// @return The number of words parsed.
static int tokenize(char_u *str, char **argv)
{
  int argc = 0, len;
  char_u *p = str;

  while (*p != NUL) {
    len = word_length(p);

    if (argv != NULL) {
      // Fill the slot
      argv[argc] = malloc(len + 1);
      memcpy(argv[argc], p, len);
      argv[argc][len] = NUL;
    }

    argc++;
    p += len;
    p = skipwhite(p);
  }

  return argc;
}

/// Calculate the length of a shell word.
///
/// @param  str A pointer to the beginning of the word
/// @return The offset from `str` at which the word ends.
static int word_length(char_u *str)
{
  char_u *p = str;
  bool inquote = false;
  int length = 0;

  // Move `p` to the end of shell word by advancing the pointer while it's
  // inside a quote or it's a non-whitespace character
  while (*p && (inquote || (*p != ' ' && *p != TAB))) {
    if (*p == '"') {
      // Found a quote character, switch the `inquote` flag
      inquote = !inquote;
    }

    p++;
    length++;
  }

  return length;
}
