#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/channel_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/event/defs.h"
#include "nvim/event/libuv_proc.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/os/pty_proc.h"
#include "nvim/types_defs.h"

struct Channel {
  uint64_t id;
  size_t refcount;
  MultiQueue *events;

  ChannelStreamType streamtype;
  union {
    Proc proc;
    LibuvProc uv;
    PtyProc pty;
    RStream socket;
    StdioPair stdio;
    StderrState err;
    InternalState internal;
  } stream;

  bool is_rpc;
  bool detach;  ///< Prevents self-exit on channel-close. Normally, Nvim self-exits if its primary
                ///< RPC channel is closed, unless detach=true. Note: currently, detach=false does
                ///< not FORCE self-exit.
  RpcState rpc;
  Terminal *term;

  CallbackReader on_data;
  CallbackReader on_stderr;
  Callback on_exit;
  int exit_status;

  bool callback_busy;
  bool callback_scheduled;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.h.generated.h"
# include "channel.h.inline.generated.h"
#endif

static inline bool callback_reader_set(CallbackReader reader)
{
  return reader.cb.type != kCallbackNone || reader.self;
}

EXTERN PMap(uint64_t) channels INIT( = MAP_INIT);

EXTERN Callback on_print INIT( = CALLBACK_INIT);

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
    return &chan->stream.socket.s;

  case kChannelStreamStdio:
    return &chan->stream.stdio.out;

  case kChannelStreamInternal:
  case kChannelStreamStderr:
    abort();
  }
  abort();
}

static inline RStream *channel_outstream(Channel *chan)
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
