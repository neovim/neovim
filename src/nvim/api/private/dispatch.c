// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>

#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/lib/khash.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch_table.generated.h"
#endif

/// Get handler for the given method name
///
/// @param[in]  name  Method name.
/// @param[in]  name_len  Method name length.
///
/// @return Handler stored in `methods` hash or
///         msgpack_rpc_handle_missing_method() handler.
MsgpackRpcRequestHandler msgpack_rpc_get_handler_for(const char *const name,
                                                     const size_t name_len)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  const MsgpackRpcRequestHandlerMapItem *const ret = gperf_dispatch_find(
      name, name_len);
  if (ret == NULL) {
    return (MsgpackRpcRequestHandler) {
      .fn = msgpack_rpc_handle_missing_method,
    };
  } else {
    return ret->handler;
  }
}
