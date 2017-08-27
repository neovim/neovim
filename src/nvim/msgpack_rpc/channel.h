#ifndef NVIM_MSGPACK_RPC_CHANNEL_H
#define NVIM_MSGPACK_RPC_CHANNEL_H

#include <stdbool.h>
#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/event/socket.h"
#include "nvim/event/process.h"
#include "nvim/vim.h"
#include "nvim/channel.h"

#define METHOD_MAXLEN 512

/// HACK: os/input.c drains this queue immediately before blocking for input.
///       Events on this queue are async-safe, but they need the resolved state
///       of os_inchar(), so they are processed "just-in-time".
MultiQueue *ch_before_blocking_events;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.h.generated.h"
#endif
#endif  // NVIM_MSGPACK_RPC_CHANNEL_H
