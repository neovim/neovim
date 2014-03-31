#ifndef NEOVIM_OS_SHELL_H
#define NEOVIM_OS_SHELL_H

#include <stdbool.h>

#include "types.h"

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

/// Builds the argument vector for running the shell configured in `sh`
/// ('shell' option), optionally with a command that will be passed with `shcf`
/// ('shellcmdflag').
///
/// @param cmd Command string. If NULL it will run an interactive shell.
/// @param extra_shell_opt Extra argument to the shell. If NULL it is ignored
/// @return A newly allocated argument vector. It must be freed with
///         `shell_free_argv` when no longer needed.
char ** shell_build_argv(char_u *cmd, char_u *extra_shell_arg);
/// Releases the memory allocated by `shell_build_argv`.
///
/// @param argv The argument vector.
void shell_free_argv(char **argv);

#endif  // NEOVIM_OS_SHELL_H

