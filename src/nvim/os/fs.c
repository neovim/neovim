// fs.c -- filesystem access
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <uv.h>

#ifdef MSWIN
# include <shlobj.h>
#endif

#include "auto/config.h"
#include "nvim/os/fs.h"
#include "nvim/os/os_defs.h"

#if defined(HAVE_ACL)
# ifdef HAVE_SYS_ACL_H
#  include <sys/acl.h>
# endif
# ifdef HAVE_SYS_ACCESS_H
#  include <sys/access.h>
# endif
#endif

#ifdef HAVE_XATTR
# include <sys/xattr.h>
#endif

#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/os/os.h"
#include "nvim/path.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/vim_defs.h"

#ifdef HAVE_SYS_UIO_H
# include <sys/uio.h>
#endif

#ifdef MSWIN
# include "nvim/mbyte.h"
# include "nvim/option.h"
# include "nvim/os/os_win_console.h"
# include "nvim/strings.h"
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fs.c.generated.h"
#endif

#ifdef HAVE_XATTR
static const char e_xattr_erange[]
  = N_("E1506: Buffer too small to copy xattr value or key");
static const char e_xattr_e2big[]
  = N_("E1508: Size of the extended attribute value is larger than the maximum size allowed");
static const char e_xattr_other[]
  = N_("E1509: Error occurred when reading or writing extended attribute");
#endif

#define RUN_UV_FS_FUNC(ret, func, ...) \
  do { \
    uv_fs_t req; \
    ret = func(NULL, &req, __VA_ARGS__); \
    uv_fs_req_cleanup(&req); \
  } while (0)

// Many fs functions from libuv return that value on success.
static const int kLibuvSuccess = 0;

/// Changes the current directory to `path`.
///
/// @return 0 on success, or negative error code.
int os_chdir(const char *path)
  FUNC_ATTR_NONNULL_ALL
{
  if (p_verbose >= 5) {
    verbose_enter();
    smsg(0, "chdir(%s)", path);
    verbose_leave();
  }
  int err = uv_chdir(path);
  if (err == 0) {
    ui_call_chdir(cstr_as_string(path));
  }
  return err;
}

/// Get the name of current directory.
///
/// @param buf Buffer to store the directory name.
/// @param len Length of `buf`.
/// @return `OK` for success, `FAIL` for failure.
int os_dirname(char *buf, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  int error_number;
  if ((error_number = uv_cwd(buf, &len)) != kLibuvSuccess) {
    xstrlcpy(buf, uv_strerror(error_number), len);
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
  if (uv_fs_lstat(NULL, &request, name, NULL) != kLibuvSuccess) {
    return false;
  }
  if (S_ISLNK(request.statbuf.st_mode)) {
    return false;
  }
  return S_ISDIR(request.statbuf.st_mode);
}

/// Check if the given path exists and is a directory.
///
/// @return `true` if `name` is a directory.
bool os_isdir(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
  int32_t mode = os_getperm(name);
  if (mode < 0) {
    return false;
  }

  return S_ISDIR(mode);
}

/// Check what `name` is:
/// @return NODE_NORMAL: file or directory (or doesn't exist)
///         NODE_WRITABLE: writable device, socket, fifo, etc.
///         NODE_OTHER: non-writable things
int os_nodetype(const char *name)
  FUNC_ATTR_NONNULL_ALL
{
#ifndef MSWIN  // Unix
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
  if (strncmp(name, "\\\\.\\", 4) == 0) {
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
/// @param[out,allocated] abspath  Returns resolved exe path, if not NULL.
/// @param[in] use_path  Also search $PATH.
///
/// @return true if `name` is executable and
///   - can be found in $PATH,
///   - is relative to current dir or
///   - is absolute.
///
/// @return `false` otherwise.
bool os_can_exe(const char *name, char **abspath, bool use_path)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!use_path || gettail_dir(name) != name) {
#ifdef MSWIN
    if (is_executable_ext(name, abspath)) {
#else
    // Must have path separator, cannot execute files in the current directory.
    if ((use_path || gettail_dir(name) != name)
        && is_executable(name, abspath)) {
#endif
      return true;
    }
    return false;
  }

  return is_executable_in_path(name, abspath);
}

/// Returns true if `name` is an executable file.
///
/// @param[in]            name     Filename to check.
/// @param[out,allocated] abspath  Returns full exe path, if not NULL.
static bool is_executable(const char *name, char **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  int32_t mode = os_getperm(name);

  if (mode < 0) {
    return false;
  }

#ifdef MSWIN
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
    *abspath = save_abs_path(name);
  }
  return ok;
}

#ifdef MSWIN
/// Checks if file `name` is executable under any of these conditions:
/// - extension is in $PATHEXT and `name` is executable
/// - result of any $PATHEXT extension appended to `name` is executable
static bool is_executable_ext(const char *name, char **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const bool is_unix_shell = strstr(path_tail(p_sh), "powershell") == NULL
                             && strstr(path_tail(p_sh), "pwsh") == NULL
                             && strstr(path_tail(p_sh), "sh") != NULL;
  char *nameext = strrchr(name, '.');
  size_t nameext_len = nameext ? strlen(nameext) : 0;
  xstrlcpy(os_buf, name, sizeof(os_buf));
  char *buf_end = xstrchrnul(os_buf, '\0');
  const char *pathext = os_getenv("PATHEXT");
  if (!pathext) {
    pathext = ".com;.exe;.bat;.cmd";
  }
  const char *ext = pathext;
  while (*ext) {
    // If $PATHEXT itself contains dot:
    if (ext[0] == '.' && (ext[1] == '\0' || ext[1] == ENV_SEPCHAR)) {
      if (is_executable(name, abspath)) {
        return true;
      }
      // Skip it.
      ext++;
      if (*ext) {
        ext++;
      }
      continue;
    }

    const char *ext_end = ext;
    size_t ext_len =
      copy_option_part((char **)&ext_end, buf_end,
                       sizeof(os_buf) - (size_t)(buf_end - os_buf), ENV_SEPSTR);
    if (ext_len != 0) {
      bool in_pathext = nameext_len == ext_len
                        && 0 == mb_strnicmp(nameext, ext, ext_len);

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
static bool is_executable_in_path(const char *name, char **abspath)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const char *path_env = os_getenv("PATH");
  if (path_env == NULL) {
    return false;
  }

#ifdef MSWIN
  // Prepend ".;" to $PATH.
  size_t pathlen = strlen(path_env);
  char *path = memcpy(xmallocz(pathlen + 2), "." ENV_SEPSTR, 2);
  memcpy(path + 2, path_env, pathlen);
#else
  char *path = xstrdup(path_env);
#endif

  size_t buf_len = strlen(name) + strlen(path) + 2;
  char *buf = xmalloc(buf_len);

  // Walk through all entries in $PATH to check if "name" exists there and
  // is an executable file.
  char *p = path;
  bool rv = false;
  while (true) {
    char *e = xstrchrnul(p, ENV_SEPCHAR);

    // Combine the $PATH segment with `name`.
    xmemcpyz(buf, p, (size_t)(e - p));
    (void)append_path(buf, name, buf_len);

#ifdef MSWIN
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
/// @param path Filename
/// @param flags Bitwise OR of flags defined in <fcntl.h>
/// @param mode Permissions for the newly-created file (IGNORED if 'flags' is
///        not `O_CREAT` or `O_TMPFILE`), subject to the current umask
/// @return file descriptor, or negative error code on failure
int os_open(const char *path, int flags, int mode)
{
  if (path == NULL) {  // uv_fs_open asserts on NULL. #7561
    return UV_EINVAL;
  }
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_open, path, flags, mode, NULL);
  return r;
}

/// Compatibility wrapper conforming to fopen(3).
///
/// Windows: works with UTF-16 filepaths by delegating to libuv (os_open).
///
/// Future: remove this, migrate callers to os/fileio.c ?
///         But file_open_fd does not support O_RDWR yet.
///
/// @param path  Filename
/// @param flags  String flags, one of { r w a r+ w+ a+ rb wb ab }
/// @return FILE pointer, or NULL on error.
FILE *os_fopen(const char *path, const char *flags)
{
  assert(flags != NULL && strlen(flags) > 0 && strlen(flags) <= 2);
  int iflags = 0;
  // Per table in fopen(3) manpage.
  if (flags[1] == '\0' || flags[1] == 'b') {
    switch (flags[0]) {
    case 'r':
      iflags = O_RDONLY;
      break;
    case 'w':
      iflags = O_WRONLY | O_CREAT | O_TRUNC;
      break;
    case 'a':
      iflags = O_WRONLY | O_CREAT | O_APPEND;
      break;
    default:
      abort();
    }
#ifdef MSWIN
    if (flags[1] == 'b') {
      iflags |= O_BINARY;
    }
#endif
  } else {
    // char 0 must be one of ('r','w','a').
    // char 1 is always '+' ('b' is handled above).
    assert(flags[1] == '+');
    switch (flags[0]) {
    case 'r':
      iflags = O_RDWR;
      break;
    case 'w':
      iflags = O_RDWR | O_CREAT | O_TRUNC;
      break;
    case 'a':
      iflags = O_RDWR | O_CREAT | O_APPEND;
      break;
    default:
      abort();
    }
  }
  // Per fopen(3) manpage: default to 0666, it will be umask-adjusted.
  int fd = os_open(path, iflags, 0666);
  if (fd < 0) {
    return NULL;
  }
  return fdopen(fd, flags);
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

/// Open the file descriptor for stdin.
int os_open_stdin_fd(void)
{
  int stdin_dup_fd;
  if (stdin_fd > 0) {
    stdin_dup_fd = stdin_fd;
  } else {
    stdin_dup_fd = os_dup(STDIN_FILENO);
#ifdef MSWIN
    // Replace the original stdin with the console input handle.
    os_replace_stdin_to_conin();
#endif
  }
  return stdin_dup_fd;
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
ptrdiff_t os_read(const int fd, bool *const ret_eof, char *const ret_buf, const size_t size,
                  const bool non_blocking)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  *ret_eof = false;
  if (ret_buf == NULL) {
    assert(size == 0);
    return 0;
  }
  size_t read_bytes = 0;
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
ptrdiff_t os_readv(const int fd, bool *const ret_eof, struct iovec *iov, size_t iov_size,
                   const bool non_blocking)
  FUNC_ATTR_NONNULL_ALL
{
  *ret_eof = false;
  size_t read_bytes = 0;
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
ptrdiff_t os_write(const int fd, const char *const buf, const size_t size, const bool non_blocking)
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
  int result = uv_fs_stat(NULL, &request, name, NULL);
  if (result == kLibuvSuccess) {
    *statbuf = request.statbuf;
  }
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
  }
  return stat_result;
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

#ifdef HAVE_XATTR
/// Copy extended attributes from_file to to_file
void os_copy_xattr(const char *from_file, const char *to_file)
{
  if (from_file == NULL) {
    return;
  }

  // get the length of the extended attributes
  ssize_t size = listxattr((char *)from_file, NULL, 0);
  // not supported or no attributes to copy
  if (size <= 0) {
    return;
  }
  char *xattr_buf = xmalloc((size_t)size);
  size = listxattr(from_file, xattr_buf, (size_t)size);
  ssize_t tsize = size;

  errno = 0;

  ssize_t max_vallen = 0;
  char *val = NULL;
  const char *errmsg = NULL;

  for (int round = 0; round < 2; round++) {
    char *key = xattr_buf;
    if (round == 1) {
      size = tsize;
    }

    while (size > 0) {
      ssize_t vallen = getxattr(from_file, key, val, round ? (size_t)max_vallen : 0);
      // only set the attribute in the second round
      if (vallen >= 0 && round
          && setxattr(to_file, key, val, (size_t)vallen, 0) == 0) {
        //
      } else if (errno) {
        switch (errno) {
        case E2BIG:
          errmsg = e_xattr_e2big;
          goto error_exit;
        case ENOTSUP:
        case EACCES:
        case EPERM:
          break;
        case ERANGE:
          errmsg = e_xattr_erange;
          goto error_exit;
        default:
          errmsg = e_xattr_other;
          goto error_exit;
        }
      }

      if (round == 0 && vallen > max_vallen) {
        max_vallen = vallen;
      }

      // add one for terminating null
      ssize_t keylen = (ssize_t)strlen(key) + 1;
      size -= keylen;
      key += keylen;
    }
    if (round) {
      break;
    }

    val = xmalloc((size_t)max_vallen + 1);
  }
error_exit:
  xfree(xattr_buf);
  xfree(val);

  if (errmsg != NULL) {
    emsg(_(errmsg));
  }
}
#endif

// Return a pointer to the ACL of file "fname" in allocated memory.
// Return NULL if the ACL is not available for whatever reason.
vim_acl_T os_get_acl(const char *fname)
{
  vim_acl_T ret = NULL;
  return ret;
}

// Set the ACL of file "fname" to "acl" (unless it's NULL).
void os_set_acl(const char *fname, vim_acl_T aclent)
{
  if (aclent == NULL) {
    return;
  }
}

void os_free_acl(vim_acl_T aclent)
{
  if (aclent == NULL) {
    return;
  }
}

#ifdef UNIX
/// Checks if the current user owns a file.
///
/// Uses both uv_fs_stat() and uv_fs_lstat() via os_fileinfo() and
/// os_fileinfo_link() respectively for extra security.
bool os_file_owned(const char *fname)
  FUNC_ATTR_NONNULL_ALL
{
  uid_t uid = getuid();
  FileInfo finfo;
  bool file_owned = os_fileinfo(fname, &finfo) && finfo.stat.st_uid == uid;
  bool link_owned = os_fileinfo_link(fname, &finfo) && finfo.stat.st_uid == uid;
  return file_owned && link_owned;
}
#else
bool os_file_owned(const char *fname)
{
  return true;  // TODO(justinmk): Windows. #8244
}
#endif

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
bool os_path_exists(const char *path)
{
  uv_stat_t statbuf;
  return os_stat(path, &statbuf) == kLibuvSuccess;
}

/// Sets file access and modification times.
///
/// @see POSIX utime(2)
///
/// @param path   File path.
/// @param atime  Last access time.
/// @param mtime  Last modification time.
///
/// @return 0 on success, or negative error code.
int os_file_settime(const char *path, double atime, double mtime)
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_utime, path, atime, mtime, NULL);
  return r;
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
    return os_isdir(name) ? 2 : 1;
  }
  return 0;
}

/// Rename a file or directory.
///
/// @return `OK` for success, `FAIL` for failure.
int os_rename(const char *path, const char *new_path)
  FUNC_ATTR_NONNULL_ALL
{
  int r;
  RUN_UV_FS_FUNC(r, uv_fs_rename, path, new_path, NULL);
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
/// @param[out]  created     Set to the full name of the first created directory.
///                          It will be NULL until that happens.
///
/// @return `0` for success, libuv error code for failure.
int os_mkdir_recurse(const char *const dir, int32_t mode, char **const failed_dir,
                     char **const created)
  FUNC_ATTR_NONNULL_ARG(1, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Get end of directory name in "dir".
  // We're done when it's "/" or "c:/".
  const size_t dirlen = strlen(dir);
  char *const curdir = xmemdupz(dir, dirlen);
  char *const past_head = get_past_head(curdir);
  char *e = curdir + dirlen;
  const char *const real_end = e;
  const char past_head_save = *past_head;
  while (!os_isdir(curdir)) {
    e = path_tail_with_sep(curdir);
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
    } else if (created != NULL && *created == NULL) {
      *created = FullName_save(curdir, false);
    }
  }
  xfree(curdir);
  return 0;
}

/// Create the parent directory of a file if it does not exist
///
/// @param[in] fname Full path of the file name whose parent directories
///                  we want to create
/// @param[in] mode  Permissions for the newly-created directory.
///
/// @return `0` for success, libuv error code for failure.
int os_file_mkdir(char *fname, int32_t mode)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (!dir_of_file_exists(fname)) {
    char *tail = path_tail_with_sep(fname);
    char *last_char = tail + strlen(tail) - 1;
    if (vim_ispathsep(*last_char)) {
      emsg(_(e_noname));
      return -1;
    }
    char c = *tail;
    *tail = NUL;
    int r;
    char *failed_dir;
    if (((r = os_mkdir_recurse(fname, mode, &failed_dir, NULL)) < 0)) {
      semsg(_(e_mkdir), failed_dir, os_strerror(r));
      xfree(failed_dir);
    }
    *tail = c;
    return r;
  }
  return 0;
}

/// Create a unique temporary directory.
///
/// @param[in] templ Template of the path to the directory with XXXXXX
///                  which would be replaced by random chars.
/// @param[out] path Path to created directory for success, undefined for
///                  failure.
/// @return `0` for success, non-zero for failure.
int os_mkdtemp(const char *templ, char *path)
  FUNC_ATTR_NONNULL_ALL
{
  uv_fs_t request;
  int result = uv_fs_mkdtemp(NULL, &request, templ, NULL);
  if (result == kLibuvSuccess) {
    xstrlcpy(path, request.path, TEMP_FILE_PATH_MAXLEN);
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
  int r = uv_fs_scandir(NULL, &dir->request, path, 0, NULL);
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
  CLEAR_POINTER(file_info);
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
  CLEAR_POINTER(file_info);
  if (path == NULL) {
    return false;
  }
  uv_fs_t request;
  bool ok = uv_fs_lstat(NULL, &request, path, NULL) == kLibuvSuccess;
  if (ok) {
    file_info->stat = request.statbuf;
  }
  uv_fs_req_cleanup(&request);
  return ok;
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
  CLEAR_POINTER(file_info);
  bool ok = uv_fs_fstat(NULL,
                        &request,
                        file_descriptor,
                        NULL) == kLibuvSuccess;
  if (ok) {
    file_info->stat = request.statbuf;
  }
  uv_fs_req_cleanup(&request);
  return ok;
}

/// Compare the inodes of two FileInfos
///
/// @return `true` if the two FileInfos represent the same file.
bool os_fileinfo_id_equal(const FileInfo *file_info_1, const FileInfo *file_info_2)
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
/// @return `true` on success, `false` for failure.
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
bool os_fileid_equal_fileinfo(const FileID *file_id, const FileInfo *file_info)
  FUNC_ATTR_NONNULL_ALL
{
  return file_id->inode == file_info->stat.st_ino
         && file_id->device_id == file_info->stat.st_dev;
}

/// Return the canonicalized absolute pathname.
///
/// @param[in] name Filename to be canonicalized.
/// @param[out] buf Buffer to store the canonicalized values.
///                 If it is NULL, memory is allocated. In that case, the caller
///                 should deallocate this buffer.
/// @param[in] len  The length of the buffer.
///
/// @return pointer to the buf on success, or NULL.
char *os_realpath(const char *name, char *buf, size_t len)
  FUNC_ATTR_NONNULL_ARG(1)
{
  uv_fs_t request;
  int result = uv_fs_realpath(NULL, &request, name, NULL);
  if (result == kLibuvSuccess) {
    if (buf == NULL) {
      buf = xmalloc(len);
    }
    xstrlcpy(buf, request.ptr, len);
  }
  uv_fs_req_cleanup(&request);
  return result == kLibuvSuccess ? buf : NULL;
}

#ifdef MSWIN
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
    const int r = utf8_to_utf16(fname, -1, &p);
    if (r != 0) {
      semsg("utf8_to_utf16 failed: %d", r);
    } else if (p != NULL) {
      // Get a pointer to the IPersistFile interface.
      hr = pslw->lpVtbl->QueryInterface(pslw, &IID_IPersistFile, (void **)&ppf);
      if (hr != S_OK) {
        goto shortcut_errorw;
      }

      // "load" the name and resolve the link
      hr = ppf->lpVtbl->Load(ppf, p, STGM_READ);
      if (hr != S_OK) {
        goto shortcut_errorw;
      }

# if 0  // This makes Vim wait a long time if the target does not exist.
      hr = pslw->lpVtbl->Resolve(pslw, NULL, SLR_NO_UI);
      if (hr != S_OK) {
        goto shortcut_errorw;
      }
# endif

      // Get the path to the link target.
      ZeroMemory(wsz, MAX_PATH * sizeof(wchar_t));
      hr = pslw->lpVtbl->GetPath(pslw, wsz, MAX_PATH, &ffdw, 0);
      if (hr == S_OK && wsz[0] != NUL) {
        const int r2 = utf16_to_utf8(wsz, -1, &rfname);
        if (r2 != 0) {
          semsg("utf16_to_utf8 failed: %d", r2);
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

# define IS_PATH_SEP(c) ((c) == L'\\' || (c) == L'/')
/// Returns true if the path contains a reparse point (junction or symbolic
/// link). Otherwise false in returned.
bool os_is_reparse_point_include(const char *path)
{
  wchar_t *p, *q, *utf16_path;
  wchar_t buf[MAX_PATH];
  DWORD attr;
  bool result = false;

  const int r = utf8_to_utf16(path, -1, &utf16_path);
  if (r != 0) {
    semsg("utf8_to_utf16 failed: %d", r);
    return false;
  }

  p = utf16_path;
  if (isalpha((uint8_t)p[0]) && p[1] == L':' && IS_PATH_SEP(p[2])) {
    p += 3;
  } else if (IS_PATH_SEP(p[0]) && IS_PATH_SEP(p[1])) {
    p += 2;
  }

  while (*p != L'\0') {
    q = wcspbrk(p, L"\\/");
    if (q == NULL) {
      p = q = utf16_path + wcslen(utf16_path);
    } else {
      p = q + 1;
    }
    if (q - utf16_path >= MAX_PATH) {
      break;
    }
    wcsncpy(buf, utf16_path, (size_t)(q - utf16_path));
    buf[q - utf16_path] = L'\0';
    attr = GetFileAttributesW(buf);
    if (attr != INVALID_FILE_ATTRIBUTES
        && (attr & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
      result = true;
      break;
    }
  }
  xfree(utf16_path);
  return result;
}
#endif
