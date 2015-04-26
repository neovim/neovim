/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * cursor_modify.c: functions related to insertion/deletion relative
 *                  to the current cursor position.
 */

#include "nvim/vim.h"
#include "nvim/cursor.h"
#include "nvim/cursor_modify.h"
#include "nvim/types.h"
#include "nvim/misc2.h"
#include "nvim/memline.h"
#include "nvim/strings.h"
#include "nvim/charset.h"
#include "nvim/ascii.h"
#include "nvim/edit.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/search.h"
#include "nvim/undo.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "cursor_modify.c.generated.h"
#endif

/*
 * Insert string "p" at the cursor position.  Stops at a NUL byte.
 * Handles Replace mode and multi-byte characters.
 */
void ins_bytes(char_u *p)
{
  ins_bytes_len(p, (int)STRLEN(p));
}

/*
 * Insert string "p" with length "len" at the cursor position.
 * Handles Replace mode and multi-byte characters.
 */
void ins_bytes_len(char_u *p, int len)
{
  int i;
  int n;

  if (has_mbyte) {
    for (i = 0; i < len; i += n) {
      if (enc_utf8) {
        /* avoid reading past p[len] */
        n = utfc_ptr2len_len(p + i, len - i);
      } else {
        n = (*mb_ptr2len)(p + i);
      }

      ins_char_bytes(p + i, n);
    }
  } else {
    for (i = 0; i < len; ++i) {
      ins_char(p[i]);
    }
  }
}

/*
 * Insert or replace a single character at the cursor position.
 * When in REPLACE or VREPLACE mode, replace any existing character.
 * Caller must have prepared for undo.
 * For multi-byte characters we get the whole character, the caller must
 * convert bytes to a character.
 */
void ins_char(int c)
{
  char_u buf[MB_MAXBYTES + 1];
  int n;

  n = (*mb_char2bytes)(c, buf);

  /* When "c" is 0x100, 0x200, etc. we don't want to insert a NUL byte.
   * Happens for CTRL-Vu9900. */
  if (buf[0] == 0)
    buf[0] = '\n';

  ins_char_bytes(buf, n);
}

void ins_char_bytes(char_u *buf, int charlen)
{
  int c = buf[0];
  int newlen;                   /* nr of bytes inserted */
  int oldlen;                   /* nr of bytes deleted (0 when not replacing) */
  char_u      *p;
  char_u      *newp;
  char_u      *oldp;
  int linelen;                  /* length of old line including NUL */
  colnr_T col;
  linenr_T lnum = curwin->w_cursor.lnum;
  int i;

  /* Break tabs if needed. */
  if (virtual_active() && curwin->w_cursor.coladd > 0)
    coladvance_force(getviscol());

  col = curwin->w_cursor.col;
  oldp = ml_get(lnum);
  linelen = (int)STRLEN(oldp) + 1;

  /* The lengths default to the values for when not replacing. */
  oldlen = 0;
  newlen = charlen;

  if (State & REPLACE_FLAG) {
    if (State & VREPLACE_FLAG) {
      colnr_T new_vcol = 0;             /* init for GCC */
      colnr_T vcol;
      int old_list;

      /*
       * Disable 'list' temporarily, unless 'cpo' contains the 'L' flag.
       * Returns the old value of list, so when finished,
       * curwin->w_p_list should be set back to this.
       */
      old_list = curwin->w_p_list;
      if (old_list && vim_strchr(p_cpo, CPO_LISTWM) == NULL)
        curwin->w_p_list = false;

      /*
       * In virtual replace mode each character may replace one or more
       * characters (zero if it's a TAB).  Count the number of bytes to
       * be deleted to make room for the new character, counting screen
       * cells.  May result in adding spaces to fill a gap.
       */
      getvcol(curwin, &curwin->w_cursor, NULL, &vcol, NULL);
      new_vcol = vcol + chartabsize(buf, vcol);
      while (oldp[col + oldlen] != NUL && vcol < new_vcol) {
        vcol += chartabsize(oldp + col + oldlen, vcol);
        /* Don't need to remove a TAB that takes us to the right
         * position. */
        if (vcol > new_vcol && oldp[col + oldlen] == TAB) {
          break;
        }

        oldlen += (*mb_ptr2len)(oldp + col + oldlen);
        /* Deleted a bit too much, insert spaces. */
        if (vcol > new_vcol) {
          newlen += vcol - new_vcol;
        }
      }

      curwin->w_p_list = old_list;
    } else if (oldp[col] != NUL)  {
      /* normal replace */
      oldlen = (*mb_ptr2len)(oldp + col);
    }

    /* Push the replaced bytes onto the replace stack, so that they can be
     * put back when BS is used.  The bytes of a multi-byte character are
     * done the other way around, so that the first byte is popped off
     * first (it tells the byte length of the character). */
    replace_push(NUL);
    for (i = 0; i < oldlen; ++i) {
      if (has_mbyte) {
        i += replace_push_mb(oldp + col + i) - 1;
      } else {
        replace_push(oldp[col + i]);
      }
    }
  }

  newp = (char_u *) xmalloc((size_t)(linelen + newlen - oldlen));

  /* Copy bytes before the cursor. */
  if (col > 0)
    memmove(newp, oldp, (size_t)col);

  /* Copy bytes after the changed character(s). */
  p = newp + col;
  memmove(p + newlen, oldp + col + oldlen,
      (size_t)(linelen - col - oldlen));

  /* Insert or overwrite the new character. */
  memmove(p, buf, (size_t)charlen);
  i = charlen;

  /* Fill with spaces when necessary. */
  while (i < newlen)
    p[i++] = ' ';

  /* Replace the line in the buffer. */
  ml_replace(lnum, newp, false);

  /* mark the buffer as changed and prepare for displaying */
  changed_bytes(lnum, col);

  /*
   * If we're in Insert or Replace mode and 'showmatch' is set, then briefly
   * show the match for right parens and braces.
   */
  if (p_sm && (State & INSERT)
      && msg_silent == 0
      && !ins_compl_active()
      ) {
    if (has_mbyte)
      showmatch(mb_ptr2char(buf));
    else
      showmatch(c);
  }

  if (!p_ri || (State & REPLACE_FLAG)) {
    /* Normal insert: move cursor right */
    curwin->w_cursor.col += charlen;
  }
  /*
   * TODO: should try to update w_row here, to avoid recomputing it later.
   */
}

/*
 * Insert a string at the cursor position.
 * Note: Does NOT handle Replace mode.
 * Caller must have prepared for undo.
 */
void ins_str(char_u *s)
{
  char_u      *oldp, *newp;
  int newlen = (int)STRLEN(s);
  int oldlen;
  colnr_T col;
  linenr_T lnum = curwin->w_cursor.lnum;

  if (virtual_active() && curwin->w_cursor.coladd > 0)
    coladvance_force(getviscol());

  col = curwin->w_cursor.col;
  oldp = ml_get(lnum);
  oldlen = (int)STRLEN(oldp);

  newp = (char_u *) xmalloc((size_t)(oldlen + newlen + 1));
  if (col > 0)
    memmove(newp, oldp, (size_t)col);
  memmove(newp + col, s, (size_t)newlen);
  memmove(newp + col + newlen, oldp + col, (size_t)(oldlen - col + 1));
  ml_replace(lnum, newp, false);
  changed_bytes(lnum, col);
  curwin->w_cursor.col += newlen;
}

/*
 * Delete one character under the cursor.
 * If "fixpos" is TRUE, don't leave the cursor on the NUL after the line.
 * Caller must have prepared for undo.
 *
 * return FAIL for failure, OK otherwise
 */
int del_char(int fixpos)
{
  if (has_mbyte) {
    /* Make sure the cursor is at the start of a character. */
    mb_adjust_cursor();
    if (*get_cursor_pos_ptr() == NUL)
      return FAIL;

    return del_chars(1L, fixpos);
  }

  return del_bytes(1L, fixpos, true);
}

/*
 * Like del_bytes(), but delete characters instead of bytes.
 */
int del_chars(long count, int fixpos)
{
  long bytes = 0;
  long i;
  char_u      *p;
  int l;

  p = get_cursor_pos_ptr();
  for (i = 0; i < count && *p != NUL; ++i) {
    l = (*mb_ptr2len)(p);
    bytes += l;
    p += l;
  }

  return del_bytes(bytes, fixpos, true);
}

/*
 * Delete "count" bytes under the cursor.
 * If "fixpos" is TRUE, don't leave the cursor on the NUL after the line.
 * Caller must have prepared for undo.
 * If 'use_delcombine' is TRUE, apply 'delcombine' option.
 *
 * return FAIL for failure, OK otherwise
 */
int del_bytes(long count, int fixpos_arg,
              int use_delcombine)
{
  char_u      *oldp, *newp;
  colnr_T oldlen;
  linenr_T lnum = curwin->w_cursor.lnum;
  colnr_T col = curwin->w_cursor.col;
  int was_alloced;
  long movelen;
  int fixpos = fixpos_arg;

  oldp = ml_get(lnum);
  oldlen = (int)STRLEN(oldp);

  /*
   * Can't do anything when the cursor is on the NUL after the line.
   */
  if (col >= oldlen)
    return FAIL;

  /* If 'delcombine' is set and deleting (less than) one character, only
   * delete the last combining character. */
  if (p_deco && use_delcombine && enc_utf8
      && utfc_ptr2len(oldp + col) >= count) {
    int cc[MAX_MCO];
    int n;

    (void)utfc_ptr2char(oldp + col, cc);
    if (cc[0] != NUL) {
      /* Find the last composing char, there can be several. */
      n = col;
      do {
        col = n;
        count = utf_ptr2len(oldp + n);
        n += (int)count;
      } while (UTF_COMPOSINGLIKE(oldp + col, oldp + n));
      fixpos = 0;
    }
  }

  /*
   * When count is too big, reduce it.
   */
  movelen = (long)oldlen - (long)col - count + 1;   /* includes trailing NUL */
  if (movelen <= 1) {
    /*
     * If we just took off the last character of a non-blank line, and
     * fixpos is TRUE, we don't want to end up positioned at the NUL,
     * unless "restart_edit" is set or 'virtualedit' contains "onemore".
     */
    if (col > 0 && fixpos && restart_edit == 0
        && (ve_flags & VE_ONEMORE) == 0) {
      --curwin->w_cursor.col;
      curwin->w_cursor.coladd = 0;

      if (has_mbyte) {
        char_u *newp = oldp + curwin->w_cursor.col;
        curwin->w_cursor.col -= (*mb_head_off)(oldp, newp);
      }
    }

    count = oldlen - col;
    movelen = 1;
  }

  /*
   * If the old line has been allocated the deletion can be done in the
   * existing line. Otherwise a new line has to be allocated.
   */
  was_alloced = ml_line_alloced();          /* check if oldp was allocated */
  if (was_alloced) {
    newp = oldp;                            /* use same allocated memory */
  } else {                                    /* need to allocate a new line */
    newp = xmalloc((size_t)(oldlen + 1 - count));
    memmove(newp, oldp, (size_t)col);
  }

  memmove(newp + col, oldp + col + count, (size_t)movelen);
  if (!was_alloced)
    ml_replace(lnum, newp, false);

  /* mark the buffer as changed and prepare for displaying */
  changed_bytes(lnum, curwin->w_cursor.col);
  return OK;
}

/*
 * Delete from cursor to end of line.
 * Caller must have prepared for undo.
 * If 'fixpos' is TRUE, fix the cursor position when done.
 */
void truncate_line(int fixpos)
{
  char_u      *newp;
  linenr_T lnum = curwin->w_cursor.lnum;
  colnr_T col = curwin->w_cursor.col;

  if (col == 0)
    newp = vim_strsave((char_u *)"");
  else
    newp = vim_strnsave(ml_get(lnum), (size_t)col);

  ml_replace(lnum, newp, false);

  /* mark the buffer as changed and prepare for displaying */
  changed_bytes(lnum, curwin->w_cursor.col);

  /*
   * If "fixpos" is TRUE we don't want to end up positioned at the NUL.
   */
  if (fixpos && curwin->w_cursor.col > 0)
    --curwin->w_cursor.col;
}

/*
 * Delete "nlines" lines at the cursor.
 * Saves the lines for undo first if "undo" is TRUE.
 */
void del_lines(long nlines, int undo)
{
  long n;
  linenr_T first = curwin->w_cursor.lnum;

  if (nlines <= 0)
    return;

  /* save the deleted lines for undo */
  if (undo && u_savedel(first, nlines) == FAIL)
    return;

  for (n = 0; n < nlines; ) {
    if (curbuf->b_ml.ml_flags & ML_EMPTY)           /* nothing to delete */
      break;

    ml_delete(first, true);
    ++n;

    /* If we delete the last line in the file, stop */
    if (first > curbuf->b_ml.ml_line_count)
      break;
  }

  /* Correct the cursor position before calling deleted_lines_mark(), it may
   * trigger a callback to display the cursor. */
  curwin->w_cursor.col = 0;
  check_cursor_lnum();

  /* adjust marks, mark the buffer as changed and prepare for displaying */
  deleted_lines_mark(first, n);
}
