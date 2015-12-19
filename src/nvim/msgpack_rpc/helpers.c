#include <stdint.h>
#include <stdbool.h>
#include <inttypes.h>

#include <msgpack.h>

#include "nvim/api/private/helpers.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/msgpack_rpc/defs.h"
#include "nvim/vim.h"
#include "nvim/log.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/helpers.c.generated.h"
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
  *arg = obj->via.f64;
  return obj->type == MSGPACK_OBJECT_FLOAT;
}

bool msgpack_rpc_to_string(msgpack_object *obj, String *arg)
  FUNC_ATTR_NONNULL_ALL
{
  if (obj->type == MSGPACK_OBJECT_BIN || obj->type == MSGPACK_OBJECT_STR) {
    arg->data = obj->via.bin.ptr != NULL
                    ? xmemdupz(obj->via.bin.ptr, obj->via.bin.size)
                    : NULL;
    arg->size = obj->via.bin.size;
    return true;
  }
  return false;
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

    case MSGPACK_OBJECT_FLOAT:
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
          arg->type = kObjectTypeBuffer;
          return msgpack_rpc_to_buffer(obj, &arg->data.buffer);
        case kObjectTypeWindow:
          arg->type = kObjectTypeWindow;
          return msgpack_rpc_to_window(obj, &arg->data.window);
        case kObjectTypeTabpage:
          arg->type = kObjectTypeTabpage;
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
  msgpack_pack_str(res, result.size);
  msgpack_pack_str_body(res, result.data, result.size);
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

/// Handler executed when an invalid method name is passed
Object msgpack_rpc_handle_missing_method(uint64_t channel_id,
                                         uint64_t request_id,
                                         Array args,
                                         Error *error)
{
  snprintf(error->msg, sizeof(error->msg), "Invalid method name");
  error->set = true;
  return NIL;
}

/// Handler executed when malformated arguments are passed
Object msgpack_rpc_handle_invalid_arguments(uint64_t channel_id,
                                            uint64_t request_id,
                                            Array args,
                                            Error *error)
{
  snprintf(error->msg, sizeof(error->msg), "Invalid method arguments");
  error->set = true;
  return NIL;
}

/// Serializes a msgpack-rpc request or notification(id == 0)
void msgpack_rpc_serialize_request(uint64_t request_id,
                                   String method,
                                   Array args,
                                   msgpack_packer *pac)
  FUNC_ATTR_NONNULL_ARG(4)
{
  msgpack_pack_array(pac, request_id ? 4 : 3);
  msgpack_pack_int(pac, request_id ? 0 : 2);

  if (request_id) {
    msgpack_pack_uint64(pac, request_id);
  }

  msgpack_rpc_from_string(method, pac);
  msgpack_rpc_from_array(args, pac);
}

/// Serializes a msgpack-rpc response
void msgpack_rpc_serialize_response(uint64_t response_id,
                                    Error *err,
                                    Object arg,
                                    msgpack_packer *pac)
  FUNC_ATTR_NONNULL_ARG(2, 4)
{
  msgpack_pack_array(pac, 4);
  msgpack_pack_int(pac, 1);
  msgpack_pack_uint64(pac, response_id);

  if (err->set) {
    // error represented by a [type, message] array
    msgpack_pack_array(pac, 2);
    msgpack_rpc_from_integer(err->type, pac);
    msgpack_rpc_from_string(cstr_as_string(err->msg), pac);
    // Nil result
    msgpack_pack_nil(pac);
  } else {
    // Nil error
    msgpack_pack_nil(pac);
    // Return value
    msgpack_rpc_from_object(arg, pac);
  }
}

static bool msgpack_rpc_is_notification(msgpack_object *req)
{
  return req->via.array.ptr[0].via.u64 == 2;
}

msgpack_object *msgpack_rpc_method(msgpack_object *req)
{
  msgpack_object *obj = req->via.array.ptr
    + (msgpack_rpc_is_notification(req) ? 1 : 2);
  return obj->type == MSGPACK_OBJECT_STR || obj->type == MSGPACK_OBJECT_BIN ?
    obj : NULL;
}

msgpack_object *msgpack_rpc_args(msgpack_object *req)
{
  msgpack_object *obj = req->via.array.ptr
    + (msgpack_rpc_is_notification(req) ? 2 : 3);
  return obj->type == MSGPACK_OBJECT_ARRAY ? obj : NULL;
}

static msgpack_object *msgpack_rpc_msg_id(msgpack_object *req)
{
  if (msgpack_rpc_is_notification(req)) {
    return NULL;
  }
  msgpack_object *obj = &req->via.array.ptr[1];
  return obj->type == MSGPACK_OBJECT_POSITIVE_INTEGER ? obj : NULL;
}

void msgpack_rpc_validate(uint64_t *response_id,
                          msgpack_object *req,
                          Error *err)
{
  // response id not known yet

  *response_id = NO_RESPONSE;
  // Validate the basic structure of the msgpack-rpc payload
  if (req->type != MSGPACK_OBJECT_ARRAY) {
    api_set_error(err, Validation, _("Message is not an array"));
    return;
  }

  if (req->via.array.size == 0) {
    api_set_error(err, Validation, _("Message is empty"));
    return;
  }

  if (req->via.array.ptr[0].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    api_set_error(err, Validation, _("Message type must be an integer"));
    return;
  }

  uint64_t type = req->via.array.ptr[0].via.u64;
  if (type != kMessageTypeRequest && type != kMessageTypeNotification) {
    api_set_error(err, Validation, _("Unknown message type"));
    return;
  }

  if ((type == kMessageTypeRequest && req->via.array.size != 4) ||
      (type == kMessageTypeNotification && req->via.array.size != 3)) {
    api_set_error(err, Validation, _("Request array size should be 4 (request) "
                                     "or 3 (notification)"));
    return;
  }

  if (type == kMessageTypeRequest) {
    msgpack_object *id_obj = msgpack_rpc_msg_id(req);
    if (!id_obj) {
      api_set_error(err, Validation, _("ID must be a positive integer"));
      return;
    }
    *response_id = id_obj->via.u64;
  }

  if (!msgpack_rpc_method(req)) {
    api_set_error(err, Validation, _("Method must be a string"));
    return;
  }

  if (!msgpack_rpc_args(req)) {
    api_set_error(err, Validation, _("Parameters must be an array"));
    return;
  }
}
