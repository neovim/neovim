#pragma once

#include <assert.h>
#include <stdarg.h>
#include <stdbool.h>
#include <uv.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/types_defs.h"

enum { EVENT_HANDLER_MAX_ARGC = 10, };

typedef void (*argv_callback)(void **argv);
typedef struct {
  argv_callback handler;
  void *argv[EVENT_HANDLER_MAX_ARGC];
} Event;

#define event_create(cb, ...) ((Event){ .handler = cb, .argv = { __VA_ARGS__ } })

typedef struct multiqueue MultiQueue;
typedef void (*PutCallback)(MultiQueue *multiq, void *data);

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

typedef struct time_watcher TimeWatcher;
typedef void (*time_cb)(TimeWatcher *watcher, void *data);

struct time_watcher {
  uv_timer_t uv;
  void *data;
  time_cb cb, close_cb;
  MultiQueue *events;
  bool blockable;
};

typedef struct wbuffer WBuffer;
typedef void (*wbuffer_data_finalizer)(void *data);

struct wbuffer {
  size_t size, refcount;
  char *data;
  wbuffer_data_finalizer cb;
};

typedef struct stream Stream;
typedef struct rstream RStream;
/// Type of function called when the RStream buffer is filled with data
///
/// @param stream The Stream instance
/// @param read_data data that was read
/// @param count Number of bytes that was read.
/// @param data User-defined data
/// @param eof If the stream reached EOF.
/// @return number of bytes which were consumed
typedef size_t (*stream_read_cb)(RStream *stream, const char *read_data, size_t count, void *data,
                                 bool eof);

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
  union {
    uv_pipe_t pipe;
    uv_tcp_t tcp;
    uv_idle_t idle;
#ifdef MSWIN
    uv_tty_t tty;
#endif
  } uv;
  uv_stream_t *uvstream;
  uv_file fd;
  void *cb_data;
  stream_close_cb close_cb, internal_close_cb;
  void *close_cb_data, *internal_data;
  size_t pending_reqs;
  MultiQueue *events;

  // only used for writing:
  stream_write_cb write_cb;
  size_t curmem;
  size_t maxmem;
};

struct rstream {
  Stream s;
  bool did_eof;
  bool want_read;
  bool pending_read;
  bool paused_full;
  char *buffer;  // ARENA_BLOCK_SIZE
  char *read_pos;
  char *write_pos;
  uv_buf_t uvbuf;
  stream_read_cb read_cb;
  size_t num_bytes;
  int64_t fpos;
};

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

typedef enum {
  kProcessTypeUv,
  kProcessTypePty,
} ProcessType;

typedef struct process Process;
typedef void (*process_exit_cb)(Process *proc, int status, void *data);
typedef void (*internal_process_cb)(Process *proc);

struct process {
  ProcessType type;
  Loop *loop;
  void *data;
  int pid, status, refcount;
  uint8_t exit_signal;  // Signal used when killing (on Windows).
  uint64_t stopped_time;  // process_stop() timestamp
  const char *cwd;
  char **argv;
  const char *exepath;
  dict_T *env;
  Stream in;
  RStream out, err;
  /// Exit handler. If set, user must call process_free().
  process_exit_cb cb;
  internal_process_cb internal_exit_cb, internal_close_cb;
  bool closed, detach, overlapped, fwd_err;
  MultiQueue *events;
};
