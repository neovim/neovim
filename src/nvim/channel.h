#ifndef NVIM_CHANNEL_H
#define NVIM_CHANNEL_H

#include <stdint.h>

#include "nvim/channel_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/macros.h"
#include "nvim/map.h"
#include "nvim/msgpack_rpc/channel_defs.h"

EXTERN PMap(uint64_t) channels INIT(= MAP_INIT);

EXTERN Callback on_print INIT(= CALLBACK_INIT);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "channel.h.generated.h"
#endif

/// @returns Channel with the id or NULL if not found
static inline Channel *find_channel(uint64_t id)
{
  return pmap_get(uint64_t)(&channels, id);
}

#endif  // NVIM_CHANNEL_H
