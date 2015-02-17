#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/uv_helpers.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/rstream.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/log.h"
#include "nvim/misc1.h"

struct rbuffer {
  char *data;
  size_t capacity, rpos, wpos;
  RStream *rstream;
};

struct rstream {
  void *data;
  uv_buf_t uvbuf;
  size_t fpos;
  RBuffer *buffer;
  uv_stream_t *stream;
  uv_idle_t *fread_idle;
  uv_handle_type file_type;
  uv_file fd;
  rstream_cb cb;
  bool free_handle;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/rstream.c.generated.h"
#endif

/// Creates a new `RBuffer` instance.
RBuffer *rbuffer_new(size_t capacity)
{
  RBuffer *rv = xmalloc(sizeof(RBuffer));
  rv->data = xmalloc(capacity);
  rv->capacity = capacity;
  rv->rpos = rv->wpos = 0;
  rv->rstream = NULL;
  return rv;
}

/// Advances `rbuffer` read pointers to consume data. If the associated
/// RStream had stopped because the buffer was full, this will restart it.
///
/// This is called automatically by rbuffer_read, but when using
/// `rbuffer_read_ptr` directly, this needs to called after the data was
/// consumed.
void rbuffer_consumed(RBuffer *rbuffer, size_t count)
{
  rbuffer->rpos += count;
  if (count && rbuffer->wpos == rbuffer->capacity) {
    // `wpos` is at the end of the buffer, so free some space by moving unread
    // data...
    rbuffer_relocate(rbuffer);
    if (rbuffer->rstream) {
      // restart the associated RStream
      rstream_start(rbuffer->rstream);
    }
  }
}

/// Advances `rbuffer` write pointers. If the internal buffer becomes full,
/// this will stop the associated RStream instance.
void rbuffer_produced(RBuffer *rbuffer, size_t count)
{
  rbuffer->wpos += count;
  DLOG("Received %u bytes from RStream(%p)", (size_t)count, rbuffer->rstream);

  rbuffer_relocate(rbuffer);
  if (rbuffer->rstream && rbuffer->wpos == rbuffer->capacity) {
    // The last read filled the buffer, stop reading for now
    //
    rstream_stop(rbuffer->rstream);
    DLOG("Buffer for RStream(%p) is full, stopping it", rbuffer->rstream);
  }
}

/// Reads data from a `RBuffer` instance into a raw buffer.
///
/// @param rbuffer The `RBuffer` instance
/// @param buffer The buffer which will receive the data
/// @param count Number of bytes that `buffer` can accept
/// @return The number of bytes copied into `buffer`
size_t rbuffer_read(RBuffer *rbuffer, char *buffer, size_t count)
{
  size_t read_count = rbuffer_pending(rbuffer);

  if (count < read_count) {
    read_count = count;
  }

  if (read_count > 0) {
    memcpy(buffer, rbuffer_read_ptr(rbuffer), read_count);
    rbuffer_consumed(rbuffer, read_count);
  }

  return read_count;
}

/// Copies data to `rbuffer` read queue.
///
/// @param rbuffer the `RBuffer` instance
/// @param buffer The buffer containing data to be copied
/// @param count Number of bytes that should be copied
/// @return The number of bytes actually copied
size_t rbuffer_write(RBuffer *rbuffer, char *buffer, size_t count)
{
  size_t write_count = rbuffer_available(rbuffer);

  if (count < write_count) {
    write_count = count;
  }

  if (write_count > 0) {
    memcpy(rbuffer_write_ptr(rbuffer), buffer, write_count);
    rbuffer_produced(rbuffer, write_count);
  }

  return write_count;
}

/// Returns a pointer to a raw buffer containing the first byte available for
/// reading.
char *rbuffer_read_ptr(RBuffer *rbuffer)
{
  return rbuffer->data + rbuffer->rpos;
}

/// Returns a pointer to a raw buffer containing the first byte available for
/// write.
char *rbuffer_write_ptr(RBuffer *rbuffer)
{
  return rbuffer->data + rbuffer->wpos;
}

/// Returns the number of bytes ready for consumption in `rbuffer`
///
/// @param rbuffer The `RBuffer` instance
/// @return The number of bytes ready for consumption
size_t rbuffer_pending(RBuffer *rbuffer)
{
  return rbuffer->wpos - rbuffer->rpos;
}

/// Returns available space in `rbuffer`
///
/// @param rbuffer The `RBuffer` instance
/// @return The space available in number of bytes
size_t rbuffer_available(RBuffer *rbuffer)
{
  return rbuffer->capacity - rbuffer->wpos;
}

void rbuffer_free(RBuffer *rbuffer)
{
  free(rbuffer->data);
  free(rbuffer);
}

/// Creates a new RStream instance. A RStream encapsulates all the boilerplate
/// necessary for reading from a libuv stream.
///
/// @param cb A function that will be called whenever some data is available
///        for reading with `rstream_read`
/// @param buffer RBuffer instance to associate with the RStream
/// @param data Some state to associate with the `RStream` instance
/// @return The newly-allocated `RStream` instance
RStream * rstream_new(rstream_cb cb, RBuffer *buffer, void *data)
{
  RStream *rv = xmalloc(sizeof(RStream));
  rv->buffer = buffer;
  rv->buffer->rstream = rv;
  rv->fpos = 0;
  rv->data = data;
  rv->cb = cb;
  rv->stream = NULL;
  rv->fread_idle = NULL;
  rv->free_handle = false;
  rv->file_type = UV_UNKNOWN_HANDLE;

  return rv;
}

/// Returns the read pointer used by the rstream.
char *rstream_read_ptr(RStream *rstream)
{
  return rbuffer_read_ptr(rstream->buffer);
}

/// Returns the number of bytes before the rstream is full.
size_t rstream_available(RStream *rstream)
{
  return rbuffer_available(rstream->buffer);
}

/// Frees all memory allocated for a RStream instance
///
/// @param rstream The `RStream` instance
void rstream_free(RStream *rstream)
{
  if (rstream->free_handle) {
    if (rstream->fread_idle != NULL) {
      uv_close((uv_handle_t *)rstream->fread_idle, close_cb);
    } else {
      uv_close((uv_handle_t *)rstream->stream, close_cb);
    }
  }

  rbuffer_free(rstream->buffer);
  free(rstream);
}

/// Sets the underlying `uv_stream_t` instance
///
/// @param rstream The `RStream` instance
/// @param stream The new `uv_stream_t` instance
void rstream_set_stream(RStream *rstream, uv_stream_t *stream)
{
  handle_set_rstream((uv_handle_t *)stream, rstream);
  rstream->stream = stream;
}

/// Sets the underlying file descriptor that will be read from. Only pipes
/// and regular files are supported for now.
///
/// @param rstream The `RStream` instance
/// @param file The file descriptor
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
    // Non-blocking file reads are simulated with an idle handle that reads
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

/// Starts watching for events from a `RStream` instance.
///
/// @param rstream The `RStream` instance
void rstream_start(RStream *rstream)
{
  if (rstream->file_type == UV_FILE) {
    uv_idle_start(rstream->fread_idle, fread_idle_cb);
  } else {
    uv_read_start(rstream->stream, alloc_cb, read_cb);
  }
}

/// Stops watching for events from a `RStream` instance.
///
/// @param rstream The `RStream` instance
void rstream_stop(RStream *rstream)
{
  if (rstream->file_type == UV_FILE) {
    uv_idle_stop(rstream->fread_idle);
  } else {
    uv_read_stop(rstream->stream);
  }
}

/// Returns the number of bytes ready for consumption in `rstream`
size_t rstream_pending(RStream *rstream)
{
  return rbuffer_pending(rstream->buffer);
}

/// Reads data from a `RStream` instance into a buffer.
///
/// @param rstream The `RStream` instance
/// @param buffer The buffer which will receive the data
/// @param count Number of bytes that `buffer` can accept
/// @return The number of bytes copied into `buffer`
size_t rstream_read(RStream *rstream, char *buffer, size_t count)
{
  return rbuffer_read(rstream->buffer, buffer, count);
}

RBuffer *rstream_buffer(RStream *rstream)
{
  return rstream->buffer;
}

// Callbacks used by libuv

// Called by libuv to allocate memory for reading.
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf)
{
  RStream *rstream = handle_get_rstream(handle);

  buf->len = rbuffer_available(rstream->buffer);
  buf->base = rbuffer_write_ptr(rstream->buffer);
}

// Callback invoked by libuv after it copies the data into the buffer provided
// by `alloc_cb`. This is also called on EOF or when `alloc_cb` returns a
// 0-length buffer.
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf)
{
  RStream *rstream = handle_get_rstream((uv_handle_t *)stream);

  if (cnt <= 0) {
    if (cnt != UV_ENOBUFS) {
      DLOG("Closing RStream(%p)", rstream);
      // Read error or EOF, either way stop the stream and invoke the callback
      // with eof == true
      uv_read_stop(stream);
      rstream->cb(rstream, rstream->data, true);
    }
    return;
  }

  // at this point we're sure that cnt is positive, no error occurred
  size_t nread = (size_t) cnt;

  // Data was already written, so all we need is to update 'wpos' to reflect
  // the space actually used in the buffer.
  rbuffer_produced(rstream->buffer, nread);
  rstream->cb(rstream, rstream->data, false);
}

// Called by the by the 'idle' handle to emulate a reading event
static void fread_idle_cb(uv_idle_t *handle)
{
  uv_fs_t req;
  RStream *rstream = handle_get_rstream((uv_handle_t *)handle);

  rstream->uvbuf.len = rbuffer_available(rstream->buffer);
  rstream->uvbuf.base = rbuffer_write_ptr(rstream->buffer);

  // the offset argument to uv_fs_read is int64_t, could someone really try
  // to read more than 9 quintillion (9e18) bytes?
  // upcast is meant to avoid tautological condition warning on 32 bits
  uintmax_t fpos_intmax = rstream->fpos;
  if (fpos_intmax > INT64_MAX) {
    ELOG("stream offset overflow");
    preserve_exit();
  }

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
    return;
  }

  // no errors (req.result (ssize_t) is positive), it's safe to cast.
  size_t nread = (size_t) req.result;
  rbuffer_produced(rstream->buffer, nread);
  rstream->fpos += nread;
}

static void close_cb(uv_handle_t *handle)
{
  free(handle->data);
  free(handle);
}

static void rbuffer_relocate(RBuffer *rbuffer)
{
  assert(rbuffer->rpos <= rbuffer->wpos);
  // Move data ...
  memmove(
      rbuffer->data,  // ...to the beginning of the buffer(rpos 0)
      rbuffer->data + rbuffer->rpos,  // ...From the first unread position
      rbuffer->wpos - rbuffer->rpos);  // ...By the number of unread bytes
  rbuffer->wpos -= rbuffer->rpos;
  rbuffer->rpos = 0;
}
