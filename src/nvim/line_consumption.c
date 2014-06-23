/// @file
///
/// Functions to determine physical line consumption of real lines
///
/// Throughout this file the terminology is:
/// - physical line: the amount of lines on the screen.
/// - real line: text in a file between two newline characters
///
///
/// There are several situations where a real line can take up several lines on
/// screen. This is especially true if the 'wrap' option is activated.
///
/// The contrary, several real lines consuming less physical lines on the screen
/// becomes true if 'folding' is used.
///
/// This file provides functions that determine the amount of physical lines
/// used by real lines, considering these factors.

#include "nvim/vim.h"
#include "nvim/buffer_defs.h"
#include "nvim/diff.h"
#include "nvim/fold.h"
#include "nvim/memline.h"
#include "nvim/charset.h"
#include "nvim/move.h"
#include "nvim/line_consumption.h"
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "line_consumption.c.generated.h"
#endif

/// Gets the physical line count consumed by a real line in current window
///
/// @param lnum Line number of buffer
///
/// @return The physical line count
size_t plines(linenr_T lnum)
{
  return plines_win(curwin, lnum, true);
}

/// Gets the physical line count consumed by a real line in a window
///
/// @param wp The window handle
/// @param lnum The real line to check
/// @param winheight when true limit to window height
///
/// @return The physical line count
size_t plines_win(win_T *wp, linenr_T lnum, bool winheight)
{
  // Check for filler lines above this buffer line.  When folded the result
  // is one line anyway.
  return plines_win_nofill(wp, lnum, winheight)
         + (size_t)diff_check_fill(wp, lnum);
}

/// Gets the physical line count in current window, ignoring filler lines
///
/// Gets the physical line count consumed by a real line in the current window
/// without considering filler lines
///
/// @param lnum The real line
///
/// @return The physical line count
size_t plines_nofill(linenr_T lnum)
{
  return plines_win_nofill(curwin, lnum, true);
}

/// Gets the physical line count ignoring filler lines
///
/// Gets the physical line count consumed by a real line in a window ignoring
/// filler lines
///
/// @remark Note: Caller must handle lines that are MAYBE folded.
///
/// @param wp The window handle
/// @param lnum The real line to check
/// @param winheight when true limit to window height
///
/// @return The physical line count
size_t plines_win_nofill(win_T *wp, linenr_T lnum, bool winheight)
{
  if (!wp->w_p_wrap) {
    return 1;
  }

  if (wp->w_width == 0) {
    return 1;
  }

  // A folded lines is handled just like an empty line.
  if (lineFolded(wp, lnum) == true) {
    return 1;
  }

  size_t lines = plines_win_nofold(wp, lnum);
  if (winheight && lines > (size_t)wp->w_height) {
    return (size_t)wp->w_height;
  }

  return lines;
}

/// Gets the physical line count, ignoring 'folding', 'wrap' and 'diff'
///
/// Gets the physical line count of a real line in a window, ignoring 'folding',
/// 'wrap' and 'diff'
///
/// @param wp The window handle
/// @param lnum The real line to check
///
/// @return The physical line count
size_t plines_win_nofold(win_T *wp, linenr_T lnum)
{
  char_u *s = ml_get_buf(wp->w_buffer, lnum, false);
  if (*s == NUL) {  // empty line
    return 1;
  }

  colnr_T col = win_linetabsize(wp, s, (colnr_T)MAXCOL);

  // If list mode is on, then the '$' at the end of the line may take up one
  // extra column.
  if (wp->w_p_list && lcs_eol != NUL)
    col += 1;

  // Add column offset for 'number', 'relativenumber' and 'foldcolumn'.
  int width = wp->w_width - win_col_off(wp);
  if (width <= 0) {
    return 32000;
  }

  if (col <= width) {
    return 1;
  }

  col -= width;
  width += win_col_off2(wp);
  return (size_t)((col + (width - 1)) / width + 1);  // width cannot be negative
}

/// Gets physical line count consumed by a real line up to a certain column
///
/// Gets the physical line count consumed by a real line in a window up to a
/// certain column of that real line.
///
/// @param wp The window handle
/// @para lnum The real line to check
/// @param column Limits the check of line to this column of the real line
///
/// @return The physical line count
size_t plines_win_col(win_T *wp, linenr_T lnum, colnr_T column)
{
  // Check for filler lines above this buffer line. When folded the result is
  // one line anyway.
  size_t lines = (size_t)diff_check_fill(wp, lnum);

  if (!wp->w_p_wrap) {
    return lines + 1;
  }

  if (wp->w_width == 0) {
    return lines + 1;
  }

  char_u *s = ml_get_buf(wp->w_buffer, lnum, false);

  colnr_T col = 0;
  while (*s != NUL && --column >= 0) {
    col += win_lbr_chartabsize(wp, s, col, NULL);
    mb_ptr_adv(s);
  }

  // If *s is a TAB, and the TAB is not displayed as ^I, and we're not in
  // INSERT mode, then col must be adjusted so that it represents the last
  // screen position of the TAB.  This only fixes an error when the TAB wraps
  // from one screen line to the next (when 'columns' is not a multiple of
  // 'ts') -- webb.
  if (*s == TAB && (State & NORMAL) && (!wp->w_p_list || lcs_tab1)) {
    col += win_lbr_chartabsize(wp, s, col, NULL) - 1;
  }

  // Add column offset for 'number', 'relativenumber', 'foldcolumn', etc.
  int width = wp->w_width - win_col_off(wp);
  if (width <= 0) {
    return 9999;
  }

  lines += 1;
  if (col > width) {  // cast is not dangerous because col > width
    lines += (size_t)((col - width) / (width + win_col_off2(wp)) + 1);
  }
  return lines;
}

/// Gets physical line count of a range of real lines in a window
///
/// Gets the physical line count consumed by a range of real lines in a window
///
/// @param wp The window handle
/// @param first The first line of the range
/// @param last The last line of the range
/// @return The physical line count
size_t plines_m_win(win_T *wp, linenr_T first, linenr_T last)
{
  size_t count = 0;

  while (first <= last) {
    // Check if there are any really folded lines, but also included lines that
    // are maybe folded.
    linenr_T x = foldedCount(wp, first, NULL);
    if (x > 0) {
      count++;              // count 1 for "+-- folded" line
      first += x;
    } else {
      if (first == wp->w_topline) {
        count += plines_win_nofill(wp, first, true) + (size_t)wp->w_topfill;
      } else {
        count += plines_win(wp, first, true);
      }
      first++;
    }
  }
  return count;
}
