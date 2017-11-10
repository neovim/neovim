// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/log.h"
#include "nvim/ui.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_getln.h"
#include "nvim/fold.h"
#include "nvim/main.h"
#include "nvim/ascii.h"
#include "nvim/misc1.h"
#include "nvim/mbyte.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/event/loop.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/os/signal.h"
#include "nvim/popupmnu.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/window.h"
#include "nvim/cursor_shape.h"
#ifdef FEAT_TUI
# include "nvim/tui/tui.h"
#else
# include "nvim/msgpack_rpc/server.h"
#endif
#include "nvim/api/private/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.c.generated.h"
#endif

#define MAX_UI_COUNT 16

static UI *uis[MAX_UI_COUNT];
static bool ui_ext[UI_WIDGETS] = { 0 };
static size_t ui_count = 0;
static int row = 0, col = 0;
static struct {
  int top, bot, left, right;
} sr;
static int current_attr_code = 0;
static bool pending_cursor_update = false;
static int busy = 0;
static int height, width;
static int old_mode_idx = -1;

#if MIN_LOG_LEVEL > DEBUG_LOG_LEVEL
# define UI_LOG(funname, ...)
#else
static size_t uilog_seen = 0;
static char uilog_last_event[1024] = { 0 };
# define UI_LOG(funname, ...) \
  do { \
    if (strequal(uilog_last_event, STR(funname))) { \
      uilog_seen++; \
    } else { \
      if (uilog_seen > 0) { \
        do_log(DEBUG_LOG_LEVEL, "UI: ", NULL, -1, true, \
               "%s (+%zu times...)", uilog_last_event, uilog_seen); \
      } \
      do_log(DEBUG_LOG_LEVEL, "UI: ", NULL, -1, true, STR(funname)); \
      uilog_seen = 0; \
      xstrlcpy(uilog_last_event, STR(funname), sizeof(uilog_last_event)); \
    } \
  } while (0)
#endif

// UI_CALL invokes a function on all registered UI instances. The functions can
// have 0-5 arguments (configurable by SELECT_NTH).
//
// See http://stackoverflow.com/a/11172679 for how it works.
#ifdef _MSC_VER
# define UI_CALL(funname, ...) \
    do { \
      flush_cursor_update(); \
      UI_LOG(funname, 0); \
      for (size_t i = 0; i < ui_count; i++) { \
        UI *ui = uis[i]; \
        UI_CALL_MORE(funname, __VA_ARGS__); \
      } \
    } while (0)
#else
# define UI_CALL(...) \
    do { \
      flush_cursor_update(); \
      UI_LOG(__VA_ARGS__, 0); \
      for (size_t i = 0; i < ui_count; i++) { \
        UI *ui = uis[i]; \
        UI_CALL_HELPER(CNT(__VA_ARGS__), __VA_ARGS__); \
      } \
    } while (0)
#endif
#define CNT(...) SELECT_NTH(__VA_ARGS__, MORE, MORE, MORE, MORE, ZERO, ignore)
#define SELECT_NTH(a1, a2, a3, a4, a5, a6, ...) a6
#define UI_CALL_HELPER(c, ...) UI_CALL_HELPER2(c, __VA_ARGS__)
// Resolves to UI_CALL_MORE or UI_CALL_ZERO.
#define UI_CALL_HELPER2(c, ...) UI_CALL_##c(__VA_ARGS__)
#define UI_CALL_MORE(method, ...) if (ui->method) ui->method(ui, __VA_ARGS__)
#define UI_CALL_ZERO(method) if (ui->method) ui->method(ui)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_events_call.generated.h"
#endif

void ui_builtin_start(void)
{
#ifdef FEAT_TUI
  tui_start();
#else
  fprintf(stderr, "Nvim headless-mode started.\n");
  size_t len;
  char **addrs = server_address_list(&len);
  if (addrs != NULL) {
    fprintf(stderr, "Listening on:\n");
    for (size_t i = 0; i < len; i++) {
      fprintf(stderr, "\t%s\n", addrs[i]);
    }
    xfree(addrs);
  }
  fprintf(stderr, "Press CTRL+C to exit.\n");
#endif
}

void ui_builtin_stop(void)
{
  UI_CALL(stop);
}

bool ui_rgb_attached(void)
{
  for (size_t i = 0; i < ui_count; i++) {
    if (uis[i]->rgb) {
      return true;
    }
  }
  return false;
}

bool ui_active(void)
{
  return ui_count != 0;
}

void ui_event(char *name, Array args)
{
  bool args_consumed = false;
  UI_CALL(event, name, args, &args_consumed);
  if (!args_consumed) {
    api_free_array(args);
  }
}


/// Converts an attrentry_T into an HlAttrs
///
/// @param[in] aep data to convert
/// @param use_rgb use 'gui*' settings if true, else resorts to 'cterm*'
HlAttrs attrentry2hlattrs(const attrentry_T *aep, bool use_rgb)
{
  assert(aep);

  HlAttrs attrs = HLATTRS_INIT;
  int mask = 0;

  mask = use_rgb ? aep->rgb_ae_attr : aep->cterm_ae_attr;

  attrs.bold = mask & HL_BOLD;
  attrs.underline = mask & HL_UNDERLINE;
  attrs.undercurl = mask & HL_UNDERCURL;
  attrs.italic = mask & HL_ITALIC;
  attrs.reverse = mask & (HL_INVERSE | HL_STANDOUT);

  if (use_rgb) {
    if (aep->rgb_fg_color != -1) {
      attrs.foreground = aep->rgb_fg_color;
    }

    if (aep->rgb_bg_color != -1) {
      attrs.background = aep->rgb_bg_color;
    }

    if (aep->rgb_sp_color != -1) {
      attrs.special = aep->rgb_sp_color;
    }
  } else {
    if (cterm_normal_fg_color != aep->cterm_fg_color) {
      attrs.foreground = aep->cterm_fg_color - 1;
    }

    if (cterm_normal_bg_color != aep->cterm_bg_color) {
        attrs.background = aep->cterm_bg_color - 1;
    }
  }

  return attrs;
}

Dictionary hlattrs2dict(HlAttrs attrs)
{
  Dictionary hl = ARRAY_DICT_INIT;

  if (attrs.bold) {
    PUT(hl, "bold", BOOLEAN_OBJ(true));
  }

  if (attrs.underline) {
    PUT(hl, "underline", BOOLEAN_OBJ(true));
  }

  if (attrs.undercurl) {
    PUT(hl, "undercurl", BOOLEAN_OBJ(true));
  }

  if (attrs.italic) {
    PUT(hl, "italic", BOOLEAN_OBJ(true));
  }

  if (attrs.reverse) {
    PUT(hl, "reverse", BOOLEAN_OBJ(true));
  }

  if (attrs.foreground != -1) {
    PUT(hl, "foreground", INTEGER_OBJ(attrs.foreground));
  }

  if (attrs.background != -1) {
    PUT(hl, "background", INTEGER_OBJ(attrs.background));
  }

  if (attrs.special != -1) {
    PUT(hl, "special", INTEGER_OBJ(attrs.special));
  }

  return hl;
}

void ui_refresh(void)
{
  if (!ui_active()) {
    return;
  }

  if (updating_screen) {
    ui_schedule_refresh();
    return;
  }

  int width = INT_MAX, height = INT_MAX;
  bool ext_widgets[UI_WIDGETS];
  for (UIWidget i = 0; (int)i < UI_WIDGETS; i++) {
    ext_widgets[i] = true;
  }

  for (size_t i = 0; i < ui_count; i++) {
    UI *ui = uis[i];
    width = MIN(ui->width, width);
    height = MIN(ui->height, height);
    for (UIWidget i = 0; (int)i < UI_WIDGETS; i++) {
      ext_widgets[i] &= ui->ui_ext[i];
    }
  }

  row = col = 0;

  int save_p_lz = p_lz;
  p_lz = false;  // convince redrawing() to return true ...
  screen_resize(width, height);
  p_lz = save_p_lz;

  for (UIWidget i = 0; (int)i < UI_WIDGETS; i++) {
    ui_set_external(i, ext_widgets[i]);
  }
  ui_mode_info_set();
  old_mode_idx = -1;
  ui_cursor_shape();
}

static void ui_refresh_event(void **argv)
{
  ui_refresh();
}

void ui_schedule_refresh(void)
{
  loop_schedule(&main_loop, event_create(ui_refresh_event, 0));
}

void ui_resize(int new_width, int new_height)
{
  width = new_width;
  height = new_height;

  UI_CALL(update_fg, (ui->rgb ? normal_fg : cterm_normal_fg_color - 1));
  UI_CALL(update_bg, (ui->rgb ? normal_bg : cterm_normal_bg_color - 1));
  UI_CALL(update_sp, (ui->rgb ? normal_sp : -1));

  sr.top = 0;
  sr.bot = height - 1;
  sr.left = 0;
  sr.right = width - 1;
  ui_call_resize(width, height);
}

void ui_busy_start(void)
{
  if (!(busy++)) {
    ui_call_busy_start();
  }
}

void ui_busy_stop(void)
{
  if (!(--busy)) {
    ui_call_busy_stop();
  }
}

void ui_attach_impl(UI *ui)
{
  if (ui_count == MAX_UI_COUNT) {
    abort();
  }

  uis[ui_count++] = ui;
  ui_refresh();
}

void ui_detach_impl(UI *ui)
{
  size_t shift_index = MAX_UI_COUNT;

  // Find the index that will be removed
  for (size_t i = 0; i < ui_count; i++) {
    if (uis[i] == ui) {
      shift_index = i;
      break;
    }
  }

  if (shift_index == MAX_UI_COUNT) {
    abort();
  }

  // Shift UIs at "shift_index"
  while (shift_index < ui_count - 1) {
    uis[shift_index] = uis[shift_index + 1];
    shift_index++;
  }

  if (--ui_count
      // During teardown/exit the loop was already destroyed, cannot schedule.
      // https://github.com/neovim/neovim/pull/5119#issuecomment-258667046
      && !exiting) {
    ui_schedule_refresh();
  }
}

// Set scrolling region for window 'wp'.
// The region starts 'off' lines from the start of the window.
// Also set the vertical scroll region for a vertically split window.  Always
// the full width of the window, excluding the vertical separator.
void ui_set_scroll_region(win_T *wp, int off)
{
  sr.top = wp->w_winrow + off;
  sr.bot = wp->w_winrow + wp->w_height - 1;

  if (wp->w_width != Columns) {
    sr.left = wp->w_wincol;
    sr.right = wp->w_wincol + wp->w_width - 1;
  }

  ui_call_set_scroll_region(sr.top, sr.bot, sr.left, sr.right);
}

// Reset scrolling region to the whole screen.
void ui_reset_scroll_region(void)
{
  sr.top = 0;
  sr.bot = (int)Rows - 1;
  sr.left = 0;
  sr.right = (int)Columns - 1;
  ui_call_set_scroll_region(sr.top, sr.bot, sr.left, sr.right);
}

void ui_start_highlight(int attr_code)
{
  current_attr_code = attr_code;

  if (!ui_count) {
    return;
  }

  set_highlight_args(current_attr_code);
}

void ui_stop_highlight(void)
{
  current_attr_code = HL_NORMAL;

  if (!ui_count) {
    return;
  }

  set_highlight_args(current_attr_code);
}

void ui_puts(uint8_t *str)
{
  uint8_t *p = str;
  uint8_t c;

  while ((c = *p)) {
    if (c < 0x20) {
      abort();
    }

    size_t clen = (size_t)mb_ptr2len(p);
    ui_call_put((String){ .data = (char *)p, .size = clen });
    col++;
    if (mb_ptr2cells(p) > 1) {
      // double cell character, blank the next cell
      ui_call_put((String)STRING_INIT);
      col++;
    }
    if (utf_ambiguous_width(utf_ptr2char(p))) {
      pending_cursor_update = true;
    }
    if (col >= width) {
      ui_linefeed();
    }
    p += clen;
  }
}

void ui_putc(uint8_t c)
{
  uint8_t buf[2] = {c, 0};
  ui_puts(buf);
}

void ui_cursor_goto(int new_row, int new_col)
{
  if (new_row == row && new_col == col) {
    return;
  }
  row = new_row;
  col = new_col;
  pending_cursor_update = true;
}

void ui_mode_info_set(void)
{
  Array style = mode_style_array();
  bool enabled = (*p_guicursor != NUL);
  ui_call_mode_info_set(enabled, style);
  api_free_array(style);
}

int ui_current_row(void)
{
  return row;
}

int ui_current_col(void)
{
  return col;
}

void ui_flush(void)
{
  cmdline_ui_flush();
  ui_call_flush();
}

static void set_highlight_args(int attr_code)
{
  HlAttrs rgb_attrs = HLATTRS_INIT;
  HlAttrs cterm_attrs = rgb_attrs;

  if (attr_code == HL_NORMAL) {
    goto end;
  }
  attrentry_T *aep = syn_cterm_attr2entry(attr_code);

  if (!aep) {
    goto end;
  }

  rgb_attrs = attrentry2hlattrs(aep, true);
  cterm_attrs = attrentry2hlattrs(aep, false);

end:
  UI_CALL(highlight_set, (ui->rgb ? rgb_attrs : cterm_attrs));
}

void ui_linefeed(void)
{
  int new_col = 0;
  int new_row = row;
  if (new_row < sr.bot) {
    new_row++;
  } else {
    ui_call_scroll(1);
  }
  ui_cursor_goto(new_row, new_col);
}

static void flush_cursor_update(void)
{
  if (pending_cursor_update) {
    pending_cursor_update = false;
    ui_call_cursor_goto(row, col);
  }
}

/// Check if current mode has changed.
/// May update the shape of the cursor.
void ui_cursor_shape(void)
{
  if (!full_screen) {
    return;
  }
  int mode_idx = cursor_get_mode_idx();

  if (old_mode_idx != mode_idx) {
    old_mode_idx = mode_idx;
    char *full_name = shape_table[mode_idx].full_name;
    ui_call_mode_change(cstr_as_string(full_name), mode_idx);
  }
  conceal_check_cursur_line();
}

/// Returns true if `widget` is externalized.
bool ui_is_external(UIWidget widget)
{
  return ui_ext[widget];
}

/// Sets `widget` as "external".
/// Such widgets are not drawn by Nvim; external UIs are expected to handle
/// higher-level UI events and present the data.
void ui_set_external(UIWidget widget, bool external)
{
  ui_ext[widget] = external;
}
