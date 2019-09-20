// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * mark.c: functions for setting marks and jumping to them
 */

#include <assert.h>
#include <inttypes.h>
#include <string.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/mark.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/diff.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/search.h"
#include "nvim/sign.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/os/input.h"

/*
 * This file contains routines to maintain and manipulate marks.
 */

/*
 * If a named file mark's lnum is non-zero, it is valid.
 * If a named file mark's fnum is non-zero, it is for an existing buffer,
 * otherwise it is from .shada and namedfm[n].fname is the file name.
 * There are marks 'A - 'Z (set by user) and '0 to '9 (set when writing
 * shada).
 */

/// Global marks (marks with file number or name)
static xfmark_T namedfm[NGLOBALMARKS];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark.c.generated.h"
#endif
/*
 * Set named mark "c" at current cursor position.
 * Returns OK on success, FAIL if bad name given.
 */
int setmark(int c)
{
  return setmark_pos(c, &curwin->w_cursor, curbuf->b_fnum);
}

/// Free fmark_T item
void free_fmark(fmark_T fm)
{
  tv_dict_unref(fm.additional_data);
}

/// Free xfmark_T item
void free_xfmark(xfmark_T fm)
{
  xfree(fm.fname);
  free_fmark(fm.fmark);
}

/// Free and clear fmark_T item
void clear_fmark(fmark_T *fm)
  FUNC_ATTR_NONNULL_ALL
{
  free_fmark(*fm);
  memset(fm, 0, sizeof(*fm));
}

/*
 * Set named mark "c" to position "pos".
 * When "c" is upper case use file "fnum".
 * Returns OK on success, FAIL if bad name given.
 */
int setmark_pos(int c, pos_T *pos, int fnum)
{
  int i;

  /* Check for a special key (may cause islower() to crash). */
  if (c < 0)
    return FAIL;

  if (c == '\'' || c == '`') {
    if (pos == &curwin->w_cursor) {
      setpcmark();
      /* keep it even when the cursor doesn't move */
      curwin->w_prev_pcmark = curwin->w_pcmark;
    } else
      curwin->w_pcmark = *pos;
    return OK;
  }

  // Can't set a mark in a non-existant buffer.
  buf_T *buf = buflist_findnr(fnum);
  if (buf == NULL) {
    return FAIL;
  }

  if (c == '"') {
    RESET_FMARK(&buf->b_last_cursor, *pos, buf->b_fnum);
    return OK;
  }

  /* Allow setting '[ and '] for an autocommand that simulates reading a
   * file. */
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
    RESET_FMARK(buf->b_namedm + i, *pos, fnum);
    return OK;
  }
  if (ASCII_ISUPPER(c) || ascii_isdigit(c)) {
    if (ascii_isdigit(c)) {
      i = c - '0' + NMARKS;
    } else {
      i = c - 'A';
    }
    RESET_XFMARK(namedfm + i, *pos, fnum, NULL);
    return OK;
  }
  return FAIL;
}

/*
 * Set the previous context mark to the current position and add it to the
 * jump list.
 */
void setpcmark(void)
{
  xfmark_T    *fm;

  /* for :global the mark is set only once */
  if (global_busy || listcmd_busy || cmdmod.keepjumps)
    return;

  curwin->w_prev_pcmark = curwin->w_pcmark;
  curwin->w_pcmark = curwin->w_cursor;

  if (curwin->w_pcmark.lnum == 0) {
    curwin->w_pcmark.lnum = 1;
  }

  /* If jumplist is full: remove oldest entry */
  if (++curwin->w_jumplistlen > JUMPLISTSIZE) {
    curwin->w_jumplistlen = JUMPLISTSIZE;
    free_xfmark(curwin->w_jumplist[0]);
    memmove(&curwin->w_jumplist[0], &curwin->w_jumplist[1],
            (JUMPLISTSIZE - 1) * sizeof(curwin->w_jumplist[0]));
  }
  curwin->w_jumplistidx = curwin->w_jumplistlen;
  fm = &curwin->w_jumplist[curwin->w_jumplistlen - 1];

  SET_XFMARK(fm, curwin->w_pcmark, curbuf->b_fnum, NULL);
}

/*
 * To change context, call setpcmark(), then move the current position to
 * where ever, then call checkpcmark().  This ensures that the previous
 * context will only be changed if the cursor moved to a different line.
 * If pcmark was deleted (with "dG") the previous mark is restored.
 */
void checkpcmark(void)
{
  if (curwin->w_prev_pcmark.lnum != 0
      && (equalpos(curwin->w_pcmark, curwin->w_cursor)
          || curwin->w_pcmark.lnum == 0)) {
    curwin->w_pcmark = curwin->w_prev_pcmark;
    curwin->w_prev_pcmark.lnum = 0;             /* Show it has been checked */
  }
}

/*
 * move "count" positions in the jump list (count may be negative)
 */
pos_T *movemark(int count)
{
  pos_T       *pos;
  xfmark_T    *jmp;

  cleanup_jumplist(curwin, true);

  if (curwin->w_jumplistlen == 0)           /* nothing to jump to */
    return (pos_T *)NULL;

  for (;; ) {
    if (curwin->w_jumplistidx + count < 0
        || curwin->w_jumplistidx + count >= curwin->w_jumplistlen)
      return (pos_T *)NULL;

    /*
     * if first CTRL-O or CTRL-I command after a jump, add cursor position
     * to list.  Careful: If there are duplicates (CTRL-O immediately after
     * starting Vim on a file), another entry may have been removed.
     */
    if (curwin->w_jumplistidx == curwin->w_jumplistlen) {
      setpcmark();
      --curwin->w_jumplistidx;          /* skip the new entry */
      if (curwin->w_jumplistidx + count < 0)
        return (pos_T *)NULL;
    }

    curwin->w_jumplistidx += count;

    jmp = curwin->w_jumplist + curwin->w_jumplistidx;
    if (jmp->fmark.fnum == 0)
      fname2fnum(jmp);
    if (jmp->fmark.fnum != curbuf->b_fnum) {
      /* jump to other file */
      if (buflist_findnr(jmp->fmark.fnum) == NULL) { /* Skip this one .. */
        count += count < 0 ? -1 : 1;
        continue;
      }
      if (buflist_getfile(jmp->fmark.fnum, jmp->fmark.mark.lnum,
              0, FALSE) == FAIL)
        return (pos_T *)NULL;
      /* Set lnum again, autocommands my have changed it */
      curwin->w_cursor = jmp->fmark.mark;
      pos = (pos_T *)-1;
    } else
      pos = &(jmp->fmark.mark);
    return pos;
  }
}

/*
 * Move "count" positions in the changelist (count may be negative).
 */
pos_T *movechangelist(int count)
{
  int n;

  if (curbuf->b_changelistlen == 0)         /* nothing to jump to */
    return (pos_T *)NULL;

  n = curwin->w_changelistidx;
  if (n + count < 0) {
    if (n == 0)
      return (pos_T *)NULL;
    n = 0;
  } else if (n + count >= curbuf->b_changelistlen) {
    if (n == curbuf->b_changelistlen - 1)
      return (pos_T *)NULL;
    n = curbuf->b_changelistlen - 1;
  } else
    n += count;
  curwin->w_changelistidx = n;
  return &(curbuf->b_changelist[n].mark);
}

/*
 * Find mark "c" in buffer pointed to by "buf".
 * If "changefile" is TRUE it's allowed to edit another file for '0, 'A, etc.
 * If "fnum" is not NULL store the fnum there for '0, 'A etc., don't edit
 * another file.
 * Returns:
 * - pointer to pos_T if found.  lnum is 0 when mark not set, -1 when mark is
 *   in another file which can't be gotten. (caller needs to check lnum!)
 * - NULL if there is no mark called 'c'.
 * - -1 if mark is in other file and jumped there (only if changefile is TRUE)
 */
pos_T *getmark_buf(buf_T *buf, int c, int changefile)
{
  return getmark_buf_fnum(buf, c, changefile, NULL);
}

pos_T *getmark(int c, int changefile)
{
  return getmark_buf_fnum(curbuf, c, changefile, NULL);
}

pos_T *getmark_buf_fnum(buf_T *buf, int c, int changefile, int *fnum)
{
  pos_T               *posp;
  pos_T               *startp, *endp;
  static pos_T pos_copy;

  posp = NULL;

  /* Check for special key, can't be a mark name and might cause islower()
   * to crash. */
  if (c < 0)
    return posp;
  if (c > '~') {                        // check for islower()/isupper()
  } else if (c == '\'' || c == '`') {   // previous context mark
    pos_copy = curwin->w_pcmark;        // need to make a copy because
    posp = &pos_copy;                   //   w_pcmark may be changed soon
  } else if (c == '"') {                // to pos when leaving buffer
    posp = &(buf->b_last_cursor.mark);
  } else if (c == '^') {                // to where Insert mode stopped
    posp = &(buf->b_last_insert.mark);
  } else if (c == '.') {                // to where last change was made
    posp = &(buf->b_last_change.mark);
  } else if (c == '[') {                // to start of previous operator
    posp = &(buf->b_op_start);
  } else if (c == ']') {                // to end of previous operator
    posp = &(buf->b_op_end);
  } else if (c == '{' || c == '}') {    // to previous/next paragraph
    pos_T pos;
    oparg_T oa;
    int slcb = listcmd_busy;

    pos = curwin->w_cursor;
    listcmd_busy = TRUE;            /* avoid that '' is changed */
    if (findpar(&oa.inclusive,
            c == '}' ? FORWARD : BACKWARD, 1L, NUL, FALSE)) {
      pos_copy = curwin->w_cursor;
      posp = &pos_copy;
    }
    curwin->w_cursor = pos;
    listcmd_busy = slcb;
  } else if (c == '(' || c == ')') {  /* to previous/next sentence */
    pos_T pos;
    int slcb = listcmd_busy;

    pos = curwin->w_cursor;
    listcmd_busy = TRUE;            /* avoid that '' is changed */
    if (findsent(c == ')' ? FORWARD : BACKWARD, 1L)) {
      pos_copy = curwin->w_cursor;
      posp = &pos_copy;
    }
    curwin->w_cursor = pos;
    listcmd_busy = slcb;
  } else if (c == '<' || c == '>') {  /* start/end of visual area */
    startp = &buf->b_visual.vi_start;
    endp = &buf->b_visual.vi_end;
    if (((c == '<') == lt(*startp, *endp) || endp->lnum == 0)
        && startp->lnum != 0) {
      posp = startp;
    } else {
      posp = endp;
    }

    // For Visual line mode, set mark at begin or end of line
    if (buf->b_visual.vi_mode == 'V') {
      pos_copy = *posp;
      posp = &pos_copy;
      if (c == '<')
        pos_copy.col = 0;
      else
        pos_copy.col = MAXCOL;
      pos_copy.coladd = 0;
    }
  } else if (ASCII_ISLOWER(c)) {      /* normal named mark */
    posp = &(buf->b_namedm[c - 'a'].mark);
  } else if (ASCII_ISUPPER(c) || ascii_isdigit(c)) {    /* named file mark */
    if (ascii_isdigit(c))
      c = c - '0' + NMARKS;
    else
      c -= 'A';
    posp = &(namedfm[c].fmark.mark);

    if (namedfm[c].fmark.fnum == 0) {
      fname2fnum(&namedfm[c]);
    }

    if (fnum != NULL)
      *fnum = namedfm[c].fmark.fnum;
    else if (namedfm[c].fmark.fnum != buf->b_fnum) {
      /* mark is in another file */
      posp = &pos_copy;

      if (namedfm[c].fmark.mark.lnum != 0
          && changefile && namedfm[c].fmark.fnum) {
        if (buflist_getfile(namedfm[c].fmark.fnum,
                (linenr_T)1, GETF_SETMARK, FALSE) == OK) {
          /* Set the lnum now, autocommands could have changed it */
          curwin->w_cursor = namedfm[c].fmark.mark;
          return (pos_T *)-1;
        }
        pos_copy.lnum = -1;             /* can't get file */
      } else
        pos_copy.lnum = 0;              /* mark exists, but is not valid in
                                           current buffer */
    }
  }

  return posp;
}

/*
 * Search for the next named mark in the current file.
 *
 * Returns pointer to pos_T of the next mark or NULL if no mark is found.
 */
pos_T *
getnextmark (
    pos_T *startpos,          /* where to start */
    int dir,                /* direction for search */
    int begin_line
)
{
  int i;
  pos_T       *result = NULL;
  pos_T pos;

  pos = *startpos;

  /* When searching backward and leaving the cursor on the first non-blank,
   * position must be in a previous line.
   * When searching forward and leaving the cursor on the first non-blank,
   * position must be in a next line. */
  if (dir == BACKWARD && begin_line)
    pos.col = 0;
  else if (dir == FORWARD && begin_line)
    pos.col = MAXCOL;

  for (i = 0; i < NMARKS; i++) {
    if (curbuf->b_namedm[i].mark.lnum > 0) {
      if (dir == FORWARD) {
        if ((result == NULL || lt(curbuf->b_namedm[i].mark, *result))
            && lt(pos, curbuf->b_namedm[i].mark))
          result = &curbuf->b_namedm[i].mark;
      } else {
        if ((result == NULL || lt(*result, curbuf->b_namedm[i].mark))
            && lt(curbuf->b_namedm[i].mark, pos))
          result = &curbuf->b_namedm[i].mark;
      }
    }
  }

  return result;
}

/*
 * For an xtended filemark: set the fnum from the fname.
 * This is used for marks obtained from the .shada file.  It's postponed
 * until the mark is used to avoid a long startup delay.
 */
static void fname2fnum(xfmark_T *fm)
{
  char_u *p;

  if (fm->fname != NULL) {
    /*
     * First expand "~/" in the file name to the home directory.
     * Don't expand the whole name, it may contain other '~' chars.
     */
    if (fm->fname[0] == '~' && (fm->fname[1] == '/'
#ifdef BACKSLASH_IN_FILENAME
                                || fm->fname[1] == '\\'
#endif
                                )) {
      int len;

      expand_env((char_u *)"~/", NameBuff, MAXPATHL);
      len = (int)STRLEN(NameBuff);
      STRLCPY(NameBuff + len, fm->fname + 2, MAXPATHL - len);
    } else
      STRLCPY(NameBuff, fm->fname, MAXPATHL);

    /* Try to shorten the file name. */
    os_dirname(IObuff, IOSIZE);
    p = path_shorten_fname(NameBuff, IObuff);

    // buflist_new() will call fmarks_check_names()
    (void)buflist_new(NameBuff, p, (linenr_T)1, 0);
  }
}

/*
 * Check all file marks for a name that matches the file name in buf.
 * May replace the name with an fnum.
 * Used for marks that come from the .shada file.
 */
void fmarks_check_names(buf_T *buf)
{
  char_u      *name = buf->b_ffname;
  int i;

  if (buf->b_ffname == NULL)
    return;

  for (i = 0; i < NGLOBALMARKS; ++i)
    fmarks_check_one(&namedfm[i], name, buf);

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    for (i = 0; i < wp->w_jumplistlen; ++i) {
      fmarks_check_one(&wp->w_jumplist[i], name, buf);
    }
  }
}

static void fmarks_check_one(xfmark_T *fm, char_u *name, buf_T *buf)
{
  if (fm->fmark.fnum == 0
      && fm->fname != NULL
      && fnamecmp(name, fm->fname) == 0) {
    fm->fmark.fnum = buf->b_fnum;
    XFREE_CLEAR(fm->fname);
  }
}

/*
 * Check a if a position from a mark is valid.
 * Give and error message and return FAIL if not.
 */
int check_mark(pos_T *pos)
{
  if (pos == NULL) {
    EMSG(_(e_umark));
    return FAIL;
  }
  if (pos->lnum <= 0) {
    /* lnum is negative if mark is in another file can can't get that
     * file, error message already give then. */
    if (pos->lnum == 0)
      EMSG(_(e_marknotset));
    return FAIL;
  }
  if (pos->lnum > curbuf->b_ml.ml_line_count) {
    EMSG(_(e_markinval));
    return FAIL;
  }
  return OK;
}

/// Clear all marks and change list in the given buffer
///
/// Used mainly when trashing the entire buffer during ":e" type commands.
///
/// @param[out]  buf  Buffer to clear marks in.
void clrallmarks(buf_T *const buf)
  FUNC_ATTR_NONNULL_ALL
{
  for (size_t i = 0; i < NMARKS; i++) {
    clear_fmark(&buf->b_namedm[i]);
  }
  clear_fmark(&buf->b_last_cursor);
  buf->b_last_cursor.mark.lnum = 1;
  clear_fmark(&buf->b_last_insert);
  clear_fmark(&buf->b_last_change);
  buf->b_op_start.lnum = 0;  // start/end op mark cleared
  buf->b_op_end.lnum = 0;
  for (int i = 0; i < buf->b_changelistlen; i++) {
    clear_fmark(&buf->b_changelist[i]);
  }
  buf->b_changelistlen = 0;
}

/*
 * Get name of file from a filemark.
 * When it's in the current buffer, return the text at the mark.
 * Returns an allocated string.
 */
char_u *fm_getname(fmark_T *fmark, int lead_len)
{
  if (fmark->fnum == curbuf->b_fnum)                /* current buffer */
    return mark_line(&(fmark->mark), lead_len);
  return buflist_nr2name(fmark->fnum, FALSE, TRUE);
}

/*
 * Return the line at mark "mp".  Truncate to fit in window.
 * The returned string has been allocated.
 */
static char_u *mark_line(pos_T *mp, int lead_len)
{
  char_u      *s, *p;
  int len;

  if (mp->lnum == 0 || mp->lnum > curbuf->b_ml.ml_line_count)
    return vim_strsave((char_u *)"-invalid-");
  assert(Columns >= 0 && (size_t)Columns <= SIZE_MAX);
  // Allow for up to 5 bytes per character.
  s = vim_strnsave(skipwhite(ml_get(mp->lnum)), (size_t)Columns * 5);

  // Truncate the line to fit it in the window
  len = 0;
  for (p = s; *p != NUL; MB_PTR_ADV(p)) {
    len += ptr2cells(p);
    if (len >= Columns - lead_len)
      break;
  }
  *p = NUL;
  return s;
}

/*
 * print the marks
 */
void ex_marks(exarg_T *eap)
{
  char_u      *arg = eap->arg;
  int i;
  char_u      *name;

  if (arg != NULL && *arg == NUL)
    arg = NULL;

  show_one_mark('\'', arg, &curwin->w_pcmark, NULL, true);
  for (i = 0; i < NMARKS; ++i)
    show_one_mark(i + 'a', arg, &curbuf->b_namedm[i].mark, NULL, true);
  for (i = 0; i < NGLOBALMARKS; ++i) {
    if (namedfm[i].fmark.fnum != 0)
      name = fm_getname(&namedfm[i].fmark, 15);
    else
      name = namedfm[i].fname;
    if (name != NULL) {
      show_one_mark(i >= NMARKS ? i - NMARKS + '0' : i + 'A',
          arg, &namedfm[i].fmark.mark, name,
          namedfm[i].fmark.fnum == curbuf->b_fnum);
      if (namedfm[i].fmark.fnum != 0)
        xfree(name);
    }
  }
  show_one_mark('"', arg, &curbuf->b_last_cursor.mark, NULL, true);
  show_one_mark('[', arg, &curbuf->b_op_start, NULL, true);
  show_one_mark(']', arg, &curbuf->b_op_end, NULL, true);
  show_one_mark('^', arg, &curbuf->b_last_insert.mark, NULL, true);
  show_one_mark('.', arg, &curbuf->b_last_change.mark, NULL, true);
  show_one_mark('<', arg, &curbuf->b_visual.vi_start, NULL, true);
  show_one_mark('>', arg, &curbuf->b_visual.vi_end, NULL, true);
  show_one_mark(-1, arg, NULL, NULL, false);
}

static void
show_one_mark(
    int c,
    char_u *arg,
    pos_T *p,
    char_u *name_arg,
    int current                   // in current file
)
{
  static bool did_title = false;
  bool mustfree = false;
  char_u *name = name_arg;

  if (c == -1) {  // finish up
    if (did_title) {
      did_title = false;
    } else {
      if (arg == NULL) {
        MSG(_("No marks set"));
      } else {
        EMSG2(_("E283: No marks matching \"%s\""), arg);
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
        snprintf((char *)IObuff, IOSIZE, " %c %6ld %4d ", c, p->lnum, p->col);
        msg_outtrans(IObuff);
        if (name != NULL) {
          msg_outtrans_attr(name, current ? HL_ATTR(HLF_D) : 0);
        }
      }
      ui_flush();  // show one line at a time
    }
    if (mustfree) {
      xfree(name);
    }
  }
}

/*
 * ":delmarks[!] [marks]"
 */
void ex_delmarks(exarg_T *eap)
{
  char_u      *p;
  int from, to;
  int i;
  int lower;
  int digit;
  int n;

  if (*eap->arg == NUL && eap->forceit)
    /* clear all marks */
    clrallmarks(curbuf);
  else if (eap->forceit)
    EMSG(_(e_invarg));
  else if (*eap->arg == NUL)
    EMSG(_(e_argreq));
  else {
    /* clear specified marks only */
    for (p = eap->arg; *p != NUL; ++p) {
      lower = ASCII_ISLOWER(*p);
      digit = ascii_isdigit(*p);
      if (lower || digit || ASCII_ISUPPER(*p)) {
        if (p[1] == '-') {
          /* clear range of marks */
          from = *p;
          to = p[2];
          if (!(lower ? ASCII_ISLOWER(p[2])
                : (digit ? ascii_isdigit(p[2])
                   : ASCII_ISUPPER(p[2])))
              || to < from) {
            EMSG2(_(e_invarg2), p);
            return;
          }
          p += 2;
        } else
          /* clear one lower case mark */
          from = to = *p;

        for (i = from; i <= to; ++i) {
          if (lower) {
            curbuf->b_namedm[i - 'a'].mark.lnum = 0;
          } else {
            if (digit) {
              n = i - '0' + NMARKS;
            } else {
              n = i - 'A';
            }
            namedfm[n].fmark.mark.lnum = 0;
            XFREE_CLEAR(namedfm[n].fname);
          }
        }
      } else
        switch (*p) {
        case '"': CLEAR_FMARK(&curbuf->b_last_cursor); break;
        case '^': CLEAR_FMARK(&curbuf->b_last_insert); break;
        case '.': CLEAR_FMARK(&curbuf->b_last_change); break;
        case '[': curbuf->b_op_start.lnum    = 0; break;
        case ']': curbuf->b_op_end.lnum      = 0; break;
        case '<': curbuf->b_visual.vi_start.lnum = 0; break;
        case '>': curbuf->b_visual.vi_end.lnum   = 0; break;
        case ' ': break;
        default:  EMSG2(_(e_invarg2), p);
          return;
        }
    }
  }
}

/*
 * print the jumplist
 */
void ex_jumps(exarg_T *eap)
{
  int i;
  char_u      *name;

  cleanup_jumplist(curwin, true);
  // Highlight title
  MSG_PUTS_TITLE(_("\n jump line  col file/text"));
  for (i = 0; i < curwin->w_jumplistlen && !got_int; ++i) {
    if (curwin->w_jumplist[i].fmark.mark.lnum != 0) {
      name = fm_getname(&curwin->w_jumplist[i].fmark, 16);

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
      sprintf((char *)IObuff, "%c %2d %5ld %4d ",
          i == curwin->w_jumplistidx ? '>' : ' ',
          i > curwin->w_jumplistidx ? i - curwin->w_jumplistidx
          : curwin->w_jumplistidx - i,
          curwin->w_jumplist[i].fmark.mark.lnum,
          curwin->w_jumplist[i].fmark.mark.col);
      msg_outtrans(IObuff);
      msg_outtrans_attr(name,
                        curwin->w_jumplist[i].fmark.fnum == curbuf->b_fnum
                        ? HL_ATTR(HLF_D) : 0);
      xfree(name);
      os_breakcheck();
    }
    ui_flush();
  }
  if (curwin->w_jumplistidx == curwin->w_jumplistlen)
    MSG_PUTS("\n>");
}

void ex_clearjumps(exarg_T *eap)
{
  free_jumplist(curwin);
  curwin->w_jumplistlen = 0;
  curwin->w_jumplistidx = 0;
}

/*
 * print the changelist
 */
void ex_changes(exarg_T *eap)
{
  int i;
  char_u      *name;

  // Highlight title
  MSG_PUTS_TITLE(_("\nchange line  col text"));

  for (i = 0; i < curbuf->b_changelistlen && !got_int; ++i) {
    if (curbuf->b_changelist[i].mark.lnum != 0) {
      msg_putchar('\n');
      if (got_int)
        break;
      sprintf((char *)IObuff, "%c %3d %5ld %4d ",
          i == curwin->w_changelistidx ? '>' : ' ',
          i > curwin->w_changelistidx ? i - curwin->w_changelistidx
          : curwin->w_changelistidx - i,
          (long)curbuf->b_changelist[i].mark.lnum,
          curbuf->b_changelist[i].mark.col);
      msg_outtrans(IObuff);
      name = mark_line(&curbuf->b_changelist[i].mark, 17);
      msg_outtrans_attr(name, HL_ATTR(HLF_D));
      xfree(name);
      os_breakcheck();
    }
    ui_flush();
  }
  if (curwin->w_changelistidx == curbuf->b_changelistlen)
    MSG_PUTS("\n>");
}

#define one_adjust(add) \
  { \
    lp = add; \
    if (*lp >= line1 && *lp <= line2) \
    { \
      if (amount == MAXLNUM) \
        *lp = 0; \
      else \
        *lp += amount; \
    } \
    else if (amount_after && *lp > line2) \
      *lp += amount_after; \
  }

/* don't delete the line, just put at first deleted line */
#define one_adjust_nodel(add) \
  { \
    lp = add; \
    if (*lp >= line1 && *lp <= line2) \
    { \
      if (amount == MAXLNUM) \
        *lp = line1; \
      else \
        *lp += amount; \
    } \
    else if (amount_after && *lp > line2) \
      *lp += amount_after; \
  }

/*
 * Adjust marks between line1 and line2 (inclusive) to move 'amount' lines.
 * Must be called before changed_*(), appended_lines() or deleted_lines().
 * May be called before or after changing the text.
 * When deleting lines line1 to line2, use an 'amount' of MAXLNUM: The marks
 * within this range are made invalid.
 * If 'amount_after' is non-zero adjust marks after line2.
 * Example: Delete lines 34 and 35: mark_adjust(34, 35, MAXLNUM, -2);
 * Example: Insert two lines below 55: mark_adjust(56, MAXLNUM, 2, 0);
 *				   or: mark_adjust(56, 55, MAXLNUM, 2);
 */
void mark_adjust(linenr_T line1,
                 linenr_T line2,
                 long amount,
                 long amount_after,
                 bool end_temp)
{
  mark_adjust_internal(line1, line2, amount, amount_after, true, end_temp);
}

// mark_adjust_nofold() does the same as mark_adjust() but without adjusting
// folds in any way. Folds must be adjusted manually by the caller.
// This is only useful when folds need to be moved in a way different to
// calling foldMarkAdjust() with arguments line1, line2, amount, amount_after,
// for an example of why this may be necessary, see do_move().
void mark_adjust_nofold(linenr_T line1, linenr_T line2, long amount,
                        long amount_after, bool end_temp)
{
  mark_adjust_internal(line1, line2, amount, amount_after, false, end_temp);
}

static void mark_adjust_internal(linenr_T line1, linenr_T line2,
                                 long amount, long amount_after,
                                 bool adjust_folds, bool end_temp)
{
  int i;
  int fnum = curbuf->b_fnum;
  linenr_T    *lp;
  static pos_T initpos = { 1, 0, 0 };

  if (line2 < line1 && amount_after == 0L)          /* nothing to do */
    return;

  if (!cmdmod.lockmarks) {
    /* named marks, lower case and upper case */
    for (i = 0; i < NMARKS; i++) {
      one_adjust(&(curbuf->b_namedm[i].mark.lnum));
      if (namedfm[i].fmark.fnum == fnum)
        one_adjust_nodel(&(namedfm[i].fmark.mark.lnum));
    }
    for (i = NMARKS; i < NGLOBALMARKS; i++) {
      if (namedfm[i].fmark.fnum == fnum)
        one_adjust_nodel(&(namedfm[i].fmark.mark.lnum));
    }

    /* last Insert position */
    one_adjust(&(curbuf->b_last_insert.mark.lnum));

    /* last change position */
    one_adjust(&(curbuf->b_last_change.mark.lnum));

    /* last cursor position, if it was set */
    if (!equalpos(curbuf->b_last_cursor.mark, initpos))
      one_adjust(&(curbuf->b_last_cursor.mark.lnum));


    /* list of change positions */
    for (i = 0; i < curbuf->b_changelistlen; ++i)
      one_adjust_nodel(&(curbuf->b_changelist[i].mark.lnum));

    /* Visual area */
    one_adjust_nodel(&(curbuf->b_visual.vi_start.lnum));
    one_adjust_nodel(&(curbuf->b_visual.vi_end.lnum));

    // quickfix marks
    if (!qf_mark_adjust(NULL, line1, line2, amount, amount_after)) {
      curbuf->b_has_qf_entry &= ~BUF_HAS_QF_ENTRY;
    }
    // location lists
    bool found_one = false;
    FOR_ALL_TAB_WINDOWS(tab, win) {
      found_one |= qf_mark_adjust(win, line1, line2, amount, amount_after);
    }
    if (!found_one) {
      curbuf->b_has_qf_entry &= ~BUF_HAS_LL_ENTRY;
    }

    sign_mark_adjust(line1, line2, amount, amount_after);
    bufhl_mark_adjust(curbuf, line1, line2, amount, amount_after, end_temp);
  }

  /* previous context mark */
  one_adjust(&(curwin->w_pcmark.lnum));

  /* previous pcmark */
  one_adjust(&(curwin->w_prev_pcmark.lnum));

  /* saved cursor for formatting */
  if (saved_cursor.lnum != 0)
    one_adjust_nodel(&(saved_cursor.lnum));

  /*
   * Adjust items in all windows related to the current buffer.
   */
  FOR_ALL_TAB_WINDOWS(tab, win) {
    if (!cmdmod.lockmarks) {
      /* Marks in the jumplist.  When deleting lines, this may create
       * duplicate marks in the jumplist, they will be removed later. */
      for (i = 0; i < win->w_jumplistlen; ++i) {
        if (win->w_jumplist[i].fmark.fnum == fnum) {
          one_adjust_nodel(&(win->w_jumplist[i].fmark.mark.lnum));
        }
      }
    }

    if (win->w_buffer == curbuf) {
      if (!cmdmod.lockmarks) {
        /* marks in the tag stack */
        for (i = 0; i < win->w_tagstacklen; i++) {
          if (win->w_tagstack[i].fmark.fnum == fnum) {
            one_adjust_nodel(&(win->w_tagstack[i].fmark.mark.lnum));
          }
        }
      }

      /* the displayed Visual area */
      if (win->w_old_cursor_lnum != 0) {
        one_adjust_nodel(&(win->w_old_cursor_lnum));
        one_adjust_nodel(&(win->w_old_visual_lnum));
      }

      /* topline and cursor position for windows with the same buffer
       * other than the current window */
      if (win != curwin) {
        if (win->w_topline >= line1 && win->w_topline <= line2) {
          if (amount == MAXLNUM) {                  /* topline is deleted */
            if (line1 <= 1) {
              win->w_topline = 1;
            } else {
              win->w_topline = line1 - 1;
            }
          } else {                      /* keep topline on the same line */
            win->w_topline += amount;
          }
          win->w_topfill = 0;
        } else if (amount_after && win->w_topline > line2) {
          win->w_topline += amount_after;
          win->w_topfill = 0;
        }
        if (win->w_cursor.lnum >= line1 && win->w_cursor.lnum <= line2) {
          if (amount == MAXLNUM) {         /* line with cursor is deleted */
            if (line1 <= 1) {
              win->w_cursor.lnum = 1;
            } else {
              win->w_cursor.lnum = line1 - 1;
            }
            win->w_cursor.col = 0;
          } else {                      /* keep cursor on the same line */
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

  /* adjust diffs */
  diff_mark_adjust(line1, line2, amount, amount_after);
}

/* This code is used often, needs to be fast. */
#define col_adjust(pp) \
  { \
    posp = pp; \
    if (posp->lnum == lnum && posp->col >= mincol) \
    { \
      posp->lnum += lnum_amount; \
      assert(col_amount > INT_MIN && col_amount <= INT_MAX); \
      if (col_amount < 0 && posp->col <= (colnr_T)-col_amount) { \
        posp->col = 0; \
      } else if (posp->col < spaces_removed) { \
        posp->col = (int)col_amount + spaces_removed; \
      } else { \
        posp->col += (colnr_T)col_amount; \
      } \
    } \
  }

// Adjust marks in line "lnum" at column "mincol" and further: add
// "lnum_amount" to the line number and add "col_amount" to the column
// position.
// "spaces_removed" is the number of spaces that were removed, matters when the
// cursor is inside them.
void mark_col_adjust(
    linenr_T lnum, colnr_T mincol, long lnum_amount, long col_amount,
    int spaces_removed)
{
  int i;
  int fnum = curbuf->b_fnum;
  pos_T       *posp;

  if ((col_amount == 0L && lnum_amount == 0L) || cmdmod.lockmarks)
    return;     /* nothing to do */

  /* named marks, lower case and upper case */
  for (i = 0; i < NMARKS; i++) {
    col_adjust(&(curbuf->b_namedm[i].mark));
    if (namedfm[i].fmark.fnum == fnum)
      col_adjust(&(namedfm[i].fmark.mark));
  }
  for (i = NMARKS; i < NGLOBALMARKS; i++) {
    if (namedfm[i].fmark.fnum == fnum)
      col_adjust(&(namedfm[i].fmark.mark));
  }

  /* last Insert position */
  col_adjust(&(curbuf->b_last_insert.mark));

  /* last change position */
  col_adjust(&(curbuf->b_last_change.mark));

  /* list of change positions */
  for (i = 0; i < curbuf->b_changelistlen; ++i)
    col_adjust(&(curbuf->b_changelist[i].mark));

  /* Visual area */
  col_adjust(&(curbuf->b_visual.vi_start));
  col_adjust(&(curbuf->b_visual.vi_end));

  /* previous context mark */
  col_adjust(&(curwin->w_pcmark));

  /* previous pcmark */
  col_adjust(&(curwin->w_prev_pcmark));

  /* saved cursor for formatting */
  col_adjust(&saved_cursor);

  /*
   * Adjust items in all windows related to the current buffer.
   */
  FOR_ALL_WINDOWS_IN_TAB(win, curtab) {
    /* marks in the jumplist */
    for (i = 0; i < win->w_jumplistlen; ++i) {
      if (win->w_jumplist[i].fmark.fnum == fnum) {
        col_adjust(&(win->w_jumplist[i].fmark.mark));
      }
    }

    if (win->w_buffer == curbuf) {
      /* marks in the tag stack */
      for (i = 0; i < win->w_tagstacklen; i++) {
        if (win->w_tagstack[i].fmark.fnum == fnum) {
          col_adjust(&(win->w_tagstack[i].fmark.mark));
        }
      }

      /* cursor position for other windows with the same buffer */
      if (win != curwin) {
        col_adjust(&win->w_cursor);
      }
    }
  }
}

// When deleting lines, this may create duplicate marks in the
// jumplist. They will be removed here for the specified window.
// When "checktail" is true, removes tail jump if it matches current position.
void cleanup_jumplist(win_T *wp, bool checktail)
{
  int i;

  // Load all the files from the jump list. This is
  // needed to properly clean up duplicate entries, but will take some
  // time.
  for (i = 0; i < wp->w_jumplistlen; i++) {
    if ((wp->w_jumplist[i].fmark.fnum == 0)
        && (wp->w_jumplist[i].fmark.mark.lnum != 0)) {
      fname2fnum(&wp->w_jumplist[i]);
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
    if (i >= wp->w_jumplistlen) {  // no duplicate
      if (to != from) {
        // Not using wp->w_jumplist[to++] = wp->w_jumplist[from] because
        // this way valgrind complains about overlapping source and destination
        // in memcpy() call. (clang-3.6.0, debug build with -DEXITFREE).
        wp->w_jumplist[to] = wp->w_jumplist[from];
      }
      to++;
    } else {
      xfree(wp->w_jumplist[from].fname);
    }
  }
  if (wp->w_jumplistidx == wp->w_jumplistlen) {
    wp->w_jumplistidx = to;
  }
  wp->w_jumplistlen = to;

  // When pointer is below last jump, remove the jump if it matches the current
  // line.  This avoids useless/phantom jumps. #9805
  if (checktail && wp->w_jumplistlen
      && wp->w_jumplistidx == wp->w_jumplistlen) {
    const xfmark_T *fm_last = &wp->w_jumplist[wp->w_jumplistlen - 1];
    if (fm_last->fmark.fnum == curbuf->b_fnum
        && fm_last->fmark.mark.lnum == wp->w_cursor.lnum) {
      xfree(fm_last->fname);
      wp->w_jumplistlen--;
      wp->w_jumplistidx--;
    }
  }
}

/*
 * Copy the jumplist from window "from" to window "to".
 */
void copy_jumplist(win_T *from, win_T *to)
{
  int i;

  for (i = 0; i < from->w_jumplistlen; ++i) {
    to->w_jumplist[i] = from->w_jumplist[i];
    if (from->w_jumplist[i].fname != NULL)
      to->w_jumplist[i].fname = vim_strsave(from->w_jumplist[i].fname);
  }
  to->w_jumplistlen = from->w_jumplistlen;
  to->w_jumplistidx = from->w_jumplistidx;
}

/// Iterate over jumplist items
///
/// @warning No jumplist-editing functions must be run while iteration is in
///          progress.
///
/// @param[in]   iter  Iterator. Pass NULL to start iteration.
/// @param[in]   win   Window for which jump list is processed.
/// @param[out]  fm    Item definition.
///
/// @return Pointer that needs to be passed to next `mark_jumplist_iter` call or
///         NULL if iteration is over.
const void *mark_jumplist_iter(const void *const iter, const win_T *const win,
                               xfmark_T *const fm)
  FUNC_ATTR_NONNULL_ARG(2, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (iter == NULL && win->w_jumplistlen == 0) {
    *fm = (xfmark_T) {{{0, 0, 0}, 0, 0, NULL}, NULL};
    return NULL;
  }
  const xfmark_T *const iter_mark =
      (iter == NULL
       ? &(win->w_jumplist[0])
       : (const xfmark_T *const) iter);
  *fm = *iter_mark;
  if (iter_mark == &(win->w_jumplist[win->w_jumplistlen - 1])) {
    return NULL;
  } else {
    return iter_mark + 1;
  }
}

/// Iterate over global marks
///
/// @warning No mark-editing functions must be run while iteration is in
///          progress.
///
/// @param[in]   iter  Iterator. Pass NULL to start iteration.
/// @param[out]  name  Mark name.
/// @param[out]  fm    Mark definition.
///
/// @return Pointer that needs to be passed to next `mark_global_iter` call or
///         NULL if iteration is over.
const void *mark_global_iter(const void *const iter, char *const name,
                             xfmark_T *const fm)
  FUNC_ATTR_NONNULL_ARG(2, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  *name = NUL;
  const xfmark_T *iter_mark = (iter == NULL
                               ? &(namedfm[0])
                               : (const xfmark_T *const) iter);
  while ((size_t) (iter_mark - &(namedfm[0])) < ARRAY_SIZE(namedfm)
         && !iter_mark->fmark.mark.lnum) {
    iter_mark++;
  }
  if ((size_t) (iter_mark - &(namedfm[0])) == ARRAY_SIZE(namedfm)
      || !iter_mark->fmark.mark.lnum) {
    return NULL;
  }
  size_t iter_off = (size_t) (iter_mark - &(namedfm[0]));
  *name = (char) (iter_off < NMARKS
                  ? 'A' + (char) iter_off
                  : '0' + (char) (iter_off - NMARKS));
  *fm = *iter_mark;
  while ((size_t) (++iter_mark - &(namedfm[0])) < ARRAY_SIZE(namedfm)) {
    if (iter_mark->fmark.mark.lnum) {
      return (const void *) iter_mark;
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
static inline const fmark_T *next_buffer_mark(const buf_T *const buf,
                                              char *const mark_name)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (*mark_name) {
    case NUL: {
      *mark_name = '"';
      return &(buf->b_last_cursor);
    }
    case '"': {
      *mark_name = '^';
      return &(buf->b_last_insert);
    }
    case '^': {
      *mark_name = '.';
      return &(buf->b_last_change);
    }
    case '.': {
      *mark_name = 'a';
      return &(buf->b_namedm[0]);
    }
    case 'z': {
      return NULL;
    }
    default: {
      (*mark_name)++;
      return &(buf->b_namedm[*mark_name - 'a']);
    }
  }
}

/// Iterate over buffer marks
///
/// @warning No mark-editing functions must be run while iteration is in
///          progress.
///
/// @param[in]   iter  Iterator. Pass NULL to start iteration.
/// @param[in]   buf   Buffer.
/// @param[out]  name  Mark name.
/// @param[out]  fm    Mark definition.
///
/// @return Pointer that needs to be passed to next `mark_buffer_iter` call or
///         NULL if iteration is over.
const void *mark_buffer_iter(const void *const iter, const buf_T *const buf,
                             char *const name, fmark_T *const fm)
  FUNC_ATTR_NONNULL_ARG(2, 3, 4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  *name = NUL;
  char mark_name = (char) (iter == NULL
                           ? NUL
                           : (iter == &(buf->b_last_cursor)
                              ? '"'
                              : (iter == &(buf->b_last_insert)
                                 ? '^'
                                 : (iter == &(buf->b_last_change)
                                    ? '.'
                                    : 'a' + (char) ((const fmark_T *)iter
                                                    - &(buf->b_namedm[0]))))));
  const fmark_T *iter_mark = next_buffer_mark(buf, &mark_name);
  while (iter_mark != NULL && iter_mark->mark.lnum == 0) {
    iter_mark = next_buffer_mark(buf, &mark_name);
  }
  if (iter_mark == NULL) {
    return NULL;
  }
  size_t iter_off = (size_t) (iter_mark - &(buf->b_namedm[0]));
  if (mark_name) {
    *name = mark_name;
  } else {
    *name = (char) ('a' + (char) iter_off);
  }
  *fm = *iter_mark;
  return (const void *) iter_mark;
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
bool mark_set_local(const char name, buf_T *const buf,
                    const fmark_T fm, const bool update)
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

/*
 * Free items in the jumplist of window "wp".
 */
void free_jumplist(win_T *wp)
{
  int i;

  for (i = 0; i < wp->w_jumplistlen; ++i) {
    free_xfmark(wp->w_jumplist[i]);
  }
  wp->w_jumplistlen = 0;
}

void set_last_cursor(win_T *win)
{
  if (win->w_buffer != NULL) {
    RESET_FMARK(&win->w_buffer->b_last_cursor, win->w_cursor, 0);
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
  memset(&namedfm[0], 0, sizeof(namedfm));
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
    const char_u *const p = ml_get_buf(buf, lp->lnum, false);
    if (*p == NUL || (int)STRLEN(p) < lp->col) {
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
