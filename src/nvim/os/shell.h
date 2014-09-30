#ifndef NVIM_OS_SHELL_H
#define NVIM_OS_SHELL_H

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/shell.h.generated.h"
#endif
#endif  // NVIM_OS_SHELL_H
