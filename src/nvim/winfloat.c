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
#include "nvim/gettext_defs.h"
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
      tp_last = tp->tp_lastwin;
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

  wp->w_config = fconfig;

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

/// Parses the 'border' style configuration and updates WinConfig.
///
/// @param fconfig Configuration storage.
/// @param dup_val Value text to parse.
/// @param len Length of the text.
/// @param err Pointer to the Error structure for error handling.
///
/// @return true if parsing is successful, otherwise false.
static bool parse_opt_border(WinConfig *config, char *dup_val, size_t len, Error *err)
{
  Object style = CSTR_AS_OBJ(dup_val);
  parse_border_style(style, config, err);
  api_free_object(style);
  if (ERROR_SET(err)) {
    return false;
  }
  int border_attr = syn_name2attr("FloatBorder");
  for (int i = 0; i < 8; i++) {
    config->border_attr[i] = config->border_hl_ids[i]
                             ? hl_get_ui_attr(0, HLF_BORDER, config->border_hl_ids[i], false)
                             : border_attr;
  }
  return true;
}

/// Parses numeric keys for 'height' and 'width' options and updates WinConfig.
///
/// @param fconfig Configuration storage.
/// @param dig Digits representing the numeric value.
/// @param len Length of the digits.
/// @param err Pointer to the Error structure for error handling.
///
/// @return true if parsing is successful, otherwise false.
static bool parse_opt_dig_key(WinConfig *config, char *dig, size_t len, Error *err)
{
  int val = getdigits_int(&dig, false, 0);
  if (len == 6) {
    config->width = val;
  } else {
    config->height = val;
  }
  return true;
}

/// Parses options for configuring floating windows for completion popups or preview popups.
/// Supports setting border style, title, title position, footer, footer position, height, and width.
/// Only processes height and width options if `preview` is true.
///
/// @param fconfig The floating window configuration to modify.
/// @param preview Indicates if the configuration is for a preview popup.
///
/// @return True if options are successfully parsed, otherwise false.
bool parse_float_option(WinConfig *config)
{
  char *p = p_pvp;
  Error err = ERROR_INIT;

  struct {
    char *key;
    bool (*parser_func)(WinConfig *, char *, size_t, Error *);
  } parsers[] = {
    { "border:", parse_opt_border },
    { "height:", parse_opt_dig_key },
    { "width:", parse_opt_dig_key },
    { NULL, NULL },
  };

  for (; *p != NUL; p += (*p == ',' ? 1 : 0)) {
    char *s = p;

    char *e = strchr(p, ':');
    if (e == NULL || e[1] == NUL) {
      return false;
    }

    p = strchr(e, ',');
    if (p == NULL) {
      p = e + strlen(e);
    }

    bool parsed = false;
    for (size_t i = 0; parsers[i].key; i++) {
      size_t len = strlen(parsers[i].key);
      if (strncmp(s, parsers[i].key, len) == 0) {
        // when is width or height use e + 1
        char *val = s[0] == 'w' || s[0] == 'h' ? e + 1 : NULL;
        if (!val) {
          val = xmemdupz(s + len, (p ? (size_t)(p - s) - len : (size_t)(s - len)));
          if (!val) {
            return false;
          }
        }
        if (!parsers[i].parser_func(config, val, len, &err)) {
          return false;
        }
        parsed = true;
        break;
      }
    }

    if (!parsed) {
      return false;
    }
  }

  return true;
}

/// Searches for a floating window matching given criteria.
///
/// @param find_info Search for info window if true, else preview window.
///
/// @return A pointer to the a floating window structure.
win_T *win_float_find_preview(FloatType float_type)
{
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    if (wp->w_float_is == float_type) {
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

/// create a floating preview window.
///
/// @param[in] bool enter floating window.
/// @param[in] bool create a new buffer for window.
///
/// @return win_T
win_T *win_float_create(bool enter, bool new_buf, FloatType float_type)
{
  WinConfig config = WIN_CONFIG_INIT;
  config.col = curwin->w_wcol;
  config.row = curwin->w_wrow;
  config.relative = kFloatRelativeEditor;
  config.focusable = false;
  config.anchor = 0;  // NW
  config.noautocmd = true;
  config.hide = true;
  config.style = kWinStyleMinimal;
  if (float_type == kFloatPreview && !parse_float_option(&config)) {
    emsg(_(e_invarg));
    return NULL;
  }
  Error err = ERROR_INIT;
  block_autocmds();
  win_T *wp = win_new_float(NULL, false, config, &err);
  if (!wp) {
    unblock_autocmds();
    return NULL;
  }

  if (new_buf) {
    Buffer b = nvim_create_buf(false, true, &err);
    if (!b) {
      win_remove(wp, NULL);
      win_free(wp, NULL);
      unblock_autocmds();
      return NULL;
    }
    buf_T *buf = find_buffer_by_handle(b, &err);
    buf->b_p_bl = false;  // unlist
    set_option_direct_for(kOptBufhidden, STATIC_CSTR_AS_OPTVAL("wipe"), OPT_LOCAL, 0, kOptReqBuf,
                          buf);
    win_set_buf(wp, buf, &err);
  }
  unblock_autocmds();
  wp->w_p_diff = false;
  wp->w_float_is = float_type;
  if (wp->w_float_is == kFloatPreview) {
    wp->w_p_pvw = true;
    wp->w_p_wrap = true;
    wp->w_p_so = 0;
  }

  if (enter) {
    win_enter(wp, false);
  }
  p_pvwid = wp->handle;
  return wp;
}

/// Closes a specified floating window used for previews or popups.
/// Searches for and closes a floating window based on given criteria.
///
/// @param find_info Flag to determine search criteria for the floating window.
///
/// @return True if the window is successfully closed, otherwise false.
bool win_float_close(FloatType float_type)
{
  win_T *wp = win_float_find_preview(float_type);
  p_pvwid = 9999;
  return wp && win_close(wp, false, false) != FAIL;
}

/// Set bufname as title for a floating window.
/// Title position is center.
///
/// @param wp A pointer of win_T
/// @param redraw bool
/// @return
void win_float_set_title(win_T *wp, bool redraw)
{
  if (!wp->w_floating || !wp->w_config.border) {
    return;
  }

  if (wp->w_config.title) {
    clear_virttext(&wp->w_config.title_chunks);
  }
  int title_id = syn_check_group(S_LEN("FloatTitle"));
  wp->w_config.title = true;
  wp->w_config.title_pos = kAlignCenter;
  wp->w_config.title_width = (int)mb_string2cells(wp->w_buffer->b_fname);
  kv_push(*(&wp->w_config.title_chunks), ((VirtTextChunk){ .text = xstrdup(wp->w_buffer->b_fname),
                                                           .hl_id = title_id }));
  if (redraw) {
    win_config_float(wp, wp->w_config);
  }
}

/// adjust a preview floating window postion to fit screen and buffer in wp.
///
/// @param wp A pointer of win_T
/// @return
void win_float_adjust_position(win_T *wp)
{
  if (!wp->w_floating) {
    return;
  }

  int border_extra = wp->w_config.border ? 2 : 0;
  int right_extra = Columns - curwin->w_wincol - curwin->w_wcol - border_extra;
  int left_extra = curwin->w_wincol + curwin->w_wcol - border_extra;
  int below_height = Rows - curwin->w_winrow - curwin->w_wrow - border_extra;
  int above_height = curwin->w_winrow + curwin->w_wrow - border_extra;

  // fit screen
  bool west = false;
  if (wp->w_config.width < right_extra) {  // placed in right
    west = true;
  } else if (wp->w_config.width < left_extra) {  // placed in left
    west = false;
  } else {  // eighter width not enough to placed the preview window use the largest onw.
    if (right_extra > left_extra) {
      west = true;
      wp->w_config.width = right_extra;
    } else {
      wp->w_config.width = left_extra;
    }
  }

  if (wp->w_config.height < below_height) {  // below is enough to placed preview window
    wp->w_config.anchor = west ? 0 : kFloatAnchorEast;  // NW or NE
  } else if (wp->w_config.height < above_height) {
    // SW or SE
    wp->w_config.anchor = west ? kFloatAnchorSouth : kFloatAnchorSouth | kFloatAnchorEast;
  } else {  // either height value smaller than max height use the largest one
    if (below_height > above_height) {
      wp->w_config.height = below_height;
      wp->w_config.anchor = west ? 0 : kFloatAnchorEast;  // NW or NE
    } else {
      wp->w_config.height = above_height;
      // SW or SE
      wp->w_config.anchor = west ? kFloatAnchorSouth : kFloatAnchorSouth | kFloatAnchorEast;
    }
  }

  if (wp->w_topline < 1) {
    wp->w_topline = 1;
  } else if (wp->w_topline > wp->w_buffer->b_ml.ml_line_count) {
    wp->w_topline = wp->w_buffer->b_ml.ml_line_count;
  }

  // fit buffer preview window it's wrap always
  if (wp->w_p_wrap) {
    // actually height of preview window
    int actual_height = 0;
    // max width of lines in preview window
    int max_width = 0;
    int lnum = wp->w_topline;
    int height = wp->w_config.height;
    while (height) {
      actual_height += plines_win(wp, lnum, false);
      int len = linetabsize(wp, lnum);
      if (len > max_width) {
        max_width = len;
      }
      lnum++;
      if (lnum > wp->w_buffer->b_ml.ml_line_count) {
        break;
      }
      height--;
    }

    if (actual_height > 0) {
      wp->w_config.height = MIN(wp->w_config.height, actual_height);
    }

    if (max_width > 0) {
      wp->w_config.width = MIN(wp->w_config.width, max_width);
    }
  }

  if ((wp->w_config.anchor & kFloatAnchorSouth) == 0) {
    wp->w_config.row += 1;
    wp->w_config.col += 1;
  }
  wp->w_config.hide = false;
  win_config_float(wp, wp->w_config);
}
