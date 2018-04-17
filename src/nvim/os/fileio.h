#ifndef NVIM_OS_FILEIO_H
#define NVIM_OS_FILEIO_H

#include <stdbool.h>
#include <stddef.h>

#include "nvim/func_attr.h"
#include "nvim/rbuffer.h"

/// Structure used to read from/write to file
typedef struct {
  int fd;  ///< File descriptor.
  int _error;  ///< Error code for use with RBuffer callbacks or zero.
  RBuffer *rv;  ///< Read or write buffer.
  bool wr;  ///< True if file is in write mode.
  bool eof;  ///< True if end of file was encountered.
  bool non_blocking;  ///< True if EAGAIN should not restart syscalls.
} FileDescriptor;

/// file_open() flags
typedef enum {
  kFileReadOnly = 1,  ///< Open file read-only. Default.
  kFileCreate = 2,  ///< Create file if it does not exist yet.
                    ///< Implies kFileWriteOnly.
  kFileWriteOnly = 4,  ///< Open file for writing only.
                       ///< Cannot be used with kFileReadOnly.
  kFileNoSymlink = 8,  ///< Do not allow symbolic links.
  kFileCreateOnly = 16,  ///< Only create the file, failing if it already
                         ///< exists. Implies kFileWriteOnly. Cannot be used
                         ///< with kFileCreate.
  kFileTruncate = 32,  ///< Truncate the file if it exists.
                       ///< Implies kFileWriteOnly. Cannot be used with
                       ///< kFileCreateOnly.
  kFileAppend = 64,  ///< Append to the file. Implies kFileWriteOnly. Cannot
                     ///< be used with kFileCreateOnly.
  kFileNonBlocking = 128,  ///< Do not restart read() or write() syscall if
                           ///< EAGAIN was encountered.
} FileOpenFlags;

static inline bool file_eof(const FileDescriptor *const fp)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_NONNULL_ALL;

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

static inline int file_fd(const FileDescriptor *const fp)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_NONNULL_ALL;

/// Return the file descriptor associated with the FileDescriptor structure
///
/// @param[in]  fp  File to check.
///
/// @return File descriptor.
static inline int file_fd(const FileDescriptor *const fp)
{
  return fp->fd;
}

enum {
  /// Read or write buffer size
  ///
  /// Currently equal to (IOSIZE - 1), but they do not need to be connected.
  kRWBufferSize = 1024
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fileio.h.generated.h"
#endif
#endif  // NVIM_OS_FILEIO_H
