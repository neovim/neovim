#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "mpack/conv.h"
#include "mpack/mpack_core.h"
#include "mpack/object.h"
#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/eval/decode.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/eval_defs.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/vim_defs.h"

/// Helper structure for container_struct
typedef struct {
  size_t stack_index;   ///< Index of current container in stack.
  list_T *special_val;  ///< _VAL key contents for special maps.
                        ///< When container is not a special dictionary it is
                        ///< NULL.
  const char *s;        ///< Location where container starts.
  typval_T container;   ///< Container. Either VAR_LIST, VAR_DICT or VAR_LIST
                        ///< which is _VAL from special dictionary.
} ContainerStackItem;

/// Helper structure for values struct
typedef struct {
  bool is_special_string;  ///< Indicates that current value is a special
                           ///< dictionary with string.
  bool didcomma;           ///< True if previous token was comma.
  bool didcolon;           ///< True if previous token was colon.
  typval_T val;            ///< Actual value.
} ValuesStackItem;

/// Vector containing values not yet saved in any container
typedef kvec_t(ValuesStackItem) ValuesStack;

/// Vector containing containers, each next container is located inside previous
typedef kvec_t(ContainerStackItem) ContainerStack;

#include "eval/decode.c.generated.h"

/// Create special dictionary
///
/// @param[out]  rettv  Location where created dictionary will be saved.
/// @param[in]  type  Type of the dictionary.
/// @param[in]  val  Value associated with the _VAL key.
static inline void create_special_dict(typval_T *const rettv, const MessagePackType type,
                                       typval_T val)
  FUNC_ATTR_NONNULL_ALL
{
  dict_T *const dict = tv_dict_alloc();
  dictitem_T *const type_di = tv_dict_item_alloc_len(S_LEN("_TYPE"));
  type_di->di_tv.v_type = VAR_LIST;
  type_di->di_tv.v_lock = VAR_UNLOCKED;
  type_di->di_tv.vval.v_list = (list_T *)eval_msgpack_type_lists[type];
  tv_list_ref(type_di->di_tv.vval.v_list);
  tv_dict_add(dict, type_di);
  dictitem_T *const val_di = tv_dict_item_alloc_len(S_LEN("_VAL"));
  val_di->di_tv = val;
  tv_dict_add(dict, val_di);
  dict->dv_refcount++;
  *rettv = (typval_T) {
    .v_type = VAR_DICT,
    .v_lock = VAR_UNLOCKED,
    .vval = { .v_dict = dict },
  };
}

#define DICT_LEN(dict) (dict)->dv_hashtab.ht_used

/// Create a new special dictionary that ought to represent a MAP
///
/// @param[out]  ret_tv  Address where new special dictionary is saved.
/// @param[in]  len  Expected number of items to be populated before list
///                  becomes accessible from Vimscript. It is still valid to
///                  underpopulate a list, value only controls how many elements
///                  will be allocated in advance. @see ListLenSpecials.
///
/// @return [allocated] list which should contain key-value pairs. Return value
///                     may be safely ignored.
list_T *decode_create_map_special_dict(typval_T *const ret_tv, const ptrdiff_t len)
  FUNC_ATTR_NONNULL_ALL
{
  list_T *const list = tv_list_alloc(len);
  tv_list_ref(list);
  create_special_dict(ret_tv, kMPMap, ((typval_T) {
    .v_type = VAR_LIST,
    .v_lock = VAR_UNLOCKED,
    .vval = { .v_list = list },
  }));
  return list;
}

/// Convert char* string to typval_T
///
/// Depending on whether string has (no) NUL bytes, it may use a special
/// dictionary, VAR_BLOB, or decode string to VAR_STRING.
///
/// @param[in]  s  String to decode.
/// @param[in]  len  String length.
/// @param[in]  force_blob  whether string always should be decoded as a blob,
///                         or only when embedded NUL bytes were present
/// @param[in]  s_allocated  If true, then `s` was allocated and can be saved in
///                          a returned structure. If it is not saved there, it
///                          will be freed.
///
/// @return Decoded string.
typval_T decode_string(const char *const s, const size_t len, bool force_blob,
                       const bool s_allocated)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(s != NULL || len == 0);
  const bool use_blob = force_blob || ((s != NULL) && (memchr(s, NUL, len) != NULL));
  if (use_blob) {
    typval_T tv;
    tv.v_lock = VAR_UNLOCKED;
    blob_T *b = tv_blob_alloc_ret(&tv);
    if (s_allocated) {
      b->bv_ga.ga_data = (void *)s;
      b->bv_ga.ga_len = (int)len;
      b->bv_ga.ga_maxlen = (int)len;
    } else {
      ga_concat_len(&b->bv_ga, s, len);
    }
    return tv;
  }
  return (typval_T) {
    .v_type = VAR_STRING,
    .v_lock = VAR_UNLOCKED,
    .vval = { .v_string = ((s == NULL || s_allocated) ? (char *)s : xmemdupz(s, len)) },
  };
}

static void positive_integer_to_special_typval(typval_T *rettv, uint64_t val)
{
  if (val <= VARNUMBER_MAX) {
    *rettv = (typval_T) {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_number = (varnumber_T)val },
    };
  } else {
    list_T *const list = tv_list_alloc(4);
    tv_list_ref(list);
    create_special_dict(rettv, kMPInteger, ((typval_T) {
      .v_type = VAR_LIST,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_list = list },
    }));
    tv_list_append_number(list, 1);
    tv_list_append_number(list, (varnumber_T)((val >> 62) & 0x3));
    tv_list_append_number(list, (varnumber_T)((val >> 31) & 0x7FFFFFFF));
    tv_list_append_number(list, (varnumber_T)(val & 0x7FFFFFFF));
  }
}

static void typval_parse_enter(mpack_parser_t *parser, mpack_node_t *node)
{
  typval_T *result = NULL;

  mpack_node_t *parent = MPACK_PARENT_NODE(node);
  if (parent) {
    switch (parent->tok.type) {
    case MPACK_TOKEN_ARRAY: {
      list_T *list = parent->data[1].p;
      result = tv_list_append_owned_tv(list, (typval_T) { .v_type = VAR_UNKNOWN });
      break;
    }
    case MPACK_TOKEN_MAP: {
      typval_T(*items)[2] = parent->data[1].p;
      result = &items[parent->pos][parent->key_visited];
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
    result = parser->data.p;
  }

  // for types that are completed in typval_parse_exit
  node->data[0].p = result;
  node->data[1].p = NULL;  // free on error if non-NULL

  switch (node->tok.type) {
  case MPACK_TOKEN_NIL:
    *result = (typval_T) {
      .v_type = VAR_SPECIAL,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_special = kSpecialVarNull },
    };
    break;
  case MPACK_TOKEN_BOOLEAN:
    *result = (typval_T) {
      .v_type = VAR_BOOL,
      .v_lock = VAR_UNLOCKED,
      .vval = {
        .v_bool = mpack_unpack_boolean(node->tok) ? kBoolVarTrue : kBoolVarFalse
      },
    };
    break;
  case MPACK_TOKEN_SINT: {
    *result = (typval_T) {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_number = mpack_unpack_sint(node->tok) },
    };
    break;
  }
  case MPACK_TOKEN_UINT:
    positive_integer_to_special_typval(result, mpack_unpack_uint(node->tok));
    break;
  case MPACK_TOKEN_FLOAT:
    *result = (typval_T) {
      .v_type = VAR_FLOAT,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_float = mpack_unpack_float(node->tok) },
    };
    break;

  case MPACK_TOKEN_BIN:
  case MPACK_TOKEN_STR:
  case MPACK_TOKEN_EXT:
    // actually converted in typval_parse_exit after the data chunks
    node->data[1].p = xmallocz(node->tok.length);
    break;
  case MPACK_TOKEN_CHUNK: {
    char *data = parent->data[1].p;
    memcpy(data + parent->pos,
           node->tok.data.chunk_ptr, node->tok.length);
    break;
  }

  case MPACK_TOKEN_ARRAY: {
    list_T *const list = tv_list_alloc((ptrdiff_t)node->tok.length);
    tv_list_ref(list);
    *result = (typval_T) {
      .v_type = VAR_LIST,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_list = list },
    };
    node->data[1].p = list;
    break;
  }
  case MPACK_TOKEN_MAP:
    // we don't know if this will be safe to convert to a typval dict yet
    node->data[1].p = xmallocz(node->tok.length * 2 * sizeof(typval_T));
    break;
  }
}

/// Free node which was entered but never exited, due to a nested error
///
/// Don't bother with typvals as these will be GC:d eventually
void typval_parser_error_free(mpack_parser_t *parser)
{
  for (uint32_t i = 0; i < parser->size; i++) {
    mpack_node_t *node = &parser->items[i];
    switch (node->tok.type) {
    case MPACK_TOKEN_BIN:
    case MPACK_TOKEN_STR:
    case MPACK_TOKEN_EXT:
    case MPACK_TOKEN_MAP:
      XFREE_CLEAR(node->data[1].p);
      break;
    default:
      break;
    }
  }
}

static void typval_parse_exit(mpack_parser_t *parser, mpack_node_t *node)
{
  typval_T *result = node->data[0].p;
  switch (node->tok.type) {
  case MPACK_TOKEN_BIN:
  case MPACK_TOKEN_STR:
    *result = decode_string(node->data[1].p, node->tok.length, false, true);
    node->data[1].p = NULL;
    break;

  case MPACK_TOKEN_EXT: {
    list_T *const list = tv_list_alloc(2);
    tv_list_ref(list);
    tv_list_append_number(list, node->tok.data.ext_type);
    list_T *const ext_val_list = tv_list_alloc(kListLenMayKnow);
    tv_list_append_list(list, ext_val_list);
    create_special_dict(result, kMPExt, ((typval_T) { .v_type = VAR_LIST,
                                                      .v_lock = VAR_UNLOCKED,
                                                      .vval = { .v_list = list } }));
    // TODO(bfredl): why not use BLOB?
    encode_list_write((void *)ext_val_list, node->data[1].p, node->tok.length);
    XFREE_CLEAR(node->data[1].p);
  }
  break;

  case MPACK_TOKEN_MAP: {
    typval_T(*items)[2] = node->data[1].p;
    for (size_t i = 0; i < node->tok.length; i++) {
      typval_T *key = &items[i][0];
      if (key->v_type != VAR_STRING
          || key->vval.v_string == NULL
          || key->vval.v_string[0] == NUL) {
        goto msgpack_to_vim_generic_map;
      }
    }
    dict_T *const dict = tv_dict_alloc();
    dict->dv_refcount++;
    *result = (typval_T) {
      .v_type = VAR_DICT,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_dict = dict },
    };
    for (size_t i = 0; i < node->tok.length; i++) {
      char *key = items[i][0].vval.v_string;
      size_t keylen = strlen(key);
      dictitem_T *const di = xmallocz(offsetof(dictitem_T, di_key) + keylen);
      memcpy(&di->di_key[0], key, keylen);
      di->di_tv.v_type = VAR_UNKNOWN;
      if (tv_dict_add(dict, di) == FAIL) {
        // Duplicate key: fallback to generic map
        TV_DICT_ITER(dict, d, {
            d->di_tv.v_type = VAR_SPECIAL;  // don't free values in tv_clear(), they will be reused
            d->di_tv.vval.v_special = kSpecialVarNull;
          });
        tv_clear(result);
        xfree(di);
        goto msgpack_to_vim_generic_map;
      }
      di->di_tv = items[i][1];
    }
    for (size_t i = 0; i < node->tok.length; i++) {
      xfree(items[i][0].vval.v_string);
    }
    XFREE_CLEAR(node->data[1].p);
    break;
msgpack_to_vim_generic_map: {}
    list_T *const list = decode_create_map_special_dict(result, node->tok.length);
    for (size_t i = 0; i < node->tok.length; i++) {
      list_T *const kv_pair = tv_list_alloc(2);
      tv_list_append_list(list, kv_pair);

      tv_list_append_owned_tv(kv_pair, items[i][0]);
      tv_list_append_owned_tv(kv_pair, items[i][1]);
    }
    XFREE_CLEAR(node->data[1].p);
    break;
  }

  default:
    // other kinds are handled completely in typval_parse_enter
    break;
  }
}

int mpack_parse_typval(mpack_parser_t *parser, const char **data, size_t *size)
{
  return mpack_parse(parser, data, size, typval_parse_enter, typval_parse_exit);
}

int unpack_typval(const char **data, size_t *size, typval_T *ret)
{
  ret->v_type = VAR_UNKNOWN;
  mpack_parser_t parser;
  mpack_parser_init(&parser, 0);
  parser.data.p = ret;
  int status = mpack_parse_typval(&parser, data, size);
  if (status != MPACK_OK) {
    typval_parser_error_free(&parser);
    tv_clear(ret);
  }
  return status;
}
