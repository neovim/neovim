/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * misc2.c: Various functions.
 */
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
#include "message.h"
#include "misc1.h"
#include "move.h"
#include "option.h"
#include "ops.h"
#include "os_unix.h"
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

        if (newline == NULL)
          return FAIL;

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
        if (newline == NULL)
          return FAIL;

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

/**********************************************************************
 * Various routines dealing with allocation and deallocation of memory.
 */

#if defined(MEM_PROFILE) || defined(PROTO)

# define MEM_SIZES  8200
static long_u mem_allocs[MEM_SIZES];
static long_u mem_frees[MEM_SIZES];
static long_u mem_allocated;
static long_u mem_freed;
static long_u mem_peak;
static long_u num_alloc;
static long_u num_freed;

static void mem_pre_alloc_s(size_t *sizep);
static void mem_pre_alloc_l(long_u *sizep);
static void mem_post_alloc(void **pp, size_t size);
static void mem_pre_free(void **pp);

static void mem_pre_alloc_s(size_t *sizep)
{
  *sizep += sizeof(size_t);
}

static void mem_pre_alloc_l(long_u *sizep)
{
  *sizep += sizeof(size_t);
}

static void mem_post_alloc(void **pp, size_t size)
{
  if (*pp == NULL)
    return;
  size -= sizeof(size_t);
  *(long_u *)*pp = size;
  if (size <= MEM_SIZES-1)
    mem_allocs[size-1]++;
  else
    mem_allocs[MEM_SIZES-1]++;
  mem_allocated += size;
  if (mem_allocated - mem_freed > mem_peak)
    mem_peak = mem_allocated - mem_freed;
  num_alloc++;
  *pp = (void *)((char *)*pp + sizeof(size_t));
}

static void mem_pre_free(void **pp)
{
  long_u size;

  *pp = (void *)((char *)*pp - sizeof(size_t));
  size = *(size_t *)*pp;
  if (size <= MEM_SIZES-1)
    mem_frees[size-1]++;
  else
    mem_frees[MEM_SIZES-1]++;
  mem_freed += size;
  num_freed++;
}

/*
 * called on exit via atexit()
 */
void vim_mem_profile_dump(void)
{
  int i, j;

  printf("\r\n");
  j = 0;
  for (i = 0; i < MEM_SIZES - 1; i++) {
    if (mem_allocs[i] || mem_frees[i]) {
      if (mem_frees[i] > mem_allocs[i])
        printf("\r\n%s", _("ERROR: "));
      printf("[%4d / %4lu-%-4lu] ", i + 1, mem_allocs[i], mem_frees[i]);
      j++;
      if (j > 3) {
        j = 0;
        printf("\r\n");
      }
    }
  }

  i = MEM_SIZES - 1;
  if (mem_allocs[i]) {
    printf("\r\n");
    if (mem_frees[i] > mem_allocs[i])
      puts(_("ERROR: "));
    printf("[>%d / %4lu-%-4lu]", i, mem_allocs[i], mem_frees[i]);
  }

  printf(_("\n[bytes] total alloc-freed %lu-%lu, in use %lu, peak use %lu\n"),
      mem_allocated, mem_freed, mem_allocated - mem_freed, mem_peak);
  printf(_("[calls] total re/malloc()'s %lu, total free()'s %lu\n\n"),
      num_alloc, num_freed);
}

#endif /* MEM_PROFILE */

/*
 * Some memory is reserved for error messages and for being able to
 * call mf_release_all(), which needs some memory for mf_trans_add().
 */
# define KEEP_ROOM (2 * 8192L)
#define KEEP_ROOM_KB (KEEP_ROOM / 1024L)

/*
 * Note: if unsigned is 16 bits we can only allocate up to 64K with alloc().
 * Use lalloc for larger blocks.
 */
char_u *alloc(unsigned size)
{
  return lalloc((long_u)size, TRUE);
}

/*
 * Allocate memory and set all bytes to zero.
 */
char_u *alloc_clear(unsigned size)
{
  char_u *p;

  p = lalloc((long_u)size, TRUE);
  if (p != NULL)
    (void)vim_memset(p, 0, (size_t)size);
  return p;
}

/*
 * alloc() with check for maximum line length
 */
char_u *alloc_check(unsigned size)
{
#if !defined(UNIX) && !defined(__EMX__)
  if (sizeof(int) == 2 && size > 0x7fff) {
    /* Don't hide this message */
    emsg_silent = 0;
    EMSG(_("E340: Line is becoming too long"));
    return NULL;
  }
#endif
  return lalloc((long_u)size, TRUE);
}

/*
 * Allocate memory like lalloc() and set all bytes to zero.
 */
char_u *lalloc_clear(long_u size, int message)
{
  char_u *p;

  p = (lalloc(size, message));
  if (p != NULL)
    (void)vim_memset(p, 0, (size_t)size);
  return p;
}

/*
 * Low level memory allocation function.
 * This is used often, KEEP IT FAST!
 */
char_u *lalloc(long_u size, int message)
{
  char_u      *p;                   /* pointer to new storage space */
  static int releasing = FALSE;     /* don't do mf_release_all() recursive */
  int try_again;
#if defined(HAVE_AVAIL_MEM) && !defined(SMALL_MEM)
  static long_u allocated = 0;      /* allocated since last avail check */
#endif

  /* Safety check for allocating zero bytes */
  if (size == 0) {
    /* Don't hide this message */
    emsg_silent = 0;
    EMSGN(_("E341: Internal error: lalloc(%ld, )"), size);
    return NULL;
  }

#ifdef MEM_PROFILE
  mem_pre_alloc_l(&size);
#endif


  /*
   * Loop when out of memory: Try to release some memfile blocks and
   * if some blocks are released call malloc again.
   */
  for (;; ) {
    /*
     * Handle three kind of systems:
     * 1. No check for available memory: Just return.
     * 2. Slow check for available memory: call mch_avail_mem() after
     *    allocating KEEP_ROOM amount of memory.
     * 3. Strict check for available memory: call mch_avail_mem()
     */
    if ((p = (char_u *)malloc((size_t)size)) != NULL) {
#ifndef HAVE_AVAIL_MEM
      /* 1. No check for available memory: Just return. */
      goto theend;
#else
# ifndef SMALL_MEM
      /* 2. Slow check for available memory: call mch_avail_mem() after
       *    allocating (KEEP_ROOM / 2) amount of memory. */
      allocated += size;
      if (allocated < KEEP_ROOM / 2)
        goto theend;
      allocated = 0;
# endif
      /* 3. check for available memory: call mch_avail_mem() */
      if (mch_avail_mem(TRUE) < KEEP_ROOM_KB && !releasing) {
        free((char *)p);                /* System is low... no go! */
        p = NULL;
      } else
        goto theend;
#endif
    }
    /*
     * Remember that mf_release_all() is being called to avoid an endless
     * loop, because mf_release_all() may call alloc() recursively.
     */
    if (releasing)
      break;
    releasing = TRUE;

    clear_sb_text();                  /* free any scrollback text */
    try_again = mf_release_all();     /* release as many blocks as possible */
    try_again |= garbage_collect();     /* cleanup recursive lists/dicts */

    releasing = FALSE;
    if (!try_again)
      break;
  }

  if (message && p == NULL)
    do_outofmem_msg(size);

theend:
#ifdef MEM_PROFILE
  mem_post_alloc((void **)&p, (size_t)size);
#endif
  return p;
}

#if defined(MEM_PROFILE) || defined(PROTO)
/*
 * realloc() with memory profiling.
 */
void *mem_realloc(void *ptr, size_t size)
{
  void *p;

  mem_pre_free(&ptr);
  mem_pre_alloc_s(&size);

  p = realloc(ptr, size);

  mem_post_alloc(&p, size);

  return p;
}
#endif

/*
 * Avoid repeating the error message many times (they take 1 second each).
 * Did_outofmem_msg is reset when a character is read.
 */
void do_outofmem_msg(long_u size)
{
  if (!did_outofmem_msg) {
    /* Don't hide this message */
    emsg_silent = 0;

    /* Must come first to avoid coming back here when printing the error
     * message fails, e.g. when setting v:errmsg. */
    did_outofmem_msg = TRUE;

    EMSGN(_("E342: Out of memory!  (allocating %lu bytes)"), size);
  }
}

#if defined(EXITFREE) || defined(PROTO)

/*
 * Free everything that we allocated.
 * Can be used to detect memory leaks, e.g., with ccmalloc.
 * NOTE: This is tricky!  Things are freed that functions depend on.  Don't be
 * surprised if Vim crashes...
 * Some things can't be freed, esp. things local to a library function.
 */
void free_all_mem(void)
{
  buf_T       *buf, *nextbuf;
  static int entered = FALSE;

  /* When we cause a crash here it is caught and Vim tries to exit cleanly.
   * Don't try freeing everything again. */
  if (entered)
    return;
  entered = TRUE;

  block_autocmds();         /* don't want to trigger autocommands here */

  /* Close all tabs and windows.  Reset 'equalalways' to avoid redraws. */
  p_ea = FALSE;
  if (first_tabpage->tp_next != NULL)
    do_cmdline_cmd((char_u *)"tabonly!");
  if (firstwin != lastwin)
    do_cmdline_cmd((char_u *)"only!");

  /* Free all spell info. */
  spell_free_all();

  /* Clear user commands (before deleting buffers). */
  ex_comclear(NULL);

  /* Clear menus. */
  do_cmdline_cmd((char_u *)"aunmenu *");
  do_cmdline_cmd((char_u *)"menutranslate clear");

  /* Clear mappings, abbreviations, breakpoints. */
  do_cmdline_cmd((char_u *)"lmapclear");
  do_cmdline_cmd((char_u *)"xmapclear");
  do_cmdline_cmd((char_u *)"mapclear");
  do_cmdline_cmd((char_u *)"mapclear!");
  do_cmdline_cmd((char_u *)"abclear");
  do_cmdline_cmd((char_u *)"breakdel *");
  do_cmdline_cmd((char_u *)"profdel *");
  do_cmdline_cmd((char_u *)"set keymap=");

  free_titles();
  free_findfile();

  /* Obviously named calls. */
  free_all_autocmds();
  clear_termcodes();
  free_all_options();
  free_all_marks();
  alist_clear(&global_alist);
  free_homedir();
  free_users();
  free_search_patterns();
  free_old_sub();
  free_last_insert();
  free_prev_shellcmd();
  free_regexp_stuff();
  free_tag_stuff();
  free_cd_dir();
  set_expr_line(NULL);
  diff_clear(curtab);
  clear_sb_text();            /* free any scrollback text */

  /* Free some global vars. */
  vim_free(last_cmdline);
  vim_free(new_last_cmdline);
  set_keep_msg(NULL, 0);

  /* Clear cmdline history. */
  p_hi = 0;
  init_history();

  {
    win_T       *win;
    tabpage_T   *tab;

    qf_free_all(NULL);
    /* Free all location lists */
    FOR_ALL_TAB_WINDOWS(tab, win)
    qf_free_all(win);
  }

  /* Close all script inputs. */
  close_all_scripts();

  /* Destroy all windows.  Must come before freeing buffers. */
  win_free_all();

  /* Free all buffers.  Reset 'autochdir' to avoid accessing things that
   * were freed already. */
  p_acd = FALSE;
  for (buf = firstbuf; buf != NULL; ) {
    nextbuf = buf->b_next;
    close_buffer(NULL, buf, DOBUF_WIPE, FALSE);
    if (buf_valid(buf))
      buf = nextbuf;            /* didn't work, try next one */
    else
      buf = firstbuf;
  }

  free_cmdline_buf();

  /* Clear registers. */
  clear_registers();
  ResetRedobuff();
  ResetRedobuff();


  /* highlight info */
  free_highlight();

  reset_last_sourcing();

  free_tabpage(first_tabpage);
  first_tabpage = NULL;

# ifdef UNIX
  /* Machine-specific free. */
  mch_free_mem();
# endif

  /* message history */
  for (;; )
    if (delete_first_msg() == FAIL)
      break;

  eval_clear();

  free_termoptions();

  /* screenlines (can't display anything now!) */
  free_screenlines();

  clear_hl_tables();

  vim_free(IObuff);
  vim_free(NameBuff);
}

#endif

/*
 * Copy "string" into newly allocated memory.
 */
char_u *vim_strsave(char_u *string)
{
  char_u      *p;
  unsigned len;

  len = (unsigned)STRLEN(string) + 1;
  p = alloc(len);
  if (p != NULL)
    mch_memmove(p, string, (size_t)len);
  return p;
}

/*
 * Copy up to "len" bytes of "string" into newly allocated memory and
 * terminate with a NUL.
 * The allocated memory always has size "len + 1", also when "string" is
 * shorter.
 */
char_u *vim_strnsave(char_u *string, int len)
{
  char_u      *p;

  p = alloc((unsigned)(len + 1));
  if (p != NULL) {
    STRNCPY(p, string, len);
    p[len] = NUL;
  }
  return p;
}

/*
 * Same as vim_strsave(), but any characters found in esc_chars are preceded
 * by a backslash.
 */
char_u *vim_strsave_escaped(char_u *string, char_u *esc_chars)
{
  return vim_strsave_escaped_ext(string, esc_chars, '\\', FALSE);
}

/*
 * Same as vim_strsave_escaped(), but when "bsl" is TRUE also escape
 * characters where rem_backslash() would remove the backslash.
 * Escape the characters with "cc".
 */
char_u *vim_strsave_escaped_ext(char_u *string, char_u *esc_chars, int cc, int bsl)
{
  char_u      *p;
  char_u      *p2;
  char_u      *escaped_string;
  unsigned length;
  int l;

  /*
   * First count the number of backslashes required.
   * Then allocate the memory and insert them.
   */
  length = 1;                           /* count the trailing NUL */
  for (p = string; *p; p++) {
    if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1) {
      length += l;                      /* count a multibyte char */
      p += l - 1;
      continue;
    }
    if (vim_strchr(esc_chars, *p) != NULL || (bsl && rem_backslash(p)))
      ++length;                         /* count a backslash */
    ++length;                           /* count an ordinary char */
  }
  escaped_string = alloc(length);
  if (escaped_string != NULL) {
    p2 = escaped_string;
    for (p = string; *p; p++) {
      if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1) {
        mch_memmove(p2, p, (size_t)l);
        p2 += l;
        p += l - 1;                     /* skip multibyte char  */
        continue;
      }
      if (vim_strchr(esc_chars, *p) != NULL || (bsl && rem_backslash(p)))
        *p2++ = cc;
      *p2++ = *p;
    }
    *p2 = NUL;
  }
  return escaped_string;
}

/*
 * Return TRUE when 'shell' has "csh" in the tail.
 */
int csh_like_shell(void)
{
  return strstr((char *)gettail(p_sh), "csh") != NULL;
}

/*
 * Escape "string" for use as a shell argument with system().
 * This uses single quotes, except when we know we need to use double quotes
 * (MS-DOS and MS-Windows without 'shellslash' set).
 * Escape a newline, depending on the 'shell' option.
 * When "do_special" is TRUE also replace "!", "%", "#" and things starting
 * with "<" like "<cfile>".
 * Returns the result in allocated memory, NULL if we have run out.
 */
char_u *vim_strsave_shellescape(char_u *string, int do_special)
{
  unsigned length;
  char_u      *p;
  char_u      *d;
  char_u      *escaped_string;
  int l;
  int csh_like;

  /* Only csh and similar shells expand '!' within single quotes.  For sh and
   * the like we must not put a backslash before it, it will be taken
   * literally.  If do_special is set the '!' will be escaped twice.
   * Csh also needs to have "\n" escaped twice when do_special is set. */
  csh_like = csh_like_shell();

  /* First count the number of extra bytes required. */
  length = (unsigned)STRLEN(string) + 3;    /* two quotes and a trailing NUL */
  for (p = string; *p != NUL; mb_ptr_adv(p)) {
    if (*p == '\'')
      length += 3;                      /* ' => '\'' */
    if (*p == '\n' || (*p == '!' && (csh_like || do_special))) {
      ++length;                         /* insert backslash */
      if (csh_like && do_special)
        ++length;                       /* insert backslash */
    }
    if (do_special && find_cmdline_var(p, &l) >= 0) {
      ++length;                         /* insert backslash */
      p += l - 1;
    }
  }

  /* Allocate memory for the result and fill it. */
  escaped_string = alloc(length);
  if (escaped_string != NULL) {
    d = escaped_string;

    /* add opening quote */
    *d++ = '\'';

    for (p = string; *p != NUL; ) {
      if (*p == '\'') {
        *d++ = '\'';
        *d++ = '\\';
        *d++ = '\'';
        *d++ = '\'';
        ++p;
        continue;
      }
      if (*p == '\n' || (*p == '!' && (csh_like || do_special))) {
        *d++ = '\\';
        if (csh_like && do_special)
          *d++ = '\\';
        *d++ = *p++;
        continue;
      }
      if (do_special && find_cmdline_var(p, &l) >= 0) {
        *d++ = '\\';                    /* insert backslash */
        while (--l >= 0)                /* copy the var */
          *d++ = *p++;
        continue;
      }

      MB_COPY_CHAR(p, d);
    }

    /* add terminating quote and finish with a NUL */
    *d++ = '\'';
    *d = NUL;
  }

  return escaped_string;
}

/*
 * Like vim_strsave(), but make all characters uppercase.
 * This uses ASCII lower-to-upper case translation, language independent.
 */
char_u *vim_strsave_up(char_u *string)
{
  char_u *p1;

  p1 = vim_strsave(string);
  vim_strup(p1);
  return p1;
}

/*
 * Like vim_strnsave(), but make all characters uppercase.
 * This uses ASCII lower-to-upper case translation, language independent.
 */
char_u *vim_strnsave_up(char_u *string, int len)
{
  char_u *p1;

  p1 = vim_strnsave(string, len);
  vim_strup(p1);
  return p1;
}

/*
 * ASCII lower-to-upper case translation, language independent.
 */
void vim_strup(char_u *p)
{
  char_u  *p2;
  int c;

  if (p != NULL) {
    p2 = p;
    while ((c = *p2) != NUL)
      *p2++ = (c < 'a' || c > 'z') ? c : (c - 0x20);
  }
}

/*
 * Make string "s" all upper-case and return it in allocated memory.
 * Handles multi-byte characters as well as possible.
 * Returns NULL when out of memory.
 */
char_u *strup_save(char_u *orig)
{
  char_u      *p;
  char_u      *res;

  res = p = vim_strsave(orig);

  if (res != NULL)
    while (*p != NUL) {
      int l;

      if (enc_utf8) {
        int c, uc;
        int newl;
        char_u  *s;

        c = utf_ptr2char(p);
        uc = utf_toupper(c);

        /* Reallocate string when byte count changes.  This is rare,
         * thus it's OK to do another malloc()/free(). */
        l = utf_ptr2len(p);
        newl = utf_char2len(uc);
        if (newl != l) {
          s = alloc((unsigned)STRLEN(res) + 1 + newl - l);
          if (s == NULL)
            break;
          mch_memmove(s, res, p - res);
          STRCPY(s + (p - res) + newl, p + l);
          p = s + (p - res);
          vim_free(res);
          res = s;
        }

        utf_char2bytes(uc, p);
        p += newl;
      } else if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1)
        p += l;                 /* skip multi-byte character */
      else {
        *p = TOUPPER_LOC(*p);         /* note that toupper() can be a macro */
        p++;
      }
    }

  return res;
}

/*
 * copy a space a number of times
 */
void copy_spaces(char_u *ptr, size_t count)
{
  size_t i = count;
  char_u      *p = ptr;

  while (i--)
    *p++ = ' ';
}

/*
 * Copy a character a number of times.
 * Does not work for multi-byte characters!
 */
void copy_chars(char_u *ptr, size_t count, int c)
{
  size_t i = count;
  char_u      *p = ptr;

  while (i--)
    *p++ = c;
}

/*
 * delete spaces at the end of a string
 */
void del_trailing_spaces(char_u *ptr)
{
  char_u      *q;

  q = ptr + STRLEN(ptr);
  while (--q > ptr && vim_iswhite(q[0]) && q[-1] != '\\' && q[-1] != Ctrl_V)
    *q = NUL;
}

/*
 * Like strncpy(), but always terminate the result with one NUL.
 * "to" must be "len + 1" long!
 */
void vim_strncpy(char_u *to, char_u *from, size_t len)
{
  STRNCPY(to, from, len);
  to[len] = NUL;
}

/*
 * Like strcat(), but make sure the result fits in "tosize" bytes and is
 * always NUL terminated.
 */
void vim_strcat(char_u *to, char_u *from, size_t tosize)
{
  size_t tolen = STRLEN(to);
  size_t fromlen = STRLEN(from);

  if (tolen + fromlen + 1 > tosize) {
    mch_memmove(to + tolen, from, tosize - tolen - 1);
    to[tosize - 1] = NUL;
  } else
    STRCPY(to + tolen, from);
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
 * Replacement for free() that ignores NULL pointers.
 * Also skip free() when exiting for sure, this helps when we caught a deadly
 * signal that was caused by a crash in free().
 */
void vim_free(void *x)
{
  if (x != NULL && !really_exiting) {
#ifdef MEM_PROFILE
    mem_pre_free(&x);
#endif
    free(x);
  }
}

#ifndef HAVE_MEMSET
void * vim_memset(ptr, c, size)
void    *ptr;
int c;
size_t size;
{
  char *p = ptr;

  while (size-- > 0)
    *p++ = c;
  return ptr;
}
#endif

#ifdef VIM_MEMCMP
/*
 * Return zero when "b1" and "b2" are the same for "len" bytes.
 * Return non-zero otherwise.
 */
int vim_memcmp(b1, b2, len)
void    *b1;
void    *b2;
size_t len;
{
  char_u  *p1 = (char_u *)b1, *p2 = (char_u *)b2;

  for (; len > 0; --len) {
    if (*p1 != *p2)
      return 1;
    ++p1;
    ++p2;
  }
  return 0;
}
#endif

#ifdef VIM_MEMMOVE
/*
 * Version of memmove() that handles overlapping source and destination.
 * For systems that don't have a function that is guaranteed to do that (SYSV).
 */
void mch_memmove(dst_arg, src_arg, len)
void    *src_arg, *dst_arg;
size_t len;
{
  /*
   * A void doesn't have a size, we use char pointers.
   */
  char *dst = dst_arg, *src = src_arg;

  /* overlap, copy backwards */
  if (dst > src && dst < src + len) {
    src += len;
    dst += len;
    while (len-- > 0)
      *--dst = *--src;
  } else                                /* copy forwards */
    while (len-- > 0)
      *dst++ = *src++;
}
#endif

#if (!defined(HAVE_STRCASECMP) && !defined(HAVE_STRICMP)) || defined(PROTO)
/*
 * Compare two strings, ignoring case, using current locale.
 * Doesn't work for multi-byte characters.
 * return 0 for match, < 0 for smaller, > 0 for bigger
 */
int vim_stricmp(char *s1, char *s2)
{
  int i;

  for (;; ) {
    i = (int)TOLOWER_LOC(*s1) - (int)TOLOWER_LOC(*s2);
    if (i != 0)
      return i;                             /* this character different */
    if (*s1 == NUL)
      break;                                /* strings match until NUL */
    ++s1;
    ++s2;
  }
  return 0;                                 /* strings match */
}
#endif

#if (!defined(HAVE_STRNCASECMP) && !defined(HAVE_STRNICMP)) || defined(PROTO)
/*
 * Compare two strings, for length "len", ignoring case, using current locale.
 * Doesn't work for multi-byte characters.
 * return 0 for match, < 0 for smaller, > 0 for bigger
 */
int vim_strnicmp(char *s1, char *s2, size_t len)
{
  int i;

  while (len > 0) {
    i = (int)TOLOWER_LOC(*s1) - (int)TOLOWER_LOC(*s2);
    if (i != 0)
      return i;                             /* this character different */
    if (*s1 == NUL)
      break;                                /* strings match until NUL */
    ++s1;
    ++s2;
    --len;
  }
  return 0;                                 /* strings match */
}
#endif

/*
 * Version of strchr() and strrchr() that handle unsigned char strings
 * with characters from 128 to 255 correctly.  It also doesn't return a
 * pointer to the NUL at the end of the string.
 */
char_u *vim_strchr(char_u *string, int c)
{
  char_u      *p;
  int b;

  p = string;
  if (enc_utf8 && c >= 0x80) {
    while (*p != NUL) {
      if (utf_ptr2char(p) == c)
        return p;
      p += (*mb_ptr2len)(p);
    }
    return NULL;
  }
  if (enc_dbcs != 0 && c > 255) {
    int n2 = c & 0xff;

    c = ((unsigned)c >> 8) & 0xff;
    while ((b = *p) != NUL) {
      if (b == c && p[1] == n2)
        return p;
      p += (*mb_ptr2len)(p);
    }
    return NULL;
  }
  if (has_mbyte) {
    while ((b = *p) != NUL) {
      if (b == c)
        return p;
      p += (*mb_ptr2len)(p);
    }
    return NULL;
  }
  while ((b = *p) != NUL) {
    if (b == c)
      return p;
    ++p;
  }
  return NULL;
}

/*
 * Version of strchr() that only works for bytes and handles unsigned char
 * strings with characters above 128 correctly. It also doesn't return a
 * pointer to the NUL at the end of the string.
 */
char_u *vim_strbyte(char_u *string, int c)
{
  char_u      *p = string;

  while (*p != NUL) {
    if (*p == c)
      return p;
    ++p;
  }
  return NULL;
}

/*
 * Search for last occurrence of "c" in "string".
 * Return NULL if not found.
 * Does not handle multi-byte char for "c"!
 */
char_u *vim_strrchr(char_u *string, int c)
{
  char_u      *retval = NULL;
  char_u      *p = string;

  while (*p) {
    if (*p == c)
      retval = p;
    mb_ptr_adv(p);
  }
  return retval;
}

/*
 * Vim's version of strpbrk(), in case it's missing.
 * Don't generate a prototype for this, causes problems when it's not used.
 */
# ifndef HAVE_STRPBRK
#  ifdef vim_strpbrk
#   undef vim_strpbrk
#  endif
char_u *vim_strpbrk(char_u *s, char_u *charset)
{
  while (*s) {
    if (vim_strchr(charset, *s) != NULL)
      return s;
    mb_ptr_adv(s);
  }
  return NULL;
}
# endif

/*
 * Vim has its own isspace() function, because on some machines isspace()
 * can't handle characters above 128.
 */
int vim_isspace(int x)
{
  return (x >= 9 && x <= 13) || x == ' ';
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

/*
 * Set the current end-of-line type to EOL_DOS, EOL_UNIX or EOL_MAC.
 * Sets both 'textmode' and 'fileformat'.
 * Note: Does _not_ set global value of 'textmode'!
 */
void 
set_fileformat (
    int t,
    int opt_flags                  /* OPT_LOCAL and/or OPT_GLOBAL */
)
{
  char        *p = NULL;

  switch (t) {
  case EOL_DOS:
    p = FF_DOS;
    curbuf->b_p_tx = TRUE;
    break;
  case EOL_UNIX:
    p = FF_UNIX;
    curbuf->b_p_tx = FALSE;
    break;
  case EOL_MAC:
    p = FF_MAC;
    curbuf->b_p_tx = FALSE;
    break;
  }
  if (p != NULL)
    set_string_option_direct((char_u *)"ff", -1, (char_u *)p,
        OPT_FREE | opt_flags, 0);

  /* This may cause the buffer to become (un)modified. */
  check_status(curbuf);
  redraw_tabline = TRUE;
  need_maketitle = TRUE;            /* set window title later */
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
int call_shell(char_u *cmd, int opt)
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
      retval = mch_call_shell(cmd, opt);
    else {
      char_u *ecmd = cmd;

      if (*p_sxe != NUL && STRCMP(p_sxq, "(") == 0) {
        ecmd = vim_strsave_escaped_ext(cmd, p_sxe, '^', FALSE);
        if (ecmd == NULL)
          ecmd = cmd;
      }
      ncmd = alloc((unsigned)(STRLEN(ecmd) + STRLEN(p_sxq) * 2 + 1));
      if (ncmd != NULL) {
        STRCPY(ncmd, p_sxq);
        STRCAT(ncmd, ecmd);
        /* When 'shellxquote' is ( append ).
         * When 'shellxquote' is "( append )". */
        STRCAT(ncmd, STRCMP(p_sxq, "(") == 0 ? (char_u *)")"
            : STRCMP(p_sxq, "\"(") == 0 ? (char_u *)")\""
            : p_sxq);
        retval = mch_call_shell(ncmd, opt);
        vim_free(ncmd);
      } else
        retval = -1;
      if (ecmd != cmd)
        vim_free(ecmd);
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

/*
 * Return TRUE if "p" points to just after a path separator.
 * Takes care of multi-byte characters.
 * "b" must point to the start of the file name
 */
int after_pathsep(char_u *b, char_u *p)
{
  return p > b && vim_ispathsep(p[-1])
         && (!has_mbyte || (*mb_head_off)(b, p - 1) == 0);
}

/*
 * Return TRUE if file names "f1" and "f2" are in the same directory.
 * "f1" may be a short name, "f2" must be a full path.
 */
int same_directory(char_u *f1, char_u *f2)
{
  char_u ffname[MAXPATHL];
  char_u      *t1;
  char_u      *t2;

  /* safety check */
  if (f1 == NULL || f2 == NULL)
    return FALSE;

  (void)vim_FullName(f1, ffname, MAXPATHL, FALSE);
  t1 = gettail_sep(ffname);
  t2 = gettail_sep(f2);
  return t1 - ffname == t2 - f2
         && pathcmp((char *)ffname, (char *)f2, (int)(t1 - ffname)) == 0;
}

#if defined(FEAT_SESSION) || defined(MSWIN) || defined(FEAT_GUI_MAC) \
  || ((defined(FEAT_GUI_GTK)) \
  && ( defined(FEAT_WINDOWS) || defined(FEAT_DND)) ) \
  || defined(FEAT_SUN_WORKSHOP) || defined(FEAT_NETBEANS_INTG) \
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
  *gettail_sep(dir) = NUL;
  return mch_chdir((char *)dir) == 0 ? OK : FAIL;
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
  if (mch_isdir((char_u *)name))
    return FALSE;           /* trailing slash for a directory */
  return TRUE;
}
#endif

/*
 * Change directory to "new_dir".  If FEAT_SEARCHPATH is defined, search
 * 'cdpath' for relative directory names, otherwise just mch_chdir().
 */
int vim_chdir(char_u *new_dir)
{
  char_u      *dir_name;
  int r;

  dir_name = find_directory_in_path(new_dir, (int)STRLEN(new_dir),
      FNAME_MESS, curbuf->b_ffname);
  if (dir_name == NULL)
    return -1;
  r = mch_chdir((char *)dir_name);
  vim_free(dir_name);
  return r;
}

#ifndef HAVE_QSORT
/*
 * Our own qsort(), for systems that don't have it.
 * It's simple and slow.  From the K&R C book.
 */
void qsort(base, elm_count, elm_size, cmp)
void        *base;
size_t elm_count;
size_t elm_size;
int (*cmp)(const void *, const void *);
{
  char_u      *buf;
  char_u      *p1;
  char_u      *p2;
  int i, j;
  int gap;

  buf = alloc((unsigned)elm_size);
  if (buf == NULL)
    return;

  for (gap = elm_count / 2; gap > 0; gap /= 2)
    for (i = gap; i < elm_count; ++i)
      for (j = i - gap; j >= 0; j -= gap) {
        /* Compare the elements. */
        p1 = (char_u *)base + j * elm_size;
        p2 = (char_u *)base + (j + gap) * elm_size;
        if ((*cmp)((void *)p1, (void *)p2) <= 0)
          break;
        /* Exchange the elements. */
        mch_memmove(buf, p1, elm_size);
        mch_memmove(p1, p2, elm_size);
        mch_memmove(p2, buf, elm_size);
      }

  vim_free(buf);
}
#endif

/*
 * Sort an array of strings.
 */
static int
sort_compare(const void *s1, const void *s2);

static int sort_compare(const void *s1, const void *s2)
{
  return STRCMP(*(char **)s1, *(char **)s2);
}

void sort_strings(char_u **files, int count)
{
  qsort((void *)files, (size_t)count, sizeof(char_u *), sort_compare);
}

#if !defined(NO_EXPANDPATH) || defined(PROTO)
/*
 * Compare path "p[]" to "q[]".
 * If "maxlen" >= 0 compare "p[maxlen]" to "q[maxlen]"
 * Return value like strcmp(p, q), but consider path separators.
 */
int pathcmp(const char *p, const char *q, int maxlen)
{
  int i;
  int c1, c2;
  const char  *s = NULL;

  for (i = 0; maxlen < 0 || i < maxlen; i += MB_PTR2LEN((char_u *)p + i)) {
    c1 = PTR2CHAR((char_u *)p + i);
    c2 = PTR2CHAR((char_u *)q + i);

    /* End of "p": check if "q" also ends or just has a slash. */
    if (c1 == NUL) {
      if (c2 == NUL)        /* full match */
        return 0;
      s = q;
      break;
    }

    /* End of "q": check if "p" just has a slash. */
    if (c2 == NUL) {
      s = p;
      break;
    }

    if ((p_fic ? MB_TOUPPER(c1) != MB_TOUPPER(c2) : c1 != c2)
#ifdef BACKSLASH_IN_FILENAME
        /* consider '/' and '\\' to be equal */
        && !((c1 == '/' && c2 == '\\')
             || (c1 == '\\' && c2 == '/'))
#endif
        ) {
      if (vim_ispathsep(c1))
        return -1;
      if (vim_ispathsep(c2))
        return 1;
      return p_fic ? MB_TOUPPER(c1) - MB_TOUPPER(c2)
             : c1 - c2;         /* no match */
    }
  }
  if (s == NULL)        /* "i" ran into "maxlen" */
    return 0;

  c1 = PTR2CHAR((char_u *)s + i);
  c2 = PTR2CHAR((char_u *)s + i + MB_PTR2LEN((char_u *)s + i));
  /* ignore a trailing slash, but not "//" or ":/" */
  if (c2 == NUL
      && i > 0
      && !after_pathsep((char_u *)s, (char_u *)s + i)
#ifdef BACKSLASH_IN_FILENAME
      && (c1 == '/' || c1 == '\\')
#else
      && c1 == '/'
#endif
      )
    return 0;       /* match with trailing slash */
  if (s == q)
    return -1;              /* no match */
  return 1;
}
#endif

/*
 * Return 0 for not writable, 1 for writable file, 2 for a dir which we have
 * rights to write into.
 */
int filewritable(char_u *fname)
{
  int retval = 0;
#if defined(UNIX) || defined(VMS)
  int perm = 0;
#endif

#if defined(UNIX) || defined(VMS)
  perm = mch_getperm(fname);
#endif
  if (
# if defined(UNIX) || defined(VMS)
    (perm & 0222) &&
#  endif
    mch_access((char *)fname, W_OK) == 0
    ) {
    ++retval;
    if (mch_isdir(fname))
      ++retval;
  }
  return retval;
}

/*
 * Print an error message with one or two "%s" and one or two string arguments.
 * This is not in message.c to avoid a warning for prototypes.
 */
int emsg3(char_u *s, char_u *a1, char_u *a2)
{
  if (emsg_not_now())
    return TRUE;                /* no error messages at the moment */
#ifdef HAVE_STDARG_H
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, a1, a2);
#else
  vim_snprintf((char *)IObuff, IOSIZE, (char *)s, (long_u)a1, (long_u)a2);
#endif
  return emsg(IObuff);
}

/*
 * Print an error message with one "%ld" and one long int argument.
 * This is not in message.c to avoid a warning for prototypes.
 */
int emsgn(char_u *s, long n)
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
 * Returns NULL when out of memory or unable to read that many bytes.
 */
char_u *read_string(FILE *fd, int cnt)
{
  char_u      *str;
  int i;
  int c;

  /* allocate memory */
  str = alloc((unsigned)cnt + 1);
  if (str != NULL) {
    /* Read the string.  Quit when running into the EOF. */
    for (i = 0; i < cnt; ++i) {
      c = getc(fd);
      if (c == EOF) {
        vim_free(str);
        return NULL;
      }
      str[i] = c;
    }
    str[i] = NUL;
  }
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



#if (defined(FEAT_MBYTE) && defined(FEAT_QUICKFIX)) \
  || defined(FEAT_SPELL) || defined(PROTO)
/*
 * Return TRUE if string "s" contains a non-ASCII character (128 or higher).
 * When "s" is NULL FALSE is returned.
 */
int has_non_ascii(char_u *s)
{
  char_u      *p;

  if (s != NULL)
    for (p = s; *p != NUL; ++p)
      if (*p >= 128)
        return TRUE;
  return FALSE;
}
#endif
