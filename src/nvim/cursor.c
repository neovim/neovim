// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdbool.h>
#include <inttypes.h>

#include "nvim/assert.h"
#include "nvim/change.h"
#include "nvim/cursor.h"
#include "nvim/charset.h"
#include "nvim/fold.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/screen.h"
#include "nvim/state.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/mark.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cursor.c.generated.h"
#endif

/*
 * Get the screen position of the cursor.
 */
int getviscol(void)
{
  colnr_T x;

  getvvcol(curwin, &curwin->w_cursor, &x, NULL, NULL);
  return (int)x;
}

/*
 * Get the screen position of character col with a coladd in the cursor line.
 */
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

/*
 * Go to column "wcol", and add/insert white space as necessary to get the
 * cursor in that column.
 * The caller must have saved the cursor line for undo!
 */
int coladvance_force(colnr_T wcol)
{
  int rc = coladvance2(&curwin->w_cursor, true, false, wcol);

  if (wcol == MAXCOL) {
    curwin->w_valid &= ~VALID_VIRTCOL;
  } else {
    /* Virtcol is valid */
    curwin->w_valid |= VALID_VIRTCOL;
    curwin->w_virtcol = wcol;
  }
  return rc;
}

/*
 * Try to advance the Cursor to the specified screen column.
 * If virtual editing: fine tune the cursor position.
 * Note that all virtual positions off the end of a line should share
 * a curwin->w_cursor.col value (n.b. this is equal to STRLEN(line)),
 * beginning at coladd 0.
 *
 * return OK if desired column is reached, FAIL if not
 */
int coladvance(colnr_T wcol)
{
  int rc = getvpos(&curwin->w_cursor, wcol);

  if (wcol == MAXCOL || rc == FAIL)
    curwin->w_valid &= ~VALID_VIRTCOL;
  else if (*get_cursor_pos_ptr() != TAB) {
    /* Virtcol is valid when not on a TAB */
    curwin->w_valid |= VALID_VIRTCOL;
    curwin->w_virtcol = wcol;
  }
  return rc;
}

static int coladvance2(
    pos_T *pos,
    bool addspaces,                /* change the text to achieve our goal? */
    bool finetune,                 /* change char offset for the exact column */
    colnr_T wcol                   /* column to move to */
)
{
  int idx;
  char_u      *ptr;
  char_u      *line;
  colnr_T col = 0;
  int csize = 0;
  int one_more;
  int head = 0;

  one_more = (State & INSERT)
             || restart_edit != NUL
             || (VIsual_active && *p_sel != 'o')
             || ((ve_flags & VE_ONEMORE) && wcol < MAXCOL);
  line = ml_get_buf(curbuf, pos->lnum, false);

  if (wcol >= MAXCOL) {
    idx = (int)STRLEN(line) - 1 + one_more;
    col = wcol;

    if ((addspaces || finetune) && !VIsual_active) {
      curwin->w_curswant = linetabsize(line) + one_more;
      if (curwin->w_curswant > 0)
        --curwin->w_curswant;
    }
  } else {
    int width = curwin->w_width_inner - win_col_off(curwin);

    if (finetune
        && curwin->w_p_wrap
        && curwin->w_width_inner != 0
        && wcol >= (colnr_T)width) {
      csize = linetabsize(line);
      if (csize > 0)
        csize--;

      if (wcol / width > (colnr_T)csize / width
          && ((State & INSERT) == 0 || (int)wcol > csize + 1)) {
        /* In case of line wrapping don't move the cursor beyond the
         * right screen edge.  In Insert mode allow going just beyond
         * the last character (like what happens when typing and
         * reaching the right window edge). */
        wcol = (csize / width + 1) * width - 1;
      }
    }

    ptr = line;
    while (col <= wcol && *ptr != NUL) {
      /* Count a tab for what it's worth (if list mode not on) */
      csize = win_lbr_chartabsize(curwin, line, ptr, col, &head);
      MB_PTR_ADV(ptr);
      col += csize;
    }
    idx = (int)(ptr - line);
    /*
     * Handle all the special cases.  The virtual_active() check
     * is needed to ensure that a virtual position off the end of
     * a line has the correct indexing.  The one_more comparison
     * replaces an explicit add of one_more later on.
     */
    if (col > wcol || (!virtual_active() && one_more == 0)) {
      idx -= 1;
      /* Don't count the chars from 'showbreak'. */
      csize -= head;
      col -= csize;
    }

    if (virtual_active()
        && addspaces
        && ((col != wcol && col != wcol + 1) || csize > 1)) {
      /* 'virtualedit' is set: The difference between wcol and col is
       * filled with spaces. */

      if (line[idx] == NUL) {
        /* Append spaces */
        int correct = wcol - col;
        size_t newline_size;
        STRICT_ADD(idx, correct, &newline_size, size_t);
        char_u *newline = xmallocz(newline_size);
        memcpy(newline, line, (size_t)idx);
        memset(newline + idx, ' ', (size_t)correct);

        ml_replace(pos->lnum, newline, false);
        changed_bytes(pos->lnum, (colnr_T)idx);
        idx += correct;
        col = wcol;
      } else {
        /* Break a tab */
        int linelen = (int)STRLEN(line);
        int correct = wcol - col - csize + 1;             /* negative!! */
        char_u  *newline;

        if (-correct > csize)
          return FAIL;

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
        changed_bytes(pos->lnum, idx);
        idx += (csize - 1 + correct);
        col += correct;
      }
    }
  }

  if (idx < 0)
    pos->col = 0;
  else
    pos->col = idx;

  pos->coladd = 0;

  if (finetune) {
    if (wcol == MAXCOL) {
      /* The width of the last character is used to set coladd. */
      if (!one_more) {
        colnr_T scol, ecol;

        getvcol(curwin, pos, &scol, NULL, &ecol);
        pos->coladd = ecol - scol;
      }
    } else {
      int b = (int)wcol - (int)col;

      // The difference between wcol and col is used to set coladd.
      if (b > 0 && b < (MAXCOL - 2 * curwin->w_width_inner)) {
        pos->coladd = b;
      }

      col += b;
    }
  }

  // Prevent from moving onto a trail byte.
  if (has_mbyte) {
    mark_mb_adjustpos(curbuf, pos);
  }

  if (col < wcol)
    return FAIL;
  return OK;
}

/*
 * Return in "pos" the position of the cursor advanced to screen column "wcol".
 * return OK if desired column is reached, FAIL if not
 */
int getvpos(pos_T *pos, colnr_T wcol)
{
  return coladvance2(pos, false, virtual_active(), wcol);
}

/*
 * Increment the cursor position.  See inc() for return values.
 */
int inc_cursor(void)
{
  return inc(&curwin->w_cursor);
}

/*
 * dec(p)
 *
 * Decrement the line pointer 'p' crossing line boundaries as necessary.
 * Return 1 when crossing a line, -1 when at start of file, 0 otherwise.
 */
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
    (void)hasFoldingWin(wp, from_line, NULL, &from_line, true, NULL);
  }

  // If to_line is in a closed fold, the line count is off by +1. Correct it.
  if (from_line > to_line) {
    retval--;
  }

  return (lnum < cursor) ? -retval : retval;
}

// Make sure "pos.lnum" and "pos.col" are valid in "buf".
// This allows for the col to be on the NUL byte.
void check_pos(buf_T *buf, pos_T *pos)
{
  char_u *line;
  colnr_T len;

  if (pos->lnum > buf->b_ml.ml_line_count) {
     pos->lnum = buf->b_ml.ml_line_count;
  }

  if (pos->col > 0) {
     line = ml_get_buf(buf, pos->lnum, false);
     len = (colnr_T)STRLEN(line);
     if (pos->col > len) {
         pos->col = len;
     }
  }
}

/*
 * Make sure curwin->w_cursor.lnum is valid.
 */
void check_cursor_lnum(void)
{
  if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
    /* If there is a closed fold at the end of the file, put the cursor in
     * its first line.  Otherwise in the last line. */
    if (!hasFolding(curbuf->b_ml.ml_line_count,
            &curwin->w_cursor.lnum, NULL))
      curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  }
  if (curwin->w_cursor.lnum <= 0)
    curwin->w_cursor.lnum = 1;
}

/*
 * Make sure curwin->w_cursor.col is valid.
 */
void check_cursor_col(void)
{
  check_cursor_col_win(curwin);
}

/// Make sure win->w_cursor.col is valid. Special handling of insert-mode.
/// @see mb_check_adjust_col
void check_cursor_col_win(win_T *win)
{
  colnr_T len;
  colnr_T oldcol = win->w_cursor.col;
  colnr_T oldcoladd = win->w_cursor.col + win->w_cursor.coladd;

  len = (colnr_T)STRLEN(ml_get_buf(win->w_buffer, win->w_cursor.lnum, false));
  if (len == 0) {
    win->w_cursor.col = 0;
  } else if (win->w_cursor.col >= len) {
    /* Allow cursor past end-of-line when:
     * - in Insert mode or restarting Insert mode
     * - in Visual mode and 'selection' isn't "old"
     * - 'virtualedit' is set */
    if ((State & INSERT) || restart_edit
        || (VIsual_active && *p_sel != 'o')
        || (ve_flags & VE_ONEMORE)
        || virtual_active()) {
      win->w_cursor.col = len;
    } else {
      win->w_cursor.col = len - 1;
      // Move the cursor to the head byte.
      if (has_mbyte) {
        mark_mb_adjustpos(win->w_buffer, &win->w_cursor);
      }
    }
  } else if (win->w_cursor.col < 0) {
    win->w_cursor.col = 0;
  }

  // If virtual editing is on, we can leave the cursor on the old position,
  // only we must set it to virtual.  But don't do it when at the end of the
  // line.
  if (oldcol == MAXCOL) {
    win->w_cursor.coladd = 0;
  } else if (ve_flags == VE_ALL) {
    if (oldcoladd > win->w_cursor.col) {
      win->w_cursor.coladd = oldcoladd - win->w_cursor.col;

      // Make sure that coladd is not more than the char width.
      // Not for the last character, coladd is then used when the cursor
      // is actually after the last character.
      if (win->w_cursor.col + 1 < len) {
        assert(win->w_cursor.coladd > 0);
        int cs, ce;

        getvcol(win, &win->w_cursor, &cs, NULL, &ce);
        if (win->w_cursor.coladd > ce - cs) {
          win->w_cursor.coladd = ce - cs;
        }
      }
    } else {
      // avoid weird number when there is a miscalculation or overflow
      win->w_cursor.coladd = 0;
    }
  }
}

/*
 * make sure curwin->w_cursor in on a valid character
 */
void check_cursor(void)
{
  check_cursor_lnum();
  check_cursor_col();
}

/*
 * Make sure curwin->w_cursor is not on the NUL at the end of the line.
 * Allow it when in Visual mode and 'selection' is not "old".
 */
void adjust_cursor_col(void)
{
  if (curwin->w_cursor.col > 0
      && (!VIsual_active || *p_sel == 'o')
      && gchar_cursor() == NUL)
    --curwin->w_cursor.col;
}

/*
 * When curwin->w_leftcol has changed, adjust the cursor position.
 * Return true if the cursor was moved.
 */
bool leftcol_changed(void)
{
  // TODO(hinidu): I think it should be colnr_T or int, but p_siso is long.
  // Perhaps we can change p_siso to int.
  int64_t lastcol;
  colnr_T s, e;
  bool retval = false;

  changed_cline_bef_curs();
  lastcol = curwin->w_leftcol + curwin->w_width_inner - curwin_col_off() - 1;
  validate_virtcol();

  /*
   * If the cursor is right or left of the screen, move it to last or first
   * character.
   */
  if (curwin->w_virtcol > (colnr_T)(lastcol - p_siso)) {
    retval = true;
    coladvance((colnr_T)(lastcol - p_siso));
  } else if (curwin->w_virtcol < curwin->w_leftcol + p_siso) {
    retval = true;
    coladvance((colnr_T)(curwin->w_leftcol + p_siso));
  }

  /*
   * If the start of the character under the cursor is not on the screen,
   * advance the cursor one more char.  If this fails (last char of the
   * line) adjust the scrolling.
   */
  getvvcol(curwin, &curwin->w_cursor, &s, NULL, &e);
  if (e > (colnr_T)lastcol) {
    retval = true;
    coladvance(s - 1);
  } else if (s < curwin->w_leftcol) {
    retval = true;
    if (coladvance(e + 1) == FAIL) {    /* there isn't another character */
      curwin->w_leftcol = s;            /* adjust w_leftcol instead */
      changed_cline_bef_curs();
    }
  }

  if (retval)
    curwin->w_set_curswant = true;
  redraw_later(NOT_VALID);
  return retval;
}

int gchar_cursor(void)
{
  return utf_ptr2char(get_cursor_pos_ptr());
}

/*
 * Write a character at the current cursor position.
 * It is directly written into the block.
 */
void pchar_cursor(char_u c)
{
  *(ml_get_buf(curbuf, curwin->w_cursor.lnum, true)
    + curwin->w_cursor.col) = c;
}

/*
 * Return pointer to cursor line.
 */
char_u *get_cursor_line_ptr(void)
{
  return ml_get_buf(curbuf, curwin->w_cursor.lnum, false);
}

/*
 * Return pointer to cursor position.
 */
char_u *get_cursor_pos_ptr(void)
{
  return ml_get_buf(curbuf, curwin->w_cursor.lnum, false) +
         curwin->w_cursor.col;
}
