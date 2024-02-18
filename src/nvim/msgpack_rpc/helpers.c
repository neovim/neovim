#include <msgpack/object.h>
#include <msgpack/sbuffer.h>
#include <msgpack/unpack.h>
#include <msgpack/zone.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "klib/kvec.h"
#include "msgpack/pack.h"
#include "nvim/api/private/helpers.h"
#include "nvim/assert_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/helpers.c.generated.h"
#endif

static msgpack_zone zone;
static msgpack_sbuffer sbuffer;

void msgpack_rpc_helpers_init(void)
{
  msgpack_zone_init(&zone, 0xfff);
  msgpack_sbuffer_init(&sbuffer);
}

#ifdef EXITFREE
void msgpack_rpc_helpers_free_all_mem(void)
{
  msgpack_zone_destroy(&zone);
  msgpack_sbuffer_destroy(&sbuffer);
}
#endif

// uncrustify:off

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

void msgpack_rpc_from_string(const String result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_str(res, result.size);
  if (result.size > 0) {
    msgpack_pack_str_body(res, result.data, result.size);
  }
}

static void msgpack_rpc_from_handle(ObjectType type, Integer o, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(3)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, &sbuffer, msgpack_sbuffer_write);
  msgpack_pack_int64(&pac, (handle_T)o);
  msgpack_pack_ext(res, sbuffer.size, (int8_t)(type - EXT_OBJECT_TYPE_SHIFT));
  msgpack_pack_ext_body(res, sbuffer.data, sbuffer.size);
  msgpack_sbuffer_clear(&sbuffer);
}

typedef struct {
  Object *aobj;
  bool container;
  size_t idx;
} APIToMPObjectStackItem;

/// Convert type used by Nvim API to msgpack type.
///
/// consumes (frees) any luaref inside `result`, even though they are not used
/// (just represented as NIL)
///
/// @param[in]  result  Object to convert.
/// @param[out]  res  Structure that defines where conversion results are saved.
///
/// @return true in case of success, false otherwise.
void msgpack_rpc_from_object(Object *result, msgpack_packer *const res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  kvec_withinit_t(APIToMPObjectStackItem, 2) stack = KV_INITIAL_VALUE;
  kvi_init(stack);
  kvi_push(stack, ((APIToMPObjectStackItem) { result, false, 0 }));
  while (kv_size(stack)) {
    APIToMPObjectStackItem cur = kv_last(stack);
    STATIC_ASSERT(kObjectTypeWindow == kObjectTypeBuffer + 1
                  && kObjectTypeTabpage == kObjectTypeWindow + 1,
                  "Buffer, window and tabpage enum items are in order");
    switch (cur.aobj->type) {
    case kObjectTypeLuaRef:
      // TODO(bfredl): could also be an error. Though kObjectTypeLuaRef
      // should only appear when the caller has opted in to handle references,
      // see nlua_pop_Object.
      api_free_luaref(cur.aobj->data.luaref);
      cur.aobj->data.luaref = LUA_NOREF;
      FALLTHROUGH;
    case kObjectTypeNil:
      msgpack_pack_nil(res);
      break;
    case kObjectTypeBoolean:
      msgpack_rpc_from_boolean(cur.aobj->data.boolean, res);
      break;
    case kObjectTypeInteger:
      msgpack_rpc_from_integer(cur.aobj->data.integer, res);
      break;
    case kObjectTypeFloat:
      msgpack_rpc_from_float(cur.aobj->data.floating, res);
      break;
    case kObjectTypeString:
      msgpack_rpc_from_string(cur.aobj->data.string, res);
      break;
    case kObjectTypeBuffer:
    case kObjectTypeWindow:
    case kObjectTypeTabpage:
      msgpack_rpc_from_handle(cur.aobj->type, cur.aobj->data.integer, res);
      break;
    case kObjectTypeArray: {
      const size_t size = cur.aobj->data.array.size;
      if (cur.container) {
        if (cur.idx >= size) {
          (void)kv_pop(stack);
        } else {
          const size_t idx = cur.idx;
          cur.idx++;
          kv_last(stack) = cur;
          kvi_push(stack, ((APIToMPObjectStackItem) {
              .aobj = &cur.aobj->data.array.items[idx],
              .container = false,
          }));
        }
      } else {
        msgpack_pack_array(res, size);
        cur.container = true;
        kv_last(stack) = cur;
      }
      break;
    }
    case kObjectTypeDictionary: {
      const size_t size = cur.aobj->data.dictionary.size;
      if (cur.container) {
        if (cur.idx >= size) {
          (void)kv_pop(stack);
        } else {
          const size_t idx = cur.idx;
          cur.idx++;
          kv_last(stack) = cur;
          msgpack_rpc_from_string(cur.aobj->data.dictionary.items[idx].key, res);
          kvi_push(stack, ((APIToMPObjectStackItem) {
              .aobj = &cur.aobj->data.dictionary.items[idx].value,
              .container = false,
          }));
        }
      } else {
        msgpack_pack_map(res, size);
        cur.container = true;
        kv_last(stack) = cur;
      }
      break;
    }
    }
    if (!cur.container) {
      (void)kv_pop(stack);
    }
  }
  kvi_destroy(stack);
}

// uncrustify:on

void msgpack_rpc_from_array(Array result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_array(res, result.size);

  for (size_t i = 0; i < result.size; i++) {
    msgpack_rpc_from_object(&result.items[i], res);
  }
}

void msgpack_rpc_from_dictionary(Dictionary result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2)
{
  msgpack_pack_map(res, result.size);

  for (size_t i = 0; i < result.size; i++) {
    msgpack_rpc_from_string(result.items[i].key, res);
    msgpack_rpc_from_object(&result.items[i].value, res);
  }
}

/// Serializes a msgpack-rpc request or notification(id == 0)
void msgpack_rpc_serialize_request(uint32_t request_id, const String method, Array args,
                                   msgpack_packer *pac)
  FUNC_ATTR_NONNULL_ARG(4)
{
  msgpack_pack_array(pac, request_id ? 4 : 3);
  msgpack_pack_int(pac, request_id ? 0 : 2);

  if (request_id) {
    msgpack_pack_uint32(pac, request_id);
  }

  msgpack_rpc_from_string(method, pac);
  msgpack_rpc_from_array(args, pac);
}

/// Serializes a msgpack-rpc response
void msgpack_rpc_serialize_response(uint32_t response_id, Error *err, Object *arg,
                                    msgpack_packer *pac)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_pack_array(pac, 4);
  msgpack_pack_int(pac, 1);
  msgpack_pack_uint32(pac, response_id);

  if (ERROR_SET(err)) {
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
  return obj->type == MSGPACK_OBJECT_STR || obj->type == MSGPACK_OBJECT_BIN
         ? obj : NULL;
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

MessageType msgpack_rpc_validate(uint32_t *response_id, msgpack_object *req, Error *err)
{
  *response_id = 0;
  // Validate the basic structure of the msgpack-rpc payload
  if (req->type != MSGPACK_OBJECT_ARRAY) {
    api_set_error(err, kErrorTypeValidation, "Message is not an array");
    return kMessageTypeUnknown;
  }

  if (req->via.array.size == 0) {
    api_set_error(err, kErrorTypeValidation, "Message is empty");
    return kMessageTypeUnknown;
  }

  if (req->via.array.ptr[0].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    api_set_error(err, kErrorTypeValidation, "Message type must be an integer");
    return kMessageTypeUnknown;
  }

  MessageType type = (MessageType)req->via.array.ptr[0].via.u64;
  if (type != kMessageTypeRequest && type != kMessageTypeNotification) {
    api_set_error(err, kErrorTypeValidation, "Unknown message type");
    return kMessageTypeUnknown;
  }

  if ((type == kMessageTypeRequest && req->via.array.size != 4)
      || (type == kMessageTypeNotification && req->via.array.size != 3)) {
    api_set_error(err, kErrorTypeValidation,
                  "Request array size must be 4 (request) or 3 (notification)");
    return type;
  }

  if (type == kMessageTypeRequest) {
    msgpack_object *id_obj = msgpack_rpc_msg_id(req);
    if (!id_obj) {
      api_set_error(err, kErrorTypeValidation, "ID must be a positive integer");
      return type;
    }
    *response_id = (uint32_t)id_obj->via.u64;
  }

  if (!msgpack_rpc_method(req)) {
    api_set_error(err, kErrorTypeValidation, "Method must be a string");
    return type;
  }

  if (!msgpack_rpc_args(req)) {
    api_set_error(err, kErrorTypeValidation, "Parameters must be an array");
    return type;
  }

  return type;
}
