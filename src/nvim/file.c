/// @file file.c
///
/// Buffered reading/writing to a file. Unlike fileio.c this is not dealing with
/// Neovim stuctures for buffer, with autocommands, etc: just fopen/fread/fwrite
/// replacement.

#include <unistd.h>
#include <stddef.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/file.h"
#include "nvim/memory.h"
#include "nvim/os/os.h"
#include "nvim/globals.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file.c.generated.h"
#endif

/// Open file
///
/// @param[out]  ret_fp  Address where information needed for reading from or
///                      writing to a file is saved
/// @param[in]  fname  File name to open.
/// @param[in]  flags  Flags, @see FileOpenFlags.
/// @param[in]  mode  Permissions for the newly created file (ignored if flags
///                   does not have FILE_CREATE\*).
///
/// @return Error code (@see os_strerror()) or 0.
int file_open(FileDescriptor *const ret_fp, const char *const fname,
              const int flags, const int mode)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int fd;

  fd = os_open(fname, flags, mode);

  if (fd < 0) {
    return fd;
  }

  ret_fp->fd = fd;
  ret_fp->eof = false;
  return 0;
}

/// Like file_open(), but allocate and return ret_fp
///
/// @param[out]  error  Error code, @see os_strerror(). Is set to zero on
///                     success.
/// @param[in]  fname  File name to open.
/// @param[in]  flags  Flags, @see FileOpenFlags.
/// @param[in]  mode  Permissions for the newly created file (ignored if flags
///                   does not have FILE_CREATE\*).
///
/// @return [allocated] Opened file or NULL in case of error.
FileDescriptor *file_open_new(int *const error, const char *const fname,
                              const int flags, const int mode)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  FileDescriptor *const fp = xmalloc(sizeof(*fp));
  if ((*error = file_open(fp, fname, flags, mode)) != 0) {
    xfree(fp);
    return NULL;
  }
  return fp;
}

/// Close file
///
/// @param[in,out]  fp  File to close.
///
/// @return 0 or error code.
int file_close(FileDescriptor *const fp) FUNC_ATTR_NONNULL_ALL
{
  const int error = file_fsync(fp);
  const int error2 = os_close(fp->fd);
  if (error2 != 0) {
    return error2;
  }
  return error;
}

/// Close and free file obtained using file_open_new()
///
/// @param[in,out]  fp  File to close.
///
/// @return 0 or error code.
int file_free(FileDescriptor *const fp) FUNC_ATTR_NONNULL_ALL
{
  const int ret = file_close(fp);
  xfree(fp);
  return ret;
}

/// Flush file modifications to disk
///
/// @param[in,out]  fp  File to work with.
///
/// @return 0 or error code.
int file_fsync(FileDescriptor *const fp)
  FUNC_ATTR_NONNULL_ALL
{
  return os_fsync(fp->fd);
}

/// Read from file
///
/// @param[in,out]  fp  File to work with.
/// @param[out]  ret_buf  Buffer to read to. Must not be NULL.
/// @param[in]  size  Number of bytes to read. Buffer must have at least ret_buf
///                   bytes.
///
/// @return error_code (< 0) or number of bytes read.
ptrdiff_t file_read(FileDescriptor *const fp, char *const ret_buf,
                    const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  return os_read(fp->fd, &fp->eof, ret_buf, size);
}

/// Write to a file
///
/// @param[in]  fd  File descriptor to write to.
/// @param[in]  buf  Data to write. May be NULL if size is zero.
/// @param[in]  size  Amount of bytes to write.
///
/// @return Number of bytes written or libuv error code (< 0).
ptrdiff_t file_write(FileDescriptor *const fp, const char *const buf,
                     const size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  return os_write(fp->fd, buf, size);
}

/// Buffer used for skipping. Its contents is undefined and should never be
/// used.
static char skipbuf[IOSIZE];

/// Skip some bytes
///
/// This is like `fseek(fp, size, SEEK_CUR)`, but actual implementation simply
/// reads to a buffer and discards the result.
ptrdiff_t file_skip(FileDescriptor *const fp, const size_t size)
  FUNC_ATTR_NONNULL_ALL
{
  size_t read_bytes = 0;
  do {
    ptrdiff_t new_read_bytes = file_read(
        fp, skipbuf, (size_t)(size - read_bytes > sizeof(skipbuf)
                              ? sizeof(skipbuf)
                              : size - read_bytes));
    if (new_read_bytes < 0) {
      return new_read_bytes;
    } else if (new_read_bytes == 0) {
      break;
    }
    read_bytes += (size_t)new_read_bytes;
  } while (read_bytes < size && !fp->eof);

  return (ptrdiff_t)read_bytes;
}
