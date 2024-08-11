// vim: set fdm=marker fdl=1 fdc=3

// fold.c: code for folding

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_session.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/indent.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/ops.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/search.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/types_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"

// local declarations. {{{1
// typedef fold_T {{{2

// The toplevel folds for each window are stored in the w_folds growarray.
// Each toplevel fold can contain an array of second level folds in the
// fd_nested growarray.
// The info stored in both growarrays is the same: An array of fold_T.

typedef struct {
  linenr_T fd_top;              // first line of fold; for nested fold
                                // relative to parent
  linenr_T fd_len;              // number of lines in the fold
  garray_T fd_nested;           // array of nested folds
  char fd_flags;                // see below
  TriState fd_small;            // kTrue, kFalse, or kNone: fold smaller than
                                // 'foldminlines'; kNone applies to nested
                                // folds too
} fold_T;

enum {
  FD_OPEN = 0,    // fold is open (nested ones can be closed)
  FD_CLOSED = 1,  // fold is closed
  FD_LEVEL = 2,   // depends on 'foldlevel' (nested folds too)
};

#define MAX_LEVEL       20      // maximum fold depth

// Define "fline_T", passed to get fold level for a line. {{{2
typedef struct {
  win_T *wp;              // window
  linenr_T lnum;                // current line number
  linenr_T off;                 // offset between lnum and real line number
  linenr_T lnum_save;           // line nr used by foldUpdateIEMSRecurse()
  int lvl;                      // current level (-1 for undefined)
  int lvl_next;                 // level used for next line
  int start;                    // number of folds that are forced to start at
                                // this line.
  int end;                      // level of fold that is forced to end below
                                // this line
  int had_end;                  // level of fold that is forced to end above
                                // this line (copy of "end" of prev. line)
} fline_T;

// Flag is set when redrawing is needed.
static bool fold_changed;

// Function used by foldUpdateIEMSRecurse
typedef void (*LevelGetter)(fline_T *);

// static functions {{{2

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.c.generated.h"
#endif
static const char *e_nofold = N_("E490: No fold found");

// While updating the folds lines between invalid_top and invalid_bot have an
// undefined fold level.  Only used for the window currently being updated.
static linenr_T invalid_top = 0;
static linenr_T invalid_bot = 0;

// When using 'foldexpr' we sometimes get the level of the next line, which
// calls foldlevel() to get the level of the current line, which hasn't been
// stored yet.  To get around this chicken-egg problem the level of the
// previous line is stored here when available.  prev_lnum is zero when the
// level is not available.
static linenr_T prev_lnum = 0;
static int prev_lnum_lvl = -1;

// Flags used for "done" argument of setManualFold.
#define DONE_NOTHING    0
#define DONE_ACTION     1       // did close or open a fold
#define DONE_FOLD       2       // did find a fold

static size_t foldstartmarkerlen;
static char *foldendmarker;
static size_t foldendmarkerlen;

// Exported folding functions. {{{1
// copyFoldingState() {{{2
/// Copy that folding state from window "wp_from" to window "wp_to".
void copyFoldingState(win_T *wp_from, win_T *wp_to)
{
  wp_to->w_fold_manual = wp_from->w_fold_manual;
  wp_to->w_foldinvalid = wp_from->w_foldinvalid;
  cloneFoldGrowArray(&wp_from->w_folds, &wp_to->w_folds);
}

// hasAnyFolding() {{{2
/// @return  true if there may be folded lines in window "win".
int hasAnyFolding(win_T *win)
{
  // very simple now, but can become more complex later
  return !win->w_buffer->terminal && win->w_p_fen
         && (!foldmethodIsManual(win) || !GA_EMPTY(&win->w_folds));
}

// hasFolding() {{{2
/// When returning true, *firstp and *lastp are set to the first and last
/// lnum of the sequence of folded lines (skipped when NULL).
///
/// @return  true if line "lnum" in window "win" is part of a closed fold.
bool hasFolding(win_T *win, linenr_T lnum, linenr_T *firstp, linenr_T *lastp)
{
  return hasFoldingWin(win, lnum, firstp, lastp, true, NULL);
}

// hasFoldingWin() {{{2
/// Search folds starting at lnum
/// @param lnum first line to search
/// @param[out] first first line of fold containing lnum
/// @param[out] lastp last line with a fold
/// @param cache when true: use cached values of window
/// @param[out] infop where to store fold info
///
/// @return true if range contains folds
bool hasFoldingWin(win_T *const win, const linenr_T lnum, linenr_T *const firstp,
                   linenr_T *const lastp, const bool cache, foldinfo_T *const infop)
{
  checkupdate(win);

  // Return quickly when there is no folding at all in this window.
  if (!hasAnyFolding(win)) {
    if (infop != NULL) {
      infop->fi_level = 0;
    }
    return false;
  }

  bool had_folded = false;
  linenr_T first = 0;
  linenr_T last = 0;

  if (cache) {
    // First look in cached info for displayed lines.  This is probably
    // the fastest, but it can only be used if the entry is still valid.
    const int x = find_wl_entry(win, lnum);
    if (x >= 0) {
      first = win->w_lines[x].wl_lnum;
      last = win->w_lines[x].wl_lastlnum;
      had_folded = win->w_lines[x].wl_folded;
    }
  }

  linenr_T lnum_rel = lnum;
  int level = 0;
  int low_level = 0;
  fold_T *fp;
  bool maybe_small = false;
  bool use_level = false;

  if (first == 0) {
    // Recursively search for a fold that contains "lnum".
    garray_T *gap = &win->w_folds;
    while (true) {
      if (!foldFind(gap, lnum_rel, &fp)) {
        break;
      }

      // Remember lowest level of fold that starts in "lnum".
      if (lnum_rel == fp->fd_top && low_level == 0) {
        low_level = level + 1;
      }

      first += fp->fd_top;
      last += fp->fd_top;

      // is this fold closed?
      had_folded = check_closed(win, fp, &use_level, level,
                                &maybe_small, lnum - lnum_rel);
      if (had_folded) {
        // Fold closed: Set last and quit loop.
        last += fp->fd_len - 1;
        break;
      }

      // Fold found, but it's open: Check nested folds.  Line number is
      // relative to containing fold.
      gap = &fp->fd_nested;
      lnum_rel -= fp->fd_top;
      level++;
    }
  }

  if (!had_folded) {
    if (infop != NULL) {
      infop->fi_level = level;
      infop->fi_lnum = lnum - lnum_rel;
      infop->fi_low_level = low_level == 0 ? level : low_level;
    }
    return false;
  }

  last = MIN(last, win->w_buffer->b_ml.ml_line_count);
  if (lastp != NULL) {
    *lastp = last;
  }
  if (firstp != NULL) {
    *firstp = first;
  }
  if (infop != NULL) {
    infop->fi_level = level + 1;
    infop->fi_lnum = first;
    infop->fi_low_level = low_level == 0 ? level + 1 : low_level;
  }
  return true;
}

// foldLevel() {{{2
/// @return  fold level at line number "lnum" in the current window.
static int foldLevel(linenr_T lnum)
{
  // While updating the folds lines between invalid_top and invalid_bot have
  // an undefined fold level.  Otherwise update the folds first.
  if (invalid_top == 0) {
    checkupdate(curwin);
  } else if (lnum == prev_lnum && prev_lnum_lvl >= 0) {
    return prev_lnum_lvl;
  } else if (lnum >= invalid_top && lnum <= invalid_bot) {
    return -1;
  }

  // Return quickly when there is no folding at all in this window.
  if (!hasAnyFolding(curwin)) {
    return 0;
  }

  return foldLevelWin(curwin, lnum);
}

// lineFolded() {{{2
/// Low level function to check if a line is folded.  Doesn't use any caching.
///
/// @return  true if line is folded or,
///          false if line is not folded.
bool lineFolded(win_T *const win, const linenr_T lnum)
{
  return fold_info(win, lnum).fi_lines != 0;
}

// fold_info() {{{2
///
/// Count the number of lines that are folded at line number "lnum".
/// Normally "lnum" is the first line of a possible fold, and the returned
/// number is the number of lines in the fold.
/// Doesn't use caching from the displayed window.
///
/// @return with the fold level info.
///         fi_lines = number of folded lines from "lnum",
///                    or 0 if line is not folded.
foldinfo_T fold_info(win_T *win, linenr_T lnum)
{
  foldinfo_T info;
  linenr_T last;

  if (hasFoldingWin(win, lnum, NULL, &last, false, &info)) {
    info.fi_lines = (last - lnum + 1);
  } else {
    info.fi_lines = 0;
  }

  return info;
}

// foldmethodIsManual() {{{2
/// @return  true if 'foldmethod' is "manual"
bool foldmethodIsManual(win_T *wp)
{
  return wp->w_p_fdm[3] == 'u';
}

// foldmethodIsIndent() {{{2
/// @return  true if 'foldmethod' is "indent"
bool foldmethodIsIndent(win_T *wp)
{
  return wp->w_p_fdm[0] == 'i';
}

// foldmethodIsExpr() {{{2
/// @return  true if 'foldmethod' is "expr"
bool foldmethodIsExpr(win_T *wp)
{
  return wp->w_p_fdm[1] == 'x';
}

// foldmethodIsMarker() {{{2
/// @return  true if 'foldmethod' is "marker"
bool foldmethodIsMarker(win_T *wp)
{
  return wp->w_p_fdm[2] == 'r';
}

// foldmethodIsSyntax() {{{2
/// @return  true if 'foldmethod' is "syntax"
bool foldmethodIsSyntax(win_T *wp)
{
  return wp->w_p_fdm[0] == 's';
}

// foldmethodIsDiff() {{{2
/// @return  true if 'foldmethod' is "diff"
bool foldmethodIsDiff(win_T *wp)
{
  return wp->w_p_fdm[0] == 'd';
}

// closeFold() {{{2
/// Close fold for current window at position "pos".
/// Repeat "count" times.
void closeFold(pos_T pos, int count)
{
  setFoldRepeat(pos, count, false);
}

// closeFoldRecurse() {{{2
/// Close fold for current window at position `pos` recursively.
void closeFoldRecurse(pos_T pos)
{
  setManualFold(pos, false, true, NULL);
}

// opFoldRange() {{{2
///
/// Open or Close folds for current window in lines "first" to "last".
/// Used for "zo", "zO", "zc" and "zC" in Visual mode.
///
/// @param opening     true to open, false to close
/// @param recurse     true to do it recursively
/// @param had_visual  true when Visual selection used
void opFoldRange(pos_T firstpos, pos_T lastpos, int opening, int recurse, bool had_visual)
{
  int done = DONE_NOTHING;              // avoid error messages
  linenr_T first = firstpos.lnum;
  linenr_T last = lastpos.lnum;
  linenr_T lnum_next;

  for (linenr_T lnum = first; lnum <= last; lnum = lnum_next + 1) {
    pos_T temp = { lnum, 0, 0 };
    lnum_next = lnum;
    // Opening one level only: next fold to open is after the one going to
    // be opened.
    if (opening && !recurse) {
      hasFolding(curwin, lnum, NULL, &lnum_next);
    }
    setManualFold(temp, opening, recurse, &done);
    // Closing one level only: next line to close a fold is after just
    // closed fold.
    if (!opening && !recurse) {
      hasFolding(curwin, lnum, NULL, &lnum_next);
    }
  }
  if (done == DONE_NOTHING) {
    emsg(_(e_nofold));
  }
  // Force a redraw to remove the Visual highlighting.
  if (had_visual) {
    redraw_curbuf_later(UPD_INVERTED);
  }
}

// openFold() {{{2
/// Open fold for current window at position "pos".
/// Repeat "count" times.
void openFold(pos_T pos, int count)
{
  setFoldRepeat(pos, count, true);
}

// openFoldRecurse() {{{2
/// Open fold for current window at position `pos` recursively.
void openFoldRecurse(pos_T pos)
{
  setManualFold(pos, true, true, NULL);
}

// foldOpenCursor() {{{2
/// Open folds until the cursor line is not in a closed fold.
void foldOpenCursor(void)
{
  checkupdate(curwin);
  if (hasAnyFolding(curwin)) {
    while (true) {
      int done = DONE_NOTHING;
      setManualFold(curwin->w_cursor, true, false, &done);
      if (!(done & DONE_ACTION)) {
        break;
      }
    }
  }
}

// newFoldLevel() {{{2
/// Set new foldlevel for current window.
void newFoldLevel(void)
{
  newFoldLevelWin(curwin);

  if (foldmethodIsDiff(curwin) && curwin->w_p_scb) {
    // Set the same foldlevel in other windows in diff mode.
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp != curwin && foldmethodIsDiff(wp) && wp->w_p_scb) {
        wp->w_p_fdl = curwin->w_p_fdl;
        newFoldLevelWin(wp);
      }
    }
  }
}

static void newFoldLevelWin(win_T *wp)
{
  checkupdate(wp);
  if (wp->w_fold_manual) {
    // Set all flags for the first level of folds to FD_LEVEL.  Following
    // manual open/close will then change the flags to FD_OPEN or
    // FD_CLOSED for those folds that don't use 'foldlevel'.
    fold_T *fp = (fold_T *)wp->w_folds.ga_data;
    for (int i = 0; i < wp->w_folds.ga_len; i++) {
      fp[i].fd_flags = FD_LEVEL;
    }
    wp->w_fold_manual = false;
  }
  changed_window_setting(wp);
}

// foldCheckClose() {{{2
/// Apply 'foldlevel' to all folds that don't contain the cursor.
void foldCheckClose(void)
{
  if (*p_fcl == NUL) {
    return;
  }

  // 'foldclose' can only be "all" right now
  checkupdate(curwin);
  if (checkCloseRec(&curwin->w_folds, curwin->w_cursor.lnum,
                    (int)curwin->w_p_fdl)) {
    changed_window_setting(curwin);
  }
}

// checkCloseRec() {{{2
static bool checkCloseRec(garray_T *gap, linenr_T lnum, int level)
{
  bool retval = false;

  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    // Only manually opened folds may need to be closed.
    if (fp[i].fd_flags == FD_OPEN) {
      if (level <= 0 && (lnum < fp[i].fd_top
                         || lnum >= fp[i].fd_top + fp[i].fd_len)) {
        fp[i].fd_flags = FD_LEVEL;
        retval = true;
      } else {
        retval |= checkCloseRec(&fp[i].fd_nested, lnum - fp[i].fd_top,
                                level - 1);
      }
    }
  }
  return retval;
}

// foldManualAllowed() {{{2
/// @return  true if it's allowed to manually create or delete a fold or,
///          give an error message and return false if not.
int foldManualAllowed(bool create)
{
  if (foldmethodIsManual(curwin) || foldmethodIsMarker(curwin)) {
    return true;
  }
  if (create) {
    emsg(_("E350: Cannot create fold with current 'foldmethod'"));
  } else {
    emsg(_("E351: Cannot delete fold with current 'foldmethod'"));
  }
  return false;
}

// foldCreate() {{{2
/// Create a fold from line "start" to line "end" (inclusive) in the current
/// window.
void foldCreate(win_T *wp, pos_T start, pos_T end)
{
  bool use_level = false;
  bool closed = false;
  int level = 0;
  pos_T start_rel = start;
  pos_T end_rel = end;

  if (start.lnum > end.lnum) {
    // reverse the range
    end = start_rel;
    start = end_rel;
    start_rel = start;
    end_rel = end;
  }

  // When 'foldmethod' is "marker" add markers, which creates the folds.
  if (foldmethodIsMarker(wp)) {
    foldCreateMarkers(wp, start, end);
    return;
  }

  checkupdate(wp);

  int i;

  // Find the place to insert the new fold
  garray_T *gap = &wp->w_folds;
  if (gap->ga_len == 0) {
    i = 0;
  } else {
    fold_T *fp;
    while (true) {
      if (!foldFind(gap, start_rel.lnum, &fp)) {
        break;
      }
      if (fp->fd_top + fp->fd_len > end_rel.lnum) {
        // New fold is completely inside this fold: Go one level deeper.
        gap = &fp->fd_nested;
        start_rel.lnum -= fp->fd_top;
        end_rel.lnum -= fp->fd_top;
        if (use_level || fp->fd_flags == FD_LEVEL) {
          use_level = true;
          if (level >= wp->w_p_fdl) {
            closed = true;
          }
        } else if (fp->fd_flags == FD_CLOSED) {
          closed = true;
        }
        level++;
      } else {
        // This fold and new fold overlap: Insert here and move some folds
        // inside the new fold.
        break;
      }
    }
    if (gap->ga_len == 0) {
      i = 0;
    } else {
      i = (int)(fp - (fold_T *)gap->ga_data);
    }
  }

  ga_grow(gap, 1);
  {
    fold_T *fp = (fold_T *)gap->ga_data + i;
    garray_T fold_ga;
    ga_init(&fold_ga, (int)sizeof(fold_T), 10);

    // Count number of folds that will be contained in the new fold.
    int cont;
    for (cont = 0; i + cont < gap->ga_len; cont++) {
      if (fp[cont].fd_top > end_rel.lnum) {
        break;
      }
    }
    if (cont > 0) {
      ga_grow(&fold_ga, cont);
      // If the first fold starts before the new fold, let the new fold
      // start there.  Otherwise the existing fold would change.
      start_rel.lnum = MIN(start_rel.lnum, fp->fd_top);

      // When last contained fold isn't completely contained, adjust end
      // of new fold.
      end_rel.lnum = MAX(end_rel.lnum, fp[cont - 1].fd_top + fp[cont - 1].fd_len - 1);
      // Move contained folds to inside new fold
      memmove(fold_ga.ga_data, fp, sizeof(fold_T) * (size_t)cont);
      fold_ga.ga_len += cont;
      i += cont;

      // Adjust line numbers in contained folds to be relative to the
      // new fold.
      for (int j = 0; j < cont; j++) {
        ((fold_T *)fold_ga.ga_data)[j].fd_top -= start_rel.lnum;
      }
    }
    // Move remaining entries to after the new fold.
    if (i < gap->ga_len) {
      memmove(fp + 1, (fold_T *)gap->ga_data + i,
              sizeof(fold_T) * (size_t)(gap->ga_len - i));
    }
    gap->ga_len = gap->ga_len + 1 - cont;

    // insert new fold
    fp->fd_nested = fold_ga;
    fp->fd_top = start_rel.lnum;
    fp->fd_len = end_rel.lnum - start_rel.lnum + 1;

    // We want the new fold to be closed.  If it would remain open because
    // of using 'foldlevel', need to adjust fd_flags of containing folds.
    if (use_level && !closed && level < wp->w_p_fdl) {
      closeFold(start, 1);
    }
    if (!use_level) {
      wp->w_fold_manual = true;
    }
    fp->fd_flags = FD_CLOSED;
    fp->fd_small = kNone;

    // redraw
    changed_window_setting(wp);
  }
}

// deleteFold() {{{2
/// @param start delete all folds from start to end when not 0
/// @param end delete all folds from start to end when not 0
/// @param recursive delete recursively if true
/// @param had_visual true when Visual selection used
void deleteFold(win_T *const wp, const linenr_T start, const linenr_T end, const int recursive,
                const bool had_visual)
{
  fold_T *found_fp = NULL;
  linenr_T found_off = 0;
  bool maybe_small = false;
  int level = 0;
  linenr_T lnum = start;
  bool did_one = false;
  linenr_T first_lnum = MAXLNUM;
  linenr_T last_lnum = 0;

  checkupdate(wp);

  while (lnum <= end) {
    // Find the deepest fold for "start".
    garray_T *gap = &wp->w_folds;
    garray_T *found_ga = NULL;
    linenr_T lnum_off = 0;
    bool use_level = false;
    while (true) {
      fold_T *fp;
      if (!foldFind(gap, lnum - lnum_off, &fp)) {
        break;
      }
      // lnum is inside this fold, remember info
      found_ga = gap;
      found_fp = fp;
      found_off = lnum_off;

      // if "lnum" is folded, don't check nesting
      if (check_closed(wp, fp, &use_level, level,
                       &maybe_small, lnum_off)) {
        break;
      }

      // check nested folds
      gap = &fp->fd_nested;
      lnum_off += fp->fd_top;
      level++;
    }
    if (found_ga == NULL) {
      lnum++;
    } else {
      lnum = found_fp->fd_top + found_fp->fd_len + found_off;

      if (foldmethodIsManual(wp)) {
        deleteFoldEntry(wp, found_ga,
                        (int)(found_fp - (fold_T *)found_ga->ga_data),
                        recursive);
      } else {
        first_lnum = MIN(first_lnum, found_fp->fd_top + found_off);
        last_lnum = MAX(last_lnum, lnum);
        if (!did_one) {
          parseMarker(wp);
        }
        deleteFoldMarkers(wp, found_fp, recursive, found_off);
      }
      did_one = true;

      // redraw window
      changed_window_setting(wp);
    }
  }
  if (!did_one) {
    emsg(_(e_nofold));
    // Force a redraw to remove the Visual highlighting.
    if (had_visual) {
      redraw_buf_later(wp->w_buffer, UPD_INVERTED);
    }
  } else {
    // Deleting markers may make cursor column invalid
    check_cursor_col(wp);
  }

  if (last_lnum > 0) {
    changed_lines(wp->w_buffer, first_lnum, 0, last_lnum, 0, false);

    // send one nvim_buf_lines_event at the end
    // last_lnum is the line *after* the last line of the outermost fold
    // that was modified. Note also that deleting a fold might only require
    // the modification of the *first* line of the fold, but we send through a
    // notification that includes every line that was part of the fold
    int64_t num_changed = last_lnum - first_lnum;
    buf_updates_send_changes(wp->w_buffer, first_lnum, num_changed, num_changed);
  }
}

// clearFolding() {{{2
/// Remove all folding for window "win".
void clearFolding(win_T *win)
{
  deleteFoldRecurse(win->w_buffer, &win->w_folds);
  win->w_foldinvalid = false;
}

// foldUpdate() {{{2
/// Update folds for changes in the buffer of a window.
/// Note that inserted/deleted lines must have already been taken care of by
/// calling foldMarkAdjust().
/// The changes in lines from top to bot (inclusive).
void foldUpdate(win_T *wp, linenr_T top, linenr_T bot)
{
  if (disable_fold_update || (State & MODE_INSERT && !foldmethodIsIndent(wp))) {
    return;
  }

  if (need_diff_redraw) {
    // will update later
    return;
  }

  if (wp->w_folds.ga_len > 0) {
    // Mark all folds from top to bot (or bot to top) as maybe-small.
    linenr_T maybe_small_start = MIN(top, bot);
    linenr_T maybe_small_end = MAX(top, bot);

    fold_T *fp;
    foldFind(&wp->w_folds, maybe_small_start, &fp);
    while (fp < (fold_T *)wp->w_folds.ga_data + wp->w_folds.ga_len
           && fp->fd_top <= maybe_small_end) {
      fp->fd_small = kNone;
      fp++;
    }
  }

  if (foldmethodIsIndent(wp)
      || foldmethodIsExpr(wp)
      || foldmethodIsMarker(wp)
      || foldmethodIsDiff(wp)
      || foldmethodIsSyntax(wp)) {
    int save_got_int = got_int;

    // reset got_int here, otherwise it won't work
    got_int = false;
    foldUpdateIEMS(wp, top, bot);
    got_int |= save_got_int;
  }
}

/// Updates folds when leaving insert-mode.
void foldUpdateAfterInsert(void)
{
  if (foldmethodIsManual(curwin)  // foldmethod=manual: No need to update.
      // These foldmethods are too slow, do not auto-update on insert-leave.
      || foldmethodIsSyntax(curwin) || foldmethodIsExpr(curwin)) {
    return;
  }

  foldUpdateAll(curwin);
  foldOpenCursor();
}

// foldUpdateAll() {{{2
/// Update all lines in a window for folding.
/// Used when a fold setting changes or after reloading the buffer.
/// The actual updating is postponed until fold info is used, to avoid doing
/// every time a setting is changed or a syntax item is added.
void foldUpdateAll(win_T *win)
{
  win->w_foldinvalid = true;
  redraw_later(win, UPD_NOT_VALID);
}

// foldMoveTo() {{{2
///
/// If "updown" is false: Move to the start or end of the fold.
/// If "updown" is true: move to fold at the same level.
/// @return FAIL if not moved.
///
/// @param dir  FORWARD or BACKWARD
int foldMoveTo(const bool updown, const int dir, const int count)
{
  int retval = FAIL;
  fold_T *fp;

  checkupdate(curwin);

  // Repeat "count" times.
  for (int n = 0; n < count; n++) {
    // Find nested folds.  Stop when a fold is closed.  The deepest fold
    // that moves the cursor is used.
    linenr_T lnum_off = 0;
    garray_T *gap = &curwin->w_folds;
    if (gap->ga_len == 0) {
      break;
    }
    bool use_level = false;
    bool maybe_small = false;
    linenr_T lnum_found = curwin->w_cursor.lnum;
    int level = 0;
    bool last = false;
    while (true) {
      if (!foldFind(gap, curwin->w_cursor.lnum - lnum_off, &fp)) {
        if (!updown || gap->ga_len == 0) {
          break;
        }

        // When moving up, consider a fold above the cursor; when
        // moving down consider a fold below the cursor.
        if (dir == FORWARD) {
          if (fp - (fold_T *)gap->ga_data >= gap->ga_len) {
            break;
          }
          fp--;
        } else {
          if (fp == (fold_T *)gap->ga_data) {
            break;
          }
        }
        // don't look for contained folds, they will always move
        // the cursor too far.
        last = true;
      }

      if (!last) {
        // Check if this fold is closed.
        if (check_closed(curwin, fp, &use_level, level,
                         &maybe_small, lnum_off)) {
          last = true;
        }

        // "[z" and "]z" stop at closed fold
        if (last && !updown) {
          break;
        }
      }

      if (updown) {
        if (dir == FORWARD) {
          // to start of next fold if there is one
          if (fp + 1 - (fold_T *)gap->ga_data < gap->ga_len) {
            linenr_T lnum = fp[1].fd_top + lnum_off;
            if (lnum > curwin->w_cursor.lnum) {
              lnum_found = lnum;
            }
          }
        } else {
          // to end of previous fold if there is one
          if (fp > (fold_T *)gap->ga_data) {
            linenr_T lnum = fp[-1].fd_top + lnum_off + fp[-1].fd_len - 1;
            if (lnum < curwin->w_cursor.lnum) {
              lnum_found = lnum;
            }
          }
        }
      } else {
        // Open fold found, set cursor to its start/end and then check
        // nested folds.
        if (dir == FORWARD) {
          linenr_T lnum = fp->fd_top + lnum_off + fp->fd_len - 1;
          if (lnum > curwin->w_cursor.lnum) {
            lnum_found = lnum;
          }
        } else {
          linenr_T lnum = fp->fd_top + lnum_off;
          if (lnum < curwin->w_cursor.lnum) {
            lnum_found = lnum;
          }
        }
      }

      if (last) {
        break;
      }

      // Check nested folds (if any).
      gap = &fp->fd_nested;
      lnum_off += fp->fd_top;
      level++;
    }
    if (lnum_found != curwin->w_cursor.lnum) {
      if (retval == FAIL) {
        setpcmark();
      }
      curwin->w_cursor.lnum = lnum_found;
      curwin->w_cursor.col = 0;
      retval = OK;
    } else {
      break;
    }
  }

  return retval;
}

// foldInitWin() {{{2
/// Init the fold info in a new window.
void foldInitWin(win_T *new_win)
{
  ga_init(&new_win->w_folds, (int)sizeof(fold_T), 10);
}

// find_wl_entry() {{{2
/// Find an entry in the win->w_lines[] array for buffer line "lnum".
/// Only valid entries are considered (for entries where wl_valid is false the
/// line number can be wrong).
///
/// @return  index of entry or -1 if not found.
int find_wl_entry(win_T *win, linenr_T lnum)
{
  for (int i = 0; i < win->w_lines_valid; i++) {
    if (win->w_lines[i].wl_valid) {
      if (lnum < win->w_lines[i].wl_lnum) {
        return -1;
      }
      if (lnum <= win->w_lines[i].wl_lastlnum) {
        return i;
      }
    }
  }
  return -1;
}

// foldAdjustVisual() {{{2
/// Adjust the Visual area to include any fold at the start or end completely.
void foldAdjustVisual(void)
{
  if (!VIsual_active || !hasAnyFolding(curwin)) {
    return;
  }

  pos_T *start, *end;

  if (ltoreq(VIsual, curwin->w_cursor)) {
    start = &VIsual;
    end = &curwin->w_cursor;
  } else {
    start = &curwin->w_cursor;
    end = &VIsual;
  }
  if (hasFolding(curwin, start->lnum, &start->lnum, NULL)) {
    start->col = 0;
  }

  if (!hasFolding(curwin, end->lnum, NULL, &end->lnum)) {
    return;
  }

  end->col = ml_get_len(end->lnum);
  if (end->col > 0 && *p_sel == 'o') {
    end->col--;
  }
  // prevent cursor from moving on the trail byte
  mb_adjust_cursor();
}

// foldAdjustCursor() {{{2
/// Move the cursor to the first line of a closed fold.
void foldAdjustCursor(win_T *wp)
{
  hasFolding(wp, wp->w_cursor.lnum, &wp->w_cursor.lnum, NULL);
}

// Internal functions for "fold_T" {{{1
// cloneFoldGrowArray() {{{2
/// Will "clone" (i.e deep copy) a garray_T of folds.
void cloneFoldGrowArray(garray_T *from, garray_T *to)
{
  ga_init(to, from->ga_itemsize, from->ga_growsize);

  if (GA_EMPTY(from)) {
    return;
  }

  ga_grow(to, from->ga_len);

  fold_T *from_p = (fold_T *)from->ga_data;
  fold_T *to_p = (fold_T *)to->ga_data;

  for (int i = 0; i < from->ga_len; i++) {
    to_p->fd_top = from_p->fd_top;
    to_p->fd_len = from_p->fd_len;
    to_p->fd_flags = from_p->fd_flags;
    to_p->fd_small = from_p->fd_small;
    cloneFoldGrowArray(&from_p->fd_nested, &to_p->fd_nested);
    to->ga_len++;
    from_p++;
    to_p++;
  }
}

// foldFind() {{{2
/// Search for line "lnum" in folds of growarray "gap".
/// Set "*fpp" to the fold struct for the fold that contains "lnum" or
/// the first fold below it (careful: it can be beyond the end of the array!).
///
/// @return  false when there is no fold that contains "lnum".
static bool foldFind(const garray_T *gap, linenr_T lnum, fold_T **fpp)
{
  if (gap->ga_len == 0) {
    *fpp = NULL;
    return false;
  }

  // Perform a binary search.
  // "low" is lowest index of possible match.
  // "high" is highest index of possible match.
  fold_T *fp = (fold_T *)gap->ga_data;
  linenr_T low = 0;
  linenr_T high = gap->ga_len - 1;
  while (low <= high) {
    linenr_T i = (low + high) / 2;
    if (fp[i].fd_top > lnum) {
      // fold below lnum, adjust high
      high = i - 1;
    } else if (fp[i].fd_top + fp[i].fd_len <= lnum) {
      // fold above lnum, adjust low
      low = i + 1;
    } else {
      // lnum is inside this fold
      *fpp = fp + i;
      return true;
    }
  }
  *fpp = fp + low;
  return false;
}

// foldLevelWin() {{{2
/// @return  fold level at line number "lnum" in window "wp".
static int foldLevelWin(win_T *wp, linenr_T lnum)
{
  fold_T *fp;
  linenr_T lnum_rel = lnum;
  int level = 0;

  // Recursively search for a fold that contains "lnum".
  garray_T *gap = &wp->w_folds;
  while (true) {
    if (!foldFind(gap, lnum_rel, &fp)) {
      break;
    }
    // Check nested folds.  Line number is relative to containing fold.
    gap = &fp->fd_nested;
    lnum_rel -= fp->fd_top;
    level++;
  }

  return level;
}

// checkupdate() {{{2
/// Check if the folds in window "wp" are invalid and update them if needed.
static void checkupdate(win_T *wp)
{
  if (!wp->w_foldinvalid) {
    return;
  }

  foldUpdate(wp, 1, (linenr_T)MAXLNUM);     // will update all
  wp->w_foldinvalid = false;
}

// setFoldRepeat() {{{2
/// Open or close fold for current window at position `pos`.
/// Repeat "count" times.
static void setFoldRepeat(pos_T pos, int count, int do_open)
{
  for (int n = 0; n < count; n++) {
    int done = DONE_NOTHING;
    setManualFold(pos, do_open, false, &done);
    if (!(done & DONE_ACTION)) {
      // Only give an error message when no fold could be opened.
      if (n == 0 && !(done & DONE_FOLD)) {
        emsg(_(e_nofold));
      }
      break;
    }
  }
}

// setManualFold() {{{2
/// Open or close the fold in the current window which contains "lnum".
/// Also does this for other windows in diff mode when needed.
///
/// @param opening  true when opening, false when closing
/// @param recurse  true when closing/opening recursive
static linenr_T setManualFold(pos_T pos, bool opening, bool recurse, int *donep)
{
  if (foldmethodIsDiff(curwin) && curwin->w_p_scb) {
    linenr_T dlnum;

    // Do the same operation in other windows in diff mode.  Calculate the
    // line number from the diffs.
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp != curwin && foldmethodIsDiff(wp) && wp->w_p_scb) {
        dlnum = diff_lnum_win(curwin->w_cursor.lnum, wp);
        if (dlnum != 0) {
          setManualFoldWin(wp, dlnum, opening, recurse, NULL);
        }
      }
    }
  }

  return setManualFoldWin(curwin, pos.lnum, opening, recurse, donep);
}

// setManualFoldWin() {{{2
/// Open or close the fold in window "wp" which contains "lnum".
/// "donep", when not NULL, points to flag that is set to DONE_FOLD when some
/// fold was found and to DONE_ACTION when some fold was opened or closed.
/// When "donep" is NULL give an error message when no fold was found for
/// "lnum", but only if "wp" is "curwin".
///
/// @param opening  true when opening, false when closing
/// @param recurse  true when closing/opening recursive
///
/// @return         the line number of the next line that could be closed.
///                 It's only valid when "opening" is true!
static linenr_T setManualFoldWin(win_T *wp, linenr_T lnum, bool opening, bool recurse, int *donep)
{
  fold_T *fp;
  fold_T *fp2;
  fold_T *found = NULL;
  int level = 0;
  bool use_level = false;
  bool found_fold = false;
  linenr_T next = MAXLNUM;
  linenr_T off = 0;
  int done = 0;

  checkupdate(wp);

  // Find the fold, open or close it.
  garray_T *gap = &wp->w_folds;
  while (true) {
    if (!foldFind(gap, lnum, &fp)) {
      // If there is a following fold, continue there next time.
      if (fp != NULL && fp < (fold_T *)gap->ga_data + gap->ga_len) {
        next = fp->fd_top + off;
      }
      break;
    }

    // lnum is inside this fold
    found_fold = true;

    // If there is a following fold, continue there next time.
    if (fp + 1 < (fold_T *)gap->ga_data + gap->ga_len) {
      next = fp[1].fd_top + off;
    }

    // Change from level-dependent folding to manual.
    if (use_level || fp->fd_flags == FD_LEVEL) {
      use_level = true;
      fp->fd_flags = level >= wp->w_p_fdl ? FD_CLOSED : FD_OPEN;
      fp2 = (fold_T *)fp->fd_nested.ga_data;
      for (int j = 0; j < fp->fd_nested.ga_len; j++) {
        fp2[j].fd_flags = FD_LEVEL;
      }
    }

    // Simple case: Close recursively means closing the fold.
    if (!opening && recurse) {
      if (fp->fd_flags != FD_CLOSED) {
        done |= DONE_ACTION;
        fp->fd_flags = FD_CLOSED;
      }
    } else if (fp->fd_flags == FD_CLOSED) {
      // When opening, open topmost closed fold.
      if (opening) {
        fp->fd_flags = FD_OPEN;
        done |= DONE_ACTION;
        if (recurse) {
          foldOpenNested(fp);
        }
      }
      break;
    }

    // fold is open, check nested folds
    found = fp;
    gap = &fp->fd_nested;
    lnum -= fp->fd_top;
    off += fp->fd_top;
    level++;
  }
  if (found_fold) {
    // When closing and not recurse, close deepest open fold.
    if (!opening && found != NULL) {
      found->fd_flags = FD_CLOSED;
      done |= DONE_ACTION;
    }
    wp->w_fold_manual = true;
    if (done & DONE_ACTION) {
      changed_window_setting(wp);
    }
    done |= DONE_FOLD;
  } else if (donep == NULL && wp == curwin) {
    emsg(_(e_nofold));
  }

  if (donep != NULL) {
    *donep |= done;
  }

  return next;
}

// foldOpenNested() {{{2
/// Open all nested folds in fold "fpr" recursively.
static void foldOpenNested(fold_T *fpr)
{
  fold_T *fp = (fold_T *)fpr->fd_nested.ga_data;
  for (int i = 0; i < fpr->fd_nested.ga_len; i++) {
    foldOpenNested(&fp[i]);
    fp[i].fd_flags = FD_OPEN;
  }
}

// deleteFoldEntry() {{{2
/// Delete fold "idx" from growarray "gap".
///
/// @param recursive  when true, also delete all the folds contained in it.
///                   when false, contained folds are moved one level up.
static void deleteFoldEntry(win_T *const wp, garray_T *const gap, const int idx,
                            const bool recursive)
{
  fold_T *fp = (fold_T *)gap->ga_data + idx;
  if (recursive || GA_EMPTY(&fp->fd_nested)) {
    // recursively delete the contained folds
    deleteFoldRecurse(wp->w_buffer, &fp->fd_nested);
    gap->ga_len--;
    if (idx < gap->ga_len) {
      memmove(fp, fp + 1, sizeof(*fp) * (size_t)(gap->ga_len - idx));
    }
  } else {
    // Move nested folds one level up, to overwrite the fold that is
    // deleted.
    int moved = fp->fd_nested.ga_len;
    ga_grow(gap, moved - 1);
    {
      // Get "fp" again, the array may have been reallocated.
      fp = (fold_T *)gap->ga_data + idx;

      // adjust fd_top and fd_flags for the moved folds
      fold_T *nfp = (fold_T *)fp->fd_nested.ga_data;
      for (int i = 0; i < moved; i++) {
        nfp[i].fd_top += fp->fd_top;
        if (fp->fd_flags == FD_LEVEL) {
          nfp[i].fd_flags = FD_LEVEL;
        }
        if (fp->fd_small == kNone) {
          nfp[i].fd_small = kNone;
        }
      }

      // move the existing folds down to make room
      if (idx + 1 < gap->ga_len) {
        memmove(fp + moved, fp + 1,
                sizeof(*fp) * (size_t)(gap->ga_len - (idx + 1)));
      }
      // move the contained folds one level up
      memmove(fp, nfp, sizeof(*fp) * (size_t)moved);
      xfree(nfp);
      gap->ga_len += moved - 1;
    }
  }
}

// deleteFoldRecurse() {{{2
/// Delete nested folds in a fold.
void deleteFoldRecurse(buf_T *bp, garray_T *gap)
{
#define DELETE_FOLD_NESTED(fd) deleteFoldRecurse(bp, &((fd)->fd_nested))
  GA_DEEP_CLEAR(gap, fold_T, DELETE_FOLD_NESTED);
}

// foldMarkAdjust() {{{2
/// Update line numbers of folds for inserted/deleted lines.
///
/// We are adjusting the folds in the range from line1 til line2,
/// make sure that line2 does not get smaller than line1
void foldMarkAdjust(win_T *wp, linenr_T line1, linenr_T line2, linenr_T amount,
                    linenr_T amount_after)
{
  // If deleting marks from line1 to line2, but not deleting all those
  // lines, set line2 so that only deleted lines have their folds removed.
  if (amount == MAXLNUM && line2 >= line1 && line2 - line1 >= -amount_after) {
    line2 = line1 - amount_after - 1;
  }
  if (line2 < line1) {
    line2 = line1;
  }
  // If appending a line in Insert mode, it should be included in the fold
  // just above the line.
  if ((State & MODE_INSERT) && amount == 1 && line2 == MAXLNUM) {
    line1--;
  }
  foldMarkAdjustRecurse(wp, &wp->w_folds, line1, line2, amount, amount_after);
}

// foldMarkAdjustRecurse() {{{2
static void foldMarkAdjustRecurse(win_T *wp, garray_T *gap, linenr_T line1, linenr_T line2,
                                  linenr_T amount, linenr_T amount_after)
{
  if (gap->ga_len == 0) {
    return;
  }

  // In Insert mode an inserted line at the top of a fold is considered part
  // of the fold, otherwise it isn't.
  linenr_T top = ((State & MODE_INSERT) && amount == 1 && line2 == MAXLNUM)
                 ? line1 + 1
                 : line1;

  // Find the fold containing or just below "line1".
  fold_T *fp;
  foldFind(gap, line1, &fp);

  // Adjust all folds below "line1" that are affected.
  for (int i = (int)(fp - (fold_T *)gap->ga_data); i < gap->ga_len; i++, fp++) {
    // Check for these situations:
    //    1  2  3
    //    1  2  3
    // line1     2      3  4  5
    //       2  3  4  5
    //       2  3  4  5
    // line2     2      3  4  5
    //          3     5  6
    //          3     5  6

    linenr_T last = fp->fd_top + fp->fd_len - 1;     // last line of fold

    // 1. fold completely above line1: nothing to do
    if (last < line1) {
      continue;
    }

    // 6. fold below line2: only adjust for amount_after
    if (fp->fd_top > line2) {
      if (amount_after == 0) {
        break;
      }
      fp->fd_top += amount_after;
    } else {
      if (fp->fd_top >= top && last <= line2) {
        // 4. fold completely contained in range
        if (amount == MAXLNUM) {
          // Deleting lines: delete the fold completely
          deleteFoldEntry(wp, gap, i, true);
          i--;              // adjust index for deletion
          fp--;
        } else {
          fp->fd_top += amount;
        }
      } else {
        if (fp->fd_top < top) {
          // 2 or 3: need to correct nested folds too
          foldMarkAdjustRecurse(wp, &fp->fd_nested, line1 - fp->fd_top,
                                line2 - fp->fd_top, amount, amount_after);
          if (last <= line2) {
            // 2. fold contains line1, line2 is below fold
            if (amount == MAXLNUM) {
              fp->fd_len = line1 - fp->fd_top;
            } else {
              fp->fd_len += amount;
            }
          } else {
            // 3. fold contains line1 and line2
            fp->fd_len += amount_after;
          }
        } else {
          // 5. fold is below line1 and contains line2; need to
          // correct nested folds too
          if (amount == MAXLNUM) {
            foldMarkAdjustRecurse(wp, &fp->fd_nested, 0, line2 - fp->fd_top,
                                  amount, amount_after + (fp->fd_top - top));
            fp->fd_len -= line2 - fp->fd_top + 1;
            fp->fd_top = line1;
          } else {
            foldMarkAdjustRecurse(wp, &fp->fd_nested, 0, line2 - fp->fd_top,
                                  amount, amount_after - amount);
            fp->fd_len += amount_after - amount;
            fp->fd_top += amount;
          }
        }
      }
    }
  }
}

// getDeepestNesting() {{{2
/// Get the lowest 'foldlevel' value that makes the deepest nested fold in
/// window `wp`.
int getDeepestNesting(win_T *wp)
{
  checkupdate(wp);
  return getDeepestNestingRecurse(&wp->w_folds);
}

static int getDeepestNestingRecurse(garray_T *gap)
{
  int maxlevel = 0;

  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    int level = getDeepestNestingRecurse(&fp[i].fd_nested) + 1;
    maxlevel = MAX(maxlevel, level);
  }

  return maxlevel;
}

// check_closed() {{{2
/// Check if a fold is closed and update the info needed to check nested folds.
///
/// @param[in,out] use_levelp true: outer fold had FD_LEVEL
/// @param[in,out] fp fold to check
/// @param level folding depth
/// @param[out] maybe_smallp true: outer this had fd_small == kNone
/// @param lnum_off line number offset for fp->fd_top
/// @return true if fold is closed
static bool check_closed(win_T *const wp, fold_T *const fp, bool *const use_levelp, const int level,
                         bool *const maybe_smallp, const linenr_T lnum_off)
{
  bool closed = false;

  // Check if this fold is closed.  If the flag is FD_LEVEL this
  // fold and all folds it contains depend on 'foldlevel'.
  if (*use_levelp || fp->fd_flags == FD_LEVEL) {
    *use_levelp = true;
    if (level >= wp->w_p_fdl) {
      closed = true;
    }
  } else if (fp->fd_flags == FD_CLOSED) {
    closed = true;
  }

  // Small fold isn't closed anyway.
  if (fp->fd_small == kNone) {
    *maybe_smallp = true;
  }
  if (closed) {
    if (*maybe_smallp) {
      fp->fd_small = kNone;
    }
    checkSmall(wp, fp, lnum_off);
    if (fp->fd_small == kTrue) {
      closed = false;
    }
  }
  return closed;
}

// checkSmall() {{{2
/// Update fd_small field of fold "fp".
///
/// @param lnum_off  offset for fp->fd_top
static void checkSmall(win_T *const wp, fold_T *const fp, const linenr_T lnum_off)
{
  if (fp->fd_small != kNone) {
    return;
  }

  // Mark any nested folds to maybe-small
  setSmallMaybe(&fp->fd_nested);

  if (fp->fd_len > wp->w_p_fml) {
    fp->fd_small = kFalse;
  } else {
    int count = 0;
    for (int n = 0; n < fp->fd_len; n++) {
      count += plines_win_nofold(wp, fp->fd_top + lnum_off + n);
      if (count > wp->w_p_fml) {
        fp->fd_small = kFalse;
        return;
      }
    }
    fp->fd_small = kTrue;
  }
}

// setSmallMaybe() {{{2
/// Set small flags in "gap" to kNone.
static void setSmallMaybe(garray_T *gap)
{
  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    fp[i].fd_small = kNone;
  }
}

// foldCreateMarkers() {{{2
/// Create a fold from line "start" to line "end" (inclusive) in window `wp`
/// by adding markers.
static void foldCreateMarkers(win_T *wp, pos_T start, pos_T end)
{
  buf_T *buf = wp->w_buffer;
  if (!MODIFIABLE(buf)) {
    emsg(_(e_modifiable));
    return;
  }
  parseMarker(wp);

  foldAddMarker(buf, start, wp->w_p_fmr, foldstartmarkerlen);
  foldAddMarker(buf, end, foldendmarker, foldendmarkerlen);

  // Update both changes here, to avoid all folds after the start are
  // changed when the start marker is inserted and the end isn't.
  changed_lines(buf, start.lnum, 0, end.lnum, 0, false);

  // Note: foldAddMarker() may not actually change start and/or end if
  // u_save() is unable to save the buffer line, but we send the
  // nvim_buf_lines_event anyway since it won't do any harm.
  int64_t num_changed = 1 + end.lnum - start.lnum;
  buf_updates_send_changes(buf, start.lnum, num_changed, num_changed);
}

// foldAddMarker() {{{2
/// Add "marker[markerlen]" in 'commentstring' to position `pos`.
static void foldAddMarker(buf_T *buf, pos_T pos, const char *marker, size_t markerlen)
{
  char *cms = buf->b_p_cms;
  char *p = strstr(buf->b_p_cms, "%s");
  bool line_is_comment = false;
  linenr_T lnum = pos.lnum;

  // Allocate a new line: old-line + 'cms'-start + marker + 'cms'-end
  char *line = ml_get_buf(buf, lnum);
  size_t line_len = (size_t)ml_get_buf_len(buf, lnum);
  size_t added = 0;

  if (u_save(lnum - 1, lnum + 1) != OK) {
    return;
  }

  // Check if the line ends with an unclosed comment
  skip_comment(line, false, false, &line_is_comment);
  char *newline = xmalloc(line_len + markerlen + strlen(cms) + 1);
  STRCPY(newline, line);
  // Append the marker to the end of the line
  if (p == NULL || line_is_comment) {
    xmemcpyz(newline + line_len, marker, markerlen);
    added = markerlen;
  } else {
    STRCPY(newline + line_len, cms);
    memcpy(newline + line_len + (p - cms), marker, markerlen);
    STRCPY(newline + line_len + (p - cms) + markerlen, p + 2);
    added = markerlen + strlen(cms) - 2;
  }
  ml_replace_buf(buf, lnum, newline, false, false);
  if (added) {
    extmark_splice_cols(buf, (int)lnum - 1, (int)line_len,
                        0, (int)added, kExtmarkUndo);
  }
}

// deleteFoldMarkers() {{{2
/// Delete the markers for a fold, causing it to be deleted.
///
/// @param lnum_off  offset for fp->fd_top
static void deleteFoldMarkers(win_T *wp, fold_T *fp, bool recursive, linenr_T lnum_off)
{
  if (recursive) {
    for (int i = 0; i < fp->fd_nested.ga_len; i++) {
      deleteFoldMarkers(wp, (fold_T *)fp->fd_nested.ga_data + i, true,
                        lnum_off + fp->fd_top);
    }
  }
  foldDelMarker(wp->w_buffer, fp->fd_top + lnum_off, wp->w_p_fmr,
                foldstartmarkerlen);
  foldDelMarker(wp->w_buffer, fp->fd_top + lnum_off + fp->fd_len - 1,
                foldendmarker, foldendmarkerlen);
}

// foldDelMarker() {{{2
/// Delete marker "marker[markerlen]" at the end of line "lnum".
/// Delete 'commentstring' if it matches.
/// If the marker is not found, there is no error message.  Could be a missing
/// close-marker.
static void foldDelMarker(buf_T *buf, linenr_T lnum, char *marker, size_t markerlen)
{
  // end marker may be missing and fold extends below the last line
  if (lnum > buf->b_ml.ml_line_count) {
    return;
  }

  char *cms = buf->b_p_cms;
  char *line = ml_get_buf(buf, lnum);
  for (char *p = line; *p != NUL; p++) {
    if (strncmp(p, marker, markerlen) != 0) {
      continue;
    }
    // Found the marker, include a digit if it's there.
    size_t len = markerlen;
    if (ascii_isdigit(p[len])) {
      len++;
    }
    if (*cms != NUL) {
      // Also delete 'commentstring' if it matches.
      char *cms2 = strstr(cms, "%s");
      if (p - line >= cms2 - cms
          && strncmp(p - (cms2 - cms), cms, (size_t)(cms2 - cms)) == 0
          && strncmp(p + len, cms2 + 2, strlen(cms2 + 2)) == 0) {
        p -= cms2 - cms;
        len += strlen(cms) - 2;
      }
    }
    if (u_save(lnum - 1, lnum + 1) == OK) {
      // Make new line: text-before-marker + text-after-marker
      char *newline = xmalloc((size_t)ml_get_buf_len(buf, lnum) - len + 1);
      assert(p >= line);
      memcpy(newline, line, (size_t)(p - line));
      STRCPY(newline + (p - line), p + len);
      ml_replace_buf(buf, lnum, newline, false, false);
      extmark_splice_cols(buf, (int)lnum - 1, (int)(p - line),
                          (int)len, 0, kExtmarkUndo);
    }
    break;
  }
}

// get_foldtext() {{{2
/// Generates text to display
///
/// @param buf allocated memory of length FOLD_TEXT_LEN. Used when 'foldtext'
///            isn't set puts the result in "buf[FOLD_TEXT_LEN]".
/// @param at line "lnum", with last line "lnume".
/// @return the text for a closed fold
///
/// Otherwise the result is in allocated memory.
char *get_foldtext(win_T *wp, linenr_T lnum, linenr_T lnume, foldinfo_T foldinfo, char *buf,
                   VirtText *vt)
  FUNC_ATTR_NONNULL_ALL
{
  char *text = NULL;
  // an error occurred when evaluating 'fdt' setting
  static bool got_fdt_error = false;
  int save_did_emsg = did_emsg;
  static win_T *last_wp = NULL;
  static linenr_T last_lnum = 0;

  if (last_wp == NULL || last_wp != wp || last_lnum > lnum || last_lnum == 0) {
    // window changed, try evaluating foldtext setting once again
    got_fdt_error = false;
  }

  if (!got_fdt_error) {
    // a previous error should not abort evaluating 'foldexpr'
    did_emsg = false;
  }

  if (*wp->w_p_fdt != NUL) {
    char dashes[MAX_LEVEL + 2];

    // Set "v:foldstart" and "v:foldend".
    set_vim_var_nr(VV_FOLDSTART, (varnumber_T)lnum);
    set_vim_var_nr(VV_FOLDEND, (varnumber_T)lnume);

    // Set "v:folddashes" to a string of "level" dashes.
    // Set "v:foldlevel" to "level".
    int level = MIN(foldinfo.fi_level, (int)sizeof(dashes) - 1);
    memset(dashes, '-', (size_t)level);
    dashes[level] = NUL;
    set_vim_var_string(VV_FOLDDASHES, dashes, -1);
    set_vim_var_nr(VV_FOLDLEVEL, (varnumber_T)level);

    // skip evaluating 'foldtext' on errors
    if (!got_fdt_error) {
      win_T *const save_curwin = curwin;
      const sctx_T saved_sctx = current_sctx;

      curwin = wp;
      curbuf = wp->w_buffer;
      current_sctx = wp->w_p_script_ctx[WV_FDT].script_ctx;

      emsg_off++;  // handle exceptions, but don't display errors

      Object obj = eval_foldtext(wp);
      if (obj.type == kObjectTypeArray) {
        Error err = ERROR_INIT;
        *vt = parse_virt_text(obj.data.array, &err, NULL);
        if (!ERROR_SET(&err)) {
          *buf = NUL;
          text = buf;
        }
        api_clear_error(&err);
      } else if (obj.type == kObjectTypeString) {
        text = obj.data.string.data;
        obj = NIL;
      }
      api_free_object(obj);

      emsg_off--;

      if (text == NULL || did_emsg) {
        got_fdt_error = true;
      }

      curwin = save_curwin;
      curbuf = curwin->w_buffer;
      current_sctx = saved_sctx;
    }
    last_lnum = lnum;
    last_wp = wp;
    set_vim_var_string(VV_FOLDDASHES, NULL, -1);

    if (!did_emsg && save_did_emsg) {
      did_emsg = save_did_emsg;
    }

    if (text != NULL) {
      // Replace unprintable characters, if there are any.  But
      // replace a TAB with a space.
      char *p;
      for (p = text; *p != NUL; p++) {
        int len = utfc_ptr2len(p);

        if (len > 1) {
          if (!vim_isprintc(utf_ptr2char(p))) {
            break;
          }
          p += len - 1;
        } else if (*p == TAB) {
          *p = ' ';
        } else if (ptr2cells(p) > 1) {
          break;
        }
      }
      if (*p != NUL) {
        p = transstr(text, true);
        xfree(text);
        text = p;
      }
    }
  }
  if (text == NULL) {
    int count = lnume - lnum + 1;

    vim_snprintf(buf, FOLD_TEXT_LEN,
                 NGETTEXT("+--%3d line folded",
                          "+--%3d lines folded ", count),
                 count);
    text = buf;
  }
  return text;
}

// foldtext_cleanup() {{{2
/// Remove 'foldmarker' and 'commentstring' from "str" (in-place).
static void foldtext_cleanup(char *str)
{
  // Ignore leading and trailing white space in 'commentstring'.
  char *cms_start = skipwhite(curbuf->b_p_cms);
  size_t cms_slen = strlen(cms_start);
  while (cms_slen > 0 && ascii_iswhite(cms_start[cms_slen - 1])) {
    cms_slen--;
  }

  // locate "%s" in 'commentstring', use the part before and after it.
  char *cms_end = strstr(cms_start, "%s");
  size_t cms_elen = 0;
  if (cms_end != NULL) {
    cms_elen = cms_slen - (size_t)(cms_end - cms_start);
    cms_slen = (size_t)(cms_end - cms_start);

    // exclude white space before "%s"
    while (cms_slen > 0 && ascii_iswhite(cms_start[cms_slen - 1])) {
      cms_slen--;
    }

    // skip "%s" and white space after it
    char *s = skipwhite(cms_end + 2);
    cms_elen -= (size_t)(s - cms_end);
    cms_end = s;
  }
  parseMarker(curwin);

  bool did1 = false;
  bool did2 = false;

  for (char *s = str; *s != NUL;) {
    size_t len = 0;
    if (strncmp(s, curwin->w_p_fmr, foldstartmarkerlen) == 0) {
      len = foldstartmarkerlen;
    } else if (strncmp(s, foldendmarker, foldendmarkerlen) == 0) {
      len = foldendmarkerlen;
    }
    if (len > 0) {
      if (ascii_isdigit(s[len])) {
        len++;
      }

      // May remove 'commentstring' start.  Useful when it's a double
      // quote and we already removed a double quote.
      char *p;
      for (p = s; p > str && ascii_iswhite(p[-1]); p--) {}
      if (p >= str + cms_slen
          && strncmp(p - cms_slen, cms_start, cms_slen) == 0) {
        len += (size_t)(s - p) + cms_slen;
        s = p - cms_slen;
      }
    } else if (cms_end != NULL) {
      if (!did1 && cms_slen > 0 && strncmp(s, cms_start, cms_slen) == 0) {
        len = cms_slen;
        did1 = true;
      } else if (!did2 && cms_elen > 0
                 && strncmp(s, cms_end, cms_elen) == 0) {
        len = cms_elen;
        did2 = true;
      }
    }
    if (len != 0) {
      while (ascii_iswhite(s[len])) {
        len++;
      }
      STRMOVE(s, s + len);
    } else {
      MB_PTR_ADV(s);
    }
  }
}

// Folding by indent, expr, marker and syntax. {{{1
// Function declarations. {{{2

// foldUpdateIEMS() {{{2
/// Update the folding for window "wp", at least from lines "top" to "bot".
/// IEMS = "Indent Expr Marker Syntax"
static void foldUpdateIEMS(win_T *const wp, linenr_T top, linenr_T bot)
{
  // Avoid problems when being called recursively.
  if (invalid_top != 0) {
    return;
  }

  if (wp->w_foldinvalid) {
    // Need to update all folds.
    top = 1;
    bot = wp->w_buffer->b_ml.ml_line_count;
    wp->w_foldinvalid = false;

    // Mark all folds as maybe-small.
    setSmallMaybe(&wp->w_folds);
  }

  // add the context for "diff" folding
  if (foldmethodIsDiff(wp)) {
    if (top > diff_context) {
      top -= diff_context;
    } else {
      top = 1;
    }
    bot += diff_context;
  }

  // When deleting lines at the end of the buffer "top" can be past the end
  // of the buffer.
  top = MIN(top, wp->w_buffer->b_ml.ml_line_count);

  fline_T fline;

  fold_changed = false;
  fline.wp = wp;
  fline.off = 0;
  fline.lvl = 0;
  fline.lvl_next = -1;
  fline.start = 0;
  fline.end = MAX_LEVEL + 1;
  fline.had_end = MAX_LEVEL + 1;

  invalid_top = top;
  invalid_bot = bot;

  LevelGetter getlevel = NULL;

  if (foldmethodIsMarker(wp)) {
    getlevel = foldlevelMarker;

    // Init marker variables to speed up foldlevelMarker().
    parseMarker(wp);

    // Need to get the level of the line above top, it is used if there is
    // no marker at the top.
    if (top > 1) {
      // Get the fold level at top - 1.
      const int level = foldLevelWin(wp, top - 1);

      // The fold may end just above the top, check for that.
      fline.lnum = top - 1;
      fline.lvl = level;
      getlevel(&fline);

      // If a fold started here, we already had the level, if it stops
      // here, we need to use lvl_next.  Could also start and end a fold
      // in the same line.
      if (fline.lvl > level) {
        fline.lvl = level - (fline.lvl - fline.lvl_next);
      } else {
        fline.lvl = fline.lvl_next;
      }
    }
    fline.lnum = top;
    getlevel(&fline);
  } else {
    fline.lnum = top;
    if (foldmethodIsExpr(wp)) {
      getlevel = foldlevelExpr;
      // start one line back, because a "<1" may indicate the end of a
      // fold in the topline
      if (top > 1) {
        fline.lnum--;
      }
    } else if (foldmethodIsSyntax(wp)) {
      getlevel = foldlevelSyntax;
    } else if (foldmethodIsDiff(wp)) {
      getlevel = foldlevelDiff;
    } else {
      getlevel = foldlevelIndent;
      // Start one line back, because if the line above "top" has an
      // undefined fold level, folding it relies on the line under it,
      // which is "top".
      if (top > 1) {
        fline.lnum--;
      }
    }

    // Backup to a line for which the fold level is defined.  Since it's
    // always defined for line one, we will stop there.
    fline.lvl = -1;
    for (; !got_int; fline.lnum--) {
      // Reset lvl_next each time, because it will be set to a value for
      // the next line, but we search backwards here.
      fline.lvl_next = -1;
      getlevel(&fline);
      if (fline.lvl >= 0) {
        break;
      }
    }
  }

  // If folding is defined by the syntax, it is possible that a change in
  // one line will cause all sub-folds of the current fold to change (e.g.,
  // closing a C-style comment can cause folds in the subsequent lines to
  // appear). To take that into account we should adjust the value of "bot"
  // to point to the end of the current fold:
  if (foldlevelSyntax == getlevel) {
    garray_T *gap = &wp->w_folds;
    fold_T *fpn = NULL;
    int current_fdl = 0;
    linenr_T fold_start_lnum = 0;
    linenr_T lnum_rel = fline.lnum;

    while (current_fdl < fline.lvl) {
      if (!foldFind(gap, lnum_rel, &fpn)) {
        break;
      }
      current_fdl++;

      fold_start_lnum += fpn->fd_top;
      gap = &fpn->fd_nested;
      lnum_rel -= fpn->fd_top;
    }
    if (fpn != NULL && current_fdl == fline.lvl) {
      linenr_T fold_end_lnum = fold_start_lnum + fpn->fd_len;

      bot = MAX(bot, fold_end_lnum);
    }
  }

  linenr_T start = fline.lnum;
  linenr_T end = bot;
  // Do at least one line.
  if (start > end && end < wp->w_buffer->b_ml.ml_line_count) {
    end = start;
  }

  fold_T *fp;

  while (!got_int) {
    // Always stop at the end of the file ("end" can be past the end of
    // the file).
    if (fline.lnum > wp->w_buffer->b_ml.ml_line_count) {
      break;
    }
    if (fline.lnum > end) {
      // For "marker", "expr"  and "syntax"  methods: If a change caused
      // a fold to be removed, we need to continue at least until where
      // it ended.
      if (getlevel != foldlevelMarker
          && getlevel != foldlevelSyntax
          && getlevel != foldlevelExpr) {
        break;
      }
      if ((start <= end
           && foldFind(&wp->w_folds, end, &fp)
           && fp->fd_top + fp->fd_len - 1 > end)
          || (fline.lvl == 0
              && foldFind(&wp->w_folds, fline.lnum, &fp)
              && fp->fd_top < fline.lnum)) {
        end = fp->fd_top + fp->fd_len - 1;
      } else if (getlevel == foldlevelSyntax
                 && foldLevelWin(wp, fline.lnum) != fline.lvl) {
        // For "syntax" method: Compare the foldlevel that the syntax
        // tells us to the foldlevel from the existing folds.  If they
        // don't match continue updating folds.
        end = fline.lnum;
      } else {
        break;
      }
    }

    // A level 1 fold starts at a line with foldlevel > 0.
    if (fline.lvl > 0) {
      invalid_top = fline.lnum;
      invalid_bot = end;
      end = foldUpdateIEMSRecurse(&wp->w_folds, 1, start, &fline, getlevel, end,
                                  FD_LEVEL);
      start = fline.lnum;
    } else {
      if (fline.lnum == wp->w_buffer->b_ml.ml_line_count) {
        break;
      }
      fline.lnum++;
      fline.lvl = fline.lvl_next;
      getlevel(&fline);
    }
  }

  // There can't be any folds from start until end now.
  foldRemove(wp, &wp->w_folds, start, end);

  // If some fold changed, need to redraw and position cursor.
  if (fold_changed && wp->w_p_fen) {
    changed_window_setting(wp);
  }

  // If we updated folds past "bot", need to redraw more lines.  Don't do
  // this in other situations, the changed lines will be redrawn anyway and
  // this method can cause the whole window to be updated.
  if (end != bot) {
    if (wp->w_redraw_top == 0 || wp->w_redraw_top > top) {
      wp->w_redraw_top = top;
    }
    wp->w_redraw_bot = MAX(wp->w_redraw_bot, end);
  }

  invalid_top = 0;
}

// foldUpdateIEMSRecurse() {{{2
/// Update a fold that starts at "flp->lnum".  At this line there is always a
/// valid foldlevel, and its level >= "level".
///
/// "flp" is valid for "flp->lnum" when called and it's valid when returning.
/// "flp->lnum" is set to the lnum just below the fold, if it ends before
/// "bot", it's "bot" plus one if the fold continues and it's bigger when using
/// the marker method and a text change made following folds to change.
/// When returning, "flp->lnum_save" is the line number that was used to get
/// the level when the level at "flp->lnum" is invalid.
/// Remove any folds from "startlnum" up to here at this level.
/// Recursively update nested folds.
/// Below line "bot" there are no changes in the text.
/// "flp->lnum", "flp->lnum_save" and "bot" are relative to the start of the
/// outer fold.
/// "flp->off" is the offset to the real line number in the buffer.
///
/// All this would be a lot simpler if all folds in the range would be deleted
/// and then created again.  But we would lose all information about the
/// folds, even when making changes that don't affect the folding (e.g. "vj~").
///
/// @param topflags  containing fold flags
///
/// @return  bot, which may have been increased for lines that also need to be
/// updated as a result of a detected change in the fold.
static linenr_T foldUpdateIEMSRecurse(garray_T *const gap, const int level,
                                      const linenr_T startlnum, fline_T *const flp,
                                      LevelGetter getlevel, linenr_T bot, const char topflags)
{
  fold_T *fp = NULL;

  // If using the marker method, the start line is not the start of a fold
  // at the level we're dealing with and the level is non-zero, we must use
  // the previous fold.  But ignore a fold that starts at or below
  // startlnum, it must be deleted.
  if (getlevel == foldlevelMarker && flp->start <= flp->lvl - level
      && flp->lvl > 0) {
    foldFind(gap, startlnum - 1, &fp);
    if (fp != NULL
        && (fp >= ((fold_T *)gap->ga_data) + gap->ga_len
            || fp->fd_top >= startlnum)) {
      fp = NULL;
    }
  }

  fold_T *fp2;
  int lvl = level;
  linenr_T startlnum2 = startlnum;
  const linenr_T firstlnum = flp->lnum;     // first lnum we got
  bool finish = false;
  const linenr_T linecount = flp->wp->w_buffer->b_ml.ml_line_count - flp->off;

  // Loop over all lines in this fold, or until "bot" is hit.
  // Handle nested folds inside of this fold.
  // "flp->lnum" is the current line.  When finding the end of the fold, it
  // is just below the end of the fold.
  // "*flp" contains the level of the line "flp->lnum" or a following one if
  // there are lines with an invalid fold level.  "flp->lnum_save" is the
  // line number that was used to get the fold level (below "flp->lnum" when
  // it has an invalid fold level).  When called the fold level is always
  // valid, thus "flp->lnum_save" is equal to "flp->lnum".
  flp->lnum_save = flp->lnum;
  while (!got_int) {
    // Updating folds can be slow, check for CTRL-C.
    line_breakcheck();

    // Set "lvl" to the level of line "flp->lnum".  When flp->start is set
    // and after the first line of the fold, set the level to zero to
    // force the fold to end.  Do the same when had_end is set: Previous
    // line was marked as end of a fold.
    lvl = MIN(flp->lvl, MAX_LEVEL);
    if (flp->lnum > firstlnum
        && (level > lvl - flp->start || level >= flp->had_end)) {
      lvl = 0;
    }

    if (flp->lnum > bot && !finish && fp != NULL) {
      // For "marker" and "syntax" methods:
      // - If a change caused a nested fold to be removed, we need to
      //   delete it and continue at least until where it ended.
      // - If a change caused a nested fold to be created, or this fold
      //   to continue below its original end, need to finish this fold.
      if (getlevel != foldlevelMarker
          && getlevel != foldlevelExpr
          && getlevel != foldlevelSyntax) {
        break;
      }
      int i = 0;
      fp2 = fp;
      if (lvl >= level) {
        // Compute how deep the folds currently are, if it's deeper
        // than "lvl" then some must be deleted, need to update
        // at least one nested fold.
        int ll = flp->lnum - fp->fd_top;
        while (foldFind(&fp2->fd_nested, ll, &fp2)) {
          i++;
          ll -= fp2->fd_top;
        }
      }
      if (lvl < level + i) {
        foldFind(&fp->fd_nested, flp->lnum - fp->fd_top, &fp2);
        if (fp2 != NULL) {
          bot = fp2->fd_top + fp2->fd_len - 1 + fp->fd_top;
        }
      } else if (fp->fd_top + fp->fd_len <= flp->lnum && lvl >= level) {
        finish = true;
      } else {
        break;
      }
    }

    // At the start of the first nested fold and at the end of the current
    // fold: check if existing folds at this level, before the current
    // one, need to be deleted or truncated.
    if (fp == NULL
        && (lvl != level
            || flp->lnum_save >= bot
            || flp->start != 0
            || flp->had_end <= MAX_LEVEL
            || flp->lnum == linecount)) {
      // Remove or update folds that have lines between startlnum and
      // firstlnum.
      while (!got_int) {
        // set concat to 1 if it's allowed to concatenate this fold
        // with a previous one that touches it.
        int concat = (flp->start != 0 || flp->had_end <= MAX_LEVEL) ? 0 : 1;

        // Find an existing fold to re-use.  Preferably one that
        // includes startlnum, otherwise one that ends just before
        // startlnum or starts after it.
        if (gap->ga_len > 0
            && (foldFind(gap, startlnum, &fp)
                || (fp < ((fold_T *)gap->ga_data) + gap->ga_len
                    && fp->fd_top <= firstlnum)
                || foldFind(gap, firstlnum - concat, &fp)
                || (fp < ((fold_T *)gap->ga_data) + gap->ga_len
                    && ((lvl < level && fp->fd_top < flp->lnum)
                        || (lvl >= level
                            && fp->fd_top <= flp->lnum_save))))) {
          if (fp->fd_top + fp->fd_len + concat > firstlnum) {
            // Use existing fold for the new fold.  If it starts
            // before where we started looking, extend it.  If it
            // starts at another line, update nested folds to keep
            // their position, compensating for the new fd_top.
            if (fp->fd_top == firstlnum) {
              // We have found a fold beginning exactly where we want one.
            } else if (fp->fd_top >= startlnum) {
              if (fp->fd_top > firstlnum) {
                // We will move the start of this fold up, hence we move all
                // nested folds (with relative line numbers) down.
                foldMarkAdjustRecurse(flp->wp, &fp->fd_nested,
                                      0, (linenr_T)MAXLNUM,
                                      (fp->fd_top - firstlnum), 0);
              } else {
                // Will move fold down, move nested folds relatively up.
                foldMarkAdjustRecurse(flp->wp, &fp->fd_nested,
                                      0,
                                      (firstlnum - fp->fd_top - 1),
                                      (linenr_T)MAXLNUM,
                                      (fp->fd_top - firstlnum));
              }
              fp->fd_len += fp->fd_top - firstlnum;
              fp->fd_top = firstlnum;
              fp->fd_small = kNone;
              fold_changed = true;
            } else if ((flp->start != 0 && lvl == level)
                       || (firstlnum != startlnum)) {
              // Before there was a fold spanning from above startlnum to below
              // firstlnum. This fold is valid above startlnum (because we are
              // not updating that range), but there is now a break in it.
              // If the break is because we are now forced to start a new fold
              // at the level "level" at line fline->lnum, then we need to
              // split the fold at fline->lnum.
              // If the break is because the range [startlnum, firstlnum) is
              // now at a lower indent than "level", we need to split the fold
              // in this range.
              // Any splits have to be done recursively.
              linenr_T breakstart;
              linenr_T breakend;
              if (firstlnum != startlnum) {
                breakstart = startlnum;
                breakend = firstlnum;
              } else {
                breakstart = flp->lnum;
                breakend = flp->lnum;
              }
              foldRemove(flp->wp, &fp->fd_nested, breakstart - fp->fd_top,
                         breakend - fp->fd_top);
              int i = (int)(fp - (fold_T *)gap->ga_data);
              foldSplit(flp->wp->w_buffer, gap, i, breakstart, breakend - 1);
              fp = (fold_T *)gap->ga_data + i + 1;
              // If using the "marker" or "syntax" method, we
              // need to continue until the end of the fold is
              // found.
              if (getlevel == foldlevelMarker
                  || getlevel == foldlevelExpr
                  || getlevel == foldlevelSyntax) {
                finish = true;
              }
            }
            if (fp->fd_top == startlnum && concat) {
              int i = (int)(fp - (fold_T *)gap->ga_data);
              if (i != 0) {
                fp2 = fp - 1;
                if (fp2->fd_top + fp2->fd_len == fp->fd_top) {
                  foldMerge(flp->wp, fp2, gap, fp);
                  fp = fp2;
                }
              }
            }
            break;
          }
          if (fp->fd_top >= startlnum) {
            // A fold that starts at or after startlnum and stops
            // before the new fold must be deleted.  Continue
            // looking for the next one.
            deleteFoldEntry(flp->wp, gap,
                            (int)(fp - (fold_T *)gap->ga_data), true);
          } else {
            // A fold has some lines above startlnum, truncate it
            // to stop just above startlnum.
            fp->fd_len = startlnum - fp->fd_top;
            foldMarkAdjustRecurse(flp->wp, &fp->fd_nested,
                                  fp->fd_len, (linenr_T)MAXLNUM,
                                  (linenr_T)MAXLNUM, 0);
            fold_changed = true;
          }
        } else {
          // Insert new fold.  Careful: ga_data may be NULL and it
          // may change!
          int i;
          if (gap->ga_len == 0) {
            i = 0;
          } else {
            i = (int)(fp - (fold_T *)gap->ga_data);
          }
          foldInsert(gap, i);
          fp = (fold_T *)gap->ga_data + i;
          // The new fold continues until bot, unless we find the
          // end earlier.
          fp->fd_top = firstlnum;
          fp->fd_len = bot - firstlnum + 1;
          // When the containing fold is open, the new fold is open.
          // The new fold is closed if the fold above it is closed.
          // The first fold depends on the containing fold.
          if (topflags == FD_OPEN) {
            flp->wp->w_fold_manual = true;
            fp->fd_flags = FD_OPEN;
          } else if (i <= 0) {
            fp->fd_flags = topflags;
            if (topflags != FD_LEVEL) {
              flp->wp->w_fold_manual = true;
            }
          } else {
            fp->fd_flags = (fp - 1)->fd_flags;
          }
          fp->fd_small = kNone;
          // If using the "marker", "expr" or "syntax" method, we
          // need to continue until the end of the fold is found.
          if (getlevel == foldlevelMarker
              || getlevel == foldlevelExpr
              || getlevel == foldlevelSyntax) {
            finish = true;
          }
          fold_changed = true;
          break;
        }
      }
    }

    if (lvl < level || flp->lnum > linecount) {
      // Found a line with a lower foldlevel, this fold ends just above
      // "flp->lnum".
      break;
    }

    // The fold includes the line "flp->lnum" and "flp->lnum_save".
    // Check "fp" for safety.
    if (lvl > level && fp != NULL) {
      // There is a nested fold, handle it recursively.
      // At least do one line (can happen when finish is true).
      bot = MAX(bot, flp->lnum);

      // Line numbers in the nested fold are relative to the start of
      // this fold.
      flp->lnum = flp->lnum_save - fp->fd_top;
      flp->off += fp->fd_top;
      int i = (int)(fp - (fold_T *)gap->ga_data);
      bot = foldUpdateIEMSRecurse(&fp->fd_nested, level + 1,
                                  startlnum2 - fp->fd_top, flp, getlevel,
                                  bot - fp->fd_top, fp->fd_flags);
      fp = (fold_T *)gap->ga_data + i;
      flp->lnum += fp->fd_top;
      flp->lnum_save += fp->fd_top;
      flp->off -= fp->fd_top;
      bot += fp->fd_top;
      startlnum2 = flp->lnum;

      // This fold may end at the same line, don't incr. flp->lnum.
    } else {
      // Get the level of the next line, then continue the loop to check
      // if it ends there.
      // Skip over undefined lines, to find the foldlevel after it.
      // For the last line in the file the foldlevel is always valid.
      flp->lnum = flp->lnum_save;
      int ll = flp->lnum + 1;
      while (!got_int) {
        // Make the previous level available to foldlevel().
        prev_lnum = flp->lnum;
        prev_lnum_lvl = flp->lvl;

        if (++flp->lnum > linecount) {
          break;
        }
        flp->lvl = flp->lvl_next;
        getlevel(flp);
        if (flp->lvl >= 0 || flp->had_end <= MAX_LEVEL) {
          break;
        }
      }
      prev_lnum = 0;
      if (flp->lnum > linecount) {
        break;
      }

      // leave flp->lnum_save to lnum of the line that was used to get
      // the level, flp->lnum to the lnum of the next line.
      flp->lnum_save = flp->lnum;
      flp->lnum = ll;
    }
  }

  if (fp == NULL) {     // only happens when got_int is set
    return bot;
  }

  // Get here when:
  // lvl < level: the folds ends just above "flp->lnum"
  // lvl >= level: fold continues below "bot"

  // Current fold at least extends until lnum.
  if (fp->fd_len < flp->lnum - fp->fd_top) {
    fp->fd_len = flp->lnum - fp->fd_top;
    fp->fd_small = kNone;
    fold_changed = true;
  } else if (fp->fd_top + fp->fd_len > linecount) {
    // running into the end of the buffer (deleted last line)
    fp->fd_len = linecount - fp->fd_top + 1;
  }

  // Delete contained folds from the end of the last one found until where
  // we stopped looking.
  foldRemove(flp->wp, &fp->fd_nested, startlnum2 - fp->fd_top,
             flp->lnum - 1 - fp->fd_top);

  if (lvl < level) {
    // End of fold found, update the length when it got shorter.
    if (fp->fd_len != flp->lnum - fp->fd_top) {
      if (fp->fd_top + fp->fd_len - 1 > bot) {
        // fold continued below bot
        if (getlevel == foldlevelMarker
            || getlevel == foldlevelExpr
            || getlevel == foldlevelSyntax) {
          // marker method: truncate the fold and make sure the
          // previously included lines are processed again
          bot = fp->fd_top + fp->fd_len - 1;
          fp->fd_len = flp->lnum - fp->fd_top;
        } else {
          // indent or expr method: split fold to create a new one
          // below bot
          int i = (int)(fp - (fold_T *)gap->ga_data);
          foldSplit(flp->wp->w_buffer, gap, i, flp->lnum, bot);
          fp = (fold_T *)gap->ga_data + i;
        }
      } else {
        fp->fd_len = flp->lnum - fp->fd_top;
      }
      fold_changed = true;
    }
  }

  // delete following folds that end before the current line
  while (true) {
    fp2 = fp + 1;
    if (fp2 >= (fold_T *)gap->ga_data + gap->ga_len
        || fp2->fd_top > flp->lnum) {
      break;
    }
    if (fp2->fd_top + fp2->fd_len > flp->lnum) {
      if (fp2->fd_top < flp->lnum) {
        // Make fold that includes lnum start at lnum.
        foldMarkAdjustRecurse(flp->wp, &fp2->fd_nested,
                              0, (flp->lnum - fp2->fd_top - 1),
                              (linenr_T)MAXLNUM, (fp2->fd_top - flp->lnum));
        fp2->fd_len -= flp->lnum - fp2->fd_top;
        fp2->fd_top = flp->lnum;
        fold_changed = true;
      }

      if (lvl >= level) {
        // merge new fold with existing fold that follows
        foldMerge(flp->wp, fp, gap, fp2);
      }
      break;
    }
    fold_changed = true;
    deleteFoldEntry(flp->wp, gap, (int)(fp2 - (fold_T *)gap->ga_data), true);
  }

  // Need to redraw the lines we inspected, which might be further down than
  // was asked for.
  bot = MAX(bot, flp->lnum - 1);

  return bot;
}

// foldInsert() {{{2
/// Insert a new fold in "gap" at position "i".
static void foldInsert(garray_T *gap, int i)
{
  ga_grow(gap, 1);

  fold_T *fp = (fold_T *)gap->ga_data + i;
  if (gap->ga_len > 0 && i < gap->ga_len) {
    memmove(fp + 1, fp, sizeof(fold_T) * (size_t)(gap->ga_len - i));
  }
  gap->ga_len++;
  ga_init(&fp->fd_nested, (int)sizeof(fold_T), 10);
}

// foldSplit() {{{2
/// Split the "i"th fold in "gap", which starts before "top" and ends below
/// "bot" in two pieces, one ending above "top" and the other starting below
/// "bot".
/// The caller must first have taken care of any nested folds from "top" to
/// "bot"!
static void foldSplit(buf_T *buf, garray_T *const gap, const int i, const linenr_T top,
                      const linenr_T bot)
{
  fold_T *fp2;

  // The fold continues below bot, need to split it.
  foldInsert(gap, i + 1);

  fold_T *const fp = (fold_T *)gap->ga_data + i;
  fp[1].fd_top = bot + 1;
  // check for wrap around (MAXLNUM, and 32bit)
  assert(fp[1].fd_top > bot);
  fp[1].fd_len = fp->fd_len - (fp[1].fd_top - fp->fd_top);
  fp[1].fd_flags = fp->fd_flags;
  fp[1].fd_small = kNone;
  fp->fd_small = kNone;

  // Move nested folds below bot to new fold.  There can't be
  // any between top and bot, they have been removed by the caller.
  garray_T *const gap1 = &fp->fd_nested;
  garray_T *const gap2 = &fp[1].fd_nested;
  foldFind(gap1, bot + 1 - fp->fd_top, &fp2);
  if (fp2 != NULL) {
    const int len = (int)((fold_T *)gap1->ga_data + gap1->ga_len - fp2);
    if (len > 0) {
      ga_grow(gap2, len);
      for (int idx = 0; idx < len; idx++) {
        ((fold_T *)gap2->ga_data)[idx] = fp2[idx];
        ((fold_T *)gap2->ga_data)[idx].fd_top
          -= fp[1].fd_top - fp->fd_top;
      }
      gap2->ga_len = len;
      gap1->ga_len -= len;
    }
  }
  fp->fd_len = top - fp->fd_top;
  fold_changed = true;
}

// foldRemove() {{{2
/// Remove folds within the range "top" to and including "bot".
/// Check for these situations:
///      1  2  3
///      1  2  3
/// top     2  3  4  5
///     2  3  4  5
/// bot     2  3  4  5
///        3     5  6
///        3     5  6
///
/// 1: not changed
/// 2: truncate to stop above "top"
/// 3: split in two parts, one stops above "top", other starts below "bot".
/// 4: deleted
/// 5: made to start below "bot".
/// 6: not changed
static void foldRemove(win_T *const wp, garray_T *gap, linenr_T top, linenr_T bot)
{
  if (bot < top) {
    return;             // nothing to do
  }

  fold_T *fp = NULL;

  while (gap->ga_len > 0) {
    // Find fold that includes top or a following one.
    if (foldFind(gap, top, &fp) && fp->fd_top < top) {
      // 2: or 3: need to delete nested folds
      foldRemove(wp, &fp->fd_nested, top - fp->fd_top, bot - fp->fd_top);
      if (fp->fd_top + fp->fd_len - 1 > bot) {
        // 3: need to split it.
        foldSplit(wp->w_buffer, gap,
                  (int)(fp - (fold_T *)gap->ga_data), top, bot);
      } else {
        // 2: truncate fold at "top".
        fp->fd_len = top - fp->fd_top;
      }
      fold_changed = true;
      continue;
    }
    if (gap->ga_data == NULL
        || fp >= (fold_T *)(gap->ga_data) + gap->ga_len
        || fp->fd_top > bot) {
      // 6: Found a fold below bot, can stop looking.
      break;
    }
    if (fp->fd_top >= top) {
      // Found an entry below top.
      fold_changed = true;
      if (fp->fd_top + fp->fd_len - 1 > bot) {
        // 5: Make fold that includes bot start below bot.
        foldMarkAdjustRecurse(wp, &fp->fd_nested,
                              0, (bot - fp->fd_top),
                              (linenr_T)MAXLNUM, (fp->fd_top - bot - 1));
        fp->fd_len -= bot - fp->fd_top + 1;
        fp->fd_top = bot + 1;
        break;
      }

      // 4: Delete completely contained fold.
      deleteFoldEntry(wp, gap, (int)(fp - (fold_T *)gap->ga_data), true);
    }
  }
}

// foldReverseOrder() {{{2
static void foldReverseOrder(garray_T *gap, const linenr_T start_arg, const linenr_T end_arg)
{
  linenr_T start = start_arg;
  linenr_T end = end_arg;
  for (; start < end; start++, end--) {
    fold_T *left = (fold_T *)gap->ga_data + start;
    fold_T *right = (fold_T *)gap->ga_data + end;
    fold_T tmp = *left;
    *left = *right;
    *right = tmp;
  }
}

// foldMoveRange() {{{2
/// Move folds within the inclusive range "line1" to "line2" to after "dest"
/// require "line1" <= "line2" <= "dest"
///
/// There are the following situations for the first fold at or below line1 - 1.
///       1  2  3  4
///       1  2  3  4
/// line1    2  3  4
///          2  3  4  5  6  7
/// line2       3  4  5  6  7
///             3  4     6  7  8  9
/// dest           4        7  8  9
///                4        7  8    10
///                4        7  8    10
///
/// In the following descriptions, "moved" means moving in the buffer, *and* in
/// the fold array.
/// Meanwhile, "shifted" just means moving in the buffer.
/// 1. not changed
/// 2. truncated above line1
/// 3. length reduced by  line2 - line1, folds starting between the end of 3 and
///    dest are truncated and shifted up
/// 4. internal folds moved (from [line1, line2] to dest)
/// 5. moved to dest.
/// 6. truncated below line2 and moved.
/// 7. length reduced by line2 - dest, folds starting between line2 and dest are
///    removed, top is moved down by move_len.
/// 8. truncated below dest and shifted up.
/// 9. shifted up
/// 10. not changed
static void truncate_fold(win_T *const wp, fold_T *fp, linenr_T end)
{
  // I want to stop *at here*, foldRemove() stops *above* top
  end += 1;
  foldRemove(wp, &fp->fd_nested, end - fp->fd_top, MAXLNUM);
  fp->fd_len = end - fp->fd_top;
}

#define FOLD_END(fp) ((fp)->fd_top + (fp)->fd_len - 1)
#define VALID_FOLD(fp, gap) \
  ((gap)->ga_len > 0 && (fp) < ((fold_T *)(gap)->ga_data + (gap)->ga_len))
#define FOLD_INDEX(fp, gap) ((size_t)((fp) - ((fold_T *)(gap)->ga_data)))
void foldMoveRange(win_T *const wp, garray_T *gap, const linenr_T line1, const linenr_T line2,
                   const linenr_T dest)
{
  fold_T *fp;
  const linenr_T range_len = line2 - line1 + 1;
  const linenr_T move_len = dest - line2;
  const bool at_start = foldFind(gap, line1 - 1, &fp);

  if (at_start) {
    if (FOLD_END(fp) > dest) {
      // Case 4 -- don't have to change this fold, but have to move nested
      // folds.
      foldMoveRange(wp, &fp->fd_nested, line1 - fp->fd_top, line2 -
                    fp->fd_top, dest - fp->fd_top);
      return;
    } else if (FOLD_END(fp) > line2) {
      // Case 3 -- Remove nested folds between line1 and line2 & reduce the
      // length of fold by "range_len".
      // Folds after this one must be dealt with.
      foldMarkAdjustRecurse(wp, &fp->fd_nested, line1 - fp->fd_top,
                            line2 - fp->fd_top, MAXLNUM, -range_len);
      fp->fd_len -= range_len;
    } else {
      // Case 2 -- truncate fold *above* line1.
      // Folds after this one must be dealt with.
      truncate_fold(wp, fp, line1 - 1);
    }
    // Look at the next fold, and treat that one as if it were the first after
    // "line1" (because now it is).
    fp = fp + 1;
  }

  if (!VALID_FOLD(fp, gap) || fp->fd_top > dest) {
    // No folds after "line1" and before "dest"
    // Case 10.
    return;
  } else if (fp->fd_top > line2) {
    for (; VALID_FOLD(fp, gap) && FOLD_END(fp) <= dest; fp++) {
      // Case 9. (for all case 9's) -- shift up.
      fp->fd_top -= range_len;
    }
    if (VALID_FOLD(fp, gap) && fp->fd_top <= dest) {
      // Case 8. -- ensure truncated at dest, shift up
      truncate_fold(wp, fp, dest);
      fp->fd_top -= range_len;
    }
    return;
  } else if (FOLD_END(fp) > dest) {
    // Case 7 -- remove nested folds and shrink
    foldMarkAdjustRecurse(wp, &fp->fd_nested, line2 + 1 - fp->fd_top,
                          dest - fp->fd_top, MAXLNUM, -move_len);
    fp->fd_len -= move_len;
    fp->fd_top += move_len;
    return;
  }

  // Case 5 or 6: changes rely on whether there are folds between the end of
  // this fold and "dest".
  size_t move_start = FOLD_INDEX(fp, gap);
  size_t move_end = 0;
  size_t dest_index = 0;
  for (; VALID_FOLD(fp, gap) && fp->fd_top <= dest; fp++) {
    if (fp->fd_top <= line2) {
      // 5, or 6
      if (FOLD_END(fp) > line2) {
        // 6, truncate before moving
        truncate_fold(wp, fp, line2);
      }
      fp->fd_top += move_len;
      continue;
    }

    // Record index of the first fold after the moved range.
    if (move_end == 0) {
      move_end = FOLD_INDEX(fp, gap);
    }

    if (FOLD_END(fp) > dest) {
      truncate_fold(wp, fp, dest);
    }

    fp->fd_top -= range_len;
  }
  dest_index = FOLD_INDEX(fp, gap);

  // All folds are now correct, but not necessarily in the correct order.
  // We must swap folds in the range [move_end, dest_index) with those in the
  // range [move_start, move_end).
  if (move_end == 0) {
    // There are no folds after those moved, so none were moved out of order.
    return;
  }
  foldReverseOrder(gap, (linenr_T)move_start, (linenr_T)(dest_index - 1));
  foldReverseOrder(gap, (linenr_T)move_start,
                   (linenr_T)(move_start + dest_index - move_end - 1));
  foldReverseOrder(gap, (linenr_T)(move_start + dest_index - move_end),
                   (linenr_T)(dest_index - 1));
}
#undef FOLD_END
#undef VALID_FOLD
#undef FOLD_INDEX

// foldMerge() {{{2
/// Merge two adjacent folds (and the nested ones in them).
/// This only works correctly when the folds are really adjacent!  Thus "fp1"
/// must end just above "fp2".
/// The resulting fold is "fp1", nested folds are moved from "fp2" to "fp1".
/// Fold entry "fp2" in "gap" is deleted.
static void foldMerge(win_T *const wp, fold_T *fp1, garray_T *gap, fold_T *fp2)
{
  fold_T *fp3;
  fold_T *fp4;
  garray_T *gap1 = &fp1->fd_nested;
  garray_T *gap2 = &fp2->fd_nested;

  // If the last nested fold in fp1 touches the first nested fold in fp2,
  // merge them recursively.
  if (foldFind(gap1, fp1->fd_len - 1, &fp3) && foldFind(gap2, 0, &fp4)) {
    foldMerge(wp, fp3, gap2, fp4);
  }

  // Move nested folds in fp2 to the end of fp1.
  if (!GA_EMPTY(gap2)) {
    ga_grow(gap1, gap2->ga_len);
    for (int idx = 0; idx < gap2->ga_len; idx++) {
      ((fold_T *)gap1->ga_data)[gap1->ga_len]
        = ((fold_T *)gap2->ga_data)[idx];
      ((fold_T *)gap1->ga_data)[gap1->ga_len].fd_top += fp1->fd_len;
      gap1->ga_len++;
    }
    gap2->ga_len = 0;
  }

  fp1->fd_len += fp2->fd_len;
  deleteFoldEntry(wp, gap, (int)(fp2 - (fold_T *)gap->ga_data), true);
  fold_changed = true;
}

// foldlevelIndent() {{{2
/// Low level function to get the foldlevel for the "indent" method.
/// Doesn't use any caching.
///
/// @return  a level of -1 if the foldlevel depends on surrounding lines.
static void foldlevelIndent(fline_T *flp)
{
  linenr_T lnum = flp->lnum + flp->off;

  buf_T *buf = flp->wp->w_buffer;
  char *s = skipwhite(ml_get_buf(buf, lnum));

  // empty line or lines starting with a character in 'foldignore': level
  // depends on surrounding lines
  if (*s == NUL || vim_strchr(flp->wp->w_p_fdi, (uint8_t)(*s)) != NULL) {
    // first and last line can't be undefined, use level 0
    flp->lvl = (lnum == 1 || lnum == buf->b_ml.ml_line_count) ? 0 : -1;
  } else {
    flp->lvl = get_indent_buf(buf, lnum) / get_sw_value(buf);
  }
  flp->lvl = MIN(flp->lvl, (int)MAX(0, flp->wp->w_p_fdn));
}

// foldlevelDiff() {{{2
/// Low level function to get the foldlevel for the "diff" method.
/// Doesn't use any caching.
static void foldlevelDiff(fline_T *flp)
{
  flp->lvl = (diff_infold(flp->wp, flp->lnum + flp->off)) ? 1 : 0;
}

// foldlevelExpr() {{{2
/// Low level function to get the foldlevel for the "expr" method.
/// Doesn't use any caching.
///
/// @return  a level of -1 if the foldlevel depends on surrounding lines.
static void foldlevelExpr(fline_T *flp)
{
  linenr_T lnum = flp->lnum + flp->off;

  win_T *win = curwin;
  curwin = flp->wp;
  curbuf = flp->wp->w_buffer;
  set_vim_var_nr(VV_LNUM, (varnumber_T)lnum);

  flp->start = 0;
  flp->had_end = flp->end;
  flp->end = MAX_LEVEL + 1;
  if (lnum <= 1) {
    flp->lvl = 0;
  }

  // KeyTyped may be reset to 0 when calling a function which invokes
  // do_cmdline().  To make 'foldopen' work correctly restore KeyTyped.
  const bool save_keytyped = KeyTyped;

  int c;
  const int n = eval_foldexpr(flp->wp, &c);
  KeyTyped = save_keytyped;

  switch (c) {
  // "a1", "a2", .. : add to the fold level
  case 'a':
    if (flp->lvl >= 0) {
      flp->lvl += n;
      flp->lvl_next = flp->lvl;
    }
    flp->start = n;
    break;

  // "s1", "s2", .. : subtract from the fold level
  case 's':
    if (flp->lvl >= 0) {
      if (n > flp->lvl) {
        flp->lvl_next = 0;
      } else {
        flp->lvl_next = flp->lvl - n;
      }
      flp->end = flp->lvl_next + 1;
    }
    break;

  // ">1", ">2", .. : start a fold with a certain level
  case '>':
    flp->lvl = n;
    flp->lvl_next = n;
    flp->start = 1;
    break;

  // "<1", "<2", .. : end a fold with a certain level
  case '<':
    // To prevent an unexpected start of a new fold, the next
    // level must not exceed the level of the current fold.
    flp->lvl_next = MIN(flp->lvl, n - 1);
    flp->end = n;
    break;

  // "=": No change in level
  case '=':
    flp->lvl_next = flp->lvl;
    break;

  // "-1", "0", "1", ..: set fold level
  default:
    if (n < 0) {
      // Use the current level for the next line, so that "a1"
      // will work there.
      flp->lvl_next = flp->lvl;
    } else {
      flp->lvl_next = n;
    }
    flp->lvl = n;
    break;
  }

  // If the level is unknown for the first or the last line in the file, use
  // level 0.
  if (flp->lvl < 0) {
    if (lnum <= 1) {
      flp->lvl = 0;
      flp->lvl_next = 0;
    }
    if (lnum == curbuf->b_ml.ml_line_count) {
      flp->lvl_next = 0;
    }
  }

  curwin = win;
  curbuf = curwin->w_buffer;
}

// parseMarker() {{{2
/// Parse 'foldmarker' and set "foldendmarker", "foldstartmarkerlen" and
/// "foldendmarkerlen".
/// Relies on the option value to have been checked for correctness already.
static void parseMarker(win_T *wp)
{
  foldendmarker = vim_strchr(wp->w_p_fmr, ',');
  foldstartmarkerlen = (size_t)(foldendmarker++ - wp->w_p_fmr);
  foldendmarkerlen = strlen(foldendmarker);
}

// foldlevelMarker() {{{2
/// Low level function to get the foldlevel for the "marker" method.
/// "foldendmarker", "foldstartmarkerlen" and "foldendmarkerlen" must have been
/// set before calling this.
/// Requires that flp->lvl is set to the fold level of the previous line!
/// Careful: This means you can't call this function twice on the same line.
/// Doesn't use any caching.
/// Sets flp->start when a start marker was found.
static void foldlevelMarker(fline_T *flp)
{
  int start_lvl = flp->lvl;

  // cache a few values for speed
  char *startmarker = flp->wp->w_p_fmr;
  char cstart = *startmarker;
  startmarker++;
  char cend = *foldendmarker;

  // Default: no start found, next level is same as current level
  flp->start = 0;
  flp->lvl_next = flp->lvl;

  char *s = ml_get_buf(flp->wp->w_buffer, flp->lnum + flp->off);
  while (*s) {
    if (*s == cstart
        && strncmp(s + 1, startmarker, foldstartmarkerlen - 1) == 0) {
      // found startmarker: set flp->lvl
      s += foldstartmarkerlen;
      if (ascii_isdigit(*s)) {
        int n = atoi(s);
        if (n > 0) {
          flp->lvl = n;
          flp->lvl_next = n;
          flp->start = MAX(n - start_lvl, 1);
        }
      } else {
        flp->lvl++;
        flp->lvl_next++;
        flp->start++;
      }
    } else if (*s == cend
               && strncmp(s + 1, foldendmarker + 1, foldendmarkerlen - 1) == 0) {
      // found endmarker: set flp->lvl_next
      s += foldendmarkerlen;
      if (ascii_isdigit(*s)) {
        int n = atoi(s);
        if (n > 0) {
          flp->lvl = n;
          flp->lvl_next = n - 1;
          // never start a fold with an end marker
          flp->lvl_next = MIN(flp->lvl_next, start_lvl);
        }
      } else {
        flp->lvl_next--;
      }
    } else {
      MB_PTR_ADV(s);
    }
  }

  // The level can't go negative, must be missing a start marker.
  flp->lvl_next = MAX(flp->lvl_next, 0);
}

// foldlevelSyntax() {{{2
/// Low level function to get the foldlevel for the "syntax" method.
/// Doesn't use any caching.
static void foldlevelSyntax(fline_T *flp)
{
  linenr_T lnum = flp->lnum + flp->off;

  // Use the maximum fold level at the start of this line and the next.
  flp->lvl = syn_get_foldlevel(flp->wp, lnum);
  flp->start = 0;
  if (lnum < flp->wp->w_buffer->b_ml.ml_line_count) {
    int n = syn_get_foldlevel(flp->wp, lnum + 1);
    if (n > flp->lvl) {
      flp->start = n - flp->lvl;        // fold(s) start here
      flp->lvl = n;
    }
  }
}

// functions for storing the fold state in a View {{{1
// put_folds() {{{2
/// Write commands to "fd" to restore the manual folds in window "wp".
///
/// @return  FAIL if writing fails.
int put_folds(FILE *fd, win_T *wp)
{
  if (foldmethodIsManual(wp)) {
    if (put_line(fd, "silent! normal! zE") == FAIL
        || put_folds_recurse(fd, &wp->w_folds, 0) == FAIL
        || put_line(fd, "let &fdl = &fdl") == FAIL) {
      return FAIL;
    }
  }

  // If some folds are manually opened/closed, need to restore that.
  if (wp->w_fold_manual) {
    return put_foldopen_recurse(fd, wp, &wp->w_folds, 0);
  }

  return OK;
}

// put_folds_recurse() {{{2
/// Write commands to "fd" to recreate manually created folds.
///
/// @return  FAIL when writing failed.
static int put_folds_recurse(FILE *fd, garray_T *gap, linenr_T off)
{
  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    // Do nested folds first, they will be created closed.
    if (put_folds_recurse(fd, &fp->fd_nested, off + fp->fd_top) == FAIL) {
      return FAIL;
    }
    if (fprintf(fd, "%" PRId64 ",%" PRId64 "fold",
                (int64_t)fp->fd_top + off,
                (int64_t)(fp->fd_top + off + fp->fd_len - 1)) < 0
        || put_eol(fd) == FAIL) {
      return FAIL;
    }
    fp++;
  }
  return OK;
}

// put_foldopen_recurse() {{{2
/// Write commands to "fd" to open and close manually opened/closed folds.
///
/// @return  FAIL when writing failed.
static int put_foldopen_recurse(FILE *fd, win_T *wp, garray_T *gap, linenr_T off)
{
  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    if (fp->fd_flags != FD_LEVEL) {
      if (!GA_EMPTY(&fp->fd_nested)) {
        // open nested folds while this fold is open
        if (fprintf(fd, "%" PRId64, (int64_t)fp->fd_top + off) < 0
            || put_eol(fd) == FAIL
            || put_line(fd, "normal! zo") == FAIL) {
          return FAIL;
        }
        if (put_foldopen_recurse(fd, wp, &fp->fd_nested,
                                 off + fp->fd_top)
            == FAIL) {
          return FAIL;
        }
        // close the parent when needed
        if (fp->fd_flags == FD_CLOSED) {
          if (put_fold_open_close(fd, fp, off) == FAIL) {
            return FAIL;
          }
        }
      } else {
        // Open or close the leaf according to the window foldlevel.
        // Do not close a leaf that is already closed, as it will close
        // the parent.
        int level = foldLevelWin(wp, off + fp->fd_top);
        if ((fp->fd_flags == FD_CLOSED && wp->w_p_fdl >= level)
            || (fp->fd_flags != FD_CLOSED && wp->w_p_fdl < level)) {
          if (put_fold_open_close(fd, fp, off) == FAIL) {
            return FAIL;
          }
        }
      }
    }
    fp++;
  }

  return OK;
}

// put_fold_open_close() {{{2
/// Write the open or close command to "fd".
///
/// @return  FAIL when writing failed.
static int put_fold_open_close(FILE *fd, fold_T *fp, linenr_T off)
{
  if (fprintf(fd, "%" PRIdLINENR, fp->fd_top + off) < 0
      || put_eol(fd) == FAIL
      || fprintf(fd, "normal! z%c",
                 fp->fd_flags == FD_CLOSED ? 'c' : 'o') < 0
      || put_eol(fd) == FAIL) {
    return FAIL;
  }

  return OK;
}

// }}}1

/// "foldclosed()" and "foldclosedend()" functions
static void foldclosed_both(typval_T *argvars, typval_T *rettv, bool end)
{
  const linenr_T lnum = tv_get_lnum(argvars);
  if (lnum >= 1 && lnum <= curbuf->b_ml.ml_line_count) {
    linenr_T first;
    linenr_T last;
    if (hasFoldingWin(curwin, lnum, &first, &last, false, NULL)) {
      rettv->vval.v_number = (varnumber_T)(end ? last : first);
      return;
    }
  }
  rettv->vval.v_number = -1;
}

/// "foldclosed()" function
void f_foldclosed(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  foldclosed_both(argvars, rettv, false);
}

/// "foldclosedend()" function
void f_foldclosedend(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  foldclosed_both(argvars, rettv, true);
}

/// "foldlevel()" function
void f_foldlevel(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const linenr_T lnum = tv_get_lnum(argvars);
  if (lnum >= 1 && lnum <= curbuf->b_ml.ml_line_count) {
    rettv->vval.v_number = foldLevel(lnum);
  }
}

/// "foldtext()" function
void f_foldtext(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  linenr_T foldstart = (linenr_T)get_vim_var_nr(VV_FOLDSTART);
  linenr_T foldend = (linenr_T)get_vim_var_nr(VV_FOLDEND);
  char *dashes = get_vim_var_str(VV_FOLDDASHES);
  if (foldstart > 0 && foldend <= curbuf->b_ml.ml_line_count) {
    // Find first non-empty line in the fold.
    linenr_T lnum;
    for (lnum = foldstart; lnum < foldend; lnum++) {
      if (!linewhite(lnum)) {
        break;
      }
    }

    // Find interesting text in this line.
    char *s = skipwhite(ml_get(lnum));
    // skip C comment-start
    if (s[0] == '/' && (s[1] == '*' || s[1] == '/')) {
      s = skipwhite(s + 2);
      if (*skipwhite(s) == NUL && lnum + 1 < foldend) {
        s = skipwhite(ml_get(lnum + 1));
        if (*s == '*') {
          s = skipwhite(s + 1);
        }
      }
    }
    int count = foldend - foldstart + 1;
    char *txt = NGETTEXT("+-%s%3d line: ", "+-%s%3d lines: ", count);
    size_t len = strlen(txt)
                 + strlen(dashes)  // for %s
                 + 20              // for %3ld
                 + strlen(s);      // concatenated
    char *r = xmalloc(len);
    snprintf(r, len, txt, dashes, count);
    len = strlen(r);
    strcat(r, s);
    // remove 'foldmarker' and 'commentstring'
    foldtext_cleanup(r + len);
    rettv->vval.v_string = r;
  }
}

/// "foldtextresult(lnum)" function
void f_foldtextresult(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char buf[FOLD_TEXT_LEN];
  static bool entered = false;

  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;
  if (entered) {
    return;  // reject recursive use
  }
  entered = true;
  linenr_T lnum = tv_get_lnum(argvars);
  // Treat illegal types and illegal string values for {lnum} the same.
  lnum = MAX(lnum, 0);

  foldinfo_T info = fold_info(curwin, lnum);
  if (info.fi_lines > 0) {
    VirtText vt = VIRTTEXT_EMPTY;
    char *text = get_foldtext(curwin, lnum, lnum + info.fi_lines - 1, info, buf, &vt);
    if (text == buf) {
      text = xstrdup(text);
    }
    if (kv_size(vt) > 0) {
      assert(*text == NUL);
      for (size_t i = 0; i < kv_size(vt);) {
        int attr = 0;
        char *new_text = next_virt_text_chunk(vt, &i, &attr);
        if (new_text == NULL) {
          break;
        }
        new_text = concat_str(text, new_text);
        xfree(text);
        text = new_text;
      }
    }
    clear_virttext(&vt);
    rettv->vval.v_string = text;
  }

  entered = false;
}
