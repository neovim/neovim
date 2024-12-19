#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/optionstr.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"
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
win_T *win_new_float(win_T *wp, bool last, WinConfig fconfig, Error *err)
{
  if (wp == NULL) {
    tabpage_T *tp = NULL;
    win_T *tp_last = last ? lastwin : lastwin_nofloating();
    if (fconfig.window != 0) {
      assert(!last);
      win_T *parent_wp = find_window_by_handle(fconfig.window, err);
      if (!parent_wp) {
        return NULL;
      }
      tp = win_find_tabpage(parent_wp);
      if (!tp) {
        return NULL;
      }
      tp_last = tp == curtab ? lastwin : tp->tp_lastwin;
      while (tp_last->w_floating && tp_last->w_prev) {
        tp_last = tp_last->w_prev;
      }
    }
    wp = win_alloc(tp_last, false);
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
    } else if (cmdwin_win != NULL && !cmdwin_win->w_floating) {
      // cmdwin can't become the only non-float. Check for others.
      bool other_nonfloat = false;
      for (win_T *wp2 = firstwin; wp2 != NULL && !wp2->w_floating; wp2 = wp2->w_next) {
        if (wp2 != wp && wp2 != cmdwin_win) {
          other_nonfloat = true;
          break;
        }
      }
      if (!other_nonfloat) {
        api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
        return NULL;
      }
    }
    int dir;
    winframe_remove(wp, &dir, NULL, NULL);
    XFREE_CLEAR(wp->w_frame);
    win_comp_pos();  // recompute window positions
    win_remove(wp, NULL);
    win_append(lastwin_nofloating(), wp, NULL);
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
  parse_winhl_opt(NULL, wp);

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

void win_config_float(win_T *wp, WinConfig fconfig)
{
  wp->w_width = MAX(fconfig.width, 1);
  wp->w_height = MAX(fconfig.height, 1);

  if (fconfig.relative == kFloatRelativeCursor) {
    fconfig.relative = kFloatRelativeWindow;
    fconfig.row += curwin->w_wrow;
    fconfig.col += curwin->w_wcol;
    fconfig.window = curwin->handle;
  } else if (fconfig.relative == kFloatRelativeMouse) {
    int row = mouse_row;
    int col = mouse_col;
    int grid = mouse_grid;
    win_T *mouse_win = mouse_find_win(&grid, &row, &col);
    if (mouse_win != NULL) {
      fconfig.relative = kFloatRelativeWindow;
      fconfig.row += row;
      fconfig.col += col;
      fconfig.window = mouse_win->handle;
    }
  }

  bool change_external = fconfig.external != wp->w_config.external;
  bool change_border = (fconfig.border != wp->w_config.border
                        || memcmp(fconfig.border_hl_ids,
                                  wp->w_config.border_hl_ids,
                                  sizeof fconfig.border_hl_ids) != 0);

  merge_win_config(&wp->w_config, fconfig);

  bool has_border = wp->w_floating && wp->w_config.border;
  for (int i = 0; i < 4; i++) {
    int new_adj = has_border && wp->w_config.border_chars[2 * i + 1][0];
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
  set_must_redraw(UPD_VALID);

  wp->w_pos_changed = true;
  if (change_external || change_border) {
    wp->w_hl_needs_update = true;
    redraw_later(wp, UPD_NOT_VALID);
  }

  // compute initial position
  if (wp->w_config.relative == kFloatRelativeWindow) {
    int row = (int)wp->w_config.row;
    int col = (int)wp->w_config.col;
    Error dummy = ERROR_INIT;
    win_T *parent = find_window_by_handle(wp->w_config.window, &dummy);
    if (parent) {
      row += parent->w_winrow;
      col += parent->w_wincol;
      ScreenGrid *grid = &parent->w_grid;
      int row_off = 0;
      int col_off = 0;
      grid_adjust(&grid, &row_off, &col_off);
      row += row_off;
      col += col_off;
      if (wp->w_config.bufpos.lnum >= 0) {
        pos_T pos = { MIN(wp->w_config.bufpos.lnum + 1, parent->w_buffer->b_ml.ml_line_count),
                      wp->w_config.bufpos.col, 0 };
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
  int za = (*(win_T **)a)->w_config.zindex;
  int zb = (*(win_T **)b)->w_config.zindex;
  return za == zb ? 0 : za < zb ? 1 : -1;
}

void win_float_remove(bool bang, int count)
{
  kvec_t(win_T *) float_win_arr = KV_INITIAL_VALUE;
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    kv_push(float_win_arr, wp);
  }
  if (float_win_arr.size > 0) {
    qsort(float_win_arr.items, float_win_arr.size, sizeof(win_T *), float_zindex_cmp);
  }
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
    if (wp->w_config.relative == kFloatRelativeWindow
        && wp->w_config.window == win->handle) {
      wp->w_pos_changed = true;
    }
  }
}

void win_reconfig_floats(void)
{
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    win_config_float(wp, wp->w_config);
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

win_T *win_float_find_preview(void)
{
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    if (wp->w_float_is_info) {
      return wp;
    }
  }
  return NULL;
}

/// Select an alternative window to `win` (assumed floating) in tabpage `tp`.
///
/// Useful for finding a window to switch to if `win` is the current window, but is then closed or
/// moved to a different tabpage.
///
/// @param  tp  `win`'s original tabpage, or NULL for current.
win_T *win_float_find_altwin(const win_T *win, const tabpage_T *tp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (tp == NULL) {
    return (win_valid(prevwin) && prevwin != win) ? prevwin : firstwin;
  }

  assert(tp != curtab);
  return (tabpage_win_valid(tp, tp->tp_prevwin) && tp->tp_prevwin != win) ? tp->tp_prevwin
                                                                          : tp->tp_firstwin;
}

/// Inline helper function for handling errors and cleanup in win_float_create.
static inline win_T *handle_error_and_cleanup(win_T *wp, Error *err)
{
  if (ERROR_SET(err)) {
    emsg(err->msg);
    api_clear_error(err);
  }
  if (wp) {
    win_remove(wp, NULL);
    win_free(wp, NULL);
  }
  unblock_autocmds();
  return NULL;
}

/// create a floating preview window.
///
/// @param[in] bool enter floating window.
/// @param[in] bool create a new buffer for window.
///
/// @return win_T
win_T *win_float_create(bool enter, bool new_buf)
{
  WinConfig config = WIN_CONFIG_INIT;
  config.col = curwin->w_wcol;
  config.row = curwin->w_wrow;
  config.relative = kFloatRelativeEditor;
  config.focusable = false;
  config.mouse = false;
  config.anchor = 0;  // NW
  config.noautocmd = true;
  config.hide = true;
  config.style = kWinStyleMinimal;
  Error err = ERROR_INIT;

  block_autocmds();
  win_T *wp = win_new_float(NULL, false, config, &err);
  if (!wp) {
    return handle_error_and_cleanup(wp, &err);
  }

  if (new_buf) {
    Buffer b = nvim_create_buf(false, true, &err);
    if (!b) {
      return handle_error_and_cleanup(wp, &err);
    }
    buf_T *buf = find_buffer_by_handle(b, &err);
    if (!buf) {
      return handle_error_and_cleanup(wp, &err);
    }
    buf->b_p_bl = false;  // unlist
    set_option_direct_for(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("wipe"), OPT_LOCAL, 0,
                          kOptScopeBuf, buf);
    win_set_buf(wp, buf, &err);
    if (ERROR_SET(&err)) {
      return handle_error_and_cleanup(wp, &err);
    }
  }
  unblock_autocmds();
  wp->w_p_diff = false;
  wp->w_float_is_info = true;
  if (enter) {
    win_enter(wp, false);
  }
  return wp;
}
