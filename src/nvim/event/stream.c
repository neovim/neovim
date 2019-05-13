// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdio.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/log.h"
#include "nvim/rbuffer.h"
#include "nvim/macros.h"
#include "nvim/event/stream.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/stream.c.generated.h"
#endif

/// Sets the stream associated with `fd` to "blocking" mode.
///
/// @return `0` on success, or libuv error code on failure.
int stream_set_blocking(int fd, bool blocking)
{
  // Private loop to avoid conflict with existing watcher(s):
  //    uv__io_stop: Assertion `loop->watchers[w->fd] == w' failed.
  uv_loop_t loop;
  uv_pipe_t stream;
  uv_loop_init(&loop);
  uv_pipe_init(&loop, &stream, 0);
  uv_pipe_open(&stream, fd);
  int retval = uv_stream_set_blocking(STRUCT_CAST(uv_stream_t, &stream),
                                      blocking);
  uv_close(STRUCT_CAST(uv_handle_t, &stream), NULL);
  uv_run(&loop, UV_RUN_NOWAIT);  // not necessary, but couldn't hurt.
  uv_loop_close(&loop);
  return retval;
}

void stream_init(Loop *loop, Stream *stream, int fd, uv_stream_t *uvstream)
  FUNC_ATTR_NONNULL_ARG(2)
{
  stream->uvstream = uvstream;

  if (fd >= 0) {
    uv_handle_type type = uv_guess_handle(fd);
    stream->fd = fd;

    if (type == UV_FILE) {
      // Non-blocking file reads are simulated with an idle handle that reads in
      // chunks of the ring buffer size, giving time for other events to be
      // processed between reads.
      uv_idle_init(&loop->uv, &stream->uv.idle);
      stream->uv.idle.data = stream;
    } else {
      assert(type == UV_NAMED_PIPE || type == UV_TTY);
#ifdef WIN32
      if (type == UV_TTY) {
        uv_tty_init(&loop->uv, &stream->uv.tty, fd, 0);
        uv_tty_set_mode(&stream->uv.tty, UV_TTY_MODE_RAW);
        stream->uvstream = STRUCT_CAST(uv_stream_t, &stream->uv.tty);
      } else {
#endif
      uv_pipe_init(&loop->uv, &stream->uv.pipe, 0);
      uv_pipe_open(&stream->uv.pipe, fd);
      stream->uvstream = STRUCT_CAST(uv_stream_t, &stream->uv.pipe);
#ifdef WIN32
      }
#endif
    }
  }

  if (stream->uvstream) {
    stream->uvstream->data = stream;
  }

  stream->internal_data = NULL;
  stream->fpos = 0;
  stream->curmem = 0;
  stream->maxmem = 0;
  stream->pending_reqs = 0;
  stream->read_cb = NULL;
  stream->write_cb = NULL;
  stream->close_cb = NULL;
  stream->internal_close_cb = NULL;
  stream->closed = false;
  stream->buffer = NULL;
  stream->events = NULL;
  stream->num_bytes = 0;
}

void stream_close(Stream *stream, stream_close_cb on_stream_close, void *data)
  FUNC_ATTR_NONNULL_ARG(1)
{
  assert(!stream->closed);
  DLOG("closing Stream: %p", stream);
  stream->closed = true;
  stream->close_cb = on_stream_close;
  stream->close_cb_data = data;

  if (!stream->pending_reqs) {
    stream_close_handle(stream);
  }
}

void stream_may_close(Stream *stream)
{
  if (!stream->closed) {
    stream_close(stream, NULL, NULL);
  }
}

void stream_close_handle(Stream *stream)
  FUNC_ATTR_NONNULL_ALL
{
  if (stream->uvstream) {
    uv_close((uv_handle_t *)stream->uvstream, close_cb);
  } else {
    uv_close((uv_handle_t *)&stream->uv.idle, close_cb);
  }
}

static void close_cb(uv_handle_t *handle)
{
  Stream *stream = handle->data;
  if (stream->buffer) {
    rbuffer_free(stream->buffer);
  }
  if (stream->close_cb) {
    stream->close_cb(stream, stream->close_cb_data);
  }
  if (stream->internal_close_cb) {
    stream->internal_close_cb(stream, stream->internal_data);
  }
}
