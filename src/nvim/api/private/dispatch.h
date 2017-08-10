#ifndef NVIM_API_PRIVATE_DISPATCH_H
#define NVIM_API_PRIVATE_DISPATCH_H

#include "nvim/api/private/defs.h"

typedef Object (*ApiDispatchWrapper)(uint64_t channel_id,
                                     Array args,
                                     Error *error);

/// RPC request handler description stored in a hash
typedef struct {
  ApiDispatchWrapper fn;
  bool async;  // function is always safe to run immediately instead of being
               // put in a request queue for handling when nvim waits for input.
} MsgpackRpcRequestHandler;

/// Helper structure for storing handler name and value in one place
typedef struct {
  /// Method name
  ///
  /// @warning It is required to be named `name` and not `key` for gperf.
  const char *name;
  MsgpackRpcRequestHandler handler;
} MsgpackRpcRequestHandlerMapItem;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch.h.generated.h"
# include "api/private/dispatch_wrappers.h.generated.h"
#endif

#endif  // NVIM_API_PRIVATE_DISPATCH_H
