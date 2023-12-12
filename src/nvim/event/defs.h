#pragma once

#include <assert.h>
#include <stdarg.h>
#include <stdbool.h>
#include <uv.h>

#include "nvim/rbuffer_defs.h"

enum { EVENT_HANDLER_MAX_ARGC = 10, };

typedef void (*argv_callback)(void **argv);
typedef struct {
  argv_callback handler;
  void *argv[EVENT_HANDLER_MAX_ARGC];
} Event;

#define event_create(cb, ...) ((Event){ .handler = cb, .argv = { __VA_ARGS__ } })

typedef struct multiqueue MultiQueue;
typedef void (*PutCallback)(MultiQueue *multiq, void *data);

#define multiqueue_put(q, h, ...) \
  do { \
    multiqueue_put_event(q, event_create(h, __VA_ARGS__)); \
  } while (0)

#define CREATE_EVENT(multiqueue, handler, ...) \
  do { \
    if (multiqueue) { \
      multiqueue_put((multiqueue), (handler), __VA_ARGS__); \
    } else { \
      void *argv[] = { __VA_ARGS__ }; \
      (handler)(argv); \
    } \
  } while (0)

// Poll for events until a condition or timeout
#define LOOP_PROCESS_EVENTS_UNTIL(loop, multiqueue, timeout, condition) \
  do { \
    int64_t remaining = timeout; \
    uint64_t before = (remaining > 0) ? os_hrtime() : 0; \
    while (!(condition)) { \
      LOOP_PROCESS_EVENTS(loop, multiqueue, remaining); \
      if (remaining == 0) { \
        break; \
      } else if (remaining > 0) { \
        uint64_t now = os_hrtime(); \
        remaining -= (int64_t)((now - before) / 1000000); \
        before = now; \
        if (remaining <= 0) { \
          break; \
        } \
      } \
    } \
  } while (0)

#define LOOP_PROCESS_EVENTS(loop, multiqueue, timeout) \
  do { \
    if (multiqueue && !multiqueue_empty(multiqueue)) { \
      multiqueue_process_events(multiqueue); \
    } else { \
      loop_poll_events(loop, timeout); \
    } \
  } while (0)

struct signal_watcher;

typedef struct signal_watcher SignalWatcher;
typedef void (*signal_cb)(SignalWatcher *watcher, int signum, void *data);
typedef void (*signal_close_cb)(SignalWatcher *watcher, void *data);

struct signal_watcher {
  uv_signal_t uv;
  void *data;
  signal_cb cb;
  signal_close_cb close_cb;
  MultiQueue *events;
};

struct time_watcher;

typedef struct time_watcher TimeWatcher;
typedef void (*time_cb)(TimeWatcher *watcher, void *data);

struct time_watcher {
  uv_timer_t uv;
  void *data;
  time_cb cb, close_cb;
  MultiQueue *events;
  bool blockable;
};

struct wbuffer;

typedef struct wbuffer WBuffer;
typedef void (*wbuffer_data_finalizer)(void *data);

struct wbuffer {
  size_t size, refcount;
  char *data;
  wbuffer_data_finalizer cb;
};

struct stream;

typedef struct stream Stream;
/// Type of function called when the Stream buffer is filled with data
///
/// @param stream The Stream instance
/// @param buf The associated RBuffer instance
/// @param count Number of bytes that was read.
/// @param data User-defined data
/// @param eof If the stream reached EOF.
typedef void (*stream_read_cb)(Stream *stream, RBuffer *buf, size_t count, void *data, bool eof);

/// Type of function called when the Stream has information about a write
/// request.
///
/// @param stream The Stream instance
/// @param data User-defined data
/// @param status 0 on success, anything else indicates failure
typedef void (*stream_write_cb)(Stream *stream, void *data, int status);
typedef void (*stream_close_cb)(Stream *stream, void *data);

struct stream {
  bool closed;
  bool did_eof;
  union {
    uv_pipe_t pipe;
    uv_tcp_t tcp;
    uv_idle_t idle;
#ifdef MSWIN
    uv_tty_t tty;
#endif
  } uv;
  uv_stream_t *uvstream;
  uv_buf_t uvbuf;
  RBuffer *buffer;
  uv_file fd;
  stream_read_cb read_cb;
  stream_write_cb write_cb;
  void *cb_data;
  stream_close_cb close_cb, internal_close_cb;
  void *close_cb_data, *internal_data;
  size_t fpos;
  size_t curmem;
  size_t maxmem;
  size_t pending_reqs;
  size_t num_bytes;
  MultiQueue *events;
};

struct socket_watcher;

#define ADDRESS_MAX_SIZE 256

typedef struct socket_watcher SocketWatcher;
typedef void (*socket_cb)(SocketWatcher *watcher, int result, void *data);
typedef void (*socket_close_cb)(SocketWatcher *watcher, void *data);

struct socket_watcher {
  // Pipe/socket path, or TCP address string
  char addr[ADDRESS_MAX_SIZE];
  // TCP server or unix socket (named pipe on Windows)
  union {
    struct {
      uv_tcp_t handle;
      struct addrinfo *addrinfo;
    } tcp;
    struct {
      uv_pipe_t handle;
    } pipe;
  } uv;
  uv_stream_t *stream;
  void *data;
  socket_cb cb;
  socket_close_cb close_cb;
  MultiQueue *events;
};
