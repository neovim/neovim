#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/option_vars.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/strings.h"
#include "nvim/tui/input.h"
#include "nvim/tui/input_defs.h"
#include "nvim/tui/termkey/driver-csi.h"
#include "nvim/tui/termkey/termkey.h"
#include "nvim/tui/termkey/termkey_defs.h"
#include "nvim/tui/tui.h"
#include "nvim/ui_client.h"

#ifdef MSWIN
# include "nvim/os/os_win_console.h"
#endif

#define READ_STREAM_SIZE 0xfff

/// Size of libtermkey's internal input buffer. The buffer may grow larger than
/// this when processing very long escape sequences, but will shrink back to
/// this size afterward
#define INPUT_BUFFER_SIZE 256

static const struct kitty_key_map_entry {
  int key;
  const char *name;
} kitty_key_map_entry[] = {
  { KITTY_KEY_ESCAPE,              "Esc" },
  { KITTY_KEY_ENTER,               "CR" },
  { KITTY_KEY_TAB,                 "Tab" },
  { KITTY_KEY_BACKSPACE,           "BS" },
  { KITTY_KEY_INSERT,              "Insert" },
  { KITTY_KEY_DELETE,              "Del" },
  { KITTY_KEY_LEFT,                "Left" },
  { KITTY_KEY_RIGHT,               "Right" },
  { KITTY_KEY_UP,                  "Up" },
  { KITTY_KEY_DOWN,                "Down" },
  { KITTY_KEY_PAGE_UP,             "PageUp" },
  { KITTY_KEY_PAGE_DOWN,           "PageDown" },
  { KITTY_KEY_HOME,                "Home" },
  { KITTY_KEY_END,                 "End" },
  { KITTY_KEY_F1,                  "F1" },
  { KITTY_KEY_F2,                  "F2" },
  { KITTY_KEY_F3,                  "F3" },
  { KITTY_KEY_F4,                  "F4" },
  { KITTY_KEY_F5,                  "F5" },
  { KITTY_KEY_F6,                  "F6" },
  { KITTY_KEY_F7,                  "F7" },
  { KITTY_KEY_F8,                  "F8" },
  { KITTY_KEY_F9,                  "F9" },
  { KITTY_KEY_F10,                 "F10" },
  { KITTY_KEY_F11,                 "F11" },
  { KITTY_KEY_F12,                 "F12" },
  { KITTY_KEY_F13,                 "F13" },
  { KITTY_KEY_F14,                 "F14" },
  { KITTY_KEY_F15,                 "F15" },
  { KITTY_KEY_F16,                 "F16" },
  { KITTY_KEY_F17,                 "F17" },
  { KITTY_KEY_F18,                 "F18" },
  { KITTY_KEY_F19,                 "F19" },
  { KITTY_KEY_F20,                 "F20" },
  { KITTY_KEY_F21,                 "F21" },
  { KITTY_KEY_F22,                 "F22" },
  { KITTY_KEY_F23,                 "F23" },
  { KITTY_KEY_F24,                 "F24" },
  { KITTY_KEY_F25,                 "F25" },
  { KITTY_KEY_F26,                 "F26" },
  { KITTY_KEY_F27,                 "F27" },
  { KITTY_KEY_F28,                 "F28" },
  { KITTY_KEY_F29,                 "F29" },
  { KITTY_KEY_F30,                 "F30" },
  { KITTY_KEY_F31,                 "F31" },
  { KITTY_KEY_F32,                 "F32" },
  { KITTY_KEY_F33,                 "F33" },
  { KITTY_KEY_F34,                 "F34" },
  { KITTY_KEY_F35,                 "F35" },
  { KITTY_KEY_KP_0,                "k0" },
  { KITTY_KEY_KP_1,                "k1" },
  { KITTY_KEY_KP_2,                "k2" },
  { KITTY_KEY_KP_3,                "k3" },
  { KITTY_KEY_KP_4,                "k4" },
  { KITTY_KEY_KP_5,                "k5" },
  { KITTY_KEY_KP_6,                "k6" },
  { KITTY_KEY_KP_7,                "k7" },
  { KITTY_KEY_KP_8,                "k8" },
  { KITTY_KEY_KP_9,                "k9" },
  { KITTY_KEY_KP_DECIMAL,          "kPoint" },
  { KITTY_KEY_KP_DIVIDE,           "kDivide" },
  { KITTY_KEY_KP_MULTIPLY,         "kMultiply" },
  { KITTY_KEY_KP_SUBTRACT,         "kMinus" },
  { KITTY_KEY_KP_ADD,              "kPlus" },
  { KITTY_KEY_KP_ENTER,            "kEnter" },
  { KITTY_KEY_KP_EQUAL,            "kEqual" },
  { KITTY_KEY_KP_LEFT,             "kLeft" },
  { KITTY_KEY_KP_RIGHT,            "kRight" },
  { KITTY_KEY_KP_UP,               "kUp" },
  { KITTY_KEY_KP_DOWN,             "kDown" },
  { KITTY_KEY_KP_PAGE_UP,          "kPageUp" },
  { KITTY_KEY_KP_PAGE_DOWN,        "kPageDown" },
  { KITTY_KEY_KP_HOME,             "kHome" },
  { KITTY_KEY_KP_END,              "kEnd" },
  { KITTY_KEY_KP_INSERT,           "kInsert" },
  { KITTY_KEY_KP_DELETE,           "kDel" },
  { KITTY_KEY_KP_BEGIN,            "kOrigin" },
};

static PMap(int) kitty_key_map = MAP_INIT;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/input.c.generated.h"
#endif

void tinput_init(TermInput *input, Loop *loop)
{
  input->loop = loop;
  input->paste = 0;
  input->in_fd = STDIN_FILENO;
  input->key_encoding = kKeyEncodingLegacy;
  input->ttimeout = (bool)p_ttimeout;
  input->ttimeoutlen = p_ttm;

  for (size_t i = 0; i < ARRAY_SIZE(kitty_key_map_entry); i++) {
    pmap_put(int)(&kitty_key_map, kitty_key_map_entry[i].key, (ptr_t)kitty_key_map_entry[i].name);
  }

  const char *term = os_getenv_noalloc("TERM");

  if (!term) {
    term = "";  // termkey_new_abstract assumes non-null (#2745)
  }

  input->tk = termkey_new_abstract(term, (TERMKEY_FLAG_UTF8 | TERMKEY_FLAG_NOSTART
                                          | TERMKEY_FLAG_KEEPC0));
  termkey_set_buffer_size(input->tk, INPUT_BUFFER_SIZE);
  termkey_hook_terminfo_getstr(input->tk, input->tk_ti_hook_fn, input);
  termkey_start(input->tk);

  int curflags = termkey_get_canonflags(input->tk);
  termkey_set_canonflags(input->tk, curflags | TERMKEY_CANON_DELBS);

  // setup input handle
  rstream_init_fd(loop, &input->read_stream, input->in_fd);

  // initialize a timer handle for handling ESC with libtermkey
  uv_timer_init(&loop->uv, &input->timer_handle);
  input->timer_handle.data = input;

  uv_timer_init(&loop->uv, &input->bg_query_timer);
  input->bg_query_timer.data = input;
}

void tinput_destroy(TermInput *input)
{
  map_destroy(int, &kitty_key_map);
  uv_close((uv_handle_t *)&input->timer_handle, NULL);
  uv_close((uv_handle_t *)&input->bg_query_timer, NULL);
  rstream_may_close(&input->read_stream);
  termkey_destroy(input->tk);
}

void tinput_start(TermInput *input)
{
  rstream_start(&input->read_stream, tinput_read_cb, input);
}

void tinput_stop(TermInput *input)
{
  rstream_stop(&input->read_stream);
  uv_timer_stop(&input->timer_handle);
  uv_timer_stop(&input->bg_query_timer);
}

static void tinput_done_event(void **argv)
  FUNC_ATTR_NORETURN
{
  os_exit(1);
}

/// Send all pending input in key buffer to Nvim server.
static void tinput_flush(TermInput *input)
{
  String keys = { .data = input->key_buffer, .size = input->key_buffer_len };
  if (input->paste) {  // produce exactly one paste event
    MAXSIZE_TEMP_ARRAY(args, 3);
    ADD_C(args, STRING_OBJ(keys));  // 'data'
    ADD_C(args, BOOLEAN_OBJ(true));  // 'crlf'
    ADD_C(args, INTEGER_OBJ(input->paste));  // 'phase'
    rpc_send_event(ui_client_channel_id, "nvim_paste", args);
    if (input->paste == 1) {
      // Paste phase: "continue"
      input->paste = 2;
    }
  } else {  // enqueue input
    if (input->key_buffer_len > 0) {
      MAXSIZE_TEMP_ARRAY(args, 1);
      ADD_C(args, STRING_OBJ(keys));
      // NOTE: This is non-blocking and won't check partially processed input,
      // but should be fine as all big sends are handled with nvim_paste, not nvim_input
      rpc_send_event(ui_client_channel_id, "nvim_input", args);
    }
  }
  input->key_buffer_len = 0;
}

static void tinput_enqueue(TermInput *input, const char *buf, size_t size)
{
  if (input->key_buffer_len > KEY_BUFFER_SIZE - size) {
    // don't ever let the buffer get too full or we risk putting incomplete keys into it
    tinput_flush(input);
  }
  size_t to_copy = MIN(size, KEY_BUFFER_SIZE - input->key_buffer_len);
  memcpy(input->key_buffer + input->key_buffer_len, buf, to_copy);
  input->key_buffer_len += to_copy;
}

/// Handle TERMKEY_KEYMOD_* modifiers, i.e. Shift, Alt and Ctrl.
///
/// @return  The number of bytes written into "buf", excluding the final NUL.
static size_t handle_termkey_modifiers(TermKeyKey *key, char *buf, size_t buflen)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t len = 0;
  if (key->modifiers & TERMKEY_KEYMOD_SHIFT) {  // Shift
    len += (size_t)snprintf(buf + len, buflen - len, "S-");
  }
  if (key->modifiers & TERMKEY_KEYMOD_ALT) {  // Alt
    len += (size_t)snprintf(buf + len, buflen - len, "A-");
  }
  if (key->modifiers & TERMKEY_KEYMOD_CTRL) {  // Ctrl
    len += (size_t)snprintf(buf + len, buflen - len, "C-");
  }
  assert(len < buflen);
  return len;
}

enum {
  KEYMOD_SUPER      = 1 << 3,
  KEYMOD_META       = 1 << 5,
  KEYMOD_RECOGNIZED = (TERMKEY_KEYMOD_SHIFT | TERMKEY_KEYMOD_ALT | TERMKEY_KEYMOD_CTRL
                       | KEYMOD_SUPER | KEYMOD_META),
};

/// Handle modifiers not handled by libtermkey.
/// Currently only Super ("D-") and Meta ("T-") are supported in Nvim.
///
/// @return  The number of bytes written into "buf", excluding the final NUL.
static size_t handle_more_modifiers(TermKeyKey *key, char *buf, size_t buflen)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t len = 0;
  if (key->modifiers & KEYMOD_SUPER) {
    len += (size_t)snprintf(buf + len, buflen - len, "D-");
  }
  if (key->modifiers & KEYMOD_META) {
    len += (size_t)snprintf(buf + len, buflen - len, "T-");
  }
  assert(len < buflen);
  return len;
}

static void handle_kitty_key_protocol(TermInput *input, TermKeyKey *key)
{
  const char *name = pmap_get(int)(&kitty_key_map, key->code.codepoint);
  if (name) {
    char buf[64];
    size_t len = 0;
    buf[len++] = '<';
    len += handle_termkey_modifiers(key, buf + len, sizeof(buf) - len);
    len += handle_more_modifiers(key, buf + len, sizeof(buf) - len);
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "%s>", name);
    assert(len < sizeof(buf));
    tinput_enqueue(input, buf, len);
  }
}

static void forward_simple_utf8(TermInput *input, TermKeyKey *key)
{
  size_t len = 0;
  char buf[64];
  char *ptr = key->utf8;

  if (key->code.codepoint >= 0xE000 && key->code.codepoint <= 0xF8FF
      && map_has(int, &kitty_key_map, (int)key->code.codepoint)) {
    handle_kitty_key_protocol(input, key);
    return;
  }
  while (*ptr) {
    if (*ptr == '<') {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "<lt>");
    } else {
      buf[len++] = *ptr;
    }
    assert(len < sizeof(buf));
    ptr++;
  }

  tinput_enqueue(input, buf, len);
}

static void forward_modified_utf8(TermInput *input, TermKeyKey *key)
{
  size_t len;
  char buf[64];

  if (key->type == TERMKEY_TYPE_KEYSYM
      && key->code.sym == TERMKEY_SYM_SUSPEND) {
    len = (size_t)snprintf(buf, sizeof(buf), "<C-Z>");
  } else if (key->type != TERMKEY_TYPE_UNICODE) {
    len = termkey_strfkey(input->tk, buf, sizeof(buf), key, TERMKEY_FORMAT_VIM);
  } else {
    assert(key->modifiers);
    if (key->code.codepoint >= 0xE000 && key->code.codepoint <= 0xF8FF
        && map_has(int, &kitty_key_map, (int)key->code.codepoint)) {
      handle_kitty_key_protocol(input, key);
      return;
    }
    // Termkey doesn't include the S- modifier for ASCII characters (e.g.,
    // ctrl-shift-l is <C-L> instead of <C-S-L>.  Vim, on the other hand,
    // treats <C-L> and <C-l> the same, requiring the S- modifier.
    len = termkey_strfkey(input->tk, buf, sizeof(buf), key, TERMKEY_FORMAT_VIM);
    if ((key->modifiers & TERMKEY_KEYMOD_CTRL)
        && !(key->modifiers & TERMKEY_KEYMOD_SHIFT)
        && ASCII_ISUPPER(key->code.codepoint)) {
      assert(len + 2 < sizeof(buf));
      // Make room for the S-
      memmove(buf + 3, buf + 1, len - 1);
      buf[1] = 'S';
      buf[2] = '-';
      len += 2;
    }
  }

  char more_buf[25];
  size_t more_len = handle_more_modifiers(key, more_buf, sizeof(more_buf));
  if (more_len > 0) {
    assert(len + more_len < sizeof(buf));
    memmove(buf + 1 + more_len, buf + 1, len - 1);
    memcpy(buf + 1, more_buf, more_len);
    len += more_len;
  }

  assert(len < sizeof(buf));
  tinput_enqueue(input, buf, len);
}

static void forward_mouse_event(TermInput *input, TermKeyKey *key)
{
  char buf[64];
  size_t len = 0;
  int button, row, col;
  static int last_pressed_button = 0;
  TermKeyMouseEvent ev;
  termkey_interpret_mouse(input->tk, key, &ev, &button, &row, &col);

  if ((ev == TERMKEY_MOUSE_RELEASE || ev == TERMKEY_MOUSE_DRAG)
      && button == 0) {
    // Some terminals (like urxvt) don't report which button was released.
    // libtermkey reports button 0 in this case.
    // For drag and release, we can reasonably infer the button to be the last
    // pressed one.
    button = last_pressed_button;
  }

  if ((button == 0 && ev != TERMKEY_MOUSE_RELEASE)
      || (ev != TERMKEY_MOUSE_PRESS && ev != TERMKEY_MOUSE_DRAG && ev != TERMKEY_MOUSE_RELEASE)) {
    return;
  }

  row--; col--;  // Termkey uses 1-based coordinates
  buf[len++] = '<';

  len += handle_termkey_modifiers(key, buf + len, sizeof(buf) - len);
  // Doesn't actually work because there are only 3 bits (0x1c) for modifiers.
  // len += handle_more_modifiers(key, buf + len, sizeof(buf) - len);

  if (button == 1) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Left");
  } else if (button == 2) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Middle");
  } else if (button == 3) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Right");
  } else if (button == 8) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "X1");
  } else if (button == 9) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "X2");
  }

  switch (ev) {
  case TERMKEY_MOUSE_PRESS:
    if (button == 4) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "ScrollWheelUp");
    } else if (button == 5) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "ScrollWheelDown");
    } else if (button == 6) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "ScrollWheelLeft");
    } else if (button == 7) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "ScrollWheelRight");
    } else {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Mouse");
      last_pressed_button = button;
    }
    break;
  case TERMKEY_MOUSE_DRAG:
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Drag");
    break;
  case TERMKEY_MOUSE_RELEASE:
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, button ? "Release" : "MouseMove");
    last_pressed_button = 0;
    break;
  case TERMKEY_MOUSE_UNKNOWN:
    abort();
  }

  len += (size_t)snprintf(buf + len, sizeof(buf) - len, "><%d,%d>", col, row);
  assert(len < sizeof(buf));
  tinput_enqueue(input, buf, len);
}

static TermKeyResult tk_getkey(TermKey *tk, TermKeyKey *key, bool force)
{
  return force ? termkey_getkey_force(tk, key) : termkey_getkey(tk, key);
}

static void tk_getkeys(TermInput *input, bool force)
{
  TermKeyKey key;
  TermKeyResult result;

  while ((result = tk_getkey(input->tk, &key, force)) == TERMKEY_RES_KEY) {
    // Only press and repeat events are handled for now
    switch (key.event) {
    case TERMKEY_EVENT_PRESS:
    case TERMKEY_EVENT_REPEAT:
      break;
    default:
      continue;
    }

    if (key.type == TERMKEY_TYPE_UNICODE && !(key.modifiers & KEYMOD_RECOGNIZED)) {
      forward_simple_utf8(input, &key);
    } else if (key.type == TERMKEY_TYPE_UNICODE
               || key.type == TERMKEY_TYPE_FUNCTION
               || key.type == TERMKEY_TYPE_KEYSYM) {
      forward_modified_utf8(input, &key);
    } else if (key.type == TERMKEY_TYPE_MOUSE) {
      forward_mouse_event(input, &key);
    } else if (key.type == TERMKEY_TYPE_MODEREPORT) {
      handle_modereport(input, &key);
    } else if (key.type == TERMKEY_TYPE_UNKNOWN_CSI) {
      handle_unknown_csi(input, &key);
    } else if (key.type == TERMKEY_TYPE_OSC || key.type == TERMKEY_TYPE_DCS) {
      handle_term_response(input, &key);
    }
  }

  if (result != TERMKEY_RES_AGAIN) {
    return;
  }
  // else: Partial keypress event was found in the buffer, but it does not
  // yet contain all the bytes required. `key` structure indicates what
  // termkey_getkey_force() would return.

  if (input->ttimeout && input->ttimeoutlen >= 0) {
    // Stop the current timer if already running
    uv_timer_stop(&input->timer_handle);
    uv_timer_start(&input->timer_handle, tinput_timer_cb, (uint64_t)input->ttimeoutlen, 0);
  } else {
    tk_getkeys(input, true);
  }
}

static void tinput_timer_cb(uv_timer_t *handle)
{
  TermInput *input = handle->data;
  // If the raw buffer is not empty, process the raw buffer first because it is
  // processing an incomplete bracketed paste sequence.
  size_t size = rstream_available(&input->read_stream);
  if (size) {
    size_t consumed = handle_raw_buffer(input, true, input->read_stream.read_pos, size);
    rstream_consume(&input->read_stream, consumed);
  }
  tk_getkeys(input, true);
  tinput_flush(input);
}

static void bg_query_timer_cb(uv_timer_t *handle)
  FUNC_ATTR_NONNULL_ALL
{
  TermInput *input = handle->data;
  tui_query_bg_color(input->tui_data);
}

/// Handle focus events.
///
/// If the upcoming sequence of bytes in the input stream matches the termcode
/// for "focus gained" or "focus lost", consume that sequence and send an event
/// to Nvim server.
///
/// @param input the input stream
/// @return true iff handle_focus_event consumed some input
static size_t handle_focus_event(TermInput *input, const char *ptr, size_t size)
{
  if (size >= 3
      && (!memcmp(ptr, "\x1b[I", 3)
          || !memcmp(ptr, "\x1b[O", 3))) {
    bool focus_gained = ptr[2] == 'I';

    MAXSIZE_TEMP_ARRAY(args, 1);
    ADD_C(args, BOOLEAN_OBJ(focus_gained));
    rpc_send_event(ui_client_channel_id, "nvim_ui_set_focus", args);
    return 3;  // Advance past the sequence
  }
  return 0;
}

#define START_PASTE "\x1b[200~"
#define END_PASTE   "\x1b[201~"
static size_t handle_bracketed_paste(TermInput *input, const char *ptr, size_t size,
                                     bool *incomplete)
{
  if (size >= 6
      && (!memcmp(ptr, START_PASTE, 6)
          || !memcmp(ptr, END_PASTE, 6))) {
    bool enable = ptr[4] == '0';
    if (input->paste && enable) {
      return 0;  // Pasting "start paste" code literally.
    }

    // Advance past the sequence
    if (!!input->paste == enable) {
      return 6;  // Spurious "disable paste" code.
    }

    if (enable) {
      // Flush before starting paste.
      tinput_flush(input);
      // Paste phase: "first-chunk".
      input->paste = 1;
    } else if (input->paste) {
      // Paste phase: "last-chunk".
      input->paste = input->paste == 2 ? 3 : -1;
      tinput_flush(input);
      // Paste phase: "disabled".
      input->paste = 0;
    }
    return 6;
  } else if (size < 6
             && (!memcmp(ptr, START_PASTE, size)
                 || !memcmp(ptr, END_PASTE, size))) {
    // Wait for further input, as the sequence may be split.
    *incomplete = true;
    return 0;
  }
  return 0;
}

/// Handle an OSC or DCS response sequence from the terminal.
static void handle_term_response(TermInput *input, const TermKeyKey *key)
  FUNC_ATTR_NONNULL_ALL
{
  const char *str = NULL;
  if (termkey_interpret_string(input->tk, key, &str) == TERMKEY_RES_KEY) {
    assert(str != NULL);

    // Handle DECRQSS SGR response for the query from tui_query_extended_underline().
    // Some terminals include "0" in the attribute list unconditionally; others don't.
    if (key->type == TERMKEY_TYPE_DCS
        && (strnequal(str, S_LEN("1$r4:3m")) || strnequal(str, S_LEN("1$r0;4:3m")))) {
      tui_enable_extended_underline(input->tui_data);
    }

    // Send an event to nvim core. This will update the v:termresponse variable
    // and fire the TermResponse event
    MAXSIZE_TEMP_ARRAY(args, 2);
    ADD_C(args, STATIC_CSTR_AS_OBJ("termresponse"));

    // libtermkey strips the OSC/DCS bytes from the response. We add it back in
    // so that downstream consumers of v:termresponse can differentiate between
    // the two.
    StringBuilder response = KV_INITIAL_VALUE;
    switch (key->type) {
    case TERMKEY_TYPE_OSC:
      kv_printf(response, "\x1b]%s", str);
      break;
    case TERMKEY_TYPE_DCS:
      kv_printf(response, "\x1bP%s", str);
      break;
    default:
      // Key type already checked for OSC/DCS in termkey_interpret_string
      UNREACHABLE;
    }

    ADD_C(args, STRING_OBJ(cbuf_as_string(response.items, response.size)));
    rpc_send_event(ui_client_channel_id, "nvim_ui_term_event", args);
    kv_destroy(response);
  }
}

/// Handle a mode report (DECRPM) sequence from the terminal.
static void handle_modereport(TermInput *input, const TermKeyKey *key)
  FUNC_ATTR_NONNULL_ALL
{
  int initial;
  int mode;
  int value;
  if (termkey_interpret_modereport(input->tk, key, &initial, &mode, &value) == TERMKEY_RES_KEY) {
    (void)initial;  // Unused
    tui_handle_term_mode(input->tui_data, (TermMode)mode, (TermModeState)value);
  }
}

/// Handle a CSI sequence from the terminal that is unrecognized by libtermkey.
static void handle_unknown_csi(TermInput *input, const TermKeyKey *key)
  FUNC_ATTR_NONNULL_ALL
{
  // There is no specified limit on the number of parameters a CSI sequence can
  // contain, so just allocate enough space for a large upper bound
  TermKeyCsiParam params[16];
  size_t nparams = 16;
  unsigned cmd;
  if (termkey_interpret_csi(input->tk, key, params, &nparams, &cmd) != TERMKEY_RES_KEY) {
    return;
  }

  uint8_t intermediate = (cmd >> 16) & 0xFF;
  uint8_t initial = (cmd >> 8) & 0xFF;
  uint8_t command = cmd & 0xFF;

  // Currently unused
  (void)intermediate;

  switch (command) {
  case 'u':
    switch (initial) {
    case '?':
      // Kitty keyboard protocol query response.
      input->key_encoding = kKeyEncodingKitty;
      break;
    }
    break;
  case 'c':
    switch (initial) {
    case '?':
      // Primary Device Attributes (DA1) response
      if (input->callbacks.primary_device_attr) {
        input->callbacks.primary_device_attr(input->tui_data);
        input->callbacks.primary_device_attr = NULL;
      }

      break;
    }
    break;
  case 't':
    if (nparams == 5) {
      // We only care about the first 3 parameters, and we ignore subparameters
      int args[3];
      for (size_t i = 0; i < ARRAY_SIZE(args); i++) {
        if (termkey_interpret_csi_param(params[i], &args[i], NULL, NULL) != TERMKEY_RES_KEY) {
          return;
        }
      }

      if (args[0] == 48) {
        // In-band resize event (DEC private mode 2048)
        int height_chars = args[1];
        int width_chars = args[2];
        tui_set_size(input->tui_data, width_chars, height_chars);
        ui_client_set_size(width_chars, height_chars);
      }
    }
    break;
  case 'n':
    // Device Status Report (DSR)
    if (nparams == 2) {
      int args[2];
      for (size_t i = 0; i < ARRAY_SIZE(args); i++) {
        if (termkey_interpret_csi_param(params[i], &args[i], NULL, NULL) != TERMKEY_RES_KEY) {
          return;
        }
      }

      if (args[0] == 997) {
        // Theme update notification
        // https://github.com/contour-terminal/contour/blob/master/docs/vt-extensions/color-palette-update-notifications.md
        // The second argument tells us whether the OS theme is set to light
        // mode or dark mode, but all we care about is the background color of
        // the terminal emulator. We query for that with OSC 11 and the response
        // is handled by the autocommand created in _defaults.lua. The terminal
        // may send us multiple notifications all at once so we use a timer to
        // coalesce the queries.
        if (uv_timer_get_due_in(&input->bg_query_timer) > 0) {
          return;
        }

        uv_timer_start(&input->bg_query_timer, bg_query_timer_cb, 100, 0);
      }
    }
    break;
  default:
    break;
  }
}

static size_t handle_raw_buffer(TermInput *input, bool force, const char *data, size_t size)
{
  const char *ptr = data;

  do {
    if (!force) {
      size_t consumed = handle_focus_event(input, ptr, size);
      if (consumed) {
        ptr += consumed;
        size -= consumed;
        continue;
      }

      bool incomplete = false;
      consumed = handle_bracketed_paste(input, ptr, size, &incomplete);
      if (incomplete) {
        assert(consumed == 0);
        // Wait for the next input, leaving it in the raw buffer due to an
        // incomplete sequence.
        return (size_t)(ptr - data);
      } else if (consumed) {
        ptr += consumed;
        size -= consumed;
        continue;
      }
    }

    //
    // Find the next ESC and push everything up to it (excluding), so it will
    // be the first thing encountered on the next iteration. The `handle_*`
    // calls (above) depend on this.
    //
    size_t count = 0;
    for (size_t i = 0; i < size; i++) {
      count = i + 1;
      if (ptr[i] == '\x1b' && count > 1) {
        count--;
        break;
      }
    }
    // Push bytes directly (paste).
    if (input->paste) {
      tinput_enqueue(input, ptr, count);
      ptr += count;
      size -= count;
      continue;
    }

    // Push through libtermkey (translates to "<keycode>" strings, etc.).
    {
      const size_t to_use = MIN(count, size);
      if (to_use > termkey_get_buffer_remaining(input->tk)) {
        // We are processing a very long escape sequence. Increase termkey's
        // internal buffer size. We don't handle out of memory situations so
        // abort if it fails
        const size_t delta = to_use - termkey_get_buffer_remaining(input->tk);
        const size_t bufsize = termkey_get_buffer_size(input->tk);
        if (!termkey_set_buffer_size(input->tk, MAX(bufsize + delta, bufsize * 2))) {
          abort();
        }
      }

      size_t consumed = termkey_push_bytes(input->tk, ptr, to_use);

      // We resize termkey's buffer when it runs out of space, so this should
      // never happen
      assert(consumed <= to_use);
      ptr += consumed;
      size -= consumed;

      // Process the input buffer now for any keys
      tk_getkeys(input, false);
    }
  } while (size);

  const size_t tk_size = termkey_get_buffer_size(input->tk);
  const size_t tk_remaining = termkey_get_buffer_remaining(input->tk);
  const size_t tk_count = tk_size - tk_remaining;
  if (tk_count < INPUT_BUFFER_SIZE && tk_size > INPUT_BUFFER_SIZE) {
    // If the termkey buffer was resized to handle a large input sequence then
    // shrink it back down to its original size.
    if (!termkey_set_buffer_size(input->tk, INPUT_BUFFER_SIZE)) {
      abort();
    }
  }

  return (size_t)(ptr - data);
}

static size_t tinput_read_cb(RStream *stream, const char *buf, size_t count_, void *data, bool eof)
{
  TermInput *input = data;

  size_t consumed = handle_raw_buffer(input, false, buf, count_);
  tinput_flush(input);

  if (eof) {
    loop_schedule_fast(&main_loop, event_create(tinput_done_event, NULL));
    return consumed;
  }

  // An incomplete sequence was found. Leave it in the raw buffer and wait for
  // the next input.
  if (consumed < count_) {
    // If 'ttimeout' is not set, start the timer with a timeout of 0 to process
    // the next input.
    int64_t ms = input->ttimeout
                 ? (input->ttimeoutlen >= 0 ? input->ttimeoutlen : 0) : 0;
    // Stop the current timer if already running
    uv_timer_stop(&input->timer_handle);
    uv_timer_start(&input->timer_handle, tinput_timer_cb, (uint32_t)ms, 0);
  }

  return consumed;
}
