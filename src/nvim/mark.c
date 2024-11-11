// mark.c: functions for setting marks and jumping to them

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/fold.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/time.h"
#include "nvim/os/time_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/quickfix.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/textobject.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

// This file contains routines to maintain and manipulate marks.

// If a named file mark's lnum is non-zero, it is valid.
// If a named file mark's fnum is non-zero, it is for an existing buffer,
// otherwise it is from .shada and namedfm[n].fname is the file name.
// There are marks 'A - 'Z (set by user) and '0 to '9 (set when writing
// shada).

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark.c.generated.h"
#endif

// Set named mark "c" at current cursor position.
// Returns OK on success, FAIL if bad name given.
int setmark(int c)
{
  fmarkv_T view = mark_view_make(curwin->w_topline, curwin->w_cursor);
  return setmark_pos(c, &curwin->w_cursor, curbuf->b_fnum, &view);
}

/// Free fmark_T item
void free_fmark(fmark_T fm)
{
  xfree(fm.additional_data);
}

/// Free xfmark_T item
void free_xfmark(xfmark_T fm)
{
  xfree(fm.fname);
  free_fmark(fm.fmark);
}

/// Free and clear fmark_T item
void clear_fmark(fmark_T *const fm, const Timestamp timestamp)
  FUNC_ATTR_NONNULL_ALL
{
  free_fmark(*fm);
  *fm = (fmark_T)INIT_FMARK;
  fm->timestamp = timestamp;
}

// Set named mark "c" to position "pos".
// When "c" is upper case use file "fnum".
// Returns OK on success, FAIL if bad name given.
int setmark_pos(int c, pos_T *pos, int fnum, fmarkv_T *view_pt)
{
  int i;
  fmarkv_T view = view_pt != NULL ? *view_pt : (fmarkv_T)INIT_FMARKV;

  // Check for a special key (may cause islower() to crash).
  if (c < 0) {
    return FAIL;
  }

  if (c == '\'' || c == '`') {
    if (pos == &curwin->w_cursor) {
      setpcmark();
      // keep it even when the cursor doesn't move
      curwin->w_prev_pcmark = curwin->w_pcmark;
    } else {
      curwin->w_pcmark = *pos;
    }
    return OK;
  }

  // Can't set a mark in a non-existent buffer.
  buf_T *buf = buflist_findnr(fnum);
  if (buf == NULL) {
    return FAIL;
  }

  if (c == '"') {
    RESET_FMARK(&buf->b_last_cursor, *pos, buf->b_fnum, view);
    return OK;
  }

  // Allow setting '[ and '] for an autocommand that simulates reading a
  // file.
  if (c == '[') {
    buf->b_op_start = *pos;
    return OK;
  }
  if (c == ']') {
    buf->b_op_end = *pos;
    return OK;
  }

  if (c == '<' || c == '>') {
    if (c == '<') {
      buf->b_visual.vi_start = *pos;
    } else {
      buf->b_visual.vi_end = *pos;
    }
    if (buf->b_visual.vi_mode == NUL) {
      // Visual_mode has not yet been set, use a sane default.
      buf->b_visual.vi_mode = 'v';
    }
    return OK;
  }

  if (ASCII_ISLOWER(c)) {
    i = c - 'a';
    RESET_FMARK(buf->b_namedm + i, *pos, fnum, view);
    return OK;
  }
  if (ASCII_ISUPPER(c) || ascii_isdigit(c)) {
    if (ascii_isdigit(c)) {
      i = c - '0' + NMARKS;
    } else {
      i = c - 'A';
    }
    RESET_XFMARK(namedfm + i, *pos, fnum, view, NULL);
    return OK;
  }
  return FAIL;
}

/// Remove every jump list entry referring to a given buffer.
/// This function will also adjust the current jump list index.
void mark_jumplist_forget_file(win_T *wp, int fnum)
{
  // Remove all jump list entries that match the deleted buffer.
  for (int i = wp->w_jumplistlen - 1; i >= 0; i--) {
    if (wp->w_jumplist[i].fmark.fnum == fnum) {
      // Found an entry that we want to delete.
      free_xfmark(wp->w_jumplist[i]);

      // If the current jump list index is behind the entry we want to delete,
      // move it back by one.
      if (wp->w_jumplistidx > i) {
        wp->w_jumplistidx--;
      }

      // Actually remove the entry from the jump list.
      wp->w_jumplistlen--;
      memmove(&wp->w_jumplist[i], &wp->w_jumplist[i + 1],
              (size_t)(wp->w_jumplistlen - i) * sizeof(wp->w_jumplist[i]));
    }
  }
}

/// Delete every entry referring to file "fnum" from both the jumplist and the
/// tag stack.
void mark_forget_file(win_T *wp, int fnum)
{
  mark_jumplist_forget_file(wp, fnum);

  // Remove all tag stack entries that match the deleted buffer.
  for (int i = wp->w_tagstacklen - 1; i >= 0; i--) {
    if (wp->w_tagstack[i].fmark.fnum == fnum) {
      // Found an entry that we want to delete.
      tagstack_clear_entry(&wp->w_tagstack[i]);

      // If the current tag stack index is behind the entry we want to delete,
      // move it back by one.
      if (wp->w_tagstackidx > i) {
        wp->w_tagstackidx--;
      }

      // Actually remove the entry from the tag stack.
      wp->w_tagstacklen--;
      memmove(&wp->w_tagstack[i], &wp->w_tagstack[i + 1],
              (size_t)(wp->w_tagstacklen - i) * sizeof(wp->w_tagstack[i]));
    }
  }
}

// Set the previous context mark to the current position and add it to the
// jump list.
void setpcmark(void)
{
  xfmark_T *fm;

  // for :global the mark is set only once
  if (global_busy || listcmd_busy || (cmdmod.cmod_flags & CMOD_KEEPJUMPS)) {
    return;
  }

  curwin->w_prev_pcmark = curwin->w_pcmark;
  curwin->w_pcmark = curwin->w_cursor;

  if (curwin->w_pcmark.lnum == 0) {
    curwin->w_pcmark.lnum = 1;
  }

  if (jop_flags & JOP_STACK) {
    // jumpoptions=stack: if we're somewhere in the middle of the jumplist
    // discard everything after the current index.
    if (curwin->w_jumplistidx < curwin->w_jumplistlen - 1) {
      // Discard the rest of the jumplist by cutting the length down to
      // contain nothing beyond the current index.
      curwin->w_jumplistlen = curwin->w_jumplistidx + 1;
    }
  }

  // If jumplist is full: remove oldest entry
  if (++curwin->w_jumplistlen > JUMPLISTSIZE) {
    curwin->w_jumplistlen = JUMPLISTSIZE;
    free_xfmark(curwin->w_jumplist[0]);
    memmove(&curwin->w_jumplist[0], &curwin->w_jumplist[1],
            (JUMPLISTSIZE - 1) * sizeof(curwin->w_jumplist[0]));
  }
  curwin->w_jumplistidx = curwin->w_jumplistlen;
  fm = &curwin->w_jumplist[curwin->w_jumplistlen - 1];

  fmarkv_T view = mark_view_make(curwin->w_topline, curwin->w_pcmark);
  SET_XFMARK(fm, curwin->w_pcmark, curbuf->b_fnum, view, NULL);
}

// To change context, call setpcmark(), then move the current position to
// where ever, then call checkpcmark().  This ensures that the previous
// context will only be changed if the cursor moved to a different line.
// If pcmark was deleted (with "dG") the previous mark is restored.
void checkpcmark(void)
{
  if (curwin->w_prev_pcmark.lnum != 0
      && (equalpos(curwin->w_pcmark, curwin->w_cursor)
          || curwin->w_pcmark.lnum == 0)) {
    curwin->w_pcmark = curwin->w_prev_pcmark;
  }
  curwin->w_prev_pcmark.lnum = 0;  // it has been checked
}

/// Get mark in "count" position in the |jumplist| relative to the current index.
///
/// If the mark is in a different buffer, it will be skipped unless the buffer exists.
///
/// @note cleanup_jumplist() is run, which removes duplicate marks, and
///       changes win->w_jumplistidx.
/// @param[in] win  window to get jumplist from.
/// @param[in] count  count to move may be negative.
///
/// @return  mark, NULL if out of jumplist bounds.
fmark_T *get_jumplist(win_T *win, int count)
{
  xfmark_T *jmp = NULL;

  cleanup_jumplist(win, true);

  if (win->w_jumplistlen == 0) {         // nothing to jump to
    return NULL;
  }

  while (true) {
    if (win->w_jumplistidx + count < 0
        || win->w_jumplistidx + count >= win->w_jumplistlen) {
      return NULL;
    }

    // if first CTRL-O or CTRL-I command after a jump, add cursor position
    // to list.  Careful: If there are duplicates (CTRL-O immediately after
    // starting Vim on a file), another entry may have been removed.
    if (win->w_jumplistidx == win->w_jumplistlen) {
      setpcmark();
      win->w_jumplistidx--;          // skip the new entry
      if (win->w_jumplistidx + count < 0) {
        return NULL;
      }
    }

    win->w_jumplistidx += count;

    jmp = win->w_jumplist + win->w_jumplistidx;
    if (jmp->fmark.fnum == 0) {
      // Resolve the fnum (buff number) in the mark before returning it (shada)
      fname2fnum(jmp);
    }
    if (jmp->fmark.fnum != curbuf->b_fnum) {
      // Needs to switch buffer, if it can't find it skip the mark
      if (buflist_findnr(jmp->fmark.fnum) == NULL) {
        count += count < 0 ? -1 : 1;
        continue;
      }
    }
    break;
  }
  return &jmp->fmark;
}

/// Get mark in "count" position in the |changelist| relative to the current index.
///
/// @note  Changes the win->w_changelistidx.
/// @param[in] win  window to get jumplist from.
/// @param[in] count  count to move may be negative.
///
/// @return  mark, NULL if out of bounds.
fmark_T *get_changelist(buf_T *buf, win_T *win, int count)
{
  int n;
  fmark_T *fm;

  if (buf->b_changelistlen == 0) {       // nothing to jump to
    return NULL;
  }

  n = win->w_changelistidx;
  if (n + count < 0) {
    if (n == 0) {
      return NULL;
    }
    n = 0;
  } else if (n + count >= buf->b_changelistlen) {
    if (n == buf->b_changelistlen - 1) {
      return NULL;
    }
    n = buf->b_changelistlen - 1;
  } else {
    n += count;
  }
  win->w_changelistidx = n;
  fm = &(buf->b_changelist[n]);
  // Changelist marks are always buffer local, Shada does not set it when loading
  fm->fnum = curbuf->handle;
  return &(buf->b_changelist[n]);
}

/// Get a named mark.
///
/// All types of marks, even those that are not technically a mark will be returned as such. Use
/// mark_move_to() to move to the mark.
/// @note Some of the pointers are statically allocated, if in doubt make a copy. For more
/// information read mark_get_local().
/// @param buf  Buffer to get the mark from.
/// @param win  Window to get or calculate the mark from (motion type marks, context mark).
/// @param fmp[out] Optional pointer to store the result in, as a workaround for the note above.
/// @param flag MarkGet value
/// @param name Name of the mark.
///
/// @return          Mark if found, otherwise NULL.  For @c kMarkBufLocal, NULL is returned
///                  when no mark is found in @a buf.
fmark_T *mark_get(buf_T *buf, win_T *win, fmark_T *fmp, MarkGet flag, int name)
{
  fmark_T *fm = NULL;
  if (ASCII_ISUPPER(name) || ascii_isdigit(name)) {
    // Global marks
    xfmark_T *xfm = mark_get_global(flag != kMarkAllNoResolve, name);
    fm = &xfm->fmark;
    if (flag == kMarkBufLocal && xfm->fmark.fnum != buf->handle) {
      // Only wanted marks belonging to the buffer
      return pos_to_mark(buf, NULL, (pos_T){ .lnum = 0 });
    }
  } else if (name > 0 && name < NMARK_LOCAL_MAX) {
    // Local Marks
    fm = mark_get_local(buf, win, name);
  }
  if (fmp != NULL && fm != NULL) {
    *fmp = *fm;
    return fmp;
  }
  return fm;
}

/// Get a global mark {A-Z0-9}.
///
/// @param name  the name of the mark.
/// @param resolve  Whether to try resolving the mark fnum (i.e., load the buffer stored in
///                 the mark fname and update the xfmark_T (expensive)).
///
/// @return  Mark
xfmark_T *mark_get_global(bool resolve, int name)
{
  xfmark_T *mark;

  if (ascii_isdigit(name)) {
    name = name - '0' + NMARKS;
  } else if (ASCII_ISUPPER(name)) {
    name -= 'A';
  } else {
    // Not a valid mark name
    assert(false);
  }
  mark = &namedfm[name];

  if (resolve && mark->fmark.fnum == 0) {
    // Resolve filename to fnum (SHADA marks)
    fname2fnum(mark);
  }
  return mark;
}

/// Get a local mark (lowercase and symbols).
///
/// Some marks are not actually marks, but positions that are never adjusted or motions presented as
/// marks. Search first for marks and fallback to finding motion type marks. If it's known
/// ahead of time that the mark is actually a motion use the mark_get_motion() directly.
///
/// @note  Lowercase, last_cursor '"', last insert '^', last change '.' are not statically
/// allocated, everything else is.
/// @param name  the name of the mark.
/// @param win  window to retrieve marks that belong to it (motions and context mark).
/// @param buf  buf to retrieve marks that belong to it.
///
/// @return  Mark, NULL if not found.
fmark_T *mark_get_local(buf_T *buf, win_T *win, int name)
{
  fmark_T *mark = NULL;
  if (ASCII_ISLOWER(name)) {
    // normal named mark
    mark = &buf->b_namedm[name - 'a'];
    // to start of previous operator
  } else if (name == '[') {
    mark = pos_to_mark(buf, NULL, buf->b_op_start);
    // to end of previous operator
  } else if (name == ']') {
    mark = pos_to_mark(buf, NULL, buf->b_op_end);
    // visual marks
  } else if (name == '<' || name == '>') {
    mark = mark_get_visual(buf, name);
    // previous context mark
  } else if (name == '\'' || name == '`') {
    // TODO(muniter): w_pcmark should be stored as a mark, but causes a nasty bug.
    mark = pos_to_mark(curbuf, NULL, win->w_pcmark);
    // to position when leaving buffer
  } else if (name == '"') {
    mark = &(buf->b_last_cursor);
    // to where last Insert mode stopped
  } else if (name == '^') {
    mark = &(buf->b_last_insert);
    // to where last change was made
  } else if (name == '.') {
    mark = &buf->b_last_change;
    // Mark that are actually not marks but motions, e.g {, }, (, ), ...
  } else {
    mark = mark_get_motion(buf, win, name);
  }

  if (mark) {
    mark->fnum = buf->b_fnum;
  }

  return mark;
}

/// Get marks that are actually motions but return them as marks
///
/// Gets the following motions as marks: '{', '}', '(', ')'
/// @param name  name of the mark
/// @param win  window to retrieve the cursor to calculate the mark.
/// @param buf  buf to wrap motion marks with it's buffer number (fm->fnum).
///
/// @return[static] Mark.
fmark_T *mark_get_motion(buf_T *buf, win_T *win, int name)
{
  fmark_T *mark = NULL;
  const pos_T pos = curwin->w_cursor;
  const bool slcb = listcmd_busy;
  listcmd_busy = true;  // avoid that '' is changed
  if (name == '{' || name == '}') {  // to previous/next paragraph
    oparg_T oa;
    if (findpar(&oa.inclusive, name == '}' ? FORWARD : BACKWARD, 1, NUL, false)) {
      mark = pos_to_mark(buf, NULL, win->w_cursor);
    }
  } else if (name == '(' || name == ')') {  // to previous/next sentence
    if (findsent(name == ')' ? FORWARD : BACKWARD, 1)) {
      mark = pos_to_mark(buf, NULL, win->w_cursor);
    }
  }
  curwin->w_cursor = pos;
  listcmd_busy = slcb;
  return mark;
}

/// Get visual marks '<', '>'
///
/// This marks are different to normal marks:
/// 1. Never adjusted.
/// 2. Different behavior depending on editor state (visual mode).
/// 3. Not saved in shada.
/// 4. Re-ordered when defined in reverse.
/// @param buf  Buffer to get the mark from.
/// @param name  Mark name '<' or '>'.
///
/// @return[static]  Mark
fmark_T *mark_get_visual(buf_T *buf, int name)
{
  fmark_T *mark = NULL;
  if (name == '<' || name == '>') {
    // start/end of visual area
    pos_T startp = buf->b_visual.vi_start;
    pos_T endp = buf->b_visual.vi_end;
    if (((name == '<') == lt(startp, endp) || endp.lnum == 0)
        && startp.lnum != 0) {
      mark = pos_to_mark(buf, NULL, startp);
    } else {
      mark = pos_to_mark(buf, NULL, endp);
    }

    if (buf->b_visual.vi_mode == 'V') {
      if (name == '<') {
        mark->mark.col = 0;
      } else {
        mark->mark.col = MAXCOL;
      }
      mark->mark.coladd = 0;
    }
  }
  return mark;
}

/// Wrap a pos_T into an fmark_T, used to abstract marks handling.
///
/// Pass an fmp if multiple c
/// @note  view fields are set to 0.
/// @param buf  for fmark->fnum.
/// @param pos  for fmark->mark.
/// @param fmp pointer to save the mark.
///
/// @return[static] Mark with the given information.
fmark_T *pos_to_mark(buf_T *buf, fmark_T *fmp, pos_T pos)
  FUNC_ATTR_NONNULL_RET
{
  static fmark_T fms = INIT_FMARK;
  fmark_T *fm = fmp == NULL ? &fms : fmp;
  fm->fnum = buf->handle;
  fm->mark = pos;
  return fm;
}

/// Attempt to switch to the buffer of the given global mark
///
/// @param fm
/// @param pcmark_on_switch  leave a context mark when switching buffer.
/// @return whether the buffer was switched or not.
static MarkMoveRes switch_to_mark_buf(fmark_T *fm, bool pcmark_on_switch)
{
  if (fm->fnum != curbuf->b_fnum) {
    // Switch to another file.
    int getfile_flag = pcmark_on_switch ? GETF_SETMARK : 0;
    bool res = buflist_getfile(fm->fnum, fm->mark.lnum, getfile_flag, false) == OK;
    return res == true ? kMarkSwitchedBuf : kMarkMoveFailed;
  }
  return 0;
}

/// Move to the given file mark, changing the buffer and cursor position.
///
/// Validate the mark, switch to the buffer, and move the cursor.
/// @param fm  Mark, can be NULL will raise E78: Unknown mark
/// @param flags  MarkMove flags to configure the movement to the mark.
///
/// @return  MarkMovekRes flags representing the outcome
MarkMoveRes mark_move_to(fmark_T *fm, MarkMove flags)
{
  static fmark_T fm_copy = INIT_FMARK;
  MarkMoveRes res = kMarkMoveSuccess;
  const char *errormsg = NULL;
  if (!mark_check(fm, &errormsg)) {
    if (errormsg != NULL) {
      emsg(errormsg);
    }
    res = kMarkMoveFailed;
    goto end;
  }

  if (fm->fnum != curbuf->handle) {
    // Need to change buffer
    fm_copy = *fm;  // Copy, autocommand may change it
    fm = &fm_copy;
    // Jump to the file with the mark
    res |= switch_to_mark_buf(fm, !(flags & kMarkJumpList));
    // Failed switching buffer
    if (res & kMarkMoveFailed) {
      goto end;
    }
    // Check line count now that the **destination buffer is loaded**.
    if (!mark_check_line_bounds(curbuf, fm, &errormsg)) {
      if (errormsg != NULL) {
        emsg(errormsg);
      }
      res |= kMarkMoveFailed;
      goto end;
    }
  } else if (flags & kMarkContext) {
    // Doing it in this condition avoids double context mark when switching buffer.
    setpcmark();
  }
  // Move the cursor while keeping track of what changed for the caller
  pos_T prev_pos = curwin->w_cursor;
  pos_T pos = fm->mark;
  // Set lnum again, autocommands my have changed it
  curwin->w_cursor = fm->mark;
  if (flags & kMarkBeginLine) {
    beginline(BL_WHITE | BL_FIX);
  }
  res = prev_pos.lnum != pos.lnum ? res | kMarkChangedLine | kMarkChangedCursor : res;
  res = prev_pos.col != pos.col ? res | kMarkChangedCol | kMarkChangedCursor : res;
  if (flags & kMarkSetView) {
    mark_view_restore(fm);
  }

  if (res & kMarkSwitchedBuf || res & kMarkChangedCursor) {
    check_cursor(curwin);
  }
end:
  return res;
}

/// Restore the mark view.
/// By remembering the offset between topline and mark lnum at the time of
/// definition, this function restores the "view".
/// @note  Assumes the mark has been checked, is valid.
/// @param  fm the named mark.
void mark_view_restore(fmark_T *fm)
{
  if (fm != NULL && fm->view.topline_offset >= 0) {
    linenr_T topline = fm->mark.lnum - fm->view.topline_offset;
    // If the mark does not have a view, topline_offset is MAXLNUM,
    // and this check can prevent restoring mark view in that case.
    if (topline >= 1) {
      set_topline(curwin, topline);
    }
  }
}

fmarkv_T mark_view_make(linenr_T topline, pos_T pos)
{
  return (fmarkv_T){ pos.lnum - topline };
}

/// Search for the next named mark in the current file from a start position.
///
/// @param startpos  where to start.
/// @param dir  direction for search.
///
/// @return  next mark or NULL if no mark is found.
fmark_T *getnextmark(pos_T *startpos, int dir, int begin_line)
{
  fmark_T *result = NULL;
  pos_T pos = *startpos;

  if (dir == BACKWARD && begin_line) {
    pos.col = 0;
  } else if (dir == FORWARD && begin_line) {
    pos.col = MAXCOL;
  }

  for (int i = 0; i < NMARKS; i++) {
    if (curbuf->b_namedm[i].mark.lnum > 0) {
      if (dir == FORWARD) {
        if ((result == NULL || lt(curbuf->b_namedm[i].mark, result->mark))
            && lt(pos, curbuf->b_namedm[i].mark)) {
          result = &curbuf->b_namedm[i];
        }
      } else {
        if ((result == NULL || lt(result->mark, curbuf->b_namedm[i].mark))
            && lt(curbuf->b_namedm[i].mark, pos)) {
          result = &curbuf->b_namedm[i];
        }
      }
    }
  }

  return result;
}

// For an xtended filemark: set the fnum from the fname.
// This is used for marks obtained from the .shada file.  It's postponed
// until the mark is used to avoid a long startup delay.
static void fname2fnum(xfmark_T *fm)
{
  if (fm->fname == NULL) {
    return;
  }

  // First expand "~/" in the file name to the home directory.
  // Don't expand the whole name, it may contain other '~' chars.
#ifdef BACKSLASH_IN_FILENAME
  if (fm->fname[0] == '~' && (fm->fname[1] == '/' || fm->fname[1] == '\\')) {
#else
  if (fm->fname[0] == '~' && (fm->fname[1] == '/')) {
#endif

    expand_env("~/", NameBuff, MAXPATHL);
    int len = (int)strlen(NameBuff);
    xstrlcpy(NameBuff + len, fm->fname + 2, (size_t)(MAXPATHL - len));
  } else {
    xstrlcpy(NameBuff, fm->fname, MAXPATHL);
  }

  // Try to shorten the file name.
  os_dirname(IObuff, IOSIZE);
  char *p = path_shorten_fname(NameBuff, IObuff);

  // buflist_new() will call fmarks_check_names()
  (void)buflist_new(NameBuff, p, 1, 0);
}

// Check all file marks for a name that matches the file name in buf.
// May replace the name with an fnum.
// Used for marks that come from the .shada file.
void fmarks_check_names(buf_T *buf)
{
  char *name = buf->b_ffname;

  if (buf->b_ffname == NULL) {
    return;
  }

  for (int i = 0; i < NGLOBALMARKS; i++) {
    fmarks_check_one(&namedfm[i], name, buf);
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    for (int i = 0; i < wp->w_jumplistlen; i++) {
      fmarks_check_one(&wp->w_jumplist[i], name, buf);
    }
  }
}

static void fmarks_check_one(xfmark_T *fm, char *name, buf_T *buf)
{
  if (fm->fmark.fnum == 0
      && fm->fname != NULL
      && path_fnamecmp(name, fm->fname) == 0) {
    fm->fmark.fnum = buf->b_fnum;
    XFREE_CLEAR(fm->fname);
  }
}

/// Check the position in @a fm is valid.
///
/// Checks for:
/// - NULL raising unknown mark error.
/// - Line number <= 0 raising mark not set.
/// - Line number > buffer line count, raising invalid mark.
///
/// @param fm[in]  File mark to check.
/// @param errormsg[out]  Error message, if any.
///
/// @return  true if the mark passes all the above checks, else false.
bool mark_check(fmark_T *fm, const char **errormsg)
{
  if (fm == NULL) {
    *errormsg = _(e_umark);
    return false;
  } else if (fm->mark.lnum <= 0) {
    // In both cases it's an error but only raise when equals to 0
    if (fm->mark.lnum == 0) {
      *errormsg = _(e_marknotset);
    }
    return false;
  }
  // Only check for valid line number if the buffer is loaded.
  if (fm->fnum == curbuf->handle && !mark_check_line_bounds(curbuf, fm, errormsg)) {
    return false;
  }
  return true;
}

/// Check if a mark line number is greater than the buffer line count, and set e_markinval.
///
/// @note  Should be done after the buffer is loaded into memory.
/// @param buf  Buffer where the mark is set.
/// @param fm  Mark to check.
/// @param errormsg[out]  Error message, if any.
/// @return  true if below line count else false.
bool mark_check_line_bounds(buf_T *buf, fmark_T *fm, const char **errormsg)
{
  if (buf != NULL && fm->mark.lnum > buf->b_ml.ml_line_count) {
    *errormsg = _(e_markinval);
    return false;
  }
  return true;
}

/// Clear all marks and change list in the given buffer
///
/// Used mainly when trashing the entire buffer during ":e" type commands.
///
/// @param[out]  buf  Buffer to clear marks in.
void clrallmarks(buf_T *const buf, const Timestamp timestamp)
  FUNC_ATTR_NONNULL_ALL
{
  for (size_t i = 0; i < NMARKS; i++) {
    clear_fmark(&buf->b_namedm[i], timestamp);
  }
  clear_fmark(&buf->b_last_cursor, timestamp);
  buf->b_last_cursor.mark.lnum = 1;
  clear_fmark(&buf->b_last_insert, timestamp);
  clear_fmark(&buf->b_last_change, timestamp);
  buf->b_op_start.lnum = 0;  // start/end op mark cleared
  buf->b_op_end.lnum = 0;
  for (int i = 0; i < buf->b_changelistlen; i++) {
    clear_fmark(&buf->b_changelist[i], timestamp);
  }
  buf->b_changelistlen = 0;
}

// Get name of file from a filemark.
// When it's in the current buffer, return the text at the mark.
// Returns an allocated string.
char *fm_getname(fmark_T *fmark, int lead_len)
{
  if (fmark->fnum == curbuf->b_fnum) {              // current buffer
    return mark_line(&(fmark->mark), lead_len);
  }
  return buflist_nr2name(fmark->fnum, false, true);
}

/// Return the line at mark "mp".  Truncate to fit in window.
/// The returned string has been allocated.
static char *mark_line(pos_T *mp, int lead_len)
{
  char *p;

  if (mp->lnum == 0 || mp->lnum > curbuf->b_ml.ml_line_count) {
    return xstrdup("-invalid-");
  }
  assert(Columns >= 0);
  // Allow for up to 5 bytes per character.
  char *s = xstrnsave(skipwhite(ml_get(mp->lnum)), (size_t)Columns * 5);

  // Truncate the line to fit it in the window
  int len = 0;
  for (p = s; *p != NUL; MB_PTR_ADV(p)) {
    len += ptr2cells(p);
    if (len >= Columns - lead_len) {
      break;
    }
  }
  *p = NUL;
  return s;
}

// print the marks
void ex_marks(exarg_T *eap)
{
  char *arg = eap->arg;
  char *name;
  pos_T *posp;

  if (arg != NULL && *arg == NUL) {
    arg = NULL;
  }

  show_one_mark('\'', arg, &curwin->w_pcmark, NULL, true);
  for (int i = 0; i < NMARKS; i++) {
    show_one_mark(i + 'a', arg, &curbuf->b_namedm[i].mark, NULL, true);
  }
  for (int i = 0; i < NGLOBALMARKS; i++) {
    if (namedfm[i].fmark.fnum != 0) {
      name = fm_getname(&namedfm[i].fmark, 15);
    } else {
      name = namedfm[i].fname;
    }
    if (name != NULL) {
      show_one_mark(i >= NMARKS ? i - NMARKS + '0' : i + 'A',
                    arg, &namedfm[i].fmark.mark, name,
                    namedfm[i].fmark.fnum == curbuf->b_fnum);
      if (namedfm[i].fmark.fnum != 0) {
        xfree(name);
      }
    }
  }
  show_one_mark('"', arg, &curbuf->b_last_cursor.mark, NULL, true);
  show_one_mark('[', arg, &curbuf->b_op_start, NULL, true);
  show_one_mark(']', arg, &curbuf->b_op_end, NULL, true);
  show_one_mark('^', arg, &curbuf->b_last_insert.mark, NULL, true);
  show_one_mark('.', arg, &curbuf->b_last_change.mark, NULL, true);

  // Show the marks as where they will jump to.
  pos_T *startp = &curbuf->b_visual.vi_start;
  pos_T *endp = &curbuf->b_visual.vi_end;
  if ((lt(*startp, *endp) || endp->lnum == 0) && startp->lnum != 0) {
    posp = startp;
  } else {
    posp = endp;
  }
  show_one_mark('<', arg, posp, NULL, true);
  show_one_mark('>', arg, posp == startp ? endp : startp, NULL, true);

  show_one_mark(-1, arg, NULL, NULL, false);
}

/// @param current  in current file
static void show_one_mark(int c, char *arg, pos_T *p, char *name_arg, int current)
{
  static bool did_title = false;
  bool mustfree = false;
  char *name = name_arg;

  if (c == -1) {  // finish up
    if (did_title) {
      did_title = false;
    } else {
      if (arg == NULL) {
        msg(_("No marks set"), 0);
      } else {
        semsg(_("E283: No marks matching \"%s\""), arg);
      }
    }
  } else if (!got_int
             && (arg == NULL || vim_strchr(arg, c) != NULL)
             && p->lnum != 0) {
    // don't output anything if 'q' typed at --more-- prompt
    if (name == NULL && current) {
      name = mark_line(p, 15);
      mustfree = true;
    }
    if (!message_filtered(name)) {
      if (!did_title) {
        // Highlight title
        msg_puts_title(_("\nmark line  col file/text"));
        did_title = true;
      }
      msg_putchar('\n');
      if (!got_int) {
        snprintf(IObuff, IOSIZE, " %c %6" PRIdLINENR " %4d ", c, p->lnum, p->col);
        msg_outtrans(IObuff, 0, false);
        if (name != NULL) {
          msg_outtrans(name, current ? HLF_D : 0, false);
        }
      }
    }
    if (mustfree) {
      xfree(name);
    }
  }
}

// ":delmarks[!] [marks]"
void ex_delmarks(exarg_T *eap)
{
  int from, to;
  int n;

  if (*eap->arg == NUL && eap->forceit) {
    // clear all marks
    clrallmarks(curbuf, os_time());
  } else if (eap->forceit) {
    emsg(_(e_invarg));
  } else if (*eap->arg == NUL) {
    emsg(_(e_argreq));
  } else {
    // clear specified marks only
    const Timestamp timestamp = os_time();
    for (char *p = eap->arg; *p != NUL; p++) {
      bool lower = ASCII_ISLOWER(*p);
      bool digit = ascii_isdigit(*p);
      if (lower || digit || ASCII_ISUPPER(*p)) {
        if (p[1] == '-') {
          // clear range of marks
          from = (uint8_t)(*p);
          to = (uint8_t)p[2];
          if (!(lower ? ASCII_ISLOWER(p[2])
                      : (digit ? ascii_isdigit(p[2])
                               : ASCII_ISUPPER(p[2])))
              || to < from) {
            semsg(_(e_invarg2), p);
            return;
          }
          p += 2;
        } else {
          // clear one lower case mark
          from = to = (uint8_t)(*p);
        }

        for (int i = from; i <= to; i++) {
          if (lower) {
            curbuf->b_namedm[i - 'a'].mark.lnum = 0;
            curbuf->b_namedm[i - 'a'].timestamp = timestamp;
          } else {
            if (digit) {
              n = i - '0' + NMARKS;
            } else {
              n = i - 'A';
            }
            namedfm[n].fmark.mark.lnum = 0;
            namedfm[n].fmark.fnum = 0;
            namedfm[n].fmark.timestamp = timestamp;
            XFREE_CLEAR(namedfm[n].fname);
          }
        }
      } else {
        switch (*p) {
        case '"':
          clear_fmark(&curbuf->b_last_cursor, timestamp);
          break;
        case '^':
          clear_fmark(&curbuf->b_last_insert, timestamp);
          break;
        case '.':
          clear_fmark(&curbuf->b_last_change, timestamp);
          break;
        case '[':
          curbuf->b_op_start.lnum = 0; break;
        case ']':
          curbuf->b_op_end.lnum = 0; break;
        case '<':
          curbuf->b_visual.vi_start.lnum = 0; break;
        case '>':
          curbuf->b_visual.vi_end.lnum = 0; break;
        case ' ':
          break;
        default:
          semsg(_(e_invarg2), p);
          return;
        }
      }
    }
  }
}

// print the jumplist
void ex_jumps(exarg_T *eap)
{
  cleanup_jumplist(curwin, true);
  // Highlight title
  msg_puts_title(_("\n jump line  col file/text"));
  for (int i = 0; i < curwin->w_jumplistlen && !got_int; i++) {
    if (curwin->w_jumplist[i].fmark.mark.lnum != 0) {
      char *name = fm_getname(&curwin->w_jumplist[i].fmark, 16);

      // Make sure to output the current indicator, even when on an wiped
      // out buffer.  ":filter" may still skip it.
      if (name == NULL && i == curwin->w_jumplistidx) {
        name = xstrdup("-invalid-");
      }
      // apply :filter /pat/ or file name not available
      if (name == NULL || message_filtered(name)) {
        xfree(name);
        continue;
      }

      msg_putchar('\n');
      if (got_int) {
        xfree(name);
        break;
      }
      snprintf(IObuff, IOSIZE, "%c %2d %5" PRIdLINENR " %4d ",
               i == curwin->w_jumplistidx ? '>' : ' ',
               i > curwin->w_jumplistidx ? i - curwin->w_jumplistidx : curwin->w_jumplistidx - i,
               curwin->w_jumplist[i].fmark.mark.lnum, curwin->w_jumplist[i].fmark.mark.col);
      msg_outtrans(IObuff, 0, false);
      msg_outtrans(name, curwin->w_jumplist[i].fmark.fnum == curbuf->b_fnum ? HLF_D : 0, false);
      xfree(name);
      os_breakcheck();
    }
  }
  if (curwin->w_jumplistidx == curwin->w_jumplistlen) {
    msg_puts("\n>");
  }
}

void ex_clearjumps(exarg_T *eap)
{
  free_jumplist(curwin);
  curwin->w_jumplistlen = 0;
  curwin->w_jumplistidx = 0;
}

// print the changelist
void ex_changes(exarg_T *eap)
{
  // Highlight title
  msg_puts_title(_("\nchange line  col text"));

  for (int i = 0; i < curbuf->b_changelistlen && !got_int; i++) {
    if (curbuf->b_changelist[i].mark.lnum != 0) {
      msg_putchar('\n');
      if (got_int) {
        break;
      }
      snprintf(IObuff, IOSIZE, "%c %3d %5" PRIdLINENR " %4d ",
               i == curwin->w_changelistidx ? '>' : ' ',
               i >
               curwin->w_changelistidx ? i - curwin->w_changelistidx : curwin->w_changelistidx - i,
               curbuf->b_changelist[i].mark.lnum,
               curbuf->b_changelist[i].mark.col);
      msg_outtrans(IObuff, 0, false);
      char *name = mark_line(&curbuf->b_changelist[i].mark, 17);
      msg_outtrans(name, HLF_D, false);
      xfree(name);
      os_breakcheck();
    }
  }
  if (curwin->w_changelistidx == curbuf->b_changelistlen) {
    msg_puts("\n>");
  }
}

#define ONE_ADJUST(add) \
  { \
    lp = add; \
    if (*lp >= line1 && *lp <= line2) { \
      if (amount == MAXLNUM) { \
        *lp = 0; \
      } else { \
        *lp += amount; \
      } \
    } else if (amount_after && *lp > line2) { \
      *lp += amount_after; \
    } \
  }

// don't delete the line, just put at first deleted line
#define ONE_ADJUST_NODEL(add) \
  { \
    lp = add; \
    if (*lp >= line1 && *lp <= line2) { \
      if (amount == MAXLNUM) { \
        *lp = line1; \
      } else { \
        *lp += amount; \
      } \
    } else if (amount_after && *lp > line2) { \
      *lp += amount_after; \
    } \
  }

// Adjust marks between "line1" and "line2" (inclusive) to move "amount" lines.
// Must be called before changed_*(), appended_lines() or deleted_lines().
// May be called before or after changing the text.
// When deleting lines "line1" to "line2", use an "amount" of MAXLNUM: The
// marks within this range are made invalid.
// If "amount_after" is non-zero adjust marks after "line2".
// Example: Delete lines 34 and 35: mark_adjust(34, 35, MAXLNUM, -2);
// Example: Insert two lines below 55: mark_adjust(56, MAXLNUM, 2, 0);
//                                 or: mark_adjust(56, 55, MAXLNUM, 2);
void mark_adjust(linenr_T line1, linenr_T line2, linenr_T amount, linenr_T amount_after,
                 ExtmarkOp op)
{
  mark_adjust_buf(curbuf, line1, line2, amount, amount_after, true, false, op);
}

// mark_adjust_nofold() does the same as mark_adjust() but without adjusting
// folds in any way. Folds must be adjusted manually by the caller.
// This is only useful when folds need to be moved in a way different to
// calling foldMarkAdjust() with arguments line1, line2, amount, amount_after,
// for an example of why this may be necessary, see do_move().
void mark_adjust_nofold(linenr_T line1, linenr_T line2, linenr_T amount, linenr_T amount_after,
                        ExtmarkOp op)
{
  mark_adjust_buf(curbuf, line1, line2, amount, amount_after, false, false, op);
}

void mark_adjust_buf(buf_T *buf, linenr_T line1, linenr_T line2, linenr_T amount,
                     linenr_T amount_after, bool adjust_folds, bool by_api, ExtmarkOp op)
{
  int fnum = buf->b_fnum;
  linenr_T *lp;
  static pos_T initpos = { 1, 0, 0 };

  if (line2 < line1 && amount_after == 0) {        // nothing to do
    return;
  }

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // named marks, lower case and upper case
    for (int i = 0; i < NMARKS; i++) {
      ONE_ADJUST(&(buf->b_namedm[i].mark.lnum));
      if (namedfm[i].fmark.fnum == fnum) {
        ONE_ADJUST_NODEL(&(namedfm[i].fmark.mark.lnum));
      }
    }
    for (int i = NMARKS; i < NGLOBALMARKS; i++) {
      if (namedfm[i].fmark.fnum == fnum) {
        ONE_ADJUST_NODEL(&(namedfm[i].fmark.mark.lnum));
      }
    }

    // last Insert position
    ONE_ADJUST(&(buf->b_last_insert.mark.lnum));

    // last change position
    ONE_ADJUST(&(buf->b_last_change.mark.lnum));

    // last cursor position, if it was set
    if (!equalpos(buf->b_last_cursor.mark, initpos)) {
      ONE_ADJUST(&(buf->b_last_cursor.mark.lnum));
    }

    // list of change positions
    for (int i = 0; i < buf->b_changelistlen; i++) {
      ONE_ADJUST_NODEL(&(buf->b_changelist[i].mark.lnum));
    }

    // Visual area
    ONE_ADJUST_NODEL(&(buf->b_visual.vi_start.lnum));
    ONE_ADJUST_NODEL(&(buf->b_visual.vi_end.lnum));

    // quickfix marks
    if (!qf_mark_adjust(buf, NULL, line1, line2, amount, amount_after)) {
      buf->b_has_qf_entry &= ~BUF_HAS_QF_ENTRY;
    }
    // location lists
    bool found_one = false;
    FOR_ALL_TAB_WINDOWS(tab, win) {
      found_one |= qf_mark_adjust(buf, win, line1, line2, amount, amount_after);
    }
    if (!found_one) {
      buf->b_has_qf_entry &= ~BUF_HAS_LL_ENTRY;
    }
  }

  if (op != kExtmarkNOOP) {
    extmark_adjust(buf, line1, line2, amount, amount_after, op);
  }

  if (curwin->w_buffer == buf) {
    // previous context mark
    ONE_ADJUST(&(curwin->w_pcmark.lnum));

    // previous pcpmark
    ONE_ADJUST(&(curwin->w_prev_pcmark.lnum));

    // saved cursor for formatting
    if (saved_cursor.lnum != 0) {
      ONE_ADJUST_NODEL(&(saved_cursor.lnum));
    }
  }

  // Adjust items in all windows related to the current buffer.
  FOR_ALL_TAB_WINDOWS(tab, win) {
    if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
      // Marks in the jumplist.  When deleting lines, this may create
      // duplicate marks in the jumplist, they will be removed later.
      for (int i = 0; i < win->w_jumplistlen; i++) {
        if (win->w_jumplist[i].fmark.fnum == fnum) {
          ONE_ADJUST_NODEL(&(win->w_jumplist[i].fmark.mark.lnum));
        }
      }
    }

    if (win->w_buffer == buf) {
      if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
        // marks in the tag stack
        for (int i = 0; i < win->w_tagstacklen; i++) {
          if (win->w_tagstack[i].fmark.fnum == fnum) {
            ONE_ADJUST_NODEL(&(win->w_tagstack[i].fmark.mark.lnum));
          }
        }
      }

      // the displayed Visual area
      if (win->w_old_cursor_lnum != 0) {
        ONE_ADJUST_NODEL(&(win->w_old_cursor_lnum));
        ONE_ADJUST_NODEL(&(win->w_old_visual_lnum));
      }

      // topline and cursor position for windows with the same buffer
      // other than the current window
      if (win != curwin || by_api) {
        if (win->w_topline >= line1 && win->w_topline <= line2) {
          if (amount == MAXLNUM) {                  // topline is deleted
            if (by_api && amount_after > line1 - line2 - 1) {
              // api: if the deleted region was replaced with new contents, topline will
              // get adjusted later as an effect of the adjusted cursor in fix_cursor()
            } else {
              win->w_topline = MAX(line1 - 1, 1);
            }
          } else if (win->w_topline > line1) {
            // keep topline on the same line, unless inserting just
            // above it (we probably want to see that line then)
            win->w_topline += amount;
          }
          win->w_topfill = 0;
          // api: display new line if inserted right at topline
          // TODO(bfredl): maybe always?
        } else if (amount_after && win->w_topline > line2 + (by_api ? 1 : 0)) {
          win->w_topline += amount_after;
          win->w_topfill = 0;
        }
      }
      if (win != curwin && !by_api) {
        if (win->w_cursor.lnum >= line1 && win->w_cursor.lnum <= line2) {
          if (amount == MAXLNUM) {         // line with cursor is deleted
            if (line1 <= 1) {
              win->w_cursor.lnum = 1;
            } else {
              win->w_cursor.lnum = line1 - 1;
            }
            win->w_cursor.col = 0;
          } else {                      // keep cursor on the same line
            win->w_cursor.lnum += amount;
          }
        } else if (amount_after && win->w_cursor.lnum > line2) {
          win->w_cursor.lnum += amount_after;
        }
      }

      if (adjust_folds) {
        foldMarkAdjust(win, line1, line2, amount, amount_after);
      }
    }
  }

  // adjust diffs
  diff_mark_adjust(buf, line1, line2, amount, amount_after);
}

// This code is used often, needs to be fast.
#define COL_ADJUST(pp) \
  { \
    posp = pp; \
    if (posp->lnum == lnum && posp->col >= mincol) { \
      posp->lnum += lnum_amount; \
      assert(col_amount > INT_MIN && col_amount <= INT_MAX); \
      if (col_amount < 0 && posp->col <= -col_amount) { \
        posp->col = 0; \
      } else if (posp->col < spaces_removed) { \
        posp->col = col_amount + spaces_removed; \
      } else { \
        posp->col += col_amount; \
      } \
    } \
  }

// Adjust marks in line "lnum" at column "mincol" and further: add
// "lnum_amount" to the line number and add "col_amount" to the column
// position.
// "spaces_removed" is the number of spaces that were removed, matters when the
// cursor is inside them.
void mark_col_adjust(linenr_T lnum, colnr_T mincol, linenr_T lnum_amount, colnr_T col_amount,
                     int spaces_removed)
{
  int fnum = curbuf->b_fnum;
  pos_T *posp;

  if ((col_amount == 0 && lnum_amount == 0) || (cmdmod.cmod_flags & CMOD_LOCKMARKS)) {
    return;     // nothing to do
  }
  // named marks, lower case and upper case
  for (int i = 0; i < NMARKS; i++) {
    COL_ADJUST(&(curbuf->b_namedm[i].mark));
    if (namedfm[i].fmark.fnum == fnum) {
      COL_ADJUST(&(namedfm[i].fmark.mark));
    }
  }
  for (int i = NMARKS; i < NGLOBALMARKS; i++) {
    if (namedfm[i].fmark.fnum == fnum) {
      COL_ADJUST(&(namedfm[i].fmark.mark));
    }
  }

  // last Insert position
  COL_ADJUST(&(curbuf->b_last_insert.mark));

  // last change position
  COL_ADJUST(&(curbuf->b_last_change.mark));

  // list of change positions
  for (int i = 0; i < curbuf->b_changelistlen; i++) {
    COL_ADJUST(&(curbuf->b_changelist[i].mark));
  }

  // Visual area
  COL_ADJUST(&(curbuf->b_visual.vi_start));
  COL_ADJUST(&(curbuf->b_visual.vi_end));

  // previous context mark
  COL_ADJUST(&(curwin->w_pcmark));

  // previous pcmark
  COL_ADJUST(&(curwin->w_prev_pcmark));

  // saved cursor for formatting
  COL_ADJUST(&saved_cursor);

  // Adjust items in all windows related to the current buffer.
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    // marks in the jumplist
    for (int i = 0; i < win->w_jumplistlen; i++) {
      if (win->w_jumplist[i].fmark.fnum == fnum) {
        COL_ADJUST(&(win->w_jumplist[i].fmark.mark));
      }
    }

    if (win->w_buffer == curbuf) {
      // marks in the tag stack
      for (int i = 0; i < win->w_tagstacklen; i++) {
        if (win->w_tagstack[i].fmark.fnum == fnum) {
          COL_ADJUST(&(win->w_tagstack[i].fmark.mark));
        }
      }

      // cursor position for other windows with the same buffer
      if (win != curwin) {
        COL_ADJUST(&win->w_cursor);
      }
    }
  }
}

// When deleting lines, this may create duplicate marks in the
// jumplist. They will be removed here for the specified window.
// When "loadfiles" is true first ensure entries have the "fnum" field set
// (this may be a bit slow).
void cleanup_jumplist(win_T *wp, bool loadfiles)
{
  int i;

  if (loadfiles) {
    // If specified, load all the files from the jump list. This is
    // needed to properly clean up duplicate entries, but will take some
    // time.
    for (i = 0; i < wp->w_jumplistlen; i++) {
      if ((wp->w_jumplist[i].fmark.fnum == 0)
          && (wp->w_jumplist[i].fmark.mark.lnum != 0)) {
        fname2fnum(&wp->w_jumplist[i]);
      }
    }
  }

  int to = 0;
  for (int from = 0; from < wp->w_jumplistlen; from++) {
    if (wp->w_jumplistidx == from) {
      wp->w_jumplistidx = to;
    }
    for (i = from + 1; i < wp->w_jumplistlen; i++) {
      if (wp->w_jumplist[i].fmark.fnum
          == wp->w_jumplist[from].fmark.fnum
          && wp->w_jumplist[from].fmark.fnum != 0
          && wp->w_jumplist[i].fmark.mark.lnum
          == wp->w_jumplist[from].fmark.mark.lnum) {
        break;
      }
    }

    bool mustfree;
    if (i >= wp->w_jumplistlen) {   // not duplicate
      mustfree = false;
    } else if (i > from + 1) {      // non-adjacent duplicate
      // jumpoptions=stack: remove duplicates only when adjacent.
      mustfree = !(jop_flags & JOP_STACK);
    } else {                        // adjacent duplicate
      mustfree = true;
    }

    if (mustfree) {
      xfree(wp->w_jumplist[from].fname);
    } else {
      if (to != from) {
        // Not using wp->w_jumplist[to++] = wp->w_jumplist[from] because
        // this way valgrind complains about overlapping source and destination
        // in memcpy() call. (clang-3.6.0, debug build with -DEXITFREE).
        wp->w_jumplist[to] = wp->w_jumplist[from];
      }
      to++;
    }
  }
  if (wp->w_jumplistidx == wp->w_jumplistlen) {
    wp->w_jumplistidx = to;
  }
  wp->w_jumplistlen = to;

  // When pointer is below last jump, remove the jump if it matches the current
  // line.  This avoids useless/phantom jumps. #9805
  if (loadfiles  // otherwise (i.e.: Shada), last entry should be kept
      && wp->w_jumplistlen && wp->w_jumplistidx == wp->w_jumplistlen) {
    const xfmark_T *fm_last = &wp->w_jumplist[wp->w_jumplistlen - 1];
    if (fm_last->fmark.fnum == curbuf->b_fnum
        && fm_last->fmark.mark.lnum == wp->w_cursor.lnum) {
      xfree(fm_last->fname);
      wp->w_jumplistlen--;
      wp->w_jumplistidx--;
    }
  }
}

// Copy the jumplist from window "from" to window "to".
void copy_jumplist(win_T *from, win_T *to)
{
  for (int i = 0; i < from->w_jumplistlen; i++) {
    to->w_jumplist[i] = from->w_jumplist[i];
    if (from->w_jumplist[i].fname != NULL) {
      to->w_jumplist[i].fname = xstrdup(from->w_jumplist[i].fname);
    }
  }
  to->w_jumplistlen = from->w_jumplistlen;
  to->w_jumplistidx = from->w_jumplistidx;
}

/// Iterate over jumplist items
///
/// @warning No jumplist-editing functions must be called while iteration is in
///          progress.
///
/// @param[in]   iter  Iterator. Pass NULL to start iteration.
/// @param[in]   win   Window for which jump list is processed.
/// @param[out]  fm    Item definition.
///
/// @return Pointer that needs to be passed to next `mark_jumplist_iter` call or
///         NULL if iteration is over.
const void *mark_jumplist_iter(const void *const iter, const win_T *const win, xfmark_T *const fm)
  FUNC_ATTR_NONNULL_ARG(2, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (iter == NULL && win->w_jumplistlen == 0) {
    *fm = (xfmark_T)INIT_XFMARK;
    return NULL;
  }
  const xfmark_T *const iter_mark = iter == NULL ? &(win->w_jumplist[0])
                                                 : (const xfmark_T *const)iter;
  *fm = *iter_mark;
  if (iter_mark == &(win->w_jumplist[win->w_jumplistlen - 1])) {
    return NULL;
  }
  return iter_mark + 1;
}

/// Iterate over global marks
///
/// @warning No mark-editing functions must be called while iteration is in
///          progress.
///
/// @param[in]   iter  Iterator. Pass NULL to start iteration.
/// @param[out]  name  Mark name.
/// @param[out]  fm    Mark definition.
///
/// @return Pointer that needs to be passed to next `mark_global_iter` call or
///         NULL if iteration is over.
const void *mark_global_iter(const void *const iter, char *const name, xfmark_T *const fm)
  FUNC_ATTR_NONNULL_ARG(2, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  *name = NUL;
  const xfmark_T *iter_mark = (iter == NULL
                               ? &(namedfm[0])
                               : (const xfmark_T *const)iter);
  while ((size_t)(iter_mark - &(namedfm[0])) < ARRAY_SIZE(namedfm)
         && !iter_mark->fmark.mark.lnum) {
    iter_mark++;
  }
  if ((size_t)(iter_mark - &(namedfm[0])) == ARRAY_SIZE(namedfm)
      || !iter_mark->fmark.mark.lnum) {
    return NULL;
  }
  size_t iter_off = (size_t)(iter_mark - &(namedfm[0]));
  *name = (char)(iter_off < NMARKS
                 ? 'A' + (char)iter_off
                 : '0' + (char)(iter_off - NMARKS));
  *fm = *iter_mark;
  while ((size_t)(++iter_mark - &(namedfm[0])) < ARRAY_SIZE(namedfm)) {
    if (iter_mark->fmark.mark.lnum) {
      return (const void *)iter_mark;
    }
  }
  return NULL;
}

/// Get next mark and its name
///
/// @param[in]      buf        Buffer for which next mark is taken.
/// @param[in,out]  mark_name  Pointer to the current mark name. Next mark name
///                            will be saved at this address as well.
///
///                            Current mark name must either be NUL, '"', '^',
///                            '.' or 'a' .. 'z'. If it is neither of these
///                            behaviour is undefined.
///
/// @return Pointer to the next mark or NULL.
static inline const fmark_T *next_buffer_mark(const buf_T *const buf, char *const mark_name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (*mark_name) {
  case NUL:
    *mark_name = '"';
    return &(buf->b_last_cursor);
  case '"':
    *mark_name = '^';
    return &(buf->b_last_insert);
  case '^':
    *mark_name = '.';
    return &(buf->b_last_change);
  case '.':
    *mark_name = 'a';
    return &(buf->b_namedm[0]);
  case 'z':
    return NULL;
  default:
    (*mark_name)++;
    return &(buf->b_namedm[*mark_name - 'a']);
  }
}

/// Iterate over buffer marks
///
/// @warning No mark-editing functions must be called while iteration is in
///          progress.
///
/// @param[in]   iter  Iterator. Pass NULL to start iteration.
/// @param[in]   buf   Buffer.
/// @param[out]  name  Mark name.
/// @param[out]  fm    Mark definition.
///
/// @return Pointer that needs to be passed to next `mark_buffer_iter` call or
///         NULL if iteration is over.
const void *mark_buffer_iter(const void *const iter, const buf_T *const buf, char *const name,
                             fmark_T *const fm)
  FUNC_ATTR_NONNULL_ARG(2, 3, 4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  *name = NUL;
  char mark_name = (char)(iter == NULL
                          ? NUL
                          : (iter == &(buf->b_last_cursor)
                             ? '"'
                             : (iter == &(buf->b_last_insert)
                                ? '^'
                                : (iter == &(buf->b_last_change)
                                   ? '.'
                                   : 'a' + (const fmark_T *)iter - &(buf->b_namedm[0])))));
  const fmark_T *iter_mark = next_buffer_mark(buf, &mark_name);
  while (iter_mark != NULL && iter_mark->mark.lnum == 0) {
    iter_mark = next_buffer_mark(buf, &mark_name);
  }
  if (iter_mark == NULL) {
    return NULL;
  }
  size_t iter_off = (size_t)(iter_mark - &(buf->b_namedm[0]));
  if (mark_name) {
    *name = mark_name;
  } else {
    *name = (char)('a' + (char)iter_off);
  }
  *fm = *iter_mark;
  return (const void *)iter_mark;
}

/// Set global mark
///
/// @param[in]  name    Mark name.
/// @param[in]  fm      Mark to be set.
/// @param[in]  update  If true then only set global mark if it was created
///                     later then existing one.
///
/// @return true on success, false on failure.
bool mark_set_global(const char name, const xfmark_T fm, const bool update)
{
  const int idx = mark_global_index(name);
  if (idx == -1) {
    return false;
  }
  xfmark_T *const fm_tgt = &(namedfm[idx]);
  if (update && fm.fmark.timestamp <= fm_tgt->fmark.timestamp) {
    return false;
  }
  if (fm_tgt->fmark.mark.lnum != 0) {
    free_xfmark(*fm_tgt);
  }
  *fm_tgt = fm;
  return true;
}

/// Set local mark
///
/// @param[in]  name    Mark name.
/// @param[in]  buf     Pointer to the buffer to set mark in.
/// @param[in]  fm      Mark to be set.
/// @param[in]  update  If true then only set global mark if it was created
///                     later then existing one.
///
/// @return true on success, false on failure.
bool mark_set_local(const char name, buf_T *const buf, const fmark_T fm, const bool update)
  FUNC_ATTR_NONNULL_ALL
{
  fmark_T *fm_tgt = NULL;
  if (ASCII_ISLOWER(name)) {
    fm_tgt = &(buf->b_namedm[name - 'a']);
  } else if (name == '"') {
    fm_tgt = &(buf->b_last_cursor);
  } else if (name == '^') {
    fm_tgt = &(buf->b_last_insert);
  } else if (name == '.') {
    fm_tgt = &(buf->b_last_change);
  } else {
    return false;
  }
  if (update && fm.timestamp <= fm_tgt->timestamp) {
    return false;
  }
  if (fm_tgt->mark.lnum != 0) {
    free_fmark(*fm_tgt);
  }
  *fm_tgt = fm;
  return true;
}

// Free items in the jumplist of window "wp".
void free_jumplist(win_T *wp)
{
  for (int i = 0; i < wp->w_jumplistlen; i++) {
    free_xfmark(wp->w_jumplist[i]);
  }
  wp->w_jumplistlen = 0;
}

void set_last_cursor(win_T *win)
{
  if (win->w_buffer != NULL) {
    RESET_FMARK(&win->w_buffer->b_last_cursor, win->w_cursor, 0, ((fmarkv_T)INIT_FMARKV));
  }
}

#if defined(EXITFREE)
void free_all_marks(void)
{
  int i;

  for (i = 0; i < NGLOBALMARKS; i++) {
    if (namedfm[i].fmark.mark.lnum != 0) {
      free_xfmark(namedfm[i]);
    }
  }
  CLEAR_FIELD(namedfm);
}
#endif

/// Adjust position to point to the first byte of a multi-byte character
///
/// If it points to a tail byte it is move backwards to the head byte.
///
/// @param[in]  buf  Buffer to adjust position in.
/// @param[out]  lp  Position to adjust.
void mark_mb_adjustpos(buf_T *buf, pos_T *lp)
  FUNC_ATTR_NONNULL_ALL
{
  if (lp->col > 0 || lp->coladd > 1) {
    const char *const p = ml_get_buf(buf, lp->lnum);
    if (*p == NUL || ml_get_buf_len(buf, lp->lnum) < lp->col) {
      lp->col = 0;
    } else {
      lp->col -= utf_head_off(p, p + lp->col);
    }
    // Reset "coladd" when the cursor would be on the right half of a
    // double-wide character.
    if (lp->coladd == 1
        && p[lp->col] != TAB
        && vim_isprintc(utf_ptr2char(p + lp->col))
        && ptr2cells(p + lp->col) > 1) {
      lp->coladd = 0;
    }
  }
}

// Add information about mark 'mname' to list 'l'
static int add_mark(list_T *l, const char *mname, const pos_T *pos, int bufnr, const char *fname)
  FUNC_ATTR_NONNULL_ARG(1, 2, 3)
{
  if (pos->lnum <= 0) {
    return OK;
  }

  dict_T *d = tv_dict_alloc();
  tv_list_append_dict(l, d);

  list_T *lpos = tv_list_alloc(kListLenMayKnow);

  tv_list_append_number(lpos, bufnr);
  tv_list_append_number(lpos, pos->lnum);
  tv_list_append_number(lpos, pos->col + 1);
  tv_list_append_number(lpos, pos->coladd);

  if (tv_dict_add_str(d, S_LEN("mark"), mname) == FAIL
      || tv_dict_add_list(d, S_LEN("pos"), lpos) == FAIL
      || (fname != NULL && tv_dict_add_str(d, S_LEN("file"), fname) == FAIL)) {
    return FAIL;
  }

  return OK;
}

/// Get information about marks local to a buffer.
///
/// @param[in] buf  Buffer to get the marks from
/// @param[out] l   List to store marks
void get_buf_local_marks(const buf_T *buf, list_T *l)
  FUNC_ATTR_NONNULL_ALL
{
  char mname[3] = "' ";

  // Marks 'a' to 'z'
  for (int i = 0; i < NMARKS; i++) {
    mname[1] = (char)('a' + i);
    add_mark(l, mname, &buf->b_namedm[i].mark, buf->b_fnum, NULL);
  }

  // Mark '' is a window local mark and not a buffer local mark
  add_mark(l, "''", &curwin->w_pcmark, curbuf->b_fnum, NULL);

  add_mark(l, "'\"", &buf->b_last_cursor.mark, buf->b_fnum, NULL);
  add_mark(l, "'[", &buf->b_op_start, buf->b_fnum, NULL);
  add_mark(l, "']", &buf->b_op_end, buf->b_fnum, NULL);
  add_mark(l, "'^", &buf->b_last_insert.mark, buf->b_fnum, NULL);
  add_mark(l, "'.", &buf->b_last_change.mark, buf->b_fnum, NULL);
  add_mark(l, "'<", &buf->b_visual.vi_start, buf->b_fnum, NULL);
  add_mark(l, "'>", &buf->b_visual.vi_end, buf->b_fnum, NULL);
}

/// Get a global mark
///
/// @note  Mark might not have it's fnum resolved.
/// @param[in]  Name of named mark
/// @param[out] Global/file mark
xfmark_T get_raw_global_mark(char name)
{
  return namedfm[mark_global_index(name)];
}

/// Get information about global marks ('A' to 'Z' and '0' to '9')
///
/// @param[out] l  List to store global marks
void get_global_marks(list_T *l)
  FUNC_ATTR_NONNULL_ALL
{
  char mname[3] = "' ";
  char *name;

  // Marks 'A' to 'Z' and '0' to '9'
  for (int i = 0; i < NMARKS + EXTRA_MARKS; i++) {
    if (namedfm[i].fmark.fnum != 0) {
      name = buflist_nr2name(namedfm[i].fmark.fnum, true, true);
    } else {
      name = namedfm[i].fname;
    }
    if (name != NULL) {
      mname[1] = i >= NMARKS ? (char)(i - NMARKS + '0') : (char)(i + 'A');

      add_mark(l, mname, &namedfm[i].fmark.mark, namedfm[i].fmark.fnum, name);
      if (namedfm[i].fmark.fnum != 0) {
        xfree(name);
      }
    }
  }
}
