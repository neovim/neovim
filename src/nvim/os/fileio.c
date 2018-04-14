// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file fileio.c
///
/// Buffered reading/writing to a file. Unlike fileio.c this is not dealing with
/// Nvim stuctures for buffer, with autocommands, etc: just fopen/fread/fwrite
/// replacement.

#include <assert.h>
#include <stddef.h>
#include <stdbool.h>
#include <fcntl.h>

#include "auto/config.h"

#ifdef HAVE_SYS_UIO_H
# include <sys/uio.h>
#endif

#include <uv.h>

#include "nvim/os/fileio.h"
#include "nvim/memory.h"
#include "nvim/os/os.h"
#include "nvim/globals.h"
#include "nvim/rbuffer.h"
#include "nvim/macros.h"
#include "nvim/message.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fileio.c.generated.h"
#endif

/// Open file
///
/// @param[out]  ret_fp  Address where information needed for reading from or
///                      writing to a file is saved
/// @param[in]  fname  File name to open.
/// @param[in]  flags  Flags, @see FileOpenFlags. Currently reading from and
///                    writing to the file at once is not supported, so either
///                    kFileWriteOnly or kFileReadOnly is required.
/// @param[in]  mode  Permissions for the newly created file (ignored if flags
///                   does not have kFileCreate\*).
///
/// @return Error code, or 0 on success. @see os_strerror()
int file_open(FileDescriptor *const ret_fp, const char *const fname,
              const int flags, const int mode)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int os_open_flags = 0;
  TriState wr = kNone;
  // -V:FLAG:501
#define FLAG(flags, flag, fcntl_flags, wrval, cond) \
  do { \
    if (flags & flag) { \
      os_open_flags |= fcntl_flags; \
      assert(cond); \
      if (wrval != kNone) { \
        wr = wrval; \
      } \
    } \
  } while (0)
  FLAG(flags, kFileWriteOnly, O_WRONLY, kTrue, true);
  FLAG(flags, kFileCreateOnly, O_CREAT|O_EXCL|O_WRONLY, kTrue, true);
  FLAG(flags, kFileCreate, O_CREAT|O_WRONLY, kTrue, !(flags & kFileCreateOnly));
  FLAG(flags, kFileTruncate, O_TRUNC|O_WRONLY, kTrue,
       !(flags & kFileCreateOnly));
  FLAG(flags, kFileAppend, O_APPEND|O_WRONLY, kTrue,
       !(flags & kFileCreateOnly));
  FLAG(flags, kFileReadOnly, O_RDONLY, kFalse, wr != kTrue);
#ifdef O_NOFOLLOW
  FLAG(flags, kFileNoSymlink, O_NOFOLLOW, kNone, true);
#endif
#undef FLAG
  // wr is used for kFileReadOnly flag, but on
  // QB:neovim-qb-slave-ubuntu-12-04-64bit it still errors out with
  // `error: variable ‘wr’ set but not used [-Werror=unused-but-set-variable]`
  (void)wr;

  const int fd = os_open(fname, os_open_flags, mode);

  if (fd < 0) {
    return fd;
  }
  return file_open_fd(ret_fp, fd, flags);
}

/// Wrap file descriptor with FileDescriptor structure
///
/// @warning File descriptor wrapped like this must not be accessed by other
///          means.
///
/// @param[out]  ret_fp  Address where information needed for reading from or
///                      writing to a file is saved
/// @param[in]  fd  File descriptor to wrap.
/// @param[in]  flags  Flags, @see FileOpenFlags. Currently reading from and
///                    writing to the file at once is not supported, so either
///                    FILE_WRITE_ONLY or FILE_READ_ONLY is required.
///
/// @return Error code (@see os_strerror()) or 0. Currently always returns 0.
int file_open_fd(FileDescriptor *const ret_fp, const int fd,
                 const int flags)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  ret_fp->wr = !!(flags & (kFileCreate
                           |kFileCreateOnly
                           |kFileTruncate
                           |kFileAppend
                           |kFileWriteOnly));
  ret_fp->non_blocking = !!(flags & kFileNonBlocking);
  // Non-blocking writes not supported currently.
  assert(!ret_fp->wr || !ret_fp->non_blocking);
  ret_fp->fd = fd;
  ret_fp->eof = false;
  ret_fp->rv = rbuffer_new(kRWBufferSize);
  ret_fp->_error = 0;
  if (ret_fp->wr) {
    ret_fp->rv->data = ret_fp;
    ret_fp->rv->full_cb = (rbuffer_callback)&file_rb_write_full_cb;
  }
  return 0;
}

/// Like file_open(), but allocate and return ret_fp
///
/// @param[out]  error  Error code, or 0 on success. @see os_strerror()
/// @param[in]  fname  File name to open.
/// @param[in]  flags  Flags, @see FileOpenFlags.
/// @param[in]  mode  Permissions for the newly created file (ignored if flags
///                   does not have kFileCreate\*).
///
/// @return [allocated] Opened file or NULL in case of error.
FileDescriptor *file_open_new(int *const error, const char *const fname,
                              const int flags, const int mode)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  FileDescriptor *const fp = xmalloc(sizeof(*fp));
  if ((*error = file_open(fp, fname, flags, mode)) != 0) {
    xfree(fp);
    return NULL;
  }
  return fp;
}

/// Like file_open_fd(), but allocate and return ret_fp
///
/// @param[out]  error  Error code, or 0 on success. @see os_strerror()
/// @param[in]  fd  File descriptor to wrap.
/// @param[in]  flags  Flags, @see FileOpenFlags.
/// @param[in]  mode  Permissions for the newly created file (ignored if flags
///                   does not have FILE_CREATE\*).
///
/// @return [allocated] Opened file or NULL in case of error.
FileDescriptor *file_open_fd_new(int *const error, const int fd,
                                 const int flags)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  FileDescriptor *const fp = xmalloc(sizeof(*fp));
  if ((*error = file_open_fd(fp, fd, flags)) != 0) {
    xfree(fp);
    return NULL;
  }
  return fp;
}

/// Close file and free its buffer
///
/// @param[in,out]  fp  File to close.
/// @param[in]  do_fsync  If true, use fsync() to write changes to disk.
///
/// @return 0 or error code.
int file_close(FileDescriptor *const fp, const bool do_fsync)
  FUNC_ATTR_NONNULL_ALL
{
  const int flush_error = (do_fsync ? file_fsync(fp) : file_flush(fp));
  const int close_error = os_close(fp->fd);
  rbuffer_free(fp->rv);
  if (close_error != 0) {
    return close_error;
  }
  return flush_error;
}

/// Close and free file obtained using file_open_new()
///
/// @param[in,out]  fp  File to close.
/// @param[in]  do_fsync  If true, use fsync() to write changes to disk.
///
/// @return 0 or error code.
int file_free(FileDescriptor *const fp, const bool do_fsync)
  FUNC_ATTR_NONNULL_ALL
{
  const int ret = file_close(fp, do_fsync);
  xfree(fp);
  return ret;
}

/// Flush file modifications to disk
///
/// @param[in,out]  fp  File to work with.
///
/// @return 0 or error code.
int file_flush(FileDescriptor *const fp)
  FUNC_ATTR_NONNULL_ALL
{
  if (!fp->wr) {
    return 0;
  }
  file_rb_write_full_cb(fp->rv, fp);
  const int error = fp->_error;
  fp->_error = 0;
  return error;
}

/// Flush file modifications to disk and run fsync()
///
/// @param[in,out]  fp  File to work with.
///
/// @return 0 or error code.
int file_fsync(FileDescriptor *const fp)
  FUNC_ATTR_NONNULL_ALL
{
  if (!fp->wr) {
    return 0;
  }
  const int flush_error = file_flush(fp);
  if (flush_error != 0) {
    return flush_error;
  }
  const int fsync_error = os_fsync(fp->fd);
  if (fsync_error != UV_EINVAL && fsync_error != UV_EROFS) {
    return fsync_error;
  }
  return 0;
}

/// Buffer used for writing
///
/// Like IObuff, but allows file_\* callers not to care about spoiling it.
static char writebuf[kRWBufferSize];

/// Function run when RBuffer is full when writing to a file
///
/// Actually does writing to the file, may also be invoked directly.
///
/// @param[in,out]  rv  RBuffer instance used.
/// @param[in,out]  fp  File to work with.
static void file_rb_write_full_cb(RBuffer *const rv, FileDescriptor *const fp)
  FUNC_ATTR_NONNULL_ALL
{
  assert(fp->wr);
  assert(rv->data == (void *)fp);
  if (rbuffer_size(rv) == 0) {
    return;
  }
  const size_t read_bytes = rbuffer_read(rv, writebuf, kRWBufferSize);
  const ptrdiff_t wres = os_write(fp->fd, writebuf, read_bytes,
                                  fp->non_blocking);
  if (wres != (ptrdiff_t)read_bytes) {
    if (wres >= 0) {
      fp->_error = UV_EIO;
    } else {
      fp->_error = (int)wres;
    }
  }
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
  assert(!fp->wr);
  char *buf = ret_buf;
  size_t read_remaining = size;
  RBuffer *const rv = fp->rv;
  bool called_read = false;
  while (read_remaining) {
    const size_t rv_size = rbuffer_size(rv);
    if (rv_size > 0) {
      const size_t rsize = rbuffer_read(rv, buf, MIN(rv_size, read_remaining));
      buf += rsize;
      read_remaining -= rsize;
    }
    if (fp->eof
        // Allow only at most one os_read[v] call.
        || (called_read && fp->non_blocking)) {
      break;
    }
    if (read_remaining) {
      assert(rbuffer_size(rv) == 0);
      rbuffer_reset(rv);
#ifdef HAVE_READV
      // If there is readv() syscall, then take an opportunity to populate
      // both target buffer and RBuffer at once, …
      size_t write_count;
      struct iovec iov[] = {
        { .iov_base = buf, .iov_len = read_remaining },
        { .iov_base = rbuffer_write_ptr(rv, &write_count),
          .iov_len = kRWBufferSize },
      };
      assert(write_count == kRWBufferSize);
      const ptrdiff_t r_ret = os_readv(fp->fd, &fp->eof, iov,
                                       ARRAY_SIZE(iov), fp->non_blocking);
      if (r_ret > 0) {
        if (r_ret > (ptrdiff_t)read_remaining) {
          rbuffer_produced(rv, (size_t)(r_ret - (ptrdiff_t)read_remaining));
          read_remaining = 0;
        } else {
          buf += (size_t)r_ret;
          read_remaining -= (size_t)r_ret;
        }
      } else if (r_ret < 0) {
        return r_ret;
      }
#else
      if (read_remaining >= kRWBufferSize) {
        // …otherwise leave RBuffer empty and populate only target buffer,
        // because filtering information through rbuffer will be more syscalls.
        const ptrdiff_t r_ret = os_read(fp->fd, &fp->eof, buf, read_remaining,
                                        fp->non_blocking);
        if (r_ret >= 0) {
          read_remaining -= (size_t)r_ret;
          return (ptrdiff_t)(size - read_remaining);
        } else if (r_ret < 0) {
          return r_ret;
        }
      } else {
        size_t write_count;
        const ptrdiff_t r_ret = os_read(fp->fd, &fp->eof,
                                        rbuffer_write_ptr(rv, &write_count),
                                        kRWBufferSize, fp->non_blocking);
        assert(write_count == kRWBufferSize);
        if (r_ret > 0) {
          rbuffer_produced(rv, (size_t)r_ret);
        } else if (r_ret < 0) {
          return r_ret;
        }
      }
#endif
      called_read = true;
    }
  }
  return (ptrdiff_t)(size - read_remaining);
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
  assert(fp->wr);
  const size_t written = rbuffer_write(fp->rv, buf, size);
  if (fp->_error != 0) {
    const int error = fp->_error;
    fp->_error = 0;
    return error;
  } else if (written != size) {
    return UV_EIO;
  }
  return (ptrdiff_t)written;
}

/// Buffer used for skipping. Its contents is undefined and should never be
/// used.
static char skipbuf[kRWBufferSize];

/// Skip some bytes
///
/// This is like `fseek(fp, size, SEEK_CUR)`, but actual implementation simply
/// reads to a buffer and discards the result.
ptrdiff_t file_skip(FileDescriptor *const fp, const size_t size)
  FUNC_ATTR_NONNULL_ALL
{
  assert(!fp->wr);
  size_t read_bytes = 0;
  do {
    const ptrdiff_t new_read_bytes = file_read(
        fp, skipbuf, MIN(size - read_bytes, sizeof(skipbuf)));
    if (new_read_bytes < 0) {
      return new_read_bytes;
    } else if (new_read_bytes == 0) {
      break;
    }
    read_bytes += (size_t)new_read_bytes;
  } while (read_bytes < size && !file_eof(fp));

  return (ptrdiff_t)read_bytes;
}

/// Msgpack callback for writing to a file
///
/// @param  data  File to write to.
/// @param[in]  buf  Data to write.
/// @param[in]  len  Length of the data to write.
///
/// @return 0 in case of success, -1 in case of error.
int msgpack_file_write(void *data, const char *buf, size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(len < PTRDIFF_MAX);
  const ptrdiff_t written_bytes = file_write((FileDescriptor *)data, buf, len);
  if (written_bytes < 0) {
    return msgpack_file_write_error((int)written_bytes);
  }
  return 0;
}

/// Print error which occurs when failing to write msgpack data
///
/// @param[in]  error  Error code of the error to print.
///
/// @return -1 (error return for msgpack_packer callbacks).
int msgpack_file_write_error(const int error)
{
  emsgf(_("E5420: Failed to write to file: %s"), os_strerror(error));
  return -1;
}
