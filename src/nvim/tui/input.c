// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/event/defs.h"
#include "nvim/log.h"
#include "nvim/macros.h"
#include "nvim/main.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/tui/input.h"
#include "nvim/tui/input_defs.h"
#include "nvim/tui/tui.h"
#include "nvim/types.h"
#include "nvim/ui_client.h"
#ifdef MSWIN
# include "nvim/os/os_win_console.h"
#endif
#include "nvim/event/rstream.h"
#include "nvim/msgpack_rpc/channel.h"

#define KEY_BUFFER_SIZE 0xfff

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

static Map(int, cstr_t) kitty_key_map = MAP_INIT;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/input.c.generated.h"
#endif

void tinput_init(TermInput *input, Loop *loop)
{
  input->loop = loop;
  input->paste = 0;
  input->in_fd = STDIN_FILENO;
  input->waiting_for_bg_response = 0;
  input->extkeys_type = kExtkeysNone;
  // The main thread is waiting for the UI thread to call CONTINUE, so it can
  // safely access global variables.
  input->ttimeout = (bool)p_ttimeout;
  input->ttimeoutlen = p_ttm;
  input->key_buffer = rbuffer_new(KEY_BUFFER_SIZE);

  for (size_t i = 0; i < ARRAY_SIZE(kitty_key_map_entry); i++) {
    map_put(int, cstr_t)(&kitty_key_map, kitty_key_map_entry[i].key,
                         kitty_key_map_entry[i].name);
  }

  input->in_fd = STDIN_FILENO;

  const char *term = os_getenv("TERM");
  if (!term) {
    term = "";  // termkey_new_abstract assumes non-null (#2745)
  }

  input->tk = termkey_new_abstract(term,
                                   TERMKEY_FLAG_UTF8 | TERMKEY_FLAG_NOSTART);
  termkey_hook_terminfo_getstr(input->tk, input->tk_ti_hook_fn, input);
  termkey_start(input->tk);

  int curflags = termkey_get_canonflags(input->tk);
  termkey_set_canonflags(input->tk, curflags | TERMKEY_CANON_DELBS);

  // setup input handle
  rstream_init_fd(loop, &input->read_stream, input->in_fd, 0xfff);
  // initialize a timer handle for handling ESC with libtermkey
  time_watcher_init(loop, &input->timer_handle, input);
}

void tinput_destroy(TermInput *input)
{
  map_destroy(int, &kitty_key_map);
  rbuffer_free(input->key_buffer);
  time_watcher_close(&input->timer_handle, NULL);
  stream_close(&input->read_stream, NULL, NULL);
  termkey_destroy(input->tk);
}

void tinput_start(TermInput *input)
{
  rstream_start(&input->read_stream, tinput_read_cb, input);
}

void tinput_stop(TermInput *input)
{
  rstream_stop(&input->read_stream);
  time_watcher_stop(&input->timer_handle);
}

static void tinput_done_event(void **argv)
  FUNC_ATTR_NORETURN
{
  os_exit(1);
}

/// Send all pending input in key buffer to Nvim server.
static void tinput_flush(TermInput *input)
{
  if (input->paste) {  // produce exactly one paste event
    const size_t len = rbuffer_size(input->key_buffer);
    String keys = { .data = xmallocz(len), .size = len };
    rbuffer_read(input->key_buffer, keys.data, len);
    MAXSIZE_TEMP_ARRAY(args, 3);
    ADD_C(args, STRING_OBJ(keys));  // 'data'
    ADD_C(args, BOOLEAN_OBJ(true));  // 'crlf'
    ADD_C(args, INTEGER_OBJ(input->paste));  // 'phase'
    rpc_send_event(ui_client_channel_id, "nvim_paste", args);
    api_free_string(keys);
    if (input->paste == 1) {
      // Paste phase: "continue"
      input->paste = 2;
    }
    rbuffer_reset(input->key_buffer);
  } else {  // enqueue input
    RBUFFER_UNTIL_EMPTY(input->key_buffer, buf, len) {
      const String keys = { .data = buf, .size = len };
      MAXSIZE_TEMP_ARRAY(args, 1);
      ADD_C(args, STRING_OBJ(keys));
      // NOTE: This is non-blocking and won't check partially processed input,
      // but should be fine as all big sends are handled with nvim_paste, not nvim_input
      rpc_send_event(ui_client_channel_id, "nvim_input", args);
      rbuffer_consumed(input->key_buffer, len);
      rbuffer_reset(input->key_buffer);
    }
  }
}

static void tinput_enqueue(TermInput *input, char *buf, size_t size)
{
  if (rbuffer_size(input->key_buffer) >
      rbuffer_capacity(input->key_buffer) - 0xff) {
    // don't ever let the buffer get too full or we risk putting incomplete keys
    // into it
    tinput_flush(input);
  }
  rbuffer_write(input->key_buffer, buf, size);
}

static void handle_kitty_key_protocol(TermInput *input, TermKeyKey *key)
{
  const char *name = map_get(int, cstr_t)(&kitty_key_map, (int)key->code.codepoint);
  if (name) {
    char buf[64];
    size_t len = 0;
    buf[len++] = '<';
    if (key->modifiers & TERMKEY_KEYMOD_SHIFT) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "S-");
    }
    if (key->modifiers & TERMKEY_KEYMOD_ALT) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "A-");
    }
    if (key->modifiers & TERMKEY_KEYMOD_CTRL) {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "C-");
    }
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "%s>", name);
    tinput_enqueue(input, buf, len);
  }
}

static void forward_simple_utf8(TermInput *input, TermKeyKey *key)
{
  size_t len = 0;
  char buf[64];
  char *ptr = key->utf8;

  if (key->code.codepoint >= 0xE000 && key->code.codepoint <= 0xF8FF
      && map_has(int, cstr_t)(&kitty_key_map, (int)key->code.codepoint)) {
    handle_kitty_key_protocol(input, key);
    return;
  }
  while (*ptr) {
    if (*ptr == '<') {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "<lt>");
    } else {
      buf[len++] = *ptr;
    }
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
        && map_has(int, cstr_t)(&kitty_key_map, (int)key->code.codepoint)) {
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
      assert(len <= 62);
      // Make room for the S-
      memmove(buf + 3, buf + 1, len - 1);
      buf[1] = 'S';
      buf[2] = '-';
      len += 2;
    }
  }

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

  if (ev == TERMKEY_MOUSE_UNKNOWN && !(key->code.mouse[0] & 0x20)) {
    int code = key->code.mouse[0] & ~0x3c;
    if (code == 66 || code == 67) {
      ev = TERMKEY_MOUSE_PRESS;
      button = code - 60;
    }
  }

  if ((button == 0 && ev != TERMKEY_MOUSE_RELEASE)
      || (ev != TERMKEY_MOUSE_PRESS && ev != TERMKEY_MOUSE_DRAG && ev != TERMKEY_MOUSE_RELEASE)) {
    return;
  }

  row--; col--;  // Termkey uses 1-based coordinates
  buf[len++] = '<';

  if (key->modifiers & TERMKEY_KEYMOD_SHIFT) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "S-");
  }

  if (key->modifiers & TERMKEY_KEYMOD_CTRL) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "C-");
  }

  if (key->modifiers & TERMKEY_KEYMOD_ALT) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "A-");
  }

  if (button == 1) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Left");
  } else if (button == 2) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Middle");
  } else if (button == 3) {
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Right");
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
    if (key.type == TERMKEY_TYPE_UNICODE && !key.modifiers) {
      forward_simple_utf8(input, &key);
    } else if (key.type == TERMKEY_TYPE_UNICODE
               || key.type == TERMKEY_TYPE_FUNCTION
               || key.type == TERMKEY_TYPE_KEYSYM) {
      forward_modified_utf8(input, &key);
    } else if (key.type == TERMKEY_TYPE_MOUSE) {
      forward_mouse_event(input, &key);
    } else if (key.type == TERMKEY_TYPE_UNKNOWN_CSI) {
      // There is no specified limit on the number of parameters a CSI sequence can contain, so just
      // allocate enough space for a large upper bound
      long args[16];
      size_t nargs = 16;
      unsigned long cmd;
      if (termkey_interpret_csi(input->tk, &key, args, &nargs, &cmd) == TERMKEY_RES_KEY) {
        uint8_t intermediate = (cmd >> 16) & 0xFF;
        uint8_t initial = (cmd >> 8) & 0xFF;
        uint8_t command = cmd & 0xFF;

        // Currently unused
        (void)intermediate;

        if (input->waiting_for_csiu_response > 0) {
          if (initial == '?' && command == 'u') {
            // The first (and only) argument contains the current progressive
            // enhancement flags. Only enable CSI u mode if the first bit
            // (disambiguate escape codes) is not already set
            if (nargs > 0 && (args[0] & 0x1) == 0) {
              input->extkeys_type = kExtkeysCSIu;
            } else {
              input->extkeys_type = kExtkeysNone;
            }
          } else if (initial == '?' && command == 'c') {
            // Received Primary Device Attributes response
            input->waiting_for_csiu_response = 0;
            tui_enable_extkeys(input->tui_data);
          } else {
            input->waiting_for_csiu_response--;
          }
        }
      }
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
    time_watcher_stop(&input->timer_handle);
    time_watcher_start(&input->timer_handle, tinput_timer_cb,
                       (uint64_t)input->ttimeoutlen, 0);
  } else {
    tk_getkeys(input, true);
  }
}

static void tinput_timer_cb(TimeWatcher *watcher, void *data)
{
  TermInput *input = (TermInput *)data;
  // If the raw buffer is not empty, process the raw buffer first because it is
  // processing an incomplete bracketed paster sequence.
  if (rbuffer_size(input->read_stream.buffer)) {
    handle_raw_buffer(input, true);
  }
  tk_getkeys(input, true);
  tinput_flush(input);
}

/// Handle focus events.
///
/// If the upcoming sequence of bytes in the input stream matches the termcode
/// for "focus gained" or "focus lost", consume that sequence and schedule an
/// event on the main loop.
///
/// @param input the input stream
/// @return true iff handle_focus_event consumed some input
static bool handle_focus_event(TermInput *input)
{
  if (rbuffer_size(input->read_stream.buffer) > 2
      && (!rbuffer_cmp(input->read_stream.buffer, "\x1b[I", 3)
          || !rbuffer_cmp(input->read_stream.buffer, "\x1b[O", 3))) {
    bool focus_gained = *rbuffer_get(input->read_stream.buffer, 2) == 'I';
    // Advance past the sequence
    rbuffer_consumed(input->read_stream.buffer, 3);

    MAXSIZE_TEMP_ARRAY(args, 1);
    ADD_C(args, BOOLEAN_OBJ(focus_gained));
    rpc_send_event(ui_client_channel_id, "nvim_ui_set_focus", args);
    return true;
  }
  return false;
}

#define START_PASTE "\x1b[200~"
#define END_PASTE   "\x1b[201~"
static HandleState handle_bracketed_paste(TermInput *input)
{
  size_t buf_size = rbuffer_size(input->read_stream.buffer);
  if (buf_size > 5
      && (!rbuffer_cmp(input->read_stream.buffer, START_PASTE, 6)
          || !rbuffer_cmp(input->read_stream.buffer, END_PASTE, 6))) {
    bool enable = *rbuffer_get(input->read_stream.buffer, 4) == '0';
    if (input->paste && enable) {
      return kNotApplicable;  // Pasting "start paste" code literally.
    }
    // Advance past the sequence
    rbuffer_consumed(input->read_stream.buffer, 6);
    if (!!input->paste == enable) {
      return kComplete;  // Spurious "disable paste" code.
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
    return kComplete;
  } else if (buf_size < 6
             && (!rbuffer_cmp(input->read_stream.buffer, START_PASTE, buf_size)
                 || !rbuffer_cmp(input->read_stream.buffer,
                                 END_PASTE, buf_size))) {
    // Wait for further input, as the sequence may be split.
    return kIncomplete;
  }
  return kNotApplicable;
}

static void set_bg(char *bgvalue)
{
  if (ui_client_attached) {
    MAXSIZE_TEMP_ARRAY(args, 2);
    ADD_C(args, CSTR_AS_OBJ("term_background"));
    ADD_C(args, CSTR_AS_OBJ(bgvalue));
    rpc_send_event(ui_client_channel_id, "nvim_ui_set_option", args);
  }
}

// During startup, tui.c requests the background color (see `ext.get_bg`).
//
// Here in input.c, we watch for the terminal response `\e]11;COLOR\a`.  If
// COLOR matches `rgb:RRRR/GGGG/BBBB/AAAA` where R, G, B, and A are hex digits,
// then compute the luminance[1] of the RGB color and classify it as light/dark
// accordingly. Note that the color components may have anywhere from one to
// four hex digits, and require scaling accordingly as values out of 4, 8, 12,
// or 16 bits. Also note the A(lpha) component is optional, and is parsed but
// ignored in the calculations.
//
// [1] https://en.wikipedia.org/wiki/Luma_%28video%29
HandleState handle_background_color(TermInput *input)
{
  if (input->waiting_for_bg_response <= 0) {
    return kNotApplicable;
  }
  size_t count = 0;
  size_t component = 0;
  size_t header_size = 0;
  size_t num_components = 0;
  size_t buf_size = rbuffer_size(input->read_stream.buffer);
  uint16_t rgb[] = { 0, 0, 0 };
  uint16_t rgb_max[] = { 0, 0, 0 };
  bool eat_backslash = false;
  bool done = false;
  bool bad = false;
  if (buf_size >= 9
      && !rbuffer_cmp(input->read_stream.buffer, "\x1b]11;rgb:", 9)) {
    header_size = 9;
    num_components = 3;
  } else if (buf_size >= 10
             && !rbuffer_cmp(input->read_stream.buffer, "\x1b]11;rgba:", 10)) {
    header_size = 10;
    num_components = 4;
  } else if (buf_size < 10
             && !rbuffer_cmp(input->read_stream.buffer,
                             "\x1b]11;rgba", buf_size)) {
    // An incomplete sequence was found, waiting for the next input.
    return kIncomplete;
  } else {
    input->waiting_for_bg_response--;
    if (input->waiting_for_bg_response == 0) {
      DLOG("did not get a response for terminal background query");
    }
    return kNotApplicable;
  }
  RBUFFER_EACH(input->read_stream.buffer, c, i) {
    count = i + 1;
    // Skip the header.
    if (i < header_size) {
      continue;
    }
    if (eat_backslash) {
      done = true;
      break;
    } else if (c == '\x07') {
      done = true;
      break;
    } else if (c == '\x1b') {
      eat_backslash = true;
    } else if (bad) {
      // ignore
    } else if ((c == '/') && (++component < num_components)) {
      // work done in condition
    } else if (ascii_isxdigit(c)) {
      if (component < 3 && rgb_max[component] != 0xffff) {
        rgb_max[component] = (uint16_t)((rgb_max[component] << 4) | 0xf);
        rgb[component] = (uint16_t)((rgb[component] << 4) | hex2nr(c));
      }
    } else {
      bad = true;
    }
  }
  if (done && !bad && rgb_max[0] && rgb_max[1] && rgb_max[2]) {
    rbuffer_consumed(input->read_stream.buffer, count);
    double r = (double)rgb[0] / (double)rgb_max[0];
    double g = (double)rgb[1] / (double)rgb_max[1];
    double b = (double)rgb[2] / (double)rgb_max[2];
    double luminance = (0.299 * r) + (0.587 * g) + (0.114 * b);  // CCIR 601
    bool is_dark = luminance < 0.5;
    char *bgvalue = is_dark ? "dark" : "light";
    DLOG("bg response: %s", bgvalue);
    ui_client_bg_response = is_dark ? kTrue : kFalse;
    set_bg(bgvalue);
    input->waiting_for_bg_response = 0;
  } else if (!done && !bad) {
    // An incomplete sequence was found, waiting for the next input.
    return kIncomplete;
  } else {
    input->waiting_for_bg_response = 0;
    rbuffer_consumed(input->read_stream.buffer, count);
    DLOG("failed to parse bg response");
    return kNotApplicable;
  }
  return kComplete;
}

static void handle_raw_buffer(TermInput *input, bool force)
{
  HandleState is_paste = kNotApplicable;
  HandleState is_bc = kNotApplicable;

  do {
    if (!force
        && (handle_focus_event(input)
            || (is_paste = handle_bracketed_paste(input)) != kNotApplicable
            || (is_bc = handle_background_color(input)) != kNotApplicable)) {
      if (is_paste == kIncomplete || is_bc == kIncomplete) {
        // Wait for the next input, leaving it in the raw buffer due to an
        // incomplete sequence.
        return;
      }
      continue;
    }

    //
    // Find the next ESC and push everything up to it (excluding), so it will
    // be the first thing encountered on the next iteration. The `handle_*`
    // calls (above) depend on this.
    //
    size_t count = 0;
    RBUFFER_EACH(input->read_stream.buffer, c, i) {
      count = i + 1;
      if (c == '\x1b' && count > 1) {
        count--;
        break;
      }
    }
    // Push bytes directly (paste).
    if (input->paste) {
      RBUFFER_UNTIL_EMPTY(input->read_stream.buffer, ptr, len) {
        size_t consumed = MIN(count, len);
        assert(consumed <= input->read_stream.buffer->size);
        tinput_enqueue(input, ptr, consumed);
        rbuffer_consumed(input->read_stream.buffer, consumed);
        if (!(count -= consumed)) {
          break;
        }
      }
      continue;
    }
    // Push through libtermkey (translates to "<keycode>" strings, etc.).
    RBUFFER_UNTIL_EMPTY(input->read_stream.buffer, ptr, len) {
      size_t consumed = termkey_push_bytes(input->tk, ptr, MIN(count, len));
      // termkey_push_bytes can return (size_t)-1, so it is possible that
      // `consumed > input->read_stream.buffer->size`, but since tk_getkeys is
      // called soon, it shouldn't happen.
      assert(consumed <= input->read_stream.buffer->size);
      rbuffer_consumed(input->read_stream.buffer, consumed);
      // Process the keys now: there is no guarantee `count` will
      // fit into libtermkey's input buffer.
      tk_getkeys(input, false);
      if (!(count -= consumed)) {
        break;
      }
    }
  } while (rbuffer_size(input->read_stream.buffer));
}

static void tinput_read_cb(Stream *stream, RBuffer *buf, size_t count_, void *data, bool eof)
{
  TermInput *input = data;

  if (eof) {
    loop_schedule_fast(&main_loop, event_create(tinput_done_event, 0));
    return;
  }

  handle_raw_buffer(input, false);
  tinput_flush(input);

  // An incomplete sequence was found. Leave it in the raw buffer and wait for
  // the next input.
  if (rbuffer_size(input->read_stream.buffer)) {
    // If 'ttimeout' is not set, start the timer with a timeout of 0 to process
    // the next input.
    long ms = input->ttimeout ?
              (input->ttimeoutlen >= 0 ? input->ttimeoutlen : 0) : 0;
    // Stop the current timer if already running
    time_watcher_stop(&input->timer_handle);
    time_watcher_start(&input->timer_handle, tinput_timer_cb, (uint32_t)ms, 0);
    return;
  }

  // Make sure the next input escape sequence fits into the ring buffer without
  // wraparound, else it could be misinterpreted (because rbuffer_read_ptr()
  // exposes the underlying buffer to callers unaware of the wraparound).
  rbuffer_reset(input->read_stream.buffer);
}
