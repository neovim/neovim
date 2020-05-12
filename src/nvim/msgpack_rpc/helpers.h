#ifndef NVIM_MSGPACK_RPC_HELPERS_H
#define NVIM_MSGPACK_RPC_HELPERS_H

#include <stdint.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/event/wstream.h"
#include "nvim/api/private/defs.h"

/// Value by which objects represented as EXT type are shifted
///
/// Subtracted when packing, added when unpacking. Used to allow moving
/// buffer/window/tabpage block inside ObjectType enum. This block yet cannot be
/// split or reordered.
#define EXT_OBJECT_TYPE_SHIFT kObjectTypeBuffer

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/helpers.h.generated.h"
#endif

#endif  // NVIM_MSGPACK_RPC_HELPERS_H

