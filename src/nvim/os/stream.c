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
  // Private loop to avoid conflict with existing watcher(s):
  //    uv__io_stop: Assertion `loop->watchers[w->fd] == w' failed.
  uv_loop_t loop;
  uv_pipe_t stream;
  uv_loop_init(&loop);
  uv_pipe_init(&loop, &stream, 0);
  uv_pipe_open(&stream, fd);
  int retval = uv_stream_set_blocking((uv_stream_t *)&stream, blocking);
  uv_close((uv_handle_t *)&stream, NULL);
  uv_run(&loop, UV_RUN_NOWAIT); // not necessary, but couldn't hurt.
  uv_loop_close(&loop);
  return retval;
}

