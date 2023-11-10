#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/event/libuv_process.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/process.h"
#include "nvim/event/socket.h"
#include "nvim/event/stream.h"
#include "nvim/garray.h"
#include "nvim/macros.h"
#include "nvim/main.h"
#include "nvim/map.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/os/pty_process.h"
#include "nvim/terminal.h"
#include "nvim/types.h"

#define CHAN_STDIO 1
#define CHAN_STDERR 2

typedef enum {
  kChannelStreamProc,
  kChannelStreamSocket,
  kChannelStreamStdio,
  kChannelStreamStderr,
  kChannelStreamInternal,
} ChannelStreamType;

typedef enum {
  kChannelPartStdin,
  kChannelPartStdout,
  kChannelPartStderr,
  kChannelPartRpc,
  kChannelPartAll,
} ChannelPart;

typedef enum {
  kChannelStdinPipe,
  kChannelStdinNull,
} ChannelStdinMode;

typedef struct {
  Stream in;
  Stream out;
} StdioPair;

typedef struct {
  bool closed;
} StderrState;

typedef struct {
  LuaRef cb;
  bool closed;
} InternalState;

typedef struct {
  Callback cb;
  dict_T *self;
  garray_T buffer;
  bool eof;
  bool buffered;
  bool fwd_err;
  const char *type;
} CallbackReader;

#define CALLBACK_READER_INIT ((CallbackReader){ .cb = CALLBACK_NONE, \
                                                .self = NULL, \
                                                .buffer = GA_EMPTY_INIT_VALUE, \
                                                .buffered = false, \
                                                .fwd_err = false, \
                                                .type = NULL })
static inline bool callback_reader_set(CallbackReader reader)
{
  return reader.cb.type != kCallbackNone || reader.self;
}

struct Channel {
  uint64_t id;
  size_t refcount;
  MultiQueue *events;

  ChannelStreamType streamtype;
  union {
    Process proc;
    LibuvProcess uv;
    PtyProcess pty;
    Stream socket;
    StdioPair stdio;
    StderrState err;
    InternalState internal;
  } stream;

  bool is_rpc;
  RpcState rpc;
  Terminal *term;

  CallbackReader on_data;
  CallbackReader on_stderr;
  Callback on_exit;
  int exit_status;

  bool callback_busy;
  bool callback_scheduled;
};

EXTERN PMap(uint64_t) channels INIT( = MAP_INIT);

EXTERN Callback on_print INIT( = CALLBACK_INIT);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.h.generated.h"
#endif

/// @returns Channel with the id or NULL if not found
static inline Channel *find_channel(uint64_t id)
{
  return (Channel *)pmap_get(uint64_t)(&channels, id);
}

static inline Stream *channel_instream(Channel *chan)
  FUNC_ATTR_NONNULL_ALL
{
  switch (chan->streamtype) {
  case kChannelStreamProc:
    return &chan->stream.proc.in;

  case kChannelStreamSocket:
    return &chan->stream.socket;

  case kChannelStreamStdio:
    return &chan->stream.stdio.out;

  case kChannelStreamInternal:
  case kChannelStreamStderr:
    abort();
  }
  abort();
}

static inline Stream *channel_outstream(Channel *chan)
  FUNC_ATTR_NONNULL_ALL
{
  switch (chan->streamtype) {
  case kChannelStreamProc:
    return &chan->stream.proc.out;

  case kChannelStreamSocket:
    return &chan->stream.socket;

  case kChannelStreamStdio:
    return &chan->stream.stdio.in;

  case kChannelStreamInternal:
  case kChannelStreamStderr:
    abort();
  }
  abort();
}
