#include <stdint.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/os/msgpack_rpc_helpers.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/msgpack_rpc_helpers.c.generated.h"
#endif

static msgpack_zone zone;
static msgpack_sbuffer sbuffer;

#define HANDLE_TYPE_CONVERSION_IMPL(t, lt)                                  \
  bool msgpack_rpc_to_##lt(msgpack_object *obj, t *arg)                     \
    FUNC_ATTR_NONNULL_ALL                                                   \
  {                                                                         \
    if (obj->type != MSGPACK_OBJECT_EXT                                     \
        || obj->via.ext.type != kObjectType##t) {                           \
      return false;                                                         \
    }                                                                       \
                                                                            \
    msgpack_object data;                                                    \
    msgpack_unpack_return ret = msgpack_unpack(obj->via.ext.ptr,            \
                                               obj->via.ext.size,           \
                                               NULL,                        \
                                               &zone,                       \
                                               &data);                      \
                                                                            \
    if (ret != MSGPACK_UNPACK_SUCCESS) {                                    \
      return false;                                                         \
    }                                                                       \
                                                                            \
    *arg = data.via.u64;                                                    \
    return true;                                                            \
  }                                                                         \
                                                                            \
  void msgpack_rpc_from_##lt(t o, msgpack_packer *res)                      \
    FUNC_ATTR_NONNULL_ARG(2)                                                \
  {                                                                         \
    msgpack_packer pac;                                                     \
    msgpack_packer_init(&pac, &sbuffer, msgpack_sbuffer_write);             \
    msgpack_pack_uint64(&pac, o);                                           \
    msgpack_pack_ext(res, sbuffer.size, kObjectType##t);                    \
    msgpack_pack_ext_body(res, sbuffer.data, sbuffer.size);                 \
    msgpack_sbuffer_clear(&sbuffer);                                        \
  }

void msgpack_rpc_helpers_init(void)
{
  msgpack_zone_init(&zone, 0xfff);
  msgpack_sbuffer_init(&sbuffer);
}

HANDLE_TYPE_CONVERSION_IMPL(Buffer, buffer)
HANDLE_TYPE_CONVERSION_IMPL(Window, window)
HANDLE_TYPE_CONVERSION_IMPL(Tabpage, tabpage)

bool msgpack_rpc_to_boolean(msgpack_object *obj, Boolean *arg)
  FUNC_ATTR_NONNULL_ALL
{
  *arg = obj->via.boolean;
  return obj->type == MSGPACK_OBJECT_BOOLEAN;
}

bool msgpack_rpc_to_integer(msgpack_object *obj, Integer *arg)
  FUNC_ATTR_NONNULL_ALL
{
  if (obj->type == MSGPACK_OBJECT_POSITIVE_INTEGER
      && obj->via.u64 <= INT64_MAX) {
    *arg = (int64_t)obj->via.u64;
    return true;
  }

  *arg = obj->via.i64;
  return obj->type == MSGPACK_OBJECT_NEGATIVE_INTEGER;
}

bool msgpack_rpc_to_float(msgpack_object *obj, Float *arg)
  FUNC_ATTR_NONNULL_ALL
{
  *arg = obj->via.dec;
  return obj->type == MSGPACK_OBJECT_DOUBLE;
}

bool msgpack_rpc_to_string(msgpack_object *obj, String *arg)
  FUNC_ATTR_NONNULL_ALL
{
  if (obj->type == MSGPACK_OBJECT_BIN || obj->type == MSGPACK_OBJECT_STR) {
    arg->data = xmemdupz(obj->via.bin.ptr, obj->via.bin.size);
    arg->size = obj->via.bin.size;
  } else {
    return false;
  }

  return true;
}

bool msgpack_rpc_to_object(msgpack_object *obj, Object *arg)
  FUNC_ATTR_NONNULL_ALL
{
  switch (obj->type) {
    case MSGPACK_OBJECT_NIL:
      arg->type = kObjectTypeNil;
      return true;

    case MSGPACK_OBJECT_BOOLEAN:
      arg->type = kObjectTypeBoolean;
      return msgpack_rpc_to_boolean(obj, &arg->data.boolean);

    case MSGPACK_OBJECT_POSITIVE_INTEGER:
    case MSGPACK_OBJECT_NEGATIVE_INTEGER:
      arg->type = kObjectTypeInteger;
      return msgpack_rpc_to_integer(obj, &arg->data.integer);

    case MSGPACK_OBJECT_DOUBLE:
      arg->type = kObjectTypeFloat;
      return msgpack_rpc_to_float(obj, &arg->data.floating);

    case MSGPACK_OBJECT_BIN:
    case MSGPACK_OBJECT_STR:
      arg->type = kObjectTypeString;
      return msgpack_rpc_to_string(obj, &arg->data.string);

    case MSGPACK_OBJECT_ARRAY:
      arg->type = kObjectTypeArray;
      return msgpack_rpc_to_array(obj, &arg->data.array);

    case MSGPACK_OBJECT_MAP:
      arg->type = kObjectTypeDictionary;
      return msgpack_rpc_to_dictionary(obj, &arg->data.dictionary);

    case MSGPACK_OBJECT_EXT:
      switch (obj->via.ext.type) {
        case kObjectTypeBuffer:
          return msgpack_rpc_to_buffer(obj, &arg->data.buffer);
        case kObjectTypeWindow:
          return msgpack_rpc_to_window(obj, &arg->data.window);
        case kObjectTypeTabpage:
          return msgpack_rpc_to_tabpage(obj, &arg->data.tabpage);
      }
    default:
      return false;
  }
}

bool msgpack_rpc_to_array(msgpack_object *obj, Array *arg)
  FUNC_ATTR_NONNULL_ALL
{
  if (obj->type != MSGPACK_OBJECT_ARRAY) {
    return false;
  }

  arg->size = obj->via.array.size;
  arg->items = xcalloc(obj->via.array.size, sizeof(Object));

  for (uint32_t i = 0; i < obj->via.array.size; i++) {
    if (!msgpack_rpc_to_object(obj->via.array.ptr + i, &arg->items[i])) {
      return false;
    }
  }

  return true;
}

bool msgpack_rpc_to_dictionary(msgpack_object *obj, Dictionary *arg)
  FUNC_ATTR_NONNULL_ALL
{
  if (obj->type != MSGPACK_OBJECT_MAP) {
    return false;
  }

  arg->size = obj->via.array.size;
  arg->items = xcalloc(obj->via.map.size, sizeof(KeyValuePair));


  for (uint32_t i = 0; i < obj->via.map.size; i++) {
    if (!msgpack_rpc_to_string(&obj->via.map.ptr[i].key,
          &arg->items[i].key)) {
      return false;
    }

    if (!msgpack_rpc_to_object(&obj->via.map.ptr[i].val,
          &arg->items[i].value)) {
      return false;
    }
  }

  return true;
}

void msgpack_rpc_from_boolean(Boolean result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  if (result) {
    msgpack_pack_true(res);
  } else {
    msgpack_pack_false(res);
  }
}

void msgpack_rpc_from_integer(Integer result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_int64(res, result);
}

void msgpack_rpc_from_float(Float result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_double(res, result);
}

void msgpack_rpc_from_string(String result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_bin(res, result.size);
  msgpack_pack_bin_body(res, result.data, result.size);
}

void msgpack_rpc_from_object(Object result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  switch (result.type) {
    case kObjectTypeNil:
      msgpack_pack_nil(res);
      break;

    case kObjectTypeBoolean:
      msgpack_rpc_from_boolean(result.data.boolean, res);
      break;

    case kObjectTypeInteger:
      msgpack_rpc_from_integer(result.data.integer, res);
      break;

    case kObjectTypeFloat:
      msgpack_rpc_from_float(result.data.floating, res);
      break;

    case kObjectTypeString:
      msgpack_rpc_from_string(result.data.string, res);
      break;

    case kObjectTypeArray:
      msgpack_rpc_from_array(result.data.array, res);
      break;

    case kObjectTypeBuffer:
      msgpack_rpc_from_buffer(result.data.buffer, res);
      break;

    case kObjectTypeWindow:
      msgpack_rpc_from_window(result.data.window, res);
      break;

    case kObjectTypeTabpage:
      msgpack_rpc_from_tabpage(result.data.tabpage, res);
      break;

    case kObjectTypeDictionary:
      msgpack_rpc_from_dictionary(result.data.dictionary, res);
      break;
  }
}

void msgpack_rpc_from_array(Array result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_array(res, result.size);

  for (size_t i = 0; i < result.size; i++) {
    msgpack_rpc_from_object(result.items[i], res);
  }
}

void msgpack_rpc_from_dictionary(Dictionary result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_map(res, result.size);

  for (size_t i = 0; i < result.size; i++) {
    msgpack_rpc_from_string(result.items[i].key, res);
    msgpack_rpc_from_object(result.items[i].value, res);
  }
}
