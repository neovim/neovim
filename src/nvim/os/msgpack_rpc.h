#ifndef NVIM_OS_MSGPACK_RPC_H
#define NVIM_OS_MSGPACK_RPC_H

#include <stdint.h>

#include <msgpack.h>

#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"
#include "nvim/os/wstream.h"

typedef enum {
  kUnpackResultOk,        /// Successfully parsed a document
  kUnpackResultFail,      /// Got unexpected input
  kUnpackResultNeedMore   /// Need more data
} UnpackResult;

/// The rpc_method_handlers table, used in msgpack_rpc_dispatch(), stores
/// functions of this type.
typedef Object (*rpc_method_handler_fn)(uint64_t channel_id,
                                        msgpack_object *req,
                                        Error *error);

/// Dispatches to the actual API function after basic payload validation by
/// `msgpack_rpc_call`. It is responsible for validating/converting arguments
/// to C types, and converting the return value back to msgpack types.
/// The implementation is generated at compile time with metadata extracted
/// from the api/*.h headers,
///
/// @param channel_id The channel id
/// @param method_id The method id
/// @param req The parsed request object
/// @param error Pointer to error structure
/// @return Some object
Object msgpack_rpc_dispatch(uint64_t channel_id,
                            uint64_t method_id,
                            msgpack_object *req,
                            Error *error)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_NONNULL_ARG(3);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/msgpack_rpc.h.generated.h"
#endif

#endif  // NVIM_OS_MSGPACK_RPC_H
