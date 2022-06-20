// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/api/private/helpers.h"
#include "nvim/log.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/msgpack_rpc/unpacker.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/unpacker.c.generated.h"
#endif

Object unpack(const char *data, size_t size, Error *err)
{
  Unpacker unpacker;
  mpack_parser_init(&unpacker.parser, 0);
  unpacker.parser.data.p = &unpacker;

  int result = mpack_parse(&unpacker.parser, &data, &size,
                           api_parse_enter, api_parse_exit);

  if (result == MPACK_NOMEM) {
    api_set_error(err, kErrorTypeException, "object was too deep to unpack");
  } else if (result == MPACK_EOF) {
    api_set_error(err, kErrorTypeException, "incomplete msgpack string");
  } else if (result == MPACK_ERROR) {
    api_set_error(err, kErrorTypeException, "invalid msgpack string");
  } else if (result == MPACK_OK && size) {
    api_set_error(err, kErrorTypeException, "trailing data in msgpack string");
  }

  return unpacker.result;
}

static void api_parse_enter(mpack_parser_t *parser, mpack_node_t *node)
{
  Unpacker *p = parser->data.p;
  Object *result = NULL;
  String *key_location = NULL;

  mpack_node_t *parent = MPACK_PARENT_NODE(node);
  if (parent) {
    switch (parent->tok.type) {
    case MPACK_TOKEN_ARRAY: {
      Object *obj = parent->data[0].p;
      result = &kv_A(obj->data.array, parent->pos);
      break;
    }
    case MPACK_TOKEN_MAP: {
      Object *obj = parent->data[0].p;
      KeyValuePair *kv = &kv_A(obj->data.dictionary, parent->pos);
      if (!parent->key_visited) {
        // TODO(bfredl): when implementing interrupt parse on error,
        // stop parsing here when node is not a STR/BIN
        kv->key = (String)STRING_INIT;
        key_location = &kv->key;
      }
      result = &kv->value;
      break;
    }

    case MPACK_TOKEN_STR:
    case MPACK_TOKEN_BIN:
    case MPACK_TOKEN_EXT:
      assert(node->tok.type == MPACK_TOKEN_CHUNK);
      break;

    default:
      abort();
    }
  } else {
    result = &p->result;
  }

  switch (node->tok.type) {
  case MPACK_TOKEN_NIL:
    *result = NIL;
    break;
  case MPACK_TOKEN_BOOLEAN:
    *result = BOOL(mpack_unpack_boolean(node->tok));
    break;
  case MPACK_TOKEN_SINT:
    *result = INTEGER_OBJ(mpack_unpack_sint(node->tok));
    break;
  case MPACK_TOKEN_UINT:
    *result = INTEGER_OBJ((Integer)mpack_unpack_uint(node->tok));
    break;
  case MPACK_TOKEN_FLOAT:
    *result = FLOAT_OBJ(mpack_unpack_float(node->tok));
    break;

  case MPACK_TOKEN_BIN:
  case MPACK_TOKEN_STR: {
    char *mem = arena_alloc(&p->arena, node->tok.length + 1, false);
    mem[node->tok.length] = NUL;
    String str = { .data = mem, .size = node->tok.length };
    if (key_location) {
      *key_location = str;
    } else {
      *result = STRING_OBJ(str);
    }
    node->data[0].p = str.data;
    break;
  }
  case MPACK_TOKEN_EXT:
    // handled in chunk; but save result location
    node->data[0].p = result;
    break;
  case MPACK_TOKEN_CHUNK:
    assert(parent);
    if (parent->tok.type == MPACK_TOKEN_STR || parent->tok.type == MPACK_TOKEN_BIN) {
      char *data = parent->data[0].p;
      memcpy(data + parent->pos,
             node->tok.data.chunk_ptr, node->tok.length);
    } else {
      Object *res = parent->data[0].p;

      size_t endlen = parent->pos + node->tok.length;
      if (endlen > MAX_EXT_LEN) {
        *res = NIL;
        break;
      }
      memcpy(p->ext_buf + parent->pos,
             node->tok.data.chunk_ptr, node->tok.length);
      if (parent->pos + node->tok.length < parent->tok.length) {
        break;  // EOF, let's get back to it later
      }
      const char *buf = p->ext_buf;
      size_t size = parent->tok.length;
      mpack_token_t ext_tok;
      int status = mpack_rtoken(&buf, &size, &ext_tok);
      if (status || ext_tok.type != MPACK_TOKEN_UINT) {
        // TODO(bfredl): once we fixed memory management, we can set
        // p->unpack_error and a flag like p->interrupted
        *res = NIL;
        break;
      }
      int ext_type = parent->tok.data.ext_type;
      if (0 <= ext_type && ext_type <= EXT_OBJECT_TYPE_MAX) {
        res->type = (ObjectType)(ext_type + EXT_OBJECT_TYPE_SHIFT);
        res->data.integer = (int64_t)mpack_unpack_uint(ext_tok);
      } else {
        *res = NIL;
        break;
      }
    }
    break;

  case MPACK_TOKEN_ARRAY: {
    Array arr = KV_INITIAL_VALUE;
    kv_fixsize_arena(&p->arena, arr, node->tok.length);
    kv_size(arr) = node->tok.length;
    *result = ARRAY_OBJ(arr);
    node->data[0].p = result;
    break;
  }
  case MPACK_TOKEN_MAP: {
    Dictionary dict = KV_INITIAL_VALUE;
    kv_fixsize_arena(&p->arena, dict, node->tok.length);
    kv_size(dict) = node->tok.length;
    *result = DICTIONARY_OBJ(dict);
    node->data[0].p = result;
    break;
  }

  default:
    abort();
  }
}

static void api_parse_exit(mpack_parser_t *parser, mpack_node_t *node)
{}

void unpacker_init(Unpacker *p)
{
  mpack_parser_init(&p->parser, 0);
  p->parser.data.p = p;
  mpack_tokbuf_init(&p->reader);
  p->unpack_error = (Error)ERROR_INIT;

  p->arena = (Arena)ARENA_EMPTY;
  p->reuse_blk = NULL;
}

void unpacker_teardown(Unpacker *p)
{
  arena_mem_free(p->reuse_blk, NULL);
  arena_mem_free(arena_finish(&p->arena), NULL);
}

bool unpacker_parse_header(Unpacker *p)
{
  mpack_token_t tok;
  int result;

  const char *data = p->read_ptr;
  size_t size = p->read_size;

  assert(!ERROR_SET(&p->unpack_error));

#define NEXT(tok) \
  result = mpack_read(&p->reader, &data, &size, &tok); \
  if (result) { goto error; }

  NEXT(tok);
  if (tok.type != MPACK_TOKEN_ARRAY || tok.length < 3 || tok.length > 4) {
    goto error;
  }
  size_t array_length = tok.length;

  NEXT(tok);
  if (tok.type != MPACK_TOKEN_UINT) {
    goto error;
  }
  uint32_t type = (uint32_t)mpack_unpack_uint(tok);
  if ((array_length == 3) ? type != 2 : (type >= 2)) {
    goto error;
  }
  p->type = (MessageType)type;
  p->request_id = 0;

  if (p->type != kMessageTypeNotification) {
    NEXT(tok);
    if (tok.type != MPACK_TOKEN_UINT) {
      goto error;
    }
    p->request_id = (uint32_t)mpack_unpack_uint(tok);
  }

  if (p->type != kMessageTypeResponse) {
    NEXT(tok);
    if ((tok.type != MPACK_TOKEN_STR && tok.type != MPACK_TOKEN_BIN)
        || tok.length > 100) {
      goto error;
    }
    p->method_name_len = tok.length;

    if (p->method_name_len > 0) {
      NEXT(tok);
      assert(tok.type == MPACK_TOKEN_CHUNK);
    }
    if (tok.length < p->method_name_len) {
      result = MPACK_EOF;
      goto error;
    }
    // if this fails, p->handler.fn will be NULL
    p->handler = msgpack_rpc_get_handler_for(tok.length ? tok.data.chunk_ptr : "",
                                             tok.length, &p->unpack_error);
  }

  p->read_ptr = data;
  p->read_size = size;
  return true;
#undef NEXT

error:
  if (result == MPACK_EOF) {
    // recover later by retrying from scratch
    // when more data is available.
    mpack_tokbuf_init(&p->reader);
  } else {
    api_set_error(&p->unpack_error, kErrorTypeValidation, "failed to decode msgpack");
    p->state = -1;
  }
  return false;
}

// BASIC BITCH STATE MACHINE
//
// With some basic assumptions, we can parse the overall structure of msgpack-rpc
// messages with a hand-rolled FSM of just 3 states (<x> = p->state):
//
// <0>[0, request_id, method_name, <2>args]
// <0>[1, request_id, <1>err, <2>result]
// <0>[2, method_name, <2>args]
//
// The assumption here is that the header of the message, which we define as the
// initial array head, the kind integer, request_id and/or method name (when needed),
// is relatively small, just ~10 bytes + the method name. Thus we can simply refuse
// to advance the stream beyond the header until it can be parsed in its entirety.
//
// Of course, later on, we want to specialize state 2 into sub-states depending
// on the specific method. "nvim_exec_lua" should just decode direct into lua
// objects, and "redraw/grid_line" should use a hand-rolled decoder to avoid
// a blizzard of small objects for each screen cell.

bool unpacker_advance(Unpacker *p)
{
  assert(p->state >= 0);
  if (p->state == 0) {
    if (!unpacker_parse_header(p)) {
      return false;
    }
    p->state = p->type == kMessageTypeResponse ? 1 : 2;
    arena_start(&p->arena, &p->reuse_blk);
  }

  int result;

rerun:
  result = mpack_parse(&p->parser, &p->read_ptr, &p->read_size,
                       api_parse_enter, api_parse_exit);

  if (result == MPACK_EOF) {
    return false;
  } else if (result != MPACK_OK) {
    api_set_error(&p->unpack_error, kErrorTypeValidation, "failed to parse msgpack");
    p->state = -1;
    return false;
  }

  if (p->state == 1) {
    p->error = p->result;
    p->state = 2;
    goto rerun;
  } else {
    assert(p->state == 2);
    p->state = 0;
  }
  return true;
}
