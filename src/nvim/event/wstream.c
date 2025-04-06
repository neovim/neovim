#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <uv.h>

#include "nvim/event/defs.h"
#include "nvim/event/stream.h"
#include "nvim/event/wstream.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/types_defs.h"

#define DEFAULT_MAXMEM 1024 * 1024 * 2000

typedef struct {
  Stream *stream;
  WBuffer *buffer;
  uv_write_t uv_req;
} WRequest;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/wstream.c.generated.h"
#endif

void wstream_init_fd(Loop *loop, Stream *stream, int fd, size_t maxmem)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_ARG(2)
{
  stream_init(loop, stream, fd, NULL);
  wstream_init(stream, maxmem);
}

void wstream_init_stream(Stream *stream, uv_stream_t *uvstream, size_t maxmem)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_ARG(2)
{
  stream_init(NULL, stream, -1, uvstream);
  wstream_init(stream, maxmem);
}

void wstream_init(Stream *stream, size_t maxmem)
{
  stream->maxmem = maxmem ? maxmem : DEFAULT_MAXMEM;
}

/// Sets a callback that will be called on completion of a write request,
/// indicating failure/success.
///
/// This affects all requests currently in-flight as well. Overwrites any
/// possible earlier callback.
///
/// @note This callback will not fire if the write request couldn't even be
///       queued properly (i.e.: when `wstream_write() returns an error`).
///
/// @param stream The `Stream` instance
/// @param cb The callback
void wstream_set_write_cb(Stream *stream, stream_write_cb cb, void *data)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  stream->write_cb = cb;
  stream->cb_data = data;
}

/// Queues data for writing to the backing file descriptor of a `Stream`
/// instance. This will fail if the write would cause the Stream use more
/// memory than specified by `maxmem`.
///
/// @param stream The `Stream` instance
/// @param buffer The buffer which contains data to be written
/// @return false if the write failed
bool wstream_write(Stream *stream, WBuffer *buffer)
  FUNC_ATTR_NONNULL_ALL
{
  assert(stream->maxmem);
  // This should not be called after a stream was freed
  assert(!stream->closed);

  uv_buf_t uvbuf;
  uvbuf.base = buffer->data;
  uvbuf.len = UV_BUF_LEN(buffer->size);

  if (!stream->uvstream) {
    uv_fs_t req;

    // Synchronous write
    uv_fs_write(stream->uv.idle.loop, &req, stream->fd, &uvbuf, 1, stream->fpos, NULL);

    uv_fs_req_cleanup(&req);

    wstream_release_wbuffer(buffer);

    assert(stream->write_cb == NULL);

    stream->fpos += MAX(req.result, 0);
    return req.result > 0;
  }

  if (stream->curmem > stream->maxmem) {
    goto err;
  }

  stream->curmem += buffer->size;

  WRequest *data = xmalloc(sizeof(WRequest));
  data->stream = stream;
  data->buffer = buffer;
  data->uv_req.data = data;

  if (uv_write(&data->uv_req, stream->uvstream, &uvbuf, 1, write_cb)) {
    xfree(data);
    goto err;
  }

  stream->pending_reqs++;
  return true;

err:
  wstream_release_wbuffer(buffer);
  return false;
}

/// Creates a WBuffer object for holding output data. Instances of this
/// object can be reused across Stream instances, and the memory is freed
/// automatically when no longer needed (it tracks the number of references
/// internally)
///
/// @param data Data stored by the WBuffer
/// @param size The size of the data array
/// @param refcount The number of references for the WBuffer. This will be used
///        by Stream instances to decide when a WBuffer should be freed.
/// @param cb Pointer to function that will be responsible for freeing
///        the buffer data (passing `xfree` will work as expected).
/// @return The allocated WBuffer instance
WBuffer *wstream_new_buffer(char *data, size_t size, size_t refcount, wbuffer_data_finalizer cb)
  FUNC_ATTR_NONNULL_ARG(1)
{
  WBuffer *rv = xmalloc(sizeof(WBuffer));
  rv->size = size;
  rv->refcount = refcount;
  rv->cb = cb;
  rv->data = data;

  return rv;
}

static void write_cb(uv_write_t *req, int status)
{
  WRequest *data = req->data;

  data->stream->curmem -= data->buffer->size;

  wstream_release_wbuffer(data->buffer);

  if (data->stream->write_cb) {
    data->stream->write_cb(data->stream, data->stream->cb_data, status);
  }

  data->stream->pending_reqs--;

  if (data->stream->closed && data->stream->pending_reqs == 0) {
    // Last pending write; free the stream.
    stream_close_handle(data->stream, false);
  }

  xfree(data);
}

void wstream_release_wbuffer(WBuffer *buffer)
  FUNC_ATTR_NONNULL_ALL
{
  if (!--buffer->refcount) {
    if (buffer->cb) {
      buffer->cb(buffer->data);
    }

    xfree(buffer);
  }
}

void wstream_may_close(Stream *stream)
{
  stream_may_close(stream, false);
}
