/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * ui.c: functions that handle the user interface.
 * 1. Keyboard input stuff, and a bit of windowing stuff.  These are called
 *    before the machine specific stuff (mch_*) so that we can call the GUI
 *    stuff instead if the GUI is running.
 * 2. Clipboard stuff.
 * 3. Input buffer stuff.
 */

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

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
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/os/signal.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/term.h"
#include "nvim/window.h"
#include "nvim/tui/tui.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.c.generated.h"
#endif

#define MAX_UI_COUNT 16

static UI *uis[MAX_UI_COUNT];
static size_t ui_count = 0;
static int row, col;
static struct {
  int top, bot, left, right;
} sr;
static int current_attr_code = 0;
static bool cursor_enabled = true, pending_cursor_update = false;
static int height, width;

// This set of macros allow us to use UI_CALL to invoke any function on
// registered UI instances. The functions can have 0-5 arguments(configurable
// by SELECT_NTH)
//
// See http://stackoverflow.com/a/11172679 for a better explanation of how it
// works.
#define UI_CALL(...)                                              \
  do {                                                            \
    flush_cursor_update();                                        \
    for (size_t i = 0; i < ui_count; i++) {                       \
      UI *ui = uis[i];                                            \
      UI_CALL_HELPER(CNT(__VA_ARGS__), __VA_ARGS__);              \
    }                                                             \
  } while (0)
#define CNT(...) SELECT_NTH(__VA_ARGS__, MORE, MORE, MORE, MORE, ZERO, ignore)
#define SELECT_NTH(a1, a2, a3, a4, a5, a6, ...) a6
#define UI_CALL_HELPER(c, ...) UI_CALL_HELPER2(c, __VA_ARGS__)
#define UI_CALL_HELPER2(c, ...) UI_CALL_##c(__VA_ARGS__)
#define UI_CALL_MORE(method, ...) if (ui->method) ui->method(ui, __VA_ARGS__)
#define UI_CALL_ZERO(method) if (ui->method) ui->method(ui)

void ui_builtin_start(void)
{
  tui_start();
}

void ui_builtin_stop(void)
{
  UI_CALL(stop);
}

void ui_write(uint8_t *s, int len)
{
  if (silent_mode && !p_verbose) {
    // Don't output anything in silent mode ("ex -s") unless 'verbose' set
    return;
  }

  parse_abstract_ui_codes(s, len);
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

/*
 * If the machine has job control, use it to suspend the program,
 * otherwise fake it by starting a new shell.
 * When running the GUI iconify the window.
 */
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

/*
 * May update the shape of the cursor.
 */
void ui_cursor_shape(void)
{
  ui_change_mode();
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

  screen_resize(width, height);
}

void ui_resize(int new_width, int new_height)
{
  width = new_width;
  height = new_height;

  UI_CALL(update_fg, (ui->rgb ? normal_fg : cterm_normal_fg_color - 1));
  UI_CALL(update_bg, (ui->rgb ? normal_bg : cterm_normal_bg_color - 1));

  sr.top = 0;
  sr.bot = height - 1;
  sr.left = 0;
  sr.right = width - 1;
  UI_CALL(resize, width, height);
}

void ui_cursor_on(void)
{
  if (!cursor_enabled) {
    UI_CALL(cursor_on);
    cursor_enabled = true;
  }
}

void ui_cursor_off(void)
{
  if (full_screen) {
    if (cursor_enabled) {
      UI_CALL(cursor_off);
    }
    cursor_enabled = false;
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

// Notify that the current mode has changed. Can be used to change cursor
// shape, for example.
void ui_change_mode(void)
{
  static int showing_insert_mode = MAYBE;

  if (!full_screen)
    return;

  if (State & INSERT) {
    if (showing_insert_mode != TRUE) {
      UI_CALL(insert_mode);
    }
    showing_insert_mode = TRUE;
  } else {
    if (showing_insert_mode != FALSE) {
      UI_CALL(normal_mode);
    }
    showing_insert_mode = FALSE;
  }
  conceal_check_cursur_line();
}

void ui_attach(UI *ui)
{
  if (ui_count == MAX_UI_COUNT) {
    abort();
  }

  uis[ui_count++] = ui;
  ui_refresh();
}

void ui_detach(UI *ui)
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

  ui_count--;

  if (ui_count) {
    ui_refresh();
  }
}

static void highlight_start(int attr_code)
{
  current_attr_code = attr_code;

  if (!ui_count) {
    return;
  }

  set_highlight_args(current_attr_code);
}

static void highlight_stop(int mask)
{
  current_attr_code = HL_NORMAL;

  if (!ui_count) {
    return;
  }

  set_highlight_args(current_attr_code);
}

static void set_highlight_args(int attr_code)
{
  HlAttrs rgb_attrs = { false, false, false, false, false, -1, -1 };
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

  if (cterm_normal_fg_color != aep->cterm_fg_color) {
    cterm_attrs.foreground = aep->cterm_fg_color - 1;
  }

  if (cterm_normal_bg_color != aep->cterm_bg_color) {
    cterm_attrs.background = aep->cterm_bg_color - 1;
  }

end:
  UI_CALL(highlight_set, (ui->rgb ? rgb_attrs : cterm_attrs));
}

static void parse_abstract_ui_codes(uint8_t *ptr, int len)
{
  if (!ui_active()) {
    return;
  }

  int arg1 = 0, arg2 = 0;
  uint8_t *end = ptr + len, *p, c;
  bool update_cursor = false;

  while (ptr < end) {
    if (ptr < end - 1 && ptr[0] == ESC && ptr[1] == '|') {
      p = ptr + 2;
      assert(p != end);

      if (VIM_ISDIGIT(*p)) {
        arg1 = getdigits_int(&p);
        if (p >= end) {
          break;
        }

        if (*p == ';') {
          p++;
          arg2 = getdigits_int(&p);
          if (p >= end)
            break;
        }
      }

      switch (*p) {
        case 'C':
          UI_CALL(clear);
          break;
        case 'M':
          ui_cursor_goto(arg1, arg2);
          break;
        case 's':
          update_cursor = true;
          break;
        case 'R':
          if (arg1 < arg2) {
            sr.top = arg1;
            sr.bot = arg2;
            UI_CALL(set_scroll_region, sr.top, sr.bot, sr.left, sr.right);
          } else {
            sr.top = arg2;
            sr.bot = arg1;
            UI_CALL(set_scroll_region, sr.top, sr.bot, sr.left, sr.right);
          }
          break;
        case 'V':
          if (arg1 < arg2) {
            sr.left = arg1;
            sr.right = arg2;
            UI_CALL(set_scroll_region, sr.top, sr.bot, sr.left, sr.right);
          } else {
            sr.left = arg2;
            sr.right = arg1;
            UI_CALL(set_scroll_region, sr.top, sr.bot, sr.left, sr.right);
          }
          break;
        case 'd':
          UI_CALL(scroll, 1);
          break;
        case 'D':
          UI_CALL(scroll, arg1);
          break;
        case 'i':
          UI_CALL(scroll, -1);
          break;
        case 'I':
          UI_CALL(scroll, -arg1);
          break;
        case '$':
          UI_CALL(eol_clear);
          break;
        case 'h':
          highlight_start(arg1);
          break;
        case 'H':
          highlight_stop(arg1);
          break;
        case 'f':
          UI_CALL(visual_bell);
          break;
        default:
          // Skip the ESC
          p = ptr + 1;
          break;
      }
      ptr = ++p;
    } else if ((c = *ptr) < 0x20) {
      // Ctrl character
      if (c == '\n') {
        ui_linefeed();
      } else if (c == '\r') {
        ui_carriage_return();
      } else if (c == '\b') {
        ui_cursor_left();
      } else if (c == Ctrl_L) {  // cursor right
        ui_cursor_right();
      } else if (c == Ctrl_G) {
        UI_CALL(bell);
      }
      ptr++;
    } else {
      p = ptr;
      while (p < end && (*p >= 0x20)) {
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
      ptr = p;
    }
  }

  if (update_cursor) {
    ui_cursor_shape();
  }

  UI_CALL(flush);
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

static void ui_cursor_goto(int new_row, int new_col)
{
  if (new_row == row && new_col == col) {
    return;
  }
  row = new_row;
  col = new_col;
  pending_cursor_update = true;
}

static void flush_cursor_update(void)
{
  if (pending_cursor_update) {
    pending_cursor_update = false;
    UI_CALL(cursor_goto, row, col);
  }
}
