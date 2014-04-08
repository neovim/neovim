#ifndef NEOVIM_OS_OS_H
#define NEOVIM_OS_OS_H
#include <uv.h>

#include "vim.h"

/// Change to the given directory.
///
/// @return `0` on success, a libuv error code on failure.
int os_chdir(const char *path);

/// Get the name of current directory.
///
/// @param buf Buffer to store the directory name.
/// @param len Length of `buf`.
/// @return `OK` for success, `FAIL` for failure.
int os_dirname(char_u *buf, size_t len);

/// Check if the given path is a directory or not.
///
/// @return `true` if `fname` is a directory.
bool os_isdir(const char_u *name);

/// Check if the given path represents an executable file.
///
/// @return `true` if `name` is executable and
///   - can be found in $PATH,
///   - is relative to current dir or
///   - is absolute.
///
/// @return `false` otherwise.
bool os_can_exe(const char_u *name);

/// Get the file permissions for a given file.
///
/// @return `-1` when `name` doesn't exist.
int32_t os_getperm(const char_u *name);

/// Set the permission of a file.
///
/// @return `OK` for success, `FAIL` for failure.
int os_setperm(const char_u *name, int perm);

/// Check if a file exists.
///
/// @return `true` if `name` exists.
bool os_file_exists(const char_u *name);

/// Check if a file is readonly.
///
/// @return `true` if `name` is readonly.
bool os_file_is_readonly(const char *name);

/// Check if a file is writable.
///
/// @return `0` if `name` is not writable,
/// @return `1` if `name` is writable,
/// @return `2` for a directory which we have rights to write into.
int os_file_is_writable(const char *name);

/// Rename a file or directory.
///
/// @return `OK` for success, `FAIL` for failure.
int os_rename(const char_u *path, const char_u *new_path);

/// Make a directory.
///
/// @return `0` for success, non-zero for failure.
int os_mkdir(const char *path, int32_t mode);

/// Remove a directory.
///
/// @return `0` for success, non-zero for failure.
int os_rmdir(const char *path);

/// Remove a file.
///
/// @return `0` for success, non-zero for failure.
int os_remove(const char *path);

long_u os_total_mem(int special);
const char *os_getenv(const char *name);
int os_setenv(const char *name, const char *value, int overwrite);
char *os_getenvname_at_index(size_t index);

/// Get the process ID of the Neovim process.
///
/// @return the process ID.
int64_t os_get_pid(void);

/// Get the hostname of the machine runing Neovim.
///
/// @param hostname Buffer to store the hostname.
/// @param len Length of `hostname`.
void os_get_hostname(char *hostname, size_t len);

int os_get_usernames(garray_T *usernames);
int os_get_user_name(char *s, size_t len);
int os_get_uname(uid_t uid, char *s, size_t len);
char *os_get_user_directory(const char *name);

/// Get stat information for a file.
///
/// @return OK on success, FAIL if an failure occured.
int os_stat(const char_u *name, uv_stat_t *statbuf);

#endif  // NEOVIM_OS_OS_H
