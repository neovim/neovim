// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// screen.c: code for displaying on the screen
//
// Output to the screen (console, terminal emulator or GUI window) is minimized
// by remembering what is already on the screen, and only updating the parts
// that changed.
//
// The grid_*() functions write to the screen and handle updating grid->lines[].
//
// update_screen() is the function that updates all windows and status lines.
// It is called from the main loop when must_redraw is non-zero.  It may be
// called from other places when an immediate screen update is needed.
//
// The part of the buffer that is displayed in a window is set with:
// - w_topline (first buffer line in window)
// - w_topfill (filler lines above the first line)
// - w_leftcol (leftmost window cell in window),
// - w_skipcol (skipped window cells of first line)
//
// Commands that only move the cursor around in a window, do not need to take
// action to update the display.  The main loop will check if w_topline is
// valid and update it (scroll the window) when needed.
//
// Commands that scroll a window change w_topline and must call
// check_cursor() to move the cursor into the visible part of the window, and
// call redraw_later(VALID) to have the window displayed by update_screen()
// later.
//
// Commands that change text in the buffer must call changed_bytes() or
// changed_lines() to mark the area that changed and will require updating
// later.  The main loop will call update_screen(), which will update each
// window that shows the changed buffer.  This assumes text above the change
// can remain displayed as it is.  Text after the change may need updating for
// scrolling, folding and syntax highlighting.
//
// Commands that change how a window is displayed (e.g., setting 'list') or
// invalidate the contents of a window in another way (e.g., change fold
// settings), must call redraw_later(NOT_VALID) to have the whole window
// redisplayed by update_screen() later.
//
// Commands that change how a buffer is displayed (e.g., setting 'tabstop')
// must call redraw_curbuf_later(NOT_VALID) to have all the windows for the
// buffer redisplayed by update_screen() later.
//
// Commands that change highlighting and possibly cause a scroll too must call
// redraw_later(SOME_VALID) to update the whole window but still use scrolling
// to avoid redrawing everything.  But the length of displayed lines must not
// change, use NOT_VALID then.
//
// Commands that move the window position must call redraw_later(NOT_VALID).
// TODO(neovim): should minimize redrawing by scrolling when possible.
//
// Commands that change everything (e.g., resizing the screen) must call
// redraw_all_later(NOT_VALID) or redraw_all_later(CLEAR).
//
// Things that are handled indirectly:
// - When messages scroll the screen up, msg_scrolled will be set and
//   update_screen() called to redraw.
///

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/log.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/arabic.h"
#include "nvim/screen.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/cursor_shape.h"
#include "nvim/diff.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_getln.h"
#include "nvim/edit.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/indent.h"
#include "nvim/getchar.h"
#include "nvim/highlight.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/popupmnu.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/sign.h"
#include "nvim/spell.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/undo.h"
#include "nvim/version.h"
#include "nvim/window.h"
#include "nvim/os/time.h"
#include "nvim/api/private/helpers.h"

#define MB_FILLER_CHAR '<'  /* character used when a double-width character
                             * doesn't fit. */
#define W_ENDCOL(wp)   (wp->w_wincol + wp->w_width)
#define W_ENDROW(wp)   (wp->w_winrow + wp->w_height)


// temporary buffer for rendering a single screenline, so it can be
// comparared with previous contents to calulate smallest delta.
static size_t linebuf_size = 0;
static schar_T *linebuf_char = NULL;
static sattr_T *linebuf_attr = NULL;

static match_T search_hl;       /* used for 'hlsearch' highlight matching */

static foldinfo_T win_foldinfo; /* info for 'foldcolumn' */

StlClickDefinition *tab_page_click_defs = NULL;

long tab_page_click_defs_size = 0;

// for line_putchar. Contains the state that needs to be remembered from
// putting one character to the next.
typedef struct {
  const char_u *p;
  int prev_c;  // previous Arabic character
  int prev_c1;  // first composing char for prev_c
} LineState;
#define LINE_STATE(p) { p, 0, 0 }

/// Whether to call "ui_call_grid_resize" in win_grid_alloc
static bool send_grid_resize = false;

static bool conceal_cursor_used = false;

static bool redraw_popupmenu = false;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "screen.c.generated.h"
#endif
#define SEARCH_HL_PRIORITY 0

/*
 * Redraw the current window later, with update_screen(type).
 * Set must_redraw only if not already set to a higher value.
 * e.g. if must_redraw is CLEAR, type NOT_VALID will do nothing.
 */
void redraw_later(int type)
{
  redraw_win_later(curwin, type);
}

void redraw_win_later(win_T *wp, int type)
{
  if (!exiting && wp->w_redr_type < type) {
    wp->w_redr_type = type;
    if (type >= NOT_VALID)
      wp->w_lines_valid = 0;
    if (must_redraw < type)     /* must_redraw is the maximum of all windows */
      must_redraw = type;
  }
}

/*
 * Mark all windows to be redrawn later.
 */
void redraw_all_later(int type)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    redraw_win_later(wp, type);
  }
  // This may be needed when switching tabs.
  if (must_redraw < type) {
    must_redraw = type;
  }
}

void screen_invalidate_highlights(void)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    redraw_win_later(wp, NOT_VALID);
    wp->w_grid.valid = false;
  }
}

/*
 * Mark all windows that are editing the current buffer to be updated later.
 */
void redraw_curbuf_later(int type)
{
  redraw_buf_later(curbuf, type);
}

void redraw_buf_later(buf_T *buf, int type)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf) {
      redraw_win_later(wp, type);
    }
  }
}

void redraw_buf_line_later(buf_T *buf,  linenr_T line)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf
        && line >= wp->w_topline && line < wp->w_botline) {
      redrawWinline(wp, line);
    }
  }
}

/*
 * Changed something in the current window, at buffer line "lnum", that
 * requires that line and possibly other lines to be redrawn.
 * Used when entering/leaving Insert mode with the cursor on a folded line.
 * Used to remove the "$" from a change command.
 * Note that when also inserting/deleting lines w_redraw_top and w_redraw_bot
 * may become invalid and the whole window will have to be redrawn.
 */
void
redrawWinline(
    win_T *wp,
    linenr_T lnum
)
{
  if (lnum >= wp->w_topline
      && lnum < wp->w_botline) {
    if (wp->w_redraw_top == 0 || wp->w_redraw_top > lnum) {
        wp->w_redraw_top = lnum;
    }
    if (wp->w_redraw_bot == 0 || wp->w_redraw_bot < lnum) {
        wp->w_redraw_bot = lnum;
    }
    redraw_win_later(wp, VALID);
  }
}

/*
 * update all windows that are editing the current buffer
 */
void update_curbuf(int type)
{
  redraw_curbuf_later(type);
  update_screen(type);
}

/// Redraw the parts of the screen that is marked for redraw.
///
/// Most code shouldn't call this directly, rather use redraw_later() and
/// and redraw_all_later() to mark parts of the screen as needing a redraw.
///
/// @param type set to a NOT_VALID to force redraw of entire screen
void update_screen(int type)
{
  static int did_intro = FALSE;
  int did_one;

  // Don't do anything if the screen structures are (not yet) valid.
  if (!default_grid.chars) {
    return;
  }

  if (must_redraw) {
    if (type < must_redraw)         /* use maximal type */
      type = must_redraw;

    /* must_redraw is reset here, so that when we run into some weird
    * reason to redraw while busy redrawing (e.g., asynchronous
    * scrolling), or update_topline() in win_update() will cause a
    * scroll, the screen will be redrawn later or in win_update(). */
    must_redraw = 0;
  }

  /* Need to update w_lines[]. */
  if (curwin->w_lines_valid == 0 && type < NOT_VALID)
    type = NOT_VALID;

  /* Postpone the redrawing when it's not needed and when being called
   * recursively. */
  if (!redrawing() || updating_screen) {
    redraw_later(type);                 /* remember type for next time */
    must_redraw = type;
    if (type > INVERTED_ALL)
      curwin->w_lines_valid = 0;        /* don't use w_lines[].wl_size now */
    return;
  }

  updating_screen = TRUE;
  ++display_tick;           /* let syntax code know we're in a next round of
                             * display updating */

  // Tricky: vim code can reset msg_scrolled behind our back, so need
  // separate bookkeeping for now.
  if (msg_did_scroll) {
    ui_call_win_scroll_over_reset();
    msg_did_scroll = false;
  }

  // if the screen was scrolled up when displaying a message, scroll it down
  if (msg_scrolled) {
    clear_cmdline = true;
    if (dy_flags & DY_MSGSEP) {
      int valid = MAX(Rows - msg_scrollsize(), 0);
      if (valid == 0) {
        redraw_tabline = true;
      }
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        if (W_ENDROW(wp) > valid) {
          wp->w_redr_type = NOT_VALID;
          wp->w_lines_valid = 0;
        }
        if (W_ENDROW(wp) + wp->w_status_height > valid) {
          wp->w_redr_status = true;
        }
      }
    } else if (msg_scrolled > Rows - 5) {  // clearing is faster
      type = CLEAR;
    } else if (type != CLEAR) {
      check_for_delay(false);
      grid_ins_lines(&default_grid, 0, msg_scrolled, (int)Rows,
                     0, (int)Columns);
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        if (wp->w_floating) {
          continue;
        }
        if (wp->w_winrow < msg_scrolled) {
          if (W_ENDROW(wp) > msg_scrolled
              && wp->w_redr_type < REDRAW_TOP
              && wp->w_lines_valid > 0
              && wp->w_topline == wp->w_lines[0].wl_lnum) {
            wp->w_upd_rows = msg_scrolled - wp->w_winrow;
            wp->w_redr_type = REDRAW_TOP;
          } else {
            wp->w_redr_type = NOT_VALID;
            if (W_ENDROW(wp) + wp->w_status_height
                <= msg_scrolled) {
              wp->w_redr_status = TRUE;
            }
          }
        }
      }
      redraw_cmdline = TRUE;
      redraw_tabline = TRUE;
    }
    msg_scrolled = 0;
    need_wait_return = FALSE;
  }

  if (type >= CLEAR || !default_grid.valid) {
    ui_comp_set_screen_valid(false);
  }
  win_ui_flush_positions();
  msg_ext_check_clear();

  /* reset cmdline_row now (may have been changed temporarily) */
  compute_cmdrow();

  /* Check for changed highlighting */
  if (need_highlight_changed)
    highlight_changed();

  if (type == CLEAR) {          // first clear screen
    screenclear();              // will reset clear_cmdline
    cmdline_screen_cleared();   // clear external cmdline state
    type = NOT_VALID;
    // must_redraw may be set indirectly, avoid another redraw later
    must_redraw = 0;
  } else if (!default_grid.valid) {
    grid_invalidate(&default_grid);
    default_grid.valid = true;
  }
  ui_comp_set_screen_valid(true);

  if (clear_cmdline)            /* going to clear cmdline (done below) */
    check_for_delay(FALSE);

  /* Force redraw when width of 'number' or 'relativenumber' column
   * changes. */
  if (curwin->w_redr_type < NOT_VALID
      && curwin->w_nrwidth != ((curwin->w_p_nu || curwin->w_p_rnu)
                               ? number_width(curwin) : 0))
    curwin->w_redr_type = NOT_VALID;

  /*
   * Only start redrawing if there is really something to do.
   */
  if (type == INVERTED)
    update_curswant();
  if (curwin->w_redr_type < type
      && !((type == VALID
            && curwin->w_lines[0].wl_valid
            && curwin->w_topfill == curwin->w_old_topfill
            && curwin->w_botfill == curwin->w_old_botfill
            && curwin->w_topline == curwin->w_lines[0].wl_lnum)
           || (type == INVERTED
               && VIsual_active
               && curwin->w_old_cursor_lnum == curwin->w_cursor.lnum
               && curwin->w_old_visual_mode == VIsual_mode
               && (curwin->w_valid & VALID_VIRTCOL)
               && curwin->w_old_curswant == curwin->w_curswant)
           ))
    curwin->w_redr_type = type;

  // Redraw the tab pages line if needed.
  if (redraw_tabline || type >= NOT_VALID) {
    update_window_hl(curwin, type >= NOT_VALID);
    FOR_ALL_TABS(tp) {
      if (tp != curtab) {
        update_window_hl(tp->tp_curwin, type >= NOT_VALID);
      }
    }
    draw_tabline();
  }

  /*
   * Correct stored syntax highlighting info for changes in each displayed
   * buffer.  Each buffer must only be done once.
   */
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    update_window_hl(wp, type >= NOT_VALID);

    if (wp->w_buffer->b_mod_set) {
      win_T       *wwp;

      // Check if we already did this buffer.
      for (wwp = firstwin; wwp != wp; wwp = wwp->w_next) {
        if (wwp->w_buffer == wp->w_buffer) {
          break;
        }
      }
      if (wwp == wp && syntax_present(wp)) {
        syn_stack_apply_changes(wp->w_buffer);
      }
    }
  }

  /*
   * Go from top to bottom through the windows, redrawing the ones that need
   * it.
   */
  did_one = FALSE;
  search_hl.rm.regprog = NULL;


  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_redr_type == CLEAR && wp->w_floating && wp->w_grid.chars) {
      grid_invalidate(&wp->w_grid);
      wp->w_redr_type = NOT_VALID;
    }

    if (wp->w_redr_type != 0) {
      if (!did_one) {
        did_one = TRUE;
        start_search_hl();
      }
      win_update(wp);
    }

    /* redraw status line after the window to minimize cursor movement */
    if (wp->w_redr_status) {
      win_redr_status(wp);
    }
  }

  end_search_hl();
  // May need to redraw the popup menu.
  if (pum_drawn() && redraw_popupmenu) {
    pum_redraw();
  }

  send_grid_resize = false;
  redraw_popupmenu = false;

  /* Reset b_mod_set flags.  Going through all windows is probably faster
   * than going through all buffers (there could be many buffers). */
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    wp->w_buffer->b_mod_set = false;
  }

  updating_screen = FALSE;

  /* Clear or redraw the command line.  Done last, because scrolling may
   * mess up the command line. */
  if (clear_cmdline || redraw_cmdline) {
    showmode();
  }

  /* May put up an introductory message when not editing a file */
  if (!did_intro)
    maybe_intro_message();
  did_intro = TRUE;

  // either cmdline is cleared, not drawn or mode is last drawn
  cmdline_was_last_drawn = false;
}

/*
 * Return TRUE if the cursor line in window "wp" may be concealed, according
 * to the 'concealcursor' option.
 */
int conceal_cursor_line(win_T *wp)
{
  int c;

  if (*wp->w_p_cocu == NUL)
    return FALSE;
  if (get_real_state() & VISUAL)
    c = 'v';
  else if (State & INSERT)
    c = 'i';
  else if (State & NORMAL)
    c = 'n';
  else if (State & CMDLINE)
    c = 'c';
  else
    return FALSE;
  return vim_strchr(wp->w_p_cocu, c) != NULL;
}

// Check if the cursor line needs to be redrawn because of 'concealcursor'.
//
// When cursor is moved at the same time, both lines will be redrawn regardless.
void conceal_check_cursor_line(void)
{
  bool should_conceal = conceal_cursor_line(curwin);
  if (curwin->w_p_cole > 0 && (conceal_cursor_used != should_conceal)) {
    redrawWinline(curwin, curwin->w_cursor.lnum);
    // Need to recompute cursor column, e.g., when starting Visual mode
    // without concealing. */
    curs_columns(true);
  }
}

/// Whether cursorline is drawn in a special way
///
/// If true, both old and new cursorline will need
/// need to be redrawn when moving cursor within windows.
bool win_cursorline_standout(win_T *wp)
{
  return wp->w_p_cul || (wp->w_p_cole > 0 && !conceal_cursor_line(wp));
}

/*
 * Update a single window.
 *
 * This may cause the windows below it also to be redrawn (when clearing the
 * screen or scrolling lines).
 *
 * How the window is redrawn depends on wp->w_redr_type.  Each type also
 * implies the one below it.
 * NOT_VALID	redraw the whole window
 * SOME_VALID	redraw the whole window but do scroll when possible
 * REDRAW_TOP	redraw the top w_upd_rows window lines, otherwise like VALID
 * INVERTED	redraw the changed part of the Visual area
 * INVERTED_ALL	redraw the whole Visual area
 * VALID	1. scroll up/down to adjust for a changed w_topline
 *		2. update lines at the top when scrolled down
 *		3. redraw changed text:
 *		   - if wp->w_buffer->b_mod_set set, update lines between
 *		     b_mod_top and b_mod_bot.
 *		   - if wp->w_redraw_top non-zero, redraw lines between
 *		     wp->w_redraw_top and wp->w_redr_bot.
 *		   - continue redrawing when syntax status is invalid.
 *		4. if scrolled up, update lines at the bottom.
 * This results in three areas that may need updating:
 * top:	from first row to top_end (when scrolled down)
 * mid: from mid_start to mid_end (update inversion or changed text)
 * bot: from bot_start to last row (when scrolled up)
 */
static void win_update(win_T *wp)
{
  buf_T       *buf = wp->w_buffer;
  int type;
  int top_end = 0;              /* Below last row of the top area that needs
                                   updating.  0 when no top area updating. */
  int mid_start = 999;          /* first row of the mid area that needs
                                   updating.  999 when no mid area updating. */
  int mid_end = 0;              /* Below last row of the mid area that needs
                                   updating.  0 when no mid area updating. */
  int bot_start = 999;          /* first row of the bot area that needs
                                   updating.  999 when no bot area updating */
  int scrolled_down = FALSE;            /* TRUE when scrolled down when
                                           w_topline got smaller a bit */
  matchitem_T *cur;             /* points to the match list */
  int top_to_mod = FALSE;              /* redraw above mod_top */

  int row;                      /* current window row to display */
  linenr_T lnum;                /* current buffer lnum to display */
  int idx;                      /* current index in w_lines[] */
  int srow;                     /* starting row of the current line */

  int eof = FALSE;              /* if TRUE, we hit the end of the file */
  int didline = FALSE;           /* if TRUE, we finished the last line */
  int i;
  long j;
  static int recursive = FALSE;         /* being called recursively */
  int old_botline = wp->w_botline;
  long fold_count;
  // Remember what happened to the previous line.
#define DID_NONE 1      // didn't update a line
#define DID_LINE 2      // updated a normal line
#define DID_FOLD 3      // updated a folded line
  int did_update = DID_NONE;
  linenr_T syntax_last_parsed = 0;              /* last parsed text line */
  linenr_T mod_top = 0;
  linenr_T mod_bot = 0;
  int save_got_int;

  // If we can compute a change in the automatic sizing of the sign column
  // under 'signcolumn=auto:X' and signs currently placed in the buffer, better
  // figuring it out here so we can redraw the entire screen for it.
  buf_signcols(buf);

  type = wp->w_redr_type;

  win_grid_alloc(wp);

  if (type >= NOT_VALID) {
    wp->w_redr_status = true;
    wp->w_lines_valid = 0;
  }

  // Window is zero-height: nothing to draw.
  if (wp->w_grid.Rows == 0) {
    wp->w_redr_type = 0;
    return;
  }

  // Window is zero-width: Only need to draw the separator.
  if (wp->w_grid.Columns == 0) {
    // draw the vertical separator right of this window
    draw_vsep_win(wp, 0);
    wp->w_redr_type = 0;
    return;
  }

  init_search_hl(wp);

  /* Force redraw when width of 'number' or 'relativenumber' column
   * changes. */
  i = (wp->w_p_nu || wp->w_p_rnu) ? number_width(wp) : 0;
  if (wp->w_nrwidth != i) {
    type = NOT_VALID;
    wp->w_nrwidth = i;

    if (buf->terminal) {
      terminal_check_size(buf->terminal);
    }
  } else if (buf->b_mod_set
             && buf->b_mod_xlines != 0
             && wp->w_redraw_top != 0) {
    // When there are both inserted/deleted lines and specific lines to be
    // redrawn, w_redraw_top and w_redraw_bot may be invalid, just redraw
    // everything (only happens when redrawing is off for while).
    type = NOT_VALID;
  } else {
    /*
     * Set mod_top to the first line that needs displaying because of
     * changes.  Set mod_bot to the first line after the changes.
     */
    mod_top = wp->w_redraw_top;
    if (wp->w_redraw_bot != 0)
      mod_bot = wp->w_redraw_bot + 1;
    else
      mod_bot = 0;
    if (buf->b_mod_set) {
      if (mod_top == 0 || mod_top > buf->b_mod_top) {
        mod_top = buf->b_mod_top;
        /* Need to redraw lines above the change that may be included
         * in a pattern match. */
        if (syntax_present(wp)) {
          mod_top -= buf->b_s.b_syn_sync_linebreaks;
          if (mod_top < 1)
            mod_top = 1;
        }
      }
      if (mod_bot == 0 || mod_bot < buf->b_mod_bot)
        mod_bot = buf->b_mod_bot;

      /* When 'hlsearch' is on and using a multi-line search pattern, a
       * change in one line may make the Search highlighting in a
       * previous line invalid.  Simple solution: redraw all visible
       * lines above the change.
       * Same for a match pattern.
       */
      if (search_hl.rm.regprog != NULL
          && re_multiline(search_hl.rm.regprog))
        top_to_mod = TRUE;
      else {
        cur = wp->w_match_head;
        while (cur != NULL) {
          if (cur->match.regprog != NULL
              && re_multiline(cur->match.regprog)) {
            top_to_mod = TRUE;
            break;
          }
          cur = cur->next;
        }
      }
    }
    if (mod_top != 0 && hasAnyFolding(wp)) {
      linenr_T lnumt, lnumb;

      /*
       * A change in a line can cause lines above it to become folded or
       * unfolded.  Find the top most buffer line that may be affected.
       * If the line was previously folded and displayed, get the first
       * line of that fold.  If the line is folded now, get the first
       * folded line.  Use the minimum of these two.
       */

      /* Find last valid w_lines[] entry above mod_top.  Set lnumt to
       * the line below it.  If there is no valid entry, use w_topline.
       * Find the first valid w_lines[] entry below mod_bot.  Set lnumb
       * to this line.  If there is no valid entry, use MAXLNUM. */
      lnumt = wp->w_topline;
      lnumb = MAXLNUM;
      for (i = 0; i < wp->w_lines_valid; ++i)
        if (wp->w_lines[i].wl_valid) {
          if (wp->w_lines[i].wl_lastlnum < mod_top)
            lnumt = wp->w_lines[i].wl_lastlnum + 1;
          if (lnumb == MAXLNUM && wp->w_lines[i].wl_lnum >= mod_bot) {
            lnumb = wp->w_lines[i].wl_lnum;
            // When there is a fold column it might need updating
            // in the next line ("J" just above an open fold).
            if (compute_foldcolumn(wp, 0) > 0) {
              lnumb++;
            }
          }
        }

      (void)hasFoldingWin(wp, mod_top, &mod_top, NULL, true, NULL);
      if (mod_top > lnumt) {
        mod_top = lnumt;
      }

      // Now do the same for the bottom line (one above mod_bot).
      mod_bot--;
      (void)hasFoldingWin(wp, mod_bot, NULL, &mod_bot, true, NULL);
      mod_bot++;
      if (mod_bot < lnumb) {
        mod_bot = lnumb;
      }
    }

    /* When a change starts above w_topline and the end is below
     * w_topline, start redrawing at w_topline.
     * If the end of the change is above w_topline: do like no change was
     * made, but redraw the first line to find changes in syntax. */
    if (mod_top != 0 && mod_top < wp->w_topline) {
      if (mod_bot > wp->w_topline)
        mod_top = wp->w_topline;
      else if (syntax_present(wp))
        top_end = 1;
    }

    /* When line numbers are displayed need to redraw all lines below
     * inserted/deleted lines. */
    if (mod_top != 0 && buf->b_mod_xlines != 0 && wp->w_p_nu)
      mod_bot = MAXLNUM;
  }
  wp->w_redraw_top = 0;  // reset for next time
  wp->w_redraw_bot = 0;

  /*
   * When only displaying the lines at the top, set top_end.  Used when
   * window has scrolled down for msg_scrolled.
   */
  if (type == REDRAW_TOP) {
    j = 0;
    for (i = 0; i < wp->w_lines_valid; ++i) {
      j += wp->w_lines[i].wl_size;
      if (j >= wp->w_upd_rows) {
        top_end = j;
        break;
      }
    }
    if (top_end == 0)
      /* not found (cannot happen?): redraw everything */
      type = NOT_VALID;
    else
      /* top area defined, the rest is VALID */
      type = VALID;
  }

  /*
   * If there are no changes on the screen that require a complete redraw,
   * handle three cases:
   * 1: we are off the top of the screen by a few lines: scroll down
   * 2: wp->w_topline is below wp->w_lines[0].wl_lnum: may scroll up
   * 3: wp->w_topline is wp->w_lines[0].wl_lnum: find first entry in
   *    w_lines[] that needs updating.
   */
  if ((type == VALID || type == SOME_VALID
       || type == INVERTED || type == INVERTED_ALL)
      && !wp->w_botfill && !wp->w_old_botfill
      ) {
    if (mod_top != 0 && wp->w_topline == mod_top) {
      /*
       * w_topline is the first changed line, the scrolling will be done
       * further down.
       */
    } else if (wp->w_lines[0].wl_valid
               && (wp->w_topline < wp->w_lines[0].wl_lnum
                   || (wp->w_topline == wp->w_lines[0].wl_lnum
                       && wp->w_topfill > wp->w_old_topfill)
                   )) {
      /*
       * New topline is above old topline: May scroll down.
       */
      if (hasAnyFolding(wp)) {
        linenr_T ln;

        /* count the number of lines we are off, counting a sequence
         * of folded lines as one */
        j = 0;
        for (ln = wp->w_topline; ln < wp->w_lines[0].wl_lnum; ln++) {
          j++;
          if (j >= wp->w_grid.Rows - 2) {
            break;
          }
          (void)hasFoldingWin(wp, ln, NULL, &ln, true, NULL);
        }
      } else
        j = wp->w_lines[0].wl_lnum - wp->w_topline;
      if (j < wp->w_grid.Rows - 2) {               // not too far off
        i = plines_m_win(wp, wp->w_topline, wp->w_lines[0].wl_lnum - 1);
        /* insert extra lines for previously invisible filler lines */
        if (wp->w_lines[0].wl_lnum != wp->w_topline)
          i += diff_check_fill(wp, wp->w_lines[0].wl_lnum)
               - wp->w_old_topfill;
        if (i < wp->w_grid.Rows - 2) {  // less than a screen off
          // Try to insert the correct number of lines.
          // If not the last window, delete the lines at the bottom.
          // win_ins_lines may fail when the terminal can't do it.
          win_scroll_lines(wp, 0, i);
          if (wp->w_lines_valid != 0) {
            // Need to update rows that are new, stop at the
            // first one that scrolled down.
            top_end = i;
            scrolled_down = true;

            // Move the entries that were scrolled, disable
            // the entries for the lines to be redrawn.
            if ((wp->w_lines_valid += j) > wp->w_grid.Rows) {
              wp->w_lines_valid = wp->w_grid.Rows;
            }
            for (idx = wp->w_lines_valid; idx - j >= 0; idx--) {
              wp->w_lines[idx] = wp->w_lines[idx - j];
            }
            while (idx >= 0) {
              wp->w_lines[idx--].wl_valid = false;
            }
          }
        } else {
          mid_start = 0;  // redraw all lines
        }
      } else {
        mid_start = 0;  // redraw all lines
      }
    } else {
      /*
       * New topline is at or below old topline: May scroll up.
       * When topline didn't change, find first entry in w_lines[] that
       * needs updating.
       */

      /* try to find wp->w_topline in wp->w_lines[].wl_lnum */
      j = -1;
      row = 0;
      for (i = 0; i < wp->w_lines_valid; i++) {
        if (wp->w_lines[i].wl_valid
            && wp->w_lines[i].wl_lnum == wp->w_topline) {
          j = i;
          break;
        }
        row += wp->w_lines[i].wl_size;
      }
      if (j == -1) {
        /* if wp->w_topline is not in wp->w_lines[].wl_lnum redraw all
         * lines */
        mid_start = 0;
      } else {
        /*
         * Try to delete the correct number of lines.
         * wp->w_topline is at wp->w_lines[i].wl_lnum.
         */
        /* If the topline didn't change, delete old filler lines,
         * otherwise delete filler lines of the new topline... */
        if (wp->w_lines[0].wl_lnum == wp->w_topline)
          row += wp->w_old_topfill;
        else
          row += diff_check_fill(wp, wp->w_topline);
        /* ... but don't delete new filler lines. */
        row -= wp->w_topfill;
        if (row > 0) {
          win_scroll_lines(wp, 0, -row);
          bot_start = wp->w_grid.Rows - row;
        }
        if ((row == 0 || bot_start < 999) && wp->w_lines_valid != 0) {
          /*
           * Skip the lines (below the deleted lines) that are still
           * valid and don't need redrawing.	Copy their info
           * upwards, to compensate for the deleted lines.  Set
           * bot_start to the first row that needs redrawing.
           */
          bot_start = 0;
          idx = 0;
          for (;; ) {
            wp->w_lines[idx] = wp->w_lines[j];
            /* stop at line that didn't fit, unless it is still
             * valid (no lines deleted) */
            if (row > 0 && bot_start + row
                + (int)wp->w_lines[j].wl_size > wp->w_grid.Rows) {
              wp->w_lines_valid = idx + 1;
              break;
            }
            bot_start += wp->w_lines[idx++].wl_size;

            /* stop at the last valid entry in w_lines[].wl_size */
            if (++j >= wp->w_lines_valid) {
              wp->w_lines_valid = idx;
              break;
            }
          }
          /* Correct the first entry for filler lines at the top
           * when it won't get updated below. */
          if (wp->w_p_diff && bot_start > 0)
            wp->w_lines[0].wl_size =
              plines_win_nofill(wp, wp->w_topline, true)
              + wp->w_topfill;
        }
      }
    }

    // When starting redraw in the first line, redraw all lines.
    if (mid_start == 0) {
      mid_end = wp->w_grid.Rows;
    }
  } else {
    /* Not VALID or INVERTED: redraw all lines. */
    mid_start = 0;
    mid_end = wp->w_grid.Rows;
  }

  if (type == SOME_VALID) {
    /* SOME_VALID: redraw all lines. */
    mid_start = 0;
    mid_end = wp->w_grid.Rows;
    type = NOT_VALID;
  }

  /* check if we are updating or removing the inverted part */
  if ((VIsual_active && buf == curwin->w_buffer)
      || (wp->w_old_cursor_lnum != 0 && type != NOT_VALID)) {
    linenr_T from, to;

    if (VIsual_active) {
      if (VIsual_mode != wp->w_old_visual_mode || type == INVERTED_ALL) {
        // If the type of Visual selection changed, redraw the whole
        // selection.  Also when the ownership of the X selection is
        // gained or lost.
        if (curwin->w_cursor.lnum < VIsual.lnum) {
          from = curwin->w_cursor.lnum;
          to = VIsual.lnum;
        } else {
          from = VIsual.lnum;
          to = curwin->w_cursor.lnum;
        }
        /* redraw more when the cursor moved as well */
        if (wp->w_old_cursor_lnum < from)
          from = wp->w_old_cursor_lnum;
        if (wp->w_old_cursor_lnum > to)
          to = wp->w_old_cursor_lnum;
        if (wp->w_old_visual_lnum < from)
          from = wp->w_old_visual_lnum;
        if (wp->w_old_visual_lnum > to)
          to = wp->w_old_visual_lnum;
      } else {
        /*
         * Find the line numbers that need to be updated: The lines
         * between the old cursor position and the current cursor
         * position.  Also check if the Visual position changed.
         */
        if (curwin->w_cursor.lnum < wp->w_old_cursor_lnum) {
          from = curwin->w_cursor.lnum;
          to = wp->w_old_cursor_lnum;
        } else {
          from = wp->w_old_cursor_lnum;
          to = curwin->w_cursor.lnum;
          if (from == 0)                /* Visual mode just started */
            from = to;
        }

        if (VIsual.lnum != wp->w_old_visual_lnum
            || VIsual.col != wp->w_old_visual_col) {
          if (wp->w_old_visual_lnum < from
              && wp->w_old_visual_lnum != 0)
            from = wp->w_old_visual_lnum;
          if (wp->w_old_visual_lnum > to)
            to = wp->w_old_visual_lnum;
          if (VIsual.lnum < from)
            from = VIsual.lnum;
          if (VIsual.lnum > to)
            to = VIsual.lnum;
        }
      }

      /*
       * If in block mode and changed column or curwin->w_curswant:
       * update all lines.
       * First compute the actual start and end column.
       */
      if (VIsual_mode == Ctrl_V) {
        colnr_T fromc, toc;
        int save_ve_flags = ve_flags;

        if (curwin->w_p_lbr)
          ve_flags = VE_ALL;

        getvcols(wp, &VIsual, &curwin->w_cursor, &fromc, &toc);
        ve_flags = save_ve_flags;
        ++toc;
        if (curwin->w_curswant == MAXCOL)
          toc = MAXCOL;

        if (fromc != wp->w_old_cursor_fcol
            || toc != wp->w_old_cursor_lcol) {
          if (from > VIsual.lnum)
            from = VIsual.lnum;
          if (to < VIsual.lnum)
            to = VIsual.lnum;
        }
        wp->w_old_cursor_fcol = fromc;
        wp->w_old_cursor_lcol = toc;
      }
    } else {
      /* Use the line numbers of the old Visual area. */
      if (wp->w_old_cursor_lnum < wp->w_old_visual_lnum) {
        from = wp->w_old_cursor_lnum;
        to = wp->w_old_visual_lnum;
      } else {
        from = wp->w_old_visual_lnum;
        to = wp->w_old_cursor_lnum;
      }
    }

    /*
     * There is no need to update lines above the top of the window.
     */
    if (from < wp->w_topline)
      from = wp->w_topline;

    /*
     * If we know the value of w_botline, use it to restrict the update to
     * the lines that are visible in the window.
     */
    if (wp->w_valid & VALID_BOTLINE) {
      if (from >= wp->w_botline)
        from = wp->w_botline - 1;
      if (to >= wp->w_botline)
        to = wp->w_botline - 1;
    }

    /*
     * Find the minimal part to be updated.
     * Watch out for scrolling that made entries in w_lines[] invalid.
     * E.g., CTRL-U makes the first half of w_lines[] invalid and sets
     * top_end; need to redraw from top_end to the "to" line.
     * A middle mouse click with a Visual selection may change the text
     * above the Visual area and reset wl_valid, do count these for
     * mid_end (in srow).
     */
    if (mid_start > 0) {
      lnum = wp->w_topline;
      idx = 0;
      srow = 0;
      if (scrolled_down)
        mid_start = top_end;
      else
        mid_start = 0;
      while (lnum < from && idx < wp->w_lines_valid) {          /* find start */
        if (wp->w_lines[idx].wl_valid)
          mid_start += wp->w_lines[idx].wl_size;
        else if (!scrolled_down)
          srow += wp->w_lines[idx].wl_size;
        ++idx;
        if (idx < wp->w_lines_valid && wp->w_lines[idx].wl_valid)
          lnum = wp->w_lines[idx].wl_lnum;
        else
          ++lnum;
      }
      srow += mid_start;
      mid_end = wp->w_grid.Rows;
      for (; idx < wp->w_lines_valid; idx++) {                  // find end
        if (wp->w_lines[idx].wl_valid
            && wp->w_lines[idx].wl_lnum >= to + 1) {
          /* Only update until first row of this line */
          mid_end = srow;
          break;
        }
        srow += wp->w_lines[idx].wl_size;
      }
    }
  }

  if (VIsual_active && buf == curwin->w_buffer) {
    wp->w_old_visual_mode = VIsual_mode;
    wp->w_old_cursor_lnum = curwin->w_cursor.lnum;
    wp->w_old_visual_lnum = VIsual.lnum;
    wp->w_old_visual_col = VIsual.col;
    wp->w_old_curswant = curwin->w_curswant;
  } else {
    wp->w_old_visual_mode = 0;
    wp->w_old_cursor_lnum = 0;
    wp->w_old_visual_lnum = 0;
    wp->w_old_visual_col = 0;
  }

  /* reset got_int, otherwise regexp won't work */
  save_got_int = got_int;
  got_int = 0;
  // Set the time limit to 'redrawtime'.
  proftime_T syntax_tm = profile_setlimit(p_rdt);
  syn_set_timeout(&syntax_tm);
  win_foldinfo.fi_level = 0;

  /*
   * Update all the window rows.
   */
  idx = 0;              /* first entry in w_lines[].wl_size */
  row = 0;
  srow = 0;
  lnum = wp->w_topline;         /* first line shown in window */
  for (;; ) {
    /* stop updating when reached the end of the window (check for _past_
     * the end of the window is at the end of the loop) */
    if (row == wp->w_grid.Rows) {
      didline = true;
      break;
    }

    /* stop updating when hit the end of the file */
    if (lnum > buf->b_ml.ml_line_count) {
      eof = TRUE;
      break;
    }

    /* Remember the starting row of the line that is going to be dealt
     * with.  It is used further down when the line doesn't fit. */
    srow = row;

    // Update a line when it is in an area that needs updating, when it
    // has changes or w_lines[idx] is invalid.
    // "bot_start" may be halfway a wrapped line after using
    // win_scroll_lines(), check if the current line includes it.
    // When syntax folding is being used, the saved syntax states will
    // already have been updated, we can't see where the syntax state is
    // the same again, just update until the end of the window.
    if (row < top_end
        || (row >= mid_start && row < mid_end)
        || top_to_mod
        || idx >= wp->w_lines_valid
        || (row + wp->w_lines[idx].wl_size > bot_start)
        || (mod_top != 0
            && (lnum == mod_top
                || (lnum >= mod_top
                    && (lnum < mod_bot
                        || did_update == DID_FOLD
                        || (did_update == DID_LINE
                            && syntax_present(wp)
                            && ((foldmethodIsSyntax(wp)
                                 && hasAnyFolding(wp))
                                || syntax_check_changed(lnum)))
                        // match in fixed position might need redraw
                        // if lines were inserted or deleted
                        || (wp->w_match_head != NULL
                            && buf->b_mod_xlines != 0)))))) {
      if (lnum == mod_top) {
        top_to_mod = false;
      }

      /*
       * When at start of changed lines: May scroll following lines
       * up or down to minimize redrawing.
       * Don't do this when the change continues until the end.
       * Don't scroll when dollar_vcol >= 0, keep the "$".
       */
      if (lnum == mod_top
          && mod_bot != MAXLNUM
          && !(dollar_vcol >= 0 && mod_bot == mod_top + 1)) {
        int old_rows = 0;
        int new_rows = 0;
        int xtra_rows;
        linenr_T l;

        /* Count the old number of window rows, using w_lines[], which
         * should still contain the sizes for the lines as they are
         * currently displayed. */
        for (i = idx; i < wp->w_lines_valid; ++i) {
          /* Only valid lines have a meaningful wl_lnum.  Invalid
           * lines are part of the changed area. */
          if (wp->w_lines[i].wl_valid
              && wp->w_lines[i].wl_lnum == mod_bot)
            break;
          old_rows += wp->w_lines[i].wl_size;
          if (wp->w_lines[i].wl_valid
              && wp->w_lines[i].wl_lastlnum + 1 == mod_bot) {
            /* Must have found the last valid entry above mod_bot.
             * Add following invalid entries. */
            ++i;
            while (i < wp->w_lines_valid
                   && !wp->w_lines[i].wl_valid)
              old_rows += wp->w_lines[i++].wl_size;
            break;
          }
        }

        if (i >= wp->w_lines_valid) {
          /* We can't find a valid line below the changed lines,
           * need to redraw until the end of the window.
           * Inserting/deleting lines has no use. */
          bot_start = 0;
        } else {
          /* Able to count old number of rows: Count new window
           * rows, and may insert/delete lines */
          j = idx;
          for (l = lnum; l < mod_bot; l++) {
            if (hasFoldingWin(wp, l, NULL, &l, true, NULL)) {
              new_rows++;
            } else if (l == wp->w_topline) {
              new_rows += plines_win_nofill(wp, l, true) + wp->w_topfill;
            } else {
              new_rows += plines_win(wp, l, true);
            }
            j++;
            if (new_rows > wp->w_grid.Rows - row - 2) {
              // it's getting too much, must redraw the rest
              new_rows = 9999;
              break;
            }
          }
          xtra_rows = new_rows - old_rows;
          if (xtra_rows < 0) {
            /* May scroll text up.  If there is not enough
             * remaining text or scrolling fails, must redraw the
             * rest.  If scrolling works, must redraw the text
             * below the scrolled text. */
            if (row - xtra_rows >= wp->w_grid.Rows - 2) {
              mod_bot = MAXLNUM;
            } else {
              win_scroll_lines(wp, row, xtra_rows);
              bot_start = wp->w_grid.Rows + xtra_rows;
            }
          } else if (xtra_rows > 0) {
            /* May scroll text down.  If there is not enough
             * remaining text of scrolling fails, must redraw the
             * rest. */
            if (row + xtra_rows >= wp->w_grid.Rows - 2) {
              mod_bot = MAXLNUM;
            } else {
              win_scroll_lines(wp, row + old_rows, xtra_rows);
              if (top_end > row + old_rows) {
                // Scrolled the part at the top that requires
                // updating down.
                top_end += xtra_rows;
              }
            }
          }

          /* When not updating the rest, may need to move w_lines[]
           * entries. */
          if (mod_bot != MAXLNUM && i != j) {
            if (j < i) {
              int x = row + new_rows;

              /* move entries in w_lines[] upwards */
              for (;; ) {
                /* stop at last valid entry in w_lines[] */
                if (i >= wp->w_lines_valid) {
                  wp->w_lines_valid = j;
                  break;
                }
                wp->w_lines[j] = wp->w_lines[i];
                /* stop at a line that won't fit */
                if (x + (int)wp->w_lines[j].wl_size
                    > wp->w_grid.Rows) {
                  wp->w_lines_valid = j + 1;
                  break;
                }
                x += wp->w_lines[j++].wl_size;
                ++i;
              }
              if (bot_start > x)
                bot_start = x;
            } else {       /* j > i */
                             /* move entries in w_lines[] downwards */
              j -= i;
              wp->w_lines_valid += j;
              if (wp->w_lines_valid > wp->w_grid.Rows) {
                wp->w_lines_valid = wp->w_grid.Rows;
              }
              for (i = wp->w_lines_valid; i - j >= idx; i--) {
                wp->w_lines[i] = wp->w_lines[i - j];
              }

              /* The w_lines[] entries for inserted lines are
               * now invalid, but wl_size may be used above.
               * Reset to zero. */
              while (i >= idx) {
                wp->w_lines[i].wl_size = 0;
                wp->w_lines[i--].wl_valid = FALSE;
              }
            }
          }
        }
      }

      /*
       * When lines are folded, display one line for all of them.
       * Otherwise, display normally (can be several display lines when
       * 'wrap' is on).
       */
      fold_count = foldedCount(wp, lnum, &win_foldinfo);
      if (fold_count != 0) {
        fold_line(wp, fold_count, &win_foldinfo, lnum, row);
        ++row;
        --fold_count;
        wp->w_lines[idx].wl_folded = TRUE;
        wp->w_lines[idx].wl_lastlnum = lnum + fold_count;
        did_update = DID_FOLD;
      } else if (idx < wp->w_lines_valid
                 && wp->w_lines[idx].wl_valid
                 && wp->w_lines[idx].wl_lnum == lnum
                 && lnum > wp->w_topline
                 && !(dy_flags & (DY_LASTLINE | DY_TRUNCATE))
                 && srow + wp->w_lines[idx].wl_size > wp->w_grid.Rows
                 && diff_check_fill(wp, lnum) == 0
                 ) {
        /* This line is not going to fit.  Don't draw anything here,
         * will draw "@  " lines below. */
        row = wp->w_grid.Rows + 1;
      } else {
        prepare_search_hl(wp, lnum);
        /* Let the syntax stuff know we skipped a few lines. */
        if (syntax_last_parsed != 0 && syntax_last_parsed + 1 < lnum
            && syntax_present(wp))
          syntax_end_parsing(syntax_last_parsed + 1);

        /*
         * Display one line.
         */
        row = win_line(wp, lnum, srow, wp->w_grid.Rows, mod_top == 0, false);

        wp->w_lines[idx].wl_folded = FALSE;
        wp->w_lines[idx].wl_lastlnum = lnum;
        did_update = DID_LINE;
        syntax_last_parsed = lnum;
      }

      wp->w_lines[idx].wl_lnum = lnum;
      wp->w_lines[idx].wl_valid = true;

      if (row > wp->w_grid.Rows) {         // past end of grid
        // we may need the size of that too long line later on
        if (dollar_vcol == -1) {
          wp->w_lines[idx].wl_size = plines_win(wp, lnum, true);
        }
        idx++;
        break;
      }
      if (dollar_vcol == -1)
        wp->w_lines[idx].wl_size = row - srow;
      ++idx;
      lnum += fold_count + 1;
    } else {
      if (wp->w_p_rnu) {
        // 'relativenumber' set: The text doesn't need to be drawn, but
        // the number column nearly always does.
        fold_count = foldedCount(wp, lnum, &win_foldinfo);
        if (fold_count != 0) {
          fold_line(wp, fold_count, &win_foldinfo, lnum, row);
        } else {
          (void)win_line(wp, lnum, srow, wp->w_grid.Rows, true, true);
        }
      }

      // This line does not need to be drawn, advance to the next one.
      row += wp->w_lines[idx++].wl_size;
      if (row > wp->w_grid.Rows) {  // past end of screen
        break;
      }
      lnum = wp->w_lines[idx - 1].wl_lastlnum + 1;
      did_update = DID_NONE;
    }

    if (lnum > buf->b_ml.ml_line_count) {
      eof = TRUE;
      break;
    }
  }
  /*
   * End of loop over all window lines.
   */


  if (idx > wp->w_lines_valid)
    wp->w_lines_valid = idx;

  /*
   * Let the syntax stuff know we stop parsing here.
   */
  if (syntax_last_parsed != 0 && syntax_present(wp))
    syntax_end_parsing(syntax_last_parsed + 1);

  /*
   * If we didn't hit the end of the file, and we didn't finish the last
   * line we were working on, then the line didn't fit.
   */
  wp->w_empty_rows = 0;
  wp->w_filler_rows = 0;
  if (!eof && !didline) {
    int at_attr = hl_combine_attr(wp->w_hl_attr_normal,
                                  win_hl_attr(wp, HLF_AT));
    if (lnum == wp->w_topline) {
      /*
       * Single line that does not fit!
       * Don't overwrite it, it can be edited.
       */
      wp->w_botline = lnum + 1;
    } else if (diff_check_fill(wp, lnum) >= wp->w_grid.Rows - srow) {
      // Window ends in filler lines.
      wp->w_botline = lnum;
      wp->w_filler_rows = wp->w_grid.Rows - srow;
    } else if (dy_flags & DY_TRUNCATE) {      // 'display' has "truncate"
      int scr_row = wp->w_grid.Rows - 1;

      // Last line isn't finished: Display "@@@" in the last screen line.
      grid_puts_len(&wp->w_grid, (char_u *)"@@", 2, scr_row, 0, at_attr);

      grid_fill(&wp->w_grid, scr_row, scr_row + 1, 2, (int)wp->w_grid.Columns,
                '@', ' ', at_attr);
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    } else if (dy_flags & DY_LASTLINE) {      // 'display' has "lastline"
      // Last line isn't finished: Display "@@@" at the end.
      grid_fill(&wp->w_grid, wp->w_grid.Rows - 1, wp->w_grid.Rows,
                wp->w_grid.Columns - 3, wp->w_grid.Columns, '@', '@', at_attr);
      set_empty_rows(wp, srow);
      wp->w_botline = lnum;
    } else {
      win_draw_end(wp, '@', ' ', true, srow, wp->w_grid.Rows, at_attr);
      wp->w_botline = lnum;
    }
  } else {
    if (eof) {  // we hit the end of the file
      wp->w_botline = buf->b_ml.ml_line_count + 1;
      j = diff_check_fill(wp, wp->w_botline);
      if (j > 0 && !wp->w_botfill) {
        // display filler lines at the end of the file
        if (char2cells(wp->w_p_fcs_chars.diff) > 1) {
          i = '-';
        } else {
          i = wp->w_p_fcs_chars.diff;
        }
        if (row + j > wp->w_grid.Rows) {
          j = wp->w_grid.Rows - row;
        }
        win_draw_end(wp, i, i, true, row, row + (int)j, HLF_DED);
        row += j;
      }
    } else if (dollar_vcol == -1)
      wp->w_botline = lnum;

    // make sure the rest of the screen is blank
    // write the 'eob' character to rows that aren't part of the file.
    win_draw_end(wp, wp->w_p_fcs_chars.eob, ' ', false, row, wp->w_grid.Rows,
                 HLF_EOB);
  }

  if (wp->w_redr_type >= REDRAW_TOP) {
    draw_vsep_win(wp, 0);
  }
  syn_set_timeout(NULL);

  /* Reset the type of redrawing required, the window has been updated. */
  wp->w_redr_type = 0;
  wp->w_old_topfill = wp->w_topfill;
  wp->w_old_botfill = wp->w_botfill;

  if (dollar_vcol == -1) {
    /*
     * There is a trick with w_botline.  If we invalidate it on each
     * change that might modify it, this will cause a lot of expensive
     * calls to plines() in update_topline() each time.  Therefore the
     * value of w_botline is often approximated, and this value is used to
     * compute the value of w_topline.  If the value of w_botline was
     * wrong, check that the value of w_topline is correct (cursor is on
     * the visible part of the text).  If it's not, we need to redraw
     * again.  Mostly this just means scrolling up a few lines, so it
     * doesn't look too bad.  Only do this for the current window (where
     * changes are relevant).
     */
    wp->w_valid |= VALID_BOTLINE;
    if (wp == curwin && wp->w_botline != old_botline && !recursive) {
      recursive = TRUE;
      curwin->w_valid &= ~VALID_TOPLINE;
      update_topline();         /* may invalidate w_botline again */
      if (must_redraw != 0) {
        /* Don't update for changes in buffer again. */
        i = curbuf->b_mod_set;
        curbuf->b_mod_set = false;
        win_update(curwin);
        must_redraw = 0;
        curbuf->b_mod_set = i;
      }
      recursive = FALSE;
    }
  }

  /* restore got_int, unless CTRL-C was hit while redrawing */
  if (!got_int)
    got_int = save_got_int;
}

/// Returns width of the signcolumn that should be used for the whole window
///
/// @param wp window we want signcolumn width from
/// @return max width of signcolumn (cell unit)
///
/// @note Returns a constant for now but hopefully we can improve neovim so that
///       the returned value width adapts to the maximum number of marks to draw
///       for the window
/// TODO(teto)
int win_signcol_width(win_T *wp)
{
  // 2 is vim default value
  return 2;
}

/// Call grid_fill() with columns adjusted for 'rightleft' if needed.
/// Return the new offset.
static int win_fill_end(win_T *wp, int c1, int c2, int off, int width, int row,
                        int endrow, int attr)
{
  int nn = off + width;

  if (nn > wp->w_grid.Columns) {
    nn = wp->w_grid.Columns;
  }

  if (wp->w_p_rl) {
    grid_fill(&wp->w_grid, row, endrow, W_ENDCOL(wp) - nn, W_ENDCOL(wp) - off,
              c1, c2, attr);
  } else {
    grid_fill(&wp->w_grid, row, endrow, off, nn, c1, c2, attr);
  }

  return nn;
}

/// Clear lines near the end of the window and mark the unused lines with "c1".
/// Use "c2" as filler character.
/// When "draw_margin" is true, then draw the sign/fold/number columns.
static void win_draw_end(win_T *wp, int c1, int c2, bool draw_margin, int row,
                         int endrow, hlf_T hl)
{
  int n = 0;

  if (draw_margin) {
    // draw the fold column
    int fdc = compute_foldcolumn(wp, 0);
    if (fdc > 0) {
      n = win_fill_end(wp, ' ', ' ', n, fdc, row, endrow,
                       win_hl_attr(wp, HLF_FC));
    }
    // draw the sign column
    int count = win_signcol_count(wp);
    if (count > 0) {
      n = win_fill_end(wp, ' ', ' ', n, win_signcol_width(wp) * count, row,
                       endrow, win_hl_attr(wp, HLF_SC));
    }
    // draw the number column
    if ((wp->w_p_nu || wp->w_p_rnu) && vim_strchr(p_cpo, CPO_NUMCOL) == NULL) {
      n = win_fill_end(wp, ' ', ' ', n, number_width(wp) + 1, row, endrow,
                       win_hl_attr(wp, HLF_N));
    }
  }

  int attr = hl_combine_attr(wp->w_hl_attr_normal, win_hl_attr(wp, hl));

  if (wp->w_p_rl) {
    grid_fill(&wp->w_grid, row, endrow, wp->w_wincol, W_ENDCOL(wp) - 1 - n,
              c2, c2, attr);
    grid_fill(&wp->w_grid, row, endrow, W_ENDCOL(wp) - 1 - n, W_ENDCOL(wp) - n,
              c1, c2, attr);
  } else {
    grid_fill(&wp->w_grid, row, endrow, n, wp->w_grid.Columns, c1, c2, attr);
  }

  set_empty_rows(wp, row);
}


/*
 * Advance **color_cols and return TRUE when there are columns to draw.
 */
static int advance_color_col(int vcol, int **color_cols)
{
  while (**color_cols >= 0 && vcol > **color_cols)
    ++*color_cols;
  return **color_cols >= 0;
}

// Compute the width of the foldcolumn.  Based on 'foldcolumn' and how much
// space is available for window "wp", minus "col".
static int compute_foldcolumn(win_T *wp, int col)
{
  int fdc = wp->w_p_fdc;
  int wmw = wp == curwin && p_wmw == 0 ? 1 : p_wmw;
  int wwidth = wp->w_grid.Columns;

  if (fdc > wwidth - (col + wmw)) {
    fdc = wwidth - (col + wmw);
  }
  return fdc;
}

/// Put a single char from an UTF-8 buffer into a line buffer.
///
/// Handles composing chars and arabic shaping state.
static int line_putchar(LineState *s, schar_T *dest, int maxcells, bool rl)
{
  const char_u *p = s->p;
  int cells = utf_ptr2cells(p);
  int c_len = utfc_ptr2len(p);
  int u8c, u8cc[MAX_MCO];
  if (cells > maxcells) {
    return -1;
  }
  u8c = utfc_ptr2char(p, u8cc);
  if (*p < 0x80 && u8cc[0] == 0) {
    schar_from_ascii(dest[0], *p);
    s->prev_c = u8c;
  } else {
    if (p_arshape && !p_tbidi && arabic_char(u8c)) {
      // Do Arabic shaping.
      int pc, pc1, nc;
      int pcc[MAX_MCO];
      int firstbyte = *p;

      // The idea of what is the previous and next
      // character depends on 'rightleft'.
      if (rl) {
        pc = s->prev_c;
        pc1 = s->prev_c1;
        nc = utf_ptr2char(p + c_len);
        s->prev_c1 = u8cc[0];
      } else {
        pc = utfc_ptr2char(p + c_len, pcc);
        nc = s->prev_c;
        pc1 = pcc[0];
      }
      s->prev_c = u8c;

      u8c = arabic_shape(u8c, &firstbyte, &u8cc[0], pc, pc1, nc);
    } else {
      s->prev_c = u8c;
    }
    schar_from_cc(dest[0], u8c, u8cc);
  }
  if (cells > 1) {
    dest[1][0] = 0;
  }
  s->p += c_len;
  return cells;
}

/*
 * Display one folded line.
 */
static void fold_line(win_T *wp, long fold_count, foldinfo_T *foldinfo, linenr_T lnum, int row)
{
  char_u buf[FOLD_TEXT_LEN];
  pos_T       *top, *bot;
  linenr_T lnume = lnum + fold_count - 1;
  int len;
  char_u      *text;
  int fdc;
  int col;
  int txtcol;
  int off;
  int ri;

  /* Build the fold line:
   * 1. Add the cmdwin_type for the command-line window
   * 2. Add the 'foldcolumn'
   * 3. Add the 'number' or 'relativenumber' column
   * 4. Compose the text
   * 5. Add the text
   * 6. set highlighting for the Visual area an other text
   */
  col = 0;
  off = 0;

  /*
   * 1. Add the cmdwin_type for the command-line window
   * Ignores 'rightleft', this window is never right-left.
   */
  if (cmdwin_type != 0 && wp == curwin) {
    schar_from_ascii(linebuf_char[off], cmdwin_type);
    linebuf_attr[off] = win_hl_attr(wp, HLF_AT);
    col++;
  }

  // 2. Add the 'foldcolumn'
  // Reduce the width when there is not enough space.
  fdc = compute_foldcolumn(wp, col);
  if (fdc > 0) {
    fill_foldcolumn(buf, wp, TRUE, lnum);
    if (wp->w_p_rl) {
      int i;

      copy_text_attr(off + wp->w_grid.Columns - fdc - col, buf, fdc,
                     win_hl_attr(wp, HLF_FC));
      // reverse the fold column
      for (i = 0; i < fdc; i++) {
        schar_from_ascii(linebuf_char[off + wp->w_grid.Columns - i - 1 - col],
                         buf[i]);
      }
    } else {
      copy_text_attr(off + col, buf, fdc, win_hl_attr(wp, HLF_FC));
    }
    col += fdc;
  }

# define RL_MEMSET(p, v, l)  if (wp->w_p_rl) { \
    for (ri = 0; ri < l; ri++) { \
      linebuf_attr[off + (wp->w_grid.Columns - (p) - (l)) + ri] = v; \
    } \
  } else { \
    for (ri = 0; ri < l; ri++) { \
      linebuf_attr[off + (p) + ri] = v; \
    } \
  }

  /* Set all attributes of the 'number' or 'relativenumber' column and the
   * text */
  RL_MEMSET(col, win_hl_attr(wp, HLF_FL), wp->w_grid.Columns - col);

  // If signs are being displayed, add spaces.
  if (win_signcol_count(wp) > 0) {
      len = wp->w_grid.Columns - col;
      if (len > 0) {
          int len_max = win_signcol_width(wp) * win_signcol_count(wp);
          if (len > len_max) {
              len = len_max;
          }
          copy_text_attr(off + col, (char_u *)"  ", len,
                         win_hl_attr(wp, HLF_FL));
          col += len;
      }
  }

  /*
   * 3. Add the 'number' or 'relativenumber' column
   */
  if (wp->w_p_nu || wp->w_p_rnu) {
    len = wp->w_grid.Columns - col;
    if (len > 0) {
      int w = number_width(wp);
      long num;
      char *fmt = "%*ld ";

      if (len > w + 1)
        len = w + 1;

      if (wp->w_p_nu && !wp->w_p_rnu)
        /* 'number' + 'norelativenumber' */
        num = (long)lnum;
      else {
        /* 'relativenumber', don't use negative numbers */
        num = labs((long)get_cursor_rel_lnum(wp, lnum));
        if (num == 0 && wp->w_p_nu && wp->w_p_rnu) {
          /* 'number' + 'relativenumber': cursor line shows absolute
           * line number */
          num = lnum;
          fmt = "%-*ld ";
        }
      }

      snprintf((char *)buf, FOLD_TEXT_LEN, fmt, w, num);
      if (wp->w_p_rl) {
        // the line number isn't reversed
        copy_text_attr(off + wp->w_grid.Columns - len - col, buf, len,
                       win_hl_attr(wp, HLF_FL));
      } else {
        copy_text_attr(off + col, buf, len, win_hl_attr(wp, HLF_FL));
      }
      col += len;
    }
  }

  /*
   * 4. Compose the folded-line string with 'foldtext', if set.
   */
  text = get_foldtext(wp, lnum, lnume, foldinfo, buf);

  txtcol = col;         /* remember where text starts */

  // 5. move the text to linebuf_char[off].  Fill up with "fold".
  //    Right-left text is put in columns 0 - number-col, normal text is put
  //    in columns number-col - window-width.
  int idx;

  if (wp->w_p_rl) {
    idx = off;
  } else {
    idx = off + col;
  }

  LineState s = LINE_STATE(text);

  while (*s.p != NUL) {
    // TODO(bfredl): cargo-culted from the old Vim code:
    // if(col + cells > wp->w_width - (wp->w_p_rl ? col : 0)) { break; }
    // This is obvious wrong. If Vim ever fixes this, solve for "cells" again
    // in the correct condition.
    int maxcells = wp->w_grid.Columns - col - (wp->w_p_rl ? col : 0);
    int cells = line_putchar(&s, &linebuf_char[idx], maxcells, wp->w_p_rl);
    if (cells == -1) {
      break;
    }
    col += cells;
    idx += cells;
  }

  /* Fill the rest of the line with the fold filler */
  if (wp->w_p_rl)
    col -= txtcol;

  schar_T sc;
  schar_from_char(sc, wp->w_p_fcs_chars.fold);
  while (col < wp->w_grid.Columns
         - (wp->w_p_rl ? txtcol : 0)
         ) {
    schar_copy(linebuf_char[off+col++], sc);
  }

  if (text != buf)
    xfree(text);

  /*
   * 6. set highlighting for the Visual area an other text.
   * If all folded lines are in the Visual area, highlight the line.
   */
  if (VIsual_active && wp->w_buffer == curwin->w_buffer) {
    if (ltoreq(curwin->w_cursor, VIsual)) {
      /* Visual is after curwin->w_cursor */
      top = &curwin->w_cursor;
      bot = &VIsual;
    } else {
      /* Visual is before curwin->w_cursor */
      top = &VIsual;
      bot = &curwin->w_cursor;
    }
    if (lnum >= top->lnum
        && lnume <= bot->lnum
        && (VIsual_mode != 'v'
            || ((lnum > top->lnum
                 || (lnum == top->lnum
                     && top->col == 0))
                && (lnume < bot->lnum
                    || (lnume == bot->lnum
                        && (bot->col - (*p_sel == 'e'))
                        >= (colnr_T)STRLEN(ml_get_buf(wp->w_buffer, lnume,
                                FALSE))))))) {
      if (VIsual_mode == Ctrl_V) {
        // Visual block mode: highlight the chars part of the block
        if (wp->w_old_cursor_fcol + txtcol < (colnr_T)wp->w_grid.Columns) {
          if (wp->w_old_cursor_lcol != MAXCOL
              && wp->w_old_cursor_lcol + txtcol
              < (colnr_T)wp->w_grid.Columns) {
            len = wp->w_old_cursor_lcol;
          } else {
            len = wp->w_grid.Columns - txtcol;
          }
          RL_MEMSET(wp->w_old_cursor_fcol + txtcol, win_hl_attr(wp, HLF_V),
                    len - (int)wp->w_old_cursor_fcol);
        }
      } else {
        // Set all attributes of the text
        RL_MEMSET(txtcol, win_hl_attr(wp, HLF_V), wp->w_grid.Columns - txtcol);
      }
    }
  }

  // Show colorcolumn in the fold line, but let cursorcolumn override it.
  if (wp->w_p_cc_cols) {
    int i = 0;
    int j = wp->w_p_cc_cols[i];
    int old_txtcol = txtcol;

    while (j > -1) {
      txtcol += j;
      if (wp->w_p_wrap) {
        txtcol -= wp->w_skipcol;
      } else {
        txtcol -= wp->w_leftcol;
      }
      if (txtcol >= 0 && txtcol < wp->w_grid.Columns) {
        linebuf_attr[off + txtcol] =
          hl_combine_attr(linebuf_attr[off + txtcol], win_hl_attr(wp, HLF_MC));
      }
      txtcol = old_txtcol;
      j = wp->w_p_cc_cols[++i];
    }
  }

  /* Show 'cursorcolumn' in the fold line. */
  if (wp->w_p_cuc) {
    txtcol += wp->w_virtcol;
    if (wp->w_p_wrap)
      txtcol -= wp->w_skipcol;
    else
      txtcol -= wp->w_leftcol;
    if (txtcol >= 0 && txtcol < wp->w_grid.Columns) {
      linebuf_attr[off + txtcol] = hl_combine_attr(
          linebuf_attr[off + txtcol], win_hl_attr(wp, HLF_CUC));
    }
  }

  grid_put_linebuf(&wp->w_grid, row, 0, wp->w_grid.Columns, wp->w_grid.Columns,
                   false, wp, wp->w_hl_attr_normal, false);

  /*
   * Update w_cline_height and w_cline_folded if the cursor line was
   * updated (saves a call to plines() later).
   */
  if (wp == curwin
      && lnum <= curwin->w_cursor.lnum
      && lnume >= curwin->w_cursor.lnum) {
    curwin->w_cline_row = row;
    curwin->w_cline_height = 1;
    curwin->w_cline_folded = true;
    curwin->w_valid |= (VALID_CHEIGHT|VALID_CROW);
    conceal_cursor_used = conceal_cursor_line(curwin);
  }
}


/// Copy "buf[len]" to linebuf_char["off"] and set attributes to "attr".
///
/// Only works for ASCII text!
static void copy_text_attr(int off, char_u *buf, int len, int attr)
{
  int i;

  for (i = 0; i < len; i++) {
    schar_from_ascii(linebuf_char[off + i], buf[i]);
    linebuf_attr[off + i] = attr;
  }
}

/*
 * Fill the foldcolumn at "p" for window "wp".
 * Only to be called when 'foldcolumn' > 0.
 */
static void
fill_foldcolumn (
    char_u *p,
    win_T *wp,
    int closed,                     /* TRUE of FALSE */
    linenr_T lnum                  /* current line number */
)
{
  int i = 0;
  int level;
  int first_level;
  int empty;
  int fdc = compute_foldcolumn(wp, 0);

  // Init to all spaces.
  memset(p, ' ', (size_t)fdc);

  level = win_foldinfo.fi_level;
  if (level > 0) {
    // If there is only one column put more info in it.
    empty = (fdc == 1) ? 0 : 1;

    // If the column is too narrow, we start at the lowest level that
    // fits and use numbers to indicated the depth.
    first_level = level - fdc - closed + 1 + empty;
    if (first_level < 1) {
      first_level = 1;
    }

    for (i = 0; i + empty < fdc; i++) {
      if (win_foldinfo.fi_lnum == lnum
          && first_level + i >= win_foldinfo.fi_low_level) {
        p[i] = '-';
      } else if (first_level == 1) {
        p[i] = '|';
      } else if (first_level + i <= 9) {
        p[i] = '0' + first_level + i;
      } else {
        p[i] = '>';
      }
      if (first_level + i == level) {
        break;
      }
    }
  }
  if (closed) {
    p[i >= fdc ? i - 1 : i] = '+';
  }
}

/*
 * Display line "lnum" of window 'wp' on the screen.
 * Start at row "startrow", stop when "endrow" is reached.
 * wp->w_virtcol needs to be valid.
 *
 * Return the number of last row the line occupies.
 */
static int
win_line (
    win_T *wp,
    linenr_T lnum,
    int startrow,
    int endrow,
    bool nochange,                    // not updating for changed text
    bool number_only                  // only update the number column
)
{
  int c = 0;                          // init for GCC
  long vcol = 0;                      // virtual column (for tabs)
  long vcol_sbr = -1;                 // virtual column after showbreak
  long vcol_prev = -1;                // "vcol" of previous character
  char_u      *line;                  // current line
  char_u      *ptr;                   // current position in "line"
  int row;                            // row in the window, excl w_winrow
  ScreenGrid *grid = &wp->w_grid;     // grid specfic to the window

  char_u extra[18];                   // line number and 'fdc' must fit in here
  int n_extra = 0;                    // number of extra chars
  char_u      *p_extra = NULL;        // string of extra chars, plus NUL
  char_u      *p_extra_free = NULL;   // p_extra needs to be freed
  int c_extra = NUL;                  // extra chars, all the same
  int c_final = NUL;                  // final char, mandatory if set
  int extra_attr = 0;                 // attributes when n_extra != 0
  static char_u *at_end_str = (char_u *)"";  // used for p_extra when displaying
                                             // curwin->w_p_lcs_chars.eol at
                                             // end-of-line
  int lcs_eol_one = wp->w_p_lcs_chars.eol;     // 'eol'  until it's been used
  int lcs_prec_todo = wp->w_p_lcs_chars.prec;  // 'prec' until it's been used

  /* saved "extra" items for when draw_state becomes WL_LINE (again) */
  int saved_n_extra = 0;
  char_u      *saved_p_extra = NULL;
  int saved_c_extra = 0;
  int saved_c_final = 0;
  int saved_char_attr = 0;

  int n_attr = 0;                       /* chars with special attr */
  int saved_attr2 = 0;                  /* char_attr saved for n_attr */
  int n_attr3 = 0;                      /* chars with overruling special attr */
  int saved_attr3 = 0;                  /* char_attr saved for n_attr3 */

  int n_skip = 0;                       /* nr of chars to skip for 'nowrap' */

  int fromcol = 0, tocol = 0;           // start/end of inverting
  int fromcol_prev = -2;                // start of inverting after cursor
  int noinvcur = false;                 // don't invert the cursor
  pos_T *top, *bot;
  int lnum_in_visual_area = false;
  pos_T pos;
  long v;

  int char_attr = 0;                    /* attributes for next character */
  int attr_pri = FALSE;                 /* char_attr has priority */
  int area_highlighting = FALSE;           /* Visual or incsearch highlighting
                                              in this line */
  int attr = 0;                         /* attributes for area highlighting */
  int area_attr = 0;                    /* attributes desired by highlighting */
  int search_attr = 0;                  /* attributes desired by 'hlsearch' */
  int vcol_save_attr = 0;               /* saved attr for 'cursorcolumn' */
  int syntax_attr = 0;                  /* attributes desired by syntax */
  int has_syntax = FALSE;               /* this buffer has syntax highl. */
  int save_did_emsg;
  int eol_hl_off = 0;                   // 1 if highlighted char after EOL
  int draw_color_col = false;           // highlight colorcolumn
  int *color_cols = NULL;               // pointer to according columns array
  bool has_spell = false;               // this buffer has spell checking
# define SPWORDLEN 150
  char_u nextline[SPWORDLEN * 2];       /* text with start of the next line */
  int nextlinecol = 0;                  /* column where nextline[] starts */
  int nextline_idx = 0;                 /* index in nextline[] where next line
                                           starts */
  int spell_attr = 0;                   /* attributes desired by spelling */
  int word_end = 0;                     /* last byte with same spell_attr */
  static linenr_T checked_lnum = 0;     /* line number for "checked_col" */
  static int checked_col = 0;           /* column in "checked_lnum" up to which
                                         * there are no spell errors */
  static int cap_col = -1;              // column to check for Cap word
  static linenr_T capcol_lnum = 0;      // line number where "cap_col"
  int cur_checked_col = 0;              // checked column for current line
  int extra_check = 0;                  // has syntax or linebreak
  int multi_attr = 0;                   // attributes desired by multibyte
  int mb_l = 1;                         // multi-byte byte length
  int mb_c = 0;                         // decoded multi-byte character
  bool mb_utf8 = false;                 // screen char is UTF-8 char
  int u8cc[MAX_MCO];                    // composing UTF-8 chars
  int filler_lines;                     // nr of filler lines to be drawn
  int filler_todo;                      // nr of filler lines still to do + 1
  hlf_T diff_hlf = (hlf_T)0;            // type of diff highlighting
  int change_start = MAXCOL;            // first col of changed area
  int change_end = -1;                  // last col of changed area
  colnr_T trailcol = MAXCOL;            // start of trailing spaces
  int need_showbreak = false;           // overlong line, skip first x chars
  int line_attr = 0;                    // attribute for the whole line
  int line_attr_lowprio = 0;            // low-priority attribute for the line
  matchitem_T *cur;                     // points to the match list
  match_T     *shl;                     // points to search_hl or a match
  int shl_flag;                         // flag to indicate whether search_hl
                                        // has been processed or not
  bool prevcol_hl_flag;                 // flag to indicate whether prevcol
                                        // equals startcol of search_hl or one
                                        // of the matches
  int prev_c = 0;                       // previous Arabic character
  int prev_c1 = 0;                      // first composing char for prev_c

  bool search_attr_from_match = false;  // if search_attr is from :match
  BufhlLineInfo bufhl_info;             // bufhl data for this line
  bool has_bufhl = false;               // this buffer has highlight matches
  bool do_virttext = false;             // draw virtual text for this line

  /* draw_state: items that are drawn in sequence: */
#define WL_START        0               /* nothing done yet */
# define WL_CMDLINE     WL_START + 1    /* cmdline window column */
# define WL_FOLD        WL_CMDLINE + 1  /* 'foldcolumn' */
# define WL_SIGN        WL_FOLD + 1     /* column for signs */
#define WL_NR           WL_SIGN + 1     /* line number */
# define WL_BRI         WL_NR + 1       /* 'breakindent' */
# define WL_SBR         WL_BRI + 1       /* 'showbreak' or 'diff' */
#define WL_LINE         WL_SBR + 1      /* text in the line */
  int draw_state = WL_START;            /* what to draw next */

  int syntax_flags    = 0;
  int syntax_seqnr    = 0;
  int prev_syntax_id  = 0;
  int conceal_attr    = win_hl_attr(wp, HLF_CONCEAL);
  int is_concealing   = false;
  int boguscols       = 0;              ///< nonexistent columns added to
                                        ///< force wrapping
  int vcol_off        = 0;              ///< offset for concealed characters
  int did_wcol        = false;
  int match_conc      = 0;              ///< cchar for match functions
  int old_boguscols = 0;
# define VCOL_HLC (vcol - vcol_off)
# define FIX_FOR_BOGUSCOLS \
  { \
    n_extra += vcol_off; \
    vcol -= vcol_off; \
    vcol_off = 0; \
    col -= boguscols; \
    old_boguscols = boguscols; \
    boguscols = 0; \
  }

  if (startrow > endrow)                /* past the end already! */
    return startrow;

  row = startrow;

  if (!number_only) {
    // To speed up the loop below, set extra_check when there is linebreak,
    // trailing white space and/or syntax processing to be done.
    extra_check = wp->w_p_lbr;
    if (syntax_present(wp) && !wp->w_s->b_syn_error && !wp->w_s->b_syn_slow) {
      // Prepare for syntax highlighting in this line.  When there is an
      // error, stop syntax highlighting.
      save_did_emsg = did_emsg;
      did_emsg = false;
      syntax_start(wp, lnum);
      if (did_emsg) {
        wp->w_s->b_syn_error = true;
      } else {
        did_emsg = save_did_emsg;
        if (!wp->w_s->b_syn_slow) {
          has_syntax = true;
          extra_check = true;
        }
      }
    }

    if (bufhl_start_line(wp->w_buffer, lnum, &bufhl_info)) {
      if (kv_size(bufhl_info.line->items)) {
        has_bufhl = true;
        extra_check = true;
      }
      if (kv_size(bufhl_info.line->virt_text)) {
        do_virttext = true;
      }
    }

    // Check for columns to display for 'colorcolumn'.
    color_cols = wp->w_buffer->terminal ? NULL : wp->w_p_cc_cols;
    if (color_cols != NULL) {
      draw_color_col = advance_color_col(VCOL_HLC, &color_cols);
    }

    if (wp->w_p_spell
        && *wp->w_s->b_p_spl != NUL
        && !GA_EMPTY(&wp->w_s->b_langp)
        && *(char **)(wp->w_s->b_langp.ga_data) != NULL) {
      // Prepare for spell checking.
      has_spell = true;
      extra_check = true;

      // Get the start of the next line, so that words that wrap to the next
      // line are found too: "et<line-break>al.".
      // Trick: skip a few chars for C/shell/Vim comments
      nextline[SPWORDLEN] = NUL;
      if (lnum < wp->w_buffer->b_ml.ml_line_count) {
        line = ml_get_buf(wp->w_buffer, lnum + 1, false);
        spell_cat_line(nextline + SPWORDLEN, line, SPWORDLEN);
      }

      // When a word wrapped from the previous line the start of the current
      // line is valid.
      if (lnum == checked_lnum) {
        cur_checked_col = checked_col;
      }
      checked_lnum = 0;

      // When there was a sentence end in the previous line may require a
      // word starting with capital in this line.  In line 1 always check
      // the first word.
      if (lnum != capcol_lnum) {
        cap_col = -1;
      }
      if (lnum == 1) {
        cap_col = 0;
      }
      capcol_lnum = 0;
    }

    //
    // handle visual active in this window
    //
    fromcol = -10;
    tocol = MAXCOL;
    if (VIsual_active && wp->w_buffer == curwin->w_buffer) {
      // Visual is after curwin->w_cursor
      if (ltoreq(curwin->w_cursor, VIsual)) {
        top = &curwin->w_cursor;
        bot = &VIsual;
      } else {                          // Visual is before curwin->w_cursor
        top = &VIsual;
        bot = &curwin->w_cursor;
      }
      lnum_in_visual_area = (lnum >= top->lnum && lnum <= bot->lnum);
      if (VIsual_mode == Ctrl_V) {        // block mode
        if (lnum_in_visual_area) {
          fromcol = wp->w_old_cursor_fcol;
          tocol = wp->w_old_cursor_lcol;
        }
      } else {                          // non-block mode
        if (lnum > top->lnum && lnum <= bot->lnum) {
          fromcol = 0;
        } else if (lnum == top->lnum) {
          if (VIsual_mode == 'V') {       // linewise
            fromcol = 0;
          } else {
            getvvcol(wp, top, (colnr_T *)&fromcol, NULL, NULL);
            if (gchar_pos(top) == NUL) {
              tocol = fromcol + 1;
            }
          }
        }
        if (VIsual_mode != 'V' && lnum == bot->lnum) {
          if (*p_sel == 'e' && bot->col == 0
              && bot->coladd == 0) {
            fromcol = -10;
            tocol = MAXCOL;
          } else if (bot->col == MAXCOL) {
            tocol = MAXCOL;
          } else {
            pos = *bot;
            if (*p_sel == 'e') {
              getvvcol(wp, &pos, (colnr_T *)&tocol, NULL, NULL);
            } else {
              getvvcol(wp, &pos, NULL, NULL, (colnr_T *)&tocol);
              tocol++;
            }
          }
        }
      }

      // Check if the char under the cursor should be inverted (highlighted).
      if (!highlight_match && lnum == curwin->w_cursor.lnum && wp == curwin
          && cursor_is_block_during_visual(*p_sel == 'e')) {
        noinvcur = true;
      }

      // if inverting in this line set area_highlighting
      if (fromcol >= 0) {
        area_highlighting = true;
        attr = win_hl_attr(wp, HLF_V);
      }
    // handle 'incsearch' and ":s///c" highlighting
    } else if (highlight_match
               && wp == curwin
               && lnum >= curwin->w_cursor.lnum
               && lnum <= curwin->w_cursor.lnum + search_match_lines) {
      if (lnum == curwin->w_cursor.lnum) {
        getvcol(curwin, &(curwin->w_cursor),
                (colnr_T *)&fromcol, NULL, NULL);
      } else {
        fromcol = 0;
      }
      if (lnum == curwin->w_cursor.lnum + search_match_lines) {
        pos.lnum = lnum;
        pos.col = search_match_endcol;
        getvcol(curwin, &pos, (colnr_T *)&tocol, NULL, NULL);
      } else {
        tocol = MAXCOL;
      }
      // do at least one character; happens when past end of line
      if (fromcol == tocol) {
        tocol = fromcol + 1;
      }
      area_highlighting = true;
      attr = win_hl_attr(wp, HLF_I);
    }
  }

  filler_lines = diff_check(wp, lnum);
  if (filler_lines < 0) {
    if (filler_lines == -1) {
      if (diff_find_change(wp, lnum, &change_start, &change_end))
        diff_hlf = HLF_ADD;             /* added line */
      else if (change_start == 0)
        diff_hlf = HLF_TXD;             /* changed text */
      else
        diff_hlf = HLF_CHD;             /* changed line */
    } else
      diff_hlf = HLF_ADD;               /* added line */
    filler_lines = 0;
    area_highlighting = TRUE;
  }
  if (lnum == wp->w_topline)
    filler_lines = wp->w_topfill;
  filler_todo = filler_lines;

  // Cursor line highlighting for 'cursorline' in the current window.
  if (wp->w_p_cul && lnum == wp->w_cursor.lnum) {
    // Do not show the cursor line when Visual mode is active, because it's
    // not clear what is selected then.
    if (!(wp == curwin && VIsual_active)) {
      int cul_attr = win_hl_attr(wp, HLF_CUL);
      HlAttrs ae = syn_attr2entry(cul_attr);

      // We make a compromise here (#7383):
      //  * low-priority CursorLine if fg is not set
      //  * high-priority ("same as Vim" priority) CursorLine if fg is set
      if (ae.rgb_fg_color == -1 && ae.cterm_fg_color == 0) {
        line_attr_lowprio = cul_attr;
      } else {
        if (!(State & INSERT) && bt_quickfix(wp->w_buffer)
            && qf_current_entry(wp) == lnum) {
          line_attr = hl_combine_attr(cul_attr, line_attr);
        } else {
          line_attr = cul_attr;
        }
      }
    }
    // Update w_last_cursorline even if Visual mode is active.
    wp->w_last_cursorline = wp->w_cursor.lnum;
  }

  // If this line has a sign with line highlighting set line_attr.
  v = buf_getsigntype(wp->w_buffer, lnum, SIGN_LINEHL, 0, 1);
  if (v != 0) {
    line_attr = sign_get_attr((int)v, SIGN_LINEHL);
  }

  // Highlight the current line in the quickfix window.
  if (bt_quickfix(wp->w_buffer) && qf_current_entry(wp) == lnum) {
    line_attr = win_hl_attr(wp, HLF_QFL);
  }

  if (line_attr_lowprio || line_attr) {
    area_highlighting = true;
  }

  line = ml_get_buf(wp->w_buffer, lnum, FALSE);
  ptr = line;

  if (has_spell && !number_only) {
    // For checking first word with a capital skip white space.
    if (cap_col == 0) {
      cap_col = (int)getwhitecols(line);
    }

    /* To be able to spell-check over line boundaries copy the end of the
     * current line into nextline[].  Above the start of the next line was
     * copied to nextline[SPWORDLEN]. */
    if (nextline[SPWORDLEN] == NUL) {
      /* No next line or it is empty. */
      nextlinecol = MAXCOL;
      nextline_idx = 0;
    } else {
      v = (long)STRLEN(line);
      if (v < SPWORDLEN) {
        /* Short line, use it completely and append the start of the
         * next line. */
        nextlinecol = 0;
        memmove(nextline, line, (size_t)v);
        STRMOVE(nextline + v, nextline + SPWORDLEN);
        nextline_idx = v + 1;
      } else {
        /* Long line, use only the last SPWORDLEN bytes. */
        nextlinecol = v - SPWORDLEN;
        memmove(nextline, line + nextlinecol, SPWORDLEN);  // -V512
        nextline_idx = SPWORDLEN + 1;
      }
    }
  }

  if (wp->w_p_list) {
    if (curwin->w_p_lcs_chars.space
        || wp->w_p_lcs_chars.trail
        || wp->w_p_lcs_chars.nbsp) {
      extra_check = true;
    }
    // find start of trailing whitespace
    if (wp->w_p_lcs_chars.trail) {
      trailcol = (colnr_T)STRLEN(ptr);
      while (trailcol > (colnr_T)0 && ascii_iswhite(ptr[trailcol - 1])) {
        trailcol--;
      }
      trailcol += (colnr_T) (ptr - line);
    }
  }

  /*
   * 'nowrap' or 'wrap' and a single line that doesn't fit: Advance to the
   * first character to be displayed.
   */
  if (wp->w_p_wrap)
    v = wp->w_skipcol;
  else
    v = wp->w_leftcol;
  if (v > 0 && !number_only) {
    char_u  *prev_ptr = ptr;
    while (vcol < v && *ptr != NUL) {
      c = win_lbr_chartabsize(wp, line, ptr, (colnr_T)vcol, NULL);
      vcol += c;
      prev_ptr = ptr;
      MB_PTR_ADV(ptr);
    }

    // When:
    // - 'cuc' is set, or
    // - 'colorcolumn' is set, or
    // - 'virtualedit' is set, or
    // - the visual mode is active,
    // the end of the line may be before the start of the displayed part.
    if (vcol < v && (wp->w_p_cuc
                     || draw_color_col
                     || virtual_active()
                     || (VIsual_active && wp->w_buffer == curwin->w_buffer))) {
      vcol = v;
    }

    /* Handle a character that's not completely on the screen: Put ptr at
     * that character but skip the first few screen characters. */
    if (vcol > v) {
      vcol -= c;
      ptr = prev_ptr;
      // If the character fits on the screen, don't need to skip it.
      // Except for a TAB.
      if (utf_ptr2cells(ptr) >= c || *ptr == TAB) {
        n_skip = v - vcol;
      }
    }

    /*
     * Adjust for when the inverted text is before the screen,
     * and when the start of the inverted text is before the screen.
     */
    if (tocol <= vcol)
      fromcol = 0;
    else if (fromcol >= 0 && fromcol < vcol)
      fromcol = vcol;

    /* When w_skipcol is non-zero, first line needs 'showbreak' */
    if (wp->w_p_wrap)
      need_showbreak = TRUE;
    /* When spell checking a word we need to figure out the start of the
     * word and if it's badly spelled or not. */
    if (has_spell) {
      size_t len;
      colnr_T linecol = (colnr_T)(ptr - line);
      hlf_T spell_hlf = HLF_COUNT;

      pos = wp->w_cursor;
      wp->w_cursor.lnum = lnum;
      wp->w_cursor.col = linecol;
      len = spell_move_to(wp, FORWARD, TRUE, TRUE, &spell_hlf);

      /* spell_move_to() may call ml_get() and make "line" invalid */
      line = ml_get_buf(wp->w_buffer, lnum, FALSE);
      ptr = line + linecol;

      if (len == 0 || (int)wp->w_cursor.col > ptr - line) {
        /* no bad word found at line start, don't check until end of a
         * word */
        spell_hlf = HLF_COUNT;
        word_end = (int)(spell_to_word_end(ptr, wp) - line + 1);
      } else {
        /* bad word found, use attributes until end of word */
        assert(len <= INT_MAX);
        word_end = wp->w_cursor.col + (int)len + 1;

        /* Turn index into actual attributes. */
        if (spell_hlf != HLF_COUNT)
          spell_attr = highlight_attr[spell_hlf];
      }
      wp->w_cursor = pos;

      // Need to restart syntax highlighting for this line.
      if (has_syntax) {
        syntax_start(wp, lnum);
      }
    }
  }

  /*
   * Correct highlighting for cursor that can't be disabled.
   * Avoids having to check this for each character.
   */
  if (fromcol >= 0) {
    if (noinvcur) {
      if ((colnr_T)fromcol == wp->w_virtcol) {
        /* highlighting starts at cursor, let it start just after the
         * cursor */
        fromcol_prev = fromcol;
        fromcol = -1;
      } else if ((colnr_T)fromcol < wp->w_virtcol)
        /* restart highlighting after the cursor */
        fromcol_prev = wp->w_virtcol;
    }
    if (fromcol >= tocol)
      fromcol = -1;
  }

  /*
   * Handle highlighting the last used search pattern and matches.
   * Do this for both search_hl and the match list.
   */
  cur = wp->w_match_head;
  shl_flag = false;
  while ((cur != NULL || !shl_flag) && !number_only) {
    if (!shl_flag) {
      shl = &search_hl;
      shl_flag = true;
    } else {
      shl = &cur->hl;  // -V595
    }
    shl->startcol = MAXCOL;
    shl->endcol = MAXCOL;
    shl->attr_cur = 0;
    shl->is_addpos = false;
    v = (long)(ptr - line);
    if (cur != NULL) {
      cur->pos.cur = 0;
    }
    next_search_hl(wp, shl, lnum, (colnr_T)v,
                   shl == &search_hl ? NULL : cur);
    if (wp->w_s->b_syn_slow) {
      has_syntax = false;
    }

    // Need to get the line again, a multi-line regexp may have made it
    // invalid.
    line = ml_get_buf(wp->w_buffer, lnum, false);
    ptr = line + v;

    if (shl->lnum != 0 && shl->lnum <= lnum) {
      if (shl->lnum == lnum) {
        shl->startcol = shl->rm.startpos[0].col;
      } else {
        shl->startcol = 0;
      }
      if (lnum == shl->lnum + shl->rm.endpos[0].lnum
                  - shl->rm.startpos[0].lnum) {
          shl->endcol = shl->rm.endpos[0].col;
      } else {
          shl->endcol = MAXCOL;
      }
      // Highlight one character for an empty match.
      if (shl->startcol == shl->endcol) {
          if (line[shl->endcol] != NUL) {
              shl->endcol += (*mb_ptr2len)(line + shl->endcol);
          } else {
              ++shl->endcol;
          }
      }
      if ((long)shl->startcol < v) {   // match at leftcol
        shl->attr_cur = shl->attr;
        search_attr = shl->attr;
        search_attr_from_match = shl != &search_hl;
      }
      area_highlighting = true;
    }
    if (shl != &search_hl && cur != NULL)
      cur = cur->next;
  }

  unsigned off = 0;  // Offset relative start of line
  int col = 0;  // Visual column on screen.
  if (wp->w_p_rl) {
    // Rightleft window: process the text in the normal direction, but put
    // it in linebuf_char[off] from right to left.  Start at the
    // rightmost column of the window.
    col = grid->Columns - 1;
    off += col;
  }

  // wont highlight after 1024 columns
  int term_attrs[1024] = {0};
  if (wp->w_buffer->terminal) {
    terminal_get_line_attributes(wp->w_buffer->terminal, wp, lnum, term_attrs);
    extra_check = true;
  }

  int sign_idx = 0;
  // Repeat for the whole displayed line.
  for (;; ) {
    int has_match_conc = 0;  ///< match wants to conceal
    bool did_decrement_ptr = false;
    // Skip this quickly when working on the text.
    if (draw_state != WL_LINE) {
      if (draw_state == WL_CMDLINE - 1 && n_extra == 0) {
        draw_state = WL_CMDLINE;
        if (cmdwin_type != 0 && wp == curwin) {
          /* Draw the cmdline character. */
          n_extra = 1;
          c_extra = cmdwin_type;
          c_final = NUL;
          char_attr = win_hl_attr(wp, HLF_AT);
        }
      }

      if (draw_state == WL_FOLD - 1 && n_extra == 0) {
        int fdc = compute_foldcolumn(wp, 0);

        draw_state = WL_FOLD;
        if (fdc > 0) {
          // Draw the 'foldcolumn'.  Allocate a buffer, "extra" may
          // already be in use.
          xfree(p_extra_free);
          p_extra_free = xmalloc(12 + 1);
          fill_foldcolumn(p_extra_free, wp, false, lnum);
          n_extra = fdc;
          p_extra_free[n_extra] = NUL;
          p_extra = p_extra_free;
          c_extra = NUL;
          c_final = NUL;
          char_attr = win_hl_attr(wp, HLF_FC);
        }
      }

      //sign column
      if (draw_state == WL_SIGN - 1 && n_extra == 0) {
          draw_state = WL_SIGN;
          /* Show the sign column when there are any signs in this
           * buffer or when using Netbeans. */
          int count = win_signcol_count(wp);
          if (count > 0) {
              int text_sign;
              // Draw cells with the sign value or blank.
              c_extra = ' ';
              c_final = NUL;
              char_attr = win_hl_attr(wp, HLF_SC);
              n_extra = win_signcol_width(wp);

              if (row == startrow + filler_lines && filler_todo <= 0) {
                  text_sign = buf_getsigntype(wp->w_buffer, lnum, SIGN_TEXT,
                                              sign_idx, count);
                  if (text_sign != 0) {
                      p_extra = sign_get_text(text_sign);
                      int symbol_blen = (int)STRLEN(p_extra);
                      if (p_extra != NULL) {
                          c_extra = NUL;
                          c_final = NUL;
                          // symbol(s) bytes + (filling spaces) (one byte each)
                          n_extra = symbol_blen +
                            (win_signcol_width(wp) - mb_string2cells(p_extra));
                          memset(extra, ' ', sizeof(extra));
                          STRNCPY(extra, p_extra, STRLEN(p_extra));
                          p_extra = extra;
                          p_extra[n_extra] = NUL;
                      }
                      char_attr = sign_get_attr(text_sign, SIGN_TEXT);
                  }
              }

              sign_idx++;
              if (sign_idx < count) {
                  draw_state = WL_SIGN - 1;
              }
          }
      }

      if (draw_state == WL_NR - 1 && n_extra == 0) {
        draw_state = WL_NR;
        /* Display the absolute or relative line number. After the
         * first fill with blanks when the 'n' flag isn't in 'cpo' */
        if ((wp->w_p_nu || wp->w_p_rnu)
            && (row == startrow
                + filler_lines
                || vim_strchr(p_cpo, CPO_NUMCOL) == NULL)) {
          /* Draw the line number (empty space after wrapping). */
          if (row == startrow
              + filler_lines
              ) {
            long num;
            char *fmt = "%*ld ";

            if (wp->w_p_nu && !wp->w_p_rnu)
              /* 'number' + 'norelativenumber' */
              num = (long)lnum;
            else {
              /* 'relativenumber', don't use negative numbers */
              num = labs((long)get_cursor_rel_lnum(wp, lnum));
              if (num == 0 && wp->w_p_nu && wp->w_p_rnu) {
                /* 'number' + 'relativenumber' */
                num = lnum;
                fmt = "%-*ld ";
              }
            }

            sprintf((char *)extra, fmt,
                number_width(wp), num);
            if (wp->w_skipcol > 0)
              for (p_extra = extra; *p_extra == ' '; ++p_extra)
                *p_extra = '-';
            if (wp->w_p_rl) {                       // reverse line numbers
              // like rl_mirror(), but keep the space at the end
              char_u *p2 = skiptowhite(extra) - 1;
              for (char_u *p1 = extra; p1 < p2; p1++, p2--) {
                const int t = *p1;
                *p1 = *p2;
                *p2 = t;
              }
            }
            p_extra = extra;
            c_extra = NUL;
            c_final = NUL;
          } else {
            c_extra = ' ';
            c_final = NUL;
          }
          n_extra = number_width(wp) + 1;
          char_attr = win_hl_attr(wp, HLF_N);

          int num_sign = buf_getsigntype(wp->w_buffer, lnum, SIGN_NUMHL,
                                         0, 1);
          if (num_sign != 0) {
            // :sign defined with "numhl" highlight.
            char_attr = sign_get_attr(num_sign, SIGN_NUMHL);
          } else if ((wp->w_p_cul || wp->w_p_rnu)
                     && lnum == wp->w_cursor.lnum) {
            // When 'cursorline' is set highlight the line number of
            // the current line differently.
            // TODO(vim): Can we use CursorLine instead of CursorLineNr
            // when CursorLineNr isn't set?
            char_attr = win_hl_attr(wp, HLF_CLN);
          }
        }
      }

      if (wp->w_p_brisbr && draw_state == WL_BRI - 1
          && n_extra == 0 && *p_sbr != NUL) {
        // draw indent after showbreak value
        draw_state = WL_BRI;
      } else if (wp->w_p_brisbr && draw_state == WL_SBR && n_extra == 0) {
        // after the showbreak, draw the breakindent
        draw_state = WL_BRI - 1;
      }

      // draw 'breakindent': indent wrapped text accordingly
      if (draw_state == WL_BRI - 1 && n_extra == 0) {
        draw_state = WL_BRI;
        // if need_showbreak is set, breakindent also applies
        if (wp->w_p_bri && (row != startrow || need_showbreak)
            && filler_lines == 0) {
          char_attr = 0;

          if (diff_hlf != (hlf_T)0) {
            char_attr = win_hl_attr(wp, diff_hlf);
            if (wp->w_p_cul && lnum == wp->w_cursor.lnum) {
              char_attr = hl_combine_attr(char_attr, win_hl_attr(wp, HLF_CUL));
            }
          }
          p_extra = NULL;
          c_extra = ' ';
          n_extra = get_breakindent_win(wp, ml_get_buf(wp->w_buffer, lnum, FALSE));
          /* Correct end of highlighted area for 'breakindent',
             required wen 'linebreak' is also set. */
          if (tocol == vcol)
            tocol += n_extra;
        }
      }

      if (draw_state == WL_SBR - 1 && n_extra == 0) {
        draw_state = WL_SBR;
        if (filler_todo > 0) {
          // draw "deleted" diff line(s)
          if (char2cells(wp->w_p_fcs_chars.diff) > 1) {
            c_extra = '-';
            c_final = NUL;
          } else {
            c_extra = wp->w_p_fcs_chars.diff;
            c_final = NUL;
          }
          if (wp->w_p_rl) {
            n_extra = col + 1;
          } else {
            n_extra = grid->Columns - col;
          }
          char_attr = win_hl_attr(wp, HLF_DED);
        }
        if (*p_sbr != NUL && need_showbreak) {
          /* Draw 'showbreak' at the start of each broken line. */
          p_extra = p_sbr;
          c_extra = NUL;
          c_final = NUL;
          n_extra = (int)STRLEN(p_sbr);
          char_attr = win_hl_attr(wp, HLF_AT);
          need_showbreak = false;
          vcol_sbr = vcol + MB_CHARLEN(p_sbr);
          /* Correct end of highlighted area for 'showbreak',
           * required when 'linebreak' is also set. */
          if (tocol == vcol)
            tocol += n_extra;
          /* combine 'showbreak' with 'cursorline' */
          if (wp->w_p_cul && lnum == wp->w_cursor.lnum) {
            char_attr = hl_combine_attr(char_attr, win_hl_attr(wp, HLF_CUL));
          }
        }
      }

      if (draw_state == WL_LINE - 1 && n_extra == 0) {
        sign_idx = 0;
        draw_state = WL_LINE;
        if (saved_n_extra) {
          /* Continue item from end of wrapped line. */
          n_extra = saved_n_extra;
          c_extra = saved_c_extra;
          c_final = saved_c_final;
          p_extra = saved_p_extra;
          char_attr = saved_char_attr;
        } else {
          char_attr = 0;
        }
      }
    }

    // When still displaying '$' of change command, stop at cursor
    if ((dollar_vcol >= 0 && wp == curwin
         && lnum == wp->w_cursor.lnum && vcol >= (long)wp->w_virtcol
         && filler_todo <= 0)
        || (number_only && draw_state > WL_NR)) {
      grid_put_linebuf(grid, row, 0, col, -grid->Columns, wp->w_p_rl, wp,
                       wp->w_hl_attr_normal, false);
      // Pretend we have finished updating the window.  Except when
      // 'cursorcolumn' is set.
      if (wp->w_p_cuc) {
        row = wp->w_cline_row + wp->w_cline_height;
      } else {
        row = grid->Rows;
      }
      break;
    }

    if (draw_state == WL_LINE && (area_highlighting || has_spell)) {
      // handle Visual or match highlighting in this line
      if (vcol == fromcol
          || (vcol + 1 == fromcol && n_extra == 0
              && utf_ptr2cells(ptr) > 1)
          || ((int)vcol_prev == fromcol_prev
              && vcol_prev < vcol               // not at margin
              && vcol < tocol)) {
        area_attr = attr;                       // start highlighting
      } else if (area_attr != 0 && (vcol == tocol
                                    || (noinvcur
                                        && (colnr_T)vcol == wp->w_virtcol))) {
        area_attr = 0;                          // stop highlighting
     }

      if (!n_extra) {
        /*
         * Check for start/end of search pattern match.
         * After end, check for start/end of next match.
         * When another match, have to check for start again.
         * Watch out for matching an empty string!
         * Do this for 'search_hl' and the match list (ordered by
         * priority).
         */
        v = (long)(ptr - line);
        cur = wp->w_match_head;
        shl_flag = FALSE;
        while (cur != NULL || shl_flag == FALSE) {
          if (shl_flag == FALSE
              && ((cur != NULL
                   && cur->priority > SEARCH_HL_PRIORITY)
                  || cur == NULL)) {
            shl = &search_hl;
            shl_flag = TRUE;
          } else
            shl = &cur->hl;
          if (cur != NULL) {
            cur->pos.cur = 0;
          }
          bool pos_inprogress = true; // mark that a position match search is
                                      // in progress
          while (shl->rm.regprog != NULL
                                 || (cur != NULL && pos_inprogress)) {
            if (shl->startcol != MAXCOL
                && v >= (long)shl->startcol
                && v < (long)shl->endcol) {
              int tmp_col = v + MB_PTR2LEN(ptr);

              if (shl->endcol < tmp_col) {
                shl->endcol = tmp_col;
              }
              shl->attr_cur = shl->attr;
              // Match with the "Conceal" group results in hiding
              // the match.
              if (cur != NULL
                  && shl != &search_hl
                  && syn_name2id((char_u *)"Conceal") == cur->hlg_id) {
                has_match_conc = v == (long)shl->startcol ? 2 : 1;
                match_conc = cur->conceal_char;
              } else {
                has_match_conc = match_conc = 0;
              }
            } else if (v == (long)shl->endcol) {
              shl->attr_cur = 0;

              next_search_hl(wp, shl, lnum, (colnr_T)v,
                             shl == &search_hl ? NULL : cur);
              pos_inprogress = !(cur == NULL || cur->pos.cur == 0);

              /* Need to get the line again, a multi-line regexp
               * may have made it invalid. */
              line = ml_get_buf(wp->w_buffer, lnum, FALSE);
              ptr = line + v;

              if (shl->lnum == lnum) {
                shl->startcol = shl->rm.startpos[0].col;
                if (shl->rm.endpos[0].lnum == 0)
                  shl->endcol = shl->rm.endpos[0].col;
                else
                  shl->endcol = MAXCOL;

                if (shl->startcol == shl->endcol) {
                  // highlight empty match, try again after it
                  shl->endcol += (*mb_ptr2len)(line + shl->endcol);
                }

                /* Loop to check if the match starts at the
                 * current position */
                continue;
              }
            }
            break;
          }
          if (shl != &search_hl && cur != NULL)
            cur = cur->next;
        }

        /* Use attributes from match with highest priority among
         * 'search_hl' and the match list. */
        search_attr_from_match = false;
        search_attr = search_hl.attr_cur;
        cur = wp->w_match_head;
        shl_flag = FALSE;
        while (cur != NULL || shl_flag == FALSE) {
          if (shl_flag == FALSE
              && ((cur != NULL
                   && cur->priority > SEARCH_HL_PRIORITY)
                  || cur == NULL)) {
            shl = &search_hl;
            shl_flag = TRUE;
          } else
            shl = &cur->hl;
          if (shl->attr_cur != 0) {
            search_attr = shl->attr_cur;
            search_attr_from_match = shl != &search_hl;
          }
          if (shl != &search_hl && cur != NULL)
            cur = cur->next;
        }
        // Only highlight one character after the last column.
        if (*ptr == NUL
            && (wp->w_p_list && lcs_eol_one == -1)) {
          search_attr = 0;
        }
      }

      if (diff_hlf != (hlf_T)0) {
        if (diff_hlf == HLF_CHD && ptr - line >= change_start
            && n_extra == 0) {
          diff_hlf = HLF_TXD;                   // changed text
        }
        if (diff_hlf == HLF_TXD && ptr - line > change_end
            && n_extra == 0) {
          diff_hlf = HLF_CHD;                   // changed line
        }
        line_attr = win_hl_attr(wp, diff_hlf);
        // Overlay CursorLine onto diff-mode highlight.
        if (wp->w_p_cul && lnum == wp->w_cursor.lnum) {
          line_attr = 0 != line_attr_lowprio  // Low-priority CursorLine
            ? hl_combine_attr(hl_combine_attr(win_hl_attr(wp, HLF_CUL),
                                              line_attr),
                              hl_get_underline())
            : hl_combine_attr(line_attr, win_hl_attr(wp, HLF_CUL));
        }
      }

      // Decide which of the highlight attributes to use.
      attr_pri = true;

      if (area_attr != 0) {
        char_attr = hl_combine_attr(line_attr, area_attr);
      } else if (search_attr != 0) {
        char_attr = hl_combine_attr(line_attr, search_attr);
      }
      // Use line_attr when not in the Visual or 'incsearch' area
      // (area_attr may be 0 when "noinvcur" is set).
      else if (line_attr != 0 && ((fromcol == -10 && tocol == MAXCOL)
                                  || vcol < fromcol || vcol_prev < fromcol_prev
                                  || vcol >= tocol)) {
        char_attr = line_attr;
    } else {
        attr_pri = false;
        if (has_syntax) {
          char_attr = syntax_attr;
        } else {
          char_attr = 0;
        }
      }
    }

    // Get the next character to put on the screen.
    //
    // The "p_extra" points to the extra stuff that is inserted to
    // represent special characters (non-printable stuff) and other
    // things.  When all characters are the same, c_extra is used.
    // If c_final is set, it will compulsorily be used at the end.
    // "p_extra" must end in a NUL to avoid mb_ptr2len() reads past
    // "p_extra[n_extra]".
    // For the '$' of the 'list' option, n_extra == 1, p_extra == "".
    if (n_extra > 0) {
      if (c_extra != NUL || (n_extra == 1 && c_final != NUL)) {
        c = (n_extra == 1 && c_final != NUL) ? c_final : c_extra;
        mb_c = c;               // doesn't handle non-utf-8 multi-byte!
        if (utf_char2len(c) > 1) {
          mb_utf8 = true;
          u8cc[0] = 0;
          c = 0xc0;
        } else {
          mb_utf8 = false;
        }
      } else {
        c = *p_extra;
        mb_c = c;
        // If the UTF-8 character is more than one byte:
        // Decode it into "mb_c".
        mb_l = utfc_ptr2len(p_extra);
        mb_utf8 = false;
        if (mb_l > n_extra) {
          mb_l = 1;
        } else if (mb_l > 1) {
          mb_c = utfc_ptr2char(p_extra, u8cc);
          mb_utf8 = true;
          c = 0xc0;
        }
        if (mb_l == 0) {          // at the NUL at end-of-line
          mb_l = 1;
        }

        // If a double-width char doesn't fit display a '>' in the last column.
        if ((wp->w_p_rl ? (col <= 0) : (col >= grid->Columns - 1))
            && (*mb_char2cells)(mb_c) == 2) {
          c = '>';
          mb_c = c;
          mb_l = 1;
          mb_utf8 = false;
          multi_attr = win_hl_attr(wp, HLF_AT);

          // put the pointer back to output the double-width
          // character at the start of the next line.
          n_extra++;
          p_extra--;
        } else {
          n_extra -= mb_l - 1;
          p_extra += mb_l - 1;
        }
        ++p_extra;
      }
      --n_extra;
    } else {
      int c0;

      if (p_extra_free != NULL) {
        XFREE_CLEAR(p_extra_free);
      }

      // Get a character from the line itself.
      c0 = c = *ptr;
      mb_c = c;
      // If the UTF-8 character is more than one byte: Decode it
      // into "mb_c".
      mb_l = utfc_ptr2len(ptr);
      mb_utf8 = false;
      if (mb_l > 1) {
        mb_c = utfc_ptr2char(ptr, u8cc);
        // Overlong encoded ASCII or ASCII with composing char
        // is displayed normally, except a NUL.
        if (mb_c < 0x80) {
          c0 = c = mb_c;
        }
        mb_utf8 = true;

        // At start of the line we can have a composing char.
        // Draw it as a space with a composing char.
        if (utf_iscomposing(mb_c)) {
          int i;

          for (i = MAX_MCO - 1; i > 0; i--) {
            u8cc[i] = u8cc[i - 1];
          }
          u8cc[0] = mb_c;
          mb_c = ' ';
        }
      }

      if ((mb_l == 1 && c >= 0x80)
          || (mb_l >= 1 && mb_c == 0)
          || (mb_l > 1 && (!vim_isprintc(mb_c)))) {
        // Illegal UTF-8 byte: display as <xx>.
        // Non-BMP character : display as ? or fullwidth ?.
        transchar_hex((char *)extra, mb_c);
        if (wp->w_p_rl) {  // reverse
          rl_mirror(extra);
        }

        p_extra = extra;
        c = *p_extra;
        mb_c = mb_ptr2char_adv((const char_u **)&p_extra);
        mb_utf8 = (c >= 0x80);
        n_extra = (int)STRLEN(p_extra);
        c_extra = NUL;
        c_final = NUL;
        if (area_attr == 0 && search_attr == 0) {
          n_attr = n_extra + 1;
          extra_attr = win_hl_attr(wp, HLF_8);
          saved_attr2 = char_attr;               // save current attr
        }
      } else if (mb_l == 0) {        // at the NUL at end-of-line
        mb_l = 1;
      } else if (p_arshape && !p_tbidi && arabic_char(mb_c)) {
        // Do Arabic shaping.
        int pc, pc1, nc;
        int pcc[MAX_MCO];

        // The idea of what is the previous and next
        // character depends on 'rightleft'.
        if (wp->w_p_rl) {
          pc = prev_c;
          pc1 = prev_c1;
          nc = utf_ptr2char(ptr + mb_l);
          prev_c1 = u8cc[0];
        } else {
          pc = utfc_ptr2char(ptr + mb_l, pcc);
          nc = prev_c;
          pc1 = pcc[0];
        }
        prev_c = mb_c;

        mb_c = arabic_shape(mb_c, &c, &u8cc[0], pc, pc1, nc);
      } else {
        prev_c = mb_c;
      }
      // If a double-width char doesn't fit display a '>' in the
      // last column; the character is displayed at the start of the
      // next line.
      if ((wp->w_p_rl ? (col <= 0) :
           (col >= grid->Columns - 1))
          && (*mb_char2cells)(mb_c) == 2) {
        c = '>';
        mb_c = c;
        mb_utf8 = false;
        mb_l = 1;
        multi_attr = win_hl_attr(wp, HLF_AT);
        // Put pointer back so that the character will be
        // displayed at the start of the next line.
        ptr--;
        did_decrement_ptr = true;
      } else if (*ptr != NUL) {
        ptr += mb_l - 1;
      }

      // If a double-width char doesn't fit at the left side display a '<' in
      // the first column.  Don't do this for unprintable characters.
      if (n_skip > 0 && mb_l > 1 && n_extra == 0) {
        n_extra = 1;
        c_extra = MB_FILLER_CHAR;
        c_final = NUL;
        c = ' ';
        if (area_attr == 0 && search_attr == 0) {
          n_attr = n_extra + 1;
          extra_attr = win_hl_attr(wp, HLF_AT);
          saved_attr2 = char_attr;             // save current attr
        }
        mb_c = c;
        mb_utf8 = false;
        mb_l = 1;
      }
      ptr++;

      if (extra_check) {
        bool can_spell = true;

        /* Get syntax attribute, unless still at the start of the line
         * (double-wide char that doesn't fit). */
        v = (long)(ptr - line);
        if (has_syntax && v > 0) {
          /* Get the syntax attribute for the character.  If there
           * is an error, disable syntax highlighting. */
          save_did_emsg = did_emsg;
          did_emsg = FALSE;

          syntax_attr = get_syntax_attr((colnr_T)v - 1,
                                        has_spell ? &can_spell : NULL, false);

          if (did_emsg) {
            wp->w_s->b_syn_error = TRUE;
            has_syntax = FALSE;
          } else
            did_emsg = save_did_emsg;

          /* Need to get the line again, a multi-line regexp may
           * have made it invalid. */
          line = ml_get_buf(wp->w_buffer, lnum, FALSE);
          ptr = line + v;

          if (!attr_pri) {
            char_attr = syntax_attr;
          } else {
            char_attr = hl_combine_attr(syntax_attr, char_attr);
          }
          // no concealing past the end of the line, it interferes
          // with line highlighting.
          if (c == NUL) {
            syntax_flags = 0;
          } else {
            syntax_flags = get_syntax_info(&syntax_seqnr);
          }
        } else if (!attr_pri) {
          char_attr = 0;
        }

        /* Check spelling (unless at the end of the line).
         * Only do this when there is no syntax highlighting, the
         * @Spell cluster is not used or the current syntax item
         * contains the @Spell cluster. */
        if (has_spell && v >= word_end && v > cur_checked_col) {
          spell_attr = 0;
          if (!attr_pri) {
            char_attr = syntax_attr;
          }
          if (c != 0 && (!has_syntax || can_spell)) {
            char_u *prev_ptr;
            char_u *p;
            int len;
            hlf_T spell_hlf = HLF_COUNT;
            prev_ptr = ptr - mb_l;
            v -= mb_l - 1;

            /* Use nextline[] if possible, it has the start of the
             * next line concatenated. */
            if ((prev_ptr - line) - nextlinecol >= 0) {
              p = nextline + ((prev_ptr - line) - nextlinecol);
            } else {
              p = prev_ptr;
            }
            cap_col -= (int)(prev_ptr - line);
            size_t tmplen = spell_check(wp, p, &spell_hlf, &cap_col, nochange);
            assert(tmplen <= INT_MAX);
            len = (int)tmplen;
            word_end = v + len;

            /* In Insert mode only highlight a word that
             * doesn't touch the cursor. */
            if (spell_hlf != HLF_COUNT
                && (State & INSERT) != 0
                && wp->w_cursor.lnum == lnum
                && wp->w_cursor.col >=
                (colnr_T)(prev_ptr - line)
                && wp->w_cursor.col < (colnr_T)word_end) {
              spell_hlf = HLF_COUNT;
              spell_redraw_lnum = lnum;
            }

            if (spell_hlf == HLF_COUNT && p != prev_ptr
                && (p - nextline) + len > nextline_idx) {
              /* Remember that the good word continues at the
               * start of the next line. */
              checked_lnum = lnum + 1;
              checked_col = (int)((p - nextline) + len - nextline_idx);
            }

            /* Turn index into actual attributes. */
            if (spell_hlf != HLF_COUNT)
              spell_attr = highlight_attr[spell_hlf];

            if (cap_col > 0) {
              if (p != prev_ptr
                  && (p - nextline) + cap_col >= nextline_idx) {
                /* Remember that the word in the next line
                 * must start with a capital. */
                capcol_lnum = lnum + 1;
                cap_col = (int)((p - nextline) + cap_col
                                - nextline_idx);
              } else
                /* Compute the actual column. */
                cap_col += (int)(prev_ptr - line);
            }
          }
        }
        if (spell_attr != 0) {
          if (!attr_pri)
            char_attr = hl_combine_attr(char_attr, spell_attr);
          else
            char_attr = hl_combine_attr(spell_attr, char_attr);
        }

        if (has_bufhl && v > 0) {
          int bufhl_attr = bufhl_get_attr(&bufhl_info, (colnr_T)v);
          if (bufhl_attr != 0) {
            if (!attr_pri) {
              char_attr = hl_combine_attr(char_attr, bufhl_attr);
            } else {
              char_attr = hl_combine_attr(bufhl_attr, char_attr);
            }
          }
        }

        if (wp->w_buffer->terminal) {
          char_attr = hl_combine_attr(term_attrs[vcol], char_attr);
        }

        // Found last space before word: check for line break.
        if (wp->w_p_lbr && c0 == c && vim_isbreak(c)
            && !vim_isbreak((int)(*ptr))) {
          int mb_off = utf_head_off(line, ptr - 1);
          char_u *p = ptr - (mb_off + 1);
          // TODO: is passing p for start of the line OK?
          n_extra = win_lbr_chartabsize(wp, line, p, (colnr_T)vcol, NULL) - 1;
          if (c == TAB && n_extra + col > grid->Columns) {
            n_extra = (int)wp->w_buffer->b_p_ts
                      - vcol % (int)wp->w_buffer->b_p_ts - 1;
          }
          c_extra = mb_off > 0 ? MB_FILLER_CHAR : ' ';
          c_final = NUL;
          if (ascii_iswhite(c)) {
            if (c == TAB)
              /* See "Tab alignment" below. */
              FIX_FOR_BOGUSCOLS;
            if (!wp->w_p_list) {
              c = ' ';
            }
          }
        }

        // 'list': change char 160 to 'nbsp' and space to 'space'.
        if (wp->w_p_list
            && (((c == 160
                  || (mb_utf8 && (mb_c == 160 || mb_c == 0x202f)))
                 && curwin->w_p_lcs_chars.nbsp)
                || (c == ' ' && curwin->w_p_lcs_chars.space
                    && ptr - line <= trailcol))) {
          c = (c == ' ') ? wp->w_p_lcs_chars.space : wp->w_p_lcs_chars.nbsp;
          n_attr = 1;
          extra_attr = win_hl_attr(wp, HLF_0);
          saved_attr2 = char_attr;  // save current attr
          mb_c = c;
          if (utf_char2len(c) > 1) {
            mb_utf8 = true;
            u8cc[0] = 0;
            c = 0xc0;
          } else {
            mb_utf8 = false;
          }
        }

        if (trailcol != MAXCOL && ptr > line + trailcol && c == ' ') {
          c = wp->w_p_lcs_chars.trail;
          n_attr = 1;
          extra_attr = win_hl_attr(wp, HLF_0);
          saved_attr2 = char_attr;  // save current attr
          mb_c = c;
          if (utf_char2len(c) > 1) {
            mb_utf8 = true;
            u8cc[0] = 0;
            c = 0xc0;
          } else {
            mb_utf8 = false;
          }
        }
      }

      /*
       * Handling of non-printable characters.
       */
      if (!vim_isprintc(c)) {
        // when getting a character from the file, we may have to
        // turn it into something else on the way to putting it on the screen.
        if (c == TAB && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
          int tab_len = 0;
          long vcol_adjusted = vcol;  // removed showbreak length
          // Only adjust the tab_len, when at the first column after the
          // showbreak value was drawn.
          if (*p_sbr != NUL && vcol == vcol_sbr && wp->w_p_wrap) {
            vcol_adjusted = vcol - MB_CHARLEN(p_sbr);
          }
          // tab amount depends on current column
          tab_len = (int)wp->w_buffer->b_p_ts
                    - vcol_adjusted % (int)wp->w_buffer->b_p_ts - 1;

          if (!wp->w_p_lbr || !wp->w_p_list) {
            n_extra = tab_len;
          } else {
            char_u *p;
            int    i;
            int    saved_nextra = n_extra;

            if (vcol_off > 0) {
              // there are characters to conceal
              tab_len += vcol_off;
            }
            // boguscols before FIX_FOR_BOGUSCOLS macro from above.
            if (wp->w_p_lcs_chars.tab1 && old_boguscols > 0
                && n_extra > tab_len) {
              tab_len += n_extra - tab_len;
            }

            /* if n_extra > 0, it gives the number of chars to use for
             * a tab, else we need to calculate the width for a tab */
            int len = (tab_len * mb_char2len(wp->w_p_lcs_chars.tab2));
            if (n_extra > 0) {
              len += n_extra - tab_len;
            }
            c = wp->w_p_lcs_chars.tab1;
            p = xmalloc(len + 1);
            memset(p, ' ', len);
            p[len] = NUL;
            xfree(p_extra_free);
            p_extra_free = p;
            for (i = 0; i < tab_len; i++) {
              utf_char2bytes(wp->w_p_lcs_chars.tab2, p);
              p += mb_char2len(wp->w_p_lcs_chars.tab2);
              n_extra += mb_char2len(wp->w_p_lcs_chars.tab2)
                         - (saved_nextra > 0 ? 1: 0);
            }
            p_extra = p_extra_free;

            // n_extra will be increased by FIX_FOX_BOGUSCOLS
            // macro below, so need to adjust for that here
            if (vcol_off > 0) {
              n_extra -= vcol_off;
            }
          }

          {
            int vc_saved = vcol_off;

            // Tab alignment should be identical regardless of
            // 'conceallevel' value. So tab compensates of all
            // previous concealed characters, and thus resets
            // vcol_off and boguscols accumulated so far in the
            // line. Note that the tab can be longer than
            // 'tabstop' when there are concealed characters.
            FIX_FOR_BOGUSCOLS;

            // Make sure, the highlighting for the tab char will be
            // correctly set further below (effectively reverts the
            // FIX_FOR_BOGSUCOLS macro.
            if (n_extra == tab_len + vc_saved && wp->w_p_list
                && wp->w_p_lcs_chars.tab1) {
              tab_len += vc_saved;
            }
          }

          mb_utf8 = false;  // don't draw as UTF-8
          if (wp->w_p_list) {
            c = (n_extra == 0 && wp->w_p_lcs_chars.tab3)
                 ? wp->w_p_lcs_chars.tab3
                 : wp->w_p_lcs_chars.tab1;
            if (wp->w_p_lbr) {
              c_extra = NUL; /* using p_extra from above */
            } else {
              c_extra = wp->w_p_lcs_chars.tab2;
            }
            c_final = wp->w_p_lcs_chars.tab3;
            n_attr = tab_len + 1;
            extra_attr = win_hl_attr(wp, HLF_0);
            saved_attr2 = char_attr;  // save current attr
            mb_c = c;
            if (utf_char2len(c) > 1) {
              mb_utf8 = true;
              u8cc[0] = 0;
              c = 0xc0;
            }
          } else {
            c_final = NUL;
            c_extra = ' ';
            c = ' ';
          }
        } else if (c == NUL
                   && (wp->w_p_list
                       || ((fromcol >= 0 || fromcol_prev >= 0)
                           && tocol > vcol
                           && VIsual_mode != Ctrl_V
                           && (wp->w_p_rl ? (col >= 0) : (col < grid->Columns))
                           && !(noinvcur
                                && lnum == wp->w_cursor.lnum
                                && (colnr_T)vcol == wp->w_virtcol)))
                   && lcs_eol_one > 0) {
          // Display a '$' after the line or highlight an extra
          // character if the line break is included.
          // For a diff line the highlighting continues after the "$".
          if (diff_hlf == (hlf_T)0
              && line_attr == 0
              && line_attr_lowprio == 0) {
            // In virtualedit, visual selections may extend beyond end of line
            if (area_highlighting && virtual_active()
                && tocol != MAXCOL && vcol < tocol) {
              n_extra = 0;
            } else {
              p_extra = at_end_str;
              n_extra = 1;
              c_extra = NUL;
              c_final = NUL;
            }
          }
          if (wp->w_p_list && wp->w_p_lcs_chars.eol > 0) {
            c = wp->w_p_lcs_chars.eol;
          } else {
            c = ' ';
          }
          lcs_eol_one = -1;
          ptr--;  // put it back at the NUL
          extra_attr = win_hl_attr(wp, HLF_AT);
          n_attr = 1;
          mb_c = c;
          if (utf_char2len(c) > 1) {
            mb_utf8 = true;
            u8cc[0] = 0;
            c = 0xc0;
          } else {
            mb_utf8 = false;                    // don't draw as UTF-8
          }
        } else if (c != NUL) {
          p_extra = transchar(c);
          if (n_extra == 0) {
              n_extra = byte2cells(c) - 1;
          }
          if ((dy_flags & DY_UHEX) && wp->w_p_rl)
            rl_mirror(p_extra);                 /* reverse "<12>" */
          c_extra = NUL;
          c_final = NUL;
          if (wp->w_p_lbr) {
            char_u *p;

            c = *p_extra;
            p = xmalloc(n_extra + 1);
            memset(p, ' ', n_extra);
            STRNCPY(p, p_extra + 1, STRLEN(p_extra) - 1);
            p[n_extra] = NUL;
            xfree(p_extra_free);
            p_extra_free = p_extra = p;
          } else {
            n_extra = byte2cells(c) - 1;
            c = *p_extra++;
          }
          n_attr = n_extra + 1;
          extra_attr = win_hl_attr(wp, HLF_8);
          saved_attr2 = char_attr;  // save current attr
          mb_utf8 = false;   // don't draw as UTF-8
        } else if (VIsual_active
                   && (VIsual_mode == Ctrl_V || VIsual_mode == 'v')
                   && virtual_active()
                   && tocol != MAXCOL
                   && vcol < tocol
                   && (wp->w_p_rl ? (col >= 0) : (col < grid->Columns))) {
          c = ' ';
          ptr--;  // put it back at the NUL
        }
      }

      if (wp->w_p_cole > 0
          && (wp != curwin || lnum != wp->w_cursor.lnum
              || conceal_cursor_line(wp))
          && ((syntax_flags & HL_CONCEAL) != 0 || has_match_conc > 0)
          && !(lnum_in_visual_area
               && vim_strchr(wp->w_p_cocu, 'v') == NULL)) {
        char_attr = conceal_attr;
        if ((prev_syntax_id != syntax_seqnr || has_match_conc > 1)
            && (syn_get_sub_char() != NUL || match_conc
                || wp->w_p_cole == 1)
            && wp->w_p_cole != 3) {
          // First time at this concealed item: display one
          // character.
          if (match_conc) {
            c = match_conc;
          } else if (syn_get_sub_char() != NUL) {
            c = syn_get_sub_char();
          } else if (wp->w_p_lcs_chars.conceal != NUL) {
            c = wp->w_p_lcs_chars.conceal;
          } else {
            c = ' ';
          }

          prev_syntax_id = syntax_seqnr;

          if (n_extra > 0)
            vcol_off += n_extra;
          vcol += n_extra;
          if (wp->w_p_wrap && n_extra > 0) {
            if (wp->w_p_rl) {
              col -= n_extra;
              boguscols -= n_extra;
            } else {
              boguscols += n_extra;
              col += n_extra;
            }
          }
          n_extra = 0;
          n_attr = 0;
        } else if (n_skip == 0) {
          is_concealing = TRUE;
          n_skip = 1;
        }
        mb_c = c;
        if (utf_char2len(c) > 1) {
          mb_utf8 = true;
          u8cc[0] = 0;
          c = 0xc0;
        } else {
          mb_utf8 = false;              // don't draw as UTF-8
        }
      } else {
        prev_syntax_id = 0;
        is_concealing = FALSE;
      }

      if (n_skip > 0 && did_decrement_ptr) {
        // not showing the '>', put pointer back to avoid getting stuck
        ptr++;
      }
    }

    /* In the cursor line and we may be concealing characters: correct
     * the cursor column when we reach its position. */
    if (!did_wcol && draw_state == WL_LINE
        && wp == curwin && lnum == wp->w_cursor.lnum
        && conceal_cursor_line(wp)
        && (int)wp->w_virtcol <= vcol + n_skip) {
      if (wp->w_p_rl) {
        wp->w_wcol = grid->Columns - col + boguscols - 1;
      } else {
        wp->w_wcol = col - boguscols;
      }
      wp->w_wrow = row;
      did_wcol = true;
    }

    // Don't override visual selection highlighting.
    if (n_attr > 0 && draw_state == WL_LINE && !search_attr_from_match) {
      char_attr = hl_combine_attr(char_attr, extra_attr);
    }

    /*
     * Handle the case where we are in column 0 but not on the first
     * character of the line and the user wants us to show us a
     * special character (via 'listchars' option "precedes:<char>".
     */
    if (lcs_prec_todo != NUL
        && wp->w_p_list
        && (wp->w_p_wrap ? wp->w_skipcol > 0 : wp->w_leftcol > 0)
        && filler_todo <= 0
        && draw_state > WL_NR
        && c != NUL) {
      c = wp->w_p_lcs_chars.prec;
      lcs_prec_todo = NUL;
      if ((*mb_char2cells)(mb_c) > 1) {
        // Double-width character being overwritten by the "precedes"
        // character, need to fill up half the character.
        c_extra = MB_FILLER_CHAR;
        c_final = NUL;
        n_extra = 1;
        n_attr = 2;
        extra_attr = win_hl_attr(wp, HLF_AT);
      }
      mb_c = c;
      if (utf_char2len(c) > 1) {
        mb_utf8 = true;
        u8cc[0] = 0;
        c = 0xc0;
      } else {
        mb_utf8 = false;  // don't draw as UTF-8
      }
      saved_attr3 = char_attr;  // save current attr
      char_attr = win_hl_attr(wp, HLF_AT);  // overwriting char_attr
      n_attr3 = 1;
    }

    /*
     * At end of the text line or just after the last character.
     */
    if (c == NUL) {
      long prevcol = (long)(ptr - line) - (c == NUL);

      /* we're not really at that column when skipping some text */
      if ((long)(wp->w_p_wrap ? wp->w_skipcol : wp->w_leftcol) > prevcol)
        ++prevcol;

      // Invert at least one char, used for Visual and empty line or
      // highlight match at end of line. If it's beyond the last
      // char on the screen, just overwrite that one (tricky!)  Not
      // needed when a '$' was displayed for 'list'.
      prevcol_hl_flag = false;
      if (!search_hl.is_addpos && prevcol == (long)search_hl.startcol) {
        prevcol_hl_flag = true;
      } else {
        cur = wp->w_match_head;
        while (cur != NULL) {
          if (!cur->hl.is_addpos && prevcol == (long)cur->hl.startcol) {
            prevcol_hl_flag = true;
            break;
          }
          cur = cur->next;
        }
      }
      if (wp->w_p_lcs_chars.eol == lcs_eol_one
          && ((area_attr != 0 && vcol == fromcol
               && (VIsual_mode != Ctrl_V
                   || lnum == VIsual.lnum
                   || lnum == curwin->w_cursor.lnum)
               && c == NUL)
              // highlight 'hlsearch' match at end of line
              || prevcol_hl_flag)) {
        int n = 0;

        if (wp->w_p_rl) {
          if (col < 0)
            n = 1;
        } else {
          if (col >= grid->Columns) {
            n = -1;
          }
        }
        if (n != 0) {
          /* At the window boundary, highlight the last character
           * instead (better than nothing). */
          off += n;
          col += n;
        } else {
          // Add a blank character to highlight.
          schar_from_ascii(linebuf_char[off], ' ');
        }
        if (area_attr == 0) {
          /* Use attributes from match with highest priority among
           * 'search_hl' and the match list. */
          char_attr = search_hl.attr;
          cur = wp->w_match_head;
          shl_flag = FALSE;
          while (cur != NULL || shl_flag == FALSE) {
            if (shl_flag == FALSE
                && ((cur != NULL
                     && cur->priority > SEARCH_HL_PRIORITY)
                    || cur == NULL)) {
              shl = &search_hl;
              shl_flag = TRUE;
            } else
              shl = &cur->hl;
            if ((ptr - line) - 1 == (long)shl->startcol
                && (shl == &search_hl || !shl->is_addpos)) {
              char_attr = shl->attr;
            }
            if (shl != &search_hl && cur != NULL) {
              cur = cur->next;
            }
          }
        }

        int eol_attr = char_attr;
        if (wp->w_p_cul && lnum == wp->w_cursor.lnum) {
          eol_attr = hl_combine_attr(win_hl_attr(wp, HLF_CUL), eol_attr);
        }
        linebuf_attr[off] = eol_attr;
        if (wp->w_p_rl) {
          --col;
          --off;
        } else {
          ++col;
          ++off;
        }
        ++vcol;
        eol_hl_off = 1;
      }
      // Highlight 'cursorcolumn' & 'colorcolumn' past end of the line.
      if (wp->w_p_wrap) {
        v = wp->w_skipcol;
      } else {
        v = wp->w_leftcol;
      }

      /* check if line ends before left margin */
      if (vcol < v + col - win_col_off(wp))
        vcol = v + col - win_col_off(wp);
      /* Get rid of the boguscols now, we want to draw until the right
       * edge for 'cursorcolumn'. */
      col -= boguscols;
      // boguscols = 0;  // Disabled because value never read after this

      if (draw_color_col)
        draw_color_col = advance_color_col(VCOL_HLC, &color_cols);

      if (((wp->w_p_cuc
            && (int)wp->w_virtcol >= VCOL_HLC - eol_hl_off
            && (int)wp->w_virtcol <
            grid->Columns * (row - startrow + 1) + v
            && lnum != wp->w_cursor.lnum)
           || draw_color_col || line_attr_lowprio || line_attr
           || diff_hlf != (hlf_T)0 || do_virttext)) {
        int rightmost_vcol = 0;
        int i;

        VirtText virt_text = do_virttext ? bufhl_info.line->virt_text
                                        : (VirtText)KV_INITIAL_VALUE;
        size_t virt_pos = 0;
        LineState s = LINE_STATE((char_u *)"");
        int virt_attr = 0;

        // Make sure alignment is the same regardless
        // if listchars=eol:X is used or not.
        bool delay_virttext = wp->w_p_lcs_chars.eol == lcs_eol_one
                              && eol_hl_off == 0;

        if (wp->w_p_cuc) {
          rightmost_vcol = wp->w_virtcol;
        }

        if (draw_color_col) {
          // determine rightmost colorcolumn to possibly draw
          for (i = 0; color_cols[i] >= 0; i++) {
            if (rightmost_vcol < color_cols[i]) {
              rightmost_vcol = color_cols[i];
            }
          }
        }

        int cuc_attr = win_hl_attr(wp, HLF_CUC);
        int mc_attr = win_hl_attr(wp, HLF_MC);

        int diff_attr = 0;
        if (diff_hlf == HLF_TXD) {
          diff_hlf = HLF_CHD;
        }
        if (diff_hlf != 0) {
          diff_attr = win_hl_attr(wp, diff_hlf);
        }

        int base_attr = hl_combine_attr(line_attr_lowprio, diff_attr);
        if (base_attr || line_attr) {
          rightmost_vcol = INT_MAX;
        }

        int col_stride = wp->w_p_rl ? -1 : 1;

        while (wp->w_p_rl ? col >= 0 : col < grid->Columns) {
          int cells = -1;
          if (do_virttext && !delay_virttext) {
            if (*s.p == NUL) {
              if (virt_pos < virt_text.size) {
                s.p = (char_u *)kv_A(virt_text, virt_pos).text;
                int hl_id = kv_A(virt_text, virt_pos).hl_id;
                virt_attr = hl_id > 0 ? syn_id2attr(hl_id) : 0;
                virt_pos++;
              } else {
               do_virttext = false;
              }
            }
            if (*s.p != NUL) {
              cells = line_putchar(&s, &linebuf_char[off], grid->Columns - col,
                                   false);
            }
          }
          delay_virttext = false;

          if (cells == -1) {
            schar_from_ascii(linebuf_char[off], ' ');
            cells = 1;
          }
          col += cells * col_stride;
          if (draw_color_col) {
            draw_color_col = advance_color_col(VCOL_HLC, &color_cols);
          }

          int col_attr = base_attr;

          if (wp->w_p_cuc && VCOL_HLC == (long)wp->w_virtcol) {
            col_attr = cuc_attr;
          } else if (draw_color_col && VCOL_HLC == *color_cols) {
            col_attr = mc_attr;
          }

          if (do_virttext) {
            col_attr = hl_combine_attr(col_attr, virt_attr);
          }

          col_attr = hl_combine_attr(col_attr, line_attr);

          linebuf_attr[off] = col_attr;
          if (cells == 2) {
            linebuf_attr[off+1] = col_attr;
          }
          off += cells * col_stride;

          if (VCOL_HLC >= rightmost_vcol && *s.p == NUL
              && virt_pos >= virt_text.size) {
            break;
          }

          ++vcol;
        }
      }

      // TODO(bfredl): integrate with the common beyond-the-end-loop
      if (wp->w_buffer->terminal) {
        // terminal buffers may need to highlight beyond the end of the
        // logical line
        while (col < grid->Columns) {
          schar_from_ascii(linebuf_char[off], ' ');
          linebuf_attr[off++] = term_attrs[vcol++];
          col++;
        }
      }
      grid_put_linebuf(grid, row, 0, col, grid->Columns, wp->w_p_rl, wp,
                       wp->w_hl_attr_normal, false);
      row++;

      /*
       * Update w_cline_height and w_cline_folded if the cursor line was
       * updated (saves a call to plines() later).
       */
      if (wp == curwin && lnum == curwin->w_cursor.lnum) {
        curwin->w_cline_row = startrow;
        curwin->w_cline_height = row - startrow;
        curwin->w_cline_folded = false;
        curwin->w_valid |= (VALID_CHEIGHT|VALID_CROW);
        conceal_cursor_used = conceal_cursor_line(curwin);
      }

      break;
    }

    // Show "extends" character from 'listchars' if beyond the line end and
    // 'list' is set.
    if (wp->w_p_lcs_chars.ext != NUL
        && wp->w_p_list
        && !wp->w_p_wrap
        && filler_todo <= 0
        && (wp->w_p_rl ? col == 0 : col == grid->Columns - 1)
        && (*ptr != NUL
            || (wp->w_p_list && lcs_eol_one > 0)
            || (n_extra && (c_extra != NUL || *p_extra != NUL)))) {
      c = wp->w_p_lcs_chars.ext;
      char_attr = win_hl_attr(wp, HLF_AT);
      mb_c = c;
      if (utf_char2len(c) > 1) {
        mb_utf8 = true;
        u8cc[0] = 0;
        c = 0xc0;
      } else {
        mb_utf8 = false;
      }
    }

    /* advance to the next 'colorcolumn' */
    if (draw_color_col)
      draw_color_col = advance_color_col(VCOL_HLC, &color_cols);

    /* Highlight the cursor column if 'cursorcolumn' is set.  But don't
     * highlight the cursor position itself.
     * Also highlight the 'colorcolumn' if it is different than
     * 'cursorcolumn' */
    vcol_save_attr = -1;
    if (draw_state == WL_LINE && !lnum_in_visual_area
        && search_attr == 0 && area_attr == 0) {
      if (wp->w_p_cuc && VCOL_HLC == (long)wp->w_virtcol
          && lnum != wp->w_cursor.lnum) {
        vcol_save_attr = char_attr;
        char_attr = hl_combine_attr(win_hl_attr(wp, HLF_CUC), char_attr);
      } else if (draw_color_col && VCOL_HLC == *color_cols) {
        vcol_save_attr = char_attr;
        char_attr = hl_combine_attr(win_hl_attr(wp, HLF_MC), char_attr);
      }
    }

    // Apply lowest-priority line attr now, so everything can override it.
    if (draw_state == WL_LINE) {
      char_attr = hl_combine_attr(line_attr_lowprio, char_attr);
    }

    /*
     * Store character to be displayed.
     * Skip characters that are left of the screen for 'nowrap'.
     */
    vcol_prev = vcol;
    if (draw_state < WL_LINE || n_skip <= 0) {
      //
      // Store the character.
      //
      if (wp->w_p_rl && (*mb_char2cells)(mb_c) > 1) {
        // A double-wide character is: put first halve in left cell.
        off--;
        col--;
      }
      if (mb_utf8) {
        schar_from_cc(linebuf_char[off], mb_c, u8cc);
      } else {
        schar_from_ascii(linebuf_char[off], c);
      }
      if (multi_attr) {
        linebuf_attr[off] = multi_attr;
        multi_attr = 0;
      } else {
        linebuf_attr[off] = char_attr;
      }

      if ((*mb_char2cells)(mb_c) > 1) {
        // Need to fill two screen columns.
        off++;
        col++;
        // UTF-8: Put a 0 in the second screen char.
        linebuf_char[off][0] = 0;
        if (draw_state > WL_NR && filler_todo <= 0) {
          vcol++;
        }
        // When "tocol" is halfway through a character, set it to the end of
        // the character, otherwise highlighting won't stop.
        if (tocol == vcol) {
          tocol++;
        }
        if (wp->w_p_rl) {
          /* now it's time to backup one cell */
          --off;
          --col;
        }
      }
      if (wp->w_p_rl) {
        --off;
        --col;
      } else {
        ++off;
        ++col;
      }
    } else if (wp->w_p_cole > 0 && is_concealing) {
      --n_skip;
      ++vcol_off;
      if (n_extra > 0)
        vcol_off += n_extra;
      if (wp->w_p_wrap) {
        /*
         * Special voodoo required if 'wrap' is on.
         *
         * Advance the column indicator to force the line
         * drawing to wrap early. This will make the line
         * take up the same screen space when parts are concealed,
         * so that cursor line computations aren't messed up.
         *
         * To avoid the fictitious advance of 'col' causing
         * trailing junk to be written out of the screen line
         * we are building, 'boguscols' keeps track of the number
         * of bad columns we have advanced.
         */
        if (n_extra > 0) {
          vcol += n_extra;
          if (wp->w_p_rl) {
            col -= n_extra;
            boguscols -= n_extra;
          } else {
            col += n_extra;
            boguscols += n_extra;
          }
          n_extra = 0;
          n_attr = 0;
        }


        if ((*mb_char2cells)(mb_c) > 1) {
          // Need to fill two screen columns.
          if (wp->w_p_rl) {
            --boguscols;
            --col;
          } else {
            ++boguscols;
            ++col;
          }
        }

        if (wp->w_p_rl) {
          --boguscols;
          --col;
        } else {
          ++boguscols;
          ++col;
        }
      } else {
        if (n_extra > 0) {
          vcol += n_extra;
          n_extra = 0;
          n_attr = 0;
        }
      }

    } else
      --n_skip;

    /* Only advance the "vcol" when after the 'number' or 'relativenumber'
     * column. */
    if (draw_state > WL_NR
        && filler_todo <= 0
        )
      ++vcol;

    if (vcol_save_attr >= 0)
      char_attr = vcol_save_attr;

    /* restore attributes after "predeces" in 'listchars' */
    if (draw_state > WL_NR && n_attr3 > 0 && --n_attr3 == 0)
      char_attr = saved_attr3;

    /* restore attributes after last 'listchars' or 'number' char */
    if (n_attr > 0 && draw_state == WL_LINE && --n_attr == 0)
      char_attr = saved_attr2;

    /*
     * At end of screen line and there is more to come: Display the line
     * so far.  If there is no more to display it is caught above.
     */
    if ((wp->w_p_rl ? (col < 0) : (col >= grid->Columns))
        && (*ptr != NUL
            || filler_todo > 0
            || (wp->w_p_list && wp->w_p_lcs_chars.eol != NUL
                && p_extra != at_end_str)
            || (n_extra != 0 && (c_extra != NUL || *p_extra != NUL)))
        ) {
      bool wrap = wp->w_p_wrap       // Wrapping enabled.
        && filler_todo <= 0          // Not drawing diff filler lines.
        && lcs_eol_one != -1         // Haven't printed the lcs_eol character.
        && row != endrow - 1         // Not the last line being displayed.
        && (grid->Columns == Columns  // Window spans the width of the screen,
            || ui_has(kUIMultigrid))  // or has dedicated grid.
        && !wp->w_p_rl;              // Not right-to-left.
      grid_put_linebuf(grid, row, 0, col - boguscols, grid->Columns, wp->w_p_rl,
                       wp, wp->w_hl_attr_normal, wrap);
      if (wrap) {
        ScreenGrid *current_grid = grid;
        int current_row = row, dummy_col = 0;  // dummy_col unused
        screen_adjust_grid(&current_grid, &current_row, &dummy_col);

        // Force a redraw of the first column of the next line.
        current_grid->attrs[current_grid->line_offset[current_row+1]] = -1;

        // Remember that the line wraps, used for modeless copy.
        current_grid->line_wraps[current_row] = true;
      }

      boguscols = 0;
      row++;

      /* When not wrapping and finished diff lines, or when displayed
       * '$' and highlighting until last column, break here. */
      if ((!wp->w_p_wrap
           && filler_todo <= 0
           ) || lcs_eol_one == -1)
        break;

      // When the window is too narrow draw all "@" lines.
      if (draw_state != WL_LINE && filler_todo <= 0) {
        win_draw_end(wp, '@', ' ', true, row, wp->w_grid.Rows, HLF_AT);
        row = endrow;
      }

      /* When line got too long for screen break here. */
      if (row == endrow) {
        ++row;
        break;
      }

      col = 0;
      off = 0;
      if (wp->w_p_rl) {
        col = grid->Columns - 1;  // col is not used if breaking!
        off += col;
      }

      /* reset the drawing state for the start of a wrapped line */
      draw_state = WL_START;
      saved_n_extra = n_extra;
      saved_p_extra = p_extra;
      saved_c_extra = c_extra;
      saved_c_final = c_final;
      saved_char_attr = char_attr;
      n_extra = 0;
      lcs_prec_todo = wp->w_p_lcs_chars.prec;
      if (filler_todo <= 0) {
        need_showbreak = true;
      }
      filler_todo--;
      // When the filler lines are actually below the last line of the
      // file, don't draw the line itself, break here.
      if (filler_todo == 0 && wp->w_botfill) {
        break;
      }
    }

  }     /* for every character in the line */

  /* After an empty line check first word for capital. */
  if (*skipwhite(line) == NUL) {
    capcol_lnum = lnum + 1;
    cap_col = 0;
  }

  xfree(p_extra_free);
  return row;
}

/// Determine if dedicated window grid should be used or the default_grid
///
/// If UI did not request multigrid support, draw all windows on the
/// default_grid.
///
/// NB: this function can only been used with window grids in a context where
/// win_grid_alloc already has been called!
///
/// If the default_grid is used, adjust window relative positions to global
/// screen positions.
void screen_adjust_grid(ScreenGrid **grid, int *row_off, int *col_off)
{
  if (!(*grid)->chars && *grid != &default_grid) {
    *row_off += (*grid)->row_offset;
    *col_off += (*grid)->col_offset;
    *grid = &default_grid;
  }
}


/*
 * Check whether the given character needs redrawing:
 * - the (first byte of the) character is different
 * - the attributes are different
 * - the character is multi-byte and the next byte is different
 * - the character is two cells wide and the second cell differs.
 */
static int grid_char_needs_redraw(ScreenGrid *grid, int off_from, int off_to,
                                  int cols)
{
  return (cols > 0
          && ((schar_cmp(linebuf_char[off_from], grid->chars[off_to])
               || linebuf_attr[off_from] != grid->attrs[off_to]
               || (line_off2cells(linebuf_char, off_from, off_from + cols) > 1
                   && schar_cmp(linebuf_char[off_from + 1],
                                grid->chars[off_to + 1])))
              || p_wd < 0));
}

/// Move one buffered line to the window grid, but only the characters that
/// have actually changed.  Handle insert/delete character.
/// "coloff" gives the first column on the grid for this line.
/// "endcol" gives the columns where valid characters are.
/// "clear_width" is the width of the window.  It's > 0 if the rest of the line
/// needs to be cleared, negative otherwise.
/// "rlflag" is TRUE in a rightleft window:
///    When TRUE and "clear_width" > 0, clear columns 0 to "endcol"
///    When FALSE and "clear_width" > 0, clear columns "endcol" to "clear_width"
/// If "wrap" is true, then hint to the UI that "row" contains a line
/// which has wrapped into the next row.
static void grid_put_linebuf(ScreenGrid *grid, int row, int coloff, int endcol,
                             int clear_width, int rlflag, win_T *wp,
                             int bg_attr, bool wrap)
{
  unsigned off_from;
  unsigned off_to;
  unsigned max_off_from;
  unsigned max_off_to;
  int col = 0;
  bool redraw_this;                         // Does character need redraw?
  bool redraw_next;                         // redraw_this for next character
  bool clear_next = false;
  int char_cells;                           // 1: normal char
                                            // 2: occupies two display cells
  int start_dirty = -1, end_dirty = 0;

  // TODO(bfredl): check all callsites and eliminate
  // Check for illegal row and col, just in case
  if (row >= grid->Rows) {
    row = grid->Rows - 1;
  }
  if (endcol > grid->Columns) {
    endcol = grid->Columns;
  }

  screen_adjust_grid(&grid, &row, &coloff);

  off_from = 0;
  off_to = grid->line_offset[row] + coloff;
  max_off_from = linebuf_size;
  max_off_to = grid->line_offset[row] + grid->Columns;

  if (rlflag) {
    /* Clear rest first, because it's left of the text. */
    if (clear_width > 0) {
      while (col <= endcol && grid->chars[off_to][0] == ' '
             && grid->chars[off_to][1] == NUL
             && grid->attrs[off_to] == bg_attr
             ) {
        ++off_to;
        ++col;
      }
      if (col <= endcol) {
        grid_fill(grid, row, row + 1, col + coloff, endcol + coloff + 1,
                  ' ', ' ', bg_attr);
      }
    }
    col = endcol + 1;
    off_to = grid->line_offset[row] + col + coloff;
    off_from += col;
    endcol = (clear_width > 0 ? clear_width : -clear_width);
  }

  if (bg_attr) {
    for (int c = col; c < endcol; c++) {
      linebuf_attr[off_from+c] =
        hl_combine_attr(bg_attr, linebuf_attr[off_from+c]);
    }
  }

  redraw_next = grid_char_needs_redraw(grid, off_from, off_to, endcol - col);

  while (col < endcol) {
    char_cells = 1;
    if (col + 1 < endcol) {
      char_cells = line_off2cells(linebuf_char, off_from, max_off_from);
    }
    redraw_this = redraw_next;
    redraw_next = grid_char_needs_redraw(grid, off_from + char_cells,
                                         off_to + char_cells,
                                         endcol - col - char_cells);

    if (redraw_this) {
      if (start_dirty == -1) {
        start_dirty = col;
      }
      end_dirty = col + char_cells;
      // When writing a single-width character over a double-width
      // character and at the end of the redrawn text, need to clear out
      // the right halve of the old character.
      // Also required when writing the right halve of a double-width
      // char over the left halve of an existing one
      if (col + char_cells == endcol
          && ((char_cells == 1
               && grid_off2cells(grid, off_to, max_off_to) > 1)
              || (char_cells == 2
                  && grid_off2cells(grid, off_to, max_off_to) == 1
                  && grid_off2cells(grid, off_to + 1, max_off_to) > 1))) {
        clear_next = true;
      }

      schar_copy(grid->chars[off_to], linebuf_char[off_from]);
      if (char_cells == 2) {
        schar_copy(grid->chars[off_to+1], linebuf_char[off_from+1]);
      }

      grid->attrs[off_to] = linebuf_attr[off_from];
      // For simplicity set the attributes of second half of a
      // double-wide character equal to the first half.
      if (char_cells == 2) {
        grid->attrs[off_to + 1] = linebuf_attr[off_from];
      }
    }

    off_to += char_cells;
    off_from += char_cells;
    col += char_cells;
  }

  if (clear_next) {
    /* Clear the second half of a double-wide character of which the left
     * half was overwritten with a single-wide character. */
    schar_from_ascii(grid->chars[off_to], ' ');
    end_dirty++;
  }

  int clear_end = -1;
  if (clear_width > 0 && !rlflag) {
    // blank out the rest of the line
    // TODO(bfredl): we could cache winline widths
    while (col < clear_width) {
      if (grid->chars[off_to][0] != ' '
          || grid->chars[off_to][1] != NUL
          || grid->attrs[off_to] != bg_attr) {
        grid->chars[off_to][0] = ' ';
        grid->chars[off_to][1] = NUL;
        grid->attrs[off_to] = bg_attr;
        if (start_dirty == -1) {
          start_dirty = col;
          end_dirty = col;
        } else if (clear_end == -1) {
          end_dirty = endcol;
        }
        clear_end = col+1;
      }
      col++;
      off_to++;
    }
  }

  if (clear_width > 0 || wp->w_width != grid->Columns) {
    // If we cleared after the end of the line, it did not wrap.
    // For vsplit, line wrapping is not possible.
    grid->line_wraps[row] = false;
  }

  if (clear_end < end_dirty) {
    clear_end = end_dirty;
  }
  if (start_dirty == -1) {
    start_dirty = end_dirty;
  }
  if (clear_end > start_dirty) {
    ui_line(grid, row, coloff+start_dirty, coloff+end_dirty, coloff+clear_end,
            bg_attr, wrap);
  }
}

/*
 * Mirror text "str" for right-left displaying.
 * Only works for single-byte characters (e.g., numbers).
 */
void rl_mirror(char_u *str)
{
  char_u      *p1, *p2;
  int t;

  for (p1 = str, p2 = str + STRLEN(str) - 1; p1 < p2; ++p1, --p2) {
    t = *p1;
    *p1 = *p2;
    *p2 = t;
  }
}

/*
 * mark all status lines for redraw; used after first :cd
 */
void status_redraw_all(void)
{

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_status_height) {
      wp->w_redr_status = TRUE;
      redraw_later(VALID);
    }
  }
}

/// Marks all status lines of the current buffer for redraw.
void status_redraw_curbuf(void)
{
  status_redraw_buf(curbuf);
}

/// Marks all status lines of the specified buffer for redraw.
void status_redraw_buf(buf_T *buf)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_status_height != 0 && wp->w_buffer == buf) {
      wp->w_redr_status = true;
      redraw_later(VALID);
    }
  }
}

/*
 * Redraw all status lines that need to be redrawn.
 */
void redraw_statuslines(void)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_redr_status) {
      win_redr_status(wp);
    }
  }
  if (redraw_tabline)
    draw_tabline();
}

/*
 * Redraw all status lines at the bottom of frame "frp".
 */
void win_redraw_last_status(frame_T *frp)
{
  if (frp->fr_layout == FR_LEAF)
    frp->fr_win->w_redr_status = TRUE;
  else if (frp->fr_layout == FR_ROW) {
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
      win_redraw_last_status(frp);
  } else { /* frp->fr_layout == FR_COL */
    frp = frp->fr_child;
    while (frp->fr_next != NULL)
      frp = frp->fr_next;
    win_redraw_last_status(frp);
  }
}

/*
 * Draw the verticap separator right of window "wp" starting with line "row".
 */
static void draw_vsep_win(win_T *wp, int row)
{
  int hl;
  int c;

  if (wp->w_vsep_width) {
    // draw the vertical separator right of this window
    c = fillchar_vsep(wp, &hl);
    grid_fill(&default_grid, wp->w_winrow + row, W_ENDROW(wp),
              W_ENDCOL(wp), W_ENDCOL(wp) + 1, c, ' ', hl);
  }
}


/*
 * Get the length of an item as it will be shown in the status line.
 */
static int status_match_len(expand_T *xp, char_u *s)
{
  int len = 0;

  int emenu = (xp->xp_context == EXPAND_MENUS
               || xp->xp_context == EXPAND_MENUNAMES);

  /* Check for menu separators - replace with '|'. */
  if (emenu && menu_is_separator(s))
    return 1;

  while (*s != NUL) {
    s += skip_status_match_char(xp, s);
    len += ptr2cells(s);
    MB_PTR_ADV(s);
  }

  return len;
}

/*
 * Return the number of characters that should be skipped in a status match.
 * These are backslashes used for escaping.  Do show backslashes in help tags.
 */
static int skip_status_match_char(expand_T *xp, char_u *s)
{
  if ((rem_backslash(s) && xp->xp_context != EXPAND_HELP)
      || ((xp->xp_context == EXPAND_MENUS
           || xp->xp_context == EXPAND_MENUNAMES)
          && (s[0] == '\t' || (s[0] == '\\' && s[1] != NUL)))
      ) {
#ifndef BACKSLASH_IN_FILENAME
    if (xp->xp_shell && csh_like_shell() && s[1] == '\\' && s[2] == '!')
      return 2;
#endif
    return 1;
  }
  return 0;
}

/*
 * Show wildchar matches in the status line.
 * Show at least the "match" item.
 * We start at item 'first_match' in the list and show all matches that fit.
 *
 * If inversion is possible we use it. Else '=' characters are used.
 */
void
win_redr_status_matches (
    expand_T *xp,
    int num_matches,
    char_u **matches,          /* list of matches */
    int match,
    int showtail
)
{
#define L_MATCH(m) (showtail ? sm_gettail(matches[m]) : matches[m])
  int row;
  char_u      *buf;
  int len;
  int clen;                     /* length in screen cells */
  int fillchar;
  int attr;
  int i;
  int highlight = TRUE;
  char_u      *selstart = NULL;
  int selstart_col = 0;
  char_u      *selend = NULL;
  static int first_match = 0;
  int add_left = FALSE;
  char_u      *s;
  int emenu;
  int l;

  if (matches == NULL)          /* interrupted completion? */
    return;

  buf = xmalloc(Columns * MB_MAXBYTES + 1);

  if (match == -1) {    /* don't show match but original text */
    match = 0;
    highlight = FALSE;
  }
  /* count 1 for the ending ">" */
  clen = status_match_len(xp, L_MATCH(match)) + 3;
  if (match == 0)
    first_match = 0;
  else if (match < first_match) {
    /* jumping left, as far as we can go */
    first_match = match;
    add_left = TRUE;
  } else {
    /* check if match fits on the screen */
    for (i = first_match; i < match; ++i)
      clen += status_match_len(xp, L_MATCH(i)) + 2;
    if (first_match > 0)
      clen += 2;
    // jumping right, put match at the left
    if ((long)clen > Columns) {
      first_match = match;
      /* if showing the last match, we can add some on the left */
      clen = 2;
      for (i = match; i < num_matches; ++i) {
        clen += status_match_len(xp, L_MATCH(i)) + 2;
        if ((long)clen >= Columns) {
          break;
        }
      }
      if (i == num_matches)
        add_left = TRUE;
    }
  }
  if (add_left)
    while (first_match > 0) {
      clen += status_match_len(xp, L_MATCH(first_match - 1)) + 2;
      if ((long)clen >= Columns) {
        break;
      }
      first_match--;
    }

  fillchar = fillchar_status(&attr, curwin);

  if (first_match == 0) {
    *buf = NUL;
    len = 0;
  } else {
    STRCPY(buf, "< ");
    len = 2;
  }
  clen = len;

  i = first_match;
  while ((long)(clen + status_match_len(xp, L_MATCH(i)) + 2) < Columns) {
    if (i == match) {
      selstart = buf + len;
      selstart_col = clen;
    }

    s = L_MATCH(i);
    /* Check for menu separators - replace with '|' */
    emenu = (xp->xp_context == EXPAND_MENUS
             || xp->xp_context == EXPAND_MENUNAMES);
    if (emenu && menu_is_separator(s)) {
      STRCPY(buf + len, transchar('|'));
      l = (int)STRLEN(buf + len);
      len += l;
      clen += l;
    } else
      for (; *s != NUL; ++s) {
        s += skip_status_match_char(xp, s);
        clen += ptr2cells(s);
        if ((l = (*mb_ptr2len)(s)) > 1) {
          STRNCPY(buf + len, s, l);  // NOLINT(runtime/printf)
          s += l - 1;
          len += l;
        } else {
          STRCPY(buf + len, transchar_byte(*s));
          len += (int)STRLEN(buf + len);
        }
      }
    if (i == match)
      selend = buf + len;

    *(buf + len++) = ' ';
    *(buf + len++) = ' ';
    clen += 2;
    if (++i == num_matches)
      break;
  }

  if (i != num_matches) {
    *(buf + len++) = '>';
    ++clen;
  }

  buf[len] = NUL;

  row = cmdline_row - 1;
  if (row >= 0) {
    if (wild_menu_showing == 0 || wild_menu_showing == WM_LIST) {
      if (msg_scrolled > 0) {
        /* Put the wildmenu just above the command line.  If there is
         * no room, scroll the screen one line up. */
        if (cmdline_row == Rows - 1) {
          msg_scroll_up();
          msg_scrolled++;
        } else {
          cmdline_row++;
          row++;
        }
        wild_menu_showing = WM_SCROLLED;
      } else {
        /* Create status line if needed by setting 'laststatus' to 2.
         * Set 'winminheight' to zero to avoid that the window is
         * resized. */
        if (lastwin->w_status_height == 0) {
          save_p_ls = p_ls;
          save_p_wmh = p_wmh;
          p_ls = 2;
          p_wmh = 0;
          last_status(FALSE);
        }
        wild_menu_showing = WM_SHOWN;
      }
    }

    grid_puts(&default_grid, buf, row, 0, attr);
    if (selstart != NULL && highlight) {
      *selend = NUL;
      grid_puts(&default_grid, selstart, row, selstart_col, HL_ATTR(HLF_WM));
    }

    grid_fill(&default_grid, row, row + 1, clen, (int)Columns,
              fillchar, fillchar, attr);
  }

  win_redraw_last_status(topframe);
  xfree(buf);
}

/// Redraw the status line of window `wp`.
///
/// If inversion is possible we use it. Else '=' characters are used.
static void win_redr_status(win_T *wp)
{
  int row;
  char_u      *p;
  int len;
  int fillchar;
  int attr;
  int this_ru_col;
  static int busy = FALSE;

  // May get here recursively when 'statusline' (indirectly)
  // invokes ":redrawstatus".  Simply ignore the call then.
  if (busy
      // Also ignore if wildmenu is showing.
      || (wild_menu_showing != 0 && !ui_has(kUIWildmenu))) {
    return;
  }
  busy = true;

  wp->w_redr_status = FALSE;
  if (wp->w_status_height == 0) {
    // no status line, can only be last window
    redraw_cmdline = true;
  } else if (!redrawing()) {
    // Don't redraw right now, do it later. Don't update status line when
    // popup menu is visible and may be drawn over it
    wp->w_redr_status = true;
  } else if (*p_stl != NUL || *wp->w_p_stl != NUL) {
    /* redraw custom status line */
    redraw_custom_statusline(wp);
  } else {
    fillchar = fillchar_status(&attr, wp);

    get_trans_bufname(wp->w_buffer);
    p = NameBuff;
    len = (int)STRLEN(p);

    if (bt_help(wp->w_buffer)
        || wp->w_p_pvw
        || bufIsChanged(wp->w_buffer)
        || wp->w_buffer->b_p_ro) {
      *(p + len++) = ' ';
    }
    if (bt_help(wp->w_buffer)) {
      STRCPY(p + len, _("[Help]"));
      len += (int)STRLEN(p + len);
    }
    if (wp->w_p_pvw) {
      STRCPY(p + len, _("[Preview]"));
      len += (int)STRLEN(p + len);
    }
    if (bufIsChanged(wp->w_buffer)) {
      STRCPY(p + len, "[+]");
      len += 3;
    }
    if (wp->w_buffer->b_p_ro) {
      STRCPY(p + len, _("[RO]"));
      // len += (int)STRLEN(p + len);  // dead assignment
    }

    this_ru_col = ru_col - (Columns - wp->w_width);
    if (this_ru_col < (wp->w_width + 1) / 2) {
      this_ru_col = (wp->w_width + 1) / 2;
    }
    if (this_ru_col <= 1) {
      p = (char_u *)"<";                // No room for file name!
      len = 1;
    } else {
      int clen = 0, i;

      // Count total number of display cells.
      clen = (int)mb_string2cells(p);

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
        ++len;
      }
    }

    row = W_ENDROW(wp);
    grid_puts(&default_grid, p, row, wp->w_wincol, attr);
    grid_fill(&default_grid, row, row + 1, len + wp->w_wincol,
              this_ru_col + wp->w_wincol, fillchar, fillchar, attr);

    if (get_keymap_str(wp, (char_u *)"<%s>", NameBuff, MAXPATHL)
        && this_ru_col - len > (int)(STRLEN(NameBuff) + 1))
      grid_puts(&default_grid, NameBuff, row,
                (int)(this_ru_col - STRLEN(NameBuff) - 1), attr);

    win_redr_ruler(wp, TRUE);
  }

  /*
   * May need to draw the character below the vertical separator.
   */
  if (wp->w_vsep_width != 0 && wp->w_status_height != 0 && redrawing()) {
    if (stl_connected(wp)) {
      fillchar = fillchar_status(&attr, wp);
    } else {
      fillchar = fillchar_vsep(wp, &attr);
    }
    grid_putchar(&default_grid, fillchar, W_ENDROW(wp), W_ENDCOL(wp), attr);
  }
  busy = FALSE;
}

/*
 * Redraw the status line according to 'statusline' and take care of any
 * errors encountered.
 */
static void redraw_custom_statusline(win_T *wp)
{
  static int entered = false;
  int saved_did_emsg = did_emsg;

  /* When called recursively return.  This can happen when the statusline
   * contains an expression that triggers a redraw. */
  if (entered)
    return;
  entered = TRUE;

  did_emsg = false;
  win_redr_custom(wp, false);
  if (did_emsg) {
    // When there is an error disable the statusline, otherwise the
    // display is messed up with errors and a redraw triggers the problem
    // again and again.
    set_string_option_direct((char_u *)"statusline", -1,
        (char_u *)"", OPT_FREE | (*wp->w_p_stl != NUL
                                  ? OPT_LOCAL : OPT_GLOBAL), SID_ERROR);
  }
  did_emsg |= saved_did_emsg;
  entered = false;
}

/*
 * Return TRUE if the status line of window "wp" is connected to the status
 * line of the window right of it.  If not, then it's a vertical separator.
 * Only call if (wp->w_vsep_width != 0).
 */
int stl_connected(win_T *wp)
{
  frame_T     *fr;

  fr = wp->w_frame;
  while (fr->fr_parent != NULL) {
    if (fr->fr_parent->fr_layout == FR_COL) {
      if (fr->fr_next != NULL)
        break;
    } else {
      if (fr->fr_next != NULL)
        return TRUE;
    }
    fr = fr->fr_parent;
  }
  return FALSE;
}


/*
 * Get the value to show for the language mappings, active 'keymap'.
 */
int
get_keymap_str (
    win_T *wp,
    char_u *fmt,        // format string containing one %s item
    char_u *buf,        // buffer for the result
    int len             // length of buffer
)
{
  char_u      *p;

  if (wp->w_buffer->b_p_iminsert != B_IMODE_LMAP)
    return FALSE;

  {
    buf_T   *old_curbuf = curbuf;
    win_T   *old_curwin = curwin;
    char_u  *s;

    curbuf = wp->w_buffer;
    curwin = wp;
    STRCPY(buf, "b:keymap_name");       /* must be writable */
    ++emsg_skip;
    s = p = eval_to_string(buf, NULL, FALSE);
    --emsg_skip;
    curbuf = old_curbuf;
    curwin = old_curwin;
    if (p == NULL || *p == NUL) {
      if (wp->w_buffer->b_kmap_state & KEYMAP_LOADED) {
        p = wp->w_buffer->b_p_keymap;
      } else {
        p = (char_u *)"lang";
      }
    }
    if (vim_snprintf((char *)buf, len, (char *)fmt, p) > len - 1) {
      buf[0] = NUL;
    }
    xfree(s);
  }
  return buf[0] != NUL;
}

/*
 * Redraw the status line or ruler of window "wp".
 * When "wp" is NULL redraw the tab pages line from 'tabline'.
 */
static void
win_redr_custom (
    win_T *wp,
    int draw_ruler                 /* TRUE or FALSE */
)
{
  static int entered = FALSE;
  int attr;
  int curattr;
  int row;
  int col = 0;
  int maxwidth;
  int width;
  int n;
  int len;
  int fillchar;
  char_u buf[MAXPATHL];
  char_u      *stl;
  char_u      *p;
  struct      stl_hlrec hltab[STL_MAX_ITEM];
  StlClickRecord tabtab[STL_MAX_ITEM];
  int use_sandbox = false;
  win_T       *ewp;
  int p_crb_save;

  /* There is a tiny chance that this gets called recursively: When
   * redrawing a status line triggers redrawing the ruler or tabline.
   * Avoid trouble by not allowing recursion. */
  if (entered)
    return;
  entered = TRUE;

  /* setup environment for the task at hand */
  if (wp == NULL) {
    /* Use 'tabline'.  Always at the first line of the screen. */
    stl = p_tal;
    row = 0;
    fillchar = ' ';
    attr = HL_ATTR(HLF_TPF);
    maxwidth = Columns;
    use_sandbox = was_set_insecurely((char_u *)"tabline", 0);
  } else {
    row = W_ENDROW(wp);
    fillchar = fillchar_status(&attr, wp);
    maxwidth = wp->w_width;

    if (draw_ruler) {
      stl = p_ruf;
      /* advance past any leading group spec - implicit in ru_col */
      if (*stl == '%') {
        if (*++stl == '-')
          stl++;
        if (atoi((char *)stl))
          while (ascii_isdigit(*stl))
            stl++;
        if (*stl++ != '(')
          stl = p_ruf;
      }
      col = ru_col - (Columns - wp->w_width);
      if (col < (wp->w_width + 1) / 2) {
        col = (wp->w_width + 1) / 2;
      }
      maxwidth = wp->w_width - col;
      if (!wp->w_status_height) {
        row = Rows - 1;
        maxwidth--;  // writing in last column may cause scrolling
        fillchar = ' ';
        attr = 0;
      }

      use_sandbox = was_set_insecurely((char_u *)"rulerformat", 0);
    } else {
      if (*wp->w_p_stl != NUL)
        stl = wp->w_p_stl;
      else
        stl = p_stl;
      use_sandbox = was_set_insecurely((char_u *)"statusline",
          *wp->w_p_stl == NUL ? 0 : OPT_LOCAL);
    }

    col += wp->w_wincol;
  }

  if (maxwidth <= 0)
    goto theend;

  /* Temporarily reset 'cursorbind', we don't want a side effect from moving
   * the cursor away and back. */
  ewp = wp == NULL ? curwin : wp;
  p_crb_save = ewp->w_p_crb;
  ewp->w_p_crb = FALSE;

  /* Make a copy, because the statusline may include a function call that
   * might change the option value and free the memory. */
  stl = vim_strsave(stl);
  width = build_stl_str_hl(ewp, buf, sizeof(buf),
      stl, use_sandbox,
      fillchar, maxwidth, hltab, tabtab);
  xfree(stl);
  ewp->w_p_crb = p_crb_save;

  // Make all characters printable.
  p = (char_u *)transstr((const char *)buf);
  len = STRLCPY(buf, p, sizeof(buf));
  len = (size_t)len < sizeof(buf) ? len : (int)sizeof(buf) - 1;
  xfree(p);

  /* fill up with "fillchar" */
  while (width < maxwidth && len < (int)sizeof(buf) - 1) {
    len += utf_char2bytes(fillchar, buf + len);
    width++;
  }
  buf[len] = NUL;

  /*
   * Draw each snippet with the specified highlighting.
   */
  screen_puts_line_start(row);

  curattr = attr;
  p = buf;
  for (n = 0; hltab[n].start != NULL; n++) {
    int textlen = (int)(hltab[n].start - p);
    grid_puts_len(&default_grid, p, textlen, row, col, curattr);
    col += vim_strnsize(p, textlen);
    p = hltab[n].start;

    if (hltab[n].userhl == 0)
      curattr = attr;
    else if (hltab[n].userhl < 0)
      curattr = syn_id2attr(-hltab[n].userhl);
    else if (wp != NULL && wp != curwin && wp->w_status_height != 0)
      curattr = highlight_stlnc[hltab[n].userhl - 1];
    else
      curattr = highlight_user[hltab[n].userhl - 1];
  }
  // Make sure to use an empty string instead of p, if p is beyond buf + len.
  grid_puts(&default_grid, p >= buf + len ? (char_u *)"" : p, row, col,
            curattr);

  grid_puts_line_flush(&default_grid, false);

  if (wp == NULL) {
    // Fill the tab_page_click_defs array for clicking in the tab pages line.
    col = 0;
    len = 0;
    p = buf;
    StlClickDefinition cur_click_def = {
      .type = kStlClickDisabled,
    };
    for (n = 0; tabtab[n].start != NULL; n++) {
      len += vim_strnsize(p, (int)(tabtab[n].start - (char *) p));
      while (col < len) {
        tab_page_click_defs[col++] = cur_click_def;
      }
      p = (char_u *) tabtab[n].start;
      cur_click_def = tabtab[n].def;
    }
    while (col < Columns) {
      tab_page_click_defs[col++] = cur_click_def;
    }
  }

theend:
  entered = FALSE;
}

// Low-level functions to manipulate invidual character cells on the
// screen grid.

/// Put a ASCII character in a screen cell.
static void schar_from_ascii(char_u *p, const char c)
{
  p[0] = c;
  p[1] = 0;
}

/// Put a unicode character in a screen cell.
static int schar_from_char(char_u *p, int c)
{
  int len = utf_char2bytes(c, p);
  p[len] = NUL;
  return len;
}

/// Put a unicode char, and up to MAX_MCO composing chars, in a screen cell.
static int schar_from_cc(char_u *p, int c, int u8cc[MAX_MCO])
{
  int len = utf_char2bytes(c, p);
  for (int i = 0; i < MAX_MCO; i++) {
    if (u8cc[i] == 0) {
      break;
    }
    len += utf_char2bytes(u8cc[i], p + len);
  }
  p[len] = 0;
  return len;
}

/// compare the contents of two screen cells.
static int schar_cmp(char_u *sc1, char_u *sc2)
{
  return STRNCMP(sc1, sc2, sizeof(schar_T));
}

/// copy the contents of screen cell `sc2` into cell `sc1`
static void schar_copy(char_u *sc1, char_u *sc2)
{
  STRLCPY(sc1, sc2, sizeof(schar_T));
}

static int line_off2cells(schar_T *line, size_t off, size_t max_off)
{
  return (off + 1 < max_off && line[off + 1][0] == 0) ? 2 : 1;
}

/// Return number of display cells for char at grid->chars[off].
/// We make sure that the offset used is less than "max_off".
static int grid_off2cells(ScreenGrid *grid, size_t off, size_t max_off)
{
  return line_off2cells(grid->chars, off, max_off);
}

/// Return true if the character at "row"/"col" on the screen is the left side
/// of a double-width character.
///
/// Caller must make sure "row" and "col" are not invalid!
bool grid_lefthalve(ScreenGrid *grid, int row, int col)
{
  screen_adjust_grid(&grid, &row, &col);

  return grid_off2cells(grid, grid->line_offset[row] + col,
                        grid->line_offset[row] + grid->Columns) > 1;
}

/// Correct a position on the screen, if it's the right half of a double-wide
/// char move it to the left half.  Returns the corrected column.
int grid_fix_col(ScreenGrid *grid, int col, int row)
{
  int coloff = 0;
  screen_adjust_grid(&grid, &row, &coloff);

  col += coloff;
  if (grid->chars != NULL && col > 0
      && grid->chars[grid->line_offset[row] + col][0] == 0) {
    return col - 1 - coloff;
  }
  return col - coloff;
}

/// output a single character directly to the grid
void grid_putchar(ScreenGrid *grid, int c, int row, int col, int attr)
{
  char_u buf[MB_MAXBYTES + 1];

  buf[utf_char2bytes(c, buf)] = NUL;
  grid_puts(grid, buf, row, col, attr);
}

/// get a single character directly from grid.chars into "bytes[]".
/// Also return its attribute in *attrp;
void grid_getbytes(ScreenGrid *grid, int row, int col, char_u *bytes,
                   int *attrp)
{
  unsigned off;

  screen_adjust_grid(&grid, &row, &col);

  // safety check
  if (grid->chars != NULL && row < grid->Rows && col < grid->Columns) {
    off = grid->line_offset[row] + col;
    *attrp = grid->attrs[off];
    schar_copy(bytes, grid->chars[off]);
  }
}


/// put string '*text' on the window grid at position 'row' and 'col', with
/// attributes 'attr', and update chars[] and attrs[].
/// Note: only outputs within one row, message is truncated at grid boundary!
/// Note: if grid, row and/or col is invalid, nothing is done.
void grid_puts(ScreenGrid *grid, char_u *text, int row, int col, int attr)
{
  grid_puts_len(grid, text, -1, row, col, attr);
}

static int put_dirty_row = -1;
static int put_dirty_first = INT_MAX;
static int put_dirty_last = 0;

/// Start a group of screen_puts_len calls that builds a single screen line.
///
/// Must be matched with a screen_puts_line_flush call before moving to
/// another line.
void screen_puts_line_start(int row)
{
  assert(put_dirty_row == -1);
  put_dirty_row = row;
}

/// like grid_puts(), but output "text[len]".  When "len" is -1 output up to
/// a NUL.
void grid_puts_len(ScreenGrid *grid, char_u *text, int textlen, int row,
                   int col, int attr)
{
  unsigned off;
  char_u      *ptr = text;
  int len = textlen;
  int c;
  unsigned max_off;
  int mbyte_blen = 1;
  int mbyte_cells = 1;
  int u8c = 0;
  int u8cc[MAX_MCO];
  int clear_next_cell = FALSE;
  int prev_c = 0;                       /* previous Arabic character */
  int pc, nc, nc1;
  int pcc[MAX_MCO];
  int need_redraw;
  bool do_flush = false;

  screen_adjust_grid(&grid, &row, &col);

  // safety check
  if (grid->chars == NULL || row >= grid->Rows || col >= grid->Columns) {
    return;
  }

  if (put_dirty_row == -1) {
    screen_puts_line_start(row);
    do_flush = true;
  } else {
    if (row != put_dirty_row) {
      abort();
    }
  }
  off = grid->line_offset[row] + col;

  /* When drawing over the right halve of a double-wide char clear out the
   * left halve.  Only needed in a terminal. */
  if (grid != &default_grid && col == 0 && grid_invalid_row(grid, row)) {
    // redraw the previous cell, make it empty
    put_dirty_first = -1;
    put_dirty_last = MAX(put_dirty_last, 1);
  }

  max_off = grid->line_offset[row] + grid->Columns;
  while (col < grid->Columns
         && (len < 0 || (int)(ptr - text) < len)
         && *ptr != NUL) {
    c = *ptr;
    // check if this is the first byte of a multibyte
    if (len > 0) {
      mbyte_blen = utfc_ptr2len_len(ptr, (int)((text + len) - ptr));
    } else {
      mbyte_blen = utfc_ptr2len(ptr);
    }
    if (len >= 0) {
      u8c = utfc_ptr2char_len(ptr, u8cc, (int)((text + len) - ptr));
    } else {
      u8c = utfc_ptr2char(ptr, u8cc);
    }
    mbyte_cells = utf_char2cells(u8c);
    if (p_arshape && !p_tbidi && arabic_char(u8c)) {
      // Do Arabic shaping.
      if (len >= 0 && (int)(ptr - text) + mbyte_blen >= len) {
        // Past end of string to be displayed.
        nc = NUL;
        nc1 = NUL;
      } else {
        nc = utfc_ptr2char_len(ptr + mbyte_blen, pcc,
                               (int)((text + len) - ptr - mbyte_blen));
        nc1 = pcc[0];
      }
      pc = prev_c;
      prev_c = u8c;
      u8c = arabic_shape(u8c, &c, &u8cc[0], nc, nc1, pc);
    } else {
      prev_c = u8c;
    }
    if (col + mbyte_cells > grid->Columns) {
      // Only 1 cell left, but character requires 2 cells:
      // display a '>' in the last column to avoid wrapping. */
      c = '>';
      mbyte_cells = 1;
    }

    schar_T buf;
    schar_from_cc(buf, u8c, u8cc);


    need_redraw = schar_cmp(grid->chars[off], buf)
                  || (mbyte_cells == 2 && grid->chars[off + 1][0] != 0)
                  || grid->attrs[off] != attr
                  || exmode_active;

    if (need_redraw) {
      // When at the end of the text and overwriting a two-cell
      // character with a one-cell character, need to clear the next
      // cell.  Also when overwriting the left halve of a two-cell char
      // with the right halve of a two-cell char.  Do this only once
      // (utf8_off2cells() may return 2 on the right halve).
      if (clear_next_cell) {
        clear_next_cell = false;
      } else if ((len < 0 ? ptr[mbyte_blen] == NUL
                  : ptr + mbyte_blen >= text + len)
                 && ((mbyte_cells == 1
                      && grid_off2cells(grid, off, max_off) > 1)
                     || (mbyte_cells == 2
                         && grid_off2cells(grid, off, max_off) == 1
                         && grid_off2cells(grid, off + 1, max_off) > 1))) {
        clear_next_cell = true;
      }

      schar_copy(grid->chars[off], buf);
      grid->attrs[off] = attr;
      if (mbyte_cells == 2) {
        grid->chars[off + 1][0] = 0;
        grid->attrs[off + 1] = attr;
      }
      put_dirty_first = MIN(put_dirty_first, col);
      put_dirty_last = MAX(put_dirty_last, col+mbyte_cells);
    }

    off += mbyte_cells;
    col += mbyte_cells;
    ptr += mbyte_blen;
    if (clear_next_cell) {
      // This only happens at the end, display one space next.
      ptr = (char_u *)" ";
      len = -1;
    }
  }

  if (do_flush) {
    grid_puts_line_flush(grid, true);
  }
}

/// End a group of screen_puts_len calls and send the screen buffer to the UI
/// layer.
///
/// @param grid       The grid which contains the buffer.
/// @param set_cursor Move the visible cursor to the end of the changed region.
///                   This is a workaround for not yet refactored code paths
///                   and shouldn't be used in new code.
void grid_puts_line_flush(ScreenGrid *grid, bool set_cursor)
{
  assert(put_dirty_row != -1);
  if (put_dirty_first < put_dirty_last) {
    if (set_cursor) {
      ui_grid_cursor_goto(grid->handle, put_dirty_row,
                          MIN(put_dirty_last, grid->Columns-1));
    }
    ui_line(grid, put_dirty_row, put_dirty_first, put_dirty_last,
            put_dirty_last, 0, false);
    put_dirty_first = INT_MAX;
    put_dirty_last = 0;
  }
  put_dirty_row = -1;
}

/*
 * Prepare for 'hlsearch' highlighting.
 */
static void start_search_hl(void)
{
  if (p_hls && !no_hlsearch) {
    last_pat_prog(&search_hl.rm);
    // Set the time limit to 'redrawtime'.
    search_hl.tm = profile_setlimit(p_rdt);
  }
}

/*
 * Clean up for 'hlsearch' highlighting.
 */
static void end_search_hl(void)
{
  if (search_hl.rm.regprog != NULL) {
    vim_regfree(search_hl.rm.regprog);
    search_hl.rm.regprog = NULL;
  }
}


/*
 * Init for calling prepare_search_hl().
 */
static void init_search_hl(win_T *wp)
{
  matchitem_T *cur;

  /* Setup for match and 'hlsearch' highlighting.  Disable any previous
   * match */
  cur = wp->w_match_head;
  while (cur != NULL) {
    cur->hl.rm = cur->match;
    if (cur->hlg_id == 0)
      cur->hl.attr = 0;
    else
      cur->hl.attr = syn_id2attr(cur->hlg_id);
    cur->hl.buf = wp->w_buffer;
    cur->hl.lnum = 0;
    cur->hl.first_lnum = 0;
    /* Set the time limit to 'redrawtime'. */
    cur->hl.tm = profile_setlimit(p_rdt);
    cur = cur->next;
  }
  search_hl.buf = wp->w_buffer;
  search_hl.lnum = 0;
  search_hl.first_lnum = 0;
  search_hl.attr = win_hl_attr(wp, HLF_L);

  // time limit is set at the toplevel, for all windows
}

/*
 * Advance to the match in window "wp" line "lnum" or past it.
 */
static void prepare_search_hl(win_T *wp, linenr_T lnum)
{
  matchitem_T *cur;             /* points to the match list */
  match_T     *shl;             /* points to search_hl or a match */
  int shl_flag;                 /* flag to indicate whether search_hl
                                   has been processed or not */
  int n;

  /*
   * When using a multi-line pattern, start searching at the top
   * of the window or just after a closed fold.
   * Do this both for search_hl and the match list.
   */
  cur = wp->w_match_head;
  shl_flag = false;
  while (cur != NULL || shl_flag == false) {
    if (shl_flag == false) {
      shl = &search_hl;
      shl_flag = true;
    } else {
      shl = &cur->hl;  // -V595
    }
    if (shl->rm.regprog != NULL
        && shl->lnum == 0
        && re_multiline(shl->rm.regprog)) {
      if (shl->first_lnum == 0) {
        for (shl->first_lnum = lnum;
             shl->first_lnum > wp->w_topline;
             shl->first_lnum--) {
          if (hasFoldingWin(wp, shl->first_lnum - 1, NULL, NULL, true, NULL)) {
            break;
          }
        }
      }
      if (cur != NULL) {
        cur->pos.cur = 0;
      }
      bool pos_inprogress = true; // mark that a position match search is
                                  // in progress
      n = 0;
      while (shl->first_lnum < lnum && (shl->rm.regprog != NULL
                                        || (cur != NULL && pos_inprogress))) {
        next_search_hl(wp, shl, shl->first_lnum, (colnr_T)n,
                       shl == &search_hl ? NULL : cur);
        pos_inprogress = !(cur == NULL ||  cur->pos.cur == 0);
        if (shl->lnum != 0) {
          shl->first_lnum = shl->lnum
                            + shl->rm.endpos[0].lnum
                            - shl->rm.startpos[0].lnum;
          n = shl->rm.endpos[0].col;
        } else {
          ++shl->first_lnum;
          n = 0;
        }
      }
    }
    if (shl != &search_hl && cur != NULL)
      cur = cur->next;
  }
}

/*
 * Search for a next 'hlsearch' or match.
 * Uses shl->buf.
 * Sets shl->lnum and shl->rm contents.
 * Note: Assumes a previous match is always before "lnum", unless
 * shl->lnum is zero.
 * Careful: Any pointers for buffer lines will become invalid.
 */
static void
next_search_hl (
    win_T *win,
    match_T *shl,               /* points to search_hl or a match */
    linenr_T lnum,
    colnr_T mincol,                /* minimal column for a match */
    matchitem_T *cur               /* to retrieve match positions if any */
)
{
  linenr_T l;
  colnr_T matchcol;
  long nmatched = 0;
  int save_called_emsg = called_emsg;

  if (shl->lnum != 0) {
    /* Check for three situations:
     * 1. If the "lnum" is below a previous match, start a new search.
     * 2. If the previous match includes "mincol", use it.
     * 3. Continue after the previous match.
     */
    l = shl->lnum + shl->rm.endpos[0].lnum - shl->rm.startpos[0].lnum;
    if (lnum > l)
      shl->lnum = 0;
    else if (lnum < l || shl->rm.endpos[0].col > mincol)
      return;
  }

  /*
   * Repeat searching for a match until one is found that includes "mincol"
   * or none is found in this line.
   */
  called_emsg = FALSE;
  for (;; ) {
    /* Stop searching after passing the time limit. */
    if (profile_passed_limit(shl->tm)) {
      shl->lnum = 0;                    /* no match found in time */
      break;
    }
    /* Three situations:
     * 1. No useful previous match: search from start of line.
     * 2. Not Vi compatible or empty match: continue at next character.
     *    Break the loop if this is beyond the end of the line.
     * 3. Vi compatible searching: continue at end of previous match.
     */
    if (shl->lnum == 0)
      matchcol = 0;
    else if (vim_strchr(p_cpo, CPO_SEARCH) == NULL
        || (shl->rm.endpos[0].lnum == 0
          && shl->rm.endpos[0].col <= shl->rm.startpos[0].col)) {
      char_u      *ml;

      matchcol = shl->rm.startpos[0].col;
      ml = ml_get_buf(shl->buf, lnum, FALSE) + matchcol;
      if (*ml == NUL) {
        ++matchcol;
        shl->lnum = 0;
        break;
      }
      matchcol += mb_ptr2len(ml);
    } else {
      matchcol = shl->rm.endpos[0].col;
    }

    shl->lnum = lnum;
    if (shl->rm.regprog != NULL) {
      /* Remember whether shl->rm is using a copy of the regprog in
       * cur->match. */
      bool regprog_is_copy = (shl != &search_hl
                              && cur != NULL
                              && shl == &cur->hl
                              && cur->match.regprog == cur->hl.rm.regprog);
      int timed_out = false;

      nmatched = vim_regexec_multi(&shl->rm, win, shl->buf, lnum, matchcol,
                                   &(shl->tm), &timed_out);
      // Copy the regprog, in case it got freed and recompiled.
      if (regprog_is_copy) {
        cur->match.regprog = cur->hl.rm.regprog;
      }
      if (called_emsg || got_int || timed_out) {
        // Error while handling regexp: stop using this regexp.
        if (shl == &search_hl) {
          // don't free regprog in the match list, it's a copy
          vim_regfree(shl->rm.regprog);
          SET_NO_HLSEARCH(TRUE);
        }
        shl->rm.regprog = NULL;
        shl->lnum = 0;
        got_int = FALSE; // avoid the "Type :quit to exit Vim" message
        break;
      }
    } else if (cur != NULL) {
      nmatched = next_search_hl_pos(shl, lnum, &(cur->pos), matchcol);
    }
    if (nmatched == 0) {
      shl->lnum = 0;                    /* no match found */
      break;
    }
    if (shl->rm.startpos[0].lnum > 0
        || shl->rm.startpos[0].col >= mincol
        || nmatched > 1
        || shl->rm.endpos[0].col > mincol) {
      shl->lnum += shl->rm.startpos[0].lnum;
      break;                            /* useful match found */
    }

    // Restore called_emsg for assert_fails().
    called_emsg = save_called_emsg;
  }
}

/// If there is a match fill "shl" and return one.
/// Return zero otherwise.
static int
next_search_hl_pos(
    match_T *shl,         // points to a match
    linenr_T lnum,
    posmatch_T *posmatch, // match positions
    colnr_T mincol        // minimal column for a match
)
{
  int i;
  int found = -1;

  shl->lnum = 0;
  for (i = posmatch->cur; i < MAXPOSMATCH; i++) {
    llpos_T *pos = &posmatch->pos[i];

    if (pos->lnum == 0) {
      break;
    }
    if (pos->len == 0 && pos->col < mincol) {
      continue;
    }
    if (pos->lnum == lnum) {
      if (found >= 0) {
        // if this match comes before the one at "found" then swap
        // them
        if (pos->col < posmatch->pos[found].col) {
          llpos_T tmp = *pos;

          *pos = posmatch->pos[found];
          posmatch->pos[found] = tmp;
        }
      } else {
        found = i;
      }
    }
  }
  posmatch->cur = 0;
  if (found >= 0) {
    colnr_T start = posmatch->pos[found].col == 0
                    ? 0: posmatch->pos[found].col - 1;
    colnr_T end = posmatch->pos[found].col == 0
                  ? MAXCOL : start + posmatch->pos[found].len;

    shl->lnum = lnum;
    shl->rm.startpos[0].lnum = 0;
    shl->rm.startpos[0].col = start;
    shl->rm.endpos[0].lnum = 0;
    shl->rm.endpos[0].col = end;
    shl->is_addpos = true;
    posmatch->cur = found + 1;
    return 1;
  }
  return 0;
}


/// Fill the grid from 'start_row' to 'end_row', from 'start_col' to 'end_col'
/// with character 'c1' in first column followed by 'c2' in the other columns.
/// Use attributes 'attr'.
void grid_fill(ScreenGrid *grid, int start_row, int end_row, int start_col,
               int end_col, int c1, int c2, int attr)
{
  schar_T sc;

  int row_off = 0, col_off = 0;
  screen_adjust_grid(&grid, &row_off, &col_off);
  start_row += row_off;
  end_row += row_off;
  start_col += col_off;
  end_col += col_off;

  // safety check
  if (end_row > grid->Rows) {
    end_row = grid->Rows;
  }
  if (end_col > grid->Columns) {
    end_col = grid->Columns;
  }

  // nothing to do
  if (start_row >= end_row || start_col >= end_col) {
    return;
  }

  for (int row = start_row; row < end_row; row++) {
    // When drawing over the right halve of a double-wide char clear
    // out the left halve.  When drawing over the left halve of a
    // double wide-char clear out the right halve.  Only needed in a
    // terminal.
    if (start_col > 0 && grid_fix_col(grid, start_col, row) != start_col) {
      grid_puts_len(grid, (char_u *)" ", 1, row, start_col - 1, 0);
    }
    if (end_col < grid->Columns
        && grid_fix_col(grid, end_col, row) != end_col) {
      grid_puts_len(grid, (char_u *)" ", 1, row, end_col, 0);
    }

    // if grid was resized (in ext_multigrid mode), the UI has no redraw updates
    // for the newly resized grid. It is better mark everything as dirty and
    // send all the updates.
    int dirty_first = INT_MAX;
    int dirty_last = 0;

    int col = start_col;
    schar_from_char(sc, c1);
    int lineoff = grid->line_offset[row];
    for (col = start_col; col < end_col; col++) {
      int off = lineoff + col;
      if (schar_cmp(grid->chars[off], sc)
          || grid->attrs[off] != attr) {
        schar_copy(grid->chars[off], sc);
        grid->attrs[off] = attr;
        if (dirty_first == INT_MAX) {
          dirty_first = col;
        }
        dirty_last = col+1;
      }
      if (col == start_col) {
        schar_from_char(sc, c2);
      }
    }
    if (dirty_last > dirty_first) {
      // TODO(bfredl): support a cleared suffix even with a batched line?
      if (put_dirty_row == row) {
        put_dirty_first = MIN(put_dirty_first, dirty_first);
        put_dirty_last = MAX(put_dirty_last, dirty_last);
      } else {
        int last = c2 != ' ' ? dirty_last : dirty_first + (c1 != ' ');
        ui_line(grid, row, dirty_first, last, dirty_last, attr, false);
      }
    }

    if (end_col == grid->Columns) {
      grid->line_wraps[row] = false;
    }

    // TODO(bfredl): The relevant caller should do this
    if (row == Rows - 1 && !ui_has(kUIMessages)) {
      // overwritten the command line
      redraw_cmdline = true;
      if (start_col == 0 && end_col == Columns
          && c1 == ' ' && c2 == ' ' && attr == 0) {
        clear_cmdline = false;  // command line has been cleared
      }
      if (start_col == 0) {
        mode_displayed = false;  // mode cleared or overwritten
      }
    }
  }
}

/*
 * Check if there should be a delay.  Used before clearing or redrawing the
 * screen or the command line.
 */
void check_for_delay(int check_msg_scroll)
{
  if ((emsg_on_display || (check_msg_scroll && msg_scroll))
      && !did_wait_return
      && emsg_silent == 0) {
    ui_flush();
    os_delay(1000L, true);
    emsg_on_display = FALSE;
    if (check_msg_scroll)
      msg_scroll = FALSE;
  }
}

/// (Re)allocates a window grid if size changed while in ext_multigrid mode.
/// Updates size, offsets and handle for the grid regardless.
///
/// If "doclear" is true, don't try to copy from the old grid rather clear the
/// resized grid.
void win_grid_alloc(win_T *wp)
{
  ScreenGrid *grid = &wp->w_grid;

  int rows = wp->w_height_inner;
  int cols = wp->w_width_inner;

  bool want_allocation = ui_has(kUIMultigrid) || wp->w_floating;
  bool has_allocation = (grid->chars != NULL);

  if (grid->Rows != rows) {
    wp->w_lines_valid = 0;
    xfree(wp->w_lines);
    wp->w_lines = xcalloc(rows+1, sizeof(wline_T));
  }

  int was_resized = false;
  if ((has_allocation != want_allocation)
      || grid->Rows != rows
      || grid->Columns != cols) {
    if (want_allocation) {
      grid_alloc(grid, rows, cols, wp->w_grid.valid, wp->w_grid.valid);
      grid->valid = true;
    } else {
      // Single grid mode, all rendering will be redirected to default_grid.
      // Only keep track of the size and offset of the window.
      grid_free(grid);
      grid->Rows = rows;
      grid->Columns = cols;
      grid->valid = false;
    }
    was_resized = true;
  } else if (want_allocation && has_allocation && !wp->w_grid.valid) {
    grid_invalidate(grid);
    grid->valid = true;
  }

  grid->row_offset = wp->w_winrow;
  grid->col_offset = wp->w_wincol;

  // send grid resize event if:
  // - a grid was just resized
  // - screen_resize was called and all grid sizes must be sent
  // - the UI wants multigrid event (necessary)
  if ((send_grid_resize || was_resized) && want_allocation) {
    ui_call_grid_resize(grid->handle, grid->Columns, grid->Rows);
  }
}

/// assign a handle to the grid. The grid need not be allocated.
void grid_assign_handle(ScreenGrid *grid)
{
  static int last_grid_handle = DEFAULT_GRID_HANDLE;

  // only assign a grid handle if not already
  if (grid->handle == 0) {
    grid->handle = ++last_grid_handle;
  }
}

/// Resize the screen to Rows and Columns.
///
/// Allocate default_grid.chars[] and other grid arrays.
///
/// There may be some time between setting Rows and Columns and (re)allocating
/// default_grid arrays.  This happens when starting up and when
/// (manually) changing the shell size.  Always use default_grid.Rows and
/// default_grid.Columns to access items in default_grid.chars[].  Use Rows
/// and Columns for positioning text etc. where the final size of the shell is
/// needed.
void screenalloc(void)
{
  static bool entered = false;  // avoid recursiveness
  int retry_count = 0;

retry:
  // Allocation of the screen buffers is done only when the size changes and
  // when Rows and Columns have been set and we have started doing full
  // screen stuff.
  if ((default_grid.chars != NULL
       && Rows == default_grid.Rows
       && Columns == default_grid.Columns
       )
      || Rows == 0
      || Columns == 0
      || (!full_screen && default_grid.chars == NULL)) {
    return;
  }

  /*
   * It's possible that we produce an out-of-memory message below, which
   * will cause this function to be called again.  To break the loop, just
   * return here.
   */
  if (entered)
    return;
  entered = TRUE;

  /*
   * Note that the window sizes are updated before reallocating the arrays,
   * thus we must not redraw here!
   */
  ++RedrawingDisabled;

  // win_new_shellsize will recompute floats position, but tell the
  // compositor to not redraw them yet
  ui_comp_set_screen_valid(false);

  win_new_shellsize();      /* fit the windows in the new sized shell */

  comp_col();           /* recompute columns for shown command and ruler */

  // We're changing the size of the screen.
  // - Allocate new arrays for default_grid
  // - Move lines from the old arrays into the new arrays, clear extra
  //   lines (unless the screen is going to be cleared).
  // - Free the old arrays.
  //
  // If anything fails, make grid arrays NULL, so we don't do anything!
  // Continuing with the old arrays may result in a crash, because the
  // size is wrong.

  grid_alloc(&default_grid, Rows, Columns, true, true);
  StlClickDefinition *new_tab_page_click_defs = xcalloc(
      (size_t)Columns, sizeof(*new_tab_page_click_defs));

  clear_tab_page_click_defs(tab_page_click_defs, tab_page_click_defs_size);
  xfree(tab_page_click_defs);

  tab_page_click_defs = new_tab_page_click_defs;
  tab_page_click_defs_size = Columns;

  default_grid.row_offset = 0;
  default_grid.col_offset = 0;
  default_grid.handle = DEFAULT_GRID_HANDLE;

  must_redraw = CLEAR;  // need to clear the screen later

  entered = FALSE;
  --RedrawingDisabled;

  /*
   * Do not apply autocommands more than 3 times to avoid an endless loop
   * in case applying autocommands always changes Rows or Columns.
   */
  if (starting == 0 && ++retry_count <= 3) {
    apply_autocmds(EVENT_VIMRESIZED, NULL, NULL, FALSE, curbuf);
    /* In rare cases, autocommands may have altered Rows or Columns,
    * jump back to check if we need to allocate the screen again. */
    goto retry;
  }
}

void grid_alloc(ScreenGrid *grid, int rows, int columns, bool copy, bool valid)
{
  int new_row;
  ScreenGrid new = *grid;

  size_t ncells = (size_t)((rows+1) * columns);
  new.chars = xmalloc(ncells * sizeof(schar_T));
  new.attrs = xmalloc(ncells * sizeof(sattr_T));
  new.line_offset = xmalloc((size_t)(rows * sizeof(unsigned)));
  new.line_wraps = xmalloc((size_t)(rows * sizeof(char_u)));

  new.Rows = rows;
  new.Columns = columns;

  for (new_row = 0; new_row < new.Rows; new_row++) {
    new.line_offset[new_row] = new_row * new.Columns;
    new.line_wraps[new_row] = false;

    grid_clear_line(&new, new.line_offset[new_row], columns, valid);

    if (copy) {
      // If the screen is not going to be cleared, copy as much as
      // possible from the old screen to the new one and clear the rest
      // (used when resizing the window at the "--more--" prompt or when
      // executing an external command, for the GUI).
      if (new_row < grid->Rows && grid->chars != NULL) {
        int len = MIN(grid->Columns, new.Columns);
        memmove(new.chars + new.line_offset[new_row],
                grid->chars + grid->line_offset[new_row],
                (size_t)len * sizeof(schar_T));
        memmove(new.attrs + new.line_offset[new_row],
                grid->attrs + grid->line_offset[new_row],
                (size_t)len * sizeof(sattr_T));
      }
    }
  }
  grid_free(grid);
  *grid = new;

  // Share a single scratch buffer for all grids, by
  // ensuring it is as wide as the widest grid.
  if (linebuf_size < (size_t)columns) {
    xfree(linebuf_char);
    xfree(linebuf_attr);
    linebuf_char = xmalloc(columns * sizeof(schar_T));
    linebuf_attr = xmalloc(columns * sizeof(sattr_T));
    linebuf_size = columns;
  }
}

void grid_free(ScreenGrid *grid)
{
  xfree(grid->chars);
  xfree(grid->attrs);
  xfree(grid->line_offset);
  xfree(grid->line_wraps);

  grid->chars = NULL;
  grid->attrs = NULL;
  grid->line_offset = NULL;
  grid->line_wraps = NULL;
}

/// Doesn't allow reinit, so must only be called by free_all_mem!
void screen_free_all_mem(void)
{
  grid_free(&default_grid);
  xfree(linebuf_char);
  xfree(linebuf_attr);
}

/// Clear tab_page_click_defs table
///
/// @param[out]  tpcd  Table to clear.
/// @param[in]  tpcd_size  Size of the table.
void clear_tab_page_click_defs(StlClickDefinition *const tpcd,
                               const long tpcd_size)
{
  if (tpcd != NULL) {
    for (long i = 0; i < tpcd_size; i++) {
      if (i == 0 || tpcd[i].func != tpcd[i - 1].func) {
        xfree(tpcd[i].func);
      }
    }
    memset(tpcd, 0, (size_t) tpcd_size * sizeof(tpcd[0]));
  }
}

void screenclear(void)
{
  check_for_delay(false);
  screenalloc();  // allocate screen buffers if size changed

  int i;

  if (starting == NO_SCREEN || default_grid.chars == NULL) {
    return;
  }

  // blank out the default grid
  for (i = 0; i < default_grid.Rows; i++) {
    grid_clear_line(&default_grid, default_grid.line_offset[i],
                    (int)default_grid.Columns, true);
    default_grid.line_wraps[i] = false;
  }

  ui_call_grid_clear(1);  // clear the display
  ui_comp_set_screen_valid(true);

  clear_cmdline = false;
  mode_displayed = false;

  redraw_all_later(NOT_VALID);
  redraw_cmdline = true;
  redraw_tabline = true;
  redraw_popupmenu = true;
  pum_invalidate();
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_floating) {
      wp->w_redr_type = CLEAR;
    }
  }
  if (must_redraw == CLEAR) {
    must_redraw = NOT_VALID;  // no need to clear again
  }
  compute_cmdrow();
  msg_row = cmdline_row;  // put cursor on last line for messages
  msg_col = 0;
  msg_scrolled = 0;  // can't scroll back
  msg_didany = false;
  msg_didout = false;
}

/// clear a line in the grid starting at "off" until "width" characters
/// are cleared.
static void grid_clear_line(ScreenGrid *grid, unsigned off, int width,
                            bool valid)
{
  for (int col = 0; col < width; col++) {
    schar_from_ascii(grid->chars[off + col], ' ');
  }
  int fill = valid ? 0 : -1;
  (void)memset(grid->attrs + off, fill, (size_t)width * sizeof(sattr_T));
}

void grid_invalidate(ScreenGrid *grid)
{
  (void)memset(grid->attrs, -1, grid->Rows * grid->Columns * sizeof(sattr_T));
}

bool grid_invalid_row(ScreenGrid *grid, int row)
{
  return grid->attrs[grid->line_offset[row]] < 0;
}



/// Copy part of a grid line for vertically split window.
static void linecopy(ScreenGrid *grid, int to, int from, int col, int width)
{
  unsigned off_to = grid->line_offset[to] + col;
  unsigned off_from = grid->line_offset[from] + col;

  memmove(grid->chars + off_to, grid->chars + off_from,
          width * sizeof(schar_T));
  memmove(grid->attrs + off_to, grid->attrs + off_from,
          width * sizeof(sattr_T));
}

/*
 * Set cursor to its position in the current window.
 */
void setcursor(void)
{
  if (redrawing()) {
    validate_cursor();

    ScreenGrid *grid = &curwin->w_grid;
    int row = curwin->w_wrow;
    int col = curwin->w_wcol;
    if (curwin->w_p_rl) {
      // With 'rightleft' set and the cursor on a double-wide character,
      // position it on the leftmost column.
      col = curwin->w_width_inner - curwin->w_wcol
                    - ((utf_ptr2cells(get_cursor_pos_ptr()) == 2
                        && vim_isprintc(gchar_cursor())) ? 2 : 1);
    }

    screen_adjust_grid(&grid, &row, &col);
    ui_grid_cursor_goto(grid->handle, row, col);
  }
}

/// Scroll 'line_count' lines at 'row' in window 'wp'.
///
/// Positive `line_count' means scrolling down, so that more space is available
/// at 'row'. Negative `line_count` implies deleting lines at `row`.
void win_scroll_lines(win_T *wp, int row, int line_count)
{
  if (!redrawing() || line_count == 0) {
    return;
  }

  // No lines are being moved, just draw over the entire area
  if (row + abs(line_count) >= wp->w_grid.Rows) {
    return;
  }

  if (line_count < 0) {
    grid_del_lines(&wp->w_grid, row, -line_count,
                   wp->w_grid.Rows, 0, wp->w_grid.Columns);
  } else {
    grid_ins_lines(&wp->w_grid, row, line_count,
                   wp->w_grid.Rows, 0, wp->w_grid.Columns);
  }
}

/*
 * The rest of the routines in this file perform screen manipulations. The
 * given operation is performed physically on the screen. The corresponding
 * change is also made to the internal screen image. In this way, the editor
 * anticipates the effect of editing changes on the appearance of the screen.
 * That way, when we call screenupdate a complete redraw isn't usually
 * necessary. Another advantage is that we can keep adding code to anticipate
 * screen changes, and in the meantime, everything still works.
 */


/// insert lines on the screen and move the existing lines down
/// 'line_count' is the number of lines to be inserted.
/// 'end' is the line after the scrolled part. Normally it is Rows.
/// 'col' is the column from with we start inserting.
//
/// 'row', 'col' and 'end' are relative to the start of the region.
void grid_ins_lines(ScreenGrid *grid, int row, int line_count, int end, int col,
                    int width)
{
  int i;
  int j;
  unsigned temp;

  int row_off = 0;
  screen_adjust_grid(&grid, &row_off, &col);
  row += row_off;
  end += row_off;

  if (line_count <= 0) {
    return;
  }

  // Shift line_offset[] line_count down to reflect the inserted lines.
  // Clear the inserted lines.
  for (i = 0; i < line_count; i++) {
    if (width != grid->Columns) {
      // need to copy part of a line
      j = end - 1 - i;
      while ((j -= line_count) >= row) {
        linecopy(grid, j + line_count, j, col, width);
      }
      j += line_count;
      grid_clear_line(grid, grid->line_offset[j] + col, width, false);
      grid->line_wraps[j] = false;
    } else {
      j = end - 1 - i;
      temp = grid->line_offset[j];
      while ((j -= line_count) >= row) {
        grid->line_offset[j + line_count] = grid->line_offset[j];
        grid->line_wraps[j + line_count] = grid->line_wraps[j];
      }
      grid->line_offset[j + line_count] = temp;
      grid->line_wraps[j + line_count] = false;
      grid_clear_line(grid, temp, (int)grid->Columns, false);
    }
  }

  ui_call_grid_scroll(grid->handle, row, end, col, col+width, -line_count, 0);

  return;
}

/// delete lines on the screen and move lines up.
/// 'end' is the line after the scrolled part. Normally it is Rows.
/// When scrolling region used 'off' is the offset from the top for the region.
/// 'row' and 'end' are relative to the start of the region.
void grid_del_lines(ScreenGrid *grid, int row, int line_count, int end, int col,
                    int width)
{
  int j;
  int i;
  unsigned temp;

  int row_off = 0;
  screen_adjust_grid(&grid, &row_off, &col);
  row += row_off;
  end += row_off;

  if (line_count <= 0) {
    return;
  }

  // Now shift line_offset[] line_count up to reflect the deleted lines.
  // Clear the inserted lines.
  for (i = 0; i < line_count; i++) {
    if (width != grid->Columns) {
      // need to copy part of a line
      j = row + i;
      while ((j += line_count) <= end - 1) {
        linecopy(grid, j - line_count, j, col, width);
      }
      j -= line_count;
      grid_clear_line(grid, grid->line_offset[j] + col, width, false);
      grid->line_wraps[j] = false;
    } else {
      // whole width, moving the line pointers is faster
      j = row + i;
      temp = grid->line_offset[j];
      while ((j += line_count) <= end - 1) {
        grid->line_offset[j - line_count] = grid->line_offset[j];
        grid->line_wraps[j - line_count] = grid->line_wraps[j];
      }
      grid->line_offset[j - line_count] = temp;
      grid->line_wraps[j - line_count] = false;
      grid_clear_line(grid, temp, (int)grid->Columns, false);
    }
  }

  ui_call_grid_scroll(grid->handle, row, end, col, col+width, line_count, 0);

  return;
}


// Show the current mode and ruler.
//
// If clear_cmdline is TRUE, clear the rest of the cmdline.
// If clear_cmdline is FALSE there may be a message there that needs to be
// cleared only if a mode is shown.
// Return the length of the message (0 if no message).
int showmode(void)
{
  int need_clear;
  int length = 0;
  int do_mode;
  int attr;
  int nwr_save;
  int sub_attr;

  if (ui_has(kUIMessages) && clear_cmdline) {
    msg_ext_clear(true);
  }

  // don't make non-flushed message part of the showmode
  msg_ext_ui_flush();

  do_mode = ((p_smd && msg_silent == 0)
             && ((State & TERM_FOCUS)
                 || (State & INSERT)
                 || restart_edit
                 || VIsual_active));
  if (do_mode || reg_recording != 0) {
    // Don't show mode right now, when not redrawing or inside a mapping.
    // Call char_avail() only when we are going to show something, because
    // it takes a bit of time.
    if (!redrawing() || (char_avail() && !KeyTyped) || msg_silent != 0) {
      redraw_cmdline = TRUE;                    /* show mode later */
      return 0;
    }

    nwr_save = need_wait_return;

    /* wait a bit before overwriting an important message */
    check_for_delay(FALSE);

    /* if the cmdline is more than one line high, erase top lines */
    need_clear = clear_cmdline;
    if (clear_cmdline && cmdline_row < Rows - 1) {
      msg_clr_cmdline();  // will reset clear_cmdline
    }

    /* Position on the last line in the window, column 0 */
    msg_pos_mode();
    attr = HL_ATTR(HLF_CM);                     // Highlight mode

    // When the screen is too narrow to show the entire mode messsage,
    // avoid scrolling and truncate instead.
    msg_no_more = true;
    int save_lines_left = lines_left;
    lines_left = 0;

    if (do_mode) {
      MSG_PUTS_ATTR("--", attr);
      // CTRL-X in Insert mode
      if (edit_submode != NULL && !shortmess(SHM_COMPLETIONMENU)) {
        // These messages can get long, avoid a wrap in a narrow window.
        // Prefer showing edit_submode_extra. With external messages there
        // is no imposed limit.
        if (ui_has(kUIMessages)) {
          length = INT_MAX;
        } else {
          length = (Rows - msg_row) * Columns - 3;
        }
        if (edit_submode_extra != NULL) {
          length -= vim_strsize(edit_submode_extra);
        }
        if (length > 0) {
          if (edit_submode_pre != NULL)
            length -= vim_strsize(edit_submode_pre);
          if (length - vim_strsize(edit_submode) > 0) {
            if (edit_submode_pre != NULL) {
              msg_puts_attr((const char *)edit_submode_pre, attr);
            }
            msg_puts_attr((const char *)edit_submode, attr);
          }
          if (edit_submode_extra != NULL) {
            MSG_PUTS_ATTR(" ", attr);  // Add a space in between.
            if ((int)edit_submode_highl < (int)HLF_COUNT) {
              sub_attr = win_hl_attr(curwin, edit_submode_highl);
            } else {
              sub_attr = attr;
            }
            msg_puts_attr((const char *)edit_submode_extra, sub_attr);
          }
        }
      } else {
        if (State & TERM_FOCUS) {
          MSG_PUTS_ATTR(_(" TERMINAL"), attr);
        } else if (State & VREPLACE_FLAG)
          MSG_PUTS_ATTR(_(" VREPLACE"), attr);
        else if (State & REPLACE_FLAG)
          MSG_PUTS_ATTR(_(" REPLACE"), attr);
        else if (State & INSERT) {
          if (p_ri)
            MSG_PUTS_ATTR(_(" REVERSE"), attr);
          MSG_PUTS_ATTR(_(" INSERT"), attr);
        } else if (restart_edit == 'I' || restart_edit == 'i'
                   || restart_edit == 'a') {
          MSG_PUTS_ATTR(_(" (insert)"), attr);
        } else if (restart_edit == 'R') {
          MSG_PUTS_ATTR(_(" (replace)"), attr);
        } else if (restart_edit == 'V') {
          MSG_PUTS_ATTR(_(" (vreplace)"), attr);
        }
        if (p_hkmap) {
          MSG_PUTS_ATTR(_(" Hebrew"), attr);
        }
        if (State & LANGMAP) {
          if (curwin->w_p_arab) {
            MSG_PUTS_ATTR(_(" Arabic"), attr);
          } else if (get_keymap_str(curwin, (char_u *)" (%s)",
                                    NameBuff, MAXPATHL)) {
            MSG_PUTS_ATTR(NameBuff, attr);
          }
        }
        if ((State & INSERT) && p_paste)
          MSG_PUTS_ATTR(_(" (paste)"), attr);

        if (VIsual_active) {
          char *p;

          /* Don't concatenate separate words to avoid translation
           * problems. */
          switch ((VIsual_select ? 4 : 0)
                  + (VIsual_mode == Ctrl_V) * 2
                  + (VIsual_mode == 'V')) {
          case 0: p = N_(" VISUAL"); break;
          case 1: p = N_(" VISUAL LINE"); break;
          case 2: p = N_(" VISUAL BLOCK"); break;
          case 4: p = N_(" SELECT"); break;
          case 5: p = N_(" SELECT LINE"); break;
          default: p = N_(" SELECT BLOCK"); break;
          }
          MSG_PUTS_ATTR(_(p), attr);
        }
        MSG_PUTS_ATTR(" --", attr);
      }

      need_clear = TRUE;
    }
    if (reg_recording != 0
        && edit_submode == NULL             // otherwise it gets too long
        ) {
      recording_mode(attr);
      need_clear = true;
    }

    mode_displayed = TRUE;
    if (need_clear || clear_cmdline)
      msg_clr_eos();
    msg_didout = FALSE;                 /* overwrite this message */
    length = msg_col;
    msg_col = 0;
    msg_no_more = false;
    lines_left = save_lines_left;
    need_wait_return = nwr_save;        // never ask for hit-return for this
  } else if (clear_cmdline && msg_silent == 0) {
    // Clear the whole command line.  Will reset "clear_cmdline".
    msg_clr_cmdline();
  }

  // NB: also handles clearing the showmode if it was emtpy or disabled
  msg_ext_flush_showmode();

  /* In Visual mode the size of the selected area must be redrawn. */
  if (VIsual_active)
    clear_showcmd();

  // If the last window has no status line, the ruler is after the mode
  // message and must be redrawn
  win_T *last = lastwin_nofloating();
  if (redrawing() && last->w_status_height == 0) {
    win_redr_ruler(last, true);
  }
  redraw_cmdline = false;
  clear_cmdline = false;

  return length;
}

/*
 * Position for a mode message.
 */
static void msg_pos_mode(void)
{
  msg_col = 0;
  msg_row = Rows - 1;
}

/// Delete mode message.  Used when ESC is typed which is expected to end
/// Insert mode (but Insert mode didn't end yet!).
/// Caller should check "mode_displayed".
void unshowmode(bool force)
{
  // Don't delete it right now, when not redrawing or inside a mapping.
  if (!redrawing() || (!force && char_avail() && !KeyTyped)) {
    redraw_cmdline = true;  // delete mode later
  } else {
    clearmode();
  }
}

// Clear the mode message.
void clearmode(void)
{
  msg_ext_ui_flush();
  msg_pos_mode();
  if (reg_recording != 0) {
    recording_mode(HL_ATTR(HLF_CM));
  }
  msg_clr_eos();
  msg_ext_flush_showmode();
}

static void recording_mode(int attr)
{
  MSG_PUTS_ATTR(_("recording"), attr);
  if (!shortmess(SHM_RECORDING)) {
    char_u s[4];
    snprintf((char *)s, ARRAY_SIZE(s), " @%c", reg_recording);
    MSG_PUTS_ATTR(s, attr);
  }
}

/*
 * Draw the tab pages line at the top of the Vim window.
 */
static void draw_tabline(void)
{
  int tabcount = 0;
  int tabwidth = 0;
  int col = 0;
  int scol = 0;
  int attr;
  win_T       *wp;
  win_T       *cwp;
  int wincount;
  int modified;
  int c;
  int len;
  int attr_nosel = HL_ATTR(HLF_TP);
  int attr_fill = HL_ATTR(HLF_TPF);
  char_u      *p;
  int room;
  int use_sep_chars = (t_colors < 8
                       );

  if (default_grid.chars == NULL) {
    return;
  }
  redraw_tabline = false;

  if (ui_has(kUITabline)) {
    ui_ext_tabline_update();
    return;
  }

  if (tabline_height() < 1)
    return;


  // Init TabPageIdxs[] to zero: Clicking outside of tabs has no effect.
  assert(Columns == tab_page_click_defs_size);
  clear_tab_page_click_defs(tab_page_click_defs, tab_page_click_defs_size);

  /* Use the 'tabline' option if it's set. */
  if (*p_tal != NUL) {
    int saved_did_emsg = did_emsg;

    // Check for an error.  If there is one we would loop in redrawing the
    // screen.  Avoid that by making 'tabline' empty.
    did_emsg = false;
    win_redr_custom(NULL, false);
    if (did_emsg) {
      set_string_option_direct((char_u *)"tabline", -1,
                               (char_u *)"", OPT_FREE, SID_ERROR);
    }
    did_emsg |= saved_did_emsg;
  } else {
    FOR_ALL_TABS(tp) {
      ++tabcount;
    }

    if (tabcount > 0) {
      tabwidth = (Columns - 1 + tabcount / 2) / tabcount;
    }

    if (tabwidth < 6) {
      tabwidth = 6;
    }

    attr = attr_nosel;
    tabcount = 0;

    FOR_ALL_TABS(tp) {
      if (col >= Columns - 4) {
        break;
      }

      scol = col;

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
        grid_putchar(&default_grid, '|', 0, col++, attr);
      }

      if (tp->tp_topframe != topframe) {
        attr = win_hl_attr(cwp, HLF_TP);
      }

      grid_putchar(&default_grid, ' ', 0, col++, attr);

      modified = false;

      for (wincount = 0; wp != NULL; wp = wp->w_next, ++wincount) {
        if (bufIsChanged(wp->w_buffer)) {
          modified = true;
        }
      }


      if (modified || wincount > 1) {
        if (wincount > 1) {
          vim_snprintf((char *)NameBuff, MAXPATHL, "%d", wincount);
          len = (int)STRLEN(NameBuff);
          if (col + len >= Columns - 3) {
            break;
          }
          grid_puts_len(&default_grid, NameBuff, len, 0, col,
                        hl_combine_attr(attr, win_hl_attr(cwp, HLF_T)));
          col += len;
        }
        if (modified) {
          grid_puts_len(&default_grid, (char_u *)"+", 1, 0, col++, attr);
        }
        grid_putchar(&default_grid, ' ', 0, col++, attr);
      }

      room = scol - col + tabwidth - 1;
      if (room > 0) {
        /* Get buffer name in NameBuff[] */
        get_trans_bufname(cwp->w_buffer);
        (void)shorten_dir(NameBuff);
        len = vim_strsize(NameBuff);
        p = NameBuff;
        while (len > room) {
          len -= ptr2cells(p);
          MB_PTR_ADV(p);
        }
        if (len > Columns - col - 1) {
          len = Columns - col - 1;
        }

        grid_puts_len(&default_grid, p, (int)STRLEN(p), 0, col, attr);
        col += len;
      }
      grid_putchar(&default_grid, ' ', 0, col++, attr);

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

    if (use_sep_chars)
      c = '_';
    else
      c = ' ';
    grid_fill(&default_grid, 0, 1, col, (int)Columns, c, c,
              attr_fill);

    /* Put an "X" for closing the current tab if there are several. */
    if (first_tabpage->tp_next != NULL) {
      grid_putchar(&default_grid, 'X', 0, (int)Columns - 1,
                   attr_nosel);
      tab_page_click_defs[Columns - 1] = (StlClickDefinition) {
        .type = kStlClickTabClose,
        .tabnr = 999,
        .func = NULL,
      };
    }
  }

  /* Reset the flag here again, in case evaluating 'tabline' causes it to be
   * set. */
  redraw_tabline = FALSE;
}

void ui_ext_tabline_update(void)
{
  Array tabs = ARRAY_DICT_INIT;
  FOR_ALL_TABS(tp) {
    Dictionary tab_info = ARRAY_DICT_INIT;
    PUT(tab_info, "tab", TABPAGE_OBJ(tp->handle));

    win_T *cwp = (tp == curtab) ? curwin : tp->tp_curwin;
    get_trans_bufname(cwp->w_buffer);
    PUT(tab_info, "name", STRING_OBJ(cstr_to_string((char *)NameBuff)));

    ADD(tabs, DICTIONARY_OBJ(tab_info));
  }
  ui_call_tabline_update(curtab->handle, tabs);
}

/*
 * Get buffer name for "buf" into NameBuff[].
 * Takes care of special buffer names and translates special characters.
 */
void get_trans_bufname(buf_T *buf)
{
  if (buf_spname(buf) != NULL)
    STRLCPY(NameBuff, buf_spname(buf), MAXPATHL);
  else
    home_replace(buf, buf->b_fname, NameBuff, MAXPATHL, TRUE);
  trans_characters(NameBuff, MAXPATHL);
}

/*
 * Get the character to use in a status line.  Get its attributes in "*attr".
 */
static int fillchar_status(int *attr, win_T *wp)
{
  int fill;
  bool is_curwin = (wp == curwin);
  if (is_curwin) {
    *attr = win_hl_attr(wp, HLF_S);
    fill = wp->w_p_fcs_chars.stl;
  } else {
    *attr = win_hl_attr(wp, HLF_SNC);
    fill = wp->w_p_fcs_chars.stlnc;
  }
  /* Use fill when there is highlighting, and highlighting of current
   * window differs, or the fillchars differ, or this is not the
   * current window */
  if (*attr != 0 && ((win_hl_attr(wp, HLF_S) != win_hl_attr(wp, HLF_SNC)
                      || !is_curwin || ONE_WINDOW)
                     || (wp->w_p_fcs_chars.stl != wp->w_p_fcs_chars.stlnc))) {
    return fill;
  }
  if (is_curwin) {
    return '^';
  }
  return '=';
}

/*
 * Get the character to use in a separator between vertically split windows.
 * Get its attributes in "*attr".
 */
static int fillchar_vsep(win_T *wp, int *attr)
{
  *attr = win_hl_attr(wp, HLF_C);
  return wp->w_p_fcs_chars.vert;
}

/*
 * Return TRUE if redrawing should currently be done.
 */
int redrawing(void)
{
  return !RedrawingDisabled
         && !(p_lz && char_avail() && !KeyTyped && !do_redraw);
}

/*
 * Return TRUE if printing messages should currently be done.
 */
int messaging(void)
{
  return !(p_lz && char_avail() && !KeyTyped);
}

/*
 * Show current status info in ruler and various other places
 * If always is FALSE, only show ruler if position has changed.
 */
void showruler(int always)
{
  if (!always && !redrawing())
    return;
  if ((*p_stl != NUL || *curwin->w_p_stl != NUL) && curwin->w_status_height) {
    redraw_custom_statusline(curwin);
  } else {
    win_redr_ruler(curwin, always);
  }

  if (need_maketitle
      || (p_icon && (stl_syntax & STL_IN_ICON))
      || (p_title && (stl_syntax & STL_IN_TITLE))
      )
    maketitle();
  /* Redraw the tab pages line if needed. */
  if (redraw_tabline)
    draw_tabline();
}

static void win_redr_ruler(win_T *wp, int always)
{
  static bool did_show_ext_ruler = false;

  // If 'ruler' off or redrawing disabled, don't do anything
  if (!p_ru) {
    return;
  }

  /*
   * Check if cursor.lnum is valid, since win_redr_ruler() may be called
   * after deleting lines, before cursor.lnum is corrected.
   */
  if (wp->w_cursor.lnum > wp->w_buffer->b_ml.ml_line_count)
    return;

  /* Don't draw the ruler while doing insert-completion, it might overwrite
   * the (long) mode message. */
  if (wp == lastwin && lastwin->w_status_height == 0)
    if (edit_submode != NULL)
      return;

  if (*p_ruf) {
    int save_called_emsg = called_emsg;

    called_emsg = FALSE;
    win_redr_custom(wp, TRUE);
    if (called_emsg)
      set_string_option_direct((char_u *)"rulerformat", -1,
          (char_u *)"", OPT_FREE, SID_ERROR);
    called_emsg |= save_called_emsg;
    return;
  }

  /*
   * Check if not in Insert mode and the line is empty (will show "0-1").
   */
  int empty_line = FALSE;
  if (!(State & INSERT)
      && *ml_get_buf(wp->w_buffer, wp->w_cursor.lnum, FALSE) == NUL)
    empty_line = TRUE;

  /*
   * Only draw the ruler when something changed.
   */
  validate_virtcol_win(wp);
  if (       redraw_cmdline
             || always
             || wp->w_cursor.lnum != wp->w_ru_cursor.lnum
             || wp->w_cursor.col != wp->w_ru_cursor.col
             || wp->w_virtcol != wp->w_ru_virtcol
             || wp->w_cursor.coladd != wp->w_ru_cursor.coladd
             || wp->w_topline != wp->w_ru_topline
             || wp->w_buffer->b_ml.ml_line_count != wp->w_ru_line_count
             || wp->w_topfill != wp->w_ru_topfill
             || empty_line != wp->w_ru_empty) {

    int width;
    int row;
    int fillchar;
    int attr;
    int off;
    bool part_of_status = false;

    if (wp->w_status_height) {
      row = W_ENDROW(wp);
      fillchar = fillchar_status(&attr, wp);
      off = wp->w_wincol;
      width = wp->w_width;
      part_of_status = true;
    } else {
      row = Rows - 1;
      fillchar = ' ';
      attr = 0;
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
    char_u buffer[RULER_BUF_LEN];

    /*
     * Some sprintfs return the length, some return a pointer.
     * To avoid portability problems we use strlen() here.
     */
    vim_snprintf((char *)buffer, RULER_BUF_LEN, "%" PRId64 ",",
        (wp->w_buffer->b_ml.ml_flags & ML_EMPTY) ? (int64_t)0L
                                                 : (int64_t)wp->w_cursor.lnum);
    size_t len = STRLEN(buffer);
    col_print(buffer + len, RULER_BUF_LEN - len,
        empty_line ? 0 : (int)wp->w_cursor.col + 1,
        (int)virtcol + 1);

    /*
     * Add a "50%" if there is room for it.
     * On the last line, don't print in the last column (scrolls the
     * screen up on some terminals).
     */
    int i = (int)STRLEN(buffer);
    get_rel_pos(wp, buffer + i + 1, RULER_BUF_LEN - i - 1);
    int o = i + vim_strsize(buffer + i + 1);
    if (wp->w_status_height == 0) {  // can't use last char of screen
      o++;
    }
    int this_ru_col = ru_col - (Columns - width);
    if (this_ru_col < 0) {
      this_ru_col = 0;
    }
    // Never use more than half the window/screen width, leave the other half
    // for the filename.
    if (this_ru_col < (width + 1) / 2) {
      this_ru_col = (width + 1) / 2;
    }
    if (this_ru_col + o < width) {
      // Need at least 3 chars left for get_rel_pos() + NUL.
      while (this_ru_col + o < width && RULER_BUF_LEN > i + 4) {
        i += utf_char2bytes(fillchar, buffer + i);
        o++;
      }
      get_rel_pos(wp, buffer + i, RULER_BUF_LEN - i);
    }

    if (ui_has(kUIMessages) && !part_of_status) {
      Array content = ARRAY_DICT_INIT;
      Array chunk = ARRAY_DICT_INIT;
      ADD(chunk, INTEGER_OBJ(attr));
      ADD(chunk, STRING_OBJ(cstr_to_string((char *)buffer)));
      ADD(content, ARRAY_OBJ(chunk));
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

      grid_puts(&default_grid, buffer, row, this_ru_col + off, attr);
      i = redraw_cmdline;
      grid_fill(&default_grid, row, row + 1,
                this_ru_col + off + (int)STRLEN(buffer), off + width, fillchar,
                fillchar, attr);
      // don't redraw the cmdline because of showing the ruler
      redraw_cmdline = i;
    }

    wp->w_ru_cursor = wp->w_cursor;
    wp->w_ru_virtcol = wp->w_virtcol;
    wp->w_ru_empty = empty_line;
    wp->w_ru_topline = wp->w_topline;
    wp->w_ru_line_count = wp->w_buffer->b_ml.ml_line_count;
    wp->w_ru_topfill = wp->w_topfill;
  }
}

/*
 * Return the width of the 'number' and 'relativenumber' column.
 * Caller may need to check if 'number' or 'relativenumber' is set.
 * Otherwise it depends on 'numberwidth' and the line count.
 */
int number_width(win_T *wp)
{
  int n;
  linenr_T lnum;

  if (wp->w_p_rnu && !wp->w_p_nu) {
    // cursor line shows "0"
    lnum = wp->w_height_inner;
  } else {
    // cursor line shows absolute line number
    lnum = wp->w_buffer->b_ml.ml_line_count;
  }

  if (lnum == wp->w_nrwidth_line_count)
    return wp->w_nrwidth_width;
  wp->w_nrwidth_line_count = lnum;

  n = 0;
  do {
    lnum /= 10;
    ++n;
  } while (lnum > 0);

  /* 'numberwidth' gives the minimal width plus one */
  if (n < wp->w_p_nuw - 1)
    n = wp->w_p_nuw - 1;

  wp->w_nrwidth_width = n;
  return n;
}

/// Set dimensions of the Nvim application "shell".
void screen_resize(int width, int height)
{
  static int busy = FALSE;

  // Avoid recursiveness, can happen when setting the window size causes
  // another window-changed signal.
  if (updating_screen || busy) {
    return;
  }

  if (width < 0 || height < 0)      /* just checking... */
    return;

  if (State == HITRETURN || State == SETWSIZE) {
    /* postpone the resizing */
    State = SETWSIZE;
    return;
  }

  /* curwin->w_buffer can be NULL when we are closing a window and the
   * buffer has already been closed and removing a scrollbar causes a resize
   * event. Don't resize then, it will happen after entering another buffer.
   */
  if (curwin->w_buffer == NULL)
    return;

  ++busy;

  Rows = height;
  Columns = width;
  check_shellsize();
  height = Rows;
  width = Columns;
  ui_call_grid_resize(1, width, height);

  send_grid_resize = true;

  /* The window layout used to be adjusted here, but it now happens in
   * screenalloc() (also invoked from screenclear()).  That is because the
   * "busy" check above may skip this, but not screenalloc(). */

  if (State != ASKMORE && State != EXTERNCMD && State != CONFIRM) {
    screenclear();
  }

  if (starting != NO_SCREEN) {
    maketitle();
    changed_line_abv_curs();
    invalidate_botline();

    /*
     * We only redraw when it's needed:
     * - While at the more prompt or executing an external command, don't
     *   redraw, but position the cursor.
     * - While editing the command line, only redraw that.
     * - in Ex mode, don't redraw anything.
     * - Otherwise, redraw right now, and position the cursor.
     * Always need to call update_screen() or screenalloc(), to make
     * sure Rows/Columns and the size of the screen is correct!
     */
    if (State == ASKMORE || State == EXTERNCMD || State == CONFIRM
        || exmode_active) {
      screenalloc();
      repeat_message();
    } else {
      if (curwin->w_p_scb)
        do_check_scrollbind(TRUE);
      if (State & CMDLINE) {
        redraw_popupmenu = false;
        update_screen(NOT_VALID);
        redrawcmdline();
        if (pum_drawn()) {
          cmdline_pum_display(false);
        }
      } else {
        update_topline();
        if (pum_drawn()) {
          // TODO(bfredl): ins_compl_show_pum wants to redraw the screen first.
          // For now make sure the nested update_screen(0) won't redraw the
          // pum at the old position. Try to untangle this later.
          redraw_popupmenu = false;
          ins_compl_show_pum();
        }
        update_screen(NOT_VALID);
        if (redrawing()) {
          setcursor();
        }
      }
    }
  }
  ui_flush();
  --busy;
}

/// Check if the new Nvim application "shell" dimensions are valid.
/// Correct it if it's too small or way too big.
void check_shellsize(void)
{
  if (Rows < min_rows()) {
    // need room for one window and command line
    Rows = min_rows();
  }
  limit_screen_size();
}

// Limit Rows and Columns to avoid an overflow in Rows * Columns.
void limit_screen_size(void)
{
  if (Columns < MIN_COLUMNS) {
    Columns = MIN_COLUMNS;
  } else if (Columns > 10000) {
    Columns = 10000;
  }

  if (Rows > 1000) {
    Rows = 1000;
  }
}

void win_new_shellsize(void)
{
  static long old_Rows = 0;
  static long old_Columns = 0;

  if (old_Rows != Rows) {
    // if 'window' uses the whole screen, keep it using that */
    if (p_window == old_Rows - 1 || old_Rows == 0) {
      p_window = Rows - 1;
    }
    old_Rows = Rows;
    shell_new_rows();  // update window sizes
  }
  if (old_Columns != Columns) {
    old_Columns = Columns;
    shell_new_columns();  // update window sizes
  }
}

win_T *get_win_by_grid_handle(handle_T handle)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_grid.handle == handle) {
      return wp;
    }
  }
  return NULL;
}
