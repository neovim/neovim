#include <stdint.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/os/wstream.h"
#include "nvim/os/msgpack_rpc.h"
#include "nvim/os/msgpack_rpc_helpers.h"
#include "nvim/func_attr.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/msgpack_rpc.c.generated.h"
#endif

/// Validates the basic structure of the msgpack-rpc call and fills `res`
/// with the basic response structure.
///
/// @param id The channel id
/// @param req The parsed request object
/// @param res A packer that contains the response
void msgpack_rpc_call(uint64_t id, msgpack_object *req, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_NONNULL_ARG(3)
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
    return;
  }

  if (req->via.array.ptr[1].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    msgpack_pack_int(res, 0);  // no message id yet
    msgpack_rpc_error("Id must be a positive integer", res);
    return;
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

/// Try to unpack a msgpack document from the data in the unpacker buffer. This
/// function is a replacement to msgpack.h `msgpack_unpack_next` that lets
/// the called know if the unpacking failed due to bad input or due to missing
/// data.
///
/// @param unpacker The unpacker containing the parse buffer
/// @param result The result which will contain the parsed object
/// @return kUnpackResultOk      : An object was parsed
///         kUnpackResultFail    : Got bad input
///         kUnpackResultNeedMore: Need more data
UnpackResult msgpack_rpc_unpack(msgpack_unpacker* unpacker,
                                msgpack_unpacked* result)
  FUNC_ATTR_NONNULL_ALL
{
  if (result->zone != NULL) {
    msgpack_zone_free(result->zone);
  }

  int res = msgpack_unpacker_execute(unpacker);

  if (res > 0) {
    result->zone = msgpack_unpacker_release_zone(unpacker);
    result->data = msgpack_unpacker_data(unpacker);
    msgpack_unpacker_reset(unpacker);
    return kUnpackResultOk;
  }

  if (res < 0) {
    // Since we couldn't parse it, destroy the data consumed so far
    msgpack_unpacker_reset(unpacker);
    return kUnpackResultFail;
  }

  return kUnpackResultNeedMore;
}

/// Finishes the msgpack-rpc call with an error message.
///
/// @param msg The error message
/// @param res A packer that contains the response
void msgpack_rpc_error(char *msg, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ALL
{
  size_t len = strlen(msg);

  // error message
  msgpack_pack_raw(res, len);
  msgpack_pack_raw_body(res, msg, len);
  // Nil result
  msgpack_pack_nil(res);
}

/// Serializes a msgpack-rpc request or notification(id == 0)
WBuffer *serialize_request(uint64_t id,
                           String method,
                           Object arg,
                           msgpack_sbuffer *sbuffer)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_pack_array(&pac, id ? 4 : 3);
  msgpack_pack_int(&pac, id ? 0 : 2);

  if (id) {
    msgpack_pack_uint64(&pac, id);
  }

  msgpack_pack_raw(&pac, method.size);
  msgpack_pack_raw_body(&pac, method.data, method.size);
  msgpack_rpc_from_object(arg, &pac);
  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   free);
  msgpack_rpc_free_object(arg);
  msgpack_sbuffer_clear(sbuffer);
  return rv;
}

/// Serializes a msgpack-rpc response
WBuffer *serialize_response(uint64_t id,
                            String err,
                            Object arg,
                            msgpack_sbuffer *sbuffer)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_pack_array(&pac, 4);
  msgpack_pack_int(&pac, 1);
  msgpack_pack_uint64(&pac, id);

  if (err.size) {
    // error message
    msgpack_pack_raw(&pac, err.size);
    msgpack_pack_raw_body(&pac, err.data, err.size);
    // Nil result
    msgpack_pack_nil(&pac);
  } else {
    // Nil error
    msgpack_pack_nil(&pac);
    // Return value
    msgpack_rpc_from_object(arg, &pac);
  }

  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   free);
  msgpack_rpc_free_object(arg);
  msgpack_sbuffer_clear(sbuffer);
  return rv;
}

