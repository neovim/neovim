#pragma once

#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/event/defs.h"
#include "nvim/macros_defs.h"
#include "nvim/memory_defs.h"  // IWYU pragma: keep
#include "nvim/msgpack_rpc/channel_defs.h"  // IWYU pragma: keep

#define METHOD_MAXLEN 512

/// HACK: os/input.c drains this queue immediately before blocking for input.
///       Events on this queue are async-safe, but they need the resolved state
///       of input_get(), so they are processed "just-in-time".
EXTERN MultiQueue *ch_before_blocking_events INIT( = NULL);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.h.generated.h"
#endif
