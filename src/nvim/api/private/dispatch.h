#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/memory_defs.h"
#include "nvim/types_defs.h"

typedef Object (*ApiDispatchWrapper)(uint64_t channel_id, Array args, Arena *arena, Error *error);

/// The rpc_method_handlers table, used in msgpack_rpc_dispatch(), stores
/// functions of this type.
struct MsgpackRpcRequestHandler {
  const char *name;
  ApiDispatchWrapper fn;
  bool fast;  ///< Function is safe to be executed immediately while running the
              ///< uv loop (the loop is run very frequently due to breakcheck).
              ///< If "fast" is false, the function is deferred, i e the call will
              ///< be put in the event queue, for safe handling later.
  bool ret_alloc;  ///< return value is allocated and should be freed using api_free_object
                   ///< otherwise it uses arena and/or static memory
};

extern const MsgpackRpcRequestHandler method_handlers[];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch.h.generated.h"
# include "api/private/dispatch_wrappers.h.generated.h"
# include "keysets_defs.generated.h"
#endif
