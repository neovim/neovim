#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/ex_cmds2.h"
#include "nvim/fold.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/ascii.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
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
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/window.h"
#ifdef FEAT_TUI
# include "nvim/tui/tui.h"
#else
# include "nvim/msgpack_rpc/server.h"
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.c.generated.h"
#endif

#define MAX_UI_COUNT 16

static UI *uis[MAX_UI_COUNT];
static size_t ui_count = 0;
static int row = 0, col = 0;
static struct {
  int top, bot, left, right;
} sr;
static int current_attr_code = 0;
static bool pending_cursor_update = false;
static int busy = 0;
static int height, width;

// This set of macros allow us to use UI_CALL to invoke any function on
// registered UI instances. The functions can have 0-5 arguments(configurable
// by SELECT_NTH)
//
// See http://stackoverflow.com/a/11172679 for a better explanation of how it
// works.
#ifdef _MSC_VER
# define UI_CALL(funname, ...) \
    do { \
      flush_cursor_update(); \
      for (size_t i = 0; i < ui_count; i++) { \
        UI *ui = uis[i]; \
        UI_CALL_MORE(funname, __VA_ARGS__); \
      } \
    } while (0)
#else
# define UI_CALL(...) \
    do { \
      flush_cursor_update(); \
      for (size_t i = 0; i < ui_count; i++) { \
        UI *ui = uis[i]; \
        UI_CALL_HELPER(CNT(__VA_ARGS__), __VA_ARGS__); \
      } \
    } while (0)
#endif
#define CNT(...) SELECT_NTH(__VA_ARGS__, MORE, MORE, MORE, MORE, ZERO, ignore)
#define SELECT_NTH(a1, a2, a3, a4, a5, a6, ...) a6
#define UI_CALL_HELPER(c, ...) UI_CALL_HELPER2(c, __VA_ARGS__)
#define UI_CALL_HELPER2(c, ...) UI_CALL_##c(__VA_ARGS__)
#define UI_CALL_MORE(method, ...) if (ui->method) ui->method(ui, __VA_ARGS__)
#define UI_CALL_ZERO(method) if (ui->method) ui->method(ui)

void ui_builtin_start(void)
{
#ifdef FEAT_TUI
  tui_start();
#else
  fprintf(stderr, "Neovim was built without a Terminal UI," \
          "press Ctrl+C to exit\n");

  size_t len;
  char **addrs = server_address_list(&len);
  if (addrs != NULL) {
    fprintf(stderr, "currently listening on the following address(es)\n");
    for (size_t i = 0; i < len; i++) {
      fprintf(stderr, "\t%s\n", addrs[i]);
    }
    xfree(addrs);
  }
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

void ui_suspend(void)
{
  UI_CALL(suspend);
  UI_CALL(flush);
}

void ui_set_title(char *title)
{
  UI_CALL(set_title, title);
  UI_CALL(flush);
}

void ui_set_icon(char *icon)
{
  UI_CALL(set_icon, icon);
  UI_CALL(flush);
}

// May update the shape of the cursor.
void ui_cursor_shape(void)
{
  ui_mode_change();
}

void ui_refresh(void)
{
  if (!ui_active()) {
    return;
  }

  int width = INT_MAX, height = INT_MAX;

  for (size_t i = 0; i < ui_count; i++) {
    UI *ui = uis[i];
    width = ui->width < width ? ui->width : width;
    height = ui->height < height ? ui->height : height;
  }

  row = col = 0;
  screen_resize(width, height);
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
  UI_CALL(resize, width, height);
}

void ui_busy_start(void)
{
  if (!(busy++)) {
    UI_CALL(busy_start);
  }
}

void ui_busy_stop(void)
{
  if (!(--busy)) {
    UI_CALL(busy_stop);
  }
}

void ui_mouse_on(void)
{
  UI_CALL(mouse_on);
}

void ui_mouse_off(void)
{
  UI_CALL(mouse_off);
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

  if (--ui_count) {
    ui_refresh();
  }
}

void ui_clear(void)
{
  UI_CALL(clear);
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

  UI_CALL(set_scroll_region, sr.top, sr.bot, sr.left, sr.right);
}

// Reset scrolling region to the whole screen.
void ui_reset_scroll_region(void)
{
  sr.top = 0;
  sr.bot = (int)Rows - 1;
  sr.left = 0;
  sr.right = (int)Columns - 1;
  UI_CALL(set_scroll_region, sr.top, sr.bot, sr.left, sr.right);
}

void ui_append_lines(int count)
{
  UI_CALL(scroll, -count);
}

void ui_delete_lines(int count)
{
  UI_CALL(scroll, count);
}

void ui_eol_clear(void)
{
  UI_CALL(eol_clear);
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

void ui_visual_bell(void)
{
  UI_CALL(visual_bell);
}

void ui_puts(uint8_t *str)
{
  uint8_t *ptr = str;
  uint8_t c;

  while ((c = *ptr)) {
    if (c < 0x20) {
      parse_control_character(c);
      ptr++;
    } else {
      send_output(&ptr);
    }
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

void ui_update_menu(void)
{
    UI_CALL(update_menu);
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
  UI_CALL(flush);
}

static void send_output(uint8_t **ptr)
{
  uint8_t *p = *ptr;

  while (*p >= 0x20) {
    size_t clen = (size_t)mb_ptr2len(p);
    UI_CALL(put, p, (size_t)clen);
    col++;
    if (mb_ptr2cells(p) > 1) {
      // double cell character, blank the next cell
      UI_CALL(put, NULL, 0);
      col++;
    }
    if (col >= width) {
      ui_linefeed();
    }
    p += clen;
  }

  *ptr = p;
}

static void parse_control_character(uint8_t c)
{
  if (c == '\n') {
    ui_linefeed();
  } else if (c == '\r') {
    ui_carriage_return();
  } else if (c == '\b') {
    ui_cursor_left();
  } else if (c == Ctrl_L) {
    ui_cursor_right();
  } else if (c == Ctrl_G) {
    UI_CALL(bell);
  }
}

static void set_highlight_args(int attr_code)
{
  HlAttrs rgb_attrs = { false, false, false, false, false, -1, -1, -1 };
  HlAttrs cterm_attrs = rgb_attrs;

  if (attr_code == HL_NORMAL) {
    goto end;
  }

  int rgb_mask = 0;
  int cterm_mask = 0;
  attrentry_T *aep = syn_cterm_attr2entry(attr_code);

  if (!aep) {
    goto end;
  }

  rgb_mask = aep->rgb_ae_attr;
  cterm_mask = aep->cterm_ae_attr;

  rgb_attrs.bold = rgb_mask & HL_BOLD;
  rgb_attrs.underline = rgb_mask & HL_UNDERLINE;
  rgb_attrs.undercurl = rgb_mask & HL_UNDERCURL;
  rgb_attrs.italic = rgb_mask & HL_ITALIC;
  rgb_attrs.reverse = rgb_mask & (HL_INVERSE | HL_STANDOUT);
  cterm_attrs.bold = cterm_mask & HL_BOLD;
  cterm_attrs.underline = cterm_mask & HL_UNDERLINE;
  cterm_attrs.undercurl = cterm_mask & HL_UNDERCURL;
  cterm_attrs.italic = cterm_mask & HL_ITALIC;
  cterm_attrs.reverse = cterm_mask & (HL_INVERSE | HL_STANDOUT);

  if (aep->rgb_fg_color != normal_fg) {
    rgb_attrs.foreground = aep->rgb_fg_color;
  }

  if (aep->rgb_bg_color != normal_bg) {
    rgb_attrs.background = aep->rgb_bg_color;
  }

  if (aep->rgb_sp_color != normal_sp) {
    rgb_attrs.special = aep->rgb_sp_color;
  }

  if (cterm_normal_fg_color != aep->cterm_fg_color) {
    cterm_attrs.foreground = aep->cterm_fg_color - 1;
  }

  if (cterm_normal_bg_color != aep->cterm_bg_color) {
    cterm_attrs.background = aep->cterm_bg_color - 1;
  }

end:
  UI_CALL(highlight_set, (ui->rgb ? rgb_attrs : cterm_attrs));
}

static void ui_linefeed(void)
{
  int new_col = 0;
  int new_row = row;
  if (new_row < sr.bot) {
    new_row++;
  } else {
    UI_CALL(scroll, 1);
  }
  ui_cursor_goto(new_row, new_col);
}

static void ui_carriage_return(void)
{
  int new_col = 0;
  ui_cursor_goto(row, new_col);
}

static void ui_cursor_left(void)
{
  int new_col = col - 1;
  assert(new_col >= 0);
  ui_cursor_goto(row, new_col);
}

static void ui_cursor_right(void)
{
  int new_col = col + 1;
  assert(new_col < width);
  ui_cursor_goto(row, new_col);
}

static void flush_cursor_update(void)
{
  if (pending_cursor_update) {
    pending_cursor_update = false;
    UI_CALL(cursor_goto, row, col);
  }
}

// Notify that the current mode has changed. Can be used to change cursor
// shape, for example.
static void ui_mode_change(void)
{
  int mode;
  if (!full_screen) {
    return;
  }
  /* Get a simple UI mode out of State. */
  if ((State & REPLACE) == REPLACE)
    mode = REPLACE;
  else if (State & INSERT)
    mode = INSERT;
  else
    mode = NORMAL;
  UI_CALL(mode_change, mode);
  conceal_check_cursur_line();
}
