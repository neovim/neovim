#include <string.h>

#include "object.h"

static int mpack_parser_full(mpack_parser_t *w);
static mpack_node_t *mpack_parser_push(mpack_parser_t *w);
static mpack_node_t *mpack_parser_pop(mpack_parser_t *w);

MPACK_API void mpack_parser_init(mpack_parser_t *parser,
    mpack_uint32_t capacity)
{
  mpack_tokbuf_init(&parser->tokbuf);
  parser->data.p = NULL;
  parser->capacity = capacity ? capacity : MPACK_MAX_OBJECT_DEPTH;
  parser->size = 0;
  parser->exiting = 0;
  memset(parser->items, 0, sizeof(mpack_node_t) * (parser->capacity + 1));
  parser->items[0].pos = (size_t)-1;
  parser->status = 0;
}

#define MPACK_EXCEPTION_CHECK(parser)                                           \
  do {                                                                      \
    if (parser->status == MPACK_EXCEPTION) {                                    \
      return MPACK_EXCEPTION;                                                   \
    }                                                                       \
  } while (0)

#define MPACK_WALK(action)                                                  \
  do {                                                                      \
    mpack_node_t *n;                                                        \
                                                                            \
    if (parser->exiting) goto exit;                                         \
    if (mpack_parser_full(parser)) return MPACK_NOMEM;                      \
    n = mpack_parser_push(parser);                                          \
    action;                                                                 \
    MPACK_EXCEPTION_CHECK(parser);                                              \
    parser->exiting = 1;                                                    \
    return MPACK_EOF;                                                       \
                                                                            \
exit:                                                                       \
    parser->exiting = 0;                                                    \
    while ((n = mpack_parser_pop(parser))) {                                \
      exit_cb(parser, n);                                                   \
      MPACK_EXCEPTION_CHECK(parser);                                            \
      if (!parser->size) return MPACK_OK;                                   \
    }                                                                       \
                                                                            \
    return MPACK_EOF;                                                       \
  } while (0)

MPACK_API int mpack_parse_tok(mpack_parser_t *parser, mpack_token_t tok,
    mpack_walk_cb enter_cb, mpack_walk_cb exit_cb)
{
  MPACK_EXCEPTION_CHECK(parser);
  MPACK_WALK({n->tok = tok; enter_cb(parser, n);});
}

MPACK_API int mpack_unparse_tok(mpack_parser_t *parser, mpack_token_t *tok,
    mpack_walk_cb enter_cb, mpack_walk_cb exit_cb)
{
  MPACK_EXCEPTION_CHECK(parser);
  MPACK_WALK({enter_cb(parser, n); *tok = n->tok;});
}

MPACK_API int mpack_parse(mpack_parser_t *parser, const char **buf,
    size_t *buflen, mpack_walk_cb enter_cb, mpack_walk_cb exit_cb)
{
  int status = MPACK_EOF;
  MPACK_EXCEPTION_CHECK(parser);

  while (*buflen && status) {
    mpack_token_t tok;
    mpack_tokbuf_t *tb = &parser->tokbuf;
    const char *buf_save = *buf;
    size_t buflen_save = *buflen;

    if ((status = mpack_read(tb, buf, buflen, &tok)) == MPACK_EOF) continue;
    else if (status == MPACK_ERROR) goto rollback;

    do {
      status = mpack_parse_tok(parser, tok, enter_cb, exit_cb);
      MPACK_EXCEPTION_CHECK(parser);
    } while (parser->exiting);

    if (status != MPACK_NOMEM) continue;

rollback:
    /* restore buf/buflen so the next call will try to read the same token */
    *buf = buf_save;
    *buflen = buflen_save;
    break;
  }

  return status;
}

MPACK_API int mpack_unparse(mpack_parser_t *parser, char **buf, size_t *buflen,
    mpack_walk_cb enter_cb, mpack_walk_cb exit_cb)
{
  int status = MPACK_EOF;
  MPACK_EXCEPTION_CHECK(parser);

  while (*buflen && status) {
    int write_status;
    mpack_token_t tok;
    mpack_tokbuf_t *tb = &parser->tokbuf;

    if (!tb->plen)
      parser->status = mpack_unparse_tok(parser, &tok, enter_cb, exit_cb);

    MPACK_EXCEPTION_CHECK(parser);

    status = parser->status;

    if (status == MPACK_NOMEM)
      break;

    if (parser->exiting) {
      write_status = mpack_write(tb, buf, buflen, &tok);
      status = write_status ? write_status : status;
    }
  }

  return status;
}

MPACK_API void mpack_parser_copy(mpack_parser_t *d, mpack_parser_t *s)
{
  // workaround UBSAN being NOT happy with a flexible array member with arr[N>1] initial size
  mpack_one_parser_t *dst = (mpack_one_parser_t *)d;
  mpack_one_parser_t *src = (mpack_one_parser_t *)s;
  mpack_uint32_t i;
  mpack_uint32_t dst_capacity = dst->capacity; 
  assert(src->capacity <= dst_capacity);
  /* copy all fields except the stack */
  memcpy(dst, src, sizeof(mpack_one_parser_t) - sizeof(mpack_node_t));
  /* reset capacity */
  dst->capacity = dst_capacity;
  /* copy the stack */
  for (i = 0; i <= src->capacity; i++) {
    dst->items[i] = src->items[i];
  }
}

static int mpack_parser_full(mpack_parser_t *parser)
{
  return parser->size == parser->capacity;
}

static mpack_node_t *mpack_parser_push(mpack_parser_t *p)
{
  mpack_one_parser_t *parser = (mpack_one_parser_t *)p;
  mpack_node_t *top;
  assert(parser->size < parser->capacity);
  top = parser->items + parser->size + 1;
  top->data[0].p = NULL;
  top->data[1].p = NULL;
  top->pos = 0;
  top->key_visited = 0;
  /* increase size and invoke callback, passing parent node if any */
  parser->size++;
  return top;
}

static mpack_node_t *mpack_parser_pop(mpack_parser_t *p)
{
  mpack_one_parser_t *parser = (mpack_one_parser_t *)p;
  mpack_node_t *top, *parent;
  assert(parser->size);
  top = parser->items + parser->size;

  if (top->tok.type > MPACK_TOKEN_CHUNK && top->pos < top->tok.length) {
    /* continue processing children */
    return NULL;
  }

  parent = MPACK_PARENT_NODE(top);
  if (parent) {
    /* we use parent->tok.length to keep track of how many children remain.
     * update it to reflect the processed node. */
    if (top->tok.type == MPACK_TOKEN_CHUNK) {
      parent->pos += top->tok.length;
    } else if (parent->tok.type == MPACK_TOKEN_MAP) {
      /* maps allow up to 2^32 - 1 pairs, so to allow this many items in a
       * 32-bit length variable we use an additional flag to determine if the
       * key of a certain position was visited */
      if (parent->key_visited) {
        parent->pos++;
      }
      parent->key_visited = !parent->key_visited;
    } else {
      parent->pos++;
    }
  }

  parser->size--;
  return top;
}

