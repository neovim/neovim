#ifndef NEOVIM_OS_H
#define NEOVIM_OS_H

#include "../vim.h"

long_u mch_total_mem(int special);
int mch_chdir(char *path);

#endif
