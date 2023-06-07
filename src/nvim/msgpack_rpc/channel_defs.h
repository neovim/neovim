#ifndef NVIM_MSGPACK_RPC_CHANNEL_DEFS_H
#define NVIM_MSGPACK_RPC_CHANNEL_DEFS_H

#include <msgpack.h>
#include <stdbool.h>
#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/event/process.h"
#include "nvim/event/socket.h"
#include "nvim/vim.h"

typedef struct Channel Channel;
typedef struct Unpacker Unpacker;

typedef struct {
  uint32_t request_id;
  bool returned, errored;
  Object result;
  ArenaMem result_mem;
} ChannelCallFrame;

typedef struct {
  MessageType type;
  Channel *channel;
  MsgpackRpcRequestHandler handler;
  Array args;
  uint32_t request_id;
  Arena used_mem;
} RequestEvent;

typedef struct {
  Set(cstr_t) subscribed_events[1];
  bool closed;
  Unpacker *unpacker;
  uint32_t next_request_id;
  kvec_t(ChannelCallFrame *) call_stack;
  Dictionary info;
} RpcState;

#endif  // NVIM_MSGPACK_RPC_CHANNEL_DEFS_H
