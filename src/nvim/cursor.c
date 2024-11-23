#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/assert_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/fold.h"
#include "nvim/globals.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cursor.c.generated.h"
#endif

/// @return  the screen position of the cursor.
int getviscol(void)
{
  colnr_T x;

  getvvcol(curwin, &curwin->w_cursor, &x, NULL, NULL);
  return (int)x;
}

/// @return the screen position of character col with a coladd in the cursor line.
int getviscol2(colnr_T col, colnr_T coladd)
{
  colnr_T x;
  pos_T pos;

  pos.lnum = curwin->w_cursor.lnum;
  pos.col = col;
  pos.coladd = coladd;
  getvvcol(curwin, &pos, &x, NULL, NULL);
  return (int)x;
}

/// Go to column "wcol", and add/insert white space as necessary to get the
/// cursor in that column.
/// The caller must have saved the cursor line for undo!
int coladvance_force(colnr_T wcol)
{
  int rc = coladvance2(curwin, &curwin->w_cursor, true, false, wcol);

  if (wcol == MAXCOL) {
    curwin->w_valid &= ~VALID_VIRTCOL;
  } else {
    // Virtcol is valid
    curwin->w_valid |= VALID_VIRTCOL;
    curwin->w_virtcol = wcol;
  }
  return rc;
}

/// Try to advance the Cursor to the specified screen column.
/// If virtual editing: fine tune the cursor position.
/// Note that all virtual positions off the end of a line should share
/// a curwin->w_cursor.col value (n.b. this is equal to strlen(line)),
/// beginning at coladd 0.
///
/// @return  OK if desired column is reached, FAIL if not
int coladvance(win_T *wp, colnr_T wcol)
{
  int rc = getvpos(wp, &wp->w_cursor, wcol);

  if (wcol == MAXCOL || rc == FAIL) {
    wp->w_valid &= ~VALID_VIRTCOL;
  } else if (*(ml_get_buf(wp->w_buffer, wp->w_cursor.lnum) + wp->w_cursor.col) != TAB) {
    // Virtcol is valid when not on a TAB
    wp->w_valid |= VALID_VIRTCOL;
    wp->w_virtcol = wcol;
  }
  return rc;
}

/// @param addspaces  change the text to achieve our goal? only for wp=curwin!
/// @param finetune  change char offset for the exact column
/// @param wcol_arg  column to move to (can be negative)
static int coladvance2(win_T *wp, pos_T *pos, bool addspaces, bool finetune, colnr_T wcol_arg)
{
  assert(wp == curwin || !addspaces);
  colnr_T wcol = wcol_arg;
  int idx;
  colnr_T col = 0;
  int head = 0;

  int one_more = (State & MODE_INSERT)
                 || (State & MODE_TERMINAL)
                 || restart_edit != NUL
                 || (VIsual_active && *p_sel != 'o')
                 || ((get_ve_flags(wp) & kOptVeFlagOnemore) && wcol < MAXCOL);

  char *line = ml_get_buf(wp->w_buffer, pos->lnum);
  int linelen = ml_get_buf_len(wp->w_buffer, pos->lnum);

  if (wcol >= MAXCOL) {
    idx = linelen - 1 + one_more;
    col = wcol;

    if ((addspaces || finetune) && !VIsual_active) {
      wp->w_curswant = linetabsize(wp, pos->lnum) + one_more;
      if (wp->w_curswant > 0) {
        wp->w_curswant--;
      }
    }
  } else {
    int width = wp->w_width_inner - win_col_off(wp);
    int csize = 0;

    if (finetune
        && wp->w_p_wrap
        && wp->w_width_inner != 0
        && wcol >= (colnr_T)width
        && width > 0) {
      csize = linetabsize(wp, pos->lnum);
      if (csize > 0) {
        csize--;
      }

      if (wcol / width > (colnr_T)csize / width
          && ((State & MODE_INSERT) == 0 || (int)wcol > csize + 1)) {
        // In case of line wrapping don't move the cursor beyond the
        // right screen edge.  In Insert mode allow going just beyond
        // the last character (like what happens when typing and
        // reaching the right window edge).
        wcol = (csize / width + 1) * width - 1;
      }
    }

    CharsizeArg csarg;
    CSType cstype = init_charsize_arg(&csarg, wp, pos->lnum, line);
    StrCharInfo ci = utf_ptr2StrCharInfo(line);
    col = 0;
    while (col <= wcol && *ci.ptr != NUL) {
      CharSize cs = win_charsize(cstype, col, ci.ptr, ci.chr.value, &csarg);
      csize = cs.width;
      head = cs.head;
      col += cs.width;
      ci = utfc_next(ci);
    }
    idx = (int)(ci.ptr - line);

    // Handle all the special cases.  The virtual_active() check
    // is needed to ensure that a virtual position off the end of
    // a line has the correct indexing.  The one_more comparison
    // replaces an explicit add of one_more later on.
    if (col > wcol || (!virtual_active(wp) && one_more == 0)) {
      idx -= 1;
      // Don't count the chars from 'showbreak'.
      csize -= head;
      col -= csize;
    }

    if (virtual_active(wp)
        && addspaces
        && wcol >= 0
        && ((col != wcol && col != wcol + 1) || csize > 1)) {
      // 'virtualedit' is set: The difference between wcol and col is filled with spaces.

      if (line[idx] == NUL) {
        // Append spaces
        int correct = wcol - col;
        size_t newline_size;
        STRICT_ADD(idx, correct, &newline_size, size_t);
        char *newline = xmallocz(newline_size);
        memcpy(newline, line, (size_t)idx);
        memset(newline + idx, ' ', (size_t)correct);

        ml_replace(pos->lnum, newline, false);
        inserted_bytes(pos->lnum, (colnr_T)idx, 0, correct);
        idx += correct;
        col = wcol;
      } else {
        // Break a tab
        int correct = wcol - col - csize + 1;             // negative!!
        char *newline;

        if (-correct > csize) {
          return FAIL;
        }

        size_t n;
        STRICT_ADD(linelen - 1, csize, &n, size_t);
        newline = xmallocz(n);
        // Copy first idx chars
        memcpy(newline, line, (size_t)idx);
        // Replace idx'th char with csize spaces
        memset(newline + idx, ' ', (size_t)csize);
        // Copy the rest of the line
        STRICT_SUB(linelen, idx, &n, size_t);
        STRICT_SUB(n, 1, &n, size_t);
        memcpy(newline + idx + csize, line + idx + 1, n);

        ml_replace(pos->lnum, newline, false);
        inserted_bytes(pos->lnum, idx, 1, csize);
        idx += (csize - 1 + correct);
        col += correct;
      }
    }
  }

  pos->col = MAX(idx, 0);
  pos->coladd = 0;

  if (finetune) {
    if (wcol == MAXCOL) {
      // The width of the last character is used to set coladd.
      if (!one_more) {
        colnr_T scol, ecol;

        getvcol(wp, pos, &scol, NULL, &ecol);
        pos->coladd = ecol - scol;
      }
    } else {
      int b = (int)wcol - (int)col;

      // The difference between wcol and col is used to set coladd.
      if (b > 0 && b < (MAXCOL - 2 * wp->w_width_inner)) {
        pos->coladd = b;
      }

      col += b;
    }
  }

  // Prevent from moving onto a trail byte.
  mark_mb_adjustpos(wp->w_buffer, pos);

  if (wcol < 0 || col < wcol) {
    return FAIL;
  }
  return OK;
}

/// Return in "pos" the position of the cursor advanced to screen column "wcol".
///
/// @return  OK if desired column is reached, FAIL if not
int getvpos(win_T *wp, pos_T *pos, colnr_T wcol)
{
  return coladvance2(wp, pos, false, virtual_active(wp), wcol);
}

/// Increment the cursor position.  See inc() for return values.
int inc_cursor(void)
{
  return inc(&curwin->w_cursor);
}

/// Decrement the line pointer 'p' crossing line boundaries as necessary.
///
/// @return  1 when crossing a line, -1 when at start of file, 0 otherwise.
int dec_cursor(void)
{
  return dec(&curwin->w_cursor);
}

/// Get the line number relative to the current cursor position, i.e. the
/// difference between line number and cursor position. Only look for lines that
/// can be visible, folded lines don't count.
///
/// @param lnum line number to get the result for
linenr_T get_cursor_rel_lnum(win_T *wp, linenr_T lnum)
{
  linenr_T cursor = wp->w_cursor.lnum;
  if (lnum == cursor || !hasAnyFolding(wp)) {
    return lnum - cursor;
  }

  linenr_T from_line = lnum < cursor ? lnum : cursor;
  linenr_T to_line = lnum > cursor ? lnum : cursor;
  linenr_T retval = 0;

  // Loop until we reach to_line, skipping folds.
  for (; from_line < to_line; from_line++, retval++) {
    // If from_line is in a fold, set it to the last line of that fold.
    hasFolding(wp, from_line, NULL, &from_line);
  }

  // If to_line is in a closed fold, the line count is off by +1. Correct it.
  if (from_line > to_line) {
    retval--;
  }

  return (lnum < cursor) ? -retval : retval;
}

/// Make sure "pos.lnum" and "pos.col" are valid in "buf".
/// This allows for the col to be on the NUL byte.
void check_pos(buf_T *buf, pos_T *pos)
{
  pos->lnum = MIN(pos->lnum, buf->b_ml.ml_line_count);
  if (pos->col > 0) {
    pos->col = MIN(pos->col, ml_get_buf_len(buf, pos->lnum));
  }
}

/// Make sure curwin->w_cursor.lnum is valid.
void check_cursor_lnum(win_T *win)
{
  buf_T *buf = win->w_buffer;
  if (win->w_cursor.lnum > buf->b_ml.ml_line_count) {
    // If there is a closed fold at the end of the file, put the cursor in
    // its first line.  Otherwise in the last line.
    if (!hasFolding(win, buf->b_ml.ml_line_count, &win->w_cursor.lnum, NULL)) {
      win->w_cursor.lnum = buf->b_ml.ml_line_count;
    }
  }
  if (win->w_cursor.lnum <= 0) {
    win->w_cursor.lnum = 1;
  }
}

/// Make sure win->w_cursor.col is valid. Special handling of insert-mode.
/// @see mb_check_adjust_col
void check_cursor_col(win_T *win)
{
  colnr_T oldcol = win->w_cursor.col;
  colnr_T oldcoladd = win->w_cursor.col + win->w_cursor.coladd;
  unsigned cur_ve_flags = get_ve_flags(win);

  colnr_T len = ml_get_buf_len(win->w_buffer, win->w_cursor.lnum);
  if (len == 0) {
    win->w_cursor.col = 0;
  } else if (win->w_cursor.col >= len) {
    // Allow cursor past end-of-line when:
    // - in Insert mode or restarting Insert mode
    // - in Visual mode and 'selection' isn't "old"
    // - 'virtualedit' is set
    if ((State & MODE_INSERT) || restart_edit
        || (VIsual_active && *p_sel != 'o')
        || (cur_ve_flags & kOptVeFlagOnemore)
        || virtual_active(win)) {
      win->w_cursor.col = len;
    } else {
      win->w_cursor.col = len - 1;
      // Move the cursor to the head byte.
      mark_mb_adjustpos(win->w_buffer, &win->w_cursor);
    }
  } else if (win->w_cursor.col < 0) {
    win->w_cursor.col = 0;
  }

  // If virtual editing is on, we can leave the cursor on the old position,
  // only we must set it to virtual.  But don't do it when at the end of the
  // line.
  if (oldcol == MAXCOL) {
    win->w_cursor.coladd = 0;
  } else if (cur_ve_flags == kOptVeFlagAll) {
    if (oldcoladd > win->w_cursor.col) {
      win->w_cursor.coladd = oldcoladd - win->w_cursor.col;

      // Make sure that coladd is not more than the char width.
      // Not for the last character, coladd is then used when the cursor
      // is actually after the last character.
      if (win->w_cursor.col + 1 < len) {
        assert(win->w_cursor.coladd > 0);
        int cs, ce;

        getvcol(win, &win->w_cursor, &cs, NULL, &ce);
        win->w_cursor.coladd = MIN(win->w_cursor.coladd, ce - cs);
      }
    } else {
      // avoid weird number when there is a miscalculation or overflow
      win->w_cursor.coladd = 0;
    }
  }
}

/// Make sure curwin->w_cursor in on a valid character
void check_cursor(win_T *wp)
{
  check_cursor_lnum(wp);
  check_cursor_col(wp);
}

/// Check if VIsual position is valid, correct it if not.
/// Can be called when in Visual mode and a change has been made.
void check_visual_pos(void)
{
  if (VIsual.lnum > curbuf->b_ml.ml_line_count) {
    VIsual.lnum = curbuf->b_ml.ml_line_count;
    VIsual.col = 0;
    VIsual.coladd = 0;
  } else {
    int len = ml_get_len(VIsual.lnum);

    if (VIsual.col > len) {
      VIsual.col = len;
      VIsual.coladd = 0;
    }
  }
}

/// Make sure curwin->w_cursor is not on the NUL at the end of the line.
/// Allow it when in Visual mode and 'selection' is not "old".
void adjust_cursor_col(void)
{
  if (curwin->w_cursor.col > 0
      && (!VIsual_active || *p_sel == 'o')
      && gchar_cursor() == NUL) {
    curwin->w_cursor.col--;
  }
}

/// Set "curwin->w_leftcol" to "leftcol".
/// Adjust the cursor position if needed.
///
/// @return  true if the cursor was moved.
bool set_leftcol(colnr_T leftcol)
{
  // Return quickly when there is no change.
  if (curwin->w_leftcol == leftcol) {
    return false;
  }
  curwin->w_leftcol = leftcol;

  changed_cline_bef_curs(curwin);
  // TODO(hinidu): I think it should be colnr_T or int, but p_siso is long.
  // Perhaps we can change p_siso to int.
  int64_t lastcol = curwin->w_leftcol + curwin->w_width_inner - win_col_off(curwin) - 1;
  validate_virtcol(curwin);

  bool retval = false;
  // If the cursor is right or left of the screen, move it to last or first
  // visible character.
  int siso = get_sidescrolloff_value(curwin);
  if (curwin->w_virtcol > (colnr_T)(lastcol - siso)) {
    retval = true;
    coladvance(curwin, (colnr_T)(lastcol - siso));
  } else if (curwin->w_virtcol < curwin->w_leftcol + siso) {
    retval = true;
    coladvance(curwin, (colnr_T)(curwin->w_leftcol + siso));
  }

  // If the start of the character under the cursor is not on the screen,
  // advance the cursor one more char.  If this fails (last char of the
  // line) adjust the scrolling.
  colnr_T s, e;
  getvvcol(curwin, &curwin->w_cursor, &s, NULL, &e);
  if (e > (colnr_T)lastcol) {
    retval = true;
    coladvance(curwin, s - 1);
  } else if (s < curwin->w_leftcol) {
    retval = true;
    if (coladvance(curwin, e + 1) == FAIL) {    // there isn't another character
      curwin->w_leftcol = s;            // adjust w_leftcol instead
      changed_cline_bef_curs(curwin);
    }
  }

  if (retval) {
    curwin->w_set_curswant = true;
  }
  redraw_later(curwin, UPD_NOT_VALID);
  return retval;
}

int gchar_cursor(void)
{
  return utf_ptr2char(get_cursor_pos_ptr());
}

/// Write a character at the current cursor position.
/// It is directly written into the block.
void pchar_cursor(char c)
{
  *(ml_get_buf_mut(curbuf, curwin->w_cursor.lnum) + curwin->w_cursor.col) = c;
}

/// @return  pointer to cursor line.
char *get_cursor_line_ptr(void)
{
  return ml_get_buf(curbuf, curwin->w_cursor.lnum);
}

/// @return  pointer to cursor position.
char *get_cursor_pos_ptr(void)
{
  return ml_get_buf(curbuf, curwin->w_cursor.lnum) + curwin->w_cursor.col;
}

/// @return  length (excluding the NUL) of the cursor line.
colnr_T get_cursor_line_len(void)
{
  return ml_get_buf_len(curbuf, curwin->w_cursor.lnum);
}

/// @return  length (excluding the NUL) of the cursor position.
colnr_T get_cursor_pos_len(void)
{
  return ml_get_buf_len(curbuf, curwin->w_cursor.lnum) - curwin->w_cursor.col;
}
