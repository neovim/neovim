#include <stdint.h>
#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/os/msgpack_rpc_helpers.h"
#include "nvim/os/channel.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/api/private/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/msgpack_rpc_helpers.c.generated.h"
#endif

static msgpack_zone zone;
static msgpack_sbuffer sbuffer;

#define HANDLE_TYPE_CONVERSION_IMPL(t, lt)                                  \
  bool msgpack_rpc_to_##lt(msgpack_object *obj, t *arg, uint64_t channel)   \
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

bool msgpack_rpc_to_boolean(msgpack_object *obj,
                            Boolean *arg,
                            uint64_t channel)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  *arg = obj->via.boolean;
  return obj->type == MSGPACK_OBJECT_BOOLEAN;
}

bool msgpack_rpc_to_integer(msgpack_object *obj,
                            Integer *arg,
                            uint64_t channel)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (obj->type == MSGPACK_OBJECT_POSITIVE_INTEGER
      && obj->via.u64 <= INT64_MAX) {
    *arg = (int64_t)obj->via.u64;
    return true;
  }

  *arg = obj->via.i64;
  return obj->type == MSGPACK_OBJECT_NEGATIVE_INTEGER;
}

bool msgpack_rpc_to_float(msgpack_object *obj,
                          Float *arg,
                          uint64_t channel)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  *arg = obj->via.dec;
  return obj->type == MSGPACK_OBJECT_DOUBLE;
}

bool msgpack_rpc_to_string(msgpack_object *obj,
                           String *arg,
                           uint64_t channel)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (obj->type == MSGPACK_OBJECT_BIN || obj->type == MSGPACK_OBJECT_STR) {
    arg->data = xmemdupz(obj->via.bin.ptr, obj->via.bin.size);
    arg->size = obj->via.bin.size;
  } else {
    return false;
  }

  return true;
}

bool msgpack_rpc_to_object(msgpack_object *obj,
                           Object *arg,
                           uint64_t channel)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  switch (obj->type) {
    case MSGPACK_OBJECT_NIL:
      arg->type = kObjectTypeNil;
      return true;

    case MSGPACK_OBJECT_BOOLEAN:
      arg->type = kObjectTypeBoolean;
      return msgpack_rpc_to_boolean(obj, &arg->data.boolean, channel);

    case MSGPACK_OBJECT_POSITIVE_INTEGER:
    case MSGPACK_OBJECT_NEGATIVE_INTEGER:
      arg->type = kObjectTypeInteger;
      return msgpack_rpc_to_integer(obj, &arg->data.integer, channel);

    case MSGPACK_OBJECT_DOUBLE:
      arg->type = kObjectTypeFloat;
      return msgpack_rpc_to_float(obj, &arg->data.floating, channel);

    case MSGPACK_OBJECT_BIN:
    case MSGPACK_OBJECT_STR:
      arg->type = kObjectTypeString;
      return msgpack_rpc_to_string(obj, &arg->data.string, channel);

    case MSGPACK_OBJECT_ARRAY:
      arg->type = kObjectTypeArray;
      return msgpack_rpc_to_array(obj, &arg->data.array, channel);

    case MSGPACK_OBJECT_MAP:
      arg->type = kObjectTypeDictionary;
      return msgpack_rpc_to_dictionary(obj, &arg->data.dictionary, channel);

    case MSGPACK_OBJECT_EXT:
      switch (obj->via.ext.type) {
        case kObjectTypeBuffer:
          return msgpack_rpc_to_buffer(obj, &arg->data.buffer, channel);
        case kObjectTypeWindow:
          return msgpack_rpc_to_window(obj, &arg->data.window, channel);
        case kObjectTypeTabpage:
          return msgpack_rpc_to_tabpage(obj, &arg->data.tabpage, channel);
        case kObjectTypeFunction:
          return msgpack_rpc_to_function(obj, &arg->data.function, channel);
      }
    default:
      return false;
  }
}

bool msgpack_rpc_to_array(msgpack_object *obj,
                          Array *arg,
                          uint64_t channel)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (obj->type != MSGPACK_OBJECT_ARRAY) {
    return false;
  }

  arg->size = obj->via.array.size;
  arg->items = xcalloc(obj->via.array.size, sizeof(Object));

  for (uint32_t i = 0; i < obj->via.array.size; i++) {
    if (!msgpack_rpc_to_object(obj->via.array.ptr + i, &arg->items[i], channel)) {
      return false;
    }
  }

  return true;
}

bool msgpack_rpc_to_dictionary(msgpack_object *obj,
                               Dictionary *arg,
                               uint64_t channel)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  if (obj->type != MSGPACK_OBJECT_MAP) {
    return false;
  }

  arg->size = obj->via.array.size;
  arg->items = xcalloc(obj->via.map.size, sizeof(KeyValuePair));


  for (uint32_t i = 0; i < obj->via.map.size; i++) {
    if (!msgpack_rpc_to_string(&obj->via.map.ptr[i].key,
          &arg->items[i].key, channel)) {
      return false;
    }

    if (!msgpack_rpc_to_object(&obj->via.map.ptr[i].val,
          &arg->items[i].value, channel)) {
      return false;
    }
  }

  return true;
}

bool msgpack_rpc_to_function(msgpack_object *obj,
                             Function *arg,
                             uint64_t channel)
  FUNC_ATTR_NONNULL_ALL
{
  if (obj->type != MSGPACK_OBJECT_EXT
      || obj->via.ext.type != kObjectTypeFunction) {
    return false;
  }

  msgpack_object data;
  msgpack_unpack_return ret = msgpack_unpack(obj->via.ext.ptr,
                                             obj->via.ext.size,
                                             NULL,
                                             &zone,
                                             &data);

  if (ret != MSGPACK_UNPACK_SUCCESS || data.type != MSGPACK_OBJECT_BIN) {
    return false;
  }

  arg->data.name = xmemdupz(data.via.bin.ptr, data.via.bin.size);
  arg->data.channel = channel;
  arg->ptr = channel_callback;
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

    case kObjectTypeFunction:
      msgpack_rpc_from_function(result.data.function, res);
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

void msgpack_rpc_from_function(Function result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, &sbuffer, msgpack_sbuffer_write);
  msgpack_rpc_from_string(cstr_as_string(result.data.name), &pac);
  msgpack_pack_ext(res, sbuffer.size, kObjectTypeFunction);
  msgpack_pack_ext_body(res, sbuffer.data, sbuffer.size);
  msgpack_sbuffer_clear(&sbuffer);
}

static Object channel_callback(FunctionData *data, Array args, Error *err)
{
  assert(data->channel);

  if (data->async) {
    if (!channel_send_event(data->channel, data->name, args)) {
      api_set_error(err, Exception, _("Invalid channel id"));
    }

    return NIL;
  }

  Object rv = channel_send_call(data->channel, data->name, args, err);

  if (err->set) {
    return NIL;
  }

  return rv;
}
