/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * misc2.c: Various functions.
 */
#include <string.h>

#include "vim.h"
#include "misc2.h"
#include "file_search.h"
#include "blowfish.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_docmd.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "getchar.h"
#include "mark.h"
#include "mbyte.h"
#include "memfile.h"
#include "memline.h"
#include "memory.h"
#include "message.h"
#include "misc1.h"
#include "move.h"
#include "option.h"
#include "ops.h"
#include "os_unix.h"
#include "path.h"
#include "quickfix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "spell.h"
#include "syntax.h"
#include "tag.h"
#include "term.h"
#include "ui.h"
#include "window.h"
#include "os/os.h"
#include "os/shell.h"

static int coladvance2(pos_T *pos, int addspaces, int finetune,
                       colnr_T wcol);

/*
 * Return TRUE if in the current mode we need to use virtual.
 */
int virtual_active(void)
{
  /* While an operator is being executed we return "virtual_op", because
   * VIsual_active has already been reset, thus we can't check for "block"
   * being used. */
  if (virtual_op != MAYBE)
    return virtual_op;
  return ve_flags == VE_ALL
         || ((ve_flags & VE_BLOCK) && VIsual_active && VIsual_mode == Ctrl_V)
         || ((ve_flags & VE_INSERT) && (State & INSERT));
}

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
  int rc = coladvance2(&curwin->w_cursor, TRUE, FALSE, wcol);

  if (wcol == MAXCOL)
    curwin->w_valid &= ~VALID_VIRTCOL;
  else {
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
  else if (*ml_get_cursor() != TAB) {
    /* Virtcol is valid when not on a TAB */
    curwin->w_valid |= VALID_VIRTCOL;
    curwin->w_virtcol = wcol;
  }
  return rc;
}

/*
 * Return in "pos" the position of the cursor advanced to screen column "wcol".
 * return OK if desired column is reached, FAIL if not
 */
int getvpos(pos_T *pos, colnr_T wcol)
{
  return coladvance2(pos, FALSE, virtual_active(), wcol);
}

static int 
coladvance2 (
    pos_T *pos,
    int addspaces,                  /* change the text to achieve our goal? */
    int finetune,                   /* change char offset for the exact column */
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
             || ((ve_flags & VE_ONEMORE) && wcol < MAXCOL)
  ;
  line = ml_get_buf(curbuf, pos->lnum, FALSE);

  if (wcol >= MAXCOL) {
    idx = (int)STRLEN(line) - 1 + one_more;
    col = wcol;

    if ((addspaces || finetune) && !VIsual_active) {
      curwin->w_curswant = linetabsize(line) + one_more;
      if (curwin->w_curswant > 0)
        --curwin->w_curswant;
    }
  } else {
    int width = W_WIDTH(curwin) - win_col_off(curwin);

    if (finetune
        && curwin->w_p_wrap
        && curwin->w_width != 0
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
      csize = win_lbr_chartabsize(curwin, ptr, col, &head);
      mb_ptr_adv(ptr);
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
        char_u  *newline = alloc(idx + correct + 1);
        int t;

        for (t = 0; t < idx; ++t)
          newline[t] = line[t];

        for (t = 0; t < correct; ++t)
          newline[t + idx] = ' ';

        newline[idx + correct] = NUL;

        ml_replace(pos->lnum, newline, FALSE);
        changed_bytes(pos->lnum, (colnr_T)idx);
        idx += correct;
        col = wcol;
      } else {
        /* Break a tab */
        int linelen = (int)STRLEN(line);
        int correct = wcol - col - csize + 1;             /* negative!! */
        char_u  *newline;
        int t, s = 0;
        int v;

        if (-correct > csize)
          return FAIL;

        newline = alloc(linelen + csize);

        for (t = 0; t < linelen; t++) {
          if (t != idx)
            newline[s++] = line[t];
          else
            for (v = 0; v < csize; v++)
              newline[s++] = ' ';
        }

        newline[linelen + csize - 1] = NUL;

        ml_replace(pos->lnum, newline, FALSE);
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

      /* The difference between wcol and col is used to set coladd. */
      if (b > 0 && b < (MAXCOL - 2 * W_WIDTH(curwin)))
        pos->coladd = b;

      col += b;
    }
  }

  /* prevent from moving onto a trail byte */
  if (has_mbyte)
    mb_adjustpos(curbuf, pos);

  if (col < wcol)
    return FAIL;
  return OK;
}

/*
 * Increment the cursor position.  See inc() for return values.
 */
int inc_cursor(void)
{
  return inc(&curwin->w_cursor);
}

/*
 * Increment the line pointer "lp" crossing line boundaries as necessary.
 * Return 1 when going to the next line.
 * Return 2 when moving forward onto a NUL at the end of the line).
 * Return -1 when at the end of file.
 * Return 0 otherwise.
 */
int inc(pos_T *lp)
{
  char_u  *p = ml_get_pos(lp);

  if (*p != NUL) {      /* still within line, move to next char (may be NUL) */
    if (has_mbyte) {
      int l = (*mb_ptr2len)(p);

      lp->col += l;
      return (p[l] != NUL) ? 0 : 2;
    }
    lp->col++;
    lp->coladd = 0;
    return (p[1] != NUL) ? 0 : 2;
  }
  if (lp->lnum != curbuf->b_ml.ml_line_count) {     /* there is a next line */
    lp->col = 0;
    lp->lnum++;
    lp->coladd = 0;
    return 1;
  }
  return -1;
}

/*
 * incl(lp): same as inc(), but skip the NUL at the end of non-empty lines
 */
int incl(pos_T *lp)
{
  int r;

  if ((r = inc(lp)) >= 1 && lp->col)
    r = inc(lp);
  return r;
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

int dec(pos_T *lp)
{
  char_u      *p;

  lp->coladd = 0;
  if (lp->col > 0) {            /* still within line */
    lp->col--;
    if (has_mbyte) {
      p = ml_get(lp->lnum);
      lp->col -= (*mb_head_off)(p, p + lp->col);
    }
    return 0;
  }
  if (lp->lnum > 1) {           /* there is a prior line */
    lp->lnum--;
    p = ml_get(lp->lnum);
    lp->col = (colnr_T)STRLEN(p);
    if (has_mbyte)
      lp->col -= (*mb_head_off)(p, p + lp->col);
    return 1;
  }
  return -1;                    /* at start of file */
}

/*
 * decl(lp): same as dec(), but skip the NUL at the end of non-empty lines
 */
int decl(pos_T *lp)
{
  int r;

  if ((r = dec(lp)) == 1 && lp->col)
    r = dec(lp);
  return r;
}

/*
 * Get the line number relative to the current cursor position, i.e. the
 * difference between line number and cursor position. Only look for lines that
 * can be visible, folded lines don't count.
 */
linenr_T 
get_cursor_rel_lnum (
    win_T *wp,
    linenr_T lnum                      /* line number to get the result for */
)
{
  linenr_T cursor = wp->w_cursor.lnum;
  linenr_T retval = 0;

  if (hasAnyFolding(wp)) {
    if (lnum > cursor) {
      while (lnum > cursor) {
        (void)hasFoldingWin(wp, lnum, &lnum, NULL, TRUE, NULL);
        /* if lnum and cursor are in the same fold,
         * now lnum <= cursor */
        if (lnum > cursor)
          retval++;
        lnum--;
      }
    } else if (lnum < cursor) {
      while (lnum < cursor) {
        (void)hasFoldingWin(wp, lnum, NULL, &lnum, TRUE, NULL);
        /* if lnum and cursor are in the same fold,
         * now lnum >= cursor */
        if (lnum < cursor)
          retval--;
        lnum++;
      }
    }
    /* else if (lnum == cursor)
     *     retval = 0;
     */
  } else
    retval = lnum - cursor;

  return retval;
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

/*
 * Make sure win->w_cursor.col is valid.
 */
void check_cursor_col_win(win_T *win)
{
  colnr_T len;
  colnr_T oldcol = win->w_cursor.col;
  colnr_T oldcoladd = win->w_cursor.col + win->w_cursor.coladd;

  len = (colnr_T)STRLEN(ml_get_buf(win->w_buffer, win->w_cursor.lnum, FALSE));
  if (len == 0)
    win->w_cursor.col = 0;
  else if (win->w_cursor.col >= len) {
    /* Allow cursor past end-of-line when:
     * - in Insert mode or restarting Insert mode
     * - in Visual mode and 'selection' isn't "old"
     * - 'virtualedit' is set */
    if ((State & INSERT) || restart_edit
        || (VIsual_active && *p_sel != 'o')
        || (ve_flags & VE_ONEMORE)
        || virtual_active())
      win->w_cursor.col = len;
    else {
      win->w_cursor.col = len - 1;
      /* Move the cursor to the head byte. */
      if (has_mbyte)
        mb_adjustpos(win->w_buffer, &win->w_cursor);
    }
  } else if (win->w_cursor.col < 0)
    win->w_cursor.col = 0;

  /* If virtual editing is on, we can leave the cursor on the old position,
   * only we must set it to virtual.  But don't do it when at the end of the
   * line. */
  if (oldcol == MAXCOL)
    win->w_cursor.coladd = 0;
  else if (ve_flags == VE_ALL) {
    if (oldcoladd > win->w_cursor.col)
      win->w_cursor.coladd = oldcoladd - win->w_cursor.col;
    else
      /* avoid weird number when there is a miscalculation or overflow */
      win->w_cursor.coladd = 0;
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
 * Return TRUE if the cursor was moved.
 */
int leftcol_changed(void)
{
  long lastcol;
  colnr_T s, e;
  int retval = FALSE;

  changed_cline_bef_curs();
  lastcol = curwin->w_leftcol + W_WIDTH(curwin) - curwin_col_off() - 1;
  validate_virtcol();

  /*
   * If the cursor is right or left of the screen, move it to last or first
   * character.
   */
  if (curwin->w_virtcol > (colnr_T)(lastcol - p_siso)) {
    retval = TRUE;
    coladvance((colnr_T)(lastcol - p_siso));
  } else if (curwin->w_virtcol < curwin->w_leftcol + p_siso) {
    retval = TRUE;
    (void)coladvance((colnr_T)(curwin->w_leftcol + p_siso));
  }

  /*
   * If the start of the character under the cursor is not on the screen,
   * advance the cursor one more char.  If this fails (last char of the
   * line) adjust the scrolling.
   */
  getvvcol(curwin, &curwin->w_cursor, &s, NULL, &e);
  if (e > (colnr_T)lastcol) {
    retval = TRUE;
    coladvance(s - 1);
  } else if (s < curwin->w_leftcol) {
    retval = TRUE;
    if (coladvance(e + 1) == FAIL) {    /* there isn't another character */
      curwin->w_leftcol = s;            /* adjust w_leftcol instead */
      changed_cline_bef_curs();
    }
  }

  if (retval)
    curwin->w_set_curswant = TRUE;
  redraw_later(NOT_VALID);
  return retval;
}

/*
 * Return TRUE when 'shell' has "csh" in the tail.
 */
int csh_like_shell(void)
{
  return strstr((char *)path_tail(p_sh), "csh") != NULL;
}

/*
 * Isolate one part of a string option where parts are separated with
 * "sep_chars".
 * The part is copied into "buf[maxlen]".
 * "*option" is advanced to the next part.
 * The length is returned.
 */
int copy_option_part(char_u **option, char_u *buf, int maxlen, char *sep_chars)
{
  int len = 0;
  char_u  *p = *option;

  /* skip '.' at start of option part, for 'suffixes' */
  if (*p == '.')
    buf[len++] = *p++;
  while (*p != NUL && vim_strchr((char_u *)sep_chars, *p) == NULL) {
    /*
     * Skip backslash before a separator character and space.
     */
    if (p[0] == '\\' && vim_strchr((char_u *)sep_chars, p[1]) != NULL)
      ++p;
    if (len < maxlen - 1)
      buf[len++] = *p;
    ++p;
  }
  buf[len] = NUL;

  if (*p != NUL && *p != ',')   /* skip non-standard separator */
    ++p;
  p = skip_to_option_part(p);   /* p points to next file name */

  *option = p;
  return len;
}

/*
 * Return the current end-of-line type: EOL_DOS, EOL_UNIX or EOL_MAC.
 */
int get_fileformat(buf_T *buf)
{
  int c = *buf->b_p_ff;

  if (buf->b_p_bin || c == 'u')
    return EOL_UNIX;
  if (c == 'm')
    return EOL_MAC;
  return EOL_DOS;
}

/*
 * Like get_fileformat(), but override 'fileformat' with "p" for "++opt=val"
 * argument.
 */
int 
get_fileformat_force (
    buf_T *buf,
    exarg_T *eap           /* can be NULL! */
)
{
  int c;

  if (eap != NULL && eap->force_ff != 0)
    c = eap->cmd[eap->force_ff];
  else {
    if ((eap != NULL && eap->force_bin != 0)
        ? (eap->force_bin == FORCE_BIN) : buf->b_p_bin)
      return EOL_UNIX;
    c = *buf->b_p_ff;
  }
  if (c == 'u')
    return EOL_UNIX;
  if (c == 'm')
    return EOL_MAC;
  return EOL_DOS;
}

/// Set the current end-of-line type to EOL_UNIX, EOL_MAC, or EOL_DOS.
///
/// Sets 'fileformat'.
///
/// @param eol_style End-of-line style.
/// @param opt_flags OPT_LOCAL and/or OPT_GLOBAL
void set_fileformat(int eol_style, int opt_flags)
{
  char *p = NULL;

  switch (eol_style) {
      case EOL_UNIX:
          p = FF_UNIX;
          break;
      case EOL_MAC:
          p = FF_MAC;
          break;
      case EOL_DOS:
          p = FF_DOS;
          break;
  }

  // p is NULL if "eol_style" is EOL_UNKNOWN.
  if (p != NULL) {
    set_string_option_direct((char_u *)"ff",
                             -1,
                             (char_u *)p,
                             OPT_FREE | opt_flags,
                             0);
  }

  // This may cause the buffer to become (un)modified.
  check_status(curbuf);
  redraw_tabline = TRUE;
  need_maketitle = TRUE;  // Set window title later.
}

/*
 * Return the default fileformat from 'fileformats'.
 */
int default_fileformat(void)
{
  switch (*p_ffs) {
  case 'm':   return EOL_MAC;
  case 'd':   return EOL_DOS;
  }
  return EOL_UNIX;
}

/*
 * Call shell.	Calls mch_call_shell, with 'shellxquote' added.
 */
int call_shell(char_u *cmd, ShellOpts opts, char_u *extra_shell_arg)
{
  char_u      *ncmd;
  int retval;
  proftime_T wait_time;

  if (p_verbose > 3) {
    verbose_enter();
    smsg((char_u *)_("Calling shell to execute: \"%s\""),
        cmd == NULL ? p_sh : cmd);
    out_char('\n');
    cursor_on();
    verbose_leave();
  }

  if (do_profiling == PROF_YES)
    prof_child_enter(&wait_time);

  if (*p_sh == NUL) {
    EMSG(_(e_shellempty));
    retval = -1;
  } else {
    /* The external command may update a tags file, clear cached tags. */
    tag_freematch();

    if (cmd == NULL || *p_sxq == NUL)
      retval = os_call_shell(cmd, opts, extra_shell_arg);
    else {
      char_u *ecmd = cmd;

      if (*p_sxe != NUL && STRCMP(p_sxq, "(") == 0) {
        ecmd = vim_strsave_escaped_ext(cmd, p_sxe, '^', FALSE);
        if (ecmd == NULL)
          ecmd = cmd;
      }
      ncmd = xmalloc(STRLEN(ecmd) + STRLEN(p_sxq) * 2 + 1);
      STRCPY(ncmd, p_sxq);
      STRCAT(ncmd, ecmd);
      /* When 'shellxquote' is ( append ).
       * When 'shellxquote' is "( append )". */
      STRCAT(ncmd, STRCMP(p_sxq, "(") == 0 ? (char_u *)")"
          : STRCMP(p_sxq, "\"(") == 0 ? (char_u *)")\""
          : p_sxq);
      retval = os_call_shell(ncmd, opts, extra_shell_arg);
      free(ncmd);

      if (ecmd != cmd)
        free(ecmd);
    }
    /*
     * Check the window size, in case it changed while executing the
     * external command.
     */
    shell_resized_check();
  }

  set_vim_var_nr(VV_SHELL_ERROR, (long)retval);
  if (do_profiling == PROF_YES)
    prof_child_exit(&wait_time);

  return retval;
}

/*
 * VISUAL, SELECTMODE and OP_PENDING State are never set, they are equal to
 * NORMAL State with a condition.  This function returns the real State.
 */
int get_real_state(void)
{
  if (State & NORMAL) {
    if (VIsual_active) {
      if (VIsual_select)
        return SELECTMODE;
      return VISUAL;
    } else if (finish_op)
      return OP_PENDING;
  }
  return State;
}

#if defined(FEAT_SESSION) || defined(MSWIN) || defined(FEAT_GUI_MAC) \
  || ((defined(FEAT_GUI_GTK)) \
  && ( defined(FEAT_WINDOWS) || defined(FEAT_DND)) ) \
  || defined(PROTO)
/*
 * Change to a file's directory.
 * Caller must call shorten_fnames()!
 * Return OK or FAIL.
 */
int vim_chdirfile(char_u *fname)
{
  char_u dir[MAXPATHL];

  vim_strncpy(dir, fname, MAXPATHL - 1);
  *path_tail_with_sep(dir) = NUL;
  return os_chdir((char *)dir) == 0 ? OK : FAIL;
}
#endif

#if defined(STAT_IGNORES_SLASH) || defined(PROTO)
/*
 * Check if "name" ends in a slash and is not a directory.
 * Used for systems where stat() ignores a trailing slash on a file name.
 * The Vim code assumes a trailing slash is only ignored for a directory.
 */
int illegal_slash(char *name)
{
  if (name[0] == NUL)
    return FALSE;           /* no file name is not illegal */
  if (name[strlen(name) - 1] != '/')
    return FALSE;           /* no trailing slash */
  if (os_isdir((char_u *)name))
    return FALSE;           /* trailing slash for a directory */
  return TRUE;
}
#endif

/*
 * Change directory to "new_dir".  If FEAT_SEARCHPATH is defined, search
 * 'cdpath' for relative directory names, otherwise just os_chdir().
 */
int vim_chdir(char_u *new_dir)
{
  char_u      *dir_name;
  int r;

  dir_name = find_directory_in_path(new_dir, (int)STRLEN(new_dir),
      FNAME_MESS, curbuf->b_ffname);
  if (dir_name == NULL)
    return -1;
  r = os_chdir((char *)dir_name);
  free(dir_name);
  return r;
}


/*
 * Print an error message with one or two "%s" and one or two string arguments.
 * This is not in message.c to avoid a warning for prototypes.
 */
int emsg3(char_u *s, char_u *a1, char_u *a2)
{
  if (emsg_not_now())
    return TRUE;                /* no error messages at the moment */
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, a1, a2);
  return emsg(IObuff);
}

/*
 * Print an error message with one "%" PRId64 and one (int64_t) argument.
 * This is not in message.c to avoid a warning for prototypes.
 */
int emsgn(char_u *s, int64_t n)
{
  if (emsg_not_now())
    return TRUE;                /* no error messages at the moment */
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, n);
  return emsg(IObuff);
}

/*
 * Print an error message with one "%" PRIu64 and one (uint64_t) argument.
 */
int emsgu(char_u *s, uint64_t n)
{
  if (emsg_not_now())
    return TRUE;                /* no error messages at the moment */
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, n);
  return emsg(IObuff);
}

/*
 * Read 2 bytes from "fd" and turn them into an int, MSB first.
 */
int get2c(FILE *fd)
{
  int n;

  n = getc(fd);
  n = (n << 8) + getc(fd);
  return n;
}

/*
 * Read 3 bytes from "fd" and turn them into an int, MSB first.
 */
int get3c(FILE *fd)
{
  int n;

  n = getc(fd);
  n = (n << 8) + getc(fd);
  n = (n << 8) + getc(fd);
  return n;
}

/*
 * Read 4 bytes from "fd" and turn them into an int, MSB first.
 */
int get4c(FILE *fd)
{
  /* Use unsigned rather than int otherwise result is undefined
   * when left-shift sets the MSB. */
  unsigned n;

  n = (unsigned)getc(fd);
  n = (n << 8) + (unsigned)getc(fd);
  n = (n << 8) + (unsigned)getc(fd);
  n = (n << 8) + (unsigned)getc(fd);
  return (int)n;
}

/*
 * Read 8 bytes from "fd" and turn them into a time_t, MSB first.
 */
time_t get8ctime(FILE *fd)
{
  time_t n = 0;
  int i;

  for (i = 0; i < 8; ++i)
    n = (n << 8) + getc(fd);
  return n;
}

/*
 * Read a string of length "cnt" from "fd" into allocated memory.
 * Returns NULL when unable to read that many bytes.
 */
char_u *read_string(FILE *fd, int cnt)
{
  int i;
  int c;

  char_u *str = xmallocz(cnt);
  /* Read the string.  Quit when running into the EOF. */
  for (i = 0; i < cnt; ++i) {
    c = getc(fd);
    if (c == EOF) {
      free(str);
      return NULL;
    }
    str[i] = c;
  }
  str[i] = NUL;

  return str;
}

/*
 * Write a number to file "fd", MSB first, in "len" bytes.
 */
int put_bytes(FILE *fd, long_u nr, int len)
{
  int i;

  for (i = len - 1; i >= 0; --i)
    if (putc((int)(nr >> (i * 8)), fd) == EOF)
      return FAIL;
  return OK;
}


/*
 * Write time_t to file "fd" in 8 bytes.
 */
void put_time(FILE *fd, time_t the_time)
{
  int c;
  int i;
  time_t wtime = the_time;

  /* time_t can be up to 8 bytes in size, more than long_u, thus we
   * can't use put_bytes() here.
   * Another problem is that ">>" may do an arithmetic shift that keeps the
   * sign.  This happens for large values of wtime.  A cast to long_u may
   * truncate if time_t is 8 bytes.  So only use a cast when it is 4 bytes,
   * it's safe to assume that long_u is 4 bytes or more and when using 8
   * bytes the top bit won't be set. */
  for (i = 7; i >= 0; --i) {
    if (i + 1 > (int)sizeof(time_t))
      /* ">>" doesn't work well when shifting more bits than avail */
      putc(0, fd);
    else {
#if defined(SIZEOF_TIME_T) && SIZEOF_TIME_T > 4
      c = (int)(wtime >> (i * 8));
#else
      c = (int)((long_u)wtime >> (i * 8));
#endif
      putc(c, fd);
    }
  }
}
