// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Terminal UI functions. Invoked (by ui_bridge.c) on the TUI thread.

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <unibilium.h>
#include <uv.h>
#if defined(HAVE_TERMIOS_H)
# include <termios.h>
#endif

#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii.h"
#include "nvim/event/loop.h"
#include "nvim/event/signal.h"
#include "nvim/highlight.h"
#include "nvim/lib/kvec.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/map.h"
#include "nvim/memory.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/signal.h"
#include "nvim/os/tty.h"
#include "nvim/ui.h"
#include "nvim/vim.h"
#ifdef WIN32
# include "nvim/os/os_win_console.h"
#endif
#include "nvim/cursor_shape.h"
#include "nvim/macros.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/tui/input.h"
#include "nvim/tui/terminfo.h"
#include "nvim/tui/tui.h"
#include "nvim/ugrid.h"
#include "nvim/ui_bridge.h"

// Space reserved in two output buffers to make the cursor normal or invisible
// when flushing. No existing terminal will require 32 bytes to do that.
#define CNORM_COMMAND_MAX_SIZE 32
#define OUTBUF_SIZE 0xffff

#define TOO_MANY_EVENTS 1000000
#define STARTS_WITH(str, prefix) \
  (strlen(str) >= (sizeof(prefix) - 1) \
   && 0 == memcmp((str), (prefix), sizeof(prefix) - 1))
#define TMUX_WRAP(is_tmux, seq) \
  ((is_tmux) ? "\x1bPtmux;\x1b" seq "\x1b\\" : seq)
#define LINUXSET0C "\x1b[?0c"
#define LINUXSET1C "\x1b[?1c"

#ifdef NVIM_UNIBI_HAS_VAR_FROM
# define UNIBI_SET_NUM_VAR(var, num) \
  do { \
    (var) = unibi_var_from_num((num)); \
  } while (0)
#else
# define UNIBI_SET_NUM_VAR(var, num) (var).i = (num);
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
  int row, col;
  int out_fd;
  bool scroll_region_is_full_screen;
  bool can_change_scroll_region;
  bool can_set_lr_margin;  // smglr
  bool can_set_left_right_margin;
  bool can_scroll;
  bool can_erase_chars;
  bool immediate_wrap_after_last_column;
  bool bce;
  bool mouse_enabled;
  bool busy, is_invisible, want_invisible;
  bool cork, overflow;
  bool cursor_color_changed;
  bool is_starting;
  FILE *screenshot;
  cursorentry_T cursor_shapes[SHAPE_IDX_COUNT];
  HlAttrs clear_attrs;
  kvec_t(HlAttrs) attrs;
  int print_attr_id;
  bool default_attr;
  bool can_clear_attr;
  ModeShape showing_mode;
  struct {
    int enable_mouse, disable_mouse;
    int enable_bracketed_paste, disable_bracketed_paste;
    int enable_lr_margin, disable_lr_margin;
    int enter_strikethrough_mode;
    int set_rgb_foreground, set_rgb_background;
    int set_cursor_color;
    int reset_cursor_color;
    int enable_focus_reporting, disable_focus_reporting;
    int resize_screen;
    int reset_scroll_region;
    int set_cursor_style, reset_cursor_style;
    int save_title, restore_title;
    int get_bg;
    int set_underline_style;
    int set_underline_color;
  } unibi_ext;
  char *space_buf;
} TUIData;

static bool volatile got_winch = false;
static bool did_user_set_dimensions = false;
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
  ui->screenshot = tui_screenshot;
  ui->option_set= tui_option_set;
  ui->raw_line = tui_raw_line;

  memset(ui->ui_ext, 0, sizeof(ui->ui_ext));
  ui->ui_ext[kUILinegrid] = true;
  ui->ui_ext[kUITermColors] = true;

  return ui_bridge_attach(ui, tui_main, tui_scheduler);
}

static size_t unibi_pre_fmt_str(TUIData *data, unsigned int unibi_index, char * buf, size_t len)
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
  data->can_clear_attr = false;
  data->is_invisible = true;
  data->want_invisible = false;
  data->busy = false;
  data->cork = false;
  data->overflow = false;
  data->cursor_color_changed = false;
  data->showing_mode = SHAPE_IDX_N;
  data->unibi_ext.enable_mouse = -1;
  data->unibi_ext.disable_mouse = -1;
  data->unibi_ext.set_cursor_color = -1;
  data->unibi_ext.reset_cursor_color = -1;
  data->unibi_ext.enable_bracketed_paste = -1;
  data->unibi_ext.disable_bracketed_paste = -1;
  data->unibi_ext.enter_strikethrough_mode = -1;
  data->unibi_ext.enable_lr_margin = -1;
  data->unibi_ext.disable_lr_margin = -1;
  data->unibi_ext.enable_focus_reporting = -1;
  data->unibi_ext.disable_focus_reporting = -1;
  data->unibi_ext.resize_screen = -1;
  data->unibi_ext.reset_scroll_region = -1;
  data->unibi_ext.set_cursor_style = -1;
  data->unibi_ext.reset_cursor_style = -1;
  data->unibi_ext.get_bg = -1;
  data->unibi_ext.set_underline_color = -1;
  data->out_fd = STDOUT_FILENO;
  data->out_isatty = os_isatty(data->out_fd);

  const char *term = os_getenv("TERM");
#ifdef WIN32
  os_tty_guess_term(&term, data->out_fd);
  os_setenv("TERM", term, 1);
  // Old os_getenv() pointer is invalid after os_setenv(), fetch it again.
  term = os_getenv("TERM");
#endif

  // Set up unibilium/terminfo.
  char *termname = NULL;
  if (term) {
    os_env_var_lock();
    data->ut = unibi_from_term(term);
    os_env_var_unlock();
    if (data->ut) {
      termname = xstrdup(term);
    }
  }
  if (!data->ut) {
    data->ut = terminfo_from_builtin(term, &termname);
  }
  // Update 'term' option.
  loop_schedule_deferred(&main_loop,
                         event_create(termname_set_event, 1, termname));

  // None of the following work over SSH; see :help TERM .
  const char *colorterm = os_getenv("COLORTERM");
  const char *termprg = os_getenv("TERM_PROGRAM");
  const char *vte_version_env = os_getenv("VTE_VERSION");
  long vtev = vte_version_env ? strtol(vte_version_env, NULL, 10) : 0;
  bool iterm_env = termprg && strstr(termprg, "iTerm.app");
  bool nsterm = (termprg && strstr(termprg, "Apple_Terminal"))
                || terminfo_is_term_family(term, "nsterm");
  bool konsole = terminfo_is_term_family(term, "konsole")
                 || os_getenv("KONSOLE_PROFILE_NAME")
                 || os_getenv("KONSOLE_DBUS_SESSION");
  const char *konsolev_env = os_getenv("KONSOLE_VERSION");
  long konsolev = konsolev_env ? strtol(konsolev_env, NULL, 10)
                               : (konsole ? 1 : 0);

  patch_terminfo_bugs(data, term, colorterm, vtev, konsolev, iterm_env, nsterm);
  augment_terminfo(data, term, vtev, konsolev, iterm_env, nsterm);
  data->can_change_scroll_region =
    !!unibi_get_str(data->ut, unibi_change_scroll_region);
  data->can_set_lr_margin =
    !!unibi_get_str(data->ut, unibi_set_lr_margin);
  data->can_set_left_right_margin =
    !!unibi_get_str(data->ut, unibi_set_left_margin_parm)
    && !!unibi_get_str(data->ut, unibi_set_right_margin_parm);
  data->can_scroll =
    !!unibi_get_str(data->ut, unibi_delete_line)
    && !!unibi_get_str(data->ut, unibi_parm_delete_line)
    && !!unibi_get_str(data->ut, unibi_insert_line)
    && !!unibi_get_str(data->ut, unibi_parm_insert_line);
  data->can_erase_chars = !!unibi_get_str(data->ut, unibi_erase_chars);
  data->immediate_wrap_after_last_column =
    terminfo_is_term_family(term, "conemu")
    || terminfo_is_term_family(term, "cygwin")
    || terminfo_is_term_family(term, "win32con")
    || terminfo_is_term_family(term, "interix");
  data->bce = unibi_get_bool(data->ut, unibi_back_color_erase);
  data->normlen = unibi_pre_fmt_str(data, unibi_cursor_normal,
                                    data->norm, sizeof data->norm);
  data->invislen = unibi_pre_fmt_str(data, unibi_cursor_invisible,
                                     data->invis, sizeof data->invis);
  // Set 't_Co' from the result of unibilium & fix_terminfo.
  t_colors = unibi_get_num(data->ut, unibi_max_colors);
  // Enter alternate screen, save title, and clear.
  // NOTE: Do this *before* changing terminal settings. #6433
  unibi_out(ui, unibi_enter_ca_mode);
  // Save title/icon to the "stack". #4063
  unibi_out_ext(ui, data->unibi_ext.save_title);
  unibi_out(ui, unibi_keypad_xmit);
  unibi_out(ui, unibi_clear_screen);
  // Ask the terminal to send us the background color.
  data->input.waiting_for_bg_response = 5;
  unibi_out_ext(ui, data->unibi_ext.get_bg);
  // Enable bracketed paste
  unibi_out_ext(ui, data->unibi_ext.enable_bracketed_paste);

  uv_loop_init(&data->write_loop);
  if (data->out_isatty) {
    uv_tty_init(&data->write_loop, &data->output_handle.tty, data->out_fd, 0);
#ifdef WIN32
    uv_tty_set_mode(&data->output_handle.tty, UV_TTY_MODE_RAW);
#else
    int retry_count = 10;
    // A signal may cause uv_tty_set_mode() to fail (e.g., SIGCONT). Retry a
    // few times. #12322
    while (uv_tty_set_mode(&data->output_handle.tty, UV_TTY_MODE_IO) == UV_EINTR
           && retry_count > 0) {
      retry_count--;
    }
#endif
  } else {
    uv_pipe_init(&data->write_loop, &data->output_handle.pipe, 0);
    uv_pipe_open(&data->output_handle.pipe, data->out_fd);
  }
  flush_buf(ui);
}

static void terminfo_stop(UI *ui)
{
  TUIData *data = ui->data;
  // Destroy output stuff
  tui_mode_change(ui, (String)STRING_INIT, SHAPE_IDX_N);
  tui_mouse_off(ui);
  unibi_out(ui, unibi_exit_attribute_mode);
  // Reset cursor to normal before exiting alternate screen.
  unibi_out(ui, unibi_cursor_normal);
  unibi_out(ui, unibi_keypad_local);
  unibi_out(ui, unibi_exit_ca_mode);
  // Restore title/icon from the "stack". #4063
  unibi_out_ext(ui, data->unibi_ext.restore_title);
  if (data->cursor_color_changed) {
    unibi_out_ext(ui, data->unibi_ext.reset_cursor_color);
  }
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
  data->print_attr_id = -1;
  ugrid_init(&data->grid);
  terminfo_start(ui);
  tui_guess_size(ui);
  signal_watcher_start(&data->winch_handle, sigwinch_cb, SIGWINCH);
  tinput_start(&data->input);
}

static void tui_terminal_after_startup(UI *ui)
  FUNC_ATTR_NONNULL_ALL
{
  TUIData *data = ui->data;

  // Emit this after Nvim startup, not during.  This works around a tmux
  // 2.3 bug(?) which caused slow drawing during startup.  #7649
  unibi_out_ext(ui, data->unibi_ext.enable_focus_reporting);
  flush_buf(ui);
}

static void tui_terminal_stop(UI *ui)
{
  TUIData *data = ui->data;
  if (uv_is_closing(STRUCT_CAST(uv_handle_t, &data->output_handle))) {
    // Race between SIGCONT (tui.c) and SIGHUP (os/signal.c)? #8075
    ELOG("TUI already stopped (race?)");
    ui->data = NULL;  // Flag UI as "stopped".
    return;
  }
  tinput_stop(&data->input);
  signal_watcher_stop(&data->winch_handle);
  terminfo_stop(ui);
  ugrid_free(&data->grid);
}

static void tui_stop(UI *ui)
{
  tui_terminal_stop(ui);
  ui->data = NULL;  // Flag UI as "stopped".
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
  data->is_starting = true;
  data->screenshot = NULL;
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
  tinput_init(&data->input, &tui_loop);
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
  }
  // "Passive" (I/O-driven) loop: TUI thread "main loop".
  while (!tui_is_stopped(ui)) {
    loop_poll_events(&tui_loop, -1);  // tui_loop.events is never processed
  }

  ui_bridge_stopped(bridge);
  tinput_destroy(&data->input);
  signal_watcher_stop(&data->cont_handle);
  signal_watcher_close(&data->cont_handle, NULL);
  signal_watcher_close(&data->winch_handle, NULL);
  loop_close(&tui_loop, false);
  kv_destroy(data->invalid_regions);
  kv_destroy(data->attrs);
  xfree(data->space_buf);
  xfree(data);
}

/// Handoff point between the main (ui_bridge) thread and the TUI thread.
static void tui_scheduler(Event event, void *d)
{
  UI *ui = d;
  TUIData *data = ui->data;
  loop_schedule_fast(data->loop, event);  // `tui_loop` local to tui_main().
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

  tui_guess_size(ui);
  ui_schedule_refresh();
}

static bool attrs_differ(UI *ui, int id1, int id2, bool rgb)
{
  TUIData *data = ui->data;
  if (id1 == id2) {
    return false;
  } else if (id1 < 0 || id2 < 0) {
    return true;
  }
  HlAttrs a1 = kv_A(data->attrs, (size_t)id1);
  HlAttrs a2 = kv_A(data->attrs, (size_t)id2);

  if (rgb) {
    return a1.rgb_fg_color != a2.rgb_fg_color
           || a1.rgb_bg_color != a2.rgb_bg_color
           || a1.rgb_ae_attr != a2.rgb_ae_attr
           || a1.rgb_sp_color != a2.rgb_sp_color;
  } else {
    return a1.cterm_fg_color != a2.cterm_fg_color
           || a1.cterm_bg_color != a2.cterm_bg_color
           || a1.cterm_ae_attr != a2.cterm_ae_attr
           || (a1.cterm_ae_attr & (HL_UNDERLINE|HL_UNDERCURL)
               && a1.rgb_sp_color != a2.rgb_sp_color);
  }
}

static void update_attrs(UI *ui, int attr_id)
{
  TUIData *data = ui->data;

  if (!attrs_differ(ui, attr_id, data->print_attr_id, ui->rgb)) {
    data->print_attr_id = attr_id;
    return;
  }
  data->print_attr_id = attr_id;
  HlAttrs attrs = kv_A(data->attrs, (size_t)attr_id);
  int attr = ui->rgb ? attrs.rgb_ae_attr : attrs.cterm_ae_attr;

  bool bold = attr & HL_BOLD;
  bool italic = attr & HL_ITALIC;
  bool reverse = attr & HL_INVERSE;
  bool standout = attr & HL_STANDOUT;
  bool strikethrough = attr & HL_STRIKETHROUGH;

  bool underline;
  bool undercurl;
  if (data->unibi_ext.set_underline_style != -1) {
    underline = attr & HL_UNDERLINE;
    undercurl = attr & HL_UNDERCURL;
  } else {
    underline = (attr & HL_UNDERLINE) || (attr & HL_UNDERCURL);
    undercurl = false;
  }

  if (unibi_get_str(data->ut, unibi_set_attributes)) {
    if (bold || reverse || underline || standout) {
      UNIBI_SET_NUM_VAR(data->params[0], standout);
      UNIBI_SET_NUM_VAR(data->params[1], underline);
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
    if (underline) {
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
  if (strikethrough && data->unibi_ext.enter_strikethrough_mode != -1) {
    unibi_out_ext(ui, data->unibi_ext.enter_strikethrough_mode);
  }
  if (undercurl && data->unibi_ext.set_underline_style != -1) {
    UNIBI_SET_NUM_VAR(data->params[0], 3);
    unibi_out_ext(ui, data->unibi_ext.set_underline_style);
  }
  if ((undercurl || underline) && data->unibi_ext.set_underline_color != -1) {
    int color = attrs.rgb_sp_color;
    if (color != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], (color >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(data->params[1], (color >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(data->params[2], color & 0xff);          // blue
      unibi_out_ext(ui, data->unibi_ext.set_underline_color);
    }
  }

  int fg, bg;
  if (ui->rgb && !(attr & HL_FG_INDEXED)) {
    fg = ((attrs.rgb_fg_color != -1)
          ? attrs.rgb_fg_color : data->clear_attrs.rgb_fg_color);
    if (fg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], (fg >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(data->params[1], (fg >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(data->params[2], fg & 0xff);          // blue
      unibi_out_ext(ui, data->unibi_ext.set_rgb_foreground);
    }
  } else {
    fg = (attrs.cterm_fg_color
          ? attrs.cterm_fg_color - 1 : (data->clear_attrs.cterm_fg_color - 1));
    if (fg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], fg);
      unibi_out(ui, unibi_set_a_foreground);
    }
  }

  if (ui->rgb && !(attr & HL_BG_INDEXED)) {
    bg = ((attrs.rgb_bg_color != -1)
          ? attrs.rgb_bg_color : data->clear_attrs.rgb_bg_color);
    if (bg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], (bg >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(data->params[1], (bg >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(data->params[2], bg & 0xff);          // blue
      unibi_out_ext(ui, data->unibi_ext.set_rgb_background);
    }
  } else {
    bg = (attrs.cterm_bg_color
          ? attrs.cterm_bg_color - 1 : (data->clear_attrs.cterm_bg_color - 1));
    if (bg != -1) {
      UNIBI_SET_NUM_VAR(data->params[0], bg);
      unibi_out(ui, unibi_set_a_background);
    }
  }


  data->default_attr = fg == -1 && bg == -1
                       && !bold && !italic && !underline && !undercurl && !reverse && !standout
                       && !strikethrough;

  // Non-BCE terminals can't clear with non-default background color. Some BCE
  // terminals don't support attributes either, so don't rely on it. But assume
  // italic and bold has no effect if there is no text.
  data->can_clear_attr = !reverse && !standout && !underline && !undercurl
                         && !strikethrough && (data->bce || bg == -1);
}

static void final_column_wrap(UI *ui)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  if (grid->row != -1 && grid->col == ui->width) {
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
  update_attrs(ui, ptr->attr);
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
    if (attrs_differ(ui, cell->attr,
                     data->print_attr_id, ui->rgb)) {
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
  if (grid->row == -1) {
    goto safe_move;
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

safe_move:
  unibi_goto(ui, row, col);
  ugrid_goto(grid, row, col);
}

static void clear_region(UI *ui, int top, int bot, int left, int right, int attr_id)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  update_attrs(ui, attr_id);

  // Background is set to the default color and the right edge matches the
  // screen end, try to use terminal codes for clearing the requested area.
  if (data->can_clear_attr
      && left == 0 && right == ui->width && bot == ui->height) {
    if (top == 0) {
      unibi_out(ui, unibi_clear_screen);
      ugrid_goto(&data->grid, top, left);
    } else {
      cursor_goto(ui, top, 0);
      unibi_out(ui, unibi_clr_eos);
    }
  } else {
    int width = right-left;

    // iterate through each line and clear
    for (int row = top; row < bot; row++) {
      cursor_goto(ui, row, left);
      if (data->can_clear_attr && right == ui->width) {
        unibi_out(ui, unibi_clr_eol);
      } else if (data->can_erase_chars && data->can_clear_attr && width >= 5) {
        UNIBI_SET_NUM_VAR(data->params[0], width);
        unibi_out(ui, unibi_erase_chars);
      } else {
        out(ui, data->space_buf, (size_t)width);
        grid->col += width;
        if (data->immediate_wrap_after_last_column) {
          // Printing at the right margin immediately advances the cursor.
          final_column_wrap(ui);
        }
      }
    }
  }
}

static void set_scroll_region(UI *ui, int top, int bot, int left, int right)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;

  UNIBI_SET_NUM_VAR(data->params[0], top);
  UNIBI_SET_NUM_VAR(data->params[1], bot);
  unibi_out(ui, unibi_change_scroll_region);
  if (left != 0 || right != ui->width - 1) {
    unibi_out_ext(ui, data->unibi_ext.enable_lr_margin);
    if (data->can_set_lr_margin) {
      UNIBI_SET_NUM_VAR(data->params[0], left);
      UNIBI_SET_NUM_VAR(data->params[1], right);
      unibi_out(ui, unibi_set_lr_margin);
    } else {
      UNIBI_SET_NUM_VAR(data->params[0], left);
      unibi_out(ui, unibi_set_left_margin_parm);
      UNIBI_SET_NUM_VAR(data->params[0], right);
      unibi_out(ui, unibi_set_right_margin_parm);
    }
  }
  grid->row = -1;
}

static void reset_scroll_region(UI *ui, bool fullwidth)
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
  if (!fullwidth) {
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
  grid->row = -1;
}

static void tui_grid_resize(UI *ui, Integer g, Integer width, Integer height)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_resize(grid, (int)width, (int)height);

  xfree(data->space_buf);
  data->space_buf = xmalloc((size_t)width * sizeof(*data->space_buf));
  memset(data->space_buf, ' ', (size_t)width);

  // resize might not always be followed by a clear before flush
  // so clip the invalid region
  for (size_t i = 0; i < kv_size(data->invalid_regions); i++) {
    Rect *r = &kv_A(data->invalid_regions, i);
    r->bot = MIN(r->bot, grid->height);
    r->right = MIN(r->right, grid->width);
  }

  if (!got_winch && (!data->is_starting || did_user_set_dimensions)) {
    // Resize the _host_ terminal.
    UNIBI_SET_NUM_VAR(data->params[0], (int)height);
    UNIBI_SET_NUM_VAR(data->params[1], (int)width);
    unibi_out_ext(ui, data->unibi_ext.resize_screen);
    // DECSLPP does not reset the scroll region.
    if (data->scroll_region_is_full_screen) {
      reset_scroll_region(ui, ui->width == grid->width);
    }
  } else {  // Already handled the SIGWINCH signal; avoid double-resize.
    got_winch = false;
    grid->row = -1;
  }
}

static void tui_grid_clear(UI *ui, Integer g)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  ugrid_clear(grid);
  kv_size(data->invalid_regions) = 0;
  clear_region(ui, 0, grid->height, 0, grid->width, 0);
}

static void tui_grid_cursor_goto(UI *ui, Integer grid, Integer row, Integer col)
{
  TUIData *data = ui->data;

  // cursor position is validated in tui_flush
  data->row = (int)row;
  data->col = (int)col;
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
    HlAttrs aep = kv_A(data->attrs, c.id);

    data->want_invisible = aep.hl_blend == 100;
    if (data->want_invisible) {
      unibi_out(ui, unibi_cursor_invisible);
    } else if (aep.rgb_ae_attr & HL_INVERSE) {
      // We interpret "inverse" as "default" (no termcode for "inverse"...).
      // Hopefully the user's default cursor color is inverse.
      unibi_out_ext(ui, data->unibi_ext.reset_cursor_color);
    } else {
      UNIBI_SET_NUM_VAR(data->params[0], aep.rgb_bg_color);
      unibi_out_ext(ui, data->unibi_ext.set_cursor_color);
      data->cursor_color_changed = true;
    }
  } else if (c.id == 0) {
    // No cursor color for this mode; reset to default.
    data->want_invisible = false;
    unibi_out_ext(ui, data->unibi_ext.reset_cursor_color);
  }

  int shape;
  switch (c.shape) {
  default:
    abort(); break;
  case SHAPE_BLOCK:
    shape = 1; break;
  case SHAPE_HOR:
    shape = 3; break;
  case SHAPE_VER:
    shape = 5; break;
  }
  UNIBI_SET_NUM_VAR(data->params[0], shape + (int)(c.blinkon == 0));
  unibi_out_ext(ui, data->unibi_ext.set_cursor_style);
}

/// @param mode editor mode
static void tui_mode_change(UI *ui, String mode, Integer mode_idx)
{
  TUIData *data = ui->data;
#ifdef UNIX
  // If stdin is not a TTY, the LHS of pipe may change the state of the TTY
  // after calling uv_tty_set_mode. So, set the mode of the TTY again here.
  // #13073
  if (data->is_starting && data->input.in_fd == STDERR_FILENO) {
    uv_tty_set_mode(&data->output_handle.tty, UV_TTY_MODE_NORMAL);
    uv_tty_set_mode(&data->output_handle.tty, UV_TTY_MODE_IO);
  }
#endif
  tui_set_mode(ui, (ModeShape)mode_idx);
  data->is_starting = false;  // mode entered, no longer starting
  data->showing_mode = (ModeShape)mode_idx;
}

static void tui_grid_scroll(UI *ui, Integer g, Integer startrow,  // -V751
                            Integer endrow, Integer startcol, Integer endcol, Integer rows,
                            Integer cols FUNC_ATTR_UNUSED)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  int top = (int)startrow, bot = (int)endrow-1;
  int left = (int)startcol, right = (int)endcol-1;

  bool fullwidth = left == 0 && right == ui->width-1;
  data->scroll_region_is_full_screen = fullwidth
                                       && top == 0 && bot == ui->height-1;

  ugrid_scroll(grid, top, bot, left, right, (int)rows);

  bool can_scroll = data->can_scroll
                    && (data->scroll_region_is_full_screen
                        || (data->can_change_scroll_region
                            && ((left == 0 && right == ui->width - 1)
                                || data->can_set_lr_margin
                                || data->can_set_left_right_margin)));

  if (can_scroll) {
    // Change terminal scroll region and move cursor to the top
    if (!data->scroll_region_is_full_screen) {
      set_scroll_region(ui, top, bot, left, right);
    }
    cursor_goto(ui, top, left);
    update_attrs(ui, 0);

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
      reset_scroll_region(ui, fullwidth);
    }
  } else {
    // Mark the moved region as invalid for redrawing later
    if (rows > 0) {
      endrow = endrow - rows;
    } else {
      startrow = startrow - rows;
    }
    invalidate(ui, (int)startrow, (int)endrow, (int)startcol, (int)endcol);
  }
}

static void tui_hl_attr_define(UI *ui, Integer id, HlAttrs attrs, HlAttrs cterm_attrs, Array info)
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

static void tui_default_colors_set(UI *ui, Integer rgb_fg, Integer rgb_bg, Integer rgb_sp,
                                   Integer cterm_fg, Integer cterm_bg)
{
  TUIData *data = ui->data;

  data->clear_attrs.rgb_fg_color = (int)rgb_fg;
  data->clear_attrs.rgb_bg_color = (int)rgb_bg;
  data->clear_attrs.rgb_sp_color = (int)rgb_sp;
  data->clear_attrs.cterm_fg_color = (int)cterm_fg;
  data->clear_attrs.cterm_bg_color = (int)cterm_bg;

  data->print_attr_id = -1;
  invalidate(ui, 0, data->grid.height, 0, data->grid.width);
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
    assert(r.bot <= grid->height && r.right <= grid->width);

    for (int row = r.top; row < r.bot; row++) {
      int clear_attr = grid->cells[row][r.right-1].attr;
      int clear_col;
      for (clear_col = r.right; clear_col > 0; clear_col--) {
        UCell *cell = &grid->cells[row][clear_col-1];
        if (!(cell->data[0] == ' ' && cell->data[1] == NUL
              && cell->attr == clear_attr)) {
          break;
        }
      }

      UGRID_FOREACH_CELL(grid, row, r.left, clear_col, {
        cursor_goto(ui, row, curcol);
        print_cell(ui, cell);
      });
      if (clear_col < r.right) {
        clear_region(ui, row, row+1, clear_col, r.right, clear_attr);
      }
    }
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
  signal_stop();
  kill(0, SIGTSTP);
  signal_start();
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

static void tui_screenshot(UI *ui, String path)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  flush_buf(ui);
  grid->row = 0;
  grid->col = 0;

  FILE *f = fopen(path.data, "w");
  data->screenshot = f;
  fprintf(f, "%d,%d\n", grid->height, grid->width);
  unibi_out(ui, unibi_clear_screen);
  for (int i = 0; i < grid->height; i++) {
    cursor_goto(ui, i, 0);
    for (int j = 0; j < grid->width; j++) {
      print_cell(ui, &grid->cells[i][j]);
    }
  }
  flush_buf(ui);
  data->screenshot = NULL;

  fclose(f);
}


static void tui_option_set(UI *ui, String name, Object value)
{
  TUIData *data = ui->data;
  if (strequal(name.data, "termguicolors")) {
    ui->rgb = value.data.boolean;

    data->print_attr_id = -1;
    invalidate(ui, 0, data->grid.height, 0, data->grid.width);
  }
  if (strequal(name.data, "ttimeout")) {
    data->input.ttimeout = value.data.boolean;
  }
  if (strequal(name.data, "ttimeoutlen")) {
    data->input.ttimeoutlen = (long)value.data.integer;
  }
}

static void tui_raw_line(UI *ui, Integer g, Integer linerow, Integer startcol, Integer endcol,
                         Integer clearcol, Integer clearattr, LineFlags flags, const schar_T *chunk,
                         const sattr_T *attrs)
{
  TUIData *data = ui->data;
  UGrid *grid = &data->grid;
  for (Integer c = startcol; c < endcol; c++) {
    memcpy(grid->cells[linerow][c].data, chunk[c-startcol], sizeof(schar_T));
    assert((size_t)attrs[c-startcol] < kv_size(data->attrs));
    grid->cells[linerow][c].attr = attrs[c-startcol];
  }
  UGRID_FOREACH_CELL(grid, (int)linerow, (int)startcol, (int)endcol, {
    cursor_goto(ui, (int)linerow, curcol);
    print_cell(ui, cell);
  });

  if (clearcol > endcol) {
    ugrid_clear_chunk(grid, (int)linerow, (int)endcol, (int)clearcol,
                      (sattr_T)clearattr);
    clear_region(ui, (int)linerow, (int)linerow+1, (int)endcol, (int)clearcol,
                 (int)clearattr);
  }

  if (flags & kLineFlagWrap && ui->width == grid->width
      && linerow + 1 < grid->height) {
    // Only do line wrapping if the grid width is equal to the terminal
    // width and the line continuation is within the grid.

    if (endcol != grid->width) {
      // Print the last char of the row, if we haven't already done so.
      int size = grid->cells[linerow][grid->width - 1].data[0] == NUL ? 2 : 1;
      cursor_goto(ui, (int)linerow, grid->width - size);
      print_cell(ui, &grid->cells[linerow][grid->width - size]);
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

  for (size_t i = 0; i < kv_size(data->invalid_regions); i++) {
    Rect *r = &kv_A(data->invalid_regions, i);
    // adjacent regions are treated as overlapping
    if (!(top > r->bot || bot < r->top)
        && !(left > r->right || right < r->left)) {
      intersects = r;
      break;
    }
  }

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

/// Tries to get the user's wanted dimensions (columns and rows) for the entire
/// application (i.e., the host terminal).
static void tui_guess_size(UI *ui)
{
  TUIData *data = ui->data;
  int width = 0, height = 0;

  // 1 - look for non-default 'columns' and 'lines' options during startup
  if (data->is_starting && (Columns != DFLT_COLS || Rows != DFLT_ROWS)) {
    did_user_set_dimensions = true;
    assert(Columns >= INT_MIN && Columns <= INT_MAX);
    assert(Rows >= INT_MIN && Rows <= INT_MAX);
    width = Columns;
    height = Rows;
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

static void unibi_set_if_empty(unibi_term *ut, enum unibi_string str, const char *val)
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

static int unibi_find_ext_bool(unibi_term *ut, const char *name)
{
  size_t max = unibi_count_ext_bool(ut);
  for (size_t i = 0; i < max; i++) {
    const char * n = unibi_get_ext_bool_name(ut, i);
    if (n && 0 == strcmp(n, name)) {
      return (int)i;
    }
  }
  return -1;
}

/// Patches the terminfo records after loading from system or built-in db.
/// Several entries in terminfo are known to be deficient or outright wrong;
/// and several terminal emulators falsely announce incorrect terminal types.
static void patch_terminfo_bugs(TUIData *data, const char *term, const char *colorterm,
                                long vte_version, long konsolev, bool iterm_env, bool nsterm)
{
  unibi_term *ut = data->ut;
  const char *xterm_version = os_getenv("XTERM_VERSION");
#if 0   // We don't need to identify this specifically, for now.
  bool roxterm = !!os_getenv("ROXTERM_ID");
#endif
  bool xterm = terminfo_is_term_family(term, "xterm")
               // Treat Terminal.app as generic xterm-like, for now.
               || nsterm;
  bool kitty = terminfo_is_term_family(term, "xterm-kitty");
  bool linuxvt = terminfo_is_term_family(term, "linux");
  bool bsdvt = terminfo_is_bsd_console(term);
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
  bool alacritty = terminfo_is_term_family(term, "alacritty");
  // None of the following work over SSH; see :help TERM .
  bool iterm_pretending_xterm = xterm && iterm_env;
  bool gnome_pretending_xterm = xterm && colorterm
                                && strstr(colorterm, "gnome-terminal");
  bool mate_pretending_xterm = xterm && colorterm
                               && strstr(colorterm, "mate-terminal");
  bool true_xterm = xterm && !!xterm_version && !bsdvt;
  bool cygwin = terminfo_is_term_family(term, "cygwin");

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

    // 2017-04 terminfo.src lacks these.  Xterm-likes have them.
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]0;");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x07");
    unibi_set_if_empty(ut, unibi_set_tb_margin, "\x1b[%i%p1%d;%p2%dr");
    unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
    unibi_set_if_empty(ut, unibi_exit_italics_mode, "\x1b[23m");

    if (true_xterm) {
      // 2017-04 terminfo.src lacks these.  genuine Xterm has them.
      unibi_set_if_empty(ut, unibi_set_lr_margin, "\x1b[%i%p1%d;%p2%ds");
      unibi_set_if_empty(ut, unibi_set_left_margin_parm, "\x1b[%i%p1%ds");
      unibi_set_if_empty(ut, unibi_set_right_margin_parm, "\x1b[%i;%p2%ds");
    } else {
      // Fix things advertised via TERM=xterm, for non-xterm.
      if (unibi_get_str(ut, unibi_set_lr_margin)) {
        ILOG("Disabling smglr with TERM=xterm for non-xterm.");
        unibi_set_str(ut, unibi_set_lr_margin, NULL);
      }
    }

#ifdef WIN32
    // XXX: workaround libuv implicit LF => CRLF conversion. #10558
    unibi_set_str(ut, unibi_cursor_down, "\x1b[B");
#endif
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
    // Fix an issue where smglr is inherited by TERM=screen.xterm.
    if (unibi_get_str(ut, unibi_set_lr_margin)) {
      ILOG("Disabling smglr with TERM=screen.xterm for screen.");
      unibi_set_str(ut, unibi_set_lr_margin, NULL);
    }
  } else if (tmux) {
    unibi_set_if_empty(ut, unibi_to_status_line, "\x1b_");
    unibi_set_if_empty(ut, unibi_from_status_line, "\x1b\\");
    unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
    unibi_set_if_empty(ut, unibi_exit_italics_mode, "\x1b[23m");
  } else if (terminfo_is_term_family(term, "interix")) {
    // 2017-04 terminfo.src lacks this.
    unibi_set_if_empty(ut, unibi_carriage_return, "\x0d");
  } else if (linuxvt) {
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

  data->unibi_ext.get_bg = (int)unibi_add_ext_str(ut, "ext.get_bg",
                                                  "\x1b]11;?\x07");

  // Terminals with 256-colour SGR support despite what terminfo says.
  if (unibi_get_num(ut, unibi_max_colors) < 256) {
    // See http://fedoraproject.org/wiki/Features/256_Color_Terminals
    if (true_xterm || iterm || iterm_pretending_xterm) {
      unibi_set_num(ut, unibi_max_colors, 256);
      unibi_set_str(ut, unibi_set_a_foreground, XTERM_SETAF_256_COLON);
      unibi_set_str(ut, unibi_set_a_background, XTERM_SETAB_256_COLON);
    } else if (konsolev || xterm || gnome || rxvt || st || putty
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
  if (!(st || (vte_version != 0 && vte_version < 3900) || konsolev)) {
    data->unibi_ext.reset_cursor_style = unibi_find_ext_str(ut, "Se");
    data->unibi_ext.set_cursor_style = unibi_find_ext_str(ut, "Ss");
  }

  // Dickey ncurses terminfo includes Ss/Se capabilities since 2011-07-14. So
  // adding them to terminal types, that have such control sequences but lack
  // the correct terminfo entries, is a fixup, not an augmentation.
  if (-1 == data->unibi_ext.set_cursor_style) {
    // DECSCUSR (cursor shape) is widely supported.
    // https://github.com/gnachman/iTerm2/pull/92
    if ((!bsdvt && (!konsolev || konsolev >= 180770))
        && ((xterm && !vte_version)  // anything claiming xterm compat
            // per MinTTY 0.4.3-1 release notes from 2009
            || putty
            // per https://bugzilla.gnome.org/show_bug.cgi?id=720821
            || (vte_version >= 3900)
            || (konsolev >= 180770)  // #9364
            || tmux       // per tmux manual page
            // https://lists.gnu.org/archive/html/screen-devel/2013-03/msg00000.html
            || screen
            || st         // #7641
            || rxvt       // per command.C
            // per analysis of VT100Terminal.m
            || iterm || iterm_pretending_xterm
            || teraterm   // per TeraTerm "Supported Control Functions" doco
            || alacritty  // https://github.com/jwilm/alacritty/pull/608
            || cygwin
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
    } else if (konsolev > 0 && konsolev < 180770) {
      // Konsole before version 18.07.70: set up a nonce profile. This has
      // side-effects on temporary font resizing. #6798
      data->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
                                                                TMUX_WRAP(tmux,
                                                                          "\x1b]50;CursorShape=%?"
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
static void augment_terminfo(TUIData *data, const char *term, long vte_version, long konsolev,
                             bool iterm_env, bool nsterm)
{
  unibi_term *ut = data->ut;
  bool xterm = terminfo_is_term_family(term, "xterm")
               // Treat Terminal.app as generic xterm-like, for now.
               || nsterm;
  bool bsdvt = terminfo_is_bsd_console(term);
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
  bool alacritty = terminfo_is_term_family(term, "alacritty");
  // None of the following work over SSH; see :help TERM .
  bool iterm_pretending_xterm = xterm && iterm_env;

  const char *xterm_version = os_getenv("XTERM_VERSION");
  bool true_xterm = xterm && !!xterm_version && !bsdvt;

  // Only define this capability for terminal types that we know understand it.
  if (dtterm         // originated this extension
      || xterm       // per xterm ctlseqs doco
      || konsolev    // per commentary in VT102Emulation.cpp
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

  // terminfo describes strikethrough modes as rmxx/smxx with respect
  // to the ECMA-48 strikeout/crossed-out attributes.
  data->unibi_ext.enter_strikethrough_mode = unibi_find_ext_str(ut, "smxx");

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
    data->unibi_ext.set_cursor_color =
      (int)unibi_add_ext_str(ut, NULL, TMUX_WRAP(tmux, "\033]Pl%p1%06x\033\\"));
  } else if ((xterm || rxvt || tmux || alacritty)
             && (vte_version == 0 || vte_version >= 3900)) {
    // Supported in urxvt, newer VTE.
    data->unibi_ext.set_cursor_color = (int)unibi_add_ext_str(ut, "ext.set_cursor_color",
                                                              "\033]12;#%p1%06x\007");
  }

  if (-1 != data->unibi_ext.set_cursor_color) {
    data->unibi_ext.reset_cursor_color = (int)unibi_add_ext_str(ut, "ext.reset_cursor_color",
                                                                "\x1b]112\x07");
  }

  data->unibi_ext.save_title = (int)unibi_add_ext_str(ut, "ext.save_title", "\x1b[22;0t");
  data->unibi_ext.restore_title = (int)unibi_add_ext_str(ut, "ext.restore_title", "\x1b[23;0t");

  /// Terminals usually ignore unrecognized private modes, and there is no
  /// known ambiguity with these. So we just set them unconditionally.
  data->unibi_ext.enable_lr_margin =
    (int)unibi_add_ext_str(ut, "ext.enable_lr_margin", "\x1b[?69h");
  data->unibi_ext.disable_lr_margin = (int)unibi_add_ext_str(ut, "ext.disable_lr_margin",
                                                             "\x1b[?69l");
  data->unibi_ext.enable_bracketed_paste = (int)unibi_add_ext_str(ut, "ext.enable_bpaste",
                                                                  "\x1b[?2004h");
  data->unibi_ext.disable_bracketed_paste = (int)unibi_add_ext_str(ut, "ext.disable_bpaste",
                                                                   "\x1b[?2004l");
  // For urxvt send BOTH xterm and old urxvt sequences. #8695
  data->unibi_ext.enable_focus_reporting = (int)unibi_add_ext_str(ut, "ext.enable_focus",
                                                                  rxvt ? "\x1b[?1004h\x1b]777;focus;on\x7" : "\x1b[?1004h");
  data->unibi_ext.disable_focus_reporting = (int)unibi_add_ext_str(ut, "ext.disable_focus",
                                                                   rxvt ? "\x1b[?1004l\x1b]777;focus;off\x7" : "\x1b[?1004l");
  data->unibi_ext.enable_mouse = (int)unibi_add_ext_str(ut, "ext.enable_mouse",
                                                        "\x1b[?1002h\x1b[?1006h");
  data->unibi_ext.disable_mouse = (int)unibi_add_ext_str(ut, "ext.disable_mouse",
                                                         "\x1b[?1002l\x1b[?1006l");

  // Extended underline.
  // terminfo will have Smulx for this (but no support for colors yet).
  data->unibi_ext.set_underline_style = unibi_find_ext_str(ut, "Smulx");
  if (data->unibi_ext.set_underline_style == -1) {
    int ext_bool_Su = unibi_find_ext_bool(ut, "Su");  // used by kitty
    if (vte_version >= 5102
        || (ext_bool_Su != -1
            && unibi_get_ext_bool(ut, (size_t)ext_bool_Su))) {
      data->unibi_ext.set_underline_style = (int)unibi_add_ext_str(ut, "ext.set_underline_style",
                                                                   "\x1b[4:%p1%dm");
    }
  }
  if (data->unibi_ext.set_underline_style != -1) {
    // Only support colon syntax. #9270
    data->unibi_ext.set_underline_color = (int)unibi_add_ext_str(ut, "ext.set_underline_color",
                                                                 "\x1b[58:2::%p1%d:%p2%d:%p3%dm");
  }
}

static void flush_buf(UI *ui)
{
  uv_write_t req;
  uv_buf_t bufs[3];
  uv_buf_t *bufp = &bufs[0];
  TUIData *data = ui->data;

  // The content of the output for each condition is shown in the following
  // table. Therefore, if data->bufpos == 0 and N/A or invis + norm, there is
  // no need to output it.
  //
  //                         | is_invisible | !is_invisible
  // ------+-----------------+--------------+---------------
  // busy  | want_invisible  |     N/A      |    invis
  //       | !want_invisible |     N/A      |    invis
  // ------+-----------------+--------------+---------------
  // !busy | want_invisible  |     N/A      |    invis
  //       | !want_invisible |     norm     | invis + norm
  // ------+-----------------+--------------+---------------
  //
  if (data->bufpos <= 0
      && ((data->is_invisible && data->busy)
          || (data->is_invisible && !data->busy && data->want_invisible)
          || (!data->is_invisible && !data->busy && !data->want_invisible))) {
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
    if (!data->want_invisible) {
      bufp->base = data->norm;
      bufp->len = UV_BUF_LEN(data->normlen);
      bufp++;
      data->is_invisible = false;
    }
  }

  if (data->screenshot) {
    for (size_t i = 0; i < (size_t)(bufp - bufs); i++) {
      fwrite(bufs[i].base, bufs[i].len, 1, data->screenshot);
    }
  } else {
    uv_write(&req, STRUCT_CAST(uv_stream_t, &data->output_handle),
             bufs, (unsigned)(bufp - bufs), NULL);
    uv_run(&data->write_loop, UV_RUN_DEFAULT);
  }
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
# if defined(HAVE_TERMIOS_H)
  struct termios t;
  if (tcgetattr(input_global_fd(), &t) != -1) {
    stty_erase[0] = (char)t.c_cc[VERASE];
    stty_erase[1] = '\0';
    DLOG("stty/termios:erase=%s", stty_erase);
  }
# endif
  return stty_erase;
}

/// libtermkey hook to override terminfo entries.
/// @see TermInput.tk_ti_hook_fn
static const char *tui_tk_ti_getstr(const char *name, const char *value, void *data)
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
    if (value != NULL && value != (char *)-1 && strequal(stty_erase, value)) {
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
