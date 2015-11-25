#ifndef NVIM_MSGPACK_RPC_CHANNEL_H
#define NVIM_MSGPACK_RPC_CHANNEL_H

#include <stdbool.h>
#include <uv.h>

#include "nvim/api/private/defs.h"
#include "nvim/event/socket.h"
#include "nvim/vim.h"

#define METHOD_MAXLEN 512

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/channel.h.generated.h"
#endif
#endif  // NVIM_MSGPACK_RPC_CHANNEL_H
