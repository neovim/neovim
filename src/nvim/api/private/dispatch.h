#ifndef NVIM_API_PRIVATE_DISPATCH_H
#define NVIM_API_PRIVATE_DISPATCH_H

#include "nvim/api/private/defs.h"

/// The rpc_method_handlers table, used in msgpack_rpc_dispatch(), stores
/// functions of this type.
typedef struct {
  Object (*fn)(uint64_t channel_id,
               uint64_t request_id,
               Array args,
               Error *error);
  bool async;  // function is always safe to run immediately instead of being
               // put in a request queue for handling when nvim waits for input.
} MsgpackRpcRequestHandler;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch.h.generated.h"
#endif

#endif  // NVIM_API_PRIVATE_DISPATCH_H
