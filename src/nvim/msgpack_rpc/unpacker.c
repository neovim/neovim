#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <uv.h>

#include "klib/kvec.h"
#include "mpack/conv.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/grid.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/msgpack_rpc/unpacker.h"
#include "nvim/strings.h"
#include "nvim/ui_client.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/unpacker.c.generated.h"
#endif

Object unpack(const char *data, size_t size, Arena *arena, Error *err)
{
  Unpacker unpacker;
  mpack_parser_init(&unpacker.parser, 0);
  unpacker.parser.data.p = &unpacker;
  unpacker.arena = *arena;

  int result = mpack_parse(&unpacker.parser, &data, &size,
                           api_parse_enter, api_parse_exit);

  *arena = unpacker.arena;

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
      KeyValuePair *kv = &kv_A(obj->data.dict, parent->pos);
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
    *result = BOOLEAN_OBJ(mpack_unpack_boolean(node->tok));
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
    Dict dict = KV_INITIAL_VALUE;
    kv_fixsize_arena(&p->arena, dict, node->tok.length);
    kv_size(dict) = node->tok.length;
    *result = DICT_OBJ(dict);
    node->data[0].p = result;
    break;
  }
  }
}

static void api_parse_exit(mpack_parser_t *parser, mpack_node_t *node)
{
}

void unpacker_init(Unpacker *p)
{
  mpack_parser_init(&p->parser, 0);
  p->parser.data.p = p;
  mpack_tokbuf_init(&p->reader);
  p->unpack_error = ERROR_INIT;

  p->arena = (Arena)ARENA_EMPTY;

  p->has_grid_line_event = false;
}

void unpacker_teardown(Unpacker *p)
{
  arena_mem_free(arena_finish(&p->arena));
}

bool unpacker_parse_header(Unpacker *p)
{
  mpack_token_t tok;
  int result;

  const char *data = p->read_ptr;
  size_t size = p->read_size;

  assert(!ERROR_SET(&p->unpack_error));

  // TODO(bfredl): eliminate p->reader, we can use mpack_rtoken directly
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
// Later on, we want to specialize state 2 into more sub-states depending
// on the specific method. "nvim_exec_lua" should just decode direct into lua
// objects. For the moment "redraw/grid_line" uses a hand-rolled decoder,
// to avoid a blizzard of small objects for each screen cell.
//
// <0>[2, "redraw", <10>[<11>["method", <12>[args], <12>[args], ...], <11>[...], ...]]
//
// Where [args] gets unpacked as an Array. Note: first {11} is not saved as a state.
//
// When method is "grid_line", we furthermore decode a cell at a time like:
//
// <0>[2, "redraw", <10>[<11>["grid_line", <14>[g, r, c, [<15>[cell], <15>[cell], ...], <16>wrap]], <11>[...], ...]]
//
// where [cell] is [char, repeat, attr], where 'repeat' and 'attr' is optional

bool unpacker_advance(Unpacker *p)
{
  assert(p->state >= 0);
  p->has_grid_line_event = false;
  if (p->state == 0) {
    if (!unpacker_parse_header(p)) {
      return false;
    }
    if (p->type == kMessageTypeNotification && p->handler.fn == handle_ui_client_redraw) {
      p->type = kMessageTypeRedrawEvent;
      p->state = 10;
    } else {
      p->state = p->type == kMessageTypeResponse ? 1 : 2;
      p->arena = (Arena)ARENA_EMPTY;
    }
  }

  if (p->state >= 10 && p->state != 13) {
    if (!unpacker_parse_redraw(p)) {
      return false;
    }

    if (p->state == 16) {
      // grid_line event already unpacked
      p->has_grid_line_event = true;
      goto done;
    } else {
      assert(p->state == 12);
      // unpack other ui events using mpack_parse()
      p->arena = (Arena)ARENA_EMPTY;
      p->state = 13;
    }
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

done:
  switch (p->state) {
  case 1:
    p->error = p->result;
    p->state = 2;
    goto rerun;
  case 2:
    p->state = 0;
    return true;
  case 13:
  case 16:
    p->ncalls--;
    if (p->ncalls > 0) {
      p->state = (p->state == 16) ? 14 : 12;
    } else if (p->nevents > 0) {
      p->state = 11;
    } else {
      p->state = 0;
    }
    return true;
  default:
    abort();
  }
}

bool unpacker_parse_redraw(Unpacker *p)
{
  mpack_token_t tok;
  int result;

  const char *data = p->read_ptr;
  size_t size = p->read_size;
  GridLineEvent *g = &p->grid_line_event;

#define NEXT_TYPE(tok, typ) \
  result = mpack_rtoken(&data, &size, &tok); \
  if (result == MPACK_EOF) { \
    return false; \
  } else if (result || (tok.type != typ \
                        && !(typ == MPACK_TOKEN_STR && tok.type == MPACK_TOKEN_BIN) \
                        && !(typ == MPACK_TOKEN_SINT && tok.type == MPACK_TOKEN_UINT))) { \
    p->state = -1; \
    return false; \
  }

  switch (p->state) {
  case 10:
    NEXT_TYPE(tok, MPACK_TOKEN_ARRAY);
    p->nevents = (int)tok.length;
    FALLTHROUGH;

  case 11:
    NEXT_TYPE(tok, MPACK_TOKEN_ARRAY);
    p->ncalls = (int)tok.length;

    if (p->ncalls-- == 0) {
      p->state = -1;
      return false;
    }

    NEXT_TYPE(tok, MPACK_TOKEN_STR);
    if (tok.length > size) {
      return false;
    }

    p->ui_handler = ui_client_get_redraw_handler(data, tok.length, NULL);
    data += tok.length;
    size -= tok.length;

    p->nevents--;
    p->read_ptr = data;
    p->read_size = size;
    if (p->ui_handler.fn != ui_client_event_grid_line) {
      p->state = 12;
      return true;
    } else {
      p->state = 14;
      p->arena = (Arena)ARENA_EMPTY;
    }
    FALLTHROUGH;

  case 14:
    NEXT_TYPE(tok, MPACK_TOKEN_ARRAY);
    int eventarrsize = (int)tok.length;
    if (eventarrsize != 5) {
      p->state = -1;
      return false;
    }

    for (int i = 0; i < 3; i++) {
      NEXT_TYPE(tok, MPACK_TOKEN_UINT);
      g->args[i] = (int)tok.data.value.lo;
    }

    NEXT_TYPE(tok, MPACK_TOKEN_ARRAY);
    g->ncells = (int)tok.length;
    g->icell = 0;
    g->coloff = 0;
    g->cur_attr = -1;

    p->read_ptr = data;
    p->read_size = size;
    p->state = 15;
    FALLTHROUGH;

  case 15:
    for (; g->icell != g->ncells; g->icell++) {
      assert(g->icell < g->ncells);

      NEXT_TYPE(tok, MPACK_TOKEN_ARRAY);
      int cellarrsize = (int)tok.length;
      if (cellarrsize < 1 || cellarrsize > 3) {
        p->state = -1;
        return false;
      }

      NEXT_TYPE(tok, MPACK_TOKEN_STR);
      if (tok.length > size) {
        return false;
      }

      const char *cellbuf = data;
      size_t cellsize = tok.length;
      data += cellsize;
      size -= cellsize;

      if (cellarrsize >= 2) {
        NEXT_TYPE(tok, MPACK_TOKEN_SINT);
        g->cur_attr = (int)tok.data.value.lo;
      }

      int repeat = 1;
      if (cellarrsize >= 3) {
        NEXT_TYPE(tok, MPACK_TOKEN_UINT);
        repeat = (int)tok.data.value.lo;
      }

      g->clear_width = 0;
      if (g->icell == g->ncells - 1 && cellsize == 1 && cellbuf[0] == ' ' && repeat > 1) {
        g->clear_width = repeat;
      } else {
        schar_T sc = schar_from_buf(cellbuf, cellsize);
        for (int r = 0; r < repeat; r++) {
          if (g->coloff >= (int)grid_line_buf_size) {
            p->state = -1;
            return false;
          }
          grid_line_buf_char[g->coloff] = sc;
          grid_line_buf_attr[g->coloff++] = g->cur_attr;
        }
      }

      p->read_ptr = data;
      p->read_size = size;
    }
    p->state = 16;
    FALLTHROUGH;

  case 16:
    NEXT_TYPE(tok, MPACK_TOKEN_BOOLEAN);
    g->wrap = mpack_unpack_boolean(tok);
    p->read_ptr = data;
    p->read_size = size;
    return true;

  case 12:
    return true;

  default:
    abort();
  }
}

/// Requires a complete string. safe to use e.g. in shada as we have loaded a
/// complete shada item into a linear buffer.
///
/// Data and size are preserved in cause of failure.
///
/// @return "data" is NULL only when failure (non-null data and size=0 for
/// valid empty string)
String unpack_string(const char **data, size_t *size)
{
  const char *data2 = *data;
  size_t size2 = *size;
  mpack_token_t tok;

  // TODO(bfredl): this code is hot a f, specialize!
  int result = mpack_rtoken(&data2, &size2, &tok);
  if (result || (tok.type != MPACK_TOKEN_STR && tok.type != MPACK_TOKEN_BIN)) {
    return (String)STRING_INIT;
  }
  if (*size < tok.length) {
    // result = MPACK_EOF;
    return (String)STRING_INIT;
  }
  (*data) = data2 + tok.length;
  (*size) = size2 - tok.length;
  return cbuf_as_string((char *)data2, tok.length);
}

/// @return -1 if not an array or EOF. otherwise size of valid array
ssize_t unpack_array(const char **data, size_t *size)
{
  // TODO(bfredl): this code is hot, specialize!
  mpack_token_t tok;
  int result = mpack_rtoken(data, size, &tok);
  if (result || tok.type != MPACK_TOKEN_ARRAY) {
    return -1;
  }
  return tok.length;
}

/// does not keep "data" untouched on failure
bool unpack_integer(const char **data, size_t *size, Integer *res)
{
  mpack_token_t tok;
  int result = mpack_rtoken(data, size, &tok);
  if (result) {
    return false;
  }
  return unpack_uint_or_sint(tok, res);
}

bool unpack_uint_or_sint(mpack_token_t tok, Integer *res)
{
  if (tok.type == MPACK_TOKEN_UINT) {
    *res = (Integer)mpack_unpack_uint(tok);
    return true;
  } else if (tok.type == MPACK_TOKEN_SINT) {
    *res = (Integer)mpack_unpack_sint(tok);
    return true;
  }
  return false;
}

static void parse_nop(mpack_parser_t *parser, mpack_node_t *node)
{
}

int unpack_skip(const char **data, size_t *size)
{
  mpack_parser_t parser;
  mpack_parser_init(&parser, 0);

  return mpack_parse(&parser, data, size, parse_nop, parse_nop);
}

void push_additional_data(AdditionalDataBuilder *ad, const char *data, size_t size)
{
  if (kv_size(*ad) == 0) {
    AdditionalData init = { 0 };
    kv_concat_len(*ad, &init, sizeof(init));
  }
  AdditionalData *a = (AdditionalData *)ad->items;
  a->nitems++;
  a->nbytes += (uint32_t)size;
  kv_concat_len(*ad, data, size);
}

// currently only used for shada, so not re-entrant like unpacker_parse_redraw
bool unpack_keydict(void *retval, FieldHashfn hashy, AdditionalDataBuilder *ad, const char **data,
                    size_t *restrict size, char **error)
{
  OptKeySet *ks = (OptKeySet *)retval;
  mpack_token_t tok;

  int result = mpack_rtoken(data, size, &tok);
  if (result || tok.type != MPACK_TOKEN_MAP) {
    *error = xstrdup("is not a dict");
    return false;
  }

  size_t map_size = tok.length;

  for (size_t i = 0; i < map_size; i++) {
    const char *item_start = *data;
    // TODO(bfredl): we could specialize a hot path for FIXSTR here
    String key = unpack_string(data, size);
    if (!key.data) {
      *error = arena_printf(NULL, "has key value which is not a string").data;
      return false;
    } else if (key.size == 0) {
      *error = arena_printf(NULL, "has empty key").data;
      return false;
    }
    KeySetLink *field = hashy(key.data, key.size);

    if (!field) {
      int status = unpack_skip(data, size);
      if (status) {
        return false;
      }

      if (ad) {
        push_additional_data(ad, item_start, (size_t)(*data - item_start));
      }
      continue;
    }

    assert(field->opt_index >= 0);
    uint64_t flag = (1ULL << field->opt_index);
    if (ks->is_set_ & flag) {
      *error = xstrdup("duplicate key");
      return false;
    }
    ks->is_set_ |= flag;

    char *mem = ((char *)retval + field->ptr_off);
    switch (field->type) {
    case kObjectTypeBoolean:
      if (*size == 0 || (**data & 0xfe) != 0xc2) {
        *error = arena_printf(NULL, "has %.*s key value which is not a boolean", (int)key.size,
                              key.data).data;
        return false;
      }
      *(Boolean *)mem = **data & 0x01;
      (*data)++; (*size)--;
      break;

    case kObjectTypeInteger:
      if (!unpack_integer(data, size, (Integer *)mem)) {
        *error = arena_printf(NULL, "has %.*s key value which is not an integer", (int)key.size,
                              key.data).data;
        return false;
      }
      break;

    case kObjectTypeString: {
      String val = unpack_string(data, size);
      if (!val.data) {
        *error = arena_printf(NULL, "has %.*s key value which is not a binary", (int)key.size,
                              key.data).data;
        return false;
      }
      *(String *)mem = val;
      break;
    }

    case kUnpackTypeStringArray: {
      ssize_t len = unpack_array(data, size);
      if (len < 0) {
        *error = arena_printf(NULL, "has %.*s key with non-array value", (int)key.size,
                              key.data).data;
        return false;
      }
      StringArray *a = (StringArray *)mem;
      kv_ensure_space(*a, (size_t)len);
      for (size_t j = 0; j < (size_t)len; j++) {
        String item = unpack_string(data, size);
        if (!item.data) {
          *error = arena_printf(NULL, "has %.*s array with non-binary value", (int)key.size,
                                key.data).data;
          return false;
        }
        kv_push(*a, item);
      }
      break;
    }

    default:
      abort();  // not supported
    }
  }

  return true;
}
