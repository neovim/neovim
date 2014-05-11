#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
int os_chdir(const char *path);
int os_dirname(char_u *buf, size_t len);
_Bool os_isdir(const char_u *name);
_Bool os_can_exe(const char_u *name);
int os_stat(const char_u *name, uv_stat_t *statbuf);
int32_t os_getperm(const char_u *name);
int os_setperm(const char_u *name, int perm);
_Bool os_file_exists(const char_u *name);
_Bool os_file_is_readonly(const char *name);
int os_file_is_writable(const char *name);
int os_rename(const char_u *path, const char_u *new_path);
int os_mkdir(const char *path, int32_t mode);
int os_rmdir(const char *path);
int os_remove(const char *path);
#include "func_attr.h"
