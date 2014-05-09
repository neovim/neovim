#ifndef NVIM_OS_SHELL_H
#define NVIM_OS_SHELL_H

#include <stdbool.h>

#include "nvim/types.h"

// Flags for mch_call_shell() second argument
typedef enum {
  kShellOptFilter = 1,      ///< filtering text
  kShellOptExpand = 2,      ///< expanding wildcards
  kShellOptCooked = 4,      ///< set term to cooked mode
  kShellOptDoOut = 8,       ///< redirecting output
  kShellOptSilent = 16,     ///< don't print error returned by command
  kShellOptRead = 32,       ///< read lines and insert into buffer
  kShellOptWrite = 64,      ///< write lines from buffer
  kShellOptHideMess = 128,  ///< previously a global variable from os_unix.c
} ShellOpts;

char ** shell_build_argv(char_u *cmd, char_u *extra_shell_arg);

void shell_free_argv(char **argv);

int os_call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg);

#endif  // NVIM_OS_SHELL_H

