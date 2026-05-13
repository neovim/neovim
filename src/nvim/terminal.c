// VT220/xterm-like terminal emulator.
// Powered by libghostty https://ghostty.org
//
// Keys are encoded into byte streams that must be fed back to the master fd.
//
// Nvim buffers are used as the display mechanism for both the visible screen
// and the scrollback buffer.
//
// libghostty owns the terminal screen and scrollback contents. Nvim buffers
// mirror Ghostty's screen and the visible slice of Ghostty's history so
// scrollback remains a normal buffer.
//
// The terminal->nvim synchronization is performed in intervals of 10 milliseconds,
// to minimize screen updates when receiving large bursts of data.
//
// This module is decoupled from the processes that normally feed it data, so
// it's possible to use it as a general purpose console buffer (possibly as a
// log/display mechanism for nvim in the future)
//
// Inspired by: vimshell http://www.wana.at/vimshell
//              Conque https://code.google.com/p/conque
// Some code from pangoterm http://www.leonerd.org.uk/code/pangoterm

#include <assert.h>
#include <ghostty/vt.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/base64.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/context.h"
#include "nvim/cursor.h"
#include "nvim/cursor_shape.h"
#include "nvim/drawline.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/time.h"
#include "nvim/ex_docmd.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/input.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/msgpack_rpc/channel_defs.h"
#include "nvim/normal_defs.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/pos_defs.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

typedef struct {
  VimState state;
  Terminal *term;
  int save_rd;          ///< saved value of RedrawingDisabled
  bool close;
  bool got_bsl;         ///< if the last input was <C-\>
  bool got_bsl_o;       ///< if left terminal mode with <c-\><c-o>
  bool cursor_visible;  ///< cursor's current visibility; ensures matched busy_start/stop UI events

  // These fields remember the prior values of window options before entering terminal mode.
  // Valid only when save_curwin_handle != 0.
  handle_T save_curwin_handle;
  bool save_w_p_cul;
  char *save_w_p_culopt;
  uint8_t save_w_p_culopt_flags;
  int save_w_p_cuc;
  OptInt save_w_p_so;
  OptInt save_w_p_siso;
} TerminalState;

typedef struct {
  int16_t idx;
  int rgb;
  bool is_default;
} TerminalColorAttrs;

typedef enum {
  kTermRequestParserNormal = 0,
  kTermRequestParserEsc,
  kTermRequestParserOsc,
  kTermRequestParserDcs,
  kTermRequestParserApc,
  kTermRequestParserStringEsc,
} TermRequestParserState;

typedef enum {
  kTermRequestKindNone = 0,
  kTermRequestKindOsc,
  kTermRequestKindDcs,
  kTermRequestKindApc,
} TermRequestKind;

typedef enum {
  kTermRequestTerminatorBel = 0,
  kTermRequestTerminatorSt,
} TermRequestTerminator;

typedef enum {
  kTermRequestParserEventNone = 0,
  kTermRequestParserEventStart,
  kTermRequestParserEventFinish,
} TermRequestParserEvent;

typedef enum {
  kTerminalClipboardRegister = 0,
  kTerminalClipboardPrimary,
} TerminalClipboardRegister;

#include "terminal.c.generated.h"

// Delay for refreshing the terminal buffer after receiving updates. Improves
// performance when receiving large bursts of data.
#define REFRESH_DELAY 10

#define TEXTBUF_SIZE 0x1fff

// Whether to include OSC 52/clipboard support in Ghostty's DA1 response. Functional tests
// toggle this to force the runtime OSC 52 detection path to fall back to XTGETTCAP.
DLLEXPORT int terminal_ghostty_da_clipboard = 1;

static TimeWatcher refresh_timer;
static bool refresh_pending = false;

struct terminal {
  TerminalOptions opts;  // options passed to terminal_alloc()
  GhosttyTerminal ghostty;
  GhosttyRenderState ghostty_render_state;
  GhosttyRenderStateRowIterator ghostty_render_row_iterator;
  GhosttyKeyEncoder ghostty_key_encoder;
  GhosttyKeyEvent ghostty_key_event;
  GhosttyMouseEncoder ghostty_mouse_encoder;
  GhosttyMouseEvent ghostty_mouse_event;
  unsigned ghostty_mouse_buttons;
  struct {
    bool x10;
    bool normal;
    bool button;
    bool any;
    bool utf8;
    bool sgr;
    bool urxvt;
    bool sgr_pixels;
  } ghostty_mouse_modes;
  // Buffer used to fetch Ghostty rows.
  char textbuf[TEXTBUF_SIZE];

  size_t ghostty_scrollback_rows;  ///< Rows in Ghostty's full history.
  size_t scrollback_rows;          ///< Ghostty history rows mirrored in the nvim buffer.
  size_t scrollback_deleted;       ///< Mirrored history rows deleted from the buffer top.
  bool scrollback_clear_pending;   ///< Ghostty processed CSI 3 J since the last refresh.

  // buf_T instance that acts as a "drawing surface" for the terminal.
  // we can't store a direct reference to the buffer because the
  // refresh_timer_cb may be called after the buffer was freed, and there's
  // no way to know if the memory was reused.
  handle_T buf_handle;
  bool in_altscreen;
  // program suspended
  bool suspended;
  // program exited
  bool closed;
  // when true, the terminal's destruction is already enqueued.
  bool destroy;

  // some terminal properties
  int invalid_start, invalid_end;   // invalid rows in Ghostty screen
  struct {
    int row, col;
    GhosttyRenderStateCursorVisualStyle shape;
    bool visible;  ///< Terminal wants to show cursor.
                   ///< `TerminalState.cursor_visible` indicates whether it is actually shown.
    bool blink;
  } cursor;

  struct {
    bool resize;          ///< pending width/height
    bool cursor;          ///< pending cursor shape or blink change
    StringBuilder *send;  ///< When there is a pending TermRequest autocommand, block and store input.
    MultiQueue *events;   ///< Events waiting for refresh.
  } pending;

  bool streamed_paste;  ///< Streamed pasting
  bool theme_updates;  ///< Send a theme update notification when 'bg' changes
  bool synchronized_output;  ///< Mode 2026: suppress redraws until end of synchronized update
  bool sync_flush_pending;   ///< Set when mode 2026 ends; triggers immediate buffer refresh

  bool color_set[16];

  StringBuilder termrequest_buffer;  ///< Growable array containing unfinished request sequence
  TermRequestParserState termrequest_state;  ///< Current OSC/DCS/APC TermRequest parser state.
  TermRequestKind termrequest_kind;  ///< Current OSC/DCS/APC sequence kind.
  TermRequestTerminator termrequest_terminator;  ///< Terminator (BEL or ST) used in request.

  size_t refcount;                  // reference count
};

static Set(ptr_t) invalidated_terminals = SET_INIT;

static void emit_termrequest(void **argv)
{
  handle_T buf_handle = (handle_T)(intptr_t)argv[0];
  char *sequence = argv[1];
  size_t sequence_length = (size_t)argv[2];
  StringBuilder *pending_send = argv[3];
  int row = (int)(intptr_t)argv[4];
  int col = (int)(intptr_t)argv[5];
  size_t scrollback_deleted = (size_t)(intptr_t)argv[6];
  TermRequestTerminator terminator = (TermRequestTerminator)(intptr_t)argv[7];

  buf_T *buf = handle_get_buffer(buf_handle);
  if (!buf || buf->terminal == NULL) {  // Terminal already closed.
    xfree(sequence);
    kv_destroy(*pending_send);
    xfree(pending_send);
    return;
  }
  Terminal *term = buf->terminal;

  refresh_terminal(term);

  set_vim_var_string(VV_TERMREQUEST, sequence, (ptrdiff_t)sequence_length);

  MAXSIZE_TEMP_ARRAY(cursor, 2);
  ADD_C(cursor, INTEGER_OBJ(row - (int64_t)(term->scrollback_deleted - scrollback_deleted)));
  ADD_C(cursor, INTEGER_OBJ(col));

  MAXSIZE_TEMP_DICT(data, 3);
  String termrequest = { .data = sequence, .size = sequence_length };
  PUT_C(data, "sequence", STRING_OBJ(termrequest));
  PUT_C(data, "cursor", ARRAY_OBJ(cursor));
  PUT_C(data, "terminator",
        terminator ==
        kTermRequestTerminatorBel ? STATIC_CSTR_AS_OBJ("\x07") : STATIC_CSTR_AS_OBJ("\x1b\\"));

  term->refcount++;
  apply_autocmds_group(EVENT_TERMREQUEST, NULL, NULL, true, AUGROUP_ALL, buf, NULL,
                       &DICT_OBJ(data), false);
  term->refcount--;
  xfree(sequence);

  StringBuilder *term_pending_send = term->pending.send;
  term->pending.send = NULL;
  if (kv_size(*pending_send)) {
    terminal_send(term, pending_send->items, pending_send->size);
    kv_destroy(*pending_send);
  }
  if (term_pending_send != pending_send) {
    term->pending.send = term_pending_send;
  }
  xfree(pending_send);

  // Terminal buffer closed during TermRequest in Normal mode: destroy the terminal.
  // In Terminal mode term->refcount should still be non-zero here.
  if (term->buf_handle == 0 && !term->refcount) {
    term->destroy = true;
    term->opts.close_cb(term->opts.data);
  }
}

static void schedule_termrequest(Terminal *term)
{
  term->pending.send = xmalloc(sizeof(StringBuilder));
  kv_init(*term->pending.send);

  terminal_ghostty_cursor_position_update(term);
  int line = row_to_linenr(term, term->cursor.row);
  multiqueue_put(main_loop.events, emit_termrequest, (void *)(intptr_t)term->buf_handle,
                 xmemdup(term->termrequest_buffer.items, term->termrequest_buffer.size),
                 (void *)(intptr_t)term->termrequest_buffer.size, term->pending.send,
                 (void *)(intptr_t)line, (void *)(intptr_t)term->cursor.col,
                 (void *)(intptr_t)term->scrollback_deleted,
                 (void *)(intptr_t)term->termrequest_terminator);
}

static void terminal_termrequest_begin(Terminal *term, TermRequestKind kind)
  FUNC_ATTR_NONNULL_ALL
{
  term->termrequest_kind = kind;
  term->termrequest_state = kind == kTermRequestKindOsc
                            ? kTermRequestParserOsc
                            : kind == kTermRequestKindDcs
                            ? kTermRequestParserDcs
                            : kTermRequestParserApc;
  kv_size(term->termrequest_buffer) = 0;
  switch (kind) {
  case kTermRequestKindOsc:
    kv_concat_len(term->termrequest_buffer, "\x1b]", 2);
    break;
  case kTermRequestKindDcs:
    kv_concat_len(term->termrequest_buffer, "\x1bP", 2);
    break;
  case kTermRequestKindApc:
    kv_concat_len(term->termrequest_buffer, "\x1b_", 2);
    break;
  case kTermRequestKindNone:
    break;
  }
}

static void terminal_termrequest_finish(Terminal *term, TermRequestTerminator terminator)
  FUNC_ATTR_NONNULL_ALL
{
  term->termrequest_terminator = terminator;
  term->termrequest_state = kTermRequestParserNormal;
}

static TermRequestParserEvent terminal_termrequest_parse_byte(Terminal *term, uint8_t c)
  FUNC_ATTR_NONNULL_ALL
{
  switch (term->termrequest_state) {
  case kTermRequestParserNormal:
    switch (c) {
    case 0x90:
      terminal_termrequest_begin(term, kTermRequestKindDcs);
      return kTermRequestParserEventStart;
    case 0x9d:
      terminal_termrequest_begin(term, kTermRequestKindOsc);
      return kTermRequestParserEventStart;
    case 0x9f:
      terminal_termrequest_begin(term, kTermRequestKindApc);
      return kTermRequestParserEventStart;
    case ESC:
      term->termrequest_state = kTermRequestParserEsc;
      return kTermRequestParserEventNone;
    default:
      return kTermRequestParserEventNone;
    }

  case kTermRequestParserEsc:
    switch (c) {
    case ']':
      terminal_termrequest_begin(term, kTermRequestKindOsc);
      return kTermRequestParserEventStart;
    case 'P':
      terminal_termrequest_begin(term, kTermRequestKindDcs);
      return kTermRequestParserEventStart;
    case '_':
      terminal_termrequest_begin(term, kTermRequestKindApc);
      return kTermRequestParserEventStart;
    case ESC:
      return kTermRequestParserEventNone;
    default:
      term->termrequest_state = kTermRequestParserNormal;
      return kTermRequestParserEventNone;
    }

  case kTermRequestParserOsc:
  case kTermRequestParserDcs:
  case kTermRequestParserApc:
    if (c == 0x9c) {
      terminal_termrequest_finish(term, kTermRequestTerminatorSt);
      return kTermRequestParserEventFinish;
    }
    if (term->termrequest_kind == kTermRequestKindOsc && c == BELL) {
      terminal_termrequest_finish(term, kTermRequestTerminatorBel);
      return kTermRequestParserEventFinish;
    }
    if (c == ESC) {
      term->termrequest_state = kTermRequestParserStringEsc;
      return kTermRequestParserEventNone;
    }
    kv_push(term->termrequest_buffer, (char)c);
    return kTermRequestParserEventNone;

  case kTermRequestParserStringEsc:
    if (c == '\\') {
      terminal_termrequest_finish(term, kTermRequestTerminatorSt);
      return kTermRequestParserEventFinish;
    }
    kv_push(term->termrequest_buffer, ESC);
    if (c == 0x9c) {
      terminal_termrequest_finish(term, kTermRequestTerminatorSt);
      return kTermRequestParserEventFinish;
    }
    if (term->termrequest_kind == kTermRequestKindOsc && c == BELL) {
      terminal_termrequest_finish(term, kTermRequestTerminatorBel);
      return kTermRequestParserEventFinish;
    }
    kv_push(term->termrequest_buffer, (char)c);
    term->termrequest_state = term->termrequest_kind == kTermRequestKindOsc
                              ? kTermRequestParserOsc
                              : term->termrequest_kind == kTermRequestKindDcs
                              ? kTermRequestParserDcs
                              : kTermRequestParserApc;
    return kTermRequestParserEventNone;
  }
  return kTermRequestParserEventNone;
}

static TerminalClipboardRegister terminal_osc52_register(const char *selectors, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  if (len == 0) {
    return kTerminalClipboardRegister;
  }

  for (size_t i = 0; i < len; i++) {
    if (selectors[i] != 'p') {
      return kTerminalClipboardRegister;
    }
  }
  return kTerminalClipboardPrimary;
}

static void terminal_osc52_handle(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  if (term->termrequest_kind != kTermRequestKindOsc) {
    return;
  }

  const char *seq = term->termrequest_buffer.items;
  size_t len = term->termrequest_buffer.size;
  static const char prefix[] = "\033]52;";
  const size_t prefix_len = sizeof(prefix) - 1;
  if (len < prefix_len || memcmp(seq, prefix, prefix_len) != 0) {
    return;
  }

  const char *selectors = seq + prefix_len;
  size_t rest_len = len - prefix_len;
  const char *sep = memchr(selectors, ';', rest_len);
  if (sep == NULL) {
    return;
  }

  size_t selector_len = (size_t)(sep - selectors);
  const char *payload = sep + 1;
  size_t payload_len = rest_len - selector_len - 1;
  if (payload_len == 1 && payload[0] == '?') {
    return;
  }

  size_t decoded_len = 0;
  char *decoded = base64_decode(payload, payload_len, &decoded_len);
  if (decoded == NULL) {
    return;
  }

  char *data = xmemdupz(decoded, decoded_len);
  xfree(decoded);
  multiqueue_put(main_loop.events, term_clipboard_set,
                 (void *)(intptr_t)terminal_osc52_register(selectors, selector_len), data);
}

void terminal_init(void)
{
  time_watcher_init(&main_loop, &refresh_timer, NULL);
  // refresh_timer_cb will redraw the screen which can call vimscript
  refresh_timer.events = multiqueue_new_child(main_loop.events);
}

void terminal_teardown(void)
{
  time_watcher_stop(&refresh_timer);
  multiqueue_free(refresh_timer.events);
  time_watcher_close(&refresh_timer, NULL);
  set_destroy(ptr_t, &invalidated_terminals);
  // terminal_destroy might be called after terminal_teardown is invoked
  // make sure it is in an empty, valid state
  invalidated_terminals = (Set(ptr_t)) SET_INIT;
}

static void assert_ghostty_success(GhosttyResult res)
{
  assert(res == GHOSTTY_SUCCESS);
}

static bool terminal_ghostty_mode_get(Terminal *term, GhosttyMode mode)
  FUNC_ATTR_NONNULL_ALL
{
  bool enabled = false;
  assert_ghostty_success(ghostty_terminal_mode_get(term->ghostty, mode, &enabled));
  return enabled;
}

static bool terminal_mouse_tracking_enabled(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  bool enabled = false;
  assert_ghostty_success(ghostty_terminal_get(term->ghostty,
                                              GHOSTTY_TERMINAL_DATA_MOUSE_TRACKING,
                                              &enabled));
  return enabled;
}

static size_t terminal_scrollback_limit(buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  if (buf->b_p_scbk < 1) {
    buf->b_p_scbk = SB_MAX;
  }
  return (size_t)buf->b_p_scbk;
}

static void terminal_ghostty_size_get(Terminal *term, int *height, int *width)
  FUNC_ATTR_NONNULL_ARG(1)
{
  uint16_t rows = 0;
  uint16_t cols = 0;
  assert_ghostty_success(ghostty_terminal_get(term->ghostty, GHOSTTY_TERMINAL_DATA_ROWS, &rows));
  assert_ghostty_success(ghostty_terminal_get(term->ghostty, GHOSTTY_TERMINAL_DATA_COLS, &cols));
  if (height != NULL) {
    *height = (int)rows;
  }
  if (width != NULL) {
    *width = (int)cols;
  }
}

static void terminal_ghostty_cursor_position_update(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  uint16_t col = 0;
  uint16_t row = 0;
  assert_ghostty_success(ghostty_terminal_get(term->ghostty,
                                              GHOSTTY_TERMINAL_DATA_CURSOR_X,
                                              &col));
  assert_ghostty_success(ghostty_terminal_get(term->ghostty,
                                              GHOSTTY_TERMINAL_DATA_CURSOR_Y,
                                              &row));
  term->cursor.col = (int)col;
  term->cursor.row = (int)row;
}

static void terminal_ghostty_cursor_viewport_position_update(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  bool has_viewport_cursor = false;
  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_HAS_VALUE,
                                                  &has_viewport_cursor));
  if (!has_viewport_cursor) {
    terminal_ghostty_cursor_position_update(term);
    return;
  }

  uint16_t col = 0;
  uint16_t row = 0;
  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_X,
                                                  &col));
  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_Y,
                                                  &row));
  term->cursor.col = (int)col;
  term->cursor.row = (int)row;
}

static void terminal_ghostty_cursor_update(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  int old_row = term->cursor.row;
  int old_col = term->cursor.col;
  terminal_ghostty_cursor_viewport_position_update(term);
  bool position_changed = term->cursor.row != old_row || term->cursor.col != old_col;

  bool visible = false;
  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_CURSOR_VISIBLE,
                                                  &visible));

  bool blink = false;
  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_CURSOR_BLINKING,
                                                  &blink));

  GhosttyRenderStateCursorVisualStyle shape = GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BLOCK;
  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_CURSOR_VISUAL_STYLE,
                                                  &shape));

  bool visibility_changed = term->cursor.visible != visible;
  bool style_changed = term->cursor.blink != blink || term->cursor.shape != shape;
  term->cursor.visible = visible;
  term->cursor.blink = blink;
  term->cursor.shape = shape;

  if (style_changed) {
    term->pending.cursor = true;
  }
  if (position_changed || visibility_changed || style_changed) {
    invalidate_terminal(term, -1, -1);
  }
}

static void terminal_ghostty_termprops_update(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  bool synchronized_output = terminal_ghostty_mode_get(term, GHOSTTY_MODE_SYNC_OUTPUT);
  if (term->synchronized_output && !synchronized_output) {
    term->sync_flush_pending = true;
  }
  term->synchronized_output = synchronized_output;

  GhosttyTerminalScreen screen = GHOSTTY_TERMINAL_SCREEN_PRIMARY;
  assert_ghostty_success(ghostty_terminal_get(term->ghostty,
                                              GHOSTTY_TERMINAL_DATA_ACTIVE_SCREEN,
                                              &screen));
  bool in_altscreen = screen == GHOSTTY_TERMINAL_SCREEN_ALTERNATE;
  if (term->in_altscreen != in_altscreen) {
    int height;
    terminal_ghostty_size_get(term, &height, NULL);
    term->invalid_start = 0;
    term->invalid_end = height;
    invalidate_terminal(term, -1, -1);
  }
  term->in_altscreen = in_altscreen;

  term->theme_updates = terminal_ghostty_mode_get(term, GHOSTTY_MODE_COLOR_SCHEME_REPORT);
}

static int terminal_default_decsusr_cursor_style(void)
{
  int style = 1;
  bool blink = shape_table[SHAPE_IDX_TERM].blinkon != 0
               && shape_table[SHAPE_IDX_TERM].blinkoff != 0;

  switch (shape_table[SHAPE_IDX_TERM].shape) {
  case SHAPE_BLOCK:
    style = blink ? 1 : 2;
    break;
  case SHAPE_HOR:
    style = blink ? 3 : 4;
    break;
  case SHAPE_VER:
    style = blink ? 5 : 6;
    break;
  }
  return style;
}

static void terminal_ghostty_init_cursor_style(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  int style = terminal_default_decsusr_cursor_style();

  char buf[8];
  int len = snprintf(buf, sizeof(buf), "\x1b[%d q", style);
  assert(len > 0 && (size_t)len < sizeof(buf));
  ghostty_terminal_vt_write(term->ghostty, (const uint8_t *)buf, (size_t)len);
}

static size_t terminal_ghostty_scrollback_rows_get(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  size_t rows = 0;
  assert_ghostty_success(ghostty_terminal_get(term->ghostty,
                                              GHOSTTY_TERMINAL_DATA_SCROLLBACK_ROWS,
                                              &rows));
  return rows;
}

static bool terminal_input_clears_scrollback(const char *data, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  for (size_t i = 0; i < len; i++) {
    if ((uint8_t)data[i] == 0x9b && i + 2 < len && data[i + 1] == '3'
        && data[i + 2] == 'J') {
      return true;
    }
    if (data[i] != ESC || i + 1 >= len || data[i + 1] != '[') {
      continue;
    }
    if (i + 3 < len && data[i + 2] == '3' && data[i + 3] == 'J') {
      return true;
    }
  }
  return false;
}

static void terminal_mouse_encoder_set_size(Terminal *term, uint16_t width, uint16_t height)
  FUNC_ATTR_NONNULL_ALL
{
  GhosttyMouseEncoderSize size = {
    .size = sizeof(GhosttyMouseEncoderSize),
    .screen_width = MAX((uint32_t)width, 1U),
    .screen_height = MAX((uint32_t)height, 1U),
    .cell_width = 1,
    .cell_height = 1,
    .padding_top = 0,
    .padding_bottom = 0,
    .padding_right = 0,
    .padding_left = 0,
  };
  ghostty_mouse_encoder_setopt(term->ghostty_mouse_encoder, GHOSTTY_MOUSE_ENCODER_OPT_SIZE,
                               &size);
}

static void terminal_mouse_encoder_sync_config(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  bool x10 = terminal_ghostty_mode_get(term, GHOSTTY_MODE_X10_MOUSE);
  bool normal = terminal_ghostty_mode_get(term, GHOSTTY_MODE_NORMAL_MOUSE);
  bool button = terminal_ghostty_mode_get(term, GHOSTTY_MODE_BUTTON_MOUSE);
  bool any = terminal_ghostty_mode_get(term, GHOSTTY_MODE_ANY_MOUSE);
  bool utf8 = terminal_ghostty_mode_get(term, GHOSTTY_MODE_UTF8_MOUSE);
  bool sgr = terminal_ghostty_mode_get(term, GHOSTTY_MODE_SGR_MOUSE);
  bool urxvt = terminal_ghostty_mode_get(term, GHOSTTY_MODE_URXVT_MOUSE);
  bool sgr_pixels = terminal_ghostty_mode_get(term, GHOSTTY_MODE_SGR_PIXELS_MOUSE);

  if (x10 == term->ghostty_mouse_modes.x10
      && normal == term->ghostty_mouse_modes.normal
      && button == term->ghostty_mouse_modes.button
      && any == term->ghostty_mouse_modes.any
      && utf8 == term->ghostty_mouse_modes.utf8
      && sgr == term->ghostty_mouse_modes.sgr
      && urxvt == term->ghostty_mouse_modes.urxvt
      && sgr_pixels == term->ghostty_mouse_modes.sgr_pixels) {
    return;
  }

  term->ghostty_mouse_modes.x10 = x10;
  term->ghostty_mouse_modes.normal = normal;
  term->ghostty_mouse_modes.button = button;
  term->ghostty_mouse_modes.any = any;
  term->ghostty_mouse_modes.utf8 = utf8;
  term->ghostty_mouse_modes.sgr = sgr;
  term->ghostty_mouse_modes.urxvt = urxvt;
  term->ghostty_mouse_modes.sgr_pixels = sgr_pixels;

  // This resets motion deduplication, so call it only when mouse modes changed.
  ghostty_mouse_encoder_setopt_from_terminal(term->ghostty_mouse_encoder, term->ghostty);
}

static unsigned terminal_mouse_button_number(GhosttyMouseButton button)
{
  static const unsigned button_numbers[] = {
    [GHOSTTY_MOUSE_BUTTON_LEFT] = 1,
    [GHOSTTY_MOUSE_BUTTON_RIGHT] = 3,
    [GHOSTTY_MOUSE_BUTTON_MIDDLE] = 2,
    [GHOSTTY_MOUSE_BUTTON_FOUR] = 4,
    [GHOSTTY_MOUSE_BUTTON_FIVE] = 5,
    [GHOSTTY_MOUSE_BUTTON_SIX] = 6,
    [GHOSTTY_MOUSE_BUTTON_SEVEN] = 7,
    [GHOSTTY_MOUSE_BUTTON_EIGHT] = 8,
    [GHOSTTY_MOUSE_BUTTON_NINE] = 9,
    [GHOSTTY_MOUSE_BUTTON_TEN] = 10,
    [GHOSTTY_MOUSE_BUTTON_ELEVEN] = 11,
  };
  unsigned index = (unsigned)button;
  return index < ARRAY_SIZE(button_numbers) ? button_numbers[index] : 0;
}

static GhosttyMouseButton terminal_mouse_button_from_number(unsigned button)
{
  static const GhosttyMouseButton buttons[] = {
    GHOSTTY_MOUSE_BUTTON_UNKNOWN,
    GHOSTTY_MOUSE_BUTTON_LEFT,
    GHOSTTY_MOUSE_BUTTON_MIDDLE,
    GHOSTTY_MOUSE_BUTTON_RIGHT,
    GHOSTTY_MOUSE_BUTTON_FOUR,
    GHOSTTY_MOUSE_BUTTON_FIVE,
    GHOSTTY_MOUSE_BUTTON_SIX,
    GHOSTTY_MOUSE_BUTTON_SEVEN,
    GHOSTTY_MOUSE_BUTTON_EIGHT,
    GHOSTTY_MOUSE_BUTTON_NINE,
    GHOSTTY_MOUSE_BUTTON_TEN,
    GHOSTTY_MOUSE_BUTTON_ELEVEN,
  };
  return button < ARRAY_SIZE(buttons) ? buttons[button] : GHOSTTY_MOUSE_BUTTON_UNKNOWN;
}

static bool terminal_mouse_button_is_stateful(GhosttyMouseButton button)
{
  unsigned number = terminal_mouse_button_number(button);
  return (number >= 1 && number <= 3) || (number >= 8 && number <= 11);
}

static bool terminal_mouse_get_pressed_button(Terminal *term, GhosttyMouseButton *button)
  FUNC_ATTR_NONNULL_ALL
{
  for (unsigned number = 1; number <= 11; number++) {
    if (term->ghostty_mouse_buttons & (1U << (number - 1))) {
      *button = terminal_mouse_button_from_number(number);
      return *button != GHOSTTY_MOUSE_BUTTON_UNKNOWN;
    }
  }
  return false;
}

// public API {{{

/// Allocates a terminal instance and initializes terminal properties.
///
/// The PTY process (TerminalOptions.data) was already started by jobstart(),
/// via ex_terminal() or the term:// BufReadCmd.
///
/// @param buf Buffer used for presentation of the terminal.
/// @param opts PTY process channel, various terminal properties and callbacks.
///
/// @return the terminal instance.
Terminal *terminal_alloc(buf_T *buf, TerminalOptions opts)
  FUNC_ATTR_NONNULL_ALL
{
  // Create a new terminal instance and configure it
  Terminal *term = xcalloc(1, sizeof(Terminal));
  term->opts = opts;

  // Associate the terminal instance with the new buffer
  term->buf_handle = buf->handle;
  buf->terminal = term;
  // Create Ghostty
  uint16_t ghostty_cols = MAX(opts.width, 1);
  uint16_t ghostty_rows = MAX(opts.height, 1);
  // Ghostty's public C API documents max_scrollback as a line count, but the
  // current implementation treats it as a byte limit. Convert Nvim's row limit
  // to a conservative byte budget until Ghostty accepts rows here.
  const size_t ghostty_row_size = (size_t)ghostty_cols * 64;
  size_t ghostty_max_scrollback = SB_MAX > SIZE_MAX / ghostty_row_size
                                  ? SIZE_MAX : SB_MAX * ghostty_row_size;
  GhosttyTerminalOptions ghostty_opts = {
    .cols = ghostty_cols,
    .rows = ghostty_rows,
    .max_scrollback = ghostty_max_scrollback,
  };
  assert_ghostty_success(ghostty_terminal_new(NULL, &term->ghostty, ghostty_opts));
  assert_ghostty_success(ghostty_terminal_mode_set(term->ghostty,
                                                   GHOSTTY_MODE_GRAPHEME_CLUSTER,
                                                   true));
  terminal_update_colors(term);
  assert_ghostty_success(ghostty_render_state_new(NULL, &term->ghostty_render_state));
  assert_ghostty_success(ghostty_render_state_row_iterator_new(NULL,
                                                               &term->ghostty_render_row_iterator));
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_USERDATA, term));

  // ghostty_terminal_set() takes option values as const void *, including
  // callback options. ISO C does not allow converting function pointers to
  // object pointers, so we briefly disable pedantic warnings.
#if defined(__GNUC__)
# pragma GCC diagnostic push
# pragma GCC diagnostic ignored "-Wpedantic"
#endif
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_WRITE_PTY,
                                              (const void *)term_ghostty_write_pty_callback));
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_BELL,
                                              (const void *)term_ghostty_bell_callback));
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_TITLE_CHANGED,
                                              (const void *)term_ghostty_title_changed_callback));
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_COLOR_SCHEME,
                                              (const void *)term_ghostty_color_scheme_callback));
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_DEVICE_ATTRIBUTES,
                                              (const void *)term_ghostty_device_attributes_callback));
#if defined(__GNUC__)
# pragma GCC diagnostic pop
#endif

  assert_ghostty_success(ghostty_key_encoder_new(NULL, &term->ghostty_key_encoder));
  assert_ghostty_success(ghostty_key_event_new(NULL, &term->ghostty_key_event));
  assert_ghostty_success(ghostty_mouse_encoder_new(NULL, &term->ghostty_mouse_encoder));
  assert_ghostty_success(ghostty_mouse_event_new(NULL, &term->ghostty_mouse_event));
  terminal_mouse_encoder_set_size(term, ghostty_cols, ghostty_rows);
  bool track_last_cell = true;
  ghostty_mouse_encoder_setopt(term->ghostty_mouse_encoder,
                               GHOSTTY_MOUSE_ENCODER_OPT_TRACK_LAST_CELL,
                               &track_last_cell);
  terminal_ghostty_init_cursor_style(term);
  terminal_ghostty_render_state_update(term);

  // Force an initial refresh so the buffer starts with one line per screen row.
  term->invalid_start = 0;
  term->invalid_end = opts.height;

  // Create a separate queue for events which need to wait for a terminal
  // refresh. We cannot reschedule events back onto the main queue because this
  // can create an infinite loop (#32753).
  // This queue is never processed directly: when the terminal is refreshed, all
  // events from this queue are copied back onto the main event queue.
  term->pending.events = multiqueue_new(NULL, NULL);

  if (!(buf->b_ml.ml_flags & ML_EMPTY)) {
    linenr_T line_count = buf->b_ml.ml_line_count;
    while (!(buf->b_ml.ml_flags & ML_EMPTY)) {
      ml_delete_buf(buf, 1, false);
    }
    deleted_lines_buf(buf, 1, line_count);
  }
  return term;
}

/// Triggers TermOpen.
///
/// @param termpp  Pointer to the terminal channel's `term` field.
/// @param buf     Buffer used for presentation of the terminal.
void terminal_open(Terminal **termpp, buf_T *buf)
  FUNC_ATTR_NONNULL_ALL
{
  Terminal *term = *termpp;
  assert(term != NULL);

  CtxSwitch aco = { 0 };
  ctx_switch(&aco, NULL, NULL, buf, 0);

  assert(term->invalid_start >= 0);
  refresh_screen(term, buf);
  buf->b_locked++;
  set_option_value(kOptBuftype, STATIC_CSTR_AS_OPTVAL("terminal"), OPT_LOCAL);
  buf->b_locked--;

  if (buf->b_ffname != NULL) {
    buf_set_term_title(buf, buf->b_ffname, strlen(buf->b_ffname));
  }
  RESET_BINDING(curwin);
  // Reset cursor in current window.
  curwin->w_cursor = (pos_T){ .lnum = 1, .col = 0, .coladd = 0 };

  apply_autocmds(EVENT_TERMOPEN, NULL, NULL, false, buf);

  ctx_restore(&aco);

  if (*termpp == NULL || term->buf_handle == 0) {
    return;  // Terminal has already been destroyed.
  }

  (void)terminal_scrollback_limit(buf);

  GhosttyColorRgb palette[256];
  assert_ghostty_success(ghostty_terminal_get(term->ghostty,
                                              GHOSTTY_TERMINAL_DATA_COLOR_PALETTE_DEFAULT,
                                              palette));

  // Configure the color palette. Try to get the color from:
  //
  // - b:terminal_color_{NUM}
  // - g:terminal_color_{NUM}
  for (int i = 0; i < 16; i++) {
    char var[64];
    snprintf(var, sizeof(var), "terminal_color_%d", i);
    char *name = get_config_string(buf, var);
    if (!name) {
      continue;
    }
    int dummy;
    RgbValue color_val = name_to_color(name, &dummy);
    if (color_val == -1) {
      continue;
    }
    palette[i] = (GhosttyColorRgb){
      .r = (uint8_t)((color_val >> 16) & 0xFF),
      .g = (uint8_t)((color_val >> 8) & 0xFF),
      .b = (uint8_t)((color_val >> 0) & 0xFF),
    };
    term->color_set[i] = true;
  }

  assert_ghostty_success(ghostty_terminal_set(term->ghostty,
                                              GHOSTTY_TERMINAL_OPT_COLOR_PALETTE,
                                              palette));

  terminal_update_colors(term);
}

/// Closes the Terminal buffer.
///
/// May call terminal_destroy, which sets caller storage to NULL.
void terminal_close(Terminal **termpp, int status)
  FUNC_ATTR_NONNULL_ALL
{
  Terminal *term = *termpp;

#ifdef EXITFREE
  if (entered_free_all_mem) {
    // If called from buf_close_terminal() inside free_all_mem(), the main loop has
    // already been freed, so it is not safe to call the close callback here.
    terminal_destroy(termpp);
    return;
  }
#endif

  if (term->destroy) {  // Destruction already scheduled on the main loop.
    return;
  }

  bool only_destroy = false;

  buf_T *buf = handle_get_buffer(term->buf_handle);

  if (term->closed) {
    // If called from buf_close_terminal() after the process has already exited, we
    // only need to call the close callback to clean up the terminal object.
    only_destroy = true;
  } else {
    // flush any pending changes to the buffer
    if (!exiting) {
      block_autocmds();
      refresh_terminal(term);
      unblock_autocmds();
    }
    term->closed = true;
  }

  int pos = buf ? buf->b_ml.ml_line_count - 1 : 0;
  if (status == -1 || exiting) {
    // If this was called by buf_close_terminal() (status is -1), or if exiting, we
    // must inform the buffer the terminal no longer exists so that buf_freeall()
    // won't call buf_close_terminal() again.
    // If inside Terminal mode event handling, setting buf_handle to 0 also
    // informs terminal_enter() to call the close callback before returning.
    term->buf_handle = 0;
    if (buf) {
      buf->terminal = NULL;
    }
    if (!term->refcount) {
      // Not inside Terminal mode event handling.
      // We should not wait for the user to press a key.
      term->destroy = true;
      term->opts.close_cb(term->opts.data);
    }
  } else if (!only_destroy) {
    // Associated channel has been closed and the editor is not exiting.
    // Do not call the close callback now. Wait for the user to press a key.
    // Redraw statusline to show the exit code.
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == buf) {
        wp->w_redr_status = true;
      }
    }

    // Gets the line number to display "[Process exited]" virt text
    pos = MIN(row_to_linenr(term, term->cursor.row), pos);
  }

  if (only_destroy) {
    return;
  }

  if (buf && !is_autocmd_blocked()) {
    save_v_event_T save_v_event;
    dict_T *dict = get_v_event(&save_v_event);
    tv_dict_add_nr(dict, S_LEN("status"), status);
    tv_dict_set_keys_readonly(dict);

    MAXSIZE_TEMP_DICT(data, 1);
    PUT_C(data, "pos", INTEGER_OBJ(pos));

    apply_autocmds_group(EVENT_TERMCLOSE, NULL, NULL, status >= 0, AUGROUP_ALL,
                         buf, NULL, &DICT_OBJ(data), false);

    restore_v_event(dict, &save_v_event);
  }
}

static void terminal_state_change_event(void **argv)
{
  handle_T buf_handle = (handle_T)(intptr_t)argv[0];
  buf_T *buf = handle_get_buffer(buf_handle);
  if (buf && buf->terminal) {
    // Don't change the actual terminal content to indicate the suspended state here,
    // as unlike the process exit case the change needs to be reversed on resume.
    // Instead, the code in win_update() will add a "[Process suspended]" virtual text
    // at the botton-left of the buffer.
    redraw_buf_line_later(buf, buf->b_ml.ml_line_count, false);
  }
}

/// Updates the suspended state of the terminal program.
void terminal_set_state(Terminal *term, bool suspended)
  FUNC_ATTR_NONNULL_ALL
{
  if (term->suspended != suspended) {
    // Trigger a main loop iteration to redraw the buffer.
    multiqueue_put(refresh_timer.events, terminal_state_change_event,
                   (void *)(intptr_t)term->buf_handle);
  }
  term->suspended = suspended;
}

void terminal_check_size(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  if (term->closed) {
    return;
  }

  int curwidth, curheight;
  terminal_ghostty_size_get(term, &curheight, &curwidth);
  uint16_t width = 0;
  uint16_t height = 0;

  // Check if there is a window that displays the terminal and find the maximum width and height.
  // Skip the autocommand window which isn't actually displayed.
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (is_ctx_win(wp)) {
      continue;
    }
    if (wp->w_buffer && wp->w_buffer->terminal == term) {
      const uint16_t win_width =
        (uint16_t)(MAX(0, wp->w_view_width - win_col_off(wp)));
      width = MAX(width, win_width);
      height = (uint16_t)MAX(height, wp->w_view_height);
    }
  }

  // if no window displays the terminal, or such all windows are zero-height,
  // don't resize the terminal.
  if ((curheight == height && curwidth == width) || height == 0 || width == 0) {
    return;
  }

  term->opts.resize_cb(width, height, term->opts.data);
  assert_ghostty_success(ghostty_terminal_resize(term->ghostty, width, height, 0, 0));
  terminal_ghostty_render_state_update(term);
  terminal_mouse_encoder_set_size(term, width, height);
  term->pending.resize = true;
  invalidate_terminal(term, -1, -1);
}

static void set_terminal_winopts(TerminalState *const s)
  FUNC_ATTR_NONNULL_ALL
{
  assert(s->save_curwin_handle == 0);

  // Disable these options in terminal-mode. They are nonsense because cursor is
  // placed at end of buffer to "follow" output. #11072
  s->save_curwin_handle = curwin->handle;
  s->save_w_p_cul = curwin->w_p_cul;
  s->save_w_p_culopt = NULL;
  s->save_w_p_culopt_flags = curwin->w_p_culopt_flags;
  s->save_w_p_cuc = curwin->w_p_cuc;
  s->save_w_p_so = curwin->w_p_so;
  s->save_w_p_siso = curwin->w_p_siso;

  if (curwin->w_p_cul && curwin->w_p_culopt_flags & kOptCuloptFlagNumber) {
    if (!strequal(curwin->w_p_culopt, "number")) {
      s->save_w_p_culopt = curwin->w_p_culopt;
      curwin->w_p_culopt = xstrdup("number");
    }
    curwin->w_p_culopt_flags = kOptCuloptFlagNumber;
  } else {
    curwin->w_p_cul = false;
  }
  curwin->w_p_cuc = false;
  curwin->w_p_so = 0;
  curwin->w_p_siso = 0;

  if (curwin->w_p_cuc != s->save_w_p_cuc) {
    redraw_later(curwin, UPD_SOME_VALID);
  } else if (curwin->w_p_cul != s->save_w_p_cul
             || (curwin->w_p_cul && curwin->w_p_culopt_flags != s->save_w_p_culopt_flags)) {
    redraw_later(curwin, UPD_VALID);
  }
}

static void unset_terminal_winopts(TerminalState *const s)
  FUNC_ATTR_NONNULL_ALL
{
  assert(s->save_curwin_handle != 0);

  win_T *const wp = handle_get_window(s->save_curwin_handle);
  if (!wp) {
    goto end;
  }

  winopt_T *winopts = NULL;
  if (wp->w_buffer->handle != s->term->buf_handle) {  // Buffer no longer in "wp".
    buf_T *buf = handle_get_buffer(s->term->buf_handle);
    if (buf == NULL) {
      goto end;  // Nothing to restore as the buffer was deleted.
    }
    for (size_t i = 0; i < kv_size(buf->b_wininfo); i++) {
      WinInfo *wip = kv_A(buf->b_wininfo, i);
      if (wip->wi_win == wp && wip->wi_optset) {
        winopts = &wip->wi_opt;
        break;
      }
    }
    if (winopts == NULL) {
      goto end;  // Nothing to restore as there is no matching WinInfo.
    }
  } else {
    winopts = &wp->w_onebuf_opt;
    if (win_valid(wp)) {  // No need to redraw if window not in curtab.
      if (s->save_w_p_cuc != wp->w_p_cuc) {
        redraw_later(wp, UPD_SOME_VALID);
      } else if (s->save_w_p_cul != wp->w_p_cul
                 || (s->save_w_p_cul && s->save_w_p_culopt_flags != wp->w_p_culopt_flags)) {
        redraw_later(wp, UPD_VALID);
      }
    }
    wp->w_p_culopt_flags = s->save_w_p_culopt_flags;
  }

  if (s->save_w_p_culopt) {
    free_string_option(winopts->wo_culopt);
    winopts->wo_culopt = s->save_w_p_culopt;
    s->save_w_p_culopt = NULL;
  }
  winopts->wo_cul = s->save_w_p_cul;
  winopts->wo_cuc = s->save_w_p_cuc;
  winopts->wo_so = s->save_w_p_so;
  winopts->wo_siso = s->save_w_p_siso;

end:
  free_string_option(s->save_w_p_culopt);
  s->save_curwin_handle = 0;
}

/// Implements MODE_TERMINAL state. :help Terminal-mode
bool terminal_enter(void)
{
  buf_T *buf = curbuf;
  assert(buf->terminal);  // Should only be called when curbuf has a terminal.
  TerminalState s[1] = { 0 };
  s->term = buf->terminal;
  s->cursor_visible = true;  // Assume visible; may change via refresh_cursor later.
  Ins.stop_insert_mode = false;

  // Ensure the terminal is properly sized. Ideally window size management
  // code should always have resized the terminal already, but check here to
  // be sure.
  terminal_check_size(s->term);

  int save_state = State;
  s->save_rd = RedrawingDisabled;
  State = MODE_TERMINAL;
  mapped_ctrl_c |= MODE_TERMINAL;  // Always map CTRL-C to avoid interrupt.
  RedrawingDisabled = false;

  set_terminal_winopts(s);

  s->term->pending.cursor = true;  // Update the cursor shape table
  adjust_topline_cursor(s->term, buf, 0);  // scroll to end
  showmode();
  ui_cursor_shape();

  // Tell the terminal it has focus
  terminal_focus(s->term, true);
  // Don't fire TextChangedT from changes in Normal mode.
  curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);

  // Don't let autocommands free the terminal now!
  s->term->refcount++;
  apply_autocmds(EVENT_TERMENTER, NULL, NULL, false, curbuf);
  may_trigger_modechanged();
  s->term->refcount--;
  if (s->term->buf_handle == 0) {
    s->close = true;
  }

  s->state.execute = terminal_execute;
  s->state.check = terminal_check;
  state_enter(&s->state);

  if (!s->got_bsl_o) {
    restart_edit = 0;
  }
  State = save_state;
  RedrawingDisabled = s->save_rd;
  if (!s->cursor_visible) {
    // If cursor was hidden, show it again. Do so right after restoring State.
    ui_busy_stop();
  }

  // Restore the terminal cursor to what is set in 'guicursor'
  (void)parse_shape_opt(SHAPE_CURSOR);

  unset_terminal_winopts(s);

  // Tell the terminal it lost focus
  terminal_focus(s->term, false);
  // Don't fire TextChanged from changes in terminal mode.
  curbuf->b_last_changedtick = buf_get_changedtick(curbuf);

  if (curbuf->terminal == s->term && !s->close) {
    terminal_check_cursor();
  }
  if (restart_edit) {
    showmode();
  } else {
    unshowmode(true);
  }
  ui_cursor_shape();

  // If we're to close the terminal, don't let TermLeave autocommands free it first!
  if (s->close) {
    s->term->refcount++;
  }
  apply_autocmds(EVENT_TERMLEAVE, NULL, NULL, false, curbuf);
  if (s->close) {
    s->term->refcount--;
    const handle_T buf_handle = s->term->buf_handle;  // Callback may free s->term.
    s->term->destroy = true;
    s->term->opts.close_cb(s->term->opts.data);
    if (buf_handle != 0) {
      do_buffer(DOBUF_WIPE, DOBUF_FIRST, FORWARD, buf_handle, true);
    }
  }

  return s->got_bsl_o;
}

static void terminal_check_cursor(void)
{
  Terminal *term = curbuf->terminal;
  curwin->w_cursor.lnum = MIN(curbuf->b_ml.ml_line_count,
                              row_to_linenr(term, term->cursor.row));
  const linenr_T topline = MAX(curbuf->b_ml.ml_line_count - curwin->w_view_height + 1, 1);
  // Don't update topline if unchanged to avoid unnecessary redraws.
  if (topline != curwin->w_topline) {
    set_topline(curwin, topline);
  }
  if (term->suspended && (State & MODE_TERMINAL)) {
    // Put cursor at the "[Process suspended]" text to hint that pressing a key will
    // change the suspended state.
    curwin->w_cursor = (pos_T){ .lnum = curbuf->b_ml.ml_line_count };
  } else {
    // Nudge cursor when returning to normal-mode.
    int off = (State & MODE_TERMINAL) ? 0 : (curwin->w_p_rl ? 1 : -1);
    coladvance(curwin, MAX(0, term->cursor.col + off));
  }
}

static bool terminal_check_focus(TerminalState *const s)
  FUNC_ATTR_NONNULL_ALL
{
  if (curbuf->terminal == NULL) {
    return false;
  }

  if (s->save_curwin_handle != curwin->handle) {
    // Terminal window changed, update window options.
    unset_terminal_winopts(s);
    set_terminal_winopts(s);
  }
  if (s->term != curbuf->terminal) {
    // Active terminal changed, flush terminal's cursor state to the UI.
    terminal_focus(s->term, false);
    if (s->close) {
      s->term->destroy = true;
      s->term->opts.close_cb(s->term->opts.data);
      s->close = false;
    }

    s->term = curbuf->terminal;
    s->term->pending.cursor = true;
    invalidate_terminal(s->term, -1, -1);
    terminal_focus(s->term, true);
  }
  return true;
}

/// Function executed before each iteration of terminal mode.
///
/// @return:
///           1 if the iteration should continue normally
///           0 if the main loop must exit
static int terminal_check(VimState *state)
{
  TerminalState *const s = (TerminalState *)state;

  // Shouldn't reach here when pressing a key to close the terminal buffer.
  assert(!s->close || (s->term->buf_handle == 0 && s->term != curbuf->terminal));

  if (Ins.stop_insert_mode || !terminal_check_focus(s)) {
    return 0;
  }

  terminal_check_refresh();

  // Validate topline and cursor position for autocommands. Especially important for WinScrolled.
  terminal_check_cursor();
  validate_cursor(curwin);

  // Don't let autocommands free the terminal from under our fingers.
  s->term->refcount++;
  if (has_event(EVENT_TEXTCHANGEDT)
      && curbuf->b_last_changedtick_i != buf_get_changedtick(curbuf)) {
    apply_autocmds(EVENT_TEXTCHANGEDT, NULL, NULL, false, curbuf);
    curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);
  }
  may_trigger_win_scrolled_resized();
  s->term->refcount--;
  if (s->term->buf_handle == 0) {
    s->close = true;
  }

  // Autocommands above may have changed focus, scrolled, or moved the cursor.
  if (!terminal_check_focus(s)) {
    return 0;
  }
  terminal_check_cursor();
  validate_cursor(curwin);

  show_cursor_info_later(false);
  if (must_redraw) {
    update_screen();
  } else {
    redraw_statuslines();
    if (clear_cmdline || redraw_cmdline || redraw_mode) {
      showmode();  // clear cmdline and show mode
    }
  }

  setcursor();
  refresh_cursor(s->term, &s->cursor_visible);
  ui_flush();
  return 1;
}

/// Processes one char of terminal-mode input.
static int terminal_execute(VimState *state, int key)
{
  TerminalState *s = (TerminalState *)state;

  // Check for certain control keys like Ctrl-C and Ctrl-\. We still send the
  // unmerged key and modifiers to the terminal.
  const int key_modifiers = mod_mask;
  int tmp_mod_mask = mod_mask;
  int mod_key = merge_modifiers(key, &tmp_mod_mask);

  switch (mod_key) {
  case K_LEFTMOUSE:
  case K_LEFTDRAG:
  case K_LEFTRELEASE:
  case K_MIDDLEMOUSE:
  case K_MIDDLEDRAG:
  case K_MIDDLERELEASE:
  case K_RIGHTMOUSE:
  case K_RIGHTDRAG:
  case K_RIGHTRELEASE:
  case K_X1MOUSE:
  case K_X1DRAG:
  case K_X1RELEASE:
  case K_X2MOUSE:
  case K_X2DRAG:
  case K_X2RELEASE:
  case K_MOUSEDOWN:
  case K_MOUSEUP:
  case K_MOUSELEFT:
  case K_MOUSERIGHT:
  case K_MOUSEMOVE:
    if (send_mouse_event(s->term, mod_key, tmp_mod_mask)) {
      return 0;
    }
    break;

  case K_PASTE_START:
    paste_repeat(1);
    break;

  case K_EVENT:
    // We cannot let an event free the terminal yet. It is still needed.
    s->term->refcount++;
    state_handle_k_event();
    s->term->refcount--;
    if (s->term->buf_handle == 0) {
      s->close = true;
    }
    break;

  case K_COMMAND:
    do_cmdline(NULL, getcmdkeycmd, NULL, 0);
    break;

  case K_LUA:
    map_execute_lua(false, false);
    break;

  case K_IGNORE:
  case K_NOP:
    // Do not interrupt a Ctrl-\ sequence or close a finished terminal.
    break;

  case Ctrl_N:
    if (s->got_bsl) {
      return 0;
    }
    FALLTHROUGH;

  case Ctrl_O:
    if (s->got_bsl) {
      s->got_bsl_o = true;
      restart_edit = 'I';
      return 0;
    }
    FALLTHROUGH;

  default:
    if (mod_key == Ctrl_C) {
      // terminal_enter() always sets `mapped_ctrl_c` to avoid `got_int`. 8eeda7169aa4
      // But `got_int` may be set elsewhere, e.g. by interrupt() or an autocommand,
      // so ensure that it is cleared.
      got_int = false;
    }
    if (mod_key == Ctrl_BSL && !s->got_bsl) {
      s->got_bsl = true;
      break;
    }
    if (s->term->suspended) {
      s->term->opts.resume_cb(s->term->opts.data);
      // XXX: detecting continued process via waitpid() on SIGCHLD doesn't always work
      // (e.g. on macOS), so also consider it continued after sending SIGCONT.
      terminal_set_state(s->term, false);
      break;
    }
    if (s->term->closed) {
      s->close = true;
      return 0;
    }

    s->got_bsl = false;
    terminal_send_key(s->term, key, key_modifiers);
  }

  return 1;
}

/// Frees the given Terminal structure and sets the caller storage to NULL (in the spirit of
/// XFREE_CLEAR).
void terminal_destroy(Terminal **termpp)
  FUNC_ATTR_NONNULL_ALL
{
  Terminal *term = *termpp;
  buf_T *buf = handle_get_buffer(term->buf_handle);
  if (buf) {
    term->buf_handle = 0;
    buf->terminal = NULL;
  }

  if (!term->refcount) {
    if (set_has(ptr_t, &invalidated_terminals, term)) {
      // flush any pending changes to the buffer
      block_autocmds();
      refresh_terminal(term);
      unblock_autocmds();
      set_del(ptr_t, &invalidated_terminals, term);
    }
    kv_destroy(term->termrequest_buffer);
    multiqueue_free(term->pending.events);
    ghostty_mouse_event_free(term->ghostty_mouse_event);
    ghostty_mouse_encoder_free(term->ghostty_mouse_encoder);
    ghostty_key_event_free(term->ghostty_key_event);
    ghostty_key_encoder_free(term->ghostty_key_encoder);
    ghostty_render_state_row_iterator_free(term->ghostty_render_row_iterator);
    ghostty_render_state_free(term->ghostty_render_state);
    ghostty_terminal_free(term->ghostty);
    xfree(term);
    *termpp = NULL;  // coverity[dead-store]
  }
}

static void terminal_send(Terminal *term, const char *data, size_t size)
{
  if (term->closed) {
    return;
  }
  if (term->pending.send) {
    kv_concat_len(*term->pending.send, data, size);
    return;
  }
  term->opts.write_cb(data, size, term->opts.data);
}

static bool is_filter_char(int c)
{
  unsigned flag = 0;
  switch (c) {
  case 0x08:
    flag = kOptTpfFlagBS;
    break;
  case 0x09:
    flag = kOptTpfFlagHT;
    break;
  case 0x0A:
  case 0x0D:
    break;
  case 0x0C:
    flag = kOptTpfFlagFF;
    break;
  case 0x1b:
    flag = kOptTpfFlagESC;
    break;
  case 0x7F:
    flag = kOptTpfFlagDEL;
    break;
  default:
    if (c < ' ') {
      flag = kOptTpfFlagC0;
    } else if (c >= 0x80 && c <= 0x9F) {
      flag = kOptTpfFlagC1;
    }
  }
  return !!(tpf_flags & flag);
}

static void terminal_send_bracketed_paste(Terminal *term, bool start)
  FUNC_ATTR_NONNULL_ALL
{
  bool bracketed_paste = false;
  assert_ghostty_success(ghostty_terminal_mode_get(term->ghostty,
                                                   GHOSTTY_MODE_BRACKETED_PASTE,
                                                   &bracketed_paste));
  if (bracketed_paste) {
    terminal_send(term, start ? "\x1b[200~" : "\x1b[201~", 6);
  }
}

void terminal_set_streamed_paste(Terminal *term, bool streamed)
  FUNC_ATTR_NONNULL_ALL
{
  if (term->streamed_paste != streamed) {
    terminal_send_bracketed_paste(term, streamed);
  }
  term->streamed_paste = streamed;
}

void terminal_paste(int count, String *y_array, size_t y_size)
{
  if (y_size == 0) {
    return;
  }
  if (!curbuf->terminal->streamed_paste) {
    terminal_send_bracketed_paste(curbuf->terminal, true);
  }
  size_t buff_len = y_array[0].size;
  char *buff = xmalloc(buff_len);
  for (int i = 0; i < count; i++) {
    // feed the lines to the terminal
    for (size_t j = 0; j < y_size; j++) {
      if (j) {
        // terminate the previous line
#ifdef MSWIN
        terminal_send(curbuf->terminal, "\r\n", 2);
#else
        terminal_send(curbuf->terminal, "\n", 1);
#endif
      }
      size_t len = y_array[j].size;
      if (len > buff_len) {
        buff = xrealloc(buff, len);
        buff_len = len;
      }
      char *dst = buff;
      char *src = y_array[j].data;
      while (*src != NUL) {
        len = (size_t)utf_ptr2len(src);
        int c = utf_ptr2char(src);
        if (!is_filter_char(c)) {
          memcpy(dst, src, len);
          dst += len;
        }
        src += len;
      }
      terminal_send(curbuf->terminal, buff, (size_t)(dst - buff));
    }
  }
  xfree(buff);
  if (!curbuf->terminal->streamed_paste) {
    terminal_send_bracketed_paste(curbuf->terminal, false);
  }
}

static void terminal_key_encoder_sync_config(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  ghostty_key_encoder_setopt_from_terminal(term->ghostty_key_encoder, term->ghostty);

  // MOD_MASK_ALT is already terminal Alt, so always encode option as Alt.
  GhosttyOptionAsAlt option_as_alt = GHOSTTY_OPTION_AS_ALT_TRUE;
  ghostty_key_encoder_setopt(term->ghostty_key_encoder,
                             GHOSTTY_KEY_ENCODER_OPT_MACOS_OPTION_AS_ALT,
                             &option_as_alt);
}

/// Returns a known unshifted codepoint for a key event.
///
/// @param utf8 Produced UTF-8 text for the key event.
/// @param utf8_len Length of `utf8` in bytes.
/// @return Unshifted codepoint, or 0 if unknown.
static uint32_t terminal_key_known_unshifted_codepoint(const char *utf8, size_t utf8_len)
{
  if (utf8_len != 1) {
    return 0;
  }

  uint8_t c = (uint8_t)utf8[0];
  if (c >= 'A' && c <= 'Z') {
    return (uint32_t)(c + ('a' - 'A'));
  }
  if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '[' || c == ']'
      || c == '\\' || c == '/') {
    return c;
  }
  return 0;
}

/// Returns the UTF-8 text produced by a keypad keycode.
///
/// @param c Neovim keycode for a keypad key.
/// @param len Set to the returned text length in bytes, or 0 if `c` is not handled.
/// @return Static UTF-8 text for the keypad key, or NULL if `c` is not handled.
static const char *terminal_keypad_generated_utf8(int c, size_t *len)
  FUNC_ATTR_NONNULL_ALL
{
  *len = 1;
  switch (c) {
  case K_K0:
    FALLTHROUGH;
  case K_KINS:
    return "0";
  case K_K1:
    FALLTHROUGH;
  case K_KEND:
    return "1";
  case K_K2:
    FALLTHROUGH;
  case K_KDOWN:
    return "2";
  case K_K3:
    FALLTHROUGH;
  case K_KPAGEDOWN:
    return "3";
  case K_K4:
    FALLTHROUGH;
  case K_KLEFT:
    return "4";
  case K_K5:
    FALLTHROUGH;
  case K_KORIGIN:
    return "5";
  case K_K6:
    FALLTHROUGH;
  case K_KRIGHT:
    return "6";
  case K_K7:
    FALLTHROUGH;
  case K_KHOME:
    return "7";
  case K_K8:
    FALLTHROUGH;
  case K_KUP:
    return "8";
  case K_K9:
    FALLTHROUGH;
  case K_KPAGEUP:
    return "9";
  case K_KDEL:
    FALLTHROUGH;
  case K_KPOINT:
    return ".";
  case K_KPLUS:
    return "+";
  case K_KMINUS:
    return "-";
  case K_KMULTIPLY:
    return "*";
  case K_KDIVIDE:
    return "/";
  case K_KCOMMA:
    return ",";
  case K_KEQUAL:
    return "=";
  default:
    *len = 0;
    return NULL;
  }
}

static void terminal_key_encode_event(Terminal *term, GhosttyKey key, GhosttyMods mods,
                                      const char *utf8, size_t utf8_len)
  FUNC_ATTR_NONNULL_ARG(1)
{
  terminal_key_encoder_sync_config(term);

  ghostty_key_event_set_action(term->ghostty_key_event, GHOSTTY_KEY_ACTION_PRESS);
  ghostty_key_event_set_key(term->ghostty_key_event, key);
  ghostty_key_event_set_mods(term->ghostty_key_event, mods);
  ghostty_key_event_set_utf8(term->ghostty_key_event, utf8, utf8_len);
  uint32_t unshifted_codepoint = terminal_key_known_unshifted_codepoint(utf8, utf8_len);
  ghostty_key_event_set_unshifted_codepoint(term->ghostty_key_event, unshifted_codepoint);

  // Try encoding to a stack-allocated buffer first.
  char buf[128];
  size_t len = 0;
  GhosttyResult res = ghostty_key_encoder_encode(term->ghostty_key_encoder,
                                                 term->ghostty_key_event,
                                                 buf,
                                                 sizeof(buf),
                                                 &len);

  // If that was too small, allocate on the heap.
  if (res == GHOSTTY_OUT_OF_SPACE) {
    char *big_buf = xmalloc(len);
    assert_ghostty_success(ghostty_key_encoder_encode(term->ghostty_key_encoder,
                                                      term->ghostty_key_event,
                                                      big_buf,
                                                      len,
                                                      &len));
    terminal_send(term, big_buf, len);
    xfree(big_buf);
    return;
  }

  assert_ghostty_success(res);
  if (len > 0) {
    terminal_send(term, buf, len);
  }
}

static void terminal_send_key(Terminal *term, int c, int modifiers)
{
  // Convert K_ZERO back to ASCII
  if (c == K_ZERO) {
    c = Ctrl_AT;
  }

  GhosttyMods mods = convert_key_modifiers(c, modifiers);
  if ((mods & GHOSTTY_MODS_CTRL) && !(mods & GHOSTTY_MODS_SHIFT) && c >= 'A' && c <= 'Z') {
    c += ('a' - 'A');
  }

  GhosttyKey key = convert_key(c);
  if (key != GHOSTTY_KEY_UNIDENTIFIED) {
    size_t utf8_len = 0;
    const char *utf8 = terminal_keypad_generated_utf8(c, &utf8_len);
    terminal_key_encode_event(term, key, mods, utf8, utf8_len);
    return;
  }

  if (IS_SPECIAL(c)) {
    return;
  }

  if (c < 0x20 || c == DEL) {
    char ctrl = (char)c;
    terminal_send(term, &ctrl, 1);
    return;
  }

  char utf8[MB_MAXBYTES];
  int utf8_len = utf_char2bytes(c, utf8);
  terminal_key_encode_event(term, GHOSTTY_KEY_UNIDENTIFIED, mods, utf8, (size_t)utf8_len);
}

/// Callback scheduled on the main loop when a synchronized update ends.
/// Refreshes a single terminal with full-screen damage.
static void on_sync_flush(void **argv)
{
  if (exiting) {
    return;
  }
  handle_T buf_handle = (handle_T)(intptr_t)argv[0];
  buf_T *buf = handle_get_buffer(buf_handle);
  if (!buf || !buf->terminal) {
    return;
  }
  block_autocmds();
  refresh_terminal(buf->terminal);
  unblock_autocmds();
}

static void terminal_vt_write(Terminal *term, const char *data, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  size_t chunk_start = 0;
  for (size_t i = 0; i < len; i++) {
    TermRequestParserEvent event = terminal_termrequest_parse_byte(term, (uint8_t)data[i]);
    if (event == kTermRequestParserEventStart) {
      size_t request_start = i;
      if (i > 0 && data[i - 1] == ESC
          && ((uint8_t)data[i] == ']' || (uint8_t)data[i] == 'P' || (uint8_t)data[i] == '_')) {
        request_start--;
      }
      ghostty_terminal_vt_write(term->ghostty, (const uint8_t *)(data + chunk_start),
                                request_start - chunk_start);
      chunk_start = request_start;
    } else if (event == kTermRequestParserEventFinish) {
      ghostty_terminal_vt_write(term->ghostty, (const uint8_t *)(data + chunk_start),
                                i + 1 - chunk_start);
      terminal_osc52_handle(term);
      if (has_event(EVENT_TERMREQUEST)) {
        schedule_termrequest(term);
      }
      term->termrequest_state = kTermRequestParserNormal;
      term->termrequest_kind = kTermRequestKindNone;
      kv_size(term->termrequest_buffer) = 0;
      chunk_start = i + 1;
    }
  }
  ghostty_terminal_vt_write(term->ghostty, (const uint8_t *)(data + chunk_start),
                            len - chunk_start);
  terminal_ghostty_render_state_update(term);
}

void terminal_receive(Terminal *term, const char *data, size_t len)
{
  if (!data || len == 0) {
    return;
  }

  if (term->opts.force_crlf) {
    StringBuilder crlf_data = KV_INITIAL_VALUE;

    for (size_t i = 0; i < len; i++) {
      if (data[i] == '\n' && (i == 0 || (i > 0 && data[i - 1] != '\r'))) {
        kv_push(crlf_data, '\r');
      }
      kv_push(crlf_data, data[i]);
    }

    if (terminal_input_clears_scrollback(crlf_data.items, kv_size(crlf_data))) {
      term->scrollback_clear_pending = true;
    }
    terminal_vt_write(term, crlf_data.items, kv_size(crlf_data));
    kv_destroy(crlf_data);
  } else {
    if (terminal_input_clears_scrollback(data, len)) {
      term->scrollback_clear_pending = true;
    }
    terminal_vt_write(term, data, len);
  }

  // When a synchronized update just ended, refresh the buffer immediately
  // instead of waiting for the 10ms timer.  This eliminates the window where
  // neovim's UI could repaint showing stale buffer content.
  if (term->sync_flush_pending) {
    term->sync_flush_pending = false;
    // Schedule a full-screen refresh for this terminal on the main loop.
    // Force full-screen damage so every row is updated, not just
    // the rows with accumulated damage from individual callbacks.
    int height;
    terminal_ghostty_size_get(term, &height, NULL);
    term->invalid_start = 0;
    term->invalid_end = height;
    multiqueue_put(main_loop.events, on_sync_flush,
                   (void *)(intptr_t)term->buf_handle);
  }
}

static bool terminal_ghostty_grid_ref(Terminal *term, GhosttyPointTag tag, uint32_t row, int col,
                                      GhosttyGridRef *ref)
  FUNC_ATTR_NONNULL_ALL
{
  if (col < 0 || col > UINT16_MAX) {
    return false;
  }

  *ref = GHOSTTY_INIT_SIZED(GhosttyGridRef);
  GhosttyPoint point = {
    .tag = tag,
    .value = {
      .coordinate = {
        .x = (uint16_t)col,
        .y = row,
      },
    },
  };

  GhosttyResult result = ghostty_terminal_grid_ref(term->ghostty, point, ref);
  if (result == GHOSTTY_INVALID_VALUE || result == GHOSTTY_NO_VALUE) {
    return false;
  }
  assert_ghostty_success(result);
  return true;
}

static int terminal_ghostty_underline_hl_flag(int underline)
{
  switch (underline) {
  case GHOSTTY_SGR_UNDERLINE_NONE:
    return 0;
  case GHOSTTY_SGR_UNDERLINE_SINGLE:
    return HL_UNDERLINE;
  case GHOSTTY_SGR_UNDERLINE_DOUBLE:
    return HL_UNDERDOUBLE;
  case GHOSTTY_SGR_UNDERLINE_CURLY:
    return HL_UNDERCURL;
  case GHOSTTY_SGR_UNDERLINE_DOTTED:
    return HL_UNDERDOTTED;
  case GHOSTTY_SGR_UNDERLINE_DASHED:
    return HL_UNDERDASHED;
  default:
    return HL_UNDERLINE;
  }
}

static int terminal_ghostty_rgb(GhosttyColorRgb color)
{
  return RGB_(color.r, color.g, color.b);
}

/// Converts an RGB value to Ghostty's RGB representation.
static GhosttyColorRgb rgb_value_to_ghostty_color(RgbValue color)
{
  return (GhosttyColorRgb) {
    .r = (uint8_t)((color >> 16) & 0xff),
    .g = (uint8_t)((color >> 8) & 0xff),
    .b = (uint8_t)(color & 0xff),
  };
}

static int terminal_cell_hl_attr(Terminal *term, int hl_attrs, int16_t fg_idx, int16_t bg_idx,
                                 int fg, int bg, int sp, bool fg_default, bool bg_default,
                                 int url_attr)
  FUNC_ATTR_NONNULL_ALL
{
  bool fg_indexed = fg_idx != 0;
  bool bg_indexed = bg_idx != 0;
  bool fg_set = fg_idx && fg_idx <= 16 && term->color_set[fg_idx - 1];
  bool bg_set = bg_idx && bg_idx <= 16 && term->color_set[bg_idx - 1];

  hl_attrs |= ((fg_indexed && !fg_set) ? HL_FG_INDEXED : 0)
              | ((bg_indexed && !bg_set) ? HL_BG_INDEXED : 0);

  int attr_id = 0;
  if (hl_attrs || !fg_default || !bg_default) {
    attr_id = hl_get_term_attr(&(HlAttrs) {
      .cterm_ae_attr = (int32_t)hl_attrs,
      .cterm_fg_color = fg_idx,
      .cterm_bg_color = bg_idx,
      .rgb_ae_attr = (int32_t)hl_attrs,
      .rgb_fg_color = fg,
      .rgb_bg_color = bg,
      .rgb_sp_color = sp,
      .hl_blend = -1,
      .url = -1,
    });
  }

  return url_attr > 0 ? hl_combine_attr(attr_id, url_attr) : attr_id;
}

static int16_t terminal_ghostty_style_color_index(GhosttyStyleColor color)
{
  if (color.tag != GHOSTTY_STYLE_COLOR_PALETTE) {
    return 0;
  }
  return (int16_t)(color.value.palette + 1);
}

static int terminal_ghostty_style_color_rgb(const GhosttyColorRgb palette[256],
                                            GhosttyStyleColor color)
{
  switch (color.tag) {
  case GHOSTTY_STYLE_COLOR_NONE:
    return -1;
  case GHOSTTY_STYLE_COLOR_PALETTE:
    return terminal_ghostty_rgb(palette[color.value.palette]);
  case GHOSTTY_STYLE_COLOR_RGB:
    return terminal_ghostty_rgb(color.value.rgb);
  default:
    return -1;
  }
}

static TerminalColorAttrs terminal_ghostty_style_color_attrs(const GhosttyColorRgb palette[256],
                                                             GhosttyStyleColor color)
  FUNC_ATTR_NONNULL_ALL
{
  return (TerminalColorAttrs) {
    .idx = terminal_ghostty_style_color_index(color),
    .rgb = terminal_ghostty_style_color_rgb(palette, color),
    .is_default = color.tag == GHOSTTY_STYLE_COLOR_NONE,
  };
}

static TerminalColorAttrs terminal_ghostty_cell_bg_attrs(GhosttyCell cell, GhosttyStyleColor color,
                                                         const GhosttyColorRgb palette[256])
  FUNC_ATTR_NONNULL_ALL
{
  TerminalColorAttrs attrs = terminal_ghostty_style_color_attrs(palette, color);
  if (color.tag != GHOSTTY_STYLE_COLOR_NONE) {
    return attrs;
  }

  GhosttyCellContentTag content_tag = GHOSTTY_CELL_CONTENT_CODEPOINT;
  assert_ghostty_success(ghostty_cell_get(cell, GHOSTTY_CELL_DATA_CONTENT_TAG, &content_tag));
  if (content_tag == GHOSTTY_CELL_CONTENT_BG_COLOR_PALETTE) {
    GhosttyColorPaletteIndex palette_index = 0;
    assert_ghostty_success(ghostty_cell_get(cell, GHOSTTY_CELL_DATA_COLOR_PALETTE,
                                            &palette_index));
    return (TerminalColorAttrs) {
      .idx = (int16_t)(palette_index + 1),
      .rgb = terminal_ghostty_rgb(palette[palette_index]),
      .is_default = false,
    };
  }

  if (content_tag == GHOSTTY_CELL_CONTENT_BG_COLOR_RGB) {
    GhosttyColorRgb bg = { 0 };
    assert_ghostty_success(ghostty_cell_get(cell, GHOSTTY_CELL_DATA_COLOR_RGB, &bg));
    attrs.rgb = terminal_ghostty_rgb(bg);
    attrs.is_default = false;
  }
  return attrs;
}

static int terminal_ghostty_cell_url_attr(const GhosttyGridRef *ref)
  FUNC_ATTR_NONNULL_ALL
{
  size_t uri_len = 0;
  GhosttyResult result = ghostty_grid_ref_hyperlink_uri(ref, NULL, 0, &uri_len);
  if (result == GHOSTTY_SUCCESS && uri_len == 0) {
    return 0;
  }
  if (result != GHOSTTY_OUT_OF_SPACE) {
    assert_ghostty_success(result);
  }

  char *uri = xmalloc(uri_len + 1);
  result = ghostty_grid_ref_hyperlink_uri(ref, (uint8_t *)uri, uri_len, &uri_len);
  assert_ghostty_success(result);
  uri[uri_len] = NUL;
  int attr = hl_add_url(0, uri);
  xfree(uri);
  return attr;
}

static int terminal_ghostty_cell_attr(Terminal *term, GhosttyPointTag tag, uint32_t row, int col,
                                      const GhosttyColorRgb palette[256])
  FUNC_ATTR_NONNULL_ALL
{
  GhosttyGridRef ref = { 0 };
  if (!terminal_ghostty_grid_ref(term, tag, row, col, &ref)) {
    return 0;
  }

  GhosttyCell cell = 0;
  assert_ghostty_success(ghostty_grid_ref_cell(&ref, &cell));

  GhosttyStyle style = GHOSTTY_INIT_SIZED(GhosttyStyle);
  assert_ghostty_success(ghostty_grid_ref_style(&ref, &style));

  TerminalColorAttrs fg = terminal_ghostty_style_color_attrs(palette, style.fg_color);
  TerminalColorAttrs bg = terminal_ghostty_cell_bg_attrs(cell, style.bg_color, palette);
  int underline = terminal_ghostty_underline_hl_flag(style.underline);
  int sp = underline ? terminal_ghostty_style_color_rgb(palette, style.underline_color) : -1;

  int hl_attrs = (style.bold ? HL_BOLD : 0)
                 | (style.faint ? HL_DIM : 0)
                 | (style.blink ? HL_BLINK : 0)
                 | (style.invisible ? HL_CONCEALED : 0)
                 | (style.overline ? HL_OVERLINE : 0)
                 | (style.italic ? HL_ITALIC : 0)
                 | (style.inverse ? HL_INVERSE : 0)
                 | underline
                 | (style.strikethrough ? HL_STRIKETHROUGH : 0);

  int url_attr = terminal_ghostty_cell_url_attr(&ref);
  return terminal_cell_hl_attr(term, hl_attrs, fg.idx, bg.idx, fg.rgb, bg.rgb, sp,
                               fg.is_default, bg.is_default, url_attr);
}

void terminal_get_line_attributes(Terminal *term, win_T *wp, int linenr, int *term_attrs)
{
  (void)wp;
  int height, width;
  terminal_ghostty_size_get(term, &height, &width);
  assert(linenr);
  if (linenr < 1) {
    return;
  }

  size_t screen_row = (size_t)(linenr - 1);
  if (screen_row >= term->scrollback_rows + (size_t)height) {
    // Terminal height was decreased but the change wasn't reflected into the
    // buffer yet
    return;
  }

  width = MIN(TERM_ATTRS_MAX, width);
  GhosttyRenderStateColors colors = GHOSTTY_INIT_SIZED(GhosttyRenderStateColors);
  assert_ghostty_success(ghostty_render_state_colors_get(term->ghostty_render_state, &colors));
  GhosttyPointTag tag = GHOSTTY_POINT_TAG_ACTIVE;
  uint32_t row = 0;
  if (screen_row < term->scrollback_rows) {
    tag = GHOSTTY_POINT_TAG_SCREEN;
    size_t offset = term->ghostty_scrollback_rows - term->scrollback_rows;
    row = (uint32_t)(offset + screen_row);
  } else {
    row = (uint32_t)(screen_row - term->scrollback_rows);
  }

  for (int col = 0; col < width; col++) {
    int attr_id = terminal_ghostty_cell_attr(term, tag, row, col, colors.palette);
    term_attrs[col] = attr_id;
  }
}

Buffer terminal_buf(const Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  return term->buf_handle;
}

bool terminal_running(const Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  return !term->closed;
}

bool terminal_suspended(const Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  return term->suspended;
}

void terminal_notify_theme(Terminal *term, bool dark)
  FUNC_ATTR_NONNULL_ALL
{
  if (!term->theme_updates) {
    return;
  }

  char buf[10];
  ssize_t ret = snprintf(buf, sizeof(buf), "\x1b[997;%cn", dark ? '1' : '2');
  assert(ret > 0);
  assert((size_t)ret <= sizeof(buf));
  terminal_send(term, buf, (size_t)ret);
}

/// Updates the terminal's default foreground, background, and cursor colors.
void terminal_update_colors(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  bool dark = (*p_bg == 'd');

  // Set the foreground color.
  RgbValue fg = (p_tgc && normal_fg >= 0) ? normal_fg : (dark ? 0xffffff : 0x000000);
  GhosttyColorRgb fg_ghostty = rgb_value_to_ghostty_color(fg);
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_COLOR_FOREGROUND,
                                              &fg_ghostty));

  // Set the background color.
  RgbValue bg = (p_tgc && normal_bg >= 0) ? normal_bg : (dark ? 0x000000 : 0xffffff);
  GhosttyColorRgb bg_ghostty = rgb_value_to_ghostty_color(bg);
  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_COLOR_BACKGROUND,
                                              &bg_ghostty));

  // Set the cursor color.
  if (*p_guicursor != NUL && shape_table[SHAPE_IDX_TERM].id != 0) {
    HlAttrs attrs = syn_attr2entry(syn_id2attr(shape_table[SHAPE_IDX_TERM].id));
    if (attrs.hl_blend != 100 && !(attrs.rgb_ae_attr & HL_INVERSE) && attrs.rgb_bg_color >= 0) {
      GhosttyColorRgb cursor_ghostty = rgb_value_to_ghostty_color(attrs.rgb_bg_color);
      assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_COLOR_CURSOR,
                                                  &cursor_ghostty));
      return;
    }
  }

  assert_ghostty_success(ghostty_terminal_set(term->ghostty, GHOSTTY_TERMINAL_OPT_COLOR_CURSOR,
                                              NULL));
}

/// Updates the default colors for every open terminal buffer.
void terminal_update_colors_all(void)
{
  FOR_ALL_BUFFERS(buf) {
    if (buf->terminal) {
      terminal_update_colors(buf->terminal);
    }
  }
}

static void terminal_focus(Terminal *term, bool focus)
  FUNC_ATTR_NONNULL_ALL
{
  bool report_focus = false;

  assert_ghostty_success(ghostty_terminal_mode_get(term->ghostty,
                                                   GHOSTTY_MODE_FOCUS_EVENT,
                                                   &report_focus));

  // Return early if focus reporting is not enabled.
  if (!report_focus) {
    return;
  }

  enum { FOCUS_BUF_SIZE = 3, };
  char buf[FOCUS_BUF_SIZE];
  size_t len = 0;
  assert_ghostty_success(ghostty_focus_encode(focus ? GHOSTTY_FOCUS_GAINED : GHOSTTY_FOCUS_LOST,
                                              buf,
                                              FOCUS_BUF_SIZE,
                                              &len));

  terminal_send(term, buf, len);
}

// }}}
// libghostty callbacks {{{

/// Called when Ghostty needs to write the response for a terminal query.
static void term_ghostty_write_pty_callback(GhosttyTerminal ghostty FUNC_ATTR_UNUSED,
                                            void *user_data, const uint8_t *data, size_t len)
{
  Terminal *term = (Terminal *)user_data;
  terminal_send(term, (const char *)data, len);
}

/// Called when the terminal program wants to set the title.
static void term_ghostty_title_changed_callback(GhosttyTerminal ghostty, void *user_data)
{
  Terminal *term = (Terminal *)user_data;
  GhosttyString title = { 0 };
  assert_ghostty_success(ghostty_terminal_get(ghostty, GHOSTTY_TERMINAL_DATA_TITLE, &title));

  buf_T *buf = handle_get_buffer(term->buf_handle);
  buf_set_term_title(buf, title.ptr == NULL ? "" : (const char *)title.ptr, title.len);
}

/// Called when the terminal program wants to ring the system bell.
static void term_ghostty_bell_callback(GhosttyTerminal ghostty FUNC_ATTR_UNUSED,
                                       void *user_data FUNC_ATTR_UNUSED)
{
  vim_beep(kOptBoFlagTerm);
}

/// Called when the terminal program wants to know the terminal device attributes.
static bool term_ghostty_device_attributes_callback(GhosttyTerminal ghostty, void *user_data,
                                                    GhosttyDeviceAttributes *out_attrs)
{
  (void)ghostty;
  (void)user_data;

  GhosttyDeviceAttributes attrs = {
    .primary = {
      .conformance_level = GHOSTTY_DA_CONFORMANCE_VT220,
      .features = { GHOSTTY_DA_FEATURE_ANSI_COLOR },
      .num_features = 1,
    },
    .secondary = {
      .device_type = GHOSTTY_DA_DEVICE_TYPE_VT220,
      .firmware_version = 10,
      .rom_cartridge = 0,
    },
    .tertiary = {
      .unit_id = 0,
    },
  };
  if (terminal_ghostty_da_clipboard) {
    attrs.primary.features[attrs.primary.num_features++] = GHOSTTY_DA_FEATURE_CLIPBOARD;
  }
  *out_attrs = attrs;
  return true;
}

static void buf_set_term_title(buf_T *buf, const char *title, size_t len)
{
  if (!buf) {
    return;  // In case of receiving OSC 2 between buffer close and job exit.
  }

  Error err = ERROR_INIT;
  buf->b_locked++;
  dict_set_var(buf->b_vars,
               STATIC_CSTR_AS_STRING("term_title"),
               STRING_OBJ(((String){ .data = (char *)title, .size = len })),
               false,
               false,
               NULL,
               &err);
  buf->b_locked--;
  api_clear_error(&err);
  status_redraw_buf(buf);
}

/// Called when the terminal program wants to query the system theme.
static bool term_ghostty_color_scheme_callback(GhosttyTerminal ghostty FUNC_ATTR_UNUSED,
                                               void *user_data FUNC_ATTR_UNUSED,
                                               GhosttyColorScheme *out_scheme)
{
  *out_scheme = (*p_bg == 'd') ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT;
  return true;
}

static void term_clipboard_set(void **argv)
{
  TerminalClipboardRegister reg = (TerminalClipboardRegister)(intptr_t)argv[0];
  char *data = argv[1];

  char regname;
  switch (reg) {
  case kTerminalClipboardRegister:
    regname = '+';
    break;
  case kTerminalClipboardPrimary:
    regname = '*';
    break;
  }

  list_T *lines = tv_list_alloc(1);
  tv_list_append_allocated_string(lines, data);

  list_T *args = tv_list_alloc(3);
  tv_list_append_list(args, lines);

  const char regtype = 'v';
  tv_list_append_string(args, &regtype, 1);

  tv_list_append_string(args, &regname, 1);
  eval_call_provider("clipboard", "set", args, true);
}

// }}}
// input handling {{{

static GhosttyMods convert_mouse_modifiers(int modifiers)
{
  GhosttyMods mods = 0;
  if (modifiers & MOD_MASK_SHIFT) {
    mods |= GHOSTTY_MODS_SHIFT;
  }
  if (modifiers & MOD_MASK_CTRL) {
    mods |= GHOSTTY_MODS_CTRL;
  }
  if (modifiers & MOD_MASK_ALT) {
    mods |= GHOSTTY_MODS_ALT;
  }
  if (modifiers & MOD_MASK_CMD) {
    mods |= GHOSTTY_MODS_SUPER;
  }
  return mods;
}

static GhosttyMods convert_key_modifiers(int key, int modifiers)
{
  GhosttyMods mods = convert_mouse_modifiers(modifiers);

  switch (key) {
  case K_S_TAB:
  case K_S_UP:
  case K_S_DOWN:
  case K_S_LEFT:
  case K_S_RIGHT:
  case K_S_HOME:
  case K_S_END:
  case K_S_F1:
  case K_S_F2:
  case K_S_F3:
  case K_S_F4:
  case K_S_F5:
  case K_S_F6:
  case K_S_F7:
  case K_S_F8:
  case K_S_F9:
  case K_S_F10:
  case K_S_F11:
  case K_S_F12:
    mods |= GHOSTTY_MODS_SHIFT;
    break;

  case K_C_LEFT:
  case K_C_RIGHT:
  case K_C_HOME:
  case K_C_END:
    mods |= GHOSTTY_MODS_CTRL;
    break;
  }

  return mods;
}

static GhosttyKey convert_key(int key)
{
  switch (key) {
  case K_BS:
    return GHOSTTY_KEY_BACKSPACE;
  case K_S_TAB:
    FALLTHROUGH;
  case TAB:
    return GHOSTTY_KEY_TAB;
  case Ctrl_M:
    return GHOSTTY_KEY_ENTER;
  case ESC:
    return GHOSTTY_KEY_ESCAPE;

  case K_S_UP:
    FALLTHROUGH;
  case K_UP:
    return GHOSTTY_KEY_ARROW_UP;
  case K_S_DOWN:
    FALLTHROUGH;
  case K_DOWN:
    return GHOSTTY_KEY_ARROW_DOWN;
  case K_S_LEFT:
    FALLTHROUGH;
  case K_C_LEFT:
    FALLTHROUGH;
  case K_LEFT:
    return GHOSTTY_KEY_ARROW_LEFT;
  case K_S_RIGHT:
    FALLTHROUGH;
  case K_C_RIGHT:
    FALLTHROUGH;
  case K_RIGHT:
    return GHOSTTY_KEY_ARROW_RIGHT;

  case K_INS:
    return GHOSTTY_KEY_INSERT;
  case K_DEL:
    return GHOSTTY_KEY_DELETE;
  case K_S_HOME:
    FALLTHROUGH;
  case K_C_HOME:
    FALLTHROUGH;
  case K_HOME:
    return GHOSTTY_KEY_HOME;
  case K_S_END:
    FALLTHROUGH;
  case K_C_END:
    FALLTHROUGH;
  case K_END:
    return GHOSTTY_KEY_END;
  case K_PAGEUP:
    return GHOSTTY_KEY_PAGE_UP;
  case K_PAGEDOWN:
    return GHOSTTY_KEY_PAGE_DOWN;

  case K_K0:
    FALLTHROUGH;
  case K_KINS:
    return GHOSTTY_KEY_NUMPAD_0;
  case K_K1:
    FALLTHROUGH;
  case K_KEND:
    return GHOSTTY_KEY_NUMPAD_1;
  case K_K2:
    FALLTHROUGH;
  case K_KDOWN:
    return GHOSTTY_KEY_NUMPAD_2;
  case K_K3:
    FALLTHROUGH;
  case K_KPAGEDOWN:
    return GHOSTTY_KEY_NUMPAD_3;
  case K_K4:
    FALLTHROUGH;
  case K_KLEFT:
    return GHOSTTY_KEY_NUMPAD_4;
  case K_K5:
    FALLTHROUGH;
  case K_KORIGIN:
    return GHOSTTY_KEY_NUMPAD_5;
  case K_K6:
    FALLTHROUGH;
  case K_KRIGHT:
    return GHOSTTY_KEY_NUMPAD_6;
  case K_K7:
    FALLTHROUGH;
  case K_KHOME:
    return GHOSTTY_KEY_NUMPAD_7;
  case K_K8:
    FALLTHROUGH;
  case K_KUP:
    return GHOSTTY_KEY_NUMPAD_8;
  case K_K9:
    FALLTHROUGH;
  case K_KPAGEUP:
    return GHOSTTY_KEY_NUMPAD_9;
  case K_KDEL:
    FALLTHROUGH;
  case K_KPOINT:
    return GHOSTTY_KEY_NUMPAD_DECIMAL;
  case K_KENTER:
    return GHOSTTY_KEY_NUMPAD_ENTER;
  case K_KPLUS:
    return GHOSTTY_KEY_NUMPAD_ADD;
  case K_KMINUS:
    return GHOSTTY_KEY_NUMPAD_SUBTRACT;
  case K_KMULTIPLY:
    return GHOSTTY_KEY_NUMPAD_MULTIPLY;
  case K_KDIVIDE:
    return GHOSTTY_KEY_NUMPAD_DIVIDE;
  case K_KCOMMA:
    return GHOSTTY_KEY_NUMPAD_COMMA;
  case K_KEQUAL:
    return GHOSTTY_KEY_NUMPAD_EQUAL;

  case K_S_F1:
    FALLTHROUGH;
  case K_F1:
    return GHOSTTY_KEY_F1;
  case K_S_F2:
    FALLTHROUGH;
  case K_F2:
    return GHOSTTY_KEY_F2;
  case K_S_F3:
    FALLTHROUGH;
  case K_F3:
    return GHOSTTY_KEY_F3;
  case K_S_F4:
    FALLTHROUGH;
  case K_F4:
    return GHOSTTY_KEY_F4;
  case K_S_F5:
    FALLTHROUGH;
  case K_F5:
    return GHOSTTY_KEY_F5;
  case K_S_F6:
    FALLTHROUGH;
  case K_F6:
    return GHOSTTY_KEY_F6;
  case K_S_F7:
    FALLTHROUGH;
  case K_F7:
    return GHOSTTY_KEY_F7;
  case K_S_F8:
    FALLTHROUGH;
  case K_F8:
    return GHOSTTY_KEY_F8;
  case K_S_F9:
    FALLTHROUGH;
  case K_F9:
    return GHOSTTY_KEY_F9;
  case K_S_F10:
    FALLTHROUGH;
  case K_F10:
    return GHOSTTY_KEY_F10;
  case K_S_F11:
    FALLTHROUGH;
  case K_F11:
    return GHOSTTY_KEY_F11;
  case K_S_F12:
    FALLTHROUGH;
  case K_F12:
    return GHOSTTY_KEY_F12;
  case K_F13:
    return GHOSTTY_KEY_F13;
  case K_F14:
    return GHOSTTY_KEY_F14;
  case K_F15:
    return GHOSTTY_KEY_F15;
  case K_F16:
    return GHOSTTY_KEY_F16;
  case K_F17:
    return GHOSTTY_KEY_F17;
  case K_F18:
    return GHOSTTY_KEY_F18;
  case K_F19:
    return GHOSTTY_KEY_F19;
  case K_F20:
    return GHOSTTY_KEY_F20;
  case K_F21:
    return GHOSTTY_KEY_F21;
  case K_F22:
    return GHOSTTY_KEY_F22;
  case K_F23:
    return GHOSTTY_KEY_F23;
  case K_F24:
    return GHOSTTY_KEY_F24;
  case K_F25:
    return GHOSTTY_KEY_F25;

  default:
    return GHOSTTY_KEY_UNIDENTIFIED;
  }
}

static void terminal_mouse_encode_event(Terminal *term, GhosttyMouseAction action, bool has_button,
                                        GhosttyMouseButton button, int row, int col,
                                        GhosttyMods mods, bool any_button_pressed)
  FUNC_ATTR_NONNULL_ALL
{
  ghostty_mouse_encoder_setopt(term->ghostty_mouse_encoder,
                               GHOSTTY_MOUSE_ENCODER_OPT_ANY_BUTTON_PRESSED,
                               &any_button_pressed);
  ghostty_mouse_event_set_action(term->ghostty_mouse_event, action);
  ghostty_mouse_event_set_mods(term->ghostty_mouse_event, mods);
  ghostty_mouse_event_set_position(term->ghostty_mouse_event, (GhosttyMousePosition) {
    .x = (float)col,
    .y = (float)row,
  });

  if (has_button) {
    ghostty_mouse_event_set_button(term->ghostty_mouse_event, button);
  } else {
    ghostty_mouse_event_clear_button(term->ghostty_mouse_event);
  }

  // Try encoding to a stack-allocated buffer first.
  char buf[128];
  size_t len = 0;
  GhosttyResult res = ghostty_mouse_encoder_encode(term->ghostty_mouse_encoder,
                                                   term->ghostty_mouse_event,
                                                   buf,
                                                   sizeof(buf),
                                                   &len);

  // If that was too small, allocate on the heap.
  if (res == GHOSTTY_OUT_OF_SPACE) {
    char *big_buf = xmalloc(len);
    assert_ghostty_success(ghostty_mouse_encoder_encode(term->ghostty_mouse_encoder,
                                                        term->ghostty_mouse_event,
                                                        big_buf,
                                                        len,
                                                        &len));
    terminal_send(term, big_buf, len);
    xfree(big_buf);
    return;
  }

  assert_ghostty_success(res);
  if (len > 0) {
    terminal_send(term, buf, len);
  }
}

static void mouse_action(Terminal *term, bool has_button, GhosttyMouseButton button, int row,
                         int col, bool pressed, GhosttyMods mods)
{
  terminal_mouse_encoder_sync_config(term);

  GhosttyMouseButton motion_button = GHOSTTY_MOUSE_BUTTON_UNKNOWN;
  bool any_button_pressed = terminal_mouse_get_pressed_button(term, &motion_button);
  terminal_mouse_encode_event(term, GHOSTTY_MOUSE_ACTION_MOTION, any_button_pressed,
                              motion_button, row, col, mods, any_button_pressed);

  if (!has_button) {
    return;
  }

  unsigned button_number = terminal_mouse_button_number(button);
  if (button_number == 0) {
    return;
  }

  unsigned old_buttons = term->ghostty_mouse_buttons;
  if (terminal_mouse_button_is_stateful(button)) {
    unsigned mask = 1U << (button_number - 1);
    if (pressed) {
      term->ghostty_mouse_buttons |= mask;
    } else {
      term->ghostty_mouse_buttons &= ~mask;
    }
  }

  if (term->ghostty_mouse_buttons == old_buttons && (button_number < 4 || button_number > 7)) {
    return;
  }

  any_button_pressed = term->ghostty_mouse_buttons != 0 || pressed;
  terminal_mouse_encode_event(term,
                              pressed ? GHOSTTY_MOUSE_ACTION_PRESS : GHOSTTY_MOUSE_ACTION_RELEASE,
                              true, button, row, col, mods, any_button_pressed);
}

// process a mouse event while the terminal is focused. return true if the
// terminal should lose focus
static bool send_mouse_event(Terminal *term, int c, int modifiers)
{
  int row = mouse_row;
  int col = mouse_col;
  int grid = mouse_grid;
  win_T *mouse_win = mouse_find_win_inner(&grid, &row, &col);
  if (mouse_win == NULL) {
    goto end;
  }

  int offset;
  if (!term->suspended && !term->closed
      && terminal_mouse_tracking_enabled(term) && mouse_win->w_buffer->terminal == term && row >= 0
      && (grid > 1 || row + mouse_win->w_winbar_height < mouse_win->w_height)
      && col >= (offset = win_col_off(mouse_win))
      && (grid > 1 || col < mouse_win->w_width)) {
    // event in the terminal window and mouse events was enabled by the
    // program. translate and forward the event
    GhosttyMouseButton button = GHOSTTY_MOUSE_BUTTON_UNKNOWN;
    bool has_button = true;
    bool pressed = false;

    switch (c) {
    case K_LEFTDRAG:
    case K_LEFTMOUSE:
      pressed = true; FALLTHROUGH;
    case K_LEFTRELEASE:
      button = GHOSTTY_MOUSE_BUTTON_LEFT;
      break;
    case K_MIDDLEDRAG:
    case K_MIDDLEMOUSE:
      pressed = true; FALLTHROUGH;
    case K_MIDDLERELEASE:
      button = GHOSTTY_MOUSE_BUTTON_MIDDLE;
      break;
    case K_RIGHTDRAG:
    case K_RIGHTMOUSE:
      pressed = true; FALLTHROUGH;
    case K_RIGHTRELEASE:
      button = GHOSTTY_MOUSE_BUTTON_RIGHT;
      break;
    case K_X1DRAG:
    case K_X1MOUSE:
      pressed = true; FALLTHROUGH;
    case K_X1RELEASE:
      button = GHOSTTY_MOUSE_BUTTON_EIGHT;
      break;
    case K_X2DRAG:
    case K_X2MOUSE:
      pressed = true; FALLTHROUGH;
    case K_X2RELEASE:
      button = GHOSTTY_MOUSE_BUTTON_NINE;
      break;
    case K_MOUSEDOWN:
      pressed = true;
      button = GHOSTTY_MOUSE_BUTTON_FOUR;
      break;
    case K_MOUSEUP:
      pressed = true;
      button = GHOSTTY_MOUSE_BUTTON_FIVE;
      break;
    case K_MOUSERIGHT:
      pressed = true;
      button = GHOSTTY_MOUSE_BUTTON_SIX;
      break;
    case K_MOUSELEFT:
      pressed = true;
      button = GHOSTTY_MOUSE_BUTTON_SEVEN;
      break;
    case K_MOUSEMOVE:
      has_button = false;
      break;
    default:
      return false;
    }

    GhosttyMods mods = convert_mouse_modifiers(modifiers);
    mouse_action(term, has_button, button, row, col - offset, pressed, mods);
    return false;
  }

  if (c == K_MOUSEUP || c == K_MOUSEDOWN || c == K_MOUSELEFT || c == K_MOUSERIGHT) {
    win_T *save_curwin = curwin;
    // switch window/buffer to perform the scroll
    curwin = mouse_win;
    curbuf = curwin->w_buffer;

    cmdarg_T cap;
    oparg_T oa;
    CLEAR_FIELD(cap);
    clear_oparg(&oa);
    cap.oap = &oa;

    switch (cap.cmdchar = c) {
    case K_MOUSEUP:
      cap.arg = MSCR_UP;
      break;
    case K_MOUSEDOWN:
      cap.arg = MSCR_DOWN;
      break;
    case K_MOUSELEFT:
      cap.arg = MSCR_LEFT;
      break;
    case K_MOUSERIGHT:
      cap.arg = MSCR_RIGHT;
      break;
    default:
      abort();
    }

    // Call the common mouse scroll function shared with other modes.
    do_mousescroll(&cap);

    curwin->w_redr_status = true;
    curwin = save_curwin;
    curbuf = curwin->w_buffer;
    redraw_later(mouse_win, UPD_NOT_VALID);
    invalidate_terminal(term, -1, -1);
    // Only need to exit focus if the scrolled window is the terminal window
    return mouse_win == curwin;
  }

end:
  // Ignore left release action if it was not forwarded to prevent
  // leaving Terminal mode after entering to it using a mouse.
  if ((c == K_LEFTRELEASE && mouse_win != NULL && mouse_win->w_buffer->terminal == term)
      || c == K_MOUSEMOVE) {
    return false;
  }

  requeue_key(vgetc_char, vgetc_mod_mask, true);
  return true;
}

// }}}
// terminal buffer refresh & misc {{{

static bool terminal_ghostty_append_codepoint(Terminal *term, char **ptr, size_t *cell_len,
                                              uint32_t codepoint)
  FUNC_ATTR_NONNULL_ALL
{
  if (*cell_len >= MAX_SCHAR_SIZE - 4
      || (size_t)(*ptr - term->textbuf) + MB_MAXBYTES >= TEXTBUF_SIZE) {
    return false;
  }

  char *cell_start = *ptr;
  *ptr += utf_char2bytes((int)codepoint, *ptr);
  *cell_len += (size_t)(*ptr - cell_start);
  return true;
}

static void terminal_ghostty_append_cell_text(Terminal *term, const GhosttyGridRef *ref,
                                              GhosttyCell cell, char **ptr, size_t *line_len)
  FUNC_ATTR_NONNULL_ALL
{
  size_t grapheme_len = 0;
  GhosttyResult result = ghostty_grid_ref_graphemes(ref, NULL, 0, &grapheme_len);
  if (grapheme_len == 0) {
    if ((size_t)(*ptr - term->textbuf) < TEXTBUF_SIZE - 1) {
      *(*ptr)++ = ' ';
    }
    bool has_styling = false;
    assert_ghostty_success(ghostty_cell_get(cell, GHOSTTY_CELL_DATA_HAS_STYLING, &has_styling));
    if (has_styling) {
      *line_len = (size_t)(*ptr - term->textbuf);
    }
    return;
  }
  if (result != GHOSTTY_OUT_OF_SPACE) {
    assert_ghostty_success(result);
  }

  uint32_t stack[16];
  uint32_t *graphemes = stack;
  if (grapheme_len > ARRAY_SIZE(stack)) {
    graphemes = xmalloc(sizeof(*graphemes) * grapheme_len);
  }

  assert_ghostty_success(ghostty_grid_ref_graphemes(ref, graphemes, grapheme_len,
                                                    &grapheme_len));
  size_t cell_len = 0;
  for (size_t i = 0; i < grapheme_len; i++) {
    if (!terminal_ghostty_append_codepoint(term, ptr, &cell_len, graphemes[i])) {
      break;
    }
  }
  *line_len = (size_t)(*ptr - term->textbuf);

  if (graphemes != stack) {
    xfree(graphemes);
  }
}

static size_t fetch_ghostty_row(Terminal *term, GhosttyPointTag tag, uint32_t row, int end_col)
  FUNC_ATTR_NONNULL_ALL
{
  int col = 0;
  size_t line_len = 0;
  char *ptr = term->textbuf;

  while (col < end_col) {
    GhosttyGridRef ref = { 0 };
    if (!terminal_ghostty_grid_ref(term, tag, row, col, &ref)) {
      break;
    }
    GhosttyCell cell = 0;
    assert_ghostty_success(ghostty_grid_ref_cell(&ref, &cell));
    terminal_ghostty_append_cell_text(term, &ref, cell, &ptr, &line_len);
    GhosttyCellWide wide = GHOSTTY_CELL_WIDE_NARROW;
    assert_ghostty_success(ghostty_cell_get(cell, GHOSTTY_CELL_DATA_WIDE, &wide));
    col += wide == GHOSTTY_CELL_WIDE_WIDE ? 2 : 1;
  }

  term->textbuf[line_len] = NUL;
  return line_len;
}

static void fetch_active_row(Terminal *term, int row, int end_col)
{
  if (row < 0 || fetch_ghostty_row(term, GHOSTTY_POINT_TAG_ACTIVE, (uint32_t)row, end_col) == 0) {
    term->textbuf[0] = NUL;
  }
}

static void fetch_screen_row(Terminal *term, size_t screen_row, int end_col)
{
  size_t offset = term->ghostty_scrollback_rows - term->scrollback_rows;
  size_t row = offset + screen_row;
  if (row > UINT32_MAX
      || fetch_ghostty_row(term, GHOSTTY_POINT_TAG_SCREEN, (uint32_t)row, end_col) == 0) {
    term->textbuf[0] = NUL;
  }
}

// queue a terminal instance for refresh
static void invalidate_terminal(Terminal *term, int start_row, int end_row)
{
  if (start_row != -1 && end_row != -1) {
    term->invalid_start = MIN(term->invalid_start, start_row);
    term->invalid_end = MAX(term->invalid_end, end_row);
  }

  // During synchronized output (mode 2026), accumulate damage but defer
  // the actual refresh until the synchronized update ends.
  if (term->synchronized_output) {
    return;
  }

  set_put(ptr_t, &invalidated_terminals, term);
  if (!refresh_pending) {
    time_watcher_start(&refresh_timer, refresh_timer_cb, REFRESH_DELAY, 0);
    refresh_pending = true;
  }
}

/// Invalidates the terminal rows Ghostty reports as dirty.
///
/// We're currently handling invalid terminal rows as a single range, so partial Ghostty damage is
/// collapsed to the smallest range covering every dirty row. After this returns, Ghostty's render
/// state has been fully reset to not dirty.
static void terminal_ghostty_render_state_update(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  assert_ghostty_success(ghostty_render_state_update(term->ghostty_render_state,
                                                     term->ghostty));
  terminal_ghostty_cursor_update(term);
  terminal_ghostty_termprops_update(term);

  GhosttyRenderStateDirty dirty_state = GHOSTTY_RENDER_STATE_DIRTY_FALSE;
  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_DIRTY,
                                                  &dirty_state));
  // Nothing to re-render, so we're done.
  if (dirty_state == GHOSTTY_RENDER_STATE_DIRTY_FALSE) {
    return;
  }

  int dirty_start = INT_MAX;
  int dirty_end = -1;

  // The whole screen is dirty, so the dirty range spans the full height.
  if (dirty_state == GHOSTTY_RENDER_STATE_DIRTY_FULL) {
    uint16_t rows = 0;
    assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                    GHOSTTY_RENDER_STATE_DATA_ROWS,
                                                    &rows));
    dirty_start = 0;
    dirty_end = rows;
  }

  assert_ghostty_success(ghostty_render_state_get(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_DATA_ROW_ITERATOR,
                                                  &term->ghostty_render_row_iterator));

  int row_idx = 0;

  while (ghostty_render_state_row_iterator_next(term->ghostty_render_row_iterator)) {
    if (dirty_state == GHOSTTY_RENDER_STATE_DIRTY_PARTIAL) {
      bool row_dirty = false;
      assert_ghostty_success(ghostty_render_state_row_get(term->ghostty_render_row_iterator,
                                                          GHOSTTY_RENDER_STATE_ROW_DATA_DIRTY,
                                                          &row_dirty));
      if (row_dirty) {
        dirty_start = MIN(dirty_start, row_idx);
        dirty_end = row_idx + 1;
      }
    }

    // Mark the row as clean.
    bool dirty = false;
    assert_ghostty_success(ghostty_render_state_row_set(term->ghostty_render_row_iterator,
                                                        GHOSTTY_RENDER_STATE_ROW_OPTION_DIRTY,
                                                        &dirty));
    row_idx++;
  }

  invalidate_terminal(term, dirty_start, dirty_end);

  dirty_state = GHOSTTY_RENDER_STATE_DIRTY_FALSE;
  assert_ghostty_success(ghostty_render_state_set(term->ghostty_render_state,
                                                  GHOSTTY_RENDER_STATE_OPTION_DIRTY,
                                                  &dirty_state));
}

/// Normally refresh_timer_cb() is called when processing main_loop.events, but with
/// partial mappings main_loop.events isn't processed, while terminal buffers still
/// need refreshing after processing a key, so call this function before redrawing.
void terminal_check_refresh(void)
{
  multiqueue_process_events(refresh_timer.events);
}

static void refresh_terminal(Terminal *term)
{
  buf_T *buf = handle_get_buffer(term->buf_handle);
  if (!buf) {
    // Destroyed by `buf_freeall()`. Do not do anything else.
    return;
  }
  linenr_T ml_before = buf->b_ml.ml_line_count;

  bool resized = refresh_size(term, buf);
  refresh_scrollback(term, buf, resized);
  refresh_screen(term, buf);

  int ml_added = buf->b_ml.ml_line_count - ml_before;
  adjust_topline_cursor(term, buf, ml_added);

  // Resized window may have scrolled horizontally to keep its cursor in-view using the old terminal
  // size. Reset the scroll, and let curs_columns correct it if that sends the cursor out-of-view.
  if (resized) {
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (wp->w_buffer == buf && wp->w_leftcol != 0) {
        wp->w_leftcol = 0;
        curs_columns(wp, true);
      }
    }
  }

  // Copy pending events back to the main event queue
  multiqueue_move_events(main_loop.events, term->pending.events);
}

static void refresh_cursor(Terminal *term, bool *cursor_visible)
  FUNC_ATTR_NONNULL_ALL
{
  if (!is_focused(term)) {
    return;
  }
  if (term->cursor.visible != *cursor_visible) {
    *cursor_visible = term->cursor.visible;
    if (*cursor_visible) {
      ui_busy_stop();
    } else {
      ui_busy_start();
    }
  }

  if (!term->pending.cursor) {
    return;
  }
  term->pending.cursor = false;

  if (term->cursor.blink) {
    // For the TUI, this value doesn't actually matter, as long as it's non-zero. The terminal
    // emulator dictates the blink frequency, not the application.
    // For GUIs we just pick an arbitrary value, for now.
    shape_table[SHAPE_IDX_TERM].blinkon = 500;
    shape_table[SHAPE_IDX_TERM].blinkoff = 500;
  } else {
    shape_table[SHAPE_IDX_TERM].blinkon = 0;
    shape_table[SHAPE_IDX_TERM].blinkoff = 0;
  }

  switch (term->cursor.shape) {
  case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BLOCK:
  case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BLOCK_HOLLOW:
    shape_table[SHAPE_IDX_TERM].shape = SHAPE_BLOCK;
    break;
  case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_UNDERLINE:
    shape_table[SHAPE_IDX_TERM].shape = SHAPE_HOR;
    shape_table[SHAPE_IDX_TERM].percentage = 20;
    break;
  case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_BAR:
    shape_table[SHAPE_IDX_TERM].shape = SHAPE_VER;
    shape_table[SHAPE_IDX_TERM].percentage = 25;
    break;
  case GHOSTTY_RENDER_STATE_CURSOR_VISUAL_STYLE_MAX_VALUE:
    abort();
  }

  ui_mode_info_set();
}

/// Calls refresh_terminal() on all invalidated_terminals.
static void refresh_timer_cb(TimeWatcher *watcher, void *data)
{
  refresh_pending = false;
  if (exiting) {  // Cannot redraw (requires event loop) during teardown/exit.
    return;
  }

  // Don't process autocommands while updating terminal buffers.
  block_autocmds();
  // Refreshing one terminal may poll for output to another, which should not
  // interfere with the set_foreach() below.
  Set(ptr_t) to_refresh = invalidated_terminals;
  invalidated_terminals = (Set(ptr_t)) SET_INIT;

  Terminal *term;
  set_foreach(&to_refresh, term, {
    // Skip terminals in synchronized output — they will be refreshed
    // when the synchronized update ends (mode 2026 reset).
    if (!term->synchronized_output) {
      refresh_terminal(term);
    }
  });

  set_destroy(ptr_t, &to_refresh);
  unblock_autocmds();
}

static bool refresh_size(Terminal *term, buf_T *buf)
{
  (void)buf;
  if (!term->pending.resize || term->closed) {
    return false;
  }

  term->pending.resize = false;
  int width, height;
  terminal_ghostty_size_get(term, &height, &width);
  term->invalid_start = 0;
  term->invalid_end = height;
  return true;
}

void on_scrollback_option_changed(Terminal *term)
{
  refresh_terminal(term);
}

// Refresh the scrollback of an invalidated terminal.
static void refresh_scrollback(Terminal *term, buf_T *buf, bool resized)
{
  // Buffer update callbacks may poll for uv events.
  // Avoid polling for output to the same terminal as the one being refreshed.
  term->opts.read_pause_cb(true, term->opts.data);

  int width, height;
  terminal_ghostty_size_get(term, &height, &width);

  if (term->in_altscreen) {
    linenr_T target_line_count = (linenr_T)(term->scrollback_rows + (size_t)height);
    if (buf->b_ml.ml_line_count > target_line_count) {
      target_line_count++;
    }
    FOR_ALL_TAB_WINDOWS(tp, wp) {
      if (!is_ctx_win(wp) && wp->w_buffer == buf) {
        target_line_count = MAX(target_line_count,
                                (linenr_T)(term->scrollback_rows + (size_t)wp->w_view_height));
      }
    }
    while (buf->b_ml.ml_line_count > target_line_count && buf->b_ml.ml_line_count > 1) {
      ml_delete_buf(buf, buf->b_ml.ml_line_count, false);
      deleted_lines_buf(buf, buf->b_ml.ml_line_count, 1);
    }
    while (buf->b_ml.ml_line_count < target_line_count) {
      ml_append_buf(buf, buf->b_ml.ml_line_count, "", 0, false);
      appended_lines_buf(buf, buf->b_ml.ml_line_count, 1);
    }
    term->opts.read_pause_cb(false, term->opts.data);
    return;
  }

  size_t ghostty_scrollback_rows = terminal_ghostty_scrollback_rows_get(term);
  size_t scrollback_limit = terminal_scrollback_limit(buf);
  size_t scrollback_rows = MIN(ghostty_scrollback_rows, scrollback_limit);

  // Increasing 'scrollback' does not resurrect lines that were not mirrored in
  // the nvim buffer before the option changed. This matches the old terminal
  // behavior while still allowing Ghostty to retain enough history for reflow.
  if (ghostty_scrollback_rows <= term->ghostty_scrollback_rows
      && scrollback_rows > term->scrollback_rows) {
    scrollback_rows = term->scrollback_rows;
  }

  size_t old_scrollback_rows = term->scrollback_rows;
  size_t initial_scrollback_rows = old_scrollback_rows;
  size_t old_ghostty_scrollback_rows = term->ghostty_scrollback_rows;
  bool scrollback_cleared = term->scrollback_clear_pending;
  term->scrollback_clear_pending = false;

  if (!resized && scrollback_cleared) {
    size_t deleted = old_scrollback_rows;
    if (deleted > 0) {
      mark_adjust_buf(buf, 1, (linenr_T)deleted, MAXLNUM, -(linenr_T)deleted, true,
                      kMarkAdjustTerm, kExtmarkUndo);
      term->scrollback_deleted += deleted;
    }
    while (deleted > 0 && buf->b_ml.ml_line_count > 1) {
      ml_delete_buf(buf, 1, false);
      deleted_lines_buf(buf, 1, 1);
      deleted--;
    }
    old_scrollback_rows = scrollback_rows;
  } else if (old_ghostty_scrollback_rows <= ghostty_scrollback_rows) {
    size_t ghostty_delta = ghostty_scrollback_rows - old_ghostty_scrollback_rows;
    size_t mirrored_delta = scrollback_rows > old_scrollback_rows
                            ? scrollback_rows - old_scrollback_rows : 0;
    size_t deleted = ghostty_delta > mirrored_delta ? ghostty_delta - mirrored_delta : 0;
    if (deleted > 0) {
      mark_adjust_buf(buf, 1, (linenr_T)deleted, MAXLNUM, -(linenr_T)deleted, true,
                      kMarkAdjustTerm, kExtmarkUndo);
      term->scrollback_deleted += deleted;
    }
    deleted = MIN(deleted, old_scrollback_rows);
    while (deleted > 0 && buf->b_ml.ml_line_count > 1) {
      ml_delete_buf(buf, 1, false);
      deleted_lines_buf(buf, 1, 1);
      old_scrollback_rows--;
      deleted--;
    }
  } else if (!resized && scrollback_rows < old_scrollback_rows) {
    size_t deleted = old_scrollback_rows - scrollback_rows;
    mark_adjust_buf(buf, 1, (linenr_T)deleted, MAXLNUM, -(linenr_T)deleted, true,
                    kMarkAdjustTerm, kExtmarkUndo);
    term->scrollback_deleted += deleted;
    while (deleted > 0 && buf->b_ml.ml_line_count > 1) {
      ml_delete_buf(buf, 1, false);
      deleted_lines_buf(buf, 1, 1);
      old_scrollback_rows--;
      deleted--;
    }
  }

  term->ghostty_scrollback_rows = ghostty_scrollback_rows;
  term->scrollback_rows = scrollback_rows;

  if (!resized) {
    while (old_scrollback_rows < scrollback_rows) {
      fetch_screen_row(term, old_scrollback_rows, width);
      ml_append_buf(buf, (linenr_T)old_scrollback_rows, term->textbuf, 0, false);
      appended_lines_buf(buf, (linenr_T)old_scrollback_rows, 1);
      old_scrollback_rows++;
    }
  }

  if (!resized) {
    while (old_scrollback_rows > scrollback_rows && buf->b_ml.ml_line_count > 1) {
      mark_adjust_buf(buf, 1, 1, MAXLNUM, -1, true, kMarkAdjustTerm, kExtmarkUndo);
      term->scrollback_deleted++;
      ml_delete_buf(buf, 1, false);
      deleted_lines_buf(buf, 1, 1);
      old_scrollback_rows--;
    }
  }

  linenr_T target_line_count = (linenr_T)(scrollback_rows + (size_t)height);
  while (buf->b_ml.ml_line_count < target_line_count) {
    ml_append_buf(buf, buf->b_ml.ml_line_count, "", 0, false);
    appended_lines_buf(buf, buf->b_ml.ml_line_count, 1);
  }
  while (buf->b_ml.ml_line_count > target_line_count && buf->b_ml.ml_line_count > 1) {
    mark_adjust_buf(buf, 1, 1, MAXLNUM, -1, true, kMarkAdjustTerm, kExtmarkUndo);
    term->scrollback_deleted++;
    ml_delete_buf(buf, 1, false);
    deleted_lines_buf(buf, 1, 1);
  }

  bool history_dirty = resized || scrollback_cleared
                       || old_ghostty_scrollback_rows != ghostty_scrollback_rows
                       || initial_scrollback_rows != scrollback_rows
                       || buf->b_ml.ml_line_count < (linenr_T)scrollback_rows;
  if (history_dirty) {
    for (size_t row = 0; row < scrollback_rows; row++) {
      fetch_screen_row(term, row, width);
      linenr_T linenr = (linenr_T)row + 1;
      while (buf->b_ml.ml_line_count < linenr - 1) {
        ml_append_buf(buf, buf->b_ml.ml_line_count, "", 0, false);
        appended_lines_buf(buf, buf->b_ml.ml_line_count, 1);
      }
      if (linenr <= buf->b_ml.ml_line_count) {
        ml_replace_buf(buf, linenr, term->textbuf, true, false);
      } else {
        ml_append_buf(buf, buf->b_ml.ml_line_count, term->textbuf, 0, false);
        appended_lines_buf(buf, buf->b_ml.ml_line_count, 1);
      }
    }
    if (scrollback_rows > 0) {
      changed_lines(buf, 1, 0, (linenr_T)scrollback_rows + 1, 0, true);
    }
  }

  term->opts.read_pause_cb(false, term->opts.data);
}

// Refresh the screen (visible part of the buffer when the terminal is
// focused) of a invalidated terminal
static void refresh_screen(Terminal *term, buf_T *buf)
{
  int changed = 0;
  int added = 0;
  int height;
  int width;
  terminal_ghostty_size_get(term, &height, &width);
  // Terminal height may have decreased before `invalid_end` reflects it.
  term->invalid_end = MIN(term->invalid_end, height);

  // There are no invalid rows.
  if (term->invalid_start >= term->invalid_end) {
    term->invalid_start = INT_MAX;
    term->invalid_end = -1;
    return;
  }

  for (int r = term->invalid_start, linenr = row_to_linenr(term, r);
       r < term->invalid_end; r++, linenr++) {
    fetch_active_row(term, r, width);

    while (buf->b_ml.ml_line_count < linenr - 1) {
      ml_append_buf(buf, buf->b_ml.ml_line_count, "", 0, false);
      added++;
    }
    if (linenr <= buf->b_ml.ml_line_count) {
      ml_replace_buf(buf, linenr, term->textbuf, true, false);
      changed++;
    } else {
      ml_append_buf(buf, linenr - 1, term->textbuf, 0, false);
      added++;
    }
  }
  int change_start = row_to_linenr(term, term->invalid_start);
  int change_end = change_start + changed;
  term->invalid_start = INT_MAX;
  term->invalid_end = -1;
  // Call this after resetting the invalid region, as buffer update callbacks may
  // poll for terminal output and lead to new invalidations.
  changed_lines(buf, change_start, 0, change_end, added, true);
}

static void adjust_topline_cursor(Terminal *term, buf_T *buf, int added)
{
  linenr_T ml_end = buf->b_ml.ml_line_count;

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == buf) {
      if (wp == curwin && is_focused(term)) {
        // Move window cursor to terminal cursor's position and "follow" output.
        terminal_check_cursor();
        continue;
      }

      bool following = ml_end == wp->w_cursor.lnum + added;  // cursor at end?
      if (following) {
        // "Follow" the terminal output
        wp->w_cursor.lnum = ml_end;
        set_topline(wp, MAX(wp->w_cursor.lnum - wp->w_view_height + 1, 1));
      } else {
        // Ensure valid cursor for each window displaying this terminal.
        wp->w_cursor.lnum = MIN(wp->w_cursor.lnum, ml_end);
      }
      mb_check_adjust_col(wp);
    }
  }

  if (ml_end == buf->b_last_cursor.mark.lnum + added) {
    buf->b_last_cursor.mark.lnum = ml_end;
  }

  for (size_t i = 0; i < kv_size(buf->b_wininfo); i++) {
    WinInfo *wip = kv_A(buf->b_wininfo, i);
    if (ml_end == wip->wi_mark.mark.lnum + added) {
      wip->wi_mark.mark.lnum = ml_end;
    }
  }
}

static int row_to_linenr(Terminal *term, int row)
{
  return row != INT_MAX ? row + (int)term->scrollback_rows + 1 : INT_MAX;
}

static bool is_focused(Terminal *term)
{
  return State & MODE_TERMINAL && curbuf->terminal == term;
}

static char *get_config_string(buf_T *buf, char *key)
{
  Error err = ERROR_INIT;
  Object obj = dict_get_value(buf->b_vars, cstr_as_string(key), NULL, &err);
  api_clear_error(&err);
  if (obj.type == kObjectTypeNil) {
    obj = dict_get_value(get_globvar_dict(), cstr_as_string(key), NULL, &err);
    api_clear_error(&err);
  }
  if (obj.type == kObjectTypeString) {
    return obj.data.string.data;
  }
  api_free_object(obj);
  return NULL;
}

// }}}

// vim: foldmethod=marker
