#include <stdbool.h>

#include "os/shell.h"
#include "types.h"
#include "ascii.h"


void shell_skip_word(char_u **ptr)
{
  char_u *p = *ptr;
  bool inquote = false;

  // Move `p` to the end of shell word by advancing the pointer it while it's
  // inside a quote or it's a non-whitespace character
  while (*p && (inquote || (*p != ' ' && *p != TAB))) {
    if (*p == '"')
      // Found a quote character, switch the `inquote` flag
      inquote = !inquote;
    ++p;
  }

  *ptr = p;
}
