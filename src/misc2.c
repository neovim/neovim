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
#include "charset.h"
#include "edit.h"
#include "eval.h"
#include "ex_docmd.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "mbyte.h"
#include "memfile.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "move.h"
#include "option.h"
#include "os_unix.h"
#include "screen.h"
#include "tag.h"
#include "term.h"
#include "ui.h"
#include "window.h"
#include "os/os.h"

static char_u   *username = NULL; /* cached result of mch_get_user_name() */

static int coladvance2(pos_T *pos, int addspaces, int finetune,
                       colnr_T wcol);

/*
 * Return TRUE if in the current mode we need to use virtual.
 */
int virtual_active(void)         {
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
int getviscol(void)         {
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
  } else   {
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
      } else   {
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
    } else   {
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
int inc_cursor(void)         {
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
int dec_cursor(void)         {
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
    } else if (lnum < cursor)   {
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
void check_cursor_lnum(void)          {
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
void check_cursor_col(void)          {
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
void check_cursor(void)          {
  check_cursor_lnum();
  check_cursor_col();
}

/*
 * Make sure curwin->w_cursor is not on the NUL at the end of the line.
 * Allow it when in Visual mode and 'selection' is not "old".
 */
void adjust_cursor_col(void)          {
  if (curwin->w_cursor.col > 0
      && (!VIsual_active || *p_sel == 'o')
      && gchar_cursor() == NUL)
    --curwin->w_cursor.col;
}

/*
 * When curwin->w_leftcol has changed, adjust the cursor position.
 * Return TRUE if the cursor was moved.
 */
int leftcol_changed(void)         {
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
  } else if (curwin->w_virtcol < curwin->w_leftcol + p_siso)   {
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
  } else if (s < curwin->w_leftcol)   {
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
void vim_mem_profile_dump(void)          {
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
void free_all_mem(void)          {
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
  vim_free(username);
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
int csh_like_shell(void)         {
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

/************************************************************************
 * functions that use lookup tables for various things, generally to do with
 * special key codes.
 */

/*
 * Some useful tables.
 */

static struct modmasktable {
  short mod_mask;               /* Bit-mask for particular key modifier */
  short mod_flag;               /* Bit(s) for particular key modifier */
  char_u name;                  /* Single letter name of modifier */
} mod_mask_table[] =
{
  {MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'M'},
  {MOD_MASK_META,             MOD_MASK_META,          (char_u)'T'},
  {MOD_MASK_CTRL,             MOD_MASK_CTRL,          (char_u)'C'},
  {MOD_MASK_SHIFT,            MOD_MASK_SHIFT,         (char_u)'S'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_2CLICK,        (char_u)'2'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_3CLICK,        (char_u)'3'},
  {MOD_MASK_MULTI_CLICK,      MOD_MASK_4CLICK,        (char_u)'4'},
  /* 'A' must be the last one */
  {MOD_MASK_ALT,              MOD_MASK_ALT,           (char_u)'A'},
  {0, 0, NUL}
};

/*
 * Shifted key terminal codes and their unshifted equivalent.
 * Don't add mouse codes here, they are handled separately!
 */
#define MOD_KEYS_ENTRY_SIZE 5

static char_u modifier_keys_table[] =
{
  /*  mod mask	    with modifier		without modifier */
  MOD_MASK_SHIFT, '&', '9',                   '@', '1',         /* begin */
  MOD_MASK_SHIFT, '&', '0',                   '@', '2',         /* cancel */
  MOD_MASK_SHIFT, '*', '1',                   '@', '4',         /* command */
  MOD_MASK_SHIFT, '*', '2',                   '@', '5',         /* copy */
  MOD_MASK_SHIFT, '*', '3',                   '@', '6',         /* create */
  MOD_MASK_SHIFT, '*', '4',                   'k', 'D',         /* delete char */
  MOD_MASK_SHIFT, '*', '5',                   'k', 'L',         /* delete line */
  MOD_MASK_SHIFT, '*', '7',                   '@', '7',         /* end */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_END,    '@', '7',         /* end */
  MOD_MASK_SHIFT, '*', '9',                   '@', '9',         /* exit */
  MOD_MASK_SHIFT, '*', '0',                   '@', '0',         /* find */
  MOD_MASK_SHIFT, '#', '1',                   '%', '1',         /* help */
  MOD_MASK_SHIFT, '#', '2',                   'k', 'h',         /* home */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_HOME,   'k', 'h',         /* home */
  MOD_MASK_SHIFT, '#', '3',                   'k', 'I',         /* insert */
  MOD_MASK_SHIFT, '#', '4',                   'k', 'l',         /* left arrow */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_LEFT,   'k', 'l',         /* left arrow */
  MOD_MASK_SHIFT, '%', 'a',                   '%', '3',         /* message */
  MOD_MASK_SHIFT, '%', 'b',                   '%', '4',         /* move */
  MOD_MASK_SHIFT, '%', 'c',                   '%', '5',         /* next */
  MOD_MASK_SHIFT, '%', 'd',                   '%', '7',         /* options */
  MOD_MASK_SHIFT, '%', 'e',                   '%', '8',         /* previous */
  MOD_MASK_SHIFT, '%', 'f',                   '%', '9',         /* print */
  MOD_MASK_SHIFT, '%', 'g',                   '%', '0',         /* redo */
  MOD_MASK_SHIFT, '%', 'h',                   '&', '3',         /* replace */
  MOD_MASK_SHIFT, '%', 'i',                   'k', 'r',         /* right arr. */
  MOD_MASK_CTRL,  KS_EXTRA, (int)KE_C_RIGHT,  'k', 'r',         /* right arr. */
  MOD_MASK_SHIFT, '%', 'j',                   '&', '5',         /* resume */
  MOD_MASK_SHIFT, '!', '1',                   '&', '6',         /* save */
  MOD_MASK_SHIFT, '!', '2',                   '&', '7',         /* suspend */
  MOD_MASK_SHIFT, '!', '3',                   '&', '8',         /* undo */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_UP,     'k', 'u',         /* up arrow */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_DOWN,   'k', 'd',         /* down arrow */

  /* vt100 F1 */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF1,    KS_EXTRA, (int)KE_XF1,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF2,    KS_EXTRA, (int)KE_XF2,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF3,    KS_EXTRA, (int)KE_XF3,
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_XF4,    KS_EXTRA, (int)KE_XF4,

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F1,     'k', '1',         /* F1 */
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F2,     'k', '2',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F3,     'k', '3',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F4,     'k', '4',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F5,     'k', '5',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F6,     'k', '6',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F7,     'k', '7',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F8,     'k', '8',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F9,     'k', '9',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F10,    'k', ';',         /* F10 */

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F11,    'F', '1',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F12,    'F', '2',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F13,    'F', '3',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F14,    'F', '4',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F15,    'F', '5',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F16,    'F', '6',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F17,    'F', '7',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F18,    'F', '8',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F19,    'F', '9',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F20,    'F', 'A',

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F21,    'F', 'B',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F22,    'F', 'C',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F23,    'F', 'D',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F24,    'F', 'E',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F25,    'F', 'F',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F26,    'F', 'G',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F27,    'F', 'H',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F28,    'F', 'I',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F29,    'F', 'J',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F30,    'F', 'K',

  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F31,    'F', 'L',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F32,    'F', 'M',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F33,    'F', 'N',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F34,    'F', 'O',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F35,    'F', 'P',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F36,    'F', 'Q',
  MOD_MASK_SHIFT, KS_EXTRA, (int)KE_S_F37,    'F', 'R',

  /* TAB pseudo code*/
  MOD_MASK_SHIFT, 'k', 'B',                   KS_EXTRA, (int)KE_TAB,

  NUL
};

static struct key_name_entry {
  int key;              /* Special key code or ascii value */
  char_u  *name;        /* Name of key */
} key_names_table[] =
{
  {' ',               (char_u *)"Space"},
  {TAB,               (char_u *)"Tab"},
  {K_TAB,             (char_u *)"Tab"},
  {NL,                (char_u *)"NL"},
  {NL,                (char_u *)"NewLine"},     /* Alternative name */
  {NL,                (char_u *)"LineFeed"},    /* Alternative name */
  {NL,                (char_u *)"LF"},          /* Alternative name */
  {CAR,               (char_u *)"CR"},
  {CAR,               (char_u *)"Return"},      /* Alternative name */
  {CAR,               (char_u *)"Enter"},       /* Alternative name */
  {K_BS,              (char_u *)"BS"},
  {K_BS,              (char_u *)"BackSpace"},   /* Alternative name */
  {ESC,               (char_u *)"Esc"},
  {CSI,               (char_u *)"CSI"},
  {K_CSI,             (char_u *)"xCSI"},
  {'|',               (char_u *)"Bar"},
  {'\\',              (char_u *)"Bslash"},
  {K_DEL,             (char_u *)"Del"},
  {K_DEL,             (char_u *)"Delete"},      /* Alternative name */
  {K_KDEL,            (char_u *)"kDel"},
  {K_UP,              (char_u *)"Up"},
  {K_DOWN,            (char_u *)"Down"},
  {K_LEFT,            (char_u *)"Left"},
  {K_RIGHT,           (char_u *)"Right"},
  {K_XUP,             (char_u *)"xUp"},
  {K_XDOWN,           (char_u *)"xDown"},
  {K_XLEFT,           (char_u *)"xLeft"},
  {K_XRIGHT,          (char_u *)"xRight"},

  {K_F1,              (char_u *)"F1"},
  {K_F2,              (char_u *)"F2"},
  {K_F3,              (char_u *)"F3"},
  {K_F4,              (char_u *)"F4"},
  {K_F5,              (char_u *)"F5"},
  {K_F6,              (char_u *)"F6"},
  {K_F7,              (char_u *)"F7"},
  {K_F8,              (char_u *)"F8"},
  {K_F9,              (char_u *)"F9"},
  {K_F10,             (char_u *)"F10"},

  {K_F11,             (char_u *)"F11"},
  {K_F12,             (char_u *)"F12"},
  {K_F13,             (char_u *)"F13"},
  {K_F14,             (char_u *)"F14"},
  {K_F15,             (char_u *)"F15"},
  {K_F16,             (char_u *)"F16"},
  {K_F17,             (char_u *)"F17"},
  {K_F18,             (char_u *)"F18"},
  {K_F19,             (char_u *)"F19"},
  {K_F20,             (char_u *)"F20"},

  {K_F21,             (char_u *)"F21"},
  {K_F22,             (char_u *)"F22"},
  {K_F23,             (char_u *)"F23"},
  {K_F24,             (char_u *)"F24"},
  {K_F25,             (char_u *)"F25"},
  {K_F26,             (char_u *)"F26"},
  {K_F27,             (char_u *)"F27"},
  {K_F28,             (char_u *)"F28"},
  {K_F29,             (char_u *)"F29"},
  {K_F30,             (char_u *)"F30"},

  {K_F31,             (char_u *)"F31"},
  {K_F32,             (char_u *)"F32"},
  {K_F33,             (char_u *)"F33"},
  {K_F34,             (char_u *)"F34"},
  {K_F35,             (char_u *)"F35"},
  {K_F36,             (char_u *)"F36"},
  {K_F37,             (char_u *)"F37"},

  {K_XF1,             (char_u *)"xF1"},
  {K_XF2,             (char_u *)"xF2"},
  {K_XF3,             (char_u *)"xF3"},
  {K_XF4,             (char_u *)"xF4"},

  {K_HELP,            (char_u *)"Help"},
  {K_UNDO,            (char_u *)"Undo"},
  {K_INS,             (char_u *)"Insert"},
  {K_INS,             (char_u *)"Ins"},         /* Alternative name */
  {K_KINS,            (char_u *)"kInsert"},
  {K_HOME,            (char_u *)"Home"},
  {K_KHOME,           (char_u *)"kHome"},
  {K_XHOME,           (char_u *)"xHome"},
  {K_ZHOME,           (char_u *)"zHome"},
  {K_END,             (char_u *)"End"},
  {K_KEND,            (char_u *)"kEnd"},
  {K_XEND,            (char_u *)"xEnd"},
  {K_ZEND,            (char_u *)"zEnd"},
  {K_PAGEUP,          (char_u *)"PageUp"},
  {K_PAGEDOWN,        (char_u *)"PageDown"},
  {K_KPAGEUP,         (char_u *)"kPageUp"},
  {K_KPAGEDOWN,       (char_u *)"kPageDown"},

  {K_KPLUS,           (char_u *)"kPlus"},
  {K_KMINUS,          (char_u *)"kMinus"},
  {K_KDIVIDE,         (char_u *)"kDivide"},
  {K_KMULTIPLY,       (char_u *)"kMultiply"},
  {K_KENTER,          (char_u *)"kEnter"},
  {K_KPOINT,          (char_u *)"kPoint"},

  {K_K0,              (char_u *)"k0"},
  {K_K1,              (char_u *)"k1"},
  {K_K2,              (char_u *)"k2"},
  {K_K3,              (char_u *)"k3"},
  {K_K4,              (char_u *)"k4"},
  {K_K5,              (char_u *)"k5"},
  {K_K6,              (char_u *)"k6"},
  {K_K7,              (char_u *)"k7"},
  {K_K8,              (char_u *)"k8"},
  {K_K9,              (char_u *)"k9"},

  {'<',               (char_u *)"lt"},

  {K_MOUSE,           (char_u *)"Mouse"},
  {K_NETTERM_MOUSE,   (char_u *)"NetMouse"},
  {K_DEC_MOUSE,       (char_u *)"DecMouse"},
#ifdef FEAT_MOUSE_JSB
  {K_JSBTERM_MOUSE,   (char_u *)"JsbMouse"},
#endif
  {K_URXVT_MOUSE,     (char_u *)"UrxvtMouse"},
  {K_SGR_MOUSE,       (char_u *)"SgrMouse"},
  {K_LEFTMOUSE,       (char_u *)"LeftMouse"},
  {K_LEFTMOUSE_NM,    (char_u *)"LeftMouseNM"},
  {K_LEFTDRAG,        (char_u *)"LeftDrag"},
  {K_LEFTRELEASE,     (char_u *)"LeftRelease"},
  {K_LEFTRELEASE_NM,  (char_u *)"LeftReleaseNM"},
  {K_MIDDLEMOUSE,     (char_u *)"MiddleMouse"},
  {K_MIDDLEDRAG,      (char_u *)"MiddleDrag"},
  {K_MIDDLERELEASE,   (char_u *)"MiddleRelease"},
  {K_RIGHTMOUSE,      (char_u *)"RightMouse"},
  {K_RIGHTDRAG,       (char_u *)"RightDrag"},
  {K_RIGHTRELEASE,    (char_u *)"RightRelease"},
  {K_MOUSEDOWN,       (char_u *)"ScrollWheelUp"},
  {K_MOUSEUP,         (char_u *)"ScrollWheelDown"},
  {K_MOUSELEFT,       (char_u *)"ScrollWheelRight"},
  {K_MOUSERIGHT,      (char_u *)"ScrollWheelLeft"},
  {K_MOUSEDOWN,       (char_u *)"MouseDown"},   /* OBSOLETE: Use	  */
  {K_MOUSEUP,         (char_u *)"MouseUp"},     /* ScrollWheelXXX instead */
  {K_X1MOUSE,         (char_u *)"X1Mouse"},
  {K_X1DRAG,          (char_u *)"X1Drag"},
  {K_X1RELEASE,               (char_u *)"X1Release"},
  {K_X2MOUSE,         (char_u *)"X2Mouse"},
  {K_X2DRAG,          (char_u *)"X2Drag"},
  {K_X2RELEASE,               (char_u *)"X2Release"},
  {K_DROP,            (char_u *)"Drop"},
  {K_ZERO,            (char_u *)"Nul"},
  {K_SNR,             (char_u *)"SNR"},
  {K_PLUG,            (char_u *)"Plug"},
  {0,                 NULL}
};

#define KEY_NAMES_TABLE_LEN (sizeof(key_names_table) / \
                             sizeof(struct key_name_entry))

static struct mousetable {
  int pseudo_code;              /* Code for pseudo mouse event */
  int button;                   /* Which mouse button is it? */
  int is_click;                 /* Is it a mouse button click event? */
  int is_drag;                  /* Is it a mouse drag event? */
} mouse_table[] =
{
  {(int)KE_LEFTMOUSE,         MOUSE_LEFT,     TRUE,   FALSE},
  {(int)KE_LEFTDRAG,          MOUSE_LEFT,     FALSE,  TRUE},
  {(int)KE_LEFTRELEASE,       MOUSE_LEFT,     FALSE,  FALSE},
  {(int)KE_MIDDLEMOUSE,       MOUSE_MIDDLE,   TRUE,   FALSE},
  {(int)KE_MIDDLEDRAG,        MOUSE_MIDDLE,   FALSE,  TRUE},
  {(int)KE_MIDDLERELEASE,     MOUSE_MIDDLE,   FALSE,  FALSE},
  {(int)KE_RIGHTMOUSE,        MOUSE_RIGHT,    TRUE,   FALSE},
  {(int)KE_RIGHTDRAG,         MOUSE_RIGHT,    FALSE,  TRUE},
  {(int)KE_RIGHTRELEASE,      MOUSE_RIGHT,    FALSE,  FALSE},
  {(int)KE_X1MOUSE,           MOUSE_X1,       TRUE,   FALSE},
  {(int)KE_X1DRAG,            MOUSE_X1,       FALSE,  TRUE},
  {(int)KE_X1RELEASE,         MOUSE_X1,       FALSE,  FALSE},
  {(int)KE_X2MOUSE,           MOUSE_X2,       TRUE,   FALSE},
  {(int)KE_X2DRAG,            MOUSE_X2,       FALSE,  TRUE},
  {(int)KE_X2RELEASE,         MOUSE_X2,       FALSE,  FALSE},
  /* DRAG without CLICK */
  {(int)KE_IGNORE,            MOUSE_RELEASE,  FALSE,  TRUE},
  /* RELEASE without CLICK */
  {(int)KE_IGNORE,            MOUSE_RELEASE,  FALSE,  FALSE},
  {0,                         0,              0,      0},
};

/*
 * Return the modifier mask bit (MOD_MASK_*) which corresponds to the given
 * modifier name ('S' for Shift, 'C' for Ctrl etc).
 */
int name_to_mod_mask(int c)
{
  int i;

  c = TOUPPER_ASC(c);
  for (i = 0; mod_mask_table[i].mod_mask != 0; i++)
    if (c == mod_mask_table[i].name)
      return mod_mask_table[i].mod_flag;
  return 0;
}

/*
 * Check if if there is a special key code for "key" that includes the
 * modifiers specified.
 */
int simplify_key(int key, int *modifiers)
{
  int i;
  int key0;
  int key1;

  if (*modifiers & (MOD_MASK_SHIFT | MOD_MASK_CTRL | MOD_MASK_ALT)) {
    /* TAB is a special case */
    if (key == TAB && (*modifiers & MOD_MASK_SHIFT)) {
      *modifiers &= ~MOD_MASK_SHIFT;
      return K_S_TAB;
    }
    key0 = KEY2TERMCAP0(key);
    key1 = KEY2TERMCAP1(key);
    for (i = 0; modifier_keys_table[i] != NUL; i += MOD_KEYS_ENTRY_SIZE)
      if (key0 == modifier_keys_table[i + 3]
          && key1 == modifier_keys_table[i + 4]
          && (*modifiers & modifier_keys_table[i])) {
        *modifiers &= ~modifier_keys_table[i];
        return TERMCAP2KEY(modifier_keys_table[i + 1],
            modifier_keys_table[i + 2]);
      }
  }
  return key;
}

/*
 * Change <xHome> to <Home>, <xUp> to <Up>, etc.
 */
int handle_x_keys(int key)
{
  switch (key) {
  case K_XUP:     return K_UP;
  case K_XDOWN:   return K_DOWN;
  case K_XLEFT:   return K_LEFT;
  case K_XRIGHT:  return K_RIGHT;
  case K_XHOME:   return K_HOME;
  case K_ZHOME:   return K_HOME;
  case K_XEND:    return K_END;
  case K_ZEND:    return K_END;
  case K_XF1:     return K_F1;
  case K_XF2:     return K_F2;
  case K_XF3:     return K_F3;
  case K_XF4:     return K_F4;
  case K_S_XF1:   return K_S_F1;
  case K_S_XF2:   return K_S_F2;
  case K_S_XF3:   return K_S_F3;
  case K_S_XF4:   return K_S_F4;
  }
  return key;
}

/*
 * Return a string which contains the name of the given key when the given
 * modifiers are down.
 */
char_u *get_special_key_name(int c, int modifiers)
{
  static char_u string[MAX_KEY_NAME_LEN + 1];

  int i, idx;
  int table_idx;
  char_u  *s;

  string[0] = '<';
  idx = 1;

  /* Key that stands for a normal character. */
  if (IS_SPECIAL(c) && KEY2TERMCAP0(c) == KS_KEY)
    c = KEY2TERMCAP1(c);

  /*
   * Translate shifted special keys into unshifted keys and set modifier.
   * Same for CTRL and ALT modifiers.
   */
  if (IS_SPECIAL(c)) {
    for (i = 0; modifier_keys_table[i] != 0; i += MOD_KEYS_ENTRY_SIZE)
      if (       KEY2TERMCAP0(c) == (int)modifier_keys_table[i + 1]
                 && (int)KEY2TERMCAP1(c) == (int)modifier_keys_table[i + 2]) {
        modifiers |= modifier_keys_table[i];
        c = TERMCAP2KEY(modifier_keys_table[i + 3],
            modifier_keys_table[i + 4]);
        break;
      }
  }

  /* try to find the key in the special key table */
  table_idx = find_special_key_in_table(c);

  /*
   * When not a known special key, and not a printable character, try to
   * extract modifiers.
   */
  if (c > 0
      && (*mb_char2len)(c) == 1
      ) {
    if (table_idx < 0
        && (!vim_isprintc(c) || (c & 0x7f) == ' ')
        && (c & 0x80)) {
      c &= 0x7f;
      modifiers |= MOD_MASK_ALT;
      /* try again, to find the un-alted key in the special key table */
      table_idx = find_special_key_in_table(c);
    }
    if (table_idx < 0 && !vim_isprintc(c) && c < ' ') {
      c += '@';
      modifiers |= MOD_MASK_CTRL;
    }
  }

  /* translate the modifier into a string */
  for (i = 0; mod_mask_table[i].name != 'A'; i++)
    if ((modifiers & mod_mask_table[i].mod_mask)
        == mod_mask_table[i].mod_flag) {
      string[idx++] = mod_mask_table[i].name;
      string[idx++] = (char_u)'-';
    }

  if (table_idx < 0) {          /* unknown special key, may output t_xx */
    if (IS_SPECIAL(c)) {
      string[idx++] = 't';
      string[idx++] = '_';
      string[idx++] = KEY2TERMCAP0(c);
      string[idx++] = KEY2TERMCAP1(c);
    }
    /* Not a special key, only modifiers, output directly */
    else {
      if (has_mbyte && (*mb_char2len)(c) > 1)
        idx += (*mb_char2bytes)(c, string + idx);
      else if (vim_isprintc(c))
        string[idx++] = c;
      else {
        s = transchar(c);
        while (*s)
          string[idx++] = *s++;
      }
    }
  } else   {            /* use name of special key */
    STRCPY(string + idx, key_names_table[table_idx].name);
    idx = (int)STRLEN(string);
  }
  string[idx++] = '>';
  string[idx] = NUL;
  return string;
}

/*
 * Try translating a <> name at (*srcp)[] to dst[].
 * Return the number of characters added to dst[], zero for no match.
 * If there is a match, srcp is advanced to after the <> name.
 * dst[] must be big enough to hold the result (up to six characters)!
 */
int 
trans_special (
    char_u **srcp,
    char_u *dst,
    int keycode             /* prefer key code, e.g. K_DEL instead of DEL */
)
{
  int modifiers = 0;
  int key;
  int dlen = 0;

  key = find_special_key(srcp, &modifiers, keycode, FALSE);
  if (key == 0)
    return 0;

  /* Put the appropriate modifier in a string */
  if (modifiers != 0) {
    dst[dlen++] = K_SPECIAL;
    dst[dlen++] = KS_MODIFIER;
    dst[dlen++] = modifiers;
  }

  if (IS_SPECIAL(key)) {
    dst[dlen++] = K_SPECIAL;
    dst[dlen++] = KEY2TERMCAP0(key);
    dst[dlen++] = KEY2TERMCAP1(key);
  } else if (has_mbyte && !keycode)
    dlen += (*mb_char2bytes)(key, dst + dlen);
  else if (keycode)
    dlen = (int)(add_char2buf(key, dst + dlen) - dst);
  else
    dst[dlen++] = key;

  return dlen;
}

/*
 * Try translating a <> name at (*srcp)[], return the key and modifiers.
 * srcp is advanced to after the <> name.
 * returns 0 if there is no match.
 */
int 
find_special_key (
    char_u **srcp,
    int *modp,
    int keycode,                 /* prefer key code, e.g. K_DEL instead of DEL */
    int keep_x_key              /* don't translate xHome to Home key */
)
{
  char_u      *last_dash;
  char_u      *end_of_name;
  char_u      *src;
  char_u      *bp;
  int modifiers;
  int bit;
  int key;
  unsigned long n;
  int l;

  src = *srcp;
  if (src[0] != '<')
    return 0;

  /* Find end of modifier list */
  last_dash = src;
  for (bp = src + 1; *bp == '-' || vim_isIDc(*bp); bp++) {
    if (*bp == '-') {
      last_dash = bp;
      if (bp[1] != NUL) {
        if (has_mbyte)
          l = mb_ptr2len(bp + 1);
        else
          l = 1;
        if (bp[l + 1] == '>')
          bp += l;              /* anything accepted, like <C-?> */
      }
    }
    if (bp[0] == 't' && bp[1] == '_' && bp[2] && bp[3])
      bp += 3;          /* skip t_xx, xx may be '-' or '>' */
    else if (STRNICMP(bp, "char-", 5) == 0) {
      vim_str2nr(bp + 5, NULL, &l, TRUE, TRUE, NULL, NULL);
      bp += l + 5;
      break;
    }
  }

  if (*bp == '>') {     /* found matching '>' */
    end_of_name = bp + 1;

    /* Which modifiers are given? */
    modifiers = 0x0;
    for (bp = src + 1; bp < last_dash; bp++) {
      if (*bp != '-') {
        bit = name_to_mod_mask(*bp);
        if (bit == 0x0)
          break;                /* Illegal modifier name */
        modifiers |= bit;
      }
    }

    /*
     * Legal modifier name.
     */
    if (bp >= last_dash) {
      if (STRNICMP(last_dash + 1, "char-", 5) == 0
          && VIM_ISDIGIT(last_dash[6])) {
        /* <Char-123> or <Char-033> or <Char-0x33> */
        vim_str2nr(last_dash + 6, NULL, NULL, TRUE, TRUE, NULL, &n);
        key = (int)n;
      } else   {
        /*
         * Modifier with single letter, or special key name.
         */
        if (has_mbyte)
          l = mb_ptr2len(last_dash + 1);
        else
          l = 1;
        if (modifiers != 0 && last_dash[l + 1] == '>')
          key = PTR2CHAR(last_dash + 1);
        else {
          key = get_special_key_code(last_dash + 1);
          if (!keep_x_key)
            key = handle_x_keys(key);
        }
      }

      /*
       * get_special_key_code() may return NUL for invalid
       * special key name.
       */
      if (key != NUL) {
        /*
         * Only use a modifier when there is no special key code that
         * includes the modifier.
         */
        key = simplify_key(key, &modifiers);

        if (!keycode) {
          /* don't want keycode, use single byte code */
          if (key == K_BS)
            key = BS;
          else if (key == K_DEL || key == K_KDEL)
            key = DEL;
        }

        /*
         * Normal Key with modifier: Try to make a single byte code.
         */
        if (!IS_SPECIAL(key))
          key = extract_modifiers(key, &modifiers);

        *modp = modifiers;
        *srcp = end_of_name;
        return key;
      }
    }
  }
  return 0;
}

/*
 * Try to include modifiers in the key.
 * Changes "Shift-a" to 'A', "Alt-A" to 0xc0, etc.
 */
int extract_modifiers(int key, int *modp)
{
  int modifiers = *modp;

  if ((modifiers & MOD_MASK_SHIFT) && ASCII_ISALPHA(key)) {
    key = TOUPPER_ASC(key);
    modifiers &= ~MOD_MASK_SHIFT;
  }
  if ((modifiers & MOD_MASK_CTRL)
      && ((key >= '?' && key <= '_') || ASCII_ISALPHA(key))
      ) {
    key = Ctrl_chr(key);
    modifiers &= ~MOD_MASK_CTRL;
    /* <C-@> is <Nul> */
    if (key == 0)
      key = K_ZERO;
  }
  if ((modifiers & MOD_MASK_ALT) && key < 0x80
      && !enc_dbcs                      /* avoid creating a lead byte */
      ) {
    key |= 0x80;
    modifiers &= ~MOD_MASK_ALT;         /* remove the META modifier */
  }

  *modp = modifiers;
  return key;
}

/*
 * Try to find key "c" in the special key table.
 * Return the index when found, -1 when not found.
 */
int find_special_key_in_table(int c)
{
  int i;

  for (i = 0; key_names_table[i].name != NULL; i++)
    if (c == key_names_table[i].key)
      break;
  if (key_names_table[i].name == NULL)
    i = -1;
  return i;
}

/*
 * Find the special key with the given name (the given string does not have to
 * end with NUL, the name is assumed to end before the first non-idchar).
 * If the name starts with "t_" the next two characters are interpreted as a
 * termcap name.
 * Return the key code, or 0 if not found.
 */
int get_special_key_code(char_u *name)
{
  char_u  *table_name;
  char_u string[3];
  int i, j;

  /*
   * If it's <t_xx> we get the code for xx from the termcap
   */
  if (name[0] == 't' && name[1] == '_' && name[2] != NUL && name[3] != NUL) {
    string[0] = name[2];
    string[1] = name[3];
    string[2] = NUL;
    if (add_termcap_entry(string, FALSE) == OK)
      return TERMCAP2KEY(name[2], name[3]);
  } else
    for (i = 0; key_names_table[i].name != NULL; i++) {
      table_name = key_names_table[i].name;
      for (j = 0; vim_isIDc(name[j]) && table_name[j] != NUL; j++)
        if (TOLOWER_ASC(table_name[j]) != TOLOWER_ASC(name[j]))
          break;
      if (!vim_isIDc(name[j]) && table_name[j] == NUL)
        return key_names_table[i].key;
    }
  return 0;
}

char_u *get_key_name(int i)
{
  if (i >= (int)KEY_NAMES_TABLE_LEN)
    return NULL;
  return key_names_table[i].name;
}

/*
 * Look up the given mouse code to return the relevant information in the other
 * arguments.  Return which button is down or was released.
 */
int get_mouse_button(int code, int *is_click, int *is_drag)
{
  int i;

  for (i = 0; mouse_table[i].pseudo_code; i++)
    if (code == mouse_table[i].pseudo_code) {
      *is_click = mouse_table[i].is_click;
      *is_drag = mouse_table[i].is_drag;
      return mouse_table[i].button;
    }
  return 0;         /* Shouldn't get here */
}

/*
 * Return the appropriate pseudo mouse event token (KE_LEFTMOUSE etc) based on
 * the given information about which mouse button is down, and whether the
 * mouse was clicked, dragged or released.
 */
int 
get_pseudo_mouse_code (
    int button,             /* eg MOUSE_LEFT */
    int is_click,
    int is_drag
)
{
  int i;

  for (i = 0; mouse_table[i].pseudo_code; i++)
    if (button == mouse_table[i].button
        && is_click == mouse_table[i].is_click
        && is_drag == mouse_table[i].is_drag) {
      return mouse_table[i].pseudo_code;
    }
  return (int)KE_IGNORE;            /* not recognized, ignore it */
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
int default_fileformat(void)         {
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
  } else   {
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
int get_real_state(void)         {
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

#if defined(CURSOR_SHAPE) || defined(PROTO)

/*
 * Handling of cursor and mouse pointer shapes in various modes.
 */

cursorentry_T shape_table[SHAPE_IDX_COUNT] =
{
  /* The values will be filled in from the 'guicursor' and 'mouseshape'
   * defaults when Vim starts.
   * Adjust the SHAPE_IDX_ defines when making changes! */
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "n", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "v", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "i", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "r", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "c", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "ci", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "cr", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "o", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "ve", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "e", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "s", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "sd", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "vs", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "vd", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "m", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "ml", SHAPE_MOUSE},
  {0, 0, 0, 100L, 100L, 100L, 0, 0, "sm", SHAPE_CURSOR},
};


/*
 * Parse the 'guicursor' option ("what" is SHAPE_CURSOR) or 'mouseshape'
 * ("what" is SHAPE_MOUSE).
 * Returns error message for an illegal option, NULL otherwise.
 */
char_u *parse_shape_opt(int what)
{
  char_u      *modep;
  char_u      *colonp;
  char_u      *commap;
  char_u      *slashp;
  char_u      *p, *endp;
  int idx = 0;                          /* init for GCC */
  int all_idx;
  int len;
  int i;
  long n;
  int found_ve = FALSE;                 /* found "ve" flag */
  int round;

  /*
   * First round: check for errors; second round: do it for real.
   */
  for (round = 1; round <= 2; ++round) {
    /*
     * Repeat for all comma separated parts.
     */
    modep = p_guicursor;
    while (*modep != NUL) {
      colonp = vim_strchr(modep, ':');
      if (colonp == NULL)
        return (char_u *)N_("E545: Missing colon");
      if (colonp == modep)
        return (char_u *)N_("E546: Illegal mode");
      commap = vim_strchr(modep, ',');

      /*
       * Repeat for all mode's before the colon.
       * For the 'a' mode, we loop to handle all the modes.
       */
      all_idx = -1;
      while (modep < colonp || all_idx > = 0) {
        if (all_idx < 0) {
          /* Find the mode. */
          if (modep[1] == '-' || modep[1] == ':')
            len = 1;
          else
            len = 2;
          if (len == 1 && TOLOWER_ASC(modep[0]) == 'a')
            all_idx = SHAPE_IDX_COUNT - 1;
          else {
            for (idx = 0; idx < SHAPE_IDX_COUNT; ++idx)
              if (STRNICMP(modep, shape_table[idx].name, len)
                  == 0)
                break;
            if (idx == SHAPE_IDX_COUNT
                || (shape_table[idx].used_for & what) == 0)
              return (char_u *)N_("E546: Illegal mode");
            if (len == 2 && modep[0] == 'v' && modep[1] == 'e')
              found_ve = TRUE;
          }
          modep += len + 1;
        }

        if (all_idx >= 0)
          idx = all_idx--;
        else if (round == 2) {
          {
            /* Set the defaults, for the missing parts */
            shape_table[idx].shape = SHAPE_BLOCK;
            shape_table[idx].blinkwait = 700L;
            shape_table[idx].blinkon = 400L;
            shape_table[idx].blinkoff = 250L;
          }
        }

        /* Parse the part after the colon */
        for (p = colonp + 1; *p && *p != ','; ) {
          {
            /*
             * First handle the ones with a number argument.
             */
            i = *p;
            len = 0;
            if (STRNICMP(p, "ver", 3) == 0)
              len = 3;
            else if (STRNICMP(p, "hor", 3) == 0)
              len = 3;
            else if (STRNICMP(p, "blinkwait", 9) == 0)
              len = 9;
            else if (STRNICMP(p, "blinkon", 7) == 0)
              len = 7;
            else if (STRNICMP(p, "blinkoff", 8) == 0)
              len = 8;
            if (len != 0) {
              p += len;
              if (!VIM_ISDIGIT(*p))
                return (char_u *)N_("E548: digit expected");
              n = getdigits(&p);
              if (len == 3) {               /* "ver" or "hor" */
                if (n == 0)
                  return (char_u *)N_("E549: Illegal percentage");
                if (round == 2) {
                  if (TOLOWER_ASC(i) == 'v')
                    shape_table[idx].shape = SHAPE_VER;
                  else
                    shape_table[idx].shape = SHAPE_HOR;
                  shape_table[idx].percentage = n;
                }
              } else if (round == 2)   {
                if (len == 9)
                  shape_table[idx].blinkwait = n;
                else if (len == 7)
                  shape_table[idx].blinkon = n;
                else
                  shape_table[idx].blinkoff = n;
              }
            } else if (STRNICMP(p, "block", 5) == 0)   {
              if (round == 2)
                shape_table[idx].shape = SHAPE_BLOCK;
              p += 5;
            } else   {          /* must be a highlight group name then */
              endp = vim_strchr(p, '-');
              if (commap == NULL) {                         /* last part */
                if (endp == NULL)
                  endp = p + STRLEN(p);                     /* find end of part */
              } else if (endp > commap || endp == NULL)
                endp = commap;
              slashp = vim_strchr(p, '/');
              if (slashp != NULL && slashp < endp) {
                /* "group/langmap_group" */
                i = syn_check_group(p, (int)(slashp - p));
                p = slashp + 1;
              }
              if (round == 2) {
                shape_table[idx].id = syn_check_group(p,
                    (int)(endp - p));
                shape_table[idx].id_lm = shape_table[idx].id;
                if (slashp != NULL && slashp < endp)
                  shape_table[idx].id = i;
              }
              p = endp;
            }
          }           /* if (what != SHAPE_MOUSE) */

          if (*p == '-')
            ++p;
        }
      }
      modep = p;
      if (*modep == ',')
        ++modep;
    }
  }

  /* If the 's' flag is not given, use the 'v' cursor for 's' */
  if (!found_ve) {
    {
      shape_table[SHAPE_IDX_VE].shape = shape_table[SHAPE_IDX_V].shape;
      shape_table[SHAPE_IDX_VE].percentage =
        shape_table[SHAPE_IDX_V].percentage;
      shape_table[SHAPE_IDX_VE].blinkwait =
        shape_table[SHAPE_IDX_V].blinkwait;
      shape_table[SHAPE_IDX_VE].blinkon =
        shape_table[SHAPE_IDX_V].blinkon;
      shape_table[SHAPE_IDX_VE].blinkoff =
        shape_table[SHAPE_IDX_V].blinkoff;
      shape_table[SHAPE_IDX_VE].id = shape_table[SHAPE_IDX_V].id;
      shape_table[SHAPE_IDX_VE].id_lm = shape_table[SHAPE_IDX_V].id_lm;
    }
  }

  return NULL;
}

# if defined(MCH_CURSOR_SHAPE) || defined(FEAT_GUI) \
  || defined(FEAT_MOUSESHAPE) || defined(PROTO)
/*
 * Return the index into shape_table[] for the current mode.
 * When "mouse" is TRUE, consider indexes valid for the mouse pointer.
 */
int get_shape_idx(int mouse)
{
  if (!mouse && State == SHOWMATCH)
    return SHAPE_IDX_SM;
  if (State & VREPLACE_FLAG)
    return SHAPE_IDX_R;
  if (State & REPLACE_FLAG)
    return SHAPE_IDX_R;
  if (State & INSERT)
    return SHAPE_IDX_I;
  if (State & CMDLINE) {
    if (cmdline_at_end())
      return SHAPE_IDX_C;
    if (cmdline_overstrike())
      return SHAPE_IDX_CR;
    return SHAPE_IDX_CI;
  }
  if (finish_op)
    return SHAPE_IDX_O;
  if (VIsual_active) {
    if (*p_sel == 'e')
      return SHAPE_IDX_VE;
    else
      return SHAPE_IDX_V;
  }
  return SHAPE_IDX_N;
}
#endif


#endif /* CURSOR_SHAPE */


/*
 * Optional encryption support.
 * Mohsin Ahmed, mosh@sasi.com, 98-09-24
 * Based on zip/crypt sources.
 *
 * NOTE FOR USA: Since 2000 exporting this code from the USA is allowed to
 * most countries.  There are a few exceptions, but that still should not be a
 * problem since this code was originally created in Europe and India.
 *
 * Blowfish addition originally made by Mohsin Ahmed,
 * http://www.cs.albany.edu/~mosh 2010-03-14
 * Based on blowfish by Bruce Schneier (http://www.schneier.com/blowfish.html)
 * and sha256 by Christophe Devine.
 */

/* from zip.h */

typedef unsigned short ush;     /* unsigned 16-bit value */
typedef unsigned long ulg;      /* unsigned 32-bit value */

static void make_crc_tab(void);

static ulg crc_32_tab[256];

/*
 * Fill the CRC table.
 */
static void make_crc_tab(void)                 {
  ulg s,t,v;
  static int done = FALSE;

  if (done)
    return;
  for (t = 0; t < 256; t++) {
    v = t;
    for (s = 0; s < 8; s++)
      v = (v >> 1) ^ ((v & 1) * (ulg)0xedb88320L);
    crc_32_tab[t] = v;
  }
  done = TRUE;
}

#define CRC32(c, b) (crc_32_tab[((int)(c) ^ (b)) & 0xff] ^ ((c) >> 8))

static ulg keys[3]; /* keys defining the pseudo-random sequence */

/*
 * Return the next byte in the pseudo-random sequence.
 */
#define DECRYPT_BYTE_ZIP(t) { \
    ush temp; \
 \
    temp = (ush)keys[2] | 2; \
    t = (int)(((unsigned)(temp * (temp ^ 1U)) >> 8) & 0xff); \
}

/*
 * Update the encryption keys with the next byte of plain text.
 */
#define UPDATE_KEYS_ZIP(c) { \
    keys[0] = CRC32(keys[0], (c)); \
    keys[1] += keys[0] & 0xff; \
    keys[1] = keys[1] * 134775813L + 1; \
    keys[2] = CRC32(keys[2], (int)(keys[1] >> 24)); \
}

static int crypt_busy = 0;
static ulg saved_keys[3];
static int saved_crypt_method;

/*
 * Return int value for crypt method string:
 * 0 for "zip", the old method.  Also for any non-valid value.
 * 1 for "blowfish".
 */
int crypt_method_from_string(char_u *s)
{
  return *s == 'b' ? 1 : 0;
}

/*
 * Get the crypt method for buffer "buf" as a number.
 */
int get_crypt_method(buf_T *buf)
{
  return crypt_method_from_string(*buf->b_p_cm == NUL ? p_cm : buf->b_p_cm);
}

/*
 * Set the crypt method for buffer "buf" to "method" using the int value as
 * returned by crypt_method_from_string().
 */
void set_crypt_method(buf_T *buf, int method)
{
  free_string_option(buf->b_p_cm);
  buf->b_p_cm = vim_strsave((char_u *)(method == 0 ? "zip" : "blowfish"));
}

/*
 * Prepare for initializing encryption.  If already doing encryption then save
 * the state.
 * Must always be called symmetrically with crypt_pop_state().
 */
void crypt_push_state(void)          {
  if (crypt_busy == 1) {
    /* save the state */
    if (use_crypt_method == 0) {
      saved_keys[0] = keys[0];
      saved_keys[1] = keys[1];
      saved_keys[2] = keys[2];
    } else
      bf_crypt_save();
    saved_crypt_method = use_crypt_method;
  } else if (crypt_busy > 1)
    EMSG2(_(e_intern2), "crypt_push_state()");
  ++crypt_busy;
}

/*
 * End encryption.  If doing encryption before crypt_push_state() then restore
 * the saved state.
 * Must always be called symmetrically with crypt_push_state().
 */
void crypt_pop_state(void)          {
  --crypt_busy;
  if (crypt_busy == 1) {
    use_crypt_method = saved_crypt_method;
    if (use_crypt_method == 0) {
      keys[0] = saved_keys[0];
      keys[1] = saved_keys[1];
      keys[2] = saved_keys[2];
    } else
      bf_crypt_restore();
  }
}

/*
 * Encrypt "from[len]" into "to[len]".
 * "from" and "to" can be equal to encrypt in place.
 */
void crypt_encode(char_u *from, size_t len, char_u *to)
{
  size_t i;
  int ztemp, t;

  if (use_crypt_method == 0)
    for (i = 0; i < len; ++i) {
      ztemp = from[i];
      DECRYPT_BYTE_ZIP(t);
      UPDATE_KEYS_ZIP(ztemp);
      to[i] = t ^ ztemp;
    }
  else
    bf_crypt_encode(from, len, to);
}

/*
 * Decrypt "ptr[len]" in place.
 */
void crypt_decode(char_u *ptr, long len)
{
  char_u *p;

  if (use_crypt_method == 0)
    for (p = ptr; p < ptr + len; ++p) {
      ush temp;

      temp = (ush)keys[2] | 2;
      temp = (int)(((unsigned)(temp * (temp ^ 1U)) >> 8) & 0xff);
      UPDATE_KEYS_ZIP(*p ^= temp);
    }
  else
    bf_crypt_decode(ptr, len);
}

/*
 * Initialize the encryption keys and the random header according to
 * the given password.
 * If "passwd" is NULL or empty, don't do anything.
 */
void 
crypt_init_keys (
    char_u *passwd                 /* password string with which to modify keys */
)
{
  if (passwd != NULL && *passwd != NUL) {
    if (use_crypt_method == 0) {
      char_u *p;

      make_crc_tab();
      keys[0] = 305419896L;
      keys[1] = 591751049L;
      keys[2] = 878082192L;
      for (p = passwd; *p!= NUL; ++p) {
        UPDATE_KEYS_ZIP((int)*p);
      }
    } else
      bf_crypt_init_keys(passwd);
  }
}

/*
 * Free an allocated crypt key.  Clear the text to make sure it doesn't stay
 * in memory anywhere.
 */
void free_crypt_key(char_u *key)
{
  char_u *p;

  if (key != NULL) {
    for (p = key; *p != NUL; ++p)
      *p = 0;
    vim_free(key);
  }
}

/*
 * Ask the user for a crypt key.
 * When "store" is TRUE, the new key is stored in the 'key' option, and the
 * 'key' option value is returned: Don't free it.
 * When "store" is FALSE, the typed key is returned in allocated memory.
 * Returns NULL on failure.
 */
char_u *
get_crypt_key (
    int store,
    int twice                  /* Ask for the key twice. */
)
{
  char_u      *p1, *p2 = NULL;
  int round;

  for (round = 0;; ++round) {
    cmdline_star = TRUE;
    cmdline_row = msg_row;
    p1 = getcmdline_prompt(NUL, round == 0
        ? (char_u *)_("Enter encryption key: ")
        : (char_u *)_("Enter same key again: "), 0, EXPAND_NOTHING,
        NULL);
    cmdline_star = FALSE;

    if (p1 == NULL)
      break;

    if (round == twice) {
      if (p2 != NULL && STRCMP(p1, p2) != 0) {
        MSG(_("Keys don't match!"));
        free_crypt_key(p1);
        free_crypt_key(p2);
        p2 = NULL;
        round = -1;                     /* do it again */
        continue;
      }

      if (store) {
        set_option_value((char_u *)"key", 0L, p1, OPT_LOCAL);
        free_crypt_key(p1);
        p1 = curbuf->b_p_key;
      }
      break;
    }
    p2 = p1;
  }

  /* since the user typed this, no need to wait for return */
  if (msg_didout)
    msg_putchar('\n');
  need_wait_return = FALSE;
  msg_didout = FALSE;

  free_crypt_key(p2);
  return p1;
}


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

/*
 * Get user name from machine-specific function.
 * Returns the user name in "buf[len]".
 * Some systems are quite slow in obtaining the user name (Windows NT), thus
 * cache the result.
 * Returns OK or FAIL.
 */
int get_user_name(char_u *buf, int len)
{
  if (username == NULL) {
    if (mch_get_user_name(buf, len) == FAIL)
      return FAIL;
    username = vim_strsave(buf);
  } else
    vim_strncpy(buf, username, len - 1);
  return OK;
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
 * The putenv() implementation below comes from the "screen" program.
 * Included with permission from Juergen Weigert.
 * See pty.c for the copyright notice.
 */

/*
 *  putenv  --	put value into environment
 *
 *  Usage:  i = putenv (string)
 *    int i;
 *    char  *string;
 *
 *  where string is of the form <name>=<value>.
 *  Putenv returns 0 normally, -1 on error (not enough core for malloc).
 *
 *  Putenv may need to add a new name into the environment, or to
 *  associate a value longer than the current value with a particular
 *  name.  So, to make life simpler, putenv() copies your entire
 *  environment into the heap (i.e. malloc()) from the stack
 *  (i.e. where it resides when your process is initiated) the first
 *  time you call it.
 *
 *  (history removed, not very interesting.  See the "screen" sources.)
 */

#if !defined(HAVE_SETENV) && !defined(HAVE_PUTENV)

#define EXTRASIZE 5             /* increment to add to env. size */

static int envsize = -1;        /* current size of environment */
extern
char **environ;                 /* the global which is your env. */

static int findenv(char *name);  /* look for a name in the env. */
static int newenv(void);       /* copy env. from stack to heap */
static int moreenv(void);      /* incr. size of env. */

int putenv(const char *string)
{
  int i;
  char    *p;

  if (envsize < 0) {            /* first time putenv called */
    if (newenv() < 0)           /* copy env. to heap */
      return -1;
  }

  i = findenv((char *)string);   /* look for name in environment */

  if (i < 0) {                  /* name must be added */
    for (i = 0; environ[i]; i++) ;
    if (i >= (envsize - 1)) {   /* need new slot */
      if (moreenv() < 0)
        return -1;
    }
    p = (char *)alloc((unsigned)(strlen(string) + 1));
    if (p == NULL)              /* not enough core */
      return -1;
    environ[i + 1] = 0;         /* new end of env. */
  } else   {                    /* name already in env. */
    p = vim_realloc(environ[i], strlen(string) + 1);
    if (p == NULL)
      return -1;
  }
  sprintf(p, "%s", string);     /* copy into env. */
  environ[i] = p;

  return 0;
}

static int findenv(char *name)
{
  char    *namechar, *envchar;
  int i, found;

  found = 0;
  for (i = 0; environ[i] && !found; i++) {
    envchar = environ[i];
    namechar = name;
    while (*namechar && *namechar != '=' && (*namechar == *envchar)) {
      namechar++;
      envchar++;
    }
    found = ((*namechar == '\0' || *namechar == '=') && *envchar == '=');
  }
  return found ? i - 1 : -1;
}

static int newenv(void)                {
  char    **env, *elem;
  int i, esize;

  for (i = 0; environ[i]; i++)
    ;
  esize = i + EXTRASIZE + 1;
  env = (char **)alloc((unsigned)(esize * sizeof (elem)));
  if (env == NULL)
    return -1;

  for (i = 0; environ[i]; i++) {
    elem = (char *)alloc((unsigned)(strlen(environ[i]) + 1));
    if (elem == NULL)
      return -1;
    env[i] = elem;
    strcpy(elem, environ[i]);
  }

  env[i] = 0;
  environ = env;
  envsize = esize;
  return 0;
}

static int moreenv(void)                {
  int esize;
  char    **env;

  esize = envsize + EXTRASIZE;
  env = (char **)vim_realloc((char *)environ, esize * sizeof (*env));
  if (env == 0)
    return -1;
  environ = env;
  envsize = esize;
  return 0;
}

# ifdef USE_VIMPTY_GETENV
char_u *vimpty_getenv(const char_u *string)
{
  int i;
  char_u *p;

  if (envsize < 0)
    return NULL;

  i = findenv((char *)string);

  if (i < 0)
    return NULL;

  p = vim_strchr((char_u *)environ[i], '=');
  return p + 1;
}
# endif

#endif /* !defined(HAVE_SETENV) && !defined(HAVE_PUTENV) */

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
