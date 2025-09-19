#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/vim.h"
#include "nvim/api/win_config.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#include "winfloat.c.generated.h"

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
    if (wp->w_p_wbr != NULL && fconfig.height == 1) {
      if (wp->w_p_wbr != empty_string_option) {
        free_string_option(wp->w_p_wbr);
      }
      wp->w_p_wbr = empty_string_option;
    }
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
    win_T *mouse_win = mouse_find_win_inner(&grid, &row, &col);
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
      grid_adjust(&parent->w_grid, &row, &col);
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

void win_float_remove_by_zindex(bool bang, int count)
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

void win_float_anchor_laststatus(void)
{
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    if (win->w_config.relative == kFloatRelativeLaststatus) {
      win->w_pos_changed = true;
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

/// Parses options for configuring floating windows for completion popups or preview popups.
/// Supports setting border style, title, title position, footer, footer position, height, and width.
///
/// @param config The floating window configuration to modify.
///
/// @return True if options are successfully parsed, otherwise false.
bool win_float_parse_option(WinConfig *config)
{
  char *p = p_pvp;
  Error err = ERROR_INIT;

  for (; *p != NUL; p += (*p == ',' ? 1 : 0)) {
    char *s = p;
    char *e = strchr(p, ':');
    if (e == NULL || e[1] == NUL) {
      goto cleanup;
    }

    p = strchr(e, ',');
    if (p == NULL) {
      p = e + strlen(e);
    }

    bool parsed = false;
    if (strncmp(s, "height:", 7) == 0 || strncmp(s, "width:", 6) == 0) {
      char *dig = e + 1;
      char *start = dig;
      int val = getdigits_int(&dig, false, 0);
      if (dig == start) {
        goto cleanup;
      }

      if (s[0] == 'h') {  // height
        config->height = val;
      } else {  // width
        config->width = val;
      }
      parsed = true;
    } else if (strncmp(s, "align:", 6) == 0) {
      char *val = e + 1;
      size_t len = (p ? (size_t)(p - val) : (size_t)strlen(val));

      // TODO(glepnir): support this by adding completepopup
      bool is_item = (len == 4) && strncmp(val, "item", 4) == 0;
      bool is_menu = (len == 4) && strncmp(val, "menu", 4) == 0;

      if (!is_item && !is_menu) {
        // Invalid align value
        api_set_error(&err, kErrorTypeValidation, "Invalid align value. Expected 'item' or 'menu'");
        goto cleanup;
      }
      parsed = true;
    }

    if (!parsed) {
      goto cleanup;
    }
  }

  return true;

cleanup:
  api_clear_error(&err);
  return false;
}

/// Searches for a floating window matching given criteria.
///
/// @param preview Search for preview window if true, else pum info window.
///
/// @return A pointer to the a floating window structure.
win_T *win_float_find_preview(bool preview)
{
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    if ((preview && wp->w_p_pvw) || wp->w_float_is_info) {
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
  win_T *wp = prevwin;
  if (tp == NULL) {
    return (win_valid(wp) && wp != win && wp->w_config.focusable
            && !wp->w_config.hide) ? wp : firstwin;
  }

  assert(tp != curtab);
  wp = tabpage_win_valid(tp, tp->tp_prevwin) ? tp->tp_prevwin : tp->tp_firstwin;
  return (wp->w_config.focusable && !wp->w_config.hide) ? wp : tp->tp_firstwin;
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
/// @param[in] bool create a floating preview window.
///
/// @return win_T
win_T *win_float_create(bool enter, bool new_buf, bool preview)
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

  if (preview) {
    if (!win_float_parse_option(&config)) {
      emsg(_(e_invarg));
      return NULL;
    }

    if (*p_winborder != NUL && !parse_winborder(&config, &err)) {
      if (ERROR_SET(&err)) {
        emsg(err.msg);
        api_clear_error(&err);
        return NULL;
      }
    }
  }

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
  if (preview) {
    wp->w_p_pvw = true;
    wp->w_p_wrap = true;
    wp->w_p_so = 0;
  } else {
    wp->w_float_is_info = true;
  }

  if (enter) {
    win_enter(wp, false);
  }

  return wp;
}

/// Closes a specified floating window used for previews or popups.
/// Searches for and closes a floating window based on given criteria.
///
/// @param preview Flag to determine search criteria for the floating window.
///
/// @return True if the window is successfully closed, otherwise false.
bool win_float_close(bool preview)
{
  win_T *wp = win_float_find_preview(preview);
  return wp && win_close(wp, false, false) != FAIL;
}

/// Set bufname as title for a floating window.
/// Title position is center.
///
/// @param wp A pointer of win_T
/// @param redraw bool
/// @return
void win_float_set_title(win_T *wp)
{
  if (!wp->w_floating || !wp->w_config.border) {
    return;
  }

  if (wp->w_config.title) {
    clear_virttext(&wp->w_config.title_chunks);
  }
  wp->w_config.title = true;
  wp->w_config.title_pos = kAlignCenter;
  wp->w_config.title_width = (int)mb_string2cells(wp->w_buffer->b_fname);
  kv_push(*(&wp->w_config.title_chunks), ((VirtTextChunk){
    .text = xstrdup(wp->w_buffer->b_fname), .hl_id = -1
  }));
  win_config_float(wp, wp->w_config);
}

/// adjust a preview floating window postion to fit screen and buffer in wp.
///
/// @param wp A pointer of win_T
void win_float_adjust_position(win_T *wp)
{
  if (!wp->w_floating) {
    return;
  }

  // Get cursor screen coordinates
  int cursor_row = curwin->w_winrow + curwin->w_wrow;
  int cursor_col = curwin->w_wincol + curwin->w_wcol;

  // Border takes space on all sides
  int border_width = wp->w_config.border ? 2 : 0;   // left + right border
  int border_height = wp->w_config.border ? 2 : 0;  // top + bottom border

  // Calculate actual content height considering wrap, folds, etc.
  int actual_height = wp->w_config.height;
  if (wp->w_buffer && wp->w_buffer->b_ml.ml_line_count > 0) {
    // Calculate from topline to get actual display height
    linenr_T start_line = wp->w_topline;
    linenr_T end_line = MIN(start_line + wp->w_config.height - 1,
                            wp->w_buffer->b_ml.ml_line_count);

    // Use plines_m_win to calculate actual screen lines needed
    // This handles wrap, folding, virtual text, etc.
    int content_height = plines_m_win(wp, start_line, end_line, wp->w_config.height);

    // If we have fewer lines than requested, adjust
    if (content_height < wp->w_config.height) {
      actual_height = content_height;
    }

    // Ensure minimum height
    if (actual_height < 1) {
      actual_height = 1;
    }
  }

  // Calculate available space in four directions (including border)
  int right_space = Columns - cursor_col - 1;  // -1 for cursor position
  int left_space = cursor_col;
  int below_space = Rows - cursor_row - 2;     // -2 for cursor and cmdline
  int above_space = cursor_row - 1;            // -1 for cursor position

  // Determine horizontal position and adjust width if needed
  bool place_right = true;
  int final_width = wp->w_config.width;
  int total_width = final_width + border_width;

  if (total_width <= right_space) {
    place_right = true;  // Prefer right side
  } else if (total_width <= left_space) {
    place_right = false;  // Place on left side
  } else {
    // Neither side has enough space, choose the larger one and adjust width
    if (right_space >= left_space) {
      place_right = true;
      final_width = MAX(1, right_space - border_width);
    } else {
      place_right = false;
      final_width = MAX(1, left_space - border_width);
    }
    wp->w_config.width = final_width;
  }

  // Determine vertical position and adjust height if needed
  bool place_below = true;
  int final_height = actual_height;
  int total_height = final_height + border_height;

  if (total_height <= below_space) {
    place_below = true;  // Prefer below cursor
  } else if (total_height <= above_space) {
    place_below = false;  // Place above cursor
  } else {
    // Neither direction has enough space, choose the larger one and adjust height
    if (below_space >= above_space) {
      place_below = true;
      final_height = MAX(1, below_space - border_height);
    } else {
      place_below = false;
      final_height = MAX(1, above_space - border_height);
    }
    wp->w_config.height = final_height;

    // Recalculate actual content height with new height limit
    if (wp->w_buffer && wp->w_buffer->b_ml.ml_line_count > 0) {
      linenr_T start_line = wp->w_topline;
      linenr_T end_line = MIN(start_line + final_height - 1,
                              wp->w_buffer->b_ml.ml_line_count);
      int content_height = plines_m_win(wp, start_line, end_line, final_height);
      wp->w_config.height = MIN(final_height, content_height);
    }
  }

  // Set anchor and position based on placement
  wp->w_config.anchor = 0;  // Reset anchor

  if (place_below && place_right) {
    // Bottom-right: anchor NW
    wp->w_config.anchor = 0;  // NW
    wp->w_config.row = cursor_row + 1;
    wp->w_config.col = cursor_col + 1;
  } else if (place_below && !place_right) {
    // Bottom-left: anchor NE
    wp->w_config.anchor = kFloatAnchorEast;  // NE
    wp->w_config.row = cursor_row + 1;
    wp->w_config.col = cursor_col;
  } else if (!place_below && place_right) {
    // Top-right: anchor SW
    wp->w_config.anchor = kFloatAnchorSouth;  // SW
    wp->w_config.row = cursor_row;
    wp->w_config.col = cursor_col + 1;
  } else {
    // Top-left: anchor SE
    wp->w_config.anchor = kFloatAnchorSouth | kFloatAnchorEast;  // SE
    wp->w_config.row = cursor_row;
    wp->w_config.col = cursor_col;
  }

  // Ensure topline is valid
  if (wp->w_topline < 1) {
    wp->w_topline = 1;
  } else if (wp->w_topline > wp->w_buffer->b_ml.ml_line_count) {
    wp->w_topline = wp->w_buffer->b_ml.ml_line_count;
  }

  wp->w_config.hide = false;
  win_config_float(wp, wp->w_config);
}
