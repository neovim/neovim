// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

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
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#include <vterm.h>

#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/terminal.h"
#include "nvim/message.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/macros.h"
#include "nvim/mbyte.h"
#include "nvim/buffer.h"
#include "nvim/ascii.h"
#include "nvim/getchar.h"
#include "nvim/ui.h"
#include "nvim/syntax.h"
#include "nvim/screen.h"
#include "nvim/keymap.h"
#include "nvim/edit.h"
#include "nvim/mouse.h"
#include "nvim/memline.h"
#include "nvim/map.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/main.h"
#include "nvim/state.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_cmds.h"
#include "nvim/window.h"
#include "nvim/fileio.h"
#include "nvim/event/loop.h"
#include "nvim/event/time.h"
#include "nvim/os/input.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/handle.h"

typedef struct terminal_state {
  VimState state;
  Terminal *term;
  int save_rd;              // saved value of RedrawingDisabled
  bool close;
  bool got_bsl;             // if the last input was <C-\>
} TerminalState;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "terminal.c.generated.h"
#endif

// Delay for refreshing the terminal buffer after receiving updates from
// libvterm. Improves performance when receiving large bursts of data.
#define REFRESH_DELAY 10

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
  char textbuf[0x1fff];

  ScrollbackLine **sb_buffer;       // Scrollback buffer storage for libvterm
  size_t sb_current;                // number of rows pushed to sb_buffer
  size_t sb_size;                   // sb_buffer size
  // "virtual index" that points to the first sb_buffer row that we need to
  // push to the terminal buffer when refreshing the scrollback. When negative,
  // it actually points to entries that are no longer in sb_buffer (because the
  // window height has increased) and must be deleted from the terminal buffer
  int sb_pending;

  // buf_T instance that acts as a "drawing surface" for libvterm
  // we can't store a direct reference to the buffer because the
  // refresh_timer_cb may be called after the buffer was freed, and there's
  // no way to know if the memory was reused.
  handle_T buf_handle;
  // program exited
  bool closed, destroy;

  // some vterm properties
  bool forward_mouse;
  int invalid_start, invalid_end;   // invalid rows in libvterm screen
  struct {
    int row, col;
    bool visible;
  } cursor;
  int pressed_button;               // which mouse button is pressed
  bool pending_resize;              // pending width/height

  size_t refcount;                  // reference count
};

static VTermScreenCallbacks vterm_screen_callbacks = {
  .damage      = term_damage,
  .moverect    = term_moverect,
  .movecursor  = term_movecursor,
  .settermprop = term_settermprop,
  .bell        = term_bell,
  .sb_pushline = term_sb_push,
  .sb_popline  = term_sb_pop,
};

static PMap(ptr_t) *invalidated_terminals;
static Map(int, int) *color_indexes;
static int default_vt_fg, default_vt_bg;
static VTermColor default_vt_bg_rgb;

void terminal_init(void)
{
  invalidated_terminals = pmap_new(ptr_t)();
  time_watcher_init(&main_loop, &refresh_timer, NULL);
  // refresh_timer_cb will redraw the screen which can call vimscript
  refresh_timer.events = multiqueue_new_child(main_loop.events);

  // initialize a rgb->color index map for cterm attributes(VTermScreenCell
  // only has RGB information and we need color indexes for terminal UIs)
  color_indexes = map_new(int, int)();
  VTerm *vt = vterm_new(24, 80);
  VTermState *state = vterm_obtain_state(vt);

  for (int color_index = 255; color_index >= 0; color_index--) {
    VTermColor color;
    // Some of the default 16 colors has the same color as the later
    // 240 colors. To avoid collisions, we will use the custom colors
    // below in non true color mode.
    if (color_index < 16) {
      color.red = 0;
      color.green = 0;
      color.blue = (uint8_t)(color_index + 1);
    } else {
      vterm_state_get_palette_color(state, color_index, &color);
    }
    map_put(int, int)(color_indexes,
        RGB(color.red, color.green, color.blue), color_index + 1);
  }

  VTermColor fg, bg;
  vterm_state_get_default_colors(state, &fg, &bg);
  default_vt_fg = RGB(fg.red, fg.green, fg.blue);
  default_vt_bg = RGB(bg.red, bg.green, bg.blue);
  default_vt_bg_rgb = bg;
  vterm_free(vt);
}

void terminal_teardown(void)
{
  time_watcher_stop(&refresh_timer);
  multiqueue_free(refresh_timer.events);
  time_watcher_close(&refresh_timer, NULL);
  pmap_free(ptr_t)(invalidated_terminals);
  map_free(int, int)(color_indexes);
}

// public API {{{

Terminal *terminal_open(TerminalOptions opts)
{
  bool true_color = ui_rgb_attached();
  // Create a new terminal instance and configure it
  Terminal *rv = xcalloc(1, sizeof(Terminal));
  rv->opts = opts;
  rv->cursor.visible = true;
  // Associate the terminal instance with the new buffer
  rv->buf_handle = curbuf->handle;
  curbuf->terminal = rv;
  // Create VTerm
  rv->vt = vterm_new(opts.height, opts.width);
  vterm_set_utf8(rv->vt, 1);
  // Setup state
  VTermState *state = vterm_obtain_state(rv->vt);
  // Set up screen
  rv->vts = vterm_obtain_screen(rv->vt);
  vterm_screen_enable_altscreen(rv->vts, true);
  // delete empty lines at the end of the buffer
  vterm_screen_set_callbacks(rv->vts, &vterm_screen_callbacks, rv);
  vterm_screen_set_damage_merge(rv->vts, VTERM_DAMAGE_SCROLL);
  vterm_screen_reset(rv->vts, 1);
  // force a initial refresh of the screen to ensure the buffer will always
  // have as many lines as screen rows when refresh_scrollback is called
  rv->invalid_start = 0;
  rv->invalid_end = opts.height;
  refresh_screen(rv, curbuf);
  set_option_value("buftype", 0, "terminal", OPT_LOCAL);  // -V666

  // Default settings for terminal buffers
  curbuf->b_p_ma = false;     // 'nomodifiable'
  curbuf->b_p_ul = -1;        // 'undolevels'
  curbuf->b_p_scbk = p_scbk;  // 'scrollback'
  curbuf->b_p_tw = 0;         // 'textwidth'
  set_option_value("wrap", false, NULL, OPT_LOCAL);
  set_option_value("list", false, NULL, OPT_LOCAL);
  buf_set_term_title(curbuf, (char *)curbuf->b_ffname);
  RESET_BINDING(curwin);
  // Reset cursor in current window.
  curwin->w_cursor = (pos_T){ .lnum = 1, .col = 0, .coladd = 0 };

  // Apply TermOpen autocmds _before_ configuring the scrollback buffer.
  apply_autocmds(EVENT_TERMOPEN, NULL, NULL, false, curbuf);

  // Configure the scrollback buffer.
  rv->sb_size = curbuf->b_p_scbk < 0
                ? SB_MAX : (size_t)MAX(1, curbuf->b_p_scbk);
  rv->sb_buffer = xmalloc(sizeof(ScrollbackLine *) * rv->sb_size);

  if (!true_color) {
    // Change the first 16 colors so we can easily get the correct color
    // index from them.
    for (int i = 0; i < 16; i++) {
      VTermColor color;
      color.red = 0;
      color.green = 0;
      color.blue = (uint8_t)(i + 1);
      vterm_state_set_palette_color(state, i, &color);
    }
    return rv;
  }

  vterm_state_set_bold_highbright(state, true);

  // Configure the color palette. Try to get the color from:
  //
  // - b:terminal_color_{NUM}
  // - g:terminal_color_{NUM}
  // - the VTerm instance
  for (int i = 0; i < 16; i++) {
    RgbValue color_val = -1;
    char var[64];
    snprintf(var, sizeof(var), "terminal_color_%d", i);
    char *name = get_config_string(var);
    if (name) {
      color_val = name_to_color((uint8_t *)name);
      xfree(name);

      if (color_val != -1) {
        VTermColor color;
        color.red = (uint8_t)((color_val >> 16) & 0xFF);
        color.green = (uint8_t)((color_val >> 8) & 0xFF);
        color.blue = (uint8_t)((color_val >> 0) & 0xFF);
        vterm_state_set_palette_color(state, i, &color);
      }
    }
  }

  return rv;
}

void terminal_close(Terminal *term, char *msg)
{
  if (term->closed) {
    return;
  }

  term->forward_mouse = false;

  // flush any pending changes to the buffer
  if (!exiting) {
    block_autocmds();
    refresh_terminal(term);
    unblock_autocmds();
  }

  buf_T *buf = handle_get_buffer(term->buf_handle);
  term->closed = true;

  if (!msg || exiting) {
    // If no msg was given, this was called by close_buffer(buffer.c).  Or if
    // exiting, we must inform the buffer the terminal no longer exists so that
    // close_buffer() doesn't call this again.
    term->buf_handle = 0;
    if (buf) {
      buf->terminal = NULL;
    }
    if (!term->refcount) {
      // We should not wait for the user to press a key.
      term->opts.close_cb(term->opts.data);
    }
  } else {
    terminal_receive(term, msg, strlen(msg));
  }

  if (buf) {
    apply_autocmds(EVENT_TERMCLOSE, NULL, NULL, false, buf);
  }
}

void terminal_resize(Terminal *term, uint16_t width, uint16_t height)
{
  if (term->closed) {
    // If two windows display the same terminal and one is closed by keypress.
    return;
  }
  bool force = width == UINT16_MAX || height == UINT16_MAX;
  int curwidth, curheight;
  vterm_get_size(term->vt, &curheight, &curwidth);

  if (force || !width) {
    width = (uint16_t)curwidth;
  }

  if (force || !height) {
    height = (uint16_t)curheight;
  }

  if (!force && curheight == height && curwidth == width) {
    return;
  }

  if (height == 0 || width == 0) {
    return;
  }

  vterm_set_size(term->vt, height, width);
  vterm_screen_flush_damage(term->vts);
  term->pending_resize = true;
  invalidate_terminal(term, -1, -1);
}

void terminal_enter(void)
{
  buf_T *buf = curbuf;
  assert(buf->terminal);  // Should only be called when curbuf has a terminal.
  TerminalState state, *s = &state;
  memset(s, 0, sizeof(TerminalState));
  s->term = buf->terminal;

  // Ensure the terminal is properly sized.
  terminal_resize(s->term, 0, 0);

  int save_state = State;
  s->save_rd = RedrawingDisabled;
  State = TERM_FOCUS;
  mapped_ctrl_c |= TERM_FOCUS;  // Always map CTRL-C to avoid interrupt.
  RedrawingDisabled = false;

  // Disable these options in terminal-mode. They are nonsense because cursor is
  // placed at end of buffer to "follow" output.
  win_T *save_curwin = curwin;
  int save_w_p_cul = curwin->w_p_cul;
  int save_w_p_cuc = curwin->w_p_cuc;
  int save_w_p_rnu = curwin->w_p_rnu;
  curwin->w_p_cul = false;
  curwin->w_p_cuc = false;
  curwin->w_p_rnu = false;

  adjust_topline(s->term, buf, 0);  // scroll to end
  // erase the unfocused cursor
  invalidate_terminal(s->term, s->term->cursor.row, s->term->cursor.row + 1);
  showmode();
  ui_busy_start();
  redraw(false);

  s->state.execute = terminal_execute;
  state_enter(&s->state);

  restart_edit = 0;
  State = save_state;
  RedrawingDisabled = s->save_rd;
  if (save_curwin == curwin) {  // save_curwin may be invalid (window closed)!
    curwin->w_p_cul = save_w_p_cul;
    curwin->w_p_cuc = save_w_p_cuc;
    curwin->w_p_rnu = save_w_p_rnu;
  }

  // draw the unfocused cursor
  invalidate_terminal(s->term, s->term->cursor.row, s->term->cursor.row + 1);
  unshowmode(true);
  redraw(curbuf->handle != s->term->buf_handle);
  ui_busy_stop();
  if (s->close) {
    bool wipe = s->term->buf_handle != 0;
    s->term->opts.close_cb(s->term->opts.data);
    if (wipe) {
      do_cmdline_cmd("bwipeout!");
    }
  }
}

static int terminal_execute(VimState *state, int key)
{
  TerminalState *s = (TerminalState *)state;

  switch (key) {
    // Temporary fix until paste events gets implemented
    case K_PASTE:
      break;

    case K_LEFTMOUSE:
    case K_LEFTDRAG:
    case K_LEFTRELEASE:
    case K_MIDDLEMOUSE:
    case K_MIDDLEDRAG:
    case K_MIDDLERELEASE:
    case K_RIGHTMOUSE:
    case K_RIGHTDRAG:
    case K_RIGHTRELEASE:
    case K_MOUSEDOWN:
    case K_MOUSEUP:
      if (send_mouse_event(s->term, key)) {
        return 0;
      }
      break;

    case K_EVENT:
      // We cannot let an event free the terminal yet. It is still needed.
      s->term->refcount++;
      multiqueue_process_events(main_loop.events);
      s->term->refcount--;
      if (s->term->buf_handle == 0) {
        s->close = true;
        return 0;
      }
      break;

    case Ctrl_N:
      if (s->got_bsl) {
        return 0;
      }
      // FALLTHROUGH

    default:
      if (key == Ctrl_BSL && !s->got_bsl) {
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

  return curbuf->handle == s->term->buf_handle;
}

void terminal_destroy(Terminal *term)
{
  buf_T *buf = handle_get_buffer(term->buf_handle);
  if (buf) {
    term->buf_handle = 0;
    buf->terminal = NULL;
  }

  if (!term->refcount) {
    if (pmap_has(ptr_t)(invalidated_terminals, term)) {
      // flush any pending changes to the buffer
      block_autocmds();
      refresh_terminal(term);
      unblock_autocmds();
      pmap_del(ptr_t)(invalidated_terminals, term);
    }
    for (size_t i = 0; i < term->sb_current; i++) {
      xfree(term->sb_buffer[i]);
    }
    xfree(term->sb_buffer);
    vterm_free(term->vt);
    xfree(term);
  }
}

void terminal_send(Terminal *term, char *data, size_t size)
{
  if (term->closed) {
    return;
  }
  term->opts.write_cb(data, size, term->opts.data);
}

void terminal_send_key(Terminal *term, int c)
{
  VTermModifier mod = VTERM_MOD_NONE;

  // Convert K_ZERO back to ASCII
  if (c == K_ZERO) {
    c = Ctrl_AT;
  }

  VTermKey key = convert_key(c, &mod);

  if (key) {
    vterm_keyboard_key(term->vt, key, mod);
  } else {
    vterm_keyboard_unichar(term->vt, (uint32_t)c, mod);
  }

  size_t len = vterm_output_read(term->vt, term->textbuf,
      sizeof(term->textbuf));
  terminal_send(term, term->textbuf, (size_t)len);
}

void terminal_receive(Terminal *term, char *data, size_t len)
{
  if (!data) {
    return;
  }

  vterm_input_write(term->vt, data, len);
  vterm_screen_flush_damage(term->vts);
}

void terminal_get_line_attributes(Terminal *term, win_T *wp, int linenr,
                                  int *term_attrs)
{
  int height, width;
  vterm_get_size(term->vt, &height, &width);
  assert(linenr);
  int row = linenr_to_row(term, linenr);
  if (row >= height) {
    // Terminal height was decreased but the change wasn't reflected into the
    // buffer yet
    return;
  }

  for (int col = 0; col < width; col++) {
    VTermScreenCell cell;
    fetch_cell(term, row, col, &cell);
    // Get the rgb value set by libvterm.
    int vt_fg = RGB(cell.fg.red, cell.fg.green, cell.fg.blue);
    int vt_bg = RGB(cell.bg.red, cell.bg.green, cell.bg.blue);
    vt_fg = vt_fg != default_vt_fg ? vt_fg : - 1;
    vt_bg = vt_bg != default_vt_bg ? vt_bg : - 1;
    // Since libvterm does not expose the color index used by the program, we
    // use the rgb value to find the appropriate index in the cache computed by
    // `terminal_init`.
    int vt_fg_idx = vt_fg != -1 ?
                    map_get(int, int)(color_indexes, vt_fg) : 0;
    int vt_bg_idx = vt_bg != -1 ?
                    map_get(int, int)(color_indexes, vt_bg) : 0;

    int hl_attrs = (cell.attrs.bold ? HL_BOLD : 0)
                 | (cell.attrs.italic ? HL_ITALIC : 0)
                 | (cell.attrs.reverse ? HL_INVERSE : 0)
                 | (cell.attrs.underline ? HL_UNDERLINE : 0);

    int attr_id = 0;

    if (hl_attrs || vt_fg != -1 || vt_bg != -1) {
      attr_id = get_attr_entry(&(HlAttrs) {
        .cterm_ae_attr = (int16_t)hl_attrs,
        .cterm_fg_color = vt_fg_idx,
        .cterm_bg_color = vt_bg_idx,
        .rgb_ae_attr = (int16_t)hl_attrs,
        .rgb_fg_color = vt_fg,
        .rgb_bg_color = vt_bg,
      });
    }

    if (term->cursor.visible && term->cursor.row == row
        && term->cursor.col == col) {
      attr_id = hl_combine_attr(attr_id,
                                is_focused(term) && wp == curwin
                                ? win_hl_attr(wp, HLF_TERM)
                                : win_hl_attr(wp, HLF_TERMNC));
    }

    term_attrs[col] = attr_id;
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

static int term_movecursor(VTermPos new, VTermPos old, int visible,
    void *data)
{
  Terminal *term = data;
  term->cursor.row = new.row;
  term->cursor.col = new.col;
  invalidate_terminal(term, old.row, old.row + 1);
  invalidate_terminal(term, new.row, new.row + 1);
  return 1;
}

static void buf_set_term_title(buf_T *buf, char *title)
  FUNC_ATTR_NONNULL_ALL
{
  Error err = ERROR_INIT;
  dict_set_var(buf->b_vars,
               STATIC_CSTR_AS_STRING("term_title"),
               STRING_OBJ(cstr_as_string(title)),
               false,
               false,
               &err);
  api_clear_error(&err);
}

static int term_settermprop(VTermProp prop, VTermValue *val, void *data)
{
  Terminal *term = data;

  switch (prop) {
    case VTERM_PROP_ALTSCREEN:
      break;

    case VTERM_PROP_CURSORVISIBLE:
      term->cursor.visible = val->boolean;
      invalidate_terminal(term, term->cursor.row, term->cursor.row + 1);
      break;

    case VTERM_PROP_TITLE: {
      buf_T *buf = handle_get_buffer(term->buf_handle);
      buf_set_term_title(buf, val->string);
      break;
    }

    case VTERM_PROP_MOUSE:
      term->forward_mouse = (bool)val->number;
      break;

    default:
      return 0;
  }

  return 1;
}

static int term_bell(void *data)
{
  ui_call_bell();
  return 1;
}

// Scrollback push handler (from pangoterm).
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
  pmap_put(ptr_t)(invalidated_terminals, term, NULL);

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

  size_t cols_to_copy = (size_t)cols;
  if (cols_to_copy > sbrow->cols) {
    cols_to_copy = sbrow->cols;
  }

  // copy to vterm state
  memcpy(cells, sbrow->cells, sizeof(cells[0]) * cols_to_copy);
  for (size_t col = cols_to_copy; col < (size_t)cols; col++) {
    cells[col].chars[0] = 0;
    cells[col].width = 1;
  }

  xfree(sbrow);
  pmap_put(ptr_t)(invalidated_terminals, term, NULL);

  return 1;
}

// }}}
// input handling {{{

static void convert_modifiers(int key, VTermModifier *statep)
{
  if (mod_mask & MOD_MASK_SHIFT) { *statep |= VTERM_MOD_SHIFT; }
  if (mod_mask & MOD_MASK_CTRL)  { *statep |= VTERM_MOD_CTRL; }
  if (mod_mask & MOD_MASK_ALT)   { *statep |= VTERM_MOD_ALT; }

  switch (key) {
    case K_S_TAB:
    case K_S_UP:
    case K_S_DOWN:
    case K_S_LEFT:
    case K_S_RIGHT:
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
      *statep |= VTERM_MOD_CTRL;
      break;
  }
}

static VTermKey convert_key(int key, VTermModifier *statep)
{
  convert_modifiers(key, statep);

  switch (key) {
    case K_BS:        return VTERM_KEY_BACKSPACE;
    case K_S_TAB:     // FALLTHROUGH
    case TAB:         return VTERM_KEY_TAB;
    case Ctrl_M:      return VTERM_KEY_ENTER;
    case ESC:         return VTERM_KEY_ESCAPE;

    case K_S_UP:      // FALLTHROUGH
    case K_UP:        return VTERM_KEY_UP;
    case K_S_DOWN:    // FALLTHROUGH
    case K_DOWN:      return VTERM_KEY_DOWN;
    case K_S_LEFT:    // FALLTHROUGH
    case K_C_LEFT:    // FALLTHROUGH
    case K_LEFT:      return VTERM_KEY_LEFT;
    case K_S_RIGHT:   // FALLTHROUGH
    case K_C_RIGHT:   // FALLTHROUGH
    case K_RIGHT:     return VTERM_KEY_RIGHT;

    case K_INS:       return VTERM_KEY_INS;
    case K_DEL:       return VTERM_KEY_DEL;
    case K_HOME:      return VTERM_KEY_HOME;
    case K_END:       return VTERM_KEY_END;
    case K_PAGEUP:    return VTERM_KEY_PAGEUP;
    case K_PAGEDOWN:  return VTERM_KEY_PAGEDOWN;

    case K_K0:        // FALLTHROUGH
    case K_KINS:      return VTERM_KEY_KP_0;
    case K_K1:        // FALLTHROUGH
    case K_KEND:      return VTERM_KEY_KP_1;
    case K_K2:        return VTERM_KEY_KP_2;
    case K_K3:        // FALLTHROUGH
    case K_KPAGEDOWN: return VTERM_KEY_KP_3;
    case K_K4:        return VTERM_KEY_KP_4;
    case K_K5:        return VTERM_KEY_KP_5;
    case K_K6:        return VTERM_KEY_KP_6;
    case K_K7:        // FALLTHROUGH
    case K_KHOME:     return VTERM_KEY_KP_7;
    case K_K8:        return VTERM_KEY_KP_8;
    case K_K9:        // FALLTHROUGH
    case K_KPAGEUP:   return VTERM_KEY_KP_9;
    case K_KDEL:      // FALLTHROUGH
    case K_KPOINT:    return VTERM_KEY_KP_PERIOD;
    case K_KENTER:    return VTERM_KEY_KP_ENTER;
    case K_KPLUS:     return VTERM_KEY_KP_PLUS;
    case K_KMINUS:    return VTERM_KEY_KP_MINUS;
    case K_KMULTIPLY: return VTERM_KEY_KP_MULT;
    case K_KDIVIDE:   return VTERM_KEY_KP_DIVIDE;

    case K_S_F1:      // FALLTHROUGH
    case K_F1:        return VTERM_KEY_FUNCTION(1);
    case K_S_F2:      // FALLTHROUGH
    case K_F2:        return VTERM_KEY_FUNCTION(2);
    case K_S_F3:      // FALLTHROUGH
    case K_F3:        return VTERM_KEY_FUNCTION(3);
    case K_S_F4:      // FALLTHROUGH
    case K_F4:        return VTERM_KEY_FUNCTION(4);
    case K_S_F5:      // FALLTHROUGH
    case K_F5:        return VTERM_KEY_FUNCTION(5);
    case K_S_F6:      // FALLTHROUGH
    case K_F6:        return VTERM_KEY_FUNCTION(6);
    case K_S_F7:      // FALLTHROUGH
    case K_F7:        return VTERM_KEY_FUNCTION(7);
    case K_S_F8:      // FALLTHROUGH
    case K_F8:        return VTERM_KEY_FUNCTION(8);
    case K_S_F9:      // FALLTHROUGH
    case K_F9:        return VTERM_KEY_FUNCTION(9);
    case K_S_F10:     // FALLTHROUGH
    case K_F10:       return VTERM_KEY_FUNCTION(10);
    case K_S_F11:     // FALLTHROUGH
    case K_F11:       return VTERM_KEY_FUNCTION(11);
    case K_S_F12:     // FALLTHROUGH
    case K_F12:       return VTERM_KEY_FUNCTION(12);

    case K_F13:       return VTERM_KEY_FUNCTION(13);
    case K_F14:       return VTERM_KEY_FUNCTION(14);
    case K_F15:       return VTERM_KEY_FUNCTION(15);
    case K_F16:       return VTERM_KEY_FUNCTION(16);
    case K_F17:       return VTERM_KEY_FUNCTION(17);
    case K_F18:       return VTERM_KEY_FUNCTION(18);
    case K_F19:       return VTERM_KEY_FUNCTION(19);
    case K_F20:       return VTERM_KEY_FUNCTION(20);
    case K_F21:       return VTERM_KEY_FUNCTION(21);
    case K_F22:       return VTERM_KEY_FUNCTION(22);
    case K_F23:       return VTERM_KEY_FUNCTION(23);
    case K_F24:       return VTERM_KEY_FUNCTION(24);
    case K_F25:       return VTERM_KEY_FUNCTION(25);
    case K_F26:       return VTERM_KEY_FUNCTION(26);
    case K_F27:       return VTERM_KEY_FUNCTION(27);
    case K_F28:       return VTERM_KEY_FUNCTION(28);
    case K_F29:       return VTERM_KEY_FUNCTION(29);
    case K_F30:       return VTERM_KEY_FUNCTION(30);
    case K_F31:       return VTERM_KEY_FUNCTION(31);
    case K_F32:       return VTERM_KEY_FUNCTION(32);
    case K_F33:       return VTERM_KEY_FUNCTION(33);
    case K_F34:       return VTERM_KEY_FUNCTION(34);
    case K_F35:       return VTERM_KEY_FUNCTION(35);
    case K_F36:       return VTERM_KEY_FUNCTION(36);
    case K_F37:       return VTERM_KEY_FUNCTION(37);

    default:          return VTERM_KEY_NONE;
  }
}

static void mouse_action(Terminal *term, int button, int row, int col,
    bool drag, VTermModifier mod)
{
  if (term->pressed_button && (term->pressed_button != button || !drag)) {
    // release the previous button
    vterm_mouse_button(term->vt, term->pressed_button, 0, mod);
    term->pressed_button = 0;
  }

  // move the mouse
  vterm_mouse_move(term->vt, row, col, mod);

  if (!term->pressed_button) {
    // press the button if not already pressed
    vterm_mouse_button(term->vt, button, 1, mod);
    term->pressed_button = button;
  }
}

// process a mouse event while the terminal is focused. return true if the
// terminal should lose focus
static bool send_mouse_event(Terminal *term, int c)
{
  int row = mouse_row, col = mouse_col;
  win_T *mouse_win = mouse_find_win(&row, &col);

  if (term->forward_mouse && mouse_win->w_buffer->terminal == term) {
    // event in the terminal window and mouse events was enabled by the
    // program. translate and forward the event
    int button;
    bool drag = false;

    switch (c) {
      case K_LEFTDRAG: drag = true;  // FALLTHROUGH
      case K_LEFTMOUSE: button = 1; break;
      case K_MIDDLEDRAG: drag = true;  // FALLTHROUGH
      case K_MIDDLEMOUSE: button = 2; break;
      case K_RIGHTDRAG: drag = true;  // FALLTHROUGH
      case K_RIGHTMOUSE: button = 3; break;
      case K_MOUSEDOWN: button = 4; break;
      case K_MOUSEUP: button = 5; break;
      default: return false;
    }

    mouse_action(term, button, row, col, drag, 0);
    size_t len = vterm_output_read(term->vt, term->textbuf,
        sizeof(term->textbuf));
    terminal_send(term, term->textbuf, (size_t)len);
    return false;
  }

  if (c == K_MOUSEDOWN || c == K_MOUSEUP) {
    win_T *save_curwin = curwin;
    // switch window/buffer to perform the scroll
    curwin = mouse_win;
    curbuf = curwin->w_buffer;
    int direction = c == K_MOUSEDOWN ? MSCR_DOWN : MSCR_UP;
    if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL)) {
      scroll_redraw(direction, curwin->w_botline - curwin->w_topline);
    } else {
      scroll_redraw(direction, 3L);
    }

    curwin->w_redr_status = true;
    curwin = save_curwin;
    curbuf = curwin->w_buffer;
    redraw_win_later(mouse_win, NOT_VALID);
    invalidate_terminal(term, -1, -1);
    // Only need to exit focus if the scrolled window is the terminal window
    return mouse_win == curwin;
  }

  ins_char_typebuf(c);
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
    int cell_len = 0;
    if (cell.chars[0]) {
      for (int i = 0; cell.chars[i]; i++) {
        cell_len += utf_char2bytes((int)cell.chars[i],
            (uint8_t *)ptr + cell_len);
      }
    } else {
      *ptr = ' ';
      cell_len = 1;
    }
    char c = *ptr;
    ptr += cell_len;
    if (c != ' ') {
      // only increase the line length if the last character is not whitespace
      line_len = (size_t)(ptr - term->textbuf);
    }
    col += cell.width;
  }

  // trim trailing whitespace
  term->textbuf[line_len] = 0;
}

static void fetch_cell(Terminal *term, int row, int col,
    VTermScreenCell *cell)
{
  if (row < 0) {
    ScrollbackLine *sbrow = term->sb_buffer[-row - 1];
    if ((size_t)col < sbrow->cols) {
      *cell = sbrow->cells[col];
    } else {
      // fill the pointer with an empty cell
      *cell = (VTermScreenCell) {
        .chars = { 0 },
        .width = 1,
        .bg = default_vt_bg_rgb
      };
    }
  } else {
    vterm_screen_get_cell(term->vts, (VTermPos){.row = row, .col = col},
        cell);
  }
}

// queue a terminal instance for refresh
static void invalidate_terminal(Terminal *term, int start_row, int end_row)
{
  if (start_row != -1 && end_row != -1) {
    term->invalid_start = MIN(term->invalid_start, start_row);
    term->invalid_end = MAX(term->invalid_end, end_row);
  }

  pmap_put(ptr_t)(invalidated_terminals, term, NULL);
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
  long ml_before = buf->b_ml.ml_line_count;
  WITH_BUFFER(buf, {
    refresh_size(term, buf);
    refresh_scrollback(term, buf);
    refresh_screen(term, buf);
    redraw_buf_later(buf, NOT_VALID);
  });
  long ml_added = buf->b_ml.ml_line_count - ml_before;
  adjust_topline(term, buf, ml_added);
}
// Calls refresh_terminal() on all invalidated_terminals.
static void refresh_timer_cb(TimeWatcher *watcher, void *data)
{
  refresh_pending = false;
  if (exiting  // Cannot redraw (requires event loop) during teardown/exit.
      // WM_LIST (^D) is not redrawn, unlike the normal wildmenu. So we must
      // skip redraws to keep it visible.
      || wild_menu_showing == WM_LIST) {
    return;
  }
  Terminal *term;
  void *stub; (void)(stub);
  // don't process autocommands while updating terminal buffers
  block_autocmds();
  map_foreach(invalidated_terminals, term, stub, {
    refresh_terminal(term);
  });
  bool any_visible = is_term_visible();
  pmap_clear(ptr_t)(invalidated_terminals);
  unblock_autocmds();
  if (any_visible) {
    redraw(true);
  }
}

static void refresh_size(Terminal *term, buf_T *buf)
{
  if (!term->pending_resize || term->closed) {
    return;
  }

  term->pending_resize = false;
  int width, height;
  vterm_get_size(term->vt, &height, &width);
  term->invalid_start = 0;
  term->invalid_end = height;
  term->opts.resize_cb((uint16_t)width, (uint16_t)height, term->opts.data);
}

/// Adjusts scrollback storage after 'scrollback' option changed.
static void on_scrollback_option_changed(Terminal *term, buf_T *buf)
{
  const size_t scbk = curbuf->b_p_scbk < 0
                      ? SB_MAX : (size_t)MAX(1, curbuf->b_p_scbk);
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
    deleted_lines(1, (long)diff);
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
    fetch_row(term, -term->sb_pending, width);
    int buf_index = (int)buf->b_ml.ml_line_count - height;
    ml_append(buf_index, (uint8_t *)term->textbuf, 0, false);
    appended_lines(buf_index, 1);
    term->sb_pending--;
  }

  // Remove extra lines at the bottom
  int max_line_count = (int)term->sb_current + height;
  while (buf->b_ml.ml_line_count > max_line_count) {
    ml_delete(buf->b_ml.ml_line_count, false);
    deleted_lines(buf->b_ml.ml_line_count, 1);
  }

  on_scrollback_option_changed(term, buf);
}

// Refresh the screen (visible part of the buffer when the terminal is
// focused) of a invalidated terminal
static void refresh_screen(Terminal *term, buf_T *buf)
{
  int changed = 0;
  int added = 0;
  int height;
  int width;
  vterm_get_size(term->vt, &height, &width);
  // Terminal height may have decreased before `invalid_end` reflects it.
  term->invalid_end = MIN(term->invalid_end, height);

  for (int r = term->invalid_start, linenr = row_to_linenr(term, r);
       r < term->invalid_end; r++, linenr++) {
    fetch_row(term, r, width);

    if (linenr <= buf->b_ml.ml_line_count) {
      ml_replace(linenr, (uint8_t *)term->textbuf, true);
      changed++;
    } else {
      ml_append(linenr - 1, (uint8_t *)term->textbuf, 0, false);
      added++;
    }
  }

  int change_start = row_to_linenr(term, term->invalid_start);
  int change_end = change_start + changed;
  changed_lines(change_start, 0, change_end, added);
  term->invalid_start = INT_MAX;
  term->invalid_end = -1;
}

/// @return true if any invalidated terminal buffer is visible to the user
static bool is_term_visible(void)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer->terminal
        && pmap_has(ptr_t)(invalidated_terminals, wp->w_buffer->terminal)) {
      return true;
    }
  }
  return false;
}

static void redraw(bool restore_cursor)
{
  Terminal *term = curbuf->terminal;
  if (!term) {
    restore_cursor = true;
  }

  int save_row = 0;
  int save_col = 0;
  if (restore_cursor) {
    // save the current row/col to restore after updating screen when not
    // focused
    save_row = ui_current_row();
    save_col = ui_current_col();
  }
  block_autocmds();

  if (must_redraw) {
    update_screen(0);
  }

  if (need_maketitle) {  // Update title in terminal-mode. #7248
    maketitle();
  }

  if (restore_cursor) {
    ui_cursor_goto(save_row, save_col);
  } else if (term) {
    curwin->w_wrow = term->cursor.row;
    curwin->w_wcol = term->cursor.col + win_col_off(curwin);
    curwin->w_cursor.lnum = MIN(curbuf->b_ml.ml_line_count,
                                row_to_linenr(term, term->cursor.row));
    // Nudge cursor when returning to normal-mode.
    int off = is_focused(term) ? 0 : (curwin->w_p_rl ? 1 : -1);
    curwin->w_cursor.col = MAX(0, term->cursor.col + win_col_off(curwin) + off);
    curwin->w_cursor.coladd = 0;
    mb_check_adjust_col(curwin);
  }

  unblock_autocmds();
  ui_flush();
}

static void adjust_topline(Terminal *term, buf_T *buf, long added)
{
  int height, width;
  vterm_get_size(term->vt, &height, &width);
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf) {
      linenr_T ml_end = buf->b_ml.ml_line_count;
      bool following = ml_end == wp->w_cursor.lnum + added;  // cursor at end?

      if (following || (wp == curwin && is_focused(term))) {
        // "Follow" the terminal output
        wp->w_cursor.lnum = ml_end;
        set_topline(wp, MAX(wp->w_cursor.lnum - height + 1, 1));
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
  return State & TERM_FOCUS && curbuf->terminal == term;
}

#define GET_CONFIG_VALUE(k, o) \
  do { \
    Error err = ERROR_INIT; \
    /* Only called from terminal_open where curbuf->terminal is the */ \
    /* context  */ \
    o = dict_get_value(curbuf->b_vars, cstr_as_string(k), &err); \
    api_clear_error(&err); \
    if (o.type == kObjectTypeNil) { \
      o = dict_get_value(&globvardict, cstr_as_string(k), &err); \
      api_clear_error(&err); \
    } \
  } while (0)

static char *get_config_string(char *key)
{
  Object obj;
  GET_CONFIG_VALUE(key, obj);
  if (obj.type == kObjectTypeString) {
    return obj.data.string.data;
  }
  api_free_object(obj);
  return NULL;
}

// }}}

// vim: foldmethod=marker
