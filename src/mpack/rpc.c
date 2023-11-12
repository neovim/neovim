#include <string.h>

#include "rpc.h"

enum {
  MPACK_RPC_RECEIVE_ARRAY = 1,
  MPACK_RPC_RECEIVE_TYPE,
  MPACK_RPC_RECEIVE_ID
};

static mpack_rpc_header_t mpack_rpc_request_hdr(void);
static mpack_rpc_header_t mpack_rpc_reply_hdr(void);
static mpack_rpc_header_t mpack_rpc_notify_hdr(void);
static int mpack_rpc_put(mpack_rpc_session_t *s, mpack_rpc_message_t m);
static int mpack_rpc_pop(mpack_rpc_session_t *s, mpack_rpc_message_t *m);
static void mpack_rpc_reset_hdr(mpack_rpc_header_t *hdr);

MPACK_API void mpack_rpc_session_init(mpack_rpc_session_t *session,
    mpack_uint32_t capacity)
{
  session->capacity = capacity ? capacity : MPACK_RPC_MAX_REQUESTS;
  session->request_id = 0;
  mpack_tokbuf_init(&session->reader);
  mpack_tokbuf_init(&session->writer);
  mpack_rpc_reset_hdr(&session->receive);
  mpack_rpc_reset_hdr(&session->send);
  memset(session->slots, 0,
      sizeof(struct mpack_rpc_slot_s) * session->capacity);
}

MPACK_API int mpack_rpc_receive_tok(mpack_rpc_session_t *session,
    mpack_token_t tok, mpack_rpc_message_t *msg)
{
  int type;

  if (session->receive.index == 0) {
    if (tok.type != MPACK_TOKEN_ARRAY)
      /* not an array */
      return MPACK_RPC_EARRAY;

    if (tok.length < 3 || tok.length > 4)
      /* invalid array length */
      return MPACK_RPC_EARRAYL;

    session->receive.toks[0] = tok;
    session->receive.index++;
    return MPACK_EOF;  /* get the type */
  }

  if (session->receive.index == 1) {

    if (tok.type != MPACK_TOKEN_UINT || tok.length > 1 || tok.data.value.lo > 2)
      /* invalid type */
      return MPACK_RPC_ETYPE;

    if (tok.data.value.lo < 2 && session->receive.toks[0].length != 4)
      /* request or response with array length != 4 */
      return MPACK_RPC_EARRAYL;

    if (tok.data.value.lo == 2 && session->receive.toks[0].length != 3)
      /* notification with array length != 3 */
      return MPACK_RPC_EARRAYL;

    session->receive.toks[1] = tok;
    session->receive.index++;

    if (tok.data.value.lo < 2) return MPACK_EOF;

    type = MPACK_RPC_NOTIFICATION;
    goto end;
  }

  assert(session->receive.index == 2);
  
  if (tok.type != MPACK_TOKEN_UINT || tok.length > 4)
    /* invalid request/response id */
    return MPACK_RPC_EMSGID;
    
  msg->id = tok.data.value.lo;
  msg->data.p = NULL;
  type = (int)session->receive.toks[1].data.value.lo + MPACK_RPC_REQUEST;

  if (type == MPACK_RPC_RESPONSE && !mpack_rpc_pop(session, msg))
    /* response with invalid id */
    return MPACK_RPC_ERESPID;

end:
  mpack_rpc_reset_hdr(&session->receive);
  return type;
}

MPACK_API int mpack_rpc_request_tok(mpack_rpc_session_t *session, 
    mpack_token_t *tok, mpack_data_t data)
{
  if (session->send.index == 0) {
    int status;
    mpack_rpc_message_t msg;
    do {
      msg.id = session->request_id;
      msg.data = data;
      session->send = mpack_rpc_request_hdr();
      session->send.toks[2].type = MPACK_TOKEN_UINT;
      session->send.toks[2].data.value.lo = msg.id;
      session->send.toks[2].data.value.hi = 0;
      *tok = session->send.toks[0];
      status = mpack_rpc_put(session, msg);
      if (status == -1) return MPACK_NOMEM;
      session->request_id = (session->request_id + 1) % 0xffffffff;
    } while (!status);
    session->send.index++;
    return MPACK_EOF;
  }
  
  if (session->send.index == 1) {
    *tok = session->send.toks[1];
    session->send.index++;
    return MPACK_EOF;
  }

  assert(session->send.index == 2);
  *tok = session->send.toks[2];
  mpack_rpc_reset_hdr(&session->send);
  return MPACK_OK;
}

MPACK_API int mpack_rpc_reply_tok(mpack_rpc_session_t *session,
    mpack_token_t *tok, mpack_uint32_t id)
{
  if (session->send.index == 0) {
    session->send = mpack_rpc_reply_hdr();
    session->send.toks[2].type = MPACK_TOKEN_UINT;
    session->send.toks[2].data.value.lo = id;
    session->send.toks[2].data.value.hi = 0;
    *tok = session->send.toks[0];
    session->send.index++;
    return MPACK_EOF;
  }

  if (session->send.index == 1) {
    *tok = session->send.toks[1];
    session->send.index++;
    return MPACK_EOF;
  }

  assert(session->send.index == 2);
  *tok = session->send.toks[2];
  mpack_rpc_reset_hdr(&session->send);
  return MPACK_OK;
}

MPACK_API int mpack_rpc_notify_tok(mpack_rpc_session_t *session,
    mpack_token_t *tok)
{
  if (session->send.index == 0) {
    session->send = mpack_rpc_notify_hdr();
    *tok = session->send.toks[0];
    session->send.index++;
    return MPACK_EOF;
  }

  assert(session->send.index == 1);
  *tok = session->send.toks[1];
  mpack_rpc_reset_hdr(&session->send);
  return MPACK_OK;
}

MPACK_API int mpack_rpc_receive(mpack_rpc_session_t *session, const char **buf,
    size_t *buflen, mpack_rpc_message_t *msg)
{
  int status;

  do {
    mpack_token_t tok;
    status = mpack_read(&session->reader, buf, buflen, &tok);
    if (status) break;
    status = mpack_rpc_receive_tok(session, tok, msg);
    if (status >= MPACK_RPC_REQUEST) break;
  } while (*buflen);

  return status;
}

MPACK_API int mpack_rpc_request(mpack_rpc_session_t *session, char **buf,
    size_t *buflen, mpack_data_t data)
{
  int status = MPACK_EOF;

  while (status && *buflen) {
    int write_status;
    mpack_token_t tok;
    if (!session->writer.plen) {
      status = mpack_rpc_request_tok(session, &tok, data);
    }
    if (status == MPACK_NOMEM) break;
    write_status = mpack_write(&session->writer, buf, buflen, &tok);
    status = write_status ? write_status : status;
  }

  return status;
}

MPACK_API int mpack_rpc_reply(mpack_rpc_session_t *session, char **buf,
    size_t *buflen, mpack_uint32_t id)
{
  int status = MPACK_EOF;

  while (status && *buflen) {
    int write_status;
    mpack_token_t tok;
    if (!session->writer.plen) {
      status = mpack_rpc_reply_tok(session, &tok, id);
    }
    write_status = mpack_write(&session->writer, buf, buflen, &tok);
    status = write_status ? write_status : status;
  }

  return status;
}

MPACK_API int mpack_rpc_notify(mpack_rpc_session_t *session, char **buf,
    size_t *buflen)
{
  int status = MPACK_EOF;

  while (status && *buflen) {
    int write_status;
    mpack_token_t tok;
    if (!session->writer.plen) {
      status = mpack_rpc_notify_tok(session, &tok);
    }
    write_status = mpack_write(&session->writer, buf, buflen, &tok);
    status = write_status ? write_status : status;
  }

  return status;
}

MPACK_API void mpack_rpc_session_copy(mpack_rpc_session_t *dst,
    mpack_rpc_session_t *src)
{
  mpack_uint32_t i;
  mpack_uint32_t dst_capacity = dst->capacity; 
  assert(src->capacity <= dst_capacity);
  /* copy all fields except slots */
  memcpy(dst, src, sizeof(mpack_rpc_one_session_t) -
      sizeof(struct mpack_rpc_slot_s));
  /* reset capacity */
  dst->capacity = dst_capacity;
  /* reinsert requests  */
  memset(dst->slots, 0, sizeof(struct mpack_rpc_slot_s) * dst->capacity);
  for (i = 0; i < src->capacity; i++) {
    if (src->slots[i].used) mpack_rpc_put(dst, src->slots[i].msg);
  }
}

static mpack_rpc_header_t mpack_rpc_request_hdr(void)
{
  mpack_rpc_header_t hdr;
  hdr.index = 0;
  hdr.toks[0].type = MPACK_TOKEN_ARRAY;
  hdr.toks[0].length = 4;
  hdr.toks[1].type = MPACK_TOKEN_UINT;
  hdr.toks[1].data.value.lo = 0;
  hdr.toks[1].data.value.hi = 0;
  return hdr;
}

static mpack_rpc_header_t mpack_rpc_reply_hdr(void)
{
  mpack_rpc_header_t hdr = mpack_rpc_request_hdr();
  hdr.toks[1].data.value.lo = 1;
  hdr.toks[1].data.value.hi = 0;
  return hdr;
}

static mpack_rpc_header_t mpack_rpc_notify_hdr(void)
{
  mpack_rpc_header_t hdr = mpack_rpc_request_hdr();
  hdr.toks[0].length = 3;
  hdr.toks[1].data.value.lo = 2;
  hdr.toks[1].data.value.hi = 0;
  return hdr;
}

static int mpack_rpc_put(mpack_rpc_session_t *session, mpack_rpc_message_t msg)
{
  struct mpack_rpc_slot_s *slot = NULL;
  mpack_uint32_t i;
  mpack_uint32_t hash = msg.id % session->capacity;

  for (i = 0; i < session->capacity; i++) {
    if (!session->slots[hash].used || session->slots[hash].msg.id == msg.id) {
      slot = session->slots + hash;
      break;
    }
    hash = hash > 0 ? hash - 1 : session->capacity - 1;
  }

  if (!slot) return -1; /* no space */
  if (slot->msg.id == msg.id && slot->used) return 0;  /* duplicate key */
  slot->msg = msg;
  slot->used = 1;
  return 1;
}

static int mpack_rpc_pop(mpack_rpc_session_t *session, mpack_rpc_message_t *msg)
{
  struct mpack_rpc_slot_s *slot = NULL;
  mpack_uint32_t i;
  mpack_uint32_t hash = msg->id % session->capacity;

  for (i = 0; i < session->capacity; i++) {
    if (session->slots[hash].used && session->slots[hash].msg.id == msg->id) {
      slot = session->slots + hash;
      break;
    }
    hash = hash > 0 ? hash - 1 : session->capacity - 1;
  }
  
  if (!slot) return 0;

  *msg = slot->msg;
  slot->used = 0;

  return 1;
}

static void mpack_rpc_reset_hdr(mpack_rpc_header_t *hdr)
{
  hdr->index = 0;
}
