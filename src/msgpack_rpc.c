#include <msgpack.h>

#include "msgpack_rpc.h"
#include "vim.h"
#include "memory.h"


bool msgpack_rpc_call(msgpack_object *req, msgpack_packer *res)
{
  // Validate the basic structure of the msgpack-rpc payload
  if (req->type != MSGPACK_OBJECT_ARRAY) {
    return msgpack_rpc_error(req, res, "Request is not an array");
  }

  if (req->via.array.size != 4) {
    char error_msg[256];
    snprintf(error_msg,
             sizeof(error_msg),
             "Request array size is %u, it should be 4",
             req->via.array.size);
    return msgpack_rpc_error(req, res, error_msg);
  }

  if (req->via.array.ptr[0].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    return msgpack_rpc_error(req, res, "Message type must be an integer");
  }

  if (req->via.array.ptr[0].via.u64 != 0) {
    return msgpack_rpc_error(req, res, "Message type must be 0");
  }

  if (req->via.array.ptr[1].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    return msgpack_rpc_error(req, res, "Id must be a positive integer");
  }

  if (req->via.array.ptr[2].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    return msgpack_rpc_error(req, res, "Method id must be a positive integer");
  }

  if (req->via.array.ptr[3].type != MSGPACK_OBJECT_ARRAY) {
    return msgpack_rpc_error(req, res, "Paremeters must be an array");
  }

  // dispatch the message
  return msgpack_rpc_dispatch(req, res);
}

void msgpack_rpc_response(msgpack_object *req, msgpack_packer *res)
{
  // Array of size 4
  msgpack_pack_array(res, 4);
  // Response type is 1
  msgpack_pack_int(res, 1);
  // Msgid is the same as the request
  msgpack_pack_int(res, req->via.array.ptr[1].via.u64);
}

void msgpack_rpc_success(msgpack_object *req, msgpack_packer *res)
{
  msgpack_rpc_response(req, res);
  // Nil error
  msgpack_pack_nil(res);
}

bool msgpack_rpc_error(msgpack_object *req, msgpack_packer *res, char *msg)
{
  size_t len = strlen(msg);

  msgpack_rpc_response(req, res);
  msgpack_pack_raw(res, len);
  msgpack_pack_raw_body(res, msg, len);
  // Nil result
  msgpack_pack_nil(res);

  return false;
}

char **msgpack_rpc_array_argument(msgpack_object *obj)
{
  uint32_t i;
  char **rv = xmalloc(obj->via.array.size + 1);

  for (i = 0; i < obj->via.array.size; i++) {
    rv[i] = msgpack_rpc_raw_argument(obj->via.array.ptr + i);
  }

  rv[i] = NULL;

  return rv;
}

char *msgpack_rpc_raw_argument(msgpack_object *obj)
{
  char *rv = xmalloc(obj->via.raw.size + 1);
  memcpy(rv, obj->via.raw.ptr, obj->via.raw.size);
  rv[obj->via.raw.size] = NUL;

  return rv;
}

uint32_t msgpack_rpc_integer_argument(msgpack_object *obj)
{
  return obj->via.u64;
}

bool msgpack_rpc_array_result(char **result,
                              msgpack_object *req,
                              msgpack_packer *res)
{
  char **ptr;
  uint32_t array_size;

  // Count number of items in the array
  for (ptr = result; *ptr != NULL; ptr++) continue;

  msgpack_rpc_success(req, res);
  // Subtract 1 to exclude the NULL slot
  array_size = ptr - result - 1;
  msgpack_pack_array(res, array_size);

  // push each string to the array
  for (ptr = result; *ptr != NULL; ptr++) {
    size_t raw_size = strlen(*ptr);
    msgpack_pack_raw(res, raw_size);
    msgpack_pack_raw_body(res, *ptr, raw_size);
  }

  return true;
}

bool msgpack_rpc_raw_result(char *result,
                            msgpack_object *req,
                            msgpack_packer *res)
{
  size_t raw_size = strlen(result);
  msgpack_rpc_success(req, res);
  msgpack_pack_raw(res, raw_size);
  msgpack_pack_raw_body(res, result, raw_size);
  return true;
}

bool msgpack_rpc_integer_result(uint32_t result,
                                msgpack_object *req,
                                msgpack_packer *res)
{
  msgpack_rpc_success(req, res);
  msgpack_pack_int(res, result);
  return true;
}

bool msgpack_rpc_void_result(msgpack_object *req, msgpack_packer *res)
{
  msgpack_rpc_success(req, res);
  msgpack_pack_nil(res);
  return true;
}
