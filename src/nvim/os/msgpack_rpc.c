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
  Error error = ERROR_INIT;
  msgpack_rpc_validate(&response_id, req, &error);

  if (error.set) {
    return serialize_response(response_id, &error, NIL, sbuffer);
  }

  // dispatch the call
  Object rv = msgpack_rpc_dispatch(channel_id, req, &error);
  // send the response
  msgpack_packer response;
  msgpack_packer_init(&response, sbuffer, msgpack_sbuffer_write);

  if (error.set) {
    ELOG("Error dispatching msgpack-rpc call: %s(request: id %" PRIu64 ")",
         error.msg,
         response_id);
    return serialize_response(response_id, &error, NIL, sbuffer);
  }

  DLOG("Successfully completed mspgack-rpc call(request id: %" PRIu64 ")",
       response_id);
  return serialize_response(response_id, &error, rv, sbuffer);
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
  msgpack_pack_bin(res, len);
  msgpack_pack_bin_body(res, msg, len);
  // Nil result
  msgpack_pack_nil(res);
}

/// Handler executed when an invalid method name is passed
Object msgpack_rpc_handle_missing_method(uint64_t channel_id,
                                         msgpack_object *req,
                                         Error *error)
{
  snprintf(error->msg, sizeof(error->msg), "Invalid method name");
  error->set = true;
  return NIL;
}

/// Serializes a msgpack-rpc request or notification(id == 0)
WBuffer *serialize_request(uint64_t request_id,
                           String method,
                           Array args,
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

  msgpack_pack_bin(&pac, method.size);
  msgpack_pack_bin_body(&pac, method.data, method.size);
  msgpack_rpc_from_array(args, &pac);
  WBuffer *rv = wstream_new_buffer(xmemdup(sbuffer->data, sbuffer->size),
                                   sbuffer->size,
                                   refcount,
                                   free);
  api_free_array(args);
  msgpack_sbuffer_clear(sbuffer);
  return rv;
}

/// Serializes a msgpack-rpc response
WBuffer *serialize_response(uint64_t response_id,
                            Error *err,
                            Object arg,
                            msgpack_sbuffer *sbuffer)
  FUNC_ATTR_NONNULL_ARG(2, 4)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, sbuffer, msgpack_sbuffer_write);
  msgpack_pack_array(&pac, 4);
  msgpack_pack_int(&pac, 1);
  msgpack_pack_uint64(&pac, response_id);

  if (err->set) {
    // error represented by a [type, message] array
    msgpack_pack_array(&pac, 2);
    msgpack_rpc_from_integer(err->type, &pac);
    msgpack_rpc_from_string(cstr_as_string(err->msg), &pac);
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
  api_free_object(arg);
  msgpack_sbuffer_clear(sbuffer);
  return rv;
}

static void msgpack_rpc_validate(uint64_t *response_id,
                                 msgpack_object *req,
                                 Error *err)
{
  // response id not known yet

  *response_id = 0;
  // Validate the basic structure of the msgpack-rpc payload
  if (req->type != MSGPACK_OBJECT_ARRAY) {
    api_set_error(err, Validation, _("Request is not an array"));
  }

  if (req->via.array.size != 4) {
    api_set_error(err, Validation, _("Request array size should be 4"));
  }

  if (req->via.array.ptr[1].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    api_set_error(err, Validation, _("Id must be a positive integer"));
  }

  // Set the response id, which is the same as the request
  *response_id = req->via.array.ptr[1].via.u64;

  if (req->via.array.ptr[0].type != MSGPACK_OBJECT_POSITIVE_INTEGER) {
    api_set_error(err, Validation, _("Message type must be an integer"));
  }

  if (req->via.array.ptr[0].via.u64 != 0) {
    api_set_error(err, Validation, _("Message type must be 0"));
  }

  if (req->via.array.ptr[2].type != MSGPACK_OBJECT_BIN
    && req->via.array.ptr[2].type != MSGPACK_OBJECT_STR) {
    api_set_error(err, Validation, _("Method must be a string"));
  }

  if (req->via.array.ptr[3].type != MSGPACK_OBJECT_ARRAY) {
    api_set_error(err, Validation, _("Paremeters must be an array"));
  }
}
