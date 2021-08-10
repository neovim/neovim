// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// plines.c: functions that calculate the vertical and horizontal size of text

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/plines.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/func_attr.h"
#include "nvim/fold.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/window.h"
#include "nvim/buffer.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "plines.c.generated.h"
#endif


/// @param winheight when true limit to window height
int plines_win(win_T *wp, linenr_T lnum, bool winheight)
{
  // Check for filler lines above this buffer line.  When folded the result
  // is one line anyway.
  return plines_win_nofill(wp, lnum, winheight) + diff_check_fill(wp, lnum);
}

/// @param winheight when true limit to window height
int plines_win_nofill(win_T *wp, linenr_T lnum, bool winheight)
{
  if (!wp->w_p_wrap) {
    return 1;
  }

  if (wp->w_width_inner == 0) {
    return 1;
  }

  // A folded lines is handled just like an empty line.
  if (lineFolded(wp, lnum)) {
    return 1;
  }

  const int lines = plines_win_nofold(wp, lnum);
  if (winheight && lines > wp->w_height_inner) {
    return wp->w_height_inner;
  }
  return lines;
}

/// @Return number of window lines physical line "lnum" will occupy in window
/// "wp".  Does not care about folding, 'wrap' or 'diff'.
int plines_win_nofold(win_T *wp, linenr_T lnum)
{
  char_u      *s;
  unsigned int col;
  int width;

  s = ml_get_buf(wp->w_buffer, lnum, false);
  if (*s == NUL) {  // empty line
    return 1;
  }
  col = win_linetabsize(wp, s, MAXCOL);

  // If list mode is on, then the '$' at the end of the line may take up one
  // extra column.
  if (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) {
    col += 1;
  }

  // Add column offset for 'number', 'relativenumber' and 'foldcolumn'.
  width = wp->w_width_inner - win_col_off(wp);
  if (width <= 0 || col > 32000) {
    return 32000;  // bigger than the number of screen columns
  }
  if (col <= (unsigned int)width) {
    return 1;
  }
  col -= (unsigned int)width;
  width += win_col_off2(wp);
  assert(col <= INT_MAX && (int)col < INT_MAX - (width -1));
  return ((int)col + (width - 1)) / width + 1;
}

/// Like plines_win(), but only reports the number of physical screen lines
/// used from the start of the line to the given column number.
int plines_win_col(win_T *wp, linenr_T lnum, long column)
{
  // Check for filler lines above this buffer line.  When folded the result
  // is one line anyway.
  int lines = diff_check_fill(wp, lnum);

  if (!wp->w_p_wrap) {
    return lines + 1;
  }

  if (wp->w_width_inner == 0) {
    return lines + 1;
  }

  char_u *line = ml_get_buf(wp->w_buffer, lnum, false);
  char_u *s = line;

  colnr_T col = 0;
  while (*s != NUL && --column >= 0) {
    col += win_lbr_chartabsize(wp, line, s, col, NULL);
    MB_PTR_ADV(s);
  }

  // If *s is a TAB, and the TAB is not displayed as ^I, and we're not in
  // INSERT mode, then col must be adjusted so that it represents the last
  // screen position of the TAB.  This only fixes an error when the TAB wraps
  // from one screen line to the next (when 'columns' is not a multiple of
  // 'ts') -- webb.
  if (*s == TAB && (State & NORMAL)
      && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    col += win_lbr_chartabsize(wp, line, s, col, NULL) - 1;
  }

  // Add column offset for 'number', 'relativenumber', 'foldcolumn', etc.
  int width = wp->w_width_inner - win_col_off(wp);
  if (width <= 0) {
    return 9999;
  }

  lines += 1;
  if (col > width) {
    lines += (col - width) / (width + win_col_off2(wp)) + 1;
  }
  return lines;
}

/// Get the number of screen lines lnum takes up. This takes care of
/// both folds and topfill, and limits to the current window height.
///
/// @param[in]  wp       window line is in
/// @param[in]  lnum     line number
/// @param[out] nextp    if not NULL, the line after a fold
/// @param[out] foldedp  if not NULL, whether lnum is on a fold
/// @param[in]  cache    whether to use the window's cache for folds
///
/// @return the total number of screen lines
int plines_win_full(win_T *wp, linenr_T lnum, linenr_T *const nextp,
                    bool *const foldedp, const bool cache)
{
  bool folded = hasFoldingWin(wp, lnum, NULL, nextp, cache, NULL);
  if (foldedp) {
    *foldedp = folded;
  }
  if (folded) {
    return 1;
  } else if (lnum == wp->w_topline) {
    return plines_win_nofill(wp, lnum, true) + wp->w_topfill;
  }
  return plines_win(wp, lnum, true);
}

int plines_m_win(win_T *wp, linenr_T first, linenr_T last)
{
  int count = 0;

  while (first <= last) {
    linenr_T next = first;
    count += plines_win_full(wp, first, &next, NULL, false);
    first = next + 1;
  }
  return count;
}
