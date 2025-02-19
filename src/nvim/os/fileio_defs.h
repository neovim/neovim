#pragma once

#include <stdbool.h>
#include <stdint.h>

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fileio_defs.h.inline.generated.h"
#endif

/// Check whether end of file was encountered
///
/// @param[in]  fp  File to check.
///
/// @return true if it was, false if it was not or read operation was never
///         performed.
static inline bool file_eof(const FileDescriptor *const fp)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return fp->eof && fp->read_pos == fp->write_pos;
}

/// Return the file descriptor associated with the FileDescriptor structure
///
/// @param[in]  fp  File to check.
///
/// @return File descriptor.
static inline int file_fd(const FileDescriptor *const fp)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return fp->fd;
}
