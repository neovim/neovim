// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>

#include "nvim/api/private/handle.h"
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/window.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/diff.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/farsi.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/hashtab.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/file_search.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/mouse.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/undo.h"
#include "nvim/ui.h"
#include "nvim/os/os.h"


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "window.c.generated.h"
#endif




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
  size_t len;
  char cbuf[40];

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
    (void)win_split((int)Prenum, 0);
    break;

  /* split current window in two parts, vertically */
  case Ctrl_V:
  case 'v':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    /* When splitting the quickfix window open a new buffer in it,
     * don't replicate the quickfix buffer. */
    if (bt_quickfix(curbuf))
      goto newwindow;
    (void)win_split((int)Prenum, WSP_VERT);
    break;

  /* split current window and edit alternate file */
  case Ctrl_HAT:
  case '^':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    cmd_with_count("split #", (char_u *)cbuf, sizeof(cbuf), Prenum);
    do_cmdline_cmd(cbuf);
    break;

  /* open new window */
  case Ctrl_N:
  case 'n':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
newwindow:
    if (Prenum)
      /* window height */
      vim_snprintf(cbuf, sizeof(cbuf) - 5, "%" PRId64, (int64_t)Prenum);
    else
      cbuf[0] = NUL;
    if (nchar == 'v' || nchar == Ctrl_V) {
      xstrlcat(cbuf, "v", sizeof(cbuf));
    }
    xstrlcat(cbuf, "new", sizeof(cbuf));
    do_cmdline_cmd(cbuf);
    break;

  /* quit current window */
  case Ctrl_Q:
  case 'q':
    reset_VIsual_and_resel();                   /* stop Visual mode */
    cmd_with_count("quit", (char_u *)cbuf, sizeof(cbuf), Prenum);
    do_cmdline_cmd(cbuf);
    break;

  /* close current window */
  case Ctrl_C:
  case 'c':
    reset_VIsual_and_resel();                   /* stop Visual mode */
    cmd_with_count("close", (char_u *)cbuf, sizeof(cbuf), Prenum);
    do_cmdline_cmd(cbuf);
    break;

  /* close preview window */
  case Ctrl_Z:
  case 'z':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    do_cmdline_cmd("pclose");
    break;

  /* cursor to preview window */
  case 'P':
    wp = NULL;
    FOR_ALL_WINDOWS_IN_TAB(wp2, curtab) {
      if (wp2->w_p_pvw) {
        wp = wp2;
        break;
      }
    }
    if (wp == NULL) {
      EMSG(_("E441: There is no preview window"));
    } else {
      win_goto(wp);
    }
    break;

  /* close all but current window */
  case Ctrl_O:
  case 'o':
    CHECK_CMDWIN reset_VIsual_and_resel();      /* stop Visual mode */
    cmd_with_count("only", (char_u *)cbuf, sizeof(cbuf), Prenum);
    do_cmdline_cmd(cbuf);
    break;

  /* cursor to next window with wrap around */
  case Ctrl_W:
  case 'w':
  /* cursor to previous window with wrap around */
  case 'W':
    CHECK_CMDWIN
    if (ONE_WINDOW && Prenum != 1)             /* just one window */
      beep_flush();
    else {
      if (Prenum) {                             /* go to specified window */
        for (wp = firstwin; --Prenum > 0; ) {
          if (wp->w_next == NULL)
            break;
          else
            wp = wp->w_next;
        }
      } else {
        if (nchar == 'W') {                         /* go to previous window */
          wp = curwin->w_prev;
          if (wp == NULL)
            wp = lastwin;                           /* wrap around */
        } else {                                  /* go to next window */
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
      if (win_new_tabpage((int)Prenum, NULL) == OK
          && valid_tabpage(oldtab)) {
        newtab = curtab;
        goto_tabpage_tp(oldtab, true, true);
        if (curwin == wp) {
          win_close(curwin, false);
        }
        if (valid_tabpage(newtab)) {
          goto_tabpage_tp(newtab, true, true);
          apply_autocmds(EVENT_TABNEWENTERED, NULL, NULL, false, curbuf);
        }
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
    if (!win_valid(prevwin)) {
      beep_flush();
    } else {
      win_goto(prevwin);
    }
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
    win_equal(NULL, false, 'b');
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
    FALLTHROUGH;
  case ']':
  case Ctrl_RSB:
    CHECK_CMDWIN
    // Keep visual mode, can select words to use as a tag.
    if (Prenum)
      postponed_split = Prenum;
    else
      postponed_split = -1;

    if (nchar != '}') {
      g_do_tagpreview = 0;
    }

    // Execute the command right here, required when
    // "wincmd ]" was used in a function.
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
      tabpage_T *oldtab = curtab;
      win_T *oldwin = curwin;
      setpcmark();
      if (win_split(0, 0) == OK) {
        RESET_BINDING(curwin);
        if (do_ecmd(0, ptr, NULL, NULL, ECMD_LASTL, ECMD_HIDE, NULL) == FAIL) {
          // Failed to open the file, close the window opened for it.
          win_close(curwin, false);
          goto_tabpage_win(oldtab, oldwin);
        } else if (nchar == 'F' && lnum >= 0) {
          curwin->w_cursor.lnum = lnum;
          check_cursor_lnum();
          beginline(BL_SOL | BL_FIX);
        }
      }
      xfree(ptr);
    }
    break;

  /* Go to the first occurrence of the identifier under cursor along path in a
   * new window -- webb
   */
  case 'i':                         /* Go to any match */
  case Ctrl_I:
    type = FIND_ANY;
    FALLTHROUGH;
  case 'd':                         // Go to definition, using 'define'
  case Ctrl_D:
    CHECK_CMDWIN
    if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0)
      break;
    find_pattern_in_path(ptr, 0, len, TRUE,
                         Prenum == 0 ? TRUE : FALSE,
                         type, Prenum1, ACTION_SPLIT, 1, MAXLNUM);
    curwin->w_set_curswant = TRUE;
    break;

  case K_KENTER:
  case CAR:
    /*
     * In a quickfix window a <CR> jumps to the error under the
     * cursor in a new window.
     */
    if (bt_quickfix(curbuf)) {
      sprintf(cbuf, "split +%" PRId64 "%s",
              (int64_t)curwin->w_cursor.lnum,
              (curwin->w_llist_ref == NULL) ? "cc" : "ll");
      do_cmdline_cmd(cbuf);
    }
    break;


  /* CTRL-W g  extended commands */
  case 'g':
  case Ctrl_G:
    CHECK_CMDWIN
    no_mapping++;
    if (xchar == NUL) {
      xchar = plain_vgetc();
    }
    LANGMAP_ADJUST(xchar, true);
    no_mapping--;
    (void)add_to_showcmd(xchar);
    switch (xchar) {
    case '}':
      xchar = Ctrl_RSB;
      if (Prenum)
        g_do_tagpreview = Prenum;
      else
        g_do_tagpreview = p_pvh;
      FALLTHROUGH;
    case ']':
    case Ctrl_RSB:
      // Keep visual mode, can select words to use as a tag.
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

static void cmd_with_count(char *cmd, char_u *bufp, size_t bufsize,
                           int64_t Prenum)
{
  size_t len = xstrlcpy((char *)bufp, cmd, bufsize);

  if (Prenum > 0 && len < bufsize) {
    vim_snprintf((char *)bufp + len, bufsize - len, "%" PRId64, Prenum);
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
  frame_T   *frp, *curfrp, *frp2, *prevfrp;
  int before;
  int minheight;
  int wmh1;
  bool did_set_fraction = false;

  if (flags & WSP_TOP)
    oldwin = firstwin;
  else if (flags & WSP_BOT)
    oldwin = lastwin;
  else
    oldwin = curwin;

  /* add a status line when p_ls == 1 and splitting the first window */
  if (ONE_WINDOW && p_ls == 1 && oldwin->w_status_height == 0) {
    if (oldwin->w_height <= p_wmh && new_wp == NULL) {
      EMSG(_(e_noroom));
      return FAIL;
    }
    need_status = STATUS_HEIGHT;
  }


  if (flags & WSP_VERT) {
    int wmw1;
    int minwidth;

    layout = FR_ROW;

    /*
     * Check if we are able to split the current window and compute its
     * width.
     */
    // Current window requires at least 1 space.
    wmw1 = (p_wmw == 0 ? 1 : p_wmw);
    needed = wmw1 + 1;
    if (flags & WSP_ROOM) {
      needed += p_wiw - wmw1;
    }
    if (flags & (WSP_BOT | WSP_TOP)) {
      minwidth = frame_minwidth(topframe, NOWIN);
      available = topframe->fr_width;
      needed += minwidth;
    } else if (p_ea) {
      minwidth = frame_minwidth(oldwin->w_frame, NOWIN);
      prevfrp = oldwin->w_frame;
      for (frp = oldwin->w_frame->fr_parent; frp != NULL;
           frp = frp->fr_parent) {
        if (frp->fr_layout == FR_ROW) {
          for (frp2 = frp->fr_child; frp2 != NULL; frp2 = frp2->fr_next) {
            if (frp2 != prevfrp) {
              minwidth += frame_minwidth(frp2, NOWIN);
            }
          }
        }
        prevfrp = frp;
      }
      available = topframe->fr_width;
      needed += minwidth;
    } else {
      minwidth = frame_minwidth(oldwin->w_frame, NOWIN);
      available = oldwin->w_frame->fr_width;
      needed += minwidth;
    }
    if (available < needed && new_wp == NULL) {
      EMSG(_(e_noroom));
      return FAIL;
    }
    if (new_size == 0)
      new_size = oldwin->w_width / 2;
    if (new_size > available - minwidth - 1) {
      new_size = available - minwidth - 1;
    }
    if (new_size < wmw1) {
      new_size = wmw1;
    }

    /* if it doesn't fit in the current window, need win_equal() */
    if (oldwin->w_width - new_size - 1 < p_wmw)
      do_equal = TRUE;

    // We don't like to take lines for the new window from a
    // 'winfixwidth' window.  Take them from a window to the left or right
    // instead, if possible. Add one for the separator.
    if (oldwin->w_p_wfw) {
      win_setwidth_win(oldwin->w_width + new_size + 1, oldwin);
    }

    /* Only make all windows the same width if one of them (except oldwin)
     * is wider than one of the split windows. */
    if (!do_equal && p_ea && size == 0 && *p_ead != 'v'
        && oldwin->w_frame->fr_parent != NULL) {
      frp = oldwin->w_frame->fr_parent->fr_child;
      while (frp != NULL) {
        if (frp->fr_win != oldwin && frp->fr_win != NULL
            && (frp->fr_win->w_width > new_size
                || frp->fr_win->w_width > oldwin->w_width
                                          - new_size - 1)) {
          do_equal = TRUE;
          break;
        }
        frp = frp->fr_next;
      }
    }
  } else {
    layout = FR_COL;

    /*
     * Check if we are able to split the current window and compute its
     * height.
     */
    // Current window requires at least 1 space.
    wmh1 = (p_wmh == 0 ? 1 : p_wmh);
    needed = wmh1 + STATUS_HEIGHT;
    if (flags & WSP_ROOM) {
      needed += p_wh - wmh1;
    }
    if (flags & (WSP_BOT | WSP_TOP)) {
      minheight = frame_minheight(topframe, NOWIN) + need_status;
      available = topframe->fr_height;
      needed += minheight;
    } else if (p_ea) {
      minheight = frame_minheight(oldwin->w_frame, NOWIN) + need_status;
      prevfrp = oldwin->w_frame;
      for (frp = oldwin->w_frame->fr_parent; frp != NULL;
           frp = frp->fr_parent) {
        if (frp->fr_layout == FR_COL) {
          for (frp2 = frp->fr_child; frp2 != NULL; frp2 = frp2->fr_next) {
            if (frp2 != prevfrp) {
              minheight += frame_minheight(frp2, NOWIN);
            }
          }
        }
        prevfrp = frp;
      }
      available = topframe->fr_height;
      needed += minheight;
    } else {
      minheight = frame_minheight(oldwin->w_frame, NOWIN) + need_status;
      available = oldwin->w_frame->fr_height;
      needed += minheight;
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

    if (new_size > available - minheight - STATUS_HEIGHT) {
      new_size = available - minheight - STATUS_HEIGHT;
    }
    if (new_size < wmh1) {
      new_size = wmh1;
    }

    /* if it doesn't fit in the current window, need win_equal() */
    if (oldwin_height - new_size - STATUS_HEIGHT < p_wmh)
      do_equal = TRUE;

    /* We don't like to take lines for the new window from a
     * 'winfixheight' window.  Take them from a window above or below
     * instead, if possible. */
    if (oldwin->w_p_wfh) {
      // Set w_fraction now so that the cursor keeps the same relative
      // vertical position using the old height.
      set_fraction(oldwin);
      did_set_fraction = true;

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
  } else {
    if (new_wp == NULL)
      wp = win_alloc(oldwin->w_prev, FALSE);
    else
      win_append(oldwin->w_prev, wp);
  }

  if (new_wp == NULL) {
    if (wp == NULL)
      return FAIL;

    new_frame(wp);

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
  } else {
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
    frp = xcalloc(1, sizeof(frame_T));
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
  if (!did_set_fraction) {
    set_fraction(oldwin);
  }
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
    } else {
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
  } else {
    /* width and column of new window is same as current window */
    if (flags & (WSP_TOP | WSP_BOT)) {
      wp->w_wincol = 0;
      win_new_width(wp, Columns);
      wp->w_vsep_width = 0;
    } else {
      wp->w_wincol = oldwin->w_wincol;
      win_new_width(wp, oldwin->w_width);
      wp->w_vsep_width = oldwin->w_vsep_width;
    }
    frp->fr_width = curfrp->fr_width;

    /* "new_size" of the current window goes to the new window, use
     * one row for the status line */
    win_new_height(wp, new_size);
    if (flags & (WSP_TOP | WSP_BOT)) {
      int new_fr_height = curfrp->fr_height - new_size;

      if (!((flags & WSP_BOT) && p_ls == 0)) {
        new_fr_height -= STATUS_HEIGHT;
      }
      frame_new_height(curfrp, new_fr_height, flags & WSP_TOP, false);
    } else {
      win_new_height(oldwin, oldwin_height - (new_size + STATUS_HEIGHT));
    }
    if (before) {       // new window above current one
      wp->w_winrow = oldwin->w_winrow;
      wp->w_status_height = STATUS_HEIGHT;
      oldwin->w_winrow += wp->w_height + STATUS_HEIGHT;
    } else {          /* new window below current one */
      wp->w_winrow = oldwin->w_winrow + oldwin->w_height + STATUS_HEIGHT;
      wp->w_status_height = oldwin->w_status_height;
      if (!(flags & WSP_BOT)) {
        oldwin->w_status_height = STATUS_HEIGHT;
      }
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
    win_equal(wp, true,
        (flags & WSP_VERT) ? (dir == 'v' ? 'b' : 'h')
        : dir == 'h' ? 'b' :
        'v');

  /* Don't change the window height/width to 'winheight' / 'winwidth' if a
   * size was given. */
  if (flags & WSP_VERT) {
    i = p_wiw;
    if (size != 0)
      p_wiw = size;

  } else {
    i = p_wh;
    if (size != 0)
      p_wh = size;
  }

  // Keep same changelist position in new window.
  wp->w_changelistidx = oldwin->w_changelistidx;

  /*
   * make the new window the current window
   */
  win_enter_ext(wp, false, false, true, true, true);
  if (flags & WSP_VERT) {
    p_wiw = i;
  } else {
    p_wh = i;
  }

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

  didset_window_options(newp);
}

/*
 * Initialize window "newp" from window "old".
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


/// Check if "win" is a pointer to an existing window in the current tabpage.
///
/// @param  win  window to check
bool win_valid(win_T *win) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (win == NULL) {
    return false;
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp == win) {
      return true;
    }
  }
  return false;
}

/// Check if "win" is a pointer to an existing window in any tabpage.
///
/// @param  win  window to check
bool win_valid_any_tab(win_T *win) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (win == NULL) {
    return false;
  }

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp == win) {
      return true;
    }
  }
  return false;
}

/*
 * Return the number of windows.
 */
int win_count(void)
{
  int count = 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    ++count;
  }
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
  } else {
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
    } else {
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

  if (ONE_WINDOW) {        /* just one window */
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
  } else {
    frame_fix_height(curwin);
    frame_fix_height(wp);
    frame_fix_width(curwin);
    frame_fix_width(wp);
  }

  (void)win_comp_pos();                 /* recompute window positions */

  win_enter(wp, true);
  redraw_later(NOT_VALID);
  redraw_win_later(wp, NOT_VALID);
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

  if (ONE_WINDOW) {            /* nothing to do */
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
      assert(frp->fr_parent->fr_child);

      /* find last frame and append removed window/frame after it */
      for (; frp->fr_next != NULL; frp = frp->fr_next)
        ;
      win_append(frp->fr_win, wp1);
      frame_append(frp, wp1->w_frame);

      wp2 = frp->fr_win;                /* previously last window */
    } else {                  /* last window becomes first window */
      /* find last window/frame in the list and remove it */
      for (frp = curwin->w_frame; frp->fr_next != NULL;
           frp = frp->fr_next)
        ;
      wp1 = frp->fr_win;
      wp2 = wp1->w_prev;                    /* will become last window */
      win_remove(wp1, NULL);
      frame_remove(frp);
      assert(frp->fr_parent->fr_child);

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

  redraw_all_later(NOT_VALID);
}

/*
 * Move the current window to the very top/bottom/left/right of the screen.
 */
static void win_totop(int size, int flags)
{
  int dir;
  int height = curwin->w_height;

  if (ONE_WINDOW) {
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
      win_equal(curwin, true, 'v');
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
    } else if (win2 == lastwin) {
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
  win_enter(win1, false);
}

/*
 * Make all windows the same height.
 * 'next_curwin' will soon be the current window, make sure it has enough
 * rows.
 */
void win_equal(
    win_T *next_curwin,            // pointer to current window to be or NULL
    bool current,                  // do only frame with current window
    int dir                        // 'v' for vertically, 'h' for horizontally,
                                   // 'b' for both, 0 for using p_ead
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
static void win_equal_rec(
    win_T *next_curwin,       /* pointer to current window to be or NULL */
    bool current,                    /* do only frame with current window */
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
      frame_new_height(topfr, height, false, false);
      topfr->fr_win->w_wincol = col;
      frame_new_width(topfr, width, false, false);
      redraw_all_later(NOT_VALID);
    }
  } else if (topfr->fr_layout == FR_ROW) {
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
      } else {
        next_curwin_size = -1;
        for (fr = topfr->fr_child; fr != NULL; fr = fr->fr_next) {
          /* If 'winfixwidth' set keep the window width if
           * possible.
           * Watch out for this window being the next_curwin. */
          if (!frame_fixed_width(fr)) {
            continue;
          }
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
      wincount = 1;
      if (fr->fr_next == NULL)
        /* last frame gets all that remains (avoid roundoff error) */
        new_size = width;
      else if (dir == 'v')
        new_size = fr->fr_width;
      else if (frame_fixed_width(fr)) {
        new_size = fr->fr_newwidth;
        wincount = 0;               /* doesn't count as a sizeable window */
      } else {
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
          new_size = (wincount * room + (totwincount / 2)) / totwincount;
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
  } else { /* topfr->fr_layout == FR_COL */
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
      } else {
        next_curwin_size = -1;
        for (fr = topfr->fr_child; fr != NULL; fr = fr->fr_next) {
          /* If 'winfixheight' set keep the window height if
           * possible.
           * Watch out for this window being the next_curwin. */
          if (!frame_fixed_height(fr)) {
            continue;
          }
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
      wincount = 1;
      if (fr->fr_next == NULL)
        /* last frame gets all that remains (avoid roundoff error) */
        new_size = height;
      else if (dir == 'h')
        new_size = fr->fr_height;
      else if (frame_fixed_height(fr)) {
        new_size = fr->fr_newheight;
        wincount = 0;               /* doesn't count as a sizeable window */
      } else {
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
          new_size = (wincount * room + (totwincount / 2)) / totwincount;
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

/// Closes all windows for buffer `buf`.
///
/// @param keep_curwin don't close `curwin`
void close_windows(buf_T *buf, int keep_curwin)
{
  tabpage_T   *tp, *nexttp;
  int h = tabline_height();

  ++RedrawingDisabled;

  for (win_T *wp = firstwin; wp != NULL && !ONE_WINDOW; ) {
    if (wp->w_buffer == buf && (!keep_curwin || wp != curwin)
        && !(wp->w_closing || wp->w_buffer->b_locked > 0)) {
      if (win_close(wp, false) == FAIL) {
        // If closing the window fails give up, to avoid looping forever.
        break;
      }

      /* Start all over, autocommands may change the window layout. */
      wp = firstwin;
    } else
      wp = wp->w_next;
  }

  /* Also check windows in other tab pages. */
  for (tp = first_tabpage; tp != NULL; tp = nexttp) {
    nexttp = tp->tp_next;
    if (tp != curtab) {
      FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
        if (wp->w_buffer == buf
            && !(wp->w_closing || wp->w_buffer->b_locked > 0)) {
          win_close_othertab(wp, false, tp);

          /* Start all over, the tab page may be closed and
           * autocommands may change the window layout. */
          nexttp = first_tabpage;
          break;
        }
      }
    }
  }

  --RedrawingDisabled;

  redraw_tabline = true;
  if (h != tabline_height()) {
    shell_new_rows();
  }
}

/// Check that current window is the last one.
///
/// @return true if the current window is the only window that exists, false if
///         there is another, possibly in another tab page.
static bool last_window(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return one_window() && first_tabpage->tp_next == NULL;
}

/// Check that current tab page contains no more then one window other than
/// "aucmd_win".
bool one_window(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  bool seen_one = false;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp != aucmd_win) {
      if (seen_one) {
        return false;
      }
      seen_one = true;
    }
  }
  return true;
}

/// Close the possibly last window in a tab page.
///
/// @param  win          window to close
/// @param  free_buf     whether to free the window's current buffer
/// @param  prev_curtab  previous tabpage that will be closed if "win" is the
///                      last window in the tabpage
///
/// @return true when the window was closed already.
static bool close_last_window_tabpage(win_T *win, bool free_buf,
                                      tabpage_T *prev_curtab)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!ONE_WINDOW) {
    return false;
  }
  buf_T   *old_curbuf = curbuf;

  Terminal *term = win->w_buffer ? win->w_buffer->terminal : NULL;
  if (term) {
    // Don't free terminal buffers
    free_buf = false;
  }

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

  // save index for tabclosed event
  char_u prev_idx[NUMBUFLEN];
  sprintf((char *)prev_idx, "%i", tabpage_index(prev_curtab));

  /* Safety check: Autocommands may have closed the window when jumping
   * to the other tab page. */
  if (valid_tabpage(prev_curtab) && prev_curtab->tp_firstwin == win) {
    int h = tabline_height();

    win_close_othertab(win, free_buf, prev_curtab);
    if (h != tabline_height())
      shell_new_rows();
  }

  // Since goto_tabpage_tp above did not trigger *Enter autocommands, do
  // that now.
  apply_autocmds(EVENT_WINENTER, NULL, NULL, false, curbuf);
  apply_autocmds(EVENT_TABENTER, NULL, NULL, false, curbuf);
  if (old_curbuf != curbuf) {
    apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
  }
  return true;
}

// Close window "win".  Only works for the current tab page.
// If "free_buf" is true related buffer may be unloaded.
//
// Called by :quit, :close, :xit, :wq and findtag().
// Returns FAIL when the window was not closed.
int win_close(win_T *win, bool free_buf)
{
  win_T       *wp;
  int other_buffer = FALSE;
  int close_curwin = FALSE;
  int dir;
  bool help_window = false;
  tabpage_T   *prev_curtab = curtab;
  frame_T *win_frame = win->w_frame->fr_parent;

  if (last_window()) {
    EMSG(_("E444: Cannot close last window"));
    return FAIL;
  }

  if (win->w_closing
      || (win->w_buffer != NULL && win->w_buffer->b_locked > 0)) {
    return FAIL;     // window is already being closed
  }
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
  if (bt_help(win->w_buffer)) {
    help_window = true;
  } else {
    clear_snapshot(curtab, SNAP_HELP_IDX);
  }

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
      win->w_closing = true;
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, FALSE, curbuf);
      if (!win_valid(win))
        return FAIL;
      win->w_closing = false;
      if (last_window())
        return FAIL;
    }
    win->w_closing = true;
    apply_autocmds(EVENT_WINLEAVE, NULL, NULL, FALSE, curbuf);
    if (!win_valid(win))
      return FAIL;
    win->w_closing = false;
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
    bufref_T bufref;
    set_bufref(&bufref, curbuf);
    win->w_closing = true;
    close_buffer(win, win->w_buffer, free_buf ? DOBUF_UNLOAD : 0, true);
    if (win_valid_any_tab(win)) {
      win->w_closing = false;
    }

    // Make sure curbuf is valid. It can become invalid if 'bufhidden' is
    // "wipe".
    if (!bufref_valid(&bufref)) {
      curbuf = firstbuf;
    }
  }

  if (only_one_window() && win_valid(win) && win->w_buffer == NULL
      && (last_window() || curtab != prev_curtab
          || close_last_window_tabpage(win, free_buf, prev_curtab))) {
    // Autocommands have closed all windows, quit now.  Restore
    // curwin->w_buffer, otherwise writing ShaDa file may fail.
    if (curwin->w_buffer == NULL) {
      curwin->w_buffer = curbuf;
    }
    getout(0);
  }
  // Autocommands may have moved to another tab page.
  if (curtab != prev_curtab && win_valid_any_tab(win)
      && win->w_buffer == NULL) {
    // Need to close the window anyway, since the buffer is NULL.
    win_close_othertab(win, false, prev_curtab);
    return FAIL;
  }
  // Autocommands may have closed the window already, or closed the only
  // other window or moved to another tab page.
  if (!win_valid(win) || last_window()
      || close_last_window_tabpage(win, free_buf, prev_curtab)) {
    return FAIL;
  }

  // let terminal buffers know that this window dimensions may be ignored
  win->w_closing = true;
  /* Free the memory used for the window and get the window that received
   * the screen space. */
  wp = win_free_mem(win, &dir, NULL);

  if (help_window) {
    // Closing the help window moves the cursor back to the original window.
    win_T *tmpwp = get_snapshot_focus(SNAP_HELP_IDX);
    if (tmpwp != NULL) {
      wp = tmpwp;
    }
  }

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

    // The cursor position may be invalid if the buffer changed after last
    // using the window.
    check_cursor();
  }
  if (p_ea && (*p_ead == 'b' || *p_ead == dir)) {
    // If the frame of the closed window contains the new current window,
    // only resize that frame.  Otherwise resize all windows.
    win_equal(curwin, curwin->w_frame->fr_parent == win_frame, dir);
  } else {
    win_comp_pos();
  }

  if (close_curwin) {
    win_enter_ext(wp, false, true, false, true, true);
    if (other_buffer) {
      // careful: after this wp and win may be invalid!
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
    }
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
  int dir;
  tabpage_T   *ptp = NULL;
  int free_tp = FALSE;

  // Get here with win->w_buffer == NULL when win_close() detects the tab page
  // changed.
  if (win->w_closing
      || (win->w_buffer != NULL && win->w_buffer->b_locked > 0)) {
    return;  // window is already being closed
  }

  if (win->w_buffer != NULL) {
    // Close the link to the buffer.
    close_buffer(win, win->w_buffer, free_buf ? DOBUF_UNLOAD : 0, false);
  }

  /* Careful: Autocommands may have closed the tab page or made it the
   * current tab page.  */
  for (ptp = first_tabpage; ptp != NULL && ptp != tp; ptp = ptp->tp_next)
    ;
  if (ptp == NULL || tp == curtab)
    return;

  /* Autocommands may have closed the window already. */
  {
    bool found_window = false;
    FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
      if (wp == win) {
         found_window = true;
         break;
      }
    }
    if (!found_window) {
       return;
    }
  }

  /* When closing the last window in a tab page remove the tab page. */
  if (tp->tp_firstwin == tp->tp_lastwin) {
    char_u prev_idx[NUMBUFLEN];
    if (has_event(EVENT_TABCLOSED)) {
      vim_snprintf((char *)prev_idx, NUMBUFLEN, "%i", tabpage_index(tp));
    }

    if (tp == first_tabpage) {
      first_tabpage = tp->tp_next;
    } else {
      for (ptp = first_tabpage; ptp != NULL && ptp->tp_next != tp;
           ptp = ptp->tp_next) {
        // loop
      }
      if (ptp == NULL) {
        internal_error("win_close_othertab()");
        return;
      }
      ptp->tp_next = tp->tp_next;
    }
    free_tp = true;

    if (has_event(EVENT_TABCLOSED)) {
      apply_autocmds(EVENT_TABCLOSED, prev_idx, prev_idx, false, win->w_buffer);
    }
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
  xfree(frp);
  win_free(win, tp);

  /* When deleting the current window of another tab page select a new
   * current window. */
  if (tp != NULL && win == tp->tp_curwin)
    tp->tp_curwin = wp;

  return wp;
}

#if defined(EXITFREE)
void win_free_all(void)
{
  int dummy;

  while (first_tabpage->tp_next != NULL)
    tabpage_close(TRUE);

  if (aucmd_win != NULL) {
    (void)win_free_mem(aucmd_win, &dummy, NULL);
    aucmd_win = NULL;
  }

  while (firstwin != NULL)
    (void)win_free_mem(firstwin, &dummy, NULL);

  // No window should be used after this. Set curwin to NULL to crash
  // instead of using freed memory.
  curwin = NULL;
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
  if (tp == NULL ? ONE_WINDOW : tp->tp_firstwin == tp->tp_lastwin)
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
  } else {
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
    int col = win->w_wincol;

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
    if (topframe->fr_child == frp2) {
      topframe->fr_child = frp;
    }
    xfree(frp2);

    frp2 = frp->fr_parent;
    if (frp2 != NULL && frp2->fr_layout == frp->fr_layout) {
      /* The frame above the parent has the same layout, have to merge
       * the frames into this list. */
      if (frp2->fr_child == frp)
        frp2->fr_child = frp->fr_child;
      assert(frp->fr_child);
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
      if (topframe->fr_child == frp) {
        topframe->fr_child = frp2;
      }
      xfree(frp);
    }
  }

  return wp;
}

// Return a pointer to the frame that will receive the empty screen space that
// is left over after "win" is closed.
//
// If 'splitbelow' or 'splitright' is set, the space goes above or to the left
// by default.  Otherwise, the free space goes below or to the right.  The
// result is that opening a window and then immediately closing it will
// preserve the initial window layout.  The 'wfh' and 'wfw' settings are
// respected when possible.
static frame_T *
win_altframe (
    win_T *win,
    tabpage_T *tp                /* tab page "win" is in, NULL for current */
)
{
  frame_T     *frp;

  if (tp == NULL ? ONE_WINDOW : tp->tp_firstwin == tp->tp_lastwin) {
    return alt_tabpage()->tp_curwin->w_frame;
  }

  frp = win->w_frame;

  if (frp->fr_prev == NULL) {
    return frp->fr_next;
  }
  if (frp->fr_next == NULL) {
    return frp->fr_prev;
  }

  frame_T *target_fr = frp->fr_next;
  frame_T *other_fr  = frp->fr_prev;
  if (p_spr || p_sb) {
    target_fr = frp->fr_prev;
    other_fr  = frp->fr_next;
  }

  // If 'wfh' or 'wfw' is set for the target and not for the alternate
  // window, reverse the selection.
  if (frp->fr_parent != NULL && frp->fr_parent->fr_layout == FR_ROW) {
    if (frame_fixed_width(target_fr) && !frame_fixed_width(other_fr)) {
      target_fr = other_fr;
    }
  } else {
    if (frame_fixed_height(target_fr) && !frame_fixed_height(other_fr)) {
      target_fr = other_fr;
    }
  }

  return target_fr;
}

/*
 * Return the tabpage that will be used if the current one is closed.
 */
static tabpage_T *alt_tabpage(void)
{
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

/// Check that the frame "frp" contains the window "wp".
///
/// @param  frp  frame
/// @param  wp   window
static bool frame_has_win(frame_T *frp, win_T *wp)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  if (frp->fr_layout == FR_LEAF) {
    return frp->fr_win == wp;
  }
  for (frame_T *p = frp->fr_child; p != NULL; p = p->fr_next) {
    if (frame_has_win(p, wp)) {
      return true;
    }
  }
  return false;
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
  } else if (topfrp->fr_layout == FR_ROW) {
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
  } else { /* fr_layout == FR_COL */
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
        } else {
          frame_new_height(frp, frp->fr_height + extra_lines,
              topfirst, wfh);
          break;
        }
        if (topfirst) {
          do
            frp = frp->fr_next;
          while (wfh && frp != NULL && frame_fixed_height(frp));
        } else {
          do
            frp = frp->fr_prev;
          while (wfh && frp != NULL && frame_fixed_height(frp));
        }
        /* Increase "height" if we could not reduce enough frames. */
        if (frp == NULL)
          height -= extra_lines;
      }
    } else if (extra_lines > 0) {
      /* increase height of bottom or top frame */
      frame_new_height(frp, frp->fr_height + extra_lines, topfirst, wfh);
    }
  }
  topfrp->fr_height = height;
}

/// Return true if height of frame "frp" should not be changed because of
/// the 'winfixheight' option.
///
/// @param  frp  frame
///
/// @return true if the frame has a fixed height
static bool frame_fixed_height(frame_T *frp)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  // frame with one window: fixed height if 'winfixheight' set.
  if (frp->fr_win != NULL) {
    return frp->fr_win->w_p_wfh;
  }
  if (frp->fr_layout == FR_ROW) {
    // The frame is fixed height if one of the frames in the row is fixed
    // height.
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next) {
      if (frame_fixed_height(frp)) {
        return true;
      }
    }
    return false;
  }

  // frp->fr_layout == FR_COL: The frame is fixed height if all of the
  // frames in the row are fixed height.
  for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next) {
    if (!frame_fixed_height(frp)) {
      return false;
    }
  }
  return true;
}

/// Return true if width of frame "frp" should not be changed because of
/// the 'winfixwidth' option.
///
/// @param  frp  frame
///
/// @return true if the frame has a fixed width
static bool frame_fixed_width(frame_T *frp)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  // frame with one window: fixed width if 'winfixwidth' set.
  if (frp->fr_win != NULL) {
    return frp->fr_win->w_p_wfw;
  }
  if (frp->fr_layout == FR_COL) {
    // The frame is fixed width if one of the frames in the row is fixed
    // width.
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next) {
      if (frame_fixed_width(frp)) {
        return true;
      }
    }
    return false;
  }

  // frp->fr_layout == FR_ROW: The frame is fixed width if all of the
  // frames in the row are fixed width.
  for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next) {
    if (!frame_fixed_width(frp)) {
      return false;
    }
  }
  return true;
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
  } else if (frp->fr_layout == FR_ROW) {
    /* Handle all the frames in the row. */
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
      frame_add_statusline(frp);
  } else { /* frp->fr_layout == FR_COL */
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
  } else if (topfrp->fr_layout == FR_COL) {
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
  } else { /* fr_layout == FR_ROW */
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
        } else {
          frame_new_width(frp, frp->fr_width + extra_cols,
              leftfirst, wfw);
          break;
        }
        if (leftfirst) {
          do
            frp = frp->fr_next;
          while (wfw && frp != NULL && frame_fixed_width(frp));
        } else {
          do
            frp = frp->fr_prev;
          while (wfw && frp != NULL && frame_fixed_width(frp));
        }
        /* Increase "width" if we could not reduce enough frames. */
        if (frp == NULL)
          width -= extra_cols;
      }
    } else if (extra_cols > 0) {
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
  } else if (frp->fr_layout == FR_COL) {
    /* Handle all the frames in the column. */
    for (frp = frp->fr_child; frp != NULL; frp = frp->fr_next)
      frame_add_vsep(frp);
  } else { /* frp->fr_layout == FR_ROW */
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
  } else if (topfrp->fr_layout == FR_ROW) {
    /* get the minimal height from each frame in this row */
    m = 0;
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
      n = frame_minheight(frp, next_curwin);
      if (n > m)
        m = n;
    }
  } else {
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
  } else if (topfrp->fr_layout == FR_COL) {
    /* get the minimal width from each frame in this column */
    m = 0;
    for (frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
      n = frame_minwidth(frp, next_curwin);
      if (n > m)
        m = n;
    }
  } else {
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
    if (wp == curwin) {                 /* don't close current window */
      continue;
    }

    /* Check if it's allowed to abandon this window */
    r = can_abandon(wp->w_buffer, forceit);
    if (!win_valid(wp)) {             /* autocommands messed wp up */
      nextwp = firstwin;
      continue;
    }
    if (!r) {
      if (message && (p_confirm || cmdmod.confirm) && p_write) {
        dialog_changed(wp->w_buffer, false);
        if (!win_valid(wp)) {                 // autocommands messed wp up
          nextwp = firstwin;
          continue;
        }
      }
      if (bufIsChanged(wp->w_buffer))
        continue;
    }
    win_close(wp, !buf_hide(wp->w_buffer) && !bufIsChanged(wp->w_buffer));
  }

  if (message && !ONE_WINDOW)
    EMSG(_("E445: Other window contains changes"));
}


/*
 * Init the current window "curwin".
 * Called when a new file is being edited.
 */
void curwin_init(void)
{
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
 *
 * Return FAIL when something goes wrong.
 */
int win_alloc_first(void)
{
  if (win_alloc_firstwin(NULL) == FAIL)
    return FAIL;

  first_tabpage = alloc_tabpage();
  first_tabpage->tp_topframe = topframe;
  curtab = first_tabpage;

  return OK;
}

/*
 * Init "aucmd_win".  This can only be done after the first
 * window is fully initialized, thus it can't be in win_alloc_first().
 */
void win_alloc_aucmd_win(void)
{
  aucmd_win = win_alloc(NULL, TRUE);
  win_init_some(aucmd_win, curwin);
  RESET_BINDING(aucmd_win);
  new_frame(aucmd_win);
}

/*
 * Allocate the first window or the first window in a new tab page.
 * When "oldwin" is NULL create an empty buffer for it.
 * When "oldwin" is not NULL copy info from it to the new window.
 * Return FAIL when something goes wrong (out of memory).
 */
static int win_alloc_firstwin(win_T *oldwin)
{
  curwin = win_alloc(NULL, FALSE);
  if (oldwin == NULL) {
    /* Very first window, need to create an empty buffer for it and
     * initialize from scratch. */
    curbuf = buflist_new(NULL, NULL, 1L, BLN_LISTED);
    if (curbuf == NULL) {
      return FAIL;
    }
    curwin->w_buffer = curbuf;
    curwin->w_s = &(curbuf->b_s);
    curbuf->b_nwindows = 1;     /* there is one window */
    curwin->w_alist = &global_alist;
    curwin_init();              /* init current window */
  } else {
    /* First window in new tab page, initialize it from "oldwin". */
    win_init(curwin, oldwin, 0);

    /* We don't want cursor- and scroll-binding in the first window. */
    RESET_BINDING(curwin);
  }

  new_frame(curwin);
  topframe = curwin->w_frame;
  topframe->fr_width = Columns;
  topframe->fr_height = Rows - p_ch;

  return OK;
}

/*
 * Create a frame for window "wp".
 */
static void new_frame(win_T *wp)
{
  frame_T *frp = xcalloc(1, sizeof(frame_T));

  wp->w_frame = frp;
  frp->fr_layout = FR_LEAF;
  frp->fr_win = wp;
}

/*
 * Initialize the window and frame size to the maximum.
 */
void win_init_size(void)
{
  firstwin->w_height = ROWS_AVAIL;
  topframe->fr_height = ROWS_AVAIL;
  firstwin->w_width = Columns;
  topframe->fr_width = Columns;
}

/*
 * Allocate a new tabpage_T and init the values.
 */
static tabpage_T *alloc_tabpage(void)
{
  static int last_tp_handle = 0;
  tabpage_T *tp = xcalloc(1, sizeof(tabpage_T));
  tp->handle = ++last_tp_handle;
  handle_register_tabpage(tp);

  // Init t: variables.
  tp->tp_vars = tv_dict_alloc();
  init_var_dict(tp->tp_vars, &tp->tp_winvar, VAR_SCOPE);
  tp->tp_diff_invalid = TRUE;
  tp->tp_ch_used = p_ch;

  return tp;
}

void free_tabpage(tabpage_T *tp)
{
  int idx;

  handle_unregister_tabpage(tp);
  diff_clear(tp);
  for (idx = 0; idx < SNAP_COUNT; ++idx)
    clear_snapshot(tp, idx);
  vars_clear(&tp->tp_vars->dv_hashtab);         /* free all t: variables */
  hash_init(&tp->tp_vars->dv_hashtab);
  unref_var_dict(tp->tp_vars);

  xfree(tp->tp_localdir);
  xfree(tp);
}

/// Create a new tabpage with one window.
///
/// It will edit the current buffer, like after :split.
///
/// @param after Put new tabpage after tabpage "after", or after the current
///              tabpage in case of 0.
/// @param filename Will be passed to apply_autocmds().
/// @return Was the new tabpage created successfully? FAIL or OK.
int win_new_tabpage(int after, char_u *filename)
{
  tabpage_T   *tp = curtab;
  tabpage_T   *newtp;
  int n;

  newtp = alloc_tabpage();

  /* Remember the current windows in this Tab page. */
  if (leave_tabpage(curbuf, TRUE) == FAIL) {
    xfree(newtp);
    return FAIL;
  }

  newtp->tp_localdir = tp->tp_localdir ? vim_strsave(tp->tp_localdir) : NULL;

  curtab = newtp;

  /* Create a new empty window. */
  if (win_alloc_firstwin(tp->tp_curwin) == OK) {
    /* Make the new Tab page the new topframe. */
    if (after == 1) {
      /* New tab page becomes the first one. */
      newtp->tp_next = first_tabpage;
      first_tabpage = newtp;
    } else {
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

    redraw_all_later(NOT_VALID);

    apply_autocmds(EVENT_WINNEW, NULL, NULL, false, curbuf);
    apply_autocmds(EVENT_WINENTER, NULL, NULL, false, curbuf);
    apply_autocmds(EVENT_TABNEW, filename, filename, false, curbuf);
    apply_autocmds(EVENT_TABENTER, NULL, NULL, false, curbuf);

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
int may_open_tabpage(void)
{
  int n = (cmdmod.tab == 0) ? postponed_split_tab : cmdmod.tab;

  if (n != 0) {
    cmdmod.tab = 0;         /* reset it to avoid doing it twice */
    postponed_split_tab = 0;
    return win_new_tabpage(n, NULL);
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

  for (todo = count - 1; todo > 0; --todo) {
    if (win_new_tabpage(0, NULL) == FAIL) {
      break;
    }
  }

  unblock_autocmds();

  /* return actual number of tab pages */
  return count - todo;
}

/// Check that tpc points to a valid tab page.
///
/// @param[in]  tpc  Tabpage to check.
bool valid_tabpage(tabpage_T *tpc) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  FOR_ALL_TABS(tp) {
    if (tp == tpc) {
      return true;
    }
  }
  return false;
}

/// Returns true when `tpc` is valid and at least one window is valid.
int valid_tabpage_win(tabpage_T *tpc)
{
  FOR_ALL_TABS(tp) {
    if (tp == tpc) {
      FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
        if (win_valid_any_tab(wp)) {
          return true;
        }
      }
      return false;
    }
  }
  // shouldn't happen
  return false;
}

/// Close tabpage `tab`, assuming it has no windows in it.
/// There must be another tabpage or this will crash.
void close_tabpage(tabpage_T *tab)
{
  tabpage_T *ptp;

  if (tab == first_tabpage) {
    first_tabpage = tab->tp_next;
    ptp = first_tabpage;
  } else {
    for (ptp = first_tabpage; ptp != NULL && ptp->tp_next != tab;
         ptp = ptp->tp_next) {
      // do nothing
    }
    assert(ptp != NULL);
    ptp->tp_next = tab->tp_next;
  }

  goto_tabpage_tp(ptp, false, false);
  free_tabpage(tab);
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
  win_enter_ext(tp->tp_curwin, false, true, false,
                trigger_enter_autocmds, trigger_leave_autocmds);
  prevwin = next_prevwin;

  last_status(false);  // status line may appear or disappear
  (void)win_comp_pos();  // recompute w_winrow for all windows
  diff_need_scrollbind = true;

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

  redraw_all_later(NOT_VALID);
  must_redraw = NOT_VALID;
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
    // Not allowed when editing the command line.
    text_locked_msg();
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
  } else if (n < 0) {
    /* "gT": go to previous tab page, wrap around end.  "N gT" repeats
     * this N times. */
    ttp = curtab;
    for (i = n; i < 0; ++i) {
      for (tp = first_tabpage; tp->tp_next != ttp && tp->tp_next != NULL;
           tp = tp->tp_next)
        ;
      ttp = tp;
    }
  } else if (n == 9999) {
    /* Go to last tab page. */
    for (tp = first_tabpage; tp->tp_next != NULL; tp = tp->tp_next)
      ;
  } else {
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
    win_enter(wp, true);
  }
}

// Move the current tab page to after tab page "nr".
void tabpage_move(int nr)
{
  int n = 1;
  tabpage_T *tp;
  tabpage_T *tp_dst;

  assert(curtab != NULL);

  if (first_tabpage->tp_next == NULL) {
    return;
  }

  for (tp = first_tabpage; tp->tp_next != NULL && n < nr; tp = tp->tp_next) {
    ++n;
  }

  if (tp == curtab || (nr > 0 && tp->tp_next != NULL
                       && tp->tp_next == curtab)) {
    return;
  }

  tp_dst = tp;

  // Remove the current tab page from the list of tab pages.
  if (curtab == first_tabpage) {
    first_tabpage = curtab->tp_next;
  } else {
    tp = NULL;
    FOR_ALL_TABS(tp2) {
      if (tp2->tp_next == curtab) {
        tp = tp2;
        break;
      }
    }
    if (tp == NULL) {   // "cannot happen"
      return;
    }
    tp->tp_next = curtab->tp_next;
  }

  // Re-insert it at the specified position.
  if (nr <= 0) {
    curtab->tp_next = first_tabpage;
    first_tabpage = curtab;
  } else {
    curtab->tp_next = tp_dst->tp_next;
    tp_dst->tp_next = curtab;
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

  win_enter(wp, true);

  /* Conceal cursor line in previous window, unconceal in current window. */
  if (win_valid(owp) && owp->w_p_cole > 0 && !msg_scrolled)
    update_single_line(owp, owp->w_cursor.lnum);
  if (curwin->w_p_cole > 0 && !msg_scrolled)
    need_cursor_line_redraw = TRUE;
}


/*
 * Find the tabpage for window "win".
 */
tabpage_T *win_find_tabpage(win_T *win)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp == win) {
      return tp;
    }
  }
  return NULL;
}

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
     * First go upwards in the tree of frames until we find an upwards or
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
void win_enter(win_T *wp, bool undo_sync)
{
  win_enter_ext(wp, undo_sync, false, false, true, true);
}

/*
 * Make window wp the current window.
 * Can be called with "curwin_invalid" TRUE, which means that curwin has just
 * been closed and isn't valid.
 */
static void win_enter_ext(win_T *wp, bool undo_sync, int curwin_invalid,
                          int trigger_new_autocmds, int trigger_enter_autocmds,
                          int trigger_leave_autocmds)
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

  // sync undo before leaving the current buffer
  if (undo_sync && curbuf != wp->w_buffer) {
    u_sync(FALSE);
  }

  // Might need to scroll the old window before switching, e.g., when the
  // cursor was moved.
  update_topline();

  // may have to copy the buffer options when 'cpo' contains 'S'
  if (wp->w_buffer != curbuf) {
    buf_copy_options(wp->w_buffer, BCO_ENTER | BCO_NOHELP);
  }
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

  // New directory is either the local directory of the window, tab or NULL.
  char *new_dir = (char *)(curwin->w_localdir
                           ? curwin->w_localdir : curtab->tp_localdir);

  char cwd[MAXPATHL];
  if (os_dirname((char_u *)cwd, MAXPATHL) != OK) {
    cwd[0] = NUL;
  }

  if (new_dir) {
    // Window/tab has a local directory: Save current directory as global
    // (unless that was done already) and change to the local directory.
    if (globaldir == NULL) {
      if (cwd[0] != NUL) {
        globaldir = (char_u *)xstrdup(cwd);
      }
    }
    if (os_chdir(new_dir) == 0) {
      if (!p_acd && !strequal(new_dir, cwd)) {
        do_autocmd_dirchanged(new_dir, curwin->w_localdir
                              ? kCdScopeWindow : kCdScopeTab);
      }
      shorten_fnames(true);
    }
  } else if (globaldir != NULL) {
    // Window doesn't have a local directory and we are not in the global
    // directory: Change to the global directory.
    if (os_chdir((char *)globaldir) == 0) {
      if (!p_acd && !strequal((char *)globaldir, cwd)) {
        do_autocmd_dirchanged((char *)globaldir, kCdScopeGlobal);
      }
    }
    xfree(globaldir);
    globaldir = NULL;
    shorten_fnames(TRUE);
  }

  if (trigger_new_autocmds) {
    apply_autocmds(EVENT_WINNEW, NULL, NULL, false, curbuf);
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

  if (HL_ATTR(HLF_INACTIVE)
      || (prevwin && prevwin->w_hl_ids[HLF_INACTIVE])
      || curwin->w_hl_ids[HLF_INACTIVE]) {
    redraw_all_later(NOT_VALID);
  }

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
  do_autochdir();
}


/// Jump to the first open window that contains buffer "buf", if one exists.
/// Returns a pointer to the window found, otherwise NULL.
win_T *buf_jump_open_win(buf_T *buf)
{
  if (curwin->w_buffer == buf) {
    win_enter(curwin, false);
    return curwin;
  } else {
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == buf) {
        win_enter(wp, false);
        return wp;
      }
    }
  }

  return NULL;
}

/// Jump to the first open window in any tab page that contains buffer "buf",
/// if one exists.
/// @return the found window, or NULL.
win_T *buf_jump_open_tab(buf_T *buf)
{

  // First try the current tab page.
  {
    win_T *wp = buf_jump_open_win(buf);
    if (wp != NULL)
      return wp;
  }

  FOR_ALL_TABS(tp) {
    // Skip the current tab since we already checked it.
    if (tp == curtab) {
      continue;
    }
    FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
      if (wp->w_buffer == buf) {
        goto_tabpage_win(tp, wp);

        // If we the current window didn't switch,
        // something went wrong.
        if (curwin != wp) {
          wp = NULL;
        }

        // Return the window we switched to.
        return wp;
      }
    }
  }

  // If we made it this far, we didn't find the buffer.
  return NULL;
}

/*
 * Allocate a window structure and link it in the window list when "hidden" is
 * FALSE.
 */
static win_T *win_alloc(win_T *after, int hidden)
{
  static int last_win_id = LOWEST_WIN_ID - 1;

  // allocate window structure and linesizes arrays
  win_T *new_wp = xcalloc(1, sizeof(win_T));
  win_alloc_lines(new_wp);

  new_wp->handle = ++last_win_id;
  handle_register_window(new_wp);

  // Init w: variables.
  new_wp->w_vars = tv_dict_alloc();
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
  wininfo_T   *wip;

  handle_unregister_window(wp);
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

  if (prevwin == wp) {
    prevwin = NULL;
  }
  FOR_ALL_TABS(ttp) {
    if (ttp->tp_prevwin == wp) {
      ttp->tp_prevwin = NULL;
    }
  }

  win_free_lsize(wp);

  for (i = 0; i < wp->w_tagstacklen; ++i)
    xfree(wp->w_tagstack[i].tagname);

  xfree(wp->w_localdir);

  /* Remove the window from the b_wininfo lists, it may happen that the
   * freed memory is re-used for another window. */
  FOR_ALL_BUFFERS(buf) {
    for (wip = buf->b_wininfo; wip != NULL; wip = wip->wi_next)
      if (wip->wi_win == wp)
        wip->wi_win = NULL;
  }

  clear_matches(wp);

  free_jumplist(wp);

  qf_free_all(wp);


  xfree(wp->w_p_cc_cols);

  if (wp != aucmd_win)
    win_remove(wp, tp);
  if (autocmd_busy) {
    wp->w_next = au_pending_free_win;
    au_pending_free_win = wp;
  } else {
    xfree(wp);
  }

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
  if (wp->w_prev != NULL) {
    wp->w_prev->w_next = wp->w_next;
  } else if (tp == NULL) {
    firstwin = curtab->tp_firstwin = wp->w_next;
  } else {
    tp->tp_firstwin = wp->w_next;
  }
  if (wp->w_next != NULL) {
    wp->w_next->w_prev = wp->w_prev;
  } else if (tp == NULL) {
    lastwin = curtab->tp_lastwin = wp->w_prev;
  } else {
    tp->tp_lastwin = wp->w_prev;
  }
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
  if (frp->fr_prev != NULL) {
    frp->fr_prev->fr_next = frp->fr_next;
  } else {
    frp->fr_parent->fr_child = frp->fr_next;
    // special case: topframe->fr_child == frp
    if (topframe->fr_child == frp) {
      topframe->fr_child = frp->fr_next;
    }
  }
  if (frp->fr_next != NULL) {
    frp->fr_next->fr_prev = frp->fr_prev;
  }
}


/*
 * Allocate w_lines[] for window "wp".
 */
void win_alloc_lines(win_T *wp)
{
  wp->w_lines_valid = 0;
  assert(Rows >= 0);
  wp->w_lines = xcalloc(Rows, sizeof(wline_T));
}

/*
 * free lsize arrays for a window
 */
void win_free_lsize(win_T *wp)
{
  // TODO: why would wp be NULL here?
  if (wp != NULL) {
    xfree(wp->w_lines);
    wp->w_lines = NULL;
  }
}

/*
 * Called from win_new_shellsize() after Rows changed.
 * This only does the current tab page, others must be done when made active.
 */
void shell_new_rows(void)
{
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
void shell_new_columns(void)
{
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
  ga_init(gap, (int)sizeof(int), 1);
  ga_grow(gap, win_count() * 2);
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
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
  if (win_count() * 2 == gap->ga_len) {
    /* The order matters, because frames contain other frames, but it's
     * difficult to get right. The easy way out is to do it twice. */
    for (int j = 0; j < 2; ++j)
    {
      int i = 0;
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        frame_setwidth(wp->w_frame, ((int *)gap->ga_data)[i++]);
        win_setheight_win(((int *)gap->ga_data)[i++], wp);
      }
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
int win_comp_pos(void)
{
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
  } else {
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
  } else if (curfrp->fr_parent->fr_layout == FR_ROW) {
    /* Row of frames: Also need to resize frames left and right of this
     * one.  First check for the minimal height of these. */
    h = frame_minheight(curfrp->fr_parent, NULL);
    if (height < h)
      height = h;
    frame_setheight(curfrp->fr_parent, height);
  } else {
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
        } else {
          if (frp->fr_height - take < h) {
            take -= frp->fr_height - h;
            frame_new_height(frp, h, FALSE, FALSE);
          } else {
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
  } else {
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
        } else {
          if (frp->fr_width - take < w) {
            take -= frp->fr_width - w;
            frame_new_width(frp, w, FALSE, FALSE);
          } else {
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
void win_setminheight(void)
{
  int room;
  int first = TRUE;

  /* loop until there is a 'winminheight' that is possible */
  while (p_wmh > 0) {
    /* TODO: handle vertical splits */
    room = -p_wh;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      room += wp->w_height - p_wmh;
    }
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
    } else {
      room = 0;
      for (fr = fr->fr_child;; fr = fr->fr_next) {
        room += fr->fr_height - frame_minheight(fr, NULL);
        if (fr == curfr)
          break;
      }
    }
    fr = curfr->fr_next;                /* put fr at frame that grows */
  } else { /* drag down */
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
    } else {
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
  } else { /* drag right */
    left = FALSE;
    /* sum up the room of frames right of the current one */
    room = 0;
    for (fr = curfr->fr_next; fr != NULL; fr = fr->fr_next)
      room += fr->fr_width - frame_minwidth(fr, NULL);
    fr = curfr;                         /* put fr at window that grows */
  }
  assert(fr);

  // Not enough room
  if (room < offset) {
    offset = room;  // Move as far as we can
  }

  // No room at all, quit.
  if (offset <= 0) {
    return;
  }

  if (fr == NULL) {
    return;  // Safety check, should not happen.
  }

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
    } else {
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

// Set wp->w_fraction for the current w_wrow and w_height.
// Has no effect when the window is less than two lines.
void set_fraction(win_T *wp)
{
  if (wp->w_height > 1) {
    wp->w_fraction = ((long)wp->w_wrow * FRACTION_MULT + wp->w_height / 2)
                   / (long)wp->w_height;
  }
}

/*
 * Set the height of a window.
 * This takes care of the things inside the window, not what happens to the
 * window position, the frame or to other windows.
 */
void win_new_height(win_T *wp, int height)
{
  int prev_height = wp->w_height;

  /* Don't want a negative height.  Happens when splitting a tiny window.
   * Will equalize heights soon to fix it. */
  if (height < 0)
    height = 0;
  if (wp->w_height == height)
    return;         /* nothing to do */

  if (wp->w_height > 0) {
    if (wp == curwin) {
      // w_wrow needs to be valid. When setting 'laststatus' this may
      // call win_new_height() recursively.
      validate_cursor();
    }
    if (wp->w_height != prev_height) {  // -V547
      return;  // Recursive call already changed the size, bail out.
    }
    if (wp->w_wrow != wp->w_prev_fraction_row) {
      set_fraction(wp);
    }
  }

  wp->w_height = height;
  wp->w_skipcol = 0;

  // There is no point in adjusting the scroll position when exiting.  Some
  // values might be invalid.
  if (!exiting) {
    scroll_to_fraction(wp, prev_height);
  }
}

void scroll_to_fraction(win_T *wp, int prev_height)
{
    linenr_T lnum;
    int sline, line_size;
    int height = wp->w_height;

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
    wp->w_wrow = ((long)wp->w_fraction * (long)height - 1L + FRACTION_MULT / 2)
                 / FRACTION_MULT;
    line_size = plines_win_col(wp, lnum, (long)(wp->w_cursor.col)) - 1;
    sline = wp->w_wrow - line_size;

    if (sline >= 0) {
      // Make sure the whole cursor line is visible, if possible.
      const int rows = plines_win(wp, lnum, false);

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
          && (wp->w_width - win_col_off(wp)) > 0) {
        wp->w_skipcol += wp->w_width - win_col_off(wp);
        --wp->w_wrow;
        while (wp->w_wrow >= wp->w_height) {
          wp->w_skipcol += wp->w_width - win_col_off(wp)
                           + win_col_off2(wp);
          --wp->w_wrow;
        }
      }
      set_topline(wp, lnum);
    } else if (sline > 0) {
      while (sline > 0 && lnum > 1) {
        (void)hasFoldingWin(wp, lnum, &lnum, NULL, true, NULL);
        if (lnum == 1) {
          /* first line in buffer is folded */
          line_size = 1;
          --sline;
          break;
        }
        lnum--;
        if (lnum == wp->w_topline) {
          line_size = plines_win_nofill(wp, lnum, true)
                      + wp->w_topfill;
        } else {
          line_size = plines_win(wp, lnum, true);
        }
        sline -= line_size;
      }

      if (sline < 0) {
        /*
         * Line we want at top would go off top of screen.  Use next
         * line instead.
         */
        (void)hasFoldingWin(wp, lnum, NULL, &lnum, true, NULL);
        lnum++;
        wp->w_wrow -= line_size + sline;
      } else if (sline > 0) {
        /* First line of file reached, use that as topline. */
        lnum = 1;
        wp->w_wrow -= sline;
      }
      set_topline(wp, lnum);
    }
  }

  if (wp == curwin) {
    if (p_so)
      update_topline();
    curs_columns(FALSE);        /* validate w_wrow */
  }
  if (prev_height > 0) {
    wp->w_prev_fraction_row = wp->w_wrow;
  }

  win_comp_scroll(wp);
  redraw_win_later(wp, SOME_VALID);
  wp->w_redr_status = TRUE;
  invalidate_botline_win(wp);

  if (wp->w_buffer->terminal) {
    terminal_resize(wp->w_buffer->terminal, 0, wp->w_height);
    redraw_win_later(wp, NOT_VALID);
  }
}

/// Set the width of a window.
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

  if (wp->w_buffer->terminal) {
    if (wp->w_height != 0) {
      terminal_resize(wp->w_buffer->terminal,
                      (uint16_t)(MAX(0, wp->w_width - win_col_off(wp))),
                      0);
    }
  }
}

void win_comp_scroll(win_T *wp)
{
  wp->w_p_scr = wp->w_height / 2;
  if (wp->w_p_scr == 0)
    wp->w_p_scr = 1;
}

/*
 * command_height: called whenever p_ch has been changed
 */
void command_height(void)
{
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
        screen_fill(cmdline_row, (int)Rows, 0,
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
 * Get the file name at the cursor.
 * If Visual mode is active, use the selected text if it's in one line.
 * Returns the name in allocated memory, NULL for failure.
 */
char_u *grab_file_name(long count, linenr_T *file_lnum)
{
  int options = FNAME_MESS | FNAME_EXP | FNAME_REL | FNAME_UNESC;
  if (VIsual_active) {
    size_t len;
    char_u  *ptr;
    if (get_visual_text(NULL, &ptr, &len) == FAIL)
      return NULL;
    return find_file_name_in_path(ptr, len, options, count, curbuf->b_ffname);
  }
  return file_name_at_cursor(options | FNAME_HYP, count, file_lnum);
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
  return file_name_in_line(get_cursor_line_ptr(),
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
  size_t len;
  bool in_type = true;
  bool is_url = false;

  /*
   * search forward for what could be the start of a file name
   */
  ptr = line + col;
  while (*ptr != NUL && !vim_isfilec(*ptr)) {
    MB_PTR_ADV(ptr);
  }
  if (*ptr == NUL) {            // nothing found
    if (options & FNAME_MESS) {
      EMSG(_("E446: No file name under cursor"));
    }
    return NULL;
  }

  /*
   * Search backward for first char of the file name.
   * Go one char back to ":" before "//" even when ':' is not in 'isfname'.
   */
  while (ptr > line) {
    if ((len = (size_t)(utf_head_off(line, ptr - 1))) > 0) {
      ptr -= len + 1;
    } else if (vim_isfilec(ptr[-1])
               || ((options & FNAME_HYP) && path_is_url((char *)ptr - 1))) {
      ptr--;
    } else {
      break;
    }
  }

  /*
   * Search forward for the last char of the file name.
   * Also allow "://" when ':' is not in 'isfname'.
   */
  len = 0;
  while (vim_isfilec(ptr[len]) || (ptr[len] == '\\' && ptr[len + 1] == ' ')
         || ((options & FNAME_HYP) && path_is_url((char *)ptr + len))
         || (is_url && vim_strchr((char_u *)"?&=", ptr[len]) != NULL)) {
    // After type:// we also include ?, & and = as valid characters, so that
    // http://google.com?q=this&that=ok works.
    if ((ptr[len] >= 'A' && ptr[len] <= 'Z')
        || (ptr[len] >= 'a' && ptr[len] <= 'z')) {
      if (in_type && path_is_url((char *)ptr + len + 1)) {
        is_url = true;
      }
    } else {
      in_type = false;
    }

    if (ptr[len] == '\\' && ptr[len + 1] == ' ') {
      // Skip over the "\" in "\ ".
      ++len;
    }
    if (has_mbyte) {
      len += (size_t)(*mb_ptr2len)(ptr + len);
    } else {
      ++len;
    }
  }

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
        *file_lnum = getdigits_long(&p);
    }
  }

  return find_file_name_in_path(ptr, len, options, count, rel_fname);
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
                             || (p_ls == 1 && (morewin || !ONE_WINDOW))));
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
    } else if (wp->w_status_height == 0 && statusline) {
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
  } else if (fr->fr_layout == FR_ROW) {
    /* vertically split windows, set status line for each one */
    for (fp = fr->fr_child; fp != NULL; fp = fp->fr_next)
      last_status_rec(fp, statusline);
  } else {
    /* horizontally split window, set status line for last one */
    for (fp = fr->fr_child; fp->fr_next != NULL; fp = fp->fr_next)
      ;
    last_status_rec(fp, statusline);
  }
}

/*
 * Return the number of lines used by the tab page line.
 */
int tabline_height(void)
{
  if (ui_is_external(kUITabline)) {
    return 0;
  }
  assert(first_tabpage);
  switch (p_stal) {
  case 0: return 0;
  case 1: return (first_tabpage->tp_next == NULL) ? 0 : 1;
  }
  return 1;
}

/*
 * Return the minimal number of rows that is needed on the screen to display
 * the current number of windows.
 */
int min_rows(void)
{
  if (firstwin == NULL)         /* not initialized yet */
    return MIN_LINES;

  int total = 0;
  FOR_ALL_TABS(tp) {
    int n = frame_minheight(tp->tp_topframe, NULL);
    if (total < n) {
      total = n;
    }
  }
  total += tabline_height();
  total += 1;           /* count the room for the command line */
  return total;
}

/// Check that there is only one window (and only one tab page), not counting a
/// help or preview window, unless it is the current window. Does not count
/// "aucmd_win".
bool only_one_window(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // If there is another tab page there always is another window.
  if (first_tabpage->tp_next != NULL) {
    return false;
  }

  int count = 0;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer != NULL
        && (!((bt_help(wp->w_buffer) && !bt_help(curbuf))
              || wp->w_p_pvw) || wp == curwin) && wp != aucmd_win) {
      count++;
    }
  }
  return count <= 1;
}

/*
 * Correct the cursor line number in other windows.  Used after changing the
 * current buffer, and before applying autocommands.
 * When "do_curwin" is TRUE, also check current window.
 */
void check_lnums(int do_curwin)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if ((do_curwin || wp != curwin) && wp->w_buffer == curbuf) {
      if (wp->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        wp->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      }
      if (wp->w_topline > curbuf->b_ml.ml_line_count) {
        wp->w_topline = curbuf->b_ml.ml_line_count;
      }
    }
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
  *frp = xcalloc(1, sizeof(frame_T));
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
    xfree(fr);
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
    redraw_all_later(NOT_VALID);
  }
  clear_snapshot(curtab, idx);
}

/// Check if frames "sn" and "fr" have the same layout, same following frames
/// and same children.  And the window pointer is valid.
static int check_snapshot_rec(frame_T *sn, frame_T *fr)
{
  if (sn->fr_layout != fr->fr_layout
      || (sn->fr_next == NULL) != (fr->fr_next == NULL)
      || (sn->fr_child == NULL) != (fr->fr_child == NULL)
      || (sn->fr_next != NULL
          && check_snapshot_rec(sn->fr_next, fr->fr_next) == FAIL)
      || (sn->fr_child != NULL
          && check_snapshot_rec(sn->fr_child, fr->fr_child) == FAIL)
      || (sn->fr_win != NULL && !win_valid(sn->fr_win)))
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

/// Gets the focused window (the one holding the cursor) of the snapshot.
static win_T *get_snapshot_focus(int idx)
{
  if (curtab->tp_snapshot[idx] == NULL) {
    return NULL;
  }

  frame_T *sn = curtab->tp_snapshot[idx];
  // This should be equivalent to the recursive algorithm found in
  // restore_snapshot as far as traveling nodes go.
  while (sn->fr_child != NULL || sn->fr_next != NULL) {
    while (sn->fr_child != NULL) {
      sn = sn->fr_child;
    }
    if (sn->fr_next != NULL) {
      sn = sn->fr_next;
    }
  }

  return sn->fr_win;
}

/*
 * Set "win" to be the curwin and "tp" to be the current tab page.
 * restore_win() MUST be called to undo, also when FAIL is returned.
 * No autocommands will be executed until restore_win() is called.
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
    return FAIL;
  }
  curwin = win;
  curbuf = curwin->w_buffer;
  return OK;
}

// Restore current tabpage and window saved by switch_win(), if still valid.
// When "no_display" is true the display won't be affected, no redraw is
// triggered.
void restore_win(win_T *save_curwin, tabpage_T *save_curtab, bool no_display)
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

/// Make "buf" the current buffer.
///
/// restore_buffer() MUST be called to undo.
/// No autocommands will be executed. Use aucmd_prepbuf() if there are any.
void switch_buffer(bufref_T *save_curbuf, buf_T *buf)
{
  block_autocmds();
  set_bufref(save_curbuf, curbuf);
  curbuf->b_nwindows--;
  curbuf = buf;
  curwin->w_buffer = buf;
  curbuf->b_nwindows++;
}

/// Restore the current buffer after using switch_buffer().
void restore_buffer(bufref_T *save_curbuf)
{
  unblock_autocmds();
  // Check for valid buffer, just in case.
  if (bufref_valid(save_curbuf)) {
    curbuf->b_nwindows--;
    curwin->w_buffer = save_curbuf->br_buf;
    curbuf = save_curbuf->br_buf;
    curbuf->b_nwindows++;
  }
}


/// Add match to the match list of window 'wp'.  The pattern 'pat' will be
/// highlighted with the group 'grp' with priority 'prio'.
/// Optionally, a desired ID 'id' can be specified (greater than or equal to 1).
///
/// @param[in] id a desired ID 'id' can be specified
///               (greater than or equal to 1). -1 must be specified if no
///               particular ID is desired
/// @return ID of added match, -1 on failure.
int match_add(win_T *wp, const char *const grp, const char *const pat,
              int prio, int id, list_T *pos_list,
              const char *const conceal_char)
{
  matchitem_T *cur;
  matchitem_T *prev;
  matchitem_T *m;
  int hlg_id;
  regprog_T   *regprog = NULL;
  int rtype = SOME_VALID;

  if (*grp == NUL || (pat != NULL && *pat == NUL)) {
    return -1;
  }
  if (id < -1 || id == 0) {
    EMSGN(_("E799: Invalid ID: %" PRId64
            " (must be greater than or equal to 1)"),
          id);
    return -1;
  }
  if (id != -1) {
    cur = wp->w_match_head;
    while (cur != NULL) {
      if (cur->id == id) {
        EMSGN(_("E801: ID already taken: %" PRId64), id);
        return -1;
      }
      cur = cur->next;
    }
  }
  if ((hlg_id = syn_name2id((const char_u *)grp)) == 0) {
    EMSG2(_(e_nogroup), grp);
    return -1;
  }
  if (pat != NULL && (regprog = vim_regcomp((char_u *)pat, RE_MAGIC)) == NULL) {
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
  m = xcalloc(1, sizeof(matchitem_T));
  m->id = id;
  m->priority = prio;
  m->pattern = pat == NULL ? NULL: (char_u *)xstrdup(pat);
  m->hlg_id = hlg_id;
  m->match.regprog = regprog;
  m->match.rmm_ic = FALSE;
  m->match.rmm_maxcol = 0;
  m->conceal_char = 0;
  if (conceal_char != NULL) {
    m->conceal_char = utf_ptr2char((const char_u *)conceal_char);
  }

  // Set up position matches
  if (pos_list != NULL) {
    linenr_T toplnum = 0;
    linenr_T botlnum = 0;

    int i = 0;
    TV_LIST_ITER(pos_list, li, {
      linenr_T lnum = 0;
      colnr_T col = 0;
      int len = 1;
      bool error = false;

      if (TV_LIST_ITEM_TV(li)->v_type == VAR_LIST) {
        const list_T *const subl = TV_LIST_ITEM_TV(li)->vval.v_list;
        const listitem_T *subli = tv_list_first(subl);
        if (subli == NULL) {
          emsgf(_("E5030: Empty list at position %d"),
                (int)tv_list_idx_of_item(pos_list, li));
          goto fail;
        }
        lnum = tv_get_number_chk(TV_LIST_ITEM_TV(subli), &error);
        if (error) {
          goto fail;
        }
        if (lnum <= 0) {
          continue;
        }
        m->pos.pos[i].lnum = lnum;
        subli = TV_LIST_ITEM_NEXT(subl, subli);
        if (subli != NULL) {
          col = tv_get_number_chk(TV_LIST_ITEM_TV(subli), &error);
          if (error) {
            goto fail;
          }
          if (col < 0) {
            continue;
          }
          subli = TV_LIST_ITEM_NEXT(subl, subli);
          if (subli != NULL) {
            len = tv_get_number_chk(TV_LIST_ITEM_TV(subli), &error);
            if (len < 0) {
              continue;
            }
            if (error) {
              goto fail;
            }
          }
        }
        m->pos.pos[i].col = col;
        m->pos.pos[i].len = len;
      } else if (TV_LIST_ITEM_TV(li)->v_type == VAR_NUMBER) {
        if (TV_LIST_ITEM_TV(li)->vval.v_number <= 0) {
          continue;
        }
        m->pos.pos[i].lnum = TV_LIST_ITEM_TV(li)->vval.v_number;
        m->pos.pos[i].col = 0;
        m->pos.pos[i].len = 0;
      } else {
        emsgf(_("E5031: List or number required at position %d"),
              (int)tv_list_idx_of_item(pos_list, li));
        goto fail;
      }
      if (toplnum == 0 || lnum < toplnum) {
        toplnum = lnum;
      }
      if (botlnum == 0 || lnum >= botlnum) {
        botlnum = lnum + 1;
      }
      i++;
      if (i >= MAXPOSMATCH) {
        break;
      }
    });

    // Calculate top and bottom lines for redrawing area 
    if (toplnum != 0){
      if (wp->w_buffer->b_mod_set) {
        if (wp->w_buffer->b_mod_top > toplnum) {
          wp->w_buffer->b_mod_top = toplnum;
        }
        if (wp->w_buffer->b_mod_bot < botlnum) {
          wp->w_buffer->b_mod_bot = botlnum;
        }
      } else {
        wp->w_buffer->b_mod_set = true;
        wp->w_buffer->b_mod_top = toplnum;
        wp->w_buffer->b_mod_bot = botlnum;
        wp->w_buffer->b_mod_xlines = 0;
      }
      m->pos.toplnum = toplnum;
      m->pos.botlnum = botlnum;
      rtype = VALID;
    }
  }
 
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

  redraw_later(rtype);
  return id;

fail:
  xfree(m);
  return -1;
}


/// Delete match with ID 'id' in the match list of window 'wp'.
/// Print error messages if 'perr' is TRUE.
int match_delete(win_T *wp, int id, int perr)
{
  matchitem_T *cur = wp->w_match_head;
  matchitem_T *prev = cur;
  int rtype = SOME_VALID;

  if (id < 1) {
    if (perr) {
      EMSGN(_("E802: Invalid ID: %" PRId64
              " (must be greater than or equal to 1)"),
            id);
    }
    return -1;
  }
  while (cur != NULL && cur->id != id) {
    prev = cur;
    cur = cur->next;
  }
  if (cur == NULL) {
    if (perr) {
      EMSGN(_("E803: ID not found: %" PRId64), id);
    }
    return -1;
  }
  if (cur == prev)
    wp->w_match_head = cur->next;
  else
    prev->next = cur->next;
  vim_regfree(cur->match.regprog);
  xfree(cur->pattern);
  if (cur->pos.toplnum != 0) {
    if (wp->w_buffer->b_mod_set) {
      if (wp->w_buffer->b_mod_top > cur->pos.toplnum) {
        wp->w_buffer->b_mod_top = cur->pos.toplnum;
      }
      if (wp->w_buffer->b_mod_bot < cur->pos.botlnum) {
        wp->w_buffer->b_mod_bot = cur->pos.botlnum;
      }
    } else {
      wp->w_buffer->b_mod_set = true;
      wp->w_buffer->b_mod_top = cur->pos.toplnum;
      wp->w_buffer->b_mod_bot = cur->pos.botlnum;
      wp->w_buffer->b_mod_xlines = 0;
    }
    rtype = VALID;
  }
  xfree(cur);
  redraw_later(rtype);
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
    xfree(wp->w_match_head->pattern);
    xfree(wp->w_match_head);
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


/// Check that "topfrp" and its children are at the right height.
///
/// @param  topfrp  top frame pointer
/// @param  height  expected height
static bool frame_check_height(frame_T *topfrp, int height)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (topfrp->fr_height != height) {
    return false;
  }
  if (topfrp->fr_layout == FR_ROW) {
    for (frame_T *frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
      if (frp->fr_height != height) {
        return false;
      }
    }
  }
  return true;
}

/// Check that "topfrp" and its children are at the right width.
///
/// @param  topfrp  top frame pointer
/// @param  width   expected width
static bool frame_check_width(frame_T *topfrp, int width)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (topfrp->fr_width != width) {
    return false;
  }
  if (topfrp->fr_layout == FR_COL) {
    for (frame_T *frp = topfrp->fr_child; frp != NULL; frp = frp->fr_next) {
      if (frp->fr_width != width) {
        return false;
      }
    }
  }
  return true;
}

int win_getid(typval_T *argvars)
{
  if (argvars[0].v_type == VAR_UNKNOWN) {
    return curwin->handle;
  }
  int winnr = tv_get_number(&argvars[0]);
  win_T *wp;
  if (winnr > 0) {
    if (argvars[1].v_type == VAR_UNKNOWN) {
      wp = firstwin;
    } else {
      tabpage_T *tp = NULL;
      int tabnr = tv_get_number(&argvars[1]);
      FOR_ALL_TABS(tp2) {
        if (--tabnr == 0) {
          tp = tp2;
          break;
        }
      }
      if (tp == NULL) {
        return -1;
      }
      if (tp == curtab) {
        wp = firstwin;
      } else {
        wp = tp->tp_firstwin;
      }
    }
    for ( ; wp != NULL; wp = wp->w_next) {
      if (--winnr == 0) {
        return wp->handle;
      }
    }
  }
  return 0;
}

int win_gotoid(typval_T *argvars)
{
  int id = tv_get_number(&argvars[0]);

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->handle == id) {
      goto_tabpage_win(tp, wp);
      return 1;
    }
  }
  return 0;
}

void win_get_tabwin(handle_T id, int *tabnr, int *winnr)
{
  *tabnr = 0;
  *winnr = 0;

  int tnum = 1, wnum = 1;
  FOR_ALL_TABS(tp) {
    FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
      if (wp->handle == id) {
        *winnr = wnum;
        *tabnr = tnum;
        return;
      }
      wnum++;
    }
    tnum++;
    wnum = 1;
  }
}

void win_id2tabwin(typval_T *const argvars, typval_T *const rettv)
{
  int winnr = 1;
  int tabnr = 1;
  handle_T id = (handle_T)tv_get_number(&argvars[0]);

  win_get_tabwin(id, &tabnr, &winnr);

  list_T *const list = tv_list_alloc_ret(rettv, 2);
  tv_list_append_number(list, tabnr);
  tv_list_append_number(list, winnr);
}

win_T * win_id2wp(typval_T *argvars)
{
  int id = tv_get_number(&argvars[0]);

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->handle == id) {
      return wp;
    }
  }

  return NULL;
}

int win_id2win(typval_T *argvars)
{
  int nr = 1;
  int id = tv_get_number(&argvars[0]);

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->handle == id) {
      return nr;
    }
    nr++;
  }
  return 0;
}

void win_findbuf(typval_T *argvars, list_T *list)
{
  int bufnr = tv_get_number(&argvars[0]);

  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer->b_fnum == bufnr) {
      tv_list_append_number(list, wp->handle);
    }
  }
}
