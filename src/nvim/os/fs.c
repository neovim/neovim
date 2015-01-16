// fs.c -- filesystem access
#include <stdbool.h>

#include <assert.h>

#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/path.h"
#include "nvim/strings.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fs.c.generated.h"
#endif

// Many fs functions from libuv return that value on success.
static const int kLibuvSuccess = 0;

/// Change to the given directory.
///
/// @return `0` on success, a libuv error code on failure.
int os_chdir(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  if (p_verbose >= 5) {
    verbose_enter();
    smsg((char_u *)"chdir(%s)", path);
    verbose_leave();
  }
  return uv_chdir(path);
}

/// Get the name of current directory.
///
/// @param buf Buffer to store the directory name.
/// @param len Length of `buf`.
/// @return `OK` for success, `FAIL` for failure.
int os_dirname(char_u *buf, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  assert(buf && len);

  int error_number;
  if ((error_number = uv_cwd((char *)buf, &len)) != kLibuvSuccess) {
    STRLCPY(buf, uv_strerror(error_number), len);
    return FAIL;
  }
  return OK;
}

/// Check if the given path is a directory or not.
///
/// @return `true` if `fname` is a directory.
bool os_isdir(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  int32_t mode = os_getperm(name);
  if (mode < 0) {
    return false;
  }

  if (!S_ISDIR(mode)) {
    return false;
  }

  return true;
}

/// Checks if the given path represents an executable file.
///
/// @param[in]  name     The name of the executable.
/// @param[out] abspath  Path of the executable, if found and not `NULL`.
///
/// @return `true` if `name` is executable and
///   - can be found in $PATH,
///   - is relative to current dir or
///   - is absolute.
///
/// @return `false` otherwise.
bool os_can_exe(const char_u *name, char_u **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  // If it's an absolute or relative path don't need to use $PATH.
  if (path_is_absolute_path(name) ||
     (name[0] == '.' && (name[1] == '/' ||
                        (name[1] == '.' && name[2] == '/')))) {
    if (is_executable(name)) {
      if (abspath != NULL) {
        *abspath = save_absolute_path(name);
      }

      return true;
    }

    return false;
  }

  return is_executable_in_path(name, abspath);
}

// Return true if "name" is an executable file, false if not or it doesn't
// exist.
static bool is_executable(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  int32_t mode = os_getperm(name);

  if (mode < 0) {
    return false;
  }

  if (S_ISREG(mode) && (S_IXUSR & mode)) {
    return true;
  }

  return false;
}

/// Checks if a file is inside the `$PATH` and is executable.
///
/// @param[in]  name The name of the executable.
/// @param[out] abspath  Path of the executable, if found and not `NULL`.
///
/// @return `true` if `name` is an executable inside `$PATH`.
static bool is_executable_in_path(const char_u *name, char_u **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const char *path = getenv("PATH");
  // PATH environment variable does not exist or is empty.
  if (path == NULL || *path == NUL) {
    return false;
  }

  size_t buf_len = STRLEN(name) + STRLEN(path) + 2;
  char_u *buf = xmalloc(buf_len);

  // Walk through all entries in $PATH to check if "name" exists there and
  // is an executable file.
  for (;; ) {
    const char *e = xstrchrnul(path, ':');

    // Glue together the given directory from $PATH with name and save into
    // buf.
    STRLCPY(buf, path, e - path + 1);
    append_path((char *) buf, (const char *) name, (int)buf_len);

    if (is_executable(buf)) {
      // Check if the caller asked for a copy of the path.
      if (abspath != NULL) {
        *abspath = save_absolute_path(buf);
      }

      free(buf);

      return true;
    }

    if (*e != ':') {
      // End of $PATH without finding any executable called name.
      free(buf);
      return false;
    }

    path = e + 1;
  }

  // We should never get to this point.
  assert(false);
  return false;
}

/// Opens or creates a file and returns a non-negative integer representing
/// the lowest-numbered unused file descriptor, for use in subsequent system
/// calls (read, write, lseek, fcntl, etc.). If the operation fails, `-errno`
/// is returned, and no file is created or modified.
///
/// @param flags Bitwise OR of flags defined in <fcntl.h>
/// @param mode Permissions for the newly-created file (IGNORED if 'flags' is
///        not `O_CREAT` or `O_TMPFILE`), subject to the current umask
/// @return file descriptor, or negative `errno` on failure
int os_open(const char* path, int flags, int mode)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t open_req;
  int r = uv_fs_open(uv_default_loop(), &open_req, path, flags, mode, NULL);
  uv_fs_req_cleanup(&open_req);
  // r is the same as open_req.result (except for OOM: then only r is set).
  return r;
}

/// Get stat information for a file.
///
/// @return OK on success, FAIL if a failure occurred.
static bool os_stat(const char *name, uv_stat_t *statbuf)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_stat(uv_default_loop(), &request, name, NULL);
  *statbuf = request.statbuf;
  uv_fs_req_cleanup(&request);
  return (result == kLibuvSuccess);
}

/// Get the file permissions for a given file.
///
/// @return `-1` when `name` doesn't exist.
int32_t os_getperm(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  uv_stat_t statbuf;
  if (os_stat((char *)name, &statbuf)) {
    return (int32_t)statbuf.st_mode;
  } else {
    return -1;
  }
}

/// Set the permission of a file.
///
/// @return `OK` for success, `FAIL` for failure.
int os_setperm(const char_u *name, int perm)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_chmod(uv_default_loop(), &request,
                           (const char*)name, perm, NULL);
  uv_fs_req_cleanup(&request);

  if (result == kLibuvSuccess) {
    return OK;
  }

  return FAIL;
}

/// Changes the ownership of the file referred to by the open file descriptor.
///
/// @return `0` on success, a libuv error code on failure.
///
/// @note If the `owner` or `group` is specified as `-1`, then that ID is not
/// changed.
int os_fchown(int file_descriptor, uv_uid_t owner, uv_gid_t group)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_fchown(uv_default_loop(), &request, file_descriptor,
                            owner, group, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

/// Check if a file exists.
///
/// @return `true` if `name` exists.
bool os_file_exists(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  uv_stat_t statbuf;
  return os_stat((char *)name, &statbuf);
}

/// Check if a file is readonly.
///
/// @return `true` if `name` is readonly.
bool os_file_is_readonly(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  return access(name, W_OK) != 0;
}

/// Check if a file is writable.
///
/// @return `0` if `name` is not writable,
/// @return `1` if `name` is writable,
/// @return `2` for a directory which we have rights to write into.
int os_file_is_writable(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  if (access(name, W_OK) == 0) {
    if (os_isdir((char_u *)name)) {
      return 2;
    }
    return 1;
  }
  return 0;
}

/// Rename a file or directory.
///
/// @return `OK` for success, `FAIL` for failure.
int os_rename(const char_u *path, const char_u *new_path)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_rename(uv_default_loop(), &request,
                            (const char *)path, (const char *)new_path, NULL);
  uv_fs_req_cleanup(&request);

  if (result == kLibuvSuccess) {
    return OK;
  }

  return FAIL;
}

/// Make a directory.
///
/// @return `0` for success, non-zero for failure.
int os_mkdir(const char *path, int32_t mode)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_mkdir(uv_default_loop(), &request, path, mode, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

/// Create a unique temporary directory.
///
/// @param[in] template Template of the path to the directory with XXXXXX
///                     which would be replaced by random chars.
/// @param[out] path Path to created directory for success, undefined for
///                  failure.
/// @return `0` for success, non-zero for failure.
int os_mkdtemp(const char *template, char *path)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_mkdtemp(uv_default_loop(), &request, template, NULL);
  if (result == kLibuvSuccess) {
    STRNCPY(path, request.path, TEMP_FILE_PATH_MAXLEN);
  }
  uv_fs_req_cleanup(&request);
  return result;
}

/// Remove a directory.
///
/// @return `0` for success, non-zero for failure.
int os_rmdir(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_rmdir(uv_default_loop(), &request, path, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

/// Remove a file.
///
/// @return `0` for success, non-zero for failure.
int os_remove(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_unlink(uv_default_loop(), &request, path, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

/// Get the file information for a given path
///
/// @param path Path to the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_fileinfo(const char *path, FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return os_stat(path, &(file_info->stat));
}

/// Get the file information for a given path without following links
///
/// @param path Path to the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_fileinfo_link(const char *path, FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_lstat(uv_default_loop(), &request, path, NULL);
  file_info->stat = request.statbuf;
  uv_fs_req_cleanup(&request);
  return (result == kLibuvSuccess);
}

/// Get the file information for a given file descriptor
///
/// @param file_descriptor File descriptor of the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_fileinfo_fd(int file_descriptor, FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_fstat(uv_default_loop(), &request, file_descriptor, NULL);
  file_info->stat = request.statbuf;
  uv_fs_req_cleanup(&request);
  return (result == kLibuvSuccess);
}

/// Compare the inodes of two FileInfos
///
/// @return `true` if the two FileInfos represent the same file.
bool os_fileinfo_id_equal(const FileInfo *file_info_1,
                           const FileInfo *file_info_2)
  FUNC_ATTR_NONNULL_ALL
{
  return file_info_1->stat.st_ino == file_info_2->stat.st_ino
         && file_info_1->stat.st_dev == file_info_2->stat.st_dev;
}

/// Get the `FileID` of a `FileInfo`
///
/// @param file_info Pointer to the `FileInfo`
/// @param[out] file_id Pointer to a `FileID`
void os_fileinfo_id(const FileInfo *file_info, FileID *file_id)
  FUNC_ATTR_NONNULL_ALL
{
  file_id->inode = file_info->stat.st_ino;
  file_id->device_id = file_info->stat.st_dev;
}

/// Get the inode of a `FileInfo`
///
/// @deprecated Use `FileID` instead, this function is only needed in memline.c
/// @param file_info Pointer to the `FileInfo`
/// @return the inode number
uint64_t os_fileinfo_inode(const FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return file_info->stat.st_ino;
}

/// Get the size of a file from a `FileInfo`.
///
/// @return filesize in bytes.
uint64_t os_fileinfo_size(const FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return file_info->stat.st_size;
}

/// Get the number of hardlinks from a `FileInfo`.
///
/// @return number of hardlinks.
uint64_t os_fileinfo_hardlinks(const FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return file_info->stat.st_nlink;
}

/// Get the blocksize from a `FileInfo`.
///
/// @return blocksize in bytes.
uint64_t os_fileinfo_blocksize(const FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return file_info->stat.st_blksize;
}

/// Get the `FileID` for a given path
///
/// @param path Path to the file.
/// @param[out] file_info Pointer to a `FileID` to fill in.
/// @return `true` on sucess, `false` for failure.
bool os_fileid(const char *path, FileID *file_id)
  FUNC_ATTR_NONNULL_ALL
{
  uv_stat_t statbuf;
  if (os_stat(path, &statbuf)) {
    file_id->inode = statbuf.st_ino;
    file_id->device_id = statbuf.st_dev;
    return true;
  }
  return false;
}

/// Check if two `FileID`s are equal
///
/// @param file_id_1 Pointer to first `FileID`
/// @param file_id_2 Pointer to second `FileID`
/// @return `true` if the two `FileID`s represent te same file.
bool os_fileid_equal(const FileID *file_id_1, const FileID *file_id_2)
  FUNC_ATTR_NONNULL_ALL
{
  return file_id_1->inode == file_id_2->inode
         && file_id_1->device_id == file_id_2->device_id;
}

/// Check if a `FileID` is equal to a `FileInfo`
///
/// @param file_id Pointer to a `FileID`
/// @param file_info Pointer to a `FileInfo`
/// @return `true` if the `FileID` and the `FileInfo` represent te same file.
bool os_fileid_equal_fileinfo(const FileID *file_id,
                                const FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return file_id->inode == file_info->stat.st_ino
         && file_id->device_id == file_info->stat.st_dev;
}

