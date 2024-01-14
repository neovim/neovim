#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/macros.h"
#include "nvim/memory.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/optionstr.h"
#include "nvim/pos.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/vim.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "winfloat.c.generated.h"
#endif

/// Create a new float.
///
/// @param wp      if NULL, allocate a new window, otherwise turn existing window into a float.
///                It must then already belong to the current tabpage!
/// @param last    make the window the last one in the window list.
///                Only used when allocating the autocommand window.
/// @param config  must already have been validated!
win_T *win_new_float(win_T *wp, bool last, FloatConfig fconfig, Error *err)
{
  if (wp == NULL) {
    wp = win_alloc(last ? lastwin : lastwin_nofloating(), false);
    win_init(wp, curwin, 0);
  } else {
    assert(!last);
    assert(!wp->w_floating);
    if (firstwin == wp && lastwin_nofloating() == wp) {
      // last non-float
      api_set_error(err, kErrorTypeException,
                    "Cannot change last window into float");
      return NULL;
    } else if (!win_valid(wp)) {
      api_set_error(err, kErrorTypeException,
                    "Cannot change window from different tabpage into float");
      return NULL;
    }
    int dir;
    winframe_remove(wp, &dir, NULL);
    XFREE_CLEAR(wp->w_frame);
    (void)win_comp_pos();  // recompute window positions
    win_remove(wp, NULL);
    win_append(lastwin_nofloating(), wp);
  }
  wp->w_floating = true;
  wp->w_status_height = 0;
  wp->w_winbar_height = 0;
  wp->w_hsep_height = 0;
  wp->w_vsep_width = 0;

  win_config_float(wp, fconfig);
  win_set_inner_size(wp, true);
  wp->w_pos_changed = true;
  redraw_later(wp, UPD_VALID);
  return wp;
}

void win_set_minimal_style(win_T *wp)
{
  wp->w_p_nu = false;
  wp->w_p_rnu = false;
  wp->w_p_cul = false;
  wp->w_p_cuc = false;
  wp->w_p_spell = false;
  wp->w_p_list = false;

  // Hide EOB region: use " " fillchar and cleared highlighting
  if (wp->w_p_fcs_chars.eob != ' ') {
    char *old = wp->w_p_fcs;
    wp->w_p_fcs = ((*old == NUL)
                   ? xstrdup("eob: ")
                   : concat_str(old, ",eob: "));
    free_string_option(old);
  }

  // TODO(bfredl): this could use a highlight namespace directly,
  // and avoid peculiarities around window options
  char *old = wp->w_p_winhl;
  wp->w_p_winhl = ((*old == NUL)
                   ? xstrdup("EndOfBuffer:")
                   : concat_str(old, ",EndOfBuffer:"));
  free_string_option(old);
  parse_winhl_opt(wp);

  // signcolumn: use 'auto'
  if (wp->w_p_scl[0] != 'a' || strlen(wp->w_p_scl) >= 8) {
    free_string_option(wp->w_p_scl);
    wp->w_p_scl = xstrdup("auto");
  }

  // foldcolumn: use '0'
  if (wp->w_p_fdc[0] != '0') {
    free_string_option(wp->w_p_fdc);
    wp->w_p_fdc = xstrdup("0");
  }

  // colorcolumn: cleared
  if (wp->w_p_cc != NULL && *wp->w_p_cc != NUL) {
    free_string_option(wp->w_p_cc);
    wp->w_p_cc = xstrdup("");
  }

  // statuscolumn: cleared
  if (wp->w_p_stc != NULL && *wp->w_p_stc != NUL) {
    free_string_option(wp->w_p_stc);
    wp->w_p_stc = xstrdup("");
  }
}

int win_border_height(win_T *wp)
{
  return wp->w_border_adj[0] + wp->w_border_adj[2];
}

int win_border_width(win_T *wp)
{
  return wp->w_border_adj[1] + wp->w_border_adj[3];
}

void win_config_float(win_T *wp, FloatConfig fconfig)
{
  wp->w_width = MAX(fconfig.width, 1);
  wp->w_height = MAX(fconfig.height, 1);

  if (fconfig.relative == kFloatRelativeCursor) {
    fconfig.relative = kFloatRelativeWindow;
    fconfig.row += curwin->w_wrow;
    fconfig.col += curwin->w_wcol;
    fconfig.window = curwin->handle;
  } else if (fconfig.relative == kFloatRelativeMouse) {
    int row = mouse_row, col = mouse_col, grid = mouse_grid;
    win_T *mouse_win = mouse_find_win(&grid, &row, &col);
    if (mouse_win != NULL) {
      fconfig.relative = kFloatRelativeWindow;
      fconfig.row += row;
      fconfig.col += col;
      fconfig.window = mouse_win->handle;
    }
  }

  bool change_external = fconfig.external != wp->w_float_config.external;
  bool change_border = (fconfig.border != wp->w_float_config.border
                        || memcmp(fconfig.border_hl_ids,
                                  wp->w_float_config.border_hl_ids,
                                  sizeof fconfig.border_hl_ids) != 0);

  wp->w_float_config = fconfig;

  bool has_border = wp->w_floating && wp->w_float_config.border;
  for (int i = 0; i < 4; i++) {
    int new_adj = has_border && wp->w_float_config.border_chars[2 * i + 1][0];
    if (new_adj != wp->w_border_adj[i]) {
      change_border = true;
      wp->w_border_adj[i] = new_adj;
    }
  }

  if (!ui_has(kUIMultigrid)) {
    wp->w_height = MIN(wp->w_height, Rows - win_border_height(wp));
    wp->w_width = MIN(wp->w_width, Columns - win_border_width(wp));
  }

  win_set_inner_size(wp, true);
  must_redraw = MAX(must_redraw, UPD_VALID);

  wp->w_pos_changed = true;
  if (change_external || change_border) {
    wp->w_hl_needs_update = true;
    redraw_later(wp, UPD_NOT_VALID);
  }

  // compute initial position
  if (wp->w_float_config.relative == kFloatRelativeWindow) {
    int row = (int)wp->w_float_config.row;
    int col = (int)wp->w_float_config.col;
    Error dummy = ERROR_INIT;
    win_T *parent = find_window_by_handle(wp->w_float_config.window, &dummy);
    if (parent) {
      row += parent->w_winrow;
      col += parent->w_wincol;
      ScreenGrid *grid = &parent->w_grid;
      int row_off = 0, col_off = 0;
      grid_adjust(&grid, &row_off, &col_off);
      row += row_off;
      col += col_off;
      if (wp->w_float_config.bufpos.lnum >= 0) {
        pos_T pos = { wp->w_float_config.bufpos.lnum + 1,
                      wp->w_float_config.bufpos.col, 0 };
        int trow, tcol, tcolc, tcole;
        textpos2screenpos(parent, &pos, &trow, &tcol, &tcolc, &tcole, true);
        row += trow - 1;
        col += tcol - 1;
      }
    }
    api_clear_error(&dummy);
    wp->w_winrow = row;
    wp->w_wincol = col;
  } else {
    wp->w_winrow = (int)fconfig.row;
    wp->w_wincol = (int)fconfig.col;
  }

  // changing border style while keeping border only requires redrawing border
  if (fconfig.border) {
    wp->w_redr_border = true;
    redraw_later(wp, UPD_VALID);
  }
}

static int float_zindex_cmp(const void *a, const void *b)
{
  return (*(win_T **)b)->w_float_config.zindex - (*(win_T **)a)->w_float_config.zindex;
}

void win_float_remove(bool bang, int count)
{
  kvec_t(win_T *) float_win_arr = KV_INITIAL_VALUE;
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    kv_push(float_win_arr, wp);
  }
  qsort(float_win_arr.items, float_win_arr.size, sizeof(win_T *), float_zindex_cmp);
  for (size_t i = 0; i < float_win_arr.size; i++) {
    if (win_close(float_win_arr.items[i], false, false) == FAIL) {
      break;
    }
    if (!bang) {
      count--;
      if (count == 0) {
        break;
      }
    }
  }
  kv_destroy(float_win_arr);
}

void win_check_anchored_floats(win_T *win)
{
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    // float might be anchored to moved window
    if (wp->w_float_config.relative == kFloatRelativeWindow
        && wp->w_float_config.window == win->handle) {
      wp->w_pos_changed = true;
    }
  }
}

void win_reconfig_floats(void)
{
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    win_config_float(wp, wp->w_float_config);
  }
}

/// Return true if "win" is floating window in the current tab page.
///
/// @param  win  window to check
bool win_float_valid(const win_T *win)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (win == NULL) {
    return false;
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp == win) {
      return wp->w_floating;
    }
  }
  return false;
}
