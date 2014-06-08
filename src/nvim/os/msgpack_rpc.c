#include <stdint.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/os/msgpack_rpc.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

#define REMOTE_FUNCS_IMPL(t, lt)                                            \
  bool msgpack_rpc_to_##lt(msgpack_object *obj, t *arg)                     \
  {                                                                         \
    *arg = obj->via.u64;                                                    \
    return obj->type == MSGPACK_OBJECT_POSITIVE_INTEGER;                    \
  }                                                                         \
                                                                            \
  void msgpack_rpc_from_##lt(t result, msgpack_packer *res)                 \
  {                                                                         \
    msgpack_pack_uint64(res, result);                                       \
  }

#define TYPED_ARRAY_IMPL(t, lt)                                             \
  bool msgpack_rpc_to_##lt##array(msgpack_object *obj, t##Array *arg)       \
  {                                                                         \
    if (obj->type != MSGPACK_OBJECT_ARRAY) {                                \
      return false;                                                         \
    }                                                                       \
                                                                            \
    arg->size = obj->via.array.size;                                        \
    arg->items = xcalloc(obj->via.array.size, sizeof(t));                   \
                                                                            \
    for (size_t i = 0; i < obj->via.array.size; i++) {                      \
      if (!msgpack_rpc_to_##lt(obj->via.array.ptr + i, &arg->items[i])) {   \
        return false;                                                       \
      }                                                                     \
    }                                                                       \
                                                                            \
    return true;                                                            \
  }                                                                         \
                                                                            \
  void msgpack_rpc_from_##lt##array(t##Array result, msgpack_packer *res)   \
  {                                                                         \
    msgpack_pack_array(res, result.size);                                   \
                                                                            \
    for (size_t i = 0; i < result.size; i++) {                              \
      msgpack_rpc_from_##lt(result.items[i], res);                          \
    }                                                                       \
  }                                                                         \
                                                                            \
  void msgpack_rpc_free_##lt##array(t##Array value) {                       \
    for (size_t i = 0; i < value.size; i++) {                               \
      msgpack_rpc_free_##lt(value.items[i]);                                \
    }                                                                       \
                                                                            \
    free(value.items);                                                      \
  }

void msgpack_rpc_call(uint64_t id, msgpack_object *req, msgpack_packer *res)
{
  // The initial response structure is the same no matter what happens,
  // we set it up here
  // Array of size 4
  msgpack_pack_array(res, 4);
  // Response type is 1
  msgpack_pack_int(res, 1);

  // Validate the basic structure of the msgpack-rpc payload
  if (req->type != MSGPACK_OBJECT_ARRAY) {
    msgpack_pack_int(res, 0);  // no message id yet
    msgpack_rpc_error("Request is not an array", res);
    return;
  }

  if (req->via.array.size != 4) {
    msgpack_pack_int(res, 0);  // no message id yet
    char error_msg[256];
    snprintf(error_msg,
             sizeof(error_msg),
             "Request array size is %u, it should be 4",
             req->via.array.size);
    msgpack_rpc_error(error_msg, res);
  }

  if (req->via.array.ptr[1].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    msgpack_pack_int(res, 0);  // no message id yet
    msgpack_rpc_error("Id must be a positive integer", res);
  }

  // Set the response id, which is the same as the request
  msgpack_pack_uint64(res, req->via.array.ptr[1].via.u64);

  if (req->via.array.ptr[0].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    msgpack_rpc_error("Message type must be an integer", res);
    return;
  }

  if (req->via.array.ptr[0].via.u64 != 0) {
    msgpack_rpc_error("Message type must be 0", res);
    return;
  }

  if (req->via.array.ptr[2].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    msgpack_rpc_error("Method id must be a positive integer", res);
    return;
  }

  if (req->via.array.ptr[3].type != MSGPACK_OBJECT_ARRAY) {
    msgpack_rpc_error("Paremeters must be an array", res);
    return;
  }

  // dispatch the message
  msgpack_rpc_dispatch(id, req, res);
}

void msgpack_rpc_notification(String type, Object data, msgpack_packer *pac)
{
  msgpack_pack_array(pac, 3);
  msgpack_pack_int(pac, 2);
  msgpack_pack_raw(pac, type.size);
  msgpack_pack_raw_body(pac, type.data, type.size);
  msgpack_rpc_from_object(data, pac);
}

void msgpack_rpc_error(char *msg, msgpack_packer *res)
{
  size_t len = strlen(msg);

  // error message
  msgpack_pack_raw(res, len);
  msgpack_pack_raw_body(res, msg, len);
  // Nil result
  msgpack_pack_nil(res);
}

bool msgpack_rpc_to_boolean(msgpack_object *obj, Boolean *arg)
{
  *arg = obj->via.boolean;
  return obj->type == MSGPACK_OBJECT_BOOLEAN;
}

bool msgpack_rpc_to_integer(msgpack_object *obj, Integer *arg)
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
{
  *arg = obj->via.dec;
  return obj->type == MSGPACK_OBJECT_DOUBLE;
}

bool msgpack_rpc_to_string(msgpack_object *obj, String *arg)
{
  if (obj->type != MSGPACK_OBJECT_RAW) {
    return false;
  }

  arg->data = xmemdupz(obj->via.raw.ptr, obj->via.raw.size);
  arg->size = obj->via.raw.size;
  return true;
}

bool msgpack_rpc_to_object(msgpack_object *obj, Object *arg)
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

    case MSGPACK_OBJECT_RAW:
      arg->type = kObjectTypeString;
      return msgpack_rpc_to_string(obj, &arg->data.string);

    case MSGPACK_OBJECT_ARRAY:
      arg->type = kObjectTypeArray;
      return msgpack_rpc_to_array(obj, &arg->data.array);

    case MSGPACK_OBJECT_MAP:
      arg->type = kObjectTypeDictionary;
      return msgpack_rpc_to_dictionary(obj, &arg->data.dictionary);

    default:
      return false;
  }
}

bool msgpack_rpc_to_position(msgpack_object *obj, Position *arg)
{
  return obj->type == MSGPACK_OBJECT_ARRAY
      && obj->via.array.size == 2
      && msgpack_rpc_to_integer(obj->via.array.ptr, &arg->row)
      && msgpack_rpc_to_integer(obj->via.array.ptr + 1, &arg->col);
}


bool msgpack_rpc_to_array(msgpack_object *obj, Array *arg)
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
{
  if (result) {
    msgpack_pack_true(res);
  } else {
    msgpack_pack_false(res);
  }
}

void msgpack_rpc_from_integer(Integer result, msgpack_packer *res)
{
  msgpack_pack_int64(res, result);
}

void msgpack_rpc_from_float(Float result, msgpack_packer *res)
{
  msgpack_pack_double(res, result);
}

void msgpack_rpc_from_string(String result, msgpack_packer *res)
{
  msgpack_pack_raw(res, result.size);
  msgpack_pack_raw_body(res, result.data, result.size);
}

void msgpack_rpc_from_object(Object result, msgpack_packer *res)
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

    case kObjectTypeDictionary:
      msgpack_rpc_from_dictionary(result.data.dictionary, res);
      break;

    default:
      abort();
  }
}

void msgpack_rpc_from_position(Position result, msgpack_packer *res)
{
  msgpack_pack_array(res, 2);;
  msgpack_pack_int64(res, result.row);
  msgpack_pack_int64(res, result.col);
}

void msgpack_rpc_from_array(Array result, msgpack_packer *res)
{
  msgpack_pack_array(res, result.size);

  for (size_t i = 0; i < result.size; i++) {
    msgpack_rpc_from_object(result.items[i], res);
  }
}

void msgpack_rpc_from_dictionary(Dictionary result, msgpack_packer *res)
{
  msgpack_pack_map(res, result.size);

  for (size_t i = 0; i < result.size; i++) {
    msgpack_rpc_from_string(result.items[i].key, res);
    msgpack_rpc_from_object(result.items[i].value, res);
  }
}

void msgpack_rpc_free_string(String value)
{
  if (!value.data) {
    return;
  }

  free(value.data);
}

void msgpack_rpc_free_object(Object value)
{
  switch (value.type) {
    case kObjectTypeNil:
    case kObjectTypeBoolean:
    case kObjectTypeInteger:
    case kObjectTypeFloat:
      break;

    case kObjectTypeString:
      msgpack_rpc_free_string(value.data.string);
      break;

    case kObjectTypeArray:
      msgpack_rpc_free_array(value.data.array);
      break;

    case kObjectTypeDictionary:
      msgpack_rpc_free_dictionary(value.data.dictionary);
      break;

    default:
      abort();
  }
}

void msgpack_rpc_free_array(Array value)
{
  for (uint32_t i = 0; i < value.size; i++) {
    msgpack_rpc_free_object(value.items[i]);
  }

  free(value.items);
}

void msgpack_rpc_free_dictionary(Dictionary value)
{
  for (uint32_t i = 0; i < value.size; i++) {
    msgpack_rpc_free_string(value.items[i].key);
    msgpack_rpc_free_object(value.items[i].value);
  }

  free(value.items);
}

REMOTE_FUNCS_IMPL(Buffer, buffer)
REMOTE_FUNCS_IMPL(Window, window)
REMOTE_FUNCS_IMPL(Tabpage, tabpage)

TYPED_ARRAY_IMPL(Buffer, buffer)
TYPED_ARRAY_IMPL(Window, window)
TYPED_ARRAY_IMPL(Tabpage, tabpage)
TYPED_ARRAY_IMPL(String, string)

