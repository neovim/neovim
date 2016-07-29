// fs.c -- filesystem access
#include <stdbool.h>
#include <stddef.h>
#include <assert.h>
#include <limits.h>
#include <fcntl.h>
#include <errno.h>

#include "auto/config.h"

#ifdef HAVE_SYS_UIO_H
# include <sys/uio.h>
#endif

#include <uv.h>

#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/ascii.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/assert.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/path.h"
#include "nvim/strings.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fs.c.generated.h"
#endif

#define RUN_UV_FS_FUNC(ret, func, ...) \
    do { \
      bool did_try_to_free = false; \
uv_call_start: {} \
      uv_fs_t req; \
      ret = func(&fs_loop, &req, __VA_ARGS__); \
      uv_fs_req_cleanup(&req); \
      if (ret == UV_ENOMEM && !did_try_to_free) { \
        try_to_free_memory(); \
        did_try_to_free = true; \
        goto uv_call_start; \
      } \
    } while (0)

// Many fs functions from libuv return that value on success.
static const int kLibuvSuccess = 0;
static uv_loop_t fs_loop;


// Initialize the fs module
void fs_init(void)
{
  uv_loop_init(&fs_loop);
}


/// Change to the given directory.
///
/// @return `0` on success, a libuv error code on failure.
int os_chdir(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  if (p_verbose >= 5) {
    verbose_enter();
    smsg("chdir(%s)", path);
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
  int error_number;
  if ((error_number = uv_cwd((char *)buf, &len)) != kLibuvSuccess) {
    STRLCPY(buf, uv_strerror(error_number), len);
    return FAIL;
  }
  return OK;
}

/// Check if the given path is a directory and not a symlink to a directory.
/// @return `true` if `name` is a directory and NOT a symlink to a directory.
///         `false` if `name` is not a directory or if an error occurred.
bool os_isrealdir(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  if (uv_fs_lstat(&fs_loop, &request, (char *)name, NULL) != kLibuvSuccess) {
    return false;
  }
  if (S_ISLNK(request.statbuf.st_mode)) {
    return false;
  } else {
    return S_ISDIR(request.statbuf.st_mode);
  }
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

/// Check what `name` is:
/// @return NODE_NORMAL: file or directory (or doesn't exist)
///         NODE_WRITABLE: writable device, socket, fifo, etc.
///         NODE_OTHER: non-writable things
int os_nodetype(const char *name)
{
#ifdef WIN32
  // Edge case from Vim os_win32.c:
  // We can't open a file with a name "\\.\con" or "\\.\prn", trying to read
  // from it later will cause Vim to hang. Thus return NODE_WRITABLE here.
  if (STRNCMP(name, "\\\\.\\", 4) == 0) {
    return NODE_WRITABLE;
  }
#endif

  uv_stat_t statbuf;
  if (0 != os_stat(name, &statbuf)) {
    return NODE_NORMAL;  // File doesn't exist.
  }

#ifndef WIN32
  // libuv does not handle BLK and DIR in uv_handle_type.
  //    Related: https://github.com/joyent/libuv/pull/1421
  if (S_ISREG(statbuf.st_mode) || S_ISDIR(statbuf.st_mode)) {
    return NODE_NORMAL;
  }
  if (S_ISBLK(statbuf.st_mode)) {  // block device isn't writable
    return NODE_OTHER;
  }
#endif

  // Vim os_win32.c:mch_nodetype does this (since patch 7.4.015):
  //    if (enc_codepage >= 0 && (int)GetACP() != enc_codepage) {
  //      wn = enc_to_utf16(name, NULL);
  //      hFile = CreatFile(wn, ...)
  // to get a HANDLE. But libuv just calls win32's _get_osfhandle() on the fd we
  // give it. uv_fs_open calls fs__capture_path which does a similar dance and
  // saves us the hassle.

  int nodetype = NODE_WRITABLE;
  int fd = os_open(name, O_RDONLY, 0);
  switch(uv_guess_handle(fd)) {
    case UV_TTY:         // FILE_TYPE_CHAR
      nodetype = NODE_WRITABLE;
      break;
    case UV_FILE:        // FILE_TYPE_DISK
      nodetype = NODE_NORMAL;
      break;
    case UV_NAMED_PIPE:  // not handled explicitly in Vim os_win32.c
    case UV_UDP:         // unix only
    case UV_TCP:         // unix only
    case UV_UNKNOWN_HANDLE:
    default:
#ifdef WIN32
      nodetype = NODE_NORMAL;
#else
      nodetype = NODE_WRITABLE;  // Everything else is writable?
#endif
      break;
  }

  close(fd);
  return nodetype;
}

/// Checks if the given path represents an executable file.
///
/// @param[in]  name     Name of the executable.
/// @param[out] abspath  Path of the executable, if found and not `NULL`.
/// @param[in] use_path  If 'false', only check if "name" is executable
///
/// @return `true` if `name` is executable and
///   - can be found in $PATH,
///   - is relative to current dir or
///   - is absolute.
///
/// @return `false` otherwise.
bool os_can_exe(const char_u *name, char_u **abspath, bool use_path)
  FUNC_ATTR_NONNULL_ARG(1)
{
  // when use_path is false or if it's an absolute or relative path don't
  // need to use $PATH.
  if (!use_path || path_is_absolute_path(name)
      || (name[0] == '.'
          && (name[1] == '/'
              || (name[1] == '.' && name[2] == '/')))) {
    // There must be a path separator, files in the current directory
    // can't be executed
    if (gettail_dir(name) != name && is_executable(name)) {
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

#if WIN32
  // Windows does not have exec bit; just check if the file exists and is not
  // a directory.
  return (S_ISREG(mode));
#else
  return (S_ISREG(mode) && (S_IXUSR & mode));
#endif

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
  const char *path = os_getenv("PATH");
  if (path == NULL) {
    return false;
  }

  size_t buf_len = STRLEN(name) + STRLEN(path) + 2;

#ifdef WIN32
  const char *pathext = os_getenv("PATHEXT");
  if (!pathext) {
    pathext = ".com;.exe;.bat;.cmd";
  }

  buf_len += STRLEN(pathext);
#endif

  char_u *buf = xmalloc(buf_len);

  // Walk through all entries in $PATH to check if "name" exists there and
  // is an executable file.
  for (;; ) {
    const char *e = xstrchrnul(path, ENV_SEPCHAR);

    // Glue together the given directory from $PATH with name and save into
    // buf.
    STRLCPY(buf, path, e - path + 1);
    append_path((char *) buf, (const char *) name, buf_len);

    if (is_executable(buf)) {
      // Check if the caller asked for a copy of the path.
      if (abspath != NULL) {
        *abspath = save_absolute_path(buf);
      }

      xfree(buf);

      return true;
    }

#ifdef WIN32
    // Try appending file extensions from $PATHEXT to the name.
    char *buf_end = xstrchrnul((char *)buf, '\0');
    for (const char *ext = pathext; *ext; ext++) {
      // Skip the extension if there is no suffix after a '.'.
      if (ext[0] == '.' && (ext[1] == '\0' || ext[1] == ';')) {
        *ext++;

        continue;
      }

      const char *ext_end = xstrchrnul(ext, ENV_SEPCHAR);
      STRLCPY(buf_end, ext, ext_end - ext + 1);

      if (is_executable(buf)) {
        // Check if the caller asked for a copy of the path.
        if (abspath != NULL) {
          *abspath = save_absolute_path(buf);
        }

        xfree(buf);

        return true;
      }

      if (*ext_end != ENV_SEPCHAR) {
        break;
      }
      ext = ext_end;
    }
#endif

    if (*e != ENV_SEPCHAR) {
      // End of $PATH without finding any executable called name.
      xfree(buf);
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
/// calls (read, write, lseek, fcntl, etc.). If the operation fails, a libuv
/// error code is returned, and no file is created or modified.
///
/// @param flags Bitwise OR of flags defined in <fcntl.h>
/// @param mode Permissions for the newly-created file (IGNORED if 'flags' is
///        not `O_CREAT` or `O_TMPFILE`), subject to the current umask
/// @return file descriptor, or libuv error code on failure
int os_open(const char* path, int flags, int mode)
  FUNC_ATTR_NONNULL_ALL
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_open, path, flags, mode, NULL);
  return r;
}

/// Close a file
///
/// @return 0 or libuv error code on failure.
int os_close(const int fd)
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_close, fd, NULL);
  return r;
}

/// Read from a file
///
/// Handles EINTR and ENOMEM, but not other errors.
///
/// @param[in]  fd  File descriptor to read from.
/// @param[out]  ret_eof  Is set to true if EOF was encountered, otherwise set
///                       to false. Initial value is ignored.
/// @param[out]  ret_buf  Buffer to write to. May be NULL if size is zero.
/// @param[in]  size  Amount of bytes to read.
///
/// @return Number of bytes read or libuv error code (< 0).
ptrdiff_t os_read(const int fd, bool *ret_eof, char *const ret_buf,
                  const size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  *ret_eof = false;
  if (ret_buf == NULL) {
    assert(size == 0);
    return 0;
  }
  size_t read_bytes = 0;
  bool did_try_to_free = false;
  while (read_bytes != size) {
    const ptrdiff_t cur_read_bytes = read(fd, ret_buf + read_bytes,
                                          size - read_bytes);
    if (cur_read_bytes > 0) {
      read_bytes += (size_t)cur_read_bytes;
      assert(read_bytes <= size);
    }
    if (cur_read_bytes < 0) {
#ifdef HAVE_UV_TRANSLATE_SYS_ERROR
      const int error = uv_translate_sys_error(errno);
#elif WIN32
      const int error = win32_translate_sys_error(errno);
#else
      const int error = -errno;
      STATIC_ASSERT(-EINTR == UV_EINTR, "Need to translate error codes");
      STATIC_ASSERT(-EAGAIN == UV_EAGAIN, "Need to translate error codes");
      STATIC_ASSERT(-ENOMEM == UV_ENOMEM, "Need to translate error codes");
#endif
      errno = 0;
      if (error == UV_EINTR || error == UV_EAGAIN) {
        continue;
      } else if (error == UV_ENOMEM && !did_try_to_free) {
        try_to_free_memory();
        did_try_to_free = true;
        continue;
      } else {
        return (ptrdiff_t)error;
      }
    }
    if (cur_read_bytes == 0) {
      *ret_eof = true;
      break;
    }
  }
  return (ptrdiff_t)read_bytes;
}

#ifdef HAVE_READV
/// Read from a file to multiple buffers at once
///
/// Wrapper for readv().
///
/// @param[in]  fd  File descriptor to read from.
/// @param[out]  ret_eof  Is set to true if EOF was encountered, otherwise set
///                       to false. Initial value is ignored.
/// @param[out]  iov  Description of buffers to write to. Note: this description
///                   may change, it is incorrect to use data it points to after
///                   os_readv().
/// @param[in]  iov_size  Number of buffers in iov.
ptrdiff_t os_readv(int fd, bool *ret_eof, struct iovec *iov, size_t iov_size)
  FUNC_ATTR_NONNULL_ALL
{
  *ret_eof = false;
  size_t read_bytes = 0;
  bool did_try_to_free = false;
  size_t toread = 0;
  for (size_t i = 0; i < iov_size; i++) {
    // Overflow, trying to read too much data
    assert(toread <= SIZE_MAX - iov[i].iov_len);
    toread += iov[i].iov_len;
  }
  while (read_bytes < toread && iov_size && !*ret_eof) {
    ptrdiff_t cur_read_bytes = readv(fd, iov, (int)iov_size);
    if (toread && cur_read_bytes == 0) {
      *ret_eof = true;
    }
    if (cur_read_bytes > 0) {
      read_bytes += (size_t)cur_read_bytes;
      while (iov_size && cur_read_bytes) {
        if (cur_read_bytes < (ptrdiff_t)iov->iov_len) {
          iov->iov_len -= (size_t)cur_read_bytes;
          iov->iov_base = (char *)iov->iov_base + cur_read_bytes;
          cur_read_bytes = 0;
        } else {
          cur_read_bytes -= (ptrdiff_t)iov->iov_len;
          iov_size--;
          iov++;
        }
      }
    } else if (cur_read_bytes < 0) {
#ifdef HAVE_UV_TRANSLATE_SYS_ERROR
      const int error = uv_translate_sys_error(errno);
#elif WIN32
      const int error = win32_translate_sys_error(errno);
#else
      const int error = -errno;
      STATIC_ASSERT(-EINTR == UV_EINTR, "Need to translate error codes");
      STATIC_ASSERT(-EAGAIN == UV_EAGAIN, "Need to translate error codes");
      STATIC_ASSERT(-ENOMEM == UV_ENOMEM, "Need to translate error codes");
#endif
      errno = 0;
      if (error == UV_EINTR || error == UV_EAGAIN) {
        continue;
      } else if (error == UV_ENOMEM && !did_try_to_free) {
        try_to_free_memory();
        did_try_to_free = true;
        continue;
      } else {
        return (ptrdiff_t)error;
      }
    }
  }
  return (ptrdiff_t)read_bytes;
}
#endif  // HAVE_READV

/// Write to a file
///
/// @param[in]  fd  File descriptor to write to.
/// @param[in]  buf  Data to write. May be NULL if size is zero.
/// @param[in]  size  Amount of bytes to write.
///
/// @return Number of bytes written or libuv error code (< 0).
ptrdiff_t os_write(const int fd, const char *const buf, const size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (buf == NULL) {
    assert(size == 0);
    return 0;
  }
  size_t written_bytes = 0;
  while (written_bytes != size) {
    const ptrdiff_t cur_written_bytes = write(fd, buf + written_bytes,
                                              size - written_bytes);
    if (cur_written_bytes > 0) {
      written_bytes += (size_t)cur_written_bytes;
    }
    if (cur_written_bytes < 0) {
#ifdef HAVE_UV_TRANSLATE_SYS_ERROR
      const int error = uv_translate_sys_error(errno);
#elif WIN32
      const int error = win32_translate_sys_error(errno);
#else
      const int error = -errno;
      STATIC_ASSERT(-EINTR == UV_EINTR, "Need to translate error codes");
      STATIC_ASSERT(-EAGAIN == UV_EAGAIN, "Need to translate error codes");
      // According to the man page open() may fail with ENOMEM, but write()
      // can’t.
#endif
      errno = 0;
      if (error == UV_EINTR || error == UV_EAGAIN) {
        continue;
      } else {
        return error;
      }
    }
    if (cur_written_bytes == 0) {
      return UV_UNKNOWN;
    }
  }
  return (ptrdiff_t)written_bytes;
}

/// Flushes file modifications to disk.
///
/// @param fd the file descriptor of the file to flush to disk.
///
/// @return `0` on success, a libuv error code on failure.
int os_fsync(int fd)
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_fsync, fd, NULL);
  return r;
}

/// Get stat information for a file.
///
/// @return libuv return code.
static int os_stat(const char *name, uv_stat_t *statbuf)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_stat(&fs_loop, &request, name, NULL);
  *statbuf = request.statbuf;
  uv_fs_req_cleanup(&request);
  return result;
}

/// Get the file permissions for a given file.
///
/// @return libuv error code on error.
int32_t os_getperm(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  uv_stat_t statbuf;
  int stat_result = os_stat((char *)name, &statbuf);
  if (stat_result == kLibuvSuccess) {
    return (int32_t)statbuf.st_mode;
  } else {
    return stat_result;
  }
}

/// Set the permission of a file.
///
/// @return `OK` for success, `FAIL` for failure.
int os_setperm(const char_u *name, int perm)
  FUNC_ATTR_NONNULL_ALL
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_chmod, (const char *)name, perm, NULL);
  return (r == kLibuvSuccess ? OK : FAIL);
}

/// Changes the ownership of the file referred to by the open file descriptor.
///
/// @return `0` on success, a libuv error code on failure.
///
/// @note If the `owner` or `group` is specified as `-1`, then that ID is not
/// changed.
int os_fchown(int fd, uv_uid_t owner, uv_gid_t group)
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_fchown, fd, owner, group, NULL);
  return r;
}

/// Check if a path exists.
///
/// @return `true` if `path` exists
bool os_path_exists(const char_u *path)
  FUNC_ATTR_NONNULL_ALL
{
  uv_stat_t statbuf;
  return os_stat((char *)path, &statbuf) == kLibuvSuccess;
}

/// Check if a file is readable.
///
/// @return true if `name` is readable, otherwise false.
bool os_file_is_readable(const char *name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_access, name, R_OK, NULL);
  return (r == 0);
}

/// Check if a file is writable.
///
/// @return `0` if `name` is not writable,
/// @return `1` if `name` is writable,
/// @return `2` for a directory which we have rights to write into.
int os_file_is_writable(const char *name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_access, name, W_OK, NULL);
  if (r == 0) {
    return os_isdir((char_u *)name) ? 2 : 1;
  }
  return 0;
}

/// Rename a file or directory.
///
/// @return `OK` for success, `FAIL` for failure.
int os_rename(const char_u *path, const char_u *new_path)
  FUNC_ATTR_NONNULL_ALL
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_rename, (const char *)path, (const char *)new_path,
                 NULL);
  return (r == kLibuvSuccess ? OK : FAIL);
}

/// Make a directory.
///
/// @return `0` for success, libuv error code for failure.
int os_mkdir(const char *path, int32_t mode)
  FUNC_ATTR_NONNULL_ALL
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_mkdir, path, mode, NULL);
  return r;
}

/// Make a directory, with higher levels when needed
///
/// @param[in]  dir  Directory to create.
/// @param[in]  mode  Permissions for the newly-created directory.
/// @param[out]  failed_dir  If it failed to create directory, then this
///                          argument is set to an allocated string containing
///                          the name of the directory which os_mkdir_recurse
///                          failed to create. I.e. it will contain dir or any
///                          of the higher level directories.
///
/// @return `0` for success, libuv error code for failure.
int os_mkdir_recurse(const char *const dir, int32_t mode,
                     char **const failed_dir)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Get end of directory name in "dir".
  // We're done when it's "/" or "c:/".
  const size_t dirlen = strlen(dir);
  char *const curdir = xmemdupz(dir, dirlen);
  char *const past_head = (char *) get_past_head((char_u *) curdir);
  char *e = curdir + dirlen;
  const char *const real_end = e;
  const char past_head_save = *past_head;
  while (!os_isdir((char_u *) curdir)) {
    e = (char *) path_tail_with_sep((char_u *) curdir);
    if (e <= past_head) {
      *past_head = NUL;
      break;
    }
    *e = NUL;
  }
  while (e != real_end) {
    if (e > past_head) {
      *e = PATHSEP;
    } else {
      *past_head = past_head_save;
    }
    const size_t component_len = strlen(e);
    e += component_len;
    if (e == real_end
        && memcnt(e - component_len, PATHSEP, component_len) == component_len) {
      // Path ends with something like "////". Ignore this.
      break;
    }
    int ret;
    if ((ret = os_mkdir(curdir, mode)) != 0) {
      *failed_dir = curdir;
      return ret;
    }
  }
  xfree(curdir);
  return 0;
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
  int result = uv_fs_mkdtemp(&fs_loop, &request, template, NULL);
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
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_rmdir, path, NULL);
  return r;
}

/// Opens a directory.
/// @param[out] dir   The Directory object.
/// @param      path  Path to the directory.
/// @returns true if dir contains one or more items, false if not or an error
///          occurred.
bool os_scandir(Directory *dir, const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  int r = uv_fs_scandir(&fs_loop, &dir->request, path, 0, NULL);
  if (r < 0) {
    os_closedir(dir);
  }
  return r >= 0;
}

/// Increments the directory pointer.
/// @param dir  The Directory object.
/// @returns a pointer to the next path in `dir` or `NULL`.
const char *os_scandir_next(Directory *dir)
  FUNC_ATTR_NONNULL_ALL
{
  int err = uv_fs_scandir_next(&dir->request, &dir->ent);
  return err != UV_EOF ? dir->ent.name : NULL;
}

/// Frees memory associated with `os_scandir()`.
/// @param dir  The directory.
void os_closedir(Directory *dir)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_req_cleanup(&dir->request);
}

/// Remove a file.
///
/// @return `0` for success, non-zero for failure.
int os_remove(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_unlink, path, NULL);
  return r;
}

/// Get the file information for a given path
///
/// @param path Path to the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_fileinfo(const char *path, FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return os_stat(path, &(file_info->stat)) == kLibuvSuccess;
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
  int result = uv_fs_lstat(&fs_loop, &request, path, NULL);
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
  int result = uv_fs_fstat(&fs_loop, &request, file_descriptor, NULL);
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
  if (os_stat(path, &statbuf) == kLibuvSuccess) {
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

