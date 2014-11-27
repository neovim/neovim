/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * ui.c: functions that handle the user interface.
 * 1. Keyboard input stuff, and a bit of windowing stuff.  These are called
 *    before the machine specific stuff (mch_*) so that we can call the GUI
 *    stuff instead if the GUI is running.
 * 2. Clipboard stuff.
 * 3. Input buffer stuff.
 */

#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/ex_cmds2.h"
#include "nvim/fold.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/garray.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"
#include "nvim/os/signal.h"
#include "nvim/screen.h"
#include "nvim/term.h"
#include "nvim/window.h"

void ui_write(char_u *s, int len)
{
  /* Don't output anything in silent mode ("ex -s") unless 'verbose' set */
  if (!(silent_mode && p_verbose == 0)) {
    char_u  *tofree = NULL;

    if (output_conv.vc_type != CONV_NONE) {
      /* Convert characters from 'encoding' to 'termencoding'. */
      tofree = string_convert(&output_conv, s, &len);
      if (tofree != NULL)
        s = tofree;
    }

    mch_write(s, len);

    if (output_conv.vc_type != CONV_NONE)
      free(tofree);
  }
}

/*
 * Delay for the given number of milliseconds.	If ignoreinput is FALSE then we
 * cancel the delay if a key is hit.
 */
void ui_delay(long msec, bool ignoreinput)
{
  os_delay(msec, ignoreinput);
}

/*
 * If the machine has job control, use it to suspend the program,
 * otherwise fake it by starting a new shell.
 * When running the GUI iconify the window.
 */
void ui_suspend(void)
{
  mch_suspend();
}

/*
 * Try to get the current Vim shell size.  Put the result in Rows and Columns.
 * Use the new sizes as defaults for 'columns' and 'lines'.
 * Return OK when size could be determined, FAIL otherwise.
 */
int ui_get_shellsize(void)
{
  int retval;

  retval = mch_get_shellsize();

  check_shellsize();

  /* adjust the default for 'lines' and 'columns' */
  if (retval == OK) {
    set_number_default("lines", Rows);
    set_number_default("columns", Columns);
  }
  return retval;
}

/*
 * Set the size of the Vim shell according to Rows and Columns, if possible.
 * The gui_set_shellsize() or mch_set_shellsize() function will try to set the
 * new size.  If this is not possible, it will adjust Rows and Columns.
 */
void 
ui_set_shellsize(int mustset)
{
  mch_set_shellsize();
}

void ui_breakcheck(void)
{
  os_breakcheck();
}

/*****************************************************************************
 * Functions for copying and pasting text between applications.
 * This is always included in a GUI version, but may also be included when the
 * clipboard and mouse is available to a terminal version such as xterm.
 * Note: there are some more functions in ops.c that handle selection stuff.
 *
 * Also note that the majority of functions here deal with the X 'primary'
 * (visible - for Visual mode use) selection, and only that. There are no
 * versions of these for the 'clipboard' selection, as Visual mode has no use
 * for them.
 */

/*
 * Exit because of an input read error.
 */
void read_error_exit(void)
{
  if (silent_mode)      /* Normal way to exit for "ex -s" */
    getout(0);
  STRCPY(IObuff, _("Vim: Error reading input, exiting...\n"));
  preserve_exit();
}

/*
 * May update the shape of the cursor.
 */
void ui_cursor_shape(void)
{
  term_cursor_shape();


  conceal_check_cursur_line();
}

/*
 * Check bounds for column number
 */
int check_col(int col)
{
  if (col < 0)
    return 0;
  if (col >= (int)screen_Columns)
    return (int)screen_Columns - 1;
  return col;
}

/*
 * Check bounds for row number
 */
int check_row(int row)
{
  if (row < 0)
    return 0;
  if (row >= (int)screen_Rows)
    return (int)screen_Rows - 1;
  return row;
}

/*
 * Stuff for the X clipboard.  Shared between VMS and Unix.
 */

/*
 * Move the cursor to the specified row and column on the screen.
 * Change current window if necessary.	Returns an integer with the
 * CURSOR_MOVED bit set if the cursor has moved or unset otherwise.
 *
 * The MOUSE_FOLD_CLOSE bit is set when clicked on the '-' in a fold column.
 * The MOUSE_FOLD_OPEN bit is set when clicked on the '+' in a fold column.
 *
 * If flags has MOUSE_FOCUS, then the current window will not be changed, and
 * if the mouse is outside the window then the text will scroll, or if the
 * mouse was previously on a status line, then the status line may be dragged.
 *
 * If flags has MOUSE_MAY_VIS, then VIsual mode will be started before the
 * cursor is moved unless the cursor was on a status line.
 * This function returns one of IN_UNKNOWN, IN_BUFFER, IN_STATUS_LINE or
 * IN_SEP_LINE depending on where the cursor was clicked.
 *
 * If flags has MOUSE_MAY_STOP_VIS, then Visual mode will be stopped, unless
 * the mouse is on the status line of the same window.
 *
 * If flags has MOUSE_DID_MOVE, nothing is done if the mouse didn't move since
 * the last call.
 *
 * If flags has MOUSE_SETPOS, nothing is done, only the current position is
 * remembered.
 */
int 
jump_to_mouse (
    int flags,
    bool *inclusive,        /* used for inclusive operator, can be NULL */
    int which_button               /* MOUSE_LEFT, MOUSE_RIGHT, MOUSE_MIDDLE */
)
{
  static int on_status_line = 0;        /* #lines below bottom of window */
  static int on_sep_line = 0;           /* on separator right of window */
  static int prev_row = -1;
  static int prev_col = -1;
  static win_T *dragwin = NULL;         /* window being dragged */
  static int did_drag = FALSE;          /* drag was noticed */

  win_T       *wp, *old_curwin;
  pos_T old_cursor;
  int count;
  bool first;
  int row = mouse_row;
  int col = mouse_col;
  int mouse_char;

  mouse_past_bottom = false;
  mouse_past_eol = false;

  if (flags & MOUSE_RELEASED) {
    /* On button release we may change window focus if positioned on a
     * status line and no dragging happened. */
    if (dragwin != NULL && !did_drag)
      flags &= ~(MOUSE_FOCUS | MOUSE_DID_MOVE);
    dragwin = NULL;
    did_drag = FALSE;
  }

  if ((flags & MOUSE_DID_MOVE)
      && prev_row == mouse_row
      && prev_col == mouse_col) {
retnomove:
    /* before moving the cursor for a left click which is NOT in a status
     * line, stop Visual mode */
    if (on_status_line)
      return IN_STATUS_LINE;
    if (on_sep_line)
      return IN_SEP_LINE;
    if (flags & MOUSE_MAY_STOP_VIS) {
      end_visual_mode();
      redraw_curbuf_later(INVERTED);            /* delete the inversion */
    }
    return IN_BUFFER;
  }

  prev_row = mouse_row;
  prev_col = mouse_col;

  if (flags & MOUSE_SETPOS)
    goto retnomove;                             /* ugly goto... */

  /* Remember the character under the mouse, it might be a '-' or '+' in the
   * fold column. */
  if (row >= 0 && row < Rows && col >= 0 && col <= Columns
      && ScreenLines != NULL)
    mouse_char = ScreenLines[LineOffset[row] + col];
  else
    mouse_char = ' ';

  old_curwin = curwin;
  old_cursor = curwin->w_cursor;

  if (!(flags & MOUSE_FOCUS)) {
    if (row < 0 || col < 0)                     /* check if it makes sense */
      return IN_UNKNOWN;

    /* find the window where the row is in */
    wp = mouse_find_win(&row, &col);
    dragwin = NULL;
    /*
     * winpos and height may change in win_enter()!
     */
    if (row >= wp->w_height) {                  /* In (or below) status line */
      on_status_line = row - wp->w_height + 1;
      dragwin = wp;
    } else
      on_status_line = 0;
    if (col >= wp->w_width) {           /* In separator line */
      on_sep_line = col - wp->w_width + 1;
      dragwin = wp;
    } else
      on_sep_line = 0;

    /* The rightmost character of the status line might be a vertical
     * separator character if there is no connecting window to the right. */
    if (on_status_line && on_sep_line) {
      if (stl_connected(wp))
        on_sep_line = 0;
      else
        on_status_line = 0;
    }

    /* Before jumping to another buffer, or moving the cursor for a left
     * click, stop Visual mode. */
    if (VIsual_active
        && (wp->w_buffer != curwin->w_buffer
            || (!on_status_line
                && !on_sep_line
                && (
                  wp->w_p_rl ? col < wp->w_width - wp->w_p_fdc :
                                     col >= wp->w_p_fdc
                                             + (cmdwin_type == 0 && wp ==
                                                curwin ? 0 : 1)
                  )
                && (flags & MOUSE_MAY_STOP_VIS)))) {
      end_visual_mode();
      redraw_curbuf_later(INVERTED);            /* delete the inversion */
    }
    if (cmdwin_type != 0 && wp != curwin) {
      /* A click outside the command-line window: Use modeless
       * selection if possible.  Allow dragging the status lines. */
      on_sep_line = 0;
      row = 0;
      col += wp->w_wincol;
      wp = curwin;
    }
    /* Only change window focus when not clicking on or dragging the
     * status line.  Do change focus when releasing the mouse button
     * (MOUSE_FOCUS was set above if we dragged first). */
    if (dragwin == NULL || (flags & MOUSE_RELEASED))
      win_enter(wp, true);                      /* can make wp invalid! */
# ifdef CHECK_DOUBLE_CLICK
    /* set topline, to be able to check for double click ourselves */
    if (curwin != old_curwin)
      set_mouse_topline(curwin);
# endif
    if (on_status_line) {                       /* In (or below) status line */
      /* Don't use start_arrow() if we're in the same window */
      if (curwin == old_curwin)
        return IN_STATUS_LINE;
      else
        return IN_STATUS_LINE | CURSOR_MOVED;
    }
    if (on_sep_line) {                          /* In (or below) status line */
      /* Don't use start_arrow() if we're in the same window */
      if (curwin == old_curwin)
        return IN_SEP_LINE;
      else
        return IN_SEP_LINE | CURSOR_MOVED;
    }

    curwin->w_cursor.lnum = curwin->w_topline;
  } else if (on_status_line && which_button == MOUSE_LEFT)   {
    if (dragwin != NULL) {
      /* Drag the status line */
      count = row - dragwin->w_winrow - dragwin->w_height + 1
              - on_status_line;
      win_drag_status_line(dragwin, count);
      did_drag |= count;
    }
    return IN_STATUS_LINE;                      /* Cursor didn't move */
  } else if (on_sep_line && which_button == MOUSE_LEFT)   {
    if (dragwin != NULL) {
      /* Drag the separator column */
      count = col - dragwin->w_wincol - dragwin->w_width + 1
              - on_sep_line;
      win_drag_vsep_line(dragwin, count);
      did_drag |= count;
    }
    return IN_SEP_LINE;                         /* Cursor didn't move */
  } else { /* keep_window_focus must be TRUE */
          /* before moving the cursor for a left click, stop Visual mode */
    if (flags & MOUSE_MAY_STOP_VIS) {
      end_visual_mode();
      redraw_curbuf_later(INVERTED);            /* delete the inversion */
    }


    row -= curwin->w_winrow;
    col -= curwin->w_wincol;

    /*
     * When clicking beyond the end of the window, scroll the screen.
     * Scroll by however many rows outside the window we are.
     */
    if (row < 0) {
      count = 0;
      for (first = true; curwin->w_topline > 1; ) {
        if (curwin->w_topfill < diff_check(curwin, curwin->w_topline))
          ++count;
        else
          count += plines(curwin->w_topline - 1);
        if (!first && count > -row)
          break;
        first = false;
        hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
        if (curwin->w_topfill < diff_check(curwin, curwin->w_topline))
          ++curwin->w_topfill;
        else {
          --curwin->w_topline;
          curwin->w_topfill = 0;
        }
      }
      check_topfill(curwin, false);
      curwin->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
      redraw_later(VALID);
      row = 0;
    } else if (row >= curwin->w_height)   {
      count = 0;
      for (first = true; curwin->w_topline < curbuf->b_ml.ml_line_count; ) {
        if (curwin->w_topfill > 0)
          ++count;
        else
          count += plines(curwin->w_topline);
        if (!first && count > row - curwin->w_height + 1)
          break;
        first = false;
        if (hasFolding(curwin->w_topline, NULL, &curwin->w_topline)
            && curwin->w_topline == curbuf->b_ml.ml_line_count)
          break;
        if (curwin->w_topfill > 0)
          --curwin->w_topfill;
        else {
          ++curwin->w_topline;
          curwin->w_topfill =
            diff_check_fill(curwin, curwin->w_topline);
        }
      }
      check_topfill(curwin, false);
      redraw_later(VALID);
      curwin->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
      row = curwin->w_height - 1;
    } else if (row == 0)   {
      /* When dragging the mouse, while the text has been scrolled up as
       * far as it goes, moving the mouse in the top line should scroll
       * the text down (done later when recomputing w_topline). */
      if (mouse_dragging > 0
          && curwin->w_cursor.lnum
          == curwin->w_buffer->b_ml.ml_line_count
          && curwin->w_cursor.lnum == curwin->w_topline)
        curwin->w_valid &= ~(VALID_TOPLINE);
    }
  }

  /* Check for position outside of the fold column. */
  if (
    curwin->w_p_rl ? col < curwin->w_width - curwin->w_p_fdc :
                           col >= curwin->w_p_fdc
                                   + (cmdwin_type == 0 ? 0 : 1)
    )
    mouse_char = ' ';

  /* compute the position in the buffer line from the posn on the screen */
  if (mouse_comp_pos(curwin, &row, &col, &curwin->w_cursor.lnum))
    mouse_past_bottom = true;

  /* Start Visual mode before coladvance(), for when 'sel' != "old" */
  if ((flags & MOUSE_MAY_VIS) && !VIsual_active) {
    check_visual_highlight();
    VIsual = old_cursor;
    VIsual_active = TRUE;
    VIsual_reselect = TRUE;
    /* if 'selectmode' contains "mouse", start Select mode */
    may_start_select('o');
    setmouse();
    if (p_smd && msg_silent == 0)
      redraw_cmdline = TRUE;            /* show visual mode later */
  }

  curwin->w_curswant = col;
  curwin->w_set_curswant = FALSE;       /* May still have been TRUE */
  if (coladvance(col) == FAIL) {        /* Mouse click beyond end of line */
    if (inclusive != NULL)
      *inclusive = true;
    mouse_past_eol = true;
  } else if (inclusive != NULL)
    *inclusive = false;

  count = IN_BUFFER;
  if (curwin != old_curwin || curwin->w_cursor.lnum != old_cursor.lnum
      || curwin->w_cursor.col != old_cursor.col)
    count |= CURSOR_MOVED;              /* Cursor has moved */

  if (mouse_char == '+')
    count |= MOUSE_FOLD_OPEN;
  else if (mouse_char != ' ')
    count |= MOUSE_FOLD_CLOSE;

  return count;
}

/*
 * Compute the position in the buffer line from the posn on the screen in
 * window "win".
 * Returns TRUE if the position is below the last line.
 */
bool mouse_comp_pos(win_T *win, int *rowp, int *colp, linenr_T *lnump)
{
  int col = *colp;
  int row = *rowp;
  linenr_T lnum;
  bool retval = false;
  int off;
  int count;

  if (win->w_p_rl)
    col = win->w_width - 1 - col;

  lnum = win->w_topline;

  while (row > 0) {
    /* Don't include filler lines in "count" */
    if (win->w_p_diff
        && !hasFoldingWin(win, lnum, NULL, NULL, TRUE, NULL)
        ) {
      if (lnum == win->w_topline)
        row -= win->w_topfill;
      else
        row -= diff_check_fill(win, lnum);
      count = plines_win_nofill(win, lnum, TRUE);
    } else
      count = plines_win(win, lnum, TRUE);
    if (count > row)
      break;            /* Position is in this buffer line. */
    (void)hasFoldingWin(win, lnum, NULL, &lnum, TRUE, NULL);
    if (lnum == win->w_buffer->b_ml.ml_line_count) {
      retval = true;
      break;                    /* past end of file */
    }
    row -= count;
    ++lnum;
  }

  if (!retval) {
    /* Compute the column without wrapping. */
    off = win_col_off(win) - win_col_off2(win);
    if (col < off)
      col = off;
    col += row * (win->w_width - off);
    /* add skip column (for long wrapping line) */
    col += win->w_skipcol;
  }

  if (!win->w_p_wrap)
    col += win->w_leftcol;

  /* skip line number and fold column in front of the line */
  col -= win_col_off(win);
  if (col < 0) {
    col = 0;
  }

  *colp = col;
  *rowp = row;
  *lnump = lnum;
  return retval;
}

/*
 * Find the window at screen position "*rowp" and "*colp".  The positions are
 * updated to become relative to the top-left of the window.
 */
win_T *mouse_find_win(int *rowp, int *colp)
{
  frame_T     *fp;

  fp = topframe;
  *rowp -= firstwin->w_winrow;
  for (;; ) {
    if (fp->fr_layout == FR_LEAF)
      break;
    if (fp->fr_layout == FR_ROW) {
      for (fp = fp->fr_child; fp->fr_next != NULL; fp = fp->fr_next) {
        if (*colp < fp->fr_width)
          break;
        *colp -= fp->fr_width;
      }
    } else {  /* fr_layout == FR_COL */
      for (fp = fp->fr_child; fp->fr_next != NULL; fp = fp->fr_next) {
        if (*rowp < fp->fr_height)
          break;
        *rowp -= fp->fr_height;
      }
    }
  }
  return fp->fr_win;
}

#if defined(USE_IM_CONTROL) || defined(PROTO)
/*
 * Save current Input Method status to specified place.
 */
void im_save_status(long *psave)
{
  /* Don't save when 'imdisable' is set or "xic" is NULL, IM is always
   * disabled then (but might start later).
   * Also don't save when inside a mapping, vgetc_im_active has not been set
   * then.
   * And don't save when the keys were stuffed (e.g., for a "." command).
   * And don't save when the GUI is running but our window doesn't have
   * input focus (e.g., when a find dialog is open). */
  if (!p_imdisable && KeyTyped && !KeyStuffed
      ) {
    /* Do save when IM is on, or IM is off and saved status is on. */
    if (vgetc_im_active)
      *psave = B_IMODE_IM;
    else if (*psave == B_IMODE_IM)
      *psave = B_IMODE_NONE;
  }
}
#endif

