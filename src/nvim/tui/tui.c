// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Terminal UI functions. Invoked (by ui_client.c) on the UI process.

#include <assert.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unibilium.h>
#include <uv.h>

#include "auto/config.h"
#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/cursor_shape.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/signal.h"
#include "nvim/event/stream.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight_defs.h"
#include "nvim/log.h"
#include "nvim/macros.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/tui/input.h"
#include "nvim/tui/terminfo.h"
#include "nvim/tui/tui.h"
#include "nvim/ugrid.h"
#include "nvim/ui.h"
#include "nvim/ui_client.h"

#ifdef MSWIN
# include "nvim/os/os_win_console.h"
# include "nvim/os/tty.h"
#endif

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

#define UNIBI_SET_NUM_VAR(var, num) \
  do { \
    (var) = unibi_var_from_num((num)); \
  } while (0)
#define UNIBI_SET_STR_VAR(var, str) \
  do { \
    (var) = unibi_var_from_str((str)); \
  } while (0)

typedef struct {
  int top, bot, left, right;
} Rect;

struct TUIData {
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
  char *term;  // value of $TERM
  union {
    uv_tty_t tty;
    uv_pipe_t pipe;
  } output_handle;
  bool out_isatty;
  SignalWatcher winch_handle;
  uv_timer_t startup_delay_timer;
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
  bool mouse_move_enabled;
  bool title_enabled;
  bool busy, is_invisible, want_invisible;
  bool cork, overflow;
  bool set_cursor_color_as_str;
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
  Integer verbose;
  struct {
    int enable_mouse, disable_mouse;
    int enable_mouse_move, disable_mouse_move;
    int enable_bracketed_paste, disable_bracketed_paste;
    int enable_lr_margin, disable_lr_margin;
    int enter_strikethrough_mode;
    int enter_altfont_mode;
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
    int enable_extended_keys, disable_extended_keys;
    int get_extkeys;
  } unibi_ext;
  char *space_buf;
  bool stopped;
  int width;
  int height;
  bool rgb;
};

static int got_winch = 0;
static bool cursor_style_enabled = false;
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/tui.c.generated.h"
#endif

void tui_start(TUIData **tui_p, int *width, int *height, char **term)
{
  TUIData *tui = xcalloc(1, sizeof(TUIData));
  tui->is_starting = true;
  tui->screenshot = NULL;
  tui->stopped = false;
  tui->loop = &main_loop;
  kv_init(tui->invalid_regions);
  signal_watcher_init(tui->loop, &tui->winch_handle, tui);

  // TODO(bfredl): zero hl is empty, send this explicitly?
  kv_push(tui->attrs, HLATTRS_INIT);

  tui->input.tk_ti_hook_fn = tui_tk_ti_getstr;
  tinput_init(&tui->input, &main_loop);
  ugrid_init(&tui->grid);
  tui_terminal_start(tui);

  uv_timer_init(&tui->loop->uv, &tui->startup_delay_timer);
  tui->startup_delay_timer.data = tui;
  uv_timer_start(&tui->startup_delay_timer, after_startup_cb,
                 100, 0);

  *tui_p = tui;
  loop_poll_events(&main_loop, 1);
  *width = tui->width;
  *height = tui->height;
  *term = tui->term;
}

void tui_enable_extkeys(TUIData *tui)
{
  TermInput input = tui->input;
  unibi_term *ut = tui->ut;

  switch (input.extkeys_type) {
  case kExtkeysCSIu:
    tui->unibi_ext.enable_extended_keys = (int)unibi_add_ext_str(ut, "ext.enable_extended_keys",
                                                                 "\x1b[>1u");
    tui->unibi_ext.disable_extended_keys = (int)unibi_add_ext_str(ut, "ext.disable_extended_keys",
                                                                  "\x1b[<1u");
    break;
  case kExtkeysXterm:
    tui->unibi_ext.enable_extended_keys = (int)unibi_add_ext_str(ut, "ext.enable_extended_keys",
                                                                 "\x1b[>4;2m");
    tui->unibi_ext.disable_extended_keys = (int)unibi_add_ext_str(ut, "ext.disable_extended_keys",
                                                                  "\x1b[>4;0m");
    break;
  default:
    break;
  }

  unibi_out_ext(tui, tui->unibi_ext.enable_extended_keys);
}

static size_t unibi_pre_fmt_str(TUIData *tui, unsigned unibi_index, char *buf, size_t len)
{
  const char *str = unibi_get_str(tui->ut, unibi_index);
  if (!str) {
    return 0U;
  }
  return unibi_run(str, tui->params, buf, len);
}

static void terminfo_start(TUIData *tui)
{
  tui->scroll_region_is_full_screen = true;
  tui->bufpos = 0;
  tui->default_attr = false;
  tui->can_clear_attr = false;
  tui->is_invisible = true;
  tui->want_invisible = false;
  tui->busy = false;
  tui->cork = false;
  tui->overflow = false;
  tui->set_cursor_color_as_str = false;
  tui->cursor_color_changed = false;
  tui->showing_mode = SHAPE_IDX_N;
  tui->unibi_ext.enable_mouse = -1;
  tui->unibi_ext.disable_mouse = -1;
  tui->unibi_ext.enable_mouse_move = -1;
  tui->unibi_ext.disable_mouse_move = -1;
  tui->unibi_ext.set_cursor_color = -1;
  tui->unibi_ext.reset_cursor_color = -1;
  tui->unibi_ext.enable_bracketed_paste = -1;
  tui->unibi_ext.disable_bracketed_paste = -1;
  tui->unibi_ext.enter_strikethrough_mode = -1;
  tui->unibi_ext.enter_altfont_mode = -1;
  tui->unibi_ext.enable_lr_margin = -1;
  tui->unibi_ext.disable_lr_margin = -1;
  tui->unibi_ext.enable_focus_reporting = -1;
  tui->unibi_ext.disable_focus_reporting = -1;
  tui->unibi_ext.resize_screen = -1;
  tui->unibi_ext.reset_scroll_region = -1;
  tui->unibi_ext.set_cursor_style = -1;
  tui->unibi_ext.reset_cursor_style = -1;
  tui->unibi_ext.get_bg = -1;
  tui->unibi_ext.set_underline_color = -1;
  tui->unibi_ext.enable_extended_keys = -1;
  tui->unibi_ext.disable_extended_keys = -1;
  tui->unibi_ext.get_extkeys = -1;
  tui->out_fd = STDOUT_FILENO;
  tui->out_isatty = os_isatty(tui->out_fd);
  tui->input.tui_data = tui;

  const char *term = os_getenv("TERM");
#ifdef MSWIN
  os_tty_guess_term(&term, tui->out_fd);
  os_setenv("TERM", term, 1);
  // Old os_getenv() pointer is invalid after os_setenv(), fetch it again.
  term = os_getenv("TERM");
#endif

  // Set up unibilium/terminfo.
  if (term) {
    tui->ut = unibi_from_term(term);
    if (tui->ut) {
      if (!tui->term) {
        tui->term = xstrdup(term);
      }
    }
  }
  if (!tui->ut) {
    tui->ut = terminfo_from_builtin(term, &tui->term);
  }

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

  patch_terminfo_bugs(tui, term, colorterm, vtev, konsolev, iterm_env, nsterm);
  augment_terminfo(tui, term, vtev, konsolev, iterm_env, nsterm);
  tui->can_change_scroll_region =
    !!unibi_get_str(tui->ut, unibi_change_scroll_region);
  tui->can_set_lr_margin =
    !!unibi_get_str(tui->ut, unibi_set_lr_margin);
  tui->can_set_left_right_margin =
    !!unibi_get_str(tui->ut, unibi_set_left_margin_parm)
    && !!unibi_get_str(tui->ut, unibi_set_right_margin_parm);
  tui->can_scroll =
    !!unibi_get_str(tui->ut, unibi_delete_line)
    && !!unibi_get_str(tui->ut, unibi_parm_delete_line)
    && !!unibi_get_str(tui->ut, unibi_insert_line)
    && !!unibi_get_str(tui->ut, unibi_parm_insert_line);
  tui->can_erase_chars = !!unibi_get_str(tui->ut, unibi_erase_chars);
  tui->immediate_wrap_after_last_column =
    terminfo_is_term_family(term, "conemu")
    || terminfo_is_term_family(term, "cygwin")
    || terminfo_is_term_family(term, "win32con")
    || terminfo_is_term_family(term, "interix");
  tui->bce = unibi_get_bool(tui->ut, unibi_back_color_erase);
  tui->normlen = unibi_pre_fmt_str(tui, unibi_cursor_normal,
                                   tui->norm, sizeof tui->norm);
  tui->invislen = unibi_pre_fmt_str(tui, unibi_cursor_invisible,
                                    tui->invis, sizeof tui->invis);
  // Set 't_Co' from the result of unibilium & fix_terminfo.
  t_colors = unibi_get_num(tui->ut, unibi_max_colors);
  // Enter alternate screen, save title, and clear.
  // NOTE: Do this *before* changing terminal settings. #6433
  unibi_out(tui, unibi_enter_ca_mode);
  unibi_out(tui, unibi_keypad_xmit);
  unibi_out(tui, unibi_clear_screen);
  // Ask the terminal to send us the background color.
  tui->input.waiting_for_bg_response = 5;
  unibi_out_ext(tui, tui->unibi_ext.get_bg);
  // Enable bracketed paste
  unibi_out_ext(tui, tui->unibi_ext.enable_bracketed_paste);

  // Query the terminal to see if it supports CSI u
  tui->input.waiting_for_csiu_response = 5;
  unibi_out_ext(tui, tui->unibi_ext.get_extkeys);

  int ret;
  uv_loop_init(&tui->write_loop);
  if (tui->out_isatty) {
    ret = uv_tty_init(&tui->write_loop, &tui->output_handle.tty, tui->out_fd, 0);
    if (ret) {
      ELOG("uv_tty_init failed: %s", uv_strerror(ret));
    }
#ifndef MSWIN
    int retry_count = 10;
    // A signal may cause uv_tty_set_mode() to fail (e.g., SIGCONT). Retry a
    // few times. #12322
    while ((ret = uv_tty_set_mode(&tui->output_handle.tty, UV_TTY_MODE_IO)) == UV_EINTR
           && retry_count > 0) {
      retry_count--;
    }
    if (ret) {
      ELOG("uv_tty_set_mode failed: %s", uv_strerror(ret));
    }
#endif
  } else {
    ret = uv_pipe_init(&tui->write_loop, &tui->output_handle.pipe, 0);
    if (ret) {
      ELOG("uv_pipe_init failed: %s", uv_strerror(ret));
    }
    ret = uv_pipe_open(&tui->output_handle.pipe, tui->out_fd);
    if (ret) {
      ELOG("uv_pipe_open failed: %s", uv_strerror(ret));
    }
  }
  flush_buf(tui);
}

static void terminfo_stop(TUIData *tui)
{
  // Destroy output stuff
  tui_mode_change(tui, (String)STRING_INIT, SHAPE_IDX_N);
  tui_mouse_off(tui);
  unibi_out(tui, unibi_exit_attribute_mode);
  // Reset cursor to normal before exiting alternate screen.
  unibi_out(tui, unibi_cursor_normal);
  unibi_out(tui, unibi_keypad_local);
  // Disable extended keys before exiting alternate screen.
  unibi_out_ext(tui, tui->unibi_ext.disable_extended_keys);
  // May restore old title before exiting alternate screen.
  tui_set_title(tui, (String)STRING_INIT);
  // Exit alternate screen.
  unibi_out(tui, unibi_exit_ca_mode);
  if (tui->cursor_color_changed) {
    unibi_out_ext(tui, tui->unibi_ext.reset_cursor_color);
  }
  // Disable bracketed paste
  unibi_out_ext(tui, tui->unibi_ext.disable_bracketed_paste);
  // Disable focus reporting
  unibi_out_ext(tui, tui->unibi_ext.disable_focus_reporting);
  flush_buf(tui);
  uv_tty_reset_mode();
  uv_close((uv_handle_t *)&tui->output_handle, NULL);
  uv_run(&tui->write_loop, UV_RUN_DEFAULT);
  if (uv_loop_close(&tui->write_loop)) {
    abort();
  }
  unibi_destroy(tui->ut);
}

static void tui_terminal_start(TUIData *tui)
{
  tui->print_attr_id = -1;
  terminfo_start(tui);
  tui_guess_size(tui);
  signal_watcher_start(&tui->winch_handle, sigwinch_cb, SIGWINCH);
  tinput_start(&tui->input);
}

static void after_startup_cb(uv_timer_t *handle)
{
  TUIData *tui = handle->data;
  tui_terminal_after_startup(tui);
}

static void tui_terminal_after_startup(TUIData *tui)
  FUNC_ATTR_NONNULL_ALL
{
  // Emit this after Nvim startup, not during.  This works around a tmux
  // 2.3 bug(?) which caused slow drawing during startup.  #7649
  unibi_out_ext(tui, tui->unibi_ext.enable_focus_reporting);
  flush_buf(tui);
}

/// stop the terminal but allow it to restart later (like after suspend)
static void tui_terminal_stop(TUIData *tui)
{
  if (uv_is_closing(STRUCT_CAST(uv_handle_t, &tui->output_handle))) {
    // Race between SIGCONT (tui.c) and SIGHUP (os/signal.c)? #8075
    ELOG("TUI already stopped (race?)");
    tui->stopped = true;
    return;
  }
  tinput_stop(&tui->input);
  signal_watcher_stop(&tui->winch_handle);
  // Position the cursor on the last screen line, below all the text
  cursor_goto(tui, tui->height - 1, 0);
  terminfo_stop(tui);
}

void tui_stop(TUIData *tui)
{
  tui_terminal_stop(tui);
  stream_set_blocking(tui->input.in_fd, true);   // normalize stream (#2598)
  tinput_destroy(&tui->input);
  tui->stopped = true;
  signal_watcher_close(&tui->winch_handle, NULL);
  uv_close((uv_handle_t *)&tui->startup_delay_timer, NULL);
}

/// Returns true if UI `ui` is stopped.
bool tui_is_stopped(TUIData *tui)
{
  return tui->stopped;
}

#ifdef EXITFREE
void tui_free_all_mem(TUIData *tui)
{
  ugrid_free(&tui->grid);
  kv_destroy(tui->invalid_regions);
  kv_destroy(tui->attrs);
  xfree(tui->space_buf);
  xfree(tui->term);
  xfree(tui);
}
#endif

static void sigwinch_cb(SignalWatcher *watcher, int signum, void *cbdata)
{
  got_winch++;
  TUIData *tui = cbdata;
  if (tui_is_stopped(tui)) {
    return;
  }

  tui_guess_size(tui);
}

static bool attrs_differ(TUIData *tui, int id1, int id2, bool rgb)
{
  if (id1 == id2) {
    return false;
  } else if (id1 < 0 || id2 < 0) {
    return true;
  }
  HlAttrs a1 = kv_A(tui->attrs, (size_t)id1);
  HlAttrs a2 = kv_A(tui->attrs, (size_t)id2);

  if (rgb) {
    return a1.rgb_fg_color != a2.rgb_fg_color
           || a1.rgb_bg_color != a2.rgb_bg_color
           || a1.rgb_ae_attr != a2.rgb_ae_attr
           || a1.rgb_sp_color != a2.rgb_sp_color;
  } else {
    return a1.cterm_fg_color != a2.cterm_fg_color
           || a1.cterm_bg_color != a2.cterm_bg_color
           || a1.cterm_ae_attr != a2.cterm_ae_attr
           || (a1.cterm_ae_attr & HL_UNDERLINE_MASK
               && a1.rgb_sp_color != a2.rgb_sp_color);
  }
}

static void update_attrs(TUIData *tui, int attr_id)
{
  if (!attrs_differ(tui, attr_id, tui->print_attr_id, tui->rgb)) {
    tui->print_attr_id = attr_id;
    return;
  }
  tui->print_attr_id = attr_id;
  HlAttrs attrs = kv_A(tui->attrs, (size_t)attr_id);
  int attr = tui->rgb ? attrs.rgb_ae_attr : attrs.cterm_ae_attr;

  bool bold = attr & HL_BOLD;
  bool italic = attr & HL_ITALIC;
  bool reverse = attr & HL_INVERSE;
  bool standout = attr & HL_STANDOUT;
  bool strikethrough = attr & HL_STRIKETHROUGH;
  bool altfont = attr & HL_ALTFONT;

  bool underline;
  bool undercurl;
  bool underdouble;
  bool underdotted;
  bool underdashed;
  if (tui->unibi_ext.set_underline_style != -1) {
    int ul = attr & HL_UNDERLINE_MASK;
    underline = ul == HL_UNDERLINE;
    undercurl = ul == HL_UNDERCURL;
    underdouble = ul == HL_UNDERDOUBLE;
    underdashed = ul == HL_UNDERDASHED;
    underdotted = ul == HL_UNDERDOTTED;
  } else {
    underline = attr & HL_UNDERLINE_MASK;
    undercurl = false;
    underdouble = false;
    underdotted = false;
    underdashed = false;
  }

  bool has_any_underline = undercurl || underline
                           || underdouble || underdotted || underdashed;

  if (unibi_get_str(tui->ut, unibi_set_attributes)) {
    if (bold || reverse || underline || standout) {
      UNIBI_SET_NUM_VAR(tui->params[0], standout);
      UNIBI_SET_NUM_VAR(tui->params[1], underline);
      UNIBI_SET_NUM_VAR(tui->params[2], reverse);
      UNIBI_SET_NUM_VAR(tui->params[3], 0);   // blink
      UNIBI_SET_NUM_VAR(tui->params[4], 0);   // dim
      UNIBI_SET_NUM_VAR(tui->params[5], bold);
      UNIBI_SET_NUM_VAR(tui->params[6], 0);   // blank
      UNIBI_SET_NUM_VAR(tui->params[7], 0);   // protect
      UNIBI_SET_NUM_VAR(tui->params[8], 0);   // alternate character set
      unibi_out(tui, unibi_set_attributes);
    } else if (!tui->default_attr) {
      unibi_out(tui, unibi_exit_attribute_mode);
    }
  } else {
    if (!tui->default_attr) {
      unibi_out(tui, unibi_exit_attribute_mode);
    }
    if (bold) {
      unibi_out(tui, unibi_enter_bold_mode);
    }
    if (underline) {
      unibi_out(tui, unibi_enter_underline_mode);
    }
    if (standout) {
      unibi_out(tui, unibi_enter_standout_mode);
    }
    if (reverse) {
      unibi_out(tui, unibi_enter_reverse_mode);
    }
  }
  if (italic) {
    unibi_out(tui, unibi_enter_italics_mode);
  }
  if (altfont && tui->unibi_ext.enter_altfont_mode != -1) {
    unibi_out_ext(tui, tui->unibi_ext.enter_altfont_mode);
  }
  if (strikethrough && tui->unibi_ext.enter_strikethrough_mode != -1) {
    unibi_out_ext(tui, tui->unibi_ext.enter_strikethrough_mode);
  }
  if (undercurl && tui->unibi_ext.set_underline_style != -1) {
    UNIBI_SET_NUM_VAR(tui->params[0], 3);
    unibi_out_ext(tui, tui->unibi_ext.set_underline_style);
  }
  if (underdouble && tui->unibi_ext.set_underline_style != -1) {
    UNIBI_SET_NUM_VAR(tui->params[0], 2);
    unibi_out_ext(tui, tui->unibi_ext.set_underline_style);
  }
  if (underdotted && tui->unibi_ext.set_underline_style != -1) {
    UNIBI_SET_NUM_VAR(tui->params[0], 4);
    unibi_out_ext(tui, tui->unibi_ext.set_underline_style);
  }
  if (underdashed && tui->unibi_ext.set_underline_style != -1) {
    UNIBI_SET_NUM_VAR(tui->params[0], 5);
    unibi_out_ext(tui, tui->unibi_ext.set_underline_style);
  }

  if (has_any_underline && tui->unibi_ext.set_underline_color != -1) {
    int color = attrs.rgb_sp_color;
    if (color != -1) {
      UNIBI_SET_NUM_VAR(tui->params[0], (color >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(tui->params[1], (color >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(tui->params[2], color & 0xff);          // blue
      unibi_out_ext(tui, tui->unibi_ext.set_underline_color);
    }
  }

  int fg, bg;
  if (tui->rgb && !(attr & HL_FG_INDEXED)) {
    fg = ((attrs.rgb_fg_color != -1)
          ? attrs.rgb_fg_color : tui->clear_attrs.rgb_fg_color);
    if (fg != -1) {
      UNIBI_SET_NUM_VAR(tui->params[0], (fg >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(tui->params[1], (fg >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(tui->params[2], fg & 0xff);          // blue
      unibi_out_ext(tui, tui->unibi_ext.set_rgb_foreground);
    }
  } else {
    fg = (attrs.cterm_fg_color
          ? attrs.cterm_fg_color - 1 : (tui->clear_attrs.cterm_fg_color - 1));
    if (fg != -1) {
      UNIBI_SET_NUM_VAR(tui->params[0], fg);
      unibi_out(tui, unibi_set_a_foreground);
    }
  }

  if (tui->rgb && !(attr & HL_BG_INDEXED)) {
    bg = ((attrs.rgb_bg_color != -1)
          ? attrs.rgb_bg_color : tui->clear_attrs.rgb_bg_color);
    if (bg != -1) {
      UNIBI_SET_NUM_VAR(tui->params[0], (bg >> 16) & 0xff);  // red
      UNIBI_SET_NUM_VAR(tui->params[1], (bg >> 8) & 0xff);   // green
      UNIBI_SET_NUM_VAR(tui->params[2], bg & 0xff);          // blue
      unibi_out_ext(tui, tui->unibi_ext.set_rgb_background);
    }
  } else {
    bg = (attrs.cterm_bg_color
          ? attrs.cterm_bg_color - 1 : (tui->clear_attrs.cterm_bg_color - 1));
    if (bg != -1) {
      UNIBI_SET_NUM_VAR(tui->params[0], bg);
      unibi_out(tui, unibi_set_a_background);
    }
  }

  tui->default_attr = fg == -1 && bg == -1
                      && !bold && !italic && !has_any_underline && !reverse && !standout
                      && !strikethrough;

  // Non-BCE terminals can't clear with non-default background color. Some BCE
  // terminals don't support attributes either, so don't rely on it. But assume
  // italic and bold has no effect if there is no text.
  tui->can_clear_attr = !reverse && !standout && !has_any_underline
                        && !strikethrough && (tui->bce || bg == -1);
}

static void final_column_wrap(TUIData *tui)
{
  UGrid *grid = &tui->grid;
  if (grid->row != -1 && grid->col == tui->width) {
    grid->col = 0;
    if (grid->row < MIN(tui->height, grid->height - 1)) {
      grid->row++;
    }
  }
}

/// It is undocumented, but in the majority of terminals and terminal emulators
/// printing at the right margin does not cause an automatic wrap until the
/// next character is printed, holding the cursor in place until then.
static void print_cell(TUIData *tui, UCell *ptr)
{
  UGrid *grid = &tui->grid;
  if (!tui->immediate_wrap_after_last_column) {
    // Printing the next character finally advances the cursor.
    final_column_wrap(tui);
  }
  update_attrs(tui, ptr->attr);
  out(tui, ptr->data, strlen(ptr->data));
  grid->col++;
  if (tui->immediate_wrap_after_last_column) {
    // Printing at the right margin immediately advances the cursor.
    final_column_wrap(tui);
  }
}

static bool cheap_to_print(TUIData *tui, int row, int col, int next)
{
  UGrid *grid = &tui->grid;
  UCell *cell = grid->cells[row] + col;
  while (next) {
    next--;
    if (attrs_differ(tui, cell->attr,
                     tui->print_attr_id, tui->rgb)) {
      if (tui->default_attr) {
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
static void cursor_goto(TUIData *tui, int row, int col)
{
  UGrid *grid = &tui->grid;
  if (row == grid->row && col == grid->col) {
    return;
  }
  if (0 == row && 0 == col) {
    unibi_out(tui, unibi_cursor_home);
    ugrid_goto(grid, row, col);
    return;
  }
  if (grid->row == -1) {
    goto safe_move;
  }
  if (0 == col ? col != grid->col :
      row != grid->row ? false :
      1 == col ? 2 < grid->col && cheap_to_print(tui, grid->row, 0, col) :
      2 == col ? 5 < grid->col && cheap_to_print(tui, grid->row, 0, col) :
      false) {
    // Motion to left margin from anywhere else, or CR + printing chars is
    // even less expensive than using BSes or CUB.
    unibi_out(tui, unibi_carriage_return);
    ugrid_goto(grid, grid->row, 0);
  }
  if (row == grid->row) {
    if (col < grid->col
        // Deferred right margin wrap terminals have inconsistent ideas about
        // where the cursor actually is during a deferred wrap.  Relative
        // motion calculations have OBOEs that cannot be compensated for,
        // because two terminals that claim to be the same will implement
        // different cursor positioning rules.
        && (tui->immediate_wrap_after_last_column || grid->col < tui->width)) {
      int n = grid->col - col;
      if (n <= 4) {  // This might be just BS, so it is considered really cheap.
        while (n--) {
          unibi_out(tui, unibi_cursor_left);
        }
      } else {
        UNIBI_SET_NUM_VAR(tui->params[0], n);
        unibi_out(tui, unibi_parm_left_cursor);
      }
      ugrid_goto(grid, row, col);
      return;
    } else if (col > grid->col) {
      int n = col - grid->col;
      if (n <= 2) {
        while (n--) {
          unibi_out(tui, unibi_cursor_right);
        }
      } else {
        UNIBI_SET_NUM_VAR(tui->params[0], n);
        unibi_out(tui, unibi_parm_right_cursor);
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
          unibi_out(tui, unibi_cursor_down);
        }
      } else {
        UNIBI_SET_NUM_VAR(tui->params[0], n);
        unibi_out(tui, unibi_parm_down_cursor);
      }
      ugrid_goto(grid, row, col);
      return;
    } else if (row < grid->row) {
      int n = grid->row - row;
      if (n <= 2) {
        while (n--) {
          unibi_out(tui, unibi_cursor_up);
        }
      } else {
        UNIBI_SET_NUM_VAR(tui->params[0], n);
        unibi_out(tui, unibi_parm_up_cursor);
      }
      ugrid_goto(grid, row, col);
      return;
    }
  }

safe_move:
  unibi_goto(tui, row, col);
  ugrid_goto(grid, row, col);
}

static void print_spaces(TUIData *tui, int width)
{
  UGrid *grid = &tui->grid;

  out(tui, tui->space_buf, (size_t)width);
  grid->col += width;
  if (tui->immediate_wrap_after_last_column) {
    // Printing at the right margin immediately advances the cursor.
    final_column_wrap(tui);
  }
}

/// Move cursor to the position given by `row` and `col` and print the character in `cell`.
/// This allows the grid and the host terminal to assume different widths of ambiguous-width chars.
///
/// @param is_doublewidth  whether the character is double-width on the grid.
///                        If true and the character is ambiguous-width, clear two cells.
static void print_cell_at_pos(TUIData *tui, int row, int col, UCell *cell, bool is_doublewidth)
{
  UGrid *grid = &tui->grid;

  if (grid->row == -1 && cell->data[0] == NUL) {
    // If cursor needs to repositioned and there is nothing to print, don't move cursor.
    return;
  }

  cursor_goto(tui, row, col);

  bool is_ambiwidth = utf_ambiguous_width(utf_ptr2char(cell->data));
  if (is_ambiwidth && is_doublewidth) {
    // Clear the two screen cells.
    // If the character is single-width in the host terminal it won't change the second cell.
    update_attrs(tui, cell->attr);
    print_spaces(tui, 2);
    cursor_goto(tui, row, col);
  }

  print_cell(tui, cell);

  if (is_ambiwidth) {
    // Force repositioning cursor after printing an ambiguous-width character.
    grid->row = -1;
  }
}

static void clear_region(TUIData *tui, int top, int bot, int left, int right, int attr_id)
{
  UGrid *grid = &tui->grid;

  update_attrs(tui, attr_id);

  // Background is set to the default color and the right edge matches the
  // screen end, try to use terminal codes for clearing the requested area.
  if (tui->can_clear_attr
      && left == 0 && right == tui->width && bot == tui->height) {
    if (top == 0) {
      unibi_out(tui, unibi_clear_screen);
      ugrid_goto(grid, top, left);
    } else {
      cursor_goto(tui, top, 0);
      unibi_out(tui, unibi_clr_eos);
    }
  } else {
    int width = right - left;

    // iterate through each line and clear
    for (int row = top; row < bot; row++) {
      cursor_goto(tui, row, left);
      if (tui->can_clear_attr && right == tui->width) {
        unibi_out(tui, unibi_clr_eol);
      } else if (tui->can_erase_chars && tui->can_clear_attr && width >= 5) {
        UNIBI_SET_NUM_VAR(tui->params[0], width);
        unibi_out(tui, unibi_erase_chars);
      } else {
        print_spaces(tui, width);
      }
    }
  }
}

static void set_scroll_region(TUIData *tui, int top, int bot, int left, int right)
{
  UGrid *grid = &tui->grid;

  UNIBI_SET_NUM_VAR(tui->params[0], top);
  UNIBI_SET_NUM_VAR(tui->params[1], bot);
  unibi_out(tui, unibi_change_scroll_region);
  if (left != 0 || right != tui->width - 1) {
    unibi_out_ext(tui, tui->unibi_ext.enable_lr_margin);
    if (tui->can_set_lr_margin) {
      UNIBI_SET_NUM_VAR(tui->params[0], left);
      UNIBI_SET_NUM_VAR(tui->params[1], right);
      unibi_out(tui, unibi_set_lr_margin);
    } else {
      UNIBI_SET_NUM_VAR(tui->params[0], left);
      unibi_out(tui, unibi_set_left_margin_parm);
      UNIBI_SET_NUM_VAR(tui->params[0], right);
      unibi_out(tui, unibi_set_right_margin_parm);
    }
  }
  grid->row = -1;
}

static void reset_scroll_region(TUIData *tui, bool fullwidth)
{
  UGrid *grid = &tui->grid;

  if (0 <= tui->unibi_ext.reset_scroll_region) {
    unibi_out_ext(tui, tui->unibi_ext.reset_scroll_region);
  } else {
    UNIBI_SET_NUM_VAR(tui->params[0], 0);
    UNIBI_SET_NUM_VAR(tui->params[1], tui->height - 1);
    unibi_out(tui, unibi_change_scroll_region);
  }
  if (!fullwidth) {
    if (tui->can_set_lr_margin) {
      UNIBI_SET_NUM_VAR(tui->params[0], 0);
      UNIBI_SET_NUM_VAR(tui->params[1], tui->width - 1);
      unibi_out(tui, unibi_set_lr_margin);
    } else {
      UNIBI_SET_NUM_VAR(tui->params[0], 0);
      unibi_out(tui, unibi_set_left_margin_parm);
      UNIBI_SET_NUM_VAR(tui->params[0], tui->width - 1);
      unibi_out(tui, unibi_set_right_margin_parm);
    }
    unibi_out_ext(tui, tui->unibi_ext.disable_lr_margin);
  }
  grid->row = -1;
}

void tui_grid_resize(TUIData *tui, Integer g, Integer width, Integer height)
{
  UGrid *grid = &tui->grid;
  ugrid_resize(grid, (int)width, (int)height);

  xfree(tui->space_buf);
  tui->space_buf = xmalloc((size_t)width * sizeof(*tui->space_buf));
  memset(tui->space_buf, ' ', (size_t)width);

  // resize might not always be followed by a clear before flush
  // so clip the invalid region
  for (size_t i = 0; i < kv_size(tui->invalid_regions); i++) {
    Rect *r = &kv_A(tui->invalid_regions, i);
    r->bot = MIN(r->bot, grid->height);
    r->right = MIN(r->right, grid->width);
  }

  if (!got_winch && !tui->is_starting) {
    // Resize the _host_ terminal.
    UNIBI_SET_NUM_VAR(tui->params[0], (int)height);
    UNIBI_SET_NUM_VAR(tui->params[1], (int)width);
    unibi_out_ext(tui, tui->unibi_ext.resize_screen);
    // DECSLPP does not reset the scroll region.
    if (tui->scroll_region_is_full_screen) {
      reset_scroll_region(tui, tui->width == grid->width);
    }
  } else {  // Already handled the SIGWINCH signal; avoid double-resize.
    got_winch = got_winch > 0 ? got_winch - 1 : 0;
    grid->row = -1;
  }
}

void tui_grid_clear(TUIData *tui, Integer g)
{
  UGrid *grid = &tui->grid;
  ugrid_clear(grid);
  kv_size(tui->invalid_regions) = 0;
  clear_region(tui, 0, tui->height, 0, tui->width, 0);
}

void tui_grid_cursor_goto(TUIData *tui, Integer grid, Integer row, Integer col)
{
  // cursor position is validated in tui_flush
  tui->row = (int)row;
  tui->col = (int)col;
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

void tui_mode_info_set(TUIData *tui, bool guicursor_enabled, Array args)
{
  cursor_style_enabled = guicursor_enabled;
  if (!guicursor_enabled) {
    return;  // Do not send cursor style control codes.
  }

  assert(args.size);

  // cursor style entries as defined by `shape_table`.
  for (size_t i = 0; i < args.size; i++) {
    assert(args.items[i].type == kObjectTypeDictionary);
    cursorentry_T r = decode_cursor_entry(args.items[i].data.dictionary);
    tui->cursor_shapes[i] = r;
  }

  tui_set_mode(tui, tui->showing_mode);
}

void tui_update_menu(TUIData *tui)
{
  // Do nothing; menus are for GUI only
}

void tui_busy_start(TUIData *tui)
{
  tui->busy = true;
}

void tui_busy_stop(TUIData *tui)
{
  tui->busy = false;
}

void tui_mouse_on(TUIData *tui)
{
  if (!tui->mouse_enabled) {
    unibi_out_ext(tui, tui->unibi_ext.enable_mouse);
    if (tui->mouse_move_enabled) {
      unibi_out_ext(tui, tui->unibi_ext.enable_mouse_move);
    }
    tui->mouse_enabled = true;
  }
}

void tui_mouse_off(TUIData *tui)
{
  if (tui->mouse_enabled) {
    if (tui->mouse_move_enabled) {
      unibi_out_ext(tui, tui->unibi_ext.disable_mouse_move);
    }
    unibi_out_ext(tui, tui->unibi_ext.disable_mouse);
    tui->mouse_enabled = false;
  }
}

void tui_set_mode(TUIData *tui, ModeShape mode)
{
  if (!cursor_style_enabled) {
    return;
  }
  cursorentry_T c = tui->cursor_shapes[mode];

  if (c.id != 0 && c.id < (int)kv_size(tui->attrs) && tui->rgb) {
    HlAttrs aep = kv_A(tui->attrs, c.id);

    tui->want_invisible = aep.hl_blend == 100;
    if (tui->want_invisible) {
      unibi_out(tui, unibi_cursor_invisible);
    } else if (aep.rgb_ae_attr & HL_INVERSE) {
      // We interpret "inverse" as "default" (no termcode for "inverse"...).
      // Hopefully the user's default cursor color is inverse.
      unibi_out_ext(tui, tui->unibi_ext.reset_cursor_color);
    } else {
      char hexbuf[8];
      if (tui->set_cursor_color_as_str) {
        snprintf(hexbuf, 7 + 1, "#%06x", aep.rgb_bg_color);
        UNIBI_SET_STR_VAR(tui->params[0], hexbuf);
      } else {
        UNIBI_SET_NUM_VAR(tui->params[0], aep.rgb_bg_color);
      }
      unibi_out_ext(tui, tui->unibi_ext.set_cursor_color);
      tui->cursor_color_changed = true;
    }
  } else if (c.id == 0) {
    // No cursor color for this mode; reset to default.
    tui->want_invisible = false;
    unibi_out_ext(tui, tui->unibi_ext.reset_cursor_color);
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
  UNIBI_SET_NUM_VAR(tui->params[0], shape + (int)(c.blinkon == 0));
  unibi_out_ext(tui, tui->unibi_ext.set_cursor_style);
}

/// @param mode editor mode
void tui_mode_change(TUIData *tui, String mode, Integer mode_idx)
{
#ifdef UNIX
  // If stdin is not a TTY, the LHS of pipe may change the state of the TTY
  // after calling uv_tty_set_mode. So, set the mode of the TTY again here.
  // #13073
  if (tui->is_starting && !stdin_isatty) {
    int ret = uv_tty_set_mode(&tui->output_handle.tty, UV_TTY_MODE_NORMAL);
    if (ret) {
      ELOG("uv_tty_set_mode failed: %s", uv_strerror(ret));
    }
    ret = uv_tty_set_mode(&tui->output_handle.tty, UV_TTY_MODE_IO);
    if (ret) {
      ELOG("uv_tty_set_mode failed: %s", uv_strerror(ret));
    }
  }
#endif
  tui_set_mode(tui, (ModeShape)mode_idx);
  if (tui->is_starting) {
    if (tui->verbose >= 3) {
      show_verbose_terminfo(tui);
    }
  }
  tui->is_starting = false;  // mode entered, no longer starting
  tui->showing_mode = (ModeShape)mode_idx;
}

void tui_grid_scroll(TUIData *tui, Integer g, Integer startrow,  // -V751
                     Integer endrow, Integer startcol, Integer endcol, Integer rows,
                     Integer cols FUNC_ATTR_UNUSED)
{
  UGrid *grid = &tui->grid;
  int top = (int)startrow, bot = (int)endrow - 1;
  int left = (int)startcol, right = (int)endcol - 1;

  bool fullwidth = left == 0 && right == tui->width - 1;
  tui->scroll_region_is_full_screen = fullwidth
                                      && top == 0 && bot == tui->height - 1;

  ugrid_scroll(grid, top, bot, left, right, (int)rows);

  bool can_scroll = tui->can_scroll
                    && (tui->scroll_region_is_full_screen
                        || (tui->can_change_scroll_region
                            && ((left == 0 && right == tui->width - 1)
                                || tui->can_set_lr_margin
                                || tui->can_set_left_right_margin)));

  if (can_scroll) {
    // Change terminal scroll region and move cursor to the top
    if (!tui->scroll_region_is_full_screen) {
      set_scroll_region(tui, top, bot, left, right);
    }
    cursor_goto(tui, top, left);
    update_attrs(tui, 0);

    if (rows > 0) {
      if (rows == 1) {
        unibi_out(tui, unibi_delete_line);
      } else {
        UNIBI_SET_NUM_VAR(tui->params[0], (int)rows);
        unibi_out(tui, unibi_parm_delete_line);
      }
    } else {
      if (rows == -1) {
        unibi_out(tui, unibi_insert_line);
      } else {
        UNIBI_SET_NUM_VAR(tui->params[0], -(int)rows);
        unibi_out(tui, unibi_parm_insert_line);
      }
    }

    // Restore terminal scroll region and cursor
    if (!tui->scroll_region_is_full_screen) {
      reset_scroll_region(tui, fullwidth);
    }
  } else {
    // Mark the moved region as invalid for redrawing later
    if (rows > 0) {
      endrow = endrow - rows;
    } else {
      startrow = startrow - rows;
    }
    invalidate(tui, (int)startrow, (int)endrow, (int)startcol, (int)endcol);
  }
}

void tui_hl_attr_define(TUIData *tui, Integer id, HlAttrs attrs, HlAttrs cterm_attrs, Array info)
{
  attrs.cterm_ae_attr = cterm_attrs.cterm_ae_attr;
  attrs.cterm_fg_color = cterm_attrs.cterm_fg_color;
  attrs.cterm_bg_color = cterm_attrs.cterm_bg_color;
  kv_a(tui->attrs, (size_t)id) = attrs;
}

void tui_bell(TUIData *tui)
{
  unibi_out(tui, unibi_bell);
}

void tui_visual_bell(TUIData *tui)
{
  unibi_out(tui, unibi_flash_screen);
}

void tui_default_colors_set(TUIData *tui, Integer rgb_fg, Integer rgb_bg, Integer rgb_sp,
                            Integer cterm_fg, Integer cterm_bg)
{
  tui->clear_attrs.rgb_fg_color = (int)rgb_fg;
  tui->clear_attrs.rgb_bg_color = (int)rgb_bg;
  tui->clear_attrs.rgb_sp_color = (int)rgb_sp;
  tui->clear_attrs.cterm_fg_color = (int)cterm_fg;
  tui->clear_attrs.cterm_bg_color = (int)cterm_bg;

  tui->print_attr_id = -1;
  invalidate(tui, 0, tui->grid.height, 0, tui->grid.width);
}

void tui_flush(TUIData *tui)
{
  UGrid *grid = &tui->grid;

  size_t nrevents = loop_size(tui->loop);
  if (nrevents > TOO_MANY_EVENTS) {
    WLOG("TUI event-queue flooded (thread_events=%zu); purging", nrevents);
    // Back-pressure: UI events may accumulate much faster than the terminal
    // device can serve them. Even if SIGINT/CTRL-C is received, user must still
    // wait for the TUI event-queue to drain, and if there are ~millions of
    // events in the queue, it could take hours. Clearing the queue allows the
    // UI to recover. #1234 #5396
    loop_purge(tui->loop);
    tui_busy_stop(tui);  // avoid hidden cursor
  }

  while (kv_size(tui->invalid_regions)) {
    Rect r = kv_pop(tui->invalid_regions);
    assert(r.bot <= grid->height && r.right <= grid->width);

    for (int row = r.top; row < r.bot; row++) {
      int clear_attr = grid->cells[row][r.right - 1].attr;
      int clear_col;
      for (clear_col = r.right; clear_col > 0; clear_col--) {
        UCell *cell = &grid->cells[row][clear_col - 1];
        if (!(cell->data[0] == ' ' && cell->data[1] == NUL
              && cell->attr == clear_attr)) {
          break;
        }
      }

      UGRID_FOREACH_CELL(grid, row, r.left, clear_col, {
        print_cell_at_pos(tui, row, curcol, cell,
                          curcol < clear_col - 1 && (cell + 1)->data[0] == NUL);
      });
      if (clear_col < r.right) {
        clear_region(tui, row, row + 1, clear_col, r.right, clear_attr);
      }
    }
  }

  cursor_goto(tui, tui->row, tui->col);

  flush_buf(tui);
}

/// Dumps termcap info to the messages area, if 'verbose' >= 3.
static void show_verbose_terminfo(TUIData *tui)
{
  const unibi_term *const ut = tui->ut;
  if (!ut) {
    abort();
  }

  Array chunks = ARRAY_DICT_INIT;
  Array title = ARRAY_DICT_INIT;
  ADD(title, CSTR_TO_OBJ("\n\n--- Terminal info --- {{{\n"));
  ADD(title, CSTR_TO_OBJ("Title"));
  ADD(chunks, ARRAY_OBJ(title));
  Array info = ARRAY_DICT_INIT;
  String str = terminfo_info_msg(ut, tui->term);
  ADD(info, STRING_OBJ(str));
  ADD(chunks, ARRAY_OBJ(info));
  Array end_fold = ARRAY_DICT_INIT;
  ADD(end_fold, CSTR_TO_OBJ("}}}\n"));
  ADD(end_fold, CSTR_TO_OBJ("Title"));
  ADD(chunks, ARRAY_OBJ(end_fold));

  Array args = ARRAY_DICT_INIT;
  ADD(args, ARRAY_OBJ(chunks));
  ADD(args, BOOLEAN_OBJ(true));  // history
  Dictionary opts = ARRAY_DICT_INIT;
  PUT(opts, "verbose", BOOLEAN_OBJ(true));
  ADD(args, DICTIONARY_OBJ(opts));
  rpc_send_event(ui_client_channel_id, "nvim_echo", args);
  api_free_array(args);
}

#ifdef UNIX
static void suspend_event(void **argv)
{
  TUIData *tui = argv[0];
  ui_client_detach();
  bool enable_mouse = tui->mouse_enabled;
  tui_terminal_stop(tui);
  stream_set_blocking(tui->input.in_fd, true);   // normalize stream (#2598)

  kill(0, SIGTSTP);

  tui_terminal_start(tui);
  tui_terminal_after_startup(tui);
  if (enable_mouse) {
    tui_mouse_on(tui);
  }
  stream_set_blocking(tui->input.in_fd, false);  // libuv expects this
  ui_client_attach(tui->width, tui->height, tui->term);
}
#endif

void tui_suspend(TUIData *tui)
{
// on a non-UNIX system, this is a no-op
#ifdef UNIX
  // kill(0, SIGTSTP) won't stop the UI thread, so we must poll for SIGCONT
  // before continuing. This is done in another callback to avoid
  // loop_poll_events recursion
  multiqueue_put_event(resize_events,
                       event_create(suspend_event, 1, tui));
#endif
}

void tui_set_title(TUIData *tui, String title)
{
  if (!(unibi_get_str(tui->ut, unibi_to_status_line)
        && unibi_get_str(tui->ut, unibi_from_status_line))) {
    return;
  }
  if (title.size > 0) {
    if (!tui->title_enabled) {
      // Save title/icon to the "stack". #4063
      unibi_out_ext(tui, tui->unibi_ext.save_title);
      tui->title_enabled = true;
    }
    unibi_out(tui, unibi_to_status_line);
    out(tui, title.data, title.size);
    unibi_out(tui, unibi_from_status_line);
  } else if (tui->title_enabled) {
    // Restore title/icon from the "stack". #4063
    unibi_out_ext(tui, tui->unibi_ext.restore_title);
    tui->title_enabled = false;
  }
}

void tui_set_icon(TUIData *tui, String icon)
{
}

void tui_screenshot(TUIData *tui, String path)
{
  UGrid *grid = &tui->grid;
  flush_buf(tui);
  grid->row = 0;
  grid->col = 0;

  FILE *f = fopen(path.data, "w");
  tui->screenshot = f;
  fprintf(f, "%d,%d\n", grid->height, grid->width);
  unibi_out(tui, unibi_clear_screen);
  for (int i = 0; i < grid->height; i++) {
    cursor_goto(tui, i, 0);
    for (int j = 0; j < grid->width; j++) {
      print_cell(tui, &grid->cells[i][j]);
    }
  }
  flush_buf(tui);
  tui->screenshot = NULL;

  fclose(f);
}

void tui_option_set(TUIData *tui, String name, Object value)
{
  if (strequal(name.data, "mousemoveevent")) {
    if (tui->mouse_move_enabled != value.data.boolean) {
      if (tui->mouse_enabled) {
        tui_mouse_off(tui);
        tui->mouse_move_enabled = value.data.boolean;
        tui_mouse_on(tui);
      } else {
        tui->mouse_move_enabled = value.data.boolean;
      }
    }
  } else if (strequal(name.data, "termguicolors")) {
    tui->rgb = value.data.boolean;
    tui->print_attr_id = -1;
    invalidate(tui, 0, tui->grid.height, 0, tui->grid.width);

    if (ui_client_channel_id) {
      MAXSIZE_TEMP_ARRAY(args, 2);
      ADD_C(args, CSTR_AS_OBJ("rgb"));
      ADD_C(args, BOOLEAN_OBJ(value.data.boolean));
      rpc_send_event(ui_client_channel_id, "nvim_ui_set_option", args);
    }
  } else if (strequal(name.data, "ttimeout")) {
    tui->input.ttimeout = value.data.boolean;
  } else if (strequal(name.data, "ttimeoutlen")) {
    tui->input.ttimeoutlen = (long)value.data.integer;
  } else if (strequal(name.data, "verbose")) {
    tui->verbose = value.data.integer;
  }
}

void tui_raw_line(TUIData *tui, Integer g, Integer linerow, Integer startcol, Integer endcol,
                  Integer clearcol, Integer clearattr, LineFlags flags, const schar_T *chunk,
                  const sattr_T *attrs)
{
  UGrid *grid = &tui->grid;
  for (Integer c = startcol; c < endcol; c++) {
    memcpy(grid->cells[linerow][c].data, chunk[c - startcol], sizeof(schar_T));
    assert((size_t)attrs[c - startcol] < kv_size(tui->attrs));
    grid->cells[linerow][c].attr = attrs[c - startcol];
  }
  UGRID_FOREACH_CELL(grid, (int)linerow, (int)startcol, (int)endcol, {
    print_cell_at_pos(tui, (int)linerow, curcol, cell,
                      curcol < endcol - 1 && (cell + 1)->data[0] == NUL);
  });

  if (clearcol > endcol) {
    ugrid_clear_chunk(grid, (int)linerow, (int)endcol, (int)clearcol,
                      (sattr_T)clearattr);
    clear_region(tui, (int)linerow, (int)linerow + 1, (int)endcol, (int)clearcol,
                 (int)clearattr);
  }

  if (flags & kLineFlagWrap && tui->width == grid->width
      && linerow + 1 < grid->height) {
    // Only do line wrapping if the grid width is equal to the terminal
    // width and the line continuation is within the grid.

    if (endcol != grid->width) {
      // Print the last char of the row, if we haven't already done so.
      int size = grid->cells[linerow][grid->width - 1].data[0] == NUL ? 2 : 1;
      print_cell_at_pos(tui, (int)linerow, grid->width - size,
                        &grid->cells[linerow][grid->width - size], size == 2);
    }

    // Wrap the cursor over to the next line. The next line will be
    // printed immediately without an intervening newline.
    final_column_wrap(tui);
  }
}

static void invalidate(TUIData *tui, int top, int bot, int left, int right)
{
  Rect *intersects = NULL;

  for (size_t i = 0; i < kv_size(tui->invalid_regions); i++) {
    Rect *r = &kv_A(tui->invalid_regions, i);
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
    kv_push(tui->invalid_regions, ((Rect) { top, bot, left, right }));
  }
}

/// Tries to get the user's wanted dimensions (columns and rows) for the entire
/// application (i.e., the host terminal).
void tui_guess_size(TUIData *tui)
{
  int width = 0, height = 0;

  // 1 - try from a system call(ioctl/TIOCGWINSZ on unix)
  if (tui->out_isatty
      && !uv_tty_get_winsize(&tui->output_handle.tty, &width, &height)) {
    goto end;
  }

  // 2 - use $LINES/$COLUMNS if available
  const char *val;
  int advance;
  if ((val = os_getenv("LINES"))
      && sscanf(val, "%d%n", &height, &advance) != EOF && advance
      && (val = os_getenv("COLUMNS"))
      && sscanf(val, "%d%n", &width, &advance) != EOF && advance) {
    goto end;
  }

  // 3 - read from terminfo if available
  height = unibi_get_num(tui->ut, unibi_lines);
  width = unibi_get_num(tui->ut, unibi_columns);

  end:
  if (width <= 0 || height <= 0) {
    // use the defaults
    width = DFLT_COLS;
    height = DFLT_ROWS;
  }

  tui->width = width;
  tui->height = height;

  // Redraw on SIGWINCH event if size didn't change. #23411
  ui_client_set_size(width, height);
}

static void unibi_goto(TUIData *tui, int row, int col)
{
  UNIBI_SET_NUM_VAR(tui->params[0], row);
  UNIBI_SET_NUM_VAR(tui->params[1], col);
  unibi_out(tui, unibi_cursor_address);
}

#define UNIBI_OUT(fn) \
  do { \
    const char *str = NULL; \
    if (unibi_index >= 0) { \
      str = fn(tui->ut, (unsigned)unibi_index); \
    } \
    if (str) { \
      unibi_var_t vars[26 + 26]; \
      unibi_var_t params[9]; \
      size_t orig_pos = tui->bufpos; \
      memset(&vars, 0, sizeof(vars)); \
      tui->cork = true; \
retry: \
      memcpy(params, tui->params, sizeof(params)); \
      unibi_format(vars, vars + 26, str, params, out, tui, pad, tui); \
      if (tui->overflow) { \
        tui->bufpos = orig_pos; \
        flush_buf(tui); \
        goto retry; \
      } \
      tui->cork = false; \
    } \
  } while (0)
static void unibi_out(TUIData *tui, int unibi_index)
{
  UNIBI_OUT(unibi_get_str);
}
static void unibi_out_ext(TUIData *tui, int unibi_index)
{
  UNIBI_OUT(unibi_get_ext_str);
}
#undef UNIBI_OUT

static void out(void *ctx, const char *str, size_t len)
{
  TUIData *tui = ctx;
  size_t available = sizeof(tui->buf) - tui->bufpos;

  if (tui->cork && tui->overflow) {
    return;
  }

  if (len > available) {
    if (tui->cork) {
      // Called by unibi_format(): avoid flush_buf() halfway an escape sequence.
      tui->overflow = true;
      return;
    }
    flush_buf(tui);
  }

  memcpy(tui->buf + tui->bufpos, str, len);
  tui->bufpos += len;
}

/// Called by unibi_format() for padding instructions.
/// The following parameter descriptions are extracted from unibi_format(3) and terminfo(5).
///
/// @param ctx    the same as `ctx2` passed to unibi_format()
/// @param delay  the delay in tenths of milliseconds
/// @param scale  padding is proportional to the number of lines affected
/// @param force  padding is mandatory
static void pad(void *ctx, size_t delay, int scale FUNC_ATTR_UNUSED, int force)
{
  if (!force) {
    return;
  }

  TUIData *tui = ctx;

  if (tui->overflow) {
    return;
  }

  flush_buf(tui);
  uv_sleep((unsigned)(delay/10));
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
    const char *n = unibi_get_ext_str_name(ut, i);
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
    const char *n = unibi_get_ext_bool_name(ut, i);
    if (n && 0 == strcmp(n, name)) {
      return (int)i;
    }
  }
  return -1;
}

/// Patches the terminfo records after loading from system or built-in db.
/// Several entries in terminfo are known to be deficient or outright wrong;
/// and several terminal emulators falsely announce incorrect terminal types.
static void patch_terminfo_bugs(TUIData *tui, const char *term, const char *colorterm,
                                long vte_version, long konsolev, bool iterm_env, bool nsterm)
{
  unibi_term *ut = tui->ut;
  const char *xterm_version = os_getenv("XTERM_VERSION");
#if 0   // We don't need to identify this specifically, for now.
  bool roxterm = !!os_getenv("ROXTERM_ID");
#endif
  bool xterm = terminfo_is_term_family(term, "xterm")
               // Treat Terminal.app as generic xterm-like, for now.
               || nsterm;
  bool hterm = terminfo_is_term_family(term, "hterm");
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

  if (xterm || hterm) {
    // Termit, LXTerminal, GTKTerm2, GNOME Terminal, MATE Terminal, roxterm,
    // and EvilVTE falsely claim to be xterm and do not support important xterm
    // control sequences that we use.  In an ideal world, these would have
    // their own terminal types and terminfo entries, like PuTTY does, and not
    // claim to be xterm.  Or they would mimic xterm properly enough to be
    // treatable as xterm.

    // 2017-04 terminfo.src lacks these.  Xterm-likes have them.
    if (!hterm) {
      // hterm doesn't have a status line.
      unibi_set_if_empty(ut, unibi_to_status_line, "\x1b]0;");
      unibi_set_if_empty(ut, unibi_from_status_line, "\x07");
      // TODO(aktau): patch this in when DECSTBM is fixed (https://crbug.com/1298796)
      unibi_set_if_empty(ut, unibi_set_tb_margin, "\x1b[%i%p1%d;%p2%dr");
    }
    unibi_set_if_empty(ut, unibi_enter_italics_mode, "\x1b[3m");
    unibi_set_if_empty(ut, unibi_exit_italics_mode, "\x1b[23m");

    if (true_xterm) {
      // 2017-04 terminfo.src lacks these.  genuine Xterm has them.
      unibi_set_if_empty(ut, unibi_set_lr_margin, "\x1b[%i%p1%d;%p2%ds");
      unibi_set_if_empty(ut, unibi_set_left_margin_parm, "\x1b[%i%p1%ds");
      unibi_set_if_empty(ut, unibi_set_right_margin_parm, "\x1b[%i;%p2%ds");
    } else {
      // Fix things advertised via TERM=xterm, for non-xterm.
      //
      // TODO(aktau): stop patching this out for hterm when it gains support
      // (https://crbug.com/1175065).
      if (unibi_get_str(ut, unibi_set_lr_margin)) {
        ILOG("Disabling smglr with TERM=xterm for non-xterm.");
        unibi_set_str(ut, unibi_set_lr_margin, NULL);
      }
      if (unibi_get_str(ut, unibi_set_left_margin_parm)) {
        ILOG("Disabling smglp with TERM=xterm for non-xterm.");
        unibi_set_str(ut, unibi_set_left_margin_parm, NULL);
      }
      if (unibi_get_str(ut, unibi_set_right_margin_parm)) {
        ILOG("Disabling smgrp with TERM=xterm for non-xterm.");
        unibi_set_str(ut, unibi_set_right_margin_parm, NULL);
      }
    }

#ifdef MSWIN
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
    if (unibi_get_str(ut, unibi_set_left_margin_parm)) {
      ILOG("Disabling smglp with TERM=screen.xterm for screen.");
      unibi_set_str(ut, unibi_set_left_margin_parm, NULL);
    }
    if (unibi_get_str(ut, unibi_set_right_margin_parm)) {
      ILOG("Disabling smgrp with TERM=screen.xterm for screen.");
      unibi_set_str(ut, unibi_set_right_margin_parm, NULL);
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

  tui->unibi_ext.get_bg = (int)unibi_add_ext_str(ut, "ext.get_bg",
                                                 "\x1b]11;?\x07");

  // Query the terminal to see if it supports CSI u key encoding by writing CSI
  // ? u followed by a request for the primary device attributes (CSI c)
  // See https://sw.kovidgoyal.net/kitty/keyboard-protocol/#detection-of-support-for-this-protocol
  tui->unibi_ext.get_extkeys = (int)unibi_add_ext_str(ut, "ext.get_extkeys",
                                                      "\x1b[?u\x1b[c");

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
    tui->unibi_ext.reset_cursor_style = unibi_find_ext_str(ut, "Se");
    tui->unibi_ext.set_cursor_style = unibi_find_ext_str(ut, "Ss");
  }

  // Dickey ncurses terminfo includes Ss/Se capabilities since 2011-07-14. So
  // adding them to terminal types, that have such control sequences but lack
  // the correct terminfo entries, is a fixup, not an augmentation.
  if (-1 == tui->unibi_ext.set_cursor_style) {
    // DECSCUSR (cursor shape) is widely supported.
    // https://github.com/gnachman/iTerm2/pull/92
    if ((!bsdvt && (!konsolev || konsolev >= 180770))
        && ((xterm && !vte_version)  // anything claiming xterm compat
            // per MinTTY 0.4.3-1 release notes from 2009
            || putty
            // per https://chromium.googlesource.com/apps/libapps/+/a5fb83c190aa9d74f4a9bca233dac6be2664e9e9/hterm/doc/ControlSequences.md
            || hterm
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
      tui->unibi_ext.set_cursor_style =
        (int)unibi_add_ext_str(ut, "Ss", "\x1b[%p1%d q");
      if (-1 == tui->unibi_ext.reset_cursor_style) {
        tui->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
                                                                   "");
      }
      unibi_set_ext_str(ut, (size_t)tui->unibi_ext.reset_cursor_style,
                        "\x1b[ q");
    } else if (linuxvt) {
      // Linux uses an idiosyncratic escape code to set the cursor shape and
      // does not support DECSCUSR.
      // See http://linuxgazette.net/137/anonymous.html for more info
      tui->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
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
      if (-1 == tui->unibi_ext.reset_cursor_style) {
        tui->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
                                                                   "");
      }
      unibi_set_ext_str(ut, (size_t)tui->unibi_ext.reset_cursor_style,
                        "\x1b[?c");
    } else if (konsolev > 0 && konsolev < 180770) {
      // Konsole before version 18.07.70: set up a nonce profile. This has
      // side effects on temporary font resizing. #6798
      tui->unibi_ext.set_cursor_style = (int)unibi_add_ext_str(ut, "Ss",
                                                               TMUX_WRAP(tmux,
                                                                         "\x1b]50;CursorShape=%?"
                                                                         "%p1%{3}%<" "%t%{0}"    // block
                                                                         "%e%p1%{5}%<" "%t%{2}"  // underline
                                                                         "%e%{1}"                // everything else is bar
                                                                         "%;%d;BlinkingCursorEnabled=%?"
                                                                         "%p1%{1}%<" "%t%{1}"  // Fortunately if we exclude zero as special,
                                                                         "%e%p1%{1}%&"  // in all other cases we can treat bit #0 as a flag.
                                                                         "%;%d\x07"));
      if (-1 == tui->unibi_ext.reset_cursor_style) {
        tui->unibi_ext.reset_cursor_style = (int)unibi_add_ext_str(ut, "Se",
                                                                   "");
      }
      unibi_set_ext_str(ut, (size_t)tui->unibi_ext.reset_cursor_style,
                        "\x1b]50;\x07");
    }
  }
}

/// This adds stuff that is not in standard terminfo as extended unibilium
/// capabilities.
static void augment_terminfo(TUIData *tui, const char *term, long vte_version, long konsolev,
                             bool iterm_env, bool nsterm)
{
  unibi_term *ut = tui->ut;
  bool xterm = terminfo_is_term_family(term, "xterm")
               // Treat Terminal.app as generic xterm-like, for now.
               || nsterm;
  bool hterm = terminfo_is_term_family(term, "hterm");
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
  bool kitty = terminfo_is_term_family(term, "xterm-kitty");
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
    tui->unibi_ext.resize_screen = (int)unibi_add_ext_str(ut,
                                                          "ext.resize_screen",
                                                          "\x1b[8;%p1%d;%p2%dt");
  }
  if (putty || xterm || hterm || rxvt) {
    tui->unibi_ext.reset_scroll_region = (int)unibi_add_ext_str(ut,
                                                                "ext.reset_scroll_region",
                                                                "\x1b[r");
  }

  // terminfo describes strikethrough modes as rmxx/smxx with respect
  // to the ECMA-48 strikeout/crossed-out attributes.
  tui->unibi_ext.enter_strikethrough_mode = unibi_find_ext_str(ut, "smxx");

  // It should be pretty safe to always enable this, as terminals will ignore
  // unrecognised SGR numbers.
  tui->unibi_ext.enter_altfont_mode = (int)unibi_add_ext_str(ut, "ext.enter_altfont_mode",
                                                             "\x1b[11m");

  // Dickey ncurses terminfo does not include the setrgbf and setrgbb
  // capabilities, proposed by Rüdiger Sonderfeld on 2013-10-15.  Adding
  // them here when terminfo lacks them is an augmentation, not a fixup.
  // https://github.com/termstandard/colors

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

  tui->unibi_ext.set_rgb_foreground = unibi_find_ext_str(ut, "setrgbf");
  if (-1 == tui->unibi_ext.set_rgb_foreground) {
    if (has_colon_rgb) {
      tui->unibi_ext.set_rgb_foreground = (int)unibi_add_ext_str(ut, "setrgbf",
                                                                 "\x1b[38:2:%p1%d:%p2%d:%p3%dm");
    } else {
      tui->unibi_ext.set_rgb_foreground = (int)unibi_add_ext_str(ut, "setrgbf",
                                                                 "\x1b[38;2;%p1%d;%p2%d;%p3%dm");
    }
  }
  tui->unibi_ext.set_rgb_background = unibi_find_ext_str(ut, "setrgbb");
  if (-1 == tui->unibi_ext.set_rgb_background) {
    if (has_colon_rgb) {
      tui->unibi_ext.set_rgb_background = (int)unibi_add_ext_str(ut, "setrgbb",
                                                                 "\x1b[48:2:%p1%d:%p2%d:%p3%dm");
    } else {
      tui->unibi_ext.set_rgb_background = (int)unibi_add_ext_str(ut, "setrgbb",
                                                                 "\x1b[48;2;%p1%d;%p2%d;%p3%dm");
    }
  }

  tui->unibi_ext.set_cursor_color = unibi_find_ext_str(ut, "Cs");
  if (-1 == tui->unibi_ext.set_cursor_color) {
    if (iterm || iterm_pretending_xterm) {
      // FIXME: Bypassing tmux like this affects the cursor colour globally, in
      // all panes, which is not particularly desirable.  A better approach
      // would use a tmux control sequence and an extra if(screen) test.
      tui->unibi_ext.set_cursor_color =
        (int)unibi_add_ext_str(ut, NULL, TMUX_WRAP(tmux, "\033]Pl%p1%06x\033\\"));
    } else if ((xterm || hterm || rxvt || tmux || alacritty)
               && (vte_version == 0 || vte_version >= 3900)) {
      // Supported in urxvt, newer VTE.
      tui->unibi_ext.set_cursor_color = (int)unibi_add_ext_str(ut, "ext.set_cursor_color",
                                                               "\033]12;%p1%s\007");
    }
  }
  if (-1 != tui->unibi_ext.set_cursor_color) {
    // Some terminals supporting cursor color changing specify their Cs
    // capability to take a string parameter. Others take a numeric parameter.
    // If and only if the format string contains `%s` we assume a string
    // parameter. #20628
    const char *set_cursor_color =
      unibi_get_ext_str(ut, (unsigned)tui->unibi_ext.set_cursor_color);
    if (set_cursor_color) {
      tui->set_cursor_color_as_str = strstr(set_cursor_color, "%s") != NULL;
    }

    tui->unibi_ext.reset_cursor_color = unibi_find_ext_str(ut, "Cr");
    if (-1 == tui->unibi_ext.reset_cursor_color) {
      tui->unibi_ext.reset_cursor_color = (int)unibi_add_ext_str(ut, "ext.reset_cursor_color",
                                                                 "\x1b]112\x07");
    }
  }

  tui->unibi_ext.save_title = (int)unibi_add_ext_str(ut, "ext.save_title", "\x1b[22;0t");
  tui->unibi_ext.restore_title = (int)unibi_add_ext_str(ut, "ext.restore_title", "\x1b[23;0t");

  /// Terminals usually ignore unrecognized private modes, and there is no
  /// known ambiguity with these. So we just set them unconditionally.
  tui->unibi_ext.enable_lr_margin =
    (int)unibi_add_ext_str(ut, "ext.enable_lr_margin", "\x1b[?69h");
  tui->unibi_ext.disable_lr_margin = (int)unibi_add_ext_str(ut, "ext.disable_lr_margin",
                                                            "\x1b[?69l");
  tui->unibi_ext.enable_bracketed_paste = (int)unibi_add_ext_str(ut, "ext.enable_bpaste",
                                                                 "\x1b[?2004h");
  tui->unibi_ext.disable_bracketed_paste = (int)unibi_add_ext_str(ut, "ext.disable_bpaste",
                                                                  "\x1b[?2004l");
  // For urxvt send BOTH xterm and old urxvt sequences. #8695
  tui->unibi_ext.enable_focus_reporting = (int)unibi_add_ext_str(ut, "ext.enable_focus",
                                                                 rxvt ? "\x1b[?1004h\x1b]777;focus;on\x7" : "\x1b[?1004h");
  tui->unibi_ext.disable_focus_reporting = (int)unibi_add_ext_str(ut, "ext.disable_focus",
                                                                  rxvt ? "\x1b[?1004l\x1b]777;focus;off\x7" : "\x1b[?1004l");
  tui->unibi_ext.enable_mouse = (int)unibi_add_ext_str(ut, "ext.enable_mouse",
                                                       "\x1b[?1002h\x1b[?1006h");
  tui->unibi_ext.disable_mouse = (int)unibi_add_ext_str(ut, "ext.disable_mouse",
                                                        "\x1b[?1002l\x1b[?1006l");
  tui->unibi_ext.enable_mouse_move = (int)unibi_add_ext_str(ut, "ext.enable_mouse_move",
                                                            "\x1b[?1003h");
  tui->unibi_ext.disable_mouse_move = (int)unibi_add_ext_str(ut, "ext.disable_mouse_move",
                                                             "\x1b[?1003l");

  // Extended underline.
  // terminfo will have Smulx for this (but no support for colors yet).
  tui->unibi_ext.set_underline_style = unibi_find_ext_str(ut, "Smulx");
  if (tui->unibi_ext.set_underline_style == -1) {
    int ext_bool_Su = unibi_find_ext_bool(ut, "Su");  // used by kitty
    if (vte_version >= 5102 || konsolev >= 221170
        || (ext_bool_Su != -1
            && unibi_get_ext_bool(ut, (size_t)ext_bool_Su))) {
      tui->unibi_ext.set_underline_style = (int)unibi_add_ext_str(ut, "ext.set_underline_style",
                                                                  "\x1b[4:%p1%dm");
    }
  }
  if (tui->unibi_ext.set_underline_style != -1) {
    // Only support colon syntax. #9270
    tui->unibi_ext.set_underline_color = (int)unibi_add_ext_str(ut, "ext.set_underline_color",
                                                                "\x1b[58:2::%p1%d:%p2%d:%p3%dm");
  }

  if (!kitty && (vte_version == 0 || vte_version >= 5400)) {
    // Fallback to Xterm's modifyOtherKeys if terminal does not support CSI u
    tui->input.extkeys_type = kExtkeysXterm;
  }
}

static void flush_buf(TUIData *tui)
{
  uv_write_t req;
  uv_buf_t bufs[3];
  uv_buf_t *bufp = &bufs[0];

  // The content of the output for each condition is shown in the following
  // table. Therefore, if tui->bufpos == 0 and N/A or invis + norm, there is
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
  if (tui->bufpos <= 0
      && ((tui->is_invisible && tui->busy)
          || (tui->is_invisible && !tui->busy && tui->want_invisible)
          || (!tui->is_invisible && !tui->busy && !tui->want_invisible))) {
    return;
  }

  if (!tui->is_invisible) {
    // cursor is visible. Write a "cursor invisible" command before writing the
    // buffer.
    bufp->base = tui->invis;
    bufp->len = UV_BUF_LEN(tui->invislen);
    bufp++;
    tui->is_invisible = true;
  }

  if (tui->bufpos > 0) {
    bufp->base = tui->buf;
    bufp->len = UV_BUF_LEN(tui->bufpos);
    bufp++;
  }

  if (!tui->busy) {
    assert(tui->is_invisible);
    // not busy and the cursor is invisible. Write a "cursor normal" command
    // after writing the buffer.
    if (!tui->want_invisible) {
      bufp->base = tui->norm;
      bufp->len = UV_BUF_LEN(tui->normlen);
      bufp++;
      tui->is_invisible = false;
    }
  }

  if (tui->screenshot) {
    for (size_t i = 0; i < (size_t)(bufp - bufs); i++) {
      fwrite(bufs[i].base, bufs[i].len, 1, tui->screenshot);
    }
  } else {
    int ret = uv_write(&req, STRUCT_CAST(uv_stream_t, &tui->output_handle),
                       bufs, (unsigned)(bufp - bufs), NULL);
    if (ret) {
      ELOG("uv_write failed: %s", uv_strerror(ret));
    }
    uv_run(&tui->write_loop, UV_RUN_DEFAULT);
  }
  tui->bufpos = 0;
  tui->overflow = false;
}

/// Try to get "kbs" code from stty because "the terminfo kbs entry is extremely
/// unreliable." (Vim, Bash, and tmux also do this.)
///
/// @see tmux/tty-keys.c fe4e9470bb504357d073320f5d305b22663ee3fd
/// @see https://bugzilla.redhat.com/show_bug.cgi?id=142659
static const char *tui_get_stty_erase(int fd)
{
  static char stty_erase[2] = { 0 };
#if defined(HAVE_TERMIOS_H)
  struct termios t;
  if (tcgetattr(fd, &t) != -1) {
    stty_erase[0] = (char)t.c_cc[VERASE];
    stty_erase[1] = '\0';
    DLOG("stty/termios:erase=%s", stty_erase);
  }
#endif
  return stty_erase;
}

/// libtermkey hook to override terminfo entries.
/// @see TermInput.tk_ti_hook_fn
static const char *tui_tk_ti_getstr(const char *name, const char *value, void *data)
{
  TermInput *input = data;
  static const char *stty_erase = NULL;
  if (stty_erase == NULL) {
    stty_erase = tui_get_stty_erase(input->in_fd);
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
