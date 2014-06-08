// fs.c -- filesystem access

#include "nvim/os/os.h"
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
{
  assert(buf && len);

  int errno;
  if ((errno = uv_cwd((char *)buf, &len)) != kLibuvSuccess) {
    vim_strncpy(buf, (char_u *)uv_strerror(errno), len - 1);
    return FAIL;
  }
  return OK;
}

/// Check if the given path is a directory or not.
///
/// @return `true` if `fname` is a directory.
bool os_isdir(const char_u *name)
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

/// Check if the given path represents an executable file.
///
/// @return `true` if `name` is executable and
///   - can be found in $PATH,
///   - is relative to current dir or
///   - is absolute.
///
/// @return `false` otherwise.
bool os_can_exe(const char_u *name)
{
  // If it's an absolute or relative path don't need to use $PATH.
  if (path_is_absolute_path(name) ||
     (name[0] == '.' && (name[1] == '/' ||
                        (name[1] == '.' && name[2] == '/')))) {
    return is_executable(name);
  }

  return is_executable_in_path(name);
}

// Return true if "name" is an executable file, false if not or it doesn't
// exist.
static bool is_executable(const char_u *name)
{
  int32_t mode = os_getperm(name);

  if (mode < 0) {
    return false;
  }

  if (S_ISREG(mode) && (S_IEXEC & mode)) {
    return true;
  }

  return false;
}

/// Check if a file is inside the $PATH and is executable.
///
/// @return `true` if `name` is an executable inside $PATH.
static bool is_executable_in_path(const char_u *name)
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
    const char *e = strchr(path, ':');
    if (e == NULL) {
      e = path + STRLEN(path);
    }

    // Glue together the given directory from $PATH with name and save into
    // buf.
    vim_strncpy(buf, (char_u *) path, e - path);
    append_path((char *) buf, (const char *) name, (int)buf_len);

    if (is_executable(buf)) {
      // Found our executable. Free buf and return.
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

/// Get stat information for a file.
///
/// @return OK on success, FAIL if a failure occurred.
int os_stat(const char_u *name, uv_stat_t *statbuf)
{
  uv_fs_t request;
  int result = uv_fs_stat(uv_default_loop(), &request,
                          (const char *)name, NULL);
  *statbuf = request.statbuf;
  uv_fs_req_cleanup(&request);

  if (result == kLibuvSuccess) {
    return OK;
  }

  return FAIL;
}

/// Get the file permissions for a given file.
///
/// @return `-1` when `name` doesn't exist.
int32_t os_getperm(const char_u *name)
{
  uv_stat_t statbuf;
  if (os_stat(name, &statbuf) == FAIL) {
    return -1;
  } else {
    return (int32_t)statbuf.st_mode;
  }
}

/// Set the permission of a file.
///
/// @return `OK` for success, `FAIL` for failure.
int os_setperm(const char_u *name, int perm)
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

/// Check if a file exists.
///
/// @return `true` if `name` exists.
bool os_file_exists(const char_u *name)
{
  uv_stat_t statbuf;
  if (os_stat(name, &statbuf) == OK) {
    return true;
  }

  return false;
}

/// Check if a file is readonly.
///
/// @return `true` if `name` is readonly.
bool os_file_is_readonly(const char *name)
{
  return access(name, W_OK) != 0;
}

/// Check if a file is writable.
///
/// @return `0` if `name` is not writable,
/// @return `1` if `name` is writable,
/// @return `2` for a directory which we have rights to write into.
int os_file_is_writable(const char *name)
{
  if (access(name, W_OK) == 0) {
    if (os_isdir((char_u *)name)) {
      return 2;
    }
    return 1;
  }
  return 0;
}

/// Get the size of a file in bytes.
///
/// @param[out] size pointer to an off_t to put the size into.
/// @return `true` for success, `false` for failure.
bool os_get_file_size(const char *name, off_t *size)
{
  uv_stat_t statbuf;
  if (os_stat((char_u *)name, &statbuf) == OK) {
    *size = statbuf.st_size;
    return true;
  }
  return false;
}

/// Rename a file or directory.
///
/// @return `OK` for success, `FAIL` for failure.
int os_rename(const char_u *path, const char_u *new_path)
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
{
  uv_fs_t request;
  int result = uv_fs_mkdir(uv_default_loop(), &request, path, mode, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

/// Remove a directory.
///
/// @return `0` for success, non-zero for failure.
int os_rmdir(const char *path)
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
{
  uv_fs_t request;
  int result = uv_fs_unlink(uv_default_loop(), &request, path, NULL);
  uv_fs_req_cleanup(&request);
  return result;
}

/// Get the file information for a given path
///
/// @param file_descriptor File descriptor of the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_get_file_info(const char *path, FileInfo *file_info)
{
  if (os_stat((char_u *)path, &(file_info->stat)) == OK) {
    return true;
  }
  return false;
}

/// Get the file information for a given path without following links
///
/// @param path Path to the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_get_file_info_link(const char *path, FileInfo *file_info)
{
  uv_fs_t request;
  int result = uv_fs_lstat(uv_default_loop(), &request, path, NULL);
  file_info->stat = request.statbuf;
  uv_fs_req_cleanup(&request);
  if (result == kLibuvSuccess) {
    return true;
  }
  return false;
}

/// Get the file information for a given file descriptor
///
/// @param file_descriptor File descriptor of the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_get_file_info_fd(int file_descriptor, FileInfo *file_info)
{
  uv_fs_t request;
  int result = uv_fs_fstat(uv_default_loop(), &request, file_descriptor, NULL);
  file_info->stat = request.statbuf;
  uv_fs_req_cleanup(&request);
  if (result == kLibuvSuccess) {
    return true;
  }
  return false;
}

/// Compare the inodes of two FileInfos
///
/// @return `true` if the two FileInfos represent the same file.
bool os_file_info_id_equal(FileInfo *file_info_1, FileInfo *file_info_2)
{
  return file_info_1->stat.st_ino == file_info_2->stat.st_ino
         && file_info_1->stat.st_dev == file_info_2->stat.st_dev;
}
