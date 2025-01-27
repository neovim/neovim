#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include <uv.h>

#include "nvim/event/multiqueue.h"
#include "nvim/event/rstream.h"
#include "nvim/event/stream.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/rstream.c.generated.h"
#endif

void rstream_init_fd(Loop *loop, RStream *stream, int fd)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  stream_init(loop, &stream->s, fd, NULL);
  rstream_init(stream);
}

void rstream_init_stream(RStream *stream, uv_stream_t *uvstream)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  stream_init(NULL, &stream->s, -1, uvstream);
  rstream_init(stream);
}

void rstream_init(RStream *stream)
  FUNC_ATTR_NONNULL_ARG(1)
{
  stream->read_cb = NULL;
  stream->num_bytes = 0;
  stream->buffer = alloc_block();
  stream->read_pos = stream->write_pos = stream->buffer;
}

void rstream_start_inner(RStream *stream)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (stream->s.uvstream) {
    uv_read_start(stream->s.uvstream, alloc_cb, read_cb);
  } else {
    uv_idle_start(&stream->s.uv.idle, fread_idle_cb);
  }
}

/// Starts watching for events from a `Stream` instance.
///
/// @param stream The `Stream` instance
void rstream_start(RStream *stream, stream_read_cb cb, void *data)
  FUNC_ATTR_NONNULL_ARG(1)
{
  stream->read_cb = cb;
  stream->s.cb_data = data;
  stream->want_read = true;
  if (!stream->paused_full) {
    rstream_start_inner(stream);
  }
}

/// Stops watching for events from a `Stream` instance.
///
/// @param stream The `Stream` instance
void rstream_stop_inner(RStream *stream)
  FUNC_ATTR_NONNULL_ALL
{
  if (stream->s.uvstream) {
    uv_read_stop(stream->s.uvstream);
  } else {
    uv_idle_stop(&stream->s.uv.idle);
  }
}

/// Stops watching for events from a `Stream` instance.
///
/// @param stream The `Stream` instance
void rstream_stop(RStream *stream)
  FUNC_ATTR_NONNULL_ALL
{
  rstream_stop_inner(stream);
  stream->want_read = false;
}

// Callbacks used by libuv

/// Called by libuv to allocate memory for reading.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  RStream *stream = handle->data;
  buf->base = stream->write_pos;
  // `uv_buf_t.len` happens to have different size on Windows (as a treat)
  buf->len = UV_BUF_LEN(rstream_space(stream));
}

/// Callback invoked by libuv after it copies the data into the buffer provided
/// by `alloc_cb`. This is also called on EOF or when `alloc_cb` returns a
/// 0-length buffer.
static void read_cb(uv_stream_t *uvstream, ssize_t cnt, const uv_buf_t *buf)
{
  RStream *stream = uvstream->data;

  if (cnt <= 0) {
    // cnt == 0 means libuv asked for a buffer and decided it wasn't needed:
    // http://docs.libuv.org/en/latest/stream.html#c.uv_read_start.
    //
    // We don't need to do anything with the buffer because the next call
    // to `alloc_cb` will return the same unused pointer (`rbuffer_produced`
    // won't be called)
    if (cnt == UV_ENOBUFS || cnt == 0) {
      return;
    } else if (cnt == UV_EOF && uvstream->type == UV_TTY) {
      // The TTY driver might signal EOF without closing the stream
      invoke_read_cb(stream, true);
    } else {
      DLOG("closing Stream (%p): %s (%s)", (void *)stream,
           uv_err_name((int)cnt), os_strerror((int)cnt));
      // Read error or EOF, either way stop the stream and invoke the callback
      // with eof == true
      uv_read_stop(uvstream);
      invoke_read_cb(stream, true);
    }
    return;
  }

  // at this point we're sure that cnt is positive, no error occurred
  size_t nread = (size_t)cnt;
  stream->num_bytes += nread;
  stream->write_pos += cnt;
  invoke_read_cb(stream, false);
}

static size_t rstream_space(RStream *stream)
{
  return (size_t)((stream->buffer + ARENA_BLOCK_SIZE) - stream->write_pos);
}

/// Called by the by the 'idle' handle to emulate a reading event
///
/// Idle callbacks are invoked once per event loop:
///  - to perform some very low priority activity.
///  - to keep the loop "alive" (so there is always an event to process)
static void fread_idle_cb(uv_idle_t *handle)
{
  uv_fs_t req;
  RStream *stream = handle->data;

  stream->uvbuf.base = stream->write_pos;
  // `uv_buf_t.len` happens to have different size on Windows.
  stream->uvbuf.len = UV_BUF_LEN(rstream_space(stream));

  // Synchronous read
  uv_fs_read(handle->loop, &req, stream->s.fd, &stream->uvbuf, 1, stream->s.fpos, NULL);

  uv_fs_req_cleanup(&req);

  if (req.result <= 0) {
    uv_idle_stop(&stream->s.uv.idle);
    invoke_read_cb(stream, true);
    return;
  }

  // no errors (req.result (ssize_t) is positive), it's safe to use.
  stream->write_pos += req.result;
  stream->s.fpos += req.result;
  invoke_read_cb(stream, false);
}

static void read_event(void **argv)
{
  RStream *stream = argv[0];
  stream->pending_read = false;
  if (stream->read_cb) {
    size_t available = rstream_available(stream);
    size_t consumed = stream->read_cb(stream, stream->read_pos, available, stream->s.cb_data,
                                      stream->did_eof);
    assert(consumed <= available);
    rstream_consume(stream, consumed);
  }
  stream->s.pending_reqs--;
  if (stream->s.closed && !stream->s.pending_reqs) {
    stream_close_handle(&stream->s, true);
  }
}

size_t rstream_available(RStream *stream)
{
  return (size_t)(stream->write_pos - stream->read_pos);
}

void rstream_consume(RStream *stream, size_t consumed)
{
  stream->read_pos += consumed;
  size_t remaining = (size_t)(stream->write_pos - stream->read_pos);
  if (remaining > 0 && stream->read_pos > stream->buffer) {
    memmove(stream->buffer, stream->read_pos, remaining);
    stream->read_pos = stream->buffer;
    stream->write_pos = stream->buffer + remaining;
  } else if (remaining == 0) {
    stream->read_pos = stream->write_pos = stream->buffer;
  }

  if (stream->want_read && stream->paused_full && rstream_space(stream)) {
    assert(stream->read_cb);
    stream->paused_full = false;
    rstream_start_inner(stream);
  }
}

static void invoke_read_cb(RStream *stream, bool eof)
{
  stream->did_eof |= eof;

  if (!rstream_space(stream)) {
    rstream_stop_inner(stream);
    stream->paused_full = true;
  }

  // we cannot use pending_reqs as a socket can have both pending reads and writes
  if (stream->pending_read) {
    return;
  }

  // Don't let the stream be closed before the event is processed.
  stream->s.pending_reqs++;
  stream->pending_read = true;
  CREATE_EVENT(stream->s.events, read_event, stream);
}

void rstream_may_close(RStream *stream)
{
  stream_may_close(&stream->s, true);
}
