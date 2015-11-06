#ifndef NVIM_MSGPACK_RPC_DEFS_H
#define NVIM_MSGPACK_RPC_DEFS_H

#include <msgpack.h>


/// The rpc_method_handlers table, used in msgpack_rpc_dispatch(), stores
/// functions of this type.
typedef struct {
  Object (*fn)(uint64_t channel_id,
               uint64_t request_id,
               Array args,
               Error *error);
  bool async;  // function is always safe to run immediately instead of being
               // put in a request queue for handling when nvim waits for input.
} MsgpackRpcRequestHandler;

/// Initializes the msgpack-rpc method table
void msgpack_rpc_init_method_table(void);

// Add a handler to the method table
void msgpack_rpc_add_method_handler(String method,
                                    MsgpackRpcRequestHandler handler);

void msgpack_rpc_init_function_metadata(Dictionary *metadata);

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
                            msgpack_object *req,
                            Error *error)
  FUNC_ATTR_NONNULL_ARG(2) FUNC_ATTR_NONNULL_ARG(3);

MsgpackRpcRequestHandler msgpack_rpc_get_handler_for(const char *name,
                                                     size_t name_len)
  FUNC_ATTR_NONNULL_ARG(1);
#endif  // NVIM_MSGPACK_RPC_DEFS_H
