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
#include <stdint.h>
#include <stdlib.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/window.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/normal_defs.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

typedef struct {
  linenr_T lnum;                // line number
  int fill;                     // filler lines
  int height;                   // height of added line
} lineoff_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "move.c.generated.h"
#endif

/// Get the number of screen lines skipped with "wp->w_skipcol".
int adjust_plines_for_skipcol(win_T *wp)
{
  if (wp->w_skipcol == 0) {
    return 0;
  }

  int width = wp->w_width_inner - win_col_off(wp);
  int w2 = width + win_col_off2(wp);
  if (wp->w_skipcol >= width && w2 > 0) {
    return (wp->w_skipcol - width) / w2 + 1;
  }

  return 0;
}

/// Return how many lines "lnum" will take on the screen, taking into account
/// whether it is the first line, whether w_skipcol is non-zero and limiting to
/// the window height.
static int plines_correct_topline(win_T *wp, linenr_T lnum, linenr_T *nextp, bool limit_winheight,
                                  bool *foldedp)
{
  int n = plines_win_full(wp, lnum, nextp, foldedp, true, false);
  if (lnum == wp->w_topline) {
    n -= adjust_plines_for_skipcol(wp);
  }
  if (limit_winheight && n > wp->w_height_inner) {
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
    int n = plines_correct_topline(wp, lnum, &last, true, &folded);
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

/// Redraw when w_cline_row changes and 'relativenumber' or 'cursorline' is set.
/// Also when concealing is on and 'concealcursor' is not active.
static void redraw_for_cursorline(win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  if ((wp->w_valid & VALID_CROW) == 0 && !pum_visible()
      && (wp->w_p_rnu || win_cursorline_standout(wp))) {
    // win_line() will redraw the number column and cursorline only.
    redraw_later(wp, UPD_VALID);
  }
}

/// Redraw when 'concealcursor' is active, or when w_virtcol changes and:
/// - 'cursorcolumn' is set, or
/// - 'cursorlineopt' contains "screenline", or
/// - Visual mode is active.
static void redraw_for_cursorcolumn(win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  // If the cursor moves horizontally when 'concealcursor' is active, then the
  // current line needs to be redrawn to calculate the correct cursor position.
  if (wp->w_p_cole > 0 && conceal_cursor_line(wp)) {
    redrawWinline(wp, wp->w_cursor.lnum);
  }

  if ((wp->w_valid & VALID_VIRTCOL) || pum_visible()) {
    return;
  }

  if (wp->w_p_cuc) {
    // When 'cursorcolumn' is set need to redraw with UPD_SOME_VALID.
    redraw_later(wp, UPD_SOME_VALID);
  } else if (wp->w_p_cul && (wp->w_p_culopt_flags & kOptCuloptFlagScreenline)) {
    // When 'cursorlineopt' contains "screenline" need to redraw with UPD_VALID.
    redraw_later(wp, UPD_VALID);
  }

  // When current buffer's cursor moves in Visual mode, redraw it with UPD_INVERTED.
  if (VIsual_active && wp->w_buffer == curbuf) {
    redraw_buf_later(curbuf, UPD_INVERTED);
  }
}

/// Calculates how much the 'listchars' "precedes" or 'smoothscroll' "<<<"
/// marker overlaps with buffer text for window "wp".
/// Parameter "extra2" should be the padding on the 2nd line, not the first
/// line. When "extra2" is -1 calculate the padding.
/// Returns the number of columns of overlap with buffer text, excluding the
/// extra padding on the ledge.
int sms_marker_overlap(win_T *wp, int extra2)
{
  if (extra2 == -1) {
    extra2 = win_col_off(wp) - win_col_off2(wp);
  }
  // There is no marker overlap when in showbreak mode, thus no need to
  // account for it.  See wlv_put_linebuf().
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
  if (wp->w_skipcol == 0) {
    return;
  }

  wp->w_skipcol = 0;

  // Should use the least expensive way that displays all that changed.
  // UPD_NOT_VALID is too expensive, UPD_REDRAW_TOP does not redraw
  // enough when the top line gets another screen line.
  redraw_later(wp, UPD_SOME_VALID);
}

// Update wp->w_topline to move the cursor onto the screen.
void update_topline(win_T *wp)
{
  bool check_botline = false;
  OptInt *so_ptr = wp->w_p_so >= 0 ? &wp->w_p_so : &p_so;
  OptInt save_so = *so_ptr;

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
  if (buf_is_empty(wp->w_buffer)) {  // special case - file is empty
    if (wp->w_topline != 1) {
      redraw_later(wp, UPD_NOT_VALID);
    }
    wp->w_topline = 1;
    wp->w_botline = 2;
    wp->w_skipcol = 0;
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
      } else if (check_top_offset(wp)) {
        check_topline = true;
      } else if (wp->w_skipcol > 0 && wp->w_cursor.lnum == wp->w_topline) {
        colnr_T vcol;

        // Check that the cursor position is visible.  Add columns for
        // the marker displayed in the top-left if needed.
        getvvcol(wp, &wp->w_cursor, &vcol, NULL, NULL);
        int overlap = sms_marker_overlap(wp, -1);
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
      int64_t n;
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
          hasFolding(wp, lnum, NULL, &lnum);
        }
      } else {
        n = wp->w_topline + *so_ptr - wp->w_cursor.lnum;
      }

      // If we weren't very close to begin with, we scroll to put the
      // cursor in the middle of the window.  Otherwise put the cursor
      // near the top of the window.
      if (n >= halfheight) {
        scroll_cursor_halfway(wp, false, false);
      } else {
        scroll_cursor_top(wp, scrolljump_value(wp), false);
        check_botline = true;
      }
    } else {
      // Make sure topline is the first line of a fold.
      hasFolding(wp, wp->w_topline, &wp->w_topline, NULL);
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
        if ((wp->w_cursor.lnum >= wp->w_botline - *so_ptr || hasAnyFolding(wp))) {
          lineoff_T loff;

          // Cursor is (a few lines) above botline, check if there are
          // 'scrolloff' window lines below the cursor.  If not, need to
          // scroll.
          int n = wp->w_empty_rows;
          loff.lnum = wp->w_cursor.lnum;
          // In a fold go to its last line.
          hasFolding(wp, loff.lnum, NULL, &loff.lnum);
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
        int line_count = 0;
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
            hasFolding(wp, lnum, &lnum, NULL);
          }
        } else {
          line_count = wp->w_cursor.lnum - wp->w_botline + 1 + (int)(*so_ptr);
        }
        if (line_count <= wp->w_height_inner + 1) {
          scroll_cursor_bot(wp, scrolljump_value(wp), false);
        } else {
          scroll_cursor_halfway(wp, false, false);
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
      validate_cursor(wp);
    }
  }

  *so_ptr = save_so;
}

/// Return the scrolljump value to use for the window "wp".
/// When 'scrolljump' is positive use it as-is.
/// When 'scrolljump' is negative use it as a percentage of the window height.
static int scrolljump_value(win_T *wp)
{
  int result = p_sj >= 0 ? (int)p_sj : (wp->w_height_inner * (int)(-p_sj)) / 100;
  return result;
}

/// Return true when there are not 'scrolloff' lines above the cursor for window "wp".
static bool check_top_offset(win_T *wp)
{
  int so = get_scrolloff_value(wp);
  if (wp->w_cursor.lnum < wp->w_topline + so || hasAnyFolding(wp)) {
    lineoff_T loff;
    loff.lnum = wp->w_cursor.lnum;
    loff.fill = 0;
    int n = wp->w_topfill;  // always have this context
    // Count the visible screen lines above the cursor line.
    while (n < so) {
      topline_back(wp, &loff);
      // Stop when included a line above the window.
      if (loff.lnum < wp->w_topline
          || (loff.lnum == wp->w_topline && loff.fill > 0)) {
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
  validate_virtcol(curwin);
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
void changed_window_setting(win_T *wp)
{
  wp->w_lines_valid = 0;
  changed_line_abv_curs_win(wp);
  wp->w_valid &= ~(VALID_BOTLINE|VALID_BOTLINE_AP|VALID_TOPLINE);
  redraw_later(wp, UPD_NOT_VALID);
}

/// Call changed_window_setting() for every window.
void changed_window_setting_all(void)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    changed_window_setting(wp);
  }
}

// Set wp->w_topline to a certain number.
void set_topline(win_T *wp, linenr_T lnum)
{
  linenr_T prev_topline = wp->w_topline;

  // go to first of folded lines
  hasFolding(wp, lnum, &lnum, NULL);
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
void changed_cline_bef_curs(win_T *wp)
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

// Make sure the value of wp->w_botline is valid.
void validate_botline(win_T *wp)
{
  if (!(wp->w_valid & VALID_BOTLINE)) {
    comp_botline(wp);
  }
}

// Mark wp->w_botline as invalid (because of some change in the buffer).
void invalidate_botline(win_T *wp)
{
  wp->w_valid &= ~(VALID_BOTLINE|VALID_BOTLINE_AP);
}

void approximate_botline_win(win_T *wp)
{
  wp->w_valid &= ~VALID_BOTLINE;
}

// Return true if wp->w_wrow and wp->w_wcol are valid.
int cursor_valid(win_T *wp)
{
  check_cursor_moved(wp);
  return (wp->w_valid & (VALID_WROW|VALID_WCOL)) == (VALID_WROW|VALID_WCOL);
}

// Validate cursor position.  Makes sure w_wrow and w_wcol are valid.
// w_topline must be valid, you may need to call update_topline() first!
void validate_cursor(win_T *wp)
{
  check_cursor_lnum(wp);
  check_cursor_moved(wp);
  if ((wp->w_valid & (VALID_WCOL|VALID_WROW)) != (VALID_WCOL|VALID_WROW)) {
    curs_columns(wp, true);
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
      int n = plines_correct_topline(wp, lnum, &last, true, &folded);
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
      wp->w_cline_folded = hasFolding(wp, wp->w_cursor.lnum, NULL, NULL);
    } else {
      wp->w_cline_height = wp->w_lines[i].wl_size;
      wp->w_cline_folded = wp->w_lines[i].wl_folded;
    }
  }

  redraw_for_cursorline(wp);
  wp->w_valid |= VALID_CROW|VALID_CHEIGHT;
}

// Validate wp->w_virtcol only.
void validate_virtcol(win_T *wp)
{
  check_cursor_moved(wp);

  if (wp->w_valid & VALID_VIRTCOL) {
    return;
  }

  getvvcol(wp, &wp->w_cursor, NULL, &(wp->w_virtcol), NULL);
  redraw_for_cursorcolumn(wp);
  wp->w_valid |= VALID_VIRTCOL;
}

// Validate wp->w_cline_height only.
void validate_cheight(win_T *wp)
{
  check_cursor_moved(wp);

  if (wp->w_valid & VALID_CHEIGHT) {
    return;
  }

  wp->w_cline_height = plines_win_full(wp, wp->w_cursor.lnum,
                                       NULL, &wp->w_cline_folded,
                                       true, true);
  wp->w_valid |= VALID_CHEIGHT;
}

// Validate w_wcol and w_virtcol only.
void validate_cursor_col(win_T *wp)
{
  validate_virtcol(wp);

  if (wp->w_valid & VALID_WCOL) {
    return;
  }

  colnr_T col = wp->w_virtcol;
  colnr_T off = win_col_off(wp);
  col += off;
  int width = wp->w_width_inner - off + win_col_off2(wp);

  // long line wrapping, adjust wp->w_wrow
  if (wp->w_p_wrap && col >= (colnr_T)wp->w_width_inner && width > 0) {
    // use same formula as what is used in curs_columns()
    col -= ((col - wp->w_width_inner) / width + 1) * width;
  }
  if (col > (int)wp->w_leftcol) {
    col -= wp->w_leftcol;
  } else {
    col = 0;
  }
  wp->w_wcol = col;

  wp->w_valid |= VALID_WCOL;
}

// Compute offset of a window, occupied by absolute or relative line number,
// fold column and sign column (these don't move when scrolling horizontally).
int win_col_off(win_T *wp)
{
  return ((wp->w_p_nu || wp->w_p_rnu || *wp->w_p_stc != NUL)
          ? (number_width(wp) + (*wp->w_p_stc == NUL)) : 0)
         + ((wp != cmdwin_win) ? 0 : 1)
         + win_fdccol_count(wp) + (wp->w_scwidth * SIGN_WIDTH);
}

// Return the difference in column offset for the second screen line of a
// wrapped line.  It's positive if 'number' or 'relativenumber' is on and 'n'
// is in 'cpoptions'.
int win_col_off2(win_T *wp)
{
  if ((wp->w_p_nu || wp->w_p_rnu || *wp->w_p_stc != NUL)
      && vim_strchr(p_cpo, CPO_NUMCOL) != NULL) {
    return number_width(wp) + (*wp->w_p_stc == NUL);
  }
  return 0;
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
    int siso = get_sidescrolloff_value(wp);
    int off_left = startcol - wp->w_leftcol - siso;
    int off_right = endcol - wp->w_leftcol - wp->w_width_inner + siso + 1;
    if (off_left < 0 || off_right > 0) {
      int diff = (off_left < 0) ? -off_left : off_right;

      // When far off or not enough room on either side, put cursor in
      // middle of window.
      int new_leftcol;
      if (p_ss == 0 || diff >= width1 / 2 || off_right >= off_left) {
        new_leftcol = wp->w_wcol - extra - width1 / 2;
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
      new_leftcol = MAX(new_leftcol, 0);
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
  int so = get_scrolloff_value(wp);
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
      n = wp->w_wrow + so;
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
      wp->w_skipcol = n > 0 ? width1 + (n - 1) * width2
                            : 0;
    } else if (extra == 1) {
      // less than 'scrolloff' lines above, decrease skipcol
      assert(so <= INT_MAX);
      extra = (wp->w_skipcol + so * width2 - wp->w_virtcol + width2 - 1) / width2;
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
      wp->w_skipcol = MAX(wp->w_skipcol, endcol);
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
  colnr_T scol = 0;
  colnr_T ccol = 0;
  colnr_T ecol = 0;
  int row = 0;
  colnr_T coloff = 0;
  bool visible_row = false;
  bool is_folded = false;

  linenr_T lnum = pos->lnum;
  if (lnum >= wp->w_topline && lnum <= wp->w_botline) {
    is_folded = hasFolding(wp, lnum, &lnum, NULL);
    row = plines_m_win(wp, wp->w_topline, lnum - 1, INT_MAX);
    // "row" should be the screen line where line "lnum" begins, which can
    // be negative if "lnum" is "w_topline" and "w_skipcol" is non-zero.
    row -= adjust_plines_for_skipcol(wp);
    // Add filler lines above this buffer line.
    row += lnum == wp->w_topline ? wp->w_topfill : win_get_fill(wp, lnum);
    visible_row = true;
  } else if (!local || lnum < wp->w_topline) {
    row = 0;
  } else {
    row = wp->w_height_inner - 1;
  }

  bool existing_row = (lnum > 0 && lnum <= wp->w_buffer->b_ml.ml_line_count);

  if ((local || visible_row) && existing_row) {
    const colnr_T off = win_col_off(wp);
    if (is_folded) {
      row += (local ? 0 : wp->w_winrow + wp->w_winrow_off) + 1;
      coloff = (local ? 0 : wp->w_wincol + wp->w_wincol_off) + 1 + off;
    } else {
      assert(lnum == pos->lnum);
      getvcol(wp, pos, &scol, &ccol, &ecol);

      // similar to what is done in validate_cursor_col()
      colnr_T col = scol;
      col += off;
      int width = wp->w_width_inner - off + win_col_off2(wp);

      // long line wrapping, adjust row
      if (wp->w_p_wrap && col >= (colnr_T)wp->w_width_inner && width > 0) {
        // use same formula as what is used in curs_columns()
        int rowoff = visible_row ? ((col - wp->w_width_inner) / width + 1) : 0;
        col -= rowoff * width;
        row += rowoff;
      }

      col -= wp->w_leftcol;

      if (col >= 0 && col < wp->w_width_inner && row >= 0 && row < wp->w_height_inner) {
        coloff = col - scol + (local ? 0 : wp->w_wincol + wp->w_wincol_off) + 1;
        row += (local ? 0 : wp->w_winrow + wp->w_winrow_off) + 1;
      } else {
        // character is left, right or below of the window
        scol = ccol = ecol = 0;
        if (local) {
          coloff = col < 0 ? -1 : wp->w_width_inner + 1;
        } else {
          row = 0;
        }
      }
    }
  }
  *rowp = row;
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
    .lnum = (linenr_T)tv_get_number(&argvars[1]),
    .col = (colnr_T)tv_get_number(&argvars[2]) - 1,
    .coladd = 0
  };
  if (pos.lnum > wp->w_buffer->b_ml.ml_line_count) {
    semsg(_(e_invalid_line_number_nr), pos.lnum);
    return;
  }
  pos.col = MAX(pos.col, 0);
  int row = 0;
  int scol = 0;
  int ccol = 0;
  int ecol = 0;
  textpos2screenpos(wp, &pos, &row, &scol, &ccol, &ecol, false);

  tv_dict_add_nr(dict, S_LEN("row"), row);
  tv_dict_add_nr(dict, S_LEN("col"), scol);
  tv_dict_add_nr(dict, S_LEN("curscol"), ccol);
  tv_dict_add_nr(dict, S_LEN("endcol"), ecol);
}

/// Convert a virtual (screen) column to a character column.  The first column
/// is one.  For a multibyte character, the column number of the first byte is
/// returned.
static int virtcol2col(win_T *wp, linenr_T lnum, int vcol)
{
  int offset = vcol2col(wp, lnum, vcol - 1, NULL);
  char *line = ml_get_buf(wp->w_buffer, lnum);
  char *p = line + offset;

  if (*p == NUL) {
    if (p == line) {  // empty line
      return 0;
    }
    // Move to the first byte of the last char.
    MB_PTR_BACK(line, p);
  }
  return (int)(p - line + 1);
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

  rettv->vval.v_number = virtcol2col(wp, lnum, screencol);
}

/// Make sure the cursor is in the visible part of the topline after scrolling
/// the screen with 'smoothscroll'.
static void cursor_correct_sms(win_T *wp)
{
  if (!wp->w_p_sms || !wp->w_p_wrap || wp->w_cursor.lnum != wp->w_topline) {
    return;
  }

  int so = get_scrolloff_value(wp);
  int width1 = wp->w_width_inner - win_col_off(wp);
  int width2 = width1 + win_col_off2(wp);
  int so_cols = so == 0 ? 0 : width1 + (so - 1) * width2;
  int space_cols = (wp->w_height_inner - 1) * width2;
  int size = so == 0 ? 0 : win_linetabsize(wp, wp->w_topline,
                                           ml_get_buf(wp->w_buffer, wp->w_topline),
                                           (colnr_T)MAXCOL);

  if (wp->w_topline == 1 && wp->w_skipcol == 0) {
    so_cols = 0;               // Ignore 'scrolloff' at top of buffer.
  } else if (so_cols > space_cols / 2) {
    so_cols = space_cols / 2;  // Not enough room: put cursor in the middle.
  }

  // Not enough screen lines in topline: ignore 'scrolloff'.
  while (so_cols > size && so_cols - width2 >= width1 && width1 > 0) {
    so_cols -= width2;
  }
  if (so_cols >= width1 && so_cols > size) {
    so_cols -= width1;
  }

  // If there is no marker or we have non-zero scrolloff, just ignore it.
  int overlap = (wp->w_skipcol == 0 || so_cols != 0) ? 0 : sms_marker_overlap(wp, -1);
  int top = wp->w_skipcol + overlap + so_cols;
  int bot = wp->w_skipcol + width1 + (wp->w_height_inner - 1) * width2 - so_cols;

  validate_virtcol(wp);
  colnr_T col = wp->w_virtcol;

  if (col < top) {
    if (col < width1) {
      col += width1;
    }
    while (width2 > 0 && col < top) {
      col += width2;
    }
  } else {
    while (width2 > 0 && col >= bot) {
      col -= width2;
    }
  }

  if (col != wp->w_virtcol) {
    wp->w_curswant = col;
    coladvance(wp, wp->w_curswant);
    // validate_virtcol() marked various things as valid, but after
    // moving the cursor they need to be recomputed
    wp->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW|VALID_VIRTCOL);
  }
}

/// Scroll "count" lines up or down, and redraw.
void scroll_redraw(int up, linenr_T count)
{
  linenr_T prev_topline = curwin->w_topline;
  int prev_skipcol = curwin->w_skipcol;
  int prev_topfill = curwin->w_topfill;
  linenr_T prev_lnum = curwin->w_cursor.lnum;

  bool moved = up
               ? scrollup(curwin, count, true)
               : scrolldown(curwin, count, true);

  if (get_scrolloff_value(curwin) > 0) {
    // Adjust the cursor position for 'scrolloff'.  Mark w_topline as
    // valid, otherwise the screen jumps back at the end of the file.
    cursor_correct(curwin);
    check_cursor_moved(curwin);
    curwin->w_valid |= VALID_TOPLINE;

    // If moved back to where we were, at least move the cursor, otherwise
    // we get stuck at one position.  Don't move the cursor up if the
    // first line of the buffer is already on the screen
    while (curwin->w_topline == prev_topline
           && curwin->w_skipcol == prev_skipcol
           && curwin->w_topfill == prev_topfill) {
      if (up) {
        if (curwin->w_cursor.lnum > prev_lnum
            || cursor_down(1L, false) == FAIL) {
          break;
        }
      } else {
        if (curwin->w_cursor.lnum < prev_lnum
            || prev_topline == 1L
            || cursor_up(1L, false) == FAIL) {
          break;
        }
      }
      // Mark w_topline as valid, otherwise the screen jumps back at the
      // end of the file.
      check_cursor_moved(curwin);
      curwin->w_valid |= VALID_TOPLINE;
    }
  }

  if (moved) {
    curwin->w_viewport_invalid = true;
  }

  cursor_correct_sms(curwin);
  if (curwin->w_cursor.lnum != prev_lnum) {
    coladvance(curwin, curwin->w_curswant);
  }
  redraw_later(curwin, UPD_VALID);
}

/// Scroll a window down by "line_count" logical lines.  "CTRL-Y"
///
/// @param line_count number of lines to scroll
/// @param byfold if true, count a closed fold as one line
bool scrolldown(win_T *wp, linenr_T line_count, int byfold)
{
  int done = 0;                // total # of physical lines done
  int width1 = 0;
  int width2 = 0;
  bool do_sms = wp->w_p_wrap && wp->w_p_sms;

  if (do_sms) {
    width1 = wp->w_width_inner - win_col_off(wp);
    width2 = width1 + win_col_off2(wp);
  }

  // Make sure w_topline is at the first of a sequence of folded lines.
  hasFolding(wp, wp->w_topline, &wp->w_topline, NULL);
  validate_cursor(wp);            // w_wrow needs to be valid
  for (int todo = line_count; todo > 0; todo--) {
    if (wp->w_topfill < win_get_fill(wp, wp->w_topline)
        && wp->w_topfill < wp->w_height_inner - 1) {
      wp->w_topfill++;
      done++;
    } else {
      // break when at the very top
      if (wp->w_topline == 1 && (!do_sms || wp->w_skipcol < width1)) {
        break;
      }
      if (do_sms && wp->w_skipcol >= width1) {
        // scroll a screen line down
        if (wp->w_skipcol >= width1 + width2) {
          wp->w_skipcol -= width2;
        } else {
          wp->w_skipcol -= width1;
        }
        redraw_later(wp, UPD_NOT_VALID);
        done++;
      } else {
        // scroll a text line down
        wp->w_topline--;
        wp->w_skipcol = 0;
        wp->w_topfill = 0;
        // A sequence of folded lines only counts for one logical line
        linenr_T first;
        if (hasFolding(wp, wp->w_topline, &first, NULL)) {
          done++;
          if (!byfold) {
            todo -= wp->w_topline - first - 1;
          }
          wp->w_botline -= wp->w_topline - first;
          wp->w_topline = first;
        } else {
          if (do_sms) {
            int size = win_linetabsize(wp, wp->w_topline,
                                       ml_get_buf(wp->w_buffer, wp->w_topline), MAXCOL);
            if (size > width1) {
              wp->w_skipcol = width1;
              size -= width1;
              redraw_later(wp, UPD_NOT_VALID);
            }
            while (size > width2) {
              wp->w_skipcol += width2;
              size -= width2;
            }
            done++;
          } else {
            done += plines_win_nofill(wp, wp->w_topline, true);
          }
        }
      }
    }
    wp->w_botline--;                // approximate w_botline
    invalidate_botline(wp);
  }
  wp->w_wrow += done;               // keep w_wrow updated
  wp->w_cline_row += done;          // keep w_cline_row updated

  if (wp->w_cursor.lnum == wp->w_topline) {
    wp->w_cline_row = 0;
  }
  check_topfill(wp, true);

  // Compute the row number of the last row of the cursor line
  // and move the cursor onto the displayed part of the window.
  int wrow = wp->w_wrow;
  if (wp->w_p_wrap && wp->w_width_inner != 0) {
    validate_virtcol(wp);
    validate_cheight(wp);
    wrow += wp->w_cline_height - 1 -
            wp->w_virtcol / wp->w_width_inner;
  }
  bool moved = false;
  while (wrow >= wp->w_height_inner && wp->w_cursor.lnum > 1) {
    linenr_T first;
    if (hasFolding(wp, wp->w_cursor.lnum, &first, NULL)) {
      wrow--;
      if (first == 1) {
        wp->w_cursor.lnum = 1;
      } else {
        wp->w_cursor.lnum = first - 1;
      }
    } else {
      wrow -= plines_win(wp, wp->w_cursor.lnum--, true);
    }
    wp->w_valid &=
      ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW|VALID_VIRTCOL);
    moved = true;
  }
  if (moved) {
    // Move cursor to first line of closed fold.
    foldAdjustCursor(wp);
    coladvance(wp, wp->w_curswant);
  }
  wp->w_cursor.lnum = MAX(wp->w_cursor.lnum, wp->w_topline);

  return moved;
}

/// Scroll a window up by "line_count" logical lines.  "CTRL-E"
///
/// @param line_count number of lines to scroll
/// @param byfold if true, count a closed fold as one line
bool scrollup(win_T *wp, linenr_T line_count, bool byfold)
{
  linenr_T topline = wp->w_topline;
  linenr_T botline = wp->w_botline;
  bool do_sms = wp->w_p_wrap && wp->w_p_sms;

  if (do_sms || (byfold && hasAnyFolding(wp)) || win_may_fill(wp)) {
    int width1 = wp->w_width_inner - win_col_off(wp);
    int width2 = width1 + win_col_off2(wp);
    int size = 0;
    const colnr_T prev_skipcol = wp->w_skipcol;

    if (do_sms) {
      size = linetabsize(wp, wp->w_topline);
    }

    // diff mode: first consume "topfill"
    // 'smoothscroll': increase "w_skipcol" until it goes over the end of
    // the line, then advance to the next line.
    // folding: count each sequence of folded lines as one logical line.
    for (int todo = line_count; todo > 0; todo--) {
      if (wp->w_topfill > 0) {
        wp->w_topfill--;
      } else {
        linenr_T lnum = wp->w_topline;
        if (byfold) {
          // for a closed fold: go to the last line in the fold
          hasFolding(wp, lnum, NULL, &lnum);
        }
        if (lnum == wp->w_topline && do_sms) {
          // 'smoothscroll': increase "w_skipcol" until it goes over
          // the end of the line, then advance to the next line.
          int add = wp->w_skipcol > 0 ? width2 : width1;
          wp->w_skipcol += add;
          if (wp->w_skipcol >= size) {
            if (lnum == wp->w_buffer->b_ml.ml_line_count) {
              // at the last screen line, can't scroll further
              wp->w_skipcol -= add;
              break;
            }
            lnum++;
          }
        } else {
          if (lnum >= wp->w_buffer->b_ml.ml_line_count) {
            break;
          }
          lnum++;
        }

        if (lnum > wp->w_topline) {
          // approximate w_botline
          wp->w_botline += lnum - wp->w_topline;
          wp->w_topline = lnum;
          wp->w_topfill = win_get_fill(wp, lnum);
          wp->w_skipcol = 0;
          if (todo > 1 && do_sms) {
            size = linetabsize(wp, wp->w_topline);
          }
        }
      }
    }

    if (prev_skipcol > 0 || wp->w_skipcol > 0) {
      // need to redraw more, because wl_size of the (new) topline may
      // now be invalid
      redraw_later(wp, UPD_NOT_VALID);
    }
  } else {
    wp->w_topline += line_count;
    wp->w_botline += line_count;            // approximate w_botline
  }

  wp->w_topline = MIN(wp->w_topline, wp->w_buffer->b_ml.ml_line_count);
  wp->w_botline = MIN(wp->w_botline, wp->w_buffer->b_ml.ml_line_count + 1);

  check_topfill(wp, false);

  if (hasAnyFolding(wp)) {
    // Make sure w_topline is at the first of a sequence of folded lines.
    hasFolding(wp, wp->w_topline, &wp->w_topline, NULL);
  }

  wp->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE);
  if (wp->w_cursor.lnum < wp->w_topline) {
    wp->w_cursor.lnum = wp->w_topline;
    wp->w_valid &=
      ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW|VALID_VIRTCOL);
    coladvance(wp, wp->w_curswant);
  }

  bool moved = topline != wp->w_topline || botline != wp->w_botline;

  return moved;
}

/// Called after changing the cursor column: make sure that curwin->w_skipcol is
/// valid for 'smoothscroll'.
void adjust_skipcol(void)
{
  if (!curwin->w_p_wrap || !curwin->w_p_sms || curwin->w_cursor.lnum != curwin->w_topline) {
    return;
  }

  int width1 = curwin->w_width_inner - win_col_off(curwin);
  if (width1 <= 0) {
    return;  // no text will be displayed
  }
  int width2 = width1 + win_col_off2(curwin);
  int so = get_scrolloff_value(curwin);
  colnr_T scrolloff_cols = so == 0 ? 0 : width1 + (so - 1) * width2;
  bool scrolled = false;

  validate_cheight(curwin);
  if (curwin->w_cline_height == curwin->w_height_inner
      // w_cline_height may be capped at w_height_inner, check there aren't
      // actually more lines.
      && plines_win(curwin, curwin->w_cursor.lnum, false) <= curwin->w_height_inner) {
    // the line just fits in the window, don't scroll
    reset_skipcol(curwin);
    return;
  }

  validate_virtcol(curwin);
  int overlap = sms_marker_overlap(curwin, -1);
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
    validate_virtcol(curwin);
    redraw_later(curwin, UPD_NOT_VALID);
    return;  // don't scroll in the other direction now
  }
  int row = 0;
  colnr_T col = curwin->w_virtcol + scrolloff_cols;

  // Avoid adjusting for 'scrolloff' beyond the text line height.
  if (scrolloff_cols > 0) {
    int size = win_linetabsize(curwin, curwin->w_topline,
                               ml_get(curwin->w_topline), (colnr_T)MAXCOL);
    size = width1 + width2 * ((size - width1 + width2 - 1) / width2);
    while (col > size) {
      col -= width2;
    }
  }
  col -= curwin->w_skipcol;

  if (col >= width1) {
    col -= width1;
    row++;
  }
  if (col > width2) {
    row += (int)col / width2;
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
        wp->w_topfill = MAX(wp->w_topfill, 0);
      }
    }
  }
  win_check_anchored_floats(wp);
}

// Scroll the screen one line down, but don't do it if it would move the
// cursor off the screen.
void scrolldown_clamp(void)
{
  bool can_fill = (curwin->w_topfill < win_get_fill(curwin, curwin->w_topline));

  if (curwin->w_topline <= 1
      && !can_fill) {
    return;
  }

  validate_cursor(curwin);        // w_wrow needs to be valid

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
    validate_cheight(curwin);
    validate_virtcol(curwin);
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
    hasFolding(curwin, curwin->w_topline, &curwin->w_topline, NULL);
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

  validate_cursor(curwin);        // w_wrow needs to be valid

  // Compute the row number of the first row of the cursor line
  // and make sure it doesn't go off the screen. Make sure the cursor
  // doesn't go before 'scrolloff' lines from the screen start.
  int start_row = (curwin->w_wrow
                   - plines_win_nofill(curwin, curwin->w_topline, true)
                   - curwin->w_topfill);
  if (curwin->w_p_wrap && curwin->w_width_inner != 0) {
    validate_virtcol(curwin);
    start_row -= curwin->w_virtcol / curwin->w_width_inner;
  }
  if (start_row >= get_scrolloff_value(curwin)) {
    if (curwin->w_topfill > 0) {
      curwin->w_topfill--;
    } else {
      hasFolding(curwin, curwin->w_topline, NULL, &curwin->w_topline);
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
    } else if (hasFolding(wp, lp->lnum, &lp->lnum, NULL)) {
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
    } else if (hasFolding(wp, lp->lnum, NULL, &lp->lnum)) {
      // Add a closed fold
      lp->height = 1;
    } else {
      lp->height = plines_win_nofill(wp, lp->lnum, true);
    }
  }
}

// Recompute topline to put the cursor at the top of the window.
// Scroll at least "min_scroll" lines.
// If "always" is true, always set topline (for "zt").
void scroll_cursor_top(win_T *wp, int min_scroll, int always)
{
  linenr_T old_topline = wp->w_topline;
  int old_skipcol = wp->w_skipcol;
  linenr_T old_topfill = wp->w_topfill;
  int off = get_scrolloff_value(wp);

  if (mouse_dragging > 0) {
    off = mouse_dragging - 1;
  }

  // Decrease topline until:
  // - it has become 1
  // - (part of) the cursor line is moved off the screen or
  // - moved at least 'scrolljump' lines and
  // - at least 'scrolloff' lines above and below the cursor
  validate_cheight(wp);
  int scrolled = 0;
  int used = wp->w_cline_height;  // includes filler lines above
  if (wp->w_cursor.lnum < wp->w_topline) {
    scrolled = used;
  }

  linenr_T top;  // just above displayed lines
  linenr_T bot;  // just below displayed lines
  if (hasFolding(wp, wp->w_cursor.lnum, &top, &bot)) {
    top--;
    bot++;
  } else {
    top = wp->w_cursor.lnum - 1;
    bot = wp->w_cursor.lnum + 1;
  }
  linenr_T new_topline = top + 1;

  // "used" already contains the number of filler lines above, don't add it
  // again.
  // Hide filler lines above cursor line by adding them to "extra".
  int extra = win_get_fill(wp, wp->w_cursor.lnum);

  // Check if the lines from "top" to "bot" fit in the window.  If they do,
  // set new_topline and advance "top" and "bot" to include more lines.
  while (top > 0) {
    int i = hasFolding(wp, top, &top, NULL)
            ? 1  // count one logical line for a sequence of folded lines
            : plines_win_nofill(wp, top, true);
    if (top < wp->w_topline) {
      scrolled += i;
    }

    // If scrolling is needed, scroll at least 'sj' lines.
    if ((new_topline >= wp->w_topline || scrolled > min_scroll) && extra >= off) {
      break;
    }

    used += i;
    if (extra + i <= off && bot < wp->w_buffer->b_ml.ml_line_count) {
      if (hasFolding(wp, bot, NULL, &bot)) {
        // count one logical line for a sequence of folded lines
        used++;
      } else {
        used += plines_win(wp, bot, true);
      }
    }
    if (used > wp->w_height_inner) {
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
  if (used > wp->w_height_inner) {
    scroll_cursor_halfway(wp, false, false);
  } else {
    // If "always" is false, only adjust topline to a lower value, higher
    // value may happen with wrapping lines.
    if (new_topline < wp->w_topline || always) {
      wp->w_topline = new_topline;
    }
    wp->w_topline = MIN(wp->w_topline, wp->w_cursor.lnum);
    wp->w_topfill = win_get_fill(wp, wp->w_topline);
    if (wp->w_topfill > 0 && extra > off) {
      wp->w_topfill -= extra - off;
      wp->w_topfill = MAX(wp->w_topfill, 0);
    }
    check_topfill(wp, false);
    if (wp->w_topline != old_topline) {
      reset_skipcol(wp);
    } else if (wp->w_topline == wp->w_cursor.lnum) {
      validate_virtcol(wp);
      if (wp->w_skipcol >= wp->w_virtcol) {
        // TODO(vim): if the line doesn't fit may optimize w_skipcol instead
        // of making it zero
        reset_skipcol(wp);
      }
    }
    if (wp->w_topline != old_topline
        || wp->w_skipcol != old_skipcol
        || wp->w_topfill != old_topfill) {
      wp->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
    }
    wp->w_valid |= VALID_TOPLINE;
    wp->w_viewport_invalid = true;
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
void scroll_cursor_bot(win_T *wp, int min_scroll, bool set_topbot)
{
  lineoff_T loff;
  linenr_T old_topline = wp->w_topline;
  int old_skipcol = wp->w_skipcol;
  int old_topfill = wp->w_topfill;
  linenr_T old_botline = wp->w_botline;
  int old_valid = wp->w_valid;
  int old_empty_rows = wp->w_empty_rows;
  linenr_T cln = wp->w_cursor.lnum;  // Cursor Line Number
  bool do_sms = wp->w_p_wrap && wp->w_p_sms;

  if (set_topbot) {
    int used = 0;
    wp->w_botline = cln + 1;
    loff.lnum = cln + 1;
    loff.fill = 0;
    while (true) {
      topline_back_winheight(wp, &loff, false);
      if (loff.height == MAXCOL) {
        break;
      }
      if (used + loff.height > wp->w_height_inner) {
        if (do_sms) {
          // 'smoothscroll' and 'wrap' are set.  The above line is
          // too long to show in its entirety, so we show just a part
          // of it.
          if (used < wp->w_height_inner) {
            int plines_offset = used + loff.height - wp->w_height_inner;
            used = wp->w_height_inner;
            wp->w_topfill = loff.fill;
            wp->w_topline = loff.lnum;
            wp->w_skipcol = skipcol_from_plines(wp, plines_offset);
          }
        }
        break;
      }
      wp->w_topfill = loff.fill;
      wp->w_topline = loff.lnum;
      used += loff.height;
    }

    set_empty_rows(wp, used);
    wp->w_valid |= VALID_BOTLINE|VALID_BOTLINE_AP;
    if (wp->w_topline != old_topline
        || wp->w_topfill != old_topfill
        || wp->w_skipcol != old_skipcol
        || wp->w_skipcol != 0) {
      wp->w_valid &= ~(VALID_WROW|VALID_CROW);
      if (wp->w_skipcol != old_skipcol) {
        redraw_later(wp, UPD_NOT_VALID);
      } else {
        reset_skipcol(wp);
      }
    }
  } else {
    validate_botline(wp);
  }

  // The lines of the cursor line itself are always used.
  int used = plines_win_nofill(wp, cln, true);

  int scrolled = 0;
  // If the cursor is on or below botline, we will at least scroll by the
  // height of the cursor line, which is "used".  Correct for empty lines,
  // which are really part of botline.
  if (cln >= wp->w_botline) {
    scrolled = used;
    if (cln == wp->w_botline) {
      scrolled -= wp->w_empty_rows;
    }
    if (do_sms) {
      // 'smoothscroll' and 'wrap' are set.
      // Calculate how many screen lines the current top line of window
      // occupies. If it is occupying more than the entire window, we
      // need to scroll the additional clipped lines to scroll past the
      // top line before we can move on to the other lines.
      int top_plines = plines_win_nofill(wp, wp->w_topline, false);
      int width1 = wp->w_width_inner - win_col_off(wp);

      if (width1 > 0) {
        int width2 = width1 + win_col_off2(wp);
        int skip_lines = 0;

        // A similar formula is used in curs_columns().
        if (wp->w_skipcol > width1) {
          skip_lines += (wp->w_skipcol - width1) / width2 + 1;
        } else if (wp->w_skipcol > 0) {
          skip_lines = 1;
        }

        top_plines -= skip_lines;
        if (top_plines > wp->w_height_inner) {
          scrolled += (top_plines - wp->w_height_inner);
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
  if (!hasFolding(wp, wp->w_cursor.lnum, &loff.lnum, &boff.lnum)) {
    loff.lnum = cln;
    boff.lnum = cln;
  }
  loff.fill = 0;
  boff.fill = 0;
  int fill_below_window = win_get_fill(wp, wp->w_botline) - wp->w_filler_rows;

  int extra = 0;
  int so = get_scrolloff_value(wp);
  while (loff.lnum > 1) {
    // Stop when scrolled nothing or at least "min_scroll", found "extra"
    // context for 'scrolloff' and counted all lines below the window.
    if ((((scrolled <= 0 || scrolled >= min_scroll)
          && extra >= (mouse_dragging > 0 ? mouse_dragging - 1 : so))
         || boff.lnum + 1 > wp->w_buffer->b_ml.ml_line_count)
        && loff.lnum <= wp->w_botline
        && (loff.lnum < wp->w_botline
            || loff.fill >= fill_below_window)) {
      break;
    }

    // Add one line above
    topline_back(wp, &loff);
    if (loff.height == MAXCOL) {
      used = MAXCOL;
    } else {
      used += loff.height;
    }
    if (used > wp->w_height_inner) {
      break;
    }
    if (loff.lnum >= wp->w_botline
        && (loff.lnum > wp->w_botline
            || loff.fill <= fill_below_window)) {
      // Count screen lines that are below the window.
      scrolled += loff.height;
      if (loff.lnum == wp->w_botline
          && loff.fill == 0) {
        scrolled -= wp->w_empty_rows;
      }
    }

    if (boff.lnum < wp->w_buffer->b_ml.ml_line_count) {
      // Add one line below
      botline_forw(wp, &boff);
      used += boff.height;
      if (used > wp->w_height_inner) {
        break;
      }
      if (extra < (mouse_dragging > 0 ? mouse_dragging - 1 : so)
          || scrolled < min_scroll) {
        extra += boff.height;
        if (boff.lnum >= wp->w_botline
            || (boff.lnum + 1 == wp->w_botline
                && boff.fill > wp->w_filler_rows)) {
          // Count screen lines that are below the window.
          scrolled += boff.height;
          if (boff.lnum == wp->w_botline
              && boff.fill == 0) {
            scrolled -= wp->w_empty_rows;
          }
        }
      }
    }
  }

  linenr_T line_count;
  // wp->w_empty_rows is larger, no need to scroll
  if (scrolled <= 0) {
    line_count = 0;
    // more than a screenfull, don't scroll but redraw
  } else if (used > wp->w_height_inner) {
    line_count = used;
    // scroll minimal number of lines
  } else {
    line_count = 0;
    boff.fill = wp->w_topfill;
    boff.lnum = wp->w_topline - 1;
    int i;
    for (i = 0; i < scrolled && boff.lnum < wp->w_botline;) {
      botline_forw(wp, &boff);
      i += boff.height;
      line_count++;
    }
    if (i < scrolled) {         // below wp->w_botline, don't scroll
      line_count = 9999;
    }
  }

  // Scroll up if the cursor is off the bottom of the screen a bit.
  // Otherwise put it at 1/2 of the screen.
  if (line_count >= wp->w_height_inner && line_count > min_scroll) {
    scroll_cursor_halfway(wp, false, true);
  } else if (line_count > 0) {
    if (do_sms) {
      scrollup(wp, scrolled, true);  // TODO(vim):
    } else {
      scrollup(wp, line_count, true);
    }
  }

  // If topline didn't change we need to restore w_botline and w_empty_rows
  // (we changed them).
  // If topline did change, update_screen() will set botline.
  if (wp->w_topline == old_topline && wp->w_skipcol == old_skipcol && set_topbot) {
    wp->w_botline = old_botline;
    wp->w_empty_rows = old_empty_rows;
    wp->w_valid = old_valid;
  }
  wp->w_valid |= VALID_TOPLINE;
  wp->w_viewport_invalid = true;

  // Make sure cursor is still visible after adjusting skipcol for "zb".
  if (set_topbot) {
    cursor_correct_sms(wp);
  }
}

/// Recompute topline to put the cursor halfway across the window
///
/// @param atend if true, also put the cursor halfway to the end of the file.
///
void scroll_cursor_halfway(win_T *wp, bool atend, bool prefer_above)
{
  linenr_T old_topline = wp->w_topline;
  lineoff_T loff = { .lnum = wp->w_cursor.lnum };
  lineoff_T boff = { .lnum = wp->w_cursor.lnum };
  hasFolding(wp, loff.lnum, &loff.lnum, &boff.lnum);
  int used = plines_win_nofill(wp, loff.lnum, true);
  loff.fill = 0;
  boff.fill = 0;
  linenr_T topline = loff.lnum;
  colnr_T skipcol = 0;

  int want_height;
  bool do_sms = wp->w_p_wrap && wp->w_p_sms;
  if (do_sms) {
    // 'smoothscroll' and 'wrap' are set
    if (atend) {
      want_height = (wp->w_height_inner - used) / 2;
      used = 0;
    } else {
      want_height = wp->w_height_inner;
    }
  }

  int topfill = 0;
  while (topline > 1) {
    // If using smoothscroll, we can precisely scroll to the
    // exact point where the cursor is halfway down the screen.
    if (do_sms) {
      topline_back_winheight(wp, &loff, false);
      if (loff.height == MAXCOL) {
        break;
      }
      used += loff.height;
      if (!atend && boff.lnum < wp->w_buffer->b_ml.ml_line_count) {
        botline_forw(wp, &boff);
        used += boff.height;
      }
      if (used > want_height) {
        if (used - loff.height < want_height) {
          topline = loff.lnum;
          topfill = loff.fill;
          skipcol = skipcol_from_plines(wp, used - want_height);
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
        if (boff.lnum < wp->w_buffer->b_ml.ml_line_count) {
          botline_forw(wp, &boff);
          used += boff.height;
          if (used > wp->w_height_inner) {
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
        topline_back(wp, &loff);
        if (loff.height == MAXCOL) {
          used = MAXCOL;
        } else {
          used += loff.height;
        }
        if (used > wp->w_height_inner) {
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

  if (!hasFolding(wp, topline, &wp->w_topline, NULL)
      && (wp->w_topline != topline || skipcol != 0 || wp->w_skipcol != 0)) {
    wp->w_topline = topline;
    if (skipcol != 0) {
      wp->w_skipcol = skipcol;
      redraw_later(wp, UPD_NOT_VALID);
    } else if (do_sms) {
      reset_skipcol(wp);
    }
  }
  wp->w_topfill = topfill;
  if (old_topline > wp->w_topline + wp->w_height_inner) {
    wp->w_botfill = false;
  }
  check_topfill(wp, false);
  wp->w_valid &= ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
  wp->w_valid |= VALID_TOPLINE;
}

// Correct the cursor position so that it is in a part of the screen at least
// 'so' lines from the top and bottom, if possible.
// If not possible, put it at the same position as scroll_cursor_halfway().
// When called topline must be valid!
void cursor_correct(win_T *wp)
{
  // How many lines we would like to have above/below the cursor depends on
  // whether the first/last line of the file is on screen.
  int above_wanted = get_scrolloff_value(wp);
  int below_wanted = get_scrolloff_value(wp);
  if (mouse_dragging > 0) {
    above_wanted = mouse_dragging - 1;
    below_wanted = mouse_dragging - 1;
  }
  if (wp->w_topline == 1) {
    above_wanted = 0;
    int max_off = wp->w_height_inner / 2;
    below_wanted = MIN(below_wanted, max_off);
  }
  validate_botline(wp);
  if (wp->w_botline == wp->w_buffer->b_ml.ml_line_count + 1
      && mouse_dragging == 0) {
    below_wanted = 0;
    int max_off = (wp->w_height_inner - 1) / 2;
    above_wanted = MIN(above_wanted, max_off);
  }

  // If there are sufficient file-lines above and below the cursor, we can
  // return now.
  linenr_T cln = wp->w_cursor.lnum;  // Cursor Line Number
  if (cln >= wp->w_topline + above_wanted
      && cln < wp->w_botline - below_wanted
      && !hasAnyFolding(wp)) {
    return;
  }

  if (wp->w_p_sms && !wp->w_p_wrap) {
    // 'smoothscroll' is active
    if (wp->w_cline_height == wp->w_height_inner) {
      // The cursor line just fits in the window, don't scroll.
      reset_skipcol(wp);
      return;
    }
    // TODO(vim): If the cursor line doesn't fit in the window then only adjust w_skipcol.
  }

  // Narrow down the area where the cursor can be put by taking lines from
  // the top and the bottom until:
  // - the desired context lines are found
  // - the lines from the top is past the lines from the bottom
  linenr_T topline = wp->w_topline;
  linenr_T botline = wp->w_botline - 1;
  // count filler lines as context
  int above = wp->w_topfill;  // screen lines above topline
  int below = wp->w_filler_rows;  // screen lines below botline
  while ((above < above_wanted || below < below_wanted) && topline < botline) {
    if (below < below_wanted && (below <= above || above >= above_wanted)) {
      if (hasFolding(wp, botline, &botline, NULL)) {
        below++;
      } else {
        below += plines_win(wp, botline, true);
      }
      botline--;
    }
    if (above < above_wanted && (above < below || below >= below_wanted)) {
      if (hasFolding(wp, topline, NULL, &topline)) {
        above++;
      } else {
        above += plines_win_nofill(wp, topline, true);
      }

      // Count filler lines below this line as context.
      if (topline < botline) {
        above += win_get_fill(wp, topline + 1);
      }
      topline++;
    }
  }
  if (topline == botline || botline == 0) {
    wp->w_cursor.lnum = topline;
  } else if (topline > botline) {
    wp->w_cursor.lnum = botline;
  } else {
    if (cln < topline && wp->w_topline > 1) {
      wp->w_cursor.lnum = topline;
      wp->w_valid &=
        ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW);
    }
    if (cln > botline && wp->w_botline <= wp->w_buffer->b_ml.ml_line_count) {
      wp->w_cursor.lnum = botline;
      wp->w_valid &=
        ~(VALID_WROW|VALID_WCOL|VALID_CHEIGHT|VALID_CROW);
    }
  }
  wp->w_valid |= VALID_TOPLINE;
  wp->w_viewport_invalid = true;
}

/// Decide how much overlap to use for page-up or page-down scrolling.
/// This is symmetric, so that doing both keeps the same lines displayed.
/// Three lines are examined:
///
///  before CTRL-F          after CTRL-F / before CTRL-B
///     etc.                    l1
///  l1 last but one line       ------------
///  l2 last text line          l2 top text line
///  -------------              l3 second text line
///  l3                            etc.
static int get_scroll_overlap(Direction dir)
{
  lineoff_T loff;
  int min_height = curwin->w_height_inner - 2;

  validate_botline(curwin);
  if ((dir == BACKWARD && curwin->w_topline == 1)
      || (dir == FORWARD && curwin->w_botline > curbuf->b_ml.ml_line_count)) {
    return min_height + 2;  // no overlap, still handle 'smoothscroll'
  }

  loff.lnum = dir == FORWARD ? curwin->w_botline : curwin->w_topline - 1;
  loff.fill = win_get_fill(curwin, loff.lnum + (dir == BACKWARD))
              - (dir == FORWARD ? curwin->w_filler_rows : curwin->w_topfill);
  loff.height = loff.fill > 0 ? 1 : plines_win_nofill(curwin, loff.lnum, true);

  int h1 = loff.height;
  if (h1 > min_height) {
    return min_height + 2;  // no overlap
  }
  if (dir == FORWARD) {
    topline_back(curwin, &loff);
  } else {
    botline_forw(curwin, &loff);
  }

  int h2 = loff.height;
  if (h2 == MAXCOL || h2 + h1 > min_height) {
    return min_height + 2;  // no overlap
  }
  if (dir == FORWARD) {
    topline_back(curwin, &loff);
  } else {
    botline_forw(curwin, &loff);
  }

  int h3 = loff.height;
  if (h3 == MAXCOL || h3 + h2 > min_height) {
    return min_height + 2;  // no overlap
  }
  if (dir == FORWARD) {
    topline_back(curwin, &loff);
  } else {
    botline_forw(curwin, &loff);
  }

  int h4 = loff.height;
  if (h4 == MAXCOL || h4 + h3 + h2 > min_height || h3 + h2 + h1 > min_height) {
    return min_height + 1;  // 1 line overlap
  } else {
    return min_height;      // 2 lines overlap
  }
}

/// Scroll "count" lines with 'smoothscroll' in direction "dir". Return true
/// when scrolling happened. Adjust "curscount" for scrolling different amount
/// of lines when 'smoothscroll' is disabled.
static bool scroll_with_sms(Direction dir, int count, int *curscount)
{
  int prev_sms = curwin->w_p_sms;
  colnr_T prev_skipcol = curwin->w_skipcol;
  linenr_T prev_topline = curwin->w_topline;
  int prev_topfill = curwin->w_topfill;

  curwin->w_p_sms = true;
  scroll_redraw(dir == FORWARD, count);

  // Not actually smoothscrolling but ended up with partially visible line.
  // Continue scrolling until skipcol is zero.
  if (!prev_sms && curwin->w_skipcol > 0) {
    int fixdir = dir;
    // Reverse the scroll direction when topline already changed. One line
    // extra for scrolling backward so that consuming skipcol is symmetric.
    if (labs(curwin->w_topline - prev_topline) > (dir == BACKWARD)) {
      fixdir = dir * -1;
    }
    while (curwin->w_skipcol > 0
           && curwin->w_topline < curbuf->b_ml.ml_line_count) {
      scroll_redraw(fixdir == FORWARD, 1);
      *curscount += (fixdir == dir ? 1 : -1);
    }
  }
  curwin->w_p_sms = prev_sms;

  return curwin->w_topline == prev_topline
         && curwin->w_topfill == prev_topfill
         && curwin->w_skipcol == prev_skipcol;
}

/// Move screen "count" (half) pages up ("dir" is BACKWARD) or down ("dir" is
/// FORWARD) and update the screen. Handle moving the cursor and not scrolling
/// to reveal end of buffer lines for half-page scrolling with CTRL-D and CTRL-U.
///
/// @return  FAIL for failure, OK otherwise.
int pagescroll(Direction dir, int count, bool half)
{
  int nochange = true;
  int buflen = curbuf->b_ml.ml_line_count;
  colnr_T prev_col = curwin->w_cursor.col;
  colnr_T prev_curswant = curwin->w_curswant;
  linenr_T prev_lnum = curwin->w_cursor.lnum;
  oparg_T oa = { 0 };
  cmdarg_T ca = { 0 };
  ca.oap = &oa;

  if (half) {
    // Scroll [count], 'scroll' or current window height lines.
    if (count) {
      curwin->w_p_scr = MIN(curwin->w_height_inner, count);
    }
    count = MIN(curwin->w_height_inner, (int)curwin->w_p_scr);

    int curscount = count;
    // Adjust count so as to not reveal end of buffer lines.
    if (dir == FORWARD
        && (curwin->w_topline + curwin->w_height_inner + count > buflen || hasAnyFolding(curwin))) {
      int n = plines_correct_topline(curwin, curwin->w_topline, NULL, false, NULL);
      if (n - count < curwin->w_height_inner && curwin->w_topline < buflen) {
        n += plines_m_win(curwin, curwin->w_topline + 1, buflen, curwin->w_height_inner + count);
      }
      if (n < curwin->w_height_inner + count) {
        count = n - curwin->w_height_inner;
      }
    }

    // (Try to) scroll the window unless already at the end of the buffer.
    if (count > 0) {
      nochange = scroll_with_sms(dir, count, &curscount);
      curwin->w_cursor.lnum = prev_lnum;
      curwin->w_cursor.col = prev_col;
      curwin->w_curswant = prev_curswant;
    }

    // Move the cursor the same amount of screen lines.
    if (curwin->w_p_wrap) {
      nv_screengo(&oa, dir, curscount);
    } else if (dir == FORWARD) {
      cursor_down_inner(curwin, curscount);
    } else {
      cursor_up_inner(curwin, curscount);
    }
  } else {
    // Scroll [count] times 'window' or current window height lines.
    count *= ((ONE_WINDOW && p_window > 0 && p_window < Rows - 1)
              ? MAX(1, (int)p_window - 2) : get_scroll_overlap(dir));
    nochange = scroll_with_sms(dir, count, &count);

    if (!nochange) {
      // Place cursor at top or bottom of window.
      validate_botline(curwin);
      linenr_T lnum = (dir == FORWARD ? curwin->w_topline : curwin->w_botline - 1);
      // In silent Ex mode the value of w_botline - 1 may be 0,
      // but cursor lnum needs to be at least 1.
      curwin->w_cursor.lnum = MAX(lnum, 1);
    }
  }

  if (get_scrolloff_value(curwin) > 0) {
    cursor_correct(curwin);
  }
  // Move cursor to first line of closed fold.
  foldAdjustCursor(curwin);

  nochange = nochange
             && prev_col == curwin->w_cursor.col
             && prev_lnum == curwin->w_cursor.lnum;

  // Error if both the viewport and cursor did not change.
  if (nochange) {
    beep_flush();
  } else if (!curwin->w_p_sms) {
    beginline(BL_SOL | BL_FIX);
  } else if (p_sol) {
    nv_g_home_m_cmd(&ca);
  }

  return nochange;
}

void do_check_cursorbind(void)
{
  static win_T *prev_curwin = NULL;
  static pos_T prev_cursor = { 0, 0, 0 };

  if (curwin == prev_curwin && equalpos(curwin->w_cursor, prev_cursor)) {
    return;
  }
  prev_curwin = curwin;
  prev_cursor = curwin->w_cursor;

  linenr_T line = curwin->w_cursor.lnum;
  colnr_T col = curwin->w_cursor.col;
  colnr_T coladd = curwin->w_cursor.coladd;
  colnr_T curswant = curwin->w_curswant;
  bool set_curswant = curwin->w_set_curswant;
  win_T *old_curwin = curwin;
  buf_T *old_curbuf = curbuf;
  int old_VIsual_select = VIsual_select;
  int old_VIsual_active = VIsual_active;

  // loop through the cursorbound windows
  VIsual_select = VIsual_active = false;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    curwin = wp;
    curbuf = curwin->w_buffer;
    // skip original window and windows with 'nocursorbind'
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
        check_cursor(curwin);

        // Avoid a scroll here for the cursor position, 'scrollbind' is
        // more important.
        if (!curwin->w_p_scb) {
          validate_cursor(curwin);
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
