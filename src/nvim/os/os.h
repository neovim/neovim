#ifndef NVIM_OS_OS_H
#define NVIM_OS_OS_H
#include <uv.h>

#include "nvim/vim.h"

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

/// Get the size of a file in bytes.
///
/// @param[out] size pointer to an off_t to put the size into.
/// @return `true` for success, `false` for failure.
bool os_get_file_size(const char *name, off_t *size);

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

/// Get the total system physical memory in KiB.
uint64_t os_get_total_mem_kib(void);
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

/// Struct which encapsulates stat information.
typedef struct {
  // TODO(stefan991): make stat private
  uv_stat_t stat;
} FileInfo;

/// Get the file information for a given path
///
/// @param file_descriptor File descriptor of the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on sucess, `false` for failure.
bool os_get_file_info(const char *path, FileInfo *file_info);

/// Get the file information for a given path without following links
///
/// @param path Path to the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on sucess, `false` for failure.
bool os_get_file_info_link(const char *path, FileInfo *file_info);

/// Get the file information for a given file descriptor
///
/// @param file_descriptor File descriptor of the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on sucess, `false` for failure.
bool os_get_file_info_fd(int file_descriptor, FileInfo *file_info);

/// Compare the inodes of two FileInfos
///
/// @return `true` if the two FileInfos represent the same file.
bool os_file_info_id_equal(FileInfo *file_info_1, FileInfo *file_info_2);

#endif  // NVIM_OS_OS_H
