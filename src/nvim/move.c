// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// move.c: Functions for moving the cursor and scrolling text.
//
// There are two ways to move the cursor:
// 1. Move the cursor directly, the text is scrolled to keep the cursor in the
//    window.
// 2. Scroll the text, the cursor is moved into the text visible in the
//    window.
// The 'scrolloff' option makes this a bit complicated.

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>

#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/window.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/macros.h"
#include "nvim/mbyte.h"
#include "nvim/memline_defs.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/types.h"
#include "nvim/vim.h"
#include "nvim/window.h"

typedef struct {
  linenr_T lnum;                // line number
  int fill;                     // filler lines
  int height;                   // height of added line
} lineoff_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "move.c.generated.h"
#endif

/// Reduce "n" for the screen lines skipped with "wp->w_skipcol".
int adjust_plines_for_skipcol(win_T *wp, int n)
{
  if (wp->w_skipcol == 0) {
    return n;
  }

  int off = 0;
  int width = wp->w_width_inner - win_col_off(wp);
  if (wp->w_skipcol >= width) {
    off++;
    int skip = wp->w_skipcol - width;
    width -= win_col_off2(wp);
    while (skip >= width) {
      off++;
      skip -= width;
    }
  }
  wp->w_valid &= ~VALID_WROW;
  return n - off;
}

/// Return how many lines "lnum" will take on the screen, taking into account
/// whether it is the first line, whether w_skipcol is non-zero and limiting to
/// the window height.
static int plines_correct_topline(win_T *wp, linenr_T lnum, linenr_T *nextp, bool *foldedp)
{
  int n = plines_win_full(wp, lnum, nextp, foldedp, true, false);
  if (lnum == wp->w_topline) {
    n = adjust_plines_for_skipcol(wp, n);
  }
  if (n > wp->w_height_inner) {
    return wp->w_height_inner;
  }
  return n;
}

// Compute wp->w_botline for the current wp->w_topline.  Can be called after
// wp->w_topline changed.
static void comp_botline(win_T *wp)
{
  linenr_T lnum;
  int done;

  // If w_cline_row is valid, start there.
  // Otherwise have to start at w_topline.
  check_cursor_moved(wp);
  if (wp->w_valid & VALID_CROW) {
    lnum = wp->w_cursor.lnum;
    done = wp->w_cline_row;
  } else {
    lnum = wp->w_topline;
    done = 0;
  }

  for (; lnum <= wp->w_buffer->b_ml.ml_line_count; lnum++) {
    linenr_T last = lnum;
    bool folded;
    int n = plines_correct_topline(wp, lnum, &last, &folded);
    if (lnum <= wp->w_cursor.lnum && last >= wp->w_cursor.lnum) {
      wp->w_cline_row = done;
      wp->w_cline_height = n;
      wp->w_cline_folded = folded;
      redraw_for_cursorline(wp);
      wp->w_valid |= (VALID_CROW|VALID_CHEIGHT);
    }
    if (done + n > wp->w_height_inner) {
      break;
    }
    done += n;
    lnum = last;
  }

  // wp->w_botline is the line that is just below the window
  wp->w_botline = lnum;
  wp->w_valid |= VALID_BOTLINE|VALID_BOTLINE_AP;
  wp->w_viewport_invalid = true;

  set_empty_rows(wp, done);

  win_check_anchored_floats(wp);
}

/// Redraw when w_virtcol changes and 'cursorcolumn' is set or 'cursorlineopt'
/// contains "screenline" or when the "CurSearch" highlight is in use.
/// Also when concealing is on and 'concealcursor' is active.
static void redraw_for_cursorcolumn(win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  if ((wp->w_valid & VALID_VIRTCOL) == 0 && !pum_visible()) {
    if (wp->w_p_cuc || ((HL_ATTR(HLF_LC) || win_hl_attr(wp, HLF_LC)) && using_hlsearch())) {
      // When 'cursorcolumn' is set or "CurSearch" is in use
      // need to redraw with UPD_SOME_VALID.
      redraw_later(wp, UPD_SOME_VALID);
    } else if (wp->w_p_cul && (wp->w_p_culopt_flags & CULOPT_SCRLINE)) {
      // When 'cursorlineopt' contains "screenline" need to redraw with UPD_VALID.
      redraw_later(wp, UPD_VALID);
    }
  }
  // If the cursor moves horizontally when 'concealcursor' is active, then the
  // current line needs to be redrawn in order to calculate the correct
  // cursor position.
  if ((wp->w_valid & VALID_VIRTCOL) == 0 && wp->w_p_cole > 0 && conceal_cursor_line(wp)) {
    redrawWinline(wp, wp->w_cursor.lnum);
  }
}

/// Calculates how much the 'listchars' "precedes" or 'smoothscroll' "<<<"
/// marker overlaps with buffer text for window "wp".
/// Parameter "extra2" should be the padding on the 2nd line, not the first
/// line.
/// Returns the number of columns of overlap with buffer text, excluding the
/// extra padding on the ledge.
int sms_marker_overlap(win_T *wp, int extra2)
{
  // There is no marker overlap when in showbreak mode, thus no need to
  // account for it.  See grid_put_linebuf().
  if (*get_showbreak_value(wp) != NUL) {
    return 0;
  }

  // Overlap when 'list' and 'listchars' "precedes" are set is 1.
  if (wp->w_p_list && wp->w_p_lcs_chars.prec) {
    return 1;
  }

  return extra2 > 3 ? 0 : 3 - extra2;
}

/// Calculates the skipcol offset for window "wp" given how many
/// physical lines we want to scroll down.
static int skipcol_from_plines(win_T *wp, int plines_off)
{
  int width1 = wp->w_width_inner - win_col_off(wp);

  int skipcol = 0;
  if (plines_off > 0) {
    skipcol += width1;
  }
  if (plines_off > 1) {
    skipcol += (width1 + win_col_off2(wp)) * (plines_off - 1);
  }
  return skipcol;
}

/// Set wp->w_skipcol to zero and redraw later if needed.
static void reset_skipcol(win_T *wp)
{
  if (wp->w_skipcol != 0) {
    wp->w_skipcol = 0;

    // Should use the least expensive way that displays all that changed.
    // UPD_NOT_VALID is too expensive, UPD_REDRAW_TOP does not redraw
    // enough when the top line gets another screen line.
    redraw_later(wp, UPD_SOME_VALID);
  }
}

// Update curwin->w_topline to move the cursor onto the screen.
void update_topline(win_T *wp)
{
  bool check_botline = false;
  long *so_ptr = wp->w_p_so >= 0 ? &wp->w_p_so : &p_so;
  long save_so = *so_ptr;

  // Cursor is updated instead when this is true for 'splitkeep'.
  if (skip_update_topline) {
    return;
  }

  // If there is no valid screen and when the window height is zero just use
  // the cursor line.
  if (!default_grid.chars || wp->w_height_inner == 0) {
    wp->w_topline = wp->w_cursor.lnum;
    wp->w_botline = wp->w_topline;
    wp->w_viewport_invalid = true;
    wp->w_scbind_pos = 1;
    return;
  }

  check_cursor_moved(wp);
  if (wp->w_valid & VALID_TOPLINE) {
    return;
  }

  // When dragging with the mouse, don't scroll that quickly
  if (mouse_dragging > 0) {
    *so_ptr = mouse_dragging - 1;
  }

  linenr_T old_topline = wp->w_topline;
  int old_topfill = wp->w_topfill;

  // If the buffer is empty, always set topline to 1.
  if (buf_is_empty(curbuf)) {             // special case - file is empty
    if (wp->w_topline != 1) {
      redraw_later(wp, UPD_NOT_VALID);
    }
    wp->w_topline = 1;
    wp->w_botline = 2;
    wp->w_valid |= VALID_BOTLINE|VALID_BOTLINE_AP;
    wp->w_viewport_invalid = true;
    wp->w_scbind_pos = 1;
  } else {
    bool check_topline = false;
    // If the cursor is above or near the top of the window, scroll the window
    // to show the line the cursor is in, with 'scrolloff' context.
    if (wp->w_topline > 1 || wp->w_skipcol > 0) {
      // If the cursor is above topline, scrolling is always needed.
      // If the cursor is far below topline and there is no folding,
      // scrolling down is never needed.
      if (wp->w_cursor.lnum < wp->w_topline) {
        check_topline = true;
      } else if (check_top_offset()) {
        check_topline = true;
      } else if (wp->w_skipcol > 0 && wp->w_cursor.lnum == wp->w_topline) {
        colnr_T vcol;

        // Check that the cursor position is visible.  Add columns for
        // the marker displayed in the top-left if needed.
        getvvcol(wp, &wp->w_cursor, &vcol, NULL, NULL);
        int overlap = sms_marker_overlap(wp, win_col_off(wp) - win_col_off2(wp));
        if (wp->w_skipcol + overlap > vcol) {
          check_topline = true;
        }
      }
    }
    // Check if there are more filler lines than allowed.
    if (!check_topline && wp->w_topfill > win_get_fill(wp, wp->w_topline)) {
      check_topline = true;
    }

    if (check_topline) {
      int halfheight = wp->w_height_inner / 2 - 1;
      if (halfheight < 2) {
        halfheight = 2;
      }
      long n;
      if (hasAnyFolding(wp)) {
        // Count the number of logical lines between the cursor and
        // topline + p_so (approximation of how much will be
        // scrolled).
        n = 0;
        for (linenr_T lnum = wp->w_cursor.lnum;
             lnum < wp->w_topline + *so_ptr; lnum++) {
          n++;
          // stop at end of file or when we know we are far off
          assert(wp->w_buffer != 0);
          if (lnum >= wp->w_buffer->b_ml.ml_line_count || n >= halfheight) {
            break;
          }
          (void)hasFoldingWin(wp, lnum, NULL, &lnum, true, NULL);
        }
      } else {
        n = wp->w_topline + *so_ptr - wp->w_cursor.lnum;
      }

      // If we weren't very close to begin with, we scroll to put the
      // cursor in the middle of the window.  Otherwise put the cursor
      // near the top of the window.
      if (n >= halfheight) {
        scroll_cursor_halfway(false, false);
      } else {
        scroll_cursor_top(scrolljump_value(), false);
        check_botline = true;
      }
    } else {
      // Make sure topline is the first line of a fold.
      (void)hasFoldingWin(wp, wp->w_topline, &wp->w_topline, NULL, true, NULL);
      check_botline = true;
    }
  }

  // If the cursor is below the bottom of the window, scroll the window
  // to put the cursor on the window.
  // When w_botline is invalid, recompute it first, to avoid a redraw later.
  // If w_botline was approximated, we might need a redraw later in a few
  // cases, but we don't want to spend (a lot of) time recomputing w_botline
  // for every small change.
  if (check_botline) {
    if (!(wp->w_valid & VALID_BOTLINE_AP)) {
      validate_botline(wp);
    }

    assert(wp->w_buffer != 0);
    if (wp->w_botline <= wp->w_buffer->b_ml.ml_line_count) {
      if (wp->w_cursor.lnum < wp->w_botline) {
        if (((long)wp->w_cursor.lnum
             >= (long)wp->w_botline - *so_ptr
             || hasAnyFolding(wp))) {
          lineoff_T loff;

          // Cursor is (a few lines) above botline, check if there are
          // 'scrolloff' window lines below the cursor.  If not, need to
          // scroll.
          int n = wp->w_empty_rows;
          loff.lnum = wp->w_cursor.lnum;
          // In a fold go to its last line.
          (void)hasFoldingWin(wp, loff.lnum, NULL, &loff.lnum, true, NULL);
          loff.fill = 0;
          n += wp->w_filler_rows;
          loff.height = 0;
          while (loff.lnum < wp->w_botline
                 && (loff.lnum + 1 < wp->w_botline || loff.fill == 0)) {
            n += loff.height;
            if (n >= *so_ptr) {
              break;
            }
            botline_forw(wp, &loff);
          }
          if (n >= *so_ptr) {
            // sufficient context, no need to scroll
            check_botline = false;
          }
        } else {
          // sufficient context, no need to scroll
          check_botline = false;
        }
      }
      if (check_botline) {
        long line_count = 0;
        if (hasAnyFolding(wp)) {
          // Count the number of logical lines between the cursor and
          // botline - p_so (approximation of how much will be
          // scrolled).
          for (linenr_T lnum = wp->w_cursor.lnum;
               lnum >= wp->w_botline - *so_ptr; lnum--) {
            line_count++;
            // stop at end of file or when we know we are far off
            if (lnum <= 0 || line_count > wp->w_height_inner + 1) {
              break;
            }
            (void)hasFolding(lnum, &lnum, NULL);
          }
        } else {
          line_count = wp->w_cursor.lnum - wp->w_botline + 1 + *so_ptr;
        }
        if (line_count <= wp->w_height_inner + 1) {
          scroll_cursor_bot(scrolljump_value(), false);
        } else {
          scroll_cursor_halfway(false, false);
        }
      }
    }
  }
  wp->w_valid |= VALID_TOPLINE;
  wp->w_viewport_invalid = true;
  win_check_anchored_floats(wp);

  // Need to redraw when topline changed.
  if (wp->w_topline != old_topline
      || wp->w_topfill != old_topfill) {
    dollar_vcol = -1;
    redraw_later(wp, UPD_VALID);

    // When 'smoothscroll' is not set, should reset w_skipcol.
    if (!wp->w_p_sms) {
      reset_skipcol(wp);
    } else if (wp->w_skipcol != 0) {
      redraw_later(wp, UPD_SOME_VALID);
    }

    // May need to set w_skipcol when cursor in w_topline.
    if (wp->w_cursor.lnum == wp->w_topline) {
      validate_cursor();
    }
  }

  *so_ptr = save_so;
}

// Return the scrolljump value to use for the current window.
// When 'scrolljump' is positive use it as-is.
// When 'scrolljump' is negative use it as a percentage of the window height.
static int scrolljump_value(void)
{
  long result = p_sj >= 0 ? p_sj : (curwin->w_height_inner * -p_sj) / 100;
  assert(result <= INT_MAX);
  return (int)result;
}

// Return true when there are not 'scrolloff' lines above the cursor for the
// current window.
static bool check_top_offset(void)
{
  long so = get_scrolloff_value(curwin);
  if (curwin->w_cursor.lnum < curwin->w_topline + so
      || hasAnyFolding(curwin)) {
    lineoff_T loff;
    loff.lnum = curwin->w_cursor.lnum;
    loff.fill = 0;
    int n = curwin->w_topfill;          // always have this context
    // Count the visible screen lines above the cursor line.
    while (n < so) {
      topline_back(curwin, &loff);
      // Stop when included a line above the window.
      if (loff.lnum < curwin->w_topline
          || (loff.lnum == curwin->w_topline
              && loff.fill > 0)) {
        break;
      }
      n += loff.height;
    }
    if (n < so) {
      return true;
    }
  }
  return false;
}

/// Update w_curswant.
void update_curswant_force(void)
{
  validate_virtcol();
  curwin->w_curswant = curwin->w_virtcol;
  curwin->w_set_curswant = false;
}

/// Update w_curswant if w_set_curswant is set.
void update_curswant(void)
{
  if (curwin->w_set_curswant) {
    update_curswant_force();
  }
}

// Check if the cursor has moved.  Set the w_valid flag accordingly.
void check_cursor_moved(win_T *wp)
{
  if (wp->w_cursor.lnum != wp->w_valid_cursor.lnum) {
    wp->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL
                     |VALID_CHEIGHT|VALID_CROW|VALID_TOPLINE);
    wp->w_valid_cursor = wp->w_cursor;
    wp->w_valid_leftcol = wp->w_leftcol;
    wp->w_valid_skipcol = wp->w_skipcol;
    wp->w_viewport_invalid = true;
  } else if (wp->w_skipcol != wp->w_valid_skipcol) {
    wp->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL
                     |VALID_CHEIGHT|VALID_CROW
                     |VALID_BOTLINE|VALID_BOTLINE_AP);
    wp->w_valid_cursor = wp->w_cursor;
    wp->w_valid_leftcol = wp->w_leftcol;
    wp->w_valid_skipcol = wp->w_skipcol;
  } else if (wp->w_cursor.col != wp->w_valid_cursor.col
             || wp->w_leftcol != wp->w_valid_leftcol
             || wp->w_cursor.coladd !=
             wp->w_valid_cursor.coladd) {
    wp->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL);
    wp->w_valid_cursor.col = wp->w_cursor.col;
    wp->w_valid_leftcol = wp->w_leftcol;
    wp->w_valid_cursor.coladd = wp->w_cursor.coladd;
    wp->w_viewport_invalid = true;
  }
}

// Call this function when some window settings have changed, which require
// the cursor position, botline and topline to be recomputed and the window to
// be redrawn.  E.g, when changing the 'wrap' option or folding.
void changed_window_setting(void)
{
  changed_window_setting_win(curwin);
}

void changed_window_setting_win(win_T *wp)
{
  wp->w_lines_valid = 0;
  changed_line_abv_curs_win(wp);
  wp->w_valid &= ~(VALID_BOTLINE|VALID_BOTLINE_AP|VALID_TOPLINE);
  redraw_later(wp, UPD_NOT_VALID);
}

// Set wp->w_topline to a certain number.
void set_topline(win_T *wp, linenr_T lnum)
{
  linenr_T prev_topline = wp->w_topline;

  // go to first of folded lines
  (void)hasFoldingWin(wp, lnum, &lnum, NULL, true, NULL);
  // Approximate the value of w_botline
  wp->w_botline += lnum - wp->w_topline;
  wp->w_topline = lnum;
  wp->w_topline_was_set = true;
  if (lnum != prev_topline) {
    // Keep the filler lines when the topline didn't change.
    wp->w_topfill = 0;
  }
  wp->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_TOPLINE);
  // Don't set VALID_TOPLINE here, 'scrolloff' needs to be checked.
  redraw_later(wp, UPD_VALID);
}

/// Call this function when the length of the cursor line (in screen
/// characters) has changed, and the change is before the cursor.
/// If the line length changed the number of screen lines might change,
/// requiring updating w_topline.  That may also invalidate w_crow.
/// Need to take care of w_botline separately!
void changed_cline_bef_curs(void)
{
  curwin->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL|VALID_CROW
                       |VALID_CHEIGHT|VALID_TOPLINE);
}

void changed_cline_bef_curs_win(win_T *wp)
{
  wp->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL|VALID_CROW
                   |VALID_CHEIGHT|VALID_TOPLINE);
}

// Call this function when the length of a line (in screen characters) above
// the cursor have changed.
// Need to take care of w_botline separately!
void changed_line_abv_curs(void)
{
  curwin->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL|VALID_CROW
                       |VALID_CHEIGHT|VALID_TOPLINE);
}

void changed_line_abv_curs_win(win_T *wp)
{
  wp->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL|VALID_CROW
                   |VALID_CHEIGHT|VALID_TOPLINE);
}

/// Display of line has changed for "buf", invalidate cursor position and
/// w_botline.
void changed_line_display_buf(buf_T *buf)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf) {
      wp->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL
                       |VALID_CROW|VALID_CHEIGHT
                       |VALID_TOPLINE|VALID_BOTLINE|VALID_BOTLINE_AP);
    }
  }
}

// Make sure the value of curwin->w_botline is valid.
void validate_botline(win_T *wp)
{
  if (!(wp->w_valid & VALID_BOTLINE)) {
    comp_botline(wp);
  }
}

// Mark curwin->w_botline as invalid (because of some change in the buffer).
void invalidate_botline(void)
{
  curwin->w_valid &= ~(VALID_BOTLINE|VALID_BOTLINE_AP);
}

void invalidate_botline_win(win_T *wp)
{
  wp->w_valid &= ~(VALID_BOTLINE|VALID_BOTLINE_AP);
}

void approximate_botline_win(win_T *wp)
{
  wp->w_valid &= ~VALID_BOTLINE;
}

// Return true if curwin->w_wrow and curwin->w_wcol are valid.
int cursor_valid(void)
{
  check_cursor_moved(curwin);
  return (curwin->w_valid & (VALID_WROW|VALID_WCOL)) == (VALID_WROW|VALID_WCOL);
}

// Validate cursor position.  Makes sure w_wrow and w_wcol are valid.
// w_topline must be valid, you may need to call update_topline() first!
void validate_cursor(void)
{
  check_cursor_moved(curwin);
  if ((curwin->w_valid & (VALID_WCOL|VALID_WROW)) != (VALID_WCOL|VALID_WROW)) {
    curs_columns(curwin, true);
  }
}

// Compute wp->w_cline_row and wp->w_cline_height, based on the current value
// of wp->w_topline.
static void curs_rows(win_T *wp)
{
  // Check if wp->w_lines[].wl_size is invalid
  int all_invalid = (!redrawing()
                     || wp->w_lines_valid == 0
                     || wp->w_lines[0].wl_lnum > wp->w_topline);
  int i = 0;
  wp->w_cline_row = 0;
  for (linenr_T lnum = wp->w_topline; lnum < wp->w_cursor.lnum; i++) {
    bool valid = false;
    if (!all_invalid && i < wp->w_lines_valid) {
      if (wp->w_lines[i].wl_lnum < lnum || !wp->w_lines[i].wl_valid) {
        continue;                       // skip changed or deleted lines
      }
      if (wp->w_lines[i].wl_lnum == lnum) {
        // Check for newly inserted lines below this row, in which
        // case we need to check for folded lines.
        if (!wp->w_buffer->b_mod_set
            || wp->w_lines[i].wl_lastlnum < wp->w_cursor.lnum
            || wp->w_buffer->b_mod_top
            > wp->w_lines[i].wl_lastlnum + 1) {
          valid = true;
        }
      } else if (wp->w_lines[i].wl_lnum > lnum) {
        i--;                            // hold at inserted lines
      }
    }
    if (valid && (lnum != wp->w_topline || (wp->w_skipcol == 0 && !win_may_fill(wp)))) {
      lnum = wp->w_lines[i].wl_lastlnum + 1;
      // Cursor inside folded lines, don't count this row
      if (lnum > wp->w_cursor.lnum) {
        break;
      }
      wp->w_cline_row += wp->w_lines[i].wl_size;
    } else {
      linenr_T last = lnum;
      bool folded;
      int n = plines_correct_topline(wp, lnum, &last, &folded);
      lnum = last + 1;
      if (folded && lnum > wp->w_cursor.lnum) {
        break;
      }
      wp->w_cline_row += n;
    }
  }

  check_cursor_moved(wp);
  if (!(wp->w_valid & VALID_CHEIGHT)) {
    if (all_invalid
        || i == wp->w_lines_valid
        || (i < wp->w_lines_valid
            && (!wp->w_lines[i].wl_valid
                || wp->w_lines[i].wl_lnum != wp->w_cursor.lnum))) {
      wp->w_cline_height = plines_win_full(wp, wp->w_cursor.lnum, NULL,
                                           &wp->w_cline_folded, true, true);
    } else if (i > wp->w_lines_valid) {
      // a line that is too long to fit on the last screen line
      wp->w_cline_height = 0;
      wp->w_cline_folded = hasFoldingWin(wp, wp->w_cursor.lnum, NULL,
                                         NULL, true, NULL);
    } else {
      wp->w_cline_height = wp->w_lines[i].wl_size;
      wp->w_cline_folded = wp->w_lines[i].wl_folded;
    }
  }

  redraw_for_cursorline(curwin);
  wp->w_valid |= VALID_CROW|VALID_CHEIGHT;
}

// Validate curwin->w_virtcol only.
void validate_virtcol(void)
{
  validate_virtcol_win(curwin);
}

// Validate wp->w_virtcol only.
void validate_virtcol_win(win_T *wp)
{
  check_cursor_moved(wp);

  if (wp->w_valid & VALID_VIRTCOL) {
    return;
  }

  getvvcol(wp, &wp->w_cursor, NULL, &(wp->w_virtcol), NULL);
  redraw_for_cursorcolumn(wp);
  wp->w_valid |= VALID_VIRTCOL;
}

// Validate curwin->w_cline_height only.
void validate_cheight(void)
{
  check_cursor_moved(curwin);

  if (curwin->w_valid & VALID_CHEIGHT) {
    return;
  }

  curwin->w_cline_height = plines_win_full(curwin, curwin->w_cursor.lnum,
                                           NULL, &curwin->w_cline_folded,
                                           true, true);
  curwin->w_valid |= VALID_CHEIGHT;
}

// Validate w_wcol and w_virtcol only.
void validate_cursor_col(void)
{
  validate_virtcol();

  if (curwin->w_valid & VALID_WCOL) {
    return;
  }

  colnr_T col = curwin->w_virtcol;
  colnr_T off = curwin_col_off();
  col += off;
  int width = curwin->w_width_inner - off + curwin_col_off2();

  // long line wrapping, adjust curwin->w_wrow
  if (curwin->w_p_wrap && col >= (colnr_T)curwin->w_width_inner
      && width > 0) {
    // use same formula as what is used in curs_columns()
    col -= ((col - curwin->w_width_inner) / width + 1) * width;
  }
  if (col > (int)curwin->w_leftcol) {
    col -= curwin->w_leftcol;
  } else {
    col = 0;
  }
  curwin->w_wcol = col;

  curwin->w_valid |= VALID_WCOL;
}

// Compute offset of a window, occupied by absolute or relative line number,
// fold column and sign column (these don't move when scrolling horizontally).
int win_col_off(win_T *wp)
{
  return ((wp->w_p_nu || wp->w_p_rnu || (*wp->w_p_stc != NUL)) ?
          (number_width(wp) + (*wp->w_p_stc == NUL)) : 0)
         + (cmdwin_type == 0 || wp != curwin ? 0 : 1)
         + win_fdccol_count(wp)
         + (win_signcol_count(wp) * win_signcol_width(wp));
}

int curwin_col_off(void)
{
  return win_col_off(curwin);
}

// Return the difference in column offset for the second screen line of a
// wrapped line.  It's positive if 'number' or 'relativenumber' is on and 'n'
// is in 'cpoptions'.
int win_col_off2(win_T *wp)
{
  if ((wp->w_p_nu || wp->w_p_rnu) && vim_strchr(p_cpo, CPO_NUMCOL) != NULL) {
    return number_width(wp) + 1;
  }
  return 0;
}

int curwin_col_off2(void)
{
  return win_col_off2(curwin);
}

// Compute wp->w_wcol and wp->w_virtcol.
// Also updates wp->w_wrow and wp->w_cline_row.
// Also updates wp->w_leftcol.
// @param may_scroll when true, may scroll horizontally
void curs_columns(win_T *wp, int may_scroll)
{
  colnr_T startcol;
  colnr_T endcol;

  // First make sure that w_topline is valid (after moving the cursor).
  update_topline(wp);

  // Next make sure that w_cline_row is valid.
  if (!(wp->w_valid & VALID_CROW)) {
    curs_rows(wp);
  }

  // Compute the number of virtual columns.
  if (wp->w_cline_folded) {
    // In a folded line the cursor is always in the first column
    startcol = wp->w_virtcol = endcol = wp->w_leftcol;
  } else {
    getvvcol(wp, &wp->w_cursor, &startcol, &(wp->w_virtcol), &endcol);
  }

  // remove '$' from change command when cursor moves onto it
  if (startcol > dollar_vcol) {
    dollar_vcol = -1;
  }

  int extra = win_col_off(wp);
  wp->w_wcol = wp->w_virtcol + extra;
  endcol += extra;

  // Now compute w_wrow, counting screen lines from w_cline_row.
  wp->w_wrow = wp->w_cline_row;

  int n;
  int width1 = wp->w_width_inner - extra;  // text width for first screen line
  int width2 = 0;                          // text width for second and later screen line
  bool did_sub_skipcol = false;
  if (width1 <= 0) {
    // No room for text, put cursor in last char of window.
    // If not wrapping, the last non-empty line.
    wp->w_wcol = wp->w_width_inner - 1;
    if (wp->w_p_wrap) {
      wp->w_wrow = wp->w_height_inner - 1;
    } else {
      wp->w_wrow = wp->w_height_inner - 1 - wp->w_empty_rows;
    }
  } else if (wp->w_p_wrap && wp->w_width_inner != 0) {
    width2 = width1 + win_col_off2(wp);

    // skip columns that are not visible
    if (wp->w_cursor.lnum == wp->w_topline
        && wp->w_skipcol > 0
        && wp->w_wcol >= wp->w_skipcol) {
      // Deduct by multiples of width2.  This allows the long line wrapping
      // formula below to correctly calculate the w_wcol value when wrapping.
      if (wp->w_skipcol <= width1) {
        wp->w_wcol -= width2;
      } else {
        wp->w_wcol -= width2 * (((wp->w_skipcol - width1) / width2) + 1);
      }

      did_sub_skipcol = true;
    }

    // long line wrapping, adjust wp->w_wrow
    if (wp->w_wcol >= wp->w_width_inner) {
      // this same formula is used in validate_cursor_col()
      n = (wp->w_wcol - wp->w_width_inner) / width2 + 1;
      wp->w_wcol -= n * width2;
      wp->w_wrow += n;

      // When cursor wraps to first char of next line in Insert
      // mode, the 'showbreak' string isn't shown, backup to first
      // column
      char *const sbr = get_showbreak_value(wp);
      if (*sbr && *get_cursor_pos_ptr() == NUL
          && wp->w_wcol == vim_strsize(sbr)) {
        wp->w_wcol = 0;
      }
    }
  } else if (may_scroll
             && !wp->w_cline_folded) {
    // No line wrapping: compute wp->w_leftcol if scrolling is on and line
    // is not folded.
    // If scrolling is off, wp->w_leftcol is assumed to be 0

    // If Cursor is left of the screen, scroll rightwards.
    // If Cursor is right of the screen, scroll leftwards
    // If we get closer to the edge than 'sidescrolloff', scroll a little
    // extra
    long siso = get_sidescrolloff_value(wp);
    assert(siso <= INT_MAX);
    int off_left = startcol - wp->w_leftcol - (int)siso;
    int off_right =
      endcol - wp->w_leftcol - wp->w_width_inner + (int)siso + 1;
    if (off_left < 0 || off_right > 0) {
      int diff = (off_left < 0) ? -off_left : off_right;

      // When far off or not enough room on either side, put cursor in
      // middle of window.
      int new_leftcol;
      if (p_ss == 0 || diff >= width1 / 2 || off_right >= off_left) {
        new_leftcol = curwin->w_wcol - extra - width1 / 2;
      } else {
        if (diff < p_ss) {
          assert(p_ss <= INT_MAX);
          diff = (int)p_ss;
        }
        if (off_left < 0) {
          new_leftcol = wp->w_leftcol - diff;
        } else {
          new_leftcol = wp->w_leftcol + diff;
        }
      }
      if (new_leftcol < 0) {
        new_leftcol = 0;
      }
      if (new_leftcol != (int)wp->w_leftcol) {
        wp->w_leftcol = new_leftcol;
        win_check_anchored_floats(wp);
        // screen has to be redrawn with new wp->w_leftcol
        redraw_later(wp, UPD_NOT_VALID);
      }
    }
    wp->w_wcol -= wp->w_leftcol;
  } else if (wp->w_wcol > (int)wp->w_leftcol) {
    wp->w_wcol -= wp->w_leftcol;
  } else {
    wp->w_wcol = 0;
  }

  // Skip over filler lines.  At the top use w_topfill, there
  // may be some filler lines above the window.
  if (wp->w_cursor.lnum == wp->w_topline) {
    wp->w_wrow += wp->w_topfill;
  } else {
    wp->w_wrow += win_get_fill(wp, wp->w_cursor.lnum);
  }

  int plines = 0;
  long so = get_scrolloff_value(wp);
  colnr_T prev_skipcol = wp->w_skipcol;
  if ((wp->w_wrow >= wp->w_height_inner
       || ((prev_skipcol > 0
            || wp->w_wrow + so >= wp->w_height_inner)
           && (plines = plines_win_nofill(wp, wp->w_cursor.lnum, false)) - 1
           >= wp->w_height_inner))
      && wp->w_height_inner != 0
      && wp->w_cursor.lnum == wp->w_topline
      && width2 > 0
      && wp->w_width_inner != 0) {
    // Cursor past end of screen.  Happens with a single line that does
    // not fit on screen.  Find a skipcol to show the text around the
    // cursor.  Avoid scrolling all the time. compute value of "extra":
    // 1: Less than "p_so" lines above
    // 2: Less than "p_so" lines below
    // 3: both of them
    extra = 0;
    if (wp->w_skipcol + so * width2 > wp->w_virtcol) {
      extra = 1;
    }
    // Compute last display line of the buffer line that we want at the
    // bottom of the window.
    if (plines == 0) {
      plines = plines_win(wp, wp->w_cursor.lnum, false);
    }
    plines--;
    if (plines > wp->w_wrow + so) {
      assert(so <= INT_MAX);
      n = wp->w_wrow + (int)so;
    } else {
      n = plines;
    }
    if ((colnr_T)n >= wp->w_height_inner + wp->w_skipcol / width2 - so) {
      extra += 2;
    }

    if (extra == 3 || wp->w_height_inner <= so * 2) {
      // not enough room for 'scrolloff', put cursor in the middle
      n = wp->w_virtcol / width2;
      if (n > wp->w_height_inner / 2) {
        n -= wp->w_height_inner / 2;
      } else {
        n = 0;
      }
      // don't skip more than necessary
      if (n > plines - wp->w_height_inner + 1) {
        n = plines - wp->w_height_inner + 1;
      }
      wp->w_skipcol = n * width2;
    } else if (extra == 1) {
      // less than 'scrolloff' lines above, decrease skipcol
      assert(so <= INT_MAX);
      extra = (wp->w_skipcol + (int)so * width2 - wp->w_virtcol + width2 - 1) / width2;
      if (extra > 0) {
        if ((colnr_T)(extra * width2) > wp->w_skipcol) {
          extra = wp->w_skipcol / width2;
        }
        wp->w_skipcol -= extra * width2;
      }
    } else if (extra == 2) {
      // less than 'scrolloff' lines below, increase skipcol
      endcol = (n - wp->w_height_inner + 1) * width2;
      while (endcol > wp->w_virtcol) {
        endcol -= width2;
      }
      if (endcol > wp->w_skipcol) {
        wp->w_skipcol = endcol;
      }
    }

    // adjust w_wrow for the changed w_skipcol
    if (did_sub_skipcol) {
      wp->w_wrow -= (wp->w_skipcol - prev_skipcol) / width2;
    } else {
      wp->w_wrow -= wp->w_skipcol / width2;
    }

    if (wp->w_wrow >= wp->w_height_inner) {
      // small window, make sure cursor is in it
      extra = wp->w_wrow - wp->w_height_inner + 1;
      wp->w_skipcol += extra * width2;
      wp->w_wrow -= extra;
    }

    // extra could be either positive or negative
    extra = (prev_skipcol - wp->w_skipcol) / width2;
    win_scroll_lines(wp, 0, extra);
  } else if (!wp->w_p_sms) {
    wp->w_skipcol = 0;
  }
  if (prev_skipcol != wp->w_skipcol) {
    redraw_later(wp, UPD_SOME_VALID);
  }

  redraw_for_cursorcolumn(wp);

  // now w_leftcol and w_skipcol are valid, avoid check_cursor_moved()
  // thinking otherwise
  wp->w_valid_leftcol = wp->w_leftcol;
  wp->w_valid_skipcol = wp->w_skipcol;

  wp->w_valid |= VALID_WCOL|VALID_WROW|VALID_VIRTCOL;
}

/// Compute the screen position of text character at "pos" in window "wp"
/// The resulting values are one-based, zero when character is not visible.
///
/// @param[out] rowp screen row
/// @param[out] scolp start screen column
/// @param[out] ccolp cursor screen column
/// @param[out] ecolp end screen column
void textpos2screenpos(win_T *wp, pos_T *pos, int *rowp, int *scolp, int *ccolp, int *ecolp,
                       bool local)
{
  colnr_T scol = 0, ccol = 0, ecol = 0;
  int row = 0;
  int rowoff = 0;
  colnr_T coloff = 0;
  bool visible_row = false;
  bool is_folded = false;

  linenr_T lnum = pos->lnum;
  if (lnum >= wp->w_topline && lnum <= wp->w_botline) {
    is_folded = hasFoldingWin(wp, lnum, &lnum, NULL, true, NULL);
    row = plines_m_win(wp, wp->w_topline, lnum - 1) + 1;
    // Add filler lines above this buffer line.
    row += lnum == wp->w_topline ? wp->w_topfill : win_get_fill(wp, lnum);
    visible_row = true;
  } else if (!local || lnum < wp->w_topline) {
    row = 0;
  } else {
    row = wp->w_height_inner;
  }

  bool existing_row = (lnum > 0 && lnum <= wp->w_buffer->b_ml.ml_line_count);

  if ((local || visible_row) && existing_row) {
    const colnr_T off = win_col_off(wp);
    if (is_folded) {
      row += local ? 0 : wp->w_winrow + wp->w_winrow_off;
      coloff = (local ? 0 : wp->w_wincol + wp->w_wincol_off) + 1 + off;
    } else {
      assert(lnum == pos->lnum);
      getvcol(wp, pos, &scol, &ccol, &ecol);

      // similar to what is done in validate_cursor_col()
      colnr_T col = scol;
      col += off;
      int width = wp->w_width_inner - off + win_col_off2(wp);

      if (lnum == wp->w_topline) {
        col -= wp->w_skipcol;
      }

      // long line wrapping, adjust row
      if (wp->w_p_wrap && col >= (colnr_T)wp->w_width_inner && width > 0) {
        // use same formula as what is used in curs_columns()
        rowoff = visible_row ? ((col - wp->w_width_inner) / width + 1) : 0;
        col -= rowoff * width;
      }

      col -= wp->w_leftcol;

      if (col >= 0 && col < wp->w_width_inner && row + rowoff <= wp->w_height_inner) {
        coloff = col - scol + (local ? 0 : wp->w_wincol + wp->w_wincol_off) + 1;
        row += local ? 0 : wp->w_winrow + wp->w_winrow_off;
      } else {
        // character is left, right or below of the window
        scol = ccol = ecol = 0;
        if (local) {
          coloff = col < 0 ? -1 : wp->w_width_inner + 1;
        } else {
          row = rowoff = 0;
        }
      }
    }
  }
  *rowp = row + rowoff;
  *scolp = scol + coloff;
  *ccolp = ccol + coloff;
  *ecolp = ecol + coloff;
}

/// "screenpos({winid}, {lnum}, {col})" function
void f_screenpos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_dict_alloc_ret(rettv);
  dict_T *dict = rettv->vval.v_dict;

  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  if (wp == NULL) {
    return;
  }

  pos_T pos = {
    .lnum   = (linenr_T)tv_get_number(&argvars[1]),
    .col    = (colnr_T)tv_get_number(&argvars[2]) - 1,
    .coladd = 0
  };
  if (pos.lnum > wp->w_buffer->b_ml.ml_line_count) {
    semsg(_(e_invalid_line_number_nr), pos.lnum);
    return;
  }
  int row = 0;
  int scol = 0, ccol = 0, ecol = 0;
  textpos2screenpos(wp, &pos, &row, &scol, &ccol, &ecol, false);

  tv_dict_add_nr(dict, S_LEN("row"), row);
  tv_dict_add_nr(dict, S_LEN("col"), scol);
  tv_dict_add_nr(dict, S_LEN("curscol"), ccol);
  tv_dict_add_nr(dict, S_LEN("endcol"), ecol);
}

/// "virtcol2col({winid}, {lnum}, {col})" function
void f_virtcol2col(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = -1;

  if (tv_check_for_number_arg(argvars, 0) == FAIL
      || tv_check_for_number_arg(argvars, 1) == FAIL
      || tv_check_for_number_arg(argvars, 2) == FAIL) {
    return;
  }

  win_T *wp = find_win_by_nr_or_id(&argvars[0]);
  if (wp == NULL) {
    return;
  }

  bool error = false;
  linenr_T lnum = (linenr_T)tv_get_number_chk(&argvars[1], &error);
  if (error || lnum < 0 || lnum > wp->w_buffer->b_ml.ml_line_count) {
    return;
  }

  int screencol = (int)tv_get_number_chk(&argvars[2], &error);
  if (error || screencol < 0) {
    return;
  }

  rettv->vval.v_number = vcol2col(wp, lnum, screencol);
}

/// Scroll the current window down by "line_count" logical lines.  "CTRL-Y"
///
/// @param line_count number of lines to scroll
/// @param byfold if true, count a closed fold as one line
bool scrolldown(long line_count, int byfold)
{
  int done = 0;                // total # of physical lines done
  int width1 = 0;
  int width2 = 0;
  bool do_sms = curwin->w_p_wrap && curwin->w_p_sms;

  if (do_sms) {
    width1 = curwin->w_width_inner - curwin_col_off();
    width2 = width1 + curwin_col_off2();
  }

  // Make sure w_topline is at the first of a sequence of folded lines.
  (void)hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
  validate_cursor();            // w_wrow needs to be valid
  for (long todo = line_count; todo > 0; todo--) {
    if (curwin->w_topfill < win_get_fill(curwin, curwin->w_topline)
        && curwin->w_topfill < curwin->w_height_inner - 1) {
      curwin->w_topfill++;
      done++;
    } else {
      // break when at the very top
      if (curwin->w_topline == 1 && (!do_sms || curwin->w_skipcol < width1)) {
        break;
      }
      if (do_sms && curwin->w_skipcol >= width1) {
        // scroll a screen line down
        if (curwin->w_skipcol >= width1 + width2) {
          curwin->w_skipcol -= width2;
        } else {
          curwin->w_skipcol -= width1;
        }
        redraw_later(curwin, UPD_NOT_VALID);
        done++;
      } else {
        // scroll a text line down
        curwin->w_topline--;
        curwin->w_skipcol = 0;
        curwin->w_topfill = 0;
        // A sequence of folded lines only counts for one logical line
        linenr_T first;
        if (hasFolding(curwin->w_topline, &first, NULL)) {
          done++;
          if (!byfold) {
            todo -= curwin->w_topline - first - 1;
          }
          curwin->w_botline -= curwin->w_topline - first;
          curwin->w_topline = first;
        } else {
          if (do_sms) {
            int size = (int)win_linetabsize(curwin, curwin->w_topline,
                                            ml_get(curwin->w_topline), (colnr_T)MAXCOL);
            if (size > width1) {
              curwin->w_skipcol = width1;
              size -= width1;
              redraw_later(curwin, UPD_NOT_VALID);
            }
            while (size > width2) {
              curwin->w_skipcol += width2;
              size -= width2;
            }
            done++;
          } else {
            done += plines_win_nofill(curwin, curwin->w_topline, true);
          }
        }
      }
    }
    curwin->w_botline--;                // approximate w_botline
    invalidate_botline();
  }
  curwin->w_wrow += done;               // keep w_wrow updated
  curwin->w_cline_row += done;          // keep w_cline_row updated

  if (curwin->w_cursor.lnum == curwin->w_topline) {
    curwin->w_cline_row = 0;
  }
  check_topfill(curwin, true);

  // Compute the row number of the last row of the cursor line
  // and move the cursor onto the displayed part of the window.
  int wrow = curwin->w_wrow;
  if (curwin->w_p_wrap && curwin->w_width_inner != 0) {
    validate_virtcol();
    validate_cheight();
    wrow += curwin->w_cline_height - 1 -
            curwin->w_virtcol / curwin->w_width_inner;
  }
  bool moved = false;
  while (wrow >= curwin->w_height_inner && curwin->w_cursor.lnum > 1) {
    linenr_T first;
    if (hasFolding(curwin->w_cursor.lnum, &first, NULL)) {
      wrow--;
      if (first == 1) {
        curwin->w_cursor.lnum = 1;
      } else {
        curwin->w_cursor.lnum = first - 1;
      }
    } else {
      wrow -= plines_win(curwin, curwin->w_cursor.lnum--, true);
    }
    curwin->w_valid &=
      ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW|VALID_VIRTCOL);
    moved = true;
  }
  if (moved) {
    // Move cursor to first line of closed fold.
    foldAdjustCursor();
    coladvance(curwin->w_curswant);
  }

  if (curwin->w_cursor.lnum == curwin->w_topline && do_sms) {
    long so = get_scrolloff_value(curwin);
    long scrolloff_cols = so == 0 ? 0 : width1 + (so - 1) * width2;

    // make sure the cursor is in the visible text
    validate_virtcol();
    long col = curwin->w_virtcol - curwin->w_skipcol + scrolloff_cols;
    int row = 0;
    if (col >= width1) {
      col -= width1;
      row++;
    }
    if (col > width2 && width2 > 0) {
      row += (int)col / width2;
      col = col % width2;
    }
    if (row >= curwin->w_height_inner) {
      curwin->w_curswant = curwin->w_virtcol - (row - curwin->w_height_inner + 1) * width2;
      coladvance(curwin->w_curswant);
    }
  }
  return moved;
}

/// Scroll the current window up by "line_count" logical lines.  "CTRL-E"
///
/// @param line_count number of lines to scroll
/// @param byfold if true, count a closed fold as one line
bool scrollup(long line_count, int byfold)
{
  linenr_T topline = curwin->w_topline;
  linenr_T botline = curwin->w_botline;
  int do_sms = curwin->w_p_wrap && curwin->w_p_sms;

  if (do_sms || (byfold && hasAnyFolding(curwin)) || win_may_fill(curwin)) {
    int width1 = curwin->w_width_inner - curwin_col_off();
    int width2 = width1 + curwin_col_off2();
    unsigned size = 0;
    const colnr_T prev_skipcol = curwin->w_skipcol;

    if (do_sms) {
      size = linetabsize(curwin, curwin->w_topline);
    }

    // diff mode: first consume "topfill"
    // 'smoothscroll': increase "w_skipcol" until it goes over the end of
    // the line, then advance to the next line.
    // folding: count each sequence of folded lines as one logical line.
    for (long todo = line_count; todo > 0; todo--) {
      if (curwin->w_topfill > 0) {
        curwin->w_topfill--;
      } else {
        linenr_T lnum = curwin->w_topline;
        if (byfold) {
          // for a closed fold: go to the last line in the fold
          (void)hasFolding(lnum, NULL, &lnum);
        }
        if (lnum == curwin->w_topline && do_sms) {
          // 'smoothscroll': increase "w_skipcol" until it goes over
          // the end of the line, then advance to the next line.
          int add = curwin->w_skipcol > 0 ? width2 : width1;
          curwin->w_skipcol += add;
          if ((unsigned)curwin->w_skipcol >= size) {
            if (lnum == curbuf->b_ml.ml_line_count) {
              // at the last screen line, can't scroll further
              curwin->w_skipcol -= add;
              break;
            }
            lnum++;
          }
        } else {
          if (lnum >= curbuf->b_ml.ml_line_count) {
            break;
          }
          lnum++;
        }

        if (lnum > curwin->w_topline) {
          // approximate w_botline
          curwin->w_botline += lnum - curwin->w_topline;
          curwin->w_topline = lnum;
          curwin->w_topfill = win_get_fill(curwin, lnum);
          curwin->w_skipcol = 0;
          if (todo > 1 && do_sms) {
            size = linetabsize(curwin, curwin->w_topline);
          }
        }
      }
    }

    if (prev_skipcol > 0 || curwin->w_skipcol > 0) {
      // need to redraw more, because wl_size of the (new) topline may
      // now be invalid
      redraw_later(curwin, UPD_NOT_VALID);
    }
  } else {
    curwin->w_topline += (linenr_T)line_count;
    curwin->w_botline += (linenr_T)line_count;            // approximate w_botline
  }

  if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
    curwin->w_topline = curbuf->b_ml.ml_line_count;
  }
  if (curwin->w_botline > curbuf->b_ml.ml_line_count + 1) {
    curwin->w_botline = curbuf->b_ml.ml_line_count + 1;
  }

  check_topfill(curwin, false);

  if (hasAnyFolding(curwin)) {
    // Make sure w_topline is at the first of a sequence of folded lines.
    (void)hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
  }

  curwin->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE);
  if (curwin->w_cursor.lnum < curwin->w_topline) {
    curwin->w_cursor.lnum = curwin->w_topline;
    curwin->w_valid &=
      ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW|VALID_VIRTCOL);
    coladvance(curwin->w_curswant);
  }

  if (curwin->w_cursor.lnum == curwin->w_topline && do_sms && curwin->w_skipcol > 0) {
    int col_off = curwin_col_off();
    int col_off2 = curwin_col_off2();

    int width1 = curwin->w_width_inner - col_off;
    int width2 = width1 + col_off2;
    int extra2 = col_off - col_off2;
    long so = get_scrolloff_value(curwin);
    long scrolloff_cols = so == 0 ? 0 : width1 + (so - 1) * width2;
    int space_cols = (curwin->w_height_inner - 1) * width2;

    // If we have non-zero scrolloff, just ignore the marker as we are
    // going past it anyway.
    int overlap = scrolloff_cols != 0 ? 0 : sms_marker_overlap(curwin, extra2);

    // Make sure the cursor is in a visible part of the line, taking
    // 'scrolloff' into account, but using screen lines.
    // If there are not enough screen lines put the cursor in the middle.
    if (scrolloff_cols > space_cols / 2) {
      scrolloff_cols = space_cols / 2;
    }
    validate_virtcol();
    if (curwin->w_virtcol < curwin->w_skipcol + overlap + scrolloff_cols) {
      colnr_T col = curwin->w_virtcol;

      if (col < width1) {
        col += width1;
      }
      while (col < curwin->w_skipcol + overlap + scrolloff_cols) {
        col += width2;
      }
      curwin->w_curswant = col;
      coladvance(curwin->w_curswant);

      // validate_virtcol() marked various things as valid, but after
      // moving the cursor they need to be recomputed
      curwin->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW|VALID_VIRTCOL);
    }
  }

  bool moved = topline != curwin->w_topline || botline != curwin->w_botline;

  return moved;
}

/// Called after changing the cursor column: make sure that curwin->w_skipcol is
/// valid for 'smoothscroll'.
void adjust_skipcol(void)
{
  if (!curwin->w_p_wrap || !curwin->w_p_sms || curwin->w_cursor.lnum != curwin->w_topline) {
    return;
  }

  int width1 = curwin->w_width_inner - curwin_col_off();
  if (width1 <= 0) {
    return;  // no text will be displayed
  }
  int width2 = width1 + curwin_col_off2();
  long so = get_scrolloff_value(curwin);
  long scrolloff_cols = so == 0 ? 0 : width1 + (so - 1) * width2;
  bool scrolled = false;

  validate_cheight();
  if (curwin->w_cline_height == curwin->w_height_inner
      // w_cline_height may be capped at w_height_inner, check there aren't
      // actually more lines.
      && plines_win(curwin, curwin->w_cursor.lnum, false) <= curwin->w_height_inner) {
    // the line just fits in the window, don't scroll
    reset_skipcol(curwin);
    return;
  }

  validate_virtcol();
  int overlap = sms_marker_overlap(curwin, curwin_col_off() - curwin_col_off2());
  while (curwin->w_skipcol > 0
         && curwin->w_virtcol < curwin->w_skipcol + overlap + scrolloff_cols) {
    // scroll a screen line down
    if (curwin->w_skipcol >= width1 + width2) {
      curwin->w_skipcol -= width2;
    } else {
      curwin->w_skipcol -= width1;
    }
    scrolled = true;
  }
  if (scrolled) {
    validate_virtcol();
    redraw_later(curwin, UPD_NOT_VALID);
    return;  // don't scroll in the other direction now
  }
  long col = curwin->w_virtcol - curwin->w_skipcol + scrolloff_cols;
  int row = 0;
  if (col >= width1) {
    col -= width1;
    row++;
  }
  if (col > width2) {
    row += (int)col / width2;
    col = col % width2;
  }
  if (row >= curwin->w_height_inner) {
    if (curwin->w_skipcol == 0) {
      curwin->w_skipcol += width1;
      row--;
    }
    if (row >= curwin->w_height_inner) {
      curwin->w_skipcol += (row - curwin->w_height_inner) * width2;
    }
    redraw_later(curwin, UPD_NOT_VALID);
  }
}

/// Don't end up with too many filler lines in the window.
///
/// @param down  when true scroll down when not enough space
void check_topfill(win_T *wp, bool down)
{
  if (wp->w_topfill > 0) {
    int n = plines_win_nofill(wp, wp->w_topline, true);
    if (wp->w_topfill + n > wp->w_height_inner) {
      if (down && wp->w_topline > 1) {
        wp->w_topline--;
        wp->w_topfill = 0;
      } else {
        wp->w_topfill = wp->w_height_inner - n;
        if (wp->w_topfill < 0) {
          wp->w_topfill = 0;
        }
      }
    }
  }
  win_check_anchored_floats(curwin);
}

// Use as many filler lines as possible for w_topline.  Make sure w_topline
// is still visible.
static void max_topfill(void)
{
  int n = plines_win_nofill(curwin, curwin->w_topline, true);
  if (n >= curwin->w_height_inner) {
    curwin->w_topfill = 0;
  } else {
    curwin->w_topfill = win_get_fill(curwin, curwin->w_topline);
    if (curwin->w_topfill + n > curwin->w_height_inner) {
      curwin->w_topfill = curwin->w_height_inner - n;
    }
  }
}

// Scroll the screen one line down, but don't do it if it would move the
// cursor off the screen.
void scrolldown_clamp(void)
{
  int can_fill = (curwin->w_topfill < win_get_fill(curwin, curwin->w_topline));

  if (curwin->w_topline <= 1
      && !can_fill) {
    return;
  }

  validate_cursor();        // w_wrow needs to be valid

  // Compute the row number of the last row of the cursor line
  // and make sure it doesn't go off the screen. Make sure the cursor
  // doesn't go past 'scrolloff' lines from the screen end.
  int end_row = curwin->w_wrow;
  if (can_fill) {
    end_row++;
  } else {
    end_row += plines_win_nofill(curwin, curwin->w_topline - 1, true);
  }
  if (curwin->w_p_wrap && curwin->w_width_inner != 0) {
    validate_cheight();
    validate_virtcol();
    end_row += curwin->w_cline_height - 1 -
               curwin->w_virtcol / curwin->w_width_inner;
  }
  if (end_row < curwin->w_height_inner - get_scrolloff_value(curwin)) {
    if (can_fill) {
      curwin->w_topfill++;
      check_topfill(curwin, true);
    } else {
      curwin->w_topline--;
      curwin->w_topfill = 0;
    }
    (void)hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
    curwin->w_botline--;            // approximate w_botline
    curwin->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE);
  }
}

// Scroll the screen one line up, but don't do it if it would move the cursor
// off the screen.
void scrollup_clamp(void)
{
  if (curwin->w_topline == curbuf->b_ml.ml_line_count
      && curwin->w_topfill == 0) {
    return;
  }

  validate_cursor();        // w_wrow needs to be valid

  // Compute the row number of the first row of the cursor line
  // and make sure it doesn't go off the screen. Make sure the cursor
  // doesn't go before 'scrolloff' lines from the screen start.
  int start_row = (curwin->w_wrow
                   - plines_win_nofill(curwin, curwin->w_topline, true)
                   - curwin->w_topfill);
  if (curwin->w_p_wrap && curwin->w_width_inner != 0) {
    validate_virtcol();
    start_row -= curwin->w_virtcol / curwin->w_width_inner;
  }
  if (start_row >= get_scrolloff_value(curwin)) {
    if (curwin->w_topfill > 0) {
      curwin->w_topfill--;
    } else {
      (void)hasFolding(curwin->w_topline, NULL, &curwin->w_topline);
      curwin->w_topline++;
    }
    curwin->w_botline++;                // approximate w_botline
    curwin->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE);
  }
}

// Add one line above "lp->lnum".  This can be a filler line, a closed fold or
// a (wrapped) text line.  Uses and sets "lp->fill".
// Returns the height of the added line in "lp->height".
// Lines above the first one are incredibly high: MAXCOL.
// When "winheight" is true limit to window height.
static void topline_back_winheight(win_T *wp, lineoff_T *lp, int winheight)
{
  if (lp->fill < win_get_fill(wp, lp->lnum)) {
    // Add a filler line
    lp->fill++;
    lp->height = 1;
  } else {
    lp->lnum--;
    lp->fill = 0;
    if (lp->lnum < 1) {
      lp->height = MAXCOL;
    } else if (hasFolding(lp->lnum, &lp->lnum, NULL)) {
      // Add a closed fold
      lp->height = 1;
    } else {
      lp->height = plines_win_nofill(wp, lp->lnum, winheight);
    }
  }
}

static void topline_back(win_T *wp, lineoff_T *lp)
{
  topline_back_winheight(wp, lp, true);
}

// Add one line below "lp->lnum".  This can be a filler line, a closed fold or
// a (wrapped) text line.  Uses and sets "lp->fill".
// Returns the height of the added line in "lp->height".
// Lines below the last one are incredibly high.
static void botline_forw(win_T *wp, lineoff_T *lp)
{
  if (lp->fill < win_get_fill(wp, lp->lnum + 1)) {
    // Add a filler line.
    lp->fill++;
    lp->height = 1;
  } else {
    lp->lnum++;
    lp->fill = 0;
    assert(wp->w_buffer != 0);
    if (lp->lnum > wp->w_buffer->b_ml.ml_line_count) {
      lp->height = MAXCOL;
    } else if (hasFoldingWin(wp, lp->lnum, NULL, &lp->lnum, true, NULL)) {
      // Add a closed fold
      lp->height = 1;
    } else {
      lp->height = plines_win_nofill(wp, lp->lnum, true);
    }
  }
}

// Switch from including filler lines below lp->lnum to including filler
// lines above loff.lnum + 1.  This keeps pointing to the same line.
// When there are no filler lines nothing changes.
static void botline_topline(lineoff_T *lp)
{
  if (lp->fill > 0) {
    lp->lnum++;
    lp->fill = win_get_fill(curwin, lp->lnum) - lp->fill + 1;
  }
}

// Switch from including filler lines above lp->lnum to including filler
// lines below loff.lnum - 1.  This keeps pointing to the same line.
// When there are no filler lines nothing changes.
static void topline_botline(lineoff_T *lp)
{
  if (lp->fill > 0) {
    lp->fill = win_get_fill(curwin, lp->lnum) - lp->fill + 1;
    lp->lnum--;
  }
}

// Recompute topline to put the cursor at the top of the window.
// Scroll at least "min_scroll" lines.
// If "always" is true, always set topline (for "zt").
void scroll_cursor_top(int min_scroll, int always)
{
  linenr_T old_topline = curwin->w_topline;
  int old_skipcol = curwin->w_skipcol;
  linenr_T old_topfill = curwin->w_topfill;
  int off = (int)get_scrolloff_value(curwin);

  if (mouse_dragging > 0) {
    off = mouse_dragging - 1;
  }

  // Decrease topline until:
  // - it has become 1
  // - (part of) the cursor line is moved off the screen or
  // - moved at least 'scrolljump' lines and
  // - at least 'scrolloff' lines above and below the cursor
  validate_cheight();
  int scrolled = 0;
  int used = curwin->w_cline_height;  // includes filler lines above
  if (curwin->w_cursor.lnum < curwin->w_topline) {
    scrolled = used;
  }

  linenr_T top;  // just above displayed lines
  linenr_T bot;  // just below displayed lines
  if (hasFolding(curwin->w_cursor.lnum, &top, &bot)) {
    top--;
    bot++;
  } else {
    top = curwin->w_cursor.lnum - 1;
    bot = curwin->w_cursor.lnum + 1;
  }
  linenr_T new_topline = top + 1;

  // "used" already contains the number of filler lines above, don't add it
  // again.
  // Hide filler lines above cursor line by adding them to "extra".
  int extra = win_get_fill(curwin, curwin->w_cursor.lnum);

  // Check if the lines from "top" to "bot" fit in the window.  If they do,
  // set new_topline and advance "top" and "bot" to include more lines.
  while (top > 0) {
    int i = hasFolding(top, &top, NULL)
            ? 1  // count one logical line for a sequence of folded lines
            : plines_win_nofill(curwin, top, true);
    if (top < curwin->w_topline) {
      scrolled += i;
    }

    // If scrolling is needed, scroll at least 'sj' lines.
    if ((new_topline >= curwin->w_topline || scrolled > min_scroll) && extra >= off) {
      break;
    }

    used += i;
    if (extra + i <= off && bot < curbuf->b_ml.ml_line_count) {
      if (hasFolding(bot, NULL, &bot)) {
        // count one logical line for a sequence of folded lines
        used++;
      } else {
        used += plines_win(curwin, bot, true);
      }
    }
    if (used > curwin->w_height_inner) {
      break;
    }

    extra += i;
    new_topline = top;
    top--;
    bot++;
  }

  // If we don't have enough space, put cursor in the middle.
  // This makes sure we get the same position when using "k" and "j"
  // in a small window.
  if (used > curwin->w_height_inner) {
    scroll_cursor_halfway(false, false);
  } else {
    // If "always" is false, only adjust topline to a lower value, higher
    // value may happen with wrapping lines.
    if (new_topline < curwin->w_topline || always) {
      curwin->w_topline = new_topline;
    }
    if (curwin->w_topline > curwin->w_cursor.lnum) {
      curwin->w_topline = curwin->w_cursor.lnum;
    }
    curwin->w_topfill = win_get_fill(curwin, curwin->w_topline);
    if (curwin->w_topfill > 0 && extra > off) {
      curwin->w_topfill -= extra - off;
      if (curwin->w_topfill < 0) {
        curwin->w_topfill = 0;
      }
    }
    check_topfill(curwin, false);
    if (curwin->w_topline == curwin->w_cursor.lnum) {
      validate_virtcol();
      if (curwin->w_skipcol >= curwin->w_virtcol) {
        // TODO(vim): if the line doesn't fit may optimize w_skipcol instead
        // of making it zero
        reset_skipcol(curwin);
      }
    }
    if (curwin->w_topline != old_topline
        || curwin->w_skipcol != old_skipcol
        || curwin->w_topfill != old_topfill) {
      curwin->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
    }
    curwin->w_valid |= VALID_TOPLINE;
    curwin->w_viewport_invalid = true;
  }
}

// Set w_empty_rows and w_filler_rows for window "wp", having used up "used"
// screen lines for text lines.
void set_empty_rows(win_T *wp, int used)
{
  wp->w_filler_rows = 0;
  if (used == 0) {
    wp->w_empty_rows = 0;  // single line that doesn't fit
  } else {
    wp->w_empty_rows = wp->w_height_inner - used;
    if (wp->w_botline <= wp->w_buffer->b_ml.ml_line_count) {
      wp->w_filler_rows = win_get_fill(wp, wp->w_botline);
      if (wp->w_empty_rows > wp->w_filler_rows) {
        wp->w_empty_rows -= wp->w_filler_rows;
      } else {
        wp->w_filler_rows = wp->w_empty_rows;
        wp->w_empty_rows = 0;
      }
    }
  }
}

/// Recompute topline to put the cursor at the bottom of the window.
/// When scrolling scroll at least "min_scroll" lines.
/// If "set_topbot" is true, set topline and botline first (for "zb").
/// This is messy stuff!!!
void scroll_cursor_bot(int min_scroll, int set_topbot)
{
  int used;
  lineoff_T loff;
  linenr_T old_topline = curwin->w_topline;
  int old_skipcol = curwin->w_skipcol;
  int old_topfill = curwin->w_topfill;
  linenr_T old_botline = curwin->w_botline;
  int old_valid = curwin->w_valid;
  int old_empty_rows = curwin->w_empty_rows;
  linenr_T cln = curwin->w_cursor.lnum;  // Cursor Line Number
  int do_sms = curwin->w_p_wrap && curwin->w_p_sms;

  if (set_topbot) {
    bool set_skipcol = false;

    used = 0;
    curwin->w_botline = cln + 1;
    loff.fill = 0;
    for (curwin->w_topline = curwin->w_botline;
         curwin->w_topline > 1;
         curwin->w_topline = loff.lnum) {
      loff.lnum = curwin->w_topline;
      topline_back_winheight(curwin, &loff, false);
      if (loff.height == MAXCOL) {
        break;
      }
      if (used + loff.height > curwin->w_height_inner) {
        if (do_sms) {
          // 'smoothscroll' and 'wrap' are set.  The above line is
          // too long to show in its entirety, so we show just a part
          // of it.
          if (used < curwin->w_height_inner) {
            int plines_offset = used + loff.height - curwin->w_height_inner;
            used = curwin->w_height_inner;
            curwin->w_topfill = loff.fill;
            curwin->w_topline = loff.lnum;
            curwin->w_skipcol = skipcol_from_plines(curwin, plines_offset);
            set_skipcol = true;
          }
        }
        break;
      }
      used += loff.height;
      curwin->w_topfill = loff.fill;
    }
    set_empty_rows(curwin, used);
    curwin->w_valid |= VALID_BOTLINE|VALID_BOTLINE_AP;
    if (curwin->w_topline != old_topline
        || curwin->w_topfill != old_topfill
        || set_skipcol
        || curwin->w_skipcol != 0) {
      curwin->w_valid &= ~(VALID_WROW|VALID_CROW);
      if (set_skipcol) {
        redraw_later(curwin, UPD_NOT_VALID);
      } else {
        reset_skipcol(curwin);
      }
    }
  } else {
    validate_botline(curwin);
  }

  // The lines of the cursor line itself are always used.
  used = plines_win_nofill(curwin, cln, true);

  int scrolled = 0;
  // If the cursor is on or below botline, we will at least scroll by the
  // height of the cursor line, which is "used".  Correct for empty lines,
  // which are really part of botline.
  if (cln >= curwin->w_botline) {
    scrolled = used;
    if (cln == curwin->w_botline) {
      scrolled -= curwin->w_empty_rows;
    }
    if (do_sms) {
      // 'smoothscroll' and 'wrap' are set.
      // Calculate how many screen lines the current top line of window
      // occupies. If it is occupying more than the entire window, we
      // need to scroll the additional clipped lines to scroll past the
      // top line before we can move on to the other lines.
      int top_plines = plines_win_nofill(curwin, curwin->w_topline, false);
      int skip_lines = 0;
      int width1 = curwin->w_width_inner - curwin_col_off();
      if (width1 > 0) {
        int width2 = width1 + curwin_col_off2();
        // similar formula is used in curs_columns()
        if (curwin->w_skipcol > width1) {
          skip_lines += (curwin->w_skipcol - width1) / width2 + 1;
        } else if (curwin->w_skipcol > 0) {
          skip_lines = 1;
        }

        top_plines -= skip_lines;
        if (top_plines > curwin->w_height_inner) {
          scrolled += (top_plines - curwin->w_height_inner);
        }
      }
    }
  }

  lineoff_T boff;
  // Stop counting lines to scroll when
  // - hitting start of the file
  // - scrolled nothing or at least 'sj' lines
  // - at least 'so' lines below the cursor
  // - lines between botline and cursor have been counted
  if (!hasFolding(curwin->w_cursor.lnum, &loff.lnum, &boff.lnum)) {
    loff.lnum = cln;
    boff.lnum = cln;
  }
  loff.fill = 0;
  boff.fill = 0;
  int fill_below_window = win_get_fill(curwin, curwin->w_botline) - curwin->w_filler_rows;

  int extra = 0;
  long so = get_scrolloff_value(curwin);
  while (loff.lnum > 1) {
    // Stop when scrolled nothing or at least "min_scroll", found "extra"
    // context for 'scrolloff' and counted all lines below the window.
    if ((((scrolled <= 0 || scrolled >= min_scroll)
          && extra >= (mouse_dragging > 0 ? mouse_dragging - 1 : so))
         || boff.lnum + 1 > curbuf->b_ml.ml_line_count)
        && loff.lnum <= curwin->w_botline
        && (loff.lnum < curwin->w_botline
            || loff.fill >= fill_below_window)) {
      break;
    }

    // Add one line above
    topline_back(curwin, &loff);
    if (loff.height == MAXCOL) {
      used = MAXCOL;
    } else {
      used += loff.height;
    }
    if (used > curwin->w_height_inner) {
      break;
    }
    if (loff.lnum >= curwin->w_botline
        && (loff.lnum > curwin->w_botline
            || loff.fill <= fill_below_window)) {
      // Count screen lines that are below the window.
      scrolled += loff.height;
      if (loff.lnum == curwin->w_botline
          && loff.fill == 0) {
        scrolled -= curwin->w_empty_rows;
      }
    }

    if (boff.lnum < curbuf->b_ml.ml_line_count) {
      // Add one line below
      botline_forw(curwin, &boff);
      used += boff.height;
      if (used > curwin->w_height_inner) {
        break;
      }
      if (extra < (mouse_dragging > 0 ? mouse_dragging - 1 : so)
          || scrolled < min_scroll) {
        extra += boff.height;
        if (boff.lnum >= curwin->w_botline
            || (boff.lnum + 1 == curwin->w_botline
                && boff.fill > curwin->w_filler_rows)) {
          // Count screen lines that are below the window.
          scrolled += boff.height;
          if (boff.lnum == curwin->w_botline
              && boff.fill == 0) {
            scrolled -= curwin->w_empty_rows;
          }
        }
      }
    }
  }

  linenr_T line_count;
  // curwin->w_empty_rows is larger, no need to scroll
  if (scrolled <= 0) {
    line_count = 0;
    // more than a screenfull, don't scroll but redraw
  } else if (used > curwin->w_height_inner) {
    line_count = used;
    // scroll minimal number of lines
  } else {
    line_count = 0;
    boff.fill = curwin->w_topfill;
    boff.lnum = curwin->w_topline - 1;
    int i;
    for (i = 0; i < scrolled && boff.lnum < curwin->w_botline;) {
      botline_forw(curwin, &boff);
      i += boff.height;
      line_count++;
    }
    if (i < scrolled) {         // below curwin->w_botline, don't scroll
      line_count = 9999;
    }
  }

  // Scroll up if the cursor is off the bottom of the screen a bit.
  // Otherwise put it at 1/2 of the screen.
  if (line_count >= curwin->w_height_inner && line_count > min_scroll) {
    scroll_cursor_halfway(false, true);
  } else if (line_count > 0) {
    if (do_sms) {
      scrollup(scrolled, true);  // TODO(vim):
    } else {
      scrollup(line_count, true);
    }
  }

  // If topline didn't change we need to restore w_botline and w_empty_rows
  // (we changed them).
  // If topline did change, update_screen() will set botline.
  if (curwin->w_topline == old_topline && curwin->w_skipcol == old_skipcol && set_topbot) {
    curwin->w_botline = old_botline;
    curwin->w_empty_rows = old_empty_rows;
    curwin->w_valid = old_valid;
  }
  curwin->w_valid |= VALID_TOPLINE;
  curwin->w_viewport_invalid = true;
}

/// Recompute topline to put the cursor halfway across the window
///
/// @param atend if true, also put the cursor halfway to the end of the file.
///
void scroll_cursor_halfway(bool atend, bool prefer_above)
{
  linenr_T old_topline = curwin->w_topline;
  lineoff_T loff = { .lnum = curwin->w_cursor.lnum };
  lineoff_T boff = { .lnum = curwin->w_cursor.lnum };
  (void)hasFolding(loff.lnum, &loff.lnum, &boff.lnum);
  int used = plines_win_nofill(curwin, loff.lnum, true);
  loff.fill = 0;
  boff.fill = 0;
  linenr_T topline = loff.lnum;
  colnr_T skipcol = 0;

  int want_height;
  bool do_sms = curwin->w_p_wrap && curwin->w_p_sms;
  if (do_sms) {
    // 'smoothscroll' and 'wrap' are set
    if (atend) {
      want_height = (curwin->w_height_inner - used) / 2;
      used = 0;
    } else {
      want_height = curwin->w_height_inner;
    }
  }

  int topfill = 0;
  while (topline > 1) {
    // If using smoothscroll, we can precisely scroll to the
    // exact point where the cursor is halfway down the screen.
    if (do_sms) {
      topline_back_winheight(curwin, &loff, false);
      if (loff.height == MAXCOL) {
        break;
      }
      used += loff.height;
      if (!atend && boff.lnum < curbuf->b_ml.ml_line_count) {
        botline_forw(curwin, &boff);
        used += boff.height;
      }
      if (used > want_height) {
        if (used - loff.height < want_height) {
          topline = loff.lnum;
          topfill = loff.fill;
          skipcol = skipcol_from_plines(curwin, used - want_height);
        }
        break;
      }
      topline = loff.lnum;
      topfill = loff.fill;
      continue;
    }

    // If not using smoothscroll, we have to iteratively find how many
    // lines to scroll down to roughly fit the cursor.
    // This may not be right in the middle if the lines'
    // physical height > 1 (e.g. 'wrap' is on).

    // Depending on "prefer_above" we add a line above or below first.
    // Loop twice to avoid duplicating code.
    bool done = false;
    int above = 0;
    int below = 0;
    for (int round = 1; round <= 2; round++) {
      if (prefer_above
          ? (round == 2 && below < above)
          : (round == 1 && below <= above)) {
        // add a line below the cursor
        if (boff.lnum < curbuf->b_ml.ml_line_count) {
          botline_forw(curwin, &boff);
          used += boff.height;
          if (used > curwin->w_height_inner) {
            done = true;
            break;
          }
          below += boff.height;
        } else {
          below++;                    // count a "~" line
          if (atend) {
            used++;
          }
        }
      }

      if (prefer_above
          ? (round == 1 && below >= above)
          : (round == 1 && below > above)) {
        // add a line above the cursor
        topline_back(curwin, &loff);
        if (loff.height == MAXCOL) {
          used = MAXCOL;
        } else {
          used += loff.height;
        }
        if (used > curwin->w_height_inner) {
          done = true;
          break;
        }
        above += loff.height;
        topline = loff.lnum;
        topfill = loff.fill;
      }
    }
    if (done) {
      break;
    }
  }

  if (!hasFolding(topline, &curwin->w_topline, NULL)
      && (curwin->w_topline != topline || skipcol != 0 || curwin->w_skipcol != 0)) {
    curwin->w_topline = topline;
    if (skipcol != 0) {
      curwin->w_skipcol = skipcol;
      redraw_later(curwin, UPD_NOT_VALID);
    } else if (do_sms) {
      reset_skipcol(curwin);
    }
  }
  curwin->w_topfill = topfill;
  if (old_topline > curwin->w_topline + curwin->w_height_inner) {
    curwin->w_botfill = false;
  }
  check_topfill(curwin, false);
  curwin->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
  curwin->w_valid |= VALID_TOPLINE;
}

// Correct the cursor position so that it is in a part of the screen at least
// 'so' lines from the top and bottom, if possible.
// If not possible, put it at the same position as scroll_cursor_halfway().
// When called topline must be valid!
void cursor_correct(void)
{
  // How many lines we would like to have above/below the cursor depends on
  // whether the first/last line of the file is on screen.
  int above_wanted = (int)get_scrolloff_value(curwin);
  int below_wanted = (int)get_scrolloff_value(curwin);
  if (mouse_dragging > 0) {
    above_wanted = mouse_dragging - 1;
    below_wanted = mouse_dragging - 1;
  }
  if (curwin->w_topline == 1) {
    above_wanted = 0;
    int max_off = curwin->w_height_inner / 2;
    if (below_wanted > max_off) {
      below_wanted = max_off;
    }
  }
  validate_botline(curwin);
  if (curwin->w_botline == curbuf->b_ml.ml_line_count + 1
      && mouse_dragging == 0) {
    below_wanted = 0;
    int max_off = (curwin->w_height_inner - 1) / 2;
    if (above_wanted > max_off) {
      above_wanted = max_off;
    }
  }

  // If there are sufficient file-lines above and below the cursor, we can
  // return now.
  linenr_T cln = curwin->w_cursor.lnum;  // Cursor Line Number
  if (cln >= curwin->w_topline + above_wanted
      && cln < curwin->w_botline - below_wanted
      && !hasAnyFolding(curwin)) {
    return;
  }

  if (curwin->w_p_sms && !curwin->w_p_wrap) {
    // 'smoothscroll' is active
    if (curwin->w_cline_height == curwin->w_height_inner) {
      // The cursor line just fits in the window, don't scroll.
      reset_skipcol(curwin);
      return;
    }
    // TODO(vim): If the cursor line doesn't fit in the window then only adjust w_skipcol.
  }

  // Narrow down the area where the cursor can be put by taking lines from
  // the top and the bottom until:
  // - the desired context lines are found
  // - the lines from the top is past the lines from the bottom
  linenr_T topline = curwin->w_topline;
  linenr_T botline = curwin->w_botline - 1;
  // count filler lines as context
  int above = curwin->w_topfill;  // screen lines above topline
  int below = curwin->w_filler_rows;  // screen lines below botline
  while ((above < above_wanted || below < below_wanted) && topline < botline) {
    if (below < below_wanted && (below <= above || above >= above_wanted)) {
      if (hasFolding(botline, &botline, NULL)) {
        below++;
      } else {
        below += plines_win(curwin, botline, true);
      }
      botline--;
    }
    if (above < above_wanted && (above < below || below >= below_wanted)) {
      if (hasFolding(topline, NULL, &topline)) {
        above++;
      } else {
        above += plines_win_nofill(curwin, topline, true);
      }

      // Count filler lines below this line as context.
      if (topline < botline) {
        above += win_get_fill(curwin, topline + 1);
      }
      topline++;
    }
  }
  if (topline == botline || botline == 0) {
    curwin->w_cursor.lnum = topline;
  } else if (topline > botline) {
    curwin->w_cursor.lnum = botline;
  } else {
    if (cln < topline && curwin->w_topline > 1) {
      curwin->w_cursor.lnum = topline;
      curwin->w_valid &=
        ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW);
    }
    if (cln > botline && curwin->w_botline <= curbuf->b_ml.ml_line_count) {
      curwin->w_cursor.lnum = botline;
      curwin->w_valid &=
        ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW);
    }
  }
  curwin->w_valid |= VALID_TOPLINE;
  curwin->w_viewport_invalid = true;
}

/// Move screen "count" pages up ("dir" is BACKWARD) or down ("dir" is FORWARD)
/// and update the screen.
///
/// @return  FAIL for failure, OK otherwise.
int onepage(Direction dir, long count)
{
  long n;
  int retval = OK;
  lineoff_T loff;
  linenr_T old_topline = curwin->w_topline;
  long so = get_scrolloff_value(curwin);

  if (curbuf->b_ml.ml_line_count == 1) {    // nothing to do
    beep_flush();
    return FAIL;
  }

  for (; count > 0; count--) {
    validate_botline(curwin);
    // It's an error to move a page up when the first line is already on
    // the screen. It's an error to move a page down when the last line
    // is on the screen and the topline is 'scrolloff' lines from the
    // last line.
    if (dir == FORWARD
        ? ((curwin->w_topline >= curbuf->b_ml.ml_line_count - so)
           && curwin->w_botline > curbuf->b_ml.ml_line_count)
        : (curwin->w_topline == 1
           && curwin->w_topfill == win_get_fill(curwin, curwin->w_topline))) {
      beep_flush();
      retval = FAIL;
      break;
    }

    loff.fill = 0;
    if (dir == FORWARD) {
      if (ONE_WINDOW && p_window > 0 && p_window < Rows - 1) {
        // Vi compatible scrolling
        if (p_window <= 2) {
          curwin->w_topline++;
        } else {
          curwin->w_topline += (linenr_T)p_window - 2;
        }
        if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
          curwin->w_topline = curbuf->b_ml.ml_line_count;
        }
        curwin->w_cursor.lnum = curwin->w_topline;
      } else if (curwin->w_botline > curbuf->b_ml.ml_line_count) {
        // at end of file
        curwin->w_topline = curbuf->b_ml.ml_line_count;
        curwin->w_topfill = 0;
        curwin->w_valid &= ~(VALID_WROW|VALID_CROW);
      } else {
        // For the overlap, start with the line just below the window
        // and go upwards.
        loff.lnum = curwin->w_botline;
        loff.fill = win_get_fill(curwin, loff.lnum)
                    - curwin->w_filler_rows;
        get_scroll_overlap(&loff, -1);
        curwin->w_topline = loff.lnum;
        curwin->w_topfill = loff.fill;
        check_topfill(curwin, false);
        curwin->w_cursor.lnum = curwin->w_topline;
        curwin->w_valid &= ~(VALID_WCOL|VALID_CHEIGHT|VALID_WROW|
                             VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
      }
    } else {  // dir == BACKWARDS
      if (curwin->w_topline == 1) {
        // Include max number of filler lines
        max_topfill();
        continue;
      }
      if (ONE_WINDOW && p_window > 0 && p_window < Rows - 1) {
        // Vi compatible scrolling (sort of)
        if (p_window <= 2) {
          curwin->w_topline--;
        } else {
          curwin->w_topline -= (linenr_T)p_window - 2;
        }
        if (curwin->w_topline < 1) {
          curwin->w_topline = 1;
        }
        curwin->w_cursor.lnum = curwin->w_topline + (linenr_T)p_window - 1;
        if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
          curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
        }
        continue;
      }

      // Find the line at the top of the window that is going to be the
      // line at the bottom of the window.  Make sure this results in
      // the same line as before doing CTRL-F.
      loff.lnum = curwin->w_topline - 1;
      loff.fill = win_get_fill(curwin, loff.lnum + 1) - curwin->w_topfill;
      get_scroll_overlap(&loff, 1);

      if (loff.lnum >= curbuf->b_ml.ml_line_count) {
        loff.lnum = curbuf->b_ml.ml_line_count;
        loff.fill = 0;
      } else {
        botline_topline(&loff);
      }
      curwin->w_cursor.lnum = loff.lnum;

      // Find the line just above the new topline to get the right line
      // at the bottom of the window.
      n = 0;
      while (n <= curwin->w_height_inner && loff.lnum >= 1) {
        topline_back(curwin, &loff);
        if (loff.height == MAXCOL) {
          n = MAXCOL;
        } else {
          n += loff.height;
        }
      }
      if (loff.lnum < 1) {                      // at begin of file
        curwin->w_topline = 1;
        max_topfill();
        curwin->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE);
      } else {
        // Go two lines forward again.
        topline_botline(&loff);
        botline_forw(curwin, &loff);
        botline_forw(curwin, &loff);
        botline_topline(&loff);
        // We're at the wrong end of a fold now.
        (void)hasFoldingWin(curwin, loff.lnum, &loff.lnum, NULL, true, NULL);

        // Always scroll at least one line.  Avoid getting stuck on
        // very long lines.
        if (loff.lnum >= curwin->w_topline
            && (loff.lnum > curwin->w_topline
                || loff.fill >= curwin->w_topfill)) {
          // First try using the maximum number of filler lines.  If
          // that's not enough, backup one line.
          loff.fill = curwin->w_topfill;
          if (curwin->w_topfill < win_get_fill(curwin, curwin->w_topline)) {
            max_topfill();
          }
          if (curwin->w_topfill == loff.fill) {
            curwin->w_topline--;
            curwin->w_topfill = 0;
          }
          comp_botline(curwin);
          curwin->w_cursor.lnum = curwin->w_botline - 1;
          curwin->w_valid &=
            ~(VALID_WCOL | VALID_CHEIGHT | VALID_WROW | VALID_CROW);
        } else {
          curwin->w_topline = loff.lnum;
          curwin->w_topfill = loff.fill;
          check_topfill(curwin, false);
          curwin->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE);
        }
      }
    }
  }
  foldAdjustCursor();
  cursor_correct();
  check_cursor_col();
  if (retval == OK) {
    beginline(BL_SOL | BL_FIX);
  }
  curwin->w_valid &= ~(VALID_WCOL|VALID_WROW|VALID_VIRTCOL);

  if (retval == OK && dir == FORWARD) {
    // Avoid the screen jumping up and down when 'scrolloff' is non-zero.
    // But make sure we scroll at least one line (happens with mix of long
    // wrapping lines and non-wrapping line).
    if (check_top_offset()) {
      scroll_cursor_top(1, false);
      if (curwin->w_topline <= old_topline
          && old_topline < curbuf->b_ml.ml_line_count) {
        curwin->w_topline = old_topline + 1;
        (void)hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
      }
    } else if (curwin->w_botline > curbuf->b_ml.ml_line_count) {
      (void)hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
    }
  }

  redraw_later(curwin, UPD_VALID);
  return retval;
}

// Decide how much overlap to use for page-up or page-down scrolling.
// This is symmetric, so that doing both keeps the same lines displayed.
// Three lines are examined:
//
//  before CTRL-F           after CTRL-F / before CTRL-B
//     etc.                     l1
//  l1 last but one line        ------------
//  l2 last text line           l2 top text line
//  -------------               l3 second text line
//  l3                             etc.
static void get_scroll_overlap(lineoff_T *lp, int dir)
{
  int min_height = curwin->w_height_inner - 2;

  if (lp->fill > 0) {
    lp->height = 1;
  } else {
    lp->height = plines_win_nofill(curwin, lp->lnum, true);
  }
  int h1 = lp->height;
  if (h1 > min_height) {
    return;             // no overlap
  }
  lineoff_T loff0 = *lp;
  if (dir > 0) {
    botline_forw(curwin, lp);
  } else {
    topline_back(curwin, lp);
  }
  int h2 = lp->height;
  if (h2 == MAXCOL || h2 + h1 > min_height) {
    *lp = loff0;        // no overlap
    return;
  }

  lineoff_T loff1 = *lp;
  if (dir > 0) {
    botline_forw(curwin, lp);
  } else {
    topline_back(curwin, lp);
  }
  int h3 = lp->height;
  if (h3 == MAXCOL || h3 + h2 > min_height) {
    *lp = loff0;        // no overlap
    return;
  }

  lineoff_T loff2 = *lp;
  if (dir > 0) {
    botline_forw(curwin, lp);
  } else {
    topline_back(curwin, lp);
  }
  int h4 = lp->height;
  if (h4 == MAXCOL || h4 + h3 + h2 > min_height || h3 + h2 + h1 > min_height) {
    *lp = loff1;        // 1 line overlap
  } else {
    *lp = loff2;        // 2 lines overlap
  }
}

// Scroll 'scroll' lines up or down.
void halfpage(bool flag, linenr_T Prenum)
{
  long scrolled = 0;
  int i;

  if (Prenum) {
    curwin->w_p_scr = (Prenum > curwin->w_height_inner) ? curwin->w_height_inner
                                                        : Prenum;
  }
  assert(curwin->w_p_scr <= INT_MAX);
  int n = curwin->w_p_scr <= curwin->w_height_inner ? (int)curwin->w_p_scr
                                                    : curwin->w_height_inner;

  update_topline(curwin);
  validate_botline(curwin);
  int room = curwin->w_empty_rows + curwin->w_filler_rows;
  if (flag) {
    // scroll the text up
    while (n > 0 && curwin->w_botline <= curbuf->b_ml.ml_line_count) {
      if (curwin->w_topfill > 0) {
        i = 1;
        n--;
        curwin->w_topfill--;
      } else {
        i = plines_win_nofill(curwin, curwin->w_topline, true);
        n -= i;
        if (n < 0 && scrolled > 0) {
          break;
        }
        (void)hasFolding(curwin->w_topline, NULL, &curwin->w_topline);
        curwin->w_topline++;
        curwin->w_topfill = win_get_fill(curwin, curwin->w_topline);

        if (curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
          curwin->w_cursor.lnum++;
          curwin->w_valid &=
            ~(VALID_VIRTCOL|VALID_CHEIGHT|VALID_WCOL);
        }
      }
      curwin->w_valid &= ~(VALID_CROW|VALID_WROW);
      scrolled += i;

      // Correct w_botline for changed w_topline.
      // Won't work when there are filler lines.
      if (win_may_fill(curwin)) {
        curwin->w_valid &= ~(VALID_BOTLINE|VALID_BOTLINE_AP);
      } else {
        room += i;
        do {
          i = plines_win(curwin, curwin->w_botline, true);
          if (i > room) {
            break;
          }
          (void)hasFolding(curwin->w_botline, NULL, &curwin->w_botline);
          curwin->w_botline++;
          room -= i;
        } while (curwin->w_botline <= curbuf->b_ml.ml_line_count);
      }
    }

    // When hit bottom of the file: move cursor down.
    if (n > 0) {
      if (hasAnyFolding(curwin)) {
        while (--n >= 0
               && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
          (void)hasFolding(curwin->w_cursor.lnum, NULL,
                           &curwin->w_cursor.lnum);
          curwin->w_cursor.lnum++;
        }
      } else {
        curwin->w_cursor.lnum += n;
      }
      check_cursor_lnum();
    }
  } else {
    // scroll the text down
    while (n > 0 && curwin->w_topline > 1) {
      if (curwin->w_topfill < win_get_fill(curwin, curwin->w_topline)) {
        i = 1;
        n--;
        curwin->w_topfill++;
      } else {
        i = plines_win_nofill(curwin, curwin->w_topline - 1, true);
        n -= i;
        if (n < 0 && scrolled > 0) {
          break;
        }
        curwin->w_topline--;
        (void)hasFolding(curwin->w_topline, &curwin->w_topline, NULL);
        curwin->w_topfill = 0;
      }
      curwin->w_valid &= ~(VALID_CROW|VALID_WROW|
                           VALID_BOTLINE|VALID_BOTLINE_AP);
      scrolled += i;
      if (curwin->w_cursor.lnum > 1) {
        curwin->w_cursor.lnum--;
        curwin->w_valid &= ~(VALID_VIRTCOL|VALID_CHEIGHT|VALID_WCOL);
      }
    }

    // When hit top of the file: move cursor up.
    if (n > 0) {
      if (curwin->w_cursor.lnum <= (linenr_T)n) {
        curwin->w_cursor.lnum = 1;
      } else if (hasAnyFolding(curwin)) {
        while (--n >= 0 && curwin->w_cursor.lnum > 1) {
          curwin->w_cursor.lnum--;
          (void)hasFolding(curwin->w_cursor.lnum,
                           &curwin->w_cursor.lnum, NULL);
        }
      } else {
        curwin->w_cursor.lnum -= n;
      }
    }
  }
  // Move cursor to first line of closed fold.
  foldAdjustCursor();
  check_topfill(curwin, !flag);
  cursor_correct();
  beginline(BL_SOL | BL_FIX);
  redraw_later(curwin, UPD_VALID);
}

void do_check_cursorbind(void)
{
  linenr_T line    = curwin->w_cursor.lnum;
  colnr_T col      = curwin->w_cursor.col;
  colnr_T coladd   = curwin->w_cursor.coladd;
  colnr_T curswant = curwin->w_curswant;
  int set_curswant = curwin->w_set_curswant;
  win_T *old_curwin = curwin;
  buf_T *old_curbuf = curbuf;
  int old_VIsual_select = VIsual_select;
  int old_VIsual_active = VIsual_active;

  // loop through the cursorbound windows
  VIsual_select = VIsual_active = false;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    curwin = wp;
    curbuf = curwin->w_buffer;
    // skip original window  and windows with 'noscrollbind'
    if (curwin != old_curwin && curwin->w_p_crb) {
      if (curwin->w_p_diff) {
        curwin->w_cursor.lnum =
          diff_get_corresponding_line(old_curbuf, line);
      } else {
        curwin->w_cursor.lnum = line;
      }
      curwin->w_cursor.col = col;
      curwin->w_cursor.coladd = coladd;
      curwin->w_curswant = curswant;
      curwin->w_set_curswant = set_curswant;

      // Make sure the cursor is in a valid position.  Temporarily set
      // "restart_edit" to allow the cursor to be beyond the EOL.
      {
        int restart_edit_save = restart_edit;
        restart_edit = true;
        check_cursor();

        // Avoid a scroll here for the cursor position, 'scrollbind' is
        // more important.
        if (!curwin->w_p_scb) {
          validate_cursor();
        }

        restart_edit = restart_edit_save;
      }
      // Correct cursor for multi-byte character.
      mb_adjust_cursor();
      redraw_later(curwin, UPD_VALID);

      // Only scroll when 'scrollbind' hasn't done this.
      if (!curwin->w_p_scb) {
        update_topline(curwin);
      }
      curwin->w_redr_status = true;
    }
  }

  // reset current-window
  VIsual_select = old_VIsual_select;
  VIsual_active = old_VIsual_active;
  curwin = old_curwin;
  curbuf = old_curbuf;
}
