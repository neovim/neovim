#pragma once

#include <msgpack.h>
#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/event/wstream.h"

/// Value by which objects represented as EXT type are shifted
///
/// Subtracted when packing, added when unpacking. Used to allow moving
/// buffer/window/tabpage block inside ObjectType enum. This block yet cannot be
/// split or reordered.
#define EXT_OBJECT_TYPE_SHIFT kObjectTypeBuffer
#define EXT_OBJECT_TYPE_MAX (kObjectTypeTabpage - EXT_OBJECT_TYPE_SHIFT)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/helpers.h.generated.h"
#endif
