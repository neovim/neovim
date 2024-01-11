#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/channel_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/event/defs.h"
#include "nvim/event/libuv_process.h"
#include "nvim/func_attr.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/os/pty_process.h"
#include "nvim/types_defs.h"

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
  REAL_FATTR_NONNULL_ALL;

static inline Stream *channel_instream(Channel *chan)
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
  REAL_FATTR_NONNULL_ALL;

static inline Stream *channel_outstream(Channel *chan)
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
