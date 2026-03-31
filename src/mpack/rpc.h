#ifndef MPACK_RPC_H
#define MPACK_RPC_H

#include "mpack_core.h"
#include "object.h"

#ifndef MPACK_RPC_MAX_REQUESTS
# define MPACK_RPC_MAX_REQUESTS 32
#endif

enum {
  MPACK_RPC_REQUEST = MPACK_NOMEM + 1,
  MPACK_RPC_RESPONSE,
  MPACK_RPC_NOTIFICATION,
  MPACK_RPC_ERROR
};

enum {
  MPACK_RPC_EARRAY = MPACK_RPC_ERROR,
  MPACK_RPC_EARRAYL,
  MPACK_RPC_ETYPE,
  MPACK_RPC_EMSGID,
  MPACK_RPC_ERESPID
};

typedef struct mpack_rpc_header_s {
  mpack_token_t toks[3];
  int index;
} mpack_rpc_header_t;

typedef struct mpack_rpc_message_s {
  mpack_uint32_t id;
  mpack_data_t data;
} mpack_rpc_message_t;

struct mpack_rpc_slot_s {
  int used;
  mpack_rpc_message_t msg;
};

#define MPACK_RPC_SESSION_STRUCT(c)      \
  struct {     \
    mpack_tokbuf_t reader, writer;       \
    mpack_rpc_header_t receive, send;    \
    mpack_uint32_t request_id, capacity; \
    struct mpack_rpc_slot_s slots[c];    \
  }

/* Some compilers warn against anonymous structs:
 * https://github.com/libmpack/libmpack/issues/6 */
typedef MPACK_RPC_SESSION_STRUCT(1) mpack_rpc_one_session_t;

#define MPACK_RPC_SESSION_STRUCT_SIZE(c)        \
  (sizeof(struct mpack_rpc_slot_s) * (c - 1) +  \
   sizeof(mpack_rpc_one_session_t))

typedef MPACK_RPC_SESSION_STRUCT(MPACK_RPC_MAX_REQUESTS) mpack_rpc_session_t;

MPACK_API void mpack_rpc_session_init(mpack_rpc_session_t *s, mpack_uint32_t c)
  FUNUSED FNONULL;

MPACK_API int mpack_rpc_receive_tok(mpack_rpc_session_t *s, mpack_token_t t,
    mpack_rpc_message_t *msg) FUNUSED FNONULL;
MPACK_API int mpack_rpc_request_tok(mpack_rpc_session_t *s, mpack_token_t *t,
    mpack_data_t d) FUNUSED FNONULL_ARG((1,2));
MPACK_API int mpack_rpc_reply_tok(mpack_rpc_session_t *s, mpack_token_t *t,
    mpack_uint32_t i) FUNUSED FNONULL;
MPACK_API int mpack_rpc_notify_tok(mpack_rpc_session_t *s, mpack_token_t *t)
  FUNUSED FNONULL;

MPACK_API int mpack_rpc_receive(mpack_rpc_session_t *s, const char **b,
    size_t *bl, mpack_rpc_message_t *m) FUNUSED FNONULL;
MPACK_API int mpack_rpc_request(mpack_rpc_session_t *s, char **b, size_t *bl,
    mpack_data_t d) FUNUSED FNONULL_ARG((1,2,3));
MPACK_API int mpack_rpc_reply(mpack_rpc_session_t *s, char **b, size_t *bl,
    mpack_uint32_t i) FNONULL FUNUSED;
MPACK_API int mpack_rpc_notify(mpack_rpc_session_t *s, char **b, size_t *bl)
  FNONULL FUNUSED;

MPACK_API void mpack_rpc_session_copy(mpack_rpc_session_t *d,
    mpack_rpc_session_t *s) FUNUSED FNONULL;

#endif  /* MPACK_RPC_H */
