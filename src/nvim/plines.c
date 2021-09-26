// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// plines.c: calculate the vertical and horizontal size of text in a window

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/diff.h"
#include "nvim/fold.h"
#include "nvim/func_attr.h"
#include "nvim/indent.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/plines.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "plines.c.generated.h"
#endif

/// Functions calculating vertical size of text when displayed inside a window.
/// Calls horizontal size functions defined below.

/// @param winheight when true limit to window height
int plines_win(win_T *wp, linenr_T lnum, bool winheight)
{
  // Check for filler lines above this buffer line.  When folded the result
  // is one line anyway.
  return plines_win_nofill(wp, lnum, winheight) + win_get_fill(wp, lnum);
}


/// Return the number of filler lines above "lnum".
///
/// @param wp
/// @param lnum
///
/// @return Number of filler lines above lnum
int win_get_fill(win_T *wp, linenr_T lnum)
{
  int virt_lines = decor_virtual_lines(wp, lnum);

  // be quick when there are no filler lines
  if (diffopt_filler()) {
    int n = diff_check(wp, lnum);

    if (n > 0) {
      return virt_lines+n;
    }
  }
  return virt_lines;
}

bool win_may_fill(win_T *wp)
{
  return (wp->w_p_diff && diffopt_filler()) || wp->w_buffer->b_virt_line_mark;
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
  char_u *s;
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
  int lines = win_get_fill(wp, lnum);

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
int plines_win_full(win_T *wp, linenr_T lnum, linenr_T *const nextp, bool *const foldedp,
                    const bool cache)
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

/// Functions calculating horizontal size of text, when displayed in a window.

/// Return the number of characters 'c' will take on the screen, taking
/// into account the size of a tab.
/// Also see getvcol()
///
/// @param p
/// @param col
///
/// @return Number of characters.
int win_chartabsize(win_T *wp, char_u *p, colnr_T col)
{
  buf_T *buf = wp->w_buffer;
  if (*p == TAB && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    return tabstop_padding(col, buf->b_p_ts, buf->b_p_vts_array);
  } else {
    return ptr2cells(p);
  }
}

/// Return the number of characters the string 's' will take on the screen,
/// taking into account the size of a tab.
///
/// @param s
///
/// @return Number of characters the string will take on the screen.
int linetabsize(char_u *s)
{
  return linetabsize_col(0, s);
}

/// Like linetabsize(), but starting at column "startcol".
///
/// @param startcol
/// @param s
///
/// @return Number of characters the string will take on the screen.
int linetabsize_col(int startcol, char_u *s)
{
  colnr_T col = startcol;
  char_u *line = s;  // pointer to start of line, for breakindent

  while (*s != NUL) {
    col += lbr_chartabsize_adv(line, &s, col);
  }
  return (int)col;
}

/// Like linetabsize(), but for a given window instead of the current one.
///
/// @param wp
/// @param line
/// @param len
///
/// @return Number of characters the string will take on the screen.
unsigned int win_linetabsize(win_T *wp, char_u *line, colnr_T len)
{
  colnr_T col = 0;

  for (char_u *s = line;
       *s != NUL && (len == MAXCOL || s < line + len);
       MB_PTR_ADV(s)) {
    col += win_lbr_chartabsize(wp, line, s, col, NULL);
  }

  return (unsigned int)col;
}

/// like win_chartabsize(), but also check for line breaks on the screen
///
/// @param line
/// @param s
/// @param col
///
/// @return The number of characters taken up on the screen.
int lbr_chartabsize(char_u *line, unsigned char *s, colnr_T col)
{
  if (!curwin->w_p_lbr && *get_showbreak_value(curwin) == NUL
      && !curwin->w_p_bri) {
    if (curwin->w_p_wrap) {
      return win_nolbr_chartabsize(curwin, s, col, NULL);
    }
    return win_chartabsize(curwin, s, col);
  }
  return win_lbr_chartabsize(curwin, line == NULL ? s: line, s, col, NULL);
}

/// Call lbr_chartabsize() and advance the pointer.
///
/// @param line
/// @param s
/// @param col
///
/// @return The number of characters take up on the screen.
int lbr_chartabsize_adv(char_u *line, char_u **s, colnr_T col)
{
  int retval;

  retval = lbr_chartabsize(line, *s, col);
  MB_PTR_ADV(*s);
  return retval;
}

/// This function is used very often, keep it fast!!!!
///
/// If "headp" not NULL, set *headp to the size of what we for 'showbreak'
/// string at start of line.  Warning: *headp is only set if it's a non-zero
/// value, init to 0 before calling.
///
/// @param wp
/// @param line
/// @param s
/// @param col
/// @param headp
///
/// @return The number of characters taken up on the screen.
int win_lbr_chartabsize(win_T *wp, char_u *line, char_u *s, colnr_T col, int *headp)
{
  colnr_T col2;
  colnr_T col_adj = 0;  // col + screen size of tab
  colnr_T colmax;
  int added;
  int mb_added = 0;
  int numberextra;
  char_u *ps;
  int n;

  // No 'linebreak', 'showbreak' and 'breakindent': return quickly.
  if (!wp->w_p_lbr && !wp->w_p_bri && *get_showbreak_value(wp) == NUL) {
    if (wp->w_p_wrap) {
      return win_nolbr_chartabsize(wp, s, col, headp);
    }
    return win_chartabsize(wp, s, col);
  }

  // First get normal size, without 'linebreak'
  int size = win_chartabsize(wp, s, col);
  int c = *s;
  if (*s == TAB) {
    col_adj = size - 1;
  }

  // If 'linebreak' set check at a blank before a non-blank if the line
  // needs a break here
  if (wp->w_p_lbr
      && vim_isbreak(c)
      && !vim_isbreak((int)s[1])
      && wp->w_p_wrap
      && (wp->w_width_inner != 0)) {
    // Count all characters from first non-blank after a blank up to next
    // non-blank after a blank.
    numberextra = win_col_off(wp);
    col2 = col;
    colmax = (colnr_T)(wp->w_width_inner - numberextra - col_adj);

    if (col >= colmax) {
      colmax += col_adj;
      n = colmax + win_col_off2(wp);

      if (n > 0) {
        colmax += (((col - colmax) / n) + 1) * n - col_adj;
      }
    }

    for (;;) {
      ps = s;
      MB_PTR_ADV(s);
      c = *s;

      if (!(c != NUL
            && (vim_isbreak(c) || col2 == col || !vim_isbreak((int)(*ps))))) {
        break;
      }

      col2 += win_chartabsize(wp, s, col2);

      if (col2 >= colmax) {  // doesn't fit
        size = colmax - col + col_adj;
        break;
      }
    }
  } else if ((size == 2)
             && (MB_BYTE2LEN(*s) > 1)
             && wp->w_p_wrap
             && in_win_border(wp, col)) {
    // Count the ">" in the last column.
    size++;
    mb_added = 1;
  }

  // May have to add something for 'breakindent' and/or 'showbreak'
  // string at start of line.
  // Set *headp to the size of what we add.
  added = 0;

  char_u *const sbr = get_showbreak_value(wp);
  if ((*sbr != NUL || wp->w_p_bri) && wp->w_p_wrap && col != 0) {
    colnr_T sbrlen = 0;
    int numberwidth = win_col_off(wp);

    numberextra = numberwidth;
    col += numberextra + mb_added;

    if (col >= (colnr_T)wp->w_width_inner) {
      col -= wp->w_width_inner;
      numberextra = wp->w_width_inner - (numberextra - win_col_off2(wp));
      if (col >= numberextra && numberextra > 0) {
        col %= numberextra;
      }
      if (*sbr != NUL) {
        sbrlen = (colnr_T)MB_CHARLEN(sbr);
        if (col >= sbrlen) {
          col -= sbrlen;
        }
      }
      if (col >= numberextra && numberextra > 0) {
        col %= numberextra;
      } else if (col > 0 && numberextra > 0) {
        col += numberwidth - win_col_off2(wp);
      }

      numberwidth -= win_col_off2(wp);
    }

    if (col == 0 || (col + size + sbrlen > (colnr_T)wp->w_width_inner)) {
      if (*sbr != NUL) {
        if (size + sbrlen + numberwidth > (colnr_T)wp->w_width_inner) {
          // Calculate effective window width.
          int width = (colnr_T)wp->w_width_inner - sbrlen - numberwidth;
          int prev_width = col ? ((colnr_T)wp->w_width_inner - (sbrlen + col))
                               : 0;

          if (width <= 0) {
            width = 1;
          }
          added += ((size - prev_width) / width) * vim_strsize(sbr);
          if ((size - prev_width) % width) {
            // Wrapped, add another length of 'sbr'.
            added += vim_strsize(sbr);
          }
        } else {
          added += vim_strsize(sbr);
        }
      }

      if (wp->w_p_bri) {
        added += get_breakindent_win(wp, line);
      }

      size += added;
      if (col != 0) {
        added = 0;
      }
    }
  }

  if (headp != NULL) {
    *headp = added + mb_added;
  }
  return size;
}

/// Like win_lbr_chartabsize(), except that we know 'linebreak' is off and
/// 'wrap' is on.  This means we need to check for a double-byte character that
/// doesn't fit at the end of the screen line.
///
/// @param wp
/// @param s
/// @param col
/// @param headp
///
/// @return The number of characters take up on the screen.
static int win_nolbr_chartabsize(win_T *wp, char_u *s, colnr_T col, int *headp)
{
  int n;

  if ((*s == TAB) && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    return tabstop_padding(col,
                           wp->w_buffer->b_p_ts,
                           wp->w_buffer->b_p_vts_array);
  }
  n = ptr2cells(s);

  // Add one cell for a double-width character in the last column of the
  // window, displayed with a ">".
  if ((n == 2) && (MB_BYTE2LEN(*s) > 1) && in_win_border(wp, col)) {
    if (headp != NULL) {
      *headp = 1;
    }
    return 3;
  }
  return n;
}

