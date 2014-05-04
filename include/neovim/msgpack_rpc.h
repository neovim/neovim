#ifndef NEOVIM_MSGPACK_RPC_H
#define NEOVIM_MSGPACK_RPC_H

#include <stdint.h>
#include <stdbool.h>

#include <msgpack.h>

bool msgpack_rpc_call(msgpack_object *req, msgpack_packer *res);
bool msgpack_rpc_dispatch(msgpack_object *req, msgpack_packer *res);
void msgpack_rpc_response(msgpack_object *req, msgpack_packer *res);
void msgpack_rpc_success(msgpack_object *req, msgpack_packer *res);
bool msgpack_rpc_error(msgpack_object *req, msgpack_packer *res, char *msg);
char **msgpack_rpc_array_argument(msgpack_object *obj);
char *msgpack_rpc_raw_argument(msgpack_object *obj);
uint32_t msgpack_rpc_integer_argument(msgpack_object *obj);
bool msgpack_rpc_array_result(char **result,
                              msgpack_object *req,
                              msgpack_packer *res);
bool msgpack_rpc_raw_result(char *result,
                            msgpack_object *req,
                            msgpack_packer *res);
bool msgpack_rpc_integer_result(uint32_t result,
                                msgpack_object *req,
                                msgpack_packer *res);
bool msgpack_rpc_void_result(msgpack_object *req, msgpack_packer *res);


#endif // NEOVIM_MSGPACK_RPC_H

