#ifndef NVIM_FILE_H
#define NVIM_FILE_H

#include <stdbool.h>
#include <stddef.h>
#include <fcntl.h>

#include "nvim/func_attr.h"
#include "nvim/rbuffer.h"

/// Structure used to read from/write to file
typedef struct {
  int fd;  ///< File descriptor.
  int _error;  ///< Error code for use with RBuffer callbacks or zero.
  RBuffer *rv;  ///< Read or write buffer.
  bool wr;  ///< True if file is in write mode.
  bool eof;  ///< True if end of file was encountered.
} FileDescriptor;

/// file_open() flags
typedef enum {
  FILE_READ_ONLY = O_RDONLY,  ///< Open file read-only.
  FILE_CREATE = O_CREAT,  ///< Create file if it does not exist yet.
  FILE_WRITE_ONLY = O_WRONLY,  ///< Open file for writing only.
#ifdef O_NOFOLLOW
  FILE_NOSYMLINK = O_NOFOLLOW,  ///< Do not allow symbolic links.
#else
  FILE_NOSYMLINK = 0,
#endif
  FILE_CREATE_ONLY = O_CREAT|O_EXCL,  ///< Only create the file, failing
                                      ///< if it already exists.
  FILE_TRUNCATE = O_TRUNC,  ///< Truncate the file if it exists.
} FileOpenFlags;

/// Check whether end of file was encountered
///
/// @param[in]  fp  File to check.
///
/// @return true if it was, false if it was not or read operation was never
///         performed.
static inline bool file_eof(const FileDescriptor *const fp)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_ALWAYS_INLINE
{
  return fp->eof && rbuffer_size(fp->rv) == 0;
}

/// Return the file descriptor associated with the FileDescriptor structure
///
/// @param[in]  fp  File to check.
///
/// @return File descriptor.
static inline int file_fd(const FileDescriptor *const fp)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_ALWAYS_INLINE
{
  return fp->fd;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file.h.generated.h"
#endif
#endif  // NVIM_FILE_H
