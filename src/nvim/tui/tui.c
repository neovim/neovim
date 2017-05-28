// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Terminal UI functions. Invoked (by ui_bridge.c) on the TUI thread.

#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <limits.h>

#include <uv.h>
#include <unibilium.h>
#if defined(HAVE_TERMIOS_H)
# include <termios.h>
#endif

#include "nvim/lib/kvec.h"

#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/log.h"
#include "nvim/ui.h"
#include "nvim/map.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/event/loop.h"
#include "nvim/event/signal.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/strings.h"
#include "nvim/ui_bridge.h"
#include "nvim/ugrid.h"
#include "nvim/tui/input.h"
#include "nvim/tui/tui.h"
#include "nvim/cursor_shape.h"
#include "nvim/syntax.h"
#include "nvim/macros.h"

// Space reserved in the output buffer to restore the cursor to normal when
// flushing. No existing terminal will require 32 bytes to do that.
#define CNORM_COMMAND_MAX_SIZE 32
#define OUTBUF_SIZE 0xffff

#define TOO_MANY_EVENTS 1000000
#define STARTS_WITH(str, prefix) (!memcmp((str), (prefix), sizeof(prefix) - 1))
#define TMUX_WRAP(is_tmux,seq) ((is_tmux) ? "\x1bPtmux;\x1b" seq "\x1b\\" : seq)
#define LINUXRESETC "\x1b[?0c"

// Per the commentary in terminfo, only a minus sign is a true suffix
// separator.
#define TERMINAL_FAMILY(term, prefix) ((term) \
    && (0 == memcmp((term), (prefix), sizeof(prefix) - 1)) \
    && ('\0' == (term)[sizeof(prefix) - 1] || '-' == (term)[sizeof(prefix) - 1]))

typedef struct {
  int top, bot, left, right;
} Rect;

typedef struct {
  UIBridgeData *bridge;
  Loop *loop;
  bool stop;
  unibi_var_t params[9];
  char buf[OUTBUF_SIZE];
  size_t bufpos, bufsize;
  TermInput input;
  uv_loop_t write_loop;
  unibi_term *ut;
  union {
    uv_tty_t tty;
    uv_pipe_t pipe;
  } output_handle;
  bool out_isatty;
  SignalWatcher winch_handle, cont_handle;
  bool cont_received;
  UGrid grid;
  kvec_t(Rect) invalid_regions;
  int out_fd;
  bool scroll_region_is_full_screen;
  bool can_change_scroll_region;
  bool can_set_lr_margin;
  bool can_set_left_right_margin;
  bool immediate_wrap_after_last_column;
  bool mouse_enabled;
  bool busy;
  cursorentry_T cursor_shapes[SHAPE_IDX_COUNT];
  HlAttrs print_attrs;
  bool default_attr;
  ModeShape showing_mode;
  struct {
    int enable_mouse, disable_mouse;
    int enable_bracketed_paste, disable_bracketed_paste;
    int enable_lr_margin, disable_lr_margin;
    int set_rgb_foreground, set_rgb_background;
    int set_cursor_color;
    int enable_focus_reporting, disable_focus_reporting;
    int resize_screen;
    int reset_scroll_region;
    int set_cursor_style, reset_cursor_style;
  } unibi_ext;
} TUIData;

static bool volatile got_winch = false;
static bool cursor_style_enabled = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/tui.c.generated.h"
#endif


UI *tui_start(void)
{
  UI *ui = xcalloc(1, sizeof(UI));
  ui->stop = tui_stop;
  ui->rgb = p_tgc;
  ui->resize = tui_resize;
  ui->clear = tui_clear;
  ui->eol_clear = tui_eol_clear;
  ui->cursor_goto = tui_cursor_goto;
  ui->mode_info_set = tui_mode_info_set;
  ui->update_menu = tui_update_menu;
  ui->busy_start = tui_busy_start;
  ui->busy_stop = tui_busy_stop;
  ui->mouse_on = tui_mouse_on;
  ui->mouse_off = tui_mouse_off;
  ui->mode_change = tui_mode_change;
  ui->set_scroll_region = tui_set_scroll_region;
  ui->scroll = tui_scroll;
  ui->highlight_set = tui_highlight_set;
  ui->put = tui_put;
  ui->bell = tui_bell;
  ui->visual_bell = tui_visual_bell;
  ui->update_fg = tui_update_fg;
  ui->update_bg = tui_update_bg;
  ui->update_sp = tui_update_sp;
  ui->flush = tui_flush;
  ui->suspend = tui_suspend;
  ui->set_title = tui_set_title;
  ui->set_icon = tui_set_icon;
  ui->event = tui_event;

  memset(ui->ui_ext, 0, sizeof(ui->ui_ext));

  return ui_bridge_attach(ui, tui_main, tui_scheduler);
}

static void terminfo_start(UI *ui)
{
  TUIData *data = ui->data;
  data->scroll_region_is_full_screen = true;
  data->bufpos = 0;
  data->bufsize = sizeof(data->buf) - CNORM_COMMAND_MAX_SIZE;
  data->default_attr = false;
  data->showing_mode = SHAPE_IDX_N;
  data->unibi_ext.enable_mouse = -1;
  data->unibi_ext.disable_mouse = -1;
  data->unibi_ext.set_cursor_color = -1;
  data->unibi_ext.enable_bracketed_paste = -1;
  data->unibi_ext.disable_bracketed_paste = -1;
  data->unibi_ext.enable_lr_margin = -1;
  data->unibi_ext.disable_lr_margin = -1;
  data->unibi_ext.enable_focus_reporting = -1;
  data->unibi_ext.disable_focus_reporting = -1;
  data->unibi_ext.resize_screen = -1;
  data->unibi_ext.reset_scroll_region = -1;
  data->unibi_ext.set_cursor_style = -1;
  data->unibi_ext.reset_cursor_style = -1;
  data->out_fd = 1;
  data->out_isatty = os_isatty(data->out_fd);
  // setup unibilium
  const char *term = os_getenv("TERM");
  data->ut = unibi_from_env();
  if (!data->ut) {
    data->ut = load_builtin_terminfo(term);
  }
  const char *colorterm = os_getenv("COLORTERM");
  const char *termprg = os_getenv("TERM_PROGRAM");
  const char *vte_version_env = os_getenv("VTE_VERSION");
  long vte_version = vte_version_env ? strtol(vte_version_env, NULL, 10) : 0;
  bool iterm = termprg && strstr(termprg, "iTerm.app");
  bool konsole = os_getenv("KONSOLE_PROFILE_NAME")
    || os_getenv("KONSOLE_DBUS_SESSION");
  patch_terminfo_bugs(data, term, colorterm, vte_version, konsole, iterm);
  augment_terminfo(data, term, colorterm, vte_version, konsole, iterm);
  data->can_change_scroll_region =
    !!unibi_get_str(data->ut, unibi_change_scroll_region);
  data->can_set_lr_margin =
    !!unibi_get_str(data->ut, unibi_set_lr_margin);
  data->can_set_left_right_margin =
    !!unibi_get_str(data->ut, unibi_set_left_margin_parm)
    && !!unibi_get_str(data->ut, unibi_set_right_margin_parm);
  data->immediate_wrap_after_last_column =
    TERMINAL_FAMILY(term, "interix");
  // Set 't_Co' from the result of unibilium & fix_terminfo.
  t_colors = unibi_get_num(data->ut, unibi_max_colors);
  // Enter alternate screen and clear
  // NOTE: Do this *before* changing terminal settings. #6433
  unibi_out(ui, unibi_enter_ca_mode);
  unibi_out(ui, unibi_clear_screen);
  // Enable bracketed paste
  unibi_out(ui, data->unibi_ext.enable_bracketed_paste);
  // Enable focus reporting
  unibi_out(ui, data->unibi_ext.enable_focus_reporting);
  uv_loop_init(&data->write_loop);
  if (data->out_isatty) {
    uv_tty_init(&data->write_loop, &data->output_handle.tty, data->out_fd, 0);
#ifdef WIN32
    uv_tty_set_mode(&data->output_handle.tty, UV_TTY_MODE_RAW);
#else
    uv_tty_set_mode(&data->output_handle.tty, UV_TTY_MODE_IO);
#endif
  } else {
    uv_pipe_init(&data->write_loop, &data->output_handle.pipe, 0);
    uv_pipe_open(&data->output_handle.pipe, data->out_fd);
  }
}

static void terminfo_stop(UI *ui)
{
  TUIData *data = ui->data;
  // Destroy output stuff
  tui_mode_change(ui, (String)STRING_INIT, SHAPE_IDX_N);
  tui_mouse_off(ui);
  unibi_out(ui, unibi_exit_attribute_mode);
  // cursor should be set to normal before exiting alternate screen
  unibi_out(ui, unibi_cursor_normal);
  unibi_out(ui, unibi_exit_ca_mode);
  // Disable bracketed paste
  unibi_out(ui, data->unibi_ext.disable_bracketed_paste);
  // Disable focus reporting
  unibi_out(ui, data->unibi_ext.disable_focus_reporting);
  flush_buf(ui, true);
  uv_tty_reset_mode();
  uv_close((uv_handle_t *)&data->output_handle, NULL);
  uv_run(&data->write_loop, UV_RUN_DEFAULT);
  if (uv_loop_close(&data->write_loop)) {
    abort();
  }
  unibi_destroy(data->ut);
}

static void tui_terminal_start(UI *ui)
{
  TUIData *data = ui->data;
  data->print_attrs = EMPTY_ATTRS;
  ugrid_init(&data->grid);
  terminfo_start(ui);
  update_size(ui);
  signal_watcher_start(&data->winch_handle, sigwinch_cb, SIGWINCH);
  term_input_start(&data->input);
}

static void tui_terminal_stop(UI *ui)
{
  TUIData *data = ui->data;
  term_input_stop(&data->input);
  signal_watcher_stop(&data->winch_handle);
  terminfo_stop(ui);
  ugrid_free(&data->grid);
}

static void tui_stop(UI *ui)
{
  tui_terminal_stop(ui);
  TUIData *data = ui->data;
  data->stop = true;
}

// Main function of the TUI thread
static void tui_main(UIBridgeData *bridge, UI *ui)
{
  Loop tui_loop;
  loop_init(&tui_loop, NULL);
  TUIData *data = xcalloc(1, sizeof(TUIData));
  ui->data = data;
  data->bridge = bridge;
  data->loop = &tui_loop;
  kv_init(data->invalid_regions);
  signal_watcher_init(data->loop, &data->winch_handle, ui);
  signal_watcher_init(data->loop, &data->cont_handle, data);
#ifdef UNIX
  signal_watcher_start(&data->cont_handle, sigcont_cb, SIGCONT);
#endif

#if TERMKEY_VERSION_MAJOR > 0 || TERMKEY_VERSION_MINOR > 18
  data->input.tk_ti_hook_fn = tui_tk_ti_getstr;
#endif
  term_input_init(&data->input, &tui_loop);
  tui_terminal_start(ui);
  data->stop = false;

  // allow the main thread to continue, we are ready to start handling UI
  // callbacks
  CONTINUE(bridge);

  while (!data->stop) {
    loop_poll_events(&tui_loop, -1);
  }

  ui_bridge_stopped(bridge);
  term_input_destroy(&data->input);
  signal_watcher_stop(&data->cont_handle);
  signal_watcher_close(&data->cont_handle, NULL);
  signal_watcher_close(&data->winch_handle, NULL);
  loop_close(&tui_loop, false);
  kv_destroy(data->invalid_regions);
  xfree(data);
  xfree(ui);
}

static void tui_scheduler(Event event, void *d)
{
  UI *ui = d;
  TUIData *data = ui->data;
  loop_schedule(data->loop, event);
}

#ifdef UNIX
static void sigcont_cb(SignalWatcher *watcher, int signum, void *data)
{
  ((TUIData *)data)->cont_received = true;
}
#endif

static void sigwinch_cb(SignalWatcher *watcher, int signum, void *data)
{
  got_winch = true;
  UI *ui = data;
  update_size(ui);
  ui_schedule_refresh();
}

static bool attrs_differ(HlAttrs a1, HlAttrs a2)
{
  return a1.foreground != a2.foreground || a1.background != a2.background
    || a1.bold != a2.bold || a1.italic != a2.italic
    || a1.undercurl != a2.undercurl || a1.underline != a2.underline
    || a1.reverse != a2.reverse;
}

static void update_attrs(UI *ui, HlAttrs attrs)
{
  TUIData *data = ui->data;

  if (!attrs_differ(attrs, data->print_attrs)) {
    return;
  }

  data->print_attrs = attrs;
  if (!data->default_attr) {
    data->default_attr = true;
    unibi_out(ui, unibi_exit_attribute_mode);
  }
  UGrid *grid = &data->grid;

  int fg = attrs.foreground != -1 ? attrs.foreground : grid->fg;
  int bg = attrs.background != -1 ? attrs.background : grid->bg;

  if (ui->rgb) {
    if (fg != -1) {
      data->params[0].i = (fg >> 16) & 0xff;  // red
      data->params[1].i = (fg >> 8) & 0xff;   // green
      data->params[2].i = fg & 0xff;          // blue
      unibi_out(ui, data->unibi_ext.set_rgb_foreground);
      data->default_attr = false;
    }

    if (bg != -1) {
      data->params[0].i = (bg >> 16) & 0xff;  // red
      data->params[1].i = (bg >> 8) & 0xff;   // green
      data->params[2].i = bg & 0xff;          // blue
      unibi_out(ui, data->unibi_ext.set_rgb_background);
      data->default_attr = false;
    }
  } else {
    if (fg != -1) {
      data->params[0].i = fg;
      unibi_out(ui, unibi_set_a_foreground);
      data->default_attr = false;
    }

    if (bg != -1) {
      data->params[0].i = bg;
      unibi_out(ui, unibi_set_a_background);
      data->default_attr = false;
    }
  }

  if (attrs.bold) {
    unibi_out(ui, unibi_enter_bold_mode);
    data->default_attr = false;
  }
  if (attrs.italic) {
    unibi_out(ui, unibi_enter_italics_mode);
    data->default_attr = false;
  }
  if (attrs.underline || attrs.undercurl) {
    unibi_out(ui, unibi_enter_underline_mode);
    data->default_attr = false;
  }
  if (attrs.reverse) {
    unibi_out(ui, unibi_enter_reverse_mode);
    data->default_attr = false;
  }
}

static void print_cell(UI *ui, UCell *ptr)
{
  update_attrs(ui, ptr->attrs);
  out(ui, ptr->data, strlen(ptr->data));
}

static bool cheap_to_print(UI *ui, int row, int col, int next)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  UCell *cell = grid->cells[row] + col;
  while (next) {
    --next;
    if (attrs_differ(cell->attrs, data->print_attrs)) {
      if (data->default_attr) {
        return false;
      }
    }
    if (strlen(cell->data) > 1) {
      return false;
    }
    ++cell;
  }
  return true;
}

/// The behaviour that this is checking for the absence of is undocumented,
/// but is implemented in the majority of terminals and terminal emulators.
/// Printing at the right margin does not cause an automatic wrap until the
/// next character is printed, holding the cursor in place until then.
static void check_final_column_wrap(UI *ui)
{
  TUIData *data = ui->data;
  if (!data->immediate_wrap_after_last_column) {
    return;
  }
  UGrid *grid = &data->grid;
  if (grid->col == ui->width) {
    grid->col = 0;
    ++grid->row;
  }
}

/// This optimizes several cases where it is cheaper to do something other
/// than send a full cursor positioning control sequence.  However, there are
/// some further optimizations that may seem obvious but that will not work.
///
/// We cannot use VT (ASCII 0/11) for moving the cursor up, because VT means
/// move the cursor down on a DEC terminal.  Similarly, on a DEC terminal FF
/// (ASCII 0/12) means the same thing and does not mean home.  VT, CVT, and
/// TAB also stop at software-defined tabulation stops, not at a fixed set
/// of row/column positions.
static void cursor_goto(UI *ui, int row, int col)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  if (row == grid->row && col == grid->col) {
    return;
  }
  if (0 == row && 0 == col) {
    unibi_out(ui, unibi_cursor_home);
    ugrid_goto(&data->grid, row, col);
    return;
  }
  if (0 == col ? col != grid->col :
      1 == col ? 2 < grid->col && cheap_to_print(ui, grid->row, 0, col) :
      2 == col ? 5 < grid->col && cheap_to_print(ui, grid->row, 0, col) :
      false) {
    // Motion to left margin from anywhere else, or CR + printing chars is
    // even less expensive than using BSes or CUB.
    unibi_out(ui, unibi_carriage_return);
    ugrid_goto(&data->grid, grid->row, 0);
  } else if (col > grid->col) {
      int n = col - grid->col;
      if (n <= (row == grid->row ? 4 : 2)
          && cheap_to_print(ui, grid->row, grid->col, n)) {
        UGRID_FOREACH_CELL(grid, grid->row, grid->row,
          grid->col, col - 1, {
          print_cell(ui, cell);
          ++grid->col;
          check_final_column_wrap(ui);
        });
      }
  }
  if (row == grid->row) {
    if (col < grid->col) {
      int n = grid->col - col;
      if (n <= 4) { // This might be just BS, so it is considered really cheap.
        while (n--) {
          unibi_out(ui, unibi_cursor_left);
        }
      } else {
        if (!data->immediate_wrap_after_last_column && grid->col >= ui->width) {
          --n;  // We have calculated one too many columns because of delayed wrap.
        }
        data->params[0].i = n;
        unibi_out(ui, unibi_parm_left_cursor);
      }
      ugrid_goto(&data->grid, row, col);
      return;
    } else if (col > grid->col) {
      int n = col - grid->col;
      if (n <= 2) {
        while (n--) {
          unibi_out(ui, unibi_cursor_right);
        }
      } else {
        data->params[0].i = n;
        unibi_out(ui, unibi_parm_right_cursor);
      }
      ugrid_goto(&data->grid, row, col);
      return;
    }
  }
  if (col == grid->col) {
    if (row > grid->row) {
      int n = row - grid->row;
      if (n <= 4) { // This might be just LF, so it is considered really cheap.
        while (n--) {
          unibi_out(ui, unibi_cursor_down);
        }
      } else {
        data->params[0].i = n;
        unibi_out(ui, unibi_parm_down_cursor);
      }
      ugrid_goto(&data->grid, row, col);
      return;
    } else if (row < grid->row) {
      int n = grid->row - row;
      if (n <= 2) {
        while (n--) {
          unibi_out(ui, unibi_cursor_up);
        }
      } else {
        data->params[0].i = n;
        unibi_out(ui, unibi_parm_up_cursor);
      }
      ugrid_goto(&data->grid, row, col);
      return;
    }
  }
  unibi_goto(ui, row, col);
  ugrid_goto(&data->grid, row, col);
}

static void clear_region(UI *ui, int top, int bot, int left, int right)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  int saved_row = grid->row;
  int saved_col = grid->col;

  bool cleared = false;
  if (grid->bg == -1 && right == ui->width -1) {
    // Background is set to the default color and the right edge matches the
    // screen end, try to use terminal codes for clearing the requested area.
    HlAttrs clear_attrs = EMPTY_ATTRS;
    clear_attrs.foreground = grid->fg;
    clear_attrs.background = grid->bg;
    update_attrs(ui, clear_attrs);
    if (left == 0) {
      if (bot == ui->height - 1) {
        if (top == 0) {
          unibi_out(ui, unibi_clear_screen);
          ugrid_goto(&data->grid, top, left);
        } else {
          cursor_goto(ui, top, 0);
          unibi_out(ui, unibi_clr_eos);
        }
        cleared = true;
      }
    }

    if (!cleared) {
      // iterate through each line and clear with clr_eol
      for (int row = top; row <= bot; ++row) {
        cursor_goto(ui, row, left);
        unibi_out(ui, unibi_clr_eol);
      }
      cleared = true;
    }
  }

  if (!cleared) {
    // could not clear using faster terminal codes, refresh the whole region
    UGRID_FOREACH_CELL(grid, top, bot, left, right, {
      cursor_goto(ui, row, col);
      print_cell(ui, cell);
      ++grid->col;
      check_final_column_wrap(ui);
    });
  }

  // restore cursor
  cursor_goto(ui, saved_row, saved_col);
}

static bool can_use_scroll(UI * ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  return data->scroll_region_is_full_screen
    || (data->can_change_scroll_region
        && ((grid->left == 0 && grid->right == ui->width - 1)
            || data->can_set_lr_margin
            || data->can_set_left_right_margin));
}

static void set_scroll_region(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  data->params[0].i = grid->top;
  data->params[1].i = grid->bot;
  unibi_out(ui, unibi_change_scroll_region);
  if (grid->left != 0 || grid->right != ui->width - 1) {
    unibi_out(ui, data->unibi_ext.enable_lr_margin);
    if (data->can_set_lr_margin) {
      data->params[0].i = grid->left;
      data->params[1].i = grid->right;
      unibi_out(ui, unibi_set_lr_margin);
    } else {
      data->params[0].i = grid->left;
      unibi_out(ui, unibi_set_left_margin_parm);
      data->params[0].i = grid->right;
      unibi_out(ui, unibi_set_right_margin_parm);
    }
  }
  unibi_goto(ui, grid->row, grid->col);
}

static void reset_scroll_region(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  if (0 <= data->unibi_ext.reset_scroll_region) {
    unibi_out(ui, data->unibi_ext.reset_scroll_region);
  } else {
    data->params[0].i = 0;
    data->params[1].i = ui->height - 1;
    unibi_out(ui, unibi_change_scroll_region);
  }
  if (grid->left != 0 || grid->right != ui->width - 1) {
    if (data->can_set_lr_margin) {
      data->params[0].i = 0;
      data->params[1].i = ui->width - 1;
      unibi_out(ui, unibi_set_lr_margin);
    } else {
      data->params[0].i = 0;
      unibi_out(ui, unibi_set_left_margin_parm);
      data->params[0].i = ui->width - 1;
      unibi_out(ui, unibi_set_right_margin_parm);
    }
    unibi_out(ui, data->unibi_ext.disable_lr_margin);
  }
  unibi_goto(ui, grid->row, grid->col);
}

static void tui_resize(UI *ui, Integer width, Integer height)
{
  TUIData *data = ui->data;
  ugrid_resize(&data->grid, (int)width, (int)height);

  if (!got_winch) {  // Try to resize the terminal window.
    data->params[0].i = (int)height;
    data->params[1].i = (int)width;
    unibi_out(ui, data->unibi_ext.resize_screen);
    // DECSLPP does not reset the scroll region.
    if (data->scroll_region_is_full_screen) {
      reset_scroll_region(ui);
    }
  } else {  // Already handled the SIGWINCH signal; avoid double-resize.
    got_winch = false;
  }
}

static void tui_clear(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_clear(grid);
  clear_region(ui, grid->top, grid->bot, grid->left, grid->right);
}

static void tui_eol_clear(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_eol_clear(grid);
  clear_region(ui, grid->row, grid->row, grid->col, grid->right);
}

static void tui_cursor_goto(UI *ui, Integer row, Integer col)
{
  cursor_goto(ui, (int)row, (int)col);
}

CursorShape tui_cursor_decode_shape(const char *shape_str)
{
  CursorShape shape = 0;
  if (strequal(shape_str, "block")) {
    shape = SHAPE_BLOCK;
  } else if (strequal(shape_str, "vertical")) {
    shape = SHAPE_VER;
  } else if (strequal(shape_str, "horizontal")) {
    shape = SHAPE_HOR;
  } else {
    EMSG2(_(e_invarg2), shape_str);
  }
  return shape;
}

static cursorentry_T decode_cursor_entry(Dictionary args)
{
  cursorentry_T r;

  for (size_t i = 0; i < args.size; i++) {
    char *key = args.items[i].key.data;
    Object value = args.items[i].value;

    if (strequal(key, "cursor_shape")) {
      r.shape = tui_cursor_decode_shape(args.items[i].value.data.string.data);
    } else if (strequal(key, "blinkon")) {
      r.blinkon = (int)value.data.integer;
    } else if (strequal(key, "blinkoff")) {
      r.blinkoff = (int)value.data.integer;
    } else if (strequal(key, "hl_id")) {
      r.id = (int)value.data.integer;
    }
  }
  return r;
}

static void tui_mode_info_set(UI *ui, bool guicursor_enabled, Array args)
{
  cursor_style_enabled = guicursor_enabled;
  if (!guicursor_enabled) {
    return;  // Do not send cursor style control codes.
  }
  TUIData *data = ui->data;

  assert(args.size);

  // cursor style entries as defined by `shape_table`.
  for (size_t i = 0; i < args.size; i++) {
    assert(args.items[i].type == kObjectTypeDictionary);
    cursorentry_T r = decode_cursor_entry(args.items[i].data.dictionary);
    data->cursor_shapes[i] = r;
  }

  tui_set_mode(ui, data->showing_mode);
}

static void tui_update_menu(UI *ui)
{
    // Do nothing; menus are for GUI only
}

static void tui_busy_start(UI *ui)
{
  ((TUIData *)ui->data)->busy = true;
}

static void tui_busy_stop(UI *ui)
{
  ((TUIData *)ui->data)->busy = false;
}

static void tui_mouse_on(UI *ui)
{
  TUIData *data = ui->data;
  if (!data->mouse_enabled) {
    unibi_out(ui, data->unibi_ext.enable_mouse);
    data->mouse_enabled = true;
  }
}

static void tui_mouse_off(UI *ui)
{
  TUIData *data = ui->data;
  if (data->mouse_enabled) {
    unibi_out(ui, data->unibi_ext.disable_mouse);
    data->mouse_enabled = false;
  }
}

static void tui_set_mode(UI *ui, ModeShape mode)
{
  if (!cursor_style_enabled) {
    return;
  }
  TUIData *data = ui->data;
  cursorentry_T c = data->cursor_shapes[mode];
  int shape = c.shape;

  if (c.id != 0 && ui->rgb) {
    int attr = syn_id2attr(c.id);
    if (attr > 0) {
      attrentry_T *aep = syn_cterm_attr2entry(attr);
      data->params[0].i = aep->rgb_bg_color;
      unibi_out(ui, data->unibi_ext.set_cursor_color);
    }
  }

  switch (shape) {
    case SHAPE_BLOCK: shape = 1; break;
    case SHAPE_HOR:   shape = 3; break;
    case SHAPE_VER:   shape = 5; break;
    default: WLOG("Unknown shape value %d", shape); break;
  }
  data->params[0].i = shape + (int)(c.blinkon == 0);
  unibi_out(ui, data->unibi_ext.set_cursor_style);
}

/// @param mode editor mode
static void tui_mode_change(UI *ui, String mode, Integer mode_idx)
{
  TUIData *data = ui->data;
  tui_set_mode(ui, (ModeShape)mode_idx);
  data->showing_mode = (ModeShape)mode_idx;
}

static void tui_set_scroll_region(UI *ui, Integer top, Integer bot,
                                  Integer left, Integer right)
{
  TUIData *data = ui->data;
  ugrid_set_scroll_region(&data->grid, (int)top, (int)bot,
                          (int)left, (int)right);
  data->scroll_region_is_full_screen =
    left == 0 && right == ui->width - 1
    && top == 0 && bot == ui->height - 1;
}

static void tui_scroll(UI *ui, Integer count)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  int clear_top, clear_bot;
  ugrid_scroll(grid, (int)count, &clear_top, &clear_bot);

  if (can_use_scroll(ui)) {
    int saved_row = grid->row;
    int saved_col = grid->col;
    bool scroll_clears_to_current_colour =
      unibi_get_bool(data->ut, unibi_back_color_erase);

    // Change terminal scroll region and move cursor to the top
    if (!data->scroll_region_is_full_screen) {
      set_scroll_region(ui);
    }
    cursor_goto(ui, grid->top, grid->left);
    // also set default color attributes or some terminals can become funny
    if (scroll_clears_to_current_colour) {
      HlAttrs clear_attrs = EMPTY_ATTRS;
      clear_attrs.foreground = grid->fg;
      clear_attrs.background = grid->bg;
      update_attrs(ui, clear_attrs);
    }

    if (count > 0) {
      if (count == 1) {
        unibi_out(ui, unibi_delete_line);
      } else {
        data->params[0].i = (int)count;
        unibi_out(ui, unibi_parm_delete_line);
      }
    } else {
      if (count == -1) {
        unibi_out(ui, unibi_insert_line);
      } else {
        data->params[0].i = -(int)count;
        unibi_out(ui, unibi_parm_insert_line);
      }
    }

    // Restore terminal scroll region and cursor
    if (!data->scroll_region_is_full_screen) {
      reset_scroll_region(ui);
    }
    cursor_goto(ui, saved_row, saved_col);

    if (!scroll_clears_to_current_colour) {
      // This is required because scrolling will leave wrong background in the
      // cleared area on non-bge terminals.
      clear_region(ui, clear_top, clear_bot, grid->left, grid->right);
    }
  } else {
    // Mark the entire scroll region as invalid for redrawing later
    invalidate(ui, grid->top, grid->bot, grid->left, grid->right);
  }
}

static void tui_highlight_set(UI *ui, HlAttrs attrs)
{
  ((TUIData *)ui->data)->grid.attrs = attrs;
}

static void tui_put(UI *ui, String text)
{
  TUIData *data = ui->data;
  print_cell(ui, ugrid_put(&data->grid, (uint8_t *)text.data, text.size));
  check_final_column_wrap(ui);
}

static void tui_bell(UI *ui)
{
  unibi_out(ui, unibi_bell);
}

static void tui_visual_bell(UI *ui)
{
  unibi_out(ui, unibi_flash_screen);
}

static void tui_update_fg(UI *ui, Integer fg)
{
  ((TUIData *)ui->data)->grid.fg = (int)fg;
}

static void tui_update_bg(UI *ui, Integer bg)
{
  ((TUIData *)ui->data)->grid.bg = (int)bg;
}

static void tui_update_sp(UI *ui, Integer sp)
{
  // Do nothing; 'special' color is for GUI only
}

static void tui_flush(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  size_t nrevents = loop_size(data->loop);
  if (nrevents > TOO_MANY_EVENTS) {
    ILOG("TUI event-queue flooded (thread_events=%zu); purging", nrevents);
    // Back-pressure: UI events may accumulate much faster than the terminal
    // device can serve them. Even if SIGINT/CTRL-C is received, user must still
    // wait for the TUI event-queue to drain, and if there are ~millions of
    // events in the queue, it could take hours. Clearing the queue allows the
    // UI to recover. #1234 #5396
    loop_purge(data->loop);
    tui_busy_stop(ui);  // avoid hidden cursor
  }

  int saved_row = grid->row;
  int saved_col = grid->col;

  while (kv_size(data->invalid_regions)) {
    Rect r = kv_pop(data->invalid_regions);
    UGRID_FOREACH_CELL(grid, r.top, r.bot, r.left, r.right, {
      cursor_goto(ui, row, col);
      print_cell(ui, cell);
      ++grid->col;
      check_final_column_wrap(ui);
    });
  }

  cursor_goto(ui, saved_row, saved_col);

  flush_buf(ui, true);
}

#ifdef UNIX
static void suspend_event(void **argv)
{
  UI *ui = argv[0];
  TUIData *data = ui->data;
  bool enable_mouse = data->mouse_enabled;
  tui_terminal_stop(ui);
  data->cont_received = false;
  stream_set_blocking(input_global_fd(), true);   // normalize stream (#2598)
  kill(0, SIGTSTP);
  while (!data->cont_received) {
    // poll the event loop until SIGCONT is received
    loop_poll_events(data->loop, -1);
  }
  tui_terminal_start(ui);
  if (enable_mouse) {
    tui_mouse_on(ui);
  }
  stream_set_blocking(input_global_fd(), false);  // libuv expects this
  // resume the main thread
  CONTINUE(data->bridge);
}
#endif

static void tui_suspend(UI *ui)
{
#ifdef UNIX
  TUIData *data = ui->data;
  // kill(0, SIGTSTP) won't stop the UI thread, so we must poll for SIGCONT
  // before continuing. This is done in another callback to avoid
  // loop_poll_events recursion
  multiqueue_put_event(data->loop->fast_events,
                       event_create(suspend_event, 1, ui));
#endif
}

static void tui_set_title(UI *ui, String title)
{
  TUIData *data = ui->data;
  if (!(title.data && unibi_get_str(data->ut, unibi_to_status_line)
        && unibi_get_str(data->ut, unibi_from_status_line))) {
    return;
  }
  unibi_out(ui, unibi_to_status_line);
  out(ui, title.data, title.size);
  unibi_out(ui, unibi_from_status_line);
}

static void tui_set_icon(UI *ui, String icon)
{
}

// NB: if we start to use this, the ui_bridge must be updated
// to make a copy for the tui thread
static void tui_event(UI *ui, char *name, Array args, bool *args_consumed)
{
}

static void invalidate(UI *ui, int top, int bot, int left, int right)
{
  TUIData *data = ui->data;
  Rect *intersects = NULL;
  // Increase dimensions before comparing to ensure adjacent regions are
  // treated as intersecting
  --top;
  ++bot;
  --left;
  ++right;

  for (size_t i = 0; i < kv_size(data->invalid_regions); i++) {
    Rect *r = &kv_A(data->invalid_regions, i);
    if (!(top > r->bot || bot < r->top
          || left > r->right || right < r->left)) {
      intersects = r;
      break;
    }
  }

  ++top;
  --bot;
  ++left;
  --right;

  if (intersects) {
    // If top/bot/left/right intersects with a invalid rect, we replace it
    // by the union
    intersects->top = MIN(top, intersects->top);
    intersects->bot = MAX(bot, intersects->bot);
    intersects->left = MIN(left, intersects->left);
    intersects->right = MAX(right, intersects->right);
  } else {
    // Else just add a new entry;
    kv_push(data->invalid_regions, ((Rect) { top, bot, left, right }));
  }
}

static void update_size(UI *ui)
{
  TUIData *data = ui->data;
  int width = 0, height = 0;

  // 1 - look for non-default 'columns' and 'lines' options during startup
  if (starting != 0 && (Columns != DFLT_COLS || Rows != DFLT_ROWS)) {
    assert(Columns >= INT_MIN && Columns <= INT_MAX);
    assert(Rows >= INT_MIN && Rows <= INT_MAX);
    width = (int)Columns;
    height = (int)Rows;
    goto end;
  }

  // 2 - try from a system call(ioctl/TIOCGWINSZ on unix)
  if (data->out_isatty
      && !uv_tty_get_winsize(&data->output_handle.tty, &width, &height)) {
    goto end;
  }

  // 3 - use $LINES/$COLUMNS if available
  const char *val;
  int advance;
  if ((val = os_getenv("LINES"))
      && sscanf(val, "%d%n", &height, &advance) != EOF && advance
      && (val = os_getenv("COLUMNS"))
      && sscanf(val, "%d%n", &width, &advance) != EOF && advance) {
    goto end;
  }

  // 4 - read from terminfo if available
  height = unibi_get_num(data->ut, unibi_lines);
  width = unibi_get_num(data->ut, unibi_columns);

end:
  if (width <= 0 || height <= 0) {
    // use the defaults
    width = DFLT_COLS;
    height = DFLT_ROWS;
  }

  data->bridge->bridge.width = ui->width = width;
  data->bridge->bridge.height = ui->height = height;
}

static void unibi_goto(UI *ui, int row, int col)
{
  TUIData *data = ui->data;
  data->params[0].i = row;
  data->params[1].i = col;
  unibi_out(ui, unibi_cursor_address);
}

static void unibi_out(UI *ui, int unibi_index)
{
  TUIData *data = ui->data;

  const char *str = NULL;

  if (unibi_index >= 0) {
    if (unibi_index < unibi_string_begin_) {
      str = unibi_get_ext_str(data->ut, (unsigned)unibi_index);
    } else {
      str = unibi_get_str(data->ut, (unsigned)unibi_index);
    }
  }

  if (str) {
    unibi_var_t vars[26 + 26] = {{0}};
    unibi_format(vars, vars + 26, str, data->params, out, ui, NULL, NULL);
  }
}

static void out(void *ctx, const char *str, size_t len)
{
  UI *ui = ctx;
  TUIData *data = ui->data;
  size_t available = data->bufsize - data->bufpos;

  if (len > available) {
    flush_buf(ui, false);
  }

  memcpy(data->buf + data->bufpos, str, len);
  data->bufpos += len;
}

static void unibi_set_if_empty(unibi_term *ut, enum unibi_string str,
    const char *val)
{
  if (!unibi_get_str(ut, str)) {
    unibi_set_str(ut, str, val);
  }
}

static int unibi_find_ext_str(unibi_term *ut, const char *name)
{
  size_t max = unibi_count_ext_str(ut);
  for (size_t i = 0; i < max; ++i) {
    const char * n = unibi_get_ext_str_name(ut, i);
    if (n && 0 == strcmp(n, name)) {
      return (int)i;
    }
  }
  return -1;
}

// One creates the dumps from terminfo.src by using
//      od -t d1 -w
// on the compiled files.

// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
// This is a 256-colour terminfo description that lacks true-colour and
// DECSTBN/DECSLRM/DECLRMM capabilities that xterm actually has.
static const char xterm_256colour_terminfo[] = {
  26,   1,  37,   0,  29,   0,  15,   0, 105,   1, -42,   5, 120, 116, 101, 114,
 109,  45,  50,  53,  54,  99, 111, 108, 111, 114, 124, 120, 116, 101, 114, 109,
  32, 119, 105, 116, 104,  32,  50,  53,  54,  32,  99, 111, 108, 111, 114, 115,
   0,   0,   1,   0,   0,   1,   0,   0,   0,   1,   0,   0,   0,   0,   1,   1,
   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,   0,   1,   1,  80,   0,
   8,   0,  24,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,   0,   1,  -1, 127,   0,   0,   4,   0,
   6,   0,   8,   0,  25,   0,  30,   0,  38,   0,  42,   0,  46,   0,  -1,  -1,
  57,   0,  74,   0,  76,   0,  80,   0,  87,   0,  -1,  -1,  89,   0, 102,   0,
  -1,  -1, 106,   0, 110,   0, 120,   0, 124,   0,  -1,  -1,  -1,  -1,-128,   0,
-124,   0,-119,   0,-114,   0,  -1,  -1,-105,   0,-100,   0, -95,   0,  -1,  -1,
 -90,   0, -85,   0, -80,   0, -75,   0, -66,   0, -62,   0, -55,   0,  -1,  -1,
 -46,   0, -41,   0, -35,   0, -29,   0,  -1,  -1,  -1,  -1,  -1,  -1, -11,   0,
  -1,  -1,  -1,  -1,  -1,  -1,   7,   1,  -1,  -1,  11,   1,  -1,  -1,  -1,  -1,
  -1,  -1,  13,   1,  -1,  -1,  18,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  22,   1,  26,   1,  32,   1,  36,   1,  40,   1,  44,   1,  50,   1,  56,   1,
  62,   1,  68,   1,  74,   1,  78,   1,  -1,  -1,  83,   1,  -1,  -1,  87,   1,
  92,   1,  97,   1, 101,   1, 108,   1,  -1,  -1, 115,   1, 119,   1, 127,   1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,-121,   1,-112,   1,  -1,  -1,  -1,  -1,-103,   1,
 -94,   1, -85,   1, -76,   1, -67,   1, -58,   1, -49,   1, -40,   1, -31,   1,
 -22,   1,  -1,  -1,  -1,  -1,  -1,  -1, -13,   1,  -9,   1,  -4,   1,  -1,  -1,
   1,   2,  10,   2,  -1,  -1,  -1,  -1,  28,   2,  31,   2,  42,   2,  45,   2,
  47,   2,  50,   2,-113,   2,  -1,  -1,-110,   2,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,-108,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
-104,   2,  -1,  -1, -51,   2,  -1,  -1,  -1,  -1, -47,   2, -41,   2,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, -35,   2, -31,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -27,   2,  -1,  -1,  -1,  -1,
 -20,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -13,   2,  -6,   2,   1,   3,
  -1,  -1,  -1,  -1,   8,   3,  -1,  -1,  15,   3,  -1,  -1,  -1,  -1,  -1,  -1,
  22,   3,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  29,   3,  35,   3,
  41,   3,  48,   3,  55,   3,  62,   3,  69,   3,  77,   3,  85,   3,  93,   3,
 101,   3, 109,   3, 117,   3, 125,   3,-123,   3,-116,   3,-109,   3,-102,   3,
 -95,   3, -87,   3, -79,   3, -71,   3, -63,   3, -55,   3, -47,   3, -39,   3,
 -31,   3, -24,   3, -17,   3, -10,   3,  -3,   3,   5,   4,  13,   4,  21,   4,
  29,   4,  37,   4,  45,   4,  53,   4,  61,   4,  68,   4,  75,   4,  82,   4,
  89,   4,  97,   4, 105,   4, 113,   4, 121,   4,-127,   4,-119,   4,-111,   4,
-103,   4, -96,   4, -89,   4, -82,   4,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1, -77,   4, -66,   4, -61,   4, -42,   4, -38,   4,
 -29,   4, -22,   4,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  72,   5,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  77,   5,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  83,   5,  -1,  -1,  -1,  -1,  -1,  -1,  87,   5,-106,   5,  27,  91,
  90,   0,   7,   0,  13,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  59,
  37, 112,  50,  37, 100, 114,   0,  27,  91,  51, 103,   0,  27,  91,  72,  27,
  91,  50,  74,   0,  27,  91,  75,   0,  27,  91,  74,   0,  27,  91,  37, 105,
  37, 112,  49,  37, 100,  71,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,
  59,  37, 112,  50,  37, 100,  72,   0,  10,   0,  27,  91,  72,   0,  27,  91,
  63,  50,  53, 108,   0,   8,   0,  27,  91,  63,  49,  50, 108,  27,  91,  63,
  50,  53, 104,   0,  27,  91,  67,   0,  27,  91,  65,   0,  27,  91,  63,  49,
  50,  59,  50,  53, 104,   0,  27,  91,  80,   0,  27,  91,  77,   0,  27,  40,
  48,   0,  27,  91,  53, 109,   0,  27,  91,  49, 109,   0,  27,  91,  63,  49,
  48,  52,  57, 104,   0,  27,  91,  50, 109,   0,  27,  91,  52, 104,   0,  27,
  91,  56, 109,   0,  27,  91,  55, 109,   0,  27,  91,  55, 109,   0,  27,  91,
  52, 109,   0,  27,  91,  37, 112,  49,  37, 100,  88,   0,  27,  40,  66,   0,
  27,  40,  66,  27,  91, 109,   0,  27,  91,  63,  49,  48,  52,  57, 108,   0,
  27,  91,  52, 108,   0,  27,  91,  50,  55, 109,   0,  27,  91,  50,  52, 109,
   0,  27,  91,  63,  53, 104,  36,  60,  49,  48,  48,  47,  62,  27,  91,  63,
  53, 108,   0,  27,  91,  33, 112,  27,  91,  63,  51,  59,  52, 108,  27,  91,
  52, 108,  27,  62,   0,  27,  91,  76,   0,   8,   0,  27,  91,  51, 126,   0,
  27,  79,  66,   0,  27,  79,  80,   0,  27,  91,  50,  49, 126,   0,  27,  79,
  81,   0,  27,  79,  82,   0,  27,  79,  83,   0,  27,  91,  49,  53, 126,   0,
  27,  91,  49,  55, 126,   0,  27,  91,  49,  56, 126,   0,  27,  91,  49,  57,
 126,   0,  27,  91,  50,  48, 126,   0,  27,  79,  72,   0,  27,  91,  50, 126,
   0,  27,  79,  68,   0,  27,  91,  54, 126,   0,  27,  91,  53, 126,   0,  27,
  79,  67,   0,  27,  91,  49,  59,  50,  66,   0,  27,  91,  49,  59,  50,  65,
   0,  27,  79,  65,   0,  27,  91,  63,  49, 108,  27,  62,   0,  27,  91,  63,
  49, 104,  27,  61,   0,  27,  91,  63,  49,  48,  51,  52, 108,   0,  27,  91,
  63,  49,  48,  51,  52, 104,   0,  27,  91,  37, 112,  49,  37, 100,  80,   0,
  27,  91,  37, 112,  49,  37, 100,  77,   0,  27,  91,  37, 112,  49,  37, 100,
  66,   0,  27,  91,  37, 112,  49,  37, 100,  64,   0,  27,  91,  37, 112,  49,
  37, 100,  83,   0,  27,  91,  37, 112,  49,  37, 100,  76,   0,  27,  91,  37,
 112,  49,  37, 100,  68,   0,  27,  91,  37, 112,  49,  37, 100,  67,   0,  27,
  91,  37, 112,  49,  37, 100,  84,   0,  27,  91,  37, 112,  49,  37, 100,  65,
   0,  27,  91, 105,   0,  27,  91,  52, 105,   0,  27,  91,  53, 105,   0,  27,
  99,  27,  93,  49,  48,  52,   7,   0,  27,  91,  33, 112,  27,  91,  63,  51,
  59,  52, 108,  27,  91,  52, 108,  27,  62,   0,  27,  56,   0,  27,  91,  37,
 105,  37, 112,  49,  37, 100, 100,   0,  27,  55,   0,  10,   0,  27,  77,   0,
  37,  63,  37, 112,  57,  37, 116,  27,  40,  48,  37, 101,  27,  40,  66,  37,
  59,  27,  91,  48,  37,  63,  37, 112,  54,  37, 116,  59,  49,  37,  59,  37,
  63,  37, 112,  53,  37, 116,  59,  50,  37,  59,  37,  63,  37, 112,  50,  37,
 116,  59,  52,  37,  59,  37,  63,  37, 112,  49,  37, 112,  51,  37, 124,  37,
 116,  59,  55,  37,  59,  37,  63,  37, 112,  52,  37, 116,  59,  53,  37,  59,
  37,  63,  37, 112,  55,  37, 116,  59,  56,  37,  59, 109,   0,  27,  72,   0,
   9,   0,  27,  79,  69,   0,  96,  96,  97,  97, 102, 102, 103, 103, 105, 105,
 106, 106, 107, 107, 108, 108, 109, 109, 110, 110, 111, 111, 112, 112, 113, 113,
 114, 114, 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120, 121, 121,
 122, 122, 123, 123, 124, 124, 125, 125, 126, 126,   0,  27,  91,  90,   0,  27,
  91,  63,  55, 104,   0,  27,  91,  63,  55, 108,   0,  27,  79,  70,   0,  27,
  79,  77,   0,  27,  91,  51,  59,  50, 126,   0,  27,  91,  49,  59,  50,  70,
   0,  27,  91,  49,  59,  50,  72,   0,  27,  91,  50,  59,  50, 126,   0,  27,
  91,  49,  59,  50,  68,   0,  27,  91,  54,  59,  50, 126,   0,  27,  91,  53,
  59,  50, 126,   0,  27,  91,  49,  59,  50,  67,   0,  27,  91,  50,  51, 126,
   0,  27,  91,  50,  52, 126,   0,  27,  91,  49,  59,  50,  80,   0,  27,  91,
  49,  59,  50,  81,   0,  27,  91,  49,  59,  50,  82,   0,  27,  91,  49,  59,
  50,  83,   0,  27,  91,  49,  53,  59,  50, 126,   0,  27,  91,  49,  55,  59,
  50, 126,   0,  27,  91,  49,  56,  59,  50, 126,   0,  27,  91,  49,  57,  59,
  50, 126,   0,  27,  91,  50,  48,  59,  50, 126,   0,  27,  91,  50,  49,  59,
  50, 126,   0,  27,  91,  50,  51,  59,  50, 126,   0,  27,  91,  50,  52,  59,
  50, 126,   0,  27,  91,  49,  59,  53,  80,   0,  27,  91,  49,  59,  53,  81,
   0,  27,  91,  49,  59,  53,  82,   0,  27,  91,  49,  59,  53,  83,   0,  27,
  91,  49,  53,  59,  53, 126,   0,  27,  91,  49,  55,  59,  53, 126,   0,  27,
  91,  49,  56,  59,  53, 126,   0,  27,  91,  49,  57,  59,  53, 126,   0,  27,
  91,  50,  48,  59,  53, 126,   0,  27,  91,  50,  49,  59,  53, 126,   0,  27,
  91,  50,  51,  59,  53, 126,   0,  27,  91,  50,  52,  59,  53, 126,   0,  27,
  91,  49,  59,  54,  80,   0,  27,  91,  49,  59,  54,  81,   0,  27,  91,  49,
  59,  54,  82,   0,  27,  91,  49,  59,  54,  83,   0,  27,  91,  49,  53,  59,
  54, 126,   0,  27,  91,  49,  55,  59,  54, 126,   0,  27,  91,  49,  56,  59,
  54, 126,   0,  27,  91,  49,  57,  59,  54, 126,   0,  27,  91,  50,  48,  59,
  54, 126,   0,  27,  91,  50,  49,  59,  54, 126,   0,  27,  91,  50,  51,  59,
  54, 126,   0,  27,  91,  50,  52,  59,  54, 126,   0,  27,  91,  49,  59,  51,
  80,   0,  27,  91,  49,  59,  51,  81,   0,  27,  91,  49,  59,  51,  82,   0,
  27,  91,  49,  59,  51,  83,   0,  27,  91,  49,  53,  59,  51, 126,   0,  27,
  91,  49,  55,  59,  51, 126,   0,  27,  91,  49,  56,  59,  51, 126,   0,  27,
  91,  49,  57,  59,  51, 126,   0,  27,  91,  50,  48,  59,  51, 126,   0,  27,
  91,  50,  49,  59,  51, 126,   0,  27,  91,  50,  51,  59,  51, 126,   0,  27,
  91,  50,  52,  59,  51, 126,   0,  27,  91,  49,  59,  52,  80,   0,  27,  91,
  49,  59,  52,  81,   0,  27,  91,  49,  59,  52,  82,   0,  27,  91,  49,  75,
   0,  27,  91,  37, 105,  37, 100,  59,  37, 100,  82,   0,  27,  91,  54, 110,
   0,  27,  91,  63,  37,  91,  59,  48,  49,  50,  51,  52,  53,  54,  55,  56,
  57,  93,  99,   0,  27,  91,  99,   0,  27,  91,  51,  57,  59,  52,  57, 109,
   0,  27,  93,  49,  48,  52,   7,   0,  27,  93,  52,  59,  37, 112,  49,  37,
 100,  59, 114, 103,  98,  58,  37, 112,  50,  37, 123,  50,  53,  53, 125,  37,
  42,  37, 123,  49,  48,  48,  48, 125,  37,  47,  37,  50,  46,  50,  88,  47,
  37, 112,  51,  37, 123,  50,  53,  53, 125,  37,  42,  37, 123,  49,  48,  48,
  48, 125,  37,  47,  37,  50,  46,  50,  88,  47,  37, 112,  52,  37, 123,  50,
  53,  53, 125,  37,  42,  37, 123,  49,  48,  48,  48, 125,  37,  47,  37,  50,
  46,  50,  88,  27,  92,   0,  27,  91,  51, 109,   0,  27,  91,  50,  51, 109,
   0,  27,  91,  77,   0,  27,  91,  37,  63,  37, 112,  49,  37, 123,  56, 125,
  37,  60,  37, 116,  51,  37, 112,  49,  37, 100,  37, 101,  37, 112,  49,  37,
 123,  49,  54, 125,  37,  60,  37, 116,  57,  37, 112,  49,  37, 123,  56, 125,
  37,  45,  37, 100,  37, 101,  51,  56,  59,  53,  59,  37, 112,  49,  37, 100,
  37,  59, 109,   0,  27,  91,  37,  63,  37, 112,  49,  37, 123,  56, 125,  37,
  60,  37, 116,  52,  37, 112,  49,  37, 100,  37, 101,  37, 112,  49,  37, 123,
  49,  54, 125,  37,  60,  37, 116,  49,  48,  37, 112,  49,  37, 123,  56, 125,
  37,  45,  37, 100,  37, 101,  52,  56,  59,  53,  59,  37, 112,  49,  37, 100,
  37,  59, 109,   0
};
// Taken from unibilium/t/static_tmux.c as of 2015-08-14.
// This is an 256-colour terminfo description that lacks
// status line capabilities that tmux actually has.
static const char tmux_256colour_terminfo[] = {
    26, 1, 56, 0, 15, 0, 15, 0, 105, 1, -48, 2, 116, 109, 117, 120, 124, 86, 84, 32,
    49, 48, 48, 47, 65, 78, 83, 73, 32, 88, 51, 46, 54, 52, 32, 118, 105, 114, 116, 117,
    97, 108, 32, 116, 101, 114, 109, 105, 110, 97, 108, 32, 119, 105, 116, 104, 32, 50, 53, 54,
    32, 99, 111, 108, 111, 114, 115, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0,
    0, 1, 1, 0, 80, 0, 8, 0, 24, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 1, -1, 127, 0, 0, 4, 0, 6, 0,
    8, 0, 25, 0, 30, 0, 37, 0, 41, 0, -1, -1, -1, -1, 45, 0, 62, 0, 64, 0,
    68, 0, 75, 0, -1, -1, 77, 0, 89, 0, -1, -1, 93, 0, 96, 0, 102, 0, 106, 0,
    -1, -1, -1, -1, 110, 0, 112, 0, 117, 0, 122, 0, -1, -1, -1, -1, 123, 0, -1, -1,
    -1, -1, -128, 0, -123, 0, -118, 0, -1, -1, -113, 0, -111, 0, -106, 0, -1, -1, -105, 0,
    -100, 0, -94, 0, -88, 0, -1, -1, -1, -1, -1, -1, -85, 0, -1, -1, -1, -1, -1, -1,
    -81, 0, -1, -1, -77, 0, -1, -1, -1, -1, -1, -1, -75, 0, -1, -1, -70, 0, -1, -1,
    -1, -1, -1, -1, -1, -1, -66, 0, -62, 0, -56, 0, -52, 0, -48, 0, -44, 0, -38, 0,
    -32, 0, -26, 0, -20, 0, -14, 0, -9, 0, -1, -1, -4, 0, -1, -1, 0, 1, 5, 1,
    10, 1, -1, -1, -1, -1, -1, -1, 14, 1, 18, 1, 26, 1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    34, 1, -1, -1, 37, 1, 46, 1, 55, 1, 64, 1, -1, -1, 73, 1, 82, 1, 91, 1,
    -1, -1, 100, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    109, 1, -1, -1, -1, -1, 126, 1, -1, -1, -127, 1, -124, 1, -122, 1, -119, 1, -46, 1,
    -1, -1, -43, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -41, 1, -1, -1, 24, 2, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, 28, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, 35, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, 40, 2, 46, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 52, 2, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, 57, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 66, 2, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 71, 2, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, 77, 2, -1, -1, -1, -1, -1, -1, 81, 2, -112, 2, 27, 91, 90, 0,
    7, 0, 13, 0, 27, 91, 37, 105, 37, 112, 49, 37, 100, 59, 37, 112, 50, 37, 100, 114,
    0, 27, 91, 51, 103, 0, 27, 91, 72, 27, 91, 74, 0, 27, 91, 75, 0, 27, 91, 74,
    0, 27, 91, 37, 105, 37, 112, 49, 37, 100, 59, 37, 112, 50, 37, 100, 72, 0, 10, 0,
    27, 91, 72, 0, 27, 91, 63, 50, 53, 108, 0, 8, 0, 27, 91, 51, 52, 104, 27, 91,
    63, 50, 53, 104, 0, 27, 91, 67, 0, 27, 77, 0, 27, 91, 51, 52, 108, 0, 27, 91,
    80, 0, 27, 91, 77, 0, 14, 0, 27, 91, 53, 109, 0, 27, 91, 49, 109, 0, 0, 27,
    91, 52, 104, 0, 27, 91, 55, 109, 0, 27, 91, 55, 109, 0, 27, 91, 52, 109, 0, 15,
    0, 27, 91, 109, 15, 0, 0, 27, 91, 52, 108, 0, 27, 91, 50, 55, 109, 0, 27, 91,
    50, 52, 109, 0, 27, 103, 0, 27, 41, 48, 0, 27, 91, 76, 0, 8, 0, 27, 91, 51,
    126, 0, 27, 79, 66, 0, 27, 79, 80, 0, 27, 91, 50, 49, 126, 0, 27, 79, 81, 0,
    27, 79, 82, 0, 27, 79, 83, 0, 27, 91, 49, 53, 126, 0, 27, 91, 49, 55, 126, 0,
    27, 91, 49, 56, 126, 0, 27, 91, 49, 57, 126, 0, 27, 91, 50, 48, 126, 0, 27, 91,
    49, 126, 0, 27, 91, 50, 126, 0, 27, 79, 68, 0, 27, 91, 54, 126, 0, 27, 91, 53,
    126, 0, 27, 79, 67, 0, 27, 79, 65, 0, 27, 91, 63, 49, 108, 27, 62, 0, 27, 91,
    63, 49, 104, 27, 61, 0, 27, 69, 0, 27, 91, 37, 112, 49, 37, 100, 80, 0, 27, 91,
    37, 112, 49, 37, 100, 77, 0, 27, 91, 37, 112, 49, 37, 100, 66, 0, 27, 91, 37, 112,
    49, 37, 100, 64, 0, 27, 91, 37, 112, 49, 37, 100, 76, 0, 27, 91, 37, 112, 49, 37,
    100, 68, 0, 27, 91, 37, 112, 49, 37, 100, 67, 0, 27, 91, 37, 112, 49, 37, 100, 65,
    0, 27, 99, 27, 91, 63, 49, 48, 48, 48, 108, 27, 91, 63, 50, 53, 104, 0, 27, 56,
    0, 27, 55, 0, 10, 0, 27, 77, 0, 27, 91, 48, 37, 63, 37, 112, 54, 37, 116, 59,
    49, 37, 59, 37, 63, 37, 112, 49, 37, 116, 59, 55, 37, 59, 37, 63, 37, 112, 50, 37,
    116, 59, 52, 37, 59, 37, 63, 37, 112, 51, 37, 116, 59, 55, 37, 59, 37, 63, 37, 112,
    52, 37, 116, 59, 53, 37, 59, 109, 37, 63, 37, 112, 57, 37, 116, 14, 37, 101, 15, 37,
    59, 0, 27, 72, 0, 9, 0, 43, 43, 44, 44, 45, 45, 46, 46, 48, 48, 96, 96, 97,
    97, 102, 102, 103, 103, 104, 104, 105, 105, 106, 106, 107, 107, 108, 108, 109, 109, 110, 110, 111,
    111, 112, 112, 113, 113, 114, 114, 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120, 121,
    121, 122, 122, 123, 123, 124, 124, 125, 125, 126, 126, 0, 27, 91, 90, 0, 27, 40, 66, 27,
    41, 48, 0, 27, 91, 52, 126, 0, 27, 91, 50, 51, 126, 0, 27, 91, 50, 52, 126, 0,
    27, 91, 49, 75, 0, 27, 91, 51, 57, 59, 52, 57, 109, 0, 27, 91, 51, 109, 0, 27,
    91, 50, 51, 109, 0, 27, 91, 77, 0, 27, 91, 37, 63, 37, 112, 49, 37, 123, 56, 125,
    37, 60, 37, 116, 51, 37, 112, 49, 37, 100, 37, 101, 37, 112, 49, 37, 123, 49, 54, 125,
    37, 60, 37, 116, 57, 37, 112, 49, 37, 123, 56, 125, 37, 45, 37, 100, 37, 101, 51, 56,
    59, 53, 59, 37, 112, 49, 37, 100, 37, 59, 109, 0, 27, 91, 37, 63, 37, 112, 49, 37,
    123, 56, 125, 37, 60, 37, 116, 52, 37, 112, 49, 37, 100, 37, 101, 37, 112, 49, 37, 123,
    49, 54, 125, 37, 60, 37, 116, 49, 48, 37, 112, 49, 37, 123, 56, 125, 37, 45, 37, 100,
    37, 101, 52, 56, 59, 53, 59, 37, 112, 49, 37, 100, 37, 59, 109, 0
};
// Taken from unibilium/t/static_screen-256color.c as of 2015-08-14.
// This is an 256-colour terminfo description that lacks
// status line capabilities that screen actually has.
static const char screen_256colour_terminfo[] = {
    26, 1, 43, 0, 43, 0, 15, 0, 105, 1, -43, 2, 115, 99, 114, 101, 101, 110, 45, 50,
    53, 54, 99, 111, 108, 111, 114, 124, 71, 78, 85, 32, 83, 99, 114, 101, 101, 110, 32, 119,
    105, 116, 104, 32, 50, 53, 54, 32, 99, 111, 108, 111, 114, 115, 0, 0, 1, 0, 0, 1,
    0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 80, 0,
    8, 0, 24, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, 0, 1, -1, 127, 0, 0, 4, 0, 6, 0, 8, 0, 25, 0, 30, 0,
    37, 0, 41, 0, -1, -1, -1, -1, 45, 0, 62, 0, 64, 0, 68, 0, 75, 0, -1, -1,
    77, 0, 89, 0, -1, -1, 93, 0, 96, 0, 102, 0, 106, 0, -1, -1, -1, -1, 110, 0,
    112, 0, 117, 0, 122, 0, -1, -1, -1, -1, -125, 0, -1, -1, -1, -1, -120, 0, -115, 0,
    -110, 0, -1, -1, -105, 0, -103, 0, -98, 0, -1, -1, -89, 0, -84, 0, -78, 0, -72, 0,
    -1, -1, -1, -1, -1, -1, -69, 0, -1, -1, -1, -1, -1, -1, -65, 0, -1, -1, -61, 0,
    -1, -1, -1, -1, -1, -1, -59, 0, -1, -1, -54, 0, -1, -1, -1, -1, -1, -1, -1, -1,
    -50, 0, -46, 0, -40, 0, -36, 0, -32, 0, -28, 0, -22, 0, -16, 0, -10, 0, -4, 0,
    2, 1, 7, 1, -1, -1, 12, 1, -1, -1, 16, 1, 21, 1, 26, 1, -1, -1, -1, -1,
    -1, -1, 30, 1, 34, 1, 42, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 50, 1, -1, -1, 53, 1,
    62, 1, 71, 1, 80, 1, -1, -1, 89, 1, 98, 1, 107, 1, -1, -1, 116, 1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 125, 1, -1, -1, -1, -1,
    -114, 1, -1, -1, -111, 1, -108, 1, -106, 1, -103, 1, -30, 1, -1, -1, -27, 1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -25, 1, -1, -1, 40, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 44, 2,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 51, 2, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    56, 2, 62, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, 68, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, 73, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 82, 2,
    -1, -1, -1, -1, -1, -1, 86, 2, -107, 2, 27, 91, 90, 0, 7, 0, 13, 0, 27, 91,
    37, 105, 37, 112, 49, 37, 100, 59, 37, 112, 50, 37, 100, 114, 0, 27, 91, 51, 103, 0,
    27, 91, 72, 27, 91, 74, 0, 27, 91, 75, 0, 27, 91, 74, 0, 27, 91, 37, 105, 37,
    112, 49, 37, 100, 59, 37, 112, 50, 37, 100, 72, 0, 10, 0, 27, 91, 72, 0, 27, 91,
    63, 50, 53, 108, 0, 8, 0, 27, 91, 51, 52, 104, 27, 91, 63, 50, 53, 104, 0, 27,
    91, 67, 0, 27, 77, 0, 27, 91, 51, 52, 108, 0, 27, 91, 80, 0, 27, 91, 77, 0,
    14, 0, 27, 91, 53, 109, 0, 27, 91, 49, 109, 0, 27, 91, 63, 49, 48, 52, 57, 104,
    0, 27, 91, 52, 104, 0, 27, 91, 55, 109, 0, 27, 91, 51, 109, 0, 27, 91, 52, 109,
    0, 15, 0, 27, 91, 109, 15, 0, 27, 91, 63, 49, 48, 52, 57, 108, 0, 27, 91, 52,
    108, 0, 27, 91, 50, 51, 109, 0, 27, 91, 50, 52, 109, 0, 27, 103, 0, 27, 41, 48,
    0, 27, 91, 76, 0, 8, 0, 27, 91, 51, 126, 0, 27, 79, 66, 0, 27, 79, 80, 0,
    27, 91, 50, 49, 126, 0, 27, 79, 81, 0, 27, 79, 82, 0, 27, 79, 83, 0, 27, 91,
    49, 53, 126, 0, 27, 91, 49, 55, 126, 0, 27, 91, 49, 56, 126, 0, 27, 91, 49, 57,
    126, 0, 27, 91, 50, 48, 126, 0, 27, 91, 49, 126, 0, 27, 91, 50, 126, 0, 27, 79,
    68, 0, 27, 91, 54, 126, 0, 27, 91, 53, 126, 0, 27, 79, 67, 0, 27, 79, 65, 0,
    27, 91, 63, 49, 108, 27, 62, 0, 27, 91, 63, 49, 104, 27, 61, 0, 27, 69, 0, 27,
    91, 37, 112, 49, 37, 100, 80, 0, 27, 91, 37, 112, 49, 37, 100, 77, 0, 27, 91, 37,
    112, 49, 37, 100, 66, 0, 27, 91, 37, 112, 49, 37, 100, 64, 0, 27, 91, 37, 112, 49,
    37, 100, 76, 0, 27, 91, 37, 112, 49, 37, 100, 68, 0, 27, 91, 37, 112, 49, 37, 100,
    67, 0, 27, 91, 37, 112, 49, 37, 100, 65, 0, 27, 99, 27, 91, 63, 49, 48, 48, 48,
    108, 27, 91, 63, 50, 53, 104, 0, 27, 56, 0, 27, 55, 0, 10, 0, 27, 77, 0, 27,
    91, 48, 37, 63, 37, 112, 54, 37, 116, 59, 49, 37, 59, 37, 63, 37, 112, 49, 37, 116,
    59, 51, 37, 59, 37, 63, 37, 112, 50, 37, 116, 59, 52, 37, 59, 37, 63, 37, 112, 51,
    37, 116, 59, 55, 37, 59, 37, 63, 37, 112, 52, 37, 116, 59, 53, 37, 59, 109, 37, 63,
    37, 112, 57, 37, 116, 14, 37, 101, 15, 37, 59, 0, 27, 72, 0, 9, 0, 43, 43, 44,
    44, 45, 45, 46, 46, 48, 48, 96, 96, 97, 97, 102, 102, 103, 103, 104, 104, 105, 105, 106,
    106, 107, 107, 108, 108, 109, 109, 110, 110, 111, 111, 112, 112, 113, 113, 114, 114, 115, 115, 116,
    116, 117, 117, 118, 118, 119, 119, 120, 120, 121, 121, 122, 122, 123, 123, 124, 124, 125, 125, 126,
    126, 0, 27, 91, 90, 0, 27, 40, 66, 27, 41, 48, 0, 27, 91, 52, 126, 0, 27, 91,
    50, 51, 126, 0, 27, 91, 50, 52, 126, 0, 27, 91, 49, 75, 0, 27, 91, 51, 57, 59,
    52, 57, 109, 0, 27, 91, 77, 0, 27, 91, 37, 63, 37, 112, 49, 37, 123, 56, 125, 37,
    60, 37, 116, 51, 37, 112, 49, 37, 100, 37, 101, 37, 112, 49, 37, 123, 49, 54, 125, 37,
    60, 37, 116, 57, 37, 112, 49, 37, 123, 56, 125, 37, 45, 37, 100, 37, 101, 51, 56, 59,
    53, 59, 37, 112, 49, 37, 100, 37, 59, 109, 0, 27, 91, 37, 63, 37, 112, 49, 37, 123,
    56, 125, 37, 60, 37, 116, 52, 37, 112, 49, 37, 100, 37, 101, 37, 112, 49, 37, 123, 49,
    54, 125, 37, 60, 37, 116, 49, 48, 37, 112, 49, 37, 123, 56, 125, 37, 45, 37, 100, 37,
    101, 52, 56, 59, 53, 59, 37, 112, 49, 37, 100, 37, 59, 109, 0, 0, 3, 0, 1, 0,
    24, 0, 52, 0, -112, 0, 1, 1, 0, 0, 1, 0, 0, 0, 4, 0, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    0, 0, 3, 0, 6, 0, 9, 0, 12, 0, 15, 0, 18, 0, 23, 0, 28, 0, 32, 0,
    37, 0, 43, 0, 49, 0, 55, 0, 61, 0, 66, 0, 71, 0, 77, 0, 83, 0, 89, 0,
    95, 0, 101, 0, 107, 0, 111, 0, 116, 0, 120, 0, 124, 0, -128, 0, 27, 40, 66, 0,
    27, 40, 37, 112, 49, 37, 99, 0, 65, 88, 0, 71, 48, 0, 88, 84, 0, 85, 56, 0,
    69, 48, 0, 83, 48, 0, 107, 68, 67, 53, 0, 107, 68, 67, 54, 0, 107, 68, 78, 0,
    107, 68, 78, 53, 0, 107, 69, 78, 68, 53, 0, 107, 69, 78, 68, 54, 0, 107, 72, 79,
    77, 53, 0, 107, 72, 79, 77, 54, 0, 107, 73, 67, 53, 0, 107, 73, 67, 54, 0, 107,
    76, 70, 84, 53, 0, 107, 78, 88, 84, 53, 0, 107, 78, 88, 84, 54, 0, 107, 80, 82,
    86, 53, 0, 107, 80, 82, 86, 54, 0, 107, 82, 73, 84, 53, 0, 107, 85, 80, 0, 107,
    85, 80, 53, 0, 107, 97, 50, 0, 107, 98, 49, 0, 107, 98, 51, 0, 107, 99, 50, 0
};
// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
static const char iterm_256colour_terminfo[] = {
  26,   1,  57,   0,  29,   0,  15,   0, 105,   1,  73,   3, 105,  84, 101, 114,
 109,  46,  97, 112, 112, 124, 105, 116, 101, 114, 109, 124, 105,  84, 101, 114,
 109,  46,  97, 112, 112,  32, 116, 101, 114, 109, 105, 110,  97, 108,  32, 101,
 109, 117, 108,  97, 116, 111, 114,  32, 102, 111, 114,  32,  77,  97,  99,  32,
  79,  83,  32,  88,   0,   0,   1,   0,   0,   1,   0,   0,   0,   0,   1,   0,
   0,   0,   1,   1,   0,   0,   0,   0,   0,   1,   0,   0,   0,   0,   1,   0,
   0,   1,  80,   0,   8,   0,  24,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  50,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,   0,   1,  -1, 127,
  -1,  -1,   0,   0,   2,   0,  -2,  -1,   4,   0,   9,   0,  16,   0,  20,   0,
  24,   0,  -1,  -1,  35,   0,  52,   0,  54,   0,  58,   0,  65,   0,  -1,  -1,
  67,   0,  74,   0,  -1,  -1,  78,   0,  -1,  -1,  82,   0,  86,   0,  90,   0,
  -1,  -1,  96,   0,  98,   0, 103,   0, 108,   0,  -1,  -1,  -2,  -1, 117,   0,
 122,   0,  -1,  -1, 127,   0,-124,   0,-119,   0,  -1,  -1,-114,   0,-112,   0,
-107,   0,  -1,  -1, -94,   0, -89,   0, -85,   0, -81,   0,  -1,  -1, -63,   0,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -61,   0, -57,   0,  -1,  -1, -53,   0,
  -1,  -1,  -1,  -1,  -1,  -1, -51,   0,  -1,  -1, -46,   0,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, -42,   0, -38,   0, -32,   0, -28,   0, -24,   0, -20,   0,
 -14,   0,  -8,   0,  -2,   0,   4,   1,  10,   1,  -1,  -1,  -1,  -1,  14,   1,
  -1,  -1,  18,   1,  23,   1,  28,   1,  -1,  -1,  -1,  -1,  -1,  -1,  32,   1,
  36,   1,  44,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  52,   1,  61,   1,  70,   1,  79,   1,  -1,  -1,  88,   1,  97,   1,
 106,   1,  -1,  -1, 115,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1, 124,   1,  -1,  -1,  -1,  -1,-104,   1,-101,   1,
 -90,   1, -87,   1, -85,   1, -82,   1,  -4,   1,  -1,  -1,  -1,   1,   1,   2,
  -1,  -1,  -1,  -1,  -1,  -1,   6,   2,  10,   2,  14,   2,  18,   2,  22,   2,
  -1,  -1,  -1,  -1,  26,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  77,   2,
  83,   2,  -1,  -1,  -1,  -1,  89,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  96,   2, 100,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
 104,   2, 110,   2, 116,   2, 122,   2,-128,   2,-122,   2,-116,   2,-110,   2,
 104,   2, -98,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -92,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -87,   2, -76,   2, -71,   2,
 -63,   2, -59,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -54,   2,
   9,   3,   7,   0,  13,   0,  27,  91,  51, 103,   0,  27,  91,  72,  27,  91,
  74,   0,  27,  91,  75,   0,  27,  91,  74,   0,  27,  91,  37, 105,  37, 112,
  49,  37, 100,  71,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  59,  37,
 112,  50,  37, 100,  72,   0,  10,   0,  27,  91,  72,   0,  27,  91,  63,  50,
  53, 108,   0,   8,   0,  27,  91,  63,  50,  53, 104,   0,  27,  91,  67,   0,
  27,  91,  65,   0,  27,  91,  80,   0,  27,  91,  77,   0,  27,  93,  50,  59,
   7,   0,  14,   0,  27,  91,  53, 109,   0,  27,  91,  49, 109,   0,  27,  55,
  27,  91,  63,  52,  55, 104,   0,  27,  91,  52, 104,   0,  27,  91,  56, 109,
   0,  27,  91,  55, 109,   0,  27,  91,  55, 109,   0,  27,  91,  52, 109,   0,
  15,   0,  27,  91, 109,  15,   0,  27,  91,  50,  74,  27,  91,  63,  52,  55,
 108,  27,  56,   0,  27,  91,  52, 108,   0,  27,  91, 109,   0,  27,  91, 109,
   0,  27,  91,  63,  53, 104,  36,  60,  50,  48,  48,  47,  62,  27,  91,  63,
  53, 108,   0,   7,   0,  27,  91,  64,   0,  27,  91,  76,   0, 127,   0,  27,
  91,  51, 126,   0,  27,  79,  66,   0,  27,  79,  80,   0,  27,  91,  50,  49,
 126,   0,  27,  79,  81,   0,  27,  79,  82,   0,  27,  79,  83,   0,  27,  91,
  49,  53, 126,   0,  27,  91,  49,  55, 126,   0,  27,  91,  49,  56, 126,   0,
  27,  91,  49,  57, 126,   0,  27,  91,  50,  48, 126,   0,  27,  79,  72,   0,
  27,  79,  68,   0,  27,  91,  54, 126,   0,  27,  91,  53, 126,   0,  27,  79,
  67,   0,  27,  79,  65,   0,  27,  91,  63,  49, 108,  27,  62,   0,  27,  91,
  63,  49, 104,  27,  61,   0,  27,  91,  37, 112,  49,  37, 100,  80,   0,  27,
  91,  37, 112,  49,  37, 100,  77,   0,  27,  91,  37, 112,  49,  37, 100,  66,
   0,  27,  91,  37, 112,  49,  37, 100,  64,   0,  27,  91,  37, 112,  49,  37,
 100,  76,   0,  27,  91,  37, 112,  49,  37, 100,  68,   0,  27,  91,  37, 112,
  49,  37, 100,  67,   0,  27,  91,  37, 112,  49,  37, 100,  65,   0,  27,  62,
  27,  91,  63,  51, 108,  27,  91,  63,  52, 108,  27,  91,  63,  53, 108,  27,
  91,  63,  55, 104,  27,  91,  63,  56, 104,   0,  27,  56,   0,  27,  91,  37,
 105,  37, 112,  49,  37, 100, 100,   0,  27,  55,   0,  10,   0,  27,  77,   0,
  27,  91,  48,  37,  63,  37, 112,  54,  37, 116,  59,  49,  37,  59,  37,  63,
  37, 112,  50,  37, 116,  59,  52,  37,  59,  37,  63,  37, 112,  49,  37, 112,
  51,  37, 124,  37, 116,  59,  55,  37,  59,  37,  63,  37, 112,  52,  37, 116,
  59,  53,  37,  59,  37,  63,  37, 112,  55,  37, 116,  59,  56,  37,  59, 109,
  37,  63,  37, 112,  57,  37, 116,  14,  37, 101,  15,  37,  59,   0,  27,  72,
   0,   9,   0,  27,  93,  50,  59,   0,  27,  79, 113,   0,  27,  79, 115,   0,
  27,  79, 114,   0,  27,  79, 112,   0,  27,  79, 110,   0,  96,  96,  97,  97,
 102, 102, 103, 103, 106, 106, 107, 107, 108, 108, 109, 109, 110, 110, 111, 111,
 112, 112, 113, 113, 114, 114, 115, 115, 116, 116, 117, 117, 118, 118, 119, 119,
 120, 120, 121, 121, 122, 122, 123, 123, 124, 124, 125, 125, 126, 126,   0,  27,
  91,  63,  55, 104,   0,  27,  91,  63,  55, 108,   0,  27,  40,  66,  27,  41,
  48,   0,  27,  79,  70,   0,  27,  79,  77,   0,  27,  91,  50,  51, 126,   0,
  27,  91,  50,  52, 126,   0,  27,  91,  50,  53, 126,   0,  27,  91,  50,  54,
 126,   0,  27,  91,  50,  56, 126,   0,  27,  91,  50,  57, 126,   0,  27,  91,
  51,  49, 126,   0,  27,  91,  50,  50, 126,   0,  27,  91,  51,  51, 126,   0,
  27,  91,  51,  52, 126,   0,  27,  91,  49,  75,   0,  27,  91,  37, 105,  37,
 100,  59,  37, 100,  82,   0,  27,  91,  54, 110,   0,  27,  91,  63,  49,  59,
  50,  99,   0,  27,  91,  99,   0,  27,  91,  48, 109,   0,  27,  91,  37,  63,
  37, 112,  49,  37, 123,  56, 125,  37,  60,  37, 116,  51,  37, 112,  49,  37,
 100,  37, 101,  37, 112,  49,  37, 123,  49,  54, 125,  37,  60,  37, 116,  57,
  37, 112,  49,  37, 123,  56, 125,  37,  45,  37, 100,  37, 101,  51,  56,  59,
  53,  59,  37, 112,  49,  37, 100,  37,  59, 109,   0,  27,  91,  37,  63,  37,
 112,  49,  37, 123,  56, 125,  37,  60,  37, 116,  52,  37, 112,  49,  37, 100,
  37, 101,  37, 112,  49,  37, 123,  49,  54, 125,  37,  60,  37, 116,  49,  48,
  37, 112,  49,  37, 123,  56, 125,  37,  45,  37, 100,  37, 101,  52,  56,  59,
  53,  59,  37, 112,  49,  37, 100,  37,  59, 109,   0
};
// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
// This is a 256-colour terminfo description that lacks true-colour
// capabilities that rxvt actually has.
static const char rxvt_256colour_terminfo[] = {
  26,   1,  47,   0,  29,   0,  15,   0, 110,   1, -31,   4, 114, 120, 118, 116,
  45,  50,  53,  54,  99, 111, 108, 111, 114, 124, 114, 120, 118, 116,  32,  50,
  46,  55,  46,  57,  32, 119, 105, 116, 104,  32, 120, 116, 101, 114, 109,  32,
  50,  53,  54,  45,  99, 111, 108, 111, 114, 115,   0,   0,   1,   0,   0,   1,
   1,   0,   0,   0,   0,   0,   0,   0,   1,   1,   0,   0,   0,   0,   0,   1,
   0,   0,   0,   0,   0,   0,   1,   1,  80,   0,   8,   0,  24,   0,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,   0,   1,  -1, 127,  -1,  -1,   0,   0,   2,   0,   4,   0,  21,   0,
  26,   0,  34,   0,  38,   0,  42,   0,  -1,  -1,  53,   0,  70,   0,  72,   0,
  76,   0,  83,   0,  -1,  -1,  85,   0,  92,   0,  -1,  -1,  96,   0,  -1,  -1,
  -1,  -1, 100,   0,  -1,  -1,  -1,  -1, 104,   0, 106,   0, 111,   0, 116,   0,
  -1,  -1,  -1,  -1, 125,   0,  -1,  -1,  -1,  -1,-126,   0,-121,   0,-116,   0,
  -1,  -1,-111,   0,-109,   0,-104,   0,  -1,  -1, -91,   0, -86,   0, -80,   0,
 -74,   0,  -1,  -1,  -1,  -1, -56,   0, -42,   0,  -1,  -1,  -1,  -1,  -8,   0,
  -4,   0,  -1,  -1,   0,   1,  -1,  -1,  -1,  -1,  -1,  -1,   2,   1,  -1,  -1,
   7,   1,  -1,  -1,  11,   1,  -1,  -1,  16,   1,  22,   1,  28,   1,  34,   1,
  40,   1,  46,   1,  52,   1,  58,   1,  64,   1,  70,   1,  76,   1,  82,   1,
  87,   1,  -1,  -1,  92,   1,  -1,  -1,  96,   1, 101,   1, 106,   1, 110,   1,
 114,   1,  -1,  -1, 118,   1, 122,   1, 125,   1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,-128,   1,-119,   1,-110,   1,
  -1,  -1,-101,   1, -92,   1, -83,   1,  -1,  -1, -74,   1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -65,   1, -32,   1,  -1,  -1,
  -1,  -1,  18,   2,  21,   2,  32,   2,  35,   2,  37,   2,  40,   2, 107,   2,
  -1,  -1, 110,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 112,   2, 116,   2,
 120,   2, 124,   2,-128,   2,  -1,  -1,  -1,  -1,-124,   2,  -1,  -1, -73,   2,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -69,   2,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -62,   2,
 -57,   2,  -1,  -1, -53,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, -48,   2,  -1,  -1, -43,   2, -38,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, -33,   2, -28,   2, -23,   2,  -1,  -1,  -1,  -1, -19,   2,
  -1,  -1, -14,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -9,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -5,   2,   1,   3,   7,   3,  13,   3,  19,   3,
  25,   3,  31,   3,  37,   3,  43,   3,  49,   3,  55,   3,  61,   3,  67,   3,
  73,   3,  79,   3,  85,   3,  91,   3,  97,   3, 103,   3, 109,   3, 115,   3,
 121,   3, 127,   3,-123,   3,-117,   3,-111,   3,-105,   3, -99,   3, -93,   3,
 -87,   3, -81,   3, -75,   3, -69,   3, -63,   3,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
 -57,   3,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
 -52,   3, -41,   3, -36,   3, -28,   3, -24,   3, -15,   3,  -8,   3,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  86,   4,  -1,  -1,
  -1,  -1,  -1,  -1,  90,   4,-103,   4,  -1,  -1,  -1,  -1,  -1,  -1, -39,   4,
 -35,   4,   7,   0,  13,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  59,
  37, 112,  50,  37, 100, 114,   0,  27,  91,  51, 103,   0,  27,  91,  72,  27,
  91,  50,  74,   0,  27,  91,  75,   0,  27,  91,  74,   0,  27,  91,  37, 105,
  37, 112,  49,  37, 100,  71,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,
  59,  37, 112,  50,  37, 100,  72,   0,  10,   0,  27,  91,  72,   0,  27,  91,
  63,  50,  53, 108,   0,   8,   0,  27,  91,  63,  50,  53, 104,   0,  27,  91,
  67,   0,  27,  91,  65,   0,  27,  91,  77,   0,  14,   0,  27,  91,  53, 109,
   0,  27,  91,  49, 109,   0,  27,  55,  27,  91,  63,  52,  55, 104,   0,  27,
  91,  52, 104,   0,  27,  91,  55, 109,   0,  27,  91,  55, 109,   0,  27,  91,
  52, 109,   0,  15,   0,  27,  91, 109,  15,   0,  27,  91,  50,  74,  27,  91,
  63,  52,  55, 108,  27,  56,   0,  27,  91,  52, 108,   0,  27,  91,  50,  55,
 109,   0,  27,  91,  50,  52, 109,   0,  27,  91,  63,  53, 104,  36,  60,  49,
  48,  48,  47,  62,  27,  91,  63,  53, 108,   0,  27,  91,  63,  52,  55, 108,
  27,  61,  27,  91,  63,  49, 108,   0,  27,  91, 114,  27,  91, 109,  27,  91,
  50,  74,  27,  91,  72,  27,  91,  63,  55, 104,  27,  91,  63,  49,  59,  51,
  59,  52,  59,  54, 108,  27,  91,  52, 108,   0,  27,  91,  64,   0,  27,  91,
  76,   0,   8,   0,  27,  91,  51, 126,   0,  27,  91,  66,   0,  27,  91,  56,
  94,   0,  27,  91,  50,  49, 126,   0,  27,  91,  49,  49, 126,   0,  27,  91,
  50,  49, 126,   0,  27,  91,  49,  50, 126,   0,  27,  91,  49,  51, 126,   0,
  27,  91,  49,  52, 126,   0,  27,  91,  49,  53, 126,   0,  27,  91,  49,  55,
 126,   0,  27,  91,  49,  56, 126,   0,  27,  91,  49,  57, 126,   0,  27,  91,
  50,  48, 126,   0,  27,  91,  55, 126,   0,  27,  91,  50, 126,   0,  27,  91,
  68,   0,  27,  91,  54, 126,   0,  27,  91,  53, 126,   0,  27,  91,  67,   0,
  27,  91,  97,   0,  27,  91,  98,   0,  27,  91,  65,   0,  27,  62,   0,  27,
  61,   0,  27,  91,  37, 112,  49,  37, 100,  77,   0,  27,  91,  37, 112,  49,
  37, 100,  66,   0,  27,  91,  37, 112,  49,  37, 100,  64,   0,  27,  91,  37,
 112,  49,  37, 100,  76,   0,  27,  91,  37, 112,  49,  37, 100,  68,   0,  27,
  91,  37, 112,  49,  37, 100,  67,   0,  27,  91,  37, 112,  49,  37, 100,  65,
   0,  27,  62,  27,  91,  49,  59,  51,  59,  52,  59,  53,  59,  54, 108,  27,
  91,  63,  55, 104,  27,  91, 109,  27,  91, 114,  27,  91,  50,  74,  27,  91,
  72,   0,  27,  91, 114,  27,  91, 109,  27,  91,  50,  74,  27,  91,  72,  27,
  91,  63,  55, 104,  27,  91,  63,  49,  59,  51,  59,  52,  59,  54, 108,  27,
  91,  52, 108,  27,  62,  27,  91,  63,  49,  48,  48,  48, 108,  27,  91,  63,
  50,  53, 104,   0,  27,  56,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,
 100,   0,  27,  55,   0,  10,   0,  27,  77,   0,  27,  91,  48,  37,  63,  37,
 112,  54,  37, 116,  59,  49,  37,  59,  37,  63,  37, 112,  50,  37, 116,  59,
  52,  37,  59,  37,  63,  37, 112,  49,  37, 112,  51,  37, 124,  37, 116,  59,
  55,  37,  59,  37,  63,  37, 112,  52,  37, 116,  59,  53,  37,  59, 109,  37,
  63,  37, 112,  57,  37, 116,  14,  37, 101,  15,  37,  59,   0,  27,  72,   0,
   9,   0,  27,  79, 119,   0,  27,  79, 121,   0,  27,  79, 117,   0,  27,  79,
 113,   0,  27,  79, 115,   0,  96,  96,  97,  97, 102, 102, 103, 103, 106, 106,
 107, 107, 108, 108, 109, 109, 110, 110, 111, 111, 112, 112, 113, 113, 114, 114,
 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120, 121, 121, 122, 122,
 123, 123, 124, 124, 125, 125, 126, 126,   0,  27,  91,  90,   0,  27,  40,  66,
  27,  41,  48,   0,  27,  91,  56, 126,   0,  27,  79,  77,   0,  27,  91,  49,
 126,   0,  27,  91,  51,  36,   0,  27,  91,  52, 126,   0,  27,  91,  56,  36,
   0,  27,  91,  55,  36,   0,  27,  91,  50,  36,   0,  27,  91, 100,   0,  27,
  91,  54,  36,   0,  27,  91,  53,  36,   0,  27,  91,  99,   0,  27,  91,  50,
  51, 126,   0,  27,  91,  50,  52, 126,   0,  27,  91,  50,  53, 126,   0,  27,
  91,  50,  54, 126,   0,  27,  91,  50,  56, 126,   0,  27,  91,  50,  57, 126,
   0,  27,  91,  51,  49, 126,   0,  27,  91,  51,  50, 126,   0,  27,  91,  51,
  51, 126,   0,  27,  91,  51,  52, 126,   0,  27,  91,  50,  51,  36,   0,  27,
  91,  50,  52,  36,   0,  27,  91,  49,  49,  94,   0,  27,  91,  49,  50,  94,
   0,  27,  91,  49,  51,  94,   0,  27,  91,  49,  52,  94,   0,  27,  91,  49,
  53,  94,   0,  27,  91,  49,  55,  94,   0,  27,  91,  49,  56,  94,   0,  27,
  91,  49,  57,  94,   0,  27,  91,  50,  48,  94,   0,  27,  91,  50,  49,  94,
   0,  27,  91,  50,  51,  94,   0,  27,  91,  50,  52,  94,   0,  27,  91,  50,
  53,  94,   0,  27,  91,  50,  54,  94,   0,  27,  91,  50,  56,  94,   0,  27,
  91,  50,  57,  94,   0,  27,  91,  51,  49,  94,   0,  27,  91,  51,  50,  94,
   0,  27,  91,  51,  51,  94,   0,  27,  91,  51,  52,  94,   0,  27,  91,  50,
  51,  64,   0,  27,  91,  50,  52,  64,   0,  27,  91,  49,  75,   0,  27,  91,
  37, 105,  37, 100,  59,  37, 100,  82,   0,  27,  91,  54, 110,   0,  27,  91,
  63,  49,  59,  50,  99,   0,  27,  91,  99,   0,  27,  91,  51,  57,  59,  52,
  57, 109,   0,  27,  93,  49,  48,  52,   7,   0,  27,  93,  52,  59,  37, 112,
  49,  37, 100,  59, 114, 103,  98,  58,  37, 112,  50,  37, 123,  50,  53,  53,
 125,  37,  42,  37, 123,  49,  48,  48,  48, 125,  37,  47,  37,  50,  46,  50,
  88,  47,  37, 112,  51,  37, 123,  50,  53,  53, 125,  37,  42,  37, 123,  49,
  48,  48,  48, 125,  37,  47,  37,  50,  46,  50,  88,  47,  37, 112,  52,  37,
 123,  50,  53,  53, 125,  37,  42,  37, 123,  49,  48,  48,  48, 125,  37,  47,
  37,  50,  46,  50,  88,  27,  92,   0,  27,  91,  77,   0,  27,  91,  37,  63,
  37, 112,  49,  37, 123,  56, 125,  37,  60,  37, 116,  51,  37, 112,  49,  37,
 100,  37, 101,  37, 112,  49,  37, 123,  49,  54, 125,  37,  60,  37, 116,  57,
  37, 112,  49,  37, 123,  56, 125,  37,  45,  37, 100,  37, 101,  51,  56,  59,
  53,  59,  37, 112,  49,  37, 100,  37,  59, 109,   0,  27,  91,  37,  63,  37,
 112,  49,  37, 123,  56, 125,  37,  60,  37, 116,  52,  37, 112,  49,  37, 100,
  37, 101,  37, 112,  49,  37, 123,  49,  54, 125,  37,  60,  37, 116,  49,  48,
  37, 112,  49,  37, 123,  56, 125,  37,  45,  37, 100,  37, 101,  52,  56,  59,
  53,  59,  37, 112,  49,  37, 100,  37,  59, 109,   0,  27,  40,  66,   0,  27,
  40,  48,   0
};
// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
// This is a 16-colour terminfo description that lacks true-colour
// and 256-colour capabilities that linux (4.8+) actually has.
static const char linux_16colour_terminfo[] = {
  26,   1,  43,   0,  29,   0,  16,   0, 125,   1, 125,   3, 108, 105, 110, 117,
 120,  45,  49,  54,  99, 111, 108, 111, 114, 124, 108, 105, 110, 117, 120,  32,
  99, 111, 110, 115, 111, 108, 101,  32, 119, 105, 116, 104,  32,  49,  54,  32,
  99, 111, 108, 111, 114, 115,   0,   0,   1,   0,   0,   1,   1,   0,   0,   0,
   0,   0,   0,   0,   1,   1,   0,   0,   0,   0,   0,   1,   0,   0,   0,   0,
   0,   0,   1,   1,  -1,  -1,   8,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  16,   0,
   0,   1,  42,   0,  -1,  -1,   0,   0,   2,   0,   4,   0,  21,   0,  26,   0,
  33,   0,  37,   0,  41,   0,  -1,  -1,  52,   0,  69,   0,  71,   0,  75,   0,
  87,   0,  -1,  -1,  89,   0, 101,   0,  -1,  -1, 105,   0, 109,   0, 121,   0,
 125,   0,  -1,  -1,  -1,  -1,-127,   0,-125,   0,-120,   0,  -1,  -1,  -1,  -1,
-115,   0,-110,   0,  -1,  -1,  -1,  -1,-105,   0,-100,   0, -95,   0, -90,   0,
 -81,   0, -79,   0,  -1,  -1,  -1,  -1, -74,   0, -69,   0, -63,   0, -57,   0,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -39,   0, -35,   0,
  -1,  -1, -31,   0,  -1,  -1,  -1,  -1,  -1,  -1, -29,   0,  -1,  -1, -24,   0,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -20,   0, -15,   0,  -9,   0,  -4,   0,
   1,   1,   6,   1,  11,   1,  17,   1,  23,   1,  29,   1,  35,   1,  40,   1,
  -1,  -1,  45,   1,  -1,  -1,  49,   1,  54,   1,  59,   1,  -1,  -1,  -1,  -1,
  -1,  -1,  63,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  67,   1,  -1,  -1,  70,   1,  79,   1,  88,   1,  97,   1,  -1,  -1,
 106,   1, 115,   1, 124,   1,  -1,  -1,-123,   1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,-114,   1,  -1,  -1,  -1,  -1,  -1,  -1,
-108,   1,-105,   1, -94,   1, -91,   1, -89,   1, -86,   1,   1,   2,  -1,  -1,
   4,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,   6,   2,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  10,   2,  -1,  -1,  77,   2,  -1,  -1,
  -1,  -1,  81,   2,  87,   2,  -1,  -1,  -1,  -1,  93,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  97,   2,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, 102,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, 104,   2, 110,   2, 116,   2, 122,   2,-128,   2,-122,   2,
-116,   2,-110,   2,-104,   2, -98,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -92,   2,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -87,   2,
 -76,   2, -71,   2, -65,   2, -61,   2, -52,   2, -48,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  33,   3,  -1,  -1,  -1,  -1,
  -1,  -1,  37,   3,  75,   3,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 113,   3, 119,   3,   7,   0,
  13,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  59,  37, 112,  50,  37,
 100, 114,   0,  27,  91,  51, 103,   0,  27,  91,  72,  27,  91,  74,   0,  27,
  91,  75,   0,  27,  91,  74,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,
  71,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  59,  37, 112,  50,  37,
 100,  72,   0,  10,   0,  27,  91,  72,   0,  27,  91,  63,  50,  53, 108,  27,
  91,  63,  49,  99,   0,   8,   0,  27,  91,  63,  50,  53, 104,  27,  91,  63,
  48,  99,   0,  27,  91,  67,   0,  27,  91,  65,   0,  27,  91,  63,  50,  53,
 104,  27,  91,  63,  56,  99,   0,  27,  91,  80,   0,  27,  91,  77,   0,  14,
   0,  27,  91,  53, 109,   0,  27,  91,  49, 109,   0,  27,  91,  50, 109,   0,
  27,  91,  52, 104,   0,  27,  91,  55, 109,   0,  27,  91,  55, 109,   0,  27,
  91,  52, 109,   0,  27,  91,  37, 112,  49,  37, 100,  88,   0,  15,   0,  27,
  91, 109,  15,   0,  27,  91,  52, 108,   0,  27,  91,  50,  55, 109,   0,  27,
  91,  50,  52, 109,   0,  27,  91,  63,  53, 104,  36,  60,  50,  48,  48,  47,
  62,  27,  91,  63,  53, 108,   0,  27,  91,  64,   0,  27,  91,  76,   0, 127,
   0,  27,  91,  51, 126,   0,  27,  91,  66,   0,  27,  91,  91,  65,   0,  27,
  91,  50,  49, 126,   0,  27,  91,  91,  66,   0,  27,  91,  91,  67,   0,  27,
  91,  91,  68,   0,  27,  91,  91,  69,   0,  27,  91,  49,  55, 126,   0,  27,
  91,  49,  56, 126,   0,  27,  91,  49,  57, 126,   0,  27,  91,  50,  48, 126,
   0,  27,  91,  49, 126,   0,  27,  91,  50, 126,   0,  27,  91,  68,   0,  27,
  91,  54, 126,   0,  27,  91,  53, 126,   0,  27,  91,  67,   0,  27,  91,  65,
   0,  13,  10,   0,  27,  91,  37, 112,  49,  37, 100,  80,   0,  27,  91,  37,
 112,  49,  37, 100,  77,   0,  27,  91,  37, 112,  49,  37, 100,  66,   0,  27,
  91,  37, 112,  49,  37, 100,  64,   0,  27,  91,  37, 112,  49,  37, 100,  76,
   0,  27,  91,  37, 112,  49,  37, 100,  68,   0,  27,  91,  37, 112,  49,  37,
 100,  67,   0,  27,  91,  37, 112,  49,  37, 100,  65,   0,  27,  99,  27,  93,
  82,   0,  27,  56,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100, 100,   0,
  27,  55,   0,  10,   0,  27,  77,   0,  27,  91,  48,  59,  49,  48,  37,  63,
  37, 112,  49,  37, 116,  59,  55,  37,  59,  37,  63,  37, 112,  50,  37, 116,
  59,  52,  37,  59,  37,  63,  37, 112,  51,  37, 116,  59,  55,  37,  59,  37,
  63,  37, 112,  52,  37, 116,  59,  53,  37,  59,  37,  63,  37, 112,  53,  37,
 116,  59,  50,  37,  59,  37,  63,  37, 112,  54,  37, 116,  59,  49,  37,  59,
 109,  37,  63,  37, 112,  57,  37, 116,  14,  37, 101,  15,  37,  59,   0,  27,
  72,   0,   9,   0,  27,  91,  71,   0,  43,  43,  44,  44,  45,  45,  46,  46,
  48,  48,  95,  95,  96,  96,  97,  97, 102, 102, 103, 103, 104, 104, 105, 105,
 106, 106, 107, 107, 108, 108, 109, 109, 110, 110, 111, 111, 112, 112, 113, 113,
 114, 114, 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120, 121, 121,
 122, 122, 123, 123, 124, 124, 125,  99, 126, 126,   0,  27,  91,  90,   0,  27,
  91,  63,  55, 104,   0,  27,  91,  63,  55, 108,   0,  27,  41,  48,   0,  27,
  91,  52, 126,   0,  26,   0,  27,  91,  50,  51, 126,   0,  27,  91,  50,  52,
 126,   0,  27,  91,  50,  53, 126,   0,  27,  91,  50,  54, 126,   0,  27,  91,
  50,  56, 126,   0,  27,  91,  50,  57, 126,   0,  27,  91,  51,  49, 126,   0,
  27,  91,  51,  50, 126,   0,  27,  91,  51,  51, 126,   0,  27,  91,  51,  52,
 126,   0,  27,  91,  49,  75,   0,  27,  91,  37, 105,  37, 100,  59,  37, 100,
  82,   0,  27,  91,  54, 110,   0,  27,  91,  63,  54,  99,   0,  27,  91,  99,
   0,  27,  91,  51,  57,  59,  52,  57, 109,   0,  27,  93,  82,   0,  27,  93,
  80,  37, 112,  49,  37, 120,  37, 112,  50,  37, 123,  50,  53,  53, 125,  37,
  42,  37, 123,  49,  48,  48,  48, 125,  37,  47,  37,  48,  50, 120,  37, 112,
  51,  37, 123,  50,  53,  53, 125,  37,  42,  37, 123,  49,  48,  48,  48, 125,
  37,  47,  37,  48,  50, 120,  37, 112,  52,  37, 123,  50,  53,  53, 125,  37,
  42,  37, 123,  49,  48,  48,  48, 125,  37,  47,  37,  48,  50, 120,   0,  27,
  91,  77,   0,  27,  91,  51,  37, 112,  49,  37, 123,  56, 125,  37, 109,  37,
 100,  37,  63,  37, 112,  49,  37, 123,  55, 125,  37,  62,  37, 116,  59,  49,
  37, 101,  59,  50,  49,  37,  59, 109,   0,  27,  91,  52,  37, 112,  49,  37,
 123,  56, 125,  37, 109,  37, 100,  37,  63,  37, 112,  49,  37, 123,  55, 125,
  37,  62,  37, 116,  59,  53,  37, 101,  59,  50,  53,  37,  59, 109,   0,  27,
  91,  49,  49, 109,   0,  27,  91,  49,  48, 109,   0
};
// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
static const char putty_256colour_terminfo[] = {
  26,   1,  48,   0,  29,   0,  16,   0, 125,   1,-106,   4, 112, 117, 116, 116,
 121,  45,  50,  53,  54,  99, 111, 108, 111, 114, 124,  80, 117,  84,  84,  89,
  32,  48,  46,  53,  56,  32, 119, 105, 116, 104,  32, 120, 116, 101, 114, 109,
  32,  50,  53,  54,  45,  99, 111, 108, 111, 114, 115,   0,   1,   1,   0,   0,
   1,   0,   0,   0,   0,   1,   0,   0,   0,   1,   1,   0,   0,   0,   0,   0,
   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,  -1,  -1,   8,   0,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,   0,   1,  -1, 127,  22,   0,   0,   0,   4,   0,   6,   0,
   8,   0,  25,   0,  30,   0,  37,   0,  41,   0,  45,   0,  -1,  -1,  56,   0,
  73,   0,  76,   0,  80,   0,  87,   0,  -1,  -1,  89,   0,  96,   0,  -1,  -1,
 100,   0,  -1,  -1, 103,   0, 107,   0, 111,   0,  -1,  -1, 117,   0, 119,   0,
 124,   0,-127,   0,  -1,  -1,  -1,  -1,-120,   0,  -1,  -1,  -1,  -1,-115,   0,
-110,   0,-105,   0,-100,   0, -91,   0, -89,   0, -84,   0,  -1,  -1, -73,   0,
 -68,   0, -62,   0, -56,   0,  -1,  -1, -38,   0,  -1,  -1, -36,   0,  -1,  -1,
  -1,  -1,  -1,  -1,  -2,   0,  -1,  -1,   2,   1,  -1,  -1,  -1,  -1,  -1,  -1,
   4,   1,  -1,  -1,   9,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  13,   1,
  19,   1,  25,   1,  31,   1,  37,   1,  43,   1,  49,   1,  55,   1,  61,   1,
  67,   1,  73,   1,  78,   1,  -1,  -1,  83,   1,  -1,  -1,  87,   1,  92,   1,
  97,   1, 101,   1, 105,   1,  -1,  -1, 109,   1, 113,   1, 121,   1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,-127,   1,  -1,  -1,-124,   1,-115,   1,
-106,   1,  -1,  -1, -97,   1, -88,   1, -79,   1, -70,   1, -61,   1, -52,   1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
 -43,   1,  -1,  -1,  -1,  -1, -10,   1,  -7,   1,   4,   2,   7,   2,   9,   2,
  12,   2,  84,   2,  -1,  -1,  87,   2,  89,   2,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  94,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  98,   2,
  -1,  -1,-107,   2,  -1,  -1,  -1,  -1,-103,   2, -97,   2,  -1,  -1,  -1,  -1,
 -91,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1, -84,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -79,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -77,   2,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -73,   2,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -69,   2, -63,   2, -57,   2,
 -51,   2, -45,   2, -39,   2, -33,   2, -27,   2, -21,   2, -15,   2,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -9,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -4,   2,   7,   3,  12,   3,  18,   3,  22,   3,  31,   3,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  35,   3,  -1,  -1,  -1,  -1,  -1,  -1,  39,   3, 102,   3,  -1,  -1,  -1,  -1,
  -1,  -1, -90,   3, -84,   3, -78,   3,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -72,   3,
-118,   4,-112,   4,  27,  91,  90,   0,   7,   0,  13,   0,  27,  91,  37, 105,
  37, 112,  49,  37, 100,  59,  37, 112,  50,  37, 100, 114,   0,  27,  91,  51,
 103,   0,  27,  91,  72,  27,  91,  74,   0,  27,  91,  75,   0,  27,  91,  74,
   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  71,   0,  27,  91,  37, 105,
  37, 112,  49,  37, 100,  59,  37, 112,  50,  37, 100,  72,   0,  27,  68,   0,
  27,  91,  72,   0,  27,  91,  63,  50,  53, 108,   0,   8,   0,  27,  91,  63,
  50,  53, 104,   0,  27,  91,  67,   0,  27,  77,   0,  27,  91,  80,   0,  27,
  91,  77,   0,  27,  93,  48,  59,   7,   0,  14,   0,  27,  91,  53, 109,   0,
  27,  91,  49, 109,   0,  27,  91,  63,  52,  55, 104,   0,  27,  91,  52, 104,
   0,  27,  91,  55, 109,   0,  27,  91,  55, 109,   0,  27,  91,  52, 109,   0,
  27,  91,  37, 112,  49,  37, 100,  88,   0,  15,   0,  27,  91, 109,  15,   0,
  27,  91,  50,  74,  27,  91,  63,  52,  55, 108,   0,  27,  91,  52, 108,   0,
  27,  91,  50,  55, 109,   0,  27,  91,  50,  52, 109,   0,  27,  91,  63,  53,
 104,  36,  60,  49,  48,  48,  47,  62,  27,  91,  63,  53, 108,   0,   7,   0,
  27,  55,  27,  91, 114,  27,  91, 109,  27,  91,  63,  55, 104,  27,  91,  63,
  49,  59,  52,  59,  54, 108,  27,  91,  52, 108,  27,  56,  27,  62,  27,  93,
  82,   0,  27,  91,  76,   0, 127,   0,  27,  91,  51, 126,   0,  27,  79,  66,
   0,  27,  91,  49,  49, 126,   0,  27,  91,  50,  49, 126,   0,  27,  91,  49,
  50, 126,   0,  27,  91,  49,  51, 126,   0,  27,  91,  49,  52, 126,   0,  27,
  91,  49,  53, 126,   0,  27,  91,  49,  55, 126,   0,  27,  91,  49,  56, 126,
   0,  27,  91,  49,  57, 126,   0,  27,  91,  50,  48, 126,   0,  27,  91,  49,
 126,   0,  27,  91,  50, 126,   0,  27,  79,  68,   0,  27,  91,  54, 126,   0,
  27,  91,  53, 126,   0,  27,  79,  67,   0,  27,  91,  66,   0,  27,  91,  65,
   0,  27,  79,  65,   0,  27,  91,  63,  49, 108,  27,  62,   0,  27,  91,  63,
  49, 104,  27,  61,   0,  13,  10,   0,  27,  91,  37, 112,  49,  37, 100,  80,
   0,  27,  91,  37, 112,  49,  37, 100,  77,   0,  27,  91,  37, 112,  49,  37,
 100,  66,   0,  27,  91,  37, 112,  49,  37, 100,  83,   0,  27,  91,  37, 112,
  49,  37, 100,  76,   0,  27,  91,  37, 112,  49,  37, 100,  68,   0,  27,  91,
  37, 112,  49,  37, 100,  67,   0,  27,  91,  37, 112,  49,  37, 100,  84,   0,
  27,  91,  37, 112,  49,  37, 100,  65,   0,  27,  60,  27,  91,  34, 112,  27,
  91,  53,  48,  59,  54,  34, 112,  27,  99,  27,  91,  63,  51, 108,  27,  93,
  82,  27,  91,  63,  49,  48,  48,  48, 108,   0,  27,  56,   0,  27,  91,  37,
 105,  37, 112,  49,  37, 100, 100,   0,  27,  55,   0,  10,   0,  27,  77,   0,
  27,  91,  48,  37,  63,  37, 112,  49,  37, 112,  54,  37, 124,  37, 116,  59,
  49,  37,  59,  37,  63,  37, 112,  50,  37, 116,  59,  52,  37,  59,  37,  63,
  37, 112,  49,  37, 112,  51,  37, 124,  37, 116,  59,  55,  37,  59,  37,  63,
  37, 112,  52,  37, 116,  59,  53,  37,  59, 109,  37,  63,  37, 112,  57,  37,
 116,  14,  37, 101,  15,  37,  59,   0,  27,  72,   0,   9,   0,  27,  93,  48,
  59,   0,  27,  91,  71,   0,  96,  96,  97,  97, 102, 102, 103, 103, 106, 106,
 107, 107, 108, 108, 109, 109, 110, 110, 111, 111, 112, 112, 113, 113, 114, 114,
 115, 115, 116, 116, 117, 117, 118, 118, 119, 119, 120, 120, 121, 121, 122, 122,
 123, 123, 124, 124, 125, 125, 126, 126,   0,  27,  91,  90,   0,  27,  91,  63,
  55, 104,   0,  27,  91,  63,  55, 108,   0,  27,  40,  66,  27,  41,  48,   0,
  27,  91,  52, 126,   0,  26,   0,  27,  91,  68,   0,  27,  91,  67,   0,  27,
  91,  50,  51, 126,   0,  27,  91,  50,  52, 126,   0,  27,  91,  50,  53, 126,
   0,  27,  91,  50,  54, 126,   0,  27,  91,  50,  56, 126,   0,  27,  91,  50,
  57, 126,   0,  27,  91,  51,  49, 126,   0,  27,  91,  51,  50, 126,   0,  27,
  91,  51,  51, 126,   0,  27,  91,  51,  52, 126,   0,  27,  91,  49,  75,   0,
  27,  91,  37, 105,  37, 100,  59,  37, 100,  82,   0,  27,  91,  54, 110,   0,
  27,  91,  63,  54,  99,   0,  27,  91,  99,   0,  27,  91,  51,  57,  59,  52,
  57, 109,   0,  27,  93,  82,   0,  27,  91,  77,   0,  27,  91,  37,  63,  37,
 112,  49,  37, 123,  56, 125,  37,  60,  37, 116,  51,  37, 112,  49,  37, 100,
  37, 101,  37, 112,  49,  37, 123,  49,  54, 125,  37,  60,  37, 116,  57,  37,
 112,  49,  37, 123,  56, 125,  37,  45,  37, 100,  37, 101,  51,  56,  59,  53,
  59,  37, 112,  49,  37, 100,  37,  59, 109,   0,  27,  91,  37,  63,  37, 112,
  49,  37, 123,  56, 125,  37,  60,  37, 116,  52,  37, 112,  49,  37, 100,  37,
 101,  37, 112,  49,  37, 123,  49,  54, 125,  37,  60,  37, 116,  49,  48,  37,
 112,  49,  37, 123,  56, 125,  37,  45,  37, 100,  37, 101,  52,  56,  59,  53,
  59,  37, 112,  49,  37, 100,  37,  59, 109,   0,  27,  91,  49,  48, 109,   0,
  27,  91,  49,  49, 109,   0,  27,  91,  49,  50, 109,   0,  37,  63,  37, 112,
  49,  37, 123,  56, 125,  37,  61,  37, 116,  27,  37,  37,  71, -30,-105,-104,
  27,  37,  37,  64,  37, 101,  37, 112,  49,  37, 123,  49,  48, 125,  37,  61,
  37, 116,  27,  37,  37,  71, -30,-105,-103,  27,  37,  37,  64,  37, 101,  37,
 112,  49,  37, 123,  49,  50, 125,  37,  61,  37, 116,  27,  37,  37,  71, -30,
-103,-128,  27,  37,  37,  64,  37, 101,  37, 112,  49,  37, 123,  49,  51, 125,
  37,  61,  37, 116,  27,  37,  37,  71, -30,-103, -86,  27,  37,  37,  64,  37,
 101,  37, 112,  49,  37, 123,  49,  52, 125,  37,  61,  37, 116,  27,  37,  37,
  71, -30,-103, -85,  27,  37,  37,  64,  37, 101,  37, 112,  49,  37, 123,  49,
  53, 125,  37,  61,  37, 116,  27,  37,  37,  71, -30,-104, -68,  27,  37,  37,
  64,  37, 101,  37, 112,  49,  37, 123,  50,  55, 125,  37,  61,  37, 116,  27,
  37,  37,  71, -30,-122,-112,  27,  37,  37,  64,  37, 101,  37, 112,  49,  37,
 123,  49,  53,  53, 125,  37,  61,  37, 116,  27,  37,  37,  71, -32,-126, -94,
  27,  37,  37,  64,  37, 101,  37, 112,  49,  37,  99,  37,  59,   0,  27,  91,
  49,  49, 109,   0,  27,  91,  49,  48, 109,   0
};
// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
static const char interix_8colour_terminfo[] = {
  26,   1,  82,   0,  15,   0,  16,   0, 105,   1, 123,   2, 105, 110, 116, 101,
 114, 105, 120, 124, 111, 112, 101, 110, 110, 116, 124, 111, 112, 101, 110, 110,
 116,  45,  50,  53, 124, 110, 116,  99, 111, 110, 115, 111, 108, 101, 124, 110,
 116,  99, 111, 110, 115, 111, 108, 101,  45,  50,  53, 124,  79, 112, 101, 110,
  78,  84,  45, 116, 101, 114, 109,  32,  99, 111, 109, 112,  97, 116, 105,  98,
 108, 101,  32, 119, 105, 116, 104,  32,  99, 111, 108, 111, 114,   0,   1,   1,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   1,   0,  80,   0,
  -1,  -1,  25,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,   8,   0,  64,   0,   3,   0,   0,   0,
   4,   0,  -1,  -1,  -1,  -1,  -1,  -1,   6,   0,  11,   0,  15,   0,  -1,  -1,
  -1,  -1,  19,   0,  36,   0,  38,   0,  -1,  -1,  42,   0,  -1,  -1,  -1,  -1,
  46,   0,  50,   0,  54,   0,  -1,  -1,  -1,  -1,  58,   0,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  62,   0,  67,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  75,   0,  80,   0,  85,   0,  -1,  -1,  -1,  -1,  90,   0,  95,   0,
  -1,  -1,  -1,  -1, 107,   0, 111,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 115,   0,  -1,  -1, 119,   0,  -1,  -1,
  -1,  -1,  -1,  -1, 121,   0,  -1,  -1, 125,   0,  -1,  -1,  -1,  -1,  -1,  -1,
-127,   0,-123,   0,-119,   0,-115,   0,-111,   0,-107,   0,-103,   0, -99,   0,
 -95,   0, -91,   0, -87,   0,  -1,  -1, -83,   0,  -1,  -1, -79,   0, -75,   0,
 -71,   0, -67,   0, -63,   0,  -1,  -1,  -1,  -1,  -1,  -1, -59,   0,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -55,   0,  -1,  -1,
  -1,  -1, -52,   0, -43,   0,  -1,  -1, -34,   0, -25,   0, -16,   0,  -7,   0,
   2,   1,  11,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  20,   1,  -1,  -1,  -1,  -1,  -1,  -1,  23,   1,  -1,  -1,  27,   1,
  31,   1,  35,   1,  -1,  -1,  -1,  -1,  -1,  -1,  39,   1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  41,   1,  -1,  -1, 104,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1, 108,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 112,   1,
 116,   1, 120,   1, 124,   1,-128,   1,-124,   1,-120,   1,-116,   1,-112,   1,
-108,   1,-104,   1,-100,   1, -96,   1, -92,   1, -88,   1, -84,   1, -80,   1,
 -76,   1, -72,   1, -68,   1, -64,   1, -60,   1, -56,   1, -52,   1, -48,   1,
 -44,   1, -40,   1, -36,   1, -32,   1, -28,   1, -24,   1, -20,   1, -16,   1,
 -12,   1,  -8,   1,  -4,   1,   0,   2,   4,   2,   8,   2,  12,   2,  16,   2,
  20,   2,  24,   2,  28,   2,  32,   2,  36,   2,  40,   2,  44,   2,  48,   2,
  52,   2,  56,   2,  60,   2,  64,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  68,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  72,   2,  88,   2,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 103,   2, 113,   2,
  27,  91,  90,   0,   7,   0,  27,  91,  50,  74,   0,  27,  91,  75,   0,  27,
  91,  74,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  59,  37, 112,  50,
  37, 100,  72,   0,  10,   0,  27,  91,  72,   0,  27,  91,  68,   0,  27,  91,
  67,   0,  27,  91,  85,   0,  27,  91,  65,   0,  27,  91,  77,   0,  27,  91,
  49, 109,   0,  27,  91, 115,  27,  91,  49,  98,   0,  27,  91,  55, 109,   0,
  27,  91,  55, 109,   0,  27,  91,  52, 109,   0,  27,  91,  48, 109,   0,  27,
  91,  50,  98,  27,  91, 117,  13,  27,  91,  75,   0,  27,  91, 109,   0,  27,
  91, 109,   0,  27,  91,  76,   0,   8,   0,  27,  91,  77,   0,  27,  91,  66,
   0,  27,  70,  65,   0,  27,  70,  49,   0,  27,  70,  65,   0,  27,  70,  50,
   0,  27,  70,  51,   0,  27,  70,  52,   0,  27,  70,  53,   0,  27,  70,  54,
   0,  27,  70,  55,   0,  27,  70,  56,   0,  27,  70,  57,   0,  27,  91,  76,
   0,  27,  91,  68,   0,  27,  91,  85,   0,  27,  91,  84,   0,  27,  91,  83,
   0,  27,  91,  67,   0,  27,  91,  65,   0,  13,  10,   0,  27,  91,  37, 112,
  49,  37, 100,  77,   0,  27,  91,  37, 112,  49,  37, 100,  66,   0,  27,  91,
  37, 112,  49,  37, 100,  83,   0,  27,  91,  37, 112,  49,  37, 100,  76,   0,
  27,  91,  37, 112,  49,  37, 100,  68,   0,  27,  91,  37, 112,  49,  37, 100,
  67,   0,  27,  91,  37, 112,  49,  37, 100,  84,   0,  27,  91,  37, 112,  49,
  37, 100,  65,   0,  27,  99,   0,  27,  91, 117,   0,  27,  91, 115,   0,  27,
  91,  83,   0,  27,  91,  84,   0,   9,   0,  43,  16,  44,  17,  45,  24,  46,
  25,  48, -37,  96,   4,  97, -79, 102,  -8, 103, -15, 104, -80, 106, -39, 107,
 -65, 108, -38, 109, -64, 110, -59, 111, 126, 112, -60, 113, -60, 114, -60, 115,
  95, 116, -61, 117, -76, 118, -63, 119, -62, 120, -77, 121, -13, 122, -14, 123,
 -29, 124, -40, 125,-100, 126,  -2,   0,  27,  91,  90,   0,  27,  91,  85,   0,
  27,  70,  66,   0,  27,  70,  67,   0,  27,  70,  68,   0,  27,  70,  69,   0,
  27,  70,  70,   0,  27,  70,  71,   0,  27,  70,  72,   0,  27,  70,  73,   0,
  27,  70,  74,   0,  27,  70,  75,   0,  27,  70,  76,   0,  27,  70,  77,   0,
  27,  70,  78,   0,  27,  70,  79,   0,  27,  70,  80,   0,  27,  70,  81,   0,
  27,  70,  82,   0,  27,  70,  83,   0,  27,  70,  84,   0,  27,  70,  85,   0,
  27,  70,  86,   0,  27,  70,  87,   0,  27,  70,  88,   0,  27,  70,  89,   0,
  27,  70,  90,   0,  27,  70,  97,   0,  27,  70,  98,   0,  27,  70,  99,   0,
  27,  70, 100,   0,  27,  70, 101,   0,  27,  70, 102,   0,  27,  70, 103,   0,
  27,  70, 104,   0,  27,  70, 105,   0,  27,  70, 106,   0,  27,  70, 107,   0,
  27,  70, 109,   0,  27,  70, 110,   0,  27,  70, 111,   0,  27,  70, 112,   0,
  27,  70, 113,   0,  27,  70, 114,   0,  27,  70, 115,   0,  27,  70, 116,   0,
  27,  70, 117,   0,  27,  70, 118,   0,  27,  70, 119,   0,  27,  70, 120,   0,
  27,  70, 121,   0,  27,  70, 122,   0,  27,  70,  43,   0,  27,  70,  45,   0,
  27,  70,  12,   0,  27,  91, 109,   0,  27,  91,  37, 112,  49,  37, 123,  51,
  48, 125,  37,  43,  37, 100, 109,   0,  27,  91,  37, 112,  49,  37,  39,  40,
  39,  37,  43,  37, 100, 109,   0,  27,  91,  51,  37, 112,  49,  37, 100, 109,
   0,  27,  91,  52,  37, 112,  49,  37, 100, 109,   0
};
// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
// This is a 256-colour terminfo description that lacks true-colour
// capabilities that stterm actually has.
static const char st_256colour_terminfo[] = {
  26,   1,  55,   0,  29,   0,  15,   0, 105,   1, 117,   5, 115, 116,  45,  50,
  53,  54,  99, 111, 108, 111, 114, 124, 115, 116, 116, 101, 114, 109,  45,  50,
  53,  54,  99, 111, 108, 111, 114, 124, 115, 105, 109, 112, 108, 101, 116, 101,
 114, 109,  32, 119, 105, 116, 104,  32,  50,  53,  54,  32,  99, 111, 108, 111,
 114, 115,   0,   0,   1,   0,   0,   1,   0,   0,   0,   0,   1,   0,   0,   0,
   1,   1,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   1,
  80,   0,   8,   0,  24,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,   0,   1,  -1, 127,   0,   0,
   4,   0,   6,   0,   8,   0,  25,   0,  30,   0,  38,   0,  42,   0,  46,   0,
  -1,  -1,  57,   0,  74,   0,  76,   0,  80,   0,  87,   0,  -1,  -1,  89,   0,
 102,   0,  -1,  -1, 106,   0, 110,   0, 117,   0, 121,   0,  -1,  -1,  -1,  -1,
 125,   0,-127,   0,-122,   0,-117,   0,  -1,  -1,  -1,  -1,-108,   0,-103,   0,
  -1,  -1, -98,   0, -93,   0, -88,   0, -83,   0, -74,   0, -70,   0, -65,   0,
  -1,  -1, -56,   0, -51,   0, -45,   0, -39,   0,  -1,  -1, -21,   0,  -1,  -1,
 -19,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -4,   0,  -1,  -1,   0,   1,  -1,  -1,
   2,   1,  -1,  -1,   9,   1,  14,   1,  21,   1,  25,   1,  32,   1,  39,   1,
  -1,  -1,  46,   1,  50,   1,  56,   1,  60,   1,  64,   1,  68,   1,  74,   1,
  80,   1,  86,   1,  92,   1,  98,   1, 103,   1, 108,   1, 115,   1,  -1,  -1,
 119,   1, 124,   1,-127,   1,-123,   1,-116,   1,  -1,  -1,-109,   1,-105,   1,
 -97,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
 -89,   1, -80,   1, -71,   1, -62,   1, -53,   1, -44,   1, -35,   1, -26,   1,
  -1,  -1, -17,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -8,   1,  -4,   1,   1,   2,
  -1,  -1,   6,   2,   9,   2,  -1,  -1,  -1,  -1,  24,   2,  27,   2,  38,   2,
  41,   2,  43,   2,  46,   2,-128,   2,  -1,  -1,-125,   2,-123,   2,  -1,  -1,
  -1,  -1,  -1,  -1,-118,   2,-113,   2,-108,   2,-104,   2, -99,   2,  -1,  -1,
  -1,  -1, -94,   2,  -1,  -1, -29,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, -25,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1, -21,   2, -16,   2,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -12,   2,  -1,  -1,
  -1,  -1,  -5,   2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,   2,   3,   9,   3,
  16,   3,  -1,  -1,  -1,  -1,  23,   3,  -1,  -1,  30,   3,  -1,  -1,  -1,  -1,
  -1,  -1,  37,   3,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  44,   3,
  50,   3,  56,   3,  63,   3,  70,   3,  77,   3,  84,   3,  92,   3, 100,   3,
 108,   3, 116,   3, 124,   3,-124,   3,-116,   3,-108,   3,-101,   3, -94,   3,
 -87,   3, -80,   3, -72,   3, -64,   3, -56,   3, -48,   3, -40,   3, -32,   3,
 -24,   3, -16,   3,  -9,   3,  -2,   3,   5,   4,  12,   4,  20,   4,  28,   4,
  36,   4,  44,   4,  52,   4,  60,   4,  68,   4,  76,   4,  83,   4,  90,   4,
  97,   4, 104,   4, 112,   4, 120,   4,-128,   4,-120,   4,-112,   4,-104,   4,
 -96,   4, -88,   4, -81,   4, -74,   4, -67,   4,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -62,   4, -51,   4, -46,   4, -38,   4,
 -34,   4,  -2,  -1,  -2,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -25,   4,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
 -20,   4,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, -14,   4,  -1,  -1,  -1,  -1,  -1,  -1, -10,   4,  53,   5,
  27,  91,  90,   0,   7,   0,  13,   0,  27,  91,  37, 105,  37, 112,  49,  37,
 100,  59,  37, 112,  50,  37, 100, 114,   0,  27,  91,  51, 103,   0,  27,  91,
  72,  27,  91,  50,  74,   0,  27,  91,  75,   0,  27,  91,  74,   0,  27,  91,
  37, 105,  37, 112,  49,  37, 100,  71,   0,  27,  91,  37, 105,  37, 112,  49,
  37, 100,  59,  37, 112,  50,  37, 100,  72,   0,  10,   0,  27,  91,  72,   0,
  27,  91,  63,  50,  53, 108,   0,   8,   0,  27,  91,  63,  49,  50, 108,  27,
  91,  63,  50,  53, 104,   0,  27,  91,  67,   0,  27,  91,  65,   0,  27,  91,
  63,  50,  53, 104,   0,  27,  91,  80,   0,  27,  91,  77,   0,  27,  40,  48,
   0,  27,  91,  53, 109,   0,  27,  91,  49, 109,   0,  27,  91,  63,  49,  48,
  52,  57, 104,   0,  27,  91,  52, 104,   0,  27,  91,  56, 109,   0,  27,  91,
  55, 109,   0,  27,  91,  55, 109,   0,  27,  91,  52, 109,   0,  27,  91,  37,
 112,  49,  37, 100,  88,   0,  27,  40,  66,   0,  27,  91,  48, 109,   0,  27,
  91,  63,  49,  48,  52,  57, 108,   0,  27,  91,  52, 108,   0,  27,  91,  50,
  55, 109,   0,  27,  91,  50,  52, 109,   0,  27,  91,  63,  53, 104,  36,  60,
  49,  48,  48,  47,  62,  27,  91,  63,  53, 108,   0,   7,   0,  27,  91,  52,
 108,  27,  62,  27,  91,  63,  49,  48,  51,  52, 108,   0,  27,  91,  76,   0,
 127,   0,  27,  91,  51,  59,  53, 126,   0,  27,  91,  51, 126,   0,  27,  91,
  51,  59,  50, 126,   0,  27,  79,  66,   0,  27,  91,  50,  59,  50, 126,   0,
  27,  91,  49,  59,  50,  70,   0,  27,  91,  49,  59,  53,  70,   0,  27,  79,
  80,   0,  27,  91,  50,  49, 126,   0,  27,  79,  81,   0,  27,  79,  82,   0,
  27,  79,  83,   0,  27,  91,  49,  53, 126,   0,  27,  91,  49,  55, 126,   0,
  27,  91,  49,  56, 126,   0,  27,  91,  49,  57, 126,   0,  27,  91,  50,  48,
 126,   0,  27,  91,  49, 126,   0,  27,  91,  50, 126,   0,  27,  91,  50,  59,
  53, 126,   0,  27,  79,  68,   0,  27,  91,  54, 126,   0,  27,  91,  53, 126,
   0,  27,  79,  67,   0,  27,  91,  49,  59,  50,  66,   0,  27,  91,  49,  59,
  50,  65,   0,  27,  79,  65,   0,  27,  91,  63,  49, 108,  27,  62,   0,  27,
  91,  63,  49, 104,  27,  61,   0,  27,  91,  37, 112,  49,  37, 100,  80,   0,
  27,  91,  37, 112,  49,  37, 100,  77,   0,  27,  91,  37, 112,  49,  37, 100,
  66,   0,  27,  91,  37, 112,  49,  37, 100,  64,   0,  27,  91,  37, 112,  49,
  37, 100,  83,   0,  27,  91,  37, 112,  49,  37, 100,  76,   0,  27,  91,  37,
 112,  49,  37, 100,  68,   0,  27,  91,  37, 112,  49,  37, 100,  67,   0,  27,
  91,  37, 112,  49,  37, 100,  65,   0,  27,  91, 105,   0,  27,  91,  52, 105,
   0,  27,  91,  53, 105,   0,  27,  99,   0,  27,  91,  52, 108,  27,  62,  27,
  91,  63,  49,  48,  51,  52, 108,   0,  27,  56,   0,  27,  91,  37, 105,  37,
 112,  49,  37, 100, 100,   0,  27,  55,   0,  10,   0,  27,  77,   0,  37,  63,
  37, 112,  57,  37, 116,  27,  40,  48,  37, 101,  27,  40,  66,  37,  59,  27,
  91,  48,  37,  63,  37, 112,  54,  37, 116,  59,  49,  37,  59,  37,  63,  37,
 112,  50,  37, 116,  59,  52,  37,  59,  37,  63,  37, 112,  49,  37, 112,  51,
  37, 124,  37, 116,  59,  55,  37,  59,  37,  63,  37, 112,  52,  37, 116,  59,
  53,  37,  59,  37,  63,  37, 112,  55,  37, 116,  59,  56,  37,  59, 109,   0,
  27,  72,   0,   9,   0,  27,  93,  48,  59,   0,  27,  91,  49, 126,   0,  27,
  91,  53, 126,   0,  27,  79, 117,   0,  27,  91,  52, 126,   0,  27,  91,  54,
 126,   0,  43,  67,  44,  68,  45,  65,  46,  66,  48,  69,  96,  96,  97,  97,
 102, 102, 103, 103, 104,  70, 105,  71, 106, 106, 107, 107, 108, 108, 109, 109,
 110, 110, 111, 111, 112, 112, 113, 113, 114, 114, 115, 115, 116, 116, 117, 117,
 118, 118, 119, 119, 120, 120, 121, 121, 122, 122, 123, 123, 124, 124, 125, 125,
 126, 126,   0,  27,  91,  90,   0,  27,  41,  48,   0,  27,  91,  52, 126,   0,
  27,  79,  77,   0,  27,  91,  51,  59,  50, 126,   0,  27,  91,  49,  59,  50,
  70,   0,  27,  91,  49,  59,  50,  72,   0,  27,  91,  50,  59,  50, 126,   0,
  27,  91,  49,  59,  50,  68,   0,  27,  91,  54,  59,  50, 126,   0,  27,  91,
  53,  59,  50, 126,   0,  27,  91,  49,  59,  50,  67,   0,  27,  91,  50,  51,
 126,   0,  27,  91,  50,  52, 126,   0,  27,  91,  49,  59,  50,  80,   0,  27,
  91,  49,  59,  50,  81,   0,  27,  91,  49,  59,  50,  82,   0,  27,  91,  49,
  59,  50,  83,   0,  27,  91,  49,  53,  59,  50, 126,   0,  27,  91,  49,  55,
  59,  50, 126,   0,  27,  91,  49,  56,  59,  50, 126,   0,  27,  91,  49,  57,
  59,  50, 126,   0,  27,  91,  50,  48,  59,  50, 126,   0,  27,  91,  50,  49,
  59,  50, 126,   0,  27,  91,  50,  51,  59,  50, 126,   0,  27,  91,  50,  52,
  59,  50, 126,   0,  27,  91,  49,  59,  53,  80,   0,  27,  91,  49,  59,  53,
  81,   0,  27,  91,  49,  59,  53,  82,   0,  27,  91,  49,  59,  53,  83,   0,
  27,  91,  49,  53,  59,  53, 126,   0,  27,  91,  49,  55,  59,  53, 126,   0,
  27,  91,  49,  56,  59,  53, 126,   0,  27,  91,  49,  57,  59,  53, 126,   0,
  27,  91,  50,  48,  59,  53, 126,   0,  27,  91,  50,  49,  59,  53, 126,   0,
  27,  91,  50,  51,  59,  53, 126,   0,  27,  91,  50,  52,  59,  53, 126,   0,
  27,  91,  49,  59,  54,  80,   0,  27,  91,  49,  59,  54,  81,   0,  27,  91,
  49,  59,  54,  82,   0,  27,  91,  49,  59,  54,  83,   0,  27,  91,  49,  53,
  59,  54, 126,   0,  27,  91,  49,  55,  59,  54, 126,   0,  27,  91,  49,  56,
  59,  54, 126,   0,  27,  91,  49,  57,  59,  54, 126,   0,  27,  91,  50,  48,
  59,  54, 126,   0,  27,  91,  50,  49,  59,  54, 126,   0,  27,  91,  50,  51,
  59,  54, 126,   0,  27,  91,  50,  52,  59,  54, 126,   0,  27,  91,  49,  59,
  51,  80,   0,  27,  91,  49,  59,  51,  81,   0,  27,  91,  49,  59,  51,  82,
   0,  27,  91,  49,  59,  51,  83,   0,  27,  91,  49,  53,  59,  51, 126,   0,
  27,  91,  49,  55,  59,  51, 126,   0,  27,  91,  49,  56,  59,  51, 126,   0,
  27,  91,  49,  57,  59,  51, 126,   0,  27,  91,  50,  48,  59,  51, 126,   0,
  27,  91,  50,  49,  59,  51, 126,   0,  27,  91,  50,  51,  59,  51, 126,   0,
  27,  91,  50,  52,  59,  51, 126,   0,  27,  91,  49,  59,  52,  80,   0,  27,
  91,  49,  59,  52,  81,   0,  27,  91,  49,  59,  52,  82,   0,  27,  91,  49,
  75,   0,  27,  91,  37, 105,  37, 100,  59,  37, 100,  82,   0,  27,  91,  54,
 110,   0,  27,  91,  63,  49,  59,  50,  99,   0,  27,  91,  99,   0,  27,  91,
  51,  57,  59,  52,  57, 109,   0,  27,  91,  51, 109,   0,  27,  91,  50,  51,
 109,   0,  27,  91,  77,   0,  27,  91,  37,  63,  37, 112,  49,  37, 123,  56,
 125,  37,  60,  37, 116,  51,  37, 112,  49,  37, 100,  37, 101,  37, 112,  49,
  37, 123,  49,  54, 125,  37,  60,  37, 116,  57,  37, 112,  49,  37, 123,  56,
 125,  37,  45,  37, 100,  37, 101,  51,  56,  59,  53,  59,  37, 112,  49,  37,
 100,  37,  59, 109,   0,  27,  91,  37,  63,  37, 112,  49,  37, 123,  56, 125,
  37,  60,  37, 116,  52,  37, 112,  49,  37, 100,  37, 101,  37, 112,  49,  37,
 123,  49,  54, 125,  37,  60,  37, 116,  49,  48,  37, 112,  49,  37, 123,  56,
 125,  37,  45,  37, 100,  37, 101,  52,  56,  59,  53,  59,  37, 112,  49,  37,
 100,  37,  59, 109,   0
};
// Taken from Dickey ncurses terminfo.src dated 2017-04-22.
static const char ansi_terminfo[] = {
  26,   1,  40,   0,  23,   0,  16,   0, 125,   1,  68,   2,  97, 110, 115, 105,
 124,  97, 110, 115, 105,  47, 112,  99,  45, 116, 101, 114, 109,  32,  99, 111,
 109, 112,  97, 116, 105,  98, 108, 101,  32, 119, 105, 116, 104,  32,  99, 111,
 108, 111, 114,   0,   0,   1,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   1,   1,   0,   0,   0,   0,   0,   0,   0,   1,   0,  80,   0,   8,   0,
  24,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,   8,   0,  64,   0,   3,   0,   0,   0,   4,   0,
   6,   0,  -1,  -1,   8,   0,  13,   0,  20,   0,  24,   0,  28,   0,  -1,  -1,
  39,   0,  56,   0,  60,   0,  -1,  -1,  64,   0,  -1,  -1,  -1,  -1,  68,   0,
  -1,  -1,  72,   0,  -1,  -1,  76,   0,  80,   0,  -1,  -1,  -1,  -1,  84,   0,
  90,   0,  95,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 100,   0,  -1,  -1,
 105,   0, 110,   0, 115,   0, 120,   0,-127,   0,-121,   0,  -1,  -1,  -1,  -1,
  -1,  -1,-113,   0,-109,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,-105,   0,  -1,  -1,-101,   0,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1, -99,   0,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1, -95,   0, -91,   0,  -1,  -1, -87,   0,  -1,  -1,  -1,  -1,
  -1,  -1, -83,   0,  -1,  -1,  -1,  -1,  -1,  -1, -79,   0,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -75,   0,  -1,  -1, -70,   0,
 -61,   0, -52,   0, -43,   0, -34,   0, -25,   0, -16,   0,  -7,   0,   2,   1,
  11,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  20,   1,  25,   1,  30,   1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  50,   1,  -1,  -1,  61,   1,
  -1,  -1,  63,   1,-107,   1,  -1,  -1,-104,   1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
-100,   1,  -1,  -1, -37,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1, -33,   1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1, -28,   1, -17,   1, -12,   1,   7,   2,  11,   2,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  20,   2,  30,   2,  -1,  -1,
  -1,  -1,  -1,  -1,  40,   2,  44,   2,  48,   2,  52,   2,  -1,  -1,  -1,  -1,
  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
  -1,  -1,  56,   2,  62,   2,  27,  91,  90,   0,   7,   0,  13,   0,  27,  91,
  51, 103,   0,  27,  91,  72,  27,  91,  74,   0,  27,  91,  75,   0,  27,  91,
  74,   0,  27,  91,  37, 105,  37, 112,  49,  37, 100,  71,   0,  27,  91,  37,
 105,  37, 112,  49,  37, 100,  59,  37, 112,  50,  37, 100,  72,   0,  27,  91,
  66,   0,  27,  91,  72,   0,  27,  91,  68,   0,  27,  91,  67,   0,  27,  91,
  65,   0,  27,  91,  80,   0,  27,  91,  77,   0,  27,  91,  49,  49, 109,   0,
  27,  91,  53, 109,   0,  27,  91,  49, 109,   0,  27,  91,  56, 109,   0,  27,
  91,  55, 109,   0,  27,  91,  55, 109,   0,  27,  91,  52, 109,   0,  27,  91,
  37, 112,  49,  37, 100,  88,   0,  27,  91,  49,  48, 109,   0,  27,  91,  48,
  59,  49,  48, 109,   0,  27,  91, 109,   0,  27,  91, 109,   0,  27,  91,  76,
   0,   8,   0,  27,  91,  66,   0,  27,  91,  72,   0,  27,  91,  76,   0,  27,
  91,  68,   0,  27,  91,  67,   0,  27,  91,  65,   0,  13,  27,  91,  83,   0,
  27,  91,  37, 112,  49,  37, 100,  80,   0,  27,  91,  37, 112,  49,  37, 100,
  77,   0,  27,  91,  37, 112,  49,  37, 100,  66,   0,  27,  91,  37, 112,  49,
  37, 100,  64,   0,  27,  91,  37, 112,  49,  37, 100,  83,   0,  27,  91,  37,
 112,  49,  37, 100,  76,   0,  27,  91,  37, 112,  49,  37, 100,  68,   0,  27,
  91,  37, 112,  49,  37, 100,  67,   0,  27,  91,  37, 112,  49,  37, 100,  84,
   0,  27,  91,  37, 112,  49,  37, 100,  65,   0,  27,  91,  52, 105,   0,  27,
  91,  53, 105,   0,  37, 112,  49,  37,  99,  27,  91,  37, 112,  50,  37, 123,
  49, 125,  37,  45,  37, 100,  98,   0,  27,  91,  37, 105,  37, 112,  49,  37,
 100, 100,   0,  10,   0,  27,  91,  48,  59,  49,  48,  37,  63,  37, 112,  49,
  37, 116,  59,  55,  37,  59,  37,  63,  37, 112,  50,  37, 116,  59,  52,  37,
  59,  37,  63,  37, 112,  51,  37, 116,  59,  55,  37,  59,  37,  63,  37, 112,
  52,  37, 116,  59,  53,  37,  59,  37,  63,  37, 112,  54,  37, 116,  59,  49,
  37,  59,  37,  63,  37, 112,  55,  37, 116,  59,  56,  37,  59,  37,  63,  37,
 112,  57,  37, 116,  59,  49,  49,  37,  59, 109,   0,  27,  72,   0,  27,  91,
  73,   0,  43,  16,  44,  17,  45,  24,  46,  25,  48, -37,  96,   4,  97, -79,
 102,  -8, 103, -15, 104, -80, 106, -39, 107, -65, 108, -38, 109, -64, 110, -59,
 111, 126, 112, -60, 113, -60, 114, -60, 115,  95, 116, -61, 117, -76, 118, -63,
 119, -62, 120, -77, 121, -13, 122, -14, 123, -29, 124, -40, 125,-100, 126,  -2,
   0,  27,  91,  90,   0,  27,  91,  49,  75,   0,  27,  91,  37, 105,  37, 100,
  59,  37, 100,  82,   0,  27,  91,  54, 110,   0,  27,  91,  63,  37,  91,  59,
  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  93,  99,   0,  27,  91,  99,
   0,  27,  91,  51,  57,  59,  52,  57, 109,   0,  27,  91,  51,  37, 112,  49,
  37, 100, 109,   0,  27,  91,  52,  37, 112,  49,  37, 100, 109,   0,  27,  40,
  66,   0,  27,  41,  66,   0,  27,  42,  66,   0,  27,  43,  66,   0,  27,  91,
  49,  49, 109,   0,  27,  91,  49,  48, 109,   0
};

/// Load one of the built-in terminfo entries when unibilium has failed to
/// load a terminfo record from an external database, as it does on termcap-
/// -only systems.  We do not do any fancy recognition of xterm pretenders
/// here.  An external terminfo database would not do that, and we want to
/// behave as much like an external terminfo database as possible.
static unibi_term *load_builtin_terminfo(const char * term)
{
  if (TERMINAL_FAMILY(term, "xterm")) {
    return unibi_from_mem(xterm_256colour_terminfo, sizeof xterm_256colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "screen")) {
    return unibi_from_mem(screen_256colour_terminfo, sizeof screen_256colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "tmux")) {
    return unibi_from_mem(tmux_256colour_terminfo, sizeof tmux_256colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "rxvt")) {
    return unibi_from_mem(rxvt_256colour_terminfo, sizeof rxvt_256colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "putty")) {
    return unibi_from_mem(putty_256colour_terminfo, sizeof putty_256colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "linux")) {
    return unibi_from_mem(linux_16colour_terminfo, sizeof linux_16colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "interix")) {
    return unibi_from_mem(interix_8colour_terminfo, sizeof interix_8colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "iterm") || TERMINAL_FAMILY(term, "iTerm.app")) {
    return unibi_from_mem(iterm_256colour_terminfo, sizeof iterm_256colour_terminfo);
  } else if (TERMINAL_FAMILY(term, "st")) {
    return unibi_from_mem(st_256colour_terminfo, sizeof st_256colour_terminfo);
  } else {
    return unibi_from_mem(ansi_terminfo, sizeof ansi_terminfo);
  }
}

/// Several entries in terminfo are known to be deficient or outright wrong,
/// unfortunately; and several terminal emulators falsely announce incorrect
/// terminal types.  So patch the terminfo records after loading from an
/// external or a built-in database.  In an ideal world, the real terminfo data
/// would be correct and complete, and this function would be almost empty.
static void patch_terminfo_bugs(TUIData *data, const char *term,
    const char *colorterm, long vte_version, bool konsole, bool iterm_env)
{
  unibi_term *ut = data->ut;
  bool true_xterm = !!os_getenv("XTERM_VERSION");
  bool xterm = TERMINAL_FAMILY(term, "xterm");
  bool mate = colorterm && strstr(colorterm, "mate-terminal");
  bool gnome = colorterm && strstr(colorterm, "gnome-terminal");
  bool linuxvt = TERMINAL_FAMILY(term, "linux");
  bool rxvt = TERMINAL_FAMILY(term, "rxvt");
  bool teraterm = TERMINAL_FAMILY(term, "teraterm");
  bool putty = TERMINAL_FAMILY(term, "putty");
  bool screen = TERMINAL_FAMILY(term, "screen");
  bool st = TERMINAL_FAMILY(term, "st");
  bool iterm = TERMINAL_FAMILY(term, "iterm") || TERMINAL_FAMILY(term, "iTerm.app");
  bool iterm_pretending_xterm = xterm && iterm_env;

  char *fix_normal = (char *)unibi_get_str(ut, unibi_cursor_normal);
  if (fix_normal) {
    if (STARTS_WITH(fix_normal, "\x1b[?12l")) {
      // terminfo typically includes DECRST 12 as part of setting up the
      // normal cursor, which interferes with the user's control via
      // set_cursor_style.  When DECRST 12 is present, skip over it, but honor
      // the rest of the cnorm setting.
      fix_normal += sizeof "\x1b[?12l" - 1;
      unibi_set_str(ut, unibi_cursor_normal, fix_normal);
    }
    if (linuxvt
        && (strlen(fix_normal) + 1) >= (sizeof LINUXRESETC - 1)
        && !memcmp(strchr(fix_normal,0) - (sizeof LINUXRESETC - 1), LINUXRESETC, sizeof LINUXRESETC - 1)) {
      // The Linux terminfo entry similarly includes a Linux-idiosyncractic
      // cursor shape reset in cnorm, which similarly interferes with
      // set_cursor_style.
      fix_normal[strlen(fix_normal) - (sizeof LINUXRESETC - 1)] = 0;
    }
  }

  if (xterm) {
    // Termit, LXTerminal, GTKTerm2, GNOME Terminal, MATE Terminal, roxterm,
    // and EvilVTE falsely claim to be xterm and do not support important xterm
    // control sequences that we use.  In an ideal world, these would have
    // their own terminal types and terminfo entries, like PuTTY does, and not
    // claim to be xterm.  Or they would mimic xterm properly enough to be
    // treatable as xterm.
#if 0   // We don't need to identify this specifically, for now.
    bool roxterm = !!os_getenv("ROXTERM_ID");
#endif
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]0;");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x07");
    unibi_set_if_empty(ut, unibi_set_tb_margin, "\x1b[%i%p1%d;%p2%dr");
    if (true_xterm) {
      unibi_set_if_empty(ut, unibi_set_lr_margin, "\x1b[%i%p1%d;%p2%ds");
      unibi_set_if_empty(ut, unibi_set_left_margin_parm, "\x1b[%i%p1%ds");
      unibi_set_if_empty(ut, unibi_set_right_margin_parm, "\x1b[%i;%p2%ds");
    }
  } else if (rxvt) {
    unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]2");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x07");
    unibi_set_if_empty(ut, unibi_set_tb_margin, "\x1b[%i%p1%d;%p2%dr");
  } else if (screen) {
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b_");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x1b\\");
  } else if (TERMINAL_FAMILY(term, "tmux")) {
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b_");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x1b\\");
  } else if (TERMINAL_FAMILY(term, "interix")) {
    unibi_set_if_empty(ut, unibi_carriage_return, "\x0d");
  } else if (linuxvt) {
    // No deviations from the vanilla terminfo.
  } else if (putty) {
    // No deviations from the vanilla terminfo.
  } else if (iterm) {
    // No deviations from the vanilla terminfo.
  } else if (st) {
    // No deviations from the vanilla terminfo.
  }

#define XTERM_SETAF_256 \
  "\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38:5:%p1%d%;m"
#define XTERM_SETAB_256 \
  "\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48:5:%p1%d%;m"
  // "standard" means using colons like ISO 8613-6:1994/ITU T.416:1993 says.
#define XTERM_SETAF_256_NONSTANDARD \
  "\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m"
#define XTERM_SETAB_256_NONSTANDARD \
  "\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m"
#define XTERM_SETAF_16 \
  "\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e39%;m"
#define XTERM_SETAB_16 \
  "\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e39%;m"

  // Terminals where there is actually 256-colour SGR support despite what
  // the terminfo record may say.
  if (unibi_get_num(ut, unibi_max_colors) < 256) {
    // See http://fedoraproject.org/wiki/Features/256_Color_Terminals for
    // more on this.
    if (xterm && true_xterm) {
      unibi_set_num(ut, unibi_max_colors, 256);
      unibi_set_str(ut, unibi_set_a_foreground, XTERM_SETAF_256);
      unibi_set_str(ut, unibi_set_a_background, XTERM_SETAB_256);
    } else if (konsole || mate || xterm || gnome || rxvt || st
        || linuxvt  // Linux 4.8+ supports 256-colour SGR.
        || (colorterm && strstr(colorterm, "256"))
        || (term && strstr(term, "256"))
        ) {
      unibi_set_num(ut, unibi_max_colors, 256);
      unibi_set_str(ut, unibi_set_a_foreground, XTERM_SETAF_256_NONSTANDARD);
      unibi_set_str(ut, unibi_set_a_background, XTERM_SETAB_256_NONSTANDARD);
    }
  }
  // Terminals where there is actually 16-colour SGR support despite what
  // the terminfo record may say.
  if (unibi_get_num(ut, unibi_max_colors) < 16) {
    if (colorterm) {
      unibi_set_num(ut, unibi_max_colors, 16);
      unibi_set_if_empty(ut, unibi_set_a_foreground, XTERM_SETAF_16);
      unibi_set_if_empty(ut, unibi_set_a_background, XTERM_SETAB_16);
    }
  }

  // Dickey ncurses terminfo has included the Ss and Se capabilities, pioneered
  // by tmux, since 2011-07-14.  So adding them to terminal types, that do
  // actually have such control sequences but lack the correct definitions in
  // terminfo, is a fixup, not an augmentation.
  data->unibi_ext.reset_cursor_style = unibi_find_ext_str(ut, "Se");
  data->unibi_ext.set_cursor_style = unibi_find_ext_str(ut, "Ss");
  if (-1 == data->unibi_ext.set_cursor_style) {
    // The DECSCUSR sequence to change the cursor shape is widely
    // supported by several terminal types and should be in many
    // teminfo entries.  See
    // https://github.com/gnachman/iTerm2/pull/92 for more.
    // xterm even has an extended version that has a vertical bar.
    if (true_xterm    // per xterm ctlseqs doco (since version 282)
        || rxvt       // per command.C
        // per analysis of VT100Terminal.m
        || iterm || iterm_pretending_xterm
        // Allows forcing the use of DECSCUSR on linux type terminals, such as
        // console-terminal-emulator from the nosh toolset, which does indeed
        // implement the xterm extension:
        || (linuxvt && (true_xterm || (vte_version > 0) || colorterm))) {
      data->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
          "\x1b[%p1%d q");
      if (-1 == data->unibi_ext.reset_cursor_style) {
          data->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
              "");
      }
      unibi_set_ext_str(ut, (size_t)data->unibi_ext.reset_cursor_style, "\x1b[ q");
    } else if (putty   // per MinTTY 0.4.3-1 release notes from 2009
        || teraterm    // per TeraTerm "Supported Control Functions" doco
        || (vte_version >= 3900)  // VTE-based terminals since this version.
        // per tmux manual page and per
        // https://lists.gnu.org/archive/html/screen-devel/2013-03/msg00000.html
        || screen) {
      // Since we use the xterm extension, we have to map it to the unextended
      // form.
      data->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
          "\x1b[%?"
          "%p1%{4}%>" "%t%p1%{2}%-"     // a bit of a bodge for extension values
          "%e%p1"              // the conventional codes are just passed through
          "%;%d q");
      if (-1 == data->unibi_ext.reset_cursor_style) {
          data->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
              "");
      }
      unibi_set_ext_str(ut, (size_t)data->unibi_ext.reset_cursor_style, "\x1b[ q");
    } else if (linuxvt) {
      // Linux uses an idiosyncratic escape code to set the cursor shape and does
      // not support DECSCUSR.
      data->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
          "\x1b[?"
          "%?"
          // The parameter passed to Ss is the DECSCUSR parameter, so the
          // terminal capability has to translate into the Linux idiosyncratic
          // parameter.
          "%p1%{2}%<" "%t%{8}"  // blink block
          "%p1%{2}%=" "%t%{24}" // steady block
          "%p1%{3}%=" "%t%{1}"  // blink underline
          "%p1%{4}%=" "%t%{17}" // steady underline
          "%p1%{5}%=" "%t%{1}"  // blink bar
          "%p1%{6}%=" "%t%{17}" // steady bar
          "%e%{0}"              // anything else
          "%;" "%dc");
      if (-1 == data->unibi_ext.reset_cursor_style) {
          data->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
              "");
      }
      unibi_set_ext_str(ut, (size_t)data->unibi_ext.reset_cursor_style, "\x1b[?c");
    } else if (konsole) {
      // Konsole uses an idiosyncratic escape code to set the cursor shape and
      // does not support DECSCUSR.  This makes Konsole set up and apply a
      // nonce profile, which has side-effects on temporary font resizing.
      // In an ideal world, Konsole would just support DECSCUSR.
      data->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
          "\x1b]50;CursorShape=%?"
          "%p1%{3}%<" "%t%{0}"    // block
          "%e%p1%{4}%<" "%t%{2}"  // underline
          "%e%{1}"                // everything else is bar
          "%;%d;BlinkingCursorEnabled=%?"
          "%p1%{1}%<" "%t%{1}"  // Fortunately if we exclude zero as special,
          "%e%p1%{1}%&"  // in all other cases we can treat bit #0 as a flag.
          "%;%d\x07");
      if (-1 == data->unibi_ext.reset_cursor_style) {
          data->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
              "");
      }
      unibi_set_ext_str(ut, (size_t)data->unibi_ext.reset_cursor_style,
          "\x1b]50;\x07");
    }
  }
}

/// This adds stuff that is not in standard terminfo as extended unibilium
/// capabilities.
static void augment_terminfo(TUIData *data, const char *term,
    const char *colorterm, long vte_version, bool konsole, bool iterm_env)
{
  unibi_term *ut = data->ut;
  bool true_xterm = !!os_getenv("XTERM_VERSION");
  bool xterm = TERMINAL_FAMILY(term, "xterm");
  bool dtterm = TERMINAL_FAMILY(term, "dtterm");
  bool linuxvt = TERMINAL_FAMILY(term, "linux");
  bool rxvt = TERMINAL_FAMILY(term, "rxvt");
  bool teraterm = TERMINAL_FAMILY(term, "teraterm");
  bool putty = TERMINAL_FAMILY(term, "putty");
  bool screen = TERMINAL_FAMILY(term, "screen");
  bool st = TERMINAL_FAMILY(term, "st");
  bool iterm = TERMINAL_FAMILY(term, "iterm") || TERMINAL_FAMILY(term, "iTerm.app");
  bool iterm_pretending_xterm = xterm && iterm_env;
  bool tmux_wrap = screen && !!os_getenv("TMUX");
  bool truecolor = colorterm
    && (0 == strcmp(colorterm, "truecolor") || 0 == strcmp(colorterm, "24bit"));

  // Only define this capability for terminal types that we know understand it.
  if (dtterm         // originated this extension
      || xterm       // per xterm ctlseqs doco
      || konsole     // per commentary in VT102Emulation.cpp
      || teraterm    // per TeraTerm "Supported Control Functions" doco
      || rxvt) {     // per command.C
    data->unibi_ext.resize_screen = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[8;%p1%d;%p2%dt");
  }
  if (putty || xterm || rxvt) {
    data->unibi_ext.reset_scroll_region = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[r");
  }

  // Dickey ncurses terminfo does not include the setrgbf and setrgbb
  // capabilities, proposed by Rüdiger Sonderfeld on 2013-10-15.  So adding
  // them to terminal types, that do actually have such control sequences but
  // lack the correct definitions in terminfo, is an augmentation, not a
  // fixup.  See https://gist.github.com/XVilka/8346728 for more about this.
  bool has_standard_rgb = vte_version >= 3600  // per GNOME bug #685759
    || iterm || iterm_pretending_xterm  // per analysis of VT100Terminal.m
    || true_xterm;
  // "standard" means using colons like ISO 8613-6:1994/ITU T.416:1993 says.
  bool has_non_standard_rgb =
    linuxvt     // Linux 4.8+ supports true-colour SGR.
    || konsole  // per commentary in VT102Emulation.cpp
    // per http://lists.schmorp.de/pipermail/rxvt-unicode/2016q2/002261.html
    || rxvt
    || st       // per experimentation
    || truecolor;
  data->unibi_ext.set_rgb_foreground = unibi_find_ext_str(ut, "setrgbf");
  if (-1 == data->unibi_ext.set_rgb_foreground) {
    if (has_standard_rgb) {
      data->unibi_ext.set_rgb_foreground = (int)unibi_add_ext_str(ut, "setrgbf",
          "\x1b[38:2:%p1%d:%p2%d:%p3%dm");
    } else if (has_non_standard_rgb) {
      data->unibi_ext.set_rgb_foreground = (int)unibi_add_ext_str(ut, "setrgbf",
          "\x1b[38;2;%p1%d;%p2%d;%p3%dm");
    }
  }
  data->unibi_ext.set_rgb_background = unibi_find_ext_str(ut, "setrgbb");
  if (-1 == data->unibi_ext.set_rgb_background) {
    if (has_standard_rgb) {
      data->unibi_ext.set_rgb_background = (int)unibi_add_ext_str(ut, "setrgbb",
          "\x1b[48:2:%p1%d:%p2%d:%p3%dm");
    } else if (has_non_standard_rgb) {
      data->unibi_ext.set_rgb_background = (int)unibi_add_ext_str(ut, "setrgbb",
          "\x1b[48;2;%p1%d;%p2%d;%p3%dm");
    }
  }

  if (iterm || iterm_pretending_xterm) {
    // FIXME: Bypassing tmux like this affects the cursor colour globally, in
    // all panes, which is not particularly desirable.  A better approach
    // would use a tmux control sequence and an extra if(screen) test.
    data->unibi_ext.set_cursor_color = (int)unibi_add_ext_str(
        ut, NULL, TMUX_WRAP(tmux_wrap, "\033]Pl%p1%06x\033\\"));
  } else if (xterm) {
    data->unibi_ext.set_cursor_color = (int)unibi_add_ext_str(
        ut, NULL, "\033]12;#%p1%06x\007");
  }

  /// Terminals generally ignore private modes that they do not recognize,
  /// and there is no known ambiguity with these modes from terminal type to
  /// terminal type, so we can afford to just set these unconditionally.
  data->unibi_ext.enable_lr_margin = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?69h");
  data->unibi_ext.disable_lr_margin = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?69l");
  data->unibi_ext.enable_bracketed_paste = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?2004h");
  data->unibi_ext.disable_bracketed_paste = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?2004l");
  data->unibi_ext.enable_focus_reporting = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1004h");
  data->unibi_ext.disable_focus_reporting = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1004l");
  data->unibi_ext.enable_mouse = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1002h\x1b[?1006h");
  data->unibi_ext.disable_mouse = (int)unibi_add_ext_str(ut, NULL,
      "\x1b[?1002l\x1b[?1006l");
}

static void flush_buf(UI *ui, bool toggle_cursor)
{
  uv_write_t req;
  uv_buf_t buf;
  TUIData *data = ui->data;

  if (toggle_cursor && !data->busy) {
    // not busy and the cursor is invisible(see below). Append a "cursor
    // normal" command to the end of the buffer.
    data->bufsize += CNORM_COMMAND_MAX_SIZE;
    unibi_out(ui, unibi_cursor_normal);
    data->bufsize -= CNORM_COMMAND_MAX_SIZE;
  }

  buf.base = data->buf;
  buf.len = data->bufpos;
  uv_write(&req, STRUCT_CAST(uv_stream_t, &data->output_handle), &buf, 1, NULL);
  uv_run(&data->write_loop, UV_RUN_DEFAULT);
  data->bufpos = 0;

  if (toggle_cursor && !data->busy) {
    // not busy and cursor is visible(see above), append a "cursor invisible"
    // command to the beginning of the buffer for the next flush
    unibi_out(ui, unibi_cursor_invisible);
  }
}

#if TERMKEY_VERSION_MAJOR > 0 || TERMKEY_VERSION_MINOR > 18
/// Try to get "kbs" code from stty because "the terminfo kbs entry is extremely
/// unreliable." (Vim, Bash, and tmux also do this.)
///
/// @see tmux/tty-keys.c fe4e9470bb504357d073320f5d305b22663ee3fd
/// @see https://bugzilla.redhat.com/show_bug.cgi?id=142659
static const char *tui_get_stty_erase(void)
{
  static char stty_erase[2] = { 0 };
#if defined(ECHOE) && defined(ICANON) && defined(HAVE_TERMIOS_H)
  struct termios t;
  if (tcgetattr(input_global_fd(), &t) != -1) {
    stty_erase[0] = (char)t.c_cc[VERASE];
    stty_erase[1] = '\0';
    ILOG("stty/termios:erase=%s", stty_erase);
  }
#endif
  return stty_erase;
}

/// libtermkey hook to override terminfo entries.
/// @see TermInput.tk_ti_hook_fn
static const char *tui_tk_ti_getstr(const char *name, const char *value,
                                    void *data)
{
  static const char *stty_erase = NULL;
  if (stty_erase == NULL) {
    stty_erase = tui_get_stty_erase();
  }

  if (strequal(name, "key_backspace")) {
    ILOG("libtermkey:kbs=%s", value);
    if (stty_erase[0] != 0) {
      return stty_erase;
    }
  } else if (strequal(name, "key_dc")) {
    ILOG("libtermkey:kdch1=%s", value);
    // Vim: "If <BS> and <DEL> are now the same, redefine <DEL>."
    if (value != NULL && strequal(stty_erase, value)) {
      return stty_erase[0] == DEL ? CTRL_H_STR : DEL_STR;
    }
  }

  return value;
}
#endif
