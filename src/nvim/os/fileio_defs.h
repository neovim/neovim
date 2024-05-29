#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/func_attr.h"
#include "nvim/rbuffer_defs.h"

/// Structure used to read from/write to file
typedef struct {
  int fd;             ///< File descriptor.
  int _error;         ///< Error code for use with RBuffer callbacks or zero.
  RBuffer *rv;        ///< Read or write buffer.
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
  return fp->eof && rbuffer_size(fp->rv) == 0;
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
