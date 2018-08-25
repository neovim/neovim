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
#include "nvim/highlight.h"
#include "nvim/map.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/event/loop.h"
#include "nvim/event/signal.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/ui_bridge.h"
#include "nvim/ugrid.h"
#include "nvim/tui/input.h"
#include "nvim/tui/tui.h"
#include "nvim/tui/terminfo.h"
#include "nvim/cursor_shape.h"
#include "nvim/macros.h"

// Space reserved in two output buffers to make the cursor normal or invisible
// when flushing. No existing terminal will require 32 bytes to do that.
#define CNORM_COMMAND_MAX_SIZE 32
#define OUTBUF_SIZE 0xffff

#define TOO_MANY_EVENTS 1000000
#define STARTS_WITH(str, prefix) (strlen(str) >= (sizeof(prefix) - 1) \
    && 0 == memcmp((str), (prefix), sizeof(prefix) - 1))
#define TMUX_WRAP(is_tmux, seq) ((is_tmux) \
    ? "\x1bPtmux;\x1b" seq "\x1b\\" : seq)
#define LINUXSET0C "\x1b[?0c"
#define LINUXSET1C "\x1b[?1c"

#ifdef NVIM_UNIBI_HAS_VAR_FROM
#define UNIBI_SET_NUM_VAR(var, num) \
  do { \
    (var) = unibi_var_from_num((num)); \
  } while (0)
#else
#define UNIBI_SET_NUM_VAR(var, num) (var).i = (num);
#endif

typedef struct {
  int top, bot, left, right;
} Rect;

typedef struct {
  UIBridgeData *bridge;
  Loop *loop;
  unibi_var_t params[9];
  char buf[OUTBUF_SIZE];
  size_t bufpos;
  char norm[CNORM_COMMAND_MAX_SIZE];
  char invis[CNORM_COMMAND_MAX_SIZE];
  size_t normlen, invislen;
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
  bool did_resize;
  int row, col;
  int out_fd;
  bool scroll_region_is_full_screen;
  bool can_change_scroll_region;
  bool can_set_lr_margin;
  bool can_set_left_right_margin;
  bool immediate_wrap_after_last_column;
  bool bce;
  bool mouse_enabled;
  bool busy, is_invisible;
  bool cork, overflow;
  cursorentry_T cursor_shapes[SHAPE_IDX_COUNT];
  HlAttrs clear_attrs;
  kvec_t(HlAttrs) attrs;
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
  UI *ui = xcalloc(1, sizeof(UI));  // Freed by ui_bridge_stop().
  ui->stop = tui_stop;
  ui->grid_resize = tui_grid_resize;
  ui->grid_clear = tui_grid_clear;
  ui->grid_cursor_goto = tui_grid_cursor_goto;
  ui->mode_info_set = tui_mode_info_set;
  ui->update_menu = tui_update_menu;
  ui->busy_start = tui_busy_start;
  ui->busy_stop = tui_busy_stop;
  ui->mouse_on = tui_mouse_on;
  ui->mouse_off = tui_mouse_off;
  ui->mode_change = tui_mode_change;
  ui->grid_scroll = tui_grid_scroll;
  ui->hl_attr_define = tui_hl_attr_define;
  ui->bell = tui_bell;
  ui->visual_bell = tui_visual_bell;
  ui->default_colors_set = tui_default_colors_set;
  ui->flush = tui_flush;
  ui->suspend = tui_suspend;
  ui->set_title = tui_set_title;
  ui->set_icon = tui_set_icon;
  ui->option_set= tui_option_set;
  ui->raw_line = tui_raw_line;

  memset(ui->ui_ext, 0, sizeof(ui->ui_ext));
  ui->ui_ext[kUINewgrid] = true;

  return ui_bridge_attach(ui, tui_main, tui_scheduler);
}

static size_t unibi_pre_fmt_str(TUIData *data, unsigned int unibi_index,
                                char * buf, size_t len)
{
  const char *str = unibi_get_str(data->ut, unibi_index);
  if (!str) {
    return 0U;
  }
  return unibi_run(str, data->params, buf, len);
}

static void termname_set_event(void **argv)
{
  char *termname = argv[0];
  set_tty_option("term", termname);
  // Do not free termname, it is freed by set_tty_option.
}

static void terminfo_start(UI *ui)
{
  TUIData *data = ui->data;
  data->scroll_region_is_full_screen = true;
  data->bufpos = 0;
  data->default_attr = false;
  data->is_invisible = true;
  data->busy = false;
  data->cork = false;
  data->overflow = false;
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

  // Set up unibilium/terminfo.
  const char *term = os_getenv("TERM");
  data->ut = unibi_from_env();
  char *termname = NULL;
  if (!term || !data->ut) {
    data->ut = terminfo_from_builtin(term, &termname);
  } else {
    termname = xstrdup(term);
  }
  // Update 'term' option.
  loop_schedule_deferred(&main_loop,
                         event_create(termname_set_event, 1, termname));

  // None of the following work over SSH; see :help TERM .
  const char *colorterm = os_getenv("COLORTERM");
  const char *termprg = os_getenv("TERM_PROGRAM");
  const char *vte_version_env = os_getenv("VTE_VERSION");
  long vte_version = vte_version_env ? strtol(vte_version_env, NULL, 10) : 0;
  bool iterm_env = termprg && strstr(termprg, "iTerm.app");
  bool konsole = terminfo_is_term_family(term, "konsole")
    || os_getenv("KONSOLE_PROFILE_NAME")
    || os_getenv("KONSOLE_DBUS_SESSION");

  patch_terminfo_bugs(data, term, colorterm, vte_version, konsole, iterm_env);
  augment_terminfo(data, term, colorterm, vte_version, konsole, iterm_env);
  data->can_change_scroll_region =
    !!unibi_get_str(data->ut, unibi_change_scroll_region);
  data->can_set_lr_margin =
    !!unibi_get_str(data->ut, unibi_set_lr_margin);
  data->can_set_left_right_margin =
    !!unibi_get_str(data->ut, unibi_set_left_margin_parm)
    && !!unibi_get_str(data->ut, unibi_set_right_margin_parm);
  data->immediate_wrap_after_last_column =
    terminfo_is_term_family(term, "cygwin")
    || terminfo_is_term_family(term, "interix");
  data->bce = unibi_get_bool(data->ut, unibi_back_color_erase);
  data->normlen = unibi_pre_fmt_str(data, unibi_cursor_normal,
                                    data->norm, sizeof data->norm);
  data->invislen = unibi_pre_fmt_str(data, unibi_cursor_invisible,
                                     data->invis, sizeof data->invis);
  // Set 't_Co' from the result of unibilium & fix_terminfo.
  t_colors = unibi_get_num(data->ut, unibi_max_colors);
  // Enter alternate screen and clear
  // NOTE: Do this *before* changing terminal settings. #6433
  unibi_out(ui, unibi_enter_ca_mode);
  unibi_out(ui, unibi_keypad_xmit);
  unibi_out(ui, unibi_clear_screen);
  // Enable bracketed paste
  unibi_out_ext(ui, data->unibi_ext.enable_bracketed_paste);

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
  unibi_out(ui, unibi_keypad_local);
  unibi_out(ui, unibi_exit_ca_mode);
  // Disable bracketed paste
  unibi_out_ext(ui, data->unibi_ext.disable_bracketed_paste);
  // Disable focus reporting
  unibi_out_ext(ui, data->unibi_ext.disable_focus_reporting);
  flush_buf(ui);
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
  data->print_attrs = HLATTRS_INVALID;
  ugrid_init(&data->grid);
  terminfo_start(ui);
  update_size(ui);
  signal_watcher_start(&data->winch_handle, sigwinch_cb, SIGWINCH);
  term_input_start(&data->input);
}

static void tui_terminal_after_startup(UI *ui)
  FUNC_ATTR_NONNULL_ALL
{
  TUIData *data = ui->data;

  // Emit this after Nvim startup, not during.  This works around a tmux
  // 2.3 bug(?) which caused slow drawing during startup.  #7649
  unibi_out_ext(ui, data->unibi_ext.enable_focus_reporting);
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
  // Flag UI as "stopped".
  ui->data = NULL;
}

/// Returns true if UI `ui` is stopped.
static bool tui_is_stopped(UI *ui)
{
  return ui->data == NULL;
}

/// Main function of the TUI thread.
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

  // TODO(bfredl): zero hl is empty, send this explicitly?
  kv_push(data->attrs, HLATTRS_INIT);

#if TERMKEY_VERSION_MAJOR > 0 || TERMKEY_VERSION_MINOR > 18
  data->input.tk_ti_hook_fn = tui_tk_ti_getstr;
#endif
  term_input_init(&data->input, &tui_loop);
  tui_terminal_start(ui);

  // Allow main thread to continue, we are ready to handle UI callbacks.
  CONTINUE(bridge);

  loop_schedule_deferred(&main_loop,
                         event_create(show_termcap_event, 1, data->ut));

  // "Active" loop: first ~100 ms of startup.
  for (size_t ms = 0; ms < 100 && !tui_is_stopped(ui);) {
    ms += (loop_poll_events(&tui_loop, 20) ? 20 : 1);
  }
  if (!tui_is_stopped(ui)) {
    tui_terminal_after_startup(ui);
    // Tickle `main_loop` with a dummy event, else the initial "focus-gained"
    // terminal response may not get processed until user hits a key.
    loop_schedule_deferred(&main_loop, event_create(tui_dummy_event, 0));
  }
  // "Passive" (I/O-driven) loop: TUI thread "main loop".
  while (!tui_is_stopped(ui)) {
    loop_poll_events(&tui_loop, -1);  // tui_loop.events is never processed
  }

  ui_bridge_stopped(bridge);
  term_input_destroy(&data->input);
  signal_watcher_stop(&data->cont_handle);
  signal_watcher_close(&data->cont_handle, NULL);
  signal_watcher_close(&data->winch_handle, NULL);
  loop_close(&tui_loop, false);
  kv_destroy(data->invalid_regions);
  kv_destroy(data->attrs);
  xfree(data);
}

static void tui_dummy_event(void **argv)
{
}

/// Handoff point between the main (ui_bridge) thread and the TUI thread.
static void tui_scheduler(Event event, void *d)
{
  UI *ui = d;
  TUIData *data = ui->data;
  loop_schedule(data->loop, event);  // `tui_loop` local to tui_main().
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
  if (tui_is_stopped(ui)) {
    return;
  }

  update_size(ui);
  ui_schedule_refresh();
}

static bool attrs_differ(HlAttrs a1, HlAttrs a2, bool rgb)
{
  if (rgb) {
    // TODO(bfredl): when we start to support special color,
    // rgb_sp_color must be added here
    return a1.rgb_fg_color != a2.rgb_fg_color
      || a1.rgb_bg_color != a2.rgb_bg_color
      || a1.rgb_ae_attr != a2.rgb_ae_attr;
  } else {
    return a1.cterm_fg_color != a2.cterm_fg_color
      || a1.cterm_bg_color != a2.cterm_bg_color
      || a1.cterm_ae_attr != a2.cterm_ae_attr;
  }
}

static bool no_bg(UI *ui, HlAttrs attrs)
{
  return  ui->rgb ? attrs.rgb_bg_color == -1
                  : attrs.cterm_bg_color == 0;
}

static void update_attrs(UI *ui, HlAttrs attrs)
{
  TUIData *data = ui->data;

  if (!attrs_differ(attrs, data->print_attrs, ui->rgb)) {
    return;
  }

  data->print_attrs = attrs;

  int fg = ui->rgb ? attrs.rgb_fg_color : (attrs.cterm_fg_color - 1);
  if (fg == -1) {
    fg = ui->rgb ? data->clear_attrs.rgb_fg_color
                 : (data->clear_attrs.cterm_fg_color - 1);
  }

  int bg = ui->rgb ? attrs.rgb_bg_color : (attrs.cterm_bg_color - 1);
  if (bg == -1) {
    bg = ui->rgb ? data->clear_attrs.rgb_bg_color
                 : (data->clear_attrs.cterm_bg_color - 1);
  }

  int attr = ui->rgb ? attrs.rgb_ae_attr : attrs.cterm_ae_attr;
  bool bold = attr & HL_BOLD;
  bool italic = attr & HL_ITALIC;
  bool reverse = attr & HL_INVERSE;
  bool standout = attr & HL_STANDOUT;
  bool underline = attr & (HL_UNDERLINE), undercurl = attr & (HL_UNDERCURL);

  if (unibi_get_str(data->ut, unibi_set_attributes)) {
    if (bold || reverse || underline || undercurl || standout) {
      UNIBI_SET_NUM_VAR(data->params[0], standout);
      UNIBI_SET_NUM_VAR(data->params[1], underline || undercurl);
      UNIBI_SET_NUM_VAR(data->params[2], reverse);
      UNIBI_SET_NUM_VAR(data->params[3], 0);   // blink
      UNIBI_SET_NUM_VAR(data->params[4], 0);   // dim
      UNIBI_SET_NUM_VAR(data->params[5], bold);
      UNIBI_SET_NUM_VAR(data->params[6], 0);   // blank
      UNIBI_SET_NUM_VAR(data->params[7], 0);   // protect
      UNIBI_SET_NUM_VAR(data->params[8], 0);   // alternate character set
      unibi_out(ui, unibi_set_attributes);
    } else if (!data->default_attr) {
      unibi_out(ui, unibi_exit_attribute_mode);
    }
  } else {
    if (!data->default_attr) {
      unibi_out(ui, unibi_exit_attribute_mode);
    }
    if (bold) {
      unibi_out(ui, unibi_enter_bold_mode);
    }
    if (underline || undercurl) {
      unibi_out(ui, unibi_enter_underline_mode);
    }
    if (standout) {
      unibi_out(ui, unibi_enter_standout_mode);
    }
    if (reverse) {
      unibi_out(ui, unibi_enter_reverse_mode);
    }
  }
  if (italic) {
    unibi_out(ui, unibi_enter_italics_mode);
  }
  if (ui->rgb) {
    if (fg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], (fg >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(data->params[1], (fg >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(data->params[2], fg & 0xff);          // blue
      unibi_out_ext(ui, data->unibi_ext.set_rgb_foreground);
    }

    if (bg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], (bg >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(data->params[1], (bg >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(data->params[2], bg & 0xff);          // blue
      unibi_out_ext(ui, data->unibi_ext.set_rgb_background);
    }
  } else {
    if (fg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], fg);
      unibi_out(ui, unibi_set_a_foreground);
    }

    if (bg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], bg);
      unibi_out(ui, unibi_set_a_background);
    }
  }

  data->default_attr = fg == -1 && bg == -1
    && !bold && !italic && !underline && !undercurl && !reverse && !standout;
}

static void final_column_wrap(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  if (grid->col == ui->width) {
    grid->col = 0;
    if (grid->row < MIN(ui->height, grid->height - 1)) {
      grid->row++;
    }
  }
}

/// It is undocumented, but in the majority of terminals and terminal emulators
/// printing at the right margin does not cause an automatic wrap until the
/// next character is printed, holding the cursor in place until then.
static void print_cell(UI *ui, UCell *ptr)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  if (!data->immediate_wrap_after_last_column) {
    // Printing the next character finally advances the cursor.
    final_column_wrap(ui);
  }
  update_attrs(ui, ptr->attrs);
  out(ui, ptr->data, strlen(ptr->data));
  grid->col++;
  if (data->immediate_wrap_after_last_column) {
    // Printing at the right margin immediately advances the cursor.
    final_column_wrap(ui);
  }
}

static bool cheap_to_print(UI *ui, int row, int col, int next)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  UCell *cell = grid->cells[row] + col;
  while (next) {
    next--;
    if (attrs_differ(cell->attrs, data->print_attrs, ui->rgb)) {
      if (data->default_attr) {
        return false;
      }
    }
    if (strlen(cell->data) > 1) {
      return false;
    }
    cell++;
  }
  return true;
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
    ugrid_goto(grid, row, col);
    return;
  }
  if (0 == col ? col != grid->col :
      row != grid->row ? false :
      1 == col ? 2 < grid->col && cheap_to_print(ui, grid->row, 0, col) :
      2 == col ? 5 < grid->col && cheap_to_print(ui, grid->row, 0, col) :
      false) {
    // Motion to left margin from anywhere else, or CR + printing chars is
    // even less expensive than using BSes or CUB.
    unibi_out(ui, unibi_carriage_return);
    ugrid_goto(grid, grid->row, 0);
  } else if (col > grid->col) {
      int n = col - grid->col;
      if (n <= (row == grid->row ? 4 : 2)
          && cheap_to_print(ui, grid->row, grid->col, n)) {
        UGRID_FOREACH_CELL(grid, grid->row, grid->row, grid->col, col - 1, {
          print_cell(ui, cell);
        });
      }
  }
  if (row == grid->row) {
    if (col < grid->col
        // Deferred right margin wrap terminals have inconsistent ideas about
        // where the cursor actually is during a deferred wrap.  Relative
        // motion calculations have OBOEs that cannot be compensated for,
        // because two terminals that claim to be the same will implement
        // different cursor positioning rules.
        && (data->immediate_wrap_after_last_column || grid->col < ui->width)) {
      int n = grid->col - col;
      if (n <= 4) {  // This might be just BS, so it is considered really cheap.
        while (n--) {
          unibi_out(ui, unibi_cursor_left);
        }
      } else {
        UNIBI_SET_NUM_VAR(data->params[0], n);
        unibi_out(ui, unibi_parm_left_cursor);
      }
      ugrid_goto(grid, row, col);
      return;
    } else if (col > grid->col) {
      int n = col - grid->col;
      if (n <= 2) {
        while (n--) {
          unibi_out(ui, unibi_cursor_right);
        }
      } else {
        UNIBI_SET_NUM_VAR(data->params[0], n);
        unibi_out(ui, unibi_parm_right_cursor);
      }
      ugrid_goto(grid, row, col);
      return;
    }
  }
  if (col == grid->col) {
    if (row > grid->row) {
      int n = row - grid->row;
      if (n <= 4) {  // This might be just LF, so it is considered really cheap.
        while (n--) {
          unibi_out(ui, unibi_cursor_down);
        }
      } else {
        UNIBI_SET_NUM_VAR(data->params[0], n);
        unibi_out(ui, unibi_parm_down_cursor);
      }
      ugrid_goto(grid, row, col);
      return;
    } else if (row < grid->row) {
      int n = grid->row - row;
      if (n <= 2) {
        while (n--) {
          unibi_out(ui, unibi_cursor_up);
        }
      } else {
        UNIBI_SET_NUM_VAR(data->params[0], n);
        unibi_out(ui, unibi_parm_up_cursor);
      }
      ugrid_goto(grid, row, col);
      return;
    }
  }
  unibi_goto(ui, row, col);
  ugrid_goto(grid, row, col);
}

static void clear_region(UI *ui, int top, int bot, int left, int right,
                         HlAttrs attrs)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  bool cleared = false;

  // non-BCE terminals can't clear with non-default background color
  bool can_clear = data->bce || no_bg(ui, attrs);

  if (can_clear && right == ui->width -1) {
    // Background is set to the default color and the right edge matches the
    // screen end, try to use terminal codes for clearing the requested area.
    update_attrs(ui, attrs);
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
      for (int row = top; row <= bot; row++) {
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
    });

    if (data->did_resize && top == 0) {
      // TODO(bfredl): the first line of the screen doesn't gets properly
      // cleared after resize by the loop above, so redraw the final state
      // after the next flush.
      invalidate(ui, 0, bot, left, right);
      data->did_resize = false;
    }
  }

  // restore cursor
  cursor_goto(ui, data->row, data->col);
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

  UNIBI_SET_NUM_VAR(data->params[0], grid->top);
  UNIBI_SET_NUM_VAR(data->params[1], grid->bot);
  unibi_out(ui, unibi_change_scroll_region);
  if (grid->left != 0 || grid->right != ui->width - 1) {
    unibi_out_ext(ui, data->unibi_ext.enable_lr_margin);
    if (data->can_set_lr_margin) {
      UNIBI_SET_NUM_VAR(data->params[0], grid->left);
      UNIBI_SET_NUM_VAR(data->params[1], grid->right);
      unibi_out(ui, unibi_set_lr_margin);
    } else {
      UNIBI_SET_NUM_VAR(data->params[0], grid->left);
      unibi_out(ui, unibi_set_left_margin_parm);
      UNIBI_SET_NUM_VAR(data->params[0], grid->right);
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
    unibi_out_ext(ui, data->unibi_ext.reset_scroll_region);
  } else {
    UNIBI_SET_NUM_VAR(data->params[0], 0);
    UNIBI_SET_NUM_VAR(data->params[1], ui->height - 1);
    unibi_out(ui, unibi_change_scroll_region);
  }
  if (grid->left != 0 || grid->right != ui->width - 1) {
    if (data->can_set_lr_margin) {
      UNIBI_SET_NUM_VAR(data->params[0], 0);
      UNIBI_SET_NUM_VAR(data->params[1], ui->width - 1);
      unibi_out(ui, unibi_set_lr_margin);
    } else {
      UNIBI_SET_NUM_VAR(data->params[0], 0);
      unibi_out(ui, unibi_set_left_margin_parm);
      UNIBI_SET_NUM_VAR(data->params[0], ui->width - 1);
      unibi_out(ui, unibi_set_right_margin_parm);
    }
    unibi_out_ext(ui, data->unibi_ext.disable_lr_margin);
  }
  unibi_goto(ui, grid->row, grid->col);
}

static void tui_grid_resize(UI *ui, Integer g, Integer width, Integer height)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_resize(grid, (int)width, (int)height);
  data->did_resize = true;

  // resize might not always be followed by a clear before flush
  // so clip the invalid region
  for (size_t i = 0; i < kv_size(data->invalid_regions); i++) {
    Rect *r = &kv_A(data->invalid_regions, i);
    r->bot = MIN(r->bot, grid->height-1);
    r->right = MIN(r->right, grid->width-1);
  }

  if (!got_winch) {  // Try to resize the terminal window.
    UNIBI_SET_NUM_VAR(data->params[0], (int)height);
    UNIBI_SET_NUM_VAR(data->params[1], (int)width);
    unibi_out_ext(ui, data->unibi_ext.resize_screen);
    // DECSLPP does not reset the scroll region.
    if (data->scroll_region_is_full_screen) {
      reset_scroll_region(ui);
    }
  } else {  // Already handled the SIGWINCH signal; avoid double-resize.
    got_winch = false;
  }
}

static void tui_grid_clear(UI *ui, Integer g)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_clear(grid);
  kv_size(data->invalid_regions) = 0;
  clear_region(ui, 0, grid->height-1, 0, grid->width-1,
               data->clear_attrs);
}

static void tui_grid_cursor_goto(UI *ui, Integer grid, Integer row, Integer col)
{
  TUIData *data = ui->data;
  data->row = (int)row;
  data->col = (int)col;
  cursor_goto(ui, (int)row, (int)col);
}

CursorShape tui_cursor_decode_shape(const char *shape_str)
{
  CursorShape shape;
  if (strequal(shape_str, "block")) {
    shape = SHAPE_BLOCK;
  } else if (strequal(shape_str, "vertical")) {
    shape = SHAPE_VER;
  } else if (strequal(shape_str, "horizontal")) {
    shape = SHAPE_HOR;
  } else {
    WLOG("Unknown shape value '%s'", shape_str);
    shape = SHAPE_BLOCK;
  }
  return shape;
}

static cursorentry_T decode_cursor_entry(Dictionary args)
{
  cursorentry_T r = shape_table[0];

  for (size_t i = 0; i < args.size; i++) {
    char *key = args.items[i].key.data;
    Object value = args.items[i].value;

    if (strequal(key, "cursor_shape")) {
      r.shape = tui_cursor_decode_shape(args.items[i].value.data.string.data);
    } else if (strequal(key, "blinkon")) {
      r.blinkon = (int)value.data.integer;
    } else if (strequal(key, "blinkoff")) {
      r.blinkoff = (int)value.data.integer;
    } else if (strequal(key, "attr_id")) {
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
    unibi_out_ext(ui, data->unibi_ext.enable_mouse);
    data->mouse_enabled = true;
  }
}

static void tui_mouse_off(UI *ui)
{
  TUIData *data = ui->data;
  if (data->mouse_enabled) {
    unibi_out_ext(ui, data->unibi_ext.disable_mouse);
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

  if (c.id != 0 && c.id < (int)kv_size(data->attrs) && ui->rgb) {
    int color = kv_A(data->attrs, c.id).rgb_bg_color;
    UNIBI_SET_NUM_VAR(data->params[0], color);
    unibi_out_ext(ui, data->unibi_ext.set_cursor_color);
  }

  int shape;
  switch (c.shape) {
    default:          abort(); break;
    case SHAPE_BLOCK: shape = 1; break;
    case SHAPE_HOR:   shape = 3; break;
    case SHAPE_VER:   shape = 5; break;
  }
  UNIBI_SET_NUM_VAR(data->params[0], shape + (int)(c.blinkon == 0));
  unibi_out_ext(ui, data->unibi_ext.set_cursor_style);
}

/// @param mode editor mode
static void tui_mode_change(UI *ui, String mode, Integer mode_idx)
{
  TUIData *data = ui->data;
  tui_set_mode(ui, (ModeShape)mode_idx);
  data->showing_mode = (ModeShape)mode_idx;
}

static void tui_grid_scroll(UI *ui, Integer g, Integer top, Integer bot,
                            Integer left, Integer right,
                            Integer rows, Integer cols)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_set_scroll_region(&data->grid, (int)top, (int)bot-1,
                          (int)left, (int)right-1);

  data->scroll_region_is_full_screen =
    left == 0 && right == ui->width
    && top == 0 && bot == ui->height;

  int clear_top, clear_bot;
  ugrid_scroll(grid, (int)rows, &clear_top, &clear_bot);

  if (can_use_scroll(ui)) {
    // Change terminal scroll region and move cursor to the top
    if (!data->scroll_region_is_full_screen) {
      set_scroll_region(ui);
    }
    cursor_goto(ui, grid->top, grid->left);
    // also set default color attributes or some terminals can become funny
    update_attrs(ui, data->clear_attrs);

    if (rows > 0) {
      if (rows == 1) {
        unibi_out(ui, unibi_delete_line);
      } else {
        UNIBI_SET_NUM_VAR(data->params[0], (int)rows);
        unibi_out(ui, unibi_parm_delete_line);
      }
    } else {
      if (rows == -1) {
        unibi_out(ui, unibi_insert_line);
      } else {
        UNIBI_SET_NUM_VAR(data->params[0], -(int)rows);
        unibi_out(ui, unibi_parm_insert_line);
      }
    }

    // Restore terminal scroll region and cursor
    if (!data->scroll_region_is_full_screen) {
      reset_scroll_region(ui);
    }
    cursor_goto(ui, data->row, data->col);

    if (!(data->bce || no_bg(ui, data->clear_attrs))) {
      // Scrolling will leave wrong background in the cleared area on non-BCE
      // terminals. Update the cleared area.
      clear_region(ui, clear_top, clear_bot, grid->left, grid->right,
                   data->clear_attrs);
    }
  } else {
    // Mark the entire scroll region as invalid for redrawing later
    invalidate(ui, grid->top, grid->bot, grid->left, grid->right);
  }
}

static void tui_hl_attr_define(UI *ui, Integer id, HlAttrs attrs,
                               HlAttrs cterm_attrs, Array info)
{
  TUIData *data = ui->data;
  kv_a(data->attrs, (size_t)id) = attrs;
}

static void tui_bell(UI *ui)
{
  unibi_out(ui, unibi_bell);
}

static void tui_visual_bell(UI *ui)
{
  unibi_out(ui, unibi_flash_screen);
}

static void tui_default_colors_set(UI *ui, Integer rgb_fg, Integer rgb_bg,
                                   Integer rgb_sp,
                                   Integer cterm_fg, Integer cterm_bg)
{
  TUIData *data = ui->data;

  data->clear_attrs.rgb_fg_color = (int)rgb_fg;
  data->clear_attrs.rgb_bg_color = (int)rgb_bg;
  data->clear_attrs.rgb_sp_color = (int)rgb_sp;
  data->clear_attrs.cterm_fg_color = (int)cterm_fg;
  data->clear_attrs.cterm_bg_color = (int)cterm_bg;

  data->print_attrs = HLATTRS_INVALID;
  invalidate(ui, 0, data->grid.height-1, 0, data->grid.width-1);
}

static void tui_flush(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  size_t nrevents = loop_size(data->loop);
  if (nrevents > TOO_MANY_EVENTS) {
    WLOG("TUI event-queue flooded (thread_events=%zu); purging", nrevents);
    // Back-pressure: UI events may accumulate much faster than the terminal
    // device can serve them. Even if SIGINT/CTRL-C is received, user must still
    // wait for the TUI event-queue to drain, and if there are ~millions of
    // events in the queue, it could take hours. Clearing the queue allows the
    // UI to recover. #1234 #5396
    loop_purge(data->loop);
    tui_busy_stop(ui);  // avoid hidden cursor
  }

  while (kv_size(data->invalid_regions)) {
    Rect r = kv_pop(data->invalid_regions);
    assert(r.bot < grid->height && r.right < grid->width);
    UGRID_FOREACH_CELL(grid, r.top, r.bot, r.left, r.right, {
      cursor_goto(ui, row, col);
      print_cell(ui, cell);
    });
  }

  cursor_goto(ui, data->row, data->col);

  flush_buf(ui);
}

/// Dumps termcap info to the messages area, if 'verbose' >= 3.
static void show_termcap_event(void **argv)
{
  if (p_verbose < 3) {
    return;
  }
  const unibi_term *const ut = argv[0];
  if (!ut) {
    abort();
  }
  verbose_enter();
  // XXX: (future) if unibi_term is modified (e.g. after a terminal
  // query-response) this is a race condition.
  terminfo_info_msg(ut);
  verbose_leave();
  verbose_stop();  // flush now
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
  tui_terminal_after_startup(ui);
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

static void tui_option_set(UI *ui, String name, Object value)
{
  TUIData *data = ui->data;
  if (strequal(name.data, "termguicolors")) {
    ui->rgb = value.data.boolean;

    data->print_attrs = HLATTRS_INVALID;
    invalidate(ui, 0, data->grid.height-1, 0, data->grid.width-1);
  }
}

static void tui_raw_line(UI *ui, Integer g, Integer linerow, Integer startcol,
                         Integer endcol, Integer clearcol, Integer clearattr,
                         Boolean wrap, const schar_T *chunk,
                         const sattr_T *attrs)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  for (Integer c = startcol; c < endcol; c++) {
    memcpy(grid->cells[linerow][c].data, chunk[c-startcol], sizeof(schar_T));
    grid->cells[linerow][c].attrs = kv_A(data->attrs, attrs[c-startcol]);
  }
  UGRID_FOREACH_CELL(grid, (int)linerow, (int)linerow, (int)startcol,
                     (int)endcol-1, {
    cursor_goto(ui, row, col);
    print_cell(ui, cell);
  });

  if (clearcol > endcol) {
    HlAttrs cl_attrs = kv_A(data->attrs, (size_t)clearattr);
    ugrid_clear_chunk(grid, (int)linerow, (int)endcol, (int)clearcol,
                      cl_attrs);
    clear_region(ui, (int)linerow, (int)linerow, (int)endcol, (int)clearcol-1,
                 cl_attrs);
  }

  if (wrap && ui->width == grid->width && linerow + 1 < grid->height) {
    // Only do line wrapping if the grid width is equal to the terminal
    // width and the line continuation is within the grid.

    if (endcol != grid->width) {
      // Print the last cell of the row, if we haven't already done so.
      cursor_goto(ui, (int)linerow, grid->width - 1);
      print_cell(ui, &grid->cells[linerow][grid->width - 1]);
    }

    // Wrap the cursor over to the next line. The next line will be
    // printed immediately without an intervening newline.
    final_column_wrap(ui);
  }
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
  UNIBI_SET_NUM_VAR(data->params[0], row);
  UNIBI_SET_NUM_VAR(data->params[1], col);
  unibi_out(ui, unibi_cursor_address);
}

#define UNIBI_OUT(fn) \
  do { \
    TUIData *data = ui->data; \
    const char *str = NULL; \
    if (unibi_index >= 0) { \
      str = fn(data->ut, (unsigned)unibi_index); \
    } \
    if (str) { \
      unibi_var_t vars[26 + 26]; \
      size_t orig_pos = data->bufpos; \
      \
      memset(&vars, 0, sizeof(vars)); \
      data->cork = true; \
retry: \
      unibi_format(vars, vars + 26, str, data->params, out, ui, NULL, NULL); \
      if (data->overflow) { \
        data->bufpos = orig_pos; \
        flush_buf(ui); \
        goto retry; \
      } \
      data->cork = false; \
    } \
  } while (0)
static void unibi_out(UI *ui, int unibi_index)
{
  UNIBI_OUT(unibi_get_str);
}
static void unibi_out_ext(UI *ui, int unibi_index)
{
  UNIBI_OUT(unibi_get_ext_str);
}
#undef UNIBI_OUT

static void out(void *ctx, const char *str, size_t len)
{
  UI *ui = ctx;
  TUIData *data = ui->data;
  size_t available = sizeof(data->buf) - data->bufpos;

  if (data->cork && data->overflow) {
    return;
  }

  if (len > available) {
    if (data->cork) {
      data->overflow = true;
      return;
    } else {
      flush_buf(ui);
    }
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
  for (size_t i = 0; i < max; i++) {
    const char * n = unibi_get_ext_str_name(ut, i);
    if (n && 0 == strcmp(n, name)) {
      return (int)i;
    }
  }
  return -1;
}

/// Patches the terminfo records after loading from system or built-in db.
/// Several entries in terminfo are known to be deficient or outright wrong;
/// and several terminal emulators falsely announce incorrect terminal types.
static void patch_terminfo_bugs(TUIData *data, const char *term,
                                const char *colorterm, long vte_version,
                                bool konsole, bool iterm_env)
{
  unibi_term *ut = data->ut;
  const char * xterm_version = os_getenv("XTERM_VERSION");
#if 0   // We don't need to identify this specifically, for now.
  bool roxterm = !!os_getenv("ROXTERM_ID");
#endif
  bool xterm = terminfo_is_term_family(term, "xterm");
  bool kitty = terminfo_is_term_family(term, "xterm-kitty");
  bool linuxvt = terminfo_is_term_family(term, "linux");
  bool rxvt = terminfo_is_term_family(term, "rxvt");
  bool teraterm = terminfo_is_term_family(term, "teraterm");
  bool putty = terminfo_is_term_family(term, "putty");
  bool screen = terminfo_is_term_family(term, "screen");
  bool tmux = terminfo_is_term_family(term, "tmux") || !!os_getenv("TMUX");
  bool st = terminfo_is_term_family(term, "st");
  bool gnome = terminfo_is_term_family(term, "gnome")
    || terminfo_is_term_family(term, "vte");
  bool iterm = terminfo_is_term_family(term, "iterm")
    || terminfo_is_term_family(term, "iterm2")
    || terminfo_is_term_family(term, "iTerm.app")
    || terminfo_is_term_family(term, "iTerm2.app");
  // None of the following work over SSH; see :help TERM .
  bool iterm_pretending_xterm = xterm && iterm_env;
  bool konsole_pretending_xterm = xterm && konsole;
  bool gnome_pretending_xterm = xterm && colorterm
    && strstr(colorterm, "gnome-terminal");
  bool mate_pretending_xterm = xterm && colorterm
    && strstr(colorterm, "mate-terminal");
  bool true_xterm = xterm && !!xterm_version;

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
        && strlen(fix_normal) >= (sizeof LINUXSET0C - 1)
        && !memcmp(strchr(fix_normal, 0) - (sizeof LINUXSET0C - 1),
                   LINUXSET0C, sizeof LINUXSET0C - 1)) {
      // The Linux terminfo entry similarly includes a Linux-idiosyncractic
      // cursor shape reset in cnorm, which similarly interferes with
      // set_cursor_style.
      fix_normal[strlen(fix_normal) - (sizeof LINUXSET0C - 1)] = 0;
    }
  }
  char *fix_invisible = (char *)unibi_get_str(ut, unibi_cursor_invisible);
  if (fix_invisible) {
    if (linuxvt
        && strlen(fix_invisible) >= (sizeof LINUXSET1C - 1)
        && !memcmp(strchr(fix_invisible, 0) - (sizeof LINUXSET1C - 1),
                   LINUXSET1C, sizeof LINUXSET1C - 1)) {
      // The Linux terminfo entry similarly includes a Linux-idiosyncractic
      // cursor shape reset in cinvis, which similarly interferes with
      // set_cursor_style.
      fix_invisible[strlen(fix_invisible) - (sizeof LINUXSET1C - 1)] = 0;
    }
  }

  if (tmux || screen || kitty) {
    // Disable BCE in some cases we know it is not working. #8806
    unibi_set_bool(ut, unibi_back_color_erase, false);
  }

  if (xterm) {
    // Termit, LXTerminal, GTKTerm2, GNOME Terminal, MATE Terminal, roxterm,
    // and EvilVTE falsely claim to be xterm and do not support important xterm
    // control sequences that we use.  In an ideal world, these would have
    // their own terminal types and terminfo entries, like PuTTY does, and not
    // claim to be xterm.  Or they would mimic xterm properly enough to be
    // treatable as xterm.

    // 2017-04 terminfo.src lacks these.  genuine Xterm has them, as have
    // the false claimants.
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]0;");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x07");
    unibi_set_if_empty(ut, unibi_set_tb_margin, "\x1b[%i%p1%d;%p2%dr");

    if (true_xterm) {
      // 2017-04 terminfo.src lacks these.  genuine Xterm has them.
      unibi_set_if_empty(ut, unibi_set_lr_margin, "\x1b[%i%p1%d;%p2%ds");
      unibi_set_if_empty(ut, unibi_set_left_margin_parm, "\x1b[%i%p1%ds");
      unibi_set_if_empty(ut, unibi_set_right_margin_parm, "\x1b[%i;%p2%ds");
    }
    if (true_xterm
        || iterm_pretending_xterm
        || gnome_pretending_xterm
        || konsole_pretending_xterm) {
      // Apple's outdated copy of terminfo.src for MacOS lacks these.
      // genuine Xterm and three false claimants have them.
      unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
      unibi_set_if_empty(ut, unibi_exit_italics_mode, "\x1b[23m");
    }
  } else if (rxvt) {
    // 2017-04 terminfo.src lacks these.  Unicode rxvt has them.
    unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
    unibi_set_if_empty(ut, unibi_exit_italics_mode, "\x1b[23m");
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]2");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x07");
    // 2017-04 terminfo.src has older control sequences.
    unibi_set_str(ut, unibi_enter_ca_mode, "\x1b[?1049h");
    unibi_set_str(ut, unibi_exit_ca_mode, "\x1b[?1049l");
  } else if (screen) {
    // per the screen manual; 2017-04 terminfo.src lacks these.
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b_");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x1b\\");
  } else if (tmux) {
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b_");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x1b\\");
  } else if (terminfo_is_term_family(term, "interix")) {
    // 2017-04 terminfo.src lacks this.
    unibi_set_if_empty(ut, unibi_carriage_return, "\x0d");
  } else if (linuxvt) {
    // Apple's outdated copy of terminfo.src for MacOS lacks these.
    unibi_set_if_empty(ut, unibi_parm_up_cursor, "\x1b[%p1%dA");
    unibi_set_if_empty(ut, unibi_parm_down_cursor, "\x1b[%p1%dB");
    unibi_set_if_empty(ut, unibi_parm_right_cursor, "\x1b[%p1%dC");
    unibi_set_if_empty(ut, unibi_parm_left_cursor, "\x1b[%p1%dD");
  } else if (putty) {
    // No bugs in the vanilla terminfo for our purposes.
  } else if (iterm) {
    // 2017-04 terminfo.src has older control sequences.
    unibi_set_str(ut, unibi_enter_ca_mode, "\x1b[?1049h");
    unibi_set_str(ut, unibi_exit_ca_mode, "\x1b[?1049l");
    // 2017-04 terminfo.src lacks these.
    unibi_set_if_empty(ut, unibi_set_tb_margin, "\x1b[%i%p1%d;%p2%dr");
    unibi_set_if_empty(ut, unibi_orig_pair, "\x1b[39;49m");
    unibi_set_if_empty(ut, unibi_enter_dim_mode, "\x1b[2m");
    unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
    unibi_set_if_empty(ut, unibi_exit_italics_mode, "\x1b[23m");
    unibi_set_if_empty(ut, unibi_exit_underline_mode, "\x1b[24m");
    unibi_set_if_empty(ut, unibi_exit_standout_mode, "\x1b[27m");
  } else if (st) {
    // No bugs in the vanilla terminfo for our purposes.
  }

// At this time (2017-07-12) it seems like all terminals that support 256
// color codes can use semicolons in the terminal code and be fine.
// However, this is not correct according to the spec. So to reward those
// terminals that also support colons, we output the code that way on these
// specific ones.

// using colons like ISO 8613-6:1994/ITU T.416:1993 says.
#define XTERM_SETAF_256_COLON \
  "\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38:5:%p1%d%;m"
#define XTERM_SETAB_256_COLON \
  "\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48:5:%p1%d%;m"

#define XTERM_SETAF_256 \
  "\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m"
#define XTERM_SETAB_256 \
  "\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m"
#define XTERM_SETAF_16 \
  "\x1b[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e39%;m"
#define XTERM_SETAB_16 \
  "\x1b[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e39%;m"

  // Terminals with 256-colour SGR support despite what terminfo says.
  if (unibi_get_num(ut, unibi_max_colors) < 256) {
    // See http://fedoraproject.org/wiki/Features/256_Color_Terminals
    if (true_xterm || iterm || iterm_pretending_xterm) {
      unibi_set_num(ut, unibi_max_colors, 256);
      unibi_set_str(ut, unibi_set_a_foreground, XTERM_SETAF_256_COLON);
      unibi_set_str(ut, unibi_set_a_background, XTERM_SETAB_256_COLON);
    } else if (konsole || xterm || gnome || rxvt || st || putty
               || linuxvt  // Linux 4.8+ supports 256-colour SGR.
               || mate_pretending_xterm || gnome_pretending_xterm
               || tmux
               || (colorterm && strstr(colorterm, "256"))
               || (term && strstr(term, "256"))) {
      unibi_set_num(ut, unibi_max_colors, 256);
      unibi_set_str(ut, unibi_set_a_foreground, XTERM_SETAF_256);
      unibi_set_str(ut, unibi_set_a_background, XTERM_SETAB_256);
    }
  }
  // Terminals with 16-colour SGR support despite what terminfo says.
  if (unibi_get_num(ut, unibi_max_colors) < 16) {
    if (colorterm) {
      unibi_set_num(ut, unibi_max_colors, 16);
      unibi_set_if_empty(ut, unibi_set_a_foreground, XTERM_SETAF_16);
      unibi_set_if_empty(ut, unibi_set_a_background, XTERM_SETAB_16);
    }
  }

  // Blacklist of terminals that cannot be trusted to report DECSCUSR support.
  if (!(st || (vte_version != 0 && vte_version < 3900) || konsole)) {
    data->unibi_ext.reset_cursor_style = unibi_find_ext_str(ut, "Se");
    data->unibi_ext.set_cursor_style = unibi_find_ext_str(ut, "Ss");
  }

  // Dickey ncurses terminfo includes Ss/Se capabilities since 2011-07-14. So
  // adding them to terminal types, that have such control sequences but lack
  // the correct terminfo entries, is a fixup, not an augmentation.
  if (-1 == data->unibi_ext.set_cursor_style) {
    // DECSCUSR (cursor shape) sequence is widely supported by several terminal
    // types.  https://github.com/gnachman/iTerm2/pull/92
    // xterm extension: vertical bar
    if (!konsole
        && ((xterm && !vte_version)  // anything claiming xterm compat
            // per MinTTY 0.4.3-1 release notes from 2009
            || putty
            // per https://bugzilla.gnome.org/show_bug.cgi?id=720821
            || (vte_version >= 3900)
            || tmux       // per tmux manual page
            // https://lists.gnu.org/archive/html/screen-devel/2013-03/msg00000.html
            || screen
            || st         // #7641
            || rxvt       // per command.C
            // per analysis of VT100Terminal.m
            || iterm || iterm_pretending_xterm
            || teraterm    // per TeraTerm "Supported Control Functions" doco
            // Some linux-type terminals implement the xterm extension.
            // Example: console-terminal-emulator from the nosh toolset.
            || (linuxvt
                && (xterm_version || (vte_version > 0) || colorterm)))) {
      data->unibi_ext.set_cursor_style =
        (int)unibi_add_ext_str(ut, "Ss", "\x1b[%p1%d q");
      if (-1 == data->unibi_ext.reset_cursor_style) {
          data->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
                                                                      "");
      }
      unibi_set_ext_str(ut, (size_t)data->unibi_ext.reset_cursor_style,
                        "\x1b[ q");
    } else if (linuxvt) {
      // Linux uses an idiosyncratic escape code to set the cursor shape and
      // does not support DECSCUSR.
      // See http://linuxgazette.net/137/anonymous.html for more info
      data->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
          "\x1b[?"
          "%?"
          // The parameter passed to Ss is the DECSCUSR parameter, so the
          // terminal capability has to translate into the Linux idiosyncratic
          // parameter.
          //
          // linuxvt only supports block and underline. It is also only
          // possible to have a steady block (no steady underline)
          "%p1%{2}%<" "%t%{8}"       // blink block
          "%e%p1%{2}%=" "%t%{112}"   // steady block
          "%e%p1%{3}%=" "%t%{4}"     // blink underline (set to half block)
          "%e%p1%{4}%=" "%t%{4}"     // steady underline
          "%e%p1%{5}%=" "%t%{2}"     // blink bar (set to underline)
          "%e%p1%{6}%=" "%t%{2}"     // steady bar
          "%e%{0}"                   // anything else
          "%;" "%dc");
      if (-1 == data->unibi_ext.reset_cursor_style) {
          data->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
                                                                      "");
      }
      unibi_set_ext_str(ut, (size_t)data->unibi_ext.reset_cursor_style,
          "\x1b[?c");
    } else if (konsole) {
      // Konsole uses an idiosyncratic escape code to set the cursor shape and
      // does not support DECSCUSR.  This makes Konsole set up and apply a
      // nonce profile, which has side-effects on temporary font resizing.
      // In an ideal world, Konsole would just support DECSCUSR.
      data->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
          TMUX_WRAP(tmux, "\x1b]50;CursorShape=%?"
          "%p1%{3}%<" "%t%{0}"    // block
          "%e%p1%{5}%<" "%t%{2}"  // underline
          "%e%{1}"                // everything else is bar
          "%;%d;BlinkingCursorEnabled=%?"
          "%p1%{1}%<" "%t%{1}"  // Fortunately if we exclude zero as special,
          "%e%p1%{1}%&"  // in all other cases we can treat bit #0 as a flag.
          "%;%d\x07"));
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
  bool xterm = terminfo_is_term_family(term, "xterm");
  bool dtterm = terminfo_is_term_family(term, "dtterm");
  bool rxvt = terminfo_is_term_family(term, "rxvt");
  bool teraterm = terminfo_is_term_family(term, "teraterm");
  bool putty = terminfo_is_term_family(term, "putty");
  bool screen = terminfo_is_term_family(term, "screen");
  bool tmux = terminfo_is_term_family(term, "tmux") || !!os_getenv("TMUX");
  bool iterm = terminfo_is_term_family(term, "iterm")
    || terminfo_is_term_family(term, "iterm2")
    || terminfo_is_term_family(term, "iTerm.app")
    || terminfo_is_term_family(term, "iTerm2.app");
  // None of the following work over SSH; see :help TERM .
  bool iterm_pretending_xterm = xterm && iterm_env;

  const char * xterm_version = os_getenv("XTERM_VERSION");
  bool true_xterm = xterm && !!xterm_version;

  // Only define this capability for terminal types that we know understand it.
  if (dtterm         // originated this extension
      || xterm       // per xterm ctlseqs doco
      || konsole     // per commentary in VT102Emulation.cpp
      || teraterm    // per TeraTerm "Supported Control Functions" doco
      || rxvt) {     // per command.C
    data->unibi_ext.resize_screen = (int)unibi_add_ext_str(ut,
      "ext.resize_screen",
      "\x1b[8;%p1%d;%p2%dt");
  }
  if (putty || xterm || rxvt) {
    data->unibi_ext.reset_scroll_region = (int)unibi_add_ext_str(ut,
      "ext.reset_scroll_region",
      "\x1b[r");
  }

  // Dickey ncurses terminfo does not include the setrgbf and setrgbb
  // capabilities, proposed by Rüdiger Sonderfeld on 2013-10-15.  Adding
  // them here when terminfo lacks them is an augmentation, not a fixup.
  // https://gist.github.com/XVilka/8346728

  // At this time (2017-07-12) it seems like all terminals that support rgb
  // color codes can use semicolons in the terminal code and be fine.
  // However, this is not correct according to the spec. So to reward those
  // terminals that also support colons, we output the code that way on these
  // specific ones.

  // can use colons like ISO 8613-6:1994/ITU T.416:1993 says.
  bool has_colon_rgb = !tmux && !screen
    && !vte_version  // VTE colon-support has a big memory leak. #7573
    && (iterm || iterm_pretending_xterm  // per VT100Terminal.m
        // per http://invisible-island.net/xterm/xterm.log.html#xterm_282
        || true_xterm);

  data->unibi_ext.set_rgb_foreground = unibi_find_ext_str(ut, "setrgbf");
  if (-1 == data->unibi_ext.set_rgb_foreground) {
    if (has_colon_rgb) {
      data->unibi_ext.set_rgb_foreground = (int)unibi_add_ext_str(ut, "setrgbf",
          "\x1b[38:2:%p1%d:%p2%d:%p3%dm");
    } else {
      data->unibi_ext.set_rgb_foreground = (int)unibi_add_ext_str(ut, "setrgbf",
          "\x1b[38;2;%p1%d;%p2%d;%p3%dm");
    }
  }
  data->unibi_ext.set_rgb_background = unibi_find_ext_str(ut, "setrgbb");
  if (-1 == data->unibi_ext.set_rgb_background) {
    if (has_colon_rgb) {
      data->unibi_ext.set_rgb_background = (int)unibi_add_ext_str(ut, "setrgbb",
          "\x1b[48:2:%p1%d:%p2%d:%p3%dm");
    } else {
      data->unibi_ext.set_rgb_background = (int)unibi_add_ext_str(ut, "setrgbb",
          "\x1b[48;2;%p1%d;%p2%d;%p3%dm");
    }
  }

  if (iterm || iterm_pretending_xterm) {
    // FIXME: Bypassing tmux like this affects the cursor colour globally, in
    // all panes, which is not particularly desirable.  A better approach
    // would use a tmux control sequence and an extra if(screen) test.
    data->unibi_ext.set_cursor_color = (int)unibi_add_ext_str(
        ut, NULL, TMUX_WRAP(tmux, "\033]Pl%p1%06x\033\\"));
  } else if (xterm || (vte_version != 0) || rxvt) {
    // This seems to be supported for a long time in VTE
    // urxvt also supports this
    data->unibi_ext.set_cursor_color = (int)unibi_add_ext_str(
        ut, NULL, "\033]12;#%p1%06x\007");
  }

  /// Terminals usually ignore unrecognized private modes, and there is no
  /// known ambiguity with these. So we just set them unconditionally.
  data->unibi_ext.enable_lr_margin = (int)unibi_add_ext_str(
      ut, "ext.enable_lr_margin", "\x1b[?69h");
  data->unibi_ext.disable_lr_margin = (int)unibi_add_ext_str(
      ut, "ext.disable_lr_margin", "\x1b[?69l");
  data->unibi_ext.enable_bracketed_paste = (int)unibi_add_ext_str(
      ut, "ext.enable_bpaste", "\x1b[?2004h");
  data->unibi_ext.disable_bracketed_paste = (int)unibi_add_ext_str(
      ut, "ext.disable_bpaste", "\x1b[?2004l");
  // For urxvt send BOTH xterm and old urxvt sequences. #8695
  data->unibi_ext.enable_focus_reporting = (int)unibi_add_ext_str(
      ut, "ext.enable_focus",
      rxvt ? "\x1b[?1004h\x1b]777;focus;on\x7" : "\x1b[?1004h");
  data->unibi_ext.disable_focus_reporting = (int)unibi_add_ext_str(
      ut, "ext.disable_focus",
      rxvt ? "\x1b[?1004l\x1b]777;focus;off\x7" : "\x1b[?1004l");
  data->unibi_ext.enable_mouse = (int)unibi_add_ext_str(
      ut, "ext.enable_mouse", "\x1b[?1002h\x1b[?1006h");
  data->unibi_ext.disable_mouse = (int)unibi_add_ext_str(
      ut, "ext.disable_mouse", "\x1b[?1002l\x1b[?1006l");
}

static void flush_buf(UI *ui)
{
  uv_write_t req;
  uv_buf_t bufs[3];
  uv_buf_t *bufp = &bufs[0];
  TUIData *data = ui->data;

  if (data->bufpos <= 0 && data->busy == data->is_invisible) {
    return;
  }

  if (!data->is_invisible) {
    // cursor is visible. Write a "cursor invisible" command before writing the
    // buffer.
    bufp->base = data->invis;
    bufp->len = UV_BUF_LEN(data->invislen);
    bufp++;
    data->is_invisible = true;
  }

  if (data->bufpos > 0) {
    bufp->base = data->buf;
    bufp->len = UV_BUF_LEN(data->bufpos);
    bufp++;
  }

  if (!data->busy) {
    assert(data->is_invisible);
    // not busy and the cursor is invisible. Write a "cursor normal" command
    // after writing the buffer.
    bufp->base = data->norm;
    bufp->len = UV_BUF_LEN(data->normlen);
    bufp++;
    data->is_invisible = data->busy;
  }

  uv_write(&req, STRUCT_CAST(uv_stream_t, &data->output_handle),
           bufs, (unsigned)(bufp - bufs), NULL);
  uv_run(&data->write_loop, UV_RUN_DEFAULT);
  data->bufpos = 0;
  data->overflow = false;
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
    DLOG("stty/termios:erase=%s", stty_erase);
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
    DLOG("libtermkey:kbs=%s", value);
    if (stty_erase[0] != 0) {
      return stty_erase;
    }
  } else if (strequal(name, "key_dc")) {
    DLOG("libtermkey:kdch1=%s", value);
    // Vim: "If <BS> and <DEL> are now the same, redefine <DEL>."
    if (value != NULL && strequal(stty_erase, value)) {
      return stty_erase[0] == DEL ? CTRL_H_STR : DEL_STR;
    }
  } else if (strequal(name, "key_mouse")) {
    DLOG("libtermkey:kmous=%s", value);
    // If key_mouse is found, libtermkey uses its terminfo driver (driver-ti.c)
    // for mouse input, which by accident only supports X10 protocol.
    // Force libtermkey to fallback to its CSI driver (driver-csi.c). #7948
    return NULL;
  }

  return value;
}
#endif
