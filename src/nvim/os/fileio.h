#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/memory_defs.h"
#include "nvim/os/fileio_defs.h"  // IWYU pragma: keep

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
  kFileMkDir = 256,
} FileOpenFlags;

enum {
  /// Read or write buffer size
  ///
  /// Currently equal to (IOSIZE - 1), but they do not need to be connected.
  kRWBufferSize = 1024,
};

static inline size_t file_space(FileDescriptor *fp)
{
  return (size_t)((fp->buffer + ARENA_BLOCK_SIZE) - fp->write_pos);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/fileio.h.generated.h"
#endif
