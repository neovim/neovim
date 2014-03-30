#ifndef NEOVIM_OS_SHELL_H
#define NEOVIM_OS_SHELL_H

#include <stdbool.h>

#include "types.h"

// Flags for mch_call_shell() second argument
typedef enum {
  kShellOptFilter = 1,  // filtering text
  kShellOptExpand = 2,  // expanding wildcards
  kShellOptCooked = 4,  // set term to cooked mode
  kShellOptDoOut = 8,   // redirecting output
  kShellOptSilent = 16, // don't print error returned by command
  kShellOptRead = 32,   // read lines and insert into buffer
  kShellOptWrite = 64   // write lines from buffer
} ShellOpts;

char ** shell_build_argv(char_u *cmd, char_u *extra_shell_arg);
void shell_free_argv(char **argv);

#endif  // NEOVIM_OS_SHELL_H

