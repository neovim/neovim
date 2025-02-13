// VT220/xterm-like terminal emulator.
// Powered by libvterm http://www.leonerd.org.uk/code/libvterm
//
// libvterm is a pure C99 terminal emulation library with abstract input and
// display. This means that the library needs to read data from the master fd
// and feed VTerm instances, which will invoke user callbacks with screen
// update instructions that must be mirrored to the real display.
//
// Keys are sent to VTerm instances by calling
// vterm_keyboard_key/vterm_keyboard_unichar, which generates byte streams that
// must be fed back to the master fd.
//
// Nvim buffers are used as the display mechanism for both the visible screen
// and the scrollback buffer.
//
// When a line becomes invisible due to a decrease in screen height or because
// a line was pushed up during normal terminal output, we store the line
// information in the scrollback buffer, which is mirrored in the nvim buffer
// by appending lines just above the visible part of the buffer.
//
// When the screen height increases, libvterm will ask for a row in the
// scrollback buffer, which is mirrored in the nvim buffer displaying lines
// that were previously invisible.
//
// The vterm->nvim synchronization is performed in intervals of 10 milliseconds,
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
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/channel.h"
#include "nvim/channel_defs.h"
#include "nvim/cursor.h"
#include "nvim/cursor_shape.h"
#include "nvim/drawline.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/time.h"
#include "nvim/ex_docmd.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
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
#include "nvim/vterm/keyboard.h"
#include "nvim/vterm/mouse.h"
#include "nvim/vterm/parser.h"
#include "nvim/vterm/pen.h"
#include "nvim/vterm/screen.h"
#include "nvim/vterm/state.h"
#include "nvim/vterm/vterm.h"
#include "nvim/vterm/vterm_keycodes_defs.h"
#include "nvim/window.h"

typedef struct {
  VimState state;
  Terminal *term;
  int save_rd;              // saved value of RedrawingDisabled
  bool close;
  bool got_bsl;             // if the last input was <C-\>
  bool got_bsl_o;           // if left terminal mode with <c-\><c-o>
} TerminalState;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "terminal.c.generated.h"
#endif

// Delay for refreshing the terminal buffer after receiving updates from
// libvterm. Improves performance when receiving large bursts of data.
#define REFRESH_DELAY 10

#define TEXTBUF_SIZE      0x1fff
#define SELECTIONBUF_SIZE 0x0400

static TimeWatcher refresh_timer;
static bool refresh_pending = false;

typedef struct {
  size_t cols;
  VTermScreenCell cells[];
} ScrollbackLine;

struct terminal {
  TerminalOptions opts;  // options passed to terminal_open
  VTerm *vt;
  VTermScreen *vts;
  // buffer used to:
  //  - convert VTermScreen cell arrays into utf8 strings
  //  - receive data from libvterm as a result of key presses.
  char textbuf[TEXTBUF_SIZE];

  ScrollbackLine **sb_buffer;       // Scrollback storage.
  size_t sb_current;                // Lines stored in sb_buffer.
  size_t sb_size;                   // Capacity of sb_buffer.
  // "virtual index" that points to the first sb_buffer row that we need to
  // push to the terminal buffer when refreshing the scrollback. When negative,
  // it actually points to entries that are no longer in sb_buffer (because the
  // window height has increased) and must be deleted from the terminal buffer
  int sb_pending;

  char *title;     // VTermStringFragment buffer
  size_t title_len;    // number of rows pushed to sb_buffer
  size_t title_size;   // sb_buffer size

  // buf_T instance that acts as a "drawing surface" for libvterm
  // we can't store a direct reference to the buffer because the
  // refresh_timer_cb may be called after the buffer was freed, and there's
  // no way to know if the memory was reused.
  handle_T buf_handle;
  // program exited
  bool closed;
  // when true, the terminal's destruction is already enqueued.
  bool destroy;

  // some vterm properties
  bool forward_mouse;
  int invalid_start, invalid_end;   // invalid rows in libvterm screen
  struct {
    int row, col;
    int shape;
    bool visible;
    bool blink;
  } cursor;

  struct {
    bool resize;          ///< pending width/height
    bool cursor;          ///< pending cursor shape or blink change
    StringBuilder *send;  ///< When there is a pending TermRequest autocommand, block and store input.
  } pending;

  bool theme_updates;  ///< Send a theme update notification when 'bg' changes

  bool color_set[16];

  char *selection_buffer;  ///< libvterm selection buffer
  StringBuilder selection;  ///< Growable array containing full selection data

  StringBuilder termrequest_buffer;  ///< Growable array containing unfinished request payload

  size_t refcount;                  // reference count
};

static VTermScreenCallbacks vterm_screen_callbacks = {
  .damage = term_damage,
  .moverect = term_moverect,
  .movecursor = term_movecursor,
  .settermprop = term_settermprop,
  .bell = term_bell,
  .theme = term_theme,
  .sb_pushline = term_sb_push,  // Called before a line goes offscreen.
  .sb_popline = term_sb_pop,
};

static VTermSelectionCallbacks vterm_selection_callbacks = {
  .set = term_selection_set,
  // For security reasons we don't support querying the system clipboard from the embedded terminal
  .query = NULL,
};

static Set(ptr_t) invalidated_terminals = SET_INIT;

static void emit_termrequest(void **argv)
{
  Terminal *term = argv[0];
  char *payload = argv[1];
  size_t payload_length = (size_t)argv[2];
  StringBuilder *pending_send = argv[3];

  buf_T *buf = handle_get_buffer(term->buf_handle);
  String termrequest = { .data = payload, .size = payload_length };
  Object data = STRING_OBJ(termrequest);
  set_vim_var_string(VV_TERMREQUEST, payload, (ptrdiff_t)payload_length);
  apply_autocmds_group(EVENT_TERMREQUEST, NULL, NULL, false, AUGROUP_ALL, buf, NULL, &data);
  xfree(payload);

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
}

static void schedule_termrequest(Terminal *term, char *payload, size_t payload_length)
{
  term->pending.send = xmalloc(sizeof(StringBuilder));
  kv_init(*term->pending.send);
  multiqueue_put(main_loop.events, emit_termrequest, term, payload, (void *)payload_length,
                 term->pending.send);
}

static int parse_osc8(VTermStringFragment frag, int *attr)
  FUNC_ATTR_NONNULL_ALL
{
  // Parse the URI from the OSC 8 sequence and add the URL to our URL set.
  // Skip the ID, we don't use it (for now)
  size_t i = 0;
  for (; i < frag.len; i++) {
    if (frag.str[i] == ';') {
      break;
    }
  }

  // Move past the semicolon
  i++;

  if (i >= frag.len) {
    // Invalid OSC sequence
    return 0;
  }

  // Find the terminator
  const size_t start = i;
  for (; i < frag.len; i++) {
    if (frag.str[i] == '\a' || frag.str[i] == '\x1b') {
      break;
    }
  }

  const size_t len = i - start;
  if (len == 0) {
    // Empty OSC 8, no URL
    *attr = 0;
    return 1;
  }

  char *url = xmemdupz(&frag.str[start], len + 1);
  url[len] = 0;
  *attr = hl_add_url(0, url);
  xfree(url);

  return 1;
}

static int on_osc(int command, VTermStringFragment frag, void *user)
  FUNC_ATTR_NONNULL_ALL
{
  Terminal *term = user;

  if (frag.str == NULL || frag.len == 0) {
    return 0;
  }

  if (command == 8) {
    int attr = 0;
    if (parse_osc8(frag, &attr)) {
      VTermState *state = vterm_obtain_state(term->vt);
      VTermValue value = { .number = attr };
      vterm_state_set_penattr(state, VTERM_ATTR_URI, VTERM_VALUETYPE_INT, &value);
    }
  }

  if (!has_event(EVENT_TERMREQUEST)) {
    return 1;
  }

  if (frag.initial) {
    kv_size(term->termrequest_buffer) = 0;
    kv_printf(term->termrequest_buffer, "\x1b]%d;", command);
  }
  kv_concat_len(term->termrequest_buffer, frag.str, frag.len);
  if (frag.final) {
    char *payload = xmemdup(term->termrequest_buffer.items, term->termrequest_buffer.size);
    schedule_termrequest(user, payload, term->termrequest_buffer.size);
  }
  return 1;
}

static int on_dcs(const char *command, size_t commandlen, VTermStringFragment frag, void *user)
{
  Terminal *term = user;

  if (command == NULL || frag.str == NULL) {
    return 0;
  }
  if (!has_event(EVENT_TERMREQUEST)) {
    return 1;
  }

  if (frag.initial) {
    kv_size(term->termrequest_buffer) = 0;
    kv_printf(term->termrequest_buffer, "\x1bP%*s", (int)commandlen, command);
  }
  kv_concat_len(term->termrequest_buffer, frag.str, frag.len);
  if (frag.final) {
    char *payload = xmemdup(term->termrequest_buffer.items, term->termrequest_buffer.size);
    schedule_termrequest(user, payload, term->termrequest_buffer.size);
  }
  return 1;
}

static int on_apc(VTermStringFragment frag, void *user)
{
  Terminal *term = user;
  if (frag.str == NULL || frag.len == 0) {
    return 0;
  }

  if (!has_event(EVENT_TERMREQUEST)) {
    return 1;
  }

  if (frag.initial) {
    kv_size(term->termrequest_buffer) = 0;
    kv_printf(term->termrequest_buffer, "\x1b_");
  }
  kv_concat_len(term->termrequest_buffer, frag.str, frag.len);
  if (frag.final) {
    char *payload = xmemdup(term->termrequest_buffer.items, term->termrequest_buffer.size);
    schedule_termrequest(user, payload, term->termrequest_buffer.size);
  }
  return 1;
}

static VTermStateFallbacks vterm_fallbacks = {
  .control = NULL,
  .csi = NULL,
  .osc = on_osc,
  .dcs = on_dcs,
  .apc = on_apc,
  .pm = NULL,
  .sos = NULL,
};

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

static void term_output_callback(const char *s, size_t len, void *user_data)
{
  terminal_send((Terminal *)user_data, s, len);
}

// public API {{{

/// Initializes terminal properties, and triggers TermOpen.
///
/// The PTY process (TerminalOptions.data) was already started by jobstart(),
/// via ex_terminal() or the term:// BufReadCmd.
///
/// @param buf Buffer used for presentation of the terminal.
/// @param opts PTY process channel, various terminal properties and callbacks.
void terminal_open(Terminal **termpp, buf_T *buf, TerminalOptions opts)
  FUNC_ATTR_NONNULL_ALL
{
  // Create a new terminal instance and configure it
  Terminal *term = *termpp = xcalloc(1, sizeof(Terminal));
  term->opts = opts;

  // Associate the terminal instance with the new buffer
  term->buf_handle = buf->handle;
  buf->terminal = term;
  // Create VTerm
  term->vt = vterm_new(opts.height, opts.width);
  vterm_set_utf8(term->vt, 1);
  // Setup state
  VTermState *state = vterm_obtain_state(term->vt);
  // Set up screen
  term->vts = vterm_obtain_screen(term->vt);
  vterm_screen_enable_altscreen(term->vts, true);
  vterm_screen_enable_reflow(term->vts, true);
  // delete empty lines at the end of the buffer
  vterm_screen_set_callbacks(term->vts, &vterm_screen_callbacks, term);
  vterm_screen_set_unrecognised_fallbacks(term->vts, &vterm_fallbacks, term);
  vterm_screen_set_damage_merge(term->vts, VTERM_DAMAGE_SCROLL);
  vterm_screen_reset(term->vts, 1);
  vterm_output_set_callback(term->vt, term_output_callback, term);

  term->selection_buffer = xcalloc(SELECTIONBUF_SIZE, 1);
  vterm_state_set_selection_callbacks(state, &vterm_selection_callbacks, term,
                                      term->selection_buffer, SELECTIONBUF_SIZE);

  VTermValue cursor_shape;
  switch (shape_table[SHAPE_IDX_TERM].shape) {
  case SHAPE_BLOCK:
    cursor_shape.number = VTERM_PROP_CURSORSHAPE_BLOCK;
    break;
  case SHAPE_HOR:
    cursor_shape.number = VTERM_PROP_CURSORSHAPE_UNDERLINE;
    break;
  case SHAPE_VER:
    cursor_shape.number = VTERM_PROP_CURSORSHAPE_BAR_LEFT;
    break;
  }
  vterm_state_set_termprop(state, VTERM_PROP_CURSORSHAPE, &cursor_shape);

  VTermValue cursor_blink;
  if (shape_table[SHAPE_IDX_TERM].blinkon != 0 && shape_table[SHAPE_IDX_TERM].blinkoff != 0) {
    cursor_blink.boolean = true;
  } else {
    cursor_blink.boolean = false;
  }
  vterm_state_set_termprop(state, VTERM_PROP_CURSORBLINK, &cursor_blink);

  // force a initial refresh of the screen to ensure the buffer will always
  // have as many lines as screen rows when refresh_scrollback is called
  term->invalid_start = 0;
  term->invalid_end = opts.height;

  aco_save_T aco;
  aucmd_prepbuf(&aco, buf);

  refresh_screen(term, buf);
  set_option_value(kOptBuftype, STATIC_CSTR_AS_OPTVAL("terminal"), OPT_LOCAL);

  if (buf->b_ffname != NULL) {
    buf_set_term_title(buf, buf->b_ffname, strlen(buf->b_ffname));
  }
  RESET_BINDING(curwin);
  // Reset cursor in current window.
  curwin->w_cursor = (pos_T){ .lnum = 1, .col = 0, .coladd = 0 };
  // Initialize to check if the scrollback buffer has been allocated in a TermOpen autocmd.
  term->sb_buffer = NULL;
  // Apply TermOpen autocmds _before_ configuring the scrollback buffer.
  apply_autocmds(EVENT_TERMOPEN, NULL, NULL, false, buf);

  aucmd_restbuf(&aco);

  if (*termpp == NULL) {
    return;  // Terminal has already been destroyed.
  }

  if (term->sb_buffer == NULL) {
    // Local 'scrollback' _after_ autocmds.
    if (buf->b_p_scbk < 1) {
      buf->b_p_scbk = SB_MAX;
    }
    // Configure the scrollback buffer.
    term->sb_size = (size_t)buf->b_p_scbk;
    term->sb_buffer = xmalloc(sizeof(ScrollbackLine *) * term->sb_size);
  }

  // Configure the color palette. Try to get the color from:
  //
  // - b:terminal_color_{NUM}
  // - g:terminal_color_{NUM}
  // - the VTerm instance
  for (int i = 0; i < 16; i++) {
    char var[64];
    snprintf(var, sizeof(var), "terminal_color_%d", i);
    char *name = get_config_string(var);
    if (name) {
      int dummy;
      RgbValue color_val = name_to_color(name, &dummy);

      if (color_val != -1) {
        VTermColor color;
        vterm_color_rgb(&color,
                        (uint8_t)((color_val >> 16) & 0xFF),
                        (uint8_t)((color_val >> 8) & 0xFF),
                        (uint8_t)((color_val >> 0) & 0xFF));
        vterm_state_set_palette_color(state, i, &color);
        term->color_set[i] = true;
      }
    }
  }
}

/// Closes the Terminal buffer.
///
/// May call terminal_destroy, which sets caller storage to NULL.
void terminal_close(Terminal **termpp, int status)
  FUNC_ATTR_NONNULL_ALL
{
  Terminal *term = *termpp;
  if (term->destroy) {
    return;
  }

#ifdef EXITFREE
  if (entered_free_all_mem) {
    // If called from close_buffer() inside free_all_mem(), the main loop has
    // already been freed, so it is not safe to call the close callback here.
    terminal_destroy(termpp);
    return;
  }
#endif

  bool only_destroy = false;

  if (term->closed) {
    // If called from close_buffer() after the process has already exited, we
    // only need to call the close callback to clean up the terminal object.
    only_destroy = true;
  } else {
    term->forward_mouse = false;
    // flush any pending changes to the buffer
    if (!exiting) {
      block_autocmds();
      refresh_terminal(term);
      unblock_autocmds();
    }
    term->closed = true;
  }

  buf_T *buf = handle_get_buffer(term->buf_handle);

  if (status == -1 || exiting) {
    // If this was called by close_buffer() (status is -1), or if exiting, we
    // must inform the buffer the terminal no longer exists so that
    // close_buffer() won't call this again.
    // If inside Terminal mode K_EVENT handling, setting buf_handle to 0 also
    // informs terminal_enter() to call the close callback before returning.
    term->buf_handle = 0;
    if (buf) {
      buf->terminal = NULL;
    }
    if (!term->refcount) {
      // Not inside Terminal mode K_EVENT handling.
      // We should not wait for the user to press a key.
      term->destroy = true;
      term->opts.close_cb(term->opts.data);
    }
  } else if (!only_destroy) {
    // Associated channel has been closed and the editor is not exiting.
    // Do not call the close callback now. Wait for the user to press a key.
    char msg[sizeof("\r\n[Process exited ]") + NUMBUFLEN];
    if (((Channel *)term->opts.data)->streamtype == kChannelStreamInternal) {
      snprintf(msg, sizeof msg, "\r\n[Terminal closed]");
    } else {
      snprintf(msg, sizeof msg, "\r\n[Process exited %d]", status);
    }
    terminal_receive(term, msg, strlen(msg));
  }

  if (only_destroy) {
    return;
  }

  if (buf && !is_autocmd_blocked()) {
    save_v_event_T save_v_event;
    dict_T *dict = get_v_event(&save_v_event);
    tv_dict_add_nr(dict, S_LEN("status"), status);
    tv_dict_set_keys_readonly(dict);
    apply_autocmds(EVENT_TERMCLOSE, NULL, NULL, false, buf);
    restore_v_event(dict, &save_v_event);
  }
}

void terminal_check_size(Terminal *term)
{
  if (term->closed) {
    return;
  }

  int curwidth, curheight;
  vterm_get_size(term->vt, &curheight, &curwidth);
  uint16_t width = 0;
  uint16_t height = 0;

  // Check if there is a window that displays the terminal and find the maximum width and height.
  // Skip the autocommand window which isn't actually displayed.
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (is_aucmd_win(wp)) {
      continue;
    }
    if (wp->w_buffer && wp->w_buffer->terminal == term) {
      const uint16_t win_width =
        (uint16_t)(MAX(0, wp->w_width_inner - win_col_off(wp)));
      width = MAX(width, win_width);
      height = (uint16_t)MAX(height, wp->w_height_inner);
    }
  }

  // if no window displays the terminal, or such all windows are zero-height,
  // don't resize the terminal.
  if ((curheight == height && curwidth == width) || height == 0 || width == 0) {
    return;
  }

  vterm_set_size(term->vt, height, width);
  vterm_screen_flush_damage(term->vts);
  term->pending.resize = true;
  invalidate_terminal(term, -1, -1);
}

/// Implements MODE_TERMINAL state. :help Terminal-mode
bool terminal_enter(void)
{
  buf_T *buf = curbuf;
  assert(buf->terminal);  // Should only be called when curbuf has a terminal.
  TerminalState s[1] = { 0 };
  s->term = buf->terminal;
  stop_insert_mode = false;

  // Ensure the terminal is properly sized. Ideally window size management
  // code should always have resized the terminal already, but check here to
  // be sure.
  terminal_check_size(s->term);

  int save_state = State;
  s->save_rd = RedrawingDisabled;
  State = MODE_TERMINAL;
  mapped_ctrl_c |= MODE_TERMINAL;  // Always map CTRL-C to avoid interrupt.
  RedrawingDisabled = false;

  // Disable these options in terminal-mode. They are nonsense because cursor is
  // placed at end of buffer to "follow" output. #11072
  handle_T save_curwin = curwin->handle;
  bool save_w_p_cul = curwin->w_p_cul;
  char *save_w_p_culopt = NULL;
  uint8_t save_w_p_culopt_flags = curwin->w_p_culopt_flags;
  int save_w_p_cuc = curwin->w_p_cuc;
  OptInt save_w_p_so = curwin->w_p_so;
  OptInt save_w_p_siso = curwin->w_p_siso;
  if (curwin->w_p_cul && curwin->w_p_culopt_flags & kOptCuloptFlagNumber) {
    if (strcmp(curwin->w_p_culopt, "number") != 0) {
      save_w_p_culopt = curwin->w_p_culopt;
      curwin->w_p_culopt = xstrdup("number");
    }
    curwin->w_p_culopt_flags = kOptCuloptFlagNumber;
  } else {
    curwin->w_p_cul = false;
  }
  if (curwin->w_p_cuc) {
    redraw_later(curwin, UPD_SOME_VALID);
  }
  curwin->w_p_cuc = false;
  curwin->w_p_so = 0;
  curwin->w_p_siso = 0;

  // Update the cursor shape table and flush changes to the UI
  s->term->pending.cursor = true;
  refresh_cursor(s->term);

  adjust_topline(s->term, buf, 0);  // scroll to end
  showmode();
  curwin->w_redr_status = true;  // For mode() in statusline. #8323
  redraw_custom_title_later();
  if (!s->term->cursor.visible) {
    // Hide cursor if it should be hidden
    ui_busy_start();
  }
  ui_cursor_shape();
  apply_autocmds(EVENT_TERMENTER, NULL, NULL, false, curbuf);
  may_trigger_modechanged();

  // Tell the terminal it has focus
  terminal_focus(s->term, true);

  s->state.execute = terminal_execute;
  s->state.check = terminal_check;
  state_enter(&s->state);

  if (!s->got_bsl_o) {
    restart_edit = 0;
  }
  State = save_state;
  RedrawingDisabled = s->save_rd;
  apply_autocmds(EVENT_TERMLEAVE, NULL, NULL, false, curbuf);

  // Restore the terminal cursor to what is set in 'guicursor'
  (void)parse_shape_opt(SHAPE_CURSOR);

  if (save_curwin == curwin->handle) {  // Else: window was closed.
    curwin->w_p_cul = save_w_p_cul;
    if (save_w_p_culopt) {
      free_string_option(curwin->w_p_culopt);
      curwin->w_p_culopt = save_w_p_culopt;
    }
    curwin->w_p_culopt_flags = save_w_p_culopt_flags;
    curwin->w_p_cuc = save_w_p_cuc;
    curwin->w_p_so = save_w_p_so;
    curwin->w_p_siso = save_w_p_siso;
  } else if (save_w_p_culopt) {
    free_string_option(save_w_p_culopt);
  }

  // Tell the terminal it lost focus
  terminal_focus(s->term, false);

  if (curbuf->terminal == s->term && !s->close) {
    terminal_check_cursor();
  }
  if (restart_edit) {
    showmode();
  } else {
    unshowmode(true);
  }
  if (!s->term->cursor.visible) {
    // If cursor was hidden, show it again
    ui_busy_stop();
  }
  ui_cursor_shape();
  if (s->close) {
    bool wipe = s->term->buf_handle != 0;
    s->term->destroy = true;
    s->term->opts.close_cb(s->term->opts.data);
    if (wipe) {
      do_cmdline_cmd("bwipeout!");
    }
  }

  return s->got_bsl_o;
}

static void terminal_check_cursor(void)
{
  Terminal *term = curbuf->terminal;
  curwin->w_wrow = term->cursor.row;
  curwin->w_wcol = term->cursor.col + win_col_off(curwin);
  curwin->w_cursor.lnum = MIN(curbuf->b_ml.ml_line_count,
                              row_to_linenr(term, term->cursor.row));
  // Nudge cursor when returning to normal-mode.
  int off = is_focused(term) ? 0 : (curwin->w_p_rl ? 1 : -1);
  coladvance(curwin, MAX(0, term->cursor.col + off));
}

// Function executed before each iteration of terminal mode.
// Return:
//   1 if the iteration should continue normally
//   0 if the main loop must exit
static int terminal_check(VimState *state)
{
  if (stop_insert_mode) {
    return 0;
  }

  terminal_check_cursor();
  validate_cursor(curwin);

  if (must_redraw) {
    update_screen();

    // Make sure an invoked autocmd doesn't delete the buffer (and the
    // terminal) under our fingers.
    curbuf->b_locked++;

    // save and restore curwin and curbuf, in case the autocmd changes them
    aco_save_T aco;
    aucmd_prepbuf(&aco, curbuf);
    apply_autocmds(EVENT_TEXTCHANGEDT, NULL, NULL, false, curbuf);
    aucmd_restbuf(&aco);

    curbuf->b_locked--;
  }

  may_trigger_win_scrolled_resized();

  if (need_maketitle) {  // Update title in terminal-mode. #7248
    maketitle();
  }

  setcursor();
  ui_flush();
  return 1;
}

/// Processes one char of terminal-mode input.
static int terminal_execute(VimState *state, int key)
{
  TerminalState *s = (TerminalState *)state;

  // Check for certain control keys like Ctrl-C and Ctrl-\. We still send the
  // unmerged key and modifiers to the terminal.
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
    if (send_mouse_event(s->term, key)) {
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
      return 0;
    }
    break;

  case K_COMMAND:
    do_cmdline(NULL, getcmdkeycmd, NULL, 0);
    break;

  case K_LUA:
    map_execute_lua(false);
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
    if (s->term->closed) {
      s->close = true;
      return 0;
    }

    s->got_bsl = false;
    terminal_send_key(s->term, key);
  }

  if (curbuf->terminal == NULL) {
    return 0;
  }
  if (s->term != curbuf->terminal) {
    // Active terminal buffer changed, flush terminal's cursor state to the UI
    curbuf->terminal->pending.cursor = true;

    if (!s->term->cursor.visible) {
      // If cursor was hidden, show it again
      ui_busy_stop();
    }

    if (!curbuf->terminal->cursor.visible) {
      // Hide cursor if it should be hidden
      ui_busy_start();
    }

    invalidate_terminal(s->term, s->term->cursor.row, s->term->cursor.row + 1);
    invalidate_terminal(curbuf->terminal,
                        curbuf->terminal->cursor.row,
                        curbuf->terminal->cursor.row + 1);
    s->term = curbuf->terminal;
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
    for (size_t i = 0; i < term->sb_current; i++) {
      xfree(term->sb_buffer[i]);
    }
    xfree(term->sb_buffer);
    xfree(term->title);
    xfree(term->selection_buffer);
    kv_destroy(term->selection);
    kv_destroy(term->termrequest_buffer);
    vterm_free(term->vt);
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

void terminal_paste(int count, String *y_array, size_t y_size)
{
  if (y_size == 0) {
    return;
  }
  vterm_keyboard_start_paste(curbuf->terminal->vt);
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
  vterm_keyboard_end_paste(curbuf->terminal->vt);
}

static void terminal_send_key(Terminal *term, int c)
{
  VTermModifier mod = VTERM_MOD_NONE;

  // Convert K_ZERO back to ASCII
  if (c == K_ZERO) {
    c = Ctrl_AT;
  }

  VTermKey key = convert_key(&c, &mod);

  if (key != VTERM_KEY_NONE) {
    vterm_keyboard_key(term->vt, key, mod);
  } else if (!IS_SPECIAL(c)) {
    vterm_keyboard_unichar(term->vt, (uint32_t)c, mod);
  }
}

void terminal_receive(Terminal *term, const char *data, size_t len)
{
  if (!data) {
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

    vterm_input_write(term->vt, crlf_data.items, kv_size(crlf_data));
    kv_destroy(crlf_data);
  } else {
    vterm_input_write(term->vt, data, len);
  }
  vterm_screen_flush_damage(term->vts);
}

static int get_rgb(VTermState *state, VTermColor color)
{
  vterm_state_convert_color_to_rgb(state, &color);
  return RGB_(color.rgb.red, color.rgb.green, color.rgb.blue);
}

static int get_underline_hl_flag(VTermScreenCellAttrs attrs)
{
  switch (attrs.underline) {
  case VTERM_UNDERLINE_OFF:
    return 0;
  case VTERM_UNDERLINE_SINGLE:
    return HL_UNDERLINE;
  case VTERM_UNDERLINE_DOUBLE:
    return HL_UNDERDOUBLE;
  case VTERM_UNDERLINE_CURLY:
    return HL_UNDERCURL;
  default:
    return HL_UNDERLINE;
  }
}

void terminal_get_line_attributes(Terminal *term, win_T *wp, int linenr, int *term_attrs)
{
  int height, width;
  vterm_get_size(term->vt, &height, &width);
  VTermState *state = vterm_obtain_state(term->vt);
  assert(linenr);
  int row = linenr_to_row(term, linenr);
  if (row >= height) {
    // Terminal height was decreased but the change wasn't reflected into the
    // buffer yet
    return;
  }

  width = MIN(TERM_ATTRS_MAX, width);
  for (int col = 0; col < width; col++) {
    VTermScreenCell cell;
    bool color_valid = fetch_cell(term, row, col, &cell);
    bool fg_default = !color_valid || VTERM_COLOR_IS_DEFAULT_FG(&cell.fg);
    bool bg_default = !color_valid || VTERM_COLOR_IS_DEFAULT_BG(&cell.bg);

    // Get the rgb value set by libvterm.
    int vt_fg = fg_default ? -1 : get_rgb(state, cell.fg);
    int vt_bg = bg_default ? -1 : get_rgb(state, cell.bg);

    bool fg_indexed = VTERM_COLOR_IS_INDEXED(&cell.fg);
    bool bg_indexed = VTERM_COLOR_IS_INDEXED(&cell.bg);

    int16_t vt_fg_idx = ((!fg_default && fg_indexed) ? cell.fg.indexed.idx + 1 : 0);
    int16_t vt_bg_idx = ((!bg_default && bg_indexed) ? cell.bg.indexed.idx + 1 : 0);

    bool fg_set = vt_fg_idx && vt_fg_idx <= 16 && term->color_set[vt_fg_idx - 1];
    bool bg_set = vt_bg_idx && vt_bg_idx <= 16 && term->color_set[vt_bg_idx - 1];

    int hl_attrs = (cell.attrs.bold ? HL_BOLD : 0)
                   | (cell.attrs.italic ? HL_ITALIC : 0)
                   | (cell.attrs.reverse ? HL_INVERSE : 0)
                   | get_underline_hl_flag(cell.attrs)
                   | (cell.attrs.strike ? HL_STRIKETHROUGH : 0)
                   | ((fg_indexed && !fg_set) ? HL_FG_INDEXED : 0)
                   | ((bg_indexed && !bg_set) ? HL_BG_INDEXED : 0);

    int attr_id = 0;

    if (hl_attrs || !fg_default || !bg_default) {
      attr_id = hl_get_term_attr(&(HlAttrs) {
        .cterm_ae_attr = (int16_t)hl_attrs,
        .cterm_fg_color = vt_fg_idx,
        .cterm_bg_color = vt_bg_idx,
        .rgb_ae_attr = (int16_t)hl_attrs,
        .rgb_fg_color = vt_fg,
        .rgb_bg_color = vt_bg,
        .rgb_sp_color = -1,
        .hl_blend = -1,
        .url = -1,
      });
    }

    if (cell.uri > 0) {
      attr_id = hl_combine_attr(attr_id, cell.uri);
    }

    term_attrs[col] = attr_id;
  }
}

Buffer terminal_buf(const Terminal *term)
{
  return term->buf_handle;
}

bool terminal_running(const Terminal *term)
{
  return !term->closed;
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

static void terminal_focus(const Terminal *term, bool focus)
  FUNC_ATTR_NONNULL_ALL
{
  VTermState *state = vterm_obtain_state(term->vt);
  if (focus) {
    vterm_state_focus_in(state);
  } else {
    vterm_state_focus_out(state);
  }
}

// }}}
// libvterm callbacks {{{

static int term_damage(VTermRect rect, void *data)
{
  invalidate_terminal(data, rect.start_row, rect.end_row);
  return 1;
}

static int term_moverect(VTermRect dest, VTermRect src, void *data)
{
  invalidate_terminal(data, MIN(dest.start_row, src.start_row),
                      MAX(dest.end_row, src.end_row));
  return 1;
}

static int term_movecursor(VTermPos new_pos, VTermPos old_pos, int visible, void *data)
{
  Terminal *term = data;
  term->cursor.row = new_pos.row;
  term->cursor.col = new_pos.col;
  invalidate_terminal(term, -1, -1);
  return 1;
}

static void buf_set_term_title(buf_T *buf, const char *title, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  Error err = ERROR_INIT;
  dict_set_var(buf->b_vars,
               STATIC_CSTR_AS_STRING("term_title"),
               STRING_OBJ(((String){ .data = (char *)title, .size = len })),
               false,
               false,
               NULL,
               &err);
  api_clear_error(&err);
  status_redraw_buf(buf);
}

static int term_settermprop(VTermProp prop, VTermValue *val, void *data)
{
  Terminal *term = data;

  switch (prop) {
  case VTERM_PROP_ALTSCREEN:
    break;

  case VTERM_PROP_CURSORVISIBLE:
    if (is_focused(term)) {
      if (!val->boolean && term->cursor.visible) {
        // Hide the cursor
        ui_busy_start();
      } else if (val->boolean && !term->cursor.visible) {
        // Unhide the cursor
        ui_busy_stop();
      }
      invalidate_terminal(term, -1, -1);
    }
    term->cursor.visible = val->boolean;
    break;

  case VTERM_PROP_TITLE: {
    buf_T *buf = handle_get_buffer(term->buf_handle);
    VTermStringFragment frag = val->string;

    if (frag.initial && frag.final) {
      buf_set_term_title(buf, frag.str, frag.len);
      break;
    }

    if (frag.initial) {
      term->title_len = 0;
      term->title_size = MAX(frag.len, 1024);
      term->title = xmalloc(sizeof(char *) * term->title_size);
    } else if (term->title_len + frag.len > term->title_size) {
      term->title_size *= 2;
      term->title = xrealloc(term->title, sizeof(char *) * term->title_size);
    }

    memcpy(term->title + term->title_len, frag.str, frag.len);
    term->title_len += frag.len;

    if (frag.final) {
      buf_set_term_title(buf, term->title, term->title_len);
      xfree(term->title);
      term->title = NULL;
    }
    break;
  }

  case VTERM_PROP_MOUSE:
    term->forward_mouse = (bool)val->number;
    break;

  case VTERM_PROP_CURSORBLINK:
    term->cursor.blink = val->boolean;
    term->pending.cursor = true;
    invalidate_terminal(term, -1, -1);
    break;

  case VTERM_PROP_CURSORSHAPE:
    term->cursor.shape = val->number;
    term->pending.cursor = true;
    invalidate_terminal(term, -1, -1);
    break;

  case VTERM_PROP_THEMEUPDATES:
    term->theme_updates = val->boolean;
    break;

  default:
    return 0;
  }

  return 1;
}

/// Called when the terminal wants to ring the system bell.
static int term_bell(void *data)
{
  vim_beep(kOptBoFlagTerm);
  return 1;
}

/// Called when the terminal wants to query the system theme.
static int term_theme(bool *dark, void *data)
  FUNC_ATTR_NONNULL_ALL
{
  *dark = (*p_bg == 'd');
  return 1;
}

/// Scrollback push handler: called just before a line goes offscreen (and libvterm will forget it),
/// giving us a chance to store it.
///
/// Code adapted from pangoterm.
static int term_sb_push(int cols, const VTermScreenCell *cells, void *data)
{
  Terminal *term = data;

  if (!term->sb_size) {
    return 0;
  }

  // copy vterm cells into sb_buffer
  size_t c = (size_t)cols;
  ScrollbackLine *sbrow = NULL;
  if (term->sb_current == term->sb_size) {
    if (term->sb_buffer[term->sb_current - 1]->cols == c) {
      // Recycle old row if it's the right size
      sbrow = term->sb_buffer[term->sb_current - 1];
    } else {
      xfree(term->sb_buffer[term->sb_current - 1]);
    }

    // Make room at the start by shifting to the right.
    memmove(term->sb_buffer + 1, term->sb_buffer,
            sizeof(term->sb_buffer[0]) * (term->sb_current - 1));
  } else if (term->sb_current > 0) {
    // Make room at the start by shifting to the right.
    memmove(term->sb_buffer + 1, term->sb_buffer,
            sizeof(term->sb_buffer[0]) * term->sb_current);
  }

  if (!sbrow) {
    sbrow = xmalloc(sizeof(ScrollbackLine) + c * sizeof(sbrow->cells[0]));
    sbrow->cols = c;
  }

  // New row is added at the start of the storage buffer.
  term->sb_buffer[0] = sbrow;
  if (term->sb_current < term->sb_size) {
    term->sb_current++;
  }

  if (term->sb_pending < (int)term->sb_size) {
    term->sb_pending++;
  }

  memcpy(sbrow->cells, cells, sizeof(cells[0]) * c);
  set_put(ptr_t, &invalidated_terminals, term);

  return 1;
}

/// Scrollback pop handler (from pangoterm).
///
/// @param cols
/// @param cells  VTerm state to update.
/// @param data   Terminal
static int term_sb_pop(int cols, VTermScreenCell *cells, void *data)
{
  Terminal *term = data;

  if (!term->sb_current) {
    return 0;
  }

  if (term->sb_pending) {
    term->sb_pending--;
  }

  ScrollbackLine *sbrow = term->sb_buffer[0];
  term->sb_current--;
  // Forget the "popped" row by shifting the rest onto it.
  memmove(term->sb_buffer, term->sb_buffer + 1,
          sizeof(term->sb_buffer[0]) * (term->sb_current));

  size_t cols_to_copy = MIN((size_t)cols, sbrow->cols);

  // copy to vterm state
  memcpy(cells, sbrow->cells, sizeof(cells[0]) * cols_to_copy);
  for (size_t col = cols_to_copy; col < (size_t)cols; col++) {
    cells[col].schar = 0;
    cells[col].width = 1;
  }

  xfree(sbrow);
  set_put(ptr_t, &invalidated_terminals, term);

  return 1;
}

static void term_clipboard_set(void **argv)
{
  VTermSelectionMask mask = (VTermSelectionMask)(long)argv[0];
  char *data = argv[1];

  char regname;
  switch (mask) {
  case VTERM_SELECTION_CLIPBOARD:
    regname = '+';
    break;
  case VTERM_SELECTION_PRIMARY:
    regname = '*';
    break;
  default:
    regname = '+';
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

static int term_selection_set(VTermSelectionMask mask, VTermStringFragment frag, void *user)
{
  Terminal *term = user;
  if (frag.initial) {
    kv_size(term->selection) = 0;
  }

  kv_concat_len(term->selection, frag.str, frag.len);

  if (frag.final) {
    char *data = xmemdupz(term->selection.items, kv_size(term->selection));
    multiqueue_put(main_loop.events, term_clipboard_set, (void *)mask, data);
  }

  return 1;
}

// }}}
// input handling {{{

static void convert_modifiers(int *key, VTermModifier *statep)
{
  if (mod_mask & MOD_MASK_SHIFT) {
    *statep |= VTERM_MOD_SHIFT;
  }
  if (mod_mask & MOD_MASK_CTRL) {
    *statep |= VTERM_MOD_CTRL;
    if (!(mod_mask & MOD_MASK_SHIFT) && *key >= 'A' && *key <= 'Z') {
      // vterm interprets CTRL+A as SHIFT+CTRL, change to CTRL+a
      *key += ('a' - 'A');
    }
  }
  if (mod_mask & MOD_MASK_ALT) {
    *statep |= VTERM_MOD_ALT;
  }

  switch (*key) {
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
    *statep |= VTERM_MOD_SHIFT;
    break;

  case K_C_LEFT:
  case K_C_RIGHT:
  case K_C_HOME:
  case K_C_END:
    *statep |= VTERM_MOD_CTRL;
    break;
  }
}

static VTermKey convert_key(int *key, VTermModifier *statep)
{
  convert_modifiers(key, statep);

  switch (*key) {
  case K_BS:
    return VTERM_KEY_BACKSPACE;
  case K_S_TAB:
    FALLTHROUGH;
  case TAB:
    return VTERM_KEY_TAB;
  case Ctrl_M:
    return VTERM_KEY_ENTER;
  case ESC:
    return VTERM_KEY_ESCAPE;

  case K_S_UP:
    FALLTHROUGH;
  case K_UP:
    return VTERM_KEY_UP;
  case K_S_DOWN:
    FALLTHROUGH;
  case K_DOWN:
    return VTERM_KEY_DOWN;
  case K_S_LEFT:
    FALLTHROUGH;
  case K_C_LEFT:
    FALLTHROUGH;
  case K_LEFT:
    return VTERM_KEY_LEFT;
  case K_S_RIGHT:
    FALLTHROUGH;
  case K_C_RIGHT:
    FALLTHROUGH;
  case K_RIGHT:
    return VTERM_KEY_RIGHT;

  case K_INS:
    return VTERM_KEY_INS;
  case K_DEL:
    return VTERM_KEY_DEL;
  case K_S_HOME:
    FALLTHROUGH;
  case K_C_HOME:
    FALLTHROUGH;
  case K_HOME:
    return VTERM_KEY_HOME;
  case K_S_END:
    FALLTHROUGH;
  case K_C_END:
    FALLTHROUGH;
  case K_END:
    return VTERM_KEY_END;
  case K_PAGEUP:
    return VTERM_KEY_PAGEUP;
  case K_PAGEDOWN:
    return VTERM_KEY_PAGEDOWN;

  case K_K0:
    FALLTHROUGH;
  case K_KINS:
    return VTERM_KEY_KP_0;
  case K_K1:
    FALLTHROUGH;
  case K_KEND:
    return VTERM_KEY_KP_1;
  case K_K2:
    FALLTHROUGH;
  case K_KDOWN:
    return VTERM_KEY_KP_2;
  case K_K3:
    FALLTHROUGH;
  case K_KPAGEDOWN:
    return VTERM_KEY_KP_3;
  case K_K4:
    FALLTHROUGH;
  case K_KLEFT:
    return VTERM_KEY_KP_4;
  case K_K5:
    FALLTHROUGH;
  case K_KORIGIN:
    return VTERM_KEY_KP_5;
  case K_K6:
    FALLTHROUGH;
  case K_KRIGHT:
    return VTERM_KEY_KP_6;
  case K_K7:
    FALLTHROUGH;
  case K_KHOME:
    return VTERM_KEY_KP_7;
  case K_K8:
    FALLTHROUGH;
  case K_KUP:
    return VTERM_KEY_KP_8;
  case K_K9:
    FALLTHROUGH;
  case K_KPAGEUP:
    return VTERM_KEY_KP_9;
  case K_KDEL:
    FALLTHROUGH;
  case K_KPOINT:
    return VTERM_KEY_KP_PERIOD;
  case K_KENTER:
    return VTERM_KEY_KP_ENTER;
  case K_KPLUS:
    return VTERM_KEY_KP_PLUS;
  case K_KMINUS:
    return VTERM_KEY_KP_MINUS;
  case K_KMULTIPLY:
    return VTERM_KEY_KP_MULT;
  case K_KDIVIDE:
    return VTERM_KEY_KP_DIVIDE;

  case K_S_F1:
    FALLTHROUGH;
  case K_F1:
    return VTERM_KEY_FUNCTION(1);
  case K_S_F2:
    FALLTHROUGH;
  case K_F2:
    return VTERM_KEY_FUNCTION(2);
  case K_S_F3:
    FALLTHROUGH;
  case K_F3:
    return VTERM_KEY_FUNCTION(3);
  case K_S_F4:
    FALLTHROUGH;
  case K_F4:
    return VTERM_KEY_FUNCTION(4);
  case K_S_F5:
    FALLTHROUGH;
  case K_F5:
    return VTERM_KEY_FUNCTION(5);
  case K_S_F6:
    FALLTHROUGH;
  case K_F6:
    return VTERM_KEY_FUNCTION(6);
  case K_S_F7:
    FALLTHROUGH;
  case K_F7:
    return VTERM_KEY_FUNCTION(7);
  case K_S_F8:
    FALLTHROUGH;
  case K_F8:
    return VTERM_KEY_FUNCTION(8);
  case K_S_F9:
    FALLTHROUGH;
  case K_F9:
    return VTERM_KEY_FUNCTION(9);
  case K_S_F10:
    FALLTHROUGH;
  case K_F10:
    return VTERM_KEY_FUNCTION(10);
  case K_S_F11:
    FALLTHROUGH;
  case K_F11:
    return VTERM_KEY_FUNCTION(11);
  case K_S_F12:
    FALLTHROUGH;
  case K_F12:
    return VTERM_KEY_FUNCTION(12);

  case K_F13:
    return VTERM_KEY_FUNCTION(13);
  case K_F14:
    return VTERM_KEY_FUNCTION(14);
  case K_F15:
    return VTERM_KEY_FUNCTION(15);
  case K_F16:
    return VTERM_KEY_FUNCTION(16);
  case K_F17:
    return VTERM_KEY_FUNCTION(17);
  case K_F18:
    return VTERM_KEY_FUNCTION(18);
  case K_F19:
    return VTERM_KEY_FUNCTION(19);
  case K_F20:
    return VTERM_KEY_FUNCTION(20);
  case K_F21:
    return VTERM_KEY_FUNCTION(21);
  case K_F22:
    return VTERM_KEY_FUNCTION(22);
  case K_F23:
    return VTERM_KEY_FUNCTION(23);
  case K_F24:
    return VTERM_KEY_FUNCTION(24);
  case K_F25:
    return VTERM_KEY_FUNCTION(25);
  case K_F26:
    return VTERM_KEY_FUNCTION(26);
  case K_F27:
    return VTERM_KEY_FUNCTION(27);
  case K_F28:
    return VTERM_KEY_FUNCTION(28);
  case K_F29:
    return VTERM_KEY_FUNCTION(29);
  case K_F30:
    return VTERM_KEY_FUNCTION(30);
  case K_F31:
    return VTERM_KEY_FUNCTION(31);
  case K_F32:
    return VTERM_KEY_FUNCTION(32);
  case K_F33:
    return VTERM_KEY_FUNCTION(33);
  case K_F34:
    return VTERM_KEY_FUNCTION(34);
  case K_F35:
    return VTERM_KEY_FUNCTION(35);
  case K_F36:
    return VTERM_KEY_FUNCTION(36);
  case K_F37:
    return VTERM_KEY_FUNCTION(37);
  case K_F38:
    return VTERM_KEY_FUNCTION(38);
  case K_F39:
    return VTERM_KEY_FUNCTION(39);
  case K_F40:
    return VTERM_KEY_FUNCTION(40);
  case K_F41:
    return VTERM_KEY_FUNCTION(41);
  case K_F42:
    return VTERM_KEY_FUNCTION(42);
  case K_F43:
    return VTERM_KEY_FUNCTION(43);
  case K_F44:
    return VTERM_KEY_FUNCTION(44);
  case K_F45:
    return VTERM_KEY_FUNCTION(45);
  case K_F46:
    return VTERM_KEY_FUNCTION(46);
  case K_F47:
    return VTERM_KEY_FUNCTION(47);
  case K_F48:
    return VTERM_KEY_FUNCTION(48);
  case K_F49:
    return VTERM_KEY_FUNCTION(49);
  case K_F50:
    return VTERM_KEY_FUNCTION(50);
  case K_F51:
    return VTERM_KEY_FUNCTION(51);
  case K_F52:
    return VTERM_KEY_FUNCTION(52);
  case K_F53:
    return VTERM_KEY_FUNCTION(53);
  case K_F54:
    return VTERM_KEY_FUNCTION(54);
  case K_F55:
    return VTERM_KEY_FUNCTION(55);
  case K_F56:
    return VTERM_KEY_FUNCTION(56);
  case K_F57:
    return VTERM_KEY_FUNCTION(57);
  case K_F58:
    return VTERM_KEY_FUNCTION(58);
  case K_F59:
    return VTERM_KEY_FUNCTION(59);
  case K_F60:
    return VTERM_KEY_FUNCTION(60);
  case K_F61:
    return VTERM_KEY_FUNCTION(61);
  case K_F62:
    return VTERM_KEY_FUNCTION(62);
  case K_F63:
    return VTERM_KEY_FUNCTION(63);

  default:
    return VTERM_KEY_NONE;
  }
}

static void mouse_action(Terminal *term, int button, int row, int col, bool pressed,
                         VTermModifier mod)
{
  vterm_mouse_move(term->vt, row, col, mod);
  if (button) {
    vterm_mouse_button(term->vt, button, pressed, mod);
  }
}

// process a mouse event while the terminal is focused. return true if the
// terminal should lose focus
static bool send_mouse_event(Terminal *term, int c)
{
  int row = mouse_row;
  int col = mouse_col;
  int grid = mouse_grid;
  win_T *mouse_win = mouse_find_win(&grid, &row, &col);
  if (mouse_win == NULL) {
    goto end;
  }

  int offset;
  if (term->forward_mouse && mouse_win->w_buffer->terminal == term && row >= 0
      && (grid > 1 || row + mouse_win->w_winbar_height < mouse_win->w_height)
      && col >= (offset = win_col_off(mouse_win))
      && (grid > 1 || col < mouse_win->w_width)) {
    // event in the terminal window and mouse events was enabled by the
    // program. translate and forward the event
    int button;
    bool pressed = false;

    switch (c) {
    case K_LEFTDRAG:
    case K_LEFTMOUSE:
      pressed = true; FALLTHROUGH;
    case K_LEFTRELEASE:
      button = 1; break;
    case K_MIDDLEDRAG:
    case K_MIDDLEMOUSE:
      pressed = true; FALLTHROUGH;
    case K_MIDDLERELEASE:
      button = 2; break;
    case K_RIGHTDRAG:
    case K_RIGHTMOUSE:
      pressed = true; FALLTHROUGH;
    case K_RIGHTRELEASE:
      button = 3; break;
    case K_X1DRAG:
    case K_X1MOUSE:
      pressed = true; FALLTHROUGH;
    case K_X1RELEASE:
      button = 8; break;
    case K_X2DRAG:
    case K_X2MOUSE:
      pressed = true; FALLTHROUGH;
    case K_X2RELEASE:
      button = 9; break;
    case K_MOUSEDOWN:
      pressed = true; button = 4; break;
    case K_MOUSEUP:
      pressed = true; button = 5; break;
    case K_MOUSELEFT:
      pressed = true; button = 7; break;
    case K_MOUSERIGHT:
      pressed = true; button = 6; break;
    case K_MOUSEMOVE:
      button = 0; break;
    default:
      return false;
    }

    VTermModifier mod = VTERM_MOD_NONE;
    convert_modifiers(&c, &mod);
    mouse_action(term, button, row, col - offset, pressed, mod);
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

  int len = ins_char_typebuf(vgetc_char, vgetc_mod_mask, true);
  if (KeyTyped) {
    ungetchars(len);
  }
  return true;
}

// }}}
// terminal buffer refresh & misc {{{

static void fetch_row(Terminal *term, int row, int end_col)
{
  int col = 0;
  size_t line_len = 0;
  char *ptr = term->textbuf;

  while (col < end_col) {
    VTermScreenCell cell;
    fetch_cell(term, row, col, &cell);
    if (cell.schar) {
      schar_get_adv(&ptr, cell.schar);
      line_len = (size_t)(ptr - term->textbuf);
    } else {
      *ptr++ = ' ';
    }
    col += cell.width;
  }

  // end of line
  term->textbuf[line_len] = NUL;
}

static bool fetch_cell(Terminal *term, int row, int col, VTermScreenCell *cell)
{
  if (row < 0) {
    ScrollbackLine *sbrow = term->sb_buffer[-row - 1];
    if ((size_t)col < sbrow->cols) {
      *cell = sbrow->cells[col];
    } else {
      // fill the pointer with an empty cell
      *cell = (VTermScreenCell) {
        .schar = 0,
        .width = 1,
      };
      return false;
    }
  } else {
    vterm_screen_get_cell(term->vts, (VTermPos){ .row = row, .col = col },
                          cell);
  }
  return true;
}

// queue a terminal instance for refresh
static void invalidate_terminal(Terminal *term, int start_row, int end_row)
{
  if (start_row != -1 && end_row != -1) {
    term->invalid_start = MIN(term->invalid_start, start_row);
    term->invalid_end = MAX(term->invalid_end, end_row);
  }

  set_put(ptr_t, &invalidated_terminals, term);
  if (!refresh_pending) {
    time_watcher_start(&refresh_timer, refresh_timer_cb, REFRESH_DELAY, 0);
    refresh_pending = true;
  }
}

static void refresh_terminal(Terminal *term)
{
  buf_T *buf = handle_get_buffer(term->buf_handle);
  bool valid = true;
  if (!buf || !(valid = buf_valid(buf))) {
    // Destroyed by `close_buffer`. Do not do anything else.
    if (!valid) {
      term->buf_handle = 0;
    }
    return;
  }
  linenr_T ml_before = buf->b_ml.ml_line_count;

  // refresh_ functions assume the terminal buffer is current
  aco_save_T aco;
  aucmd_prepbuf(&aco, buf);
  refresh_size(term, buf);
  refresh_scrollback(term, buf);
  refresh_screen(term, buf);
  refresh_cursor(term);
  aucmd_restbuf(&aco);

  int ml_added = buf->b_ml.ml_line_count - ml_before;
  adjust_topline(term, buf, ml_added);
}

static void refresh_cursor(Terminal *term)
  FUNC_ATTR_NONNULL_ALL
{
  if (!is_focused(term) || !term->pending.cursor) {
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
  case VTERM_PROP_CURSORSHAPE_BLOCK:
    shape_table[SHAPE_IDX_TERM].shape = SHAPE_BLOCK;
    break;
  case VTERM_PROP_CURSORSHAPE_UNDERLINE:
    shape_table[SHAPE_IDX_TERM].shape = SHAPE_HOR;
    shape_table[SHAPE_IDX_TERM].percentage = 20;
    break;
  case VTERM_PROP_CURSORSHAPE_BAR_LEFT:
    shape_table[SHAPE_IDX_TERM].shape = SHAPE_VER;
    shape_table[SHAPE_IDX_TERM].percentage = 25;
    break;
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
  Terminal *term;
  void *stub; (void)(stub);
  // don't process autocommands while updating terminal buffers
  block_autocmds();
  set_foreach(&invalidated_terminals, term, {
    refresh_terminal(term);
  });
  set_clear(ptr_t, &invalidated_terminals);
  unblock_autocmds();
}

static void refresh_size(Terminal *term, buf_T *buf)
{
  if (!term->pending.resize || term->closed) {
    return;
  }

  term->pending.resize = false;
  int width, height;
  vterm_get_size(term->vt, &height, &width);
  term->invalid_start = 0;
  term->invalid_end = height;
  term->opts.resize_cb((uint16_t)width, (uint16_t)height, term->opts.data);
}

void on_scrollback_option_changed(Terminal *term)
{
  // Scrollback buffer may not exist yet, e.g. if 'scrollback' is set in a TermOpen autocmd.
  if (term->sb_buffer != NULL) {
    refresh_terminal(term);
  }
}

/// Adjusts scrollback storage and the terminal buffer scrollback lines
static void adjust_scrollback(Terminal *term, buf_T *buf)
{
  if (buf->b_p_scbk < 1) {  // Local 'scrollback' was set to -1.
    buf->b_p_scbk = SB_MAX;
  }
  const size_t scbk = (size_t)buf->b_p_scbk;
  assert(term->sb_current < SIZE_MAX);
  if (term->sb_pending > 0) {  // Pending rows must be processed first.
    abort();
  }

  // Delete lines exceeding the new 'scrollback' limit.
  if (scbk < term->sb_current) {
    size_t diff = term->sb_current - scbk;
    for (size_t i = 0; i < diff; i++) {
      ml_delete(1, false);
      term->sb_current--;
      xfree(term->sb_buffer[term->sb_current]);
    }
    deleted_lines(1, (linenr_T)diff);
  }

  // Resize the scrollback storage.
  size_t sb_region = sizeof(ScrollbackLine *) * scbk;
  if (scbk != term->sb_size) {
    term->sb_buffer = xrealloc(term->sb_buffer, sb_region);
  }

  term->sb_size = scbk;
}

// Refresh the scrollback of an invalidated terminal.
static void refresh_scrollback(Terminal *term, buf_T *buf)
{
  int width, height;
  vterm_get_size(term->vt, &height, &width);

  // May still have pending scrollback after increase in terminal height if the
  // scrollback wasn't refreshed in time; append these to the top of the buffer.
  int row_offset = term->sb_pending;
  while (term->sb_pending > 0 && buf->b_ml.ml_line_count < height) {
    fetch_row(term, term->sb_pending - row_offset - 1, width);
    ml_append(0, term->textbuf, 0, false);
    appended_lines(0, 1);
    term->sb_pending--;
  }

  row_offset -= term->sb_pending;
  while (term->sb_pending > 0) {
    // This means that either the window height has decreased or the screen
    // became full and libvterm had to push all rows up. Convert the first
    // pending scrollback row into a string and append it just above the visible
    // section of the buffer
    if (((int)buf->b_ml.ml_line_count - height) >= (int)term->sb_size) {
      // scrollback full, delete lines at the top
      ml_delete(1, false);
      deleted_lines(1, 1);
    }
    fetch_row(term, -term->sb_pending - row_offset, width);
    int buf_index = (int)buf->b_ml.ml_line_count - height;
    ml_append(buf_index, term->textbuf, 0, false);
    appended_lines(buf_index, 1);
    term->sb_pending--;
  }

  // Remove extra lines at the bottom
  int max_line_count = (int)term->sb_current + height;
  while (buf->b_ml.ml_line_count > max_line_count) {
    ml_delete(buf->b_ml.ml_line_count, false);
    deleted_lines(buf->b_ml.ml_line_count, 1);
  }

  adjust_scrollback(term, buf);
}

// Refresh the screen (visible part of the buffer when the terminal is
// focused) of a invalidated terminal
static void refresh_screen(Terminal *term, buf_T *buf)
{
  assert(buf == curbuf);  // TODO(bfredl): remove this condition
  int changed = 0;
  int added = 0;
  int height;
  int width;
  vterm_get_size(term->vt, &height, &width);
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
    fetch_row(term, r, width);

    if (linenr <= buf->b_ml.ml_line_count) {
      ml_replace(linenr, term->textbuf, true);
      changed++;
    } else {
      ml_append(linenr - 1, term->textbuf, 0, false);
      added++;
    }
  }

  int change_start = row_to_linenr(term, term->invalid_start);
  int change_end = change_start + changed;
  changed_lines(buf, change_start, 0, change_end, added, true);
  term->invalid_start = INT_MAX;
  term->invalid_end = -1;
}

static void adjust_topline(Terminal *term, buf_T *buf, int added)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == buf) {
      linenr_T ml_end = buf->b_ml.ml_line_count;
      bool following = ml_end == wp->w_cursor.lnum + added;  // cursor at end?

      if (following || (wp == curwin && is_focused(term))) {
        // "Follow" the terminal output
        wp->w_cursor.lnum = ml_end;
        set_topline(wp, MAX(wp->w_cursor.lnum - wp->w_height_inner + 1, 1));
      } else {
        // Ensure valid cursor for each window displaying this terminal.
        wp->w_cursor.lnum = MIN(wp->w_cursor.lnum, ml_end);
      }
      mb_check_adjust_col(wp);
    }
  }
}

static int row_to_linenr(Terminal *term, int row)
{
  return row != INT_MAX ? row + (int)term->sb_current + 1 : INT_MAX;
}

static int linenr_to_row(Terminal *term, int linenr)
{
  return linenr - (int)term->sb_current - 1;
}

static bool is_focused(Terminal *term)
{
  return State & MODE_TERMINAL && curbuf->terminal == term;
}

static char *get_config_string(char *key)
{
  Error err = ERROR_INIT;
  // Only called from terminal_open where curbuf->terminal is the context.
  Object obj = dict_get_value(curbuf->b_vars, cstr_as_string(key), NULL, &err);
  api_clear_error(&err);
  if (obj.type == kObjectTypeNil) {
    obj = dict_get_value(&globvardict, cstr_as_string(key), NULL, &err);
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
