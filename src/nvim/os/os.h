#ifndef NVIM_OS_OS_H
#define NVIM_OS_OS_H
#include <uv.h>

#include "nvim/vim.h"

int os_chdir(const char *path);

int os_dirname(char_u *buf, size_t len);

bool os_isdir(const char_u *name);

bool os_can_exe(const char_u *name);

int32_t os_getperm(const char_u *name);

int os_setperm(const char_u *name, int perm);

bool os_file_exists(const char_u *name);

bool os_file_is_readonly(const char *name);

int os_file_is_writable(const char *name);

bool os_get_file_size(const char *name, off_t *size);

int os_rename(const char_u *path, const char_u *new_path);

int os_mkdir(const char *path, int32_t mode);

int os_rmdir(const char *path);

int os_remove(const char *path);

uint64_t os_get_total_mem_kib(void);
const char *os_getenv(const char *name);
int os_setenv(const char *name, const char *value, int overwrite);
char *os_getenvname_at_index(size_t index);

int64_t os_get_pid(void);

void os_get_hostname(char *hostname, size_t len);

int os_get_usernames(garray_T *usernames);
int os_get_user_name(char *s, size_t len);
int os_get_uname(uid_t uid, char *s, size_t len);
char *os_get_user_directory(const char *name);

int os_stat(const char_u *name, uv_stat_t *statbuf);

/// Struct which encapsulates stat information.
typedef struct {
  // TODO(stefan991): make stat private
  uv_stat_t stat;
} FileInfo;

bool os_get_file_info(const char *path, FileInfo *file_info);

bool os_get_file_info_link(const char *path, FileInfo *file_info);

bool os_get_file_info_fd(int file_descriptor, FileInfo *file_info);

bool os_file_info_id_equal(FileInfo *file_info_1, FileInfo *file_info_2);

#endif  // NVIM_OS_OS_H
