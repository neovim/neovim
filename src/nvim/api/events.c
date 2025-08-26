#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/events.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/api/ui.h"
#include "nvim/assert_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/eval.h"
#include "nvim/globals.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/msgpack_rpc/packer.h"
#include "nvim/msgpack_rpc/packer_defs.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"

/// Emitted on the client channel if an async API request responds with an error.
///
/// @param channel_id
/// @param type Error type id as defined by `api_info().error_types`.
/// @param msg Error message.
void nvim_error_event(uint64_t channel_id, Integer type, String msg)
  FUNC_API_REMOTE_ONLY
{
  // TODO(bfredl): consider printing message to user, as will be relevant
  // if we fork nvim processes as async workers
  ELOG("async error on channel %" PRId64 ": %s", channel_id, msg.size ? msg.data : "");
}

/// Emitted by the TUI client to signal when a host-terminal event occurred.
///
/// Supports these events:
///
///   - "termresponse": The host-terminal sent a DA1, OSC, DCS, or APC response sequence to Nvim.
///                     The payload is the received response. Sets |v:termresponse| and fires
///                     |TermResponse|.
///
/// @param channel_id
/// @param event Event name
/// @param value Event payload
/// @param[out] err Error details, if any.
void nvim_ui_term_event(uint64_t channel_id, String event, Object value, Error *err)
  FUNC_API_SINCE(12) FUNC_API_REMOTE_ONLY
{
  if (strequal("termresponse", event.data)) {
    if (value.type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation, "termresponse must be a string");
      return;
    }

    const String termresponse = value.data.string;
    set_vim_var_string(VV_TERMRESPONSE, termresponse.data, (ptrdiff_t)termresponse.size);

    MAXSIZE_TEMP_DICT(data, 1);
    PUT_C(data, "sequence", value);
    apply_autocmds_group(EVENT_TERMRESPONSE, NULL, NULL, true, AUGROUP_ALL, NULL, NULL,
                         &DICT_OBJ(data));
  }
}
