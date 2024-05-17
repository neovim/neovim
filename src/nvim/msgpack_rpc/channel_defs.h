#pragma once

#include <msgpack.h>
#include <stdbool.h>
#include <uv.h>

#include "nvim/api/private/dispatch.h"
#include "nvim/map_defs.h"

typedef struct Channel Channel;
typedef struct Unpacker Unpacker;

typedef enum {
  kClientTypeUnknown = -1,
  kClientTypeRemote = 0,
  kClientTypeMsgpackRpc = 5,
  kClientTypeUi = 1,
  kClientTypeEmbedder = 2,
  kClientTypeHost = 3,
  kClientTypePlugin = 4,
} ClientType;

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
  bool closed;
  Unpacker *unpacker;
  uint32_t next_request_id;
  kvec_t(ChannelCallFrame *) call_stack;
  Dictionary info;
  ClientType client_type;
} RpcState;
