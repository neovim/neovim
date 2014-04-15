#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "os/rstream_defs.h"
#include "os/rstream.h"
#include "vim.h"
#include "memory.h"

struct rstream {
  uv_buf_t uvbuf;
  void *data;
  char *buffer;
  uv_stream_t *stream;
  uv_idle_t *fread_idle;
  uv_handle_type file_type;
  uv_file fd;
  rstream_cb cb;
  uint32_t buffer_size, rpos, wpos, fpos;
  bool reading, free_handle;
};

// Callbacks used by libuv
static void alloc_cb(uv_handle_t *, size_t, uv_buf_t *);
static void read_cb(uv_stream_t *, ssize_t, const uv_buf_t *);
static void fread_idle_cb(uv_idle_t *);

RStream * rstream_new(rstream_cb cb, uint32_t buffer_size, void *data)
{
  RStream *rv = xmalloc(sizeof(RStream));
  rv->buffer = xmalloc(buffer_size);
  rv->buffer_size = buffer_size;
  rv->data = data;
  rv->cb = cb;
  rv->rpos = rv->wpos = rv->fpos = 0;
  rv->stream = NULL;
  rv->fread_idle = NULL;
  rv->free_handle = false;

  return rv;
}

void rstream_free(RStream *rstream)
{
  if (rstream->free_handle) {
    if (rstream->fread_idle != NULL) {
      uv_close((uv_handle_t *)rstream->fread_idle, NULL);
      free(rstream->fread_idle);
    } else {
      uv_close((uv_handle_t *)rstream->stream, NULL);
      free(rstream->stream);
    }
  }

  free(rstream->buffer);
  free(rstream);
}

void rstream_set_stream(RStream *rstream, uv_stream_t *stream)
{
  stream->data = rstream;
  rstream->stream = stream;
}

void rstream_set_file(RStream *rstream, uv_file file)
{
  rstream->file_type = uv_guess_handle(file);

  if (rstream->free_handle) {
    // If this is the second time we're calling this function, free the
    // previously allocated memory
    if (rstream->fread_idle != NULL) {
      uv_close((uv_handle_t *)rstream->fread_idle, NULL);
      free(rstream->fread_idle);
    } else {
      uv_close((uv_handle_t *)rstream->stream, NULL);
      free(rstream->stream);
    }
  }

  if (rstream->file_type == UV_FILE) {
    // Non-blocking file reads are simulated with a idle handle that reads
    // in chunks of rstream->buffer_size, giving time for other events to
    // be processed between reads.
    rstream->fread_idle = xmalloc(sizeof(uv_idle_t));
    uv_idle_init(uv_default_loop(), rstream->fread_idle);
    rstream->fread_idle->data = rstream;
  } else {
    // Only pipes are supported for now
    assert(rstream->file_type == UV_NAMED_PIPE
        || rstream->file_type == UV_TTY);
    rstream->stream = xmalloc(sizeof(uv_pipe_t));
    uv_pipe_init(uv_default_loop(), (uv_pipe_t *)rstream->stream, 0);
    uv_pipe_open((uv_pipe_t *)rstream->stream, file);
    rstream->stream->data = rstream;
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

uint32_t rstream_read(RStream *rstream, char *buf, uint32_t count)
{
  uint32_t read_count = rstream->wpos - rstream->rpos;

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
  }

  return read_count;
}

uint32_t rstream_available(RStream *rstream)
{
  return rstream->wpos - rstream->rpos;
}

// Called by libuv to allocate memory for reading.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  RStream *rstream = handle->data;

  if (rstream->reading) {
    buf->len = 0;
    return;
  }

  buf->base = rstream->buffer + rstream->wpos;
  buf->len = rstream->buffer_size - rstream->wpos;
  // Avoid `alloc_cb`, `alloc_cb` sequences on windows
  rstream->reading = true;
}

// Callback invoked by libuv after it copies the data into the buffer provided
// by `alloc_cb`. This is also called on EOF or when `alloc_cb` returns a
// 0-length buffer.
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  RStream *rstream = stream->data;

  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS) {
      // Read error or EOF, either way stop the stream and invoke the callback
      // with eof == true
      uv_read_stop(stream);
      rstream->cb(rstream, rstream->data, true);
    }
    return;
  }

  // Data was already written, so all we need is to update 'wpos' to reflect
  // the space actually used in the buffer.
  rstream->wpos += cnt;
  // Invoke the callback passing in the number of bytes available and data
  // associated with the stream
  rstream->cb(rstream, rstream->data, false);
  rstream->reading = false;
}

// Called by the by the 'idle' handle to emulate a reading event
static void fread_idle_cb(uv_idle_t *handle)
{
  uv_fs_t req;
  RStream *rstream = handle->data;

  rstream->uvbuf.base = rstream->buffer + rstream->wpos;
  rstream->uvbuf.len = rstream->buffer_size - rstream->wpos;

  // Synchronous read
  uv_fs_read(
      uv_default_loop(),
      &req,
      rstream->fd,
      &rstream->uvbuf,
      1,
      rstream->fpos,
      NULL);

  uv_fs_req_cleanup(&req);

  if (req.result <= 0) {
    uv_idle_stop(rstream->fread_idle);
    rstream->cb(rstream, rstream->data, true);
    return;
  }

  rstream->wpos += req.result;
  rstream->fpos += req.result;
  rstream->cb(rstream, rstream->data, false);
}
