/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read a list of people who contributed.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#include "vim.h"
#include "window.h"
#include "buffer.h"
#include "charset.h"
#include "diff.h"
#include "edit.h"
#include "eval.h"
#include "ex_cmds.h"
#include "ex_cmds2.h"
#include "ex_docmd.h"
#include "ex_eval.h"
#include "ex_getln.h"
#include "fileio.h"
#include "fold.h"
#include "getchar.h"
#include "hashtab.h"
#include "main.h"
#include "mark.h"
#include "memline.h"
#include "message.h"
#include "misc1.h"
#include "misc2.h"
#include "file_search.h"
#include "garray.h"
#include "move.h"
#include "normal.h"
#include "option.h"
#include "os_unix.h"
#include "quickfix.h"
#include "regexp.h"
#include "screen.h"
#include "search.h"
#include "syntax.h"
#include "term.h"
#include "undo.h"
#include "os/os.h"

static int path_is_url(char_u *p);
static void win_init(win_T *newp, win_T *oldp, int flags);
static void win_init_some(win_T *newp, win_T *oldp);
static void frame_comp_pos(frame_T *topfrp, int *row, int *col);
static void frame_setheight(frame_T *curfrp, int height);
static void frame_setwidth(frame_T *curfrp, int width);
static void win_exchange(long);
static void win_rotate(int, int);
static void win_totop(int size, int flags);
static void win_equal_rec(win_T *next_curwin, int current, frame_T *topfr,
                          int dir, int col, int row, int width,
                          int height);
static int last_window(void);
static int close_last_window_tabpage(win_T *win, int free_buf,
                                     tabpage_T *prev_curtab);
static win_T *win_free_mem(win_T *win, int *dirp, tabpage_T *tp);
static frame_T *win_altframe(win_T *win, tabpage_T *tp);
static tabpage_T *alt_tabpage(void);
static win_T *frame2win(frame_T *frp);
static int frame_has_win(frame_T *frp, win_T *wp);
static void frame_new_height(frame_T *topfrp, int height, int topfirst,
                             int wfh);
static int frame_fixed_height(frame_T *frp);
static int frame_fixed_width(frame_T *frp);
static void frame_add_statusline(frame_T *frp);
static void frame_new_width(frame_T *topfrp, int width, int leftfirst,
                            int wfw);
static void frame_add_vsep(frame_T *frp);
static int frame_minwidth(frame_T *topfrp, win_T *next_curwin);
static void frame_fix_width(win_T *wp);
static int win_alloc_firstwin(win_T *oldwin);
static void new_frame(win_T *wp);
static tabpage_T *alloc_tabpage(void);
static int leave_tabpage(buf_T *new_curbuf, int trigger_leave_autocmds);
static void enter_tabpage(tabpage_T *tp, buf_T *old_curbuf,
                          int trigger_enter_autocmds,
                          int trigger_leave_autocmds);
static void frame_fix_height(win_T *wp);
static int frame_minheight(frame_T *topfrp, win_T *next_curwin);
static void win_enter_ext(win_T *wp, int undo_sync, int no_curwin,
                          int trigger_enter_autocmds,
                          int trigger_leave_autocmds);
static void win_free(win_T *wp, tabpage_T *tp);
static void frame_append(frame_T *after, frame_T *frp);
static void frame_insert(frame_T *before, frame_T *frp);
static void frame_remove(frame_T *frp);
static void win_goto_ver(int up, long count);
static void win_goto_hor(int left, long count);
static void frame_add_height(frame_T *frp, int n);
static void last_status_rec(frame_T *fr, int statusline);

static void make_snapshot_rec(frame_T *fr, frame_T **frp);
static void clear_snapshot(tabpage_T *tp, int idx);
static void clear_snapshot_rec(frame_T *fr);
static int check_snapshot_rec(frame_T *sn, frame_T *fr);
static win_T *restore_snapshot_rec(frame_T *sn, frame_T *fr);

static int frame_check_height(frame_T *topfrp, int height);
static int frame_check_width(frame_T *topfrp, int width);


static win_T *win_alloc(win_T *after, int hidden);
static void set_fraction(win_T *wp);

#define URL_SLASH       1               /* path_is_url() has found "://" */
#define URL_BACKSLASH   2               /* path_is_url() has found ":\\" */

#define NOWIN           (win_T *)-1     /* non-existing window */

# define ROWS_AVAIL (Rows - p_ch - tabline_height())


static char *m_onlyone = N_("Already only one window");

/*
 * all CTRL-W window commands are handled here, called from normal_cmd().
 */
void 
do_window (
    int nchar,
    long Prenum,
    int xchar                  /* extra char from ":wincmd gx" or NUL */
)
{
  long Prenum1;
  win_T       *wp;
  char_u      *ptr;
  linenr_T lnum = -1;
  int type = FIND_DEFINE;
  int len;
  char_u cbuf[40];

  if (Prenum == 0)
    Prenum1 = 1;
  else
    Prenum1 = Prenum;

# define CHECK_CMDWIN if (cmdwin_type != 0) { EMSG(_(e_cmdwin)); break; }

  switch (nchar) {
  /* split current window in two parts, horizontally */
  case 'S':
  case Ctrl_S:
  case 's':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    /* When splitting the quickfix window open a new buffer in it,
     * don't replicate the quickfix buffer. */
    if (bt_quickfix(curbuf))
      goto newwindow;
    win_split((int)Prenum, 0);
    break;

  /* split current window in two parts, vertically */
  case Ctrl_V:
  case 'v':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    /* When splitting the quickfix window open a new buffer in it,
     * don't replicate the quickfix buffer. */
    if (bt_quickfix(curbuf))
      goto newwindow;
    win_split((int)Prenum, WSP_VERT);
    break;

  /* split current window and edit alternate file */
  case Ctrl_HAT:
  case '^':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    STRCPY(cbuf, "split #");
    if (Prenum)
      vim_snprintf((char *)cbuf + 7, sizeof(cbuf) - 7,
          "%ld", Prenum);
    do_cmdline_cmd(cbuf);
    break;

  /* open new window */
  case Ctrl_N:
  case 'n':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
newwindow:
    if (Prenum)
      /* window height */
      vim_snprintf((char *)cbuf, sizeof(cbuf) - 5, "%ld", Prenum);
    else
      cbuf[0] = NUL;
    if (nchar == 'v' || nchar == Ctrl_V)
      STRCAT(cbuf, "v");
    STRCAT(cbuf, "new");
    do_cmdline_cmd(cbuf);
    break;

  /* quit current window */
  case Ctrl_Q:
  case 'q':
    reset_VIsual_and_resel();                   /* stop Visual mode */
    do_cmdline_cmd((char_u *)"quit");
    break;

  /* close current window */
  case Ctrl_C:
  case 'c':
    reset_VIsual_and_resel();                   /* stop Visual mode */
    do_cmdline_cmd((char_u *)"close");
    break;

  /* close preview window */
  case Ctrl_Z:
  case 'z':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    do_cmdline_cmd((char_u *)"pclose");
    break;

  /* cursor to preview window */
  case 'P':
    for (wp = firstwin; wp != NULL; wp = wp->w_next)
      if (wp->w_p_pvw)
        break;
    if (wp == NULL)
      EMSG(_("E441: There is no preview window"));
    else
      win_goto(wp);
    break;

  /* close all but current window */
  case Ctrl_O:
  case 'o':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    do_cmdline_cmd((char_u *)"only");
    break;

  /* cursor to next window with wrap around */
  case Ctrl_W:
  case 'w':
  /* cursor to previous window with wrap around */
  case 'W':
    CHECK_CMDWIN
    if (firstwin == lastwin && Prenum != 1)             /* just one window */
      beep_flush();
    else {
      if (Prenum) {                             /* go to specified window */
        for (wp = firstwin; --Prenum > 0; ) {
          if (wp->w_next == NULL)
            break;
          else
            wp = wp->w_next;
        }
      } else   {
        if (nchar == 'W') {                         /* go to previous window */
          wp = curwin->w_prev;
          if (wp == NULL)
            wp = lastwin;                           /* wrap around */
        } else   {                                  /* go to next window */
          wp = curwin->w_next;
          if (wp == NULL)
            wp = firstwin;                          /* wrap around */
        }
      }
      win_goto(wp);
    }
    break;

  /* cursor to window below */
  case 'j':
  case K_DOWN:
  case Ctrl_J:
    CHECK_CMDWIN win_goto_ver(FALSE, Prenum1);
    break;

  /* cursor to window above */
  case 'k':
  case K_UP:
  case Ctrl_K:
    CHECK_CMDWIN win_goto_ver(TRUE, Prenum1);
    break;

  /* cursor to left window */
  case 'h':
  case K_LEFT:
  case Ctrl_H:
  case K_BS:
    CHECK_CMDWIN win_goto_hor(TRUE, Prenum1);
    break;

  /* cursor to right window */
  case 'l':
  case K_RIGHT:
  case Ctrl_L:
    CHECK_CMDWIN win_goto_hor(FALSE, Prenum1);
    break;

  /* move window to new tab page */
  case 'T':
    if (one_window())
      MSG(_(m_onlyone));
    else {
      tabpage_T   *oldtab = curtab;
      tabpage_T   *newtab;

      /* First create a new tab with the window, then go back to
       * the old tab and close the window there. */
      wp = curwin;
      if (win_new_tabpage((int)Prenum) == OK
          && valid_tabpage(oldtab)) {
        newtab = curtab;
        goto_tabpage_tp(oldtab, TRUE, TRUE);
        if (curwin == wp)
          win_close(curwin, FALSE);
        if (valid_tabpage(newtab))
          goto_tabpage_tp(newtab, TRUE, TRUE);
      }
    }
    break;

  /* cursor to top-left window */
  case 't':
  case Ctrl_T:
    win_goto(firstwin);
    break;

  /* cursor to bottom-right window */
  case 'b':
  case Ctrl_B:
    win_goto(lastwin);
    break;

  /* cursor to last accessed (previous) window */
  case 'p':
  case Ctrl_P:
    if (prevwin == NULL)
      beep_flush();
    else
      win_goto(prevwin);
    break;

  /* exchange current and next window */
  case 'x':
  case Ctrl_X:
    CHECK_CMDWIN win_exchange(Prenum);
    break;

  /* rotate windows downwards */
  case Ctrl_R:
  case 'r':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    win_rotate(FALSE, (int)Prenum1);                /* downwards */
    break;

  /* rotate windows upwards */
  case 'R':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    win_rotate(TRUE, (int)Prenum1);                 /* upwards */
    break;

  /* move window to the very top/bottom/left/right */
  case 'K':
  case 'J':
  case 'H':
  case 'L':
    CHECK_CMDWIN win_totop((int)Prenum,
        ((nchar == 'H' || nchar == 'L') ? WSP_VERT : 0)
        | ((nchar == 'H' || nchar == 'K') ? WSP_TOP : WSP_BOT));
    break;

  /* make all windows the same height */
  case '=':
    win_equal(NULL, FALSE, 'b');
    break;

  /* increase current window height */
  case '+':
    win_setheight(curwin->w_height + (int)Prenum1);
    break;

  /* decrease current window height */
  case '-':
    win_setheight(curwin->w_height - (int)Prenum1);
    break;

  /* set current window height */
  case Ctrl__:
  case '_':
    win_setheight(Prenum ? (int)Prenum : 9999);
    break;

  /* increase current window width */
  case '>':
    win_setwidth(curwin->w_width + (int)Prenum1);
    break;

  /* decrease current window width */
  case '<':
    win_setwidth(curwin->w_width - (int)Prenum1);
    break;

  /* set current window width */
  case '|':
    win_setwidth(Prenum != 0 ? (int)Prenum : 9999);
    break;

  /* jump to tag and split window if tag exists (in preview window) */
  case '}':
    CHECK_CMDWIN
    if (Prenum)
      g_do_tagpreview = Prenum;
    else
      g_do_tagpreview = p_pvh;
  /*FALLTHROUGH*/
  case ']':
  case Ctrl_RSB:
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    if (Prenum)
      postponed_split = Prenum;
    else
      postponed_split = -1;

    /* Execute the command right here, required when
     * "wincmd ]" was used in a function. */
    do_nv_ident(Ctrl_RSB, NUL);
    break;

  /* edit file name under cursor in a new window */
  case 'f':
  case 'F':
  case Ctrl_F:
wingotofile:
    CHECK_CMDWIN

    ptr = grab_file_name(Prenum1, &lnum);
    if (ptr != NULL) {
      setpcmark();
      if (win_split(0, 0) == OK) {
        RESET_BINDING(curwin);
        (void)do_ecmd(0, ptr, NULL, NULL, ECMD_LASTL,
            ECMD_HIDE, NULL);
        if (nchar == 'F' && lnum >= 0) {
          curwin->w_cursor.lnum = lnum;
          check_cursor_lnum();
          beginline(BL_SOL | BL_FIX);
        }
      }
      vim_free(ptr);
    }
    break;

  /* Go to the first occurrence of the identifier under cursor along path in a
   * new window -- webb
   */
  case 'i':                         /* Go to any match */
  case Ctrl_I:
    type = FIND_ANY;
  /* FALLTHROUGH */
  case 'd':                         /* Go to definition, using 'define' */
  case Ctrl_D:
    CHECK_CMDWIN
    if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0)
      break;
    find_pattern_in_path(ptr, 0, len, TRUE,
        Prenum == 0 ? TRUE : FALSE, type,
        Prenum1, ACTION_SPLIT, (linenr_T)1, (linenr_T)MAXLNUM);
    curwin->w_set_curswant = TRUE;
    break;

  case K_KENTER:
  case CAR:
    /*
     * In a quickfix window a <CR> jumps to the error under the
     * cursor in a new window.
     */
    if (bt_quickfix(curbuf)) {
      sprintf((char *)cbuf, "split +%ld%s",
          (long)curwin->w_cursor.lnum,
          (curwin->w_llist_ref == NULL) ? "cc" : "ll");
      do_cmdline_cmd(cbuf);
    }
    break;


  /* CTRL-W g  extended commands */
  case 'g':
  case Ctrl_G:
    CHECK_CMDWIN
#ifdef USE_ON_FLY_SCROLL
    dont_scroll = TRUE;                         /* disallow scrolling here */
#endif
    ++ no_mapping;
    ++allow_keys;               /* no mapping for xchar, but allow key codes */
    if (xchar == NUL)
      xchar = plain_vgetc();
    LANGMAP_ADJUST(xchar, TRUE);
    --no_mapping;
    --allow_keys;
    (void)add_to_showcmd(xchar);
    switch (xchar) {
    case '}':
      xchar = Ctrl_RSB;
      if (Prenum)
        g_do_tagpreview = Prenum;
      else
        g_do_tagpreview = p_pvh;
    /*FALLTHROUGH*/
    case ']':
    case Ctrl_RSB:
      reset_VIsual_and_resel();                         /* stop Visual mode */
      if (Prenum)
        postponed_split = Prenum;
      else
        postponed_split = -1;

      /* Execute the command right here, required when
       * "wincmd g}" was used in a function. */
      do_nv_ident('g', xchar);
      break;

    case 'f':                       /* CTRL-W gf: "gf" in a new tab page */
    case 'F':                       /* CTRL-W gF: "gF" in a new tab page */
      cmdmod.tab = tabpage_index(curtab) + 1;
      nchar = xchar;
      goto wingotofile;
    default:
      beep_flush();
      break;
    }
    break;

  default:    beep_flush();
    break;
  }
}

/*
 * split the current window, implements CTRL-W s and :split
 *
 * "size" is the height or width for the new window, 0 to use half of current
 * height or width.
 *
 * "flags":
 * WSP_ROOM: require enough room for new window
 * WSP_VERT: vertical split.
 * WSP_TOP:  open window at the top-left of the shell (help window).
 * WSP_BOT:  open window at the bottom-right of the shell (quickfix window).
 * WSP_HELP: creating the help window, keep layout snapshot
 *
 * return FAIL for failure, OK otherwise
 */
int win_split(int size, int flags)
{
  /* When the ":tab" modifier was used open a new tab page instead. */
  if (may_open_tabpage() == OK)
    return OK;

  /* Add flags from ":vertical", ":topleft" and ":botright". */
  flags |= cmdmod.split;
  if ((flags & WSP_TOP) && (flags & WSP_BOT)) {
    EMSG(_("E442: Can't split topleft and botright at the same time"));
    return FAIL;
  }

  /* When creating the help window make a snapshot of the window layout.
   * Otherwise clear the snapshot, it's now invalid. */
  if (flags & WSP_HELP)
    make_snapshot(SNAP_HELP_IDX);
  else
    clear_snapshot(curtab, SNAP_HELP_IDX);

  return win_split_ins(size, flags, NULL, 0);
}

/*
 * When "new_wp" is NULL: split the current window in two.
 * When "new_wp" is not NULL: insert this window at the far
 * top/left/right/bottom.
 * return FAIL for failure, OK otherwise
 */
int win_split_ins(int size, int flags, win_T *new_wp, int dir)
{
  win_T       *wp = new_wp;
  win_T       *oldwin;
  int new_size = size;
  int i;
  int need_status = 0;
  int do_equal = FALSE;
  int needed;
  int available;
  int oldwin_height = 0;
  int layout;
  frame_T     *frp, *curfrp;
  int before;

  if (flags & WSP_TOP)
    oldwin = firstwin;
  else if (flags & WSP_BOT)
    oldwin = lastwin;
  else
    oldwin = curwin;

  /* add a status line when p_ls == 1 and splitting the first window */
  if (lastwin == firstwin && p_ls == 1 && oldwin->w_status_height == 0) {
    if (oldwin->w_height <= p_wmh && new_wp == NULL) {
      EMSG(_(e_noroom));
      return FAIL;
    }
    need_status = STATUS_HEIGHT;
  }


  if (flags & WSP_VERT) {
    layout = FR_ROW;

    /*
     * Check if we are able to split the current window and compute its
     * width.
     */
    needed = p_wmw + 1;
    if (flags & WSP_ROOM)
      needed += p_wiw - p_wmw;
    if (p_ea || (flags & (WSP_BOT | WSP_TOP))) {
      available = topframe->fr_width;
      needed += frame_minwidth(topframe, NULL);
    } else
      available = oldwin->w_width;
    if (available < needed && new_wp == NULL) {
      EMSG(_(e_noroom));
      return FAIL;
    }
    if (new_size == 0)
      new_size = oldwin->w_width / 2;
    if (new_size > oldwin->w_width - p_wmw - 1)
      new_size = oldwin->w_width - p_wmw - 1;
    if (new_size < p_wmw)
      new_size = p_wmw;

    /* if it doesn't fit in the current window, need win_equal() */
    if (oldwin->w_width - new_size - 1 < p_wmw)
      do_equal = TRUE;

    /* We don't like to take lines for the new window from a
     * 'winfixwidth' window.  Take them from a window to the left or right
     * instead, if possible. */
    if (oldwin->w_p_wfw)
      win_setwidth_win(oldwin->w_width + new_size, oldwin);

    /* Only make all windows the same width if one of them (except oldwin)
     * is wider than one of the split windows. */
    if (!do_equal && p_ea && size == 0 && *p_ead != 'v'
        && oldwin->w_frame->fr_parent != NULL) {
      frp = oldwin->w_frame->fr_parent->fr_child;
      while (frp != NULL) {
        if (frp->fr_win != oldwin && frp->fr_win != NULL
            && (frp->fr_win->w_width > new_size
                || frp->fr_win->w_width > oldwin->w_width
                - new_size - STATUS_HEIGHT)) {
          do_equal = TRUE;
          break;
        }
        frp = frp->fr_next;
      }
    }
  } else   {
    layout = FR_COL;

    /*
     * Check if we are able to split the current window and compute its
     * height.
     */
    needed = p_wmh + STATUS_HEIGHT + need_status;
    if (flags & WSP_ROOM)
      needed += p_wh - p_wmh;
    if (p_ea || (flags & (WSP_BOT | WSP_TOP))) {
      available = topframe->fr_height;
      needed += frame_minheight(topframe, NULL);
    } else   {
      available = oldwin->w_height;
      needed += p_wmh;
    }
    if (available < needed && new_wp == NULL) {
      EMSG(_(e_noroom));
      return FAIL;
    }
    oldwin_height = oldwin->w_height;
    if (need_status) {
      oldwin->w_status_height = STATUS_HEIGHT;
      oldwin_height -= STATUS_HEIGHT;
    }
    if (new_size == 0)
      new_size = oldwin_height / 2;

    if (new_size > oldwin_height - p_wmh - STATUS_HEIGHT)
      new_size = oldwin_height - p_wmh - STATUS_HEIGHT;
    if (new_size < p_wmh)
      new_size = p_wmh;

    /* if it doesn't fit in the current window, need win_equal() */
    if (oldwin_height - new_size - STATUS_HEIGHT < p_wmh)
      do_equal = TRUE;

    /* We don't like to take lines for the new window from a
     * 'winfixheight' window.  Take them from a window above or below
     * instead, if possible. */
    if (oldwin->w_p_wfh) {
      win_setheight_win(oldwin->w_height + new_size + STATUS_HEIGHT,
          oldwin);
      oldwin_height = oldwin->w_height;
      if (need_status)
        oldwin_height -= STATUS_HEIGHT;
    }

    /* Only make all windows the same height if one of them (except oldwin)
     * is higher than one of the split windows. */
    if (!do_equal && p_ea && size == 0
        && *p_ead != 'h'
        && oldwin->w_frame->fr_parent != NULL) {
      frp = oldwin->w_frame->fr_parent->fr_child;
      while (frp != NULL) {
        if (frp->fr_win != oldwin && frp->fr_win != NULL
            && (frp->fr_win->w_height > new_size
                || frp->fr_win->w_height > oldwin_height - new_size
                - STATUS_HEIGHT)) {
          do_equal = TRUE;
          break;
        }
        frp = frp->fr_next;
      }
    }
  }

  /*
   * allocate new window structure and link it in the window list
   */
  if ((flags & WSP_TOP) == 0
      && ((flags & WSP_BOT)
          || (flags & WSP_BELOW)
          || (!(flags & WSP_ABOVE)
              && (
                (flags & WSP_VERT) ? p_spr :
                p_sb)))) {
    /* new window below/right of current one */
    if (new_wp == NULL)
      wp = win_alloc(oldwin, FALSE);
    else
      win_append(oldwin, wp);
  } else   {
    if (new_wp == NULL)
      wp = win_alloc(oldwin->w_prev, FALSE);
    else
      win_append(oldwin->w_prev, wp);
  }

  if (new_wp == NULL) {
    if (wp == NULL)
      return FAIL;

    new_frame(wp);
    if (wp->w_frame == NULL) {
      win_free(wp, NULL);
      return FAIL;
    }

    /* make the contents of the new window the same as the current one */
    win_init(wp, curwin, flags);
  }

  /*
   * Reorganise the tree of frames to insert the new window.
   */
  if (flags & (WSP_TOP | WSP_BOT)) {
    if ((topframe->fr_layout == FR_COL && (flags & WSP_VERT) == 0)
        || (topframe->fr_layout == FR_ROW && (flags & WSP_VERT) != 0)) {
      curfrp = topframe->fr_child;
      if (flags & WSP_BOT)
        while (curfrp->fr_next != NULL)
          curfrp = curfrp->fr_next;
    } else
      curfrp = topframe;
    before = (flags & WSP_TOP);
  } else   {
    curfrp = oldwin->w_frame;
    if (flags & WSP_BELOW)
      before = FALSE;
    else if (flags & WSP_ABOVE)
      before = TRUE;
    else if (flags & WSP_VERT)
      before = !p_spr;
    else
      before = !p_sb;
  }
  if (curfrp->fr_parent == NULL || curfrp->fr_parent->fr_layout != layout) {
    /* Need to create a new frame in the tree to make a branch. */
    frp = (frame_T *)alloc_clear((unsigned)sizeof(frame_T));
    *frp = *curfrp;
    curfrp->fr_layout = layout;
    frp->fr_parent = curfrp;
    frp->fr_next = NULL;
    frp->fr_prev = NULL;
    curfrp->fr_child = frp;
    curfrp->fr_win = NULL;
    curfrp = frp;
    if (frp->fr_win != NULL)
      oldwin->w_frame = frp;
    else
      for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
        frp->fr_parent = curfrp;
  }

  if (new_wp == NULL)
    frp = wp->w_frame;
  else
    frp = new_wp->w_frame;
  frp->fr_parent = curfrp->fr_parent;

  /* Insert the new frame at the right place in the frame list. */
  if (before)
    frame_insert(curfrp, frp);
  else
    frame_append(curfrp, frp);

  /* Set w_fraction now so that the cursor keeps the same relative
   * vertical position. */
  if (oldwin->w_height > 0)
    set_fraction(oldwin);
  wp->w_fraction = oldwin->w_fraction;

  if (flags & WSP_VERT) {
    wp->w_p_scr = curwin->w_p_scr;

    if (need_status) {
      win_new_height(oldwin, oldwin->w_height - 1);
      oldwin->w_status_height = need_status;
    }
    if (flags & (WSP_TOP | WSP_BOT)) {
      /* set height and row of new window to full height */
      wp->w_winrow = tabline_height();
      win_new_height(wp, curfrp->fr_height - (p_ls > 0));
      wp->w_status_height = (p_ls > 0);
    } else   {
      /* height and row of new window is same as current window */
      wp->w_winrow = oldwin->w_winrow;
      win_new_height(wp, oldwin->w_height);
      wp->w_status_height = oldwin->w_status_height;
    }
    frp->fr_height = curfrp->fr_height;

    /* "new_size" of the current window goes to the new window, use
     * one column for the vertical separator */
    win_new_width(wp, new_size);
    if (before)
      wp->w_vsep_width = 1;
    else {
      wp->w_vsep_width = oldwin->w_vsep_width;
      oldwin->w_vsep_width = 1;
    }
    if (flags & (WSP_TOP | WSP_BOT)) {
      if (flags & WSP_BOT)
        frame_add_vsep(curfrp);
      /* Set width of neighbor frame */
      frame_new_width(curfrp, curfrp->fr_width
          - (new_size + ((flags & WSP_TOP) != 0)), flags & WSP_TOP,
          FALSE);
    } else
      win_new_width(oldwin, oldwin->w_width - (new_size + 1));
    if (before) {       /* new window left of current one */
      wp->w_wincol = oldwin->w_wincol;
      oldwin->w_wincol += new_size + 1;
    } else              /* new window right of current one */
      wp->w_wincol = oldwin->w_wincol + oldwin->w_width + 1;
    frame_fix_width(oldwin);
    frame_fix_width(wp);
  } else   {
    /* width and column of new window is same as current window */
    if (flags & (WSP_TOP | WSP_BOT)) {
      wp->w_wincol = 0;
      win_new_width(wp, Columns);
      wp->w_vsep_width = 0;
    } else   {
      wp->w_wincol = oldwin->w_wincol;
      win_new_width(wp, oldwin->w_width);
      wp->w_vsep_width = oldwin->w_vsep_width;
    }
    frp->fr_width = curfrp->fr_width;

    /* "new_size" of the current window goes to the new window, use
     * one row for the status line */
    win_new_height(wp, new_size);
    if (flags & (WSP_TOP | WSP_BOT))
      frame_new_height(curfrp, curfrp->fr_height
          - (new_size + STATUS_HEIGHT), flags & WSP_TOP, FALSE);
    else
      win_new_height(oldwin, oldwin_height - (new_size + STATUS_HEIGHT));
    if (before) {       /* new window above current one */
      wp->w_winrow = oldwin->w_winrow;
      wp->w_status_height = STATUS_HEIGHT;
      oldwin->w_winrow += wp->w_height + STATUS_HEIGHT;
    } else   {          /* new window below current one */
      wp->w_winrow = oldwin->w_winrow + oldwin->w_height + STATUS_HEIGHT;
      wp->w_status_height = oldwin->w_status_height;
      oldwin->w_status_height = STATUS_HEIGHT;
    }
    if (flags & WSP_BOT)
      frame_add_statusline(curfrp);
    frame_fix_height(wp);
    frame_fix_height(oldwin);
  }

  if (flags & (WSP_TOP | WSP_BOT))
    (void)win_comp_pos();

  /*
   * Both windows need redrawing
   */
  redraw_win_later(wp, NOT_VALID);
  wp->w_redr_status = TRUE;
  redraw_win_later(oldwin, NOT_VALID);
  oldwin->w_redr_status = TRUE;

  if (need_status) {
    msg_row = Rows - 1;
    msg_col = sc_col;
    msg_clr_eos_force();        /* Old command/ruler may still be there */
    comp_col();
    msg_row = Rows - 1;
    msg_col = 0;        /* put position back at start of line */
  }

  /*
   * equalize the window sizes.
   */
  if (do_equal || dir != 0)
    win_equal(wp, TRUE,
        (flags & WSP_VERT) ? (dir == 'v' ? 'b' : 'h')
        : dir == 'h' ? 'b' :
        'v');

  /* Don't change the window height/width to 'winheight' / 'winwidth' if a
   * size was given. */
  if (flags & WSP_VERT) {
    i = p_wiw;
    if (size != 0)
      p_wiw = size;

  } else   {
    i = p_wh;
    if (size != 0)
      p_wh = size;
  }

  /*
   * make the new window the current window
   */
  win_enter(wp, FALSE);
  if (flags & WSP_VERT)
    p_wiw = i;
  else
    p_wh = i;

  return OK;
}


/*
 * Initialize window "newp" from window "oldp".
 * Used when splitting a window and when creating a new tab page.
 * The windows will both edit the same buffer.
 * WSP_NEWLOC may be specified in flags to prevent the location list from
 * being copied.
 */
static void win_init(win_T *newp, win_T *oldp, int flags)
{
  int i;

  newp->w_buffer = oldp->w_buffer;
  newp->w_s = &(oldp->w_buffer->b_s);
  oldp->w_buffer->b_nwindows++;
  newp->w_cursor = oldp->w_cursor;
  newp->w_valid = 0;
  newp->w_curswant = oldp->w_curswant;
  newp->w_set_curswant = oldp->w_set_curswant;
  newp->w_topline = oldp->w_topline;
  newp->w_topfill = oldp->w_topfill;
  newp->w_leftcol = oldp->w_leftcol;
  newp->w_pcmark = oldp->w_pcmark;
  newp->w_prev_pcmark = oldp->w_prev_pcmark;
  newp->w_alt_fnum = oldp->w_alt_fnum;
  newp->w_wrow = oldp->w_wrow;
  newp->w_fraction = oldp->w_fraction;
  newp->w_prev_fraction_row = oldp->w_prev_fraction_row;
  copy_jumplist(oldp, newp);
  if (flags & WSP_NEWLOC) {
    /* Don't copy the location list.  */
    newp->w_llist = NULL;
    newp->w_llist_ref = NULL;
  } else
    copy_loclist(oldp, newp);
  newp->w_localdir = (oldp->w_localdir == NULL)
                     ? NULL : vim_strsave(oldp->w_localdir);

  /* copy tagstack and folds */
  for (i = 0; i < oldp->w_tagstacklen; i++) {
    newp->w_tagstack[i] = oldp->w_tagstack[i];
    if (newp->w_tagstack[i].tagname != NULL)
      newp->w_tagstack[i].tagname =
        vim_strsave(newp->w_tagstack[i].tagname);
  }
  newp->w_tagstackidx = oldp->w_tagstackidx;
  newp->w_tagstacklen = oldp->w_tagstacklen;
  copyFoldingState(oldp, newp);

  win_init_some(newp, oldp);

  check_colorcolumn(newp);
}

/*
 * Initialize window "newp" from window"old".
 * Only the essential things are copied.
 */
static void win_init_some(win_T *newp, win_T *oldp)
{
  /* Use the same argument list. */
  newp->w_alist = oldp->w_alist;
  ++newp->w_alist->al_refcount;
  newp->w_arg_idx = oldp->w_arg_idx;

  /* copy options from existing window */
  win_copy_options(oldp, newp);
}


/*
 * Check if "win" is a pointer to an existing window.
 */
int win_valid(win_T *win)
{
  win_T       *wp;

  if (win == NULL)
    return FALSE;
  for (wp = firstwin; wp != NULL; wp = wp->w_next)
    if (wp == win)
      return TRUE;
  return FALSE;
}

/*
 * Return the number of windows.
 */
int win_count(void)         {
  win_T       *wp;
  int count = 0;

  for (wp = firstwin; wp != NULL; wp = wp->w_next)
    ++count;
  return count;
}

/*
 * Make "count" windows on the screen.
 * Return actual number of windows on the screen.
 * Must be called when there is just one window, filling the whole screen
 * (excluding the command line).
 */
int 
make_windows (
    int count,
    int vertical              /* split windows vertically if TRUE */
)
{
  int maxcount;
  int todo;

  if (vertical) {
    /* Each windows needs at least 'winminwidth' lines and a separator
     * column. */
    maxcount = (curwin->w_width + curwin->w_vsep_width
                - (p_wiw - p_wmw)) / (p_wmw + 1);
  } else   {
    /* Each window needs at least 'winminheight' lines and a status line. */
    maxcount = (curwin->w_height + curwin->w_status_height
                - (p_wh - p_wmh)) / (p_wmh + STATUS_HEIGHT);
  }

  if (maxcount < 2)
    maxcount = 2;
  if (count > maxcount)
    count = maxcount;

  /*
   * add status line now, otherwise first window will be too big
   */
  if (count > 1)
    last_status(TRUE);

  /*
   * Don't execute autocommands while creating the windows.  Must do that
   * when putting the buffers in the windows.
   */
  block_autocmds();

  /* todo is number of windows left to create */
  for (todo = count - 1; todo > 0; --todo)
    if (vertical) {
      if (win_split(curwin->w_width - (curwin->w_width - todo)
              / (todo + 1) - 1, WSP_VERT | WSP_ABOVE) == FAIL)
        break;
    } else   {
      if (win_split(curwin->w_height - (curwin->w_height - todo
                                        * STATUS_HEIGHT) / (todo + 1)
              - STATUS_HEIGHT, WSP_ABOVE) == FAIL)
        break;
    }

  unblock_autocmds();

  /* return actual number of windows */
  return count - todo;
}

/*
 * Exchange current and next window
 */
static void win_exchange(long Prenum)
{
  frame_T     *frp;
  frame_T     *frp2;
  win_T       *wp;
  win_T       *wp2;
  int temp;

  if (lastwin == firstwin) {        /* just one window */
    beep_flush();
    return;
  }


  /*
   * find window to exchange with
   */
  if (Prenum) {
    frp = curwin->w_frame->fr_parent->fr_child;
    while (frp != NULL && --Prenum > 0)
      frp = frp->fr_next;
  } else if (curwin->w_frame->fr_next != NULL)  /* Swap with next */
    frp = curwin->w_frame->fr_next;
  else      /* Swap last window in row/col with previous */
    frp = curwin->w_frame->fr_prev;

  /* We can only exchange a window with another window, not with a frame
   * containing windows. */
  if (frp == NULL || frp->fr_win == NULL || frp->fr_win == curwin)
    return;
  wp = frp->fr_win;

  /*
   * 1. remove curwin from the list. Remember after which window it was in wp2
   * 2. insert curwin before wp in the list
   * if wp != wp2
   *    3. remove wp from the list
   *    4. insert wp after wp2
   * 5. exchange the status line height and vsep width.
   */
  wp2 = curwin->w_prev;
  frp2 = curwin->w_frame->fr_prev;
  if (wp->w_prev != curwin) {
    win_remove(curwin, NULL);
    frame_remove(curwin->w_frame);
    win_append(wp->w_prev, curwin);
    frame_insert(frp, curwin->w_frame);
  }
  if (wp != wp2) {
    win_remove(wp, NULL);
    frame_remove(wp->w_frame);
    win_append(wp2, wp);
    if (frp2 == NULL)
      frame_insert(wp->w_frame->fr_parent->fr_child, wp->w_frame);
    else
      frame_append(frp2, wp->w_frame);
  }
  temp = curwin->w_status_height;
  curwin->w_status_height = wp->w_status_height;
  wp->w_status_height = temp;
  temp = curwin->w_vsep_width;
  curwin->w_vsep_width = wp->w_vsep_width;
  wp->w_vsep_width = temp;

  /* If the windows are not in the same frame, exchange the sizes to avoid
   * messing up the window layout.  Otherwise fix the frame sizes. */
  if (curwin->w_frame->fr_parent != wp->w_frame->fr_parent) {
    temp = curwin->w_height;
    curwin->w_height = wp->w_height;
    wp->w_height = temp;
    temp = curwin->w_width;
    curwin->w_width = wp->w_width;
    wp->w_width = temp;
  } else   {
    frame_fix_height(curwin);
    frame_fix_height(wp);
    frame_fix_width(curwin);
    frame_fix_width(wp);
  }

  (void)win_comp_pos();                 /* recompute window positions */

  win_enter(wp, TRUE);
  redraw_later(CLEAR);
}

/*
 * rotate windows: if upwards TRUE the second window becomes the first one
 *		   if upwards FALSE the first window becomes the second one
 */
static void win_rotate(int upwards, int count)
{
  win_T       *wp1;
  win_T       *wp2;
  frame_T     *frp;
  int n;

  if (firstwin == lastwin) {            /* nothing to do */
    beep_flush();
    return;
  }


  /* Check if all frames in this row/col have one window. */
  for (frp = curwin->w_frame->fr_parent->fr_child; frp != NULL;
       frp = frp->fr_next)
    if (frp->fr_win == NULL) {
      EMSG(_("E443: Cannot rotate when another window is split"));
      return;
    }

  while (count--) {
    if (upwards) {              /* first window becomes last window */
      /* remove first window/frame from the list */
      frp = curwin->w_frame->fr_parent->fr_child;
      wp1 = frp->fr_win;
      win_remove(wp1, NULL);
      frame_remove(frp);

      /* find last frame and append removed window/frame after it */
      for (; frp->fr_next != NULL; frp = frp->fr_next)
        ;
      win_append(frp->fr_win, wp1);
      frame_append(frp, wp1->w_frame);

      wp2 = frp->fr_win;                /* previously last window */
    } else   {                  /* last window becomes first window */
      /* find last window/frame in the list and remove it */
      for (frp = curwin->w_frame; frp->fr_next != NULL;
           frp = frp->fr_next)
        ;
      wp1 = frp->fr_win;
      wp2 = wp1->w_prev;                    /* will become last window */
      win_remove(wp1, NULL);
      frame_remove(frp);

      /* append the removed window/frame before the first in the list */
      win_append(frp->fr_parent->fr_child->fr_win->w_prev, wp1);
      frame_insert(frp->fr_parent->fr_child, frp);
    }

    /* exchange status height and vsep width of old and new last window */
    n = wp2->w_status_height;
    wp2->w_status_height = wp1->w_status_height;
    wp1->w_status_height = n;
    frame_fix_height(wp1);
    frame_fix_height(wp2);
    n = wp2->w_vsep_width;
    wp2->w_vsep_width = wp1->w_vsep_width;
    wp1->w_vsep_width = n;
    frame_fix_width(wp1);
    frame_fix_width(wp2);

    /* recompute w_winrow and w_wincol for all windows */
    (void)win_comp_pos();
  }

  redraw_later(CLEAR);
}

/*
 * Move the current window to the very top/bottom/left/right of the screen.
 */
static void win_totop(int size, int flags)
{
  int dir;
  int height = curwin->w_height;

  if (lastwin == firstwin) {
    beep_flush();
    return;
  }

  /* Remove the window and frame from the tree of frames. */
  (void)winframe_remove(curwin, &dir, NULL);
  win_remove(curwin, NULL);
  last_status(FALSE);       /* may need to remove last status line */
  (void)win_comp_pos();     /* recompute window positions */

  /* Split a window on the desired side and put the window there. */
  (void)win_split_ins(size, flags, curwin, dir);
  if (!(flags & WSP_VERT)) {
    win_setheight(height);
    if (p_ea)
      win_equal(curwin, TRUE, 'v');
  }

}

/*
 * Move window "win1" to below/right of "win2" and make "win1" the current
 * window.  Only works within the same frame!
 */
void win_move_after(win_T *win1, win_T *win2)
{
  int height;

  /* check if the arguments are reasonable */
  if (win1 == win2)
    return;

  /* check if there is something to do */
  if (win2->w_next != win1) {
    /* may need move the status line/vertical separator of the last window
     * */
    if (win1 == lastwin) {
      height = win1->w_prev->w_status_height;
      win1->w_prev->w_status_height = win1->w_status_height;
      win1->w_status_height = height;
      if (win1->w_prev->w_vsep_width == 1) {
        /* Remove the vertical separator from the last-but-one window,
         * add it to the last window.  Adjust the frame widths. */
        win1->w_prev->w_vsep_width = 0;
        win1->w_prev->w_frame->fr_width -= 1;
        win1->w_vsep_width = 1;
        win1->w_frame->fr_width += 1;
      }
    } else if (win2 == lastwin)   {
      height = win1->w_status_height;
      win1->w_status_height = win2->w_status_height;
      win2->w_status_height = height;
      if (win1->w_vsep_width == 1) {
        /* Remove the vertical separator from win1, add it to the last
         * window, win2.  Adjust the frame widths. */
        win2->w_vsep_width = 1;
        win2->w_frame->fr_width += 1;
        win1->w_vsep_width = 0;
        win1->w_frame->fr_width -= 1;
      }
    }
    win_remove(win1, NULL);
    frame_remove(win1->w_frame);
    win_append(win2, win1);
    frame_append(win2->w_frame, win1->w_frame);

    (void)win_comp_pos();       /* recompute w_winrow for all windows */
    redraw_later(NOT_VALID);
  }
  win_enter(win1, FALSE);
}

/*
 * Make all windows the same height.
 * 'next_curwin' will soon be the current window, make sure it has enough
 * rows.
 */
void 
win_equal (
    win_T *next_curwin,       /* pointer to current window to be or NULL */
    int current,                    /* do only frame with current window */
    int dir                        /* 'v' for vertically, 'h' for horizontally,
                                   'b' for both, 0 for using p_ead */
)
{
  if (dir == 0)
    dir = *p_ead;
  win_equal_rec(next_curwin == NULL ? curwin : next_curwin, current,
      topframe, dir, 0, tabline_height(),
      (int)Columns, topframe->fr_height);
}

/*
 * Set a frame to a new position and height, spreading the available room
 * equally over contained frames.
 * The window "next_curwin" (if not NULL) should at least get the size from
 * 'winheight' and 'winwidth' if possible.
 */
static void 
win_equal_rec (
    win_T *next_curwin,       /* pointer to current window to be or NULL */
    int current,                    /* do only frame with current window */
    frame_T *topfr,             /* frame to set size off */
    int dir,                        /* 'v', 'h' or 'b', see win_equal() */
    int col,                        /* horizontal position for frame */
    int row,                        /* vertical position for frame */
    int width,                      /* new width of frame */
    int height                     /* new height of frame */
)
{
  int n, m;
  int extra_sep = 0;
  int wincount, totwincount = 0;
  frame_T     *fr;
  int next_curwin_size = 0;
  int room = 0;
  int new_size;
  int has_next_curwin = 0;
  int hnc;

  if (topfr->fr_layout == FR_LEAF) {
    /* Set the width/height of this frame.
     * Redraw when size or position changes */
    if (topfr->fr_height != height || topfr->fr_win->w_winrow != row
        || topfr->fr_width != width || topfr->fr_win->w_wincol != col
        ) {
      topfr->fr_win->w_winrow = row;
      frame_new_height(topfr, height, FALSE, FALSE);
      topfr->fr_win->w_wincol = col;
      frame_new_width(topfr, width, FALSE, FALSE);
      redraw_all_later(CLEAR);
    }
  } else if (topfr->fr_layout == FR_ROW)   {
    topfr->fr_width = width;
    topfr->fr_height = height;

    if (dir != 'v') {                   /* equalize frame widths */
      /* Compute the maximum number of windows horizontally in this
       * frame. */
      n = frame_minwidth(topfr, NOWIN);
      /* add one for the rightmost window, it doesn't have a separator */
      if (col + width == Columns)
        extra_sep = 1;
      else
        extra_sep = 0;
      totwincount = (n + extra_sep) / (p_wmw + 1);
      has_next_curwin = frame_has_win(topfr, next_curwin);

      /*
       * Compute width for "next_curwin" window and room available for
       * other windows.
       * "m" is the minimal width when counting p_wiw for "next_curwin".
       */
      m = frame_minwidth(topfr, next_curwin);
      room = width - m;
      if (room < 0) {
        next_curwin_size = p_wiw + room;
        room = 0;
      } else   {
        next_curwin_size = -1;
        for (fr = topfr->fr_child; fr != NULL; fr = fr->fr_next) {
          /* If 'winfixwidth' set keep the window width if
           * possible.
           * Watch out for this window being the next_curwin. */
          if (frame_fixed_width(fr)) {
            n = frame_minwidth(fr, NOWIN);
            new_size = fr->fr_width;
            if (frame_has_win(fr, next_curwin)) {
              room += p_wiw - p_wmw;
              next_curwin_size = 0;
              if (new_size < p_wiw)
                new_size = p_wiw;
            } else
              /* These windows don't use up room. */
              totwincount -= (n + (fr->fr_next == NULL
                                   ? extra_sep : 0)) / (p_wmw + 1);
            room -= new_size - n;
            if (room < 0) {
              new_size += room;
              room = 0;
            }
            fr->fr_newwidth = new_size;
          }
        }
        if (next_curwin_size == -1) {
          if (!has_next_curwin)
            next_curwin_size = 0;
          else if (totwincount > 1
                   && (room + (totwincount - 2))
                   / (totwincount - 1) > p_wiw) {
            /* Can make all windows wider than 'winwidth', spread
             * the room equally. */
            next_curwin_size = (room + p_wiw
                                + (totwincount - 1) * p_wmw
                                + (totwincount - 1)) / totwincount;
            room -= next_curwin_size - p_wiw;
          } else
            next_curwin_size = p_wiw;
        }
      }

      if (has_next_curwin)
        --totwincount;                  /* don't count curwin */
    }

    for (fr = topfr->fr_child; fr != NULL; fr = fr->fr_next) {
      n = m = 0;
      wincount = 1;
      if (fr->fr_next == NULL)
        /* last frame gets all that remains (avoid roundoff error) */
        new_size = width;
      else if (dir == 'v')
        new_size = fr->fr_width;
      else if (frame_fixed_width(fr)) {
        new_size = fr->fr_newwidth;
        wincount = 0;               /* doesn't count as a sizeable window */
      } else   {
        /* Compute the maximum number of windows horiz. in "fr". */
        n = frame_minwidth(fr, NOWIN);
        wincount = (n + (fr->fr_next == NULL ? extra_sep : 0))
                   / (p_wmw + 1);
        m = frame_minwidth(fr, next_curwin);
        if (has_next_curwin)
          hnc = frame_has_win(fr, next_curwin);
        else
          hnc = FALSE;
        if (hnc)                    /* don't count next_curwin */
          --wincount;
        if (totwincount == 0)
          new_size = room;
        else
          new_size = (wincount * room + ((unsigned)totwincount >> 1))
                     / totwincount;
        if (hnc) {                  /* add next_curwin size */
          next_curwin_size -= p_wiw - (m - n);
          new_size += next_curwin_size;
          room -= new_size - next_curwin_size;
        } else
          room -= new_size;
        new_size += n;
      }

      /* Skip frame that is full width when splitting or closing a
       * window, unless equalizing all frames. */
      if (!current || dir != 'v' || topfr->fr_parent != NULL
          || (new_size != fr->fr_width)
          || frame_has_win(fr, next_curwin))
        win_equal_rec(next_curwin, current, fr, dir, col, row,
            new_size, height);
      col += new_size;
      width -= new_size;
      totwincount -= wincount;
    }
  } else   { /* topfr->fr_layout == FR_COL */
    topfr->fr_width = width;
    topfr->fr_height = height;

    if (dir != 'h') {                   /* equalize frame heights */
      /* Compute maximum number of windows vertically in this frame. */
      n = frame_minheight(topfr, NOWIN);
      /* add one for the bottom window if it doesn't have a statusline */
      if (row + height == cmdline_row && p_ls == 0)
        extra_sep = 1;
      else
        extra_sep = 0;
      totwincount = (n + extra_sep) / (p_wmh + 1);
      has_next_curwin = frame_has_win(topfr, next_curwin);

      /*
       * Compute height for "next_curwin" window and room available for
       * other windows.
       * "m" is the minimal height when counting p_wh for "next_curwin".
       */
      m = frame_minheight(topfr, next_curwin);
      room = height - m;
      if (room < 0) {
        /* The room is less then 'winheight', use all space for the
         * current window. */
        next_curwin_size = p_wh + room;
        room = 0;
      } else   {
        next_curwin_size = -1;
        for (fr = topfr->fr_child; fr != NULL; fr = fr->fr_next) {
          /* If 'winfixheight' set keep the window height if
           * possible.
           * Watch out for this window being the next_curwin. */
          if (frame_fixed_height(fr)) {
            n = frame_minheight(fr, NOWIN);
            new_size = fr->fr_height;
            if (frame_has_win(fr, next_curwin)) {
              room += p_wh - p_wmh;
              next_curwin_size = 0;
              if (new_size < p_wh)
                new_size = p_wh;
            } else
              /* These windows don't use up room. */
              totwincount -= (n + (fr->fr_next == NULL
                                   ? extra_sep : 0)) / (p_wmh + 1);
            room -= new_size - n;
            if (room < 0) {
              new_size += room;
              room = 0;
            }
            fr->fr_newheight = new_size;
          }
        }
        if (next_curwin_size == -1) {
          if (!has_next_curwin)
            next_curwin_size = 0;
          else if (totwincount > 1
                   && (room + (totwincount - 2))
                   / (totwincount - 1) > p_wh) {
            /* can make all windows higher than 'winheight',
             * spread the room equally. */
            next_curwin_size = (room + p_wh
                                + (totwincount - 1) * p_wmh
                                + (totwincount - 1)) / totwincount;
            room -= next_curwin_size - p_wh;
          } else
            next_curwin_size = p_wh;
        }
      }

      if (has_next_curwin)
        --totwincount;                  /* don't count curwin */
    }

    for (fr = topfr->fr_child; fr != NULL; fr = fr->fr_next) {
      n = m = 0;
      wincount = 1;
      if (fr->fr_next == NULL)
        /* last frame gets all that remains (avoid roundoff error) */
        new_size = height;
      else if (dir == 'h')
        new_size = fr->fr_height;
      else if (frame_fixed_height(fr)) {
        new_size = fr->fr_newheight;
        wincount = 0;               /* doesn't count as a sizeable window */
      } else   {
        /* Compute the maximum number of windows vert. in "fr". */
        n = frame_minheight(fr, NOWIN);
        wincount = (n + (fr->fr_next == NULL ? extra_sep : 0))
                   / (p_wmh + 1);
        m = frame_minheight(fr, next_curwin);
        if (has_next_curwin)
          hnc = frame_has_win(fr, next_curwin);
        else
          hnc = FALSE;
        if (hnc)                    /* don't count next_curwin */
          --wincount;
        if (totwincount == 0)
          new_size = room;
        else
          new_size = (wincount * room + ((unsigned)totwincount >> 1))
                     / totwincount;
        if (hnc) {                  /* add next_curwin size */
          next_curwin_size -= p_wh - (m - n);
          new_size += next_curwin_size;
          room -= new_size - next_curwin_size;
        } else
          room -= new_size;
        new_size += n;
      }
      /* Skip frame that is full width when splitting or closing a
       * window, unless equalizing all frames. */
      if (!current || dir != 'h' || topfr->fr_parent != NULL
          || (new_size != fr->fr_height)
          || frame_has_win(fr, next_curwin))
        win_equal_rec(next_curwin, current, fr, dir, col, row,
            width, new_size);
      row += new_size;
      height -= new_size;
      totwincount -= wincount;
    }
  }
}

/*
 * close all windows for buffer 'buf'
 */
void 
close_windows (
    buf_T *buf,
    int keep_curwin                    /* don't close "curwin" */
)
{
  win_T       *wp;
  tabpage_T   *tp, *nexttp;
  int h = tabline_height();

  ++RedrawingDisabled;

  for (wp = firstwin; wp != NULL && lastwin != firstwin; ) {
    if (wp->w_buffer == buf && (!keep_curwin || wp != curwin)
        && !(wp->w_closing || wp->w_buffer->b_closing)
        ) {
      win_close(wp, FALSE);

      /* Start all over, autocommands may change the window layout. */
      wp = firstwin;
    } else
      wp = wp->w_next;
  }

  /* Also check windows in other tab pages. */
  for (tp = first_tabpage; tp != NULL; tp = nexttp) {
    nexttp = tp->tp_next;
    if (tp != curtab)
      for (wp = tp->tp_firstwin; wp != NULL; wp = wp->w_next)
        if (wp->w_buffer == buf
            && !(wp->w_closing || wp->w_buffer->b_closing)
            ) {
          win_close_othertab(wp, FALSE, tp);

          /* Start all over, the tab page may be closed and
           * autocommands may change the window layout. */
          nexttp = first_tabpage;
          break;
        }
  }

  --RedrawingDisabled;

  redraw_tabline = TRUE;
  if (h != tabline_height())
    shell_new_rows();
}

/*
 * Return TRUE if the current window is the only window that exists (ignoring
 * "aucmd_win").
 * Returns FALSE if there is a window, possibly in another tab page.
 */
static int last_window(void)                {
  return one_window() && first_tabpage->tp_next == NULL;
}

/*
 * Return TRUE if there is only one window other than "aucmd_win" in the
 * current tab page.
 */
int one_window(void)         {
  win_T       *wp;
  int seen_one = FALSE;

  FOR_ALL_WINDOWS(wp)
  {
    if (wp != aucmd_win) {
      if (seen_one)
        return FALSE;
      seen_one = TRUE;
    }
  }
  return TRUE;
}

/*
 * Close the possibly last window in a tab page.
 * Returns TRUE when the window was closed already.
 */
static int close_last_window_tabpage(win_T *win, int free_buf, tabpage_T *prev_curtab)
{
  if (firstwin == lastwin) {
    buf_T   *old_curbuf = curbuf;

    /*
     * Closing the last window in a tab page.  First go to another tab
     * page and then close the window and the tab page.  This avoids that
     * curwin and curtab are invalid while we are freeing memory, they may
     * be used in GUI events.
     * Don't trigger autocommands yet, they may use wrong values, so do
     * that below.
     */
    goto_tabpage_tp(alt_tabpage(), FALSE, TRUE);
    redraw_tabline = TRUE;

    /* Safety check: Autocommands may have closed the window when jumping
     * to the other tab page. */
    if (valid_tabpage(prev_curtab) && prev_curtab->tp_firstwin == win) {
      int h = tabline_height();

      win_close_othertab(win, free_buf, prev_curtab);
      if (h != tabline_height())
        shell_new_rows();
    }
    /* Since goto_tabpage_tp above did not trigger *Enter autocommands, do
     * that now. */
    apply_autocmds(EVENT_WINENTER, NULL, NULL, FALSE, curbuf);
    apply_autocmds(EVENT_TABENTER, NULL, NULL, FALSE, curbuf);
    if (old_curbuf != curbuf)
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, FALSE, curbuf);
    return TRUE;
  }
  return FALSE;
}

/*
 * Close window "win".  Only works for the current tab page.
 * If "free_buf" is TRUE related buffer may be unloaded.
 *
 * Called by :quit, :close, :xit, :wq and findtag().
 * Returns FAIL when the window was not closed.
 */
int win_close(win_T *win, int free_buf)
{
  win_T       *wp;
  int other_buffer = FALSE;
  int close_curwin = FALSE;
  int dir;
  int help_window = FALSE;
  tabpage_T   *prev_curtab = curtab;

  if (last_window()) {
    EMSG(_("E444: Cannot close last window"));
    return FAIL;
  }

  if (win->w_closing || (win->w_buffer != NULL && win->w_buffer->b_closing))
    return FAIL;     /* window is already being closed */
  if (win == aucmd_win) {
    EMSG(_("E813: Cannot close autocmd window"));
    return FAIL;
  }
  if ((firstwin == aucmd_win || lastwin == aucmd_win) && one_window()) {
    EMSG(_("E814: Cannot close window, only autocmd window would remain"));
    return FAIL;
  }

  /* When closing the last window in a tab page first go to another tab page
   * and then close the window and the tab page to avoid that curwin and
   * curtab are invalid while we are freeing memory. */
  if (close_last_window_tabpage(win, free_buf, prev_curtab))
    return FAIL;

  /* When closing the help window, try restoring a snapshot after closing
   * the window.  Otherwise clear the snapshot, it's now invalid. */
  if (win->w_buffer != NULL && win->w_buffer->b_help)
    help_window = TRUE;
  else
    clear_snapshot(curtab, SNAP_HELP_IDX);

  if (win == curwin) {
    /*
     * Guess which window is going to be the new current window.
     * This may change because of the autocommands (sigh).
     */
    wp = frame2win(win_altframe(win, NULL));

    /*
     * Be careful: If autocommands delete the window or cause this window
     * to be the last one left, return now.
     */
    if (wp->w_buffer != curbuf) {
      other_buffer = TRUE;
      win->w_closing = TRUE;
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, FALSE, curbuf);
      if (!win_valid(win))
        return FAIL;
      win->w_closing = FALSE;
      if (last_window())
        return FAIL;
    }
    win->w_closing = TRUE;
    apply_autocmds(EVENT_WINLEAVE, NULL, NULL, FALSE, curbuf);
    if (!win_valid(win))
      return FAIL;
    win->w_closing = FALSE;
    if (last_window())
      return FAIL;
    /* autocmds may abort script processing */
    if (aborting())
      return FAIL;
  }


  /* Free independent synblock before the buffer is freed. */
  if (win->w_buffer != NULL)
    reset_synblock(win);

  /*
   * Close the link to the buffer.
   */
  if (win->w_buffer != NULL) {
    win->w_closing = TRUE;
    close_buffer(win, win->w_buffer, free_buf ? DOBUF_UNLOAD : 0, TRUE);
    if (win_valid(win))
      win->w_closing = FALSE;
  }

  if (only_one_window() && win_valid(win) && win->w_buffer == NULL
      && (last_window() || curtab != prev_curtab
          || close_last_window_tabpage(win, free_buf, prev_curtab))) {
    /* Autocommands have close all windows, quit now.  Restore
    * curwin->w_buffer, otherwise writing viminfo may fail. */
    if (curwin->w_buffer == NULL)
      curwin->w_buffer = curbuf;
    getout(0);
  }
  /* Autocommands may have closed the window already, or closed the only
   * other window or moved to another tab page. */
  else if (!win_valid(win) || last_window() || curtab != prev_curtab
           || close_last_window_tabpage(win, free_buf, prev_curtab))
    return FAIL;

  /* Free the memory used for the window and get the window that received
   * the screen space. */
  wp = win_free_mem(win, &dir, NULL);

  /* Make sure curwin isn't invalid.  It can cause severe trouble when
   * printing an error message.  For win_equal() curbuf needs to be valid
   * too. */
  if (win == curwin) {
    curwin = wp;
    if (wp->w_p_pvw || bt_quickfix(wp->w_buffer)) {
      /*
       * If the cursor goes to the preview or the quickfix window, try
       * finding another window to go to.
       */
      for (;; ) {
        if (wp->w_next == NULL)
          wp = firstwin;
        else
          wp = wp->w_next;
        if (wp == curwin)
          break;
        if (!wp->w_p_pvw && !bt_quickfix(wp->w_buffer)) {
          curwin = wp;
          break;
        }
      }
    }
    curbuf = curwin->w_buffer;
    close_curwin = TRUE;
  }
  if (p_ea
      && (*p_ead == 'b' || *p_ead == dir)
      )
    win_equal(curwin, TRUE,
        dir
        );
  else
    win_comp_pos();
  if (close_curwin) {
    win_enter_ext(wp, FALSE, TRUE, TRUE, TRUE);
    if (other_buffer)
      /* careful: after this wp and win may be invalid! */
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, FALSE, curbuf);
  }

  /*
   * If last window has a status line now and we don't want one,
   * remove the status line.
   */
  last_status(FALSE);

  /* After closing the help window, try restoring the window layout from
   * before it was opened. */
  if (help_window)
    restore_snapshot(SNAP_HELP_IDX, close_curwin);


  redraw_all_later(NOT_VALID);
  return OK;
}

/*
 * Close window "win" in tab page "tp", which is not the current tab page.
 * This may be the last window in that tab page and result in closing the tab,
 * thus "tp" may become invalid!
 * Caller must check if buffer is hidden and whether the tabline needs to be
 * updated.
 */
void win_close_othertab(win_T *win, int free_buf, tabpage_T *tp)
{
  win_T       *wp;
  int dir;
  tabpage_T   *ptp = NULL;
  int free_tp = FALSE;

  if (win->w_closing || win->w_buffer->b_closing)
    return;     /* window is already being closed */

  /* Close the link to the buffer. */
  close_buffer(win, win->w_buffer, free_buf ? DOBUF_UNLOAD : 0, FALSE);

  /* Careful: Autocommands may have closed the tab page or made it the
   * current tab page.  */
  for (ptp = first_tabpage; ptp != NULL && ptp != tp; ptp = ptp->tp_next)
    ;
  if (ptp == NULL || tp == curtab)
    return;

  /* Autocommands may have closed the window already. */
  for (wp = tp->tp_firstwin; wp != NULL && wp != win; wp = wp->w_next)
    ;
  if (wp == NULL)
    return;

  /* When closing the last window in a tab page remove the tab page. */
  if (tp == NULL ? firstwin == lastwin : tp->tp_firstwin == tp->tp_lastwin) {
    if (tp == first_tabpage)
      first_tabpage = tp->tp_next;
    else {
      for (ptp = first_tabpage; ptp != NULL && ptp->tp_next != tp;
           ptp = ptp->tp_next)
        ;
      if (ptp == NULL) {
        EMSG2(_(e_intern2), "win_close_othertab()");
        return;
      }
      ptp->tp_next = tp->tp_next;
    }
    free_tp = TRUE;
  }

  /* Free the memory used for the window. */
  win_free_mem(win, &dir, tp);

  if (free_tp)
    free_tabpage(tp);
}

/*
 * Free the memory used for a window.
 * Returns a pointer to the window that got the freed up space.
 */
static win_T *
win_free_mem (
    win_T *win,
    int *dirp,              /* set to 'v' or 'h' for direction if 'ea' */
    tabpage_T *tp                /* tab page "win" is in, NULL for current */
)
{
  frame_T     *frp;
  win_T       *wp;

  /* Remove the window and its frame from the tree of frames. */
  frp = win->w_frame;
  wp = winframe_remove(win, dirp, tp);
  vim_free(frp);
  win_free(win, tp);

  /* When deleting the current window of another tab page select a new
   * current window. */
  if (tp != NULL && win == tp->tp_curwin)
    tp->tp_curwin = wp;

  return wp;
}

#if defined(EXITFREE) || defined(PROTO)
void win_free_all(void)          {
  int dummy;

  while (first_tabpage->tp_next != NULL)
    tabpage_close(TRUE);

  if (aucmd_win != NULL) {
    (void)win_free_mem(aucmd_win, &dummy, NULL);
    aucmd_win = NULL;
  }

  while (firstwin != NULL)
    (void)win_free_mem(firstwin, &dummy, NULL);
}

#endif

/*
 * Remove a window and its frame from the tree of frames.
 * Returns a pointer to the window that got the freed up space.
 */
win_T *
winframe_remove (
    win_T *win,
    int *dirp,       /* set to 'v' or 'h' for direction if 'ea' */
    tabpage_T *tp                /* tab page "win" is in, NULL for current */
)
{
  frame_T     *frp, *frp2, *frp3;
  frame_T     *frp_close = win->w_frame;
  win_T       *wp;

  /*
   * If there is only one window there is nothing to remove.
   */
  if (tp == NULL ? firstwin == lastwin : tp->tp_firstwin == tp->tp_lastwin)
    return NULL;

  /*
   * Remove the window from its frame.
   */
  frp2 = win_altframe(win, tp);
  wp = frame2win(frp2);

  /* Remove this frame from the list of frames. */
  frame_remove(frp_close);

  if (frp_close->fr_parent->fr_layout == FR_COL) {
    /* When 'winfixheight' is set, try to find another frame in the column
     * (as close to the closed frame as possible) to distribute the height
     * to. */
    if (frp2->fr_win != NULL && frp2->fr_win->w_p_wfh) {
      frp = frp_close->fr_prev;
      frp3 = frp_close->fr_next;
      while (frp != NULL || frp3 != NULL) {
        if (frp != NULL) {
          if (frp->fr_win != NULL && !frp->fr_win->w_p_wfh) {
            frp2 = frp;
            wp = frp->fr_win;
            break;
          }
          frp = frp->fr_prev;
        }
        if (frp3 != NULL) {
          if (frp3->fr_win != NULL && !frp3->fr_win->w_p_wfh) {
            frp2 = frp3;
            wp = frp3->fr_win;
            break;
          }
          frp3 = frp3->fr_next;
        }
      }
    }
    frame_new_height(frp2, frp2->fr_height + frp_close->fr_height,
        frp2 == frp_close->fr_next ? TRUE : FALSE, FALSE);
    *dirp = 'v';
  } else   {
    /* When 'winfixwidth' is set, try to find another frame in the column
     * (as close to the closed frame as possible) to distribute the width
     * to. */
    if (frp2->fr_win != NULL && frp2->fr_win->w_p_wfw) {
      frp = frp_close->fr_prev;
      frp3 = frp_close->fr_next;
      while (frp != NULL || frp3 != NULL) {
        if (frp != NULL) {
          if (frp->fr_win != NULL && !frp->fr_win->w_p_wfw) {
            frp2 = frp;
            wp = frp->fr_win;
            break;
          }
          frp = frp->fr_prev;
        }
        if (frp3 != NULL) {
          if (frp3->fr_win != NULL && !frp3->fr_win->w_p_wfw) {
            frp2 = frp3;
            wp = frp3->fr_win;
            break;
          }
          frp3 = frp3->fr_next;
        }
      }
    }
    frame_new_width(frp2, frp2->fr_width + frp_close->fr_width,
        frp2 == frp_close->fr_next ? TRUE : FALSE, FALSE);
    *dirp = 'h';
  }

  /* If rows/columns go to a window below/right its positions need to be
   * updated.  Can only be done after the sizes have been updated. */
  if (frp2 == frp_close->fr_next) {
    int row = win->w_winrow;
    int col = W_WINCOL(win);

    frame_comp_pos(frp2, &row, &col);
  }

  if (frp2->fr_next == NULL && frp2->fr_prev == NULL) {
    /* There is no other frame in this list, move its info to the parent
     * and remove it. */
    frp2->fr_parent->fr_layout = frp2->fr_layout;
    frp2->fr_parent->fr_child = frp2->fr_child;
    for (frp = frp2->fr_child; frp != NULL; frp = frp->fr_next)
      frp->fr_parent = frp2->fr_parent;
    frp2->fr_parent->fr_win = frp2->fr_win;
    if (frp2->fr_win != NULL)
      frp2->fr_win->w_frame = frp2->fr_parent;
    frp = frp2->fr_parent;
    vim_free(frp2);

    frp2 = frp->fr_parent;
    if (frp2 != NULL && frp2->fr_layout == frp->fr_layout) {
      /* The frame above the parent has the same layout, have to merge
       * the frames into this list. */
      if (frp2->fr_child == frp)
        frp2->fr_child = frp->fr_child;
      frp->fr_child->fr_prev = frp->fr_prev;
      if (frp->fr_prev != NULL)
        frp->fr_prev->fr_next = frp->fr_child;
      for (frp3 = frp->fr_child;; frp3 = frp3->fr_next) {
        frp3->fr_parent = frp2;
        if (frp3->fr_next == NULL) {
          frp3->fr_next = frp->fr_next;
          if (frp->fr_next != NULL)
            frp->fr_next->fr_prev = frp3;
          break;
        }
      }
      vim_free(frp);
    }
  }

  return wp;
}

/*
 * Find out which frame is going to get the freed up space when "win" is
 * closed.
 * if 'splitbelow'/'splitleft' the space goes to the window above/left.
 * if 'nosplitbelow'/'nosplitleft' the space goes to the window below/right.
 * This makes opening a window and closing it immediately keep the same window
 * layout.
 */
static frame_T *
win_altframe (
    win_T *win,
    tabpage_T *tp                /* tab page "win" is in, NULL for current */
)
{
  frame_T     *frp;
  int b;

  if (tp == NULL ? firstwin == lastwin : tp->tp_firstwin == tp->tp_lastwin)
    /* Last window in this tab page, will go to next tab page. */
    return alt_tabpage()->tp_curwin->w_frame;

  frp = win->w_frame;
  if (frp->fr_parent != NULL && frp->fr_parent->fr_layout == FR_ROW)
    b = p_spr;
  else
    b = p_sb;
  if ((!b && frp->fr_next != NULL) || frp->fr_prev == NULL)
    return frp->fr_next;
  return frp->fr_prev;
}

/*
 * Return the tabpage that will be used if the current one is closed.
 */
static tabpage_T *alt_tabpage(void)                        {
  tabpage_T   *tp;

  /* Use the next tab page if possible. */
  if (curtab->tp_next != NULL)
    return curtab->tp_next;

  /* Find the last but one tab page. */
  for (tp = first_tabpage; tp->tp_next != curtab; tp = tp->tp_next)
    ;
  return tp;
}

/*
 * Find the left-upper window in frame "frp".
 */
static win_T *frame2win(frame_T *frp)
{
  while (frp->fr_win == NULL)
    frp = frp->fr_child;
  return frp->fr_win;
}

/*
 * Return TRUE if frame "frp" contains window "wp".
 */
static int frame_has_win(frame_T *frp, win_T *wp)
{
  frame_T     *p;

  if (frp->fr_layout == FR_LEAF)
    return frp->fr_win == wp;

  for (p = frp->fr_child; p != NULL; p = p->fr_next)
    if (frame_has_win(p, wp))
      return TRUE;
  return FALSE;
}

/*
 * Set a new height for a frame.  Recursively sets the height for contained
 * frames and windows.  Caller must take care of positions.
 */
static void 
frame_new_height (
    frame_T *topfrp,
    int height,
    int topfirst,                   /* resize topmost contained frame first */
    int wfh                        /* obey 'winfixheight' when there is a choice;
                                   may cause the height not to be set */
)
{
  frame_T     *frp;
  int extra_lines;
  int h;

  if (topfrp->fr_win != NULL) {
    /* Simple case: just one window. */
    win_new_height(topfrp->fr_win,
        height - topfrp->fr_win->w_status_height);
  } else if (topfrp->fr_layout == FR_ROW)   {
    do {
      /* All frames in this row get the same new height. */
      for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
        frame_new_height(frp, height, topfirst, wfh);
        if (frp->fr_height > height) {
          /* Could not fit the windows, make the whole row higher. */
          height = frp->fr_height;
          break;
        }
      }
    } while (frp != NULL);
  } else   { /* fr_layout == FR_COL */
    /* Complicated case: Resize a column of frames.  Resize the bottom
     * frame first, frames above that when needed. */

    frp = topfrp->fr_child;
    if (wfh)
      /* Advance past frames with one window with 'wfh' set. */
      while (frame_fixed_height(frp)) {
        frp = frp->fr_next;
        if (frp == NULL)
          return;                   /* no frame without 'wfh', give up */
      }
    if (!topfirst) {
      /* Find the bottom frame of this column */
      while (frp->fr_next != NULL)
        frp = frp->fr_next;
      if (wfh)
        /* Advance back for frames with one window with 'wfh' set. */
        while (frame_fixed_height(frp))
          frp = frp->fr_prev;
    }

    extra_lines = height - topfrp->fr_height;
    if (extra_lines < 0) {
      /* reduce height of contained frames, bottom or top frame first */
      while (frp != NULL) {
        h = frame_minheight(frp, NULL);
        if (frp->fr_height + extra_lines < h) {
          extra_lines += frp->fr_height - h;
          frame_new_height(frp, h, topfirst, wfh);
        } else   {
          frame_new_height(frp, frp->fr_height + extra_lines,
              topfirst, wfh);
          break;
        }
        if (topfirst) {
          do
            frp = frp->fr_next;
          while (wfh && frp != NULL && frame_fixed_height(frp));
        } else   {
          do
            frp = frp->fr_prev;
          while (wfh && frp != NULL && frame_fixed_height(frp));
        }
        /* Increase "height" if we could not reduce enough frames. */
        if (frp == NULL)
          height -= extra_lines;
      }
    } else if (extra_lines > 0)   {
      /* increase height of bottom or top frame */
      frame_new_height(frp, frp->fr_height + extra_lines, topfirst, wfh);
    }
  }
  topfrp->fr_height = height;
}

/*
 * Return TRUE if height of frame "frp" should not be changed because of
 * the 'winfixheight' option.
 */
static int frame_fixed_height(frame_T *frp)
{
  /* frame with one window: fixed height if 'winfixheight' set. */
  if (frp->fr_win != NULL)
    return frp->fr_win->w_p_wfh;

  if (frp->fr_layout == FR_ROW) {
    /* The frame is fixed height if one of the frames in the row is fixed
     * height. */
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
      if (frame_fixed_height(frp))
        return TRUE;
    return FALSE;
  }

  /* frp->fr_layout == FR_COL: The frame is fixed height if all of the
   * frames in the row are fixed height. */
  for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
    if (!frame_fixed_height(frp))
      return FALSE;
  return TRUE;
}

/*
 * Return TRUE if width of frame "frp" should not be changed because of
 * the 'winfixwidth' option.
 */
static int frame_fixed_width(frame_T *frp)
{
  /* frame with one window: fixed width if 'winfixwidth' set. */
  if (frp->fr_win != NULL)
    return frp->fr_win->w_p_wfw;

  if (frp->fr_layout == FR_COL) {
    /* The frame is fixed width if one of the frames in the row is fixed
     * width. */
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
      if (frame_fixed_width(frp))
        return TRUE;
    return FALSE;
  }

  /* frp->fr_layout == FR_ROW: The frame is fixed width if all of the
   * frames in the row are fixed width. */
  for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
    if (!frame_fixed_width(frp))
      return FALSE;
  return TRUE;
}

/*
 * Add a status line to windows at the bottom of "frp".
 * Note: Does not check if there is room!
 */
static void frame_add_statusline(frame_T *frp)
{
  win_T       *wp;

  if (frp->fr_layout == FR_LEAF) {
    wp = frp->fr_win;
    if (wp->w_status_height == 0) {
      if (wp->w_height > 0)             /* don't make it negative */
        --wp->w_height;
      wp->w_status_height = STATUS_HEIGHT;
    }
  } else if (frp->fr_layout == FR_ROW)   {
    /* Handle all the frames in the row. */
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
      frame_add_statusline(frp);
  } else   { /* frp->fr_layout == FR_COL */
          /* Only need to handle the last frame in the column. */
    for (frp = frp->fr_child; frp->fr_next != NULL; frp = frp->fr_next)
      ;
    frame_add_statusline(frp);
  }
}

/*
 * Set width of a frame.  Handles recursively going through contained frames.
 * May remove separator line for windows at the right side (for win_close()).
 */
static void 
frame_new_width (
    frame_T *topfrp,
    int width,
    int leftfirst,                  /* resize leftmost contained frame first */
    int wfw                        /* obey 'winfixwidth' when there is a choice;
                                   may cause the width not to be set */
)
{
  frame_T     *frp;
  int extra_cols;
  int w;
  win_T       *wp;

  if (topfrp->fr_layout == FR_LEAF) {
    /* Simple case: just one window. */
    wp = topfrp->fr_win;
    /* Find out if there are any windows right of this one. */
    for (frp = topfrp; frp->fr_parent != NULL; frp = frp->fr_parent)
      if (frp->fr_parent->fr_layout == FR_ROW && frp->fr_next != NULL)
        break;
    if (frp->fr_parent == NULL)
      wp->w_vsep_width = 0;
    win_new_width(wp, width - wp->w_vsep_width);
  } else if (topfrp->fr_layout == FR_COL)   {
    do {
      /* All frames in this column get the same new width. */
      for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
        frame_new_width(frp, width, leftfirst, wfw);
        if (frp->fr_width > width) {
          /* Could not fit the windows, make whole column wider. */
          width = frp->fr_width;
          break;
        }
      }
    } while (frp != NULL);
  } else   { /* fr_layout == FR_ROW */
    /* Complicated case: Resize a row of frames.  Resize the rightmost
     * frame first, frames left of it when needed. */

    frp = topfrp->fr_child;
    if (wfw)
      /* Advance past frames with one window with 'wfw' set. */
      while (frame_fixed_width(frp)) {
        frp = frp->fr_next;
        if (frp == NULL)
          return;                   /* no frame without 'wfw', give up */
      }
    if (!leftfirst) {
      /* Find the rightmost frame of this row */
      while (frp->fr_next != NULL)
        frp = frp->fr_next;
      if (wfw)
        /* Advance back for frames with one window with 'wfw' set. */
        while (frame_fixed_width(frp))
          frp = frp->fr_prev;
    }

    extra_cols = width - topfrp->fr_width;
    if (extra_cols < 0) {
      /* reduce frame width, rightmost frame first */
      while (frp != NULL) {
        w = frame_minwidth(frp, NULL);
        if (frp->fr_width + extra_cols < w) {
          extra_cols += frp->fr_width - w;
          frame_new_width(frp, w, leftfirst, wfw);
        } else   {
          frame_new_width(frp, frp->fr_width + extra_cols,
              leftfirst, wfw);
          break;
        }
        if (leftfirst) {
          do
            frp = frp->fr_next;
          while (wfw && frp != NULL && frame_fixed_width(frp));
        } else   {
          do
            frp = frp->fr_prev;
          while (wfw && frp != NULL && frame_fixed_width(frp));
        }
        /* Increase "width" if we could not reduce enough frames. */
        if (frp == NULL)
          width -= extra_cols;
      }
    } else if (extra_cols > 0)   {
      /* increase width of rightmost frame */
      frame_new_width(frp, frp->fr_width + extra_cols, leftfirst, wfw);
    }
  }
  topfrp->fr_width = width;
}

/*
 * Add the vertical separator to windows at the right side of "frp".
 * Note: Does not check if there is room!
 */
static void frame_add_vsep(frame_T *frp)
{
  win_T       *wp;

  if (frp->fr_layout == FR_LEAF) {
    wp = frp->fr_win;
    if (wp->w_vsep_width == 0) {
      if (wp->w_width > 0)              /* don't make it negative */
        --wp->w_width;
      wp->w_vsep_width = 1;
    }
  } else if (frp->fr_layout == FR_COL)   {
    /* Handle all the frames in the column. */
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
      frame_add_vsep(frp);
  } else   { /* frp->fr_layout == FR_ROW */
          /* Only need to handle the last frame in the row. */
    frp = frp->fr_child;
    while (frp->fr_next != NULL)
      frp = frp->fr_next;
    frame_add_vsep(frp);
  }
}

/*
 * Set frame width from the window it contains.
 */
static void frame_fix_width(win_T *wp)
{
  wp->w_frame->fr_width = wp->w_width + wp->w_vsep_width;
}

/*
 * Set frame height from the window it contains.
 */
static void frame_fix_height(win_T *wp)
{
  wp->w_frame->fr_height = wp->w_height + wp->w_status_height;
}

/*
 * Compute the minimal height for frame "topfrp".
 * Uses the 'winminheight' option.
 * When "next_curwin" isn't NULL, use p_wh for this window.
 * When "next_curwin" is NOWIN, don't use at least one line for the current
 * window.
 */
static int frame_minheight(frame_T *topfrp, win_T *next_curwin)
{
  frame_T     *frp;
  int m;
  int n;

  if (topfrp->fr_win != NULL) {
    if (topfrp->fr_win == next_curwin)
      m = p_wh + topfrp->fr_win->w_status_height;
    else {
      /* window: minimal height of the window plus status line */
      m = p_wmh + topfrp->fr_win->w_status_height;
      /* Current window is minimal one line high */
      if (p_wmh == 0 && topfrp->fr_win == curwin && next_curwin == NULL)
        ++m;
    }
  } else if (topfrp->fr_layout == FR_ROW)   {
    /* get the minimal height from each frame in this row */
    m = 0;
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
      n = frame_minheight(frp, next_curwin);
      if (n > m)
        m = n;
    }
  } else   {
    /* Add up the minimal heights for all frames in this column. */
    m = 0;
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next)
      m += frame_minheight(frp, next_curwin);
  }

  return m;
}

/*
 * Compute the minimal width for frame "topfrp".
 * When "next_curwin" isn't NULL, use p_wiw for this window.
 * When "next_curwin" is NOWIN, don't use at least one column for the current
 * window.
 */
static int 
frame_minwidth (
    frame_T *topfrp,
    win_T *next_curwin       /* use p_wh and p_wiw for next_curwin */
)
{
  frame_T     *frp;
  int m, n;

  if (topfrp->fr_win != NULL) {
    if (topfrp->fr_win == next_curwin)
      m = p_wiw + topfrp->fr_win->w_vsep_width;
    else {
      /* window: minimal width of the window plus separator column */
      m = p_wmw + topfrp->fr_win->w_vsep_width;
      /* Current window is minimal one column wide */
      if (p_wmw == 0 && topfrp->fr_win == curwin && next_curwin == NULL)
        ++m;
    }
  } else if (topfrp->fr_layout == FR_COL)   {
    /* get the minimal width from each frame in this column */
    m = 0;
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
      n = frame_minwidth(frp, next_curwin);
      if (n > m)
        m = n;
    }
  } else   {
    /* Add up the minimal widths for all frames in this row. */
    m = 0;
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next)
      m += frame_minwidth(frp, next_curwin);
  }

  return m;
}


/*
 * Try to close all windows except current one.
 * Buffers in the other windows become hidden if 'hidden' is set, or '!' is
 * used and the buffer was modified.
 *
 * Used by ":bdel" and ":only".
 */
void 
close_others (
    int message,
    int forceit                        /* always hide all other windows */
)
{
  win_T       *wp;
  win_T       *nextwp;
  int r;

  if (one_window()) {
    if (message
        && !autocmd_busy
        )
      MSG(_(m_onlyone));
    return;
  }

  /* Be very careful here: autocommands may change the window layout. */
  for (wp = firstwin; win_valid(wp); wp = nextwp) {
    nextwp = wp->w_next;
    if (wp != curwin) {                 /* don't close current window */

      /* Check if it's allowed to abandon this window */
      r = can_abandon(wp->w_buffer, forceit);
      if (!win_valid(wp)) {             /* autocommands messed wp up */
        nextwp = firstwin;
        continue;
      }
      if (!r) {
        if (message && (p_confirm || cmdmod.confirm) && p_write) {
          dialog_changed(wp->w_buffer, FALSE);
          if (!win_valid(wp)) {                 /* autocommands messed wp up */
            nextwp = firstwin;
            continue;
          }
        }
        if (bufIsChanged(wp->w_buffer))
          continue;
      }
      win_close(wp, !P_HID(wp->w_buffer) && !bufIsChanged(wp->w_buffer));
    }
  }

  if (message && lastwin != firstwin)
    EMSG(_("E445: Other window contains changes"));
}


/*
 * Init the current window "curwin".
 * Called when a new file is being edited.
 */
void curwin_init(void)          {
  win_init_empty(curwin);
}

void win_init_empty(win_T *wp)
{
  redraw_win_later(wp, NOT_VALID);
  wp->w_lines_valid = 0;
  wp->w_cursor.lnum = 1;
  wp->w_curswant = wp->w_cursor.col = 0;
  wp->w_cursor.coladd = 0;
  wp->w_pcmark.lnum = 1;        /* pcmark not cleared but set to line 1 */
  wp->w_pcmark.col = 0;
  wp->w_prev_pcmark.lnum = 0;
  wp->w_prev_pcmark.col = 0;
  wp->w_topline = 1;
  wp->w_topfill = 0;
  wp->w_botline = 2;
  if (wp->w_p_rl)
    wp->w_farsi = W_CONV + W_R_L;
  else
    wp->w_farsi = W_CONV;
  wp->w_s = &wp->w_buffer->b_s;
}

/*
 * Allocate the first window and put an empty buffer in it.
 * Called from main().
 * Return FAIL when something goes wrong (out of memory).
 */
int win_alloc_first(void)         {
  if (win_alloc_firstwin(NULL) == FAIL)
    return FAIL;

  first_tabpage = alloc_tabpage();
  if (first_tabpage == NULL)
    return FAIL;
  first_tabpage->tp_topframe = topframe;
  curtab = first_tabpage;

  return OK;
}

/*
 * Init "aucmd_win".  This can only be done after the first
 * window is fully initialized, thus it can't be in win_alloc_first().
 */
void win_alloc_aucmd_win(void)          {
  aucmd_win = win_alloc(NULL, TRUE);
  if (aucmd_win != NULL) {
    win_init_some(aucmd_win, curwin);
    RESET_BINDING(aucmd_win);
    new_frame(aucmd_win);
  }
}

/*
 * Allocate the first window or the first window in a new tab page.
 * When "oldwin" is NULL create an empty buffer for it.
 * When "oldwin" is not NULL copy info from it to the new window (only with
 * FEAT_WINDOWS).
 * Return FAIL when something goes wrong (out of memory).
 */
static int win_alloc_firstwin(win_T *oldwin)
{
  curwin = win_alloc(NULL, FALSE);
  if (oldwin == NULL) {
    /* Very first window, need to create an empty buffer for it and
     * initialize from scratch. */
    curbuf = buflist_new(NULL, NULL, 1L, BLN_LISTED);
    if (curwin == NULL || curbuf == NULL)
      return FAIL;
    curwin->w_buffer = curbuf;
    curwin->w_s = &(curbuf->b_s);
    curbuf->b_nwindows = 1;     /* there is one window */
    curwin->w_alist = &global_alist;
    curwin_init();              /* init current window */
  } else   {
    /* First window in new tab page, initialize it from "oldwin". */
    win_init(curwin, oldwin, 0);

    /* We don't want cursor- and scroll-binding in the first window. */
    RESET_BINDING(curwin);
  }

  new_frame(curwin);
  if (curwin->w_frame == NULL)
    return FAIL;
  topframe = curwin->w_frame;
  topframe->fr_width = Columns;
  topframe->fr_height = Rows - p_ch;
  topframe->fr_win = curwin;

  return OK;
}

/*
 * Create a frame for window "wp".
 */
static void new_frame(win_T *wp)                 {
  frame_T *frp = (frame_T *)alloc_clear((unsigned)sizeof(frame_T));

  wp->w_frame = frp;
  if (frp != NULL) {
    frp->fr_layout = FR_LEAF;
    frp->fr_win = wp;
  }
}

/*
 * Initialize the window and frame size to the maximum.
 */
void win_init_size(void)          {
  firstwin->w_height = ROWS_AVAIL;
  topframe->fr_height = ROWS_AVAIL;
  firstwin->w_width = Columns;
  topframe->fr_width = Columns;
}

/*
 * Allocate a new tabpage_T and init the values.
 * Returns NULL when out of memory.
 */
static tabpage_T *alloc_tabpage(void)                        {
  tabpage_T   *tp;


  tp = (tabpage_T *)alloc_clear((unsigned)sizeof(tabpage_T));
  if (tp == NULL)
    return NULL;

  /* init t: variables */
  tp->tp_vars = dict_alloc();
  if (tp->tp_vars == NULL) {
    vim_free(tp);
    return NULL;
  }
  init_var_dict(tp->tp_vars, &tp->tp_winvar, VAR_SCOPE);

  tp->tp_diff_invalid = TRUE;
  tp->tp_ch_used = p_ch;

  return tp;
}

void free_tabpage(tabpage_T *tp)
{
  int idx;

  diff_clear(tp);
  for (idx = 0; idx < SNAP_COUNT; ++idx)
    clear_snapshot(tp, idx);
  vars_clear(&tp->tp_vars->dv_hashtab);         /* free all t: variables */
  hash_init(&tp->tp_vars->dv_hashtab);
  unref_var_dict(tp->tp_vars);



  vim_free(tp);
}

/*
 * Create a new Tab page with one window.
 * It will edit the current buffer, like after ":split".
 * When "after" is 0 put it just after the current Tab page.
 * Otherwise put it just before tab page "after".
 * Return FAIL or OK.
 */
int win_new_tabpage(int after)
{
  tabpage_T   *tp = curtab;
  tabpage_T   *newtp;
  int n;

  newtp = alloc_tabpage();
  if (newtp == NULL)
    return FAIL;

  /* Remember the current windows in this Tab page. */
  if (leave_tabpage(curbuf, TRUE) == FAIL) {
    vim_free(newtp);
    return FAIL;
  }
  curtab = newtp;

  /* Create a new empty window. */
  if (win_alloc_firstwin(tp->tp_curwin) == OK) {
    /* Make the new Tab page the new topframe. */
    if (after == 1) {
      /* New tab page becomes the first one. */
      newtp->tp_next = first_tabpage;
      first_tabpage = newtp;
    } else   {
      if (after > 0) {
        /* Put new tab page before tab page "after". */
        n = 2;
        for (tp = first_tabpage; tp->tp_next != NULL
             && n < after; tp = tp->tp_next)
          ++n;
      }
      newtp->tp_next = tp->tp_next;
      tp->tp_next = newtp;
    }
    win_init_size();
    firstwin->w_winrow = tabline_height();
    win_comp_scroll(curwin);

    newtp->tp_topframe = topframe;
    last_status(FALSE);


    redraw_all_later(CLEAR);
    apply_autocmds(EVENT_WINENTER, NULL, NULL, FALSE, curbuf);
    apply_autocmds(EVENT_TABENTER, NULL, NULL, FALSE, curbuf);
    return OK;
  }

  /* Failed, get back the previous Tab page */
  enter_tabpage(curtab, curbuf, TRUE, TRUE);
  return FAIL;
}

/*
 * Open a new tab page if ":tab cmd" was used.  It will edit the same buffer,
 * like with ":split".
 * Returns OK if a new tab page was created, FAIL otherwise.
 */
int may_open_tabpage(void)         {
  int n = (cmdmod.tab == 0) ? postponed_split_tab : cmdmod.tab;

  if (n != 0) {
    cmdmod.tab = 0;         /* reset it to avoid doing it twice */
    postponed_split_tab = 0;
    return win_new_tabpage(n);
  }
  return FAIL;
}

/*
 * Create up to "maxcount" tabpages with empty windows.
 * Returns the number of resulting tab pages.
 */
int make_tabpages(int maxcount)
{
  int count = maxcount;
  int todo;

  /* Limit to 'tabpagemax' tabs. */
  if (count > p_tpm)
    count = p_tpm;

  /*
   * Don't execute autocommands while creating the tab pages.  Must do that
   * when putting the buffers in the windows.
   */
  block_autocmds();

  for (todo = count - 1; todo > 0; --todo)
    if (win_new_tabpage(0) == FAIL)
      break;

  unblock_autocmds();

  /* return actual number of tab pages */
  return count - todo;
}

/*
 * Return TRUE when "tpc" points to a valid tab page.
 */
int valid_tabpage(tabpage_T *tpc)
{
  tabpage_T   *tp;

  for (tp = first_tabpage; tp != NULL; tp = tp->tp_next)
    if (tp == tpc)
      return TRUE;
  return FALSE;
}

/*
 * Find tab page "n" (first one is 1).  Returns NULL when not found.
 */
tabpage_T *find_tabpage(int n)
{
  tabpage_T   *tp;
  int i = 1;

  for (tp = first_tabpage; tp != NULL && i != n; tp = tp->tp_next)
    ++i;
  return tp;
}

/*
 * Get index of tab page "tp".  First one has index 1.
 * When not found returns number of tab pages plus one.
 */
int tabpage_index(tabpage_T *ftp)
{
  int i = 1;
  tabpage_T   *tp;

  for (tp = first_tabpage; tp != NULL && tp != ftp; tp = tp->tp_next)
    ++i;
  return i;
}

/*
 * Prepare for leaving the current tab page.
 * When autocommands change "curtab" we don't leave the tab page and return
 * FAIL.
 * Careful: When OK is returned need to get a new tab page very very soon!
 */
static int 
leave_tabpage (
    buf_T *new_curbuf,        /* what is going to be the new curbuf,
                                          NULL if unknown */
    int trigger_leave_autocmds
)
{
  tabpage_T   *tp = curtab;

  reset_VIsual_and_resel();     /* stop Visual mode */
  if (trigger_leave_autocmds) {
    if (new_curbuf != curbuf) {
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, FALSE, curbuf);
      if (curtab != tp)
        return FAIL;
    }
    apply_autocmds(EVENT_WINLEAVE, NULL, NULL, FALSE, curbuf);
    if (curtab != tp)
      return FAIL;
    apply_autocmds(EVENT_TABLEAVE, NULL, NULL, FALSE, curbuf);
    if (curtab != tp)
      return FAIL;
  }
  tp->tp_curwin = curwin;
  tp->tp_prevwin = prevwin;
  tp->tp_firstwin = firstwin;
  tp->tp_lastwin = lastwin;
  tp->tp_old_Rows = Rows;
  tp->tp_old_Columns = Columns;
  firstwin = NULL;
  lastwin = NULL;
  return OK;
}

/*
 * Start using tab page "tp".
 * Only to be used after leave_tabpage() or freeing the current tab page.
 * Only trigger *Enter autocommands when trigger_enter_autocmds is TRUE.
 * Only trigger *Leave autocommands when trigger_leave_autocmds is TRUE.
 */
static void enter_tabpage(tabpage_T *tp, buf_T *old_curbuf, int trigger_enter_autocmds, int trigger_leave_autocmds)
{
  int old_off = tp->tp_firstwin->w_winrow;
  win_T       *next_prevwin = tp->tp_prevwin;

  curtab = tp;
  firstwin = tp->tp_firstwin;
  lastwin = tp->tp_lastwin;
  topframe = tp->tp_topframe;

  /* We would like doing the TabEnter event first, but we don't have a
   * valid current window yet, which may break some commands.
   * This triggers autocommands, thus may make "tp" invalid. */
  win_enter_ext(tp->tp_curwin, FALSE, TRUE,
      trigger_enter_autocmds, trigger_leave_autocmds);
  prevwin = next_prevwin;

  last_status(FALSE);           /* status line may appear or disappear */
  (void)win_comp_pos();         /* recompute w_winrow for all windows */
  must_redraw = CLEAR;          /* need to redraw everything */
  diff_need_scrollbind = TRUE;

  /* The tabpage line may have appeared or disappeared, may need to resize
   * the frames for that.  When the Vim window was resized need to update
   * frame sizes too.  Use the stored value of p_ch, so that it can be
   * different for each tab page. */
  p_ch = curtab->tp_ch_used;
  if (curtab->tp_old_Rows != Rows || (old_off != firstwin->w_winrow
                                      ))
    shell_new_rows();
  if (curtab->tp_old_Columns != Columns && starting == 0)
    shell_new_columns();        /* update window widths */


  /* Apply autocommands after updating the display, when 'rows' and
   * 'columns' have been set correctly. */
  if (trigger_enter_autocmds) {
    apply_autocmds(EVENT_TABENTER, NULL, NULL, FALSE, curbuf);
    if (old_curbuf != curbuf)
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, FALSE, curbuf);
  }

  redraw_all_later(CLEAR);
}

/*
 * Go to tab page "n".  For ":tab N" and "Ngt".
 * When "n" is 9999 go to the last tab page.
 */
void goto_tabpage(int n)
{
  tabpage_T   *tp;
  tabpage_T   *ttp;
  int i;

  if (text_locked()) {
    /* Not allowed when editing the command line. */
    if (cmdwin_type != 0)
      EMSG(_(e_cmdwin));
    else
      EMSG(_(e_secure));
    return;
  }

  /* If there is only one it can't work. */
  if (first_tabpage->tp_next == NULL) {
    if (n > 1)
      beep_flush();
    return;
  }

  if (n == 0) {
    /* No count, go to next tab page, wrap around end. */
    if (curtab->tp_next == NULL)
      tp = first_tabpage;
    else
      tp = curtab->tp_next;
  } else if (n < 0)   {
    /* "gT": go to previous tab page, wrap around end.  "N gT" repeats
     * this N times. */
    ttp = curtab;
    for (i = n; i < 0; ++i) {
      for (tp = first_tabpage; tp->tp_next != ttp && tp->tp_next != NULL;
           tp = tp->tp_next)
        ;
      ttp = tp;
    }
  } else if (n == 9999)   {
    /* Go to last tab page. */
    for (tp = first_tabpage; tp->tp_next != NULL; tp = tp->tp_next)
      ;
  } else   {
    /* Go to tab page "n". */
    tp = find_tabpage(n);
    if (tp == NULL) {
      beep_flush();
      return;
    }
  }

  goto_tabpage_tp(tp, TRUE, TRUE);

}

/*
 * Go to tabpage "tp".
 * Only trigger *Enter autocommands when trigger_enter_autocmds is TRUE.
 * Only trigger *Leave autocommands when trigger_leave_autocmds is TRUE.
 * Note: doesn't update the GUI tab.
 */
void goto_tabpage_tp(tabpage_T *tp, int trigger_enter_autocmds, int trigger_leave_autocmds)
{
  /* Don't repeat a message in another tab page. */
  set_keep_msg(NULL, 0);

  if (tp != curtab && leave_tabpage(tp->tp_curwin->w_buffer,
          trigger_leave_autocmds) == OK) {
    if (valid_tabpage(tp))
      enter_tabpage(tp, curbuf, trigger_enter_autocmds,
          trigger_leave_autocmds);
    else
      enter_tabpage(curtab, curbuf, trigger_enter_autocmds,
          trigger_leave_autocmds);
  }
}

/*
 * Enter window "wp" in tab page "tp".
 * Also updates the GUI tab.
 */
void goto_tabpage_win(tabpage_T *tp, win_T *wp)
{
  goto_tabpage_tp(tp, TRUE, TRUE);
  if (curtab == tp && win_valid(wp)) {
    win_enter(wp, TRUE);
  }
}

/*
 * Move the current tab page to before tab page "nr".
 */
void tabpage_move(int nr)
{
  int n = nr;
  tabpage_T   *tp;

  if (first_tabpage->tp_next == NULL)
    return;

  /* Remove the current tab page from the list of tab pages. */
  if (curtab == first_tabpage)
    first_tabpage = curtab->tp_next;
  else {
    for (tp = first_tabpage; tp != NULL; tp = tp->tp_next)
      if (tp->tp_next == curtab)
        break;
    if (tp == NULL)     /* "cannot happen" */
      return;
    tp->tp_next = curtab->tp_next;
  }

  /* Re-insert it at the specified position. */
  if (n <= 0) {
    curtab->tp_next = first_tabpage;
    first_tabpage = curtab;
  } else   {
    for (tp = first_tabpage; tp->tp_next != NULL && n > 1; tp = tp->tp_next)
      --n;
    curtab->tp_next = tp->tp_next;
    tp->tp_next = curtab;
  }

  /* Need to redraw the tabline.  Tab page contents doesn't change. */
  redraw_tabline = TRUE;
}


/*
 * Go to another window.
 * When jumping to another buffer, stop Visual mode.  Do this before
 * changing windows so we can yank the selection into the '*' register.
 * When jumping to another window on the same buffer, adjust its cursor
 * position to keep the same Visual area.
 */
void win_goto(win_T *wp)
{
  win_T       *owp = curwin;

  if (text_locked()) {
    beep_flush();
    text_locked_msg();
    return;
  }
  if (curbuf_locked())
    return;

  if (wp->w_buffer != curbuf)
    reset_VIsual_and_resel();
  else if (VIsual_active)
    wp->w_cursor = curwin->w_cursor;

  win_enter(wp, TRUE);

  /* Conceal cursor line in previous window, unconceal in current window. */
  if (win_valid(owp) && owp->w_p_cole > 0 && !msg_scrolled)
    update_single_line(owp, owp->w_cursor.lnum);
  if (curwin->w_p_cole > 0 && !msg_scrolled)
    need_cursor_line_redraw = TRUE;
}


#if (defined(FEAT_WINDOWS) && (defined(FEAT_PYTHON) || defined(FEAT_PYTHON3))) \
  || defined(PROTO)
/*
 * Find the tabpage for window "win".
 */
tabpage_T *win_find_tabpage(win_T *win)
{
  win_T       *wp;
  tabpage_T   *tp;

  for (tp = first_tabpage; tp != NULL; tp = tp->tp_next)
    for (wp = (tp == curtab ? firstwin : tp->tp_firstwin);
         wp != NULL; wp = wp->w_next)
      if (wp == win)
        return tp;
  return NULL;
}
#endif

/*
 * Move to window above or below "count" times.
 */
static void 
win_goto_ver (
    int up,                         /* TRUE to go to win above */
    long count
)
{
  frame_T     *fr;
  frame_T     *nfr;
  frame_T     *foundfr;

  foundfr = curwin->w_frame;
  while (count--) {
    /*
     * First go upwards in the tree of frames until we find a upwards or
     * downwards neighbor.
     */
    fr = foundfr;
    for (;; ) {
      if (fr == topframe)
        goto end;
      if (up)
        nfr = fr->fr_prev;
      else
        nfr = fr->fr_next;
      if (fr->fr_parent->fr_layout == FR_COL && nfr != NULL)
        break;
      fr = fr->fr_parent;
    }

    /*
     * Now go downwards to find the bottom or top frame in it.
     */
    for (;; ) {
      if (nfr->fr_layout == FR_LEAF) {
        foundfr = nfr;
        break;
      }
      fr = nfr->fr_child;
      if (nfr->fr_layout == FR_ROW) {
        /* Find the frame at the cursor row. */
        while (fr->fr_next != NULL
               && frame2win(fr)->w_wincol + fr->fr_width
               <= curwin->w_wincol + curwin->w_wcol)
          fr = fr->fr_next;
      }
      if (nfr->fr_layout == FR_COL && up)
        while (fr->fr_next != NULL)
          fr = fr->fr_next;
      nfr = fr;
    }
  }
end:
  if (foundfr != NULL)
    win_goto(foundfr->fr_win);
}

/*
 * Move to left or right window.
 */
static void 
win_goto_hor (
    int left,                       /* TRUE to go to left win */
    long count
)
{
  frame_T     *fr;
  frame_T     *nfr;
  frame_T     *foundfr;

  foundfr = curwin->w_frame;
  while (count--) {
    /*
     * First go upwards in the tree of frames until we find a left or
     * right neighbor.
     */
    fr = foundfr;
    for (;; ) {
      if (fr == topframe)
        goto end;
      if (left)
        nfr = fr->fr_prev;
      else
        nfr = fr->fr_next;
      if (fr->fr_parent->fr_layout == FR_ROW && nfr != NULL)
        break;
      fr = fr->fr_parent;
    }

    /*
     * Now go downwards to find the leftmost or rightmost frame in it.
     */
    for (;; ) {
      if (nfr->fr_layout == FR_LEAF) {
        foundfr = nfr;
        break;
      }
      fr = nfr->fr_child;
      if (nfr->fr_layout == FR_COL) {
        /* Find the frame at the cursor row. */
        while (fr->fr_next != NULL
               && frame2win(fr)->w_winrow + fr->fr_height
               <= curwin->w_winrow + curwin->w_wrow)
          fr = fr->fr_next;
      }
      if (nfr->fr_layout == FR_ROW && left)
        while (fr->fr_next != NULL)
          fr = fr->fr_next;
      nfr = fr;
    }
  }
end:
  if (foundfr != NULL)
    win_goto(foundfr->fr_win);
}

/*
 * Make window "wp" the current window.
 */
void win_enter(win_T *wp, int undo_sync)
{
  win_enter_ext(wp, undo_sync, FALSE, TRUE, TRUE);
}

/*
 * Make window wp the current window.
 * Can be called with "curwin_invalid" TRUE, which means that curwin has just
 * been closed and isn't valid.
 */
static void win_enter_ext(win_T *wp, int undo_sync, int curwin_invalid, int trigger_enter_autocmds, int trigger_leave_autocmds)
{
  int other_buffer = FALSE;

  if (wp == curwin && !curwin_invalid)          /* nothing to do */
    return;

  if (!curwin_invalid && trigger_leave_autocmds) {
    /*
     * Be careful: If autocommands delete the window, return now.
     */
    if (wp->w_buffer != curbuf) {
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, FALSE, curbuf);
      other_buffer = TRUE;
      if (!win_valid(wp))
        return;
    }
    apply_autocmds(EVENT_WINLEAVE, NULL, NULL, FALSE, curbuf);
    if (!win_valid(wp))
      return;
    /* autocmds may abort script processing */
    if (aborting())
      return;
  }

  /* sync undo before leaving the current buffer */
  if (undo_sync && curbuf != wp->w_buffer)
    u_sync(FALSE);
  /* may have to copy the buffer options when 'cpo' contains 'S' */
  if (wp->w_buffer != curbuf)
    buf_copy_options(wp->w_buffer, BCO_ENTER | BCO_NOHELP);
  if (!curwin_invalid) {
    prevwin = curwin;           /* remember for CTRL-W p */
    curwin->w_redr_status = TRUE;
  }
  curwin = wp;
  curbuf = wp->w_buffer;
  check_cursor();
  if (!virtual_active())
    curwin->w_cursor.coladd = 0;
  changed_line_abv_curs();      /* assume cursor position needs updating */

  if (curwin->w_localdir != NULL) {
    /* Window has a local directory: Save current directory as global
     * directory (unless that was done already) and change to the local
     * directory. */
    if (globaldir == NULL) {
      char_u cwd[MAXPATHL];

      if (mch_dirname(cwd, MAXPATHL) == OK)
        globaldir = vim_strsave(cwd);
    }
    if (mch_chdir((char *)curwin->w_localdir) == 0)
      shorten_fnames(TRUE);
  } else if (globaldir != NULL)   {
    /* Window doesn't have a local directory and we are not in the global
     * directory: Change to the global directory. */
    ignored = mch_chdir((char *)globaldir);
    vim_free(globaldir);
    globaldir = NULL;
    shorten_fnames(TRUE);
  }

  if (trigger_enter_autocmds) {
    apply_autocmds(EVENT_WINENTER, NULL, NULL, FALSE, curbuf);
    if (other_buffer)
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, FALSE, curbuf);
  }

  maketitle();
  curwin->w_redr_status = TRUE;
  redraw_tabline = TRUE;
  if (restart_edit)
    redraw_later(VALID);        /* causes status line redraw */

  /* set window height to desired minimal value */
  if (curwin->w_height < p_wh && !curwin->w_p_wfh)
    win_setheight((int)p_wh);
  else if (curwin->w_height == 0)
    win_setheight(1);

  /* set window width to desired minimal value */
  if (curwin->w_width < p_wiw && !curwin->w_p_wfw)
    win_setwidth((int)p_wiw);

  setmouse();                   /* in case jumped to/from help buffer */

  /* Change directories when the 'acd' option is set. */
  DO_AUTOCHDIR
}


/*
 * Jump to the first open window that contains buffer "buf", if one exists.
 * Returns a pointer to the window found, otherwise NULL.
 */
win_T *buf_jump_open_win(buf_T *buf)
{
  win_T       *wp;

  for (wp = firstwin; wp != NULL; wp = wp->w_next)
    if (wp->w_buffer == buf)
      break;
  if (wp != NULL)
    win_enter(wp, FALSE);
  return wp;
}

/*
 * Jump to the first open window in any tab page that contains buffer "buf",
 * if one exists.
 * Returns a pointer to the window found, otherwise NULL.
 */
win_T *buf_jump_open_tab(buf_T *buf)
{
  win_T       *wp;
  tabpage_T   *tp;

  /* First try the current tab page. */
  wp = buf_jump_open_win(buf);
  if (wp != NULL)
    return wp;

  for (tp = first_tabpage; tp != NULL; tp = tp->tp_next)
    if (tp != curtab) {
      for (wp = tp->tp_firstwin; wp != NULL; wp = wp->w_next)
        if (wp->w_buffer == buf)
          break;
      if (wp != NULL) {
        goto_tabpage_win(tp, wp);
        if (curwin != wp)
          wp = NULL;            /* something went wrong */
        break;
      }
    }

  return wp;
}

/*
 * Allocate a window structure and link it in the window list when "hidden" is
 * FALSE.
 */
static win_T *win_alloc(win_T *after, int hidden)
{
  win_T       *new_wp;

  /*
   * allocate window structure and linesizes arrays
   */
  new_wp = (win_T *)alloc_clear((unsigned)sizeof(win_T));
  if (new_wp == NULL)
    return NULL;

  if (win_alloc_lines(new_wp) == FAIL) {
    vim_free(new_wp);
    return NULL;
  }

  /* init w: variables */
  new_wp->w_vars = dict_alloc();
  if (new_wp->w_vars == NULL) {
    win_free_lsize(new_wp);
    vim_free(new_wp);
    return NULL;
  }
  init_var_dict(new_wp->w_vars, &new_wp->w_winvar, VAR_SCOPE);

  /* Don't execute autocommands while the window is not properly
   * initialized yet.  gui_create_scrollbar() may trigger a FocusGained
   * event. */
  block_autocmds();
  /*
   * link the window in the window list
   */
  if (!hidden)
    win_append(after, new_wp);
  new_wp->w_wincol = 0;
  new_wp->w_width = Columns;

  /* position the display and the cursor at the top of the file. */
  new_wp->w_topline = 1;
  new_wp->w_topfill = 0;
  new_wp->w_botline = 2;
  new_wp->w_cursor.lnum = 1;
  new_wp->w_scbind_pos = 1;

  /* We won't calculate w_fraction until resizing the window */
  new_wp->w_fraction = 0;
  new_wp->w_prev_fraction_row = -1;

  foldInitWin(new_wp);
  unblock_autocmds();
  new_wp->w_match_head = NULL;
  new_wp->w_next_match_id = 4;
  return new_wp;
}


/*
 * Remove window 'wp' from the window list and free the structure.
 */
static void 
win_free (
    win_T *wp,
    tabpage_T *tp                /* tab page "win" is in, NULL for current */
)
{
  int i;
  buf_T       *buf;
  wininfo_T   *wip;

  clearFolding(wp);

  /* reduce the reference count to the argument list. */
  alist_unlink(wp->w_alist);

  /* Don't execute autocommands while the window is halfway being deleted.
   * gui_mch_destroy_scrollbar() may trigger a FocusGained event. */
  block_autocmds();








  clear_winopt(&wp->w_onebuf_opt);
  clear_winopt(&wp->w_allbuf_opt);

  vars_clear(&wp->w_vars->dv_hashtab);          /* free all w: variables */
  hash_init(&wp->w_vars->dv_hashtab);
  unref_var_dict(wp->w_vars);

  if (prevwin == wp)
    prevwin = NULL;
  win_free_lsize(wp);

  for (i = 0; i < wp->w_tagstacklen; ++i)
    vim_free(wp->w_tagstack[i].tagname);

  vim_free(wp->w_localdir);

  /* Remove the window from the b_wininfo lists, it may happen that the
   * freed memory is re-used for another window. */
  for (buf = firstbuf; buf != NULL; buf = buf->b_next)
    for (wip = buf->b_wininfo; wip != NULL; wip = wip->wi_next)
      if (wip->wi_win == wp)
        wip->wi_win = NULL;

  clear_matches(wp);

  free_jumplist(wp);

  qf_free_all(wp);


  vim_free(wp->w_p_cc_cols);

  if (wp != aucmd_win)
    win_remove(wp, tp);
  vim_free(wp);

  unblock_autocmds();
}

/*
 * Append window "wp" in the window list after window "after".
 */
void win_append(win_T *after, win_T *wp)
{
  win_T       *before;

  if (after == NULL)        /* after NULL is in front of the first */
    before = firstwin;
  else
    before = after->w_next;

  wp->w_next = before;
  wp->w_prev = after;
  if (after == NULL)
    firstwin = wp;
  else
    after->w_next = wp;
  if (before == NULL)
    lastwin = wp;
  else
    before->w_prev = wp;
}

/*
 * Remove a window from the window list.
 */
void 
win_remove (
    win_T *wp,
    tabpage_T *tp                /* tab page "win" is in, NULL for current */
)
{
  if (wp->w_prev != NULL)
    wp->w_prev->w_next = wp->w_next;
  else if (tp == NULL)
    firstwin = wp->w_next;
  else
    tp->tp_firstwin = wp->w_next;
  if (wp->w_next != NULL)
    wp->w_next->w_prev = wp->w_prev;
  else if (tp == NULL)
    lastwin = wp->w_prev;
  else
    tp->tp_lastwin = wp->w_prev;
}

/*
 * Append frame "frp" in a frame list after frame "after".
 */
static void frame_append(frame_T *after, frame_T *frp)
{
  frp->fr_next = after->fr_next;
  after->fr_next = frp;
  if (frp->fr_next != NULL)
    frp->fr_next->fr_prev = frp;
  frp->fr_prev = after;
}

/*
 * Insert frame "frp" in a frame list before frame "before".
 */
static void frame_insert(frame_T *before, frame_T *frp)
{
  frp->fr_next = before;
  frp->fr_prev = before->fr_prev;
  before->fr_prev = frp;
  if (frp->fr_prev != NULL)
    frp->fr_prev->fr_next = frp;
  else
    frp->fr_parent->fr_child = frp;
}

/*
 * Remove a frame from a frame list.
 */
static void frame_remove(frame_T *frp)
{
  if (frp->fr_prev != NULL)
    frp->fr_prev->fr_next = frp->fr_next;
  else
    frp->fr_parent->fr_child = frp->fr_next;
  if (frp->fr_next != NULL)
    frp->fr_next->fr_prev = frp->fr_prev;
}


/*
 * Allocate w_lines[] for window "wp".
 * Return FAIL for failure, OK for success.
 */
int win_alloc_lines(win_T *wp)
{
  wp->w_lines_valid = 0;
  wp->w_lines = (wline_T *)alloc_clear((unsigned)(Rows * sizeof(wline_T)));
  if (wp->w_lines == NULL)
    return FAIL;
  return OK;
}

/*
 * free lsize arrays for a window
 */
void win_free_lsize(win_T *wp)
{
  vim_free(wp->w_lines);
  wp->w_lines = NULL;
}

/*
 * Called from win_new_shellsize() after Rows changed.
 * This only does the current tab page, others must be done when made active.
 */
void shell_new_rows(void)          {
  int h = (int)ROWS_AVAIL;

  if (firstwin == NULL)         /* not initialized yet */
    return;
  if (h < frame_minheight(topframe, NULL))
    h = frame_minheight(topframe, NULL);

  /* First try setting the heights of windows with 'winfixheight'.  If
   * that doesn't result in the right height, forget about that option. */
  frame_new_height(topframe, h, FALSE, TRUE);
  if (!frame_check_height(topframe, h))
    frame_new_height(topframe, h, FALSE, FALSE);

  (void)win_comp_pos();                 /* recompute w_winrow and w_wincol */
  compute_cmdrow();
  curtab->tp_ch_used = p_ch;

}

/*
 * Called from win_new_shellsize() after Columns changed.
 */
void shell_new_columns(void)          {
  if (firstwin == NULL)         /* not initialized yet */
    return;

  /* First try setting the widths of windows with 'winfixwidth'.  If that
   * doesn't result in the right width, forget about that option. */
  frame_new_width(topframe, (int)Columns, FALSE, TRUE);
  if (!frame_check_width(topframe, Columns))
    frame_new_width(topframe, (int)Columns, FALSE, FALSE);

  (void)win_comp_pos();                 /* recompute w_winrow and w_wincol */
}

/*
 * Save the size of all windows in "gap".
 */
void win_size_save(garray_T *gap)

{
  win_T       *wp;

  ga_init2(gap, (int)sizeof(int), 1);
  if (ga_grow(gap, win_count() * 2) == OK)
    for (wp = firstwin; wp != NULL; wp = wp->w_next) {
      ((int *)gap->ga_data)[gap->ga_len++] =
        wp->w_width + wp->w_vsep_width;
      ((int *)gap->ga_data)[gap->ga_len++] = wp->w_height;
    }
}

/*
 * Restore window sizes, but only if the number of windows is still the same.
 * Does not free the growarray.
 */
void win_size_restore(garray_T *gap)
{
  win_T       *wp;
  int i;

  if (win_count() * 2 == gap->ga_len) {
    i = 0;
    for (wp = firstwin; wp != NULL; wp = wp->w_next) {
      frame_setwidth(wp->w_frame, ((int *)gap->ga_data)[i++]);
      win_setheight_win(((int *)gap->ga_data)[i++], wp);
    }
    /* recompute the window positions */
    (void)win_comp_pos();
  }
}

/*
 * Update the position for all windows, using the width and height of the
 * frames.
 * Returns the row just after the last window.
 */
int win_comp_pos(void)         {
  int row = tabline_height();
  int col = 0;

  frame_comp_pos(topframe, &row, &col);
  return row;
}

/*
 * Update the position of the windows in frame "topfrp", using the width and
 * height of the frames.
 * "*row" and "*col" are the top-left position of the frame.  They are updated
 * to the bottom-right position plus one.
 */
static void frame_comp_pos(frame_T *topfrp, int *row, int *col)
{
  win_T       *wp;
  frame_T     *frp;
  int startcol;
  int startrow;

  wp = topfrp->fr_win;
  if (wp != NULL) {
    if (wp->w_winrow != *row
        || wp->w_wincol != *col
        ) {
      /* position changed, redraw */
      wp->w_winrow = *row;
      wp->w_wincol = *col;
      redraw_win_later(wp, NOT_VALID);
      wp->w_redr_status = TRUE;
    }
    *row += wp->w_height + wp->w_status_height;
    *col += wp->w_width + wp->w_vsep_width;
  } else   {
    startrow = *row;
    startcol = *col;
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
      if (topfrp->fr_layout == FR_ROW)
        *row = startrow;                /* all frames are at the same row */
      else
        *col = startcol;                /* all frames are at the same col */
      frame_comp_pos(frp, row, col);
    }
  }
}


/*
 * Set current window height and take care of repositioning other windows to
 * fit around it.
 */
void win_setheight(int height)
{
  win_setheight_win(height, curwin);
}

/*
 * Set the window height of window "win" and take care of repositioning other
 * windows to fit around it.
 */
void win_setheight_win(int height, win_T *win)
{
  int row;

  if (win == curwin) {
    /* Always keep current window at least one line high, even when
     * 'winminheight' is zero. */
    if (height < p_wmh)
      height = p_wmh;
    if (height == 0)
      height = 1;
  }

  frame_setheight(win->w_frame, height + win->w_status_height);

  /* recompute the window positions */
  row = win_comp_pos();

  /*
   * If there is extra space created between the last window and the command
   * line, clear it.
   */
  if (full_screen && msg_scrolled == 0 && row < cmdline_row)
    screen_fill(row, cmdline_row, 0, (int)Columns, ' ', ' ', 0);
  cmdline_row = row;
  msg_row = row;
  msg_col = 0;

  redraw_all_later(NOT_VALID);
}


/*
 * Set the height of a frame to "height" and take care that all frames and
 * windows inside it are resized.  Also resize frames on the left and right if
 * the are in the same FR_ROW frame.
 *
 * Strategy:
 * If the frame is part of a FR_COL frame, try fitting the frame in that
 * frame.  If that doesn't work (the FR_COL frame is too small), recursively
 * go to containing frames to resize them and make room.
 * If the frame is part of a FR_ROW frame, all frames must be resized as well.
 * Check for the minimal height of the FR_ROW frame.
 * At the top level we can also use change the command line height.
 */
static void frame_setheight(frame_T *curfrp, int height)
{
  int room;                     /* total number of lines available */
  int take;                     /* number of lines taken from other windows */
  int room_cmdline;             /* lines available from cmdline */
  int run;
  frame_T     *frp;
  int h;
  int room_reserved;

  /* If the height already is the desired value, nothing to do. */
  if (curfrp->fr_height == height)
    return;

  if (curfrp->fr_parent == NULL) {
    /* topframe: can only change the command line */
    if (height > ROWS_AVAIL)
      height = ROWS_AVAIL;
    if (height > 0)
      frame_new_height(curfrp, height, FALSE, FALSE);
  } else if (curfrp->fr_parent->fr_layout == FR_ROW)   {
    /* Row of frames: Also need to resize frames left and right of this
     * one.  First check for the minimal height of these. */
    h = frame_minheight(curfrp->fr_parent, NULL);
    if (height < h)
      height = h;
    frame_setheight(curfrp->fr_parent, height);
  } else   {
    /*
     * Column of frames: try to change only frames in this column.
     */
    /*
     * Do this twice:
     * 1: compute room available, if it's not enough try resizing the
     *    containing frame.
     * 2: compute the room available and adjust the height to it.
     * Try not to reduce the height of a window with 'winfixheight' set.
     */
    for (run = 1; run <= 2; ++run) {
      room = 0;
      room_reserved = 0;
      for (frp = curfrp->fr_parent->fr_child; frp != NULL;
           frp = frp->fr_next) {
        if (frp != curfrp
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfh)
          room_reserved += frp->fr_height;
        room += frp->fr_height;
        if (frp != curfrp)
          room -= frame_minheight(frp, NULL);
      }
      if (curfrp->fr_width != Columns)
        room_cmdline = 0;
      else {
        room_cmdline = Rows - p_ch - (lastwin->w_winrow
                                      + lastwin->w_height +
                                      lastwin->w_status_height);
        if (room_cmdline < 0)
          room_cmdline = 0;
      }

      if (height <= room + room_cmdline)
        break;
      if (run == 2 || curfrp->fr_width == Columns) {
        if (height > room + room_cmdline)
          height = room + room_cmdline;
        break;
      }
      frame_setheight(curfrp->fr_parent, height
          + frame_minheight(curfrp->fr_parent, NOWIN) - (int)p_wmh - 1);
      /*NOTREACHED*/
    }

    /*
     * Compute the number of lines we will take from others frames (can be
     * negative!).
     */
    take = height - curfrp->fr_height;

    /* If there is not enough room, also reduce the height of a window
     * with 'winfixheight' set. */
    if (height > room + room_cmdline - room_reserved)
      room_reserved = room + room_cmdline - height;
    /* If there is only a 'winfixheight' window and making the
    * window smaller, need to make the other window taller. */
    if (take < 0 && room - curfrp->fr_height < room_reserved)
      room_reserved = 0;

    if (take > 0 && room_cmdline > 0) {
      /* use lines from cmdline first */
      if (take < room_cmdline)
        room_cmdline = take;
      take -= room_cmdline;
      topframe->fr_height += room_cmdline;
    }

    /*
     * set the current frame to the new height
     */
    frame_new_height(curfrp, height, FALSE, FALSE);

    /*
     * First take lines from the frames after the current frame.  If
     * that is not enough, takes lines from frames above the current
     * frame.
     */
    for (run = 0; run < 2; ++run) {
      if (run == 0)
        frp = curfrp->fr_next;          /* 1st run: start with next window */
      else
        frp = curfrp->fr_prev;          /* 2nd run: start with prev window */
      while (frp != NULL && take != 0) {
        h = frame_minheight(frp, NULL);
        if (room_reserved > 0
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfh) {
          if (room_reserved >= frp->fr_height)
            room_reserved -= frp->fr_height;
          else {
            if (frp->fr_height - room_reserved > take)
              room_reserved = frp->fr_height - take;
            take -= frp->fr_height - room_reserved;
            frame_new_height(frp, room_reserved, FALSE, FALSE);
            room_reserved = 0;
          }
        } else   {
          if (frp->fr_height - take < h) {
            take -= frp->fr_height - h;
            frame_new_height(frp, h, FALSE, FALSE);
          } else   {
            frame_new_height(frp, frp->fr_height - take,
                FALSE, FALSE);
            take = 0;
          }
        }
        if (run == 0)
          frp = frp->fr_next;
        else
          frp = frp->fr_prev;
      }
    }
  }
}

/*
 * Set current window width and take care of repositioning other windows to
 * fit around it.
 */
void win_setwidth(int width)
{
  win_setwidth_win(width, curwin);
}

void win_setwidth_win(int width, win_T *wp)
{
  /* Always keep current window at least one column wide, even when
   * 'winminwidth' is zero. */
  if (wp == curwin) {
    if (width < p_wmw)
      width = p_wmw;
    if (width == 0)
      width = 1;
  }

  frame_setwidth(wp->w_frame, width + wp->w_vsep_width);

  /* recompute the window positions */
  (void)win_comp_pos();

  redraw_all_later(NOT_VALID);
}

/*
 * Set the width of a frame to "width" and take care that all frames and
 * windows inside it are resized.  Also resize frames above and below if the
 * are in the same FR_ROW frame.
 *
 * Strategy is similar to frame_setheight().
 */
static void frame_setwidth(frame_T *curfrp, int width)
{
  int room;                     /* total number of lines available */
  int take;                     /* number of lines taken from other windows */
  int run;
  frame_T     *frp;
  int w;
  int room_reserved;

  /* If the width already is the desired value, nothing to do. */
  if (curfrp->fr_width == width)
    return;

  if (curfrp->fr_parent == NULL)
    /* topframe: can't change width */
    return;

  if (curfrp->fr_parent->fr_layout == FR_COL) {
    /* Column of frames: Also need to resize frames above and below of
     * this one.  First check for the minimal width of these. */
    w = frame_minwidth(curfrp->fr_parent, NULL);
    if (width < w)
      width = w;
    frame_setwidth(curfrp->fr_parent, width);
  } else   {
    /*
     * Row of frames: try to change only frames in this row.
     *
     * Do this twice:
     * 1: compute room available, if it's not enough try resizing the
     *    containing frame.
     * 2: compute the room available and adjust the width to it.
     */
    for (run = 1; run <= 2; ++run) {
      room = 0;
      room_reserved = 0;
      for (frp = curfrp->fr_parent->fr_child; frp != NULL;
           frp = frp->fr_next) {
        if (frp != curfrp
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfw)
          room_reserved += frp->fr_width;
        room += frp->fr_width;
        if (frp != curfrp)
          room -= frame_minwidth(frp, NULL);
      }

      if (width <= room)
        break;
      if (run == 2 || curfrp->fr_height >= ROWS_AVAIL) {
        if (width > room)
          width = room;
        break;
      }
      frame_setwidth(curfrp->fr_parent, width
          + frame_minwidth(curfrp->fr_parent, NOWIN) - (int)p_wmw - 1);
    }

    /*
     * Compute the number of lines we will take from others frames (can be
     * negative!).
     */
    take = width - curfrp->fr_width;

    /* If there is not enough room, also reduce the width of a window
     * with 'winfixwidth' set. */
    if (width > room - room_reserved)
      room_reserved = room - width;
    /* If there is only a 'winfixwidth' window and making the
     * window smaller, need to make the other window narrower. */
    if (take < 0 && room - curfrp->fr_width < room_reserved)
      room_reserved = 0;

    /*
     * set the current frame to the new width
     */
    frame_new_width(curfrp, width, FALSE, FALSE);

    /*
     * First take lines from the frames right of the current frame.  If
     * that is not enough, takes lines from frames left of the current
     * frame.
     */
    for (run = 0; run < 2; ++run) {
      if (run == 0)
        frp = curfrp->fr_next;          /* 1st run: start with next window */
      else
        frp = curfrp->fr_prev;          /* 2nd run: start with prev window */
      while (frp != NULL && take != 0) {
        w = frame_minwidth(frp, NULL);
        if (room_reserved > 0
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfw) {
          if (room_reserved >= frp->fr_width)
            room_reserved -= frp->fr_width;
          else {
            if (frp->fr_width - room_reserved > take)
              room_reserved = frp->fr_width - take;
            take -= frp->fr_width - room_reserved;
            frame_new_width(frp, room_reserved, FALSE, FALSE);
            room_reserved = 0;
          }
        } else   {
          if (frp->fr_width - take < w) {
            take -= frp->fr_width - w;
            frame_new_width(frp, w, FALSE, FALSE);
          } else   {
            frame_new_width(frp, frp->fr_width - take,
                FALSE, FALSE);
            take = 0;
          }
        }
        if (run == 0)
          frp = frp->fr_next;
        else
          frp = frp->fr_prev;
      }
    }
  }
}

/*
 * Check 'winminheight' for a valid value.
 */
void win_setminheight(void)          {
  int room;
  int first = TRUE;
  win_T       *wp;

  /* loop until there is a 'winminheight' that is possible */
  while (p_wmh > 0) {
    /* TODO: handle vertical splits */
    room = -p_wh;
    for (wp = firstwin; wp != NULL; wp = wp->w_next)
      room += wp->w_height - p_wmh;
    if (room >= 0)
      break;
    --p_wmh;
    if (first) {
      EMSG(_(e_noroom));
      first = FALSE;
    }
  }
}

/*
 * Status line of dragwin is dragged "offset" lines down (negative is up).
 */
void win_drag_status_line(win_T *dragwin, int offset)
{
  frame_T     *curfr;
  frame_T     *fr;
  int room;
  int row;
  int up;               /* if TRUE, drag status line up, otherwise down */
  int n;

  fr = dragwin->w_frame;
  curfr = fr;
  if (fr != topframe) {         /* more than one window */
    fr = fr->fr_parent;
    /* When the parent frame is not a column of frames, its parent should
     * be. */
    if (fr->fr_layout != FR_COL) {
      curfr = fr;
      if (fr != topframe)       /* only a row of windows, may drag statusline */
        fr = fr->fr_parent;
    }
  }

  /* If this is the last frame in a column, may want to resize the parent
   * frame instead (go two up to skip a row of frames). */
  while (curfr != topframe && curfr->fr_next == NULL) {
    if (fr != topframe)
      fr = fr->fr_parent;
    curfr = fr;
    if (fr != topframe)
      fr = fr->fr_parent;
  }

  if (offset < 0) { /* drag up */
    up = TRUE;
    offset = -offset;
    /* sum up the room of the current frame and above it */
    if (fr == curfr) {
      /* only one window */
      room = fr->fr_height - frame_minheight(fr, NULL);
    } else   {
      room = 0;
      for (fr = fr->fr_child;; fr = fr->fr_next) {
        room += fr->fr_height - frame_minheight(fr, NULL);
        if (fr == curfr)
          break;
      }
    }
    fr = curfr->fr_next;                /* put fr at frame that grows */
  } else   { /* drag down */
    up = FALSE;
    /*
     * Only dragging the last status line can reduce p_ch.
     */
    room = Rows - cmdline_row;
    if (curfr->fr_next == NULL)
      room -= 1;
    else
      room -= p_ch;
    if (room < 0)
      room = 0;
    /* sum up the room of frames below of the current one */
    for (fr = curfr->fr_next; fr != NULL; fr = fr->fr_next)
      room += fr->fr_height - frame_minheight(fr, NULL);
    fr = curfr;                         /* put fr at window that grows */
  }

  if (room < offset)            /* Not enough room */
    offset = room;              /* Move as far as we can */
  if (offset <= 0)
    return;

  /*
   * Grow frame fr by "offset" lines.
   * Doesn't happen when dragging the last status line up.
   */
  if (fr != NULL)
    frame_new_height(fr, fr->fr_height + offset, up, FALSE);

  if (up)
    fr = curfr;                 /* current frame gets smaller */
  else
    fr = curfr->fr_next;        /* next frame gets smaller */

  /*
   * Now make the other frames smaller.
   */
  while (fr != NULL && offset > 0) {
    n = frame_minheight(fr, NULL);
    if (fr->fr_height - offset <= n) {
      offset -= fr->fr_height - n;
      frame_new_height(fr, n, !up, FALSE);
    } else   {
      frame_new_height(fr, fr->fr_height - offset, !up, FALSE);
      break;
    }
    if (up)
      fr = fr->fr_prev;
    else
      fr = fr->fr_next;
  }
  row = win_comp_pos();
  screen_fill(row, cmdline_row, 0, (int)Columns, ' ', ' ', 0);
  cmdline_row = row;
  p_ch = Rows - cmdline_row;
  if (p_ch < 1)
    p_ch = 1;
  curtab->tp_ch_used = p_ch;
  redraw_all_later(SOME_VALID);
  showmode();
}

/*
 * Separator line of dragwin is dragged "offset" lines right (negative is left).
 */
void win_drag_vsep_line(win_T *dragwin, int offset)
{
  frame_T     *curfr;
  frame_T     *fr;
  int room;
  int left;             /* if TRUE, drag separator line left, otherwise right */
  int n;

  fr = dragwin->w_frame;
  if (fr == topframe)           /* only one window (cannot happen?) */
    return;
  curfr = fr;
  fr = fr->fr_parent;
  /* When the parent frame is not a row of frames, its parent should be. */
  if (fr->fr_layout != FR_ROW) {
    if (fr == topframe)         /* only a column of windows (cannot happen?) */
      return;
    curfr = fr;
    fr = fr->fr_parent;
  }

  /* If this is the last frame in a row, may want to resize a parent
   * frame instead. */
  while (curfr->fr_next == NULL) {
    if (fr == topframe)
      break;
    curfr = fr;
    fr = fr->fr_parent;
    if (fr != topframe) {
      curfr = fr;
      fr = fr->fr_parent;
    }
  }

  if (offset < 0) { /* drag left */
    left = TRUE;
    offset = -offset;
    /* sum up the room of the current frame and left of it */
    room = 0;
    for (fr = fr->fr_child;; fr = fr->fr_next) {
      room += fr->fr_width - frame_minwidth(fr, NULL);
      if (fr == curfr)
        break;
    }
    fr = curfr->fr_next;                /* put fr at frame that grows */
  } else   { /* drag right */
    left = FALSE;
    /* sum up the room of frames right of the current one */
    room = 0;
    for (fr = curfr->fr_next; fr != NULL; fr = fr->fr_next)
      room += fr->fr_width - frame_minwidth(fr, NULL);
    fr = curfr;                         /* put fr at window that grows */
  }

  if (room < offset)            /* Not enough room */
    offset = room;              /* Move as far as we can */
  if (offset <= 0)              /* No room at all, quit. */
    return;

  /* grow frame fr by offset lines */
  frame_new_width(fr, fr->fr_width + offset, left, FALSE);

  /* shrink other frames: current and at the left or at the right */
  if (left)
    fr = curfr;                 /* current frame gets smaller */
  else
    fr = curfr->fr_next;        /* next frame gets smaller */

  while (fr != NULL && offset > 0) {
    n = frame_minwidth(fr, NULL);
    if (fr->fr_width - offset <= n) {
      offset -= fr->fr_width - n;
      frame_new_width(fr, n, !left, FALSE);
    } else   {
      frame_new_width(fr, fr->fr_width - offset, !left, FALSE);
      break;
    }
    if (left)
      fr = fr->fr_prev;
    else
      fr = fr->fr_next;
  }
  (void)win_comp_pos();
  redraw_all_later(NOT_VALID);
}


#define FRACTION_MULT   16384L

/*
 * Set wp->w_fraction for the current w_wrow and w_height.
 */
static void set_fraction(win_T *wp)
{
  wp->w_fraction = ((long)wp->w_wrow * FRACTION_MULT
                    + FRACTION_MULT / 2) / (long)wp->w_height;
}

/*
 * Set the height of a window.
 * This takes care of the things inside the window, not what happens to the
 * window position, the frame or to other windows.
 */
void win_new_height(win_T *wp, int height)
{
  linenr_T lnum;
  int sline, line_size;

  /* Don't want a negative height.  Happens when splitting a tiny window.
   * Will equalize heights soon to fix it. */
  if (height < 0)
    height = 0;
  if (wp->w_height == height)
    return;         /* nothing to do */

  if (wp->w_wrow != wp->w_prev_fraction_row && wp->w_height > 0)
    set_fraction(wp);

  wp->w_height = height;
  wp->w_skipcol = 0;

  /* Don't change w_topline when height is zero.  Don't set w_topline when
   * 'scrollbind' is set and this isn't the current window. */
  if (height > 0
      && (!wp->w_p_scb || wp == curwin)
      ) {
    /*
     * Find a value for w_topline that shows the cursor at the same
     * relative position in the window as before (more or less).
     */
    lnum = wp->w_cursor.lnum;
    if (lnum < 1)               /* can happen when starting up */
      lnum = 1;
    wp->w_wrow = ((long)wp->w_fraction * (long)height - 1L) / FRACTION_MULT;
    line_size = plines_win_col(wp, lnum, (long)(wp->w_cursor.col)) - 1;
    sline = wp->w_wrow - line_size;

    if (sline >= 0) {
      /* Make sure the whole cursor line is visible, if possible. */
      int rows = plines_win(wp, lnum, FALSE);

      if (sline > wp->w_height - rows) {
        sline = wp->w_height - rows;
        wp->w_wrow -= rows - line_size;
      }
    }

    if (sline < 0) {
      /*
       * Cursor line would go off top of screen if w_wrow was this high.
       * Make cursor line the first line in the window.  If not enough
       * room use w_skipcol;
       */
      wp->w_wrow = line_size;
      if (wp->w_wrow >= wp->w_height
          && (W_WIDTH(wp) - win_col_off(wp)) > 0) {
        wp->w_skipcol += W_WIDTH(wp) - win_col_off(wp);
        --wp->w_wrow;
        while (wp->w_wrow >= wp->w_height) {
          wp->w_skipcol += W_WIDTH(wp) - win_col_off(wp)
                           + win_col_off2(wp);
          --wp->w_wrow;
        }
      }
    } else   {
      while (sline > 0 && lnum > 1) {
        hasFoldingWin(wp, lnum, &lnum, NULL, TRUE, NULL);
        if (lnum == 1) {
          /* first line in buffer is folded */
          line_size = 1;
          --sline;
          break;
        }
        --lnum;
        if (lnum == wp->w_topline)
          line_size = plines_win_nofill(wp, lnum, TRUE)
                      + wp->w_topfill;
        else
          line_size = plines_win(wp, lnum, TRUE);
        sline -= line_size;
      }

      if (sline < 0) {
        /*
         * Line we want at top would go off top of screen.  Use next
         * line instead.
         */
        hasFoldingWin(wp, lnum, NULL, &lnum, TRUE, NULL);
        lnum++;
        wp->w_wrow -= line_size + sline;
      } else if (sline > 0)   {
        /* First line of file reached, use that as topline. */
        lnum = 1;
        wp->w_wrow -= sline;
      }
    }
    set_topline(wp, lnum);
  }

  if (wp == curwin) {
    if (p_so)
      update_topline();
    curs_columns(FALSE);        /* validate w_wrow */
  }
  wp->w_prev_fraction_row = wp->w_wrow;

  win_comp_scroll(wp);
  redraw_win_later(wp, SOME_VALID);
  wp->w_redr_status = TRUE;
  invalidate_botline_win(wp);
}

/*
 * Set the width of a window.
 */
void win_new_width(win_T *wp, int width)
{
  wp->w_width = width;
  wp->w_lines_valid = 0;
  changed_line_abv_curs_win(wp);
  invalidate_botline_win(wp);
  if (wp == curwin) {
    update_topline();
    curs_columns(TRUE);         /* validate w_wrow */
  }
  redraw_win_later(wp, NOT_VALID);
  wp->w_redr_status = TRUE;
}

void win_comp_scroll(win_T *wp)
{
  wp->w_p_scr = ((unsigned)wp->w_height >> 1);
  if (wp->w_p_scr == 0)
    wp->w_p_scr = 1;
}

/*
 * command_height: called whenever p_ch has been changed
 */
void command_height(void)          {
  int h;
  frame_T     *frp;
  int old_p_ch = curtab->tp_ch_used;

  /* Use the value of p_ch that we remembered.  This is needed for when the
   * GUI starts up, we can't be sure in what order things happen.  And when
   * p_ch was changed in another tab page. */
  curtab->tp_ch_used = p_ch;

  /* Find bottom frame with width of screen. */
  frp = lastwin->w_frame;
  while (frp->fr_width != Columns && frp->fr_parent != NULL)
    frp = frp->fr_parent;

  /* Avoid changing the height of a window with 'winfixheight' set. */
  while (frp->fr_prev != NULL && frp->fr_layout == FR_LEAF
         && frp->fr_win->w_p_wfh)
    frp = frp->fr_prev;

  if (starting != NO_SCREEN) {
    cmdline_row = Rows - p_ch;

    if (p_ch > old_p_ch) {                  /* p_ch got bigger */
      while (p_ch > old_p_ch) {
        if (frp == NULL) {
          EMSG(_(e_noroom));
          p_ch = old_p_ch;
          curtab->tp_ch_used = p_ch;
          cmdline_row = Rows - p_ch;
          break;
        }
        h = frp->fr_height - frame_minheight(frp, NULL);
        if (h > p_ch - old_p_ch)
          h = p_ch - old_p_ch;
        old_p_ch += h;
        frame_add_height(frp, -h);
        frp = frp->fr_prev;
      }

      /* Recompute window positions. */
      (void)win_comp_pos();

      /* clear the lines added to cmdline */
      if (full_screen)
        screen_fill((int)(cmdline_row), (int)Rows, 0,
            (int)Columns, ' ', ' ', 0);
      msg_row = cmdline_row;
      redraw_cmdline = TRUE;
      return;
    }

    if (msg_row < cmdline_row)
      msg_row = cmdline_row;
    redraw_cmdline = TRUE;
  }
  frame_add_height(frp, (int)(old_p_ch - p_ch));

  /* Recompute window positions. */
  if (frp != lastwin->w_frame)
    (void)win_comp_pos();
}

/*
 * Resize frame "frp" to be "n" lines higher (negative for less high).
 * Also resize the frames it is contained in.
 */
static void frame_add_height(frame_T *frp, int n)
{
  frame_new_height(frp, frp->fr_height + n, FALSE, FALSE);
  for (;; ) {
    frp = frp->fr_parent;
    if (frp == NULL)
      break;
    frp->fr_height += n;
  }
}

/*
 * Add or remove a status line for the bottom window(s), according to the
 * value of 'laststatus'.
 */
void 
last_status (
    int morewin                    /* pretend there are two or more windows */
)
{
  /* Don't make a difference between horizontal or vertical split. */
  last_status_rec(topframe, (p_ls == 2
                             || (p_ls == 1 && (morewin || lastwin != firstwin))));
}

static void last_status_rec(frame_T *fr, int statusline)
{
  frame_T     *fp;
  win_T       *wp;

  if (fr->fr_layout == FR_LEAF) {
    wp = fr->fr_win;
    if (wp->w_status_height != 0 && !statusline) {
      /* remove status line */
      win_new_height(wp, wp->w_height + 1);
      wp->w_status_height = 0;
      comp_col();
    } else if (wp->w_status_height == 0 && statusline)   {
      /* Find a frame to take a line from. */
      fp = fr;
      while (fp->fr_height <= frame_minheight(fp, NULL)) {
        if (fp == topframe) {
          EMSG(_(e_noroom));
          return;
        }
        /* In a column of frames: go to frame above.  If already at
         * the top or in a row of frames: go to parent. */
        if (fp->fr_parent->fr_layout == FR_COL && fp->fr_prev != NULL)
          fp = fp->fr_prev;
        else
          fp = fp->fr_parent;
      }
      wp->w_status_height = 1;
      if (fp != fr) {
        frame_new_height(fp, fp->fr_height - 1, FALSE, FALSE);
        frame_fix_height(wp);
        (void)win_comp_pos();
      } else
        win_new_height(wp, wp->w_height - 1);
      comp_col();
      redraw_all_later(SOME_VALID);
    }
  } else if (fr->fr_layout == FR_ROW)   {
    /* vertically split windows, set status line for each one */
    for (fp = fr->fr_child; fp != NULL; fp = fp->fr_next)
      last_status_rec(fp, statusline);
  } else   {
    /* horizontally split window, set status line for last one */
    for (fp = fr->fr_child; fp->fr_next != NULL; fp = fp->fr_next)
      ;
    last_status_rec(fp, statusline);
  }
}

/*
 * Return the number of lines used by the tab page line.
 */
int tabline_height(void)         {
  switch (p_stal) {
  case 0: return 0;
  case 1: return (first_tabpage->tp_next == NULL) ? 0 : 1;
  }
  return 1;
}

/*
 * Get the file name at the cursor.
 * If Visual mode is active, use the selected text if it's in one line.
 * Returns the name in allocated memory, NULL for failure.
 */
char_u *grab_file_name(long count, linenr_T *file_lnum)
{
  if (VIsual_active) {
    int len;
    char_u  *ptr;

    if (get_visual_text(NULL, &ptr, &len) == FAIL)
      return NULL;
    return find_file_name_in_path(ptr, len,
        FNAME_MESS|FNAME_EXP|FNAME_REL, count, curbuf->b_ffname);
  }
  return file_name_at_cursor(FNAME_MESS|FNAME_HYP|FNAME_EXP|FNAME_REL, count,
      file_lnum);

}

/*
 * Return the file name under or after the cursor.
 *
 * The 'path' option is searched if the file name is not absolute.
 * The string returned has been alloc'ed and should be freed by the caller.
 * NULL is returned if the file name or file is not found.
 *
 * options:
 * FNAME_MESS	    give error messages
 * FNAME_EXP	    expand to path
 * FNAME_HYP	    check for hypertext link
 * FNAME_INCL	    apply "includeexpr"
 */
char_u *file_name_at_cursor(int options, long count, linenr_T *file_lnum)
{
  return file_name_in_line(ml_get_curline(),
      curwin->w_cursor.col, options, count, curbuf->b_ffname,
      file_lnum);
}

/*
 * Return the name of the file under or after ptr[col].
 * Otherwise like file_name_at_cursor().
 */
char_u *
file_name_in_line (
    char_u *line,
    int col,
    int options,
    long count,
    char_u *rel_fname,         /* file we are searching relative to */
    linenr_T *file_lnum         /* line number after the file name */
)
{
  char_u      *ptr;
  int len;

  /*
   * search forward for what could be the start of a file name
   */
  ptr = line + col;
  while (*ptr != NUL && !vim_isfilec(*ptr))
    mb_ptr_adv(ptr);
  if (*ptr == NUL) {            /* nothing found */
    if (options & FNAME_MESS)
      EMSG(_("E446: No file name under cursor"));
    return NULL;
  }

  /*
   * Search backward for first char of the file name.
   * Go one char back to ":" before "//" even when ':' is not in 'isfname'.
   */
  while (ptr > line) {
    if (has_mbyte && (len = (*mb_head_off)(line, ptr - 1)) > 0)
      ptr -= len + 1;
    else if (vim_isfilec(ptr[-1])
             || ((options & FNAME_HYP) && path_is_url(ptr - 1)))
      --ptr;
    else
      break;
  }

  /*
   * Search forward for the last char of the file name.
   * Also allow "://" when ':' is not in 'isfname'.
   */
  len = 0;
  while (vim_isfilec(ptr[len])
         || ((options & FNAME_HYP) && path_is_url(ptr + len)))
    if (has_mbyte)
      len += (*mb_ptr2len)(ptr + len);
    else
      ++len;

  /*
   * If there is trailing punctuation, remove it.
   * But don't remove "..", could be a directory name.
   */
  if (len > 2 && vim_strchr((char_u *)".,:;!", ptr[len - 1]) != NULL
      && ptr[len - 2] != '.')
    --len;

  if (file_lnum != NULL) {
    char_u *p;

    /* Get the number after the file name and a separator character */
    p = ptr + len;
    p = skipwhite(p);
    if (*p != NUL) {
      if (!isdigit(*p))
        ++p;                        /* skip the separator */
      p = skipwhite(p);
      if (isdigit(*p))
        *file_lnum = (int)getdigits(&p);
    }
  }

  return find_file_name_in_path(ptr, len, options, count, rel_fname);
}

static char_u *eval_includeexpr(char_u *ptr, int len);

static char_u *eval_includeexpr(char_u *ptr, int len)
{
  char_u      *res;

  set_vim_var_string(VV_FNAME, ptr, len);
  res = eval_to_string_safe(curbuf->b_p_inex, NULL,
      was_set_insecurely((char_u *)"includeexpr", OPT_LOCAL));
  set_vim_var_string(VV_FNAME, NULL, 0);
  return res;
}

/*
 * Return the name of the file ptr[len] in 'path'.
 * Otherwise like file_name_at_cursor().
 */
char_u *
find_file_name_in_path (
    char_u *ptr,
    int len,
    int options,
    long count,
    char_u *rel_fname         /* file we are searching relative to */
)
{
  char_u      *file_name;
  int c;
  char_u      *tofree = NULL;

  if ((options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
    tofree = eval_includeexpr(ptr, len);
    if (tofree != NULL) {
      ptr = tofree;
      len = (int)STRLEN(ptr);
    }
  }

  if (options & FNAME_EXP) {
    file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS,
        TRUE, rel_fname);

    /*
     * If the file could not be found in a normal way, try applying
     * 'includeexpr' (unless done already).
     */
    if (file_name == NULL
        && !(options & FNAME_INCL) && *curbuf->b_p_inex != NUL) {
      tofree = eval_includeexpr(ptr, len);
      if (tofree != NULL) {
        ptr = tofree;
        len = (int)STRLEN(ptr);
        file_name = find_file_in_path(ptr, len, options & ~FNAME_MESS,
            TRUE, rel_fname);
      }
    }
    if (file_name == NULL && (options & FNAME_MESS)) {
      c = ptr[len];
      ptr[len] = NUL;
      EMSG2(_("E447: Can't find file \"%s\" in path"), ptr);
      ptr[len] = c;
    }

    /* Repeat finding the file "count" times.  This matters when it
     * appears several times in the path. */
    while (file_name != NULL && --count > 0) {
      vim_free(file_name);
      file_name = find_file_in_path(ptr, len, options, FALSE, rel_fname);
    }
  } else
    file_name = vim_strnsave(ptr, len);

  vim_free(tofree);

  return file_name;
}

/*
 * Check if the "://" of a URL is at the pointer, return URL_SLASH.
 * Also check for ":\\", which MS Internet Explorer accepts, return
 * URL_BACKSLASH.
 */
static int path_is_url(char_u *p)
{
  if (STRNCMP(p, "://", (size_t)3) == 0)
    return URL_SLASH;
  else if (STRNCMP(p, ":\\\\", (size_t)3) == 0)
    return URL_BACKSLASH;
  return 0;
}

/*
 * Check if "fname" starts with "name://".  Return URL_SLASH if it does.
 * Return URL_BACKSLASH for "name:\\".
 * Return zero otherwise.
 */
int path_with_url(char_u *fname)
{
  char_u *p;

  for (p = fname; isalpha(*p); ++p)
    ;
  return path_is_url(p);
}

/*
 * Return TRUE if "name" is a full (absolute) path name or URL.
 */
int vim_isAbsName(char_u *name)
{
  return path_with_url(name) != 0 || mch_is_full_name(name);
}

/*
 * Get absolute file name into buffer "buf[len]".
 *
 * return FAIL for failure, OK otherwise
 */
int 
vim_FullName (
    char_u *fname,
    char_u *buf,
    int len,
    int force                  /* force expansion even when already absolute */
)
{
  int retval = OK;
  int url;

  *buf = NUL;
  if (fname == NULL)
    return FAIL;

  url = path_with_url(fname);
  if (!url)
    retval = mch_full_name(fname, buf, len, force);
  if (url || retval == FAIL) {
    /* something failed; use the file name (truncate when too long) */
    vim_strncpy(buf, fname, len - 1);
  }
  return retval;
}

/*
 * Return the minimal number of rows that is needed on the screen to display
 * the current number of windows.
 */
int min_rows(void)         {
  int total;
  tabpage_T   *tp;
  int n;

  if (firstwin == NULL)         /* not initialized yet */
    return MIN_LINES;

  total = 0;
  for (tp = first_tabpage; tp != NULL; tp = tp->tp_next) {
    n = frame_minheight(tp->tp_topframe, NULL);
    if (total < n)
      total = n;
  }
  total += tabline_height();
  total += 1;           /* count the room for the command line */
  return total;
}

/*
 * Return TRUE if there is only one window (in the current tab page), not
 * counting a help or preview window, unless it is the current window.
 * Does not count "aucmd_win".
 */
int only_one_window(void)         {
  int count = 0;
  win_T       *wp;

  /* If there is another tab page there always is another window. */
  if (first_tabpage->tp_next != NULL)
    return FALSE;

  for (wp = firstwin; wp != NULL; wp = wp->w_next)
    if (wp->w_buffer != NULL
        && (!((wp->w_buffer->b_help && !curbuf->b_help)
              || wp->w_p_pvw
              ) || wp == curwin)
        && wp != aucmd_win
        )
      ++count;
  return count <= 1;
}

/*
 * Correct the cursor line number in other windows.  Used after changing the
 * current buffer, and before applying autocommands.
 * When "do_curwin" is TRUE, also check current window.
 */
void check_lnums(int do_curwin)
{
  win_T       *wp;

  tabpage_T   *tp;

  FOR_ALL_TAB_WINDOWS(tp, wp)
  if ((do_curwin || wp != curwin) && wp->w_buffer == curbuf) {
    if (wp->w_cursor.lnum > curbuf->b_ml.ml_line_count)
      wp->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    if (wp->w_topline > curbuf->b_ml.ml_line_count)
      wp->w_topline = curbuf->b_ml.ml_line_count;
  }
}


/*
 * A snapshot of the window sizes, to restore them after closing the help
 * window.
 * Only these fields are used:
 * fr_layout
 * fr_width
 * fr_height
 * fr_next
 * fr_child
 * fr_win (only valid for the old curwin, NULL otherwise)
 */

/*
 * Create a snapshot of the current frame sizes.
 */
void make_snapshot(int idx)
{
  clear_snapshot(curtab, idx);
  make_snapshot_rec(topframe, &curtab->tp_snapshot[idx]);
}

static void make_snapshot_rec(frame_T *fr, frame_T **frp)
{
  *frp = (frame_T *)alloc_clear((unsigned)sizeof(frame_T));
  if (*frp == NULL)
    return;
  (*frp)->fr_layout = fr->fr_layout;
  (*frp)->fr_width = fr->fr_width;
  (*frp)->fr_height = fr->fr_height;
  if (fr->fr_next != NULL)
    make_snapshot_rec(fr->fr_next, &((*frp)->fr_next));
  if (fr->fr_child != NULL)
    make_snapshot_rec(fr->fr_child, &((*frp)->fr_child));
  if (fr->fr_layout == FR_LEAF && fr->fr_win == curwin)
    (*frp)->fr_win = curwin;
}

/*
 * Remove any existing snapshot.
 */
static void clear_snapshot(tabpage_T *tp, int idx)
{
  clear_snapshot_rec(tp->tp_snapshot[idx]);
  tp->tp_snapshot[idx] = NULL;
}

static void clear_snapshot_rec(frame_T *fr)
{
  if (fr != NULL) {
    clear_snapshot_rec(fr->fr_next);
    clear_snapshot_rec(fr->fr_child);
    vim_free(fr);
  }
}

/*
 * Restore a previously created snapshot, if there is any.
 * This is only done if the screen size didn't change and the window layout is
 * still the same.
 */
void 
restore_snapshot (
    int idx,
    int close_curwin                   /* closing current window */
)
{
  win_T       *wp;

  if (curtab->tp_snapshot[idx] != NULL
      && curtab->tp_snapshot[idx]->fr_width == topframe->fr_width
      && curtab->tp_snapshot[idx]->fr_height == topframe->fr_height
      && check_snapshot_rec(curtab->tp_snapshot[idx], topframe) == OK) {
    wp = restore_snapshot_rec(curtab->tp_snapshot[idx], topframe);
    win_comp_pos();
    if (wp != NULL && close_curwin)
      win_goto(wp);
    redraw_all_later(CLEAR);
  }
  clear_snapshot(curtab, idx);
}

/*
 * Check if frames "sn" and "fr" have the same layout, same following frames
 * and same children.
 */
static int check_snapshot_rec(frame_T *sn, frame_T *fr)
{
  if (sn->fr_layout != fr->fr_layout
      || (sn->fr_next == NULL) != (fr->fr_next == NULL)
      || (sn->fr_child == NULL) != (fr->fr_child == NULL)
      || (sn->fr_next != NULL
          && check_snapshot_rec(sn->fr_next, fr->fr_next) == FAIL)
      || (sn->fr_child != NULL
          && check_snapshot_rec(sn->fr_child, fr->fr_child) == FAIL))
    return FAIL;
  return OK;
}

/*
 * Copy the size of snapshot frame "sn" to frame "fr".  Do the same for all
 * following frames and children.
 * Returns a pointer to the old current window, or NULL.
 */
static win_T *restore_snapshot_rec(frame_T *sn, frame_T *fr)
{
  win_T       *wp = NULL;
  win_T       *wp2;

  fr->fr_height = sn->fr_height;
  fr->fr_width = sn->fr_width;
  if (fr->fr_layout == FR_LEAF) {
    frame_new_height(fr, fr->fr_height, FALSE, FALSE);
    frame_new_width(fr, fr->fr_width, FALSE, FALSE);
    wp = sn->fr_win;
  }
  if (sn->fr_next != NULL) {
    wp2 = restore_snapshot_rec(sn->fr_next, fr->fr_next);
    if (wp2 != NULL)
      wp = wp2;
  }
  if (sn->fr_child != NULL) {
    wp2 = restore_snapshot_rec(sn->fr_child, fr->fr_child);
    if (wp2 != NULL)
      wp = wp2;
  }
  return wp;
}


#if defined(FEAT_EVAL) || defined(FEAT_PYTHON) || defined(FEAT_PYTHON3) \
  || defined(PROTO)
/*
 * Set "win" to be the curwin and "tp" to be the current tab page.
 * restore_win() MUST be called to undo.
 * No autocommands will be executed.
 * When "no_display" is TRUE the display won't be affected, no redraw is
 * triggered, another tabpage access is limited.
 * Returns FAIL if switching to "win" failed.
 */
int switch_win(win_T **save_curwin, tabpage_T **save_curtab, win_T *win, tabpage_T *tp, int no_display)
{
  block_autocmds();
  *save_curwin = curwin;
  if (tp != NULL) {
    *save_curtab = curtab;
    if (no_display) {
      curtab->tp_firstwin = firstwin;
      curtab->tp_lastwin = lastwin;
      curtab = tp;
      firstwin = curtab->tp_firstwin;
      lastwin = curtab->tp_lastwin;
    } else
      goto_tabpage_tp(tp, FALSE, FALSE);
  }
  if (!win_valid(win)) {
    unblock_autocmds();
    return FAIL;
  }
  curwin = win;
  curbuf = curwin->w_buffer;
  return OK;
}

/*
 * Restore current tabpage and window saved by switch_win(), if still valid.
 * When "no_display" is TRUE the display won't be affected, no redraw is
 * triggered.
 */
void restore_win(win_T *save_curwin, tabpage_T *save_curtab, int no_display)
{
  if (save_curtab != NULL && valid_tabpage(save_curtab)) {
    if (no_display) {
      curtab->tp_firstwin = firstwin;
      curtab->tp_lastwin = lastwin;
      curtab = save_curtab;
      firstwin = curtab->tp_firstwin;
      lastwin = curtab->tp_lastwin;
    } else
      goto_tabpage_tp(save_curtab, FALSE, FALSE);
  }
  if (win_valid(save_curwin)) {
    curwin = save_curwin;
    curbuf = curwin->w_buffer;
  }
  unblock_autocmds();
}

/*
 * Make "buf" the current buffer.  restore_buffer() MUST be called to undo.
 * No autocommands will be executed.  Use aucmd_prepbuf() if there are any.
 */
void switch_buffer(buf_T **save_curbuf, buf_T *buf)
{
  block_autocmds();
  *save_curbuf = curbuf;
  --curbuf->b_nwindows;
  curbuf = buf;
  curwin->w_buffer = buf;
  ++curbuf->b_nwindows;
}

/*
 * Restore the current buffer after using switch_buffer().
 */
void restore_buffer(buf_T *save_curbuf)
{
  unblock_autocmds();
  /* Check for valid buffer, just in case. */
  if (buf_valid(save_curbuf)) {
    --curbuf->b_nwindows;
    curwin->w_buffer = save_curbuf;
    curbuf = save_curbuf;
    ++curbuf->b_nwindows;
  }
}
#endif


/*
 * Add match to the match list of window 'wp'.  The pattern 'pat' will be
 * highlighted with the group 'grp' with priority 'prio'.
 * Optionally, a desired ID 'id' can be specified (greater than or equal to 1).
 * If no particular ID is desired, -1 must be specified for 'id'.
 * Return ID of added match, -1 on failure.
 */
int match_add(win_T *wp, char_u *grp, char_u *pat, int prio, int id)
{
  matchitem_T *cur;
  matchitem_T *prev;
  matchitem_T *m;
  int hlg_id;
  regprog_T   *regprog;

  if (*grp == NUL || *pat == NUL)
    return -1;
  if (id < -1 || id == 0) {
    EMSGN("E799: Invalid ID: %ld (must be greater than or equal to 1)", id);
    return -1;
  }
  if (id != -1) {
    cur = wp->w_match_head;
    while (cur != NULL) {
      if (cur->id == id) {
        EMSGN("E801: ID already taken: %ld", id);
        return -1;
      }
      cur = cur->next;
    }
  }
  if ((hlg_id = syn_namen2id(grp, (int)STRLEN(grp))) == 0) {
    EMSG2(_(e_nogroup), grp);
    return -1;
  }
  if ((regprog = vim_regcomp(pat, RE_MAGIC)) == NULL) {
    EMSG2(_(e_invarg2), pat);
    return -1;
  }

  /* Find available match ID. */
  while (id == -1) {
    cur = wp->w_match_head;
    while (cur != NULL && cur->id != wp->w_next_match_id)
      cur = cur->next;
    if (cur == NULL)
      id = wp->w_next_match_id;
    wp->w_next_match_id++;
  }

  /* Build new match. */
  m = (matchitem_T *)alloc(sizeof(matchitem_T));
  m->id = id;
  m->priority = prio;
  m->pattern = vim_strsave(pat);
  m->hlg_id = hlg_id;
  m->match.regprog = regprog;
  m->match.rmm_ic = FALSE;
  m->match.rmm_maxcol = 0;

  /* Insert new match.  The match list is in ascending order with regard to
   * the match priorities. */
  cur = wp->w_match_head;
  prev = cur;
  while (cur != NULL && prio >= cur->priority) {
    prev = cur;
    cur = cur->next;
  }
  if (cur == prev)
    wp->w_match_head = m;
  else
    prev->next = m;
  m->next = cur;

  redraw_later(SOME_VALID);
  return id;
}

/*
 * Delete match with ID 'id' in the match list of window 'wp'.
 * Print error messages if 'perr' is TRUE.
 */
int match_delete(win_T *wp, int id, int perr)
{
  matchitem_T *cur = wp->w_match_head;
  matchitem_T *prev = cur;

  if (id < 1) {
    if (perr == TRUE)
      EMSGN("E802: Invalid ID: %ld (must be greater than or equal to 1)",
          id);
    return -1;
  }
  while (cur != NULL && cur->id != id) {
    prev = cur;
    cur = cur->next;
  }
  if (cur == NULL) {
    if (perr == TRUE)
      EMSGN("E803: ID not found: %ld", id);
    return -1;
  }
  if (cur == prev)
    wp->w_match_head = cur->next;
  else
    prev->next = cur->next;
  vim_regfree(cur->match.regprog);
  vim_free(cur->pattern);
  vim_free(cur);
  redraw_later(SOME_VALID);
  return 0;
}

/*
 * Delete all matches in the match list of window 'wp'.
 */
void clear_matches(win_T *wp)
{
  matchitem_T *m;

  while (wp->w_match_head != NULL) {
    m = wp->w_match_head->next;
    vim_regfree(wp->w_match_head->match.regprog);
    vim_free(wp->w_match_head->pattern);
    vim_free(wp->w_match_head);
    wp->w_match_head = m;
  }
  redraw_later(SOME_VALID);
}

/*
 * Get match from ID 'id' in window 'wp'.
 * Return NULL if match not found.
 */
matchitem_T *get_match(win_T *wp, int id)
{
  matchitem_T *cur = wp->w_match_head;

  while (cur != NULL && cur->id != id)
    cur = cur->next;
  return cur;
}


/*
 * Return TRUE if "topfrp" and its children are at the right height.
 */
static int frame_check_height(frame_T *topfrp, int height)
{
  frame_T *frp;

  if (topfrp->fr_height != height)
    return FALSE;

  if (topfrp->fr_layout == FR_ROW)
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next)
      if (frp->fr_height != height)
        return FALSE;

  return TRUE;
}

/*
 * Return TRUE if "topfrp" and its children are at the right width.
 */
static int frame_check_width(frame_T *topfrp, int width)
{
  frame_T *frp;

  if (topfrp->fr_width != width)
    return FALSE;

  if (topfrp->fr_layout == FR_COL)
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next)
      if (frp->fr_width != width)
        return FALSE;

  return TRUE;
}

