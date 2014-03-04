#ifndef NEOVIM_OS_H
#define NEOVIM_OS_H

#include "../vim.h"

long_u mch_total_mem(int special);
int mch_chdir(char *path);
int mch_dirname(char_u *buf, int len);
int mch_full_name (char_u *fname, char_u *buf, int len, int force);
int mch_is_full_name (char_u *fname);
int mch_isdir(char_u *name);

#endif
