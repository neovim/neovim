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
#include "nvim/ascii_defs.h"
#include "nvim/assert_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/charset.h"
#include "nvim/eval/vars.h"
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

/// Parse 1 to 4 hex digits as an OSC 11 color component.
///
/// Returns the component scaled to [0.0, 1.0] and advances `p` past the hex
/// digits.
static bool parse_color_component(const char **p, const char *end, double *color)
{
  int val = 0;
  int len = 0;
  while (*p < end && ascii_isxdigit((uint8_t)(**p))) {
    if (++len > 4) {
      return false;
    }
    val = (val << 4) + hex2nr((uint8_t)(**p));
    (*p)++;
  }

  if (len == 0) {
    return false;
  }

  *color = (double)val / (double)((1 << (4 * len)) - 1);
  return true;
}

/// Consume `c` and advance `p`.
static bool parse_char(const char **p, const char *end, char c)
{
  if (*p == end || **p != c) {
    return false;
  }
  (*p)++;
  return true;
}

/// Classify an OSC 11 response as a terminal background.
static UIBackground detect_background(String resp)
{
  if (resp.size == 0 || resp.data == NULL) {
    return kUIBackgroundUnknown;
  }

  const char rgb_prefix[] = "\033]11;rgb:";
  const char rgba_prefix[] = "\033]11;rgba:";
  const char *p = resp.data;
  const char *end = resp.data + resp.size;
  bool rgba = false;
  if (resp.size >= sizeof(rgb_prefix) - 1
      && memcmp(p, rgb_prefix, sizeof(rgb_prefix) - 1) == 0) {
    p += sizeof(rgb_prefix) - 1;
  } else if (resp.size >= sizeof(rgba_prefix) - 1
             && memcmp(p, rgba_prefix, sizeof(rgba_prefix) - 1) == 0) {
    p += sizeof(rgba_prefix) - 1;
    rgba = true;
  } else {
    return kUIBackgroundUnknown;
  }

  double r = 0;
  double g = 0;
  double b = 0;
  double a = 0;
  if (!parse_color_component(&p, end, &r)
      || !parse_char(&p, end, '/')
      || !parse_color_component(&p, end, &g)
      || !parse_char(&p, end, '/')
      || !parse_color_component(&p, end, &b)
      || (rgba && (!parse_char(&p, end, '/') || !parse_color_component(&p, end, &a)))
      || p != end) {
    return kUIBackgroundUnknown;
  }

  double luminance = (0.299 * r) + (0.587 * g) + (0.114 * b);
  return luminance < 0.5 ? kUIBackgroundDark : kUIBackgroundLight;
}

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
    VALIDATE_T("termresponse", kObjectTypeString, value.type, {
      return;
    });

    const String termresponse = value.data.string;
    UIBackground background = detect_background(termresponse);
    if (background != kUIBackgroundUnknown) {
      Channel *chan = find_channel(channel_id);
      if (chan && chan->rpc.ui) {
        chan->rpc.ui->detected_background = background;
      }
    }
    set_vim_var_string(VV_TERMRESPONSE, termresponse.data, (ptrdiff_t)termresponse.size);
    do_termresponse_autocmd(termresponse, channel_id, background);
  }
}
