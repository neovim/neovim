#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <uv.h>
#include <uv/version.h>

#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/stream.h"
#include "nvim/log.h"
#include "nvim/memory.h"
#include "nvim/types_defs.h"
#ifdef MSWIN
# include "nvim/os/os_win_console.h"
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/stream.c.generated.h"
#endif

// For compatibility with libuv < 1.19.0 (tested on 1.18.0)
#if UV_VERSION_MINOR < 19
# define uv_stream_get_write_queue_size(stream) stream->write_queue_size
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
  int retval = uv_stream_set_blocking((uv_stream_t *)&stream, blocking);
  uv_close((uv_handle_t *)&stream, NULL);
  uv_run(&loop, UV_RUN_NOWAIT);  // not necessary, but couldn't hurt.
  uv_loop_close(&loop);
  return retval;
}

void stream_init(Loop *loop, Stream *stream, int fd, uv_stream_t *uvstream)
  FUNC_ATTR_NONNULL_ARG(2)
{
  // The underlying stream is either a file or an existing uv stream.
  assert(uvstream == NULL ? fd >= 0 : fd < 0);
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
#ifdef MSWIN
      if (type == UV_TTY) {
        uv_tty_init(&loop->uv, &stream->uv.tty, fd, 0);
        uv_tty_set_mode(&stream->uv.tty, UV_TTY_MODE_RAW);
        DWORD dwMode;
        if (GetConsoleMode(stream->uv.tty.handle, &dwMode)) {
          dwMode |= ENABLE_VIRTUAL_TERMINAL_INPUT;
          SetConsoleMode(stream->uv.tty.handle, dwMode);
        }
        stream->uvstream = (uv_stream_t *)&stream->uv.tty;
      } else {
#endif
      uv_pipe_init(&loop->uv, &stream->uv.pipe, 0);
      uv_pipe_open(&stream->uv.pipe, fd);
      stream->uvstream = (uv_stream_t *)&stream->uv.pipe;
#ifdef MSWIN
    }
#endif
    }
  }

  if (stream->uvstream) {
    stream->uvstream->data = stream;
  }

  stream->fpos = 0;
  stream->internal_data = NULL;
  stream->curmem = 0;
  stream->maxmem = 0;
  stream->pending_reqs = 0;
  stream->write_cb = NULL;
  stream->close_cb = NULL;
  stream->internal_close_cb = NULL;
  stream->closed = false;
  stream->events = NULL;
}

void stream_may_close(Stream *stream, bool rstream)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (stream->closed) {
    return;
  }
  assert(!stream->closed);
  DLOG("closing Stream: %p", (void *)stream);
  stream->closed = true;
  stream->close_cb = NULL;
  stream->close_cb_data = NULL;

#ifdef MSWIN
  if (UV_TTY == uv_guess_handle(stream->fd)) {
    // Undo UV_TTY_MODE_RAW from stream_init(). #10801
    uv_tty_set_mode(&stream->uv.tty, UV_TTY_MODE_NORMAL);
  }
#endif

  if (!stream->pending_reqs) {
    stream_close_handle(stream, rstream);
  }
}

void stream_close_handle(Stream *stream, bool rstream)
  FUNC_ATTR_NONNULL_ALL
{
  uv_handle_t *handle = NULL;
  if (stream->uvstream) {
    if (uv_stream_get_write_queue_size(stream->uvstream) > 0) {
      WLOG("closed Stream (%p) with %zu unwritten bytes",
           (void *)stream,
           uv_stream_get_write_queue_size(stream->uvstream));
    }
    handle = (uv_handle_t *)stream->uvstream;
  } else {
    handle = (uv_handle_t *)&stream->uv.idle;
  }

  assert(handle != NULL);

  if (!uv_is_closing(handle)) {
    uv_close(handle, rstream ? rstream_close_cb : close_cb);
  }
}

static void rstream_close_cb(uv_handle_t *handle)
{
  RStream *stream = handle->data;
  if (stream->buffer) {
    free_block(stream->buffer);
  }
  close_cb(handle);
}

static void close_cb(uv_handle_t *handle)
{
  Stream *stream = handle->data;
  if (stream->close_cb) {
    stream->close_cb(stream, stream->close_cb_data);
  }
  if (stream->internal_close_cb) {
    stream->internal_close_cb(stream, stream->internal_data);
  }
}
