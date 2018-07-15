// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>
#include <msgpack.h>

#include "nvim/map.h"
#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"

#include "nvim/api/buffer.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/ui.h"
#include "nvim/api/vim.h"
#include "nvim/api/window.h"

static Map(String, MsgpackRpcRequestHandler) *methods = NULL;

static void msgpack_rpc_add_method_handler(String method,
                                           MsgpackRpcRequestHandler handler)
{
  map_put(String, MsgpackRpcRequestHandler)(methods, method, handler);
}

/// @param name API method name
/// @param name_len name size (includes terminating NUL)
MsgpackRpcRequestHandler msgpack_rpc_get_handler_for(const char *name,
                                                     size_t name_len,
                                                     Error *error)
{
  String m = { .data = (char *)name, .size = name_len };
  MsgpackRpcRequestHandler rv =
    map_get(String, MsgpackRpcRequestHandler)(methods, m);

  if (!rv.fn) {
    api_set_error(error, kErrorTypeException, "Invalid method: %s",
                  m.size > 0 ? m.data : "<empty>");
  }
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "api/private/dispatch_wrappers.generated.h"
#endif
