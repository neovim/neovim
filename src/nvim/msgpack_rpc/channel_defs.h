#ifndef NVIM_MSGPACK_RPC_CHANNEL_DEFS_H
#define NVIM_MSGPACK_RPC_CHANNEL_DEFS_H

#include <stdbool.h>
#include <uv.h>
#include <msgpack.h>

#include "nvim/api/private/defs.h"
#include "nvim/event/socket.h"
#include "nvim/event/process.h"
#include "nvim/vim.h"

typedef struct Channel Channel;

typedef struct {
  uint64_t request_id;
  bool returned, errored;
  Object result;
} ChannelCallFrame;

typedef struct {
  Channel *channel;
  MsgpackRpcRequestHandler handler;
  Array args;
  uint64_t request_id;
} RequestEvent;

typedef struct {
  PMap(cstr_t) *subscribed_events;
  bool closed;
  msgpack_unpacker *unpacker;
  uint64_t next_request_id;
  kvec_t(ChannelCallFrame *) call_stack;
  Dictionary info;
} RpcState;

#endif  // NVIM_MSGPACK_RPC_CHANNEL_DEFS_H
