#ifndef NEOVIM_OS_OS_H
#define NEOVIM_OS_OS_H

#include "vim.h"

long_u mch_total_mem(int special);
int mch_chdir(char *path);
int mch_dirname(char_u *buf, int len);
int mch_get_absolute_path(char_u *fname, char_u *buf, int len, int force);
int mch_is_absolute_path(const char_u *fname);
int mch_isdir(const char_u *name);
int mch_can_exe(const char_u *name);
const char *mch_getenv(const char *name);
int mch_setenv(const char *name, const char *value, int overwrite);
char *mch_getenvname_at_index(size_t index);
int mch_get_usernames(garray_T *usernames);
int mch_get_user_name(char *s, size_t len);
int mch_get_uname(uid_t uid, char *s, size_t len);
char *mch_get_user_directory(const char *name);
long mch_getperm(const char_u *name);
int mch_setperm(const char_u *name, int perm);
int os_file_exists(char_u *name);

#endif
