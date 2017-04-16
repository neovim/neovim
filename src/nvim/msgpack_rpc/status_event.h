#ifndef NVIM_MSGPACK_RPC_STATUS_EVENT_H
#define NVIM_MSGPACK_RPC_STATUS_EVENT_H

typedef struct {
  handle_T last_curbuf;
  handle_T last_curwin;
  handle_T last_curtab;
} StatusInfo;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/status_event.h.generated.h"
#endif
#endif  // NVIM_MSGPACK_RPC_STATUS_EVENT_H
