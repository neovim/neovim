#ifndef NEOVIM_OS_SHELL_H
#define NEOVIM_OS_SHELL_H

#include <stdbool.h>

#include "types.h"

char ** shell_build_argv(char_u *cmd, char_u *extra_shell_arg);
void shell_free_argv(char **argv);

#endif  // NEOVIM_OS_SHELL_H

