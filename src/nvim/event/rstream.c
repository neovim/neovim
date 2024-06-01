#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/event/multiqueue.h"
#include "nvim/event/rstream.h"
#include "nvim/event/stream.h"
#include "nvim/log.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/os/os_defs.h"
#include "nvim/rbuffer.h"
#include "nvim/rbuffer_defs.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/rstream.c.generated.h"
#endif

void rstream_init_fd(Loop *loop, RStream *stream, int fd, size_t bufsize)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  stream_init(loop, &stream->s, fd, NULL);
  rstream_init(stream, bufsize);
}

void rstream_init_stream(RStream *stream, uv_stream_t *uvstream, size_t bufsize)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  stream_init(NULL, &stream->s, -1, uvstream);
  rstream_init(stream, bufsize);
}

void rstream_init(RStream *stream, size_t bufsize)
  FUNC_ATTR_NONNULL_ARG(1)
{
  stream->fpos = 0;
  stream->read_cb = NULL;
  stream->num_bytes = 0;
  stream->buffer = rbuffer_new(bufsize);
  stream->buffer->data = stream;
  stream->buffer->full_cb = on_rbuffer_full;
  stream->buffer->nonfull_cb = on_rbuffer_nonfull;
}

/// Starts watching for events from a `Stream` instance.
///
/// @param stream The `Stream` instance
void rstream_start(RStream *stream, stream_read_cb cb, void *data)
  FUNC_ATTR_NONNULL_ARG(1)
{
  stream->read_cb = cb;
  stream->s.cb_data = data;
  if (stream->s.uvstream) {
    uv_read_start(stream->s.uvstream, alloc_cb, read_cb);
  } else {
    uv_idle_start(&stream->s.uv.idle, fread_idle_cb);
  }
}

/// Stops watching for events from a `Stream` instance.
///
/// @param stream The `Stream` instance
void rstream_stop(RStream *stream)
  FUNC_ATTR_NONNULL_ALL
{
  if (stream->s.uvstream) {
    uv_read_stop(stream->s.uvstream);
  } else {
    uv_idle_stop(&stream->s.uv.idle);
  }
}

static void on_rbuffer_full(RBuffer *buf, void *data)
{
  rstream_stop(data);
}

static void on_rbuffer_nonfull(RBuffer *buf, void *data)
{
  RStream *stream = data;
  assert(stream->read_cb);
  rstream_start(stream, stream->read_cb, stream->s.cb_data);
}

// Callbacks used by libuv

/// Called by libuv to allocate memory for reading.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  RStream *stream = handle->data;
  // `uv_buf_t.len` happens to have different size on Windows.
  size_t write_count;
  buf->base = rbuffer_write_ptr(stream->buffer, &write_count);
  buf->len = UV_BUF_LEN(write_count);
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
    // We don't need to do anything with the RBuffer because the next call
    // to `alloc_cb` will return the same unused pointer (`rbuffer_produced`
    // won't be called)
    if (cnt == UV_ENOBUFS || cnt == 0) {
      return;
    } else if (cnt == UV_EOF && uvstream->type == UV_TTY) {
      // The TTY driver might signal EOF without closing the stream
      invoke_read_cb(stream, 0, true);
    } else {
      DLOG("closing Stream (%p): %s (%s)", (void *)stream,
           uv_err_name((int)cnt), os_strerror((int)cnt));
      // Read error or EOF, either way stop the stream and invoke the callback
      // with eof == true
      uv_read_stop(uvstream);
      invoke_read_cb(stream, 0, true);
    }
    return;
  }

  // at this point we're sure that cnt is positive, no error occurred
  size_t nread = (size_t)cnt;
  stream->num_bytes += nread;
  // Data was already written, so all we need is to update 'wpos' to reflect
  // the space actually used in the buffer.
  rbuffer_produced(stream->buffer, nread);
  invoke_read_cb(stream, nread, false);
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

  // `uv_buf_t.len` happens to have different size on Windows.
  size_t write_count;
  stream->uvbuf.base = rbuffer_write_ptr(stream->buffer, &write_count);
  stream->uvbuf.len = UV_BUF_LEN(write_count);

  // the offset argument to uv_fs_read is int64_t, could someone really try
  // to read more than 9 quintillion (9e18) bytes?
  // upcast is meant to avoid tautological condition warning on 32 bits
  uintmax_t fpos_intmax = stream->fpos;
  if (fpos_intmax > INT64_MAX) {
    ELOG("stream offset overflow");
    preserve_exit("stream offset overflow");
  }

  // Synchronous read
  uv_fs_read(handle->loop,
             &req,
             stream->s.fd,
             &stream->uvbuf,
             1,
             (int64_t)stream->fpos,
             NULL);

  uv_fs_req_cleanup(&req);

  if (req.result <= 0) {
    uv_idle_stop(&stream->s.uv.idle);
    invoke_read_cb(stream, 0, true);
    return;
  }

  // no errors (req.result (ssize_t) is positive), it's safe to cast.
  size_t nread = (size_t)req.result;
  rbuffer_produced(stream->buffer, nread);
  stream->fpos += nread;
  invoke_read_cb(stream, nread, false);
}

static void read_event(void **argv)
{
  RStream *stream = argv[0];
  if (stream->read_cb) {
    size_t count = (uintptr_t)argv[1];
    bool eof = (uintptr_t)argv[2];
    stream->did_eof = eof;
    stream->read_cb(stream, stream->buffer, count, stream->s.cb_data, eof);
  }
  stream->s.pending_reqs--;
  if (stream->s.closed && !stream->s.pending_reqs) {
    stream_close_handle(&stream->s, true);
  }
}

static void invoke_read_cb(RStream *stream, size_t count, bool eof)
{
  // Don't let the stream be closed before the event is processed.
  stream->s.pending_reqs++;

  CREATE_EVENT(stream->s.events, read_event,
               stream, (void *)(uintptr_t *)count, (void *)(uintptr_t)eof);
}

void rstream_may_close(RStream *stream)
{
  stream_may_close(&stream->s, true);
}
