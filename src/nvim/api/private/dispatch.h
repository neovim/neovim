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
  bool arena_return;  ///< return value is allocated in the arena (or statically)
                      ///< and should not be freed as such.
};

extern const MsgpackRpcRequestHandler method_handlers[];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch.h.generated.h"
# include "api/private/dispatch_wrappers.h.generated.h"
# include "keysets_defs.generated.h"
#endif
