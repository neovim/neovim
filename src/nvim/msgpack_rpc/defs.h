#ifndef NVIM_MSGPACK_RPC_DEFS_H
#define NVIM_MSGPACK_RPC_DEFS_H


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

MsgpackRpcRequestHandler msgpack_rpc_get_handler_for(const char *name,
                                                     size_t name_len)
  FUNC_ATTR_NONNULL_ARG(1);
#endif  // NVIM_MSGPACK_RPC_DEFS_H
