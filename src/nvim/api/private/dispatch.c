// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <msgpack.h>
#include <stdbool.h>

#include "nvim/api/deprecated.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/log.h"
#include "nvim/map.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/vim.h"

// ===========================================================================
// NEW API FILES MUST GO HERE.
//
//  When creating a new API file, you must include it here,
//  so that the dispatcher can find the C functions that you are creating!
// ===========================================================================
#include "nvim/api/autocmd.h"
#include "nvim/api/buffer.h"
#include "nvim/api/extmark.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/ui.h"
#include "nvim/api/vim.h"
#include "nvim/api/vimscript.h"
#include "nvim/api/win_config.h"
#include "nvim/api/window.h"
#include "nvim/ui_client.h"

static Map(String, MsgpackRpcRequestHandler) methods = MAP_INIT;

static void msgpack_rpc_add_method_handler(String method, MsgpackRpcRequestHandler handler)
{
  map_put(String, MsgpackRpcRequestHandler)(&methods, method, handler);
}

void msgpack_rpc_add_redraw(void)
{
  msgpack_rpc_add_method_handler(STATIC_CSTR_AS_STRING("redraw"),
                                 (MsgpackRpcRequestHandler) { .fn = ui_client_handle_redraw,
                                                              .fast = true });
}

/// @param name API method name
/// @param name_len name size (includes terminating NUL)
MsgpackRpcRequestHandler msgpack_rpc_get_handler_for(const char *name, size_t name_len,
                                                     Error *error)
{
  String m = { .data = (char *)name, .size = name_len };
  MsgpackRpcRequestHandler rv =
    map_get(String, MsgpackRpcRequestHandler)(&methods, m);

  if (!rv.fn) {
    api_set_error(error, kErrorTypeException, "Invalid method: %.*s",
                  m.size > 0 ? (int)m.size : (int)sizeof("<empty>"),
                  m.size > 0 ? m.data : "<empty>");
  }
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch_wrappers.generated.h"
#endif
