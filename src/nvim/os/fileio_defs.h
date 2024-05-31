#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/func_attr.h"

/// Structure used to read from/write to file
typedef struct {
  int fd;             ///< File descriptor. Can be -1 if no backing file (file_open_buffer)
  char *buffer;       ///< Read or write buffer. always ARENA_BLOCK_SIZE if allocated
  char *read_pos;     ///< read position in buffer
  char *write_pos;    ///< write position in buffer
  bool wr;            ///< True if file is in write mode.
  bool eof;           ///< True if end of file was encountered.
  bool non_blocking;  ///< True if EAGAIN should not restart syscalls.
  uint64_t bytes_read;  ///< total bytes read so far
} FileDescriptor;

static inline bool file_eof(const FileDescriptor *fp)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_NONNULL_ALL;

/// Check whether end of file was encountered
///
/// @param[in]  fp  File to check.
///
/// @return true if it was, false if it was not or read operation was never
///         performed.
static inline bool file_eof(const FileDescriptor *const fp)
{
  return fp->eof && fp->read_pos == fp->write_pos;
}

static inline int file_fd(const FileDescriptor *fp)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_NONNULL_ALL;

/// Return the file descriptor associated with the FileDescriptor structure
///
/// @param[in]  fp  File to check.
///
/// @return File descriptor.
static inline int file_fd(const FileDescriptor *const fp)
{
  return fp->fd;
}
