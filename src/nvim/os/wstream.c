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
  size_t refcount, size;
  char *data;
};

typedef struct {
  WStream *wstream;
  WBuffer *buffer;
} WriteData;

static void write_cb(uv_write_t *req, int status);

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

void wstream_free(WStream *wstream)
{
  if (!wstream->pending_reqs) {
    free(wstream);
  } else {
    wstream->freed = true;
  }
}

void wstream_set_stream(WStream *wstream, uv_stream_t *stream)
{
  handle_set_wstream((uv_handle_t *)stream, wstream);
  wstream->stream = stream;
}

bool wstream_write(WStream *wstream, WBuffer *buffer)
{
  WriteData *data;
  uv_buf_t uvbuf;
  uv_write_t *req;

  // This should not be called after a wstream was freed
  assert(!wstream->freed);

  if (wstream->curmem + buffer->size > wstream->maxmem) {
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

WBuffer *wstream_new_buffer(char *data, size_t size, bool copy)
{
  WBuffer *rv = xmalloc(sizeof(WBuffer));
  rv->size = size;
  rv->refcount = 0;

  if (copy) {
    rv->data = xmemdup(data, size);
  } else {
    rv->data = data;
  }

  return rv;
}

static void write_cb(uv_write_t *req, int status)
{
  WriteData *data = req->data;

  free(req);
  data->wstream->curmem -= data->buffer->size;

  if (!--data->buffer->refcount) {
    // Free the data written to the stream
    free(data->buffer->data);
    free(data->buffer);
  }

  data->wstream->pending_reqs--;
  if (data->wstream->freed && data->wstream->pending_reqs == 0) {
    // Last pending write, free the wstream;
    free(data->wstream);
  }

  free(data);
}

