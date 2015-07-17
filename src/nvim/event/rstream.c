#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/event/rstream.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/log.h"
#include "nvim/misc1.h"
#include "nvim/event/loop.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/rstream.c.generated.h"
#endif

void rstream_init_fd(Loop *loop, Stream *stream, int fd, size_t bufsize,
    void *data)
  FUNC_ATTR_NONNULL_ARG(1)
  FUNC_ATTR_NONNULL_ARG(2)
{
  stream_init(loop, stream, fd, NULL, data);
  rstream_init(stream, bufsize);
}

void rstream_init_stream(Stream *stream, uv_stream_t *uvstream, size_t bufsize,
    void *data)
  FUNC_ATTR_NONNULL_ARG(1)
  FUNC_ATTR_NONNULL_ARG(2)
{
  stream_init(NULL, stream, -1, uvstream, data);
  rstream_init(stream, bufsize);
}

void rstream_init(Stream *stream, size_t bufsize)
  FUNC_ATTR_NONNULL_ARG(1)
{
  stream->buffer = rbuffer_new(bufsize);
  stream->buffer->data = stream;
  stream->buffer->full_cb = on_rbuffer_full;
  stream->buffer->nonfull_cb = on_rbuffer_nonfull;
}


/// Starts watching for events from a `Stream` instance.
///
/// @param stream The `Stream` instance
void rstream_start(Stream *stream, stream_read_cb cb)
{
  stream->read_cb = cb;
  if (stream->uvstream) {
    uv_read_start(stream->uvstream, alloc_cb, read_cb);
  } else {
    uv_idle_start(&stream->uv.idle, fread_idle_cb);
  }
}

/// Stops watching for events from a `Stream` instance.
///
/// @param stream The `Stream` instance
void rstream_stop(Stream *stream)
{
  if (stream->uvstream) {
    uv_read_stop(stream->uvstream);
  } else {
    uv_idle_stop(&stream->uv.idle);
  }
}

static void on_rbuffer_full(RBuffer *buf, void *data)
{
  rstream_stop(data);
}

static void on_rbuffer_nonfull(RBuffer *buf, void *data)
{
  Stream *stream = data;
  assert(stream->read_cb);
  rstream_start(stream, stream->read_cb);
}

// Callbacks used by libuv

// Called by libuv to allocate memory for reading.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  Stream *stream = handle->data;
  buf->base = rbuffer_write_ptr(stream->buffer, &buf->len);
}

// Callback invoked by libuv after it copies the data into the buffer provided
// by `alloc_cb`. This is also called on EOF or when `alloc_cb` returns a
// 0-length buffer.
static void read_cb(uv_stream_t *uvstream, ssize_t cnt, const uv_buf_t *buf)
{
  Stream *stream = uvstream->data;

  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS
        // cnt == 0 means libuv asked for a buffer and decided it wasn't needed:
        // http://docs.libuv.org/en/latest/stream.html#c.uv_read_start.
        //
        // We don't need to do anything with the RBuffer because the next call
        // to `alloc_cb` will return the same unused pointer(`rbuffer_produced`
        // won't be called)
        && cnt != 0) {
      DLOG("Closing Stream(%p) because of %s(%zd)", stream,
           uv_strerror((int)cnt), cnt);
      // Read error or EOF, either way stop the stream and invoke the callback
      // with eof == true
      uv_read_stop(uvstream);
      stream->read_cb(stream, stream->buffer, stream->data, true);
    }
    return;
  }

  // at this point we're sure that cnt is positive, no error occurred
  size_t nread = (size_t)cnt;
  // Data was already written, so all we need is to update 'wpos' to reflect
  // the space actually used in the buffer.
  rbuffer_produced(stream->buffer, nread);
  stream->read_cb(stream, stream->buffer, stream->data, false);
}

// Called by the by the 'idle' handle to emulate a reading event
static void fread_idle_cb(uv_idle_t *handle)
{
  uv_fs_t req;
  Stream *stream = handle->data;

  stream->uvbuf.base = rbuffer_write_ptr(stream->buffer, &stream->uvbuf.len);

  // the offset argument to uv_fs_read is int64_t, could someone really try
  // to read more than 9 quintillion (9e18) bytes?
  // upcast is meant to avoid tautological condition warning on 32 bits
  uintmax_t fpos_intmax = stream->fpos;
  if (fpos_intmax > INT64_MAX) {
    ELOG("stream offset overflow");
    preserve_exit();
  }

  // Synchronous read
  uv_fs_read(
      handle->loop,
      &req,
      stream->fd,
      &stream->uvbuf,
      1,
      (int64_t) stream->fpos,
      NULL);

  uv_fs_req_cleanup(&req);

  if (req.result <= 0) {
    uv_idle_stop(&stream->uv.idle);
    stream->read_cb(stream, stream->buffer, stream->data, true);
    return;
  }

  // no errors (req.result (ssize_t) is positive), it's safe to cast.
  size_t nread = (size_t) req.result;
  rbuffer_produced(stream->buffer, nread);
  stream->fpos += nread;
}
