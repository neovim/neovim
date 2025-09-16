#include <stddef.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"

#include "api/private/dispatch_wrappers.generated.h"

/// @param name API method name
/// @param name_len name size (includes terminating NUL)
MsgpackRpcRequestHandler msgpack_rpc_get_handler_for(const char *name, size_t name_len,
                                                     Error *error)
{
  int hash = msgpack_rpc_get_handler_for_hash(name, name_len);

  if (hash < 0) {
    api_set_error(error, kErrorTypeException, "Invalid method: %.*s",
                  name_len > 0 ? (int)name_len : (int)sizeof("<empty>"),
                  name_len > 0 ? name : "<empty>");
    return (MsgpackRpcRequestHandler){ 0 };
  }
  return method_handlers[hash];
}
