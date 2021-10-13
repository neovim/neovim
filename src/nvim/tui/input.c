// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com


#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/aucmd.h"
#include "nvim/charset.h"
#include "nvim/ex_docmd.h"
#include "nvim/macros.h"
#include "nvim/main.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/tui/input.h"
#include "nvim/vim.h"
#ifdef WIN32
# include "nvim/os/os_win_console.h"
#endif
#include "nvim/event/rstream.h"

#define KEY_BUFFER_SIZE 0xfff

#ifndef UNIT_TESTING
typedef enum {
  kIncomplete = -1,
  kNotApplicable = 0,
  kComplete = 1,
} HandleState;
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/input.c.generated.h"
#endif

void tinput_init(TermInput *input, Loop *loop)
{
  input->loop = loop;
  input->paste = 0;
  input->in_fd = STDIN_FILENO;
  input->waiting_for_bg_response = 0;
  // The main thread is waiting for the UI thread to call CONTINUE, so it can
  // safely access global variables.
  input->ttimeout = (bool)p_ttimeout;
  input->ttimeoutlen = p_ttm;
  input->key_buffer = rbuffer_new(KEY_BUFFER_SIZE);

  // If stdin is not a pty, switch to stderr. For cases like:
  //    echo q | nvim -es
  //    ls *.md | xargs nvim
#ifdef WIN32
  if (!os_isatty(input->in_fd)) {
    input->in_fd = os_get_conin_fd();
  }
#else
  if (!os_isatty(input->in_fd) && os_isatty(STDERR_FILENO)) {
    input->in_fd = STDERR_FILENO;
  }
#endif
  input_global_fd_init(input->in_fd);

  const char *term = os_getenv("TERM");
  if (!term) {
    term = "";  // termkey_new_abstract assumes non-null (#2745)
  }

#if TERMKEY_VERSION_MAJOR > 0 || TERMKEY_VERSION_MINOR > 18
  input->tk = termkey_new_abstract(term,
                                   TERMKEY_FLAG_UTF8 | TERMKEY_FLAG_NOSTART);
  termkey_hook_terminfo_getstr(input->tk, input->tk_ti_hook_fn, NULL);
  termkey_start(input->tk);
#else
  input->tk = termkey_new_abstract(term, TERMKEY_FLAG_UTF8);
#endif

  int curflags = termkey_get_canonflags(input->tk);
  termkey_set_canonflags(input->tk, curflags | TERMKEY_CANON_DELBS);

  // setup input handle
  rstream_init_fd(loop, &input->read_stream, input->in_fd, 0xfff);
  // initialize a timer handle for handling ESC with libtermkey
  time_watcher_init(loop, &input->timer_handle, input);
}

void tinput_destroy(TermInput *input)
{
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
{
  input_done();
}

static void tinput_input_event(void **argv)
{
  Integer phase = (Integer)(intptr_t)argv[2];
  if (phase) {
    multiqueue_put(main_loop.events, tinput_paste_event, 3,
                   argv[0], argv[1], (intptr_t)phase);
  } else {
    const String keys = { .data = argv[0], .size = (size_t)argv[1] };
    input_enqueue(keys);
    api_free_string(keys);
  }
}

static void tinput_paste_event(void **argv)
{
  String keys = { .data = argv[0], .size = (size_t)argv[1] };
  intptr_t phase = (intptr_t)argv[2];

  Error err = ERROR_INIT;
  nvim_paste(keys, true, phase, &err);
  if (ERROR_SET(&err)) {
    emsgf("paste: %s", err.msg);
    api_clear_error(&err);
  }

  api_free_string(keys);
}

static void tinput_flush(TermInput *input)
{
  size_t size = rbuffer_size(input->key_buffer);
  bool is_empty_phase3 = (size == 0 && input->paste == 3);
  if (size == 0 && !is_empty_phase3) {
    return;
  }
  char *data = xmalloc(is_empty_phase3 ? 1 : size);
  if (is_empty_phase3) {
    *data = '\0';
  } else {
    char *pos = data;
    RBUFFER_UNTIL_EMPTY(input->key_buffer, buf, len) {
      memcpy(pos, buf, len);
      pos += len;
      rbuffer_consumed(input->key_buffer, len);
      rbuffer_reset(input->key_buffer);
    }
  }
  loop_schedule_fast(&main_loop, event_create(tinput_input_event, 3,
                                              data, (intptr_t)size,
                                              (intptr_t)input->paste));
  if (input->paste == 1) {
    // Paste phase: "continue"
    input->paste = 2;
  }
}

static void tinput_enqueue(TermInput *input, char *buf, size_t size)
{
  if (rbuffer_space(input->key_buffer) < size) {
    tinput_flush(input);
  }
  rbuffer_write(input->key_buffer, buf, size);
}

static void forward_simple_utf8(TermInput *input, TermKeyKey *key)
{
  size_t len = 0;
  char buf[64];
  char *ptr = key->utf8;

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
    // Termkey doesn't include the S- modifier for ASCII characters (e.g.,
    // ctrl-shift-l is <C-L> instead of <C-S-L>.  Vim, on the other hand,
    // treats <C-L> and <C-l> the same, requiring the S- modifier.
    len = termkey_strfkey(input->tk, buf, sizeof(buf), key, TERMKEY_FORMAT_VIM);
    if ((key->modifiers & TERMKEY_KEYMOD_CTRL)
        && !(key->modifiers & TERMKEY_KEYMOD_SHIFT)
        && ASCII_ISUPPER(key->code.codepoint)) {
      assert(len <= 62);
      // Make remove for the S-
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

  if (button == 0 || (ev != TERMKEY_MOUSE_PRESS && ev != TERMKEY_MOUSE_DRAG
                      && ev != TERMKEY_MOUSE_RELEASE)) {
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
      len += (size_t)snprintf(buf + len, sizeof(buf) - len,
                              "ScrollWheelDown");
    } else {
      len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Mouse");
      last_pressed_button = button;
    }
    break;
  case TERMKEY_MOUSE_DRAG:
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Drag");
    break;
  case TERMKEY_MOUSE_RELEASE:
    len += (size_t)snprintf(buf + len, sizeof(buf) - len, "Release");
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

static void tinput_timer_cb(TimeWatcher *watcher, void *data);

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
    aucmd_schedule_focusgained(focus_gained);
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

// ESC NUL => <Esc>
static bool handle_forced_escape(TermInput *input)
{
  if (rbuffer_size(input->read_stream.buffer) > 1
      && !rbuffer_cmp(input->read_stream.buffer, "\x1b\x00", 2)) {
    // skip the ESC and NUL and push one <esc> to the input buffer
    size_t rcnt;
    termkey_push_bytes(input->tk, rbuffer_read_ptr(input->read_stream.buffer,
                                                   &rcnt), 1);
    rbuffer_consumed(input->read_stream.buffer, 2);
    tk_getkeys(input, true);
    return true;
  }
  return false;
}

static void set_bg_deferred(void **argv)
{
  char *bgvalue = argv[0];
  if (!option_was_set("bg") && !strequal((char *)p_bg, bgvalue)) {
    // Value differs, apply it.
    if (starting) {
      // Wait until after startup, so OptionSet is triggered.
      do_cmdline_cmd((bgvalue[0] == 'l')
                     ? "autocmd VimEnter * ++once ++nested set bg=light"
                     : "autocmd VimEnter * ++once ++nested set bg=dark");
    } else {
      set_option_value("bg", 0L, bgvalue, 0);
      reset_option_was_set("bg");
    }
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
static HandleState handle_background_color(TermInput *input)
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
    char *bgvalue = luminance < 0.5 ? "dark" : "light";
    DLOG("bg response: %s", bgvalue);
    loop_schedule_deferred(&main_loop,
                           event_create(set_bg_deferred, 1, bgvalue));
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
#ifdef UNIT_TESTING
HandleState ut_handle_background_color(TermInput *input)
{
  return handle_background_color(input);
}
#endif

static void handle_raw_buffer(TermInput *input, bool force)
{
  HandleState is_paste = kNotApplicable;
  HandleState is_bc = kNotApplicable;

  do {
    if (!force
        && (handle_focus_event(input)
            || (is_paste = handle_bracketed_paste(input)) != kNotApplicable
            || handle_forced_escape(input)
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
