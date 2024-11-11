#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/digraph.h"
#include "nvim/drawline.h"
#include "nvim/drawscreen.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/optionstr.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/sign.h"
#include "nvim/sign_defs.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/window.h"

// Determines how deeply nested %{} blocks will be evaluated in statusline.
#define MAX_STL_EVAL_DEPTH 100

/// Enumeration specifying the valid numeric bases that can
/// be used when printing numbers in the status line.
typedef enum {
  kNumBaseDecimal = 10,
  kNumBaseHexadecimal = 16,
} NumberBase;

/// Redraw the status line of window `wp`.
///
/// If inversion is possible we use it. Else '=' characters are used.
void win_redr_status(win_T *wp)
{
  int attr;
  bool is_stl_global = global_stl_height() > 0;
  static bool busy = false;

  // May get here recursively when 'statusline' (indirectly)
  // invokes ":redrawstatus".  Simply ignore the call then.
  if (busy
      // Also ignore if wildmenu is showing.
      || (wild_menu_showing != 0 && !ui_has(kUIWildmenu))) {
    return;
  }
  busy = true;

  wp->w_redr_status = false;
  if (wp->w_status_height == 0 && !(is_stl_global && wp == curwin)) {
    // no status line, either global statusline is enabled or the window is a last window
    redraw_cmdline = true;
  } else if (!redrawing()) {
    // Don't redraw right now, do it later. Don't update status line when
    // popup menu is visible and may be drawn over it
    wp->w_redr_status = true;
  } else if (*p_stl != NUL || *wp->w_p_stl != NUL) {
    // redraw custom status line
    redraw_custom_statusline(wp);
  } else {
    schar_T fillchar = fillchar_status(&attr, wp);
    const int stl_width = is_stl_global ? Columns : wp->w_width;

    get_trans_bufname(wp->w_buffer);
    char *p = NameBuff;
    int len = (int)strlen(p);

    if ((bt_help(wp->w_buffer)
         || wp->w_p_pvw
         || bufIsChanged(wp->w_buffer)
         || wp->w_buffer->b_p_ro)
        && len < MAXPATHL - 1) {
      *(p + len++) = ' ';
    }
    if (bt_help(wp->w_buffer)) {
      snprintf(p + len, MAXPATHL - (size_t)len, "%s", _("[Help]"));
      len += (int)strlen(p + len);
    }
    if (wp->w_p_pvw) {
      snprintf(p + len, MAXPATHL - (size_t)len, "%s", _("[Preview]"));
      len += (int)strlen(p + len);
    }
    if (bufIsChanged(wp->w_buffer)) {
      snprintf(p + len, MAXPATHL - (size_t)len, "%s", "[+]");
      len += (int)strlen(p + len);
    }
    if (wp->w_buffer->b_p_ro) {
      snprintf(p + len, MAXPATHL - (size_t)len, "%s", _("[RO]"));
      // len += (int)strlen(p + len);  // dead assignment
    }

    int this_ru_col = MAX(ru_col - (Columns - stl_width), (stl_width + 1) / 2);
    if (this_ru_col <= 1) {
      p = "<";                // No room for file name!
      len = 1;
    } else {
      int i;

      // Count total number of display cells.
      int clen = (int)mb_string2cells(p);

      // Find first character that will fit.
      // Going from start to end is much faster for DBCS.
      for (i = 0; p[i] != NUL && clen >= this_ru_col - 1;
           i += utfc_ptr2len(p + i)) {
        clen -= utf_ptr2cells(p + i);
      }
      len = clen;
      if (i > 0) {
        p = p + i - 1;
        *p = '<';
        len++;
      }
    }

    grid_line_start(&default_grid, is_stl_global ? (Rows - (int)p_ch - 1) : W_ENDROW(wp));
    const int off = is_stl_global ? 0 : wp->w_wincol;

    int width = grid_line_puts(off, p, -1, attr);
    grid_line_fill(off + width, off + this_ru_col, fillchar, attr);

    if (get_keymap_str(wp, "<%s>", NameBuff, MAXPATHL)
        && this_ru_col - len > (int)strlen(NameBuff) + 1) {
      grid_line_puts(off + this_ru_col - (int)strlen(NameBuff) - 1, NameBuff, -1, attr);
    }

    win_redr_ruler(wp);

    // Draw the 'showcmd' information if 'showcmdloc' == "statusline".
    if (p_sc && *p_sloc == 's') {
      const int sc_width = MIN(10, this_ru_col - len - 2);

      if (sc_width > 0) {
        grid_line_puts(off + this_ru_col - sc_width - 1, showcmd_buf, sc_width, attr);
      }
    }

    grid_line_flush();
  }

  // May need to draw the character below the vertical separator.
  if (wp->w_vsep_width != 0 && wp->w_status_height != 0 && redrawing()) {
    schar_T fillchar;
    if (stl_connected(wp)) {
      fillchar = fillchar_status(&attr, wp);
    } else {
      attr = win_hl_attr(wp, HLF_C);
      fillchar = wp->w_p_fcs_chars.vert;
    }
    grid_line_start(&default_grid, W_ENDROW(wp));
    grid_line_put_schar(W_ENDCOL(wp), fillchar, attr);
    grid_line_flush();
  }
  busy = false;
}

void get_trans_bufname(buf_T *buf)
{
  if (buf_spname(buf) != NULL) {
    xstrlcpy(NameBuff, buf_spname(buf), MAXPATHL);
  } else {
    home_replace(buf, buf->b_fname, NameBuff, MAXPATHL, true);
  }
  trans_characters(NameBuff, MAXPATHL);
}

/// Only call if (wp->w_vsep_width != 0).
///
/// @return  true if the status line of window "wp" is connected to the status
/// line of the window right of it.  If not, then it's a vertical separator.
bool stl_connected(win_T *wp)
{
  frame_T *fr = wp->w_frame;
  while (fr->fr_parent != NULL) {
    if (fr->fr_parent->fr_layout == FR_COL) {
      if (fr->fr_next != NULL) {
        break;
      }
    } else {
      if (fr->fr_next != NULL) {
        return true;
      }
    }
    fr = fr->fr_parent;
  }
  return false;
}

/// Clear status line, window bar or tab page line click definition table
///
/// @param[out]  tpcd  Table to clear.
/// @param[in]  tpcd_size  Size of the table.
void stl_clear_click_defs(StlClickDefinition *const click_defs, const size_t click_defs_size)
{
  if (click_defs != NULL) {
    for (size_t i = 0; i < click_defs_size; i++) {
      if (i == 0 || click_defs[i].func != click_defs[i - 1].func) {
        xfree(click_defs[i].func);
      }
    }
    memset(click_defs, 0, click_defs_size * sizeof(click_defs[0]));
  }
}

/// Allocate or resize the click definitions array if needed.
StlClickDefinition *stl_alloc_click_defs(StlClickDefinition *cdp, int width, size_t *size)
{
  if (*size < (size_t)width) {
    xfree(cdp);
    *size = (size_t)width;
    cdp = xcalloc(*size, sizeof(StlClickDefinition));
  }
  return cdp;
}

/// Fill the click definitions array if needed.
void stl_fill_click_defs(StlClickDefinition *click_defs, StlClickRecord *click_recs,
                         const char *buf, int width, bool tabline)
{
  if (click_defs == NULL) {
    return;
  }

  int col = 0;
  int len = 0;

  StlClickDefinition cur_click_def = {
    .type = kStlClickDisabled,
  };
  for (int i = 0; click_recs[i].start != NULL; i++) {
    len += vim_strnsize(buf, (int)(click_recs[i].start - buf));
    assert(len <= width);
    if (col < len) {
      while (col < len) {
        click_defs[col++] = cur_click_def;
      }
    } else {
      xfree(cur_click_def.func);
    }
    buf = click_recs[i].start;
    cur_click_def = click_recs[i].def;
    if (!tabline && !(cur_click_def.type == kStlClickDisabled
                      || cur_click_def.type == kStlClickFuncRun)) {
      // window bar and status line only support click functions
      cur_click_def.type = kStlClickDisabled;
    }
  }
  if (col < width) {
    while (col < width) {
      click_defs[col++] = cur_click_def;
    }
  } else {
    xfree(cur_click_def.func);
  }
}

/// Redraw the status line, window bar or ruler of window "wp".
/// When "wp" is NULL redraw the tab pages line from 'tabline'.
static void win_redr_custom(win_T *wp, bool draw_winbar, bool draw_ruler)
{
  static bool entered = false;
  int attr;
  int row;
  int col = 0;
  int maxwidth;
  schar_T fillchar;
  char buf[MAXPATHL];
  char transbuf[MAXPATHL];
  char *stl;
  OptIndex opt_idx = kOptInvalid;
  int opt_scope = 0;
  stl_hlrec_t *hltab;
  StlClickRecord *tabtab;
  bool is_stl_global = global_stl_height() > 0;

  ScreenGrid *grid = &default_grid;

  // There is a tiny chance that this gets called recursively: When
  // redrawing a status line triggers redrawing the ruler or tabline.
  // Avoid trouble by not allowing recursion.
  if (entered) {
    return;
  }
  entered = true;

  // setup environment for the task at hand
  if (wp == NULL) {
    // Use 'tabline'.  Always at the first line of the screen.
    stl = p_tal;
    row = 0;
    fillchar = schar_from_ascii(' ');
    attr = HL_ATTR(HLF_TPF);
    maxwidth = Columns;
    opt_idx = kOptTabline;
  } else if (draw_winbar) {
    opt_idx = kOptWinbar;
    stl = ((*wp->w_p_wbr != NUL) ? wp->w_p_wbr : p_wbr);
    opt_scope = ((*wp->w_p_wbr != NUL) ? OPT_LOCAL : 0);
    row = -1;  // row zero is first row of text
    col = 0;
    grid = &wp->w_grid;
    grid_adjust(&grid, &row, &col);

    if (row < 0) {
      goto theend;
    }

    fillchar = wp->w_p_fcs_chars.wbr;
    attr = (wp == curwin) ? win_hl_attr(wp, HLF_WBR) : win_hl_attr(wp, HLF_WBRNC);
    maxwidth = wp->w_width_inner;
    stl_clear_click_defs(wp->w_winbar_click_defs, wp->w_winbar_click_defs_size);
    wp->w_winbar_click_defs = stl_alloc_click_defs(wp->w_winbar_click_defs, maxwidth,
                                                   &wp->w_winbar_click_defs_size);
  } else {
    row = is_stl_global ? (Rows - (int)p_ch - 1) : W_ENDROW(wp);
    fillchar = fillchar_status(&attr, wp);
    const bool in_status_line = wp->w_status_height != 0 || is_stl_global;
    maxwidth = in_status_line && !is_stl_global ? wp->w_width : Columns;
    stl_clear_click_defs(wp->w_status_click_defs, wp->w_status_click_defs_size);
    wp->w_status_click_defs = stl_alloc_click_defs(wp->w_status_click_defs, maxwidth,
                                                   &wp->w_status_click_defs_size);

    if (draw_ruler) {
      stl = p_ruf;
      opt_idx = kOptRulerformat;
      // advance past any leading group spec - implicit in ru_col
      if (*stl == '%') {
        if (*++stl == '-') {
          stl++;
        }
        if (atoi(stl)) {
          while (ascii_isdigit(*stl)) {
            stl++;
          }
        }
        if (*stl++ != '(') {
          stl = p_ruf;
        }
      }
      col = MAX(ru_col - (Columns - maxwidth), (maxwidth + 1) / 2);
      maxwidth -= col;
      if (!in_status_line) {
        grid = &msg_grid_adj;
        row = Rows - 1;
        maxwidth--;  // writing in last column may cause scrolling
        fillchar = schar_from_ascii(' ');
        attr = HL_ATTR(HLF_MSG);
      }
    } else {
      opt_idx = kOptStatusline;
      stl = ((*wp->w_p_stl != NUL) ? wp->w_p_stl : p_stl);
      opt_scope = ((*wp->w_p_stl != NUL) ? OPT_LOCAL : 0);
    }

    if (in_status_line && !is_stl_global) {
      col += wp->w_wincol;
    }
  }

  if (maxwidth <= 0) {
    goto theend;
  }

  // Temporarily reset 'cursorbind', we don't want a side effect from moving
  // the cursor away and back.
  win_T *ewp = wp == NULL ? curwin : wp;
  int p_crb_save = ewp->w_p_crb;
  ewp->w_p_crb = false;

  // Make a copy, because the statusline may include a function call that
  // might change the option value and free the memory.
  stl = xstrdup(stl);
  build_stl_str_hl(ewp, buf, sizeof(buf), stl, opt_idx, opt_scope,
                   fillchar, maxwidth, &hltab, NULL, &tabtab, NULL);

  xfree(stl);
  ewp->w_p_crb = p_crb_save;

  int len = (int)strlen(buf);
  int start_col = col;

  // Draw each snippet with the specified highlighting.
  if (!draw_ruler) {
    grid_line_start(grid, row);
  }

  int curattr = attr;
  char *p = buf;
  for (int n = 0; hltab[n].start != NULL; n++) {
    int textlen = (int)(hltab[n].start - p);
    // Make all characters printable.
    size_t tsize = transstr_buf(p, textlen, transbuf, sizeof transbuf, true);
    col += grid_line_puts(col, transbuf, (int)tsize, curattr);
    p = hltab[n].start;

    if (hltab[n].userhl == 0) {
      curattr = attr;
    } else if (hltab[n].userhl < 0) {
      curattr = hl_combine_attr(attr, syn_id2attr(-hltab[n].userhl));
    } else if (wp != NULL && wp != curwin && wp->w_status_height != 0) {
      curattr = highlight_stlnc[hltab[n].userhl - 1];
    } else {
      curattr = highlight_user[hltab[n].userhl - 1];
    }
  }
  // Make sure to use an empty string instead of p, if p is beyond buf + len.
  size_t tsize = transstr_buf(p >= buf + len ? "" : p, -1, transbuf, sizeof transbuf, true);
  col += grid_line_puts(col, transbuf, (int)tsize, curattr);
  int maxcol = start_col + maxwidth;

  // fill up with "fillchar"
  grid_line_fill(col, maxcol, fillchar, curattr);

  if (!draw_ruler) {
    grid_line_flush();
  }

  // Fill the tab_page_click_defs, w_status_click_defs or w_winbar_click_defs array for clicking
  // in the tab page line, status line or window bar
  StlClickDefinition *click_defs = (wp == NULL) ? tab_page_click_defs
                                                : draw_winbar ? wp->w_winbar_click_defs
                                                              : wp->w_status_click_defs;

  stl_fill_click_defs(click_defs, tabtab, buf, maxwidth, wp == NULL);

theend:
  entered = false;
}

void win_redr_winbar(win_T *wp)
{
  static bool entered = false;

  // Return when called recursively. This can happen when the winbar contains an expression
  // that triggers a redraw.
  if (entered) {
    return;
  }
  entered = true;

  if (wp->w_winbar_height == 0 || !redrawing()) {
    // Do nothing.
  } else if (*p_wbr != NUL || *wp->w_p_wbr != NUL) {
    win_redr_custom(wp, true, false);
  }
  entered = false;
}

/// must be called after a grid_line_start() at the intended row
void win_redr_ruler(win_T *wp)
{
  bool is_stl_global = global_stl_height() > 0;
  static bool did_show_ext_ruler = false;

  // If 'ruler' off, don't do anything
  if (!p_ru) {
    return;
  }

  // Check if cursor.lnum is valid, since win_redr_ruler() may be called
  // after deleting lines, before cursor.lnum is corrected.
  if (wp->w_cursor.lnum > wp->w_buffer->b_ml.ml_line_count) {
    return;
  }

  // Don't draw the ruler while doing insert-completion, it might overwrite
  // the (long) mode message.
  win_T *ruler_win = curwin->w_status_height == 0 ? curwin : lastwin_nofloating();
  if (wp == ruler_win && ruler_win->w_status_height == 0 && !is_stl_global) {
    if (edit_submode != NULL) {
      return;
    }
  }

  if (*p_ruf && p_ch > 0 && !ui_has(kUIMessages)) {
    win_redr_custom(wp, false, true);
    return;
  }

  // Check if not in Insert mode and the line is empty (will show "0-1").
  int empty_line = (State & MODE_INSERT) == 0
                   && *ml_get_buf(wp->w_buffer, wp->w_cursor.lnum) == NUL;

  int width;
  schar_T fillchar;
  int attr;
  int off;
  bool part_of_status = false;

  if (wp->w_status_height) {
    fillchar = fillchar_status(&attr, wp);
    off = wp->w_wincol;
    width = wp->w_width;
    part_of_status = true;
  } else if (is_stl_global) {
    fillchar = fillchar_status(&attr, wp);
    off = 0;
    width = Columns;
    part_of_status = true;
  } else {
    fillchar = schar_from_ascii(' ');
    attr = HL_ATTR(HLF_MSG);
    width = Columns;
    off = 0;
  }

  // In list mode virtcol needs to be recomputed
  colnr_T virtcol = wp->w_virtcol;
  if (wp->w_p_list && wp->w_p_lcs_chars.tab1 == NUL) {
    wp->w_p_list = false;
    getvvcol(wp, &wp->w_cursor, NULL, &virtcol, NULL);
    wp->w_p_list = true;
  }

#define RULER_BUF_LEN 70
  char buffer[RULER_BUF_LEN];

  // Some sprintfs return the length, some return a pointer.
  // To avoid portability problems we use strlen() here.
  vim_snprintf(buffer, RULER_BUF_LEN, "%" PRId64 ",",
               (wp->w_buffer->b_ml.ml_flags &
                ML_EMPTY) ? 0 : (int64_t)wp->w_cursor.lnum);
  size_t len = strlen(buffer);
  col_print(buffer + len, RULER_BUF_LEN - len,
            empty_line ? 0 : (int)wp->w_cursor.col + 1,
            (int)virtcol + 1);

  // Add a "50%" if there is room for it.
  // On the last line, don't print in the last column (scrolls the
  // screen up on some terminals).
  int i = (int)strlen(buffer);
  get_rel_pos(wp, buffer + i + 1, RULER_BUF_LEN - i - 1);
  int o = i + vim_strsize(buffer + i + 1);
  if (wp->w_status_height == 0 && !is_stl_global) {  // can't use last char of screen
    o++;
  }
  // Never use more than half the window/screen width, leave the other half
  // for the filename.
  int this_ru_col = MAX(ru_col - (Columns - width), (width + 1) / 2);
  if (this_ru_col + o < width) {
    // Need at least 3 chars left for get_rel_pos() + NUL.
    while (this_ru_col + o < width && RULER_BUF_LEN > i + 4) {
      i += (int)schar_get(buffer + i, fillchar);
      o++;
    }
    get_rel_pos(wp, buffer + i, RULER_BUF_LEN - i);
  }

  if (ui_has(kUIMessages) && !part_of_status) {
    MAXSIZE_TEMP_ARRAY(content, 1);
    MAXSIZE_TEMP_ARRAY(chunk, 3);
    ADD_C(chunk, INTEGER_OBJ(attr));
    ADD_C(chunk, CSTR_AS_OBJ(buffer));
    ADD_C(chunk, INTEGER_OBJ(HLF_MSG));
    assert(attr == HL_ATTR(HLF_MSG));
    ADD_C(content, ARRAY_OBJ(chunk));
    ui_call_msg_ruler(content);
    did_show_ext_ruler = true;
  } else {
    if (did_show_ext_ruler) {
      ui_call_msg_ruler((Array)ARRAY_DICT_INIT);
      did_show_ext_ruler = false;
    }
    // Truncate at window boundary.
    o = 0;
    for (i = 0; buffer[i] != NUL; i += utfc_ptr2len(buffer + i)) {
      o += utf_ptr2cells(buffer + i);
      if (this_ru_col + o > width) {
        buffer[i] = NUL;
        break;
      }
    }

    int w = grid_line_puts(off + this_ru_col, buffer, -1, attr);
    grid_line_fill(off + this_ru_col + w, off + width, fillchar, attr);
  }
}

/// Get the character to use in a status line.  Get its attributes in "*attr".
schar_T fillchar_status(int *attr, win_T *wp)
{
  if (wp == curwin) {
    *attr = win_hl_attr(wp, HLF_S);
    return wp->w_p_fcs_chars.stl;
  } else {
    *attr = win_hl_attr(wp, HLF_SNC);
    return wp->w_p_fcs_chars.stlnc;
  }
}

/// Redraw the status line according to 'statusline' and take care of any
/// errors encountered.
void redraw_custom_statusline(win_T *wp)
{
  static bool entered = false;

  // When called recursively return.  This can happen when the statusline
  // contains an expression that triggers a redraw.
  if (entered) {
    return;
  }
  entered = true;

  win_redr_custom(wp, false, false);
  entered = false;
}

static void ui_ext_tabline_update(void)
{
  Arena arena = ARENA_EMPTY;

  size_t n_tabs = 0;
  FOR_ALL_TABS(tp) {
    n_tabs++;
  }

  Array tabs = arena_array(&arena, n_tabs);
  FOR_ALL_TABS(tp) {
    Dict tab_info = arena_dict(&arena, 2);
    PUT_C(tab_info, "tab", TABPAGE_OBJ(tp->handle));

    win_T *cwp = (tp == curtab) ? curwin : tp->tp_curwin;
    get_trans_bufname(cwp->w_buffer);
    PUT_C(tab_info, "name", CSTR_TO_ARENA_OBJ(&arena, NameBuff));

    ADD_C(tabs, DICT_OBJ(tab_info));
  }

  size_t n_buffers = 0;
  FOR_ALL_BUFFERS(buf) {
    n_buffers += buf->b_p_bl ? 1 : 0;
  }

  Array buffers = arena_array(&arena, n_buffers);
  FOR_ALL_BUFFERS(buf) {
    // Do not include unlisted buffers
    if (!buf->b_p_bl) {
      continue;
    }

    Dict buffer_info = arena_dict(&arena, 2);
    PUT_C(buffer_info, "buffer", BUFFER_OBJ(buf->handle));

    get_trans_bufname(buf);
    PUT_C(buffer_info, "name", CSTR_TO_ARENA_OBJ(&arena, NameBuff));

    ADD_C(buffers, DICT_OBJ(buffer_info));
  }

  ui_call_tabline_update(curtab->handle, tabs, curbuf->handle, buffers);
  arena_mem_free(arena_finish(&arena));
}

/// Draw the tab pages line at the top of the Vim window.
void draw_tabline(void)
{
  win_T *wp;
  int attr_nosel = HL_ATTR(HLF_TP);
  int attr_fill = HL_ATTR(HLF_TPF);
  bool use_sep_chars = (t_colors < 8);

  if (default_grid.chars == NULL) {
    return;
  }
  redraw_tabline = false;

  if (ui_has(kUITabline)) {
    ui_ext_tabline_update();
    return;
  }

  if (tabline_height() < 1) {
    return;
  }

  // Clear tab_page_click_defs: Clicking outside of tabs has no effect.
  assert(tab_page_click_defs_size >= (size_t)Columns);
  stl_clear_click_defs(tab_page_click_defs, tab_page_click_defs_size);

  // Use the 'tabline' option if it's set.
  if (*p_tal != NUL) {
    win_redr_custom(NULL, false, false);
  } else {
    int tabcount = 0;
    int col = 0;
    win_T *cwp;
    int wincount;
    grid_line_start(&default_grid, 0);
    FOR_ALL_TABS(tp) {
      tabcount++;
    }

    int tabwidth = MAX(tabcount > 0 ? (Columns - 1 + tabcount / 2) / tabcount : 0, 6);

    int attr = attr_nosel;
    tabcount = 0;

    FOR_ALL_TABS(tp) {
      if (col >= Columns - 4) {
        break;
      }

      int scol = col;

      if (tp == curtab) {
        cwp = curwin;
        wp = firstwin;
      } else {
        cwp = tp->tp_curwin;
        wp = tp->tp_firstwin;
      }

      if (tp->tp_topframe == topframe) {
        attr = win_hl_attr(cwp, HLF_TPS);
      }
      if (use_sep_chars && col > 0) {
        grid_line_put_schar(col++, schar_from_ascii('|'), attr);
      }

      if (tp->tp_topframe != topframe) {
        attr = win_hl_attr(cwp, HLF_TP);
      }

      grid_line_put_schar(col++, schar_from_ascii(' '), attr);

      bool modified = false;

      for (wincount = 0; wp != NULL; wp = wp->w_next, wincount++) {
        if (bufIsChanged(wp->w_buffer)) {
          modified = true;
        }
      }

      if (modified || wincount > 1) {
        if (wincount > 1) {
          vim_snprintf(NameBuff, MAXPATHL, "%d", wincount);
          int len = (int)strlen(NameBuff);
          if (col + len >= Columns - 3) {
            break;
          }
          grid_line_puts(col, NameBuff, len,
                         hl_combine_attr(attr, win_hl_attr(cwp, HLF_T)));
          col += len;
        }
        if (modified) {
          grid_line_put_schar(col++, schar_from_ascii('+'), attr);
        }
        grid_line_put_schar(col++, schar_from_ascii(' '), attr);
      }

      int room = scol - col + tabwidth - 1;
      if (room > 0) {
        // Get buffer name in NameBuff[]
        get_trans_bufname(cwp->w_buffer);
        shorten_dir(NameBuff);
        int len = vim_strsize(NameBuff);
        char *p = NameBuff;
        while (len > room) {
          len -= ptr2cells(p);
          MB_PTR_ADV(p);
        }
        len = MIN(len, Columns - col - 1);

        grid_line_puts(col, p, -1, attr);
        col += len;
      }
      grid_line_put_schar(col++, schar_from_ascii(' '), attr);

      // Store the tab page number in tab_page_click_defs[], so that
      // jump_to_mouse() knows where each one is.
      tabcount++;
      while (scol < col) {
        tab_page_click_defs[scol++] = (StlClickDefinition) {
          .type = kStlClickTabSwitch,
          .tabnr = tabcount,
          .func = NULL,
        };
      }
    }

    for (int scol = col; scol < Columns; scol++) {
      // Use 0 as tabpage number here, so that double-click opens a tabpage
      // after the last one, and single-click goes to the next tabpage.
      tab_page_click_defs[scol] = (StlClickDefinition) {
        .type = kStlClickTabSwitch,
        .tabnr = 0,
        .func = NULL,
      };
    }

    char c = use_sep_chars ? '_' : ' ';
    grid_line_fill(col, Columns, schar_from_ascii(c), attr_fill);

    // Draw the 'showcmd' information if 'showcmdloc' == "tabline".
    if (p_sc && *p_sloc == 't') {
      const int sc_width = MIN(10, (int)Columns - col - (tabcount > 1) * 3);

      if (sc_width > 0) {
        grid_line_puts(Columns - sc_width - (tabcount > 1) * 2,
                       showcmd_buf, sc_width, attr_nosel);
      }
    }

    // Put an "X" for closing the current tab if there are several.
    if (tabcount > 1) {
      grid_line_put_schar(Columns - 1, schar_from_ascii('X'), attr_nosel);
      tab_page_click_defs[Columns - 1] = (StlClickDefinition) {
        .type = kStlClickTabClose,
        .tabnr = 999,
        .func = NULL,
      };
    }

    grid_line_flush();
  }

  // Reset the flag here again, in case evaluating 'tabline' causes it to be
  // set.
  redraw_tabline = false;
}

/// Build the 'statuscolumn' string for line "lnum". When "relnum" == -1,
/// the v:lnum and v:relnum variables don't have to be updated.
///
/// @return  The width of the built status column string for line "lnum"
int build_statuscol_str(win_T *wp, linenr_T lnum, linenr_T relnum, char *buf, statuscol_T *stcp)
{
  // Only update click definitions once per window per redraw.
  // Don't update when current width is 0, since it will be redrawn again if not empty.
  const bool fillclick = relnum >= 0 && stcp->width > 0 && lnum == wp->w_topline;

  if (relnum >= 0) {
    set_vim_var_nr(VV_LNUM, lnum);
    set_vim_var_nr(VV_RELNUM, relnum);
  }

  StlClickRecord *clickrec;
  char *stc = xstrdup(wp->w_p_stc);
  int width = build_stl_str_hl(wp, buf, MAXPATHL, stc, kOptStatuscolumn, OPT_LOCAL, 0,
                               stcp->width, &stcp->hlrec, NULL, fillclick ? &clickrec : NULL, stcp);
  xfree(stc);

  if (fillclick) {
    stl_clear_click_defs(wp->w_statuscol_click_defs, wp->w_statuscol_click_defs_size);
    wp->w_statuscol_click_defs = stl_alloc_click_defs(wp->w_statuscol_click_defs, width,
                                                      &wp->w_statuscol_click_defs_size);
    stl_fill_click_defs(wp->w_statuscol_click_defs, clickrec, buf, width, false);
  }

  return width;
}

/// Build a string from the status line items in "fmt".
/// Return length of string in screen cells.
///
/// Normally works for window "wp", except when working for 'tabline' then it
/// is "curwin".
///
/// Items are drawn interspersed with the text that surrounds it
/// Specials: %-<wid>(xxx%) => group, %= => separation marker, %< => truncation
/// Item: %-<minwid>.<maxwid><itemch> All but <itemch> are optional
///
/// If maxwidth is not zero, the string will be filled at any middle marker
/// or truncated if too long, fillchar is used for all whitespace.
///
/// @param wp  The window to build a statusline for
/// @param out  The output buffer to write the statusline to
///             Note: This should not be NameBuff
/// @param outlen  The length of the output buffer
/// @param fmt  The statusline format string
/// @param opt_idx  Index of the option corresponding to "fmt"
/// @param opt_scope  The scope corresponding to "opt_idx"
/// @param fillchar  Character to use when filling empty space in the statusline
/// @param maxwidth  The maximum width to make the statusline
/// @param hltab  HL attributes (can be NULL)
/// @param tabtab  Tab clicks definition (can be NULL)
/// @param stcp  Status column attributes (can be NULL)
///
/// @return  The final width of the statusline
int build_stl_str_hl(win_T *wp, char *out, size_t outlen, char *fmt, OptIndex opt_idx,
                     int opt_scope, schar_T fillchar, int maxwidth, stl_hlrec_t **hltab,
                     size_t *hltab_len, StlClickRecord **tabtab, statuscol_T *stcp)
{
  static size_t stl_items_len = 20;  // Initial value, grows as needed.
  static stl_item_t *stl_items = NULL;
  static int *stl_groupitems = NULL;
  static stl_hlrec_t *stl_hltab = NULL;
  static StlClickRecord *stl_tabtab = NULL;
  static int *stl_separator_locations = NULL;

#define TMPLEN 70
  char buf_tmp[TMPLEN];
  char win_tmp[TMPLEN];
  char *usefmt = fmt;
  const bool save_redraw_not_allowed = redraw_not_allowed;
  const bool save_KeyTyped = KeyTyped;
  // TODO(Bram): find out why using called_emsg_before makes tests fail, does it
  // matter?
  // const int called_emsg_before = called_emsg;
  const int did_emsg_before = did_emsg;

  // When inside update_screen() we do not want redrawing a statusline,
  // ruler, title, etc. to trigger another redraw, it may cause an endless
  // loop.
  if (updating_screen) {
    redraw_not_allowed = true;
  }

  if (stl_items == NULL) {
    stl_items = xmalloc(sizeof(stl_item_t) * stl_items_len);
    stl_groupitems = xmalloc(sizeof(int) * stl_items_len);

    // Allocate one more, because the last element is used to indicate the
    // end of the list.
    stl_hltab = xmalloc(sizeof(stl_hlrec_t) * (stl_items_len + 1));
    stl_tabtab = xmalloc(sizeof(StlClickRecord) * (stl_items_len + 1));

    stl_separator_locations = xmalloc(sizeof(int) * stl_items_len);
  }

  // If "fmt" was set insecurely it needs to be evaluated in the sandbox.
  // "opt_idx" will be kOptInvalid when caller is nvim_eval_statusline().
  const bool use_sandbox = (opt_idx != kOptInvalid) ? was_set_insecurely(wp, opt_idx, opt_scope)
                                                    : false;

  // When the format starts with "%!" then evaluate it as an expression and
  // use the result as the actual format string.
  if (fmt[0] == '%' && fmt[1] == '!') {
    typval_T tv = {
      .v_type = VAR_NUMBER,
      .vval.v_number = wp->handle,
    };
    set_var(S_LEN("g:statusline_winid"), &tv, false);

    usefmt = eval_to_string_safe(fmt + 2, use_sandbox, false);
    if (usefmt == NULL) {
      usefmt = fmt;
    }

    do_unlet(S_LEN("g:statusline_winid"), true);
  }

  if (fillchar == 0) {
    fillchar = schar_from_ascii(' ');
  }

  // The cursor in windows other than the current one isn't always
  // up-to-date, esp. because of autocommands and timers.
  linenr_T lnum = wp->w_cursor.lnum;
  if (lnum > wp->w_buffer->b_ml.ml_line_count) {
    lnum = wp->w_buffer->b_ml.ml_line_count;
    wp->w_cursor.lnum = lnum;
  }

  // Get line & check if empty (cursorpos will show "0-1").
  const char *line_ptr = ml_get_buf(wp->w_buffer, lnum);
  bool empty_line = (*line_ptr == NUL);

  // Get the byte value now, in case we need it below. This is more
  // efficient than making a copy of the line.
  int byteval;
  const colnr_T len = ml_get_buf_len(wp->w_buffer, lnum);
  if (wp->w_cursor.col > len) {
    // Line may have changed since checking the cursor column, or the lnum
    // was adjusted above.
    wp->w_cursor.col = len;
    wp->w_cursor.coladd = 0;
    byteval = 0;
  } else {
    byteval = utf_ptr2char(line_ptr + wp->w_cursor.col);
  }

  int groupdepth = 0;
  int evaldepth = 0;

  int curitem = 0;
  bool prevchar_isflag = true;
  bool prevchar_isitem = false;

  // out_p is the current position in the output buffer
  char *out_p = out;

  // out_end_p is the last valid character in the output buffer
  // Note: The null termination character must occur here or earlier,
  //       so any user-visible characters must occur before here.
  char *out_end_p = (out + outlen) - 1;

  // Proceed character by character through the statusline format string
  // fmt_p is the current position in the input buffer
  for (char *fmt_p = usefmt; *fmt_p != NUL;) {
    if (curitem == (int)stl_items_len) {
      size_t new_len = stl_items_len * 3 / 2;

      stl_items = xrealloc(stl_items, sizeof(stl_item_t) * new_len);
      stl_groupitems = xrealloc(stl_groupitems, sizeof(int) * new_len);
      stl_hltab = xrealloc(stl_hltab, sizeof(stl_hlrec_t) * (new_len + 1));
      stl_tabtab = xrealloc(stl_tabtab, sizeof(StlClickRecord) * (new_len + 1));
      stl_separator_locations =
        xrealloc(stl_separator_locations, sizeof(int) * new_len);

      stl_items_len = new_len;
    }

    if (*fmt_p != '%') {
      prevchar_isflag = prevchar_isitem = false;
    }

    // Copy the formatting verbatim until we reach the end of the string
    // or find a formatting item (denoted by `%`)
    // or run out of room in our output buffer.
    while (*fmt_p != NUL && *fmt_p != '%' && out_p < out_end_p) {
      *out_p++ = *fmt_p++;
    }

    // If we have processed the entire format string or run out of
    // room in our output buffer, exit the loop.
    if (*fmt_p == NUL || out_p >= out_end_p) {
      break;
    }

    // The rest of this loop will handle a single `%` item.
    // Note: We increment here to skip over the `%` character we are currently
    //       on so we can process the item's contents.
    fmt_p++;

    // Ignore `%` at the end of the format string
    if (*fmt_p == NUL) {
      break;
    }

    // Two `%` in a row is the escape sequence to print a
    // single `%` in the output buffer.
    if (*fmt_p == '%') {
      *out_p++ = *fmt_p++;
      prevchar_isflag = prevchar_isitem = false;
      continue;
    }

    // STL_SEPARATE: Separation between items, filled with white space.
    if (*fmt_p == STL_SEPARATE) {
      fmt_p++;
      // Ignored when we are inside of a grouping
      if (groupdepth > 0) {
        continue;
      }
      stl_items[curitem].type = Separate;
      stl_items[curitem++].start = out_p;
      continue;
    }

    // STL_TRUNCMARK: Where to begin truncating if the statusline is too long.
    if (*fmt_p == STL_TRUNCMARK) {
      fmt_p++;
      stl_items[curitem].type = Trunc;
      stl_items[curitem++].start = out_p;
      continue;
    }

    // The end of a grouping
    if (*fmt_p == ')') {
      fmt_p++;
      // Ignore if we are not actually inside a group currently
      if (groupdepth < 1) {
        continue;
      }
      groupdepth--;

      // Determine how long the group is.
      // Note: We set the current output position to null
      //       so `vim_strsize` will work.
      char *t = stl_items[stl_groupitems[groupdepth]].start;
      *out_p = NUL;
      ptrdiff_t group_len = vim_strsize(t);

      // If the group contained internal items
      // and the group did not have a minimum width,
      // and if there were no normal items in the group,
      // move the output pointer back to where the group started.
      // Note: This erases any non-item characters that were in the group.
      //       Otherwise there would be no reason to do this step.
      if (curitem > stl_groupitems[groupdepth] + 1
          && stl_items[stl_groupitems[groupdepth]].minwid == 0) {
        // remove group if all items are empty and highlight group
        // doesn't change
        int group_start_userhl = 0;
        int group_end_userhl = 0;
        int n;
        for (n = stl_groupitems[groupdepth] - 1; n >= 0; n--) {
          if (stl_items[n].type == Highlight) {
            group_start_userhl = group_end_userhl = stl_items[n].minwid;
            break;
          }
        }
        for (n = stl_groupitems[groupdepth] + 1; n < curitem; n++) {
          if (stl_items[n].type == Normal) {
            break;
          }
          if (stl_items[n].type == Highlight) {
            group_end_userhl = stl_items[n].minwid;
          }
        }
        if (n == curitem && group_start_userhl == group_end_userhl) {
          // empty group
          out_p = t;
          group_len = 0;
          for (n = stl_groupitems[groupdepth] + 1; n < curitem; n++) {
            // do not use the highlighting from the removed group
            if (stl_items[n].type == Highlight) {
              stl_items[n].type = Empty;
            }
            // adjust the start position of TabPage to the next
            // item position
            if (stl_items[n].type == TabPage) {
              stl_items[n].start = out_p;
            }
          }
        }
      }

      // If the group is longer than it is allowed to be
      // truncate by removing bytes from the start of the group text.
      if (group_len > stl_items[stl_groupitems[groupdepth]].maxwid) {
        // { Determine the number of bytes to remove

        // Find the first character that should be included.
        int n = 0;
        while (group_len >= stl_items[stl_groupitems[groupdepth]].maxwid) {
          group_len -= ptr2cells(t + n);
          n += utfc_ptr2len(t + n);
        }
        // }

        // Prepend the `<` to indicate that the output was truncated.
        *t = '<';

        // { Move the truncated output
        memmove(t + 1, t + n, (size_t)(out_p - (t + n)));
        out_p = out_p - n + 1;
        // Fill up space left over by half a double-wide char.
        while (++group_len < stl_items[stl_groupitems[groupdepth]].minwid) {
          schar_get_adv(&out_p, fillchar);
        }
        // }

        // correct the start of the items for the truncation
        for (int idx = stl_groupitems[groupdepth] + 1; idx < curitem; idx++) {
          // Shift everything back by the number of removed bytes
          // Minus one for the leading '<' added above.
          stl_items[idx].start -= n - 1;

          // If the item was partially or completely truncated, set its
          // start to the start of the group
          stl_items[idx].start = MAX(stl_items[idx].start, t);
        }
        // If the group is shorter than the minimum width, add padding characters.
      } else if (abs(stl_items[stl_groupitems[groupdepth]].minwid) > group_len) {
        ptrdiff_t min_group_width = stl_items[stl_groupitems[groupdepth]].minwid;
        // If the group is left-aligned, add characters to the right.
        if (min_group_width < 0) {
          min_group_width = 0 - min_group_width;
          while (group_len++ < min_group_width && out_p < out_end_p) {
            schar_get_adv(&out_p, fillchar);
          }
          // If the group is right-aligned, shift everything to the right and
          // prepend with filler characters.
        } else {
          // { Move the group to the right
          group_len = (min_group_width - group_len) * (int)schar_len(fillchar);
          memmove(t + group_len, t, (size_t)(out_p - t));
          if (out_p + group_len >= (out_end_p + 1)) {
            group_len = out_end_p - out_p;
          }
          out_p += group_len;
          // }

          // Adjust item start positions
          for (int n = stl_groupitems[groupdepth] + 1; n < curitem; n++) {
            stl_items[n].start += group_len;
          }

          // Prepend the fill characters
          for (; group_len > 0; group_len--) {
            schar_get_adv(&t, fillchar);
          }
        }
      }
      continue;
    }
    int minwid = 0;
    int maxwid = 9999;
    int foldsignitem = -1;        // Start of fold or sign item
    bool left_align_num = false;  // Number item for should be left-aligned
    bool left_align = false;

    // Denotes that numbers should be left-padded with zeros
    bool zeropad = (*fmt_p == '0');
    if (zeropad) {
      fmt_p++;
    }

    // Denotes that the item should be left-aligned.
    // This is tracked by using a negative length.
    if (*fmt_p == '-') {
      fmt_p++;
      left_align = true;
    }

    // The first digit group is the item's min width
    if (ascii_isdigit(*fmt_p)) {
      minwid = getdigits_int(&fmt_p, false, 0);
    }

    // User highlight groups override the min width field
    // to denote the styling to use.
    if (*fmt_p == STL_USER_HL) {
      stl_items[curitem].type = Highlight;
      stl_items[curitem].start = out_p;
      stl_items[curitem].minwid = minwid > 9 ? 1 : minwid;
      fmt_p++;
      curitem++;
      continue;
    }

    // TABPAGE pairs are used to denote a region that when clicked will
    // either switch to or close a tab.
    //
    // Ex: tabline=%1Ttab\ one%X
    //   This tabline has a TABPAGENR item with minwid `1`,
    //   which is then closed with a TABCLOSENR item.
    //   Clicking on this region with mouse enabled will switch to tab 1.
    //   Setting the minwid to a different value will switch
    //   to that tab, if it exists
    //
    // Ex: tabline=%1Xtab\ one%X
    //   This tabline has a TABCLOSENR item with minwid `1`,
    //   which is then closed with a TABCLOSENR item.
    //   Clicking on this region with mouse enabled will close tab 1.
    //
    // Note: These options are only valid when creating a tabline.
    if (*fmt_p == STL_TABPAGENR || *fmt_p == STL_TABCLOSENR) {
      if (*fmt_p == STL_TABCLOSENR) {
        if (minwid == 0) {
          // %X ends the close label, go back to the previous tab label nr.
          for (int n = curitem - 1; n >= 0; n--) {
            if (stl_items[n].type == TabPage && stl_items[n].minwid >= 0) {
              minwid = stl_items[n].minwid;
              break;
            }
          }
        } else {
          // close nrs are stored as negative values
          minwid = -minwid;
        }
      }
      stl_items[curitem].type = TabPage;
      stl_items[curitem].start = out_p;
      stl_items[curitem].minwid = minwid;
      fmt_p++;
      curitem++;
      continue;
    }

    if (*fmt_p == STL_CLICK_FUNC) {
      fmt_p++;
      char *t = fmt_p;
      while (*fmt_p != STL_CLICK_FUNC && *fmt_p) {
        fmt_p++;
      }
      if (*fmt_p != STL_CLICK_FUNC) {
        break;
      }
      stl_items[curitem].type = ClickFunc;
      stl_items[curitem].start = out_p;
      stl_items[curitem].cmd = tabtab ? xmemdupz(t, (size_t)(fmt_p - t)) : NULL;
      stl_items[curitem].minwid = minwid;
      fmt_p++;
      curitem++;
      continue;
    }

    // Denotes the end of the minwid
    // the maxwid may follow immediately after
    if (*fmt_p == '.') {
      fmt_p++;
      if (ascii_isdigit(*fmt_p)) {
        maxwid = getdigits_int(&fmt_p, false, 50);
      }
    }

    // Bound the minimum width at 50.
    // Make the number negative to denote left alignment of the item
    minwid = (minwid > 50 ? 50 : minwid) * (left_align ? -1 : 1);

    // Denotes the start of a new group
    if (*fmt_p == '(') {
      stl_groupitems[groupdepth++] = curitem;
      stl_items[curitem].type = Group;
      stl_items[curitem].start = out_p;
      stl_items[curitem].minwid = minwid;
      stl_items[curitem].maxwid = maxwid;
      fmt_p++;
      curitem++;
      continue;
    }

    // Denotes end of expanded %{} block
    if (*fmt_p == '}' && evaldepth > 0) {
      fmt_p++;
      evaldepth--;
      continue;
    }

    // An invalid item was specified.
    // Continue processing on the next character of the format string.
    if (vim_strchr(STL_ALL, (uint8_t)(*fmt_p)) == NULL) {
      if (*fmt_p == NUL) {  // can happen with "%0"
        break;
      }
      fmt_p++;
      continue;
    }

    // The status line item type
    char opt = *fmt_p++;

    // OK - now for the real work
    NumberBase base = kNumBaseDecimal;
    bool itemisflag = false;
    bool fillable = true;
    int num = -1;
    char *str = NULL;
    switch (opt) {
    case STL_FILEPATH:
    case STL_FULLPATH:
    case STL_FILENAME:
      // Set fillable to false so that ' ' in the filename will not
      // get replaced with the fillchar
      fillable = false;
      if (buf_spname(wp->w_buffer) != NULL) {
        xstrlcpy(NameBuff, buf_spname(wp->w_buffer), MAXPATHL);
      } else {
        char *t = (opt == STL_FULLPATH) ? wp->w_buffer->b_ffname
                                        : wp->w_buffer->b_fname;
        home_replace(wp->w_buffer, t, NameBuff, MAXPATHL, true);
      }
      trans_characters(NameBuff, MAXPATHL);
      if (opt != STL_FILENAME) {
        str = NameBuff;
      } else {
        str = path_tail(NameBuff);
      }
      break;
    case STL_VIM_EXPR:     // '{'
    {
      char *block_start = fmt_p - 1;
      bool reevaluate = (*fmt_p == '%');
      itemisflag = true;

      if (reevaluate) {
        fmt_p++;
      }

      // Attempt to copy the expression to evaluate into
      // the output buffer as a null-terminated string.
      char *t = out_p;
      while ((*fmt_p != '}' || (reevaluate && fmt_p[-1] != '%'))
             && *fmt_p != NUL && out_p < out_end_p) {
        *out_p++ = *fmt_p++;
      }
      if (*fmt_p != '}') {          // missing '}' or out of space
        break;
      }
      fmt_p++;
      if (reevaluate) {
        out_p[-1] = 0;  // remove the % at the end of %{% expr %}
      } else {
        *out_p = 0;
      }

      // Move our position in the output buffer
      // to the beginning of the expression
      out_p = t;

      // { Evaluate the expression

      // Store the current buffer number as a string variable
      vim_snprintf(buf_tmp, sizeof(buf_tmp), "%d", curbuf->b_fnum);
      set_internal_string_var("g:actual_curbuf", buf_tmp);
      vim_snprintf(win_tmp, sizeof(win_tmp), "%d", curwin->handle);
      set_internal_string_var("g:actual_curwin", win_tmp);

      buf_T *const save_curbuf = curbuf;
      win_T *const save_curwin = curwin;
      const int save_VIsual_active = VIsual_active;
      curwin = wp;
      curbuf = wp->w_buffer;
      // Visual mode is only valid in the current window.
      if (curwin != save_curwin) {
        VIsual_active = false;
      }

      // Note: The result stored in `t` is unused.
      str = eval_to_string_safe(out_p, use_sandbox, false);

      curwin = save_curwin;
      curbuf = save_curbuf;
      VIsual_active = save_VIsual_active;

      // Remove the variable we just stored
      do_unlet(S_LEN("g:actual_curbuf"), true);
      do_unlet(S_LEN("g:actual_curwin"), true);

      // }

      // Check if the evaluated result is a number.
      // If so, convert the number to an int and free the string.
      if (str != NULL && *str != 0) {
        if (*skipdigits(str) == NUL) {
          num = atoi(str);
          XFREE_CLEAR(str);
          itemisflag = false;
        }
      }

      // If the output of the expression needs to be evaluated
      // replace the %{} block with the result of evaluation
      if (reevaluate && str != NULL && *str != 0
          && strchr(str, '%') != NULL
          && evaldepth < MAX_STL_EVAL_DEPTH) {
        size_t parsed_usefmt = (size_t)(block_start - usefmt);
        size_t str_length = strlen(str);
        size_t fmt_length = strlen(fmt_p);
        size_t new_fmt_len = parsed_usefmt + str_length + fmt_length + 3;
        char *new_fmt = xmalloc(new_fmt_len * sizeof(char));
        char *new_fmt_p = new_fmt;

        new_fmt_p = (char *)memcpy(new_fmt_p, usefmt, parsed_usefmt) + parsed_usefmt;
        new_fmt_p = (char *)memcpy(new_fmt_p, str, str_length) + str_length;
        new_fmt_p = (char *)memcpy(new_fmt_p, "%}", 2) + 2;
        new_fmt_p = (char *)memcpy(new_fmt_p, fmt_p, fmt_length) + fmt_length;
        *new_fmt_p = 0;
        new_fmt_p = NULL;

        if (usefmt != fmt) {
          xfree(usefmt);
        }
        XFREE_CLEAR(str);
        usefmt = new_fmt;
        fmt_p = usefmt + parsed_usefmt;
        evaldepth++;
        continue;
      }
      break;
    }

    case STL_LINE:
      // Overload %l with v:(re)lnum for 'statuscolumn'. Place a sign when 'signcolumn'
      // is set to "number". Take care of alignment for 'number' + 'relativenumber'.
      if (stcp != NULL && (wp->w_p_nu || wp->w_p_rnu) && get_vim_var_nr(VV_VIRTNUM) == 0) {
        if (wp->w_maxscwidth == SCL_NUM && stcp->sattrs[0].text[0]) {
          goto stcsign;
        }
        int relnum = (int)get_vim_var_nr(VV_RELNUM);
        num = (!wp->w_p_rnu || (wp->w_p_nu && relnum == 0)) ? (int)get_vim_var_nr(VV_LNUM) : relnum;
        left_align_num = wp->w_p_rnu && wp->w_p_nu && relnum == 0;
        if (!left_align_num) {
          stl_items[curitem].type = Separate;
          stl_items[curitem++].start = out_p;
        }
      } else if (stcp == NULL) {
        num = (wp->w_buffer->b_ml.ml_flags & ML_EMPTY) ? 0 : wp->w_cursor.lnum;
      }
      break;

    case STL_NUMLINES:
      num = wp->w_buffer->b_ml.ml_line_count;
      break;

    case STL_COLUMN:
      num = (State & MODE_INSERT) == 0 && empty_line ? 0 : (int)wp->w_cursor.col + 1;
      break;

    case STL_VIRTCOL:
    case STL_VIRTCOL_ALT: {
      colnr_T virtcol = wp->w_virtcol + 1;
      // Don't display %V if it's the same as %c.
      if (opt == STL_VIRTCOL_ALT
          && (virtcol == (colnr_T)((State & MODE_INSERT) == 0 && empty_line
                                   ? 0 : (int)wp->w_cursor.col + 1))) {
        break;
      }
      num = virtcol;
      break;
    }

    case STL_PERCENTAGE:
      num = ((wp->w_cursor.lnum * 100) / wp->w_buffer->b_ml.ml_line_count);
      break;

    case STL_ALTPERCENT:
      // Store the position percentage in our temporary buffer.
      // Note: We cannot store the value in `num` because
      //       `get_rel_pos` can return a named position. Ex: "Top"
      get_rel_pos(wp, buf_tmp, TMPLEN);
      str = buf_tmp;
      break;

    case STL_SHOWCMD:
      if (p_sc && (opt_idx == kOptInvalid || find_option(p_sloc) == opt_idx)) {
        str = showcmd_buf;
      }
      break;

    case STL_ARGLISTSTAT:
      fillable = false;

      // Note: This is important because `append_arg_number` starts appending
      //       at the end of the null-terminated string.
      //       Setting the first byte to null means it will place the argument
      //       number string at the beginning of the buffer.
      buf_tmp[0] = 0;

      // Note: The call will only return true if it actually
      //       appended data to the `buf_tmp` buffer.
      if (append_arg_number(wp, buf_tmp, (int)sizeof(buf_tmp))) {
        str = buf_tmp;
      }
      break;

    case STL_KEYMAP:
      fillable = false;
      if (get_keymap_str(wp, "<%s>", buf_tmp, TMPLEN)) {
        str = buf_tmp;
      }
      break;
    case STL_PAGENUM:
      num = 0;
      break;

    case STL_BUFNO:
      num = wp->w_buffer->b_fnum;
      break;

    case STL_OFFSET_X:
      base = kNumBaseHexadecimal;
      FALLTHROUGH;
    case STL_OFFSET: {
      int l = ml_find_line_or_offset(wp->w_buffer, wp->w_cursor.lnum, NULL,
                                     false);
      num = (wp->w_buffer->b_ml.ml_flags & ML_EMPTY) || l < 0
            ? 0 : l + 1 + ((State & MODE_INSERT) == 0 && empty_line
                           ? 0 : (int)wp->w_cursor.col);
      break;
    }
    case STL_BYTEVAL_X:
      base = kNumBaseHexadecimal;
      FALLTHROUGH;
    case STL_BYTEVAL:
      num = byteval;
      if (num == NL) {
        num = 0;
      } else if (num == CAR && get_fileformat(wp->w_buffer) == EOL_MAC) {
        num = NL;
      }
      break;

    case STL_ROFLAG:
    case STL_ROFLAG_ALT:
      itemisflag = true;
      if (wp->w_buffer->b_p_ro) {
        str = (opt == STL_ROFLAG_ALT) ? ",RO" : _("[RO]");
      }
      break;

    case STL_HELPFLAG:
    case STL_HELPFLAG_ALT:
      itemisflag = true;
      if (wp->w_buffer->b_help) {
        str = (opt == STL_HELPFLAG_ALT) ? ",HLP" : _("[Help]");
      }
      break;

    case STL_FOLDCOL:    // 'C' for 'statuscolumn'
    case STL_SIGNCOL: {  // 's' for 'statuscolumn'
stcsign:
      if (stcp == NULL) {
        break;
      }
      int fdc = opt == STL_FOLDCOL ? compute_foldcolumn(wp, 0) : 0;
      int width = opt == STL_FOLDCOL ? fdc > 0 : opt == STL_SIGNCOL ? wp->w_scwidth : 1;

      if (width <= 0) {
        break;
      }
      foldsignitem = curitem;

      if (fdc > 0) {
        schar_T fold_buf[9];
        fill_foldcolumn(wp, stcp->foldinfo, (linenr_T)get_vim_var_nr(VV_LNUM),
                        0, fdc, NULL, fold_buf);
        stl_items[curitem].minwid = -(stcp->use_cul ? HLF_CLF : HLF_FC);
        size_t buflen = 0;
        // TODO(bfredl): this is very backwards. we must support schar_T
        // being used directly in 'statuscolumn'
        for (int i = 0; i < fdc; i++) {
          buflen += schar_get(buf_tmp + buflen, fold_buf[i]);
        }
      }

      size_t signlen = 0;
      for (int i = 0; i < width; i++) {
        stl_items[curitem].start = out_p + signlen;
        if (fdc == 0) {
          if (stcp->sattrs[i].text[0] && get_vim_var_nr(VV_VIRTNUM) == 0) {
            SignTextAttrs sattrs = stcp->sattrs[i];
            signlen += describe_sign_text(buf_tmp + signlen, sattrs.text);
            stl_items[curitem].minwid = -(stcp->sign_cul_id ? stcp->sign_cul_id : sattrs.hl_id);
          } else {
            buf_tmp[signlen++] = ' ';
            buf_tmp[signlen++] = ' ';
            buf_tmp[signlen] = NUL;
            stl_items[curitem].minwid = -(stcp->use_cul ? HLF_CLS : HLF_SC);
          }
        }
        stl_items[curitem++].type = Highlight;
      }
      str = buf_tmp;
      break;
    }

    case STL_FILETYPE:
      // Copy the filetype if it is not null and the formatted string will fit
      // in the temporary buffer
      // (including the brackets and null terminating character)
      if (*wp->w_buffer->b_p_ft != NUL
          && strlen(wp->w_buffer->b_p_ft) < TMPLEN - 3) {
        vim_snprintf(buf_tmp, sizeof(buf_tmp), "[%s]",
                     wp->w_buffer->b_p_ft);
        str = buf_tmp;
      }
      break;

    case STL_FILETYPE_ALT:
      itemisflag = true;
      // Copy the filetype if it is not null and the formatted string will fit
      // in the temporary buffer
      // (including the comma and null terminating character)
      if (*wp->w_buffer->b_p_ft != NUL
          && strlen(wp->w_buffer->b_p_ft) < TMPLEN - 2) {
        vim_snprintf(buf_tmp, sizeof(buf_tmp), ",%s", wp->w_buffer->b_p_ft);
        // Uppercase the file extension
        for (char *t = buf_tmp; *t != 0; t++) {
          *t = (char)TOUPPER_LOC((uint8_t)(*t));
        }
        str = buf_tmp;
      }
      break;
    case STL_PREVIEWFLAG:
    case STL_PREVIEWFLAG_ALT:
      itemisflag = true;
      if (wp->w_p_pvw) {
        str = (opt == STL_PREVIEWFLAG_ALT) ? ",PRV" : _("[Preview]");
      }
      break;

    case STL_QUICKFIX:
      if (bt_quickfix(wp->w_buffer)) {
        str = wp->w_llist_ref ? _(msg_loclist) : _(msg_qflist);
      }
      break;

    case STL_MODIFIED:
    case STL_MODIFIED_ALT:
      itemisflag = true;
      switch ((opt == STL_MODIFIED_ALT)
              + bufIsChanged(wp->w_buffer) * 2
              + (!MODIFIABLE(wp->w_buffer)) * 4) {
      case 2:
        str = "[+]"; break;
      case 3:
        str = ",+"; break;
      case 4:
        str = "[-]"; break;
      case 5:
        str = ",-"; break;
      case 6:
        str = "[+-]"; break;
      case 7:
        str = ",+-"; break;
      }
      break;

    case STL_HIGHLIGHT: {
      // { The name of the highlight is surrounded by `#`
      char *t = fmt_p;
      while (*fmt_p != '#' && *fmt_p != NUL) {
        fmt_p++;
      }
      // }

      // Create a highlight item based on the name
      if (*fmt_p == '#') {
        stl_items[curitem].type = Highlight;
        stl_items[curitem].start = out_p;
        stl_items[curitem].minwid = -syn_name2id_len(t, (size_t)(fmt_p - t));
        curitem++;
        fmt_p++;
      }
      continue;
    }
    }

    // If we made it this far, the item is normal and starts at
    // our current position in the output buffer.
    // Non-normal items would have `continued`.
    stl_items[curitem].start = out_p;
    stl_items[curitem].type = Normal;

    // Copy the item string into the output buffer
    if (str != NULL && *str) {
      // { Skip the leading `,` or ` ` if the item is a flag
      //  and the proper conditions are met
      char *t = str;
      if (itemisflag) {
        if ((t[0] && t[1])
            && ((!prevchar_isitem && *t == ',')
                || (prevchar_isflag && *t == ' '))) {
          t++;
        }
        prevchar_isflag = true;
      }
      // }

      int l = vim_strsize(t);

      // If this item is non-empty, record that the last thing
      // we put in the output buffer was an item
      if (l > 0) {
        prevchar_isitem = true;
      }

      // If the item is too wide, truncate it from the beginning
      if (l > maxwid) {
        while (l >= maxwid) {
          l -= ptr2cells(t);
          t += utfc_ptr2len(t);
        }

        // Early out if there isn't enough room for the truncation marker
        if (out_p >= out_end_p) {
          break;
        }

        // Add the truncation marker
        *out_p++ = '<';
      }

      // If the item is right aligned and not wide enough,
      // pad with fill characters.
      if (minwid > 0) {
        for (; l < minwid && out_p < out_end_p; l++) {
          // Don't put a "-" in front of a digit.
          if (l + 1 == minwid && fillchar == '-' && ascii_isdigit(*t)) {
            *out_p++ = ' ';
          } else {
            schar_get_adv(&out_p, fillchar);
          }
        }
        minwid = 0;
        // For a 'statuscolumn' sign or fold item, shift the added items
        if (foldsignitem >= 0) {
          ptrdiff_t offset = out_p - stl_items[foldsignitem].start;
          for (int i = foldsignitem; i < curitem; i++) {
            stl_items[i].start += offset;
          }
        }
      } else {
        // Note: The negative value denotes a left aligned item.
        //       Here we switch the minimum width back to a positive value.
        minwid *= -1;
      }

      // { Copy the string text into the output buffer
      for (; *t && out_p < out_end_p; t++) {
        // Change a space by fillchar, unless fillchar is '-' and a
        // digit follows.
        if (fillable && *t == ' '
            && (!ascii_isdigit(*(t + 1)) || fillchar != '-')) {
          schar_get_adv(&out_p, fillchar);
        } else {
          *out_p++ = *t;
        }
      }
      // }

      // For a 'statuscolumn' sign or fold item, add an item to reset the highlight group
      if (foldsignitem >= 0) {
        stl_items[curitem].type = Highlight;
        stl_items[curitem].start = out_p;
        stl_items[curitem].minwid = 0;
      }

      // For left-aligned items, fill any remaining space with the fillchar
      for (; l < minwid && out_p < out_end_p; l++) {
        schar_get_adv(&out_p, fillchar);
      }

      // Otherwise if the item is a number, copy that to the output buffer.
    } else if (num >= 0) {
      if (out_p + 20 > out_end_p) {
        break;                  // not sufficient space
      }
      prevchar_isitem = true;

      // { Build the formatting string
      char nstr[20];
      char *t = nstr;
      if (opt == STL_VIRTCOL_ALT) {
        *t++ = '-';
        minwid--;
      }
      *t++ = '%';
      if (zeropad) {
        *t++ = '0';
      }

      // Note: The `*` means we take the width as one of the arguments
      *t++ = '*';
      *t++ = base == kNumBaseHexadecimal ? 'X' : 'd';
      *t = 0;
      // }

      // { Determine how many characters the number will take up when printed
      //  Note: We have to cast the base because the compiler uses
      //        unsigned ints for the enum values.
      int num_chars = 1;
      for (int n = num; n >= (int)base; n /= (int)base) {
        num_chars++;
      }

      // VIRTCOL_ALT takes up an extra character because
      // of the `-` we added above.
      if (opt == STL_VIRTCOL_ALT) {
        num_chars++;
      }
      // }

      assert(out_end_p >= out_p);
      size_t remaining_buf_len = (size_t)(out_end_p - out_p) + 1;

      // If the number is going to take up too much room
      // Figure out the approximate number in "scientific" type notation.
      // Ex: 14532 with maxwid of 4 -> '14>3'
      if (num_chars > maxwid) {
        // Add two to the width because the power piece will take
        // two extra characters
        num_chars += 2;

        // How many extra characters there are
        int n = num_chars - maxwid;

        // { Reduce the number by base^n
        while (num_chars-- > maxwid) {
          num /= (int)base;
        }
        // }

        // { Add the format string for the exponent bit
        *t++ = '>';
        *t++ = '%';
        // Use the same base as the first number
        *t = t[-3];
        *++t = 0;
        // }

        vim_snprintf(out_p, remaining_buf_len, nstr, 0, num, n);
      } else {
        vim_snprintf(out_p, remaining_buf_len, nstr, minwid, num);
      }

      // Advance the output buffer position to the end of the
      // number we just printed
      out_p += strlen(out_p);

      // Otherwise, there was nothing to print so mark the item as empty
    } else {
      stl_items[curitem].type = Empty;
    }

    if (num >= 0 || (!itemisflag && str && *str)) {
      prevchar_isflag = false;              // Item not NULL, but not a flag
    }

    // Only free the string buffer if we allocated it.
    // Note: This is not needed if `str` is pointing at `tmp`
    if (opt == STL_VIM_EXPR) {
      XFREE_CLEAR(str);
    }

    // Item processed, move to the next
    curitem++;
    // For a 'statuscolumn' number item that is left aligned, add a separator item.
    if (left_align_num) {
      stl_items[curitem].type = Separate;
      stl_items[curitem++].start = out_p;
    }
  }

  *out_p = NUL;
  int itemcnt = curitem;

  // Free the format buffer if we allocated it internally
  if (usefmt != fmt) {
    xfree(usefmt);
  }

  // We have now processed the entire statusline format string.
  // What follows is post-processing to handle alignment and highlighting.

  int width = vim_strsize(out);
  if (maxwidth > 0 && width > maxwidth && (!stcp || width > MAX_STCWIDTH)) {
    // Result is too long, must truncate somewhere.
    int item_idx = 0;
    char *trunc_p;

    // If there are no items, truncate from beginning
    if (itemcnt == 0) {
      trunc_p = out;

      // Otherwise, look for the truncation item
    } else {
      // Default to truncating at the first item
      trunc_p = stl_items[0].start;
      item_idx = 0;

      for (int i = 0; i < itemcnt; i++) {
        if (stl_items[i].type == Trunc) {
          // Truncate at %< stl_items.
          trunc_p = stl_items[i].start;
          item_idx = i;
          break;
        }
      }
    }

    // If the truncation point we found is beyond the maximum
    // length of the string, truncate the end of the string.
    if (width - vim_strsize(trunc_p) >= maxwidth) {
      // Walk from the beginning of the
      // string to find the last character that will fit.
      trunc_p = out;
      width = 0;
      while (true) {
        width += ptr2cells(trunc_p);
        if (width >= maxwidth) {
          break;
        }

        // Note: Only advance the pointer if the next
        //       character will fit in the available output space
        trunc_p += utfc_ptr2len(trunc_p);
      }

      // Ignore any items in the statusline that occur after
      // the truncation point
      for (int i = 0; i < itemcnt; i++) {
        if (stl_items[i].start > trunc_p) {
          for (int j = i; j < itemcnt; j++) {
            if (stl_items[j].type == ClickFunc) {
              XFREE_CLEAR(stl_items[j].cmd);
            }
          }
          itemcnt = i;
          break;
        }
      }

      // Truncate the output
      *trunc_p++ = '>';
      *trunc_p = 0;

      // Truncate at the truncation point we found
    } else {
      // { Determine how many bytes to remove
      int trunc_len = 0;
      while (width >= maxwidth) {
        width -= ptr2cells(trunc_p + trunc_len);
        trunc_len += utfc_ptr2len(trunc_p + trunc_len);
      }
      // }

      // { Truncate the string
      char *trunc_end_p = trunc_p + trunc_len;
      STRMOVE(trunc_p + 1, trunc_end_p);

      // Put a `<` to mark where we truncated at
      *trunc_p = '<';
      // }

      // { Change the start point for items based on
      //  their position relative to our truncation point

      // Note: The offset is one less than the truncation length because
      //       the truncation marker `<` is not counted.
      int item_offset = trunc_len - 1;

      for (int i = item_idx; i < itemcnt; i++) {
        // Items starting at or after the end of the truncated section need
        // to be moved backwards.
        if (stl_items[i].start >= trunc_end_p) {
          stl_items[i].start -= item_offset;
        } else {
          // Anything inside the truncated area is set to start
          // at the `<` truncation character.
          stl_items[i].start = trunc_p;
        }
      }
      // }

      if (width + 1 < maxwidth) {
        // Advance the pointer to the end of the string
        trunc_p = trunc_p + strlen(trunc_p);
      }

      // Fill up for half a double-wide character.
      while (++width < maxwidth) {
        schar_get_adv(&trunc_p, fillchar);
      }
    }
    width = maxwidth;

    // If there is room left in our statusline, and room left in our buffer,
    // add characters at the separate marker (if there is one) to
    // fill up the available space.
  } else if (width < maxwidth
             && strlen(out) + (size_t)(maxwidth - width) + 1 < outlen) {
    // Find how many separators there are, which we will use when
    // figuring out how many groups there are.
    int num_separators = 0;
    for (int i = 0; i < itemcnt; i++) {
      if (stl_items[i].type == Separate) {
        // Create an array of the start location for each separator mark.
        stl_separator_locations[num_separators] = i;
        num_separators++;
      }
    }

    // If we have separated groups, then we deal with it now
    if (num_separators) {
      int standard_spaces = (maxwidth - width) / num_separators;
      int final_spaces = (maxwidth - width) -
                         standard_spaces * (num_separators - 1);

      for (int l = 0; l < num_separators; l++) {
        int dislocation = (l == (num_separators - 1)) ? final_spaces : standard_spaces;
        dislocation *= (int)schar_len(fillchar);
        char *start = stl_items[stl_separator_locations[l]].start;
        char *seploc = start + dislocation;
        STRMOVE(seploc, start);
        for (char *s = start; s < seploc;) {
          schar_get_adv(&s, fillchar);
        }

        for (int item_idx = stl_separator_locations[l] + 1;
             item_idx < itemcnt;
             item_idx++) {
          stl_items[item_idx].start += dislocation;
        }
      }

      width = maxwidth;
    }
  }

  // Store the info about highlighting.
  if (hltab != NULL) {
    *hltab = stl_hltab;
    stl_hlrec_t *sp = stl_hltab;
    for (int l = 0; l < itemcnt; l++) {
      if (stl_items[l].type == Highlight) {
        sp->start = stl_items[l].start;
        sp->userhl = stl_items[l].minwid;
        sp++;
      }
    }
    sp->start = NULL;
    sp->userhl = 0;
  }
  if (hltab_len) {
    *hltab_len = (size_t)itemcnt;
  }

  // Store the info about tab pages labels.
  if (tabtab != NULL) {
    *tabtab = stl_tabtab;
    StlClickRecord *cur_tab_rec = stl_tabtab;
    for (int l = 0; l < itemcnt; l++) {
      if (stl_items[l].type == TabPage) {
        cur_tab_rec->start = stl_items[l].start;
        if (stl_items[l].minwid == 0) {
          cur_tab_rec->def.type = kStlClickDisabled;
          cur_tab_rec->def.tabnr = 0;
        } else {
          int tabnr = stl_items[l].minwid;
          if (stl_items[l].minwid > 0) {
            cur_tab_rec->def.type = kStlClickTabSwitch;
          } else {
            cur_tab_rec->def.type = kStlClickTabClose;
            tabnr = -tabnr;
          }
          cur_tab_rec->def.tabnr = tabnr;
        }
        cur_tab_rec->def.func = NULL;
        cur_tab_rec++;
      } else if (stl_items[l].type == ClickFunc) {
        cur_tab_rec->start = stl_items[l].start;
        cur_tab_rec->def.type = kStlClickFuncRun;
        cur_tab_rec->def.tabnr = stl_items[l].minwid;
        cur_tab_rec->def.func = stl_items[l].cmd;
        cur_tab_rec++;
      }
    }
    cur_tab_rec->start = NULL;
    cur_tab_rec->def.type = kStlClickDisabled;
    cur_tab_rec->def.tabnr = 0;
    cur_tab_rec->def.func = NULL;
  }

  redraw_not_allowed = save_redraw_not_allowed;

  // Check for an error.  If there is one the display will be messed up and
  // might loop redrawing.  Avoid that by making the corresponding option
  // empty.
  // TODO(Bram): find out why using called_emsg_before makes tests fail, does it
  // matter?
  // if (called_emsg > called_emsg_before)
  if (opt_idx != kOptInvalid && did_emsg > did_emsg_before) {
    set_option_direct(opt_idx, STATIC_CSTR_AS_OPTVAL(""), opt_scope, SID_ERROR);
  }

  // A user function may reset KeyTyped, restore it.
  KeyTyped = save_KeyTyped;

  return width;
}
