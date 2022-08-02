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
#include "nvim/api/command.h"
#include "nvim/api/extmark.h"
#include "nvim/api/options.h"
#include "nvim/api/tabpage.h"
#include "nvim/api/ui.h"
#include "nvim/api/vim.h"
#include "nvim/api/vimscript.h"
#include "nvim/api/win_config.h"
#include "nvim/api/window.h"
#include "nvim/ui_client.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/private/dispatch_wrappers.generated.h"
#endif

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
