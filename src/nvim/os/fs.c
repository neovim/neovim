// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
#include "nvim/path.h"
#include "nvim/strings.h"

#ifdef WIN32
#include "nvim/mbyte.h"  // for utf8_to_utf16, utf16_to_utf8
#endif

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


/// Changes the current directory to `path`.
///
/// @return 0 on success, or negative error code.
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
bool os_isrealdir(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  if (uv_fs_lstat(&fs_loop, &request, name, NULL) != kLibuvSuccess) {
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
/// @return `true` if `name` is a directory.
bool os_isdir(const char_u *name)
  FUNC_ATTR_NONNULL_ALL
{
  int32_t mode = os_getperm((const char *)name);
  if (mode < 0) {
    return false;
  }

  if (!S_ISDIR(mode)) {
    return false;
  }

  return true;
}

/// Check if the given path is a directory and is executable.
/// Gives the same results as `os_isdir()` on Windows.
///
/// @return `true` if `name` is a directory and executable.
bool os_isdir_executable(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  int32_t mode = os_getperm((const char *)name);
  if (mode < 0) {
    return false;
  }

#ifdef WIN32
  return (S_ISDIR(mode));
#else
  return (S_ISDIR(mode) && (S_IXUSR & mode));
#endif
}

/// Check what `name` is:
/// @return NODE_NORMAL: file or directory (or doesn't exist)
///         NODE_WRITABLE: writable device, socket, fifo, etc.
///         NODE_OTHER: non-writable things
int os_nodetype(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
#ifndef WIN32  // Unix
  uv_stat_t statbuf;
  if (0 != os_stat(name, &statbuf)) {
    return NODE_NORMAL;  // File doesn't exist.
  }
  // uv_handle_type does not distinguish BLK and DIR.
  //    Related: https://github.com/joyent/libuv/pull/1421
  if (S_ISREG(statbuf.st_mode) || S_ISDIR(statbuf.st_mode)) {
    return NODE_NORMAL;
  }
  if (S_ISBLK(statbuf.st_mode)) {  // block device isn't writable
    return NODE_OTHER;
  }
  // Everything else is writable?
  // buf_write() expects NODE_WRITABLE for char device /dev/stderr.
  return NODE_WRITABLE;
#else  // Windows
  // Edge case from Vim os_win32.c:
  // We can't open a file with a name "\\.\con" or "\\.\prn", trying to read
  // from it later will cause Vim to hang. Thus return NODE_WRITABLE here.
  if (STRNCMP(name, "\\\\.\\", 4) == 0) {
    return NODE_WRITABLE;
  }

  // Vim os_win32.c:mch_nodetype does (since 7.4.015):
  //    wn = enc_to_utf16(name, NULL);
  //    hFile = CreatFile(wn, ...)
  // to get a HANDLE. Whereas libuv just calls _get_osfhandle() on the fd we
  // give it. But uv_fs_open later calls fs__capture_path which does a similar
  // utf8-to-utf16 dance and saves us the hassle.

  // macOS: os_open(/dev/stderr) would return UV_EACCES.
  int fd = os_open(name, O_RDONLY
# ifdef O_NONBLOCK
                   | O_NONBLOCK
# endif
                   , 0);
  if (fd < 0) {  // open() failed.
    return NODE_NORMAL;
  }
  int guess = uv_guess_handle(fd);
  if (close(fd) == -1) {
    ELOG("close(%d) failed. name='%s'", fd, name);
  }

  switch (guess) {
    case UV_TTY:          // FILE_TYPE_CHAR
      return NODE_WRITABLE;
    case UV_FILE:         // FILE_TYPE_DISK
      return NODE_NORMAL;
    case UV_NAMED_PIPE:   // not handled explicitly in Vim os_win32.c
    case UV_UDP:          // unix only
    case UV_TCP:          // unix only
    case UV_UNKNOWN_HANDLE:
    default:
      return NODE_OTHER;  // Vim os_win32.c default
  }
#endif
}

/// Gets the absolute path of the currently running executable.
/// May fail if procfs is missing. #6734
/// @see path_exepath
///
/// @param[out] buffer Full path to the executable.
/// @param[in]  size   Size of `buffer`.
///
/// @return 0 on success, or libuv error code.
int os_exepath(char *buffer, size_t *size)
  FUNC_ATTR_NONNULL_ALL
{
  return uv_exepath(buffer, size);
}

/// Checks if the file `name` is executable.
///
/// @param[in]  name     Filename to check.
/// @param[out] abspath  Returns resolved executable path, if not NULL.
/// @param[in] use_path  Also search $PATH.
///
/// @return true if `name` is executable and
///   - can be found in $PATH,
///   - is relative to current dir or
///   - is absolute.
///
/// @return `false` otherwise.
bool os_can_exe(const char_u *name, char_u **abspath, bool use_path)
  FUNC_ATTR_NONNULL_ARG(1)
{
  bool no_path = !use_path || path_is_absolute(name);
  // If the filename is "qualified" (relative or absolute) do not check $PATH.
#ifdef WIN32
  no_path |= (name[0] == '.'
              && ((name[1] == '/' || name[1] == '\\')
                  || (name[1] == '.' && (name[2] == '/' || name[2] == '\\'))));
#else
  no_path |= (name[0] == '.'
              && (name[1] == '/' || (name[1] == '.' && name[2] == '/')));
#endif

  if (no_path) {
#ifdef WIN32
    if (is_executable_ext((char *)name, abspath)) {
#else
    // Must have path separator, cannot execute files in the current directory.
    if ((const char_u *)gettail_dir((const char *)name) != name
        && is_executable((char *)name, abspath)) {
#endif
      return true;
    } else {
      return false;
    }
  }

  return is_executable_in_path(name, abspath);
}

/// Returns true if `name` is an executable file.
static bool is_executable(const char *name, char_u **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int32_t mode = os_getperm((const char *)name);

  if (mode < 0) {
    return false;
  }

#ifdef WIN32
  // Windows does not have exec bit; just check if the file exists and is not
  // a directory.
  const bool ok = S_ISREG(mode);
#else
  int r = -1;
  if (S_ISREG(mode)) {
    RUN_UV_FS_FUNC(r, uv_fs_access, name, X_OK, NULL);
  }
  const bool ok = (r == 0);
#endif
  if (ok && abspath != NULL) {
    *abspath = save_abs_path((char_u *)name);
  }
  return ok;
}

#ifdef WIN32
/// Checks if file `name` is executable under any of these conditions:
/// - extension is in $PATHEXT and `name` is executable
/// - result of any $PATHEXT extension appended to `name` is executable
static bool is_executable_ext(char *name, char_u **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const bool is_unix_shell = strstr((char *)path_tail(p_sh), "sh") != NULL;
  char *nameext = strrchr(name, '.');
  size_t nameext_len = nameext ? strlen(nameext) : 0;
  xstrlcpy(os_buf, name, sizeof(os_buf));
  char *buf_end = xstrchrnul(os_buf, '\0');
  const char *pathext = os_getenv("PATHEXT");
  if (!pathext) {
    pathext = ".com;.exe;.bat;.cmd";
  }
  for (const char *ext = pathext; *ext; ext++) {
    // If $PATHEXT itself contains dot:
    if (ext[0] == '.' && (ext[1] == '\0' || ext[1] == ENV_SEPCHAR)) {
      if (is_executable(name, abspath)) {
        return true;
      }
      // Skip it.
      ext++;
      continue;
    }

    const char *ext_end = xstrchrnul(ext, ENV_SEPCHAR);
    size_t ext_len = (size_t)(ext_end - ext);
    if (ext_len != 0) {
      STRLCPY(buf_end, ext, ext_len + 1);
      bool in_pathext = nameext_len == ext_len
        && 0 == mb_strnicmp((char_u *)nameext, (char_u *)ext, ext_len);

      if (((in_pathext || is_unix_shell) && is_executable(name, abspath))
          || is_executable(os_buf, abspath)) {
        return true;
      }
    }
    ext = ext_end;
  }
  return false;
}
#endif

/// Checks if a file is in `$PATH` and is executable.
///
/// @param[in]  name  Filename to check.
/// @param[out] abspath  Returns resolved executable path, if not NULL.
///
/// @return `true` if `name` is an executable inside `$PATH`.
static bool is_executable_in_path(const char_u *name, char_u **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const char *path_env = os_getenv("PATH");
  if (path_env == NULL) {
    return false;
  }

#ifdef WIN32
  // Prepend ".;" to $PATH.
  size_t pathlen = strlen(path_env);
  char *path = memcpy(xmallocz(pathlen + 3), "." ENV_SEPSTR, 2);
  memcpy(path + 2, path_env, pathlen);
#else
  char *path = xstrdup(path_env);
#endif

  size_t buf_len = STRLEN(name) + strlen(path) + 2;
  char *buf = xmalloc(buf_len);

  // Walk through all entries in $PATH to check if "name" exists there and
  // is an executable file.
  char *p = path;
  bool rv = false;
  for (;; ) {
    char *e = xstrchrnul(p, ENV_SEPCHAR);

    // Combine the $PATH segment with `name`.
    STRLCPY(buf, p, e - p + 1);
    append_path(buf, (char *)name, buf_len);

#ifdef WIN32
    if (is_executable_ext(buf, abspath)) {
#else
    if (is_executable(buf, abspath)) {
#endif
      rv = true;
      goto end;
    }

    if (*e != ENV_SEPCHAR) {
      // End of $PATH without finding any executable called name.
      goto end;
    }

    p = e + 1;
  }

end:
  xfree(buf);
  xfree(path);
  return rv;
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
int os_open(const char *path, int flags, int mode)
{
  if (path == NULL) {  // uv_fs_open asserts on NULL. #7561
    return UV_EINVAL;
  }
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_open, path, flags, mode, NULL);
  return r;
}

/// Sets file descriptor `fd` to close-on-exec.
//
// @return -1 if failed to set, 0 otherwise.
int os_set_cloexec(const int fd)
{
#ifdef HAVE_FD_CLOEXEC
  int e;
  int fdflags = fcntl(fd, F_GETFD);
  if (fdflags < 0) {
    e = errno;
    ELOG("Failed to get flags on descriptor %d: %s", fd, strerror(e));
    errno = e;
    return -1;
  }
  if ((fdflags & FD_CLOEXEC) == 0
      && fcntl(fd, F_SETFD, fdflags | FD_CLOEXEC) == -1) {
    e = errno;
    ELOG("Failed to set CLOEXEC on descriptor %d: %s", fd, strerror(e));
    errno = e;
    return -1;
  }
  return 0;
#endif

  // No FD_CLOEXEC flag. On Windows, the file should have been opened with
  // O_NOINHERIT anyway.
  return -1;
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

/// Duplicate file descriptor
///
/// @param[in]  fd  File descriptor to duplicate.
///
/// @return New file descriptor or libuv error code (< 0).
int os_dup(const int fd)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  int ret;
os_dup_dup:
  ret = dup(fd);
  if (ret < 0) {
    const int error = os_translate_sys_error(errno);
    errno = 0;
    if (error == UV_EINTR) {
      goto os_dup_dup;
    } else {
      return error;
    }
  }
  return ret;
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
/// @param[in]  non_blocking  Do not restart syscall if EAGAIN was encountered.
///
/// @return Number of bytes read or libuv error code (< 0).
ptrdiff_t os_read(const int fd, bool *const ret_eof, char *const ret_buf,
                  const size_t size, const bool non_blocking)
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
    assert(size >= read_bytes);
    const ptrdiff_t cur_read_bytes = read(fd, ret_buf + read_bytes,
                                          IO_COUNT(size - read_bytes));
    if (cur_read_bytes > 0) {
      read_bytes += (size_t)cur_read_bytes;
    }
    if (cur_read_bytes < 0) {
      const int error = os_translate_sys_error(errno);
      errno = 0;
      if (non_blocking && error == UV_EAGAIN) {
        break;
      } else if (error == UV_EINTR || error == UV_EAGAIN) {
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
/// @param[in]  non_blocking  Do not restart syscall if EAGAIN was encountered.
///
/// @return Number of bytes read or libuv error code (< 0).
ptrdiff_t os_readv(const int fd, bool *const ret_eof, struct iovec *iov,
                   size_t iov_size, const bool non_blocking)
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
    if (cur_read_bytes == 0) {
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
      const int error = os_translate_sys_error(errno);
      errno = 0;
      if (non_blocking && error == UV_EAGAIN) {
        break;
      } else if (error == UV_EINTR || error == UV_EAGAIN) {
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
/// @param[in]  non_blocking  Do not restart syscall if EAGAIN was encountered.
///
/// @return Number of bytes written or libuv error code (< 0).
ptrdiff_t os_write(const int fd, const char *const buf, const size_t size,
                   const bool non_blocking)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (buf == NULL) {
    assert(size == 0);
    return 0;
  }
  size_t written_bytes = 0;
  while (written_bytes != size) {
    assert(size >= written_bytes);
    const ptrdiff_t cur_written_bytes = write(fd, buf + written_bytes,
                                              IO_COUNT(size - written_bytes));
    if (cur_written_bytes > 0) {
      written_bytes += (size_t)cur_written_bytes;
    }
    if (cur_written_bytes < 0) {
      const int error = os_translate_sys_error(errno);
      errno = 0;
      if (non_blocking && error == UV_EAGAIN) {
        break;
      } else if (error == UV_EINTR || error == UV_EAGAIN) {
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

/// Copies a file from `path` to `new_path`.
///
/// @see http://docs.libuv.org/en/v1.x/fs.html#c.uv_fs_copyfile
///
/// @param path Path of file to be copied
/// @param path_new Path of new file
/// @param flags Bitwise OR of flags defined in <uv.h>
/// @return 0 on success, or libuv error code on failure.
int os_copy(const char *path, const char *new_path, int flags)
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_copyfile, path, new_path, flags, NULL);
  return r;
}

/// Flushes file modifications to disk.
///
/// @param fd the file descriptor of the file to flush to disk.
///
/// @return 0 on success, or libuv error code on failure.
int os_fsync(int fd)
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_fsync, fd, NULL);
  g_stats.fsync++;
  return r;
}

/// Get stat information for a file.
///
/// @return libuv return code, or -errno
static int os_stat(const char *name, uv_stat_t *statbuf)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (!name) {
    return UV_EINVAL;
  }
  uv_fs_t request;
  int result = uv_fs_stat(&fs_loop, &request, name, NULL);
  *statbuf = request.statbuf;
  uv_fs_req_cleanup(&request);
  return result;
}

/// Get the file permissions for a given file.
///
/// @return libuv error code on error.
int32_t os_getperm(const char *name)
{
  uv_stat_t statbuf;
  int stat_result = os_stat(name, &statbuf);
  if (stat_result == kLibuvSuccess) {
    return (int32_t)statbuf.st_mode;
  } else {
    return stat_result;
  }
}

/// Set the permission of a file.
///
/// @return `OK` for success, `FAIL` for failure.
int os_setperm(const char *const name, int perm)
  FUNC_ATTR_NONNULL_ALL
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_chmod, name, perm, NULL);
  return (r == kLibuvSuccess ? OK : FAIL);
}

/// Changes the owner and group of a file, like chown(2).
///
/// @return 0 on success, or libuv error code on failure.
///
/// @note If `owner` or `group` is -1, then that ID is not changed.
int os_chown(const char *path, uv_uid_t owner, uv_gid_t group)
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_chown, path, owner, group, NULL);
  return r;
}

/// Changes the owner and group of the file referred to by the open file
/// descriptor, like fchown(2).
///
/// @return 0 on success, or libuv error code on failure.
///
/// @note If `owner` or `group` is -1, then that ID is not changed.
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
  FUNC_ATTR_NONNULL_ARG(2)
{
  return os_stat(path, &(file_info->stat)) == kLibuvSuccess;
}

/// Get the file information for a given path without following links
///
/// @param path Path to the file.
/// @param[out] file_info Pointer to a FileInfo to put the information in.
/// @return `true` on success, `false` for failure.
bool os_fileinfo_link(const char *path, FileInfo *file_info)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (path == NULL) {
    return false;
  }
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

#ifdef WIN32
# include <shlobj.h>

/// When "fname" is the name of a shortcut (*.lnk) resolve the file it points
/// to and return that name in allocated memory.
/// Otherwise NULL is returned.
char *os_resolve_shortcut(const char *fname)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
{
  HRESULT hr;
  IPersistFile *ppf = NULL;
  OLECHAR wsz[MAX_PATH];
  char *rfname = NULL;
  IShellLinkW *pslw = NULL;
  WIN32_FIND_DATAW ffdw;

  // Check if the file name ends in ".lnk". Avoid calling CoCreateInstance(),
  // it's quite slow.
  if (fname == NULL) {
    return rfname;
  }
  const size_t len = strlen(fname);
  if (len <= 4 || STRNICMP(fname + len - 4, ".lnk", 4) != 0) {
    return rfname;
  }

  CoInitialize(NULL);

  // create a link manager object and request its interface
  hr = CoCreateInstance(&CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER,
                        &IID_IShellLinkW, (void **)&pslw);
  if (hr == S_OK) {
    wchar_t *p;
    const int conversion_result = utf8_to_utf16(fname, &p);
    if (conversion_result != 0) {
      EMSG2("utf8_to_utf16 failed: %d", conversion_result);
    }

    if (p != NULL) {
      // Get a pointer to the IPersistFile interface.
      hr = pslw->lpVtbl->QueryInterface(
          pslw, &IID_IPersistFile, (void **)&ppf);
      if (hr != S_OK) {
        goto shortcut_errorw;
      }

      // "load" the name and resolve the link
      hr = ppf->lpVtbl->Load(ppf, p, STGM_READ);
      if (hr != S_OK) {
        goto shortcut_errorw;
      }

#  if 0  // This makes Vim wait a long time if the target does not exist.
      hr = pslw->lpVtbl->Resolve(pslw, NULL, SLR_NO_UI);
      if (hr != S_OK) {
        goto shortcut_errorw;
      }
#  endif

      // Get the path to the link target.
      ZeroMemory(wsz, MAX_PATH * sizeof(wchar_t));
      hr = pslw->lpVtbl->GetPath(pslw, wsz, MAX_PATH, &ffdw, 0);
      if (hr == S_OK && wsz[0] != NUL) {
        const int conversion_result = utf16_to_utf8(wsz, &rfname);
        if (conversion_result != 0) {
          EMSG2("utf16_to_utf8 failed: %d", conversion_result);
        }
      }

shortcut_errorw:
      xfree(p);
      goto shortcut_end;
    }
  }

shortcut_end:
  // Release all interface pointers (both belong to the same object)
  if (ppf != NULL) {
    ppf->lpVtbl->Release(ppf);
  }
  if (pslw != NULL) {
    pslw->lpVtbl->Release(pslw);
  }

  CoUninitialize();
  return rfname;
}

#endif
