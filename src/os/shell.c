#include <stdbool.h>

#include "os/shell.h"
#include "types.h"
#include "vim.h"
#include "ascii.h"
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

char ** shell_build_argv(char_u **ptr, int argc);
