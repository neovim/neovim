// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "klib/kvec.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/assert.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/garray.h"
#include "nvim/lua/executor.h"
#include "nvim/memory.h"
#include "nvim/types.h"
#include "nvim/vim.h"

/// Helper structure for vim_to_object
typedef struct {
  kvec_withinit_t(Object, 2) stack;  ///< Object stack.
} EncodedData;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/converter.c.generated.h"
#endif

#define TYPVAL_ENCODE_ALLOW_SPECIALS false

#define TYPVAL_ENCODE_CONV_NIL(tv) \
  kvi_push(edata->stack, NIL)

#define TYPVAL_ENCODE_CONV_BOOL(tv, num) \
  kvi_push(edata->stack, BOOLEAN_OBJ((Boolean)(num)))

#define TYPVAL_ENCODE_CONV_NUMBER(tv, num) \
  kvi_push(edata->stack, INTEGER_OBJ((Integer)(num)))

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER TYPVAL_ENCODE_CONV_NUMBER

#define TYPVAL_ENCODE_CONV_FLOAT(tv, flt) \
  kvi_push(edata->stack, FLOAT_OBJ((Float)(flt)))

#define TYPVAL_ENCODE_CONV_STRING(tv, str, len) \
  do { \
    const size_t len_ = (size_t)(len); \
    const char *const str_ = (str); \
    assert(len_ == 0 || str_ != NULL); \
    kvi_push(edata->stack, STRING_OBJ(cbuf_to_string((len_ ? str_ : ""), len_))); \
  } while (0)

#define TYPVAL_ENCODE_CONV_STR_STRING TYPVAL_ENCODE_CONV_STRING

#define TYPVAL_ENCODE_CONV_EXT_STRING(tv, str, len, type) \
  TYPVAL_ENCODE_CONV_NIL(tv)

#define TYPVAL_ENCODE_CONV_BLOB(tv, blob, len) \
  do { \
    const size_t len_ = (size_t)(len); \
    const blob_T *const blob_ = (blob); \
    kvi_push(edata->stack, STRING_OBJ(((String) { \
      .data = len_ != 0 ? xmemdupz(blob_->bv_ga.ga_data, len_) : xstrdup(""), \
      .size = len_ \
    }))); \
  } while (0)

#define TYPVAL_ENCODE_CONV_FUNC_START(tv, fun) \
  do { \
    ufunc_T *fp = find_func(fun); \
    if (fp != NULL && (fp->uf_flags & FC_LUAREF)) { \
      LuaRef ref = api_new_luaref(fp->uf_luaref); \
      kvi_push(edata->stack, LUAREF_OBJ(ref)); \
    } else { \
      TYPVAL_ENCODE_CONV_NIL(tv); \
    } \
    goto typval_encode_stop_converting_one_item; \
  } while (0)

#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS(tv, len)
#define TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF(tv, len)
#define TYPVAL_ENCODE_CONV_FUNC_END(tv)

#define TYPVAL_ENCODE_CONV_EMPTY_LIST(tv) \
  kvi_push(edata->stack, ARRAY_OBJ(((Array) { .capacity = 0, .size = 0 })))

#define TYPVAL_ENCODE_CONV_EMPTY_DICT(tv, dict) \
  kvi_push(edata->stack, \
           DICTIONARY_OBJ(((Dictionary) { .capacity = 0, .size = 0 })))

static inline void typval_encode_list_start(EncodedData *const edata, const size_t len)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  kvi_push(edata->stack, ARRAY_OBJ(((Array) {
    .capacity = len,
    .size = 0,
    .items = xmalloc(len * sizeof(*((Object)OBJECT_INIT).data.array.items)),
  })));
}

#define TYPVAL_ENCODE_CONV_LIST_START(tv, len) \
  typval_encode_list_start(edata, (size_t)(len))

#define TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START(tv, mpsv)

static inline void typval_encode_between_list_items(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  Object item = kv_pop(edata->stack);
  Object *const list = &kv_last(edata->stack);
  assert(list->type == kObjectTypeArray);
  assert(list->data.array.size < list->data.array.capacity);
  list->data.array.items[list->data.array.size++] = item;
}

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS(tv) \
  typval_encode_between_list_items(edata)

static inline void typval_encode_list_end(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  typval_encode_between_list_items(edata);
#ifndef NDEBUG
  const Object *const list = &kv_last(edata->stack);
  assert(list->data.array.size == list->data.array.capacity);
#endif
}

#define TYPVAL_ENCODE_CONV_LIST_END(tv) \
  typval_encode_list_end(edata)

static inline void typval_encode_dict_start(EncodedData *const edata, const size_t len)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  kvi_push(edata->stack, DICTIONARY_OBJ(((Dictionary) {
    .capacity = len,
    .size = 0,
    .items = xmalloc(len * sizeof(*((Object)OBJECT_INIT).data.dictionary.items)),
  })));
}

#define TYPVAL_ENCODE_CONV_DICT_START(tv, dict, len) \
  typval_encode_dict_start(edata, (size_t)(len))

#define TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START(tv, dict, mpsv)

#define TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK(label, kv_pair)

static inline void typval_encode_after_key(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  Object key = kv_pop(edata->stack);
  Object *const dict = &kv_last(edata->stack);
  assert(dict->type == kObjectTypeDictionary);
  assert(dict->data.dictionary.size < dict->data.dictionary.capacity);
  if (key.type == kObjectTypeString) {
    dict->data.dictionary.items[dict->data.dictionary.size].key
      = key.data.string;
  } else {
    api_free_object(key);
    dict->data.dictionary.items[dict->data.dictionary.size].key
      = STATIC_CSTR_TO_STRING("__INVALID_KEY__");
  }
}

#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY(tv, dict) \
  typval_encode_after_key(edata)

static inline void typval_encode_between_dict_items(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  Object val = kv_pop(edata->stack);
  Object *const dict = &kv_last(edata->stack);
  assert(dict->type == kObjectTypeDictionary);
  assert(dict->data.dictionary.size < dict->data.dictionary.capacity);
  dict->data.dictionary.items[dict->data.dictionary.size++].value = val;
}

#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS(tv, dict) \
  typval_encode_between_dict_items(edata)

static inline void typval_encode_dict_end(EncodedData *const edata)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_NONNULL_ALL
{
  typval_encode_between_dict_items(edata);
#ifndef NDEBUG
  const Object *const dict = &kv_last(edata->stack);
  assert(dict->data.dictionary.size == dict->data.dictionary.capacity);
#endif
}

#define TYPVAL_ENCODE_CONV_DICT_END(tv, dict) \
  typval_encode_dict_end(edata)

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
  TYPVAL_ENCODE_CONV_NIL(val)

#define TYPVAL_ENCODE_SCOPE static
#define TYPVAL_ENCODE_NAME object
#define TYPVAL_ENCODE_FIRST_ARG_TYPE EncodedData *const
#define TYPVAL_ENCODE_FIRST_ARG_NAME edata
#include "nvim/eval/typval_encode.c.h"
#undef TYPVAL_ENCODE_SCOPE
#undef TYPVAL_ENCODE_NAME
#undef TYPVAL_ENCODE_FIRST_ARG_TYPE
#undef TYPVAL_ENCODE_FIRST_ARG_NAME

#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_BLOB
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_FUNC_START
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_ARGS
#undef TYPVAL_ENCODE_CONV_FUNC_BEFORE_SELF
#undef TYPVAL_ENCODE_CONV_FUNC_END
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_REAL_LIST_AFTER_START
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_REAL_DICT_AFTER_START
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_SPECIAL_DICT_KEY_CHECK
#undef TYPVAL_ENCODE_CONV_LIST_END
#undef TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_RECURSE
#undef TYPVAL_ENCODE_ALLOW_SPECIALS

/// Convert a vim object to an `Object` instance, recursively expanding
/// Arrays/Dictionaries.
///
/// @param obj The source object
/// @return The converted value
Object vim_to_object(typval_T *obj)
{
  EncodedData edata;
  kvi_init(edata.stack);
  const int evo_ret = encode_vim_to_object(&edata, obj,
                                           "vim_to_object argument");
  (void)evo_ret;
  assert(evo_ret == OK);
  Object ret = kv_A(edata.stack, 0);
  assert(kv_size(edata.stack) == 1);
  kvi_destroy(edata.stack);
  return ret;
}

/// Converts from type Object to a Vimscript value.
///
/// @param obj  Object to convert from.
/// @param tv   Conversion result is placed here. On failure member v_type is
///             set to VAR_UNKNOWN (no allocation was made for this variable).
/// returns     true if conversion is successful, otherwise false.
bool object_to_vim(Object obj, typval_T *tv, Error *err)
{
  tv->v_type = VAR_UNKNOWN;
  tv->v_lock = VAR_UNLOCKED;

  switch (obj.type) {
  case kObjectTypeNil:
    tv->v_type = VAR_SPECIAL;
    tv->vval.v_special = kSpecialVarNull;
    break;

  case kObjectTypeBoolean:
    tv->v_type = VAR_BOOL;
    tv->vval.v_bool = obj.data.boolean ? kBoolVarTrue : kBoolVarFalse;
    break;

  case kObjectTypeBuffer:
  case kObjectTypeWindow:
  case kObjectTypeTabpage:
  case kObjectTypeInteger:
    STATIC_ASSERT(sizeof(obj.data.integer) <= sizeof(varnumber_T),
                  "Integer size must be <= Vimscript number size");
    tv->v_type = VAR_NUMBER;
    tv->vval.v_number = (varnumber_T)obj.data.integer;
    break;

  case kObjectTypeFloat:
    tv->v_type = VAR_FLOAT;
    tv->vval.v_float = obj.data.floating;
    break;

  case kObjectTypeString:
    tv->v_type = VAR_STRING;
    if (obj.data.string.data == NULL) {
      tv->vval.v_string = NULL;
    } else {
      tv->vval.v_string = xmemdupz(obj.data.string.data,
                                   obj.data.string.size);
    }
    break;

  case kObjectTypeArray: {
    list_T *const list = tv_list_alloc((ptrdiff_t)obj.data.array.size);

    for (uint32_t i = 0; i < obj.data.array.size; i++) {
      Object item = obj.data.array.items[i];
      typval_T li_tv;

      if (!object_to_vim(item, &li_tv, err)) {
        tv_list_free(list);
        return false;
      }

      tv_list_append_owned_tv(list, li_tv);
    }
    tv_list_ref(list);

    tv->v_type = VAR_LIST;
    tv->vval.v_list = list;
    break;
  }

  case kObjectTypeDictionary: {
    dict_T *const dict = tv_dict_alloc();

    for (uint32_t i = 0; i < obj.data.dictionary.size; i++) {
      KeyValuePair item = obj.data.dictionary.items[i];
      String key = item.key;

      if (key.size == 0) {
        api_set_error(err, kErrorTypeValidation,
                      "Empty dictionary keys aren't allowed");
        // cleanup
        tv_dict_free(dict);
        return false;
      }

      dictitem_T *const di = tv_dict_item_alloc(key.data);

      if (!object_to_vim(item.value, &di->di_tv, err)) {
        // cleanup
        tv_dict_item_free(di);
        tv_dict_free(dict);
        return false;
      }

      tv_dict_add(dict, di);
    }
    dict->dv_refcount++;

    tv->v_type = VAR_DICT;
    tv->vval.v_dict = dict;
    break;
  }

  case kObjectTypeLuaRef: {
    char *name = register_luafunc(api_new_luaref(obj.data.luaref));
    tv->v_type = VAR_FUNC;
    tv->vval.v_string = xstrdup(name);
    break;
  }

  default:
    abort();
  }

  return true;
}
