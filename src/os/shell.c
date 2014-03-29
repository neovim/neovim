#include <string.h>
#include <stdbool.h>

#include "os/shell.h"
#include "types.h"
#include "vim.h"
#include "ascii.h"
#include "misc2.h"
#include "option_defs.h"
#include "charset.h"


void shell_skip_word(char_u **cmd)
{
  char_u *p = *cmd;
  bool inquote = false;

  // Move `p` to the end of shell word by advancing the pointer it while it's
  // inside a quote or it's a non-whitespace character
  while (*p && (inquote || (*p != ' ' && *p != TAB))) {
    if (*p == '"')
      // Found a quote character, switch the `inquote` flag
      inquote = !inquote;
    ++p;
  }

  *cmd = p;
}

int shell_count_argc(char_u **ptr)
{
  int rv = 0;
  char_u *p = *ptr;

  while (true) {
    rv++;
    shell_skip_word(&p);
    if (*p == NUL)
      break;
    // Move to the next word
    p = skipwhite(p);
  }

  // Account for multiple args in p_shcf('shellcmdflag' option)
  p = p_shcf;
  while (true) {
    // Same as above, but doesn't need to take quotes into consideration
    p = skiptowhite(p);
    if (*p == NUL)
      break;
    rv++;
    p = skipwhite(p);
  }

  *ptr = p;

  return rv;
}

char ** shell_build_argv(int argc, char_u *cmd,
    char_u *extra_shell_arg, char_u **ptr, char_u **p_shcf_copy_ptr)
{
  char **argv;
  char_u *p_shcf_copy = *p_shcf_copy_ptr;
  char_u *p = *ptr;
  // Allocate argv memory
  argv = (char **)alloc((unsigned)((argc + 4) * sizeof(char *)));
  if (argv == NULL) // out of memory
    return NULL;
  
  // Build argv[]
  argc = 0;
  while (true) {
    argv[argc] = (char *)p;
    ++argc;
    shell_skip_word(&p);
    if (*p == NUL)
      break;
    // Terminate the word
    *p++ = NUL;
    p = skipwhite(p);
  }
  if (cmd != NULL) {
    char_u  *s;

    if (extra_shell_arg != NULL)
      argv[argc++] = (char *)extra_shell_arg;

    // Break 'shellcmdflag' into white separated parts.  This doesn't
    // handle quoted strings, they are very unlikely to appear.
    p_shcf_copy = alloc((unsigned)STRLEN(p_shcf) + 1);
    if (p_shcf_copy == NULL) {
      // out of memory 
      free(argv);
      return NULL;
    }

    s = p_shcf_copy;
    p = p_shcf;
    while (*p != NUL) {
      argv[argc++] = (char *)s;
      while (*p && *p != ' ' && *p != TAB)
        *s++ = *p++;
      *s++ = NUL;
      p = skipwhite(p);
    }

    argv[argc++] = (char *)cmd;
  }

  argv[argc] = NULL;
  *ptr = p;
  *p_shcf_copy_ptr = p_shcf_copy;

  return argv;
}
