#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/arglist.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/decoration.h"
#include "nvim/diff.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/vars.h"
#include "nvim/eval/window.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/file_search.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/hashtab.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/match.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/os_defs.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/pos_defs.h"
#include "nvim/quickfix.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "window.c.generated.h"
#endif

#define NOWIN           ((win_T *)-1)   // non-existing window

#define ROWS_AVAIL (Rows - p_ch - tabline_height() - global_stl_height())

/// flags for win_enter_ext()
typedef enum {
  WEE_UNDO_SYNC = 0x01,
  WEE_CURWIN_INVALID = 0x02,
  WEE_TRIGGER_NEW_AUTOCMDS = 0x04,
  WEE_TRIGGER_ENTER_AUTOCMDS = 0x08,
  WEE_TRIGGER_LEAVE_AUTOCMDS = 0x10,
} wee_flags_T;

static const char e_cannot_split_window_when_closing_buffer[]
  = N_("E1159: Cannot split a window when closing the buffer");

static char *m_onlyone = N_("Already only one window");

/// When non-zero splitting a window is forbidden.  Used to avoid that nasty
/// autocommands mess up the window structure.
static int split_disallowed = 0;

// #define WIN_DEBUG
#ifdef WIN_DEBUG
/// Call this method to log the current window layout.
static void log_frame_layout(frame_T *frame)
{
  DLOG("layout %s, wi: %d, he: %d, wwi: %d, whe: %d, id: %d",
       frame->fr_layout == FR_LEAF ? "LEAF" : frame->fr_layout == FR_ROW ? "ROW" : "COL",
       frame->fr_width,
       frame->fr_height,
       frame->fr_win == NULL ? -1 : frame->fr_win->w_width,
       frame->fr_win == NULL ? -1 : frame->fr_win->w_height,
       frame->fr_win == NULL ? -1 : frame->fr_win->w_id);
  if (frame->fr_child != NULL) {
    DLOG("children");
    log_frame_layout(frame->fr_child);
    if (frame->fr_next != NULL) {
      DLOG("END of children");
    }
  }
  if (frame->fr_next != NULL) {
    log_frame_layout(frame->fr_next);
  }
}
#endif

/// Check if the current window is allowed to move to a different buffer.
///
/// @return If the window has 'winfixbuf', or this function will return false.
bool check_can_set_curbuf_disabled(void)
{
  if (curwin->w_p_wfb) {
    emsg(_(e_winfixbuf_cannot_go_to_buffer));
    return false;
  }

  return true;
}

/// Check if the current window is allowed to move to a different buffer.
///
/// @param forceit If true, do not error. If false and 'winfixbuf' is enabled, error.
///
/// @return If the window has 'winfixbuf', then forceit must be true
///     or this function will return false.
bool check_can_set_curbuf_forceit(int forceit)
{
  if (!forceit && curwin->w_p_wfb) {
    emsg(_(e_winfixbuf_cannot_go_to_buffer));
    return false;
  }

  return true;
}

/// @return the current window, unless in the cmdline window and "prevwin" is
/// set, then return "prevwin".
win_T *prevwin_curwin(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  // In cmdwin, the alternative buffer should be used.
  return is_in_cmdwin() && prevwin != NULL ? prevwin : curwin;
}

/// If the 'switchbuf' option contains "useopen" or "usetab", then try to jump
/// to a window containing "buf".
/// Returns the pointer to the window that was jumped to or NULL.
win_T *swbuf_goto_win_with_buf(buf_T *buf)
{
  win_T *wp = NULL;

  if (buf == NULL) {
    return wp;
  }

  // If 'switchbuf' contains "useopen": jump to first window in the current
  // tab page containing "buf" if one exists.
  if (swb_flags & SWB_USEOPEN) {
    wp = buf_jump_open_win(buf);
  }

  // If 'switchbuf' contains "usetab": jump to first window in any tab page
  // containing "buf" if one exists.
  if (wp == NULL && (swb_flags & SWB_USETAB)) {
    wp = buf_jump_open_tab(buf);
  }

  return wp;
}

/// all CTRL-W window commands are handled here, called from normal_cmd().
///
/// @param xchar  extra char from ":wincmd gx" or NUL
void do_window(int nchar, int Prenum, int xchar)
{
  int type = FIND_DEFINE;
  char cbuf[40];

  int Prenum1 = Prenum == 0 ? 1 : Prenum;

#define CHECK_CMDWIN \
  do { \
    if (cmdwin_type != 0) { \
      emsg(_(e_cmdwin)); \
      return; \
    } \
  } while (0)

  switch (nchar) {
  // split current window in two parts, horizontally
  case 'S':
  case Ctrl_S:
  case 's':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode
    // When splitting the quickfix window open a new buffer in it,
    // don't replicate the quickfix buffer.
    if (bt_quickfix(curbuf)) {
      goto newwindow;
    }
    win_split(Prenum, 0);
    break;

  // split current window in two parts, vertically
  case Ctrl_V:
  case 'v':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode
    // When splitting the quickfix window open a new buffer in it,
    // don't replicate the quickfix buffer.
    if (bt_quickfix(curbuf)) {
      goto newwindow;
    }
    win_split(Prenum, WSP_VERT);
    break;

  // split current window and edit alternate file
  case Ctrl_HAT:
  case '^':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode

    if (buflist_findnr(Prenum == 0 ? curwin->w_alt_fnum : Prenum) == NULL) {
      if (Prenum == 0) {
        emsg(_(e_noalt));
      } else {
        semsg(_("E92: Buffer %" PRId64 " not found"), (int64_t)Prenum);
      }
      break;
    }

    if (!curbuf_locked() && win_split(0, 0) == OK) {
      buflist_getfile(Prenum == 0 ? curwin->w_alt_fnum : Prenum,
                      0, GETF_ALT, false);
    }
    break;

  // open new window
  case Ctrl_N:
  case 'n':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode
newwindow:
    if (Prenum) {
      // window height
      vim_snprintf(cbuf, sizeof(cbuf) - 5, "%" PRId64, (int64_t)Prenum);
    } else {
      cbuf[0] = NUL;
    }
    if (nchar == 'v' || nchar == Ctrl_V) {
      xstrlcat(cbuf, "v", sizeof(cbuf));
    }
    xstrlcat(cbuf, "new", sizeof(cbuf));
    do_cmdline_cmd(cbuf);
    break;

  // quit current window
  case Ctrl_Q:
  case 'q':
    reset_VIsual_and_resel();                   // stop Visual mode
    cmd_with_count("quit", cbuf, sizeof(cbuf), Prenum);
    do_cmdline_cmd(cbuf);
    break;

  // close current window
  case Ctrl_C:
  case 'c':
    reset_VIsual_and_resel();                   // stop Visual mode
    cmd_with_count("close", cbuf, sizeof(cbuf), Prenum);
    do_cmdline_cmd(cbuf);
    break;

  // close preview window
  case Ctrl_Z:
  case 'z':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode
    do_cmdline_cmd("pclose");
    break;

  // cursor to preview window
  case 'P': {
    win_T *wp = NULL;
    FOR_ALL_WINDOWS_IN_TAB(wp2, curtab) {
      if (wp2->w_p_pvw) {
        wp = wp2;
        break;
      }
    }
    if (wp == NULL) {
      emsg(_("E441: There is no preview window"));
    } else {
      win_goto(wp);
    }
    break;
  }

  // close all but current window
  case Ctrl_O:
  case 'o':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode
    cmd_with_count("only", cbuf, sizeof(cbuf), Prenum);
    do_cmdline_cmd(cbuf);
    break;

  // cursor to next window with wrap around
  case Ctrl_W:
  case 'w':
  // cursor to previous window with wrap around
  case 'W':
    CHECK_CMDWIN;
    if (ONE_WINDOW && Prenum != 1) {  // just one window
      beep_flush();
    } else {
      win_T *wp;
      if (Prenum) {  // go to specified window
        for (wp = firstwin; --Prenum > 0;) {
          if (wp->w_next == NULL) {
            break;
          }
          wp = wp->w_next;
        }
      } else {
        if (nchar == 'W') {  // go to previous window
          wp = curwin->w_prev;
          if (wp == NULL) {
            wp = lastwin;  // wrap around
          }
          while (wp != NULL && wp->w_floating
                 && !wp->w_config.focusable) {
            wp = wp->w_prev;
          }
        } else {  // go to next window
          wp = curwin->w_next;
          while (wp != NULL && wp->w_floating
                 && !wp->w_config.focusable) {
            wp = wp->w_next;
          }
          if (wp == NULL) {
            wp = firstwin;  // wrap around
          }
        }
      }
      win_goto(wp);
    }
    break;

  // cursor to window below
  case 'j':
  case K_DOWN:
  case Ctrl_J:
    CHECK_CMDWIN;
    win_goto_ver(false, Prenum1);
    break;

  // cursor to window above
  case 'k':
  case K_UP:
  case Ctrl_K:
    CHECK_CMDWIN;
    win_goto_ver(true, Prenum1);
    break;

  // cursor to left window
  case 'h':
  case K_LEFT:
  case Ctrl_H:
  case K_BS:
    CHECK_CMDWIN;
    win_goto_hor(true, Prenum1);
    break;

  // cursor to right window
  case 'l':
  case K_RIGHT:
  case Ctrl_L:
    CHECK_CMDWIN;
    win_goto_hor(false, Prenum1);
    break;

  // move window to new tab page
  case 'T':
    CHECK_CMDWIN;
    if (one_window(curwin)) {
      msg(_(m_onlyone), 0);
    } else {
      tabpage_T *oldtab = curtab;

      // First create a new tab with the window, then go back to
      // the old tab and close the window there.
      win_T *wp = curwin;
      if (win_new_tabpage(Prenum, NULL) == OK
          && valid_tabpage(oldtab)) {
        tabpage_T *newtab = curtab;
        goto_tabpage_tp(oldtab, true, true);
        if (curwin == wp) {
          win_close(curwin, false, false);
        }
        if (valid_tabpage(newtab)) {
          goto_tabpage_tp(newtab, true, true);
          apply_autocmds(EVENT_TABNEWENTERED, NULL, NULL, false, curbuf);
        }
      }
    }
    break;

  // cursor to top-left window
  case 't':
  case Ctrl_T:
    win_goto(firstwin);
    break;

  // cursor to bottom-right window
  case 'b':
  case Ctrl_B:
    win_goto(lastwin_nofloating());
    break;

  // cursor to last accessed (previous) window
  case 'p':
  case Ctrl_P:
    if (!win_valid(prevwin)) {
      beep_flush();
    } else {
      win_goto(prevwin);
    }
    break;

  // exchange current and next window
  case 'x':
  case Ctrl_X:
    CHECK_CMDWIN;
    win_exchange(Prenum);
    break;

  // rotate windows downwards
  case Ctrl_R:
  case 'r':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode
    win_rotate(false, Prenum1);  // downwards
    break;

  // rotate windows upwards
  case 'R':
    CHECK_CMDWIN;
    reset_VIsual_and_resel();  // stop Visual mode
    win_rotate(true, Prenum1);  // upwards
    break;

  // move window to the very top/bottom/left/right
  case 'K':
  case 'J':
  case 'H':
  case 'L':
    CHECK_CMDWIN;
    if (one_window(curwin)) {
      beep_flush();
    } else {
      const int dir = ((nchar == 'H' || nchar == 'L') ? WSP_VERT : 0)
                      | ((nchar == 'H' || nchar == 'K') ? WSP_TOP : WSP_BOT);

      win_splitmove(curwin, Prenum, dir);
    }
    break;

  // make all windows the same width and/or height
  case '=': {
    int mod = cmdmod.cmod_split & (WSP_VERT | WSP_HOR);
    win_equal(NULL, false, mod == WSP_VERT ? 'v' : mod == WSP_HOR ? 'h' : 'b');
    break;
  }

  // increase current window height
  case '+':
    win_setheight(curwin->w_height + Prenum1);
    break;

  // decrease current window height
  case '-':
    win_setheight(curwin->w_height - Prenum1);
    break;

  // set current window height
  case Ctrl__:
  case '_':
    win_setheight(Prenum ? Prenum : Rows - 1);
    break;

  // increase current window width
  case '>':
    win_setwidth(curwin->w_width + Prenum1);
    break;

  // decrease current window width
  case '<':
    win_setwidth(curwin->w_width - Prenum1);
    break;

  // set current window width
  case '|':
    win_setwidth(Prenum != 0 ? Prenum : Columns);
    break;

  // jump to tag and split window if tag exists (in preview window)
  case '}':
    CHECK_CMDWIN;
    if (Prenum) {
      g_do_tagpreview = Prenum;
    } else {
      g_do_tagpreview = (int)p_pvh;
    }
    FALLTHROUGH;
  case ']':
  case Ctrl_RSB:
    CHECK_CMDWIN;
    // Keep visual mode, can select words to use as a tag.
    if (Prenum) {
      postponed_split = Prenum;
    } else {
      postponed_split = -1;
    }

    if (nchar != '}') {
      g_do_tagpreview = 0;
    }

    // Execute the command right here, required when
    // "wincmd ]" was used in a function.
    do_nv_ident(Ctrl_RSB, NUL);
    postponed_split = 0;
    break;

  // edit file name under cursor in a new window
  case 'f':
  case 'F':
  case Ctrl_F: {
wingotofile:
    CHECK_CMDWIN;
    if (check_text_or_curbuf_locked(NULL)) {
      break;
    }

    linenr_T lnum = -1;
    char *ptr = grab_file_name(Prenum1, &lnum);
    if (ptr != NULL) {
      tabpage_T *oldtab = curtab;
      win_T *oldwin = curwin;
      setpcmark();

      // If 'switchbuf' is set to 'useopen' or 'usetab' and the
      // file is already opened in a window, then jump to it.
      win_T *wp = NULL;
      if ((swb_flags & (SWB_USEOPEN | SWB_USETAB))
          && cmdmod.cmod_tab == 0) {
        wp = swbuf_goto_win_with_buf(buflist_findname_exp(ptr));
      }

      if (wp == NULL && win_split(0, 0) == OK) {
        RESET_BINDING(curwin);
        if (do_ecmd(0, ptr, NULL, NULL, ECMD_LASTL, ECMD_HIDE, NULL) == FAIL) {
          // Failed to open the file, close the window opened for it.
          win_close(curwin, false, false);
          goto_tabpage_win(oldtab, oldwin);
        } else {
          wp = curwin;
        }
      }

      if (wp != NULL && nchar == 'F' && lnum >= 0) {
        curwin->w_cursor.lnum = lnum;
        check_cursor_lnum(curwin);
        beginline(BL_SOL | BL_FIX);
      }
      xfree(ptr);
    }
    break;
  }

  // Go to the first occurrence of the identifier under cursor along path in a
  // new window -- webb
  case 'i':                         // Go to any match
  case Ctrl_I:
    type = FIND_ANY;
    FALLTHROUGH;
  case 'd':                         // Go to definition, using 'define'
  case Ctrl_D: {
    CHECK_CMDWIN;
    size_t len;
    char *ptr;
    if ((len = find_ident_under_cursor(&ptr, FIND_IDENT)) == 0) {
      break;
    }

    // Make a copy, if the line was changed it will be freed.
    ptr = xmemdupz(ptr, len);

    find_pattern_in_path(ptr, 0, len, true, Prenum == 0,
                         type, Prenum1, ACTION_SPLIT, 1, MAXLNUM, false);
    xfree(ptr);
    curwin->w_set_curswant = true;
    break;
  }

  // Quickfix window only: view the result under the cursor in a new split.
  case K_KENTER:
  case CAR:
    if (bt_quickfix(curbuf)) {
      qf_view_result(true);
    }
    break;

  // CTRL-W g  extended commands
  case 'g':
  case Ctrl_G:
    CHECK_CMDWIN;
    no_mapping++;
    allow_keys++;               // no mapping for xchar, but allow key codes
    if (xchar == NUL) {
      xchar = plain_vgetc();
    }
    LANGMAP_ADJUST(xchar, true);
    no_mapping--;
    allow_keys--;
    add_to_showcmd(xchar);

    switch (xchar) {
    case '}':
      xchar = Ctrl_RSB;
      if (Prenum) {
        g_do_tagpreview = Prenum;
      } else {
        g_do_tagpreview = (int)p_pvh;
      }
      FALLTHROUGH;
    case ']':
    case Ctrl_RSB:
      // Keep visual mode, can select words to use as a tag.
      if (Prenum) {
        postponed_split = Prenum;
      } else {
        postponed_split = -1;
      }

      // Execute the command right here, required when
      // "wincmd g}" was used in a function.
      do_nv_ident('g', xchar);
      postponed_split = 0;
      break;

    case 'f':                       // CTRL-W gf: "gf" in a new tab page
    case 'F':                       // CTRL-W gF: "gF" in a new tab page
      cmdmod.cmod_tab = tabpage_index(curtab) + 1;
      nchar = xchar;
      goto wingotofile;

    case 't':                       // CTRL-W gt: go to next tab page
      goto_tabpage(Prenum);
      break;

    case 'T':                       // CTRL-W gT: go to previous tab page
      goto_tabpage(-Prenum1);
      break;

    case TAB:                       // CTRL-W g<Tab>: go to last used tab page
      if (!goto_tabpage_lastused()) {
        beep_flush();
      }
      break;

    case 'e':
      if (curwin->w_floating || !ui_has(kUIMultigrid)) {
        beep_flush();
        break;
      }
      WinConfig config = WIN_CONFIG_INIT;
      config.width = curwin->w_width;
      config.height = curwin->w_height;
      config.external = true;
      Error err = ERROR_INIT;
      if (!win_new_float(curwin, false, config, &err)) {
        emsg(err.msg);
        api_clear_error(&err);
        beep_flush();
      }
      break;
    default:
      beep_flush();
      break;
    }
    break;

  default:
    beep_flush();
    break;
  }
}

static void cmd_with_count(char *cmd, char *bufp, size_t bufsize, int64_t Prenum)
{
  size_t len = xstrlcpy(bufp, cmd, bufsize);

  if (Prenum > 0 && len < bufsize) {
    vim_snprintf(bufp + len, bufsize - len, "%" PRId64, Prenum);
  }
}

void win_set_buf(win_T *win, buf_T *buf, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  tabpage_T *tab = win_find_tabpage(win);

  // no redrawing and don't set the window title
  RedrawingDisabled++;

  switchwin_T switchwin;
  if (switch_win_noblock(&switchwin, win, tab, true) == FAIL) {
    api_set_error(err,
                  kErrorTypeException,
                  "Failed to switch to window %d",
                  win->handle);
    goto cleanup;
  }

  try_start();

  const int save_acd = p_acd;
  if (!switchwin.sw_same_win) {
    // Temporarily disable 'autochdir' when setting buffer in another window.
    p_acd = false;
  }

  int result = do_buffer(DOBUF_GOTO, DOBUF_FIRST, FORWARD, buf->b_fnum, 0);

  if (!switchwin.sw_same_win) {
    p_acd = save_acd;
  }

  if (!try_end(err) && result == FAIL) {
    api_set_error(err,
                  kErrorTypeException,
                  "Failed to set buffer %d",
                  buf->handle);
  }

  // If window is not current, state logic will not validate its cursor. So do it now.
  // Still needed if do_buffer returns FAIL (e.g: autocmds abort script after buffer was set).
  validate_cursor(curwin);

cleanup:
  restore_win_noblock(&switchwin, true);
  RedrawingDisabled--;
}

/// Return the number of fold columns to display
int win_fdccol_count(win_T *wp)
{
  const char *fdc = wp->w_p_fdc;

  // auto:<NUM>
  if (strncmp(fdc, "auto", 4) == 0) {
    const int fdccol = fdc[4] == ':' ? fdc[5] - '0' : 1;
    int needed_fdccols = getDeepestNesting(wp);
    return MIN(fdccol, needed_fdccols);
  }
  return fdc[0] - '0';
}

void ui_ext_win_position(win_T *wp, bool validate)
{
  wp->w_pos_changed = false;
  if (!wp->w_floating) {
    ui_call_win_pos(wp->w_grid_alloc.handle, wp->handle, wp->w_winrow,
                    wp->w_wincol, wp->w_width, wp->w_height);
    return;
  }

  WinConfig c = wp->w_config;
  if (!c.external) {
    ScreenGrid *grid = &default_grid;
    Float row = c.row;
    Float col = c.col;
    if (c.relative == kFloatRelativeWindow) {
      Error dummy = ERROR_INIT;
      win_T *win = find_window_by_handle(c.window, &dummy);
      api_clear_error(&dummy);
      if (win != NULL) {
        // When a floating window is anchored to another window,
        // update the position of its anchored window first.
        if (win->w_pos_changed && win->w_grid_alloc.chars != NULL && win_valid(win)) {
          ui_ext_win_position(win, validate);
        }
        grid = &win->w_grid;
        int row_off = 0;
        int col_off = 0;
        grid_adjust(&grid, &row_off, &col_off);
        row += row_off;
        col += col_off;
        if (c.bufpos.lnum >= 0) {
          pos_T pos = { c.bufpos.lnum + 1, c.bufpos.col, 0 };
          int trow, tcol, tcolc, tcole;
          textpos2screenpos(win, &pos, &trow, &tcol, &tcolc, &tcole, true);
          row += trow - 1;
          col += tcol - 1;
        }
      }
    }

    wp->w_grid_alloc.zindex = wp->w_config.zindex;
    if (ui_has(kUIMultigrid)) {
      String anchor = cstr_as_string(float_anchor_str[c.anchor]);
      if (!c.hide) {
        ui_call_win_float_pos(wp->w_grid_alloc.handle, wp->handle, anchor,
                              grid->handle, row, col, c.focusable,
                              wp->w_grid_alloc.zindex);
      } else {
        ui_call_win_hide(wp->w_grid_alloc.handle);
      }
    } else {
      bool valid = (wp->w_redr_type == 0);
      if (!valid && !validate) {
        wp->w_pos_changed = true;
        return;
      }
      // TODO(bfredl): ideally, compositor should work like any multigrid UI
      // and use standard win_pos events.
      bool east = c.anchor & kFloatAnchorEast;
      bool south = c.anchor & kFloatAnchorSouth;

      int comp_row = (int)row - (south ? wp->w_height_outer : 0);
      int comp_col = (int)col - (east ? wp->w_width_outer : 0);
      int above_ch = wp->w_config.zindex < kZIndexMessages ? (int)p_ch : 0;
      comp_row += grid->comp_row;
      comp_col += grid->comp_col;
      comp_row = MAX(MIN(comp_row, Rows - wp->w_height_outer - above_ch), 0);
      if (!c.fixed || east) {
        comp_col = MAX(MIN(comp_col, Columns - wp->w_width_outer), 0);
      }
      wp->w_winrow = comp_row;
      wp->w_wincol = comp_col;

      if (!c.hide) {
        ui_comp_put_grid(&wp->w_grid_alloc, comp_row, comp_col,
                         wp->w_height_outer, wp->w_width_outer, valid, false);
        ui_check_cursor_grid(wp->w_grid_alloc.handle);
        wp->w_grid_alloc.focusable = wp->w_config.focusable;
        if (!valid) {
          wp->w_grid_alloc.valid = false;
          redraw_later(wp, UPD_NOT_VALID);
        }
      } else {
        ui_comp_remove_grid(&wp->w_grid_alloc);
      }
    }
  } else {
    ui_call_win_external_pos(wp->w_grid_alloc.handle, wp->handle);
  }
}

void ui_ext_win_viewport(win_T *wp)
{
  // NOTE: The win_viewport command is delayed until the next flush when there are pending updates.
  // This ensures that the updates and the viewport are sent together.
  if ((wp == curwin || ui_has(kUIMultigrid)) && wp->w_viewport_invalid && wp->w_redr_type == 0) {
    const linenr_T line_count = wp->w_buffer->b_ml.ml_line_count;
    // Avoid ml_get errors when producing "scroll_delta".
    const linenr_T cur_topline = MIN(wp->w_topline, line_count);
    const linenr_T cur_botline = MIN(wp->w_botline, line_count);
    int64_t delta = 0;
    linenr_T last_topline = wp->w_viewport_last_topline;
    linenr_T last_botline = wp->w_viewport_last_botline;
    int last_topfill = wp->w_viewport_last_topfill;
    int64_t last_skipcol = wp->w_viewport_last_skipcol;
    if (last_topline > line_count) {
      delta -= last_topline - line_count;
      last_topline = line_count;
      last_topfill = 0;
      last_skipcol = MAXCOL;
    }
    last_botline = MIN(last_botline, line_count);
    if (cur_topline < last_topline
        || (cur_topline == last_topline && wp->w_skipcol < last_skipcol)) {
      if (last_topline > 0 && cur_botline < last_topline) {
        // Scrolling too many lines: only give an approximate "scroll_delta".
        delta -= win_text_height(wp, cur_topline, wp->w_skipcol, cur_botline, 0, NULL);
        delta -= last_topline - cur_botline;
      } else {
        delta -= win_text_height(wp, cur_topline, wp->w_skipcol, last_topline, last_skipcol, NULL);
      }
    } else if (cur_topline > last_topline
               || (cur_topline == last_topline && wp->w_skipcol > last_skipcol)) {
      if (last_botline > 0 && cur_topline > last_botline) {
        // Scrolling too many lines: only give an approximate "scroll_delta".
        delta += win_text_height(wp, last_topline, last_skipcol, last_botline, 0, NULL);
        delta += cur_topline - last_botline;
      } else {
        delta += win_text_height(wp, last_topline, last_skipcol, cur_topline, wp->w_skipcol, NULL);
      }
    }
    delta += last_topfill;
    delta -= wp->w_topfill;
    linenr_T ev_botline = wp->w_botline;
    if (ev_botline == line_count + 1 && wp->w_empty_rows == 0) {
      // TODO(bfredl): The might be more cases to consider, like how does this
      // interact with incomplete final line? Diff filler lines?
      ev_botline = line_count;
    }
    ui_call_win_viewport(wp->w_grid_alloc.handle, wp->handle, wp->w_topline - 1, ev_botline,
                         wp->w_cursor.lnum - 1, wp->w_cursor.col, line_count, delta);
    wp->w_viewport_invalid = false;
    wp->w_viewport_last_topline = wp->w_topline;
    wp->w_viewport_last_botline = wp->w_botline;
    wp->w_viewport_last_topfill = wp->w_topfill;
    wp->w_viewport_last_skipcol = wp->w_skipcol;
  }
}

/// If "split_disallowed" is set, or "wp"'s buffer is closing, give an error and return FAIL.
/// Otherwise return OK.
int check_split_disallowed(const win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  Error err = ERROR_INIT;
  const bool ok = check_split_disallowed_err(wp, &err);
  if (ERROR_SET(&err)) {
    emsg(_(err.msg));
    api_clear_error(&err);
  }
  return ok ? OK : FAIL;
}

/// Like `check_split_disallowed`, but set `err` to the (untranslated) error message on failure and
/// return false. Otherwise return true.
/// @see check_split_disallowed
bool check_split_disallowed_err(const win_T *wp, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  if (split_disallowed > 0) {
    api_set_error(err, kErrorTypeException, "E242: Can't split a window while closing another");
    return false;
  }
  if (wp->w_buffer->b_locked_split) {
    api_set_error(err, kErrorTypeException, "%s", e_cannot_split_window_when_closing_buffer);
    return false;
  }
  return true;
}

// split the current window, implements CTRL-W s and :split
//
// "size" is the height or width for the new window, 0 to use half of current
// height or width.
//
// "flags":
// WSP_ROOM: require enough room for new window
// WSP_VERT: vertical split.
// WSP_TOP:  open window at the top-left of the screen (help window).
// WSP_BOT:  open window at the bottom-right of the screen (quickfix window).
// WSP_HELP: creating the help window, keep layout snapshot
// WSP_NOENTER: do not enter the new window or trigger WinNew autocommands
//
// return FAIL for failure, OK otherwise
int win_split(int size, int flags)
{
  if (check_split_disallowed(curwin) == FAIL) {
    return FAIL;
  }

  // When the ":tab" modifier was used open a new tab page instead.
  if (may_open_tabpage() == OK) {
    return OK;
  }

  // Add flags from ":vertical", ":topleft" and ":botright".
  flags |= cmdmod.cmod_split;
  if ((flags & WSP_TOP) && (flags & WSP_BOT)) {
    emsg(_("E442: Can't split topleft and botright at the same time"));
    return FAIL;
  }

  // When creating the help window make a snapshot of the window layout.
  // Otherwise clear the snapshot, it's now invalid.
  if (flags & WSP_HELP) {
    make_snapshot(SNAP_HELP_IDX);
  } else {
    clear_snapshot(curtab, SNAP_HELP_IDX);
  }

  return win_split_ins(size, flags, NULL, 0, NULL) == NULL ? FAIL : OK;
}

/// When "new_wp" is NULL: split the current window in two.
/// When "new_wp" is not NULL: insert this window at the far
/// top/left/right/bottom.
/// When "to_flatten" is not NULL: flatten this frame before reorganising frames;
/// remains unflattened on failure.
///
/// On failure, if "new_wp" was not NULL, no changes will have been made to the
/// window layout or sizes.
/// @return  NULL for failure, or pointer to new window
win_T *win_split_ins(int size, int flags, win_T *new_wp, int dir, frame_T *to_flatten)
{
  win_T *wp = new_wp;

  // aucmd_win[] should always remain floating
  if (new_wp != NULL && is_aucmd_win(new_wp)) {
    return NULL;
  }

  win_T *oldwin;
  if (flags & WSP_TOP) {
    oldwin = firstwin;
  } else if (flags & WSP_BOT || curwin->w_floating) {
    // can't split float, use last nonfloating window instead
    oldwin = lastwin_nofloating();
  } else {
    oldwin = curwin;
  }

  int need_status = 0;
  int new_size = size;
  bool vertical = flags & WSP_VERT;
  bool toplevel = flags & (WSP_TOP | WSP_BOT);

  // add a status line when p_ls == 1 and splitting the first window
  if (one_window(firstwin) && p_ls == 1 && oldwin->w_status_height == 0) {
    if (oldwin->w_height <= p_wmh) {
      emsg(_(e_noroom));
      return NULL;
    }
    need_status = STATUS_HEIGHT;
  }

  bool do_equal = false;
  int oldwin_height = 0;
  const int layout = vertical ? FR_ROW : FR_COL;
  bool did_set_fraction = false;

  if (vertical) {
    // Check if we are able to split the current window and compute its
    // width.
    // Current window requires at least 1 space.
    int wmw1 = (p_wmw == 0 ? 1 : (int)p_wmw);
    int needed = wmw1 + 1;
    if (flags & WSP_ROOM) {
      needed += (int)p_wiw - wmw1;
    }
    int minwidth;
    int available;
    if (toplevel) {
      minwidth = frame_minwidth(topframe, NOWIN);
      available = topframe->fr_width;
      needed += minwidth;
    } else if (p_ea) {
      minwidth = frame_minwidth(oldwin->w_frame, NOWIN);
      frame_T *prevfrp = oldwin->w_frame;
      for (frame_T *frp = oldwin->w_frame->fr_parent; frp != NULL;
           frp = frp->fr_parent) {
        if (frp->fr_layout == FR_ROW) {
          frame_T *frp2;
          FOR_ALL_FRAMES(frp2, frp->fr_child) {
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
    if (available < needed) {
      emsg(_(e_noroom));
      return NULL;
    }
    if (new_size == 0) {
      new_size = oldwin->w_width / 2;
    }
    if (new_size > available - minwidth - 1) {
      new_size = available - minwidth - 1;
    }
    if (new_size < wmw1) {
      new_size = wmw1;
    }

    // if it doesn't fit in the current window, need win_equal()
    if (oldwin->w_width - new_size - 1 < p_wmw) {
      do_equal = true;
    }

    // We don't like to take lines for the new window from a
    // 'winfixwidth' window.  Take them from a window to the left or right
    // instead, if possible. Add one for the separator.
    if (oldwin->w_p_wfw) {
      win_setwidth_win(oldwin->w_width + new_size + 1, oldwin);
    }

    // Only make all windows the same width if one of them (except oldwin)
    // is wider than one of the split windows.
    if (!do_equal && p_ea && size == 0 && *p_ead != 'v'
        && oldwin->w_frame->fr_parent != NULL) {
      frame_T *frp = oldwin->w_frame->fr_parent->fr_child;
      while (frp != NULL) {
        if (frp->fr_win != oldwin && frp->fr_win != NULL
            && (frp->fr_win->w_width > new_size
                || frp->fr_win->w_width > (oldwin->w_width
                                           - new_size - 1))) {
          do_equal = true;
          break;
        }
        frp = frp->fr_next;
      }
    }
  } else {
    // Check if we are able to split the current window and compute its height.
    // Current window requires at least 1 space plus space for the window bar.
    int wmh1 = MAX((int)p_wmh, 1) + oldwin->w_winbar_height;
    int needed = wmh1 + STATUS_HEIGHT;
    if (flags & WSP_ROOM) {
      needed += (int)p_wh - wmh1 + oldwin->w_winbar_height;
    }
    if (p_ch < 1) {
      needed += 1;  // Adjust for cmdheight=0.
    }
    int minheight;
    int available;
    if (toplevel) {
      minheight = frame_minheight(topframe, NOWIN) + need_status;
      available = topframe->fr_height;
      needed += minheight;
    } else if (p_ea) {
      minheight = frame_minheight(oldwin->w_frame, NOWIN) + need_status;
      frame_T *prevfrp = oldwin->w_frame;
      for (frame_T *frp = oldwin->w_frame->fr_parent; frp != NULL; frp = frp->fr_parent) {
        if (frp->fr_layout == FR_COL) {
          frame_T *frp2;
          FOR_ALL_FRAMES(frp2, frp->fr_child) {
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
    if (available < needed) {
      emsg(_(e_noroom));
      return NULL;
    }
    oldwin_height = oldwin->w_height;
    if (need_status) {
      oldwin->w_status_height = STATUS_HEIGHT;
      oldwin_height -= STATUS_HEIGHT;
    }
    if (new_size == 0) {
      new_size = oldwin_height / 2;
    }

    if (new_size > available - minheight - STATUS_HEIGHT) {
      new_size = available - minheight - STATUS_HEIGHT;
    }
    if (new_size < wmh1) {
      new_size = wmh1;
    }

    // if it doesn't fit in the current window, need win_equal()
    if (oldwin_height - new_size - STATUS_HEIGHT < p_wmh) {
      do_equal = true;
    }

    // We don't like to take lines for the new window from a
    // 'winfixheight' window.  Take them from a window above or below
    // instead, if possible.
    if (oldwin->w_p_wfh) {
      // Set w_fraction now so that the cursor keeps the same relative
      // vertical position using the old height.
      set_fraction(oldwin);
      did_set_fraction = true;

      win_setheight_win(oldwin->w_height + new_size + STATUS_HEIGHT,
                        oldwin);
      oldwin_height = oldwin->w_height;
      if (need_status) {
        oldwin_height -= STATUS_HEIGHT;
      }
    }

    // Only make all windows the same height if one of them (except oldwin)
    // is higher than one of the split windows.
    if (!do_equal && p_ea && size == 0
        && *p_ead != 'h'
        && oldwin->w_frame->fr_parent != NULL) {
      frame_T *frp = oldwin->w_frame->fr_parent->fr_child;
      while (frp != NULL) {
        if (frp->fr_win != oldwin && frp->fr_win != NULL
            && (frp->fr_win->w_height > new_size
                || frp->fr_win->w_height > oldwin_height - new_size - STATUS_HEIGHT)) {
          do_equal = true;
          break;
        }
        frp = frp->fr_next;
      }
    }
  }

  // allocate new window structure and link it in the window list
  if ((flags & WSP_TOP) == 0
      && ((flags & WSP_BOT)
          || (flags & WSP_BELOW)
          || (!(flags & WSP_ABOVE)
              && (vertical ? p_spr : p_sb)))) {
    // new window below/right of current one
    if (new_wp == NULL) {
      wp = win_alloc(oldwin, false);
    } else {
      win_append(oldwin, wp, NULL);
    }
  } else {
    if (new_wp == NULL) {
      wp = win_alloc(oldwin->w_prev, false);
    } else {
      win_append(oldwin->w_prev, wp, NULL);
    }
  }

  if (new_wp == NULL) {
    if (wp == NULL) {
      return NULL;
    }

    new_frame(wp);

    // make the contents of the new window the same as the current one
    win_init(wp, curwin, flags);
  } else if (wp->w_floating) {
    ui_comp_remove_grid(&wp->w_grid_alloc);
    if (ui_has(kUIMultigrid)) {
      wp->w_pos_changed = true;
    } else {
      // No longer a float, a non-multigrid UI shouldn't draw it as such
      ui_call_win_hide(wp->w_grid_alloc.handle);
      win_free_grid(wp, true);
    }

    // External windows are independent of tabpages, and may have been the curwin of others.
    if (wp->w_config.external) {
      FOR_ALL_TABS(tp) {
        if (tp != curtab && tp->tp_curwin == wp) {
          tp->tp_curwin = tp->tp_firstwin;
        }
      }
    }

    wp->w_floating = false;
    new_frame(wp);

    // non-floating window doesn't store float config or have a border.
    wp->w_config = WIN_CONFIG_INIT;
    CLEAR_FIELD(wp->w_border_adj);
  }

  // Going to reorganize frames now, make sure they're flat.
  if (to_flatten != NULL) {
    frame_flatten(to_flatten);
  }

  bool before;
  frame_T *curfrp;

  // Reorganise the tree of frames to insert the new window.
  if (toplevel) {
    if ((topframe->fr_layout == FR_COL && !vertical)
        || (topframe->fr_layout == FR_ROW && vertical)) {
      curfrp = topframe->fr_child;
      if (flags & WSP_BOT) {
        while (curfrp->fr_next != NULL) {
          curfrp = curfrp->fr_next;
        }
      }
    } else {
      curfrp = topframe;
    }
    before = (flags & WSP_TOP);
  } else {
    curfrp = oldwin->w_frame;
    if (flags & WSP_BELOW) {
      before = false;
    } else if (flags & WSP_ABOVE) {
      before = true;
    } else if (vertical) {
      before = !p_spr;
    } else {
      before = !p_sb;
    }
  }
  if (curfrp->fr_parent == NULL || curfrp->fr_parent->fr_layout != layout) {
    // Need to create a new frame in the tree to make a branch.
    frame_T *frp = xcalloc(1, sizeof(frame_T));
    *frp = *curfrp;
    curfrp->fr_layout = (char)layout;
    frp->fr_parent = curfrp;
    frp->fr_next = NULL;
    frp->fr_prev = NULL;
    curfrp->fr_child = frp;
    curfrp->fr_win = NULL;
    curfrp = frp;
    if (frp->fr_win != NULL) {
      oldwin->w_frame = frp;
    } else {
      FOR_ALL_FRAMES(frp, frp->fr_child) {
        frp->fr_parent = curfrp;
      }
    }
  }

  frame_T *frp;
  if (new_wp == NULL) {
    frp = wp->w_frame;
  } else {
    frp = new_wp->w_frame;
  }
  frp->fr_parent = curfrp->fr_parent;

  // Insert the new frame at the right place in the frame list.
  if (before) {
    frame_insert(curfrp, frp);
  } else {
    frame_append(curfrp, frp);
  }

  // Set w_fraction now so that the cursor keeps the same relative
  // vertical position.
  if (!did_set_fraction) {
    set_fraction(oldwin);
  }
  wp->w_fraction = oldwin->w_fraction;

  if (vertical) {
    wp->w_p_scr = curwin->w_p_scr;

    if (need_status) {
      win_new_height(oldwin, oldwin->w_height - 1);
      oldwin->w_status_height = need_status;
    }
    if (toplevel) {
      // set height and row of new window to full height
      wp->w_winrow = tabline_height();
      win_new_height(wp, curfrp->fr_height - (p_ls == 1 || p_ls == 2));
      wp->w_status_height = (p_ls == 1 || p_ls == 2);
      wp->w_hsep_height = 0;
    } else {
      // height and row of new window is same as current window
      wp->w_winrow = oldwin->w_winrow;
      win_new_height(wp, oldwin->w_height);
      wp->w_status_height = oldwin->w_status_height;
      wp->w_hsep_height = oldwin->w_hsep_height;
    }
    frp->fr_height = curfrp->fr_height;

    // "new_size" of the current window goes to the new window, use
    // one column for the vertical separator
    win_new_width(wp, new_size);
    if (before) {
      wp->w_vsep_width = 1;
    } else {
      wp->w_vsep_width = oldwin->w_vsep_width;
      oldwin->w_vsep_width = 1;
    }
    if (toplevel) {
      if (flags & WSP_BOT) {
        frame_add_vsep(curfrp);
      }
      // Set width of neighbor frame
      frame_new_width(curfrp, curfrp->fr_width
                      - (new_size + ((flags & WSP_TOP) != 0)), flags & WSP_TOP,
                      false);
    } else {
      win_new_width(oldwin, oldwin->w_width - (new_size + 1));
    }
    if (before) {       // new window left of current one
      wp->w_wincol = oldwin->w_wincol;
      oldwin->w_wincol += new_size + 1;
    } else {  // new window right of current one
      wp->w_wincol = oldwin->w_wincol + oldwin->w_width + 1;
    }
    frame_fix_width(oldwin);
    frame_fix_width(wp);
  } else {
    const bool is_stl_global = global_stl_height() > 0;
    // width and column of new window is same as current window
    if (toplevel) {
      wp->w_wincol = 0;
      win_new_width(wp, Columns);
      wp->w_vsep_width = 0;
    } else {
      wp->w_wincol = oldwin->w_wincol;
      win_new_width(wp, oldwin->w_width);
      wp->w_vsep_width = oldwin->w_vsep_width;
    }
    frp->fr_width = curfrp->fr_width;

    // "new_size" of the current window goes to the new window, use
    // one row for the status line
    win_new_height(wp, new_size);
    const int old_status_height = oldwin->w_status_height;
    if (before) {
      wp->w_hsep_height = is_stl_global ? 1 : 0;
    } else {
      wp->w_hsep_height = oldwin->w_hsep_height;
      oldwin->w_hsep_height = is_stl_global ? 1 : 0;
    }
    if (toplevel) {
      int new_fr_height = curfrp->fr_height - new_size;
      if (is_stl_global) {
        if (flags & WSP_BOT) {
          frame_add_hsep(curfrp);
        } else {
          new_fr_height -= 1;
        }
      } else {
        if (!((flags & WSP_BOT) && p_ls == 0)) {
          new_fr_height -= STATUS_HEIGHT;
        }
        if (flags & WSP_BOT) {
          frame_add_statusline(curfrp);
        }
      }
      frame_new_height(curfrp, new_fr_height, flags & WSP_TOP, false);
    } else {
      win_new_height(oldwin, oldwin_height - (new_size + STATUS_HEIGHT));
    }

    if (before) {       // new window above current one
      wp->w_winrow = oldwin->w_winrow;
      if (is_stl_global) {
        wp->w_status_height = 0;
        oldwin->w_winrow += wp->w_height + 1;
      } else {
        wp->w_status_height = STATUS_HEIGHT;
        oldwin->w_winrow += wp->w_height + STATUS_HEIGHT;
      }
    } else {            // new window below current one
      if (is_stl_global) {
        wp->w_winrow = oldwin->w_winrow + oldwin->w_height + 1;
        wp->w_status_height = 0;
      } else {
        wp->w_winrow = oldwin->w_winrow + oldwin->w_height + STATUS_HEIGHT;
        wp->w_status_height = old_status_height;
        if (!(flags & WSP_BOT)) {
          oldwin->w_status_height = STATUS_HEIGHT;
        }
      }
    }
    frame_fix_height(wp);
    frame_fix_height(oldwin);
  }

  if (toplevel) {
    win_comp_pos();
  }

  // Both windows need redrawing.  Update all status lines, in case they
  // show something related to the window count or position.
  redraw_later(wp, UPD_NOT_VALID);
  redraw_later(oldwin, UPD_NOT_VALID);
  status_redraw_all();

  if (need_status) {
    msg_row = Rows - 1;
    msg_col = sc_col;
    msg_clr_eos_force();        // Old command/ruler may still be there
    comp_col();
    msg_row = Rows - 1;
    msg_col = 0;        // put position back at start of line
  }

  // equalize the window sizes.
  if (do_equal || dir != 0) {
    win_equal(wp, true, vertical ? (dir == 'v' ? 'b' : 'h') : (dir == 'h' ? 'b' : 'v'));
  } else if (!is_aucmd_win(wp)) {
    win_fix_scroll(false);
  }

  int i;

  // Don't change the window height/width to 'winheight' / 'winwidth' if a
  // size was given.
  if (flags & WSP_VERT) {
    i = (int)p_wiw;
    if (size != 0) {
      p_wiw = size;
    }
  } else {
    i = (int)p_wh;
    if (size != 0) {
      p_wh = size;
    }
  }

  if (!(flags & WSP_NOENTER)) {
    // make the new window the current window
    win_enter_ext(wp, (new_wp == NULL ? WEE_TRIGGER_NEW_AUTOCMDS : 0) | WEE_TRIGGER_ENTER_AUTOCMDS
                  | WEE_TRIGGER_LEAVE_AUTOCMDS);
  }
  if (vertical) {
    p_wiw = i;
  } else {
    p_wh = i;
  }

  if (win_valid(oldwin)) {
    // Send the window positions to the UI
    oldwin->w_pos_changed = true;
  }

  return wp;
}

// Initialize window "newp" from window "oldp".
// Used when splitting a window and when creating a new tab page.
// The windows will both edit the same buffer.
// WSP_NEWLOC may be specified in flags to prevent the location list from
// being copied.
void win_init(win_T *newp, win_T *oldp, int flags)
{
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
    // Don't copy the location list.
    newp->w_llist = NULL;
    newp->w_llist_ref = NULL;
  } else {
    copy_loclist_stack(oldp, newp);
  }
  newp->w_localdir = (oldp->w_localdir == NULL)
                     ? NULL : xstrdup(oldp->w_localdir);
  newp->w_prevdir = (oldp->w_prevdir == NULL)
                    ? NULL : xstrdup(oldp->w_prevdir);

  if (*p_spk != 'c') {
    if (*p_spk == 't') {
      newp->w_skipcol = oldp->w_skipcol;
    }
    newp->w_botline = oldp->w_botline;
    newp->w_prev_height = oldp->w_height;
    newp->w_prev_winrow = oldp->w_winrow;
  }

  // copy tagstack and folds
  for (int i = 0; i < oldp->w_tagstacklen; i++) {
    taggy_T *tag = &newp->w_tagstack[i];
    *tag = oldp->w_tagstack[i];
    if (tag->tagname != NULL) {
      tag->tagname = xstrdup(tag->tagname);
    }
    if (tag->user_data != NULL) {
      tag->user_data = xstrdup(tag->user_data);
    }
  }
  newp->w_tagstackidx = oldp->w_tagstackidx;
  newp->w_tagstacklen = oldp->w_tagstacklen;

  // Keep same changelist position in new window.
  newp->w_changelistidx = oldp->w_changelistidx;

  copyFoldingState(oldp, newp);

  win_init_some(newp, oldp);

  newp->w_winbar_height = oldp->w_winbar_height;
}

// Initialize window "newp" from window "old".
// Only the essential things are copied.
static void win_init_some(win_T *newp, win_T *oldp)
{
  // Use the same argument list.
  newp->w_alist = oldp->w_alist;
  newp->w_alist->al_refcount++;
  newp->w_arg_idx = oldp->w_arg_idx;

  // copy options from existing window
  win_copy_options(oldp, newp);
}

/// Check if "win" is a pointer to an existing window in the current tabpage.
///
/// @param  win  window to check
bool win_valid(const win_T *win) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return tabpage_win_valid(curtab, win);
}

/// Check if "win" is a pointer to an existing window in tabpage "tp".
///
/// @param  win  window to check
bool tabpage_win_valid(const tabpage_T *tp, const win_T *win)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (win == NULL) {
    return false;
  }

  FOR_ALL_WINDOWS_IN_TAB(wp, tp) {
    if (wp == win) {
      return true;
    }
  }
  return false;
}

// Find window "handle" in the current tab page.
// Return NULL if not found.
win_T *win_find_by_handle(handle_T handle)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->handle == handle) {
      return wp;
    }
  }
  return NULL;
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

// Return the number of windows.
int win_count(void)
{
  int count = 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    count++;
  }
  return count;
}

/// Make "count" windows on the screen.
/// Must be called when there is just one window, filling the whole screen.
/// (excluding the command line).
///
/// @param vertical  split windows vertically if true.
///
/// @return actual number of windows on the screen.
int make_windows(int count, bool vertical)
{
  int maxcount;

  if (vertical) {
    // Each window needs at least 'winminwidth' lines and a separator column.
    maxcount = (int)(curwin->w_width + curwin->w_vsep_width
                     - (p_wiw - p_wmw)) / ((int)p_wmw + 1);
  } else {
    // Each window needs at least 'winminheight' lines.
    // If statusline isn't global, each window also needs a statusline.
    // If 'winbar' is set, each window also needs a winbar.
    maxcount = (int)(curwin->w_height + curwin->w_hsep_height + curwin->w_status_height
                     - (p_wh - p_wmh)) / ((int)p_wmh + STATUS_HEIGHT + global_winbar_height());
  }

  if (maxcount < 2) {
    maxcount = 2;
  }
  if (count > maxcount) {
    count = maxcount;
  }

  // add status line now, otherwise first window will be too big
  if (count > 1) {
    last_status(true);
  }

  // Don't execute autocommands while creating the windows.  Must do that
  // when putting the buffers in the windows.
  block_autocmds();

  int todo;

  // todo is number of windows left to create
  for (todo = count - 1; todo > 0; todo--) {
    if (vertical) {
      if (win_split(curwin->w_width - (curwin->w_width - todo)
                    / (todo + 1) - 1, WSP_VERT | WSP_ABOVE) == FAIL) {
        break;
      }
    } else {
      if (win_split(curwin->w_height - (curwin->w_height - todo
                                        * STATUS_HEIGHT) / (todo + 1)
                    - STATUS_HEIGHT, WSP_ABOVE) == FAIL) {
        break;
      }
    }
  }

  unblock_autocmds();

  // return actual number of windows
  return count - todo;
}

// Exchange current and next window
static void win_exchange(int Prenum)
{
  if (curwin->w_floating) {
    emsg(e_floatexchange);
    return;
  }

  if (one_window(curwin)) {
    // just one window
    beep_flush();
    return;
  }
  if (text_or_buf_locked()) {
    beep_flush();
    return;
  }

  frame_T *frp;

  // find window to exchange with
  if (Prenum) {
    frp = curwin->w_frame->fr_parent->fr_child;
    while (frp != NULL && --Prenum > 0) {
      frp = frp->fr_next;
    }
  } else if (curwin->w_frame->fr_next != NULL) {  // Swap with next
    frp = curwin->w_frame->fr_next;
  } else {  // Swap last window in row/col with previous
    frp = curwin->w_frame->fr_prev;
  }

  // We can only exchange a window with another window, not with a frame
  // containing windows.
  if (frp == NULL || frp->fr_win == NULL || frp->fr_win == curwin) {
    return;
  }
  win_T *wp = frp->fr_win;

  // 1. remove curwin from the list. Remember after which window it was in wp2
  // 2. insert curwin before wp in the list
  // if wp != wp2
  //    3. remove wp from the list
  //    4. insert wp after wp2
  // 5. exchange the status line height, winbar height, hsep height and vsep width.
  win_T *wp2 = curwin->w_prev;
  frame_T *frp2 = curwin->w_frame->fr_prev;
  if (wp->w_prev != curwin) {
    win_remove(curwin, NULL);
    frame_remove(curwin->w_frame);
    win_append(wp->w_prev, curwin, NULL);
    frame_insert(frp, curwin->w_frame);
  }
  if (wp != wp2) {
    win_remove(wp, NULL);
    frame_remove(wp->w_frame);
    win_append(wp2, wp, NULL);
    if (frp2 == NULL) {
      frame_insert(wp->w_frame->fr_parent->fr_child, wp->w_frame);
    } else {
      frame_append(frp2, wp->w_frame);
    }
  }
  int temp = curwin->w_status_height;
  curwin->w_status_height = wp->w_status_height;
  wp->w_status_height = temp;
  temp = curwin->w_vsep_width;
  curwin->w_vsep_width = wp->w_vsep_width;
  wp->w_vsep_width = temp;
  temp = curwin->w_hsep_height;
  curwin->w_hsep_height = wp->w_hsep_height;
  wp->w_hsep_height = temp;

  frame_fix_height(curwin);
  frame_fix_height(wp);
  frame_fix_width(curwin);
  frame_fix_width(wp);

  win_comp_pos();                 // recompute window positions

  if (wp->w_buffer != curbuf) {
    reset_VIsual_and_resel();
  } else if (VIsual_active) {
    wp->w_cursor = curwin->w_cursor;
  }

  win_enter(wp, true);
  redraw_later(curwin, UPD_NOT_VALID);
  redraw_later(wp, UPD_NOT_VALID);
}

// rotate windows: if upwards true the second window becomes the first one
//                 if upwards false the first window becomes the second one
static void win_rotate(bool upwards, int count)
{
  if (curwin->w_floating) {
    emsg(e_floatexchange);
    return;
  }

  if (count <= 0 || one_window(curwin)) {
    // nothing to do
    beep_flush();
    return;
  }

  // Check if all frames in this row/col have one window.
  frame_T *frp;
  FOR_ALL_FRAMES(frp, curwin->w_frame->fr_parent->fr_child) {
    if (frp->fr_win == NULL) {
      emsg(_("E443: Cannot rotate when another window is split"));
      return;
    }
  }

  win_T *wp1 = NULL;
  win_T *wp2 = NULL;

  while (count--) {
    if (upwards) {              // first window becomes last window
      // remove first window/frame from the list
      frp = curwin->w_frame->fr_parent->fr_child;
      assert(frp != NULL);
      wp1 = frp->fr_win;
      win_remove(wp1, NULL);
      frame_remove(frp);
      assert(frp->fr_parent->fr_child);

      // find last frame and append removed window/frame after it
      for (; frp->fr_next != NULL; frp = frp->fr_next) {}
      win_append(frp->fr_win, wp1, NULL);
      frame_append(frp, wp1->w_frame);

      wp2 = frp->fr_win;                // previously last window
    } else {                  // last window becomes first window
      // find last window/frame in the list and remove it
      for (frp = curwin->w_frame; frp->fr_next != NULL;
           frp = frp->fr_next) {}
      wp1 = frp->fr_win;
      wp2 = wp1->w_prev;                    // will become last window
      win_remove(wp1, NULL);
      frame_remove(frp);
      assert(frp->fr_parent->fr_child);

      // append the removed window/frame before the first in the list
      win_append(frp->fr_parent->fr_child->fr_win->w_prev, wp1, NULL);
      frame_insert(frp->fr_parent->fr_child, frp);
    }

    // exchange status height, winbar height, hsep height and vsep width of old and new last window
    int n = wp2->w_status_height;
    wp2->w_status_height = wp1->w_status_height;
    wp1->w_status_height = n;
    n = wp2->w_hsep_height;
    wp2->w_hsep_height = wp1->w_hsep_height;
    wp1->w_hsep_height = n;
    frame_fix_height(wp1);
    frame_fix_height(wp2);
    n = wp2->w_vsep_width;
    wp2->w_vsep_width = wp1->w_vsep_width;
    wp1->w_vsep_width = n;
    frame_fix_width(wp1);
    frame_fix_width(wp2);

    // recompute w_winrow and w_wincol for all windows
    win_comp_pos();
  }

  wp1->w_pos_changed = true;
  wp2->w_pos_changed = true;

  redraw_all_later(UPD_NOT_VALID);
}

/// Move "wp" into a new split in a given direction, possibly relative to the
/// current window.
/// "wp" must be valid in the current tabpage.
/// Returns FAIL for failure, OK otherwise.
int win_splitmove(win_T *wp, int size, int flags)
{
  int dir = 0;
  int height = wp->w_height;

  if (one_window(wp)) {
    return OK;  // nothing to do
  }
  if (is_aucmd_win(wp) || check_split_disallowed(wp) == FAIL) {
    return FAIL;
  }

  frame_T *unflat_altfr = NULL;
  if (wp->w_floating) {
    win_remove(wp, NULL);
  } else {
    // Remove the window and frame from the tree of frames.  Don't flatten any
    // frames yet so we can restore things if win_split_ins fails.
    winframe_remove(wp, &dir, NULL, &unflat_altfr);
    assert(unflat_altfr != NULL);
    win_remove(wp, NULL);
    last_status(false);  // may need to remove last status line
    win_comp_pos();  // recompute window positions
  }

  // Split a window on the desired side and put "wp" there.
  if (win_split_ins(size, flags, wp, dir, unflat_altfr) == NULL) {
    if (!wp->w_floating) {
      assert(unflat_altfr != NULL);
      // win_split_ins doesn't change sizes or layout if it fails to insert an
      // existing window, so just undo winframe_remove.
      winframe_restore(wp, dir, unflat_altfr);
    }
    win_append(wp->w_prev, wp, NULL);
    return FAIL;
  }

  // If splitting horizontally, try to preserve height.
  // Note that win_split_ins autocommands may have immediately closed "wp", or made it floating!
  if (size == 0 && !(flags & WSP_VERT) && win_valid(wp) && !wp->w_floating) {
    win_setheight_win(height, wp);
    if (p_ea) {
      // Equalize windows.  Note that win_split_ins autocommands may have
      // made a window other than "wp" current.
      win_equal(curwin, curwin == wp, 'v');
    }
  }

  return OK;
}

// Move window "win1" to below/right of "win2" and make "win1" the current
// window.  Only works within the same frame!
void win_move_after(win_T *win1, win_T *win2)
{
  // check if the arguments are reasonable
  if (win1 == win2) {
    return;
  }

  // check if there is something to do
  if (win2->w_next != win1) {
    if (win1->w_frame->fr_parent != win2->w_frame->fr_parent) {
      iemsg("INTERNAL: trying to move a window into another frame");
      return;
    }

    // may need to move the status line, window bar, horizontal or vertical separator of the last
    // window
    if (win1 == lastwin) {
      int height = win1->w_prev->w_status_height;
      win1->w_prev->w_status_height = win1->w_status_height;
      win1->w_status_height = height;

      height = win1->w_prev->w_hsep_height;
      win1->w_prev->w_hsep_height = win1->w_hsep_height;
      win1->w_hsep_height = height;

      if (win1->w_prev->w_vsep_width == 1) {
        // Remove the vertical separator from the last-but-one window,
        // add it to the last window.  Adjust the frame widths.
        win1->w_prev->w_vsep_width = 0;
        win1->w_prev->w_frame->fr_width -= 1;
        win1->w_vsep_width = 1;
        win1->w_frame->fr_width += 1;
      }
    } else if (win2 == lastwin) {
      int height = win1->w_status_height;
      win1->w_status_height = win2->w_status_height;
      win2->w_status_height = height;

      height = win1->w_hsep_height;
      win1->w_hsep_height = win2->w_hsep_height;
      win2->w_hsep_height = height;

      if (win1->w_vsep_width == 1) {
        // Remove the vertical separator from win1, add it to the last
        // window, win2.  Adjust the frame widths.
        win2->w_vsep_width = 1;
        win2->w_frame->fr_width += 1;
        win1->w_vsep_width = 0;
        win1->w_frame->fr_width -= 1;
      }
    }
    win_remove(win1, NULL);
    frame_remove(win1->w_frame);
    win_append(win2, win1, NULL);
    frame_append(win2->w_frame, win1->w_frame);

    win_comp_pos();  // recompute w_winrow for all windows
    redraw_later(curwin, UPD_NOT_VALID);
  }
  win_enter(win1, false);

  win1->w_pos_changed = true;
  win2->w_pos_changed = true;
}

/// Compute maximum number of windows that can fit within "height" in frame "fr".
static int get_maximum_wincount(frame_T *fr, int height)
{
  if (fr->fr_layout != FR_COL) {
    return (height / ((int)p_wmh + STATUS_HEIGHT + frame2win(fr)->w_winbar_height));
  } else if (global_winbar_height()) {
    // If winbar is globally enabled, no need to check each window for it.
    return (height / ((int)p_wmh + STATUS_HEIGHT + 1));
  }

  frame_T *frp;
  int total_wincount = 0;

  // First, try to fit all child frames of "fr" into "height"
  FOR_ALL_FRAMES(frp, fr->fr_child) {
    win_T *wp = frame2win(frp);

    if (height < (p_wmh + STATUS_HEIGHT + wp->w_winbar_height)) {
      break;
    }
    height -= (int)p_wmh + STATUS_HEIGHT + wp->w_winbar_height;
    total_wincount += 1;
  }

  // If we still have enough room for more windows, just use the default winbar height (which is 0)
  // in order to get the amount of windows that'd fit in the remaining space
  total_wincount += height / ((int)p_wmh + STATUS_HEIGHT);

  return total_wincount;
}

/// Make all windows the same height.
/// 'next_curwin' will soon be the current window, make sure it has enough rows.
///
/// @param next_curwin  pointer to current window to be or NULL
/// @param current  do only frame with current window
/// @param dir  'v' for vertically, 'h' for horizontally, 'b' for both, 0 for using p_ead
void win_equal(win_T *next_curwin, bool current, int dir)
{
  if (dir == 0) {
    dir = (unsigned char)(*p_ead);
  }
  win_equal_rec(next_curwin == NULL ? curwin : next_curwin, current,
                topframe, dir, 0, tabline_height(),
                Columns, topframe->fr_height);
  if (!is_aucmd_win(next_curwin)) {
    win_fix_scroll(true);
  }
}

/// Set a frame to a new position and height, spreading the available room
/// equally over contained frames.
/// The window "next_curwin" (if not NULL) should at least get the size from
/// 'winheight' and 'winwidth' if possible.
///
/// @param next_curwin  pointer to current window to be or NULL
/// @param current      do only frame with current window
/// @param topfr        frame to set size off
/// @param dir          'v', 'h' or 'b', see win_equal()
/// @param col          horizontal position for frame
/// @param row          vertical position for frame
/// @param width        new width of frame
/// @param height       new height of frame
static void win_equal_rec(win_T *next_curwin, bool current, frame_T *topfr, int dir, int col,
                          int row, int width, int height)
{
  int extra_sep = 0;
  int totwincount = 0;
  int next_curwin_size = 0;
  int room = 0;
  bool has_next_curwin = false;

  if (topfr->fr_layout == FR_LEAF) {
    // Set the width/height of this frame.
    // Redraw when size or position changes
    if (topfr->fr_height != height || topfr->fr_win->w_winrow != row
        || topfr->fr_width != width
        || topfr->fr_win->w_wincol != col) {
      topfr->fr_win->w_winrow = row;
      frame_new_height(topfr, height, false, false);
      topfr->fr_win->w_wincol = col;
      frame_new_width(topfr, width, false, false);
      redraw_all_later(UPD_NOT_VALID);
    }
  } else if (topfr->fr_layout == FR_ROW) {
    topfr->fr_width = width;
    topfr->fr_height = height;

    if (dir != 'v') {                   // equalize frame widths
      // Compute the maximum number of windows horizontally in this
      // frame.
      int n = frame_minwidth(topfr, NOWIN);
      // add one for the rightmost window, it doesn't have a separator
      if (col + width == Columns) {
        extra_sep = 1;
      } else {
        extra_sep = 0;
      }
      totwincount = (n + extra_sep) / ((int)p_wmw + 1);
      has_next_curwin = frame_has_win(topfr, next_curwin);

      // Compute width for "next_curwin" window and room available for
      // other windows.
      // "m" is the minimal width when counting p_wiw for "next_curwin".
      int m = frame_minwidth(topfr, next_curwin);
      room = width - m;
      if (room < 0) {
        next_curwin_size = (int)p_wiw + room;
        room = 0;
      } else {
        next_curwin_size = -1;
        frame_T *fr;
        FOR_ALL_FRAMES(fr, topfr->fr_child) {
          if (!frame_fixed_width(fr)) {
            continue;
          }
          // If 'winfixwidth' set keep the window width if possible.
          // Watch out for this window being the next_curwin.
          n = frame_minwidth(fr, NOWIN);
          int new_size = fr->fr_width;
          if (frame_has_win(fr, next_curwin)) {
            room += (int)p_wiw - (int)p_wmw;
            next_curwin_size = 0;
            if (new_size < p_wiw) {
              new_size = (int)p_wiw;
            }
          } else {
            // These windows don't use up room.
            totwincount -= (n + (fr->fr_next == NULL ? extra_sep : 0)) / ((int)p_wmw + 1);
          }
          room -= new_size - n;
          if (room < 0) {
            new_size += room;
            room = 0;
          }
          fr->fr_newwidth = new_size;
        }
        if (next_curwin_size == -1) {
          if (!has_next_curwin) {
            next_curwin_size = 0;
          } else if (totwincount > 1
                     && (room + (totwincount - 2))
                     / (totwincount - 1) > p_wiw) {
            // Can make all windows wider than 'winwidth', spread
            // the room equally.
            next_curwin_size = (int)(room + p_wiw
                                     + (totwincount - 1) * p_wmw
                                     + (totwincount - 1)) / totwincount;
            room -= next_curwin_size - (int)p_wiw;
          } else {
            next_curwin_size = (int)p_wiw;
          }
        }
      }

      if (has_next_curwin) {
        totwincount--;                  // don't count curwin
      }
    }

    frame_T *fr;
    FOR_ALL_FRAMES(fr, topfr->fr_child) {
      int wincount = 1;
      int new_size;
      if (fr->fr_next == NULL) {
        // last frame gets all that remains (avoid roundoff error)
        new_size = width;
      } else if (dir == 'v') {
        new_size = fr->fr_width;
      } else if (frame_fixed_width(fr)) {
        new_size = fr->fr_newwidth;
        wincount = 0;               // doesn't count as a sizeable window
      } else {
        // Compute the maximum number of windows horiz. in "fr".
        int n = frame_minwidth(fr, NOWIN);
        wincount = (n + (fr->fr_next == NULL ? extra_sep : 0)) / ((int)p_wmw + 1);
        int m = frame_minwidth(fr, next_curwin);
        bool hnc = has_next_curwin && frame_has_win(fr, next_curwin);
        if (hnc) {                    // don't count next_curwin
          wincount--;
        }
        if (totwincount == 0) {
          new_size = room;
        } else {
          new_size = (wincount * room + (totwincount / 2)) / totwincount;
        }
        if (hnc) {                  // add next_curwin size
          next_curwin_size -= (int)p_wiw - (m - n);
          if (next_curwin_size < 0) {
            next_curwin_size = 0;
          }
          new_size += next_curwin_size;
          room -= new_size - next_curwin_size;
        } else {
          room -= new_size;
        }
        new_size += n;
      }

      // Skip frame that is full width when splitting or closing a
      // window, unless equalizing all frames.
      if (!current || dir != 'v' || topfr->fr_parent != NULL
          || (new_size != fr->fr_width)
          || frame_has_win(fr, next_curwin)) {
        win_equal_rec(next_curwin, current, fr, dir, col, row,
                      new_size, height);
      }
      col += new_size;
      width -= new_size;
      totwincount -= wincount;
    }
  } else {  // topfr->fr_layout == FR_COL
    topfr->fr_width = width;
    topfr->fr_height = height;

    if (dir != 'h') {                   // equalize frame heights
      // Compute maximum number of windows vertically in this frame.
      int n = frame_minheight(topfr, NOWIN);
      // add one for the bottom window if it doesn't have a statusline or separator
      if (row + height >= cmdline_row && p_ls == 0) {
        extra_sep = STATUS_HEIGHT;
      } else if (global_stl_height() > 0) {
        extra_sep = 1;
      } else {
        extra_sep = 0;
      }
      totwincount = get_maximum_wincount(topfr, n + extra_sep);
      has_next_curwin = frame_has_win(topfr, next_curwin);

      // Compute height for "next_curwin" window and room available for
      // other windows.
      // "m" is the minimal height when counting p_wh for "next_curwin".
      int m = frame_minheight(topfr, next_curwin);
      room = height - m;
      if (room < 0) {
        // The room is less than 'winheight', use all space for the
        // current window.
        next_curwin_size = (int)p_wh + room;
        room = 0;
      } else {
        next_curwin_size = -1;
        frame_T *fr;
        FOR_ALL_FRAMES(fr, topfr->fr_child) {
          if (!frame_fixed_height(fr)) {
            continue;
          }
          // If 'winfixheight' set keep the window height if possible.
          // Watch out for this window being the next_curwin.
          n = frame_minheight(fr, NOWIN);
          int new_size = fr->fr_height;
          if (frame_has_win(fr, next_curwin)) {
            room += (int)p_wh - (int)p_wmh;
            next_curwin_size = 0;
            if (new_size < p_wh) {
              new_size = (int)p_wh;
            }
          } else {
            // These windows don't use up room.
            totwincount -= get_maximum_wincount(fr, (n + (fr->fr_next == NULL ? extra_sep : 0)));
          }
          room -= new_size - n;
          if (room < 0) {
            new_size += room;
            room = 0;
          }
          fr->fr_newheight = new_size;
        }
        if (next_curwin_size == -1) {
          if (!has_next_curwin) {
            next_curwin_size = 0;
          } else if (totwincount > 1
                     && (room + (totwincount - 2))
                     / (totwincount - 1) > p_wh) {
            // can make all windows higher than 'winheight',
            // spread the room equally.
            next_curwin_size = (int)(room + p_wh
                                     + (totwincount - 1) * p_wmh
                                     + (totwincount - 1)) / totwincount;
            room -= next_curwin_size - (int)p_wh;
          } else {
            next_curwin_size = (int)p_wh;
          }
        }
      }

      if (has_next_curwin) {
        totwincount--;                  // don't count curwin
      }
    }

    frame_T *fr;
    FOR_ALL_FRAMES(fr, topfr->fr_child) {
      int new_size;
      int wincount = 1;
      if (fr->fr_next == NULL) {
        // last frame gets all that remains (avoid roundoff error)
        new_size = height;
      } else if (dir == 'h') {
        new_size = fr->fr_height;
      } else if (frame_fixed_height(fr)) {
        new_size = fr->fr_newheight;
        wincount = 0;               // doesn't count as a sizeable window
      } else {
        // Compute the maximum number of windows vert. in "fr".
        int n = frame_minheight(fr, NOWIN);
        wincount = get_maximum_wincount(fr, (n + (fr->fr_next == NULL ? extra_sep : 0)));
        int m = frame_minheight(fr, next_curwin);
        bool hnc = has_next_curwin && frame_has_win(fr, next_curwin);
        if (hnc) {                    // don't count next_curwin
          wincount--;
        }
        if (totwincount == 0) {
          new_size = room;
        } else {
          new_size = (wincount * room + (totwincount / 2)) / totwincount;
        }
        if (hnc) {                  // add next_curwin size
          next_curwin_size -= (int)p_wh - (m - n);
          new_size += next_curwin_size;
          room -= new_size - next_curwin_size;
        } else {
          room -= new_size;
        }
        new_size += n;
      }
      // Skip frame that is full width when splitting or closing a
      // window, unless equalizing all frames.
      if (!current || dir != 'h' || topfr->fr_parent != NULL
          || (new_size != fr->fr_height)
          || frame_has_win(fr, next_curwin)) {
        win_equal_rec(next_curwin, current, fr, dir, col, row,
                      width, new_size);
      }
      row += new_size;
      height -= new_size;
      totwincount -= wincount;
    }
  }
}

void leaving_window(win_T *const win)
  FUNC_ATTR_NONNULL_ALL
{
  // Only matters for a prompt window.
  if (!bt_prompt(win->w_buffer)) {
    return;
  }

  // When leaving a prompt window stop Insert mode and perhaps restart
  // it when entering that window again.
  win->w_buffer->b_prompt_insert = restart_edit;
  if (restart_edit != NUL && mode_displayed) {
    clear_cmdline = true;  // unshow mode later
  }
  restart_edit = NUL;

  // When leaving the window (or closing the window) was done from a
  // callback we need to break out of the Insert mode loop and restart Insert
  // mode when entering the window again.
  if ((State & MODE_INSERT) && !stop_insert_mode) {
    stop_insert_mode = true;
    if (win->w_buffer->b_prompt_insert == NUL) {
      win->w_buffer->b_prompt_insert = 'A';
    }
  }
}

void entering_window(win_T *const win)
  FUNC_ATTR_NONNULL_ALL
{
  // Only matters for a prompt window.
  if (!bt_prompt(win->w_buffer)) {
    return;
  }

  // When switching to a prompt buffer that was in Insert mode, don't stop
  // Insert mode, it may have been set in leaving_window().
  if (win->w_buffer->b_prompt_insert != NUL) {
    stop_insert_mode = false;
  }

  // When entering the prompt window restart Insert mode if we were in Insert
  // mode when we left it and not already in Insert mode.
  if ((State & MODE_INSERT) == 0) {
    restart_edit = win->w_buffer->b_prompt_insert;
  }
}

void win_init_empty(win_T *wp)
{
  redraw_later(wp, UPD_NOT_VALID);
  wp->w_lines_valid = 0;
  wp->w_cursor.lnum = 1;
  wp->w_curswant = wp->w_cursor.col = 0;
  wp->w_cursor.coladd = 0;
  wp->w_pcmark.lnum = 1;        // pcmark not cleared but set to line 1
  wp->w_pcmark.col = 0;
  wp->w_prev_pcmark.lnum = 0;
  wp->w_prev_pcmark.col = 0;
  wp->w_topline = 1;
  wp->w_topfill = 0;
  wp->w_botline = 2;
  wp->w_s = &wp->w_buffer->b_s;
}

/// Init the current window "curwin".
/// Called when a new file is being edited.
void curwin_init(void)
{
  win_init_empty(curwin);
}

/// Closes all windows for buffer `buf` unless there is only one non-floating window.
///
/// @param keep_curwin  don't close `curwin`
void close_windows(buf_T *buf, bool keep_curwin)
{
  RedrawingDisabled++;

  // Start from lastwin to close floating windows with the same buffer first.
  // When the autocommand window is involved win_close() may need to print an error message.
  for (win_T *wp = lastwin; wp != NULL && (is_aucmd_win(lastwin) || !one_window(wp));) {
    if (wp->w_buffer == buf && (!keep_curwin || wp != curwin)
        && !(wp->w_closing || wp->w_buffer->b_locked > 0)) {
      if (win_close(wp, false, false) == FAIL) {
        // If closing the window fails give up, to avoid looping forever.
        break;
      }

      // Start all over, autocommands may change the window layout.
      wp = lastwin;
    } else {
      wp = wp->w_prev;
    }
  }

  tabpage_T *nexttp;

  // Also check windows in other tab pages.
  for (tabpage_T *tp = first_tabpage; tp != NULL; tp = nexttp) {
    nexttp = tp->tp_next;
    if (tp != curtab) {
      // Start from tp_lastwin to close floating windows with the same buffer first.
      for (win_T *wp = tp->tp_lastwin; wp != NULL; wp = wp->w_prev) {
        if (wp->w_buffer == buf
            && !(wp->w_closing || wp->w_buffer->b_locked > 0)) {
          win_close_othertab(wp, false, tp);

          // Start all over, the tab page may be closed and
          // autocommands may change the window layout.
          nexttp = first_tabpage;
          break;
        }
      }
    }
  }

  RedrawingDisabled--;
}

/// Check if "win" is the last non-floating window that exists.
bool last_window(win_T *win) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return one_window(win) && first_tabpage->tp_next == NULL;
}

/// Check if "win" is the only non-floating window in the current tabpage.
///
/// This should be used in place of ONE_WINDOW when necessary,
/// with "firstwin" or the affected window as argument depending on the situation.
bool one_window(win_T *win) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(!firstwin->w_floating);
  return firstwin == win && (win->w_next == NULL || win->w_next->w_floating);
}

/// Check if floating windows in the current tab can be closed.
/// Do not call this when the autocommand window is in use!
///
/// @return true if all floating windows can be closed
static bool can_close_floating_windows(void)
{
  assert(!is_aucmd_win(lastwin));
  for (win_T *wp = lastwin; wp->w_floating; wp = wp->w_prev) {
    buf_T *buf = wp->w_buffer;
    int need_hide = (bufIsChanged(buf) && buf->b_nwindows <= 1);

    if (need_hide && !buf_hide(buf)) {
      return false;
    }
  }
  return true;
}

/// @return true if, considering the cmdwin, `win` is safe to close.
/// If false and `win` is the cmdwin, it is closed; otherwise, `err` is set.
bool can_close_in_cmdwin(win_T *win, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  if (cmdwin_type != 0) {
    if (win == cmdwin_win) {
      cmdwin_result = Ctrl_C;
      return false;
    } else if (win == cmdwin_old_curwin) {
      api_set_error(err, kErrorTypeException, "%s", e_cmdwin);
      return false;
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
/// @return false if there are other windows and nothing is done, true otherwise.
static bool close_last_window_tabpage(win_T *win, bool free_buf, tabpage_T *prev_curtab)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!ONE_WINDOW) {
    return false;
  }

  buf_T *old_curbuf = curbuf;

  Terminal *term = win->w_buffer ? win->w_buffer->terminal : NULL;
  if (term) {
    // Don't free terminal buffers
    free_buf = false;
  }

  // Closing the last window in a tab page.  First go to another tab
  // page and then close the window and the tab page.  This avoids that
  // curwin and curtab are invalid while we are freeing memory, they may
  // be used in GUI events.
  // Don't trigger autocommands yet, they may use wrong values, so do
  // that below.
  goto_tabpage_tp(alt_tabpage(), false, true);

  // Safety check: Autocommands may have closed the window when jumping
  // to the other tab page.
  if (valid_tabpage(prev_curtab) && prev_curtab->tp_firstwin == win) {
    win_close_othertab(win, free_buf, prev_curtab);
  }
  entering_window(curwin);

  // Since goto_tabpage_tp above did not trigger *Enter autocommands, do
  // that now.
  apply_autocmds(EVENT_WINENTER, NULL, NULL, false, curbuf);
  apply_autocmds(EVENT_TABENTER, NULL, NULL, false, curbuf);
  if (old_curbuf != curbuf) {
    apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
  }
  return true;
}

/// Close the buffer of "win" and unload it if "action" is DOBUF_UNLOAD.
/// "action" can also be zero (do nothing).
/// "abort_if_last" is passed to close_buffer(): abort closing if all other
/// windows are closed.
static void win_close_buffer(win_T *win, int action, bool abort_if_last)
  FUNC_ATTR_NONNULL_ALL
{
  // Free independent synblock before the buffer is freed.
  if (win->w_buffer != NULL) {
    reset_synblock(win);
  }

  // When a quickfix/location list window is closed and the buffer is
  // displayed in only one window, then unlist the buffer.
  if (win->w_buffer != NULL && bt_quickfix(win->w_buffer)
      && win->w_buffer->b_nwindows == 1) {
    win->w_buffer->b_p_bl = false;
  }

  // Close the link to the buffer.
  if (win->w_buffer != NULL) {
    bufref_T bufref;
    set_bufref(&bufref, curbuf);
    win->w_closing = true;
    close_buffer(win, win->w_buffer, action, abort_if_last, true);
    if (win_valid_any_tab(win)) {
      win->w_closing = false;
    }

    // Make sure curbuf is valid. It can become invalid if 'bufhidden' is
    // "wipe".
    if (!bufref_valid(&bufref)) {
      curbuf = firstbuf;
    }
  }
}

// Close window "win".  Only works for the current tab page.
// If "free_buf" is true related buffer may be unloaded.
//
// Called by :quit, :close, :xit, :wq and findtag().
// Returns FAIL when the window was not closed.
int win_close(win_T *win, bool free_buf, bool force)
  FUNC_ATTR_NONNULL_ALL
{
  tabpage_T *prev_curtab = curtab;
  frame_T *win_frame = win->w_floating ? NULL : win->w_frame->fr_parent;
  const bool had_diffmode = win->w_p_diff;

  if (last_window(win)) {
    emsg(_("E444: Cannot close last window"));
    return FAIL;
  }

  if (win->w_closing
      || (win->w_buffer != NULL && win->w_buffer->b_locked > 0)) {
    return FAIL;     // window is already being closed
  }
  if (is_aucmd_win(win)) {
    emsg(_(e_autocmd_close));
    return FAIL;
  }
  if (lastwin->w_floating && one_window(win)) {
    if (is_aucmd_win(lastwin)) {
      emsg(_("E814: Cannot close window, only autocmd window would remain"));
      return FAIL;
    }
    if (force || can_close_floating_windows()) {
      // close the last window until the there are no floating windows
      while (lastwin->w_floating) {
        // `force` flag isn't actually used when closing a floating window.
        if (win_close(lastwin, free_buf, true) == FAIL) {
          // If closing the window fails give up, to avoid looping forever.
          return FAIL;
        }
      }
      if (!win_valid_any_tab(win)) {
        return FAIL;  // window already closed by autocommands
      }
    } else {
      emsg(e_floatonly);
      return FAIL;
    }
  }

  // When closing the last window in a tab page first go to another tab page
  // and then close the window and the tab page to avoid that curwin and
  // curtab are invalid while we are freeing memory.
  if (close_last_window_tabpage(win, free_buf, prev_curtab)) {
    return FAIL;
  }

  bool help_window = false;

  // When closing the help window, try restoring a snapshot after closing
  // the window.  Otherwise clear the snapshot, it's now invalid.
  if (bt_help(win->w_buffer)) {
    help_window = true;
  } else {
    clear_snapshot(curtab, SNAP_HELP_IDX);
  }

  win_T *wp;
  bool other_buffer = false;

  if (win == curwin) {
    leaving_window(curwin);

    // Guess which window is going to be the new current window.
    // This may change because of the autocommands (sigh).
    if (!win->w_floating) {
      wp = frame2win(win_altframe(win, NULL));
    } else {
      if (win_valid(prevwin) && prevwin != win) {
        wp = prevwin;
      } else {
        wp = firstwin;
      }
    }

    // Be careful: If autocommands delete the window or cause this window
    // to be the last one left, return now.
    if (wp->w_buffer != curbuf) {
      reset_VIsual_and_resel();  // stop Visual mode

      other_buffer = true;
      if (!win_valid(win)) {
        return FAIL;
      }
      win->w_closing = true;
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, false, curbuf);
      if (!win_valid(win)) {
        return FAIL;
      }
      win->w_closing = false;
      if (last_window(win)) {
        return FAIL;
      }
    }
    win->w_closing = true;
    apply_autocmds(EVENT_WINLEAVE, NULL, NULL, false, curbuf);
    if (!win_valid(win)) {
      return FAIL;
    }
    win->w_closing = false;
    if (last_window(win)) {
      return FAIL;
    }
    // autocmds may abort script processing
    if (aborting()) {
      return FAIL;
    }
  }

  // Fire WinClosed just before starting to free window-related resources.
  do_autocmd_winclosed(win);
  // autocmd may have freed the window already.
  if (!win_valid_any_tab(win)) {
    return OK;
  }

  win_close_buffer(win, free_buf ? DOBUF_UNLOAD : 0, true);

  if (win_valid(win) && win->w_buffer == NULL
      && !win->w_floating && last_window(win)) {
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
  if (!win_valid(win) || (!win->w_floating && last_window(win))
      || close_last_window_tabpage(win, free_buf, prev_curtab)) {
    return FAIL;
  }

  // Now we are really going to close the window.  Disallow any autocommand
  // to split a window to avoid trouble.
  split_disallowed++;

  // let terminal buffers know that this window dimensions may be ignored
  win->w_closing = true;

  bool was_floating = win->w_floating;
  if (ui_has(kUIMultigrid)) {
    ui_call_win_close(win->w_grid_alloc.handle);
  }

  if (win->w_floating) {
    ui_comp_remove_grid(&win->w_grid_alloc);
    assert(first_tabpage != NULL);  // suppress clang "Dereference of NULL pointer"
    if (win->w_config.external) {
      FOR_ALL_TABS(tp) {
        if (tp != curtab && tp->tp_curwin == win) {
          // NB: an autocmd can still abort the closing of this window,
          // but carrying out this change anyway shouldn't be a catastrophe.
          tp->tp_curwin = tp->tp_firstwin;
        }
      }
    }
  }

  // Free the memory used for the window and get the window that received
  // the screen space.
  int dir;
  wp = win_free_mem(win, &dir, NULL);

  if (help_window) {
    // Closing the help window moves the cursor back to the current window
    // of the snapshot.
    win_T *prev_win = get_snapshot_curwin(SNAP_HELP_IDX);
    if (win_valid(prev_win)) {
      wp = prev_win;
    }
  }

  bool close_curwin = false;

  // Make sure curwin isn't invalid.  It can cause severe trouble when
  // printing an error message.  For win_equal() curbuf needs to be valid
  // too.
  if (win == curwin) {
    curwin = wp;
    if (wp->w_p_pvw || bt_quickfix(wp->w_buffer)) {
      // If the cursor goes to the preview or the quickfix window, try
      // finding another window to go to.
      while (true) {
        if (wp->w_next == NULL) {
          wp = firstwin;
        } else {
          wp = wp->w_next;
        }
        if (wp == curwin) {
          break;
        }
        if (!wp->w_p_pvw && !bt_quickfix(wp->w_buffer)) {
          curwin = wp;
          break;
        }
      }
    }
    curbuf = curwin->w_buffer;
    close_curwin = true;

    // The cursor position may be invalid if the buffer changed after last
    // using the window.
    check_cursor(curwin);
  }

  if (!was_floating) {
    // If last window has a status line now and we don't want one,
    // remove the status line. Do this before win_equal(), because
    // it may change the height of a window.
    last_status(false);

    if (!curwin->w_floating && p_ea && (*p_ead == 'b' || *p_ead == dir)) {
      // If the frame of the closed window contains the new current window,
      // only resize that frame.  Otherwise resize all windows.
      win_equal(curwin, curwin->w_frame->fr_parent == win_frame, dir);
    } else {
      win_comp_pos();
      win_fix_scroll(false);
    }
  }

  if (close_curwin) {
    win_enter_ext(wp, WEE_CURWIN_INVALID | WEE_TRIGGER_ENTER_AUTOCMDS
                  | WEE_TRIGGER_LEAVE_AUTOCMDS);
    if (other_buffer) {
      // careful: after this wp and win may be invalid!
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
    }
  }

  split_disallowed--;

  // After closing the help window, try restoring the window layout from
  // before it was opened.
  if (help_window) {
    restore_snapshot(SNAP_HELP_IDX, close_curwin);
  }

  // If the window had 'diff' set and now there is only one window left in
  // the tab page with 'diff' set, and "closeoff" is in 'diffopt', then
  // execute ":diffoff!".
  if (diffopt_closeoff() && had_diffmode && curtab == prev_curtab) {
    int diffcount = 0;

    FOR_ALL_WINDOWS_IN_TAB(dwin, curtab) {
      if (dwin->w_p_diff) {
        diffcount++;
      }
    }
    if (diffcount == 1) {
      do_cmdline_cmd("diffoff!");
    }
  }

  curwin->w_pos_changed = true;
  if (!was_floating) {
    // TODO(bfredl): how about no?
    redraw_all_later(UPD_NOT_VALID);
  }
  return OK;
}

static void do_autocmd_winclosed(win_T *win)
  FUNC_ATTR_NONNULL_ALL
{
  static bool recursive = false;
  if (recursive || !has_event(EVENT_WINCLOSED)) {
    return;
  }
  recursive = true;
  char winid[NUMBUFLEN];
  vim_snprintf(winid, sizeof(winid), "%d", win->handle);
  apply_autocmds(EVENT_WINCLOSED, winid, winid, false, win->w_buffer);
  recursive = false;
}

// Close window "win" in tab page "tp", which is not the current tab page.
// This may be the last window in that tab page and result in closing the tab,
// thus "tp" may become invalid!
// Caller must check if buffer is hidden and whether the tabline needs to be
// updated.
void win_close_othertab(win_T *win, int free_buf, tabpage_T *tp)
  FUNC_ATTR_NONNULL_ALL
{
  // Get here with win->w_buffer == NULL when win_close() detects the tab page
  // changed.
  if (win->w_closing
      || (win->w_buffer != NULL && win->w_buffer->b_locked > 0)) {
    return;  // window is already being closed
  }

  // Fire WinClosed just before starting to free window-related resources.
  // If the buffer is NULL, it isn't safe to trigger autocommands,
  // and win_close() should have already triggered WinClosed.
  if (win->w_buffer != NULL) {
    do_autocmd_winclosed(win);
    // autocmd may have freed the window already.
    if (!win_valid_any_tab(win)) {
      return;
    }
  }

  if (win->w_buffer != NULL) {
    // Close the link to the buffer.
    close_buffer(win, win->w_buffer, free_buf ? DOBUF_UNLOAD : 0, false, true);
  }

  tabpage_T *ptp = NULL;

  // Careful: Autocommands may have closed the tab page or made it the
  // current tab page.
  for (ptp = first_tabpage; ptp != NULL && ptp != tp; ptp = ptp->tp_next) {}
  if (ptp == NULL || tp == curtab) {
    // If the buffer was removed from the window we have to give it any
    // buffer.
    if (win_valid_any_tab(win) && win->w_buffer == NULL) {
      win->w_buffer = firstbuf;
      firstbuf->b_nwindows++;
      win_init_empty(win);
    }
    return;
  }

  // Autocommands may have closed the window already.
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

  bool free_tp = false;

  // When closing the last window in a tab page remove the tab page.
  if (tp->tp_firstwin == tp->tp_lastwin) {
    char prev_idx[NUMBUFLEN];
    if (has_event(EVENT_TABCLOSED)) {
      vim_snprintf(prev_idx, NUMBUFLEN, "%i", tabpage_index(tp));
    }

    int h = tabline_height();

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
    redraw_tabline = true;
    if (h != tabline_height()) {
      win_new_screen_rows();
    }

    if (has_event(EVENT_TABCLOSED)) {
      apply_autocmds(EVENT_TABCLOSED, prev_idx, prev_idx, false, win->w_buffer);
    }
  }

  // Free the memory used for the window.
  int dir;
  win_free_mem(win, &dir, tp);

  if (free_tp) {
    free_tabpage(tp);
  }
}

/// Free the memory used for a window.
///
/// @param dirp  set to 'v' or 'h' for direction if 'ea'
/// @param tp    tab page "win" is in, NULL for current
///
/// @return      a pointer to the window that got the freed up space.
static win_T *win_free_mem(win_T *win, int *dirp, tabpage_T *tp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  win_T *wp;
  tabpage_T *win_tp = tp == NULL ? curtab : tp;

  if (!win->w_floating) {
    // Remove the window and its frame from the tree of frames.
    frame_T *frp = win->w_frame;
    wp = winframe_remove(win, dirp, tp, NULL);
    xfree(frp);
  } else {
    *dirp = 'h';  // Dummy value.
    wp = win_float_find_altwin(win, tp);
  }
  win_free(win, tp);

  // When deleting the current window in the tab, select a new current
  // window.
  if (win == win_tp->tp_curwin) {
    win_tp->tp_curwin = wp;
  }

  return wp;
}

#if defined(EXITFREE)
void win_free_all(void)
{
  // avoid an error for switching tabpage with the cmdline window open
  cmdwin_type = 0;
  cmdwin_buf = NULL;
  cmdwin_win = NULL;
  cmdwin_old_curwin = NULL;

  while (first_tabpage->tp_next != NULL) {
    tabpage_close(true);
  }

  while (lastwin != NULL && lastwin->w_floating) {
    win_T *wp = lastwin;
    win_remove(lastwin, NULL);
    int dummy;
    win_free_mem(wp, &dummy, NULL);
    for (int i = 0; i < AUCMD_WIN_COUNT; i++) {
      if (aucmd_win[i].auc_win == wp) {
        aucmd_win[i].auc_win = NULL;
      }
    }
  }

  for (int i = 0; i < AUCMD_WIN_COUNT; i++) {
    if (aucmd_win[i].auc_win != NULL) {
      int dummy;
      win_free_mem(aucmd_win[i].auc_win, &dummy, NULL);
      aucmd_win[i].auc_win = NULL;
    }
  }

  kv_destroy(aucmd_win_vec);

  while (firstwin != NULL) {
    int dummy;
    win_free_mem(firstwin, &dummy, NULL);
  }

  // No window should be used after this. Set curwin to NULL to crash
  // instead of using freed memory.
  curwin = NULL;
}

#endif

/// Remove a window and its frame from the tree of frames.
///
/// @param dirp  set to 'v' or 'h' for direction if 'ea'
/// @param tp    tab page "win" is in, NULL for current
/// @param unflat_altfr if not NULL, set to pointer of frame that got
///                     the space, and it is not flattened
///
/// @return      a pointer to the window that got the freed up space.
win_T *winframe_remove(win_T *win, int *dirp, tabpage_T *tp, frame_T **unflat_altfr)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  frame_T *altfr;
  win_T *wp = winframe_find_altwin(win, dirp, tp, &altfr);
  if (wp == NULL) {
    return NULL;
  }

  frame_T *frp_close = win->w_frame;

  // Save the position of the containing frame (which will also contain the
  // altframe) before we remove anything, to recompute window positions later.
  const win_T *const topleft = frame2win(frp_close->fr_parent);
  int row = topleft->w_winrow;
  int col = topleft->w_wincol;

  // Remove this frame from the list of frames.
  frame_remove(frp_close);

  if (*dirp == 'v') {
    frame_new_height(altfr, altfr->fr_height + frp_close->fr_height,
                     altfr == frp_close->fr_next, false);
  } else {
    assert(*dirp == 'h');
    frame_new_width(altfr, altfr->fr_width + frp_close->fr_width,
                    altfr == frp_close->fr_next, false);
  }

  // If the altframe wasn't adjacent and left/above, resizing it will have
  // changed window positions within the parent frame.  Recompute them.
  if (altfr != frp_close->fr_prev) {
    frame_comp_pos(frp_close->fr_parent, &row, &col);
  }

  if (unflat_altfr == NULL) {
    frame_flatten(altfr);
  } else {
    *unflat_altfr = altfr;
  }

  return wp;
}

/// Find the window that will get the freed space from a call to `winframe_remove`.
/// Makes no changes to the window layout.
///
/// @param dirp  set to 'v' or 'h' for the direction where "altfr" will be resized
///              to fill the space
/// @param tp    tab page "win" is in, NULL for current
/// @param altfr if not NULL, set to pointer of frame that will get the space
///
/// @return      a pointer to the window that will get the freed up space.
win_T *winframe_find_altwin(win_T *win, int *dirp, tabpage_T *tp, frame_T **altfr)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  assert(tp == NULL || tp != curtab);

  // If there is only one window there is nothing to remove.
  if (tp == NULL ? ONE_WINDOW : tp->tp_firstwin == tp->tp_lastwin) {
    return NULL;
  }

  frame_T *frp_close = win->w_frame;

  // Find the window and frame that gets the space.
  frame_T *frp2 = win_altframe(win, tp);
  win_T *wp = frame2win(frp2);

  if (frp_close->fr_parent->fr_layout == FR_COL) {
    // When 'winfixheight' is set, try to find another frame in the column
    // (as close to the closed frame as possible) to distribute the height
    // to.
    if (frp2->fr_win != NULL && frp2->fr_win->w_p_wfh) {
      frame_T *frp = frp_close->fr_prev;
      frame_T *frp3 = frp_close->fr_next;
      while (frp != NULL || frp3 != NULL) {
        if (frp != NULL) {
          if (!frame_fixed_height(frp)) {
            frp2 = frp;
            wp = frame2win(frp2);
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
    *dirp = 'v';
  } else {
    // When 'winfixwidth' is set, try to find another frame in the column
    // (as close to the closed frame as possible) to distribute the width
    // to.
    if (frp2->fr_win != NULL && frp2->fr_win->w_p_wfw) {
      frame_T *frp = frp_close->fr_prev;
      frame_T *frp3 = frp_close->fr_next;
      while (frp != NULL || frp3 != NULL) {
        if (frp != NULL) {
          if (!frame_fixed_width(frp)) {
            frp2 = frp;
            wp = frame2win(frp2);
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
    *dirp = 'h';
  }

  assert(wp != win && frp2 != frp_close);
  if (altfr != NULL) {
    *altfr = frp2;
  }

  return wp;
}

/// Flatten "frp" into its parent frame if it's the only child, also merging its
/// list with the grandparent if they share the same layout.
/// Frees "frp" if flattened; also "frp->fr_parent" if it has the same layout.
static void frame_flatten(frame_T *frp)
  FUNC_ATTR_NONNULL_ALL
{
  if (frp->fr_next != NULL || frp->fr_prev != NULL) {
    return;
  }

  // There is no other frame in this list, move its info to the parent
  // and remove it.
  frp->fr_parent->fr_layout = frp->fr_layout;
  frp->fr_parent->fr_child = frp->fr_child;
  frame_T *frp2;
  FOR_ALL_FRAMES(frp2, frp->fr_child) {
    frp2->fr_parent = frp->fr_parent;
  }
  frp->fr_parent->fr_win = frp->fr_win;
  if (frp->fr_win != NULL) {
    frp->fr_win->w_frame = frp->fr_parent;
  }
  frp2 = frp->fr_parent;
  if (topframe->fr_child == frp) {
    topframe->fr_child = frp2;
  }
  xfree(frp);

  frp = frp2->fr_parent;
  if (frp != NULL && frp->fr_layout == frp2->fr_layout) {
    // The frame above the parent has the same layout, have to merge
    // the frames into this list.
    if (frp->fr_child == frp2) {
      frp->fr_child = frp2->fr_child;
    }
    assert(frp2->fr_child);
    frp2->fr_child->fr_prev = frp2->fr_prev;
    if (frp2->fr_prev != NULL) {
      frp2->fr_prev->fr_next = frp2->fr_child;
    }
    for (frame_T *frp3 = frp2->fr_child;; frp3 = frp3->fr_next) {
      frp3->fr_parent = frp;
      if (frp3->fr_next == NULL) {
        frp3->fr_next = frp2->fr_next;
        if (frp2->fr_next != NULL) {
          frp2->fr_next->fr_prev = frp3;
        }
        break;
      }
    }
    if (topframe->fr_child == frp2) {
      topframe->fr_child = frp;
    }
    xfree(frp2);
  }
}

/// Undo changes from a prior call to winframe_remove, also restoring lost
/// vertical separators and statuslines, and changed window positions for
/// windows within "unflat_altfr".
/// Caller must ensure no other changes were made to the layout or window sizes!
void winframe_restore(win_T *wp, int dir, frame_T *unflat_altfr)
  FUNC_ATTR_NONNULL_ALL
{
  frame_T *frp = wp->w_frame;

  // Put "wp"'s frame back where it was.
  if (frp->fr_prev != NULL) {
    frame_append(frp->fr_prev, frp);
  } else {
    frame_insert(frp->fr_next, frp);
  }

  // Vertical separators to the left may have been lost.  Restore them.
  if (wp->w_vsep_width == 0 && frp->fr_parent->fr_layout == FR_ROW && frp->fr_prev != NULL) {
    frame_add_vsep(frp->fr_prev);
  }

  // Statuslines or horizontal separators above may have been lost.  Restore them.
  if (frp->fr_parent->fr_layout == FR_COL && frp->fr_prev != NULL) {
    if (global_stl_height() == 0 && wp->w_status_height == 0) {
      frame_add_statusline(frp->fr_prev);
    } else if (wp->w_hsep_height == 0) {
      frame_add_hsep(frp->fr_prev);
    }
  }

  // Restore the lost room that was redistributed to the altframe.  Also
  // adjusts window sizes to fit restored statuslines/separators, if needed.
  if (dir == 'v') {
    frame_new_height(unflat_altfr, unflat_altfr->fr_height - frp->fr_height,
                     unflat_altfr == frp->fr_next, false);
  } else if (dir == 'h') {
    frame_new_width(unflat_altfr, unflat_altfr->fr_width - frp->fr_width,
                    unflat_altfr == frp->fr_next, false);
  }

  // Recompute window positions within the parent frame to restore them.
  // Positions were unchanged if the altframe was adjacent and left/above.
  if (unflat_altfr != frp->fr_prev) {
    const win_T *const topleft = frame2win(frp->fr_parent);
    int row = topleft->w_winrow;
    int col = topleft->w_wincol;

    frame_comp_pos(frp->fr_parent, &row, &col);
  }
}

/// If 'splitbelow' or 'splitright' is set, the space goes above or to the left
/// by default.  Otherwise, the free space goes below or to the right.  The
/// result is that opening a window and then immediately closing it will
/// preserve the initial window layout.  The 'wfh' and 'wfw' settings are
/// respected when possible.
///
/// @param  tp  tab page "win" is in, NULL for current
///
/// @return a pointer to the frame that will receive the empty screen space that
/// is left over after "win" is closed.
static frame_T *win_altframe(win_T *win, tabpage_T *tp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  assert(tp == NULL || tp != curtab);

  if (tp == NULL ? ONE_WINDOW : tp->tp_firstwin == tp->tp_lastwin) {
    return alt_tabpage()->tp_curwin->w_frame;
  }

  frame_T *frp = win->w_frame;

  if (frp->fr_prev == NULL) {
    return frp->fr_next;
  }
  if (frp->fr_next == NULL) {
    return frp->fr_prev;
  }

  // By default the next window will get the space that was abandoned by this
  // window
  frame_T *target_fr = frp->fr_next;
  frame_T *other_fr = frp->fr_prev;

  // If this is part of a column of windows and 'splitbelow' is true then the
  // previous window will get the space.
  if (frp->fr_parent != NULL && frp->fr_parent->fr_layout == FR_COL && p_sb) {
    target_fr = frp->fr_prev;
    other_fr = frp->fr_next;
  }

  // If this is part of a row of windows, and 'splitright' is true then the
  // previous window will get the space.
  if (frp->fr_parent != NULL && frp->fr_parent->fr_layout == FR_ROW && p_spr) {
    target_fr = frp->fr_prev;
    other_fr = frp->fr_next;
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

// Return the tabpage that will be used if the current one is closed.
static tabpage_T *alt_tabpage(void)
{
  // Use the next tab page if possible.
  if (curtab->tp_next != NULL) {
    return curtab->tp_next;
  }

  // Find the last but one tab page.
  tabpage_T *tp;
  for (tp = first_tabpage; tp->tp_next != curtab; tp = tp->tp_next) {}
  return tp;
}

// Find the left-upper window in frame "frp".
win_T *frame2win(frame_T *frp)
  FUNC_ATTR_NONNULL_ALL
{
  while (frp->fr_win == NULL) {
    frp = frp->fr_child;
  }
  return frp->fr_win;
}

/// Check that the frame "frp" contains the window "wp".
///
/// @param  frp  frame
/// @param  wp   window
static bool frame_has_win(const frame_T *frp, const win_T *wp)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  if (frp->fr_layout == FR_LEAF) {
    return frp->fr_win == wp;
  }
  const frame_T *p;
  FOR_ALL_FRAMES(p, frp->fr_child) {
    if (frame_has_win(p, wp)) {
      return true;
    }
  }
  return false;
}

/// Check if current window is at the bottom
/// Returns true if there are no windows below current window
static bool is_bottom_win(win_T *wp)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  for (frame_T *frp = wp->w_frame; frp->fr_parent != NULL; frp = frp->fr_parent) {
    if (frp->fr_parent->fr_layout == FR_COL && frp->fr_next != NULL) {
      return false;
    }
  }
  return true;
}
/// Set a new height for a frame.  Recursively sets the height for contained
/// frames and windows.  Caller must take care of positions.
///
/// @param topfirst  resize topmost contained frame first.
/// @param wfh       obey 'winfixheight' when there is a choice;
///                  may cause the height not to be set.
void frame_new_height(frame_T *topfrp, int height, bool topfirst, bool wfh)
  FUNC_ATTR_NONNULL_ALL
{
  if (topfrp->fr_win != NULL) {
    // Simple case: just one window.
    win_T *wp = topfrp->fr_win;
    if (is_bottom_win(wp)) {
      wp->w_hsep_height = 0;
    }
    win_new_height(wp, height - wp->w_hsep_height - wp->w_status_height);
  } else if (topfrp->fr_layout == FR_ROW) {
    frame_T *frp;
    do {
      // All frames in this row get the same new height.
      FOR_ALL_FRAMES(frp, topfrp->fr_child) {
        frame_new_height(frp, height, topfirst, wfh);
        if (frp->fr_height > height) {
          // Could not fit the windows, make the whole row higher.
          height = frp->fr_height;
          break;
        }
      }
    } while (frp != NULL);
  } else {  // fr_layout == FR_COL
    // Complicated case: Resize a column of frames.  Resize the bottom
    // frame first, frames above that when needed.

    frame_T *frp = topfrp->fr_child;
    if (wfh) {
      // Advance past frames with one window with 'wfh' set.
      while (frame_fixed_height(frp)) {
        frp = frp->fr_next;
        if (frp == NULL) {
          return;                   // no frame without 'wfh', give up
        }
      }
    }
    if (!topfirst) {
      // Find the bottom frame of this column
      while (frp->fr_next != NULL) {
        frp = frp->fr_next;
      }
      if (wfh) {
        // Advance back for frames with one window with 'wfh' set.
        while (frame_fixed_height(frp)) {
          frp = frp->fr_prev;
        }
      }
    }

    int extra_lines = height - topfrp->fr_height;
    if (extra_lines < 0) {
      // reduce height of contained frames, bottom or top frame first
      while (frp != NULL) {
        int h = frame_minheight(frp, NULL);
        if (frp->fr_height + extra_lines < h) {
          extra_lines += frp->fr_height - h;
          frame_new_height(frp, h, topfirst, wfh);
        } else {
          frame_new_height(frp, frp->fr_height + extra_lines,
                           topfirst, wfh);
          break;
        }
        if (topfirst) {
          do {
            frp = frp->fr_next;
          } while (wfh && frp != NULL && frame_fixed_height(frp));
        } else {
          do {
            frp = frp->fr_prev;
          } while (wfh && frp != NULL && frame_fixed_height(frp));
        }
        // Increase "height" if we could not reduce enough frames.
        if (frp == NULL) {
          height -= extra_lines;
        }
      }
    } else if (extra_lines > 0) {
      // increase height of bottom or top frame
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
    FOR_ALL_FRAMES(frp, frp->fr_child) {
      if (frame_fixed_height(frp)) {
        return true;
      }
    }
    return false;
  }

  // frp->fr_layout == FR_COL: The frame is fixed height if all of the
  // frames in the row are fixed height.
  FOR_ALL_FRAMES(frp, frp->fr_child) {
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
    FOR_ALL_FRAMES(frp, frp->fr_child) {
      if (frame_fixed_width(frp)) {
        return true;
      }
    }
    return false;
  }

  // frp->fr_layout == FR_ROW: The frame is fixed width if all of the
  // frames in the row are fixed width.
  FOR_ALL_FRAMES(frp, frp->fr_child) {
    if (!frame_fixed_width(frp)) {
      return false;
    }
  }
  return true;
}

// Add a status line to windows at the bottom of "frp".
// Note: Does not check if there is room!
static void frame_add_statusline(frame_T *frp)
{
  if (frp->fr_layout == FR_LEAF) {
    win_T *wp = frp->fr_win;
    wp->w_status_height = STATUS_HEIGHT;
  } else if (frp->fr_layout == FR_ROW) {
    // Handle all the frames in the row.
    FOR_ALL_FRAMES(frp, frp->fr_child) {
      frame_add_statusline(frp);
    }
  } else {
    assert(frp->fr_layout == FR_COL);
    // Only need to handle the last frame in the column.
    for (frp = frp->fr_child; frp->fr_next != NULL; frp = frp->fr_next) {}
    frame_add_statusline(frp);
  }
}

/// Set width of a frame.  Handles recursively going through contained frames.
/// May remove separator line for windows at the right side (for win_close()).
///
/// @param leftfirst  resize leftmost contained frame first.
/// @param wfw        obey 'winfixwidth' when there is a choice;
///                   may cause the width not to be set.
static void frame_new_width(frame_T *topfrp, int width, bool leftfirst, bool wfw)
{
  if (topfrp->fr_layout == FR_LEAF) {
    // Simple case: just one window.
    win_T *wp = topfrp->fr_win;
    // Find out if there are any windows right of this one.
    frame_T *frp;
    for (frp = topfrp; frp->fr_parent != NULL; frp = frp->fr_parent) {
      if (frp->fr_parent->fr_layout == FR_ROW && frp->fr_next != NULL) {
        break;
      }
    }
    if (frp->fr_parent == NULL) {
      wp->w_vsep_width = 0;
    }
    win_new_width(wp, width - wp->w_vsep_width);
  } else if (topfrp->fr_layout == FR_COL) {
    frame_T *frp;
    do {
      // All frames in this column get the same new width.
      FOR_ALL_FRAMES(frp, topfrp->fr_child) {
        frame_new_width(frp, width, leftfirst, wfw);
        if (frp->fr_width > width) {
          // Could not fit the windows, make whole column wider.
          width = frp->fr_width;
          break;
        }
      }
    } while (frp != NULL);
  } else {  // fr_layout == FR_ROW
    // Complicated case: Resize a row of frames.  Resize the rightmost
    // frame first, frames left of it when needed.

    frame_T *frp = topfrp->fr_child;
    if (wfw) {
      // Advance past frames with one window with 'wfw' set.
      while (frame_fixed_width(frp)) {
        frp = frp->fr_next;
        if (frp == NULL) {
          return;                   // no frame without 'wfw', give up
        }
      }
    }
    if (!leftfirst) {
      // Find the rightmost frame of this row
      while (frp->fr_next != NULL) {
        frp = frp->fr_next;
      }
      if (wfw) {
        // Advance back for frames with one window with 'wfw' set.
        while (frame_fixed_width(frp)) {
          frp = frp->fr_prev;
        }
      }
    }

    int extra_cols = width - topfrp->fr_width;
    if (extra_cols < 0) {
      // reduce frame width, rightmost frame first
      while (frp != NULL) {
        int w = frame_minwidth(frp, NULL);
        if (frp->fr_width + extra_cols < w) {
          extra_cols += frp->fr_width - w;
          frame_new_width(frp, w, leftfirst, wfw);
        } else {
          frame_new_width(frp, frp->fr_width + extra_cols,
                          leftfirst, wfw);
          break;
        }
        if (leftfirst) {
          do {
            frp = frp->fr_next;
          } while (wfw && frp != NULL && frame_fixed_width(frp));
        } else {
          do {
            frp = frp->fr_prev;
          } while (wfw && frp != NULL && frame_fixed_width(frp));
        }
        // Increase "width" if we could not reduce enough frames.
        if (frp == NULL) {
          width -= extra_cols;
        }
      }
    } else if (extra_cols > 0) {
      // increase width of rightmost frame
      frame_new_width(frp, frp->fr_width + extra_cols, leftfirst, wfw);
    }
  }
  topfrp->fr_width = width;
}

/// Add the vertical separator to windows at the right side of "frp".
/// Note: Does not check if there is room!
static void frame_add_vsep(const frame_T *frp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (frp->fr_layout == FR_LEAF) {
    win_T *wp = frp->fr_win;
    if (wp->w_vsep_width == 0) {
      if (wp->w_width > 0) {            // don't make it negative
        wp->w_width--;
      }
      wp->w_vsep_width = 1;
    }
  } else if (frp->fr_layout == FR_COL) {
    // Handle all the frames in the column.
    FOR_ALL_FRAMES(frp, frp->fr_child) {
      frame_add_vsep(frp);
    }
  } else {
    assert(frp->fr_layout == FR_ROW);
    // Only need to handle the last frame in the row.
    frp = frp->fr_child;
    while (frp->fr_next != NULL) {
      frp = frp->fr_next;
    }
    frame_add_vsep(frp);
  }
}

/// Add the horizontal separator to windows at the bottom of "frp".
/// Note: Does not check if there is room or whether the windows have a statusline!
static void frame_add_hsep(const frame_T *frp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (frp->fr_layout == FR_LEAF) {
    win_T *wp = frp->fr_win;
    wp->w_hsep_height = 1;
  } else if (frp->fr_layout == FR_ROW) {
    // Handle all the frames in the row.
    FOR_ALL_FRAMES(frp, frp->fr_child) {
      frame_add_hsep(frp);
    }
  } else {
    assert(frp->fr_layout == FR_COL);
    // Only need to handle the last frame in the column.
    frp = frp->fr_child;
    while (frp->fr_next != NULL) {
      frp = frp->fr_next;
    }
    frame_add_hsep(frp);
  }
}

// Set frame width from the window it contains.
static void frame_fix_width(win_T *wp)
{
  wp->w_frame->fr_width = wp->w_width + wp->w_vsep_width;
}

// Set frame height from the window it contains.
static void frame_fix_height(win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  wp->w_frame->fr_height = wp->w_height + wp->w_hsep_height + wp->w_status_height;
}

/// Compute the minimal height for frame "topfrp". Uses the 'winminheight' option.
/// When "next_curwin" isn't NULL, use p_wh for this window.
/// When "next_curwin" is NOWIN, don't use at least one line for the current window.
static int frame_minheight(frame_T *topfrp, win_T *next_curwin)
{
  int m;

  if (topfrp->fr_win != NULL) {
    // Combined height of window bar and separator column or status line.
    int extra_height = topfrp->fr_win->w_winbar_height + topfrp->fr_win->w_hsep_height
                       + topfrp->fr_win->w_status_height;

    if (topfrp->fr_win == next_curwin) {
      m = (int)p_wh + extra_height;
    } else {
      m = (int)p_wmh + extra_height;
      if (topfrp->fr_win == curwin && next_curwin == NULL) {
        // Current window is minimal one line high.
        if (p_wmh == 0) {
          m++;
        }
      }
    }
  } else if (topfrp->fr_layout == FR_ROW) {
    // get the minimal height from each frame in this row
    m = 0;
    frame_T *frp;
    FOR_ALL_FRAMES(frp, topfrp->fr_child) {
      int n = frame_minheight(frp, next_curwin);
      if (n > m) {
        m = n;
      }
    }
  } else {
    // Add up the minimal heights for all frames in this column.
    m = 0;
    frame_T *frp;
    FOR_ALL_FRAMES(frp, topfrp->fr_child) {
      m += frame_minheight(frp, next_curwin);
    }
  }

  return m;
}

/// Compute the minimal width for frame "topfrp".
/// When "next_curwin" isn't NULL, use p_wiw for this window.
/// When "next_curwin" is NOWIN, don't use at least one column for the current
/// window.
///
/// @param next_curwin  use p_wh and p_wiw for next_curwin
static int frame_minwidth(frame_T *topfrp, win_T *next_curwin)
{
  int m;

  if (topfrp->fr_win != NULL) {
    if (topfrp->fr_win == next_curwin) {
      m = (int)p_wiw + topfrp->fr_win->w_vsep_width;
    } else {
      // window: minimal width of the window plus separator column
      m = (int)p_wmw + topfrp->fr_win->w_vsep_width;
      // Current window is minimal one column wide
      if (p_wmw == 0 && topfrp->fr_win == curwin && next_curwin == NULL) {
        m++;
      }
    }
  } else if (topfrp->fr_layout == FR_COL) {
    // get the minimal width from each frame in this column
    m = 0;
    frame_T *frp;
    FOR_ALL_FRAMES(frp, topfrp->fr_child) {
      int n = frame_minwidth(frp, next_curwin);
      if (n > m) {
        m = n;
      }
    }
  } else {
    // Add up the minimal widths for all frames in this row.
    m = 0;
    frame_T *frp;
    FOR_ALL_FRAMES(frp, topfrp->fr_child) {
      m += frame_minwidth(frp, next_curwin);
    }
  }

  return m;
}

/// Try to close all windows except current one.
/// Buffers in the other windows become hidden if 'hidden' is set, or '!' is
/// used and the buffer was modified.
///
/// Used by ":bdel" and ":only".
///
/// @param forceit  always hide all other windows
void close_others(int message, int forceit)
{
  if (curwin->w_floating) {
    if (message && !autocmd_busy) {
      emsg(e_floatonly);
    }
    return;
  }

  if (one_window(firstwin) && !lastwin->w_floating) {
    if (message
        && !autocmd_busy) {
      msg(_(m_onlyone), 0);
    }
    return;
  }

  // Be very careful here: autocommands may change the window layout.
  win_T *nextwp;
  for (win_T *wp = firstwin; win_valid(wp); wp = nextwp) {
    nextwp = wp->w_next;
    if (wp == curwin) {                 // don't close current window
      continue;
    }

    // autoccommands messed this one up
    if (!buf_valid(wp->w_buffer) && win_valid(wp)) {
      wp->w_buffer = NULL;
      win_close(wp, false, false);
      continue;
    }
    // Check if it's allowed to abandon this window
    int r = can_abandon(wp->w_buffer, forceit);
    if (!win_valid(wp)) {             // autocommands messed wp up
      nextwp = firstwin;
      continue;
    }
    if (!r) {
      if (message && (p_confirm || (cmdmod.cmod_flags & CMOD_CONFIRM)) && p_write) {
        dialog_changed(wp->w_buffer, false);
        if (!win_valid(wp)) {                 // autocommands messed wp up
          nextwp = firstwin;
          continue;
        }
      }
      if (bufIsChanged(wp->w_buffer)) {
        continue;
      }
    }
    win_close(wp, !buf_hide(wp->w_buffer) && !bufIsChanged(wp->w_buffer), false);
  }

  if (message && !ONE_WINDOW) {
    emsg(_("E445: Other window contains changes"));
  }
}

/// Store the relevant window pointers for tab page "tp".  To be used before
/// use_tabpage().
void unuse_tabpage(tabpage_T *tp)
{
  tp->tp_topframe = topframe;
  tp->tp_firstwin = firstwin;
  tp->tp_lastwin = lastwin;
  tp->tp_curwin = curwin;
}

/// Set the relevant pointers to use tab page "tp".  May want to call
/// unuse_tabpage() first.
void use_tabpage(tabpage_T *tp)
{
  curtab = tp;
  topframe = curtab->tp_topframe;
  firstwin = curtab->tp_firstwin;
  lastwin = curtab->tp_lastwin;
  curwin = curtab->tp_curwin;
}

// Allocate the first window and put an empty buffer in it.
// Only called from main().
void win_alloc_first(void)
{
  if (win_alloc_firstwin(NULL) == FAIL) {
    // allocating first buffer before any autocmds should not fail.
    abort();
  }

  first_tabpage = alloc_tabpage();
  curtab = first_tabpage;
  unuse_tabpage(first_tabpage);
}

// Init `aucmd_win[idx]`. This can only be done after the first window
// is fully initialized, thus it can't be in win_alloc_first().
void win_alloc_aucmd_win(int idx)
{
  Error err = ERROR_INIT;
  WinConfig fconfig = WIN_CONFIG_INIT;
  fconfig.width = Columns;
  fconfig.height = 5;
  fconfig.focusable = false;
  aucmd_win[idx].auc_win = win_new_float(NULL, true, fconfig, &err);
  aucmd_win[idx].auc_win->w_buffer->b_nwindows--;
  RESET_BINDING(aucmd_win[idx].auc_win);
}

// Allocate the first window or the first window in a new tab page.
// When "oldwin" is NULL create an empty buffer for it.
// When "oldwin" is not NULL copy info from it to the new window.
// Return FAIL when something goes wrong (out of memory).
static int win_alloc_firstwin(win_T *oldwin)
{
  curwin = win_alloc(NULL, false);
  if (oldwin == NULL) {
    // Very first window, need to create an empty buffer for it and
    // initialize from scratch.
    curbuf = buflist_new(NULL, NULL, 1, BLN_LISTED);
    if (curbuf == NULL) {
      return FAIL;
    }
    curwin->w_buffer = curbuf;
    curwin->w_s = &(curbuf->b_s);
    curbuf->b_nwindows = 1;     // there is one window
    curwin->w_alist = &global_alist;
    curwin_init();              // init current window
  } else {
    // First window in new tab page, initialize it from "oldwin".
    win_init(curwin, oldwin, 0);

    // We don't want cursor- and scroll-binding in the first window.
    RESET_BINDING(curwin);
  }

  new_frame(curwin);
  topframe = curwin->w_frame;
  topframe->fr_width = Columns;
  topframe->fr_height = Rows - (int)p_ch - global_stl_height();

  return OK;
}

// Create a frame for window "wp".
static void new_frame(win_T *wp)
{
  frame_T *frp = xcalloc(1, sizeof(frame_T));

  wp->w_frame = frp;
  frp->fr_layout = FR_LEAF;
  frp->fr_win = wp;
}

// Initialize the window and frame size to the maximum.
void win_init_size(void)
{
  firstwin->w_height = (int)ROWS_AVAIL;
  firstwin->w_prev_height = (int)ROWS_AVAIL;
  firstwin->w_height_inner = firstwin->w_height - firstwin->w_winbar_height;
  firstwin->w_height_outer = firstwin->w_height;
  firstwin->w_winrow_off = firstwin->w_winbar_height;
  topframe->fr_height = (int)ROWS_AVAIL;
  firstwin->w_width = Columns;
  firstwin->w_width_inner = firstwin->w_width;
  firstwin->w_width_outer = firstwin->w_width;
  topframe->fr_width = Columns;
}

// Allocate a new tabpage_T and init the values.
static tabpage_T *alloc_tabpage(void)
{
  static int last_tp_handle = 0;
  tabpage_T *tp = xcalloc(1, sizeof(tabpage_T));
  tp->handle = ++last_tp_handle;
  pmap_put(int)(&tabpage_handles, tp->handle, tp);

  // Init t: variables.
  tp->tp_vars = tv_dict_alloc();
  init_var_dict(tp->tp_vars, &tp->tp_winvar, VAR_SCOPE);
  tp->tp_diff_invalid = true;
  tp->tp_ch_used = p_ch;

  return tp;
}

void free_tabpage(tabpage_T *tp)
{
  pmap_del(int)(&tabpage_handles, tp->handle, NULL);
  diff_clear(tp);
  for (int idx = 0; idx < SNAP_COUNT; idx++) {
    clear_snapshot(tp, idx);
  }
  vars_clear(&tp->tp_vars->dv_hashtab);         // free all t: variables
  hash_init(&tp->tp_vars->dv_hashtab);
  unref_var_dict(tp->tp_vars);

  if (tp == lastused_tabpage) {
    lastused_tabpage = NULL;
  }

  xfree(tp->tp_localdir);
  xfree(tp->tp_prevdir);
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
int win_new_tabpage(int after, char *filename)
{
  tabpage_T *old_curtab = curtab;

  if (cmdwin_type != 0) {
    emsg(_(e_cmdwin));
    return FAIL;
  }

  tabpage_T *newtp = alloc_tabpage();

  // Remember the current windows in this Tab page.
  if (leave_tabpage(curbuf, true) == FAIL) {
    xfree(newtp);
    return FAIL;
  }

  newtp->tp_localdir = old_curtab->tp_localdir
                       ? xstrdup(old_curtab->tp_localdir) : NULL;

  curtab = newtp;

  // Create a new empty window.
  if (win_alloc_firstwin(old_curtab->tp_curwin) == OK) {
    // Make the new Tab page the new topframe.
    if (after == 1) {
      // New tab page becomes the first one.
      newtp->tp_next = first_tabpage;
      first_tabpage = newtp;
    } else {
      tabpage_T *tp = old_curtab;

      if (after > 0) {
        // Put new tab page before tab page "after".
        int n = 2;
        for (tp = first_tabpage; tp->tp_next != NULL
             && n < after; tp = tp->tp_next) {
          n++;
        }
      }
      newtp->tp_next = tp->tp_next;
      tp->tp_next = newtp;
    }
    newtp->tp_firstwin = newtp->tp_lastwin = newtp->tp_curwin = curwin;

    win_init_size();
    firstwin->w_winrow = tabline_height();
    firstwin->w_prev_winrow = firstwin->w_winrow;
    win_comp_scroll(curwin);

    newtp->tp_topframe = topframe;
    last_status(false);

    redraw_all_later(UPD_NOT_VALID);

    tabpage_check_windows(old_curtab);

    lastused_tabpage = old_curtab;

    entering_window(curwin);

    apply_autocmds(EVENT_WINNEW, NULL, NULL, false, curbuf);
    apply_autocmds(EVENT_WINENTER, NULL, NULL, false, curbuf);
    apply_autocmds(EVENT_TABNEW, filename, filename, false, curbuf);
    apply_autocmds(EVENT_TABENTER, NULL, NULL, false, curbuf);

    return OK;
  }

  // Failed, get back the previous Tab page
  enter_tabpage(curtab, curbuf, true, true);
  return FAIL;
}

// Open a new tab page if ":tab cmd" was used.  It will edit the same buffer,
// like with ":split".
// Returns OK if a new tab page was created, FAIL otherwise.
int may_open_tabpage(void)
{
  int n = (cmdmod.cmod_tab == 0) ? postponed_split_tab : cmdmod.cmod_tab;

  if (n == 0) {
    return FAIL;
  }

  cmdmod.cmod_tab = 0;         // reset it to avoid doing it twice
  postponed_split_tab = 0;
  int status = win_new_tabpage(n, NULL);
  if (status == OK) {
    apply_autocmds(EVENT_TABNEWENTERED, NULL, NULL, false, curbuf);
  }
  return status;
}

// Create up to "maxcount" tabpages with empty windows.
// Returns the number of resulting tab pages.
int make_tabpages(int maxcount)
{
  int count = maxcount;

  // Limit to 'tabpagemax' tabs.
  if (count > p_tpm) {
    count = (int)p_tpm;
  }

  // Don't execute autocommands while creating the tab pages.  Must do that
  // when putting the buffers in the windows.
  block_autocmds();

  int todo;
  for (todo = count - 1; todo > 0; todo--) {
    if (win_new_tabpage(0, NULL) == FAIL) {
      break;
    }
  }

  unblock_autocmds();

  // return actual number of tab pages
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

// Find tab page "n" (first one is 1).  Returns NULL when not found.
tabpage_T *find_tabpage(int n)
{
  tabpage_T *tp;
  int i = 1;

  for (tp = first_tabpage; tp != NULL && i != n; tp = tp->tp_next) {
    i++;
  }
  return tp;
}

// Get index of tab page "tp".  First one has index 1.
// When not found returns number of tab pages plus one.
int tabpage_index(tabpage_T *ftp)
{
  int i = 1;
  tabpage_T *tp;

  for (tp = first_tabpage; tp != NULL && tp != ftp; tp = tp->tp_next) {
    i++;
  }
  return i;
}

/// Prepare for leaving the current tab page.
/// When autocommands change "curtab" we don't leave the tab page and return
/// FAIL.
/// Careful: When OK is returned need to get a new tab page very very soon!
///
/// @param new_curbuf              what is going to be the new curbuf,
///                                NULL if unknown.
/// @param trigger_leave_autocmds  when true trigger *Leave autocommands.
static int leave_tabpage(buf_T *new_curbuf, bool trigger_leave_autocmds)
{
  tabpage_T *tp = curtab;

  leaving_window(curwin);
  reset_VIsual_and_resel();     // stop Visual mode
  if (trigger_leave_autocmds) {
    if (new_curbuf != curbuf) {
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, false, curbuf);
      if (curtab != tp) {
        return FAIL;
      }
    }
    apply_autocmds(EVENT_WINLEAVE, NULL, NULL, false, curbuf);
    if (curtab != tp) {
      return FAIL;
    }
    apply_autocmds(EVENT_TABLEAVE, NULL, NULL, false, curbuf);
    if (curtab != tp) {
      return FAIL;
    }
  }

  reset_dragwin();
  tp->tp_curwin = curwin;
  tp->tp_prevwin = prevwin;
  tp->tp_firstwin = firstwin;
  tp->tp_lastwin = lastwin;
  tp->tp_old_Rows_avail = ROWS_AVAIL;
  if (tp->tp_old_Columns != -1) {
    tp->tp_old_Columns = Columns;
  }
  firstwin = NULL;
  lastwin = NULL;
  return OK;
}

/// Start using tab page "tp".
/// Only to be used after leave_tabpage() or freeing the current tab page.
///
/// @param trigger_enter_autocmds  when true trigger *Enter autocommands.
/// @param trigger_leave_autocmds  when true trigger *Leave autocommands.
static void enter_tabpage(tabpage_T *tp, buf_T *old_curbuf, bool trigger_enter_autocmds,
                          bool trigger_leave_autocmds)
{
  int old_off = tp->tp_firstwin->w_winrow;
  win_T *next_prevwin = tp->tp_prevwin;
  tabpage_T *old_curtab = curtab;

  use_tabpage(tp);

  if (old_curtab != curtab) {
    tabpage_check_windows(old_curtab);
  }

  // We would like doing the TabEnter event first, but we don't have a
  // valid current window yet, which may break some commands.
  // This triggers autocommands, thus may make "tp" invalid.
  win_enter_ext(tp->tp_curwin, WEE_CURWIN_INVALID
                | (trigger_enter_autocmds ? WEE_TRIGGER_ENTER_AUTOCMDS : 0)
                | (trigger_leave_autocmds ? WEE_TRIGGER_LEAVE_AUTOCMDS : 0));
  prevwin = next_prevwin;

  last_status(false);  // status line may appear or disappear
  const int row = win_comp_pos();  // recompute w_winrow for all windows
  diff_need_scrollbind = true;

  // Use the stored value of p_ch, so that it can be different for each tab page.
  if (p_ch != curtab->tp_ch_used) {
    clear_cmdline = true;
    if (msg_grid.chars && p_ch < curtab->tp_ch_used) {
      // TODO(bfredl): a bit expensive, should be enough to invalidate the
      // region between the old and the new p_ch.
      grid_invalidate(&msg_grid);
    }
  }
  p_ch = curtab->tp_ch_used;

  // When cmdheight is changed in a tab page with '<C-w>-', cmdline_row is
  // changed but p_ch and tp_ch_used are not changed. Thus we also need to
  // check cmdline_row.
  if (row < cmdline_row && cmdline_row <= Rows - p_ch) {
    clear_cmdline = true;
  }

  // If there was a click in a window, it won't be usable for a following
  // drag.
  reset_dragwin();

  // The tabpage line may have appeared or disappeared, may need to resize the frames for that.
  // When the Vim window was resized or ROWS_AVAIL changed need to update frame sizes too.
  if (curtab->tp_old_Rows_avail != ROWS_AVAIL || (old_off != firstwin->w_winrow)) {
    win_new_screen_rows();
  }
  if (curtab->tp_old_Columns != Columns) {
    if (starting == 0) {
      win_new_screen_cols();  // update window widths
      curtab->tp_old_Columns = Columns;
    } else {
      curtab->tp_old_Columns = -1;  // update window widths later
    }
  }

  lastused_tabpage = old_curtab;

  // Apply autocommands after updating the display, when 'rows' and
  // 'columns' have been set correctly.
  if (trigger_enter_autocmds) {
    apply_autocmds(EVENT_TABENTER, NULL, NULL, false, curbuf);
    if (old_curbuf != curbuf) {
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
    }
  }

  redraw_all_later(UPD_NOT_VALID);
}

/// tells external UI that windows and inline floats in old_curtab are invisible
/// and that floats in curtab is now visible.
///
/// External floats are considered independent of tabpages. This is
/// implemented by always moving them to curtab.
static void tabpage_check_windows(tabpage_T *old_curtab)
{
  win_T *next_wp;
  for (win_T *wp = old_curtab->tp_firstwin; wp; wp = next_wp) {
    next_wp = wp->w_next;
    if (wp->w_floating) {
      if (wp->w_config.external) {
        win_remove(wp, old_curtab);
        win_append(lastwin_nofloating(), wp, NULL);
      } else {
        ui_comp_remove_grid(&wp->w_grid_alloc);
      }
    }
    wp->w_pos_changed = true;
  }

  for (win_T *wp = firstwin; wp; wp = wp->w_next) {
    if (wp->w_floating && !wp->w_config.external) {
      win_config_float(wp, wp->w_config);
    }
    wp->w_pos_changed = true;
  }
}

// Go to tab page "n".  For ":tab N" and "Ngt".
// When "n" is 9999 go to the last tab page.
void goto_tabpage(int n)
{
  if (text_locked()) {
    // Not allowed when editing the command line.
    text_locked_msg();
    return;
  }

  // If there is only one it can't work.
  if (first_tabpage->tp_next == NULL) {
    if (n > 1) {
      beep_flush();
    }
    return;
  }

  tabpage_T *tp = NULL;  // shut up compiler

  if (n == 0) {
    // No count, go to next tab page, wrap around end.
    if (curtab->tp_next == NULL) {
      tp = first_tabpage;
    } else {
      tp = curtab->tp_next;
    }
  } else if (n < 0) {
    // "gT": go to previous tab page, wrap around end.  "N gT" repeats
    // this N times.
    tabpage_T *ttp = curtab;
    for (int i = n; i < 0; i++) {
      for (tp = first_tabpage; tp->tp_next != ttp && tp->tp_next != NULL;
           tp = tp->tp_next) {}
      ttp = tp;
    }
  } else if (n == 9999) {
    // Go to last tab page.
    for (tp = first_tabpage; tp->tp_next != NULL; tp = tp->tp_next) {}
  } else {
    // Go to tab page "n".
    tp = find_tabpage(n);
    if (tp == NULL) {
      beep_flush();
      return;
    }
  }

  goto_tabpage_tp(tp, true, true);
}

/// Go to tabpage "tp".
/// Note: doesn't update the GUI tab.
///
/// @param trigger_enter_autocmds  when true trigger *Enter autocommands.
/// @param trigger_leave_autocmds  when true trigger *Leave autocommands.
void goto_tabpage_tp(tabpage_T *tp, bool trigger_enter_autocmds, bool trigger_leave_autocmds)
{
  if (trigger_enter_autocmds || trigger_leave_autocmds) {
    CHECK_CMDWIN;
  }

  // Don't repeat a message in another tab page.
  set_keep_msg(NULL, 0);

  skip_win_fix_scroll = true;
  if (tp != curtab && leave_tabpage(tp->tp_curwin->w_buffer,
                                    trigger_leave_autocmds) == OK) {
    if (valid_tabpage(tp)) {
      enter_tabpage(tp, curbuf, trigger_enter_autocmds,
                    trigger_leave_autocmds);
    } else {
      enter_tabpage(curtab, curbuf, trigger_enter_autocmds,
                    trigger_leave_autocmds);
    }
  }
  skip_win_fix_scroll = false;
}

/// Go to the last accessed tab page, if there is one.
/// @return true if the tab page is valid, false otherwise.
bool goto_tabpage_lastused(void)
{
  if (!valid_tabpage(lastused_tabpage)) {
    return false;
  }

  goto_tabpage_tp(lastused_tabpage, true, true);
  return true;
}

// Enter window "wp" in tab page "tp".
// Also updates the GUI tab.
void goto_tabpage_win(tabpage_T *tp, win_T *wp)
{
  goto_tabpage_tp(tp, true, true);
  if (curtab == tp && win_valid(wp)) {
    win_enter(wp, true);
  }
}

// Move the current tab page to after tab page "nr".
void tabpage_move(int nr)
{
  assert(curtab != NULL);

  if (first_tabpage->tp_next == NULL) {
    return;
  }

  if (tabpage_move_disallowed) {
    return;
  }

  int n = 1;
  tabpage_T *tp;

  for (tp = first_tabpage; tp->tp_next != NULL && n < nr; tp = tp->tp_next) {
    n++;
  }

  if (tp == curtab || (nr > 0 && tp->tp_next != NULL
                       && tp->tp_next == curtab)) {
    return;
  }

  tabpage_T *tp_dst = tp;

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

  // Need to redraw the tabline.  Tab page contents doesn't change.
  redraw_tabline = true;
}

/// Go to another window.
/// When jumping to another buffer, stop Visual mode.  Do this before
/// changing windows so we can yank the selection into the '*' register.
/// (note: this may trigger ModeChanged autocommand!)
/// When jumping to another window on the same buffer, adjust its cursor
/// position to keep the same Visual area.
void win_goto(win_T *wp)
{
  win_T *owp = curwin;

  if (text_or_buf_locked()) {
    beep_flush();
    return;
  }

  if (wp->w_buffer != curbuf) {
    // careful: triggers ModeChanged autocommand
    reset_VIsual_and_resel();
  } else if (VIsual_active) {
    wp->w_cursor = curwin->w_cursor;
  }

  // autocommand may have made wp invalid
  if (!win_valid(wp)) {
    return;
  }

  win_enter(wp, true);

  // Conceal cursor line in previous window, unconceal in current window.
  if (win_valid(owp) && owp->w_p_cole > 0 && !msg_scrolled) {
    redrawWinline(owp, owp->w_cursor.lnum);
  }
  if (curwin->w_p_cole > 0 && !msg_scrolled) {
    redrawWinline(curwin, curwin->w_cursor.lnum);
  }
}

// Find the tabpage for window "win".
tabpage_T *win_find_tabpage(win_T *win)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp == win) {
      return tp;
    }
  }
  return NULL;
}

/// Get the above or below neighbor window of the specified window.
///
/// Returns the specified window if the neighbor is not found.
/// Returns the previous window if the specifiecied window is a floating window.
///
/// @param up     true for the above neighbor
/// @param count  nth neighbor window
///
/// @return       found window
win_T *win_vert_neighbor(tabpage_T *tp, win_T *wp, bool up, int count)
{
  frame_T *foundfr = wp->w_frame;

  if (wp->w_floating) {
    return win_valid(prevwin) && !prevwin->w_floating ? prevwin : firstwin;
  }

  while (count--) {
    frame_T *nfr;
    // First go upwards in the tree of frames until we find an upwards or
    // downwards neighbor.
    frame_T *fr = foundfr;
    while (true) {
      if (fr == tp->tp_topframe) {
        goto end;
      }
      if (up) {
        nfr = fr->fr_prev;
      } else {
        nfr = fr->fr_next;
      }
      if (fr->fr_parent->fr_layout == FR_COL && nfr != NULL) {
        break;
      }
      fr = fr->fr_parent;
    }

    // Now go downwards to find the bottom or top frame in it.
    while (true) {
      if (nfr->fr_layout == FR_LEAF) {
        foundfr = nfr;
        break;
      }
      fr = nfr->fr_child;
      if (nfr->fr_layout == FR_ROW) {
        // Find the frame at the cursor row.
        while (fr->fr_next != NULL
               && frame2win(fr)->w_wincol + fr->fr_width
               <= wp->w_wincol + wp->w_wcol) {
          fr = fr->fr_next;
        }
      }
      if (nfr->fr_layout == FR_COL && up) {
        while (fr->fr_next != NULL) {
          fr = fr->fr_next;
        }
      }
      nfr = fr;
    }
  }
end:
  return foundfr != NULL ? foundfr->fr_win : NULL;
}

/// Move to window above or below "count" times.
///
/// @param up     true to go to win above
/// @param count  go count times into direction
static void win_goto_ver(bool up, int count)
{
  win_T *win = win_vert_neighbor(curtab, curwin, up, count);
  if (win != NULL) {
    win_goto(win);
  }
}

/// Get the left or right neighbor window of the specified window.
///
/// Returns the specified window if the neighbor is not found.
/// Returns the previous window if the specifiecied window is a floating window.
///
/// @param left  true for the left neighbor
/// @param count nth neighbor window
///
/// @return      found window
win_T *win_horz_neighbor(tabpage_T *tp, win_T *wp, bool left, int count)
{
  frame_T *foundfr = wp->w_frame;

  if (wp->w_floating) {
    return win_valid(prevwin) && !prevwin->w_floating ? prevwin : firstwin;
  }

  while (count--) {
    frame_T *nfr;
    // First go upwards in the tree of frames until we find a left or
    // right neighbor.
    frame_T *fr = foundfr;
    while (true) {
      if (fr == tp->tp_topframe) {
        goto end;
      }
      if (left) {
        nfr = fr->fr_prev;
      } else {
        nfr = fr->fr_next;
      }
      if (fr->fr_parent->fr_layout == FR_ROW && nfr != NULL) {
        break;
      }
      fr = fr->fr_parent;
    }

    // Now go downwards to find the leftmost or rightmost frame in it.
    while (true) {
      if (nfr->fr_layout == FR_LEAF) {
        foundfr = nfr;
        break;
      }
      fr = nfr->fr_child;
      if (nfr->fr_layout == FR_COL) {
        // Find the frame at the cursor row.
        while (fr->fr_next != NULL
               && frame2win(fr)->w_winrow + fr->fr_height
               <= wp->w_winrow + wp->w_wrow) {
          fr = fr->fr_next;
        }
      }
      if (nfr->fr_layout == FR_ROW && left) {
        while (fr->fr_next != NULL) {
          fr = fr->fr_next;
        }
      }
      nfr = fr;
    }
  }
end:
  return foundfr != NULL ? foundfr->fr_win : NULL;
}

/// Move to left or right window.
///
/// @param left   true to go to left window
/// @param count  go count times into direction
static void win_goto_hor(bool left, int count)
{
  win_T *win = win_horz_neighbor(curtab, curwin, left, count);
  if (win != NULL) {
    win_goto(win);
  }
}

/// Make window `wp` the current window.
///
/// @warning Autocmds may close the window immediately, so caller must check
///          win_valid(wp).
void win_enter(win_T *wp, bool undo_sync)
{
  win_enter_ext(wp, (undo_sync ? WEE_UNDO_SYNC : 0)
                | WEE_TRIGGER_ENTER_AUTOCMDS | WEE_TRIGGER_LEAVE_AUTOCMDS);
}

/// Make window "wp" the current window.
///
/// @param flags  if contains WEE_CURWIN_INVALID, it means curwin has just been
///               closed and isn't valid.
static void win_enter_ext(win_T *const wp, const int flags)
{
  bool other_buffer = false;
  const bool curwin_invalid = (flags & WEE_CURWIN_INVALID);

  if (wp == curwin && !curwin_invalid) {        // nothing to do
    return;
  }

  if (!curwin_invalid) {
    leaving_window(curwin);
  }

  if (!curwin_invalid && (flags & WEE_TRIGGER_LEAVE_AUTOCMDS)) {
    // Be careful: If autocommands delete the window, return now.
    if (wp->w_buffer != curbuf) {
      apply_autocmds(EVENT_BUFLEAVE, NULL, NULL, false, curbuf);
      other_buffer = true;
      if (!win_valid(wp)) {
        return;
      }
    }
    apply_autocmds(EVENT_WINLEAVE, NULL, NULL, false, curbuf);
    if (!win_valid(wp)) {
      return;
    }
    // autocmds may abort script processing
    if (aborting()) {
      return;
    }
  }

  // sync undo before leaving the current buffer
  if ((flags & WEE_UNDO_SYNC) && curbuf != wp->w_buffer) {
    u_sync(false);
  }

  // Might need to scroll the old window before switching, e.g., when the
  // cursor was moved.
  if (*p_spk == 'c' && !curwin_invalid) {
    update_topline(curwin);
  }

  // may have to copy the buffer options when 'cpo' contains 'S'
  if (wp->w_buffer != curbuf) {
    buf_copy_options(wp->w_buffer, BCO_ENTER | BCO_NOHELP);
  }
  if (!curwin_invalid) {
    prevwin = curwin;           // remember for CTRL-W p
    curwin->w_redr_status = true;
  }
  curwin = wp;
  curbuf = wp->w_buffer;

  check_cursor(curwin);
  if (!virtual_active(curwin)) {
    curwin->w_cursor.coladd = 0;
  }
  if (*p_spk == 'c') {
    changed_line_abv_curs();      // assume cursor position needs updating
  } else {
    // Make sure the cursor position is valid, either by moving the cursor
    // or by scrolling the text.
    win_fix_cursor(get_real_state() & (MODE_NORMAL|MODE_CMDLINE|MODE_TERMINAL));
  }

  win_fix_current_dir();

  entering_window(curwin);
  // Careful: autocommands may close the window and make "wp" invalid
  if (flags & WEE_TRIGGER_NEW_AUTOCMDS) {
    apply_autocmds(EVENT_WINNEW, NULL, NULL, false, curbuf);
  }
  if (flags & WEE_TRIGGER_ENTER_AUTOCMDS) {
    apply_autocmds(EVENT_WINENTER, NULL, NULL, false, curbuf);
    if (other_buffer) {
      apply_autocmds(EVENT_BUFENTER, NULL, NULL, false, curbuf);
    }
  }

  maketitle();
  curwin->w_redr_status = true;
  redraw_tabline = true;
  if (restart_edit) {
    redraw_later(curwin, UPD_VALID);  // causes status line redraw
  }

  // change background color according to NormalNC,
  // but only if actually defined (otherwise no extra redraw)
  if (curwin->w_hl_attr_normal != curwin->w_hl_attr_normalnc) {
    // TODO(bfredl): eventually we should be smart enough
    // to only recompose the window, not redraw it.
    redraw_later(curwin, UPD_NOT_VALID);
  }
  if (prevwin) {
    if (prevwin->w_hl_attr_normal != prevwin->w_hl_attr_normalnc) {
      redraw_later(prevwin, UPD_NOT_VALID);
    }
  }

  // set window height to desired minimal value
  if (curwin->w_height < p_wh && !curwin->w_p_wfh && !curwin->w_floating) {
    win_setheight((int)p_wh);
  } else if (curwin->w_height == 0) {
    win_setheight(1);
  }

  // set window width to desired minimal value
  if (curwin->w_width < p_wiw && !curwin->w_p_wfw && !curwin->w_floating) {
    win_setwidth((int)p_wiw);
  }

  setmouse();                   // in case jumped to/from help buffer

  // Change directories when the 'acd' option is set.
  do_autochdir();
}

/// Used after making another window the current one: change directory if needed.
void win_fix_current_dir(void)
{
  // New directory is either the local directory of the window, tab or NULL.
  char *new_dir = curwin->w_localdir ? curwin->w_localdir : curtab->tp_localdir;
  char cwd[MAXPATHL];
  if (os_dirname(cwd, MAXPATHL) != OK) {
    cwd[0] = NUL;
  }

  if (new_dir) {
    // Window/tab has a local directory: Save current directory as global
    // (unless that was done already) and change to the local directory.
    if (globaldir == NULL) {
      if (cwd[0] != NUL) {
        globaldir = xstrdup(cwd);
      }
    }
    bool dir_differs = pathcmp(new_dir, cwd, -1) != 0;
    if (!p_acd && dir_differs) {
      do_autocmd_dirchanged(new_dir, curwin->w_localdir ? kCdScopeWindow : kCdScopeTabpage,
                            kCdCauseWindow, true);
    }
    if (os_chdir(new_dir) == 0) {
      if (!p_acd && dir_differs) {
        do_autocmd_dirchanged(new_dir, curwin->w_localdir ? kCdScopeWindow : kCdScopeTabpage,
                              kCdCauseWindow, false);
      }
    }
    last_chdir_reason = NULL;
    shorten_fnames(true);
  } else if (globaldir != NULL) {
    // Window doesn't have a local directory and we are not in the global
    // directory: Change to the global directory.
    bool dir_differs = pathcmp(globaldir, cwd, -1) != 0;
    if (!p_acd && dir_differs) {
      do_autocmd_dirchanged(globaldir, kCdScopeGlobal, kCdCauseWindow, true);
    }
    if (os_chdir(globaldir) == 0) {
      if (!p_acd && dir_differs) {
        do_autocmd_dirchanged(globaldir, kCdScopeGlobal, kCdCauseWindow, false);
      }
    }
    XFREE_CLEAR(globaldir);
    last_chdir_reason = NULL;
    shorten_fnames(true);
  }
}

/// Jump to the first open window that contains buffer "buf", if one exists.
/// Returns a pointer to the window found, otherwise NULL.
win_T *buf_jump_open_win(buf_T *buf)
{
  if (curwin->w_buffer == buf) {
    win_enter(curwin, false);
    return curwin;
  }
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer == buf) {
      win_enter(wp, false);
      return wp;
    }
  }

  return NULL;
}

/// Jump to the first open window in any tab page that contains buffer "buf",
/// if one exists. First search in the windows present in the current tab page.
/// @return the found window, or NULL.
win_T *buf_jump_open_tab(buf_T *buf)
{
  // First try the current tab page.
  {
    win_T *wp = buf_jump_open_win(buf);
    if (wp != NULL) {
      return wp;
    }
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

static int last_win_id = LOWEST_WIN_ID - 1;

/// @param hidden  allocate a window structure and link it in the window if
//                 false.
win_T *win_alloc(win_T *after, bool hidden)
{
  // allocate window structure and linesizes arrays
  win_T *new_wp = xcalloc(1, sizeof(win_T));

  new_wp->handle = ++last_win_id;
  pmap_put(int)(&window_handles, new_wp->handle, new_wp);

  grid_assign_handle(&new_wp->w_grid_alloc);

  // Init w: variables.
  new_wp->w_vars = tv_dict_alloc();
  init_var_dict(new_wp->w_vars, &new_wp->w_winvar, VAR_SCOPE);

  // Don't execute autocommands while the window is not properly
  // initialized yet.  gui_create_scrollbar() may trigger a FocusGained
  // event.
  block_autocmds();
  // link the window in the window list
  if (!hidden) {
    win_append(after, new_wp, NULL);
  }

  new_wp->w_wincol = 0;
  new_wp->w_width = Columns;

  // position the display and the cursor at the top of the file.
  new_wp->w_topline = 1;
  new_wp->w_topfill = 0;
  new_wp->w_botline = 2;
  new_wp->w_cursor.lnum = 1;
  new_wp->w_scbind_pos = 1;
  new_wp->w_floating = 0;
  new_wp->w_config = WIN_CONFIG_INIT;
  new_wp->w_viewport_invalid = true;
  new_wp->w_viewport_last_topline = 1;

  new_wp->w_ns_hl = -1;

  Set(uint32_t) ns_set = SET_INIT;
  new_wp->w_ns_set = ns_set;

  // use global option for global-local options
  new_wp->w_allbuf_opt.wo_so = new_wp->w_p_so = -1;
  new_wp->w_allbuf_opt.wo_siso = new_wp->w_p_siso = -1;

  // We won't calculate w_fraction until resizing the window
  new_wp->w_fraction = 0;
  new_wp->w_prev_fraction_row = -1;

  foldInitWin(new_wp);
  unblock_autocmds();
  new_wp->w_next_match_id = 1000;  // up to 1000 can be picked by the user
  return new_wp;
}

// Free one wininfo_T.
void free_wininfo(wininfo_T *wip, buf_T *bp)
{
  if (wip->wi_optset) {
    clear_winopt(&wip->wi_opt);
    deleteFoldRecurse(bp, &wip->wi_folds);
  }
  xfree(wip);
}

/// Remove window 'wp' from the window list and free the structure.
///
/// @param tp  tab page "win" is in, NULL for current
void win_free(win_T *wp, tabpage_T *tp)
{
  pmap_del(int)(&window_handles, wp->handle, NULL);
  clearFolding(wp);

  // reduce the reference count to the argument list.
  alist_unlink(wp->w_alist);

  // Don't execute autocommands while the window is halfway being deleted.
  block_autocmds();

  set_destroy(uint32_t, &wp->w_ns_set);

  clear_winopt(&wp->w_onebuf_opt);
  clear_winopt(&wp->w_allbuf_opt);

  xfree(wp->w_p_lcs_chars.multispace);
  xfree(wp->w_p_lcs_chars.leadmultispace);

  vars_clear(&wp->w_vars->dv_hashtab);          // free all w: variables
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

  xfree(wp->w_lines);

  for (int i = 0; i < wp->w_tagstacklen; i++) {
    xfree(wp->w_tagstack[i].tagname);
    xfree(wp->w_tagstack[i].user_data);
  }

  xfree(wp->w_localdir);
  xfree(wp->w_prevdir);

  stl_clear_click_defs(wp->w_status_click_defs, wp->w_status_click_defs_size);
  xfree(wp->w_status_click_defs);

  stl_clear_click_defs(wp->w_winbar_click_defs, wp->w_winbar_click_defs_size);
  xfree(wp->w_winbar_click_defs);

  stl_clear_click_defs(wp->w_statuscol_click_defs, wp->w_statuscol_click_defs_size);
  xfree(wp->w_statuscol_click_defs);

  // Remove the window from the b_wininfo lists, it may happen that the
  // freed memory is re-used for another window.
  FOR_ALL_BUFFERS(buf) {
    for (wininfo_T *wip = buf->b_wininfo; wip != NULL; wip = wip->wi_next) {
      if (wip->wi_win == wp) {
        wininfo_T *wip2;

        // If there already is an entry with "wi_win" set to NULL it
        // must be removed, it would never be used.
        // Skip "wip" itself, otherwise Coverity complains.
        for (wip2 = buf->b_wininfo; wip2 != NULL; wip2 = wip2->wi_next) {
          // `wip2 != wip` to satisfy Coverity. #14884
          if (wip2 != wip && wip2->wi_win == NULL) {
            if (wip2->wi_next != NULL) {
              wip2->wi_next->wi_prev = wip2->wi_prev;
            }
            if (wip2->wi_prev == NULL) {
              buf->b_wininfo = wip2->wi_next;
            } else {
              wip2->wi_prev->wi_next = wip2->wi_next;
            }
            free_wininfo(wip2, buf);
            break;
          }
        }

        wip->wi_win = NULL;
      }
    }
  }

  // free the border text
  clear_virttext(&wp->w_config.title_chunks);
  clear_virttext(&wp->w_config.footer_chunks);

  clear_matches(wp);

  free_jumplist(wp);

  qf_free_all(wp);

  xfree(wp->w_p_cc_cols);

  win_free_grid(wp, false);

  if (win_valid_any_tab(wp)) {
    win_remove(wp, tp);
  }
  if (autocmd_busy) {
    wp->w_next = au_pending_free_win;
    au_pending_free_win = wp;
  } else {
    xfree(wp);
  }

  unblock_autocmds();
}

void win_free_grid(win_T *wp, bool reinit)
{
  if (wp->w_grid_alloc.handle != 0 && ui_has(kUIMultigrid)) {
    ui_call_grid_destroy(wp->w_grid_alloc.handle);
  }
  grid_free(&wp->w_grid_alloc);
  if (reinit) {
    // if a float is turned into a split, the grid data structure will be reused
    CLEAR_FIELD(wp->w_grid_alloc);
  }
}

/// Append window "wp" in the window list after window "after".
///
/// @param tp  tab page "win" (and "after", if not NULL) is in, NULL for current
void win_append(win_T *after, win_T *wp, tabpage_T *tp)
  FUNC_ATTR_NONNULL_ARG(2)
{
  assert(tp == NULL || tp != curtab);

  win_T **first = tp == NULL ? &firstwin : &tp->tp_firstwin;
  win_T **last = tp == NULL ? &lastwin : &tp->tp_lastwin;

  // after NULL is in front of the first
  win_T *before = after == NULL ? *first : after->w_next;

  wp->w_next = before;
  wp->w_prev = after;
  if (after == NULL) {
    *first = wp;
  } else {
    after->w_next = wp;
  }
  if (before == NULL) {
    *last = wp;
  } else {
    before->w_prev = wp;
  }
}

/// Remove a window from the window list.
///
/// @param tp  tab page "win" is in, NULL for current
void win_remove(win_T *wp, tabpage_T *tp)
  FUNC_ATTR_NONNULL_ARG(1)
{
  assert(tp == NULL || tp != curtab);

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

// Append frame "frp" in a frame list after frame "after".
static void frame_append(frame_T *after, frame_T *frp)
{
  frp->fr_next = after->fr_next;
  after->fr_next = frp;
  if (frp->fr_next != NULL) {
    frp->fr_next->fr_prev = frp;
  }
  frp->fr_prev = after;
}

// Insert frame "frp" in a frame list before frame "before".
static void frame_insert(frame_T *before, frame_T *frp)
{
  frp->fr_next = before;
  frp->fr_prev = before->fr_prev;
  before->fr_prev = frp;
  if (frp->fr_prev != NULL) {
    frp->fr_prev->fr_next = frp;
  } else {
    frp->fr_parent->fr_child = frp;
  }
}

// Remove a frame from a frame list.
static void frame_remove(frame_T *frp)
{
  if (frp->fr_prev != NULL) {
    frp->fr_prev->fr_next = frp->fr_next;
  } else {
    frp->fr_parent->fr_child = frp->fr_next;
  }
  if (frp->fr_next != NULL) {
    frp->fr_next->fr_prev = frp->fr_prev;
  }
}

void win_new_screensize(void)
{
  static int old_Rows = 0;
  static int old_Columns = 0;

  if (old_Rows != Rows) {
    // If 'window' uses the whole screen, keep it using that.
    // Don't change it when set with "-w size" on the command line.
    if (p_window == old_Rows - 1 || (old_Rows == 0 && !option_was_set(kOptWindow))) {
      p_window = Rows - 1;
    }
    old_Rows = Rows;
    win_new_screen_rows();  // update window sizes
  }
  if (old_Columns != Columns) {
    old_Columns = Columns;
    win_new_screen_cols();  // update window sizes
  }
}
/// Called from win_new_screensize() after Rows changed.
///
/// This only does the current tab page, others must be done when made active.
void win_new_screen_rows(void)
{
  int h = (int)ROWS_AVAIL;

  if (firstwin == NULL) {       // not initialized yet
    return;
  }
  if (h < frame_minheight(topframe, NULL)) {
    h = frame_minheight(topframe, NULL);
  }

  // First try setting the heights of windows with 'winfixheight'.  If
  // that doesn't result in the right height, forget about that option.
  frame_new_height(topframe, h, false, true);
  if (!frame_check_height(topframe, h)) {
    frame_new_height(topframe, h, false, false);
  }

  win_comp_pos();  // recompute w_winrow and w_wincol
  win_reconfig_floats();  // The size of floats might change
  compute_cmdrow();
  curtab->tp_ch_used = p_ch;

  if (!skip_win_fix_scroll) {
    win_fix_scroll(true);
  }
}

/// Called from win_new_screensize() after Columns changed.
void win_new_screen_cols(void)
{
  if (firstwin == NULL) {       // not initialized yet
    return;
  }

  // First try setting the widths of windows with 'winfixwidth'.  If that
  // doesn't result in the right width, forget about that option.
  frame_new_width(topframe, Columns, false, true);
  if (!frame_check_width(topframe, Columns)) {
    frame_new_width(topframe, Columns, false, false);
  }

  win_comp_pos();  // recompute w_winrow and w_wincol
  win_reconfig_floats();  // The size of floats might change
}

/// Make a snapshot of all the window scroll positions and sizes of the current
/// tab page.
void snapshot_windows_scroll_size(void)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    wp->w_last_topline = wp->w_topline;
    wp->w_last_topfill = wp->w_topfill;
    wp->w_last_leftcol = wp->w_leftcol;
    wp->w_last_skipcol = wp->w_skipcol;
    wp->w_last_width = wp->w_width;
    wp->w_last_height = wp->w_height;
  }
}

static bool did_initial_scroll_size_snapshot = false;

void may_make_initial_scroll_size_snapshot(void)
{
  if (!did_initial_scroll_size_snapshot) {
    did_initial_scroll_size_snapshot = true;
    snapshot_windows_scroll_size();
  }
}

/// Create a dictionary with information about size and scroll changes in a
/// window.
/// Returns the dictionary with refcount set to one.
/// Returns NULL on internal error.
static dict_T *make_win_info_dict(int width, int height, int topline, int topfill, int leftcol,
                                  int skipcol)
{
  dict_T *const d = tv_dict_alloc();
  d->dv_refcount = 1;

  // not actually looping, for breaking out on error
  while (true) {
    typval_T tv = {
      .v_lock = VAR_UNLOCKED,
      .v_type = VAR_NUMBER,
    };

    tv.vval.v_number = width;
    if (tv_dict_add_tv(d, S_LEN("width"), &tv) == FAIL) {
      break;
    }
    tv.vval.v_number = height;
    if (tv_dict_add_tv(d, S_LEN("height"), &tv) == FAIL) {
      break;
    }
    tv.vval.v_number = topline;
    if (tv_dict_add_tv(d, S_LEN("topline"), &tv) == FAIL) {
      break;
    }
    tv.vval.v_number = topfill;
    if (tv_dict_add_tv(d, S_LEN("topfill"), &tv) == FAIL) {
      break;
    }
    tv.vval.v_number = leftcol;
    if (tv_dict_add_tv(d, S_LEN("leftcol"), &tv) == FAIL) {
      break;
    }
    tv.vval.v_number = skipcol;
    if (tv_dict_add_tv(d, S_LEN("skipcol"), &tv) == FAIL) {
      break;
    }
    return d;
  }
  tv_dict_unref(d);
  return NULL;
}

/// Return values of check_window_scroll_resize():
enum {
  CWSR_SCROLLED = 1,  ///< at least one window scrolled
  CWSR_RESIZED  = 2,  ///< at least one window size changed
};

/// This function is used for three purposes:
/// 1. Goes over all windows in the current tab page and returns:
///      0                               no scrolling and no size changes found
///      CWSR_SCROLLED                   at least one window scrolled
///      CWSR_RESIZED                    at least one window changed size
///      CWSR_SCROLLED + CWSR_RESIZED    both
///    "size_count" is set to the nr of windows with size changes.
///    "first_scroll_win" is set to the first window with any relevant changes.
///    "first_size_win" is set to the first window with size changes.
///
/// 2. When the first three arguments are NULL and "winlist" is not NULL,
///    "winlist" is set to the list of window IDs with size changes.
///
/// 3. When the first three arguments are NULL and "v_event" is not NULL,
///    information about changed windows is added to "v_event".
static int check_window_scroll_resize(int *size_count, win_T **first_scroll_win,
                                      win_T **first_size_win, list_T *winlist, dict_T *v_event)
{
  int result = 0;
  // int listidx = 0;
  int tot_width = 0;
  int tot_height = 0;
  int tot_topline = 0;
  int tot_topfill = 0;
  int tot_leftcol = 0;
  int tot_skipcol = 0;

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    // Skip floating windows that do not have a snapshot (usually because they are newly-created),
    // as unlike split windows, creating floating windows doesn't cause other windows to resize.
    if (wp->w_floating && wp->w_last_topline == 0) {
      wp->w_last_topline = wp->w_topline;
      wp->w_last_topfill = wp->w_topfill;
      wp->w_last_leftcol = wp->w_leftcol;
      wp->w_last_skipcol = wp->w_skipcol;
      wp->w_last_width = wp->w_width;
      wp->w_last_height = wp->w_height;
      continue;
    }

    const bool size_changed = wp->w_last_width != wp->w_width
                              || wp->w_last_height != wp->w_height;
    if (size_changed) {
      result |= CWSR_RESIZED;
      if (winlist != NULL) {
        // Add this window to the list of changed windows.
        typval_T tv = {
          .v_lock = VAR_UNLOCKED,
          .v_type = VAR_NUMBER,
          .vval.v_number = wp->handle,
        };
        // tv_list_set_item(winlist, listidx++, &tv);
        tv_list_append_owned_tv(winlist, tv);
      } else if (size_count != NULL) {
        assert(first_size_win != NULL && first_scroll_win != NULL);
        (*size_count)++;
        if (*first_size_win == NULL) {
          *first_size_win = wp;
        }
        // For WinScrolled the first window with a size change is used
        // even when it didn't scroll.
        if (*first_scroll_win == NULL) {
          *first_scroll_win = wp;
        }
      }
    }

    const bool scroll_changed = wp->w_last_topline != wp->w_topline
                                || wp->w_last_topfill != wp->w_topfill
                                || wp->w_last_leftcol != wp->w_leftcol
                                || wp->w_last_skipcol != wp->w_skipcol;
    if (scroll_changed) {
      result |= CWSR_SCROLLED;
      if (first_scroll_win != NULL && *first_scroll_win == NULL) {
        *first_scroll_win = wp;
      }
    }

    if ((size_changed || scroll_changed) && v_event != NULL) {
      // Add info about this window to the v:event dictionary.
      int width = wp->w_width - wp->w_last_width;
      int height = wp->w_height - wp->w_last_height;
      int topline = wp->w_topline - wp->w_last_topline;
      int topfill = wp->w_topfill - wp->w_last_topfill;
      int leftcol = wp->w_leftcol - wp->w_last_leftcol;
      int skipcol = wp->w_skipcol - wp->w_last_skipcol;
      dict_T *d = make_win_info_dict(width, height, topline,
                                     topfill, leftcol, skipcol);
      if (d == NULL) {
        break;
      }
      char winid[NUMBUFLEN];
      int key_len = vim_snprintf(winid, sizeof(winid), "%d", wp->handle);
      if (tv_dict_add_dict(v_event, winid, (size_t)key_len, d) == FAIL) {
        tv_dict_unref(d);
        break;
      }
      d->dv_refcount--;

      tot_width += abs(width);
      tot_height += abs(height);
      tot_topline += abs(topline);
      tot_topfill += abs(topfill);
      tot_leftcol += abs(leftcol);
      tot_skipcol += abs(skipcol);
    }
  }

  if (v_event != NULL) {
    dict_T *alldict = make_win_info_dict(tot_width, tot_height, tot_topline,
                                         tot_topfill, tot_leftcol, tot_skipcol);
    if (alldict != NULL) {
      if (tv_dict_add_dict(v_event, S_LEN("all"), alldict) == FAIL) {
        tv_dict_unref(alldict);
      } else {
        alldict->dv_refcount--;
      }
    }
  }

  return result;
}

/// Trigger WinScrolled and/or WinResized if any window in the current tab page
/// scrolled or changed size.
void may_trigger_win_scrolled_resized(void)
{
  static bool recursive = false;
  const bool do_resize = has_event(EVENT_WINRESIZED);
  const bool do_scroll = has_event(EVENT_WINSCROLLED);

  if (recursive
      || !(do_scroll || do_resize)
      || !did_initial_scroll_size_snapshot) {
    return;
  }

  int size_count = 0;
  win_T *first_scroll_win = NULL;
  win_T *first_size_win = NULL;
  int cwsr = check_window_scroll_resize(&size_count,
                                        &first_scroll_win, &first_size_win,
                                        NULL, NULL);
  bool trigger_resize = do_resize && size_count > 0;
  bool trigger_scroll = do_scroll && cwsr != 0;
  if (!trigger_resize && !trigger_scroll) {
    return;  // no relevant changes
  }

  list_T *windows_list = NULL;
  if (trigger_resize) {
    // Create the list for v:event.windows before making the snapshot.
    // windows_list = tv_list_alloc_with_items(size_count);
    windows_list = tv_list_alloc(size_count);
    check_window_scroll_resize(NULL, NULL, NULL, windows_list, NULL);
  }

  dict_T *scroll_dict = NULL;
  if (trigger_scroll) {
    // Create the dict with entries for v:event before making the snapshot.
    scroll_dict = tv_dict_alloc();
    scroll_dict->dv_refcount = 1;
    check_window_scroll_resize(NULL, NULL, NULL, NULL, scroll_dict);
  }

  // WinScrolled/WinResized are triggered only once, even when multiple
  // windows scrolled or changed size.  Store the current values before
  // triggering the event, if a scroll or resize happens as a side effect
  // then WinScrolled/WinResized is triggered for that later.
  snapshot_windows_scroll_size();

  recursive = true;

  // If both are to be triggered do WinResized first.
  if (trigger_resize) {
    save_v_event_T save_v_event;
    dict_T *v_event = get_v_event(&save_v_event);

    if (tv_dict_add_list(v_event, S_LEN("windows"), windows_list) == OK) {
      tv_dict_set_keys_readonly(v_event);

      char winid[NUMBUFLEN];
      vim_snprintf(winid, sizeof(winid), "%d", first_size_win->handle);
      apply_autocmds(EVENT_WINRESIZED, winid, winid, false, first_size_win->w_buffer);
    }
    restore_v_event(v_event, &save_v_event);
  }

  if (trigger_scroll) {
    save_v_event_T save_v_event;
    dict_T *v_event = get_v_event(&save_v_event);

    // Move the entries from scroll_dict to v_event.
    tv_dict_extend(v_event, scroll_dict, "move");
    tv_dict_set_keys_readonly(v_event);
    tv_dict_unref(scroll_dict);

    char winid[NUMBUFLEN];
    vim_snprintf(winid, sizeof(winid), "%d", first_scroll_win->handle);
    apply_autocmds(EVENT_WINSCROLLED, winid, winid, false, first_scroll_win->w_buffer);

    restore_v_event(v_event, &save_v_event);
  }

  recursive = false;
}

// Save the size of all windows in "gap".
void win_size_save(garray_T *gap)
{
  ga_init(gap, (int)sizeof(int), 1);
  ga_grow(gap, win_count() * 2 + 1);
  // first entry is the total lines available for windows
  ((int *)gap->ga_data)[gap->ga_len++] =
    (int)ROWS_AVAIL + global_stl_height() - last_stl_height(false);

  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    ((int *)gap->ga_data)[gap->ga_len++] =
      wp->w_width + wp->w_vsep_width;
    ((int *)gap->ga_data)[gap->ga_len++] = wp->w_height;
  }
}

// Restore window sizes, but only if the number of windows is still the same
// and total lines available for windows didn't change.
// Does not free the growarray.
void win_size_restore(garray_T *gap)
  FUNC_ATTR_NONNULL_ALL
{
  if (win_count() * 2 + 1 == gap->ga_len
      && ((int *)gap->ga_data)[0] ==
      ROWS_AVAIL + global_stl_height() - last_stl_height(false)) {
    // The order matters, because frames contain other frames, but it's
    // difficult to get right. The easy way out is to do it twice.
    for (int j = 0; j < 2; j++) {
      int i = 1;
      FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
        int width = ((int *)gap->ga_data)[i++];
        int height = ((int *)gap->ga_data)[i++];
        if (!wp->w_floating) {
          frame_setwidth(wp->w_frame, width);
          win_setheight_win(height, wp);
        }
      }
    }
    // recompute the window positions
    win_comp_pos();
  }
}

// Update the position for all windows, using the width and height of the frames.
// Returns the row just after the last window and global statusline (if there is one).
int win_comp_pos(void)
{
  int row = tabline_height();
  int col = 0;

  frame_comp_pos(topframe, &row, &col);

  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev) {
    // float might be anchored to moved window
    if (wp->w_config.relative == kFloatRelativeWindow) {
      wp->w_pos_changed = true;
    }
  }

  return row + global_stl_height();
}

// Update the position of the windows in frame "topfrp", using the width and
// height of the frames.
// "*row" and "*col" are the top-left position of the frame.  They are updated
// to the bottom-right position plus one.
static void frame_comp_pos(frame_T *topfrp, int *row, int *col)
{
  win_T *wp = topfrp->fr_win;
  if (wp != NULL) {
    if (wp->w_winrow != *row
        || wp->w_wincol != *col) {
      // position changed, redraw
      wp->w_winrow = *row;
      wp->w_wincol = *col;
      redraw_later(wp, UPD_NOT_VALID);
      wp->w_redr_status = true;
      wp->w_pos_changed = true;
    }
    const int h = wp->w_height + wp->w_hsep_height + wp->w_status_height;
    *row += h > topfrp->fr_height ? topfrp->fr_height : h;
    *col += wp->w_width + wp->w_vsep_width;
  } else {
    int startrow = *row;
    int startcol = *col;
    frame_T *frp;
    FOR_ALL_FRAMES(frp, topfrp->fr_child) {
      if (topfrp->fr_layout == FR_ROW) {
        *row = startrow;  // all frames are at the same row
      } else {
        *col = startcol;  // all frames are at the same col
      }
      frame_comp_pos(frp, row, col);
    }
  }
}

// Set current window height and take care of repositioning other windows to
// fit around it.
void win_setheight(int height)
{
  win_setheight_win(height, curwin);
}

// Set the window height of window "win" and take care of repositioning other
// windows to fit around it.
void win_setheight_win(int height, win_T *win)
{
  // Always keep current window at least one line high, even when 'winminheight' is zero.
  // Keep window at least two lines high if 'winbar' is enabled.
  height = MAX(height, (int)(win == curwin ? MAX(p_wmh, 1) : p_wmh) + win->w_winbar_height);

  if (win->w_floating) {
    win->w_config.height = height;
    win_config_float(win, win->w_config);
    redraw_later(win, UPD_VALID);
  } else {
    frame_setheight(win->w_frame, height + win->w_hsep_height + win->w_status_height);

    // recompute the window positions
    int row = win_comp_pos();

    // If there is extra space created between the last window and the command
    // line, clear it.
    if (full_screen && msg_scrolled == 0 && row < cmdline_row) {
      grid_clear(&default_grid, row, cmdline_row, 0, Columns, 0);
      if (msg_grid.chars) {
        clear_cmdline = true;
      }
    }
    cmdline_row = row;
    p_ch = MAX(Rows - cmdline_row, 0);
    curtab->tp_ch_used = p_ch;
    msg_row = row;
    msg_col = 0;

    win_fix_scroll(true);

    redraw_all_later(UPD_NOT_VALID);
    redraw_cmdline = true;
  }
}

// Set the height of a frame to "height" and take care that all frames and
// windows inside it are resized.  Also resize frames on the left and right if
// the are in the same FR_ROW frame.
//
// Strategy:
// If the frame is part of a FR_COL frame, try fitting the frame in that
// frame.  If that doesn't work (the FR_COL frame is too small), recursively
// go to containing frames to resize them and make room.
// If the frame is part of a FR_ROW frame, all frames must be resized as well.
// Check for the minimal height of the FR_ROW frame.
// At the top level we can also use change the command line height.
static void frame_setheight(frame_T *curfrp, int height)
{
  // If the height already is the desired value, nothing to do.
  if (curfrp->fr_height == height) {
    return;
  }

  if (curfrp->fr_parent == NULL) {
    // topframe: can only change the command line height
    if (height > ROWS_AVAIL) {
      // If height is greater than the available space, try to create space for
      // the frame by reducing 'cmdheight' if possible, while making sure
      // `cmdheight` doesn't go below 1 if it wasn't set to 0 explicitly.
      height = (int)MIN(ROWS_AVAIL + p_ch - !p_ch_was_zero, height);
    }
    if (height > 0) {
      frame_new_height(curfrp, height, false, false);
    }
  } else if (curfrp->fr_parent->fr_layout == FR_ROW) {
    // Row of frames: Also need to resize frames left and right of this
    // one.  First check for the minimal height of these.
    int h = frame_minheight(curfrp->fr_parent, NULL);
    if (height < h) {
      height = h;
    }
    frame_setheight(curfrp->fr_parent, height);
  } else {
    // Column of frames: try to change only frames in this column.

    int room;                     // total number of lines available
    int room_cmdline;             // lines available from cmdline
    int room_reserved;

    // Do this twice:
    // 1: compute room available, if it's not enough try resizing the
    //    containing frame.
    // 2: compute the room available and adjust the height to it.
    // Try not to reduce the height of a window with 'winfixheight' set.
    for (int run = 1; run <= 2; run++) {
      room = 0;
      room_reserved = 0;
      frame_T *frp;
      FOR_ALL_FRAMES(frp, curfrp->fr_parent->fr_child) {
        if (frp != curfrp
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfh) {
          room_reserved += frp->fr_height;
        }
        room += frp->fr_height;
        if (frp != curfrp) {
          room -= frame_minheight(frp, NULL);
        }
      }
      if (curfrp->fr_width != Columns) {
        room_cmdline = 0;
      } else {
        win_T *wp = lastwin_nofloating();
        room_cmdline = Rows - (int)p_ch - global_stl_height()
                       - (wp->w_winrow + wp->w_height + wp->w_hsep_height + wp->w_status_height);
        if (room_cmdline < 0) {
          room_cmdline = 0;
        }
      }

      if (height <= room + room_cmdline) {
        break;
      }
      if (run == 2 || curfrp->fr_width == Columns) {
        height = room + room_cmdline;
        break;
      }
      frame_setheight(curfrp->fr_parent, height
                      + frame_minheight(curfrp->fr_parent, NOWIN) - (int)p_wmh - 1);
      // NOTREACHED
    }

    // Compute the number of lines we will take from others frames (can be
    // negative!).
    int take = height - curfrp->fr_height;

    // If there is not enough room, also reduce the height of a window
    // with 'winfixheight' set.
    if (height > room + room_cmdline - room_reserved) {
      room_reserved = room + room_cmdline - height;
    }
    // If there is only a 'winfixheight' window and making the
    // window smaller, need to make the other window taller.
    if (take < 0 && room - curfrp->fr_height < room_reserved) {
      room_reserved = 0;
    }

    if (take > 0 && room_cmdline > 0) {
      // use lines from cmdline first
      if (take < room_cmdline) {
        room_cmdline = take;
      }
      take -= room_cmdline;
      topframe->fr_height += room_cmdline;
    }

    // set the current frame to the new height
    frame_new_height(curfrp, height, false, false);

    // First take lines from the frames after the current frame.  If
    // that is not enough, takes lines from frames above the current
    // frame.
    for (int run = 0; run < 2; run++) {
      // 1st run: start with next window
      // 2nd run: start with prev window
      frame_T *frp = run == 0 ? curfrp->fr_next : curfrp->fr_prev;

      while (frp != NULL && take != 0) {
        int h = frame_minheight(frp, NULL);
        if (room_reserved > 0
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfh) {
          if (room_reserved >= frp->fr_height) {
            room_reserved -= frp->fr_height;
          } else {
            if (frp->fr_height - room_reserved > take) {
              room_reserved = frp->fr_height - take;
            }
            take -= frp->fr_height - room_reserved;
            frame_new_height(frp, room_reserved, false, false);
            room_reserved = 0;
          }
        } else {
          if (frp->fr_height - take < h) {
            take -= frp->fr_height - h;
            frame_new_height(frp, h, false, false);
          } else {
            frame_new_height(frp, frp->fr_height - take, false, false);
            take = 0;
          }
        }
        if (run == 0) {
          frp = frp->fr_next;
        } else {
          frp = frp->fr_prev;
        }
      }
    }
  }
}

// Set current window width and take care of repositioning other windows to
// fit around it.
void win_setwidth(int width)
{
  win_setwidth_win(width, curwin);
}

void win_setwidth_win(int width, win_T *wp)
{
  // Always keep current window at least one column wide, even when
  // 'winminwidth' is zero.
  if (wp == curwin) {
    if (width < p_wmw) {
      width = (int)p_wmw;
    }
    if (width == 0) {
      width = 1;
    }
  } else if (width < 0) {
    width = 0;
  }
  if (wp->w_floating) {
    wp->w_config.width = width;
    win_config_float(wp, wp->w_config);
    redraw_later(wp, UPD_NOT_VALID);
  } else {
    frame_setwidth(wp->w_frame, width + wp->w_vsep_width);

    // recompute the window positions
    win_comp_pos();
    redraw_all_later(UPD_NOT_VALID);
  }
}

// Set the width of a frame to "width" and take care that all frames and
// windows inside it are resized.  Also resize frames above and below if the
// are in the same FR_ROW frame.
//
// Strategy is similar to frame_setheight().
static void frame_setwidth(frame_T *curfrp, int width)
{
  // If the width already is the desired value, nothing to do.
  if (curfrp->fr_width == width) {
    return;
  }

  if (curfrp->fr_parent == NULL) {
    // topframe: can't change width
    return;
  }

  if (curfrp->fr_parent->fr_layout == FR_COL) {
    // Column of frames: Also need to resize frames above and below of
    // this one.  First check for the minimal width of these.
    int w = frame_minwidth(curfrp->fr_parent, NULL);
    if (width < w) {
      width = w;
    }
    frame_setwidth(curfrp->fr_parent, width);
  } else {
    // Row of frames: try to change only frames in this row.
    //
    // Do this twice:
    // 1: compute room available, if it's not enough try resizing the
    //    containing frame.
    // 2: compute the room available and adjust the width to it.

    int room;  // total number of lines available
    int room_reserved;
    for (int run = 1; run <= 2; run++) {
      room = 0;
      room_reserved = 0;
      frame_T *frp;
      FOR_ALL_FRAMES(frp, curfrp->fr_parent->fr_child) {
        if (frp != curfrp
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfw) {
          room_reserved += frp->fr_width;
        }
        room += frp->fr_width;
        if (frp != curfrp) {
          room -= frame_minwidth(frp, NULL);
        }
      }

      if (width <= room) {
        break;
      }
      if (run == 2 || curfrp->fr_height >= ROWS_AVAIL) {
        width = room;
        break;
      }
      frame_setwidth(curfrp->fr_parent, width
                     + frame_minwidth(curfrp->fr_parent, NOWIN) - (int)p_wmw - 1);
    }

    // Compute the number of lines we will take from others frames (can be
    // negative!).
    int take = width - curfrp->fr_width;

    // If there is not enough room, also reduce the width of a window
    // with 'winfixwidth' set.
    if (width > room - room_reserved) {
      room_reserved = room - width;
    }
    // If there is only a 'winfixwidth' window and making the
    // window smaller, need to make the other window narrower.
    if (take < 0 && room - curfrp->fr_width < room_reserved) {
      room_reserved = 0;
    }

    // set the current frame to the new width
    frame_new_width(curfrp, width, false, false);

    // First take lines from the frames right of the current frame.  If
    // that is not enough, takes lines from frames left of the current
    // frame.
    for (int run = 0; run < 2; run++) {
      // 1st run: start with next window
      // 2nd run: start with prev window
      frame_T *frp = run == 0 ? curfrp->fr_next : curfrp->fr_prev;

      while (frp != NULL && take != 0) {
        int w = frame_minwidth(frp, NULL);
        if (room_reserved > 0
            && frp->fr_win != NULL
            && frp->fr_win->w_p_wfw) {
          if (room_reserved >= frp->fr_width) {
            room_reserved -= frp->fr_width;
          } else {
            if (frp->fr_width - room_reserved > take) {
              room_reserved = frp->fr_width - take;
            }
            take -= frp->fr_width - room_reserved;
            frame_new_width(frp, room_reserved, false, false);
            room_reserved = 0;
          }
        } else {
          if (frp->fr_width - take < w) {
            take -= frp->fr_width - w;
            frame_new_width(frp, w, false, false);
          } else {
            frame_new_width(frp, frp->fr_width - take, false, false);
            take = 0;
          }
        }
        if (run == 0) {
          frp = frp->fr_next;
        } else {
          frp = frp->fr_prev;
        }
      }
    }
  }
}

// Check 'winminheight' for a valid value and reduce it if needed.
const char *did_set_winminheight(optset_T *args FUNC_ATTR_UNUSED)
{
  bool first = true;

  // loop until there is a 'winminheight' that is possible
  while (p_wmh > 0) {
    const int room = Rows - (int)p_ch;
    const int needed = min_rows();
    if (room >= needed) {
      break;
    }
    p_wmh--;
    if (first) {
      emsg(_(e_noroom));
      first = false;
    }
  }
  return NULL;
}

// Check 'winminwidth' for a valid value and reduce it if needed.
const char *did_set_winminwidth(optset_T *args FUNC_ATTR_UNUSED)
{
  bool first = true;

  // loop until there is a 'winminheight' that is possible
  while (p_wmw > 0) {
    const int room = Columns;
    const int needed = frame_minwidth(topframe, NULL);
    if (room >= needed) {
      break;
    }
    p_wmw--;
    if (first) {
      emsg(_(e_noroom));
      first = false;
    }
  }
  return NULL;
}

/// Status line of dragwin is dragged "offset" lines down (negative is up).
void win_drag_status_line(win_T *dragwin, int offset)
{
  frame_T *fr = dragwin->w_frame;
  frame_T *curfr = fr;
  if (fr != topframe) {         // more than one window
    fr = fr->fr_parent;
    // When the parent frame is not a column of frames, its parent should
    // be.
    if (fr->fr_layout != FR_COL) {
      curfr = fr;
      if (fr != topframe) {     // only a row of windows, may drag statusline
        fr = fr->fr_parent;
      }
    }
  }

  // If this is the last frame in a column, may want to resize the parent
  // frame instead (go two up to skip a row of frames).
  while (curfr != topframe && curfr->fr_next == NULL) {
    if (fr != topframe) {
      fr = fr->fr_parent;
    }
    curfr = fr;
    if (fr != topframe) {
      fr = fr->fr_parent;
    }
  }

  int room;
  const bool up = offset < 0;  // if true, drag status line up, otherwise down

  if (up) {  // drag up
    offset = -offset;
    // sum up the room of the current frame and above it
    if (fr == curfr) {
      // only one window
      room = fr->fr_height - frame_minheight(fr, NULL);
    } else {
      room = 0;
      for (fr = fr->fr_child;; fr = fr->fr_next) {
        room += fr->fr_height - frame_minheight(fr, NULL);
        if (fr == curfr) {
          break;
        }
      }
    }
    fr = curfr->fr_next;                // put fr at frame that grows
  } else {  // drag down
    // Only dragging the last status line can reduce p_ch.
    room = Rows - cmdline_row;
    if (curfr->fr_next != NULL) {
      room -= (int)p_ch + global_stl_height();
    } else if (!p_ch_was_zero) {
      room--;
    }
    if (room < 0) {
      room = 0;
    }
    // sum up the room of frames below of the current one
    FOR_ALL_FRAMES(fr, curfr->fr_next) {
      room += fr->fr_height - frame_minheight(fr, NULL);
    }
    fr = curfr;  // put fr at window that grows
  }

  if (room < offset) {          // Not enough room
    offset = room;              // Move as far as we can
  }
  if (offset <= 0) {
    return;
  }

  // Grow frame fr by "offset" lines.
  // Doesn't happen when dragging the last status line up.
  if (fr != NULL) {
    frame_new_height(fr, fr->fr_height + offset, up, false);
  }

  if (up) {
    fr = curfr;                 // current frame gets smaller
  } else {
    fr = curfr->fr_next;        // next frame gets smaller
  }
  // Now make the other frames smaller.
  while (fr != NULL && offset > 0) {
    int n = frame_minheight(fr, NULL);
    if (fr->fr_height - offset <= n) {
      offset -= fr->fr_height - n;
      frame_new_height(fr, n, !up, false);
    } else {
      frame_new_height(fr, fr->fr_height - offset, !up, false);
      break;
    }
    if (up) {
      fr = fr->fr_prev;
    } else {
      fr = fr->fr_next;
    }
  }
  int row = win_comp_pos();
  grid_clear(&default_grid, row, cmdline_row, 0, Columns, 0);
  if (msg_grid.chars) {
    clear_cmdline = true;
  }
  cmdline_row = row;
  p_ch = MAX(Rows - cmdline_row, p_ch_was_zero ? 0 : 1);
  curtab->tp_ch_used = p_ch;

  win_fix_scroll(true);

  redraw_all_later(UPD_SOME_VALID);
  showmode();
}

// Separator line of dragwin is dragged "offset" lines right (negative is left).
void win_drag_vsep_line(win_T *dragwin, int offset)
{
  frame_T *fr = dragwin->w_frame;
  if (fr == topframe) {         // only one window (cannot happen?)
    return;
  }
  frame_T *curfr = fr;
  fr = fr->fr_parent;
  // When the parent frame is not a row of frames, its parent should be.
  if (fr->fr_layout != FR_ROW) {
    if (fr == topframe) {       // only a column of windows (cannot happen?)
      return;
    }
    curfr = fr;
    fr = fr->fr_parent;
  }

  // If this is the last frame in a row, may want to resize a parent
  // frame instead.
  while (curfr->fr_next == NULL) {
    if (fr == topframe) {
      break;
    }
    curfr = fr;
    fr = fr->fr_parent;
    if (fr != topframe) {
      curfr = fr;
      fr = fr->fr_parent;
    }
  }

  int room;
  const bool left = offset < 0;  // if true, drag separator line left, otherwise right

  if (left) {  // drag left
    offset = -offset;
    // sum up the room of the current frame and left of it
    room = 0;
    for (fr = fr->fr_child;; fr = fr->fr_next) {
      room += fr->fr_width - frame_minwidth(fr, NULL);
      if (fr == curfr) {
        break;
      }
    }
    fr = curfr->fr_next;                // put fr at frame that grows
  } else {  // drag right
    // sum up the room of frames right of the current one
    room = 0;
    FOR_ALL_FRAMES(fr, curfr->fr_next) {
      room += fr->fr_width - frame_minwidth(fr, NULL);
    }
    fr = curfr;  // put fr at window that grows
  }

  // Not enough room
  if (room < offset) {
    offset = room;  // Move as far as we can
  }

  // No room at all, quit.
  if (offset <= 0) {
    return;
  }

  if (fr == NULL) {
    // This can happen when calling win_move_separator() on the rightmost
    // window.  Just don't do anything.
    return;
  }

  // grow frame fr by offset lines
  frame_new_width(fr, fr->fr_width + offset, left, false);

  // shrink other frames: current and at the left or at the right
  if (left) {
    fr = curfr;                 // current frame gets smaller
  } else {
    fr = curfr->fr_next;        // next frame gets smaller
  }
  while (fr != NULL && offset > 0) {
    int n = frame_minwidth(fr, NULL);
    if (fr->fr_width - offset <= n) {
      offset -= fr->fr_width - n;
      frame_new_width(fr, n, !left, false);
    } else {
      frame_new_width(fr, fr->fr_width - offset, !left, false);
      break;
    }
    if (left) {
      fr = fr->fr_prev;
    } else {
      fr = fr->fr_next;
    }
  }
  win_comp_pos();
  redraw_all_later(UPD_NOT_VALID);
}

#define FRACTION_MULT   16384

// Set wp->w_fraction for the current w_wrow and w_height.
// Has no effect when the window is less than two lines.
void set_fraction(win_T *wp)
{
  if (wp->w_height_inner > 1) {
    // When cursor is in the first line the percentage is computed as if
    // it's halfway that line.  Thus with two lines it is 25%, with three
    // lines 17%, etc.  Similarly for the last line: 75%, 83%, etc.
    wp->w_fraction = (wp->w_wrow * FRACTION_MULT + FRACTION_MULT / 2) / wp->w_height_inner;
  }
}

/// Handle scroll position, depending on 'splitkeep'.  Replaces the
/// scroll_to_fraction() call from win_new_height() if 'splitkeep' is "screen"
/// or "topline".  Instead we iterate over all windows in a tabpage and
/// calculate the new scroll position.
/// TODO(vim): Ensure this also works with wrapped lines.
/// Requires a not fully visible cursor line to be allowed at the bottom of
/// a window("zb"), probably only when 'smoothscroll' is also set.
void win_fix_scroll(bool resize)
{
  if (*p_spk == 'c') {
    return;  // 'splitkeep' is "cursor"
  }

  skip_update_topline = true;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    // Skip when window height has not changed or when floating.
    if (!wp->w_floating && wp->w_height != wp->w_prev_height) {
      // Cursor position in this window may now be invalid.  It is kept
      // potentially invalid until the window is made the current window.
      wp->w_do_win_fix_cursor = true;

      // If window has moved update botline to keep the same screenlines.
      if (*p_spk == 's' && wp->w_winrow != wp->w_prev_winrow
          && wp->w_botline - 1 <= wp->w_buffer->b_ml.ml_line_count) {
        int diff = (wp->w_winrow - wp->w_prev_winrow)
                   + (wp->w_height - wp->w_prev_height);
        linenr_T lnum = wp->w_cursor.lnum;
        wp->w_cursor.lnum = wp->w_botline - 1;

        // Add difference in height and row to botline.
        if (diff > 0) {
          cursor_down_inner(wp, diff);
        } else {
          cursor_up_inner(wp, -diff);
        }

        // Scroll to put the new cursor position at the bottom of the
        // screen.
        wp->w_fraction = FRACTION_MULT;
        scroll_to_fraction(wp, wp->w_prev_height);
        wp->w_cursor.lnum = lnum;
      } else if (wp == curwin) {
        wp->w_valid &= ~VALID_CROW;
      }

      invalidate_botline(wp);
      validate_botline(wp);
    }
    wp->w_prev_height = wp->w_height;
    wp->w_prev_winrow = wp->w_winrow;
  }
  skip_update_topline = false;
  // Ensure cursor is valid when not in normal mode or when resized.
  if (!(get_real_state() & (MODE_NORMAL|MODE_CMDLINE|MODE_TERMINAL))) {
    win_fix_cursor(false);
  } else if (resize) {
    win_fix_cursor(true);
  }
}

/// Make sure the cursor position is valid for 'splitkeep'.
/// If it is not, put the cursor position in the jumplist and move it.
/// If we are not in normal mode ("normal" is false), make it valid by scrolling
/// instead.
static void win_fix_cursor(bool normal)
{
  win_T *wp = curwin;

  if (skip_win_fix_cursor
      || !wp->w_do_win_fix_cursor
      || wp->w_buffer->b_ml.ml_line_count < wp->w_height_inner) {
    return;
  }

  wp->w_do_win_fix_cursor = false;
  // Determine valid cursor range.
  int so = MIN(wp->w_height_inner / 2, get_scrolloff_value(wp));
  linenr_T lnum = wp->w_cursor.lnum;

  wp->w_cursor.lnum = wp->w_topline;
  cursor_down_inner(wp, so);
  linenr_T top = wp->w_cursor.lnum;

  wp->w_cursor.lnum = wp->w_botline - 1;
  cursor_up_inner(wp, so);
  linenr_T bot = wp->w_cursor.lnum;

  wp->w_cursor.lnum = lnum;
  // Check if cursor position is above or below valid cursor range.
  linenr_T nlnum = 0;
  if (lnum > bot && (wp->w_botline - wp->w_buffer->b_ml.ml_line_count) != 1) {
    nlnum = bot;
  } else if (lnum < top && wp->w_topline != 1) {
    nlnum = (so == wp->w_height_inner / 2) ? bot : top;
  }

  if (nlnum != 0) {  // Cursor is invalid for current scroll position.
    if (normal) {    // Save to jumplist and set cursor to avoid scrolling.
      setmark('\'');
      wp->w_cursor.lnum = nlnum;
    } else {         // Scroll instead when not in normal mode.
      wp->w_fraction = (nlnum == bot) ? FRACTION_MULT : 0;
      scroll_to_fraction(wp, wp->w_prev_height);
      validate_botline(curwin);
    }
  }
}

// Set the height of a window.
// "height" excludes any window toolbar.
// This takes care of the things inside the window, not what happens to the
// window position, the frame or to other windows.
void win_new_height(win_T *wp, int height)
{
  // Don't want a negative height.  Happens when splitting a tiny window.
  // Will equalize heights soon to fix it.
  if (height < 0) {
    height = 0;
  }
  if (wp->w_height == height) {
    return;  // nothing to do
  }

  wp->w_height = height;
  wp->w_pos_changed = true;
  win_set_inner_size(wp, true);
}

void scroll_to_fraction(win_T *wp, int prev_height)
{
  int height = wp->w_height_inner;

  // Don't change w_topline in any of these cases:
  // - window height is 0
  // - 'scrollbind' is set and this isn't the current window
  // - window height is sufficient to display the whole buffer and first line
  //   is visible.
  if (height > 0
      && (!wp->w_p_scb || wp == curwin)
      && (height < wp->w_buffer->b_ml.ml_line_count
          || wp->w_topline > 1)) {
    // Find a value for w_topline that shows the cursor at the same
    // relative position in the window as before (more or less).
    linenr_T lnum = wp->w_cursor.lnum;
    if (lnum < 1) {             // can happen when starting up
      lnum = 1;
    }
    wp->w_wrow = (wp->w_fraction * height - 1) / FRACTION_MULT;
    int line_size = plines_win_col(wp, lnum, wp->w_cursor.col) - 1;
    int sline = wp->w_wrow - line_size;

    if (sline >= 0) {
      // Make sure the whole cursor line is visible, if possible.
      const int rows = plines_win(wp, lnum, false);

      if (sline > wp->w_height_inner - rows) {
        sline = wp->w_height_inner - rows;
        wp->w_wrow -= rows - line_size;
      }
    }

    if (sline < 0) {
      // Cursor line would go off top of screen if w_wrow was this high.
      // Make cursor line the first line in the window.  If not enough
      // room use w_skipcol;
      wp->w_wrow = line_size;
      if (wp->w_wrow >= wp->w_height_inner
          && (wp->w_width_inner - win_col_off(wp)) > 0) {
        wp->w_skipcol += wp->w_width_inner - win_col_off(wp);
        wp->w_wrow--;
        while (wp->w_wrow >= wp->w_height_inner) {
          wp->w_skipcol += wp->w_width_inner - win_col_off(wp)
                           + win_col_off2(wp);
          wp->w_wrow--;
        }
      }
    } else if (sline > 0) {
      while (sline > 0 && lnum > 1) {
        hasFolding(wp, lnum, &lnum, NULL);
        if (lnum == 1) {
          // first line in buffer is folded
          line_size = 1;
          sline--;
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
        // Line we want at top would go off top of screen.  Use next
        // line instead.
        hasFolding(wp, lnum, NULL, &lnum);
        lnum++;
        wp->w_wrow -= line_size + sline;
      } else if (sline > 0) {
        // First line of file reached, use that as topline.
        lnum = 1;
        wp->w_wrow -= sline;
      }
    }
    set_topline(wp, lnum);
  }

  if (wp == curwin) {
    curs_columns(wp, false);        // validate w_wrow
  }
  if (prev_height > 0) {
    wp->w_prev_fraction_row = wp->w_wrow;
  }

  redraw_later(wp, UPD_SOME_VALID);
  invalidate_botline(wp);
}

void win_set_inner_size(win_T *wp, bool valid_cursor)
{
  int width = wp->w_width_request;
  if (width == 0) {
    width = wp->w_width;
  }

  int prev_height = wp->w_height_inner;
  int height = wp->w_height_request;
  if (height == 0) {
    height = wp->w_height - wp->w_winbar_height;
  }

  if (height != prev_height) {
    if (height > 0 && valid_cursor) {
      if (wp == curwin && *p_spk == 'c') {
        // w_wrow needs to be valid. When setting 'laststatus' this may
        // call win_new_height() recursively.
        validate_cursor(curwin);
      }
      if (wp->w_height_inner != prev_height) {
        return;  // Recursive call already changed the size, bail out.
      }
      if (wp->w_wrow != wp->w_prev_fraction_row) {
        set_fraction(wp);
      }
    }
    wp->w_height_inner = height;
    win_comp_scroll(wp);

    // There is no point in adjusting the scroll position when exiting.  Some
    // values might be invalid.
    if (valid_cursor && !exiting && *p_spk == 'c') {
      wp->w_skipcol = 0;
      scroll_to_fraction(wp, prev_height);
    }
    redraw_later(wp, UPD_SOME_VALID);
  }

  if (width != wp->w_width_inner) {
    wp->w_width_inner = width;
    wp->w_lines_valid = 0;
    if (valid_cursor) {
      changed_line_abv_curs_win(wp);
      invalidate_botline(wp);
      if (wp == curwin && *p_spk == 'c') {
        curs_columns(wp, true);  // validate w_wrow
      }
    }
    redraw_later(wp, UPD_NOT_VALID);
  }

  if (wp->w_buffer->terminal) {
    terminal_check_size(wp->w_buffer->terminal);
  }

  wp->w_height_outer = (wp->w_height_inner + win_border_height(wp) + wp->w_winbar_height);
  wp->w_width_outer = (wp->w_width_inner + win_border_width(wp));
  wp->w_winrow_off = wp->w_border_adj[0] + wp->w_winbar_height;
  wp->w_wincol_off = wp->w_border_adj[3];

  if (ui_has(kUIMultigrid)) {
    ui_call_win_viewport_margins(wp->w_grid_alloc.handle, wp->handle,
                                 wp->w_winrow_off, wp->w_border_adj[2],
                                 wp->w_wincol_off, wp->w_border_adj[1]);
  }

  wp->w_redr_status = true;
}

/// Set the width of a window.
void win_new_width(win_T *wp, int width)
{
  // Should we give an error if width < 0?
  wp->w_width = width < 0 ? 0 : width;
  wp->w_pos_changed = true;
  win_set_inner_size(wp, true);
}

OptInt win_default_scroll(win_T *wp)
{
  return MAX(wp->w_height_inner / 2, 1);
}

void win_comp_scroll(win_T *wp)
{
  const OptInt old_w_p_scr = wp->w_p_scr;
  wp->w_p_scr = win_default_scroll(wp);

  if (wp->w_p_scr != old_w_p_scr) {
    // Used by "verbose set scroll".
    wp->w_p_script_ctx[WV_SCROLL].script_ctx.sc_sid = SID_WINLAYOUT;
    wp->w_p_script_ctx[WV_SCROLL].script_ctx.sc_lnum = 0;
  }
}

/// command_height: called whenever p_ch has been changed.
void command_height(void)
{
  int old_p_ch = (int)curtab->tp_ch_used;

  // Use the value of p_ch that we remembered.  This is needed for when the
  // GUI starts up, we can't be sure in what order things happen.  And when
  // p_ch was changed in another tab page.
  curtab->tp_ch_used = p_ch;

  // Update cmdline_row to what it should be: just below the last window.
  cmdline_row = topframe->fr_height + tabline_height() + global_stl_height();

  // If cmdline_row is smaller than what it is supposed to be for 'cmdheight'
  // then set old_p_ch to what it would be, so that the windows get resized
  // properly for the new value.
  if (cmdline_row < Rows - p_ch) {
    old_p_ch = Rows - cmdline_row;
  }

  // Find bottom frame with width of screen.
  frame_T *frp = lastwin_nofloating()->w_frame;
  while (frp->fr_width != Columns && frp->fr_parent != NULL) {
    frp = frp->fr_parent;
  }

  // Avoid changing the height of a window with 'winfixheight' set.
  while (frp->fr_prev != NULL && frp->fr_layout == FR_LEAF
         && frp->fr_win->w_p_wfh) {
    frp = frp->fr_prev;
  }

  if (starting != NO_SCREEN) {
    cmdline_row = Rows - (int)p_ch;

    if (p_ch > old_p_ch) {                  // p_ch got bigger
      while (p_ch > old_p_ch) {
        if (frp == NULL) {
          emsg(_(e_noroom));
          p_ch = old_p_ch;
          curtab->tp_ch_used = p_ch;
          cmdline_row = Rows - (int)p_ch;
          break;
        }
        int h = frp->fr_height - frame_minheight(frp, NULL);
        if (h > p_ch - old_p_ch) {
          h = (int)p_ch - old_p_ch;
        }
        old_p_ch += h;
        frame_add_height(frp, -h);
        frp = frp->fr_prev;
      }

      // Recompute window positions.
      win_comp_pos();

      // clear the lines added to cmdline
      if (full_screen) {
        grid_clear(&default_grid, cmdline_row, Rows, 0, Columns, 0);
      }
      msg_row = cmdline_row;
      redraw_cmdline = true;
      return;
    }

    if (msg_row < cmdline_row) {
      msg_row = cmdline_row;
    }
    redraw_cmdline = true;
  }
  frame_add_height(frp, (int)(old_p_ch - p_ch));

  // Recompute window positions.
  if (frp != lastwin->w_frame) {
    win_comp_pos();
  }
}

// Resize frame "frp" to be "n" lines higher (negative for less high).
// Also resize the frames it is contained in.
static void frame_add_height(frame_T *frp, int n)
{
  frame_new_height(frp, frp->fr_height + n, false, false);
  while (true) {
    frp = frp->fr_parent;
    if (frp == NULL) {
      break;
    }
    frp->fr_height += n;
  }
}

// Get the file name at the cursor.
// If Visual mode is active, use the selected text if it's in one line.
// Returns the name in allocated memory, NULL for failure.
char *grab_file_name(int count, linenr_T *file_lnum)
{
  int options = FNAME_MESS | FNAME_EXP | FNAME_REL | FNAME_UNESC;
  if (VIsual_active) {
    size_t len;
    char *ptr;
    if (get_visual_text(NULL, &ptr, &len) == FAIL) {
      return NULL;
    }
    // Only recognize ":123" here
    if (file_lnum != NULL && ptr[len] == ':' && isdigit((uint8_t)ptr[len + 1])) {
      char *p = ptr + len + 1;

      *file_lnum = getdigits_int32(&p, false, 0);
    }
    return find_file_name_in_path(ptr, len, options, count, curbuf->b_ffname);
  }
  return file_name_at_cursor(options | FNAME_HYP, count, file_lnum);
}

// Return the file name under or after the cursor.
//
// The 'path' option is searched if the file name is not absolute.
// The string returned has been alloc'ed and should be freed by the caller.
// NULL is returned if the file name or file is not found.
//
// options:
// FNAME_MESS       give error messages
// FNAME_EXP        expand to path
// FNAME_HYP        check for hypertext link
// FNAME_INCL       apply "includeexpr"
char *file_name_at_cursor(int options, int count, linenr_T *file_lnum)
{
  return file_name_in_line(get_cursor_line_ptr(),
                           curwin->w_cursor.col, options, count, curbuf->b_ffname,
                           file_lnum);
}

/// @param rel_fname  file we are searching relative to
/// @param file_lnum  line number after the file name
///
/// @return  the name of the file under or after ptr[col]. Otherwise like file_name_at_cursor().
char *file_name_in_line(char *line, int col, int options, int count, char *rel_fname,
                        linenr_T *file_lnum)
{
  // search forward for what could be the start of a file name
  char *ptr = line + col;
  while (*ptr != NUL && !vim_isfilec((uint8_t)(*ptr))) {
    MB_PTR_ADV(ptr);
  }
  if (*ptr == NUL) {            // nothing found
    if (options & FNAME_MESS) {
      emsg(_("E446: No file name under cursor"));
    }
    return NULL;
  }

  size_t len;
  bool in_type = true;
  bool is_url = false;

  // Search backward for first char of the file name.
  // Go one char back to ":" before "//", or to the drive letter before ":\" (even if ":"
  // is not in 'isfname').
  while (ptr > line) {
    if ((len = (size_t)(utf_head_off(line, ptr - 1))) > 0) {
      ptr -= len + 1;
    } else if (vim_isfilec((uint8_t)ptr[-1]) || ((options & FNAME_HYP) && path_is_url(ptr - 1))) {
      ptr--;
    } else {
      break;
    }
  }

  // Search forward for the last char of the file name.
  // Also allow ":/" when ':' is not in 'isfname'.
  len = path_has_drive_letter(ptr) ? 2 : 0;
  while (vim_isfilec((uint8_t)ptr[len]) || (ptr[len] == '\\' && ptr[len + 1] == ' ')
         || ((options & FNAME_HYP) && path_is_url(ptr + len))
         || (is_url && vim_strchr(":?&=", (uint8_t)ptr[len]) != NULL)) {
    // After type:// we also include :, ?, & and = as valid characters, so that
    // http://google.com:8080?q=this&that=ok works.
    if ((ptr[len] >= 'A' && ptr[len] <= 'Z') || (ptr[len] >= 'a' && ptr[len] <= 'z')) {
      if (in_type && path_is_url(ptr + len + 1)) {
        is_url = true;
      }
    } else {
      in_type = false;
    }

    if (ptr[len] == '\\' && ptr[len + 1] == ' ') {
      // Skip over the "\" in "\ ".
      len++;
    }
    len += (size_t)(utfc_ptr2len(ptr + len));
  }

  // If there is trailing punctuation, remove it.
  // But don't remove "..", could be a directory name.
  if (len > 2 && vim_strchr(".,:;!", (uint8_t)ptr[len - 1]) != NULL
      && ptr[len - 2] != '.') {
    len--;
  }

  if (file_lnum != NULL) {
    const char *line_english = " line ";
    const char *line_transl = _(line_msg);

    // Get the number after the file name and a separator character.
    // Also accept " line 999" with and without the same translation as
    // used in last_set_msg().
    char *p = ptr + len;
    if (strncmp(p, line_english, strlen(line_english)) == 0) {
      p += strlen(line_english);
    } else if (strncmp(p, line_transl, strlen(line_transl)) == 0) {
      p += strlen(line_transl);
    } else {
      p = skipwhite(p);
    }
    if (*p != NUL) {
      if (!isdigit((uint8_t)(*p))) {
        p++;                        // skip the separator
      }
      p = skipwhite(p);
      if (isdigit((uint8_t)(*p))) {
        *file_lnum = (linenr_T)getdigits_long(&p, false, 0);
      }
    }
  }

  return find_file_name_in_path(ptr, len, options, count, rel_fname);
}

/// Add or remove a status line from window(s), according to the
/// value of 'laststatus'.
///
/// @param morewin  pretend there are two or more windows if true.
void last_status(bool morewin)
{
  // Don't make a difference between horizontal or vertical split.
  last_status_rec(topframe, last_stl_height(morewin) > 0, global_stl_height() > 0);
}

// Remove status line from window, replacing it with a horizontal separator if needed.
static void win_remove_status_line(win_T *wp, bool add_hsep)
{
  wp->w_status_height = 0;
  if (add_hsep) {
    wp->w_hsep_height = 1;
  } else {
    win_new_height(wp, wp->w_height + STATUS_HEIGHT);
  }
  comp_col();

  stl_clear_click_defs(wp->w_status_click_defs, wp->w_status_click_defs_size);
  xfree(wp->w_status_click_defs);
  wp->w_status_click_defs_size = 0;
  wp->w_status_click_defs = NULL;
}

// Look for a horizontally resizable frame, starting with frame "fr".
// Returns NULL if there are no resizable frames.
static frame_T *find_horizontally_resizable_frame(frame_T *fr)
{
  frame_T *fp = fr;

  while (fp->fr_height <= frame_minheight(fp, NULL)) {
    if (fp == topframe) {
      return NULL;
    }
    // In a column of frames: go to frame above.  If already at
    // the top or in a row of frames: go to parent.
    if (fp->fr_parent->fr_layout == FR_COL && fp->fr_prev != NULL) {
      fp = fp->fr_prev;
    } else {
      fp = fp->fr_parent;
    }
  }

  return fp;
}

// Look for resizable frames and take lines from them to make room for the statusline.
// @return Success or failure.
static bool resize_frame_for_status(frame_T *fr)
{
  win_T *wp = fr->fr_win;
  frame_T *fp = find_horizontally_resizable_frame(fr);

  if (fp == NULL) {
    emsg(_(e_noroom));
    return false;
  } else if (fp != fr) {
    frame_new_height(fp, fp->fr_height - 1, false, false);
    frame_fix_height(wp);
    win_comp_pos();
  } else {
    win_new_height(wp, wp->w_height - 1);
  }

  return true;
}

// Look for resizable frames and take lines from them to make room for the winbar.
// @return Success or failure.
static bool resize_frame_for_winbar(frame_T *fr)
{
  win_T *wp = fr->fr_win;
  frame_T *fp = find_horizontally_resizable_frame(fr);

  if (fp == NULL || fp == fr) {
    emsg(_(e_noroom));
    return false;
  }
  frame_new_height(fp, fp->fr_height - 1, false, false);
  win_new_height(wp, wp->w_height + 1);
  frame_fix_height(wp);
  win_comp_pos();

  return true;
}

static void last_status_rec(frame_T *fr, bool statusline, bool is_stl_global)
{
  if (fr->fr_layout == FR_LEAF) {
    win_T *wp = fr->fr_win;
    bool is_last = is_bottom_win(wp);

    if (is_last) {
      if (wp->w_status_height != 0 && (!statusline || is_stl_global)) {
        win_remove_status_line(wp, false);
      } else if (wp->w_status_height == 0 && !is_stl_global && statusline) {
        // Add statusline to window if needed
        wp->w_status_height = STATUS_HEIGHT;
        if (!resize_frame_for_status(fr)) {
          return;
        }
        comp_col();
      }
      // Set prev_height when difference is due to 'laststatus'.
      if (abs(wp->w_height - wp->w_prev_height) == 1) {
        wp->w_prev_height = wp->w_height;
      }
    } else if (wp->w_status_height != 0 && is_stl_global) {
      // If statusline is global and the window has a statusline, replace it with a horizontal
      // separator
      win_remove_status_line(wp, true);
    } else if (wp->w_status_height == 0 && !is_stl_global) {
      // If statusline isn't global and the window doesn't have a statusline, re-add it
      wp->w_status_height = STATUS_HEIGHT;
      wp->w_hsep_height = 0;
      comp_col();
    }
  } else {
    // For a column or row frame, recursively call this function for all child frames
    frame_T *fp;
    FOR_ALL_FRAMES(fp, fr->fr_child) {
      last_status_rec(fp, statusline, is_stl_global);
    }
  }
}

/// Add or remove window bar from window "wp".
///
/// @param make_room Whether to resize frames to make room for winbar.
/// @param valid_cursor Whether the cursor is valid and should be used while
///                     resizing.
///
/// @return Success status.
int set_winbar_win(win_T *wp, bool make_room, bool valid_cursor)
{
  // Require the local value to be set in order to show winbar on a floating window.
  int winbar_height = wp->w_floating ? ((*wp->w_p_wbr != NUL) ? 1 : 0)
                                     : ((*p_wbr != NUL || *wp->w_p_wbr != NUL) ? 1 : 0);

  if (wp->w_winbar_height != winbar_height) {
    if (winbar_height == 1 && wp->w_height_inner <= 1) {
      if (wp->w_floating) {
        emsg(_(e_noroom));
        return NOTDONE;
      } else if (!make_room || !resize_frame_for_winbar(wp->w_frame)) {
        return FAIL;
      }
    }
    wp->w_winbar_height = winbar_height;
    win_set_inner_size(wp, valid_cursor);

    if (winbar_height == 0) {
      // When removing winbar, deallocate the w_winbar_click_defs array
      stl_clear_click_defs(wp->w_winbar_click_defs, wp->w_winbar_click_defs_size);
      xfree(wp->w_winbar_click_defs);
      wp->w_winbar_click_defs_size = 0;
      wp->w_winbar_click_defs = NULL;
    }
  }

  return OK;
}

/// Add or remove window bars from all windows in tab depending on the value of 'winbar'.
///
/// @param make_room Whether to resize frames to make room for winbar.
void set_winbar(bool make_room)
{
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (set_winbar_win(wp, make_room, true) == FAIL) {
      break;
    }
  }
}

/// Return the number of lines used by the tab page line.
int tabline_height(void)
{
  if (ui_has(kUITabline)) {
    return 0;
  }
  assert(first_tabpage);
  switch (p_stal) {
  case 0:
    return 0;
  case 1:
    return (first_tabpage->tp_next == NULL) ? 0 : 1;
  }
  return 1;
}

/// Return the number of lines used by default by the window bar.
int global_winbar_height(void)
{
  return *p_wbr != NUL ? 1 : 0;
}

/// Return the number of lines used by the global statusline
int global_stl_height(void)
{
  return (p_ls == 3) ? STATUS_HEIGHT : 0;
}

/// Return the height of the last window's statusline, or the global statusline if set.
///
/// @param morewin  pretend there are two or more windows if true.
int last_stl_height(bool morewin)
{
  return (p_ls > 1 || (p_ls == 1 && (morewin || !one_window(firstwin)))) ? STATUS_HEIGHT : 0;
}

/// Return the minimal number of rows that is needed on the screen to display
/// the current number of windows.
int min_rows(void)
{
  if (firstwin == NULL) {       // not initialized yet
    return MIN_LINES;
  }

  int total = 0;
  FOR_ALL_TABS(tp) {
    int n = frame_minheight(tp->tp_topframe, NULL);
    if (total < n) {
      total = n;
    }
  }
  total += tabline_height() + global_stl_height();
  if (p_ch > 0) {
    total += 1;           // count the room for the command line
  }
  return total;
}

/// Check that there is only one window (and only one tab page), not counting a
/// help or preview window, unless it is the current window. Does not count
/// "aucmd_win". Does not count floats unless it is current.
bool only_one_window(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // If there is another tab page there always is another window.
  if (first_tabpage->tp_next != NULL) {
    return false;
  }

  int count = 0;
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp->w_buffer != NULL
        && (!((bt_help(wp->w_buffer) && !bt_help(curbuf)) || wp->w_floating
              || wp->w_p_pvw) || wp == curwin) && !is_aucmd_win(wp)) {
      count++;
    }
  }
  return count <= 1;
}

/// Implementation of check_lnums() and check_lnums_nested().
static void check_lnums_both(bool do_curwin, bool nested)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if ((do_curwin || wp != curwin) && wp->w_buffer == curbuf) {
      if (!nested) {
        // save the original cursor position and topline
        wp->w_save_cursor.w_cursor_save = wp->w_cursor;
        wp->w_save_cursor.w_topline_save = wp->w_topline;
      }

      bool need_adjust = wp->w_cursor.lnum > curbuf->b_ml.ml_line_count;
      if (need_adjust) {
        wp->w_cursor.lnum = curbuf->b_ml.ml_line_count;
      }
      if (need_adjust || !nested) {
        // save the (corrected) cursor position
        wp->w_save_cursor.w_cursor_corr = wp->w_cursor;
      }

      need_adjust = wp->w_topline > curbuf->b_ml.ml_line_count;
      if (need_adjust) {
        wp->w_topline = curbuf->b_ml.ml_line_count;
      }
      if (need_adjust || !nested) {
        // save the (corrected) topline
        wp->w_save_cursor.w_topline_corr = wp->w_topline;
      }
    }
  }
}

/// Correct the cursor line number in other windows.  Used after changing the
/// current buffer, and before applying autocommands.
///
/// @param do_curwin  when true, also check current window.
void check_lnums(bool do_curwin)
{
  check_lnums_both(do_curwin, false);
}

/// Like check_lnums() but for when check_lnums() was already called.
void check_lnums_nested(bool do_curwin)
{
  check_lnums_both(do_curwin, true);
}

/// Reset cursor and topline to its stored values from check_lnums().
/// check_lnums() must have been called first!
void reset_lnums(void)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_buffer == curbuf) {
      // Restore the value if the autocommand didn't change it and it was set.
      // Note: This triggers e.g. on BufReadPre, when the buffer is not yet
      //       loaded, so cannot validate the buffer line
      if (equalpos(wp->w_save_cursor.w_cursor_corr, wp->w_cursor)
          && wp->w_save_cursor.w_cursor_save.lnum != 0) {
        wp->w_cursor = wp->w_save_cursor.w_cursor_save;
      }
      if (wp->w_save_cursor.w_topline_corr == wp->w_topline
          && wp->w_save_cursor.w_topline_save != 0) {
        wp->w_topline = wp->w_save_cursor.w_topline_save;
      }
      if (wp->w_save_cursor.w_topline_save > wp->w_buffer->b_ml.ml_line_count) {
        wp->w_valid &= ~VALID_TOPLINE;
      }
    }
  }
}

// A snapshot of the window sizes, to restore them after closing the help
// window.
// Only these fields are used:
// fr_layout
// fr_width
// fr_height
// fr_next
// fr_child
// fr_win (only valid for the old curwin, NULL otherwise)

// Create a snapshot of the current frame sizes.
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
  if (fr->fr_next != NULL) {
    make_snapshot_rec(fr->fr_next, &((*frp)->fr_next));
  }
  if (fr->fr_child != NULL) {
    make_snapshot_rec(fr->fr_child, &((*frp)->fr_child));
  }
  if (fr->fr_layout == FR_LEAF && fr->fr_win == curwin) {
    (*frp)->fr_win = curwin;
  }
}

// Remove any existing snapshot.
static void clear_snapshot(tabpage_T *tp, int idx)
{
  clear_snapshot_rec(tp->tp_snapshot[idx]);
  tp->tp_snapshot[idx] = NULL;
}

static void clear_snapshot_rec(frame_T *fr)
{
  if (fr == NULL) {
    return;
  }
  clear_snapshot_rec(fr->fr_next);
  clear_snapshot_rec(fr->fr_child);
  xfree(fr);
}

/// Traverse a snapshot to find the previous curwin.
static win_T *get_snapshot_curwin_rec(frame_T *ft)
{
  win_T *wp;

  if (ft->fr_next != NULL) {
    if ((wp = get_snapshot_curwin_rec(ft->fr_next)) != NULL) {
      return wp;
    }
  }
  if (ft->fr_child != NULL) {
    if ((wp = get_snapshot_curwin_rec(ft->fr_child)) != NULL) {
      return wp;
    }
  }

  return ft->fr_win;
}

/// @return  the current window stored in the snapshot or NULL.
static win_T *get_snapshot_curwin(int idx)
{
  if (curtab->tp_snapshot[idx] == NULL) {
    return NULL;
  }

  return get_snapshot_curwin_rec(curtab->tp_snapshot[idx]);
}

/// Restore a previously created snapshot, if there is any.
/// This is only done if the screen size didn't change and the window layout is
/// still the same.
///
/// @param close_curwin  closing current window
void restore_snapshot(int idx, int close_curwin)
{
  if (curtab->tp_snapshot[idx] != NULL
      && curtab->tp_snapshot[idx]->fr_width == topframe->fr_width
      && curtab->tp_snapshot[idx]->fr_height == topframe->fr_height
      && check_snapshot_rec(curtab->tp_snapshot[idx], topframe) == OK) {
    win_T *wp = restore_snapshot_rec(curtab->tp_snapshot[idx], topframe);
    win_comp_pos();
    if (wp != NULL && close_curwin) {
      win_goto(wp);
    }
    redraw_all_later(UPD_NOT_VALID);
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
      || (sn->fr_win != NULL && !win_valid(sn->fr_win))) {
    return FAIL;
  }
  return OK;
}

// Copy the size of snapshot frame "sn" to frame "fr".  Do the same for all
// following frames and children.
// Returns a pointer to the old current window, or NULL.
static win_T *restore_snapshot_rec(frame_T *sn, frame_T *fr)
{
  win_T *wp = NULL;

  fr->fr_height = sn->fr_height;
  fr->fr_width = sn->fr_width;
  if (fr->fr_layout == FR_LEAF) {
    frame_new_height(fr, fr->fr_height, false, false);
    frame_new_width(fr, fr->fr_width, false, false);
    wp = sn->fr_win;
  }
  if (sn->fr_next != NULL) {
    win_T *wp2 = restore_snapshot_rec(sn->fr_next, fr->fr_next);
    if (wp2 != NULL) {
      wp = wp2;
    }
  }
  if (sn->fr_child != NULL) {
    win_T *wp2 = restore_snapshot_rec(sn->fr_child, fr->fr_child);
    if (wp2 != NULL) {
      wp = wp2;
    }
  }
  return wp;
}

/// Check that "topfrp" and its children are at the right height.
///
/// @param  topfrp  top frame pointer
/// @param  height  expected height
static bool frame_check_height(const frame_T *topfrp, int height)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (topfrp->fr_height != height) {
    return false;
  }
  if (topfrp->fr_layout == FR_ROW) {
    const frame_T *frp;
    FOR_ALL_FRAMES(frp, topfrp->fr_child) {
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
static bool frame_check_width(const frame_T *topfrp, int width)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (topfrp->fr_width != width) {
    return false;
  }
  if (topfrp->fr_layout == FR_COL) {
    const frame_T *frp;
    FOR_ALL_FRAMES(frp, topfrp->fr_child) {
      if (frp->fr_width != width) {
        return false;
      }
    }
  }
  return true;
}

/// Simple int comparison function for use with qsort()
static int int_cmp(const void *pa, const void *pb)
{
  const int a = *(const int *)pa;
  const int b = *(const int *)pb;
  if (a > b) {
    return 1;
  }
  if (a < b) {
    return -1;
  }
  return 0;
}

/// Handle setting 'colorcolumn' or 'textwidth' in window "wp".
///
/// @return error message, NULL if it's OK.
const char *check_colorcolumn(win_T *wp)
{
  if (wp->w_buffer == NULL) {
    return NULL;      // buffer was closed
  }

  unsigned count = 0;
  int color_cols[256];
  for (char *s = wp->w_p_cc; *s != NUL && count < 255;) {
    int col;
    if (*s == '-' || *s == '+') {
      // -N and +N: add to 'textwidth'
      col = (*s == '-') ? -1 : 1;
      s++;
      if (!ascii_isdigit(*s)) {
        return e_invarg;
      }
      col = col * getdigits_int(&s, true, 0);
      if (wp->w_buffer->b_p_tw == 0) {
        goto skip;          // 'textwidth' not set, skip this item
      }
      assert((col >= 0
              && wp->w_buffer->b_p_tw <= INT_MAX - col
              && wp->w_buffer->b_p_tw + col >= INT_MIN)
             || (col < 0
                 && wp->w_buffer->b_p_tw >= INT_MIN - col
                 && wp->w_buffer->b_p_tw + col <= INT_MAX));
      col += (int)wp->w_buffer->b_p_tw;
      if (col < 0) {
        goto skip;
      }
    } else if (ascii_isdigit(*s)) {
      col = getdigits_int(&s, true, 0);
    } else {
      return e_invarg;
    }
    color_cols[count++] = col - 1;      // 1-based to 0-based
skip:
    if (*s == NUL) {
      break;
    }
    if (*s != ',') {
      return e_invarg;
    }
    if (*++s == NUL) {
      return e_invarg;        // illegal trailing comma as in "set cc=80,"
    }
  }

  xfree(wp->w_p_cc_cols);
  if (count == 0) {
    wp->w_p_cc_cols = NULL;
  } else {
    wp->w_p_cc_cols = xmalloc(sizeof(int) * (count + 1));
    // sort the columns for faster usage on screen redraw inside
    // win_line()
    qsort(color_cols, count, sizeof(int), int_cmp);

    int j = 0;
    for (unsigned i = 0; i < count; i++) {
      // skip duplicates
      if (j == 0 || wp->w_p_cc_cols[j - 1] != color_cols[i]) {
        wp->w_p_cc_cols[j++] = color_cols[i];
      }
    }
    wp->w_p_cc_cols[j] = -1;        // end marker
  }

  return NULL;    // no error
}

int get_last_winid(void)
{
  return last_win_id;
}

void win_get_tabwin(handle_T id, int *tabnr, int *winnr)
{
  *tabnr = 0;
  *winnr = 0;

  int tnum = 1;
  int wnum = 1;
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

void win_ui_flush(bool validate)
{
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (wp->w_pos_changed && wp->w_grid_alloc.chars != NULL) {
      if (tp == curtab) {
        ui_ext_win_position(wp, validate);
      } else {
        ui_call_win_hide(wp->w_grid_alloc.handle);
        wp->w_pos_changed = false;
      }
    }
    if (tp == curtab) {
      ui_ext_win_viewport(wp);
    }
  }
}

win_T *lastwin_nofloating(void)
{
  win_T *res = lastwin;
  while (res->w_floating) {
    res = res->w_prev;
  }
  return res;
}
