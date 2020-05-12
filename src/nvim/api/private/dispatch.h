#ifndef NVIM_API_PRIVATE_DISPATCH_H
#define NVIM_API_PRIVATE_DISPATCH_H

#include "nvim/api/private/defs.h"

typedef Object (*ApiDispatchWrapper)(uint64_t channel_id,
                                     Array args,
                                     Error *error);

/// The rpc_method_handlers table, used in msgpack_rpc_dispatch(), stores
/// functions of this type.
typedef struct {
  ApiDispatchWrapper fn;
  bool fast;  // Function is safe to be executed immediately while running the
              // uv loop (the loop is run very frequently due to breakcheck).
              // If "fast" is false, the function is deferred, i e the call will
              // be put in the event queue, for safe handling later.
} MsgpackRpcRequestHandler;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch.h.generated.h"
# include "api/private/dispatch_wrappers.h.generated.h"
#endif

#endif  // NVIM_API_PRIVATE_DISPATCH_H
