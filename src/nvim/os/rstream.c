#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/uv_helpers.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/rstream.h"
#include "nvim/os/event_defs.h"
#include "nvim/os/event.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

struct rstream {
  uv_buf_t uvbuf;
  void *data;
  char *buffer;
  uv_stream_t *stream;
  uv_idle_t *fread_idle;
  uv_handle_type file_type;
  uv_file fd;
  rstream_cb cb;
  size_t buffer_size, rpos, wpos, fpos;
  bool reading, free_handle, async;
};

// Callbacks used by libuv
static void alloc_cb(uv_handle_t *, size_t, uv_buf_t *);
static void read_cb(uv_stream_t *, ssize_t, const uv_buf_t *);
static void fread_idle_cb(uv_idle_t *);
static void close_cb(uv_handle_t *handle);
static void emit_read_event(RStream *rstream, bool eof);

RStream * rstream_new(rstream_cb cb,
                      uint32_t buffer_size,
                      void *data,
                      bool async)
{
  RStream *rv = xmalloc(sizeof(RStream));
  rv->buffer = xmalloc(buffer_size);
  rv->buffer_size = buffer_size;
  rv->data = data;
  rv->async = async;
  rv->cb = cb;
  rv->rpos = rv->wpos = rv->fpos = 0;
  rv->stream = NULL;
  rv->fread_idle = NULL;
  rv->free_handle = false;
  rv->file_type = UV_UNKNOWN_HANDLE;

  return rv;
}

void rstream_free(RStream *rstream)
{
  if (rstream->free_handle) {
    if (rstream->fread_idle != NULL) {
      uv_close((uv_handle_t *)rstream->fread_idle, close_cb);
    } else {
      uv_close((uv_handle_t *)rstream->stream, close_cb);
    }
  }

  free(rstream->buffer);
  free(rstream);
}

void rstream_set_stream(RStream *rstream, uv_stream_t *stream)
{
  handle_set_rstream((uv_handle_t *)stream, rstream);
  rstream->stream = stream;
}

void rstream_set_file(RStream *rstream, uv_file file)
{
  rstream->file_type = uv_guess_handle(file);

  if (rstream->free_handle) {
    // If this is the second time we're calling this function, free the
    // previously allocated memory
    if (rstream->fread_idle != NULL) {
      uv_close((uv_handle_t *)rstream->fread_idle, close_cb);
    } else {
      uv_close((uv_handle_t *)rstream->stream, close_cb);
    }
  }

  if (rstream->file_type == UV_FILE) {
    // Non-blocking file reads are simulated with a idle handle that reads
    // in chunks of rstream->buffer_size, giving time for other events to
    // be processed between reads.
    rstream->fread_idle = xmalloc(sizeof(uv_idle_t));
    uv_idle_init(uv_default_loop(), rstream->fread_idle);
    rstream->fread_idle->data = NULL;
    handle_set_rstream((uv_handle_t *)rstream->fread_idle, rstream);
  } else {
    // Only pipes are supported for now
    assert(rstream->file_type == UV_NAMED_PIPE
        || rstream->file_type == UV_TTY);
    rstream->stream = xmalloc(sizeof(uv_pipe_t));
    uv_pipe_init(uv_default_loop(), (uv_pipe_t *)rstream->stream, 0);
    uv_pipe_open((uv_pipe_t *)rstream->stream, file);
    rstream->stream->data = NULL;
    handle_set_rstream((uv_handle_t *)rstream->stream, rstream);
  }

  rstream->fd = file;
  rstream->free_handle = true;
}

bool rstream_is_regular_file(RStream *rstream)
{
  return rstream->file_type == UV_FILE;
}

void rstream_start(RStream *rstream)
{
  if (rstream->file_type == UV_FILE) {
    uv_idle_start(rstream->fread_idle, fread_idle_cb);
  } else {
    rstream->reading = false;
    uv_read_start(rstream->stream, alloc_cb, read_cb);
  }
}

void rstream_stop(RStream *rstream)
{
  if (rstream->file_type == UV_FILE) {
    uv_idle_stop(rstream->fread_idle);
  } else {
    uv_read_stop(rstream->stream);
  }
}

size_t rstream_read(RStream *rstream, char *buf, uint32_t count)
{
  size_t read_count = rstream->wpos - rstream->rpos;

  if (count < read_count) {
    read_count = count;
  }

  if (read_count > 0) {
    memcpy(buf, rstream->buffer + rstream->rpos, read_count);
    rstream->rpos += read_count;
  }

  if (rstream->wpos == rstream->buffer_size) {
    // `wpos` is at the end of the buffer, so free some space by moving unread
    // data...
    memmove(
        rstream->buffer,  // ...To the beginning of the buffer(rpos 0)
        rstream->buffer + rstream->rpos,  // ...From the first unread position
        rstream->wpos - rstream->rpos);  // ...By the number of unread bytes
    rstream->wpos -= rstream->rpos;
    rstream->rpos = 0;

    if (rstream->wpos < rstream->buffer_size) {
      // Restart reading since we have freed some space
      rstream_start(rstream);
    }
  }

  return read_count;
}

size_t rstream_available(RStream *rstream)
{
  return rstream->wpos - rstream->rpos;
}

void rstream_read_event(Event event)
{
  RStream *rstream = event.data.rstream.ptr;

  rstream->cb(rstream, rstream->data, event.data.rstream.eof);
}

// Called by libuv to allocate memory for reading.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  RStream *rstream = handle_get_rstream(handle);

  if (rstream->reading) {
    buf->len = 0;
    return;
  }

  buf->len = rstream->buffer_size - rstream->wpos;
  buf->base = rstream->buffer + rstream->wpos;

  // Avoid `alloc_cb`, `alloc_cb` sequences on windows
  rstream->reading = true;
}

// Callback invoked by libuv after it copies the data into the buffer provided
// by `alloc_cb`. This is also called on EOF or when `alloc_cb` returns a
// 0-length buffer.
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  RStream *rstream = handle_get_rstream((uv_handle_t *)stream);

  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS) {
      // Read error or EOF, either way stop the stream and invoke the callback
      // with eof == true
      uv_read_stop(stream);
      emit_read_event(rstream, true);
    }
    return;
  }

  // at this point we're sure that cnt is positive, no error occurred
  size_t nread = (size_t) cnt;

  // Data was already written, so all we need is to update 'wpos' to reflect
  // the space actually used in the buffer.
  rstream->wpos += nread;

  if (rstream->wpos == rstream->buffer_size) {
    // The last read filled the buffer, stop reading for now
    rstream_stop(rstream);
  }

  rstream->reading = false;
  emit_read_event(rstream, false);
}

// Called by the by the 'idle' handle to emulate a reading event
static void fread_idle_cb(uv_idle_t *handle)
{
  uv_fs_t req;
  RStream *rstream = handle_get_rstream((uv_handle_t *)handle);

  rstream->uvbuf.base = rstream->buffer + rstream->wpos;
  rstream->uvbuf.len = rstream->buffer_size - rstream->wpos;

  // the offset argument to uv_fs_read is int64_t, could someone really try
  // to read more than 9 quintillion (9e18) bytes?
  // upcast is meant to avoid tautological condition warning on 32 bits
  uintmax_t fpos_intmax = rstream->fpos;
  assert(fpos_intmax <= INT64_MAX);

  // Synchronous read
  uv_fs_read(
      uv_default_loop(),
      &req,
      rstream->fd,
      &rstream->uvbuf,
      1,
      (int64_t) rstream->fpos,
      NULL);

  uv_fs_req_cleanup(&req);

  if (req.result <= 0) {
    uv_idle_stop(rstream->fread_idle);
    emit_read_event(rstream, true);
    return;
  }

  // no errors (req.result (ssize_t) is positive), it's safe to cast.
  size_t nread = (size_t) req.result;

  rstream->wpos += nread;
  rstream->fpos += nread;

  if (rstream->wpos == rstream->buffer_size) {
    // The last read filled the buffer, stop reading for now
    rstream_stop(rstream);
  }

  emit_read_event(rstream, false);
}

static void close_cb(uv_handle_t *handle)
{
  free(handle->data);
  free(handle);
}

static void emit_read_event(RStream *rstream, bool eof)
{
  if (rstream->async) {
    Event event;

    event.type = kEventRStreamData;
    event.data.rstream.ptr = rstream;
    event.data.rstream.eof = eof;
    event_push(event);
  } else {
    // Invoke the callback passing in the number of bytes available and data
    // associated with the stream
    rstream->cb(rstream, rstream->data, eof);
  }
}
