#ifndef NVIM_OS_SHELL_H
#define NVIM_OS_SHELL_H

#include <stdio.h>

#include "nvim/types.h"

// Flags for os_call_shell() second argument
typedef enum {
  kShellOptFilter = 1,     ///< filtering text
  kShellOptExpand = 2,     ///< expanding wildcards
  kShellOptDoOut = 4,      ///< redirecting output
  kShellOptSilent = 8,     ///< don't print error returned by command
  kShellOptRead = 16,      ///< read lines and insert into buffer
  kShellOptWrite = 32,     ///< write lines from buffer
  kShellOptHideMess = 64,  ///< previously a global variable from os_unix.c
} ShellOpts;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/shell.h.generated.h"
#endif
#endif  // NVIM_OS_SHELL_H
