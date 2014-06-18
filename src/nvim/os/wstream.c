#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "nvim/os/uv_helpers.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

struct wstream {
  uv_stream_t *stream;
  // Memory currently used by pending buffers
  size_t curmem;
  // Maximum memory used by this instance
  size_t maxmem;
  // Number of pending requests
  size_t pending_reqs;
  bool freed;
};

struct wbuffer {
  size_t size, refcount;
  char *data;
  wbuffer_data_finalizer cb;
};

typedef struct {
  WStream *wstream;
  WBuffer *buffer;
} WriteData;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/wstream.c.generated.h"
#endif

/// Creates a new WStream instance. A WStream encapsulates all the boilerplate
/// necessary for writing to a libuv stream.
///
/// @param maxmem Maximum amount memory used by this `WStream` instance.
/// @return The newly-allocated `WStream` instance
WStream * wstream_new(size_t maxmem)
{
  WStream *rv = xmalloc(sizeof(WStream));
  rv->maxmem = maxmem;
  rv->stream = NULL;
  rv->curmem = 0;
  rv->pending_reqs = 0;
  rv->freed = false;

  return rv;
}

/// Frees all memory allocated for a WStream instance
///
/// @param wstream The `WStream` instance
void wstream_free(WStream *wstream)
{
  if (!wstream->pending_reqs) {
    free(wstream);
  } else {
    wstream->freed = true;
  }
}

/// Sets the underlying `uv_stream_t` instance
///
/// @param wstream The `WStream` instance
/// @param stream The new `uv_stream_t` instance
void wstream_set_stream(WStream *wstream, uv_stream_t *stream)
{
  handle_set_wstream((uv_handle_t *)stream, wstream);
  wstream->stream = stream;
}

/// Queues data for writing to the backing file descriptor of a `WStream`
/// instance. This will fail if the write would cause the WStream use more
/// memory than specified by `maxmem`.
///
/// @param wstream The `WStream` instance
/// @param buffer The buffer which contains data to be written
/// @return false if the write failed
bool wstream_write(WStream *wstream, WBuffer *buffer)
{
  WriteData *data;
  uv_buf_t uvbuf;
  uv_write_t *req;

  // This should not be called after a wstream was freed
  assert(!wstream->freed);

  if (wstream->curmem > wstream->maxmem) {
    return false;
  }

  buffer->refcount++;
  wstream->curmem += buffer->size;
  data = xmalloc(sizeof(WriteData));
  data->wstream = wstream;
  data->buffer = buffer;
  req = xmalloc(sizeof(uv_write_t));
  req->data = data;
  uvbuf.base = buffer->data;
  uvbuf.len = buffer->size;
  wstream->pending_reqs++;
  uv_write(req, wstream->stream, &uvbuf, 1, write_cb);

  return true;
}

/// Creates a WBuffer object for holding output data. Instances of this
/// object can be reused across WStream instances, and the memory is freed
/// automatically when no longer needed(it tracks the number of references
/// internally)
///
/// @param data Data stored by the WBuffer
/// @param size The size of the data array
/// @param cb Pointer to function that will be responsible for freeing
///        the buffer data(passing 'free' will work as expected).
/// @return The allocated WBuffer instance
WBuffer *wstream_new_buffer(char *data, size_t size, wbuffer_data_finalizer cb)
{
  WBuffer *rv = xmalloc(sizeof(WBuffer));
  rv->size = size;
  rv->refcount = 0;
  rv->cb = cb;
  rv->data = data;

  return rv;
}

static void write_cb(uv_write_t *req, int status)
{
  WriteData *data = req->data;

  free(req);
  data->wstream->curmem -= data->buffer->size;

  if (!--data->buffer->refcount) {
    data->buffer->cb(data->buffer->data);
    free(data->buffer);
  }

  data->wstream->pending_reqs--;
  if (data->wstream->freed && data->wstream->pending_reqs == 0) {
    // Last pending write, free the wstream;
    free(data->wstream);
  }

  free(data);
}

