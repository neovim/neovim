#ifndef NVIM_OS_MSGPACK_RPC_H
#define NVIM_OS_MSGPACK_RPC_H

#include <stdint.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"
#include "nvim/os/wstream.h"

typedef enum {
  kUnpackResultOk,        /// Successfully parsed a document
  kUnpackResultFail,      /// Got unexpected input
  kUnpackResultNeedMore   /// Need more data
} UnpackResult;

/// Dispatches to the actual API function after basic payload validation by
/// `msgpack_rpc_call`. It is responsible for validating/converting arguments
/// to C types, and converting the return value back to msgpack types.
/// The implementation is generated at compile time with metadata extracted
/// from the api/*.h headers,
///
/// @param id The channel id
/// @param req The parsed request object
/// @param res A packer that contains the response
void msgpack_rpc_dispatch(uint64_t id,
                          msgpack_object *req,
                          msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_NONNULL_ARG(3);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/msgpack_rpc.h.generated.h"
#endif

#endif  // NVIM_OS_MSGPACK_RPC_H

