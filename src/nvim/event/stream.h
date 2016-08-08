#ifndef NVIM_EVENT_STREAM_H
#define NVIM_EVENT_STREAM_H

#include <stdbool.h>
#include <stddef.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/rbuffer.h"

typedef struct stream Stream;
/// Type of function called when the Stream buffer is filled with data
///
/// @param stream The Stream instance
/// @param rbuffer The associated RBuffer instance
/// @param count Number of bytes to read. This must be respected if keeping
///              the order of events is a requirement. This is because events
///              may be queued and only processed later when more data is copied
///              into to the buffer, so one read may starve another.
/// @param data User-defined data
/// @param eof If the stream reached EOF.
typedef void (*stream_read_cb)(Stream *stream, RBuffer *buf, size_t count,
    void *data, bool eof);

/// Type of function called when the Stream has information about a write
/// request.
///
/// @param wstream The Stream instance
/// @param data User-defined data
/// @param status 0 on success, anything else indicates failure
typedef void (*stream_write_cb)(Stream *stream, void *data, int status);
typedef void (*stream_close_cb)(Stream *stream, void *data);

struct stream {
  union {
    uv_pipe_t pipe;
    uv_tcp_t tcp;
    uv_idle_t idle;
  } uv;
  uv_stream_t *uvstream;
  uv_buf_t uvbuf;
  RBuffer *buffer;
  uv_file fd;
  stream_read_cb read_cb;
  stream_write_cb write_cb;
  stream_close_cb close_cb, internal_close_cb;
  size_t fpos;
  size_t curmem;
  size_t maxmem;
  size_t pending_reqs;
  void *data, *internal_data;
  bool closed;
  Queue *events;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/stream.h.generated.h"
#endif
#endif  // NVIM_EVENT_STREAM_H
