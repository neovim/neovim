// Functions for working with stdio streams (as opposed to RStream/WStream).

#include <stdio.h>
#include <stdbool.h>

#include <uv.h>

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/stream.c.generated.h"
#endif

/// Sets the stream associated with `fd` to "blocking" mode.
///
/// @return `0` on success, or `-errno` on failure.
int stream_set_blocking(int fd, bool blocking)
{
  int flags = fcntl(fd, F_GETFL, 0);
  int err = 0;
  if (!blocking && !(flags & O_NONBLOCK)) {
    err = fcntl(fd, F_SETFL, flags | O_NONBLOCK);
  } else if (blocking && (flags & O_NONBLOCK)) {
    err = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK);
  }
  return err == -1 ? -errno : 0;
}

