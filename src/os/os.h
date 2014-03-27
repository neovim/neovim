#ifndef NEOVIM_OS_OS_H
#define NEOVIM_OS_OS_H

#include "vim.h"

long_u os_total_mem(int special);
int os_chdir(const char *path);
int os_dirname(char_u *buf, size_t len);
int os_get_absolute_path(char_u *fname, char_u *buf, int len, int force);
int os_is_absolute_path(const char_u *fname);
int os_isdir(const char_u *name);
int os_can_exe(const char_u *name);
const char *os_getenv(const char *name);
int os_setenv(const char *name, const char *value, int overwrite);
char *os_getenvname_at_index(size_t index);
int os_get_usernames(garray_T *usernames);
int os_get_user_name(char *s, size_t len);
int os_get_uname(uid_t uid, char *s, size_t len);
char *os_get_user_directory(const char *name);
int32_t os_getperm(const char_u *name);
int os_setperm(const char_u *name, int perm);
int os_file_exists(const char_u *name);

#endif  // NEOVIM_OS_OS_H
