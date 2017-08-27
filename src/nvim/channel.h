#ifndef NVIM_CHANNEL_H
#define NVIM_CHANNEL_H

#include "nvim/main.h"
#include "nvim/event/socket.h"
#include "nvim/event/process.h"
#include "nvim/os/pty_process.h"
#include "nvim/event/libuv_process.h"
#include "nvim/eval/typval.h"
#include "nvim/msgpack_rpc/channel_defs.h"

typedef enum {
  kChannelStreamProc,
  kChannelStreamSocket,
  kChannelStreamStdio,
  kChannelStreamInternal
} ChannelStreamType;

typedef struct {
  Stream in;
  Stream out;
} StdioPair;

// typedef struct {
//   Callback on_out;
//   Callback on_close;
//   Garray buffer;
//   bool buffering;
// } CallbackReader

#define CallbackReader Callback

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
  } stream;

  bool is_rpc;
  RpcState rpc;
  Terminal *term;

  CallbackReader on_stdout;
  CallbackReader on_stderr;
  Callback on_exit;

  varnumber_T *status_ptr; // TODO: refactor?
};

EXTERN PMap(uint64_t) *channels;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.h.generated.h"
#endif

static inline Channel *channel_alloc(ChannelStreamType type)
{
  Channel *chan = xcalloc(1, sizeof(*chan));
  chan->id = next_chan_id++;
  chan->events = multiqueue_new_child(main_loop.events);
  chan->refcount = 1;
  chan->streamtype = type;
  pmap_put(uint64_t)(channels, chan->id, chan);
  return chan;
}

/// @returns Channel with the id or NULL if not found
static inline Channel *find_channel(uint64_t id)
{
  return pmap_get(uint64_t)(channels, id);
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
      return &chan->stream.stdio.in;

    case kChannelStreamInternal:
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
      return &chan->stream.stdio.out;

    case kChannelStreamInternal:
      abort();
  }
  abort();
}


#endif  // NVIM_CHANNEL_H
