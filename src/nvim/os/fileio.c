/// @file fileio.c
///
/// Buffered reading/writing to a file. Unlike fileio.c this is not dealing with
/// Nvim structures for buffer, with autocommands, etc: just fopen/fread/fwrite
/// replacement.

#include <assert.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <uv.h>

#include "auto/config.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/fileio.h"
#include "nvim/os/fs.h"
#include "nvim/os/os_defs.h"
#include "nvim/rbuffer.h"
#include "nvim/rbuffer_defs.h"
#include "nvim/types_defs.h"

#ifdef HAVE_SYS_UIO_H
# include <sys/uio.h>
#endif

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
int file_open(FileDescriptor *const ret_fp, const char *const fname, const int flags,
              const int mode)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  int os_open_flags = 0;
  TriState wr = kNone;
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
  FLAG(flags, kFileMkDir, O_CREAT|O_WRONLY, kTrue, !(flags & kFileCreateOnly));
#endif
#undef FLAG
  // wr is used for kFileReadOnly flag, but on
  // QB:neovim-qb-slave-ubuntu-12-04-64bit it still errors out with
  // `error: variable ‘wr’ set but not used [-Werror=unused-but-set-variable]`
  (void)wr;

  if (flags & kFileMkDir) {
    int mkdir_ret = os_file_mkdir((char *)fname, 0755);
    if (mkdir_ret < 0) {
      return mkdir_ret;
    }
  }

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
int file_open_fd(FileDescriptor *const ret_fp, const int fd, const int flags)
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
  ret_fp->buffer = alloc_block();
  ret_fp->read_pos = ret_fp->buffer;
  ret_fp->write_pos = ret_fp->buffer;
  ret_fp->bytes_read = 0;
  return 0;
}

/// Opens standard input as a FileDescriptor.
int file_open_stdin(FileDescriptor *fp)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  int error = file_open_fd(fp, os_open_stdin_fd(), kFileReadOnly|kFileNonBlocking);
  if (error != 0) {
    ELOG("failed to open stdin: %s", os_strerror(error));
  }
  return error;
}

/// opens buffer for reading
void file_open_buffer(FileDescriptor *ret_fp, char *data, size_t len)
{
  ret_fp->wr = false;
  ret_fp->non_blocking = false;
  ret_fp->fd = -1;
  ret_fp->eof = true;
  ret_fp->buffer = NULL;  // we don't take ownership
  ret_fp->read_pos = data;
  ret_fp->write_pos = data + len;
  ret_fp->bytes_read = 0;
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
  if (fp->fd < 0) {
    return 0;
  }

  const int flush_error = (do_fsync ? file_fsync(fp) : file_flush(fp));
  const int close_error = os_close(fp->fd);
  free_block(fp->buffer);
  if (close_error != 0) {
    return close_error;
  }
  return flush_error;
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
  if (fsync_error != UV_EINVAL
      && fsync_error != UV_EROFS
      // fsync not supported on this storage.
      && fsync_error != UV_ENOTSUP) {
    return fsync_error;
  }
  return 0;
}

/// Flush file modifications to disk
///
/// @param[in,out]  fp  File to work with.
///
/// @return 0 or error code.
int file_flush(FileDescriptor *fp)
  FUNC_ATTR_NONNULL_ALL
{
  if (!fp->wr) {
    return 0;
  }

  ptrdiff_t to_write = fp->write_pos - fp->read_pos;
  if (to_write == 0) {
    return 0;
  }
  const ptrdiff_t wres = os_write(fp->fd, fp->read_pos, (size_t)to_write,
                                  fp->non_blocking);
  fp->read_pos = fp->write_pos = fp->buffer;
  if (wres != to_write) {
    return (wres >= 0) ? UV_EIO : (int)wres;
  }
  return 0;
}

/// Read from file
///
/// @param[in,out]  fp  File to work with.
/// @param[out]  ret_buf  Buffer to read to. Must not be NULL.
/// @param[in]  size  Number of bytes to read. Buffer must have at least ret_buf
///                   bytes.
///
/// @return error_code (< 0) or number of bytes read.
ptrdiff_t file_read(FileDescriptor *const fp, char *const ret_buf, const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(!fp->wr);
  size_t from_buffer = MIN((size_t)(fp->write_pos - fp->read_pos), size);
  memcpy(ret_buf, fp->read_pos, from_buffer);

  char *buf = ret_buf + from_buffer;
  size_t read_remaining = size - from_buffer;
  if (!read_remaining) {
    fp->bytes_read += from_buffer;
    fp->read_pos += from_buffer;
    return (ptrdiff_t)from_buffer;
  }

  // at this point, we have consumed all of an existing buffer. restart from the beginning
  fp->read_pos = fp->write_pos = fp->buffer;

#ifdef HAVE_READV
  bool called_read = false;
  while (read_remaining) {
    // Allow only at most one os_read[v] call.
    if (fp->eof || (called_read && fp->non_blocking)) {
      break;
    }
    // If there is readv() syscall, then take an opportunity to populate
    // both target buffer and RBuffer at once, …
    struct iovec iov[] = {
      { .iov_base = buf, .iov_len = read_remaining },
      { .iov_base = fp->write_pos,
        .iov_len = ARENA_BLOCK_SIZE },
    };
    const ptrdiff_t r_ret = os_readv(fp->fd, &fp->eof, iov,
                                     ARRAY_SIZE(iov), fp->non_blocking);
    if (r_ret > 0) {
      if (r_ret > (ptrdiff_t)read_remaining) {
        fp->write_pos += (size_t)(r_ret - (ptrdiff_t)read_remaining);
        read_remaining = 0;
      } else {
        buf += r_ret;
        read_remaining -= (size_t)r_ret;
      }
    } else if (r_ret < 0) {
      return r_ret;
    }
    called_read = true;
  }
#else
  if (fp->eof) {
    // already eof, cannot read more
  } else if (read_remaining >= ARENA_BLOCK_SIZE) {
    // …otherwise leave fp->buffer empty and populate only target buffer,
    // because filtering information through rbuffer will be more syscalls.
    const ptrdiff_t r_ret = os_read(fp->fd, &fp->eof, buf, read_remaining,
                                    fp->non_blocking);
    if (r_ret >= 0) {
      read_remaining -= (size_t)r_ret;
    } else if (r_ret < 0) {
      return r_ret;
    }
  } else {
    const ptrdiff_t r_ret = os_read(fp->fd, &fp->eof,
                                    fp->write_pos,
                                    ARENA_BLOCK_SIZE, fp->non_blocking);
    if (r_ret < 0) {
      return r_ret;
    } else {
      fp->write_pos += r_ret;
      size_t to_copy = MIN((size_t)r_ret, read_remaining);
      memcpy(buf, fp->read_pos, to_copy);
      fp->read_pos += to_copy;
      read_remaining -= to_copy;
    }
  }
#endif

  fp->bytes_read += (size - read_remaining);
  return (ptrdiff_t)(size - read_remaining);
}

/// Write to a file
///
/// @param[in]  fd  File descriptor to write to.
/// @param[in]  buf  Data to write. May be NULL if size is zero.
/// @param[in]  size  Amount of bytes to write.
///
/// @return Number of bytes written or libuv error code (< 0).
ptrdiff_t file_write(FileDescriptor *const fp, const char *const buf, const size_t size)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  assert(fp->wr);
  ptrdiff_t space = (fp->buffer + ARENA_BLOCK_SIZE) - fp->write_pos;
  // includes the trivial case of size==0
  if (size < (size_t)space) {
    memcpy(fp->write_pos, buf, size);
    fp->write_pos += size;
    return (ptrdiff_t)size;
  }

  // TODO(bfredl): just as for reading, use iovec to combine fp->buffer with buf
  int status = file_flush(fp);
  if (status < 0) {
    return status;
  }

  if (size < ARENA_BLOCK_SIZE) {
    memcpy(fp->write_pos, buf, size);
    fp->write_pos += size;
    return (ptrdiff_t)size;
  }

  const ptrdiff_t wres = os_write(fp->fd, buf, size,
                                  fp->non_blocking);
  return (wres != (ptrdiff_t)size && wres >= 0) ? UV_EIO : wres;
}

/// Skip some bytes
///
/// This is like `fseek(fp, size, SEEK_CUR)`, but actual implementation simply
/// reads to the buffer and discards the result.
ptrdiff_t file_skip(FileDescriptor *const fp, const size_t size)
  FUNC_ATTR_NONNULL_ALL
{
  assert(!fp->wr);
  size_t from_buffer = MIN((size_t)(fp->write_pos - fp->read_pos), size);
  size_t skip_remaining = size - from_buffer;
  if (skip_remaining == 0) {
    fp->read_pos += from_buffer;
    fp->bytes_read += from_buffer;
    return (ptrdiff_t)from_buffer;
  }

  fp->read_pos = fp->write_pos = fp->buffer;
  bool called_read = false;
  while (skip_remaining > 0) {
    // Allow only at most one os_read[v] call.
    if (fp->eof || (called_read && fp->non_blocking)) {
      break;
    }
    const ptrdiff_t r_ret = os_read(fp->fd, &fp->eof, fp->buffer, ARENA_BLOCK_SIZE,
                                    fp->non_blocking);
    if (r_ret < 0) {
      return r_ret;
    } else if ((size_t)r_ret > skip_remaining) {
      fp->read_pos = fp->buffer + skip_remaining;
      fp->write_pos = fp->buffer + r_ret;
      fp->bytes_read += size;
      return (ptrdiff_t)size;
    }
    skip_remaining -= (size_t)r_ret;
    called_read = true;
  }

  fp->bytes_read += size - skip_remaining;
  return (ptrdiff_t)(size - skip_remaining);
}
