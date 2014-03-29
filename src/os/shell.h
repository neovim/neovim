#ifndef NEOVIM_OS_SHELL_H
#define NEOVIM_OS_SHELL_H

#include <stdbool.h>

#include "types.h"

void shell_skip_word(char_u **ptr);
int shell_count_argc(char_u **ptr);
char ** shell_build_argv(int argc, char_u *cmd,
    char_u *extra_shell_arg, char_u **ptr, char_u **p_shcf_copy_ptr);

#endif  // NEOVIM_OS_SHELL_H

