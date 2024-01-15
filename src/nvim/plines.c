// plines.c: calculate the vertical and horizontal size of text in a window

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/diff.h"
#include "nvim/fold.h"
#include "nvim/globals.h"
#include "nvim/indent.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/marktree.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "plines.c.generated.h"
#endif

/// Functions calculating horizontal size of text, when displayed in a window.

/// Return the number of characters 'c' will take on the screen, taking
/// into account the size of a tab.
/// Also see getvcol()
///
/// @param p
/// @param col
///
/// @return Number of characters.
int win_chartabsize(win_T *wp, char *p, colnr_T col)
{
  buf_T *buf = wp->w_buffer;
  if (*p == TAB && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    return tabstop_padding(col, buf->b_p_ts, buf->b_p_vts_array);
  }
  return ptr2cells(p);
}

/// Return the number of characters the string 's' will take on the screen,
/// taking into account the size of a tab.
///
/// @param s
///
/// @return Number of characters the string will take on the screen.
int linetabsize_str(char *s)
{
  return linetabsize_col(0, s);
}

/// Like linetabsize_str(), but "s" starts at column "startcol".
///
/// @param startcol
/// @param s
///
/// @return Number of characters the string will take on the screen.
int linetabsize_col(int startcol, char *s)
{
  chartabsize_T cts;
  init_chartabsize_arg(&cts, curwin, 0, startcol, s, s);
  while (*cts.cts_ptr != NUL) {
    cts.cts_vcol += lbr_chartabsize_adv(&cts);
  }
  clear_chartabsize_arg(&cts);
  return cts.cts_vcol;
}

/// Like linetabsize_str(), but for a given window instead of the current one.
///
/// @param wp
/// @param line
/// @param len
///
/// @return Number of characters the string will take on the screen.
int win_linetabsize(win_T *wp, linenr_T lnum, char *line, colnr_T len)
{
  chartabsize_T cts;
  init_chartabsize_arg(&cts, wp, lnum, 0, line, line);
  win_linetabsize_cts(&cts, len);
  clear_chartabsize_arg(&cts);
  return cts.cts_vcol;
}

/// Return the number of cells line "lnum" of window "wp" will take on the
/// screen, taking into account the size of a tab and inline virtual text.
int linetabsize(win_T *wp, linenr_T lnum)
{
  return win_linetabsize(wp, lnum, ml_get_buf(wp->w_buffer, lnum), (colnr_T)MAXCOL);
}

void win_linetabsize_cts(chartabsize_T *cts, colnr_T len)
{
  for (; *cts->cts_ptr != NUL && (len == MAXCOL || cts->cts_ptr < cts->cts_line + len);
       MB_PTR_ADV(cts->cts_ptr)) {
    cts->cts_vcol += win_lbr_chartabsize(cts, NULL);
  }
  // check for inline virtual text after the end of the line
  if (len == MAXCOL && cts->cts_has_virt_text && *cts->cts_ptr == NUL) {
    win_lbr_chartabsize(cts, NULL);
    cts->cts_vcol += cts->cts_cur_text_width_left + cts->cts_cur_text_width_right;
  }
}

/// Prepare the structure passed to chartabsize functions.
///
/// "line" is the start of the line, "ptr" is the first relevant character.
/// When "lnum" is zero do not use inline virtual text.
void init_chartabsize_arg(chartabsize_T *cts, win_T *wp, linenr_T lnum, colnr_T col, char *line,
                          char *ptr)
{
  cts->cts_win = wp;
  cts->cts_vcol = col;
  cts->cts_line = line;
  cts->cts_ptr = ptr;
  cts->cts_max_head_vcol = 0;
  cts->cts_cur_text_width_left = 0;
  cts->cts_cur_text_width_right = 0;
  cts->cts_has_virt_text = false;
  cts->cts_row = lnum - 1;

  if (cts->cts_row >= 0 && wp->w_buffer->b_virt_text_inline > 0) {
    marktree_itr_get(wp->w_buffer->b_marktree, cts->cts_row, 0, cts->cts_iter);
    MTKey mark = marktree_itr_current(cts->cts_iter);
    if (mark.pos.row == cts->cts_row) {
      cts->cts_has_virt_text = true;
    }
  }
}

/// Free any allocated item in "cts".
void clear_chartabsize_arg(chartabsize_T *cts)
{
}

/// like win_chartabsize(), but also check for line breaks on the screen
///
/// @param cts
///
/// @return The number of characters taken up on the screen.
int lbr_chartabsize(chartabsize_T *cts)
{
  if (!curwin->w_p_lbr && *get_showbreak_value(curwin) == NUL
      && !curwin->w_p_bri && !cts->cts_has_virt_text) {
    if (curwin->w_p_wrap) {
      return win_nolbr_chartabsize(cts, NULL);
    }
    return win_chartabsize(curwin, cts->cts_ptr, cts->cts_vcol);
  }
  return win_lbr_chartabsize(cts, NULL);
}

/// Call lbr_chartabsize() and advance the pointer.
///
/// @param cts
///
/// @return The number of characters take up on the screen.
int lbr_chartabsize_adv(chartabsize_T *cts)
{
  int retval = lbr_chartabsize(cts);
  MB_PTR_ADV(cts->cts_ptr);
  return retval;
}

/// Get the number of characters taken up on the screen indicated by "cts".
/// "cts->cts_cur_text_width_left" and "cts->cts_cur_text_width_right" are set
/// to the extra size for inline virtual text.
/// This function is used very often, keep it fast!!!!
///
/// If "headp" not NULL, set "*headp" to the size of 'showbreak'/'breakindent'
/// included in the return value.
/// When "cts->cts_max_head_vcol" is positive, only count in "*headp" the size
/// of 'showbreak'/'breakindent' before "cts->cts_max_head_vcol".
/// When "cts->cts_max_head_vcol" is negative, only count in "*headp" the size
/// of 'showbreak'/'breakindent' before where cursor should be placed.
///
/// Warning: "*headp" may not be set if it's 0, init to 0 before calling.
int win_lbr_chartabsize(chartabsize_T *cts, int *headp)
{
  win_T *wp = cts->cts_win;
  char *line = cts->cts_line;  // start of the line
  char *s = cts->cts_ptr;
  colnr_T vcol = cts->cts_vcol;
  int mb_added = 0;

  cts->cts_cur_text_width_left = 0;
  cts->cts_cur_text_width_right = 0;

  // No 'linebreak', 'showbreak' and 'breakindent': return quickly.
  if (!wp->w_p_lbr && !wp->w_p_bri && *get_showbreak_value(wp) == NUL
      && !cts->cts_has_virt_text) {
    if (wp->w_p_wrap) {
      return win_nolbr_chartabsize(cts, headp);
    }
    return win_chartabsize(wp, s, vcol);
  }

  bool has_lcs_eol = wp->w_p_list && wp->w_p_lcs_chars.eol != NUL;

  // First get normal size, without 'linebreak' or inline virtual text
  int size = win_chartabsize(wp, s, vcol);
  if (*s == NUL && !has_lcs_eol) {
    size = 0;  // NUL is not displayed
  }
  bool is_doublewidth = size == 2 && MB_BYTE2LEN((uint8_t)(*s)) > 1;

  if (cts->cts_has_virt_text) {
    int tab_size = size;
    int col = (int)(s - line);
    while (true) {
      MTKey mark = marktree_itr_current(cts->cts_iter);
      if (mark.pos.row != cts->cts_row || mark.pos.col > col) {
        break;
      } else if (mark.pos.col == col) {
        if (!mt_end(mark) && mark.flags & (MT_FLAG_DECOR_VIRT_TEXT_INLINE)) {
          DecorInline decor = mt_decor(mark);
          DecorVirtText *vt = decor.ext ? decor.data.ext.vt : NULL;
          while (vt) {
            if (!(vt->flags & kVTIsLines) && vt->pos == kVPosInline) {
              if (mt_right(mark)) {
                cts->cts_cur_text_width_right += vt->width;
              } else {
                cts->cts_cur_text_width_left += vt->width;
              }
              size += vt->width;
              if (*s == TAB) {
                // tab size changes because of the inserted text
                size -= tab_size;
                tab_size = win_chartabsize(wp, s, vcol + size);
                size += tab_size;
              }
            }
            vt = vt->next;
          }
        }
      }
      marktree_itr_next(wp->w_buffer->b_marktree, cts->cts_iter);
    }
  }

  if (is_doublewidth && wp->w_p_wrap && in_win_border(wp, vcol + size - 2)) {
    // Count the ">" in the last column.
    size++;
    mb_added = 1;
  }

  // May have to add something for 'breakindent' and/or 'showbreak'
  // string at the start of a screen line.
  int head = mb_added;
  char *const sbr = get_showbreak_value(wp);
  // When "size" is 0, no new screen line is started.
  if (size > 0 && wp->w_p_wrap && (*sbr != NUL || wp->w_p_bri)) {
    int col_off_prev = win_col_off(wp);
    int width2 = wp->w_width_inner - col_off_prev + win_col_off2(wp);
    colnr_T wcol = vcol + col_off_prev;
    colnr_T max_head_vcol = cts->cts_max_head_vcol;
    int added = 0;

    // cells taken by 'showbreak'/'breakindent' before current char
    int head_prev = 0;
    if (wcol >= wp->w_width_inner) {
      wcol -= wp->w_width_inner;
      col_off_prev = wp->w_width_inner - width2;
      if (wcol >= width2 && width2 > 0) {
        wcol %= width2;
      }
      if (*sbr != NUL) {
        head_prev += vim_strsize(sbr);
      }
      if (wp->w_p_bri) {
        head_prev += get_breakindent_win(wp, line);
      }
      if (wcol < head_prev) {
        head_prev -= wcol;
        wcol += head_prev;
        added += head_prev;
        if (max_head_vcol <= 0 || vcol < max_head_vcol) {
          head += head_prev;
        }
      } else {
        head_prev = 0;
      }
      wcol += col_off_prev;
    }

    if (wcol + size > wp->w_width) {
      // cells taken by 'showbreak'/'breakindent' halfway current char
      int head_mid = 0;
      if (*sbr != NUL) {
        head_mid += vim_strsize(sbr);
      }
      if (wp->w_p_bri) {
        head_mid += get_breakindent_win(wp, line);
      }
      if (head_mid > 0 && wcol + size > wp->w_width_inner) {
        // Calculate effective window width.
        int prev_rem = wp->w_width_inner - wcol;
        int width = width2 - head_mid;

        if (width <= 0) {
          width = 1;
        }
        // Divide "size - prev_rem" by "width", rounding up.
        int cnt = (size - prev_rem + width - 1) / width;
        added += cnt * head_mid;

        if (max_head_vcol == 0 || vcol + size + added < max_head_vcol) {
          head += cnt * head_mid;
        } else if (max_head_vcol > vcol + head_prev + prev_rem) {
          head += (max_head_vcol - (vcol + head_prev + prev_rem)
                   + width2 - 1) / width2 * head_mid;
        } else if (max_head_vcol < 0) {
          int off = virt_text_cursor_off(cts, *s == NUL);
          if (off >= prev_rem) {
            if (size > off) {
              head += (1 + (off - prev_rem) / width) * head_mid;
            } else {
              head += (off - prev_rem + width - 1) / width * head_mid;
            }
          }
        }
      }
    }

    size += added;
  }

  if (headp != NULL) {
    *headp = head;
  }

  colnr_T vcol_start = 0;  // start from where to consider linebreak
  // If 'linebreak' set check at a blank before a non-blank if the line
  // needs a break here
  if (wp->w_p_lbr && wp->w_p_wrap && wp->w_width_inner != 0) {
    char *t = cts->cts_line;
    while (vim_isbreak((uint8_t)t[0])) {
      t++;
    }
    vcol_start = (colnr_T)(t - cts->cts_line);
  }
  if (wp->w_p_lbr && vcol_start <= vcol
      && vim_isbreak((uint8_t)s[0])
      && !vim_isbreak((uint8_t)s[1])
      && wp->w_p_wrap
      && wp->w_width_inner != 0) {
    // Count all characters from first non-blank after a blank up to next
    // non-blank after a blank.
    int numberextra = win_col_off(wp);
    colnr_T col_adj = size - 1;
    colnr_T colmax = (colnr_T)(wp->w_width_inner - numberextra - col_adj);
    if (vcol >= colmax) {
      colmax += col_adj;
      int n = colmax + win_col_off2(wp);
      if (n > 0) {
        colmax += (((vcol - colmax) / n) + 1) * n - col_adj;
      }
    }

    colnr_T vcol2 = vcol;
    while (true) {
      char *ps = s;
      MB_PTR_ADV(s);
      int c = (uint8_t)(*s);
      if (!(c != NUL
            && (vim_isbreak(c) || vcol2 == vcol || !vim_isbreak((uint8_t)(*ps))))) {
        break;
      }

      vcol2 += win_chartabsize(wp, s, vcol2);
      if (vcol2 >= colmax) {  // doesn't fit
        size = colmax - vcol + col_adj;
        break;
      }
    }
  }

  return size;
}

/// Like win_lbr_chartabsize(), except that we know 'linebreak' is off and
/// 'wrap' is on.  This means we need to check for a double-byte character that
/// doesn't fit at the end of the screen line.
///
/// @param cts
/// @param headp
///
/// @return The number of characters take up on the screen.
static int win_nolbr_chartabsize(chartabsize_T *cts, int *headp)
{
  win_T *wp = cts->cts_win;
  char *s = cts->cts_ptr;
  colnr_T col = cts->cts_vcol;

  if ((*s == TAB) && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    return tabstop_padding(col,
                           wp->w_buffer->b_p_ts,
                           wp->w_buffer->b_p_vts_array);
  }
  int n = ptr2cells(s);

  // Add one cell for a double-width character in the last column of the
  // window, displayed with a ">".
  if ((n == 2) && (MB_BYTE2LEN((uint8_t)(*s)) > 1) && in_win_border(wp, col)) {
    if (headp != NULL) {
      *headp = 1;
    }
    return 3;
  }
  return n;
}

/// Check that virtual column "vcol" is in the rightmost column of window "wp".
///
/// @param  wp    window
/// @param  vcol  column number
static bool in_win_border(win_T *wp, colnr_T vcol)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  if (wp->w_width_inner == 0) {
    // there is no border
    return false;
  }
  int width1 = wp->w_width_inner - win_col_off(wp);  // width of first line (after line number)

  if ((int)vcol < width1 - 1) {
    return false;
  }

  if ((int)vcol == width1 - 1) {
    return true;
  }
  int width2 = width1 + win_col_off2(wp);  // width of further lines

  if (width2 <= 0) {
    return false;
  }
  return (vcol - width1) % width2 == width2 - 1;
}

/// Get how many virtual columns inline virtual text should offset the cursor.
///
/// @param cts     should contain information stored by win_lbr_chartabsize()
///                about widths of left and right gravity virtual text
/// @param on_NUL  whether this is the end of the line
static int virt_text_cursor_off(chartabsize_T *cts, bool on_NUL)
{
  int off = 0;
  if (!on_NUL || !(State & MODE_NORMAL)) {
    off += cts->cts_cur_text_width_left;
  }
  if (!on_NUL && (State & MODE_NORMAL)) {
    off += cts->cts_cur_text_width_right;
  }
  return off;
}

/// Get virtual column number of pos.
///  start: on the first position of this character (TAB, ctrl)
/// cursor: where the cursor is on this character (first char, except for TAB)
///    end: on the last position of this character (TAB, ctrl)
///
/// This is used very often, keep it fast!
///
/// @param wp
/// @param pos
/// @param start
/// @param cursor
/// @param end
void getvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end)
{
  char *ptr;     // points to current char
  char *posptr;  // points to char at pos->col
  int incr;
  int head;
  colnr_T *vts = wp->w_buffer->b_p_vts_array;
  int ts = (int)wp->w_buffer->b_p_ts;

  colnr_T vcol = 0;
  char *line = ptr = ml_get_buf(wp->w_buffer, pos->lnum);  // start of the line

  if (pos->col == MAXCOL) {
    // continue until the NUL
    posptr = NULL;
  } else {
    // In a few cases the position can be beyond the end of the line.
    for (colnr_T i = 0; i < pos->col; i++) {
      if (ptr[i] == NUL) {
        pos->col = i;
        break;
      }
    }
    posptr = ptr + pos->col;
    posptr -= utf_head_off(line, posptr);
  }

  chartabsize_T cts;
  bool on_NUL = false;
  init_chartabsize_arg(&cts, wp, pos->lnum, 0, line, line);
  cts.cts_max_head_vcol = -1;

  // This function is used very often, do some speed optimizations.
  // When 'list', 'linebreak', 'showbreak' and 'breakindent' are not set
  // and there are no virtual text use a simple loop.
  // Also use this when 'list' is set but tabs take their normal size.
  if ((!wp->w_p_list || (wp->w_p_lcs_chars.tab1 != NUL))
      && !wp->w_p_lbr
      && *get_showbreak_value(wp) == NUL
      && !wp->w_p_bri
      && !cts.cts_has_virt_text) {
    while (true) {
      head = 0;
      int c = (uint8_t)(*ptr);

      // make sure we don't go past the end of the line
      if (c == NUL) {
        // NUL at end of line only takes one column
        incr = 1;
        break;
      }

      // A tab gets expanded, depending on the current column
      if (c == TAB) {
        incr = tabstop_padding(vcol, ts, vts);
      } else {
        // For utf-8, if the byte is >= 0x80, need to look at
        // further bytes to find the cell width.
        if (c >= 0x80) {
          incr = utf_ptr2cells(ptr);
        } else {
          incr = byte2cells(c);
        }

        // If a double-cell char doesn't fit at the end of a line
        // it wraps to the next line, it's like this char is three
        // cells wide.
        if ((incr == 2)
            && wp->w_p_wrap
            && (MB_BYTE2LEN((uint8_t)(*ptr)) > 1)
            && in_win_border(wp, vcol)) {
          incr++;
          head = 1;
        }
      }

      if ((posptr != NULL) && (ptr >= posptr)) {
        // character at pos->col
        break;
      }

      vcol += incr;
      MB_PTR_ADV(ptr);
    }
  } else {
    while (true) {
      // A tab gets expanded, depending on the current column
      // Other things also take up space.
      head = 0;
      incr = win_lbr_chartabsize(&cts, &head);

      // make sure we don't go past the end of the line
      if (*cts.cts_ptr == NUL) {
        // NUL at end of line only takes one column, unless there is virtual text
        incr = MAX(1, cts.cts_cur_text_width_left + cts.cts_cur_text_width_right);
        on_NUL = true;
        break;
      }

      if ((posptr != NULL) && (cts.cts_ptr >= posptr)) {
        // character at pos->col
        break;
      }

      cts.cts_vcol += incr;
      MB_PTR_ADV(cts.cts_ptr);
    }
    vcol = cts.cts_vcol;
    ptr = cts.cts_ptr;
  }
  clear_chartabsize_arg(&cts);

  if (start != NULL) {
    *start = vcol + head;
  }

  if (end != NULL) {
    *end = vcol + incr - 1;
  }

  if (cursor != NULL) {
    if ((*ptr == TAB)
        && (State & MODE_NORMAL)
        && !wp->w_p_list
        && !virtual_active()
        && !(VIsual_active && ((*p_sel == 'e') || ltoreq(*pos, VIsual)))) {
      // cursor at end
      *cursor = vcol + incr - 1;
    } else {
      vcol += virt_text_cursor_off(&cts, on_NUL);
      // cursor at start
      *cursor = vcol + head;
    }
  }
}

/// Get virtual cursor column in the current window, pretending 'list' is off.
///
/// @param posp
///
/// @retujrn The virtual cursor column.
colnr_T getvcol_nolist(pos_T *posp)
{
  int list_save = curwin->w_p_list;
  colnr_T vcol;

  curwin->w_p_list = false;
  if (posp->coladd) {
    getvvcol(curwin, posp, NULL, &vcol, NULL);
  } else {
    getvcol(curwin, posp, NULL, &vcol, NULL);
  }
  curwin->w_p_list = list_save;
  return vcol;
}

/// Get virtual column in virtual mode.
///
/// @param wp
/// @param pos
/// @param start
/// @param cursor
/// @param end
void getvvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end)
{
  colnr_T col;

  if (virtual_active()) {
    // For virtual mode, only want one value
    getvcol(wp, pos, &col, NULL, NULL);

    colnr_T coladd = pos->coladd;
    colnr_T endadd = 0;

    // Cannot put the cursor on part of a wide character.
    char *ptr = ml_get_buf(wp->w_buffer, pos->lnum);

    if (pos->col < (colnr_T)strlen(ptr)) {
      int c = utf_ptr2char(ptr + pos->col);
      if ((c != TAB) && vim_isprintc(c)) {
        endadd = (colnr_T)(char2cells(c) - 1);
        if (coladd > endadd) {
          // past end of line
          endadd = 0;
        } else {
          coladd = 0;
        }
      }
    }
    col += coladd;

    if (start != NULL) {
      *start = col;
    }

    if (cursor != NULL) {
      *cursor = col;
    }

    if (end != NULL) {
      *end = col + endadd;
    }
  } else {
    getvcol(wp, pos, start, cursor, end);
  }
}

/// Get the leftmost and rightmost virtual column of pos1 and pos2.
/// Used for Visual block mode.
///
/// @param wp
/// @param pos1
/// @param pos2
/// @param left
/// @param right
void getvcols(win_T *wp, pos_T *pos1, pos_T *pos2, colnr_T *left, colnr_T *right)
{
  colnr_T from1;
  colnr_T from2;
  colnr_T to1;
  colnr_T to2;

  if (lt(*pos1, *pos2)) {
    getvvcol(wp, pos1, &from1, NULL, &to1);
    getvvcol(wp, pos2, &from2, NULL, &to2);
  } else {
    getvvcol(wp, pos2, &from1, NULL, &to1);
    getvvcol(wp, pos1, &from2, NULL, &to2);
  }

  if (from2 < from1) {
    *left = from2;
  } else {
    *left = from1;
  }

  if (to2 > to1) {
    if ((*p_sel == 'e') && (from2 - 1 >= to1)) {
      *right = from2 - 1;
    } else {
      *right = to2;
    }
  } else {
    *right = to1;
  }
}

/// Functions calculating vertical size of text when displayed inside a window.
/// Calls horizontal size functions defined above.

/// Check if there may be filler lines anywhere in window "wp".
bool win_may_fill(win_T *wp)
{
  return (wp->w_p_diff && diffopt_filler()) || wp->w_buffer->b_virt_line_blocks;
}

/// Return the number of filler lines above "lnum".
///
/// @param wp
/// @param lnum
///
/// @return Number of filler lines above lnum
int win_get_fill(win_T *wp, linenr_T lnum)
{
  int virt_lines = decor_virt_lines(wp, lnum, NULL, kNone);

  // be quick when there are no filler lines
  if (diffopt_filler()) {
    int n = diff_check(wp, lnum);

    if (n > 0) {
      return virt_lines + n;
    }
  }
  return virt_lines;
}

/// Return the number of window lines occupied by buffer line "lnum".
/// Includes any filler lines.
///
/// @param limit_winheight  when true limit to window height
int plines_win(win_T *wp, linenr_T lnum, bool limit_winheight)
{
  // Check for filler lines above this buffer line.
  return plines_win_nofill(wp, lnum, limit_winheight) + win_get_fill(wp, lnum);
}

/// Return the number of window lines occupied by buffer line "lnum".
/// Does not include filler lines.
///
/// @param limit_winheight  when true limit to window height
int plines_win_nofill(win_T *wp, linenr_T lnum, bool limit_winheight)
{
  if (!wp->w_p_wrap) {
    return 1;
  }

  if (wp->w_width_inner == 0) {
    return 1;
  }

  // Folded lines are handled just like an empty line.
  if (lineFolded(wp, lnum)) {
    return 1;
  }

  const int lines = plines_win_nofold(wp, lnum);
  if (limit_winheight && lines > wp->w_height_inner) {
    return wp->w_height_inner;
  }
  return lines;
}

/// Get number of window lines physical line "lnum" will occupy in window "wp".
/// Does not care about folding, 'wrap' or filler lines.
int plines_win_nofold(win_T *wp, linenr_T lnum)
{
  char *s = ml_get_buf(wp->w_buffer, lnum);
  chartabsize_T cts;
  init_chartabsize_arg(&cts, wp, lnum, 0, s, s);
  if (*s == NUL && !cts.cts_has_virt_text) {
    return 1;  // be quick for an empty line
  }
  win_linetabsize_cts(&cts, (colnr_T)MAXCOL);
  clear_chartabsize_arg(&cts);
  int64_t col = cts.cts_vcol;

  // If list mode is on, then the '$' at the end of the line may take up one
  // extra column.
  if (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL) {
    col += 1;
  }

  // Add column offset for 'number', 'relativenumber' and 'foldcolumn'.
  int width = wp->w_width_inner - win_col_off(wp);
  if (width <= 0) {
    return 32000;  // bigger than the number of screen lines
  }
  if (col <= width) {
    return 1;
  }
  col -= width;
  width += win_col_off2(wp);
  const int64_t lines = (col + (width - 1)) / width + 1;
  return (lines > 0 && lines <= INT_MAX) ? (int)lines : INT_MAX;
}

/// Like plines_win(), but only reports the number of physical screen lines
/// used from the start of the line to the given column number.
int plines_win_col(win_T *wp, linenr_T lnum, long column)
{
  // Check for filler lines above this buffer line.
  int lines = win_get_fill(wp, lnum);

  if (!wp->w_p_wrap) {
    return lines + 1;
  }

  if (wp->w_width_inner == 0) {
    return lines + 1;
  }

  char *line = ml_get_buf(wp->w_buffer, lnum);

  colnr_T col = 0;
  chartabsize_T cts;

  init_chartabsize_arg(&cts, wp, lnum, 0, line, line);
  while (*cts.cts_ptr != NUL && --column >= 0) {
    cts.cts_vcol += win_lbr_chartabsize(&cts, NULL);
    MB_PTR_ADV(cts.cts_ptr);
  }

  // If *cts.cts_ptr is a TAB, and the TAB is not displayed as ^I, and we're not
  // in MODE_INSERT state, then col must be adjusted so that it represents the
  // last screen position of the TAB.  This only fixes an error when the TAB
  // wraps from one screen line to the next (when 'columns' is not a multiple
  // of 'ts') -- webb.
  col = cts.cts_vcol;
  if (*cts.cts_ptr == TAB && (State & MODE_NORMAL)
      && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    col += win_lbr_chartabsize(&cts, NULL) - 1;
  }
  clear_chartabsize_arg(&cts);

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

/// Get the number of screen lines buffer line "lnum" will take in window "wp".
/// This takes care of both folds and topfill.
///
/// XXX: Because of topfill, this only makes sense when lnum >= wp->w_topline.
///
/// @param[in]  wp               window the line is in
/// @param[in]  lnum             line number
/// @param[out] nextp            if not NULL, the line after a fold
/// @param[out] foldedp          if not NULL, whether lnum is on a fold
/// @param[in]  cache            whether to use the window's cache for folds
/// @param[in]  limit_winheight  when true limit to window height
///
/// @return the total number of screen lines
int plines_win_full(win_T *wp, linenr_T lnum, linenr_T *const nextp, bool *const foldedp,
                    const bool cache, const bool limit_winheight)
{
  bool folded = hasFoldingWin(wp, lnum, &lnum, nextp, cache, NULL);
  if (foldedp != NULL) {
    *foldedp = folded;
  }
  return ((folded ? 1 : plines_win_nofill(wp, lnum, limit_winheight)) +
          (lnum == wp->w_topline ? wp->w_topfill : win_get_fill(wp, lnum)));
}

/// Get the number of screen lines a range of buffer lines will take in window "wp".
/// This takes care of both folds and topfill.
///
/// XXX: Because of topfill, this only makes sense when first >= wp->w_topline.
///
/// @param first            first line number
/// @param last             last line number
/// @param limit_winheight  when true limit each line to window height
///
/// @see win_text_height
int plines_m_win(win_T *wp, linenr_T first, linenr_T last, bool limit_winheight)
{
  int count = 0;

  while (first <= last) {
    linenr_T next = first;
    count += plines_win_full(wp, first, &next, NULL, false, limit_winheight);
    first = next + 1;
  }
  return count;
}

/// Get the number of screen lines a range of text will take in window "wp".
///
/// @param[in] start_lnum  Starting line number, 1-based inclusive.
/// @param[in] start_vcol  >= 0: Starting virtual column index on "start_lnum",
///                              0-based inclusive, rounded down to full screen lines.
///                        < 0:  Count a full "start_lnum", including filler lines above.
/// @param[in] end_lnum    Ending line number, 1-based inclusive.
/// @param[in] end_vcol    >= 0: Ending virtual column index on "end_lnum",
///                              0-based exclusive, rounded up to full screen lines.
///                        < 0:  Count a full "end_lnum", not including filler lines below.
/// @param[out] fill       If not NULL, set to the number of filler lines in the range.
int64_t win_text_height(win_T *const wp, const linenr_T start_lnum, const int64_t start_vcol,
                        const linenr_T end_lnum, const int64_t end_vcol, int64_t *const fill)
{
  int width1 = 0;
  int width2 = 0;
  if (start_vcol >= 0 || end_vcol >= 0) {
    width1 = wp->w_width_inner - win_col_off(wp);
    width2 = width1 + win_col_off2(wp);
    width1 = MAX(width1, 0);
    width2 = MAX(width2, 0);
  }

  int64_t height_sum_fill = 0;
  int64_t height_cur_nofill = 0;
  int64_t height_sum_nofill = 0;
  linenr_T lnum = start_lnum;

  if (start_vcol >= 0) {
    linenr_T lnum_next = lnum;
    const bool folded = hasFoldingWin(wp, lnum, &lnum, &lnum_next, true, NULL);
    height_cur_nofill = folded ? 1 : plines_win_nofill(wp, lnum, false);
    height_sum_nofill += height_cur_nofill;
    const int64_t row_off = (start_vcol < width1 || width2 <= 0)
                            ? 0
                            : 1 + (start_vcol - width1) / width2;
    height_sum_nofill -= MIN(row_off, height_cur_nofill);
    lnum = lnum_next + 1;
  }

  while (lnum <= end_lnum) {
    linenr_T lnum_next = lnum;
    const bool folded = hasFoldingWin(wp, lnum, &lnum, &lnum_next, true, NULL);
    height_sum_fill += win_get_fill(wp, lnum);
    height_cur_nofill = folded ? 1 : plines_win_nofill(wp, lnum, false);
    height_sum_nofill += height_cur_nofill;
    lnum = lnum_next + 1;
  }

  if (end_vcol >= 0) {
    height_sum_nofill -= height_cur_nofill;
    const int64_t row_off = end_vcol == 0
                            ? 0
                            : (end_vcol <= width1 || width2 <= 0)
                            ? 1
                            : 1 + (end_vcol - width1 + width2 - 1) / width2;
    height_sum_nofill += MIN(row_off, height_cur_nofill);
  }

  if (fill != NULL) {
    *fill = height_sum_fill;
  }
  return height_sum_fill + height_sum_nofill;
}
