#include <stdint.h>
#include <stdbool.h>

#include <uv.h>

#include "os/wstream.h"
#include "os/wstream_defs.h"
#include "vim.h"
#include "memory.h"

struct wstream {
  uv_stream_t *stream;
  // Memory currently used by pending buffers
  uint32_t curmem;
  // Maximum memory used by this instance
  uint32_t maxmem;
  // Number of pending requests
  uint32_t pending_reqs;
  bool freed;
};

typedef struct {
  WStream *wstream;
  // Buffer containing data to be written
  char *buffer;
  // Size of the buffer
  uint32_t length;
  // If it's our responsibility to free the buffer
  bool free;
} WriteData;

static void write_cb(uv_write_t *req, int status);

WStream * wstream_new(uint32_t maxmem)
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
  stream->data = wstream;
  wstream->stream = stream;
}

bool wstream_write(WStream *wstream, char *buffer, uint32_t length, bool free)
{
  WriteData *data;
  uv_buf_t uvbuf;
  uv_write_t *req;

  if (wstream->freed) {
    // Don't accept write requests after the WStream instance was freed
    return false;
  }

  if (wstream->curmem + length > wstream->maxmem) {
    return false;
  }

  if (free) {
    // We should only account for buffers that are ours to free
    wstream->curmem += length;
  }

  data = xmalloc(sizeof(WriteData));
  data->wstream = wstream;
  data->buffer = buffer;
  data->length = length;
  data->free = free;
  req = xmalloc(sizeof(uv_write_t));
  req->data = data;
  uvbuf.base = buffer;
  uvbuf.len = length;
  wstream->pending_reqs++;
  uv_write(req, wstream->stream, &uvbuf, 1, write_cb);

  return true;
}

static void write_cb(uv_write_t *req, int status)
{
  WriteData *data = req->data;

  free(req);

  if (data->free) {
    // Free the data written to the stream
    free(data->buffer);
    data->wstream->curmem -= data->length;
  }

  if (data->wstream->freed && --data->wstream->pending_reqs == 0) {
    // Last pending write, free the wstream;
    free(data->wstream);
  }

  free(data);
}
