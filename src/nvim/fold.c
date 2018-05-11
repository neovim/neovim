// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// vim: set fdm=marker fdl=1 fdc=3

/*
 * fold.c: code for folding
 */

#include <string.h>
#include <inttypes.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/fold.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/eval.h"
#include "nvim/ex_docmd.h"
#include "nvim/func_attr.h"
#include "nvim/indent.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/screen.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/undo.h"
#include "nvim/ops.h"

/* local declarations. {{{1 */
/* typedef fold_T {{{2 */
/*
 * The toplevel folds for each window are stored in the w_folds growarray.
 * Each toplevel fold can contain an array of second level folds in the
 * fd_nested growarray.
 * The info stored in both growarrays is the same: An array of fold_T.
 */
typedef struct {
  linenr_T fd_top;              /* first line of fold; for nested fold
                                 * relative to parent */
  linenr_T fd_len;              /* number of lines in the fold */
  garray_T fd_nested;           /* array of nested folds */
  char fd_flags;                /* see below */
  char fd_small;                /* TRUE, FALSE or MAYBE: fold smaller than
                                   'foldminlines'; MAYBE applies to nested
                                   folds too */
} fold_T;

#define FD_OPEN         0       /* fold is open (nested ones can be closed) */
#define FD_CLOSED       1       /* fold is closed */
#define FD_LEVEL        2       /* depends on 'foldlevel' (nested folds too) */

#define MAX_LEVEL       20      /* maximum fold depth */

/* Define "fline_T", passed to get fold level for a line. {{{2 */
typedef struct {
  win_T       *wp;              /* window */
  linenr_T lnum;                /* current line number */
  linenr_T off;                 /* offset between lnum and real line number */
  linenr_T lnum_save;           /* line nr used by foldUpdateIEMSRecurse() */
  int lvl;                      /* current level (-1 for undefined) */
  int lvl_next;                 /* level used for next line */
  int start;                    /* number of folds that are forced to start at
                                   this line. */
  int end;                      /* level of fold that is forced to end below
                                   this line */
  int had_end;                  /* level of fold that is forced to end above
                                   this line (copy of "end" of prev. line) */
} fline_T;

/* Flag is set when redrawing is needed. */
static int fold_changed;

/* Function used by foldUpdateIEMSRecurse */
typedef void (*LevelGetter)(fline_T *);

/* static functions {{{2 */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.c.generated.h"
#endif
static char *e_nofold = N_("E490: No fold found");

/*
 * While updating the folds lines between invalid_top and invalid_bot have an
 * undefined fold level.  Only used for the window currently being updated.
 */
static linenr_T invalid_top = (linenr_T)0;
static linenr_T invalid_bot = (linenr_T)0;

/*
 * When using 'foldexpr' we sometimes get the level of the next line, which
 * calls foldlevel() to get the level of the current line, which hasn't been
 * stored yet.  To get around this chicken-egg problem the level of the
 * previous line is stored here when available.  prev_lnum is zero when the
 * level is not available.
 */
static linenr_T prev_lnum = 0;
static int prev_lnum_lvl = -1;

/* Flags used for "done" argument of setManualFold. */
#define DONE_NOTHING    0
#define DONE_ACTION     1       /* did close or open a fold */
#define DONE_FOLD       2       /* did find a fold */

static size_t foldstartmarkerlen;
static char_u *foldendmarker;
static size_t foldendmarkerlen;

/* Exported folding functions. {{{1 */
/* copyFoldingState() {{{2 */
/*
 * Copy that folding state from window "wp_from" to window "wp_to".
 */
void copyFoldingState(win_T *wp_from, win_T *wp_to)
{
  wp_to->w_fold_manual = wp_from->w_fold_manual;
  wp_to->w_foldinvalid = wp_from->w_foldinvalid;
  cloneFoldGrowArray(&wp_from->w_folds, &wp_to->w_folds);
}

/* hasAnyFolding() {{{2 */
/*
 * Return TRUE if there may be folded lines in the current window.
 */
int hasAnyFolding(win_T *win)
{
  /* very simple now, but can become more complex later */
  return !win->w_buffer->terminal && win->w_p_fen
         && (!foldmethodIsManual(win) || !GA_EMPTY(&win->w_folds));
}

/* hasFolding() {{{2 */
/*
 * Return TRUE if line "lnum" in the current window is part of a closed
 * fold.
 * When returning TRUE, *firstp and *lastp are set to the first and last
 * lnum of the sequence of folded lines (skipped when NULL).
 */
bool hasFolding(linenr_T lnum, linenr_T *firstp, linenr_T *lastp)
{
  return hasFoldingWin(curwin, lnum, firstp, lastp, TRUE, NULL);
}

/* hasFoldingWin() {{{2 */
bool hasFoldingWin(
    win_T *win,
    linenr_T lnum,
    linenr_T *firstp,
    linenr_T *lastp,
    int cache,                      /* when TRUE: use cached values of window */
    foldinfo_T *infop             /* where to store fold info */
)
{
  int had_folded = FALSE;
  linenr_T first = 0;
  linenr_T last = 0;
  linenr_T lnum_rel = lnum;
  int x;
  fold_T      *fp;
  int level = 0;
  int use_level = FALSE;
  int maybe_small = FALSE;
  garray_T    *gap;
  int low_level = 0;

  checkupdate(win);
  /*
   * Return quickly when there is no folding at all in this window.
   */
  if (!hasAnyFolding(win)) {
    if (infop != NULL)
      infop->fi_level = 0;
    return false;
  }

  if (cache) {
    /*
     * First look in cached info for displayed lines.  This is probably
     * the fastest, but it can only be used if the entry is still valid.
     */
    x = find_wl_entry(win, lnum);
    if (x >= 0) {
      first = win->w_lines[x].wl_lnum;
      last = win->w_lines[x].wl_lastlnum;
      had_folded = win->w_lines[x].wl_folded;
    }
  }

  if (first == 0) {
    /*
     * Recursively search for a fold that contains "lnum".
     */
    gap = &win->w_folds;
    for (;; ) {
      if (!foldFind(gap, lnum_rel, &fp))
        break;

      /* Remember lowest level of fold that starts in "lnum". */
      if (lnum_rel == fp->fd_top && low_level == 0)
        low_level = level + 1;

      first += fp->fd_top;
      last += fp->fd_top;

      /* is this fold closed? */
      had_folded = check_closed(win, fp, &use_level, level,
          &maybe_small, lnum - lnum_rel);
      if (had_folded) {
        /* Fold closed: Set last and quit loop. */
        last += fp->fd_len - 1;
        break;
      }

      /* Fold found, but it's open: Check nested folds.  Line number is
       * relative to containing fold. */
      gap = &fp->fd_nested;
      lnum_rel -= fp->fd_top;
      ++level;
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

  if (last > win->w_buffer->b_ml.ml_line_count) {
    last = win->w_buffer->b_ml.ml_line_count;
  }
  if (lastp != NULL)
    *lastp = last;
  if (firstp != NULL)
    *firstp = first;
  if (infop != NULL) {
    infop->fi_level = level + 1;
    infop->fi_lnum = first;
    infop->fi_low_level = low_level == 0 ? level + 1 : low_level;
  }
  return true;
}

/* foldLevel() {{{2 */
/*
 * Return fold level at line number "lnum" in the current window.
 */
int foldLevel(linenr_T lnum)
{
  /* While updating the folds lines between invalid_top and invalid_bot have
   * an undefined fold level.  Otherwise update the folds first. */
  if (invalid_top == (linenr_T)0)
    checkupdate(curwin);
  else if (lnum == prev_lnum && prev_lnum_lvl >= 0)
    return prev_lnum_lvl;
  else if (lnum >= invalid_top && lnum <= invalid_bot)
    return -1;

  /* Return quickly when there is no folding at all in this window. */
  if (!hasAnyFolding(curwin))
    return 0;

  return foldLevelWin(curwin, lnum);
}

/* lineFolded()	{{{2 */
/*
 * Low level function to check if a line is folded.  Doesn't use any caching.
 * Return TRUE if line is folded.
 * Return FALSE if line is not folded.
 * Return MAYBE if the line is folded when next to a folded line.
 */
int lineFolded(win_T *win, linenr_T lnum)
{
  return foldedCount(win, lnum, NULL) != 0;
}

/* foldedCount() {{{2 */
/*
 * Count the number of lines that are folded at line number "lnum".
 * Normally "lnum" is the first line of a possible fold, and the returned
 * number is the number of lines in the fold.
 * Doesn't use caching from the displayed window.
 * Returns number of folded lines from "lnum", or 0 if line is not folded.
 * When "infop" is not NULL, fills *infop with the fold level info.
 */
long foldedCount(win_T *win, linenr_T lnum, foldinfo_T *infop)
{
  linenr_T last;

  if (hasFoldingWin(win, lnum, NULL, &last, FALSE, infop))
    return (long)(last - lnum + 1);
  return 0;
}

/* foldmethodIsManual() {{{2 */
/*
 * Return TRUE if 'foldmethod' is "manual"
 */
int foldmethodIsManual(win_T *wp)
{
  return wp->w_p_fdm[3] == 'u';
}

/* foldmethodIsIndent() {{{2 */
/*
 * Return TRUE if 'foldmethod' is "indent"
 */
int foldmethodIsIndent(win_T *wp)
{
  return wp->w_p_fdm[0] == 'i';
}

/* foldmethodIsExpr() {{{2 */
/*
 * Return TRUE if 'foldmethod' is "expr"
 */
int foldmethodIsExpr(win_T *wp)
{
  return wp->w_p_fdm[1] == 'x';
}

/* foldmethodIsMarker() {{{2 */
/*
 * Return TRUE if 'foldmethod' is "marker"
 */
int foldmethodIsMarker(win_T *wp)
{
  return wp->w_p_fdm[2] == 'r';
}

/* foldmethodIsSyntax() {{{2 */
/*
 * Return TRUE if 'foldmethod' is "syntax"
 */
int foldmethodIsSyntax(win_T *wp)
{
  return wp->w_p_fdm[0] == 's';
}

/* foldmethodIsDiff() {{{2 */
/*
 * Return TRUE if 'foldmethod' is "diff"
 */
int foldmethodIsDiff(win_T *wp)
{
  return wp->w_p_fdm[0] == 'd';
}

/* closeFold() {{{2 */
/*
 * Close fold for current window at line "lnum".
 * Repeat "count" times.
 */
void closeFold(linenr_T lnum, long count)
{
  setFoldRepeat(lnum, count, FALSE);
}

/* closeFoldRecurse() {{{2 */
/*
 * Close fold for current window at line "lnum" recursively.
 */
void closeFoldRecurse(linenr_T lnum)
{
  (void)setManualFold(lnum, FALSE, TRUE, NULL);
}

/* opFoldRange() {{{2 */
/*
 * Open or Close folds for current window in lines "first" to "last".
 * Used for "zo", "zO", "zc" and "zC" in Visual mode.
 */
void 
opFoldRange (
    linenr_T first,
    linenr_T last,
    int opening,                    /* TRUE to open, FALSE to close */
    int recurse,                    /* TRUE to do it recursively */
    int had_visual                 /* TRUE when Visual selection used */
)
{
  int done = DONE_NOTHING;              /* avoid error messages */
  linenr_T lnum;
  linenr_T lnum_next;

  for (lnum = first; lnum <= last; lnum = lnum_next + 1) {
    lnum_next = lnum;
    /* Opening one level only: next fold to open is after the one going to
     * be opened. */
    if (opening && !recurse)
      (void)hasFolding(lnum, NULL, &lnum_next);
    (void)setManualFold(lnum, opening, recurse, &done);
    /* Closing one level only: next line to close a fold is after just
     * closed fold. */
    if (!opening && !recurse)
      (void)hasFolding(lnum, NULL, &lnum_next);
  }
  if (done == DONE_NOTHING)
    EMSG(_(e_nofold));
  /* Force a redraw to remove the Visual highlighting. */
  if (had_visual)
    redraw_curbuf_later(INVERTED);
}

/* openFold() {{{2 */
/*
 * Open fold for current window at line "lnum".
 * Repeat "count" times.
 */
void openFold(linenr_T lnum, long count)
{
  setFoldRepeat(lnum, count, TRUE);
}

/* openFoldRecurse() {{{2 */
/*
 * Open fold for current window at line "lnum" recursively.
 */
void openFoldRecurse(linenr_T lnum)
{
  (void)setManualFold(lnum, TRUE, TRUE, NULL);
}

/* foldOpenCursor() {{{2 */
/*
 * Open folds until the cursor line is not in a closed fold.
 */
void foldOpenCursor(void)
{
  int done;

  checkupdate(curwin);
  if (hasAnyFolding(curwin))
    for (;; ) {
      done = DONE_NOTHING;
      (void)setManualFold(curwin->w_cursor.lnum, TRUE, FALSE, &done);
      if (!(done & DONE_ACTION))
        break;
    }
}

/* newFoldLevel() {{{2 */
/*
 * Set new foldlevel for current window.
 */
void newFoldLevel(void)
{
  newFoldLevelWin(curwin);

  if (foldmethodIsDiff(curwin) && curwin->w_p_scb) {
    /*
     * Set the same foldlevel in other windows in diff mode.
     */
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
  fold_T      *fp;

  checkupdate(wp);
  if (wp->w_fold_manual) {
    /* Set all flags for the first level of folds to FD_LEVEL.  Following
     * manual open/close will then change the flags to FD_OPEN or
     * FD_CLOSED for those folds that don't use 'foldlevel'. */
    fp = (fold_T *)wp->w_folds.ga_data;
    for (int i = 0; i < wp->w_folds.ga_len; ++i)
      fp[i].fd_flags = FD_LEVEL;
    wp->w_fold_manual = false;
  }
  changed_window_setting_win(wp);
}

/* foldCheckClose() {{{2 */
/*
 * Apply 'foldlevel' to all folds that don't contain the cursor.
 */
void foldCheckClose(void)
{
  if (*p_fcl != NUL) {  /* can only be "all" right now */
    checkupdate(curwin);
    if (checkCloseRec(&curwin->w_folds, curwin->w_cursor.lnum,
            (int)curwin->w_p_fdl))
      changed_window_setting();
  }
}

/* checkCloseRec() {{{2 */
static int checkCloseRec(garray_T *gap, linenr_T lnum, int level)
{
  fold_T      *fp;
  int retval = FALSE;

  fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; ++i) {
    /* Only manually opened folds may need to be closed. */
    if (fp[i].fd_flags == FD_OPEN) {
      if (level <= 0 && (lnum < fp[i].fd_top
                         || lnum >= fp[i].fd_top + fp[i].fd_len)) {
        fp[i].fd_flags = FD_LEVEL;
        retval = TRUE;
      } else
        retval |= checkCloseRec(&fp[i].fd_nested, lnum - fp[i].fd_top,
            level - 1);
    }
  }
  return retval;
}

/* foldCreateAllowed() {{{2 */
/*
 * Return TRUE if it's allowed to manually create or delete a fold.
 * Give an error message and return FALSE if not.
 */
int foldManualAllowed(int create)
{
  if (foldmethodIsManual(curwin) || foldmethodIsMarker(curwin))
    return TRUE;
  if (create)
    EMSG(_("E350: Cannot create fold with current 'foldmethod'"));
  else
    EMSG(_("E351: Cannot delete fold with current 'foldmethod'"));
  return FALSE;
}

/* foldCreate() {{{2 */
/*
 * Create a fold from line "start" to line "end" (inclusive) in the current
 * window.
 */
void foldCreate(linenr_T start, linenr_T end)
{
  fold_T      *fp;
  garray_T    *gap;
  garray_T fold_ga;
  int i, j;
  int cont;
  int use_level = FALSE;
  int closed = FALSE;
  int level = 0;
  linenr_T start_rel = start;
  linenr_T end_rel = end;

  if (start > end) {
    /* reverse the range */
    end = start_rel;
    start = end_rel;
    start_rel = start;
    end_rel = end;
  }

  /* When 'foldmethod' is "marker" add markers, which creates the folds. */
  if (foldmethodIsMarker(curwin)) {
    foldCreateMarkers(start, end);
    return;
  }

  checkupdate(curwin);

  /* Find the place to insert the new fold. */
  gap = &curwin->w_folds;
  for (;; ) {
    if (!foldFind(gap, start_rel, &fp))
      break;
    if (fp->fd_top + fp->fd_len > end_rel) {
      /* New fold is completely inside this fold: Go one level deeper. */
      gap = &fp->fd_nested;
      start_rel -= fp->fd_top;
      end_rel -= fp->fd_top;
      if (use_level || fp->fd_flags == FD_LEVEL) {
        use_level = TRUE;
        if (level >= curwin->w_p_fdl)
          closed = TRUE;
      } else if (fp->fd_flags == FD_CLOSED)
        closed = TRUE;
      ++level;
    } else {
      /* This fold and new fold overlap: Insert here and move some folds
       * inside the new fold. */
      break;
    }
  }

  i = (int)(fp - (fold_T *)gap->ga_data);
  ga_grow(gap, 1);
  {
    fp = (fold_T *)gap->ga_data + i;
    ga_init(&fold_ga, (int)sizeof(fold_T), 10);

    /* Count number of folds that will be contained in the new fold. */
    for (cont = 0; i + cont < gap->ga_len; ++cont)
      if (fp[cont].fd_top > end_rel)
        break;
    if (cont > 0) {
      ga_grow(&fold_ga, cont);
      /* If the first fold starts before the new fold, let the new fold
       * start there.  Otherwise the existing fold would change. */
      if (start_rel > fp->fd_top)
        start_rel = fp->fd_top;

      /* When last contained fold isn't completely contained, adjust end
       * of new fold. */
      if (end_rel < fp[cont - 1].fd_top + fp[cont - 1].fd_len - 1)
        end_rel = fp[cont - 1].fd_top + fp[cont - 1].fd_len - 1;
      /* Move contained folds to inside new fold. */
      memmove(fold_ga.ga_data, fp, sizeof(fold_T) * (size_t)cont);
      fold_ga.ga_len += cont;
      i += cont;

      /* Adjust line numbers in contained folds to be relative to the
       * new fold. */
      for (j = 0; j < cont; ++j)
        ((fold_T *)fold_ga.ga_data)[j].fd_top -= start_rel;
    }
    /* Move remaining entries to after the new fold. */
    if (i < gap->ga_len)
      memmove(fp + 1, (fold_T *)gap->ga_data + i,
              sizeof(fold_T) * (size_t)(gap->ga_len - i));
    gap->ga_len = gap->ga_len + 1 - cont;

    /* insert new fold */
    fp->fd_nested = fold_ga;
    fp->fd_top = start_rel;
    fp->fd_len = end_rel - start_rel + 1;

    /* We want the new fold to be closed.  If it would remain open because
     * of using 'foldlevel', need to adjust fd_flags of containing folds.
     */
    if (use_level && !closed && level < curwin->w_p_fdl)
      closeFold(start, 1L);
    if (!use_level)
      curwin->w_fold_manual = true;
    fp->fd_flags = FD_CLOSED;
    fp->fd_small = MAYBE;

    /* redraw */
    changed_window_setting();
  }
}


/* deleteFold() {{{2 */
/*
 * Delete a fold at line "start" in the current window.
 * When "end" is not 0, delete all folds from "start" to "end".
 * When "recursive" is TRUE delete recursively.
 */
void 
deleteFold (
    linenr_T start,
    linenr_T end,
    int recursive,
    int had_visual                 /* TRUE when Visual selection used */
)
{
  garray_T    *gap;
  fold_T      *fp;
  garray_T    *found_ga;
  fold_T      *found_fp = NULL;
  linenr_T found_off = 0;
  int use_level;
  int maybe_small = FALSE;
  int level = 0;
  linenr_T lnum = start;
  linenr_T lnum_off;
  int did_one = FALSE;
  linenr_T first_lnum = MAXLNUM;
  linenr_T last_lnum = 0;

  checkupdate(curwin);

  while (lnum <= end) {
    /* Find the deepest fold for "start". */
    gap = &curwin->w_folds;
    found_ga = NULL;
    lnum_off = 0;
    use_level = FALSE;
    for (;; ) {
      if (!foldFind(gap, lnum - lnum_off, &fp))
        break;
      /* lnum is inside this fold, remember info */
      found_ga = gap;
      found_fp = fp;
      found_off = lnum_off;

      /* if "lnum" is folded, don't check nesting */
      if (check_closed(curwin, fp, &use_level, level,
              &maybe_small, lnum_off))
        break;

      /* check nested folds */
      gap = &fp->fd_nested;
      lnum_off += fp->fd_top;
      ++level;
    }
    if (found_ga == NULL) {
      ++lnum;
    } else {
      lnum = found_fp->fd_top + found_fp->fd_len + found_off;

      if (foldmethodIsManual(curwin))
        deleteFoldEntry(found_ga,
            (int)(found_fp - (fold_T *)found_ga->ga_data), recursive);
      else {
        if (first_lnum > found_fp->fd_top + found_off)
          first_lnum = found_fp->fd_top + found_off;
        if (last_lnum < lnum)
          last_lnum = lnum;
        if (!did_one)
          parseMarker(curwin);
        deleteFoldMarkers(found_fp, recursive, found_off);
      }
      did_one = TRUE;

      /* redraw window */
      changed_window_setting();
    }
  }
  if (!did_one) {
    EMSG(_(e_nofold));
    /* Force a redraw to remove the Visual highlighting. */
    if (had_visual)
      redraw_curbuf_later(INVERTED);
  } else
    /* Deleting markers may make cursor column invalid. */
    check_cursor_col();

  if (last_lnum > 0)
    changed_lines(first_lnum, (colnr_T)0, last_lnum, 0L);
}

/* clearFolding() {{{2 */
/*
 * Remove all folding for window "win".
 */
void clearFolding(win_T *win)
{
  deleteFoldRecurse(&win->w_folds);
  win->w_foldinvalid = false;
}

/* foldUpdate() {{{2 */
/*
 * Update folds for changes in the buffer of a window.
 * Note that inserted/deleted lines must have already been taken care of by
 * calling foldMarkAdjust().
 * The changes in lines from top to bot (inclusive).
 */
void foldUpdate(win_T *wp, linenr_T top, linenr_T bot)
{
  if (compl_busy || State & INSERT) {
    return;
  }

  // Mark all folds from top to bot as maybe-small.
  fold_T *fp;
  (void)foldFind(&wp->w_folds, top, &fp);
  while (fp < (fold_T *)wp->w_folds.ga_data + wp->w_folds.ga_len
         && fp->fd_top < bot) {
    fp->fd_small = MAYBE;
    ++fp;
  }

  if (foldmethodIsIndent(wp)
      || foldmethodIsExpr(wp)
      || foldmethodIsMarker(wp)
      || foldmethodIsDiff(wp)
      || foldmethodIsSyntax(wp)) {
    int save_got_int = got_int;

    /* reset got_int here, otherwise it won't work */
    got_int = FALSE;
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

/* foldUpdateAll() {{{2 */
/*
 * Update all lines in a window for folding.
 * Used when a fold setting changes or after reloading the buffer.
 * The actual updating is postponed until fold info is used, to avoid doing
 * every time a setting is changed or a syntax item is added.
 */
void foldUpdateAll(win_T *win)
{
  win->w_foldinvalid = true;
  redraw_win_later(win, NOT_VALID);
}

/* foldMoveTo() {{{2 */
/*
 * If "updown" is FALSE: Move to the start or end of the fold.
 * If "updown" is TRUE: move to fold at the same level.
 * If not moved return FAIL.
 */
int 
foldMoveTo (
    int updown,
    int dir,                    /* FORWARD or BACKWARD */
    long count
)
{
  long n;
  int retval = FAIL;
  linenr_T lnum_off;
  linenr_T lnum_found;
  linenr_T lnum;
  int use_level;
  int maybe_small;
  garray_T    *gap;
  fold_T      *fp;
  int level;
  int last;

  checkupdate(curwin);

  /* Repeat "count" times. */
  for (n = 0; n < count; ++n) {
    /* Find nested folds.  Stop when a fold is closed.  The deepest fold
     * that moves the cursor is used. */
    lnum_off = 0;
    gap = &curwin->w_folds;
    use_level = FALSE;
    maybe_small = FALSE;
    lnum_found = curwin->w_cursor.lnum;
    level = 0;
    last = FALSE;
    for (;; ) {
      if (!foldFind(gap, curwin->w_cursor.lnum - lnum_off, &fp)) {
        if (!updown)
          break;

        /* When moving up, consider a fold above the cursor; when
         * moving down consider a fold below the cursor. */
        if (dir == FORWARD) {
          if (fp - (fold_T *)gap->ga_data >= gap->ga_len)
            break;
          --fp;
        } else {
          if (fp == (fold_T *)gap->ga_data)
            break;
        }
        /* don't look for contained folds, they will always move
         * the cursor too far. */
        last = TRUE;
      }

      if (!last) {
        /* Check if this fold is closed. */
        if (check_closed(curwin, fp, &use_level, level,
                &maybe_small, lnum_off))
          last = TRUE;

        /* "[z" and "]z" stop at closed fold */
        if (last && !updown)
          break;
      }

      if (updown) {
        if (dir == FORWARD) {
          /* to start of next fold if there is one */
          if (fp + 1 - (fold_T *)gap->ga_data < gap->ga_len) {
            lnum = fp[1].fd_top + lnum_off;
            if (lnum > curwin->w_cursor.lnum)
              lnum_found = lnum;
          }
        } else {
          /* to end of previous fold if there is one */
          if (fp > (fold_T *)gap->ga_data) {
            lnum = fp[-1].fd_top + lnum_off + fp[-1].fd_len - 1;
            if (lnum < curwin->w_cursor.lnum)
              lnum_found = lnum;
          }
        }
      } else {
        /* Open fold found, set cursor to its start/end and then check
         * nested folds. */
        if (dir == FORWARD) {
          lnum = fp->fd_top + lnum_off + fp->fd_len - 1;
          if (lnum > curwin->w_cursor.lnum)
            lnum_found = lnum;
        } else {
          lnum = fp->fd_top + lnum_off;
          if (lnum < curwin->w_cursor.lnum)
            lnum_found = lnum;
        }
      }

      if (last)
        break;

      /* Check nested folds (if any). */
      gap = &fp->fd_nested;
      lnum_off += fp->fd_top;
      ++level;
    }
    if (lnum_found != curwin->w_cursor.lnum) {
      if (retval == FAIL)
        setpcmark();
      curwin->w_cursor.lnum = lnum_found;
      curwin->w_cursor.col = 0;
      retval = OK;
    } else
      break;
  }

  return retval;
}

/* foldInitWin() {{{2 */
/*
 * Init the fold info in a new window.
 */
void foldInitWin(win_T *new_win)
{
  ga_init(&new_win->w_folds, (int)sizeof(fold_T), 10);
}

/* find_wl_entry() {{{2 */
/*
 * Find an entry in the win->w_lines[] array for buffer line "lnum".
 * Only valid entries are considered (for entries where wl_valid is FALSE the
 * line number can be wrong).
 * Returns index of entry or -1 if not found.
 */
int find_wl_entry(win_T *win, linenr_T lnum)
{
  int i;

  for (i = 0; i < win->w_lines_valid; ++i)
    if (win->w_lines[i].wl_valid) {
      if (lnum < win->w_lines[i].wl_lnum)
        return -1;
      if (lnum <= win->w_lines[i].wl_lastlnum)
        return i;
    }
  return -1;
}

/* foldAdjustVisual() {{{2 */
/*
 * Adjust the Visual area to include any fold at the start or end completely.
 */
void foldAdjustVisual(void)
{
  pos_T       *start, *end;
  char_u      *ptr;

  if (!VIsual_active || !hasAnyFolding(curwin))
    return;

  if (ltoreq(VIsual, curwin->w_cursor)) {
    start = &VIsual;
    end = &curwin->w_cursor;
  } else {
    start = &curwin->w_cursor;
    end = &VIsual;
  }
  if (hasFolding(start->lnum, &start->lnum, NULL))
    start->col = 0;
  if (hasFolding(end->lnum, NULL, &end->lnum)) {
    ptr = ml_get(end->lnum);
    end->col = (colnr_T)STRLEN(ptr);
    if (end->col > 0 && *p_sel == 'o')
      --end->col;
    /* prevent cursor from moving on the trail byte */
    if (has_mbyte)
      mb_adjust_cursor();
  }
}

/* cursor_foldstart() {{{2 */
/*
 * Move the cursor to the first line of a closed fold.
 */
void foldAdjustCursor(void)
{
  (void)hasFolding(curwin->w_cursor.lnum, &curwin->w_cursor.lnum, NULL);
}

/* Internal functions for "fold_T" {{{1 */
/* cloneFoldGrowArray() {{{2 */
/*
 * Will "clone" (i.e deep copy) a garray_T of folds.
 */
void cloneFoldGrowArray(garray_T *from, garray_T *to)
{
  fold_T      *from_p;
  fold_T      *to_p;

  ga_init(to, from->ga_itemsize, from->ga_growsize);

  if (GA_EMPTY(from))
    return;

  ga_grow(to, from->ga_len);

  from_p = (fold_T *)from->ga_data;
  to_p = (fold_T *)to->ga_data;

  for (int i = 0; i < from->ga_len; i++) {
    to_p->fd_top = from_p->fd_top;
    to_p->fd_len = from_p->fd_len;
    to_p->fd_flags = from_p->fd_flags;
    to_p->fd_small = from_p->fd_small;
    cloneFoldGrowArray(&from_p->fd_nested, &to_p->fd_nested);
    ++to->ga_len;
    ++from_p;
    ++to_p;
  }
}

/* foldFind() {{{2 */
/*
 * Search for line "lnum" in folds of growarray "gap".
 * Set *fpp to the fold struct for the fold that contains "lnum" or
 * the first fold below it (careful: it can be beyond the end of the array!).
 * Returns FALSE when there is no fold that contains "lnum".
 */
static int foldFind(garray_T *gap, linenr_T lnum, fold_T **fpp)
{
  linenr_T low, high;
  fold_T      *fp;

  /*
   * Perform a binary search.
   * "low" is lowest index of possible match.
   * "high" is highest index of possible match.
   */
  fp = (fold_T *)gap->ga_data;
  low = 0;
  high = gap->ga_len - 1;
  while (low <= high) {
    linenr_T i = (low + high) / 2;
    if (fp[i].fd_top > lnum)
      /* fold below lnum, adjust high */
      high = i - 1;
    else if (fp[i].fd_top + fp[i].fd_len <= lnum)
      /* fold above lnum, adjust low */
      low = i + 1;
    else {
      /* lnum is inside this fold */
      *fpp = fp + i;
      return TRUE;
    }
  }
  *fpp = fp + low;
  return FALSE;
}

/* foldLevelWin() {{{2 */
/*
 * Return fold level at line number "lnum" in window "wp".
 */
static int foldLevelWin(win_T *wp, linenr_T lnum)
{
  fold_T      *fp;
  linenr_T lnum_rel = lnum;
  int level =  0;
  garray_T    *gap;

  /* Recursively search for a fold that contains "lnum". */
  gap = &wp->w_folds;
  for (;; ) {
    if (!foldFind(gap, lnum_rel, &fp))
      break;
    /* Check nested folds.  Line number is relative to containing fold. */
    gap = &fp->fd_nested;
    lnum_rel -= fp->fd_top;
    ++level;
  }

  return level;
}

/* checkupdate() {{{2 */
/*
 * Check if the folds in window "wp" are invalid and update them if needed.
 */
static void checkupdate(win_T *wp)
{
  if (wp->w_foldinvalid) {
    foldUpdate(wp, (linenr_T)1, (linenr_T)MAXLNUM);     /* will update all */
    wp->w_foldinvalid = false;
  }
}

/* setFoldRepeat() {{{2 */
/*
 * Open or close fold for current window at line "lnum".
 * Repeat "count" times.
 */
static void setFoldRepeat(linenr_T lnum, long count, int do_open)
{
  int done;
  long n;

  for (n = 0; n < count; ++n) {
    done = DONE_NOTHING;
    (void)setManualFold(lnum, do_open, FALSE, &done);
    if (!(done & DONE_ACTION)) {
      /* Only give an error message when no fold could be opened. */
      if (n == 0 && !(done & DONE_FOLD))
        EMSG(_(e_nofold));
      break;
    }
  }
}

/* setManualFold() {{{2 */
/*
 * Open or close the fold in the current window which contains "lnum".
 * Also does this for other windows in diff mode when needed.
 */
static linenr_T 
setManualFold (
    linenr_T lnum,
    int opening,                /* TRUE when opening, FALSE when closing */
    int recurse,                /* TRUE when closing/opening recursive */
    int *donep
)
{
  if (foldmethodIsDiff(curwin) && curwin->w_p_scb) {
    linenr_T dlnum;

    /*
     * Do the same operation in other windows in diff mode.  Calculate the
     * line number from the diffs.
     */
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp != curwin && foldmethodIsDiff(wp) && wp->w_p_scb) {
        dlnum = diff_lnum_win(curwin->w_cursor.lnum, wp);
        if (dlnum != 0) {
          (void)setManualFoldWin(wp, dlnum, opening, recurse, NULL);
        }
      }
    }
  }

  return setManualFoldWin(curwin, lnum, opening, recurse, donep);
}

/* setManualFoldWin() {{{2 */
/*
 * Open or close the fold in window "wp" which contains "lnum".
 * "donep", when not NULL, points to flag that is set to DONE_FOLD when some
 * fold was found and to DONE_ACTION when some fold was opened or closed.
 * When "donep" is NULL give an error message when no fold was found for
 * "lnum", but only if "wp" is "curwin".
 * Return the line number of the next line that could be closed.
 * It's only valid when "opening" is TRUE!
 */
static linenr_T 
setManualFoldWin (
    win_T *wp,
    linenr_T lnum,
    int opening,                /* TRUE when opening, FALSE when closing */
    int recurse,                /* TRUE when closing/opening recursive */
    int *donep
)
{
  fold_T      *fp;
  fold_T      *fp2;
  fold_T      *found = NULL;
  int j;
  int level = 0;
  int use_level = FALSE;
  int found_fold = FALSE;
  garray_T    *gap;
  linenr_T next = MAXLNUM;
  linenr_T off = 0;
  int done = 0;

  checkupdate(wp);

  /*
   * Find the fold, open or close it.
   */
  gap = &wp->w_folds;
  for (;; ) {
    if (!foldFind(gap, lnum, &fp)) {
      /* If there is a following fold, continue there next time. */
      if (fp < (fold_T *)gap->ga_data + gap->ga_len)
        next = fp->fd_top + off;
      break;
    }

    /* lnum is inside this fold */
    found_fold = TRUE;

    /* If there is a following fold, continue there next time. */
    if (fp + 1 < (fold_T *)gap->ga_data + gap->ga_len)
      next = fp[1].fd_top + off;

    /* Change from level-dependent folding to manual. */
    if (use_level || fp->fd_flags == FD_LEVEL) {
      use_level = TRUE;
      if (level >= wp->w_p_fdl)
        fp->fd_flags = FD_CLOSED;
      else
        fp->fd_flags = FD_OPEN;
      fp2 = (fold_T *)fp->fd_nested.ga_data;
      for (j = 0; j < fp->fd_nested.ga_len; ++j)
        fp2[j].fd_flags = FD_LEVEL;
    }

    /* Simple case: Close recursively means closing the fold. */
    if (!opening && recurse) {
      if (fp->fd_flags != FD_CLOSED) {
        done |= DONE_ACTION;
        fp->fd_flags = FD_CLOSED;
      }
    } else if (fp->fd_flags == FD_CLOSED) {
      /* When opening, open topmost closed fold. */
      if (opening) {
        fp->fd_flags = FD_OPEN;
        done |= DONE_ACTION;
        if (recurse)
          foldOpenNested(fp);
      }
      break;
    }

    /* fold is open, check nested folds */
    found = fp;
    gap = &fp->fd_nested;
    lnum -= fp->fd_top;
    off += fp->fd_top;
    ++level;
  }
  if (found_fold) {
    /* When closing and not recurse, close deepest open fold. */
    if (!opening && found != NULL) {
      found->fd_flags = FD_CLOSED;
      done |= DONE_ACTION;
    }
    wp->w_fold_manual = true;
    if (done & DONE_ACTION)
      changed_window_setting_win(wp);
    done |= DONE_FOLD;
  } else if (donep == NULL && wp == curwin)
    EMSG(_(e_nofold));

  if (donep != NULL)
    *donep |= done;

  return next;
}

/* foldOpenNested() {{{2 */
/*
 * Open all nested folds in fold "fpr" recursively.
 */
static void foldOpenNested(fold_T *fpr)
{
  fold_T      *fp;

  fp = (fold_T *)fpr->fd_nested.ga_data;
  for (int i = 0; i < fpr->fd_nested.ga_len; ++i) {
    foldOpenNested(&fp[i]);
    fp[i].fd_flags = FD_OPEN;
  }
}

/* deleteFoldEntry() {{{2 */
/*
 * Delete fold "idx" from growarray "gap".
 * When "recursive" is TRUE also delete all the folds contained in it.
 * When "recursive" is FALSE contained folds are moved one level up.
 */
static void deleteFoldEntry(garray_T *gap, int idx, int recursive)
{
  fold_T      *fp;
  int i;
  fold_T      *nfp;

  fp = (fold_T *)gap->ga_data + idx;
  if (recursive || GA_EMPTY(&fp->fd_nested)) {
    /* recursively delete the contained folds */
    deleteFoldRecurse(&fp->fd_nested);
    --gap->ga_len;
    if (idx < gap->ga_len)
      memmove(fp, fp + 1, sizeof(fold_T) * (size_t)(gap->ga_len - idx));
  } else {
    /* Move nested folds one level up, to overwrite the fold that is
     * deleted. */
    int moved = fp->fd_nested.ga_len;
    ga_grow(gap, moved - 1);
    {
      /* Get "fp" again, the array may have been reallocated. */
      fp = (fold_T *)gap->ga_data + idx;

      /* adjust fd_top and fd_flags for the moved folds */
      nfp = (fold_T *)fp->fd_nested.ga_data;
      for (i = 0; i < moved; ++i) {
        nfp[i].fd_top += fp->fd_top;
        if (fp->fd_flags == FD_LEVEL)
          nfp[i].fd_flags = FD_LEVEL;
        if (fp->fd_small == MAYBE)
          nfp[i].fd_small = MAYBE;
      }

      /* move the existing folds down to make room */
      if (idx + 1 < gap->ga_len)
        memmove(fp + moved, fp + 1,
                sizeof(fold_T) * (size_t)(gap->ga_len - (idx + 1)));
      /* move the contained folds one level up */
      memmove(fp, nfp, sizeof(fold_T) * (size_t)moved);
      xfree(nfp);
      gap->ga_len += moved - 1;
    }
  }
}

/* deleteFoldRecurse() {{{2 */
/*
 * Delete nested folds in a fold.
 */
void deleteFoldRecurse(garray_T *gap)
{
# define DELETE_FOLD_NESTED(fd) deleteFoldRecurse(&((fd)->fd_nested))
  GA_DEEP_CLEAR(gap, fold_T, DELETE_FOLD_NESTED);
}

/* foldMarkAdjust() {{{2 */
/*
 * Update line numbers of folds for inserted/deleted lines.
 */
void foldMarkAdjust(win_T *wp, linenr_T line1, linenr_T line2, long amount, long amount_after)
{
  /* If deleting marks from line1 to line2, but not deleting all those
   * lines, set line2 so that only deleted lines have their folds removed. */
  if (amount == MAXLNUM && line2 >= line1 && line2 - line1 >= -amount_after)
    line2 = line1 - amount_after - 1;
  /* If appending a line in Insert mode, it should be included in the fold
   * just above the line. */
  if ((State & INSERT) && amount == (linenr_T)1 && line2 == MAXLNUM)
    --line1;
  foldMarkAdjustRecurse(&wp->w_folds, line1, line2, amount, amount_after);
}

/* foldMarkAdjustRecurse() {{{2 */
static void foldMarkAdjustRecurse(garray_T *gap, linenr_T line1, linenr_T line2, long amount, long amount_after)
{
  fold_T      *fp;
  linenr_T last;
  linenr_T top;

  /* In Insert mode an inserted line at the top of a fold is considered part
   * of the fold, otherwise it isn't. */
  if ((State & INSERT) && amount == (linenr_T)1 && line2 == MAXLNUM)
    top = line1 + 1;
  else
    top = line1;

  /* Find the fold containing or just below "line1". */
  (void)foldFind(gap, line1, &fp);

  /*
   * Adjust all folds below "line1" that are affected.
   */
  for (int i = (int)(fp - (fold_T *)gap->ga_data); i < gap->ga_len; ++i, ++fp) {
    /*
     * Check for these situations:
     *	  1  2	3
     *	  1  2	3
     * line1     2	3  4  5
     *	     2	3  4  5
     *	     2	3  4  5
     * line2     2	3  4  5
     *		3     5  6
     *		3     5  6
     */

    last = fp->fd_top + fp->fd_len - 1;     /* last line of fold */

    /* 1. fold completely above line1: nothing to do */
    if (last < line1)
      continue;

    /* 6. fold below line2: only adjust for amount_after */
    if (fp->fd_top > line2) {
      if (amount_after == 0)
        break;
      fp->fd_top += amount_after;
    } else {
      if (fp->fd_top >= top && last <= line2) {
        /* 4. fold completely contained in range */
        if (amount == MAXLNUM) {
          /* Deleting lines: delete the fold completely */
          deleteFoldEntry(gap, i, TRUE);
          --i;              /* adjust index for deletion */
          --fp;
        } else
          fp->fd_top += amount;
      } else {
        if (fp->fd_top < top) {
          /* 2 or 3: need to correct nested folds too */
          foldMarkAdjustRecurse(&fp->fd_nested, line1 - fp->fd_top,
              line2 - fp->fd_top, amount, amount_after);
          if (last <= line2) {
            /* 2. fold contains line1, line2 is below fold */
            if (amount == MAXLNUM)
              fp->fd_len = line1 - fp->fd_top;
            else
              fp->fd_len += amount;
          } else {
            /* 3. fold contains line1 and line2 */
            fp->fd_len += amount_after;
          }
        } else {
          /* 5. fold is below line1 and contains line2; need to
           * correct nested folds too */
          if (amount == MAXLNUM) {
            foldMarkAdjustRecurse(&fp->fd_nested, line1 - fp->fd_top,
                                  line2 - fp->fd_top, amount,
                                  amount_after + (fp->fd_top - top));
            fp->fd_len -= line2 - fp->fd_top + 1;
            fp->fd_top = line1;
          } else {
            foldMarkAdjustRecurse(&fp->fd_nested, line1 - fp->fd_top,
                                  line2 - fp->fd_top, amount,
                                  amount_after - amount);
            fp->fd_len += amount_after - amount;
            fp->fd_top += amount;
          }
        }
      }
    }
  }
}

/* getDeepestNesting() {{{2 */
/*
 * Get the lowest 'foldlevel' value that makes the deepest nested fold in the
 * current window open.
 */
int getDeepestNesting(void)
{
  checkupdate(curwin);
  return getDeepestNestingRecurse(&curwin->w_folds);
}

static int getDeepestNestingRecurse(garray_T *gap)
{
  int level;
  int maxlevel = 0;
  fold_T      *fp;

  fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; ++i) {
    level = getDeepestNestingRecurse(&fp[i].fd_nested) + 1;
    if (level > maxlevel)
      maxlevel = level;
  }

  return maxlevel;
}

/* check_closed() {{{2 */
/*
 * Check if a fold is closed and update the info needed to check nested folds.
 */
static int 
check_closed (
    win_T *win,
    fold_T *fp,
    int *use_levelp,            /* TRUE: outer fold had FD_LEVEL */
    int level,                          /* folding depth */
    int *maybe_smallp,          /* TRUE: outer this had fd_small == MAYBE */
    linenr_T lnum_off                  /* line number offset for fp->fd_top */
)
{
  int closed = FALSE;

  /* Check if this fold is closed.  If the flag is FD_LEVEL this
   * fold and all folds it contains depend on 'foldlevel'. */
  if (*use_levelp || fp->fd_flags == FD_LEVEL) {
    *use_levelp = TRUE;
    if (level >= win->w_p_fdl)
      closed = TRUE;
  } else if (fp->fd_flags == FD_CLOSED)
    closed = TRUE;

  /* Small fold isn't closed anyway. */
  if (fp->fd_small == MAYBE)
    *maybe_smallp = TRUE;
  if (closed) {
    if (*maybe_smallp)
      fp->fd_small = MAYBE;
    checkSmall(win, fp, lnum_off);
    if (fp->fd_small == TRUE)
      closed = FALSE;
  }
  return closed;
}

/* checkSmall() {{{2 */
/*
 * Update fd_small field of fold "fp".
 */
static void 
checkSmall (
    win_T *wp,
    fold_T *fp,
    linenr_T lnum_off              /* offset for fp->fd_top */
)
{
  int count;
  int n;

  if (fp->fd_small == MAYBE) {
    /* Mark any nested folds to maybe-small */
    setSmallMaybe(&fp->fd_nested);

    if (fp->fd_len > curwin->w_p_fml)
      fp->fd_small = FALSE;
    else {
      count = 0;
      for (n = 0; n < fp->fd_len; ++n) {
        count += plines_win_nofold(wp, fp->fd_top + lnum_off + n);
        if (count > curwin->w_p_fml) {
          fp->fd_small = FALSE;
          return;
        }
      }
      fp->fd_small = TRUE;
    }
  }
}

/* setSmallMaybe() {{{2 */
/*
 * Set small flags in "gap" to MAYBE.
 */
static void setSmallMaybe(garray_T *gap)
{
  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; ++i) {
    fp[i].fd_small = MAYBE;
  }
}

/* foldCreateMarkers() {{{2 */
/*
 * Create a fold from line "start" to line "end" (inclusive) in the current
 * window by adding markers.
 */
static void foldCreateMarkers(linenr_T start, linenr_T end)
{
  if (!MODIFIABLE(curbuf)) {
    EMSG(_(e_modifiable));
    return;
  }
  parseMarker(curwin);

  foldAddMarker(start, curwin->w_p_fmr, foldstartmarkerlen);
  foldAddMarker(end, foldendmarker, foldendmarkerlen);

  /* Update both changes here, to avoid all folds after the start are
   * changed when the start marker is inserted and the end isn't. */
  changed_lines(start, (colnr_T)0, end, 0L);
}

/* foldAddMarker() {{{2 */
/*
 * Add "marker[markerlen]" in 'commentstring' to line "lnum".
 */
static void foldAddMarker(linenr_T lnum, const char_u *marker, size_t markerlen)
{
  char_u      *cms = curbuf->b_p_cms;
  char_u      *line;
  char_u      *newline;
  char_u      *p = (char_u *)strstr((char *)curbuf->b_p_cms, "%s");
  bool line_is_comment = false;

  // Allocate a new line: old-line + 'cms'-start + marker + 'cms'-end
  line = ml_get(lnum);
  size_t line_len = STRLEN(line);

  if (u_save(lnum - 1, lnum + 1) == OK) {
    // Check if the line ends with an unclosed comment
    skip_comment(line, false, false, &line_is_comment);
    newline = xmalloc(line_len + markerlen + STRLEN(cms) + 1);
    STRCPY(newline, line);
    // Append the marker to the end of the line
    if (p == NULL || line_is_comment) {
      STRLCPY(newline + line_len, marker, markerlen + 1);
    } else {
      STRCPY(newline + line_len, cms);
      memcpy(newline + line_len + (p - cms), marker, markerlen);
      STRCPY(newline + line_len + (p - cms) + markerlen, p + 2);
    }
    ml_replace(lnum, newline, false);
  }
}

/* deleteFoldMarkers() {{{2 */
/*
 * Delete the markers for a fold, causing it to be deleted.
 */
static void 
deleteFoldMarkers (
    fold_T *fp,
    int recursive,
    linenr_T lnum_off              /* offset for fp->fd_top */
)
{
  if (recursive) {
    for (int i = 0; i < fp->fd_nested.ga_len; ++i) {
      deleteFoldMarkers((fold_T *)fp->fd_nested.ga_data + i, TRUE,
                        lnum_off + fp->fd_top);
    }
  }
  foldDelMarker(fp->fd_top + lnum_off, curwin->w_p_fmr, foldstartmarkerlen);
  foldDelMarker(fp->fd_top + lnum_off + fp->fd_len - 1, foldendmarker,
                foldendmarkerlen);
}

/* foldDelMarker() {{{2 */
/*
 * Delete marker "marker[markerlen]" at the end of line "lnum".
 * Delete 'commentstring' if it matches.
 * If the marker is not found, there is no error message.  Could a missing
 * close-marker.
 */
static void foldDelMarker(linenr_T lnum, char_u *marker, size_t markerlen)
{
  char_u      *newline;
  char_u      *cms = curbuf->b_p_cms;
  char_u      *cms2;

  char_u *line = ml_get(lnum);
  for (char_u *p = line; *p != NUL; ++p) {
    if (STRNCMP(p, marker, markerlen) != 0) {
      continue;
    }
    /* Found the marker, include a digit if it's there. */
    size_t len = markerlen;
    if (ascii_isdigit(p[len]))
      ++len;
    if (*cms != NUL) {
      /* Also delete 'commentstring' if it matches. */
      cms2 = (char_u *)strstr((char *)cms, "%s");
      if (p - line >= cms2 - cms
          && STRNCMP(p - (cms2 - cms), cms, cms2 - cms) == 0
          && STRNCMP(p + len, cms2 + 2, STRLEN(cms2 + 2)) == 0) {
        p -= cms2 - cms;
        len += STRLEN(cms) - 2;
      }
    }
    if (u_save(lnum - 1, lnum + 1) == OK) {
      /* Make new line: text-before-marker + text-after-marker */
      newline = xmalloc(STRLEN(line) - len + 1);
      assert(p >= line);
      memcpy(newline, line, (size_t)(p - line));
      STRCPY(newline + (p - line), p + len);
      ml_replace(lnum, newline, FALSE);
    }
    break;
  }
}

// get_foldtext() {{{2
/// Return the text for a closed fold at line "lnum", with last line "lnume".
/// When 'foldtext' isn't set puts the result in "buf[FOLD_TEXT_LEN]".
/// Otherwise the result is in allocated memory.
char_u *get_foldtext(win_T *wp, linenr_T lnum, linenr_T lnume,
                     foldinfo_T *foldinfo, char_u *buf)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char_u      *text = NULL;
  /* an error occurred when evaluating 'fdt' setting */
  static int got_fdt_error = FALSE;
  int save_did_emsg = did_emsg;
  static win_T    *last_wp = NULL;
  static linenr_T last_lnum = 0;

  if (last_wp == NULL || last_wp != wp || last_lnum > lnum || last_lnum == 0)
    /* window changed, try evaluating foldtext setting once again */
    got_fdt_error = FALSE;

  if (!got_fdt_error)
    /* a previous error should not abort evaluating 'foldexpr' */
    did_emsg = FALSE;

  if (*wp->w_p_fdt != NUL) {
    char dashes[MAX_LEVEL + 2];
    win_T   *save_curwin;
    int level;
    char_u  *p;

    // Set "v:foldstart" and "v:foldend".
    set_vim_var_nr(VV_FOLDSTART, (varnumber_T) lnum);
    set_vim_var_nr(VV_FOLDEND, (varnumber_T) lnume);

    /* Set "v:folddashes" to a string of "level" dashes. */
    /* Set "v:foldlevel" to "level". */
    level = foldinfo->fi_level;
    if (level > (int)sizeof(dashes) - 1)
      level = (int)sizeof(dashes) - 1;
    memset(dashes, '-', (size_t)level);
    dashes[level] = NUL;
    set_vim_var_string(VV_FOLDDASHES, dashes, -1);
    set_vim_var_nr(VV_FOLDLEVEL, (varnumber_T) level);

    /* skip evaluating foldtext on errors */
    if (!got_fdt_error) {
      save_curwin = curwin;
      curwin = wp;
      curbuf = wp->w_buffer;

      ++emsg_silent;       /* handle exceptions, but don't display errors */
      text = eval_to_string_safe(wp->w_p_fdt, NULL,
          was_set_insecurely((char_u *)"foldtext", OPT_LOCAL));
      --emsg_silent;

      if (text == NULL || did_emsg)
        got_fdt_error = TRUE;

      curwin = save_curwin;
      curbuf = curwin->w_buffer;
    }
    last_lnum = lnum;
    last_wp   = wp;
    set_vim_var_string(VV_FOLDDASHES, NULL, -1);

    if (!did_emsg && save_did_emsg)
      did_emsg = save_did_emsg;

    if (text != NULL) {
      /* Replace unprintable characters, if there are any.  But
       * replace a TAB with a space. */
      for (p = text; *p != NUL; ++p) {
        int len;

        if (has_mbyte && (len = (*mb_ptr2len)(p)) > 1) {
          if (!vim_isprintc((*mb_ptr2char)(p)))
            break;
          p += len - 1;
        } else if (*p == TAB)
          *p = ' ';
        else if (ptr2cells(p) > 1)
          break;
      }
      if (*p != NUL) {
        p = (char_u *)transstr((const char *)text);
        xfree(text);
        text = p;
      }
    }
  }
  if (text == NULL) {
    unsigned long count = (unsigned long)(lnume - lnum + 1);

    vim_snprintf((char *)buf, FOLD_TEXT_LEN,
                 ngettext("+--%3ld line folded",
                          "+--%3ld lines folded ", count),
                 count);
    text = buf;
  }
  return text;
}

/* foldtext_cleanup() {{{2 */
/*
 * Remove 'foldmarker' and 'commentstring' from "str" (in-place).
 */
void foldtext_cleanup(char_u *str)
{
  char_u      *s;
  char_u      *p;
  int did1 = FALSE;
  int did2 = FALSE;

  /* Ignore leading and trailing white space in 'commentstring'. */
  char_u *cms_start = skipwhite(curbuf->b_p_cms);
  size_t cms_slen = STRLEN(cms_start);
  while (cms_slen > 0 && ascii_iswhite(cms_start[cms_slen - 1]))
    --cms_slen;

  /* locate "%s" in 'commentstring', use the part before and after it. */
  char_u *cms_end = (char_u *)strstr((char *)cms_start, "%s");
  size_t cms_elen = 0;
  if (cms_end != NULL) {
    cms_elen = cms_slen - (size_t)(cms_end - cms_start);
    cms_slen = (size_t)(cms_end - cms_start);

    /* exclude white space before "%s" */
    while (cms_slen > 0 && ascii_iswhite(cms_start[cms_slen - 1]))
      --cms_slen;

    /* skip "%s" and white space after it */
    s = skipwhite(cms_end + 2);
    cms_elen -= (size_t)(s - cms_end);
    cms_end = s;
  }
  parseMarker(curwin);

  for (s = str; *s != NUL; ) {
    size_t len = 0;
    if (STRNCMP(s, curwin->w_p_fmr, foldstartmarkerlen) == 0)
      len = foldstartmarkerlen;
    else if (STRNCMP(s, foldendmarker, foldendmarkerlen) == 0)
      len = foldendmarkerlen;
    if (len > 0) {
      if (ascii_isdigit(s[len]))
        ++len;

      /* May remove 'commentstring' start.  Useful when it's a double
       * quote and we already removed a double quote. */
      for (p = s; p > str && ascii_iswhite(p[-1]); --p)
        ;
      if (p >= str + cms_slen
          && STRNCMP(p - cms_slen, cms_start, cms_slen) == 0) {
        len += (size_t)(s - p) + cms_slen;
        s = p - cms_slen;
      }
    } else if (cms_end != NULL) {
      if (!did1 && cms_slen > 0 && STRNCMP(s, cms_start, cms_slen) == 0) {
        len = cms_slen;
        did1 = TRUE;
      } else if (!did2 && cms_elen > 0
                 && STRNCMP(s, cms_end, cms_elen) == 0) {
        len = cms_elen;
        did2 = TRUE;
      }
    }
    if (len != 0) {
      while (ascii_iswhite(s[len]))
        ++len;
      STRMOVE(s, s + len);
    } else {
      mb_ptr_adv(s);
    }
  }
}

/* Folding by indent, expr, marker and syntax. {{{1 */
/* Function declarations. {{{2 */

/* foldUpdateIEMS() {{{2 */
/*
 * Update the folding for window "wp", at least from lines "top" to "bot".
 * Return TRUE if any folds did change.
 */
static void foldUpdateIEMS(win_T *wp, linenr_T top, linenr_T bot)
{
  linenr_T start;
  linenr_T end;
  fline_T fline;
  void        (*getlevel)(fline_T *);
  int level;
  fold_T      *fp;

  /* Avoid problems when being called recursively. */
  if (invalid_top != (linenr_T)0)
    return;

  if (wp->w_foldinvalid) {
    /* Need to update all folds. */
    top = 1;
    bot = wp->w_buffer->b_ml.ml_line_count;
    wp->w_foldinvalid = false;

    /* Mark all folds a maybe-small. */
    setSmallMaybe(&wp->w_folds);
  }

  /* add the context for "diff" folding */
  if (foldmethodIsDiff(wp)) {
    if (top > diff_context)
      top -= diff_context;
    else
      top = 1;
    bot += diff_context;
  }

  /* When deleting lines at the end of the buffer "top" can be past the end
   * of the buffer. */
  if (top > wp->w_buffer->b_ml.ml_line_count)
    top = wp->w_buffer->b_ml.ml_line_count;

  fold_changed = FALSE;
  fline.wp = wp;
  fline.off = 0;
  fline.lvl = 0;
  fline.lvl_next = -1;
  fline.start = 0;
  fline.end = MAX_LEVEL + 1;
  fline.had_end = MAX_LEVEL + 1;

  invalid_top = top;
  invalid_bot = bot;

  if (foldmethodIsMarker(wp)) {
    getlevel = foldlevelMarker;

    /* Init marker variables to speed up foldlevelMarker(). */
    parseMarker(wp);

    /* Need to get the level of the line above top, it is used if there is
     * no marker at the top. */
    if (top > 1) {
      /* Get the fold level at top - 1. */
      level = foldLevelWin(wp, top - 1);

      /* The fold may end just above the top, check for that. */
      fline.lnum = top - 1;
      fline.lvl = level;
      getlevel(&fline);

      /* If a fold started here, we already had the level, if it stops
       * here, we need to use lvl_next.  Could also start and end a fold
       * in the same line. */
      if (fline.lvl > level)
        fline.lvl = level - (fline.lvl - fline.lvl_next);
      else
        fline.lvl = fline.lvl_next;
    }
    fline.lnum = top;
    getlevel(&fline);
  } else {
    fline.lnum = top;
    if (foldmethodIsExpr(wp)) {
      getlevel = foldlevelExpr;
      /* start one line back, because a "<1" may indicate the end of a
       * fold in the topline */
      if (top > 1)
        --fline.lnum;
    } else if (foldmethodIsSyntax(wp))
      getlevel = foldlevelSyntax;
    else if (foldmethodIsDiff(wp))
      getlevel = foldlevelDiff;
    else
      getlevel = foldlevelIndent;

    /* Backup to a line for which the fold level is defined.  Since it's
     * always defined for line one, we will stop there. */
    fline.lvl = -1;
    for (; !got_int; --fline.lnum) {
      /* Reset lvl_next each time, because it will be set to a value for
       * the next line, but we search backwards here. */
      fline.lvl_next = -1;
      getlevel(&fline);
      if (fline.lvl >= 0)
        break;
    }
  }

  /*
   * If folding is defined by the syntax, it is possible that a change in
   * one line will cause all sub-folds of the current fold to change (e.g.,
   * closing a C-style comment can cause folds in the subsequent lines to
   * appear). To take that into account we should adjust the value of "bot"
   * to point to the end of the current fold:
   */
  if (foldlevelSyntax == getlevel) {
    garray_T *gap = &wp->w_folds;
    fold_T   *fpn = NULL;
    int current_fdl = 0;
    linenr_T fold_start_lnum = 0;
    linenr_T lnum_rel = fline.lnum;

    while (current_fdl < fline.lvl) {
      if (!foldFind(gap, lnum_rel, &fpn))
        break;
      ++current_fdl;

      fold_start_lnum += fpn->fd_top;
      gap = &fpn->fd_nested;
      lnum_rel -= fpn->fd_top;
    }
    if (fpn != NULL && current_fdl == fline.lvl) {
      linenr_T fold_end_lnum = fold_start_lnum + fpn->fd_len;

      if (fold_end_lnum > bot)
        bot = fold_end_lnum;
    }
  }

  start = fline.lnum;
  end = bot;
  /* Do at least one line. */
  if (start > end && end < wp->w_buffer->b_ml.ml_line_count)
    end = start;
  while (!got_int) {
    /* Always stop at the end of the file ("end" can be past the end of
     * the file). */
    if (fline.lnum > wp->w_buffer->b_ml.ml_line_count)
      break;
    if (fline.lnum > end) {
      /* For "marker", "expr"  and "syntax"  methods: If a change caused
       * a fold to be removed, we need to continue at least until where
       * it ended. */
      if (getlevel != foldlevelMarker
          && getlevel != foldlevelSyntax
          && getlevel != foldlevelExpr)
        break;
      if ((start <= end
           && foldFind(&wp->w_folds, end, &fp)
           && fp->fd_top + fp->fd_len - 1 > end)
          || (fline.lvl == 0
              && foldFind(&wp->w_folds, fline.lnum, &fp)
              && fp->fd_top < fline.lnum))
        end = fp->fd_top + fp->fd_len - 1;
      else if (getlevel == foldlevelSyntax
               && foldLevelWin(wp, fline.lnum) != fline.lvl)
        /* For "syntax" method: Compare the foldlevel that the syntax
         * tells us to the foldlevel from the existing folds.  If they
         * don't match continue updating folds. */
        end = fline.lnum;
      else
        break;
    }

    /* A level 1 fold starts at a line with foldlevel > 0. */
    if (fline.lvl > 0) {
      invalid_top = fline.lnum;
      invalid_bot = end;
      end = foldUpdateIEMSRecurse(&wp->w_folds, 1, start, &fline, getlevel, end,
                                  FD_LEVEL);
      start = fline.lnum;
    } else {
      if (fline.lnum == wp->w_buffer->b_ml.ml_line_count)
        break;
      ++fline.lnum;
      fline.lvl = fline.lvl_next;
      getlevel(&fline);
    }
  }

  /* There can't be any folds from start until end now. */
  foldRemove(&wp->w_folds, start, end);

  /* If some fold changed, need to redraw and position cursor. */
  if (fold_changed && wp->w_p_fen)
    changed_window_setting_win(wp);

  /* If we updated folds past "bot", need to redraw more lines.  Don't do
   * this in other situations, the changed lines will be redrawn anyway and
   * this method can cause the whole window to be updated. */
  if (end != bot) {
    if (wp->w_redraw_top == 0 || wp->w_redraw_top > top)
      wp->w_redraw_top = top;
    if (wp->w_redraw_bot < end)
      wp->w_redraw_bot = end;
  }

  invalid_top = (linenr_T)0;
}

/* foldUpdateIEMSRecurse() {{{2 */
/*
 * Update a fold that starts at "flp->lnum".  At this line there is always a
 * valid foldlevel, and its level >= "level".
 * "flp" is valid for "flp->lnum" when called and it's valid when returning.
 * "flp->lnum" is set to the lnum just below the fold, if it ends before
 * "bot", it's "bot" plus one if the fold continues and it's bigger when using
 * the marker method and a text change made following folds to change.
 * When returning, "flp->lnum_save" is the line number that was used to get
 * the level when the level at "flp->lnum" is invalid.
 * Remove any folds from "startlnum" up to here at this level.
 * Recursively update nested folds.
 * Below line "bot" there are no changes in the text.
 * "flp->lnum", "flp->lnum_save" and "bot" are relative to the start of the
 * outer fold.
 * "flp->off" is the offset to the real line number in the buffer.
 *
 * All this would be a lot simpler if all folds in the range would be deleted
 * and then created again.  But we would lose all information about the
 * folds, even when making changes that don't affect the folding (e.g. "vj~").
 *
 * Returns bot, which may have been increased for lines that also need to be
 * updated as a result of a detected change in the fold.
 */
static linenr_T foldUpdateIEMSRecurse(garray_T *gap, int level,
                                      linenr_T startlnum, fline_T *flp,
                                      LevelGetter getlevel,
                                      linenr_T bot,
                                      char topflags /* containing fold flags */
                                      )
{
  linenr_T ll;
  fold_T      *fp = NULL;
  fold_T      *fp2;
  int lvl = level;
  linenr_T startlnum2 = startlnum;
  linenr_T firstlnum = flp->lnum;       /* first lnum we got */
  int i;
  int finish = FALSE;
  linenr_T linecount = flp->wp->w_buffer->b_ml.ml_line_count - flp->off;
  int concat;

  /*
   * If using the marker method, the start line is not the start of a fold
   * at the level we're dealing with and the level is non-zero, we must use
   * the previous fold.  But ignore a fold that starts at or below
   * startlnum, it must be deleted.
   */
  if (getlevel == foldlevelMarker && flp->start <= flp->lvl - level
      && flp->lvl > 0) {
    (void)foldFind(gap, startlnum - 1, &fp);
    if (fp >= ((fold_T *)gap->ga_data) + gap->ga_len
        || fp->fd_top >= startlnum) {
      fp = NULL;
    }
  }

  /*
   * Loop over all lines in this fold, or until "bot" is hit.
   * Handle nested folds inside of this fold.
   * "flp->lnum" is the current line.  When finding the end of the fold, it
   * is just below the end of the fold.
   * "*flp" contains the level of the line "flp->lnum" or a following one if
   * there are lines with an invalid fold level.  "flp->lnum_save" is the
   * line number that was used to get the fold level (below "flp->lnum" when
   * it has an invalid fold level).  When called the fold level is always
   * valid, thus "flp->lnum_save" is equal to "flp->lnum".
   */
  flp->lnum_save = flp->lnum;
  while (!got_int) {
    /* Updating folds can be slow, check for CTRL-C. */
    line_breakcheck();

    /* Set "lvl" to the level of line "flp->lnum".  When flp->start is set
     * and after the first line of the fold, set the level to zero to
     * force the fold to end.  Do the same when had_end is set: Previous
     * line was marked as end of a fold. */
    lvl = flp->lvl;
    if (lvl > MAX_LEVEL)
      lvl = MAX_LEVEL;
    if (flp->lnum > firstlnum
        && (level > lvl - flp->start || level >= flp->had_end))
      lvl = 0;

    if (flp->lnum > bot && !finish && fp != NULL) {
      /* For "marker" and "syntax" methods:
       * - If a change caused a nested fold to be removed, we need to
       *   delete it and continue at least until where it ended.
       * - If a change caused a nested fold to be created, or this fold
       *   to continue below its original end, need to finish this fold.
       */
      if (getlevel != foldlevelMarker
          && getlevel != foldlevelExpr
          && getlevel != foldlevelSyntax)
        break;
      i = 0;
      fp2 = fp;
      if (lvl >= level) {
        /* Compute how deep the folds currently are, if it's deeper
         * than "lvl" then some must be deleted, need to update
         * at least one nested fold. */
        ll = flp->lnum - fp->fd_top;
        while (foldFind(&fp2->fd_nested, ll, &fp2)) {
          ++i;
          ll -= fp2->fd_top;
        }
      }
      if (lvl < level + i) {
        (void)foldFind(&fp->fd_nested, flp->lnum - fp->fd_top, &fp2);
        if (fp2 != NULL) {
          bot = fp2->fd_top + fp2->fd_len - 1 + fp->fd_top;
        }
      } else if (fp->fd_top + fp->fd_len <= flp->lnum && lvl >= level) {
        finish = true;
      } else {
        break;
      }
    }

    /* At the start of the first nested fold and at the end of the current
     * fold: check if existing folds at this level, before the current
     * one, need to be deleted or truncated. */
    if (fp == NULL
        && (lvl != level
            || flp->lnum_save >= bot
            || flp->start != 0
            || flp->had_end <= MAX_LEVEL
            || flp->lnum == linecount)) {
      /*
       * Remove or update folds that have lines between startlnum and
       * firstlnum.
       */
      while (!got_int) {
        /* set concat to 1 if it's allowed to concatenated this fold
         * with a previous one that touches it. */
        if (flp->start != 0 || flp->had_end <= MAX_LEVEL)
          concat = 0;
        else
          concat = 1;

        /* Find an existing fold to re-use.  Preferably one that
         * includes startlnum, otherwise one that ends just before
         * startlnum or starts after it. */
        if (foldFind(gap, startlnum, &fp)
            || (fp < ((fold_T *)gap->ga_data) + gap->ga_len
                && fp->fd_top <= firstlnum)
            || foldFind(gap, firstlnum - concat, &fp)
            || (fp < ((fold_T *)gap->ga_data) + gap->ga_len
                && ((lvl < level && fp->fd_top < flp->lnum)
                    || (lvl >= level
                        && fp->fd_top <= flp->lnum_save)))) {
          if (fp->fd_top + fp->fd_len + concat > firstlnum) {
            /* Use existing fold for the new fold.  If it starts
             * before where we started looking, extend it.  If it
             * starts at another line, update nested folds to keep
             * their position, compensating for the new fd_top. */
            if (fp->fd_top == firstlnum) {
              // We have found a fold beginning exactly where we want one.
            } else if (fp->fd_top >= startlnum) {
              if (fp->fd_top > firstlnum) {
                // We will move the start of this fold up, hence we move all
                // nested folds (with relative line numbers) down.
                foldMarkAdjustRecurse(&fp->fd_nested,
                                      (linenr_T)0, (linenr_T)MAXLNUM,
                                      (long)(fp->fd_top - firstlnum), 0L);
              } else {
                // Will move fold down, move nested folds relatively up.
                foldMarkAdjustRecurse(&fp->fd_nested,
                                      (linenr_T)0,
                                      (long)(firstlnum - fp->fd_top - 1),
                                      (linenr_T)MAXLNUM,
                                      (long)(fp->fd_top - firstlnum));
              }
              fp->fd_len += fp->fd_top - firstlnum;
              fp->fd_top = firstlnum;
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
              foldRemove(&fp->fd_nested, breakstart - fp->fd_top,
                         breakend - fp->fd_top);
              i = (int)(fp - (fold_T *)gap->ga_data);
              foldSplit(gap, i, breakstart, breakend - 1);
              fp = (fold_T *)gap->ga_data + i + 1;
              /* If using the "marker" or "syntax" method, we
               * need to continue until the end of the fold is
               * found. */
              if (getlevel == foldlevelMarker
                  || getlevel == foldlevelExpr
                  || getlevel == foldlevelSyntax)
                finish = TRUE;
            }
            if (fp->fd_top == startlnum && concat) {
              i = (int)(fp - (fold_T *)gap->ga_data);
              if (i != 0) {
                fp2 = fp - 1;
                if (fp2->fd_top + fp2->fd_len == fp->fd_top) {
                  foldMerge(fp2, gap, fp);
                  fp = fp2;
                }
              }
            }
            break;
          }
          if (fp->fd_top >= startlnum) {
            /* A fold that starts at or after startlnum and stops
             * before the new fold must be deleted.  Continue
             * looking for the next one. */
            deleteFoldEntry(gap,
                (int)(fp - (fold_T *)gap->ga_data), TRUE);
          } else {
            /* A fold has some lines above startlnum, truncate it
             * to stop just above startlnum.  */
            fp->fd_len = startlnum - fp->fd_top;
            foldMarkAdjustRecurse(&fp->fd_nested,
                (linenr_T)fp->fd_len, (linenr_T)MAXLNUM,
                (linenr_T)MAXLNUM, 0L);
            fold_changed = TRUE;
          }
        } else {
          /* Insert new fold.  Careful: ga_data may be NULL and it
           * may change! */
          i = (int)(fp - (fold_T *)gap->ga_data);
          foldInsert(gap, i);
          fp = (fold_T *)gap->ga_data + i;
          /* The new fold continues until bot, unless we find the
           * end earlier. */
          fp->fd_top = firstlnum;
          fp->fd_len = bot - firstlnum + 1;
          /* When the containing fold is open, the new fold is open.
           * The new fold is closed if the fold above it is closed.
           * The first fold depends on the containing fold. */
          if (topflags == FD_OPEN) {
            flp->wp->w_fold_manual = true;
            fp->fd_flags = FD_OPEN;
          } else if (i <= 0) {
            fp->fd_flags = topflags;
            if (topflags != FD_LEVEL)
              flp->wp->w_fold_manual = true;
          } else
            fp->fd_flags = (fp - 1)->fd_flags;
          fp->fd_small = MAYBE;
          /* If using the "marker", "expr" or "syntax" method, we
           * need to continue until the end of the fold is found. */
          if (getlevel == foldlevelMarker
              || getlevel == foldlevelExpr
              || getlevel == foldlevelSyntax)
            finish = TRUE;
          fold_changed = TRUE;
          break;
        }
      }
    }

    if (lvl < level || flp->lnum > linecount) {
      /*
       * Found a line with a lower foldlevel, this fold ends just above
       * "flp->lnum".
       */
      break;
    }

    /*
     * The fold includes the line "flp->lnum" and "flp->lnum_save".
     * Check "fp" for safety.
     */
    if (lvl > level && fp != NULL) {
      /*
       * There is a nested fold, handle it recursively.
       */
      /* At least do one line (can happen when finish is TRUE). */
      if (bot < flp->lnum)
        bot = flp->lnum;

      /* Line numbers in the nested fold are relative to the start of
       * this fold. */
      flp->lnum = flp->lnum_save - fp->fd_top;
      flp->off += fp->fd_top;
      i = (int)(fp - (fold_T *)gap->ga_data);
      bot = foldUpdateIEMSRecurse(&fp->fd_nested, level + 1,
                                  startlnum2 - fp->fd_top, flp, getlevel,
                                  bot - fp->fd_top, fp->fd_flags);
      fp = (fold_T *)gap->ga_data + i;
      flp->lnum += fp->fd_top;
      flp->lnum_save += fp->fd_top;
      flp->off -= fp->fd_top;
      bot += fp->fd_top;
      startlnum2 = flp->lnum;

      /* This fold may end at the same line, don't incr. flp->lnum. */
    } else {
      /*
       * Get the level of the next line, then continue the loop to check
       * if it ends there.
       * Skip over undefined lines, to find the foldlevel after it.
       * For the last line in the file the foldlevel is always valid.
       */
      flp->lnum = flp->lnum_save;
      ll = flp->lnum + 1;
      while (!got_int) {
        /* Make the previous level available to foldlevel(). */
        prev_lnum = flp->lnum;
        prev_lnum_lvl = flp->lvl;

        if (++flp->lnum > linecount)
          break;
        flp->lvl = flp->lvl_next;
        getlevel(flp);
        if (flp->lvl >= 0 || flp->had_end <= MAX_LEVEL)
          break;
      }
      prev_lnum = 0;
      if (flp->lnum > linecount)
        break;

      /* leave flp->lnum_save to lnum of the line that was used to get
       * the level, flp->lnum to the lnum of the next line. */
      flp->lnum_save = flp->lnum;
      flp->lnum = ll;
    }
  }

  if (fp == NULL)       /* only happens when got_int is set */
    return bot;

  /*
   * Get here when:
   * lvl < level: the folds ends just above "flp->lnum"
   * lvl >= level: fold continues below "bot"
   */

  /* Current fold at least extends until lnum. */
  if (fp->fd_len < flp->lnum - fp->fd_top) {
    fp->fd_len = flp->lnum - fp->fd_top;
    fp->fd_small = MAYBE;
    fold_changed = TRUE;
  }

  /* Delete contained folds from the end of the last one found until where
   * we stopped looking. */
  foldRemove(&fp->fd_nested, startlnum2 - fp->fd_top,
      flp->lnum - 1 - fp->fd_top);

  if (lvl < level) {
    /* End of fold found, update the length when it got shorter. */
    if (fp->fd_len != flp->lnum - fp->fd_top) {
      if (fp->fd_top + fp->fd_len > bot + 1) {
        /* fold continued below bot */
        if (getlevel == foldlevelMarker
            || getlevel == foldlevelExpr
            || getlevel == foldlevelSyntax) {
          /* marker method: truncate the fold and make sure the
           * previously included lines are processed again */
          bot = fp->fd_top + fp->fd_len - 1;
          fp->fd_len = flp->lnum - fp->fd_top;
        } else {
          /* indent or expr method: split fold to create a new one
           * below bot */
          i = (int)(fp - (fold_T *)gap->ga_data);
          foldSplit(gap, i, flp->lnum, bot);
          fp = (fold_T *)gap->ga_data + i;
        }
      } else
        fp->fd_len = flp->lnum - fp->fd_top;
      fold_changed = TRUE;
    }
  }

  /* delete following folds that end before the current line */
  for (;; ) {
    fp2 = fp + 1;
    if (fp2 >= (fold_T *)gap->ga_data + gap->ga_len
        || fp2->fd_top > flp->lnum)
      break;
    if (fp2->fd_top + fp2->fd_len > flp->lnum) {
      if (fp2->fd_top < flp->lnum) {
        /* Make fold that includes lnum start at lnum. */
        foldMarkAdjustRecurse(&fp2->fd_nested,
            (linenr_T)0, (long)(flp->lnum - fp2->fd_top - 1),
            (linenr_T)MAXLNUM, (long)(fp2->fd_top - flp->lnum));
        fp2->fd_len -= flp->lnum - fp2->fd_top;
        fp2->fd_top = flp->lnum;
        fold_changed = TRUE;
      }

      if (lvl >= level) {
        /* merge new fold with existing fold that follows */
        foldMerge(fp, gap, fp2);
      }
      break;
    }
    fold_changed = TRUE;
    deleteFoldEntry(gap, (int)(fp2 - (fold_T *)gap->ga_data), TRUE);
  }

  /* Need to redraw the lines we inspected, which might be further down than
   * was asked for. */
  if (bot < flp->lnum - 1)
    bot = flp->lnum - 1;

  return bot;
}

/* foldInsert() {{{2 */
/*
 * Insert a new fold in "gap" at position "i".
 */
static void foldInsert(garray_T *gap, int i)
{
  fold_T      *fp;

  ga_grow(gap, 1);

  fp = (fold_T *)gap->ga_data + i;
  if (i < gap->ga_len)
    memmove(fp + 1, fp, sizeof(fold_T) * (size_t)(gap->ga_len - i));
  ++gap->ga_len;
  ga_init(&fp->fd_nested, (int)sizeof(fold_T), 10);
}

/* foldSplit() {{{2 */
/*
 * Split the "i"th fold in "gap", which starts before "top" and ends below
 * "bot" in two pieces, one ending above "top" and the other starting below
 * "bot".
 * The caller must first have taken care of any nested folds from "top" to
 * "bot"!
 */
static void foldSplit(garray_T *gap, int i, linenr_T top, linenr_T bot)
{
  fold_T      *fp;
  fold_T      *fp2;
  garray_T    *gap1;
  garray_T    *gap2;
  int idx;
  int len;

  /* The fold continues below bot, need to split it. */
  foldInsert(gap, i + 1);

  fp = (fold_T *)gap->ga_data + i;
  fp[1].fd_top = bot + 1;
  // check for wrap around (MAXLNUM, and 32bit)
  assert(fp[1].fd_top > bot);
  fp[1].fd_len = fp->fd_len - (fp[1].fd_top - fp->fd_top);
  fp[1].fd_flags = fp->fd_flags;
  fp[1].fd_small = MAYBE;
  fp->fd_small = MAYBE;

  /* Move nested folds below bot to new fold.  There can't be
   * any between top and bot, they have been removed by the caller. */
  gap1 = &fp->fd_nested;
  gap2 = &fp[1].fd_nested;
  (void)(foldFind(gap1, bot + 1 - fp->fd_top, &fp2));
  len = (int)((fold_T *)gap1->ga_data + gap1->ga_len - fp2);
  if (len > 0) {
    ga_grow(gap2, len);
    for (idx = 0; idx < len; ++idx) {
      ((fold_T *)gap2->ga_data)[idx] = fp2[idx];
      ((fold_T *)gap2->ga_data)[idx].fd_top
        -= fp[1].fd_top - fp->fd_top;
    }
    gap2->ga_len = len;
    gap1->ga_len -= len;
  }
  fp->fd_len = top - fp->fd_top;
  fold_changed = TRUE;
}

/* foldRemove() {{{2 */
/*
 * Remove folds within the range "top" to and including "bot".
 * Check for these situations:
 *      1  2  3
 *      1  2  3
 * top     2  3  4  5
 *     2  3  4  5
 * bot     2  3  4  5
 *        3     5  6
 *        3     5  6
 *
 * 1: not changed
 * 2: truncate to stop above "top"
 * 3: split in two parts, one stops above "top", other starts below "bot".
 * 4: deleted
 * 5: made to start below "bot".
 * 6: not changed
 */
static void foldRemove(garray_T *gap, linenr_T top, linenr_T bot)
{
  fold_T      *fp = NULL;

  if (bot < top) {
    return;             // nothing to do
  }

  for (;; ) {
    // Find fold that includes top or a following one.
    if (foldFind(gap, top, &fp) && fp->fd_top < top) {
      // 2: or 3: need to delete nested folds
      foldRemove(&fp->fd_nested, top - fp->fd_top, bot - fp->fd_top);
      if (fp->fd_top + fp->fd_len - 1 > bot) {
        // 3: need to split it.
        foldSplit(gap, (int)(fp - (fold_T *)gap->ga_data), top, bot);
      } else {
        // 2: truncate fold at "top".
        fp->fd_len = top - fp->fd_top;
      }
      fold_changed = true;
      continue;
    }
    if (fp >= (fold_T *)(gap->ga_data) + gap->ga_len
        || fp->fd_top > bot) {
      // 6: Found a fold below bot, can stop looking.
      break;
    }
    if (fp->fd_top >= top) {
      // Found an entry below top.
      fold_changed = true;
      if (fp->fd_top + fp->fd_len - 1 > bot) {
        // 5: Make fold that includes bot start below bot.
        foldMarkAdjustRecurse(&fp->fd_nested,
            (linenr_T)0, (long)(bot - fp->fd_top),
            (linenr_T)MAXLNUM, (long)(fp->fd_top - bot - 1));
        fp->fd_len -= bot - fp->fd_top + 1;
        fp->fd_top = bot + 1;
        break;
      }

      // 4: Delete completely contained fold.
      deleteFoldEntry(gap, (int)(fp - (fold_T *)gap->ga_data), true);
    }
  }
}

// foldMoveRange() {{{2
static void reverse_fold_order(garray_T *gap, size_t start, size_t end)
{
  for (; start < end; start++, end--) {
    fold_T *left = (fold_T *)gap->ga_data + start;
    fold_T *right = (fold_T *)gap->ga_data + end;
    fold_T tmp = *left;
    *left = *right;
    *right = tmp;
  }
}

// Move folds within the inclusive range "line1" to "line2" to after "dest"
// require "line1" <= "line2" <= "dest"
//
// There are the following situations for the first fold at or below line1 - 1.
//       1  2  3  4
//       1  2  3  4
// line1    2  3  4
//          2  3  4  5  6  7
// line2       3  4  5  6  7
//             3  4     6  7  8  9
// dest           4        7  8  9
//                4        7  8    10
//                4        7  8    10
//
// In the following descriptions, "moved" means moving in the buffer, *and* in
// the fold array.
// Meanwhile, "shifted" just means moving in the buffer.
// 1. not changed
// 2. truncated above line1
// 3. length reduced by  line2 - line1, folds starting between the end of 3 and
//    dest are truncated and shifted up
// 4. internal folds moved (from [line1, line2] to dest)
// 5. moved to dest.
// 6. truncated below line2 and moved.
// 7. length reduced by line2 - dest, folds starting between line2 and dest are
//    removed, top is moved down by move_len.
// 8. truncated below dest and shifted up.
// 9. shifted up
// 10. not changed
static void truncate_fold(fold_T *fp, linenr_T end)
{
  // I want to stop *at here*, foldRemove() stops *above* top
  end += 1;
  foldRemove(&fp->fd_nested, end - fp->fd_top, MAXLNUM);
  fp->fd_len = end - fp->fd_top;
}

#define FOLD_END(fp) ((fp)->fd_top + (fp)->fd_len - 1)
#define VALID_FOLD(fp, gap) ((fp) < ((fold_T *)(gap)->ga_data + (gap)->ga_len))
#define FOLD_INDEX(fp, gap) ((size_t)(fp - ((fold_T *)(gap)->ga_data)))
void foldMoveRange(garray_T *gap, const linenr_T line1, const linenr_T line2,
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
      foldMoveRange(&fp->fd_nested, line1 - fp->fd_top, line2 -
                    fp->fd_top, dest - fp->fd_top);
      return;
    } else if (FOLD_END(fp) > line2) {
      // Case 3 -- Remove nested folds between line1 and line2 & reduce the
      // length of fold by "range_len".
      // Folds after this one must be dealt with.
      foldMarkAdjustRecurse(&fp->fd_nested, line1 - fp->fd_top,
                            line2 - fp->fd_top, MAXLNUM, -range_len);
      fp->fd_len -= range_len;
    } else {
      // Case 2 -- truncate fold *above* line1.
      // Folds after this one must be dealt with.
      truncate_fold(fp, line1 - 1);
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
      truncate_fold(fp, dest);
      fp->fd_top -= range_len;
    }
    return;
  } else if (FOLD_END(fp) > dest) {
    // Case 7 -- remove nested folds and shrink
    foldMarkAdjustRecurse(&fp->fd_nested, line2 + 1 - fp->fd_top,
                          dest - fp->fd_top, MAXLNUM, -move_len);
    fp->fd_len -= move_len;
    fp->fd_top += move_len;
    return;
  }

  // Case 5 or 6: changes rely on whether there are folds between the end of
  // this fold and "dest".
  size_t move_start = FOLD_INDEX(fp, gap);
  size_t move_end = 0, dest_index = 0;
  for (; VALID_FOLD(fp, gap) && fp->fd_top <= dest; fp++) {
    if (fp->fd_top <= line2) {
      // 5, or 6
      if (FOLD_END(fp) > line2) {
        // 6, truncate before moving
        truncate_fold(fp, line2);
      }
      fp->fd_top += move_len;
      continue;
    }

    // Record index of the first fold after the moved range.
    if (move_end == 0) {
      move_end = FOLD_INDEX(fp, gap);
    }

    if (FOLD_END(fp) > dest) {
      truncate_fold(fp, dest);
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
  reverse_fold_order(gap, move_start, dest_index - 1);
  reverse_fold_order(gap, move_start, move_start + dest_index - move_end - 1);
  reverse_fold_order(gap, move_start + dest_index - move_end, dest_index - 1);
}
#undef FOLD_END
#undef VALID_FOLD
#undef FOLD_INDEX

/* foldMerge() {{{2 */
/*
 * Merge two adjacent folds (and the nested ones in them).
 * This only works correctly when the folds are really adjacent!  Thus "fp1"
 * must end just above "fp2".
 * The resulting fold is "fp1", nested folds are moved from "fp2" to "fp1".
 * Fold entry "fp2" in "gap" is deleted.
 */
static void foldMerge(fold_T *fp1, garray_T *gap, fold_T *fp2)
{
  fold_T      *fp3;
  fold_T      *fp4;
  int idx;
  garray_T    *gap1 = &fp1->fd_nested;
  garray_T    *gap2 = &fp2->fd_nested;

  /* If the last nested fold in fp1 touches the first nested fold in fp2,
   * merge them recursively. */
  if (foldFind(gap1, fp1->fd_len - 1L, &fp3) && foldFind(gap2, 0L, &fp4))
    foldMerge(fp3, gap2, fp4);

  /* Move nested folds in fp2 to the end of fp1. */
  if (!GA_EMPTY(gap2)) {
    ga_grow(gap1, gap2->ga_len);
    for (idx = 0; idx < gap2->ga_len; ++idx) {
      ((fold_T *)gap1->ga_data)[gap1->ga_len]
        = ((fold_T *)gap2->ga_data)[idx];
      ((fold_T *)gap1->ga_data)[gap1->ga_len].fd_top += fp1->fd_len;
      ++gap1->ga_len;
    }
    gap2->ga_len = 0;
  }

  fp1->fd_len += fp2->fd_len;
  deleteFoldEntry(gap, (int)(fp2 - (fold_T *)gap->ga_data), TRUE);
  fold_changed = TRUE;
}

/* foldlevelIndent() {{{2 */
/*
 * Low level function to get the foldlevel for the "indent" method.
 * Doesn't use any caching.
 * Returns a level of -1 if the foldlevel depends on surrounding lines.
 */
static void foldlevelIndent(fline_T *flp)
{
  char_u      *s;
  buf_T       *buf;
  linenr_T lnum = flp->lnum + flp->off;

  buf = flp->wp->w_buffer;
  s = skipwhite(ml_get_buf(buf, lnum, FALSE));

  /* empty line or lines starting with a character in 'foldignore': level
   * depends on surrounding lines */
  if (*s == NUL || vim_strchr(flp->wp->w_p_fdi, *s) != NULL) {
    /* first and last line can't be undefined, use level 0 */
    if (lnum == 1 || lnum == buf->b_ml.ml_line_count)
      flp->lvl = 0;
    else
      flp->lvl = -1;
  } else
    flp->lvl = get_indent_buf(buf, lnum) / get_sw_value(curbuf);
  if (flp->lvl > flp->wp->w_p_fdn) {
    flp->lvl = (int) MAX(0, flp->wp->w_p_fdn);
  }
}

/* foldlevelDiff() {{{2 */
/*
 * Low level function to get the foldlevel for the "diff" method.
 * Doesn't use any caching.
 */
static void foldlevelDiff(fline_T *flp)
{
  if (diff_infold(flp->wp, flp->lnum + flp->off))
    flp->lvl = 1;
  else
    flp->lvl = 0;
}

/* foldlevelExpr() {{{2 */
/*
 * Low level function to get the foldlevel for the "expr" method.
 * Doesn't use any caching.
 * Returns a level of -1 if the foldlevel depends on surrounding lines.
 */
static void foldlevelExpr(fline_T *flp)
{
  win_T       *win;
  int n;
  int c;
  linenr_T lnum = flp->lnum + flp->off;
  int save_keytyped;

  win = curwin;
  curwin = flp->wp;
  curbuf = flp->wp->w_buffer;
  set_vim_var_nr(VV_LNUM, (varnumber_T) lnum);

  flp->start = 0;
  flp->had_end = flp->end;
  flp->end = MAX_LEVEL + 1;
  if (lnum <= 1)
    flp->lvl = 0;

  /* KeyTyped may be reset to 0 when calling a function which invokes
   * do_cmdline().  To make 'foldopen' work correctly restore KeyTyped. */
  save_keytyped = KeyTyped;
  n = (int)eval_foldexpr(flp->wp->w_p_fde, &c);
  KeyTyped = save_keytyped;

  switch (c) {
  /* "a1", "a2", .. : add to the fold level */
  case 'a': if (flp->lvl >= 0) {
      flp->lvl += n;
      flp->lvl_next = flp->lvl;
  }
    flp->start = n;
    break;

  /* "s1", "s2", .. : subtract from the fold level */
  case 's': if (flp->lvl >= 0) {
      if (n > flp->lvl)
        flp->lvl_next = 0;
      else
        flp->lvl_next = flp->lvl - n;
      flp->end = flp->lvl_next + 1;
  }
    break;

  /* ">1", ">2", .. : start a fold with a certain level */
  case '>': flp->lvl = n;
    flp->lvl_next = n;
    flp->start = 1;
    break;

  /* "<1", "<2", .. : end a fold with a certain level */
  case '<': flp->lvl_next = n - 1;
    flp->end = n;
    break;

  /* "=": No change in level */
  case '=': flp->lvl_next = flp->lvl;
    break;

  /* "-1", "0", "1", ..: set fold level */
  default:  if (n < 0)
      /* Use the current level for the next line, so that "a1"
       * will work there. */
      flp->lvl_next = flp->lvl;
    else
      flp->lvl_next = n;
    flp->lvl = n;
    break;
  }

  /* If the level is unknown for the first or the last line in the file, use
   * level 0. */
  if (flp->lvl < 0) {
    if (lnum <= 1) {
      flp->lvl = 0;
      flp->lvl_next = 0;
    }
    if (lnum == curbuf->b_ml.ml_line_count)
      flp->lvl_next = 0;
  }

  curwin = win;
  curbuf = curwin->w_buffer;
}

/* parseMarker() {{{2 */
/*
 * Parse 'foldmarker' and set "foldendmarker", "foldstartmarkerlen" and
 * "foldendmarkerlen".
 * Relies on the option value to have been checked for correctness already.
 */
static void parseMarker(win_T *wp)
{
  foldendmarker = vim_strchr(wp->w_p_fmr, ',');
  foldstartmarkerlen = (size_t)(foldendmarker++ - wp->w_p_fmr);
  foldendmarkerlen = STRLEN(foldendmarker);
}

/* foldlevelMarker() {{{2 */
/*
 * Low level function to get the foldlevel for the "marker" method.
 * "foldendmarker", "foldstartmarkerlen" and "foldendmarkerlen" must have been
 * set before calling this.
 * Requires that flp->lvl is set to the fold level of the previous line!
 * Careful: This means you can't call this function twice on the same line.
 * Doesn't use any caching.
 * Sets flp->start when a start marker was found.
 */
static void foldlevelMarker(fline_T *flp)
{
  char_u      *startmarker;
  int cstart;
  int cend;
  int start_lvl = flp->lvl;
  char_u      *s;
  int n;

  /* cache a few values for speed */
  startmarker = flp->wp->w_p_fmr;
  cstart = *startmarker;
  ++startmarker;
  cend = *foldendmarker;

  /* Default: no start found, next level is same as current level */
  flp->start = 0;
  flp->lvl_next = flp->lvl;

  s = ml_get_buf(flp->wp->w_buffer, flp->lnum + flp->off, FALSE);
  while (*s) {
    if (*s == cstart
        && STRNCMP(s + 1, startmarker, foldstartmarkerlen - 1) == 0) {
      /* found startmarker: set flp->lvl */
      s += foldstartmarkerlen;
      if (ascii_isdigit(*s)) {
        n = atoi((char *)s);
        if (n > 0) {
          flp->lvl = n;
          flp->lvl_next = n;
          if (n <= start_lvl)
            flp->start = 1;
          else
            flp->start = n - start_lvl;
        }
      } else {
        ++flp->lvl;
        ++flp->lvl_next;
        ++flp->start;
      }
    } else if (*s == cend && STRNCMP(s + 1, foldendmarker + 1,
                                     foldendmarkerlen - 1) == 0) {
      /* found endmarker: set flp->lvl_next */
      s += foldendmarkerlen;
      if (ascii_isdigit(*s)) {
        n = atoi((char *)s);
        if (n > 0) {
          flp->lvl = n;
          flp->lvl_next = n - 1;
          /* never start a fold with an end marker */
          if (flp->lvl_next > start_lvl)
            flp->lvl_next = start_lvl;
        }
      } else
        --flp->lvl_next;
    } else
      mb_ptr_adv(s);
  }

  /* The level can't go negative, must be missing a start marker. */
  if (flp->lvl_next < 0)
    flp->lvl_next = 0;
}

/* foldlevelSyntax() {{{2 */
/*
 * Low level function to get the foldlevel for the "syntax" method.
 * Doesn't use any caching.
 */
static void foldlevelSyntax(fline_T *flp)
{
  linenr_T lnum = flp->lnum + flp->off;
  int n;

  /* Use the maximum fold level at the start of this line and the next. */
  flp->lvl = syn_get_foldlevel(flp->wp, lnum);
  flp->start = 0;
  if (lnum < flp->wp->w_buffer->b_ml.ml_line_count) {
    n = syn_get_foldlevel(flp->wp, lnum + 1);
    if (n > flp->lvl) {
      flp->start = n - flp->lvl;        /* fold(s) start here */
      flp->lvl = n;
    }
  }
}

/* functions for storing the fold state in a View {{{1 */
/* put_folds() {{{2 */

/*
 * Write commands to "fd" to restore the manual folds in window "wp".
 * Return FAIL if writing fails.
 */
int put_folds(FILE *fd, win_T *wp)
{
  if (foldmethodIsManual(wp)) {
    if (put_line(fd, "silent! normal! zE") == FAIL
        || put_folds_recurse(fd, &wp->w_folds, (linenr_T)0) == FAIL)
      return FAIL;
  }

  /* If some folds are manually opened/closed, need to restore that. */
  if (wp->w_fold_manual)
    return put_foldopen_recurse(fd, wp, &wp->w_folds, (linenr_T)0);

  return OK;
}

/* put_folds_recurse() {{{2 */
/*
 * Write commands to "fd" to recreate manually created folds.
 * Returns FAIL when writing failed.
 */
static int put_folds_recurse(FILE *fd, garray_T *gap, linenr_T off)
{
  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    /* Do nested folds first, they will be created closed. */
    if (put_folds_recurse(fd, &fp->fd_nested, off + fp->fd_top) == FAIL)
      return FAIL;
    if (fprintf(fd, "%" PRId64 ",%" PRId64 "fold",
                (int64_t)(fp->fd_top + off),
                (int64_t)(fp->fd_top + off + fp->fd_len - 1)) < 0
        || put_eol(fd) == FAIL)
      return FAIL;
    ++fp;
  }
  return OK;
}

/* put_foldopen_recurse() {{{2 */
/*
 * Write commands to "fd" to open and close manually opened/closed folds.
 * Returns FAIL when writing failed.
 */
static int put_foldopen_recurse(FILE *fd, win_T *wp, garray_T *gap, linenr_T off)
{
  int level;

  fold_T *fp = (fold_T *)gap->ga_data;
  for (int i = 0; i < gap->ga_len; i++) {
    if (fp->fd_flags != FD_LEVEL) {
      if (!GA_EMPTY(&fp->fd_nested)) {
        /* open nested folds while this fold is open */
        if (fprintf(fd, "%" PRId64, (int64_t)(fp->fd_top + off)) < 0
            || put_eol(fd) == FAIL
            || put_line(fd, "normal! zo") == FAIL)
          return FAIL;
        if (put_foldopen_recurse(fd, wp, &fp->fd_nested,
                off + fp->fd_top)
            == FAIL)
          return FAIL;
        /* close the parent when needed */
        if (fp->fd_flags == FD_CLOSED) {
          if (put_fold_open_close(fd, fp, off) == FAIL)
            return FAIL;
        }
      } else {
        /* Open or close the leaf according to the window foldlevel.
         * Do not close a leaf that is already closed, as it will close
         * the parent. */
        level = foldLevelWin(wp, off + fp->fd_top);
        if ((fp->fd_flags == FD_CLOSED && wp->w_p_fdl >= level)
            || (fp->fd_flags != FD_CLOSED && wp->w_p_fdl < level))
          if (put_fold_open_close(fd, fp, off) == FAIL)
            return FAIL;
      }
    }
    ++fp;
  }

  return OK;
}

/* put_fold_open_close() {{{2 */
/*
 * Write the open or close command to "fd".
 * Returns FAIL when writing failed.
 */
static int put_fold_open_close(FILE *fd, fold_T *fp, linenr_T off)
{
  if (fprintf(fd, "%" PRId64, (int64_t)(fp->fd_top + off)) < 0
      || put_eol(fd) == FAIL
      || fprintf(fd, "normal! z%c",
          fp->fd_flags == FD_CLOSED ? 'c' : 'o') < 0
      || put_eol(fd) == FAIL)
    return FAIL;

  return OK;
}

/* }}}1 */
