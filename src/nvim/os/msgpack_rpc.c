#include <stdint.h>
#include <stdbool.h>
#include <inttypes.h>

#include <msgpack.h>

#include "nvim/vim.h"
#include "nvim/log.h"
#include "nvim/memory.h"
#include "nvim/os/wstream.h"
#include "nvim/os/msgpack_rpc.h"
#include "nvim/os/msgpack_rpc_helpers.h"
#include "nvim/api/private/helpers.h"
#include "nvim/func_attr.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/msgpack_rpc.c.generated.h"
#endif

extern const uint8_t msgpack_metadata[];
extern const unsigned int msgpack_metadata_size;

/// Validates the basic structure of the msgpack-rpc call and fills `res`
/// with the basic response structure.
///
/// @param channel_id The channel id
/// @param req The parsed request object
/// @param res A packer that contains the response
WBuffer *msgpack_rpc_call(uint64_t channel_id,
                          msgpack_object *req,
                          msgpack_sbuffer *sbuffer)
  FUNC_ATTR_NONNULL_ARG(2)
  FUNC_ATTR_NONNULL_ARG(3)
{
  uint64_t response_id;
  char *err = msgpack_rpc_validate(&response_id, req);

  if (err) {
    return serialize_response(response_id, err, NIL, sbuffer);
  }

  uint64_t method_id = req->via.array.ptr[2].via.u64;

  if (method_id == 0) {
    return serialize_metadata(response_id, channel_id, sbuffer);
  }

  // dispatch the call
  Error error = { .set = false };
  Object rv = msgpack_rpc_dispatch(channel_id, method_id, req, &error);
  // send the response
  msgpack_packer response;
  msgpack_packer_init(&response, sbuffer, msgpack_sbuffer_write);

  if (error.set) {
    ELOG("Error dispatching msgpack-rpc call: %s(request: id %" PRIu64 ")",
         error.msg,
         response_id);
    return serialize_response(response_id, error.msg, NIL, sbuffer);
  }

  DLOG("Successfully completed mspgack-rpc call(request id: %" PRIu64 ")",
       response_id);
  return serialize_response(response_id, NULL, rv, sbuffer);
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
WBuffer *serialize_request(uint64_t request_id,
                           String method,
                           Object arg,
                           msgpack_sbuffer *sbuffer,
                           size_t refcount)
  FUNC_ATTR_NONNULL_ARG(4)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_pack_array(&pac, request_id ? 4 : 3);
  msgpack_pack_int(&pac, request_id ? 0 : 2);

  if (request_id) {
    msgpack_pack_uint64(&pac, request_id);
  }

  msgpack_pack_raw(&pac, method.size);
  msgpack_pack_raw_body(&pac, method.data, method.size);
  msgpack_rpc_from_object(arg, &pac);
  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   refcount,
                                   free);
  msgpack_rpc_free_object(arg);
  msgpack_sbuffer_clear(sbuffer);
  return rv;
}

/// Serializes a msgpack-rpc response
WBuffer *serialize_response(uint64_t response_id,
                            char *err_msg,
                            Object arg,
                            msgpack_sbuffer *sbuffer)
  FUNC_ATTR_NONNULL_ARG(4)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_pack_array(&pac, 4);
  msgpack_pack_int(&pac, 1);
  msgpack_pack_uint64(&pac, response_id);

  if (err_msg) {
    String err = {.size = strlen(err_msg), .data = err_msg};
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
                                   1,  // responses only go though 1 channel
                                   free);
  msgpack_rpc_free_object(arg);
  msgpack_sbuffer_clear(sbuffer);
  return rv;
}

WBuffer *serialize_metadata(uint64_t id,
                            uint64_t channel_id,
                            msgpack_sbuffer *sbuffer)
  FUNC_ATTR_NONNULL_ALL
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_pack_array(&pac, 4);
  msgpack_pack_int(&pac, 1);
  msgpack_pack_uint64(&pac, id);
  // Nil error
  msgpack_pack_nil(&pac);
  // The result is the [channel_id, metadata] array
  msgpack_pack_array(&pac, 2);
  msgpack_pack_uint64(&pac, channel_id);
  msgpack_pack_raw(&pac, msgpack_metadata_size);
  msgpack_pack_raw_body(&pac, msgpack_metadata, msgpack_metadata_size);
  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   1,
                                   free);
  msgpack_sbuffer_clear(sbuffer);
  return rv;
}

static char *msgpack_rpc_validate(uint64_t *response_id, msgpack_object *req)
{
  // response id not known yet

  *response_id = 0;
  // Validate the basic structure of the msgpack-rpc payload
  if (req->type != MSGPACK_OBJECT_ARRAY) {
    return "Request is not an array";
  }

  if (req->via.array.size != 4) {
    return "Request array size should be 4";
  }

  if (req->via.array.ptr[1].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    return "Id must be a positive integer";
  }

  // Set the response id, which is the same as the request
  *response_id = req->via.array.ptr[1].via.u64;

  if (req->via.array.ptr[0].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    return "Message type must be an integer";
  }

  if (req->via.array.ptr[0].via.u64 != 0) {
    return "Message type must be 0";
  }

  if (req->via.array.ptr[2].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    return "Method id must be a positive integer";
  }

  if (req->via.array.ptr[3].type != MSGPACK_OBJECT_ARRAY) {
    return "Paremeters must be an array";
  }

  return NULL;
}
