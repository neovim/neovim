// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// screen.c: Lower level code for displaying on the screen.
//           grid.c contains some other lower-level code.

// Output to the screen (console, terminal emulator or GUI window) is minimized
// by remembering what is already on the screen, and only updating the parts
// that changed.

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/mbyte.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/option.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/pos.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/statusline.h"
#include "nvim/strings.h"
#include "nvim/types.h"
#include "nvim/ui.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "screen.c.generated.h"
#endif

static char e_conflicts_with_value_of_listchars[] = N_("E834: Conflicts with value of 'listchars'");
static char e_conflicts_with_value_of_fillchars[] = N_("E835: Conflicts with value of 'fillchars'");

/// Return true if the cursor line in window "wp" may be concealed, according
/// to the 'concealcursor' option.
bool conceal_cursor_line(const win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  int c;

  if (*wp->w_p_cocu == NUL) {
    return false;
  }
  if (get_real_state() & MODE_VISUAL) {
    c = 'v';
  } else if (State & MODE_INSERT) {
    c = 'i';
  } else if (State & MODE_NORMAL) {
    c = 'n';
  } else if (State & MODE_CMDLINE) {
    c = 'c';
  } else {
    return false;
  }
  return vim_strchr(wp->w_p_cocu, c) != NULL;
}

/// Whether cursorline is drawn in a special way
///
/// If true, both old and new cursorline will need to be redrawn when moving cursor within windows.
bool win_cursorline_standout(const win_T *wp)
  FUNC_ATTR_NONNULL_ALL
{
  return wp->w_p_cul || (wp->w_p_cole > 0 && !conceal_cursor_line(wp));
}

/// Returns width of the signcolumn that should be used for the whole window
///
/// @param wp window we want signcolumn width from
/// @return max width of signcolumn (cell unit)
///
/// @note Returns a constant for now but hopefully we can improve neovim so that
///       the returned value width adapts to the maximum number of marks to draw
///       for the window
/// TODO(teto)
int win_signcol_width(win_T *wp)
{
  // 2 is vim default value
  return 2;
}

/// Call grid_fill() with columns adjusted for 'rightleft' if needed.
/// Return the new offset.
static int win_fill_end(win_T *wp, int c1, int c2, int off, int width, int row, int endrow,
                        int attr)
{
  int nn = off + width;

  if (nn > wp->w_grid.cols) {
    nn = wp->w_grid.cols;
  }

  if (wp->w_p_rl) {
    grid_fill(&wp->w_grid, row, endrow, W_ENDCOL(wp) - nn, W_ENDCOL(wp) - off,
              c1, c2, attr);
  } else {
    grid_fill(&wp->w_grid, row, endrow, off, nn, c1, c2, attr);
  }

  return nn;
}

/// Clear lines near the end of the window and mark the unused lines with "c1".
/// Use "c2" as filler character.
/// When "draw_margin" is true, then draw the sign/fold/number columns.
void win_draw_end(win_T *wp, int c1, int c2, bool draw_margin, int row, int endrow, hlf_T hl)
{
  assert(hl >= 0 && hl < HLF_COUNT);
  int n = 0;

  if (draw_margin) {
    // draw the fold column
    int fdc = compute_foldcolumn(wp, 0);
    if (fdc > 0) {
      n = win_fill_end(wp, ' ', ' ', n, fdc, row, endrow,
                       win_hl_attr(wp, HLF_FC));
    }
    // draw the sign column
    int count = wp->w_scwidth;
    if (count > 0) {
      n = win_fill_end(wp, ' ', ' ', n, win_signcol_width(wp) * count, row,
                       endrow, win_hl_attr(wp, HLF_SC));
    }
    // draw the number column
    if ((wp->w_p_nu || wp->w_p_rnu) && vim_strchr(p_cpo, CPO_NUMCOL) == NULL) {
      n = win_fill_end(wp, ' ', ' ', n, number_width(wp) + 1, row, endrow,
                       win_hl_attr(wp, HLF_N));
    }
  }

  int attr = hl_combine_attr(win_bg_attr(wp), win_hl_attr(wp, (int)hl));

  if (wp->w_p_rl) {
    grid_fill(&wp->w_grid, row, endrow, wp->w_wincol, W_ENDCOL(wp) - 1 - n,
              c2, c2, attr);
    grid_fill(&wp->w_grid, row, endrow, W_ENDCOL(wp) - 1 - n, W_ENDCOL(wp) - n,
              c1, c2, attr);
  } else {
    grid_fill(&wp->w_grid, row, endrow, n, wp->w_grid.cols, c1, c2, attr);
  }
}

/// Compute the width of the foldcolumn.  Based on 'foldcolumn' and how much
/// space is available for window "wp", minus "col".
int compute_foldcolumn(win_T *wp, int col)
{
  int fdc = win_fdccol_count(wp);
  int wmw = wp == curwin && p_wmw == 0 ? 1 : (int)p_wmw;
  int wwidth = wp->w_grid.cols;

  if (fdc > wwidth - (col + wmw)) {
    fdc = wwidth - (col + wmw);
  }
  return fdc;
}

/// Fills the foldcolumn at "p" for window "wp".
/// Only to be called when 'foldcolumn' > 0.
///
/// @param[out] p  Char array to write into
/// @param lnum    Absolute current line number
/// @param closed  Whether it is in 'foldcolumn' mode
///
/// Assume monocell characters
/// @return number of chars added to \param p
size_t fill_foldcolumn(char *p, win_T *wp, foldinfo_T foldinfo, linenr_T lnum)
{
  int i = 0;
  int level;
  int first_level;
  int fdc = compute_foldcolumn(wp, 0);    // available cell width
  size_t char_counter = 0;
  int symbol = 0;
  int len = 0;
  bool closed = foldinfo.fi_lines > 0;
  // Init to all spaces.
  memset(p, ' ', MAX_MCO * (size_t)fdc + 1);

  level = foldinfo.fi_level;

  // If the column is too narrow, we start at the lowest level that
  // fits and use numbers to indicate the depth.
  first_level = level - fdc - closed + 1;
  if (first_level < 1) {
    first_level = 1;
  }

  for (i = 0; i < MIN(fdc, level); i++) {
    if (foldinfo.fi_lnum == lnum
        && first_level + i >= foldinfo.fi_low_level) {
      symbol = wp->w_p_fcs_chars.foldopen;
    } else if (first_level == 1) {
      symbol = wp->w_p_fcs_chars.foldsep;
    } else if (first_level + i <= 9) {
      symbol = '0' + first_level + i;
    } else {
      symbol = '>';
    }

    len = utf_char2bytes(symbol, &p[char_counter]);
    char_counter += (size_t)len;
    if (first_level + i >= level) {
      i++;
      break;
    }
  }

  if (closed) {
    if (symbol != 0) {
      // rollback previous write
      char_counter -= (size_t)len;
      memset(&p[char_counter], ' ', (size_t)len);
    }
    len = utf_char2bytes(wp->w_p_fcs_chars.foldclosed, &p[char_counter]);
    char_counter += (size_t)len;
  }

  return MAX(char_counter + (size_t)(fdc - i), (size_t)fdc);
}

/// Mirror text "str" for right-left displaying.
/// Only works for single-byte characters (e.g., numbers).
void rl_mirror(char *str)
{
  char *p1, *p2;
  char t;

  for (p1 = str, p2 = str + strlen(str) - 1; p1 < p2; p1++, p2--) {
    t = *p1;
    *p1 = *p2;
    *p2 = t;
  }
}

/// Only call if (wp->w_vsep_width != 0).
///
/// @return  true if the status line of window "wp" is connected to the status
/// line of the window right of it.  If not, then it's a vertical separator.
bool stl_connected(win_T *wp)
{
  frame_T *fr;

  fr = wp->w_frame;
  while (fr->fr_parent != NULL) {
    if (fr->fr_parent->fr_layout == FR_COL) {
      if (fr->fr_next != NULL) {
        break;
      }
    } else {
      if (fr->fr_next != NULL) {
        return true;
      }
    }
    fr = fr->fr_parent;
  }
  return false;
}

/// Get the value to show for the language mappings, active 'keymap'.
///
/// @param fmt  format string containing one %s item
/// @param buf  buffer for the result
/// @param len  length of buffer
bool get_keymap_str(win_T *wp, char *fmt, char *buf, int len)
{
  char *p;

  if (wp->w_buffer->b_p_iminsert != B_IMODE_LMAP) {
    return false;
  }

  {
    buf_T *old_curbuf = curbuf;
    win_T *old_curwin = curwin;
    char *s;

    curbuf = wp->w_buffer;
    curwin = wp;
    STRCPY(buf, "b:keymap_name");       // must be writable
    emsg_skip++;
    s = p = eval_to_string(buf, NULL, false);
    emsg_skip--;
    curbuf = old_curbuf;
    curwin = old_curwin;
    if (p == NULL || *p == NUL) {
      if (wp->w_buffer->b_kmap_state & KEYMAP_LOADED) {
        p = wp->w_buffer->b_p_keymap;
      } else {
        p = "lang";
      }
    }
    if (vim_snprintf(buf, (size_t)len, fmt, p) > len - 1) {
      buf[0] = NUL;
    }
    xfree(s);
  }
  return buf[0] != NUL;
}

/// Prepare for 'hlsearch' highlighting.
void start_search_hl(void)
{
  if (p_hls && !no_hlsearch) {
    end_search_hl();  // just in case it wasn't called before
    last_pat_prog(&screen_search_hl.rm);
    // Set the time limit to 'redrawtime'.
    screen_search_hl.tm = profile_setlimit(p_rdt);
  }
}

/// Clean up for 'hlsearch' highlighting.
void end_search_hl(void)
{
  if (screen_search_hl.rm.regprog != NULL) {
    vim_regfree(screen_search_hl.rm.regprog);
    screen_search_hl.rm.regprog = NULL;
  }
}

/// Check if there should be a delay.  Used before clearing or redrawing the
/// screen or the command line.
void check_for_delay(bool check_msg_scroll)
{
  if ((emsg_on_display || (check_msg_scroll && msg_scroll))
      && !did_wait_return
      && emsg_silent == 0
      && !in_assert_fails) {
    ui_flush();
    os_delay(1006L, true);
    emsg_on_display = false;
    if (check_msg_scroll) {
      msg_scroll = false;
    }
  }
}

/// Set cursor to its position in the current window.
void setcursor(void)
{
  setcursor_mayforce(false);
}

/// Set cursor to its position in the current window.
/// @param force  when true, also when not redrawing.
void setcursor_mayforce(bool force)
{
  if (force || redrawing()) {
    validate_cursor();

    ScreenGrid *grid = &curwin->w_grid;
    int row = curwin->w_wrow;
    int col = curwin->w_wcol;
    if (curwin->w_p_rl) {
      // With 'rightleft' set and the cursor on a double-wide character,
      // position it on the leftmost column.
      col = curwin->w_width_inner - curwin->w_wcol
            - ((utf_ptr2cells(get_cursor_pos_ptr()) == 2
                && vim_isprintc(gchar_cursor())) ? 2 : 1);
    }

    grid_adjust(&grid, &row, &col);
    ui_grid_cursor_goto(grid->handle, row, col);
  }
}

/// Scroll `line_count` lines at 'row' in window 'wp'.
///
/// Positive `line_count` means scrolling down, so that more space is available
/// at 'row'. Negative `line_count` implies deleting lines at `row`.
void win_scroll_lines(win_T *wp, int row, int line_count)
{
  if (!redrawing() || line_count == 0) {
    return;
  }

  // No lines are being moved, just draw over the entire area
  if (row + abs(line_count) >= wp->w_grid.rows) {
    return;
  }

  if (line_count < 0) {
    grid_del_lines(&wp->w_grid, row, -line_count,
                   wp->w_grid.rows, 0, wp->w_grid.cols);
  } else {
    grid_ins_lines(&wp->w_grid, row, line_count,
                   wp->w_grid.rows, 0, wp->w_grid.cols);
  }
}

/// @return true when postponing displaying the mode message: when not redrawing
/// or inside a mapping.
bool skip_showmode(void)
{
  // Call char_avail() only when we are going to show something, because it
  // takes a bit of time.  redrawing() may also call char_avail().
  if (global_busy || msg_silent != 0 || !redrawing() || (char_avail() && !KeyTyped)) {
    redraw_mode = true;  // show mode later
    return true;
  }
  return false;
}

/// Show the current mode and ruler.
///
/// If clear_cmdline is true, clear the rest of the cmdline.
/// If clear_cmdline is false there may be a message there that needs to be
/// cleared only if a mode is shown.
/// If redraw_mode is true show or clear the mode.
/// @return the length of the message (0 if no message).
int showmode(void)
{
  bool need_clear;
  int length = 0;
  int do_mode;
  int attr;
  int sub_attr;

  if (ui_has(kUIMessages) && clear_cmdline) {
    msg_ext_clear(true);
  }

  // don't make non-flushed message part of the showmode
  msg_ext_ui_flush();

  msg_grid_validate();

  do_mode = ((p_smd && msg_silent == 0)
             && ((State & MODE_TERMINAL)
                 || (State & MODE_INSERT)
                 || restart_edit != NUL
                 || VIsual_active));
  if (do_mode || reg_recording != 0) {
    if (skip_showmode()) {
      return 0;  // show mode later
    }

    bool nwr_save = need_wait_return;

    // wait a bit before overwriting an important message
    check_for_delay(false);

    // if the cmdline is more than one line high, erase top lines
    need_clear = clear_cmdline;
    if (clear_cmdline && cmdline_row < Rows - 1) {
      msg_clr_cmdline();  // will reset clear_cmdline
    }

    // Position on the last line in the window, column 0
    msg_pos_mode();
    attr = HL_ATTR(HLF_CM);                     // Highlight mode

    // When the screen is too narrow to show the entire mode message,
    // avoid scrolling and truncate instead.
    msg_no_more = true;
    int save_lines_left = lines_left;
    lines_left = 0;

    if (do_mode) {
      msg_puts_attr("--", attr);
      // CTRL-X in Insert mode
      if (edit_submode != NULL && !shortmess(SHM_COMPLETIONMENU)) {
        // These messages can get long, avoid a wrap in a narrow window.
        // Prefer showing edit_submode_extra. With external messages there
        // is no imposed limit.
        if (ui_has(kUIMessages)) {
          length = INT_MAX;
        } else {
          length = (Rows - msg_row) * Columns - 3;
        }
        if (edit_submode_extra != NULL) {
          length -= vim_strsize(edit_submode_extra);
        }
        if (length > 0) {
          if (edit_submode_pre != NULL) {
            length -= vim_strsize(edit_submode_pre);
          }
          if (length - vim_strsize(edit_submode) > 0) {
            if (edit_submode_pre != NULL) {
              msg_puts_attr((const char *)edit_submode_pre, attr);
            }
            msg_puts_attr((const char *)edit_submode, attr);
          }
          if (edit_submode_extra != NULL) {
            msg_puts_attr(" ", attr);  // Add a space in between.
            if ((int)edit_submode_highl < HLF_COUNT) {
              sub_attr = win_hl_attr(curwin, (int)edit_submode_highl);
            } else {
              sub_attr = attr;
            }
            msg_puts_attr((const char *)edit_submode_extra, sub_attr);
          }
        }
      } else {
        if (State & MODE_TERMINAL) {
          msg_puts_attr(_(" TERMINAL"), attr);
        } else if (State & VREPLACE_FLAG) {
          msg_puts_attr(_(" VREPLACE"), attr);
        } else if (State & REPLACE_FLAG) {
          msg_puts_attr(_(" REPLACE"), attr);
        } else if (State & MODE_INSERT) {
          if (p_ri) {
            msg_puts_attr(_(" REVERSE"), attr);
          }
          msg_puts_attr(_(" INSERT"), attr);
        } else if (restart_edit == 'I' || restart_edit == 'i'
                   || restart_edit == 'a' || restart_edit == 'A') {
          if (curbuf->terminal) {
            msg_puts_attr(_(" (terminal)"), attr);
          } else {
            msg_puts_attr(_(" (insert)"), attr);
          }
        } else if (restart_edit == 'R') {
          msg_puts_attr(_(" (replace)"), attr);
        } else if (restart_edit == 'V') {
          msg_puts_attr(_(" (vreplace)"), attr);
        }
        if (p_hkmap) {
          msg_puts_attr(_(" Hebrew"), attr);
        }
        if (State & MODE_LANGMAP) {
          if (curwin->w_p_arab) {
            msg_puts_attr(_(" Arabic"), attr);
          } else if (get_keymap_str(curwin, " (%s)",
                                    NameBuff, MAXPATHL)) {
            msg_puts_attr(NameBuff, attr);
          }
        }
        if ((State & MODE_INSERT) && p_paste) {
          msg_puts_attr(_(" (paste)"), attr);
        }

        if (VIsual_active) {
          char *p;

          // Don't concatenate separate words to avoid translation
          // problems.
          switch ((VIsual_select ? 4 : 0)
                  + (VIsual_mode == Ctrl_V) * 2
                  + (VIsual_mode == 'V')) {
          case 0:
            p = N_(" VISUAL"); break;
          case 1:
            p = N_(" VISUAL LINE"); break;
          case 2:
            p = N_(" VISUAL BLOCK"); break;
          case 4:
            p = N_(" SELECT"); break;
          case 5:
            p = N_(" SELECT LINE"); break;
          default:
            p = N_(" SELECT BLOCK"); break;
          }
          msg_puts_attr(_(p), attr);
        }
        msg_puts_attr(" --", attr);
      }

      need_clear = true;
    }
    if (reg_recording != 0
        && edit_submode == NULL             // otherwise it gets too long
        ) {
      recording_mode(attr);
      need_clear = true;
    }

    mode_displayed = true;
    if (need_clear || clear_cmdline || redraw_mode) {
      msg_clr_eos();
    }
    msg_didout = false;                 // overwrite this message
    length = msg_col;
    msg_col = 0;
    msg_no_more = false;
    lines_left = save_lines_left;
    need_wait_return = nwr_save;        // never ask for hit-return for this
  } else if (clear_cmdline && msg_silent == 0) {
    // Clear the whole command line.  Will reset "clear_cmdline".
    msg_clr_cmdline();
  } else if (redraw_mode) {
    msg_pos_mode();
    msg_clr_eos();
  }

  // NB: also handles clearing the showmode if it was empty or disabled
  msg_ext_flush_showmode();

  // In Visual mode the size of the selected area must be redrawn.
  if (VIsual_active) {
    clear_showcmd();
  }

  // If the last window has no status line and global statusline is disabled,
  // the ruler is after the mode message and must be redrawn
  win_T *last = lastwin_nofloating();
  if (redrawing() && last->w_status_height == 0 && global_stl_height() == 0) {
    win_redr_ruler(last, true);
  }

  redraw_cmdline = false;
  redraw_mode = false;
  clear_cmdline = false;

  return length;
}

/// Position for a mode message.
static void msg_pos_mode(void)
{
  msg_col = 0;
  msg_row = Rows - 1;
}

/// Delete mode message.  Used when ESC is typed which is expected to end
/// Insert mode (but Insert mode didn't end yet!).
/// Caller should check "mode_displayed".
void unshowmode(bool force)
{
  // Don't delete it right now, when not redrawing or inside a mapping.
  if (!redrawing() || (!force && char_avail() && !KeyTyped)) {
    redraw_cmdline = true;  // delete mode later
  } else {
    clearmode();
  }
}

// Clear the mode message.
void clearmode(void)
{
  const int save_msg_row = msg_row;
  const int save_msg_col = msg_col;

  msg_ext_ui_flush();
  msg_pos_mode();
  if (reg_recording != 0) {
    recording_mode(HL_ATTR(HLF_CM));
  }
  msg_clr_eos();
  msg_ext_flush_showmode();

  msg_col = save_msg_col;
  msg_row = save_msg_row;
}

static void recording_mode(int attr)
{
  msg_puts_attr(_("recording"), attr);
  if (!shortmess(SHM_RECORDING)) {
    char s[4];
    snprintf(s, ARRAY_SIZE(s), " @%c", reg_recording);
    msg_puts_attr(s, attr);
  }
}

void get_trans_bufname(buf_T *buf)
{
  if (buf_spname(buf) != NULL) {
    xstrlcpy(NameBuff, buf_spname(buf), MAXPATHL);
  } else {
    home_replace(buf, buf->b_fname, NameBuff, MAXPATHL, true);
  }
  trans_characters(NameBuff, MAXPATHL);
}

/// Get the character to use in a separator between vertically split windows.
/// Get its attributes in "*attr".
int fillchar_vsep(win_T *wp, int *attr)
{
  *attr = win_hl_attr(wp, HLF_C);
  return wp->w_p_fcs_chars.vert;
}

/// Get the character to use in a separator between horizontally split windows.
/// Get its attributes in "*attr".
int fillchar_hsep(win_T *wp, int *attr)
{
  *attr = win_hl_attr(wp, HLF_C);
  return wp->w_p_fcs_chars.horiz;
}

/// Return true if redrawing should currently be done.
bool redrawing(void)
{
  return !RedrawingDisabled
         && !(p_lz && char_avail() && !KeyTyped && !do_redraw);
}

/// Return true if printing messages should currently be done.
bool messaging(void)
{
  // TODO(bfredl): with general support for "async" messages with p_ch,
  // this should be re-enabled.
  return !(p_lz && char_avail() && !KeyTyped) && (p_ch > 0 || ui_has(kUIMessages));
}

#define COL_RULER 17        // columns needed by standard ruler

/// Compute columns for ruler and shown command. 'sc_col' is also used to
/// decide what the maximum length of a message on the status line can be.
/// If there is a status line for the last window, 'sc_col' is independent
/// of 'ru_col'.
void comp_col(void)
{
  int last_has_status = (p_ls > 1 || (p_ls == 1 && !ONE_WINDOW));

  sc_col = 0;
  ru_col = 0;
  if (p_ru) {
    ru_col = (ru_wid ? ru_wid : COL_RULER) + 1;
    // no last status line, adjust sc_col
    if (!last_has_status) {
      sc_col = ru_col;
    }
  }
  if (p_sc) {
    sc_col += SHOWCMD_COLS;
    if (!p_ru || last_has_status) {         // no need for separating space
      sc_col++;
    }
  }
  assert(sc_col >= 0
         && INT_MIN + sc_col <= Columns);
  sc_col = Columns - sc_col;
  assert(ru_col >= 0
         && INT_MIN + ru_col <= Columns);
  ru_col = Columns - ru_col;
  if (sc_col <= 0) {            // screen too narrow, will become a mess
    sc_col = 1;
  }
  if (ru_col <= 0) {
    ru_col = 1;
  }
  set_vim_var_nr(VV_ECHOSPACE, sc_col - 1);
}

/// Return the width of the 'number' and 'relativenumber' column.
/// Caller may need to check if 'number' or 'relativenumber' is set.
/// Otherwise it depends on 'numberwidth' and the line count.
int number_width(win_T *wp)
{
  int n;
  linenr_T lnum;

  if (wp->w_p_rnu && !wp->w_p_nu) {
    // cursor line shows "0"
    lnum = wp->w_height_inner;
  } else {
    // cursor line shows absolute line number
    lnum = wp->w_buffer->b_ml.ml_line_count;
  }

  if (lnum == wp->w_nrwidth_line_count) {
    return wp->w_nrwidth_width;
  }
  wp->w_nrwidth_line_count = lnum;

  // make best estimate for 'statuscolumn'
  if (*wp->w_p_stc != NUL) {
    char buf[MAXPATHL];
    wp->w_nrwidth_width = 0;
    n = build_statuscol_str(wp, lnum, 0, 0, NUL, buf, NULL, NULL);
    n = MAX(n, (wp->w_p_nu || wp->w_p_rnu) * (int)wp->w_p_nuw);
    wp->w_nrwidth_width = MIN(n, MAX_NUMBERWIDTH);
    return wp->w_nrwidth_width;
  }

  n = 0;
  do {
    lnum /= 10;
    n++;
  } while (lnum > 0);

  // 'numberwidth' gives the minimal width plus one
  if (n < wp->w_p_nuw - 1) {
    n = (int)wp->w_p_nuw - 1;
  }

  // If 'signcolumn' is set to 'number' and there is a sign to display, then
  // the minimal width for the number column is 2.
  if (n < 2 && (wp->w_buffer->b_signlist != NULL)
      && (*wp->w_p_scl == 'n' && *(wp->w_p_scl + 1) == 'u')) {
    n = 2;
  }

  wp->w_nrwidth_width = n;
  return n;
}

/// Calls mb_cptr2char_adv(p) and returns the character.
/// If "p" starts with "\x", "\u" or "\U" the hex or unicode value is used.
/// Returns 0 for invalid hex or invalid UTF-8 byte.
static int get_encoded_char_adv(const char_u **p)
{
  const char *s = (const char *)(*p);

  if (s[0] == '\\' && (s[1] == 'x' || s[1] == 'u' || s[1] == 'U')) {
    int64_t num = 0;
    for (int bytes = s[1] == 'x' ? 1 : s[1] == 'u' ? 2 : 4; bytes > 0; bytes--) {
      *p += 2;
      int n = hexhex2nr((char *)(*p));
      if (n < 0) {
        return 0;
      }
      num = num * 256 + n;
    }
    *p += 2;
    return (int)num;
  }

  // TODO(bfredl): use schar_T representation and utfc_ptr2len
  int clen = utf_ptr2len(s);
  int c = mb_cptr2char_adv(p);
  if (clen == 1 && c > 127) {  // Invalid UTF-8 byte
    return 0;
  }
  return c;
}

/// Handle setting 'listchars' or 'fillchars'.
/// Assume monocell characters
///
/// @param varp   either the global or the window-local value.
/// @param apply  if false, do not store the flags, only check for errors.
/// @return error message, NULL if it's OK.
char *set_chars_option(win_T *wp, char **varp, bool apply)
{
  const char *last_multispace = NULL;   // Last occurrence of "multispace:"
  const char *last_lmultispace = NULL;  // Last occurrence of "leadmultispace:"
  int multispace_len = 0;           // Length of lcs-multispace string
  int lead_multispace_len = 0;      // Length of lcs-leadmultispace string
  const bool is_listchars = (varp == &p_lcs || varp == &wp->w_p_lcs);

  struct chars_tab {
    int *cp;     ///< char value
    char *name;  ///< char id
    int def;     ///< default value
  };

  // XXX: Characters taking 2 columns is forbidden (TUI limitation?). Set old defaults in this case.
  struct chars_tab fcs_tab[] = {
    { &wp->w_p_fcs_chars.stl,        "stl",       ' ' },
    { &wp->w_p_fcs_chars.stlnc,      "stlnc",     ' ' },
    { &wp->w_p_fcs_chars.wbr,        "wbr",       ' ' },
    { &wp->w_p_fcs_chars.horiz,      "horiz",     char2cells(0x2500) == 1 ? 0x2500 : '-' },  // ─
    { &wp->w_p_fcs_chars.horizup,    "horizup",   char2cells(0x2534) == 1 ? 0x2534 : '-' },  // ┴
    { &wp->w_p_fcs_chars.horizdown,  "horizdown", char2cells(0x252c) == 1 ? 0x252c : '-' },  // ┬
    { &wp->w_p_fcs_chars.vert,       "vert",      char2cells(0x2502) == 1 ? 0x2502 : '|' },  // │
    { &wp->w_p_fcs_chars.vertleft,   "vertleft",  char2cells(0x2524) == 1 ? 0x2524 : '|' },  // ┤
    { &wp->w_p_fcs_chars.vertright,  "vertright", char2cells(0x251c) == 1 ? 0x251c : '|' },  // ├
    { &wp->w_p_fcs_chars.verthoriz,  "verthoriz", char2cells(0x253c) == 1 ? 0x253c : '+' },  // ┼
    { &wp->w_p_fcs_chars.fold,       "fold",      char2cells(0x00b7) == 1 ? 0x00b7 : '-' },  // ·
    { &wp->w_p_fcs_chars.foldopen,   "foldopen",  '-' },
    { &wp->w_p_fcs_chars.foldclosed, "foldclose", '+' },
    { &wp->w_p_fcs_chars.foldsep,    "foldsep",   char2cells(0x2502) == 1 ? 0x2502 : '|' },  // │
    { &wp->w_p_fcs_chars.diff,       "diff",      '-' },
    { &wp->w_p_fcs_chars.msgsep,     "msgsep",    ' ' },
    { &wp->w_p_fcs_chars.eob,        "eob",       '~' },
    { &wp->w_p_fcs_chars.lastline,   "lastline",  '@' },
  };

  struct chars_tab lcs_tab[] = {
    { &wp->w_p_lcs_chars.eol,     "eol",      NUL },
    { &wp->w_p_lcs_chars.ext,     "extends",  NUL },
    { &wp->w_p_lcs_chars.nbsp,    "nbsp",     NUL },
    { &wp->w_p_lcs_chars.prec,    "precedes", NUL },
    { &wp->w_p_lcs_chars.space,   "space",    NUL },
    { &wp->w_p_lcs_chars.tab2,    "tab",      NUL },
    { &wp->w_p_lcs_chars.lead,    "lead",     NUL },
    { &wp->w_p_lcs_chars.trail,   "trail",    NUL },
    { &wp->w_p_lcs_chars.conceal, "conceal",  NUL },
  };

  struct chars_tab *tab;
  int entries;
  const char *value = *varp;
  if (is_listchars) {
    tab = lcs_tab;
    entries = ARRAY_SIZE(lcs_tab);
    if (varp == &wp->w_p_lcs && wp->w_p_lcs[0] == NUL) {
      value = p_lcs;  // local value is empty, use the global value
    }
  } else {
    tab = fcs_tab;
    entries = ARRAY_SIZE(fcs_tab);
    if (varp == &wp->w_p_fcs && wp->w_p_fcs[0] == NUL) {
      value = p_fcs;  // local value is empty, use the global value
    }
  }

  // first round: check for valid value, second round: assign values
  for (int round = 0; round <= (apply ? 1 : 0); round++) {
    if (round > 0) {
      // After checking that the value is valid: set defaults
      for (int i = 0; i < entries; i++) {
        if (tab[i].cp != NULL) {
          *(tab[i].cp) = tab[i].def;
        }
      }
      if (is_listchars) {
        wp->w_p_lcs_chars.tab1 = NUL;
        wp->w_p_lcs_chars.tab3 = NUL;

        xfree(wp->w_p_lcs_chars.multispace);
        if (multispace_len > 0) {
          wp->w_p_lcs_chars.multispace = xmalloc(((size_t)multispace_len + 1) * sizeof(int));
          wp->w_p_lcs_chars.multispace[multispace_len] = NUL;
        } else {
          wp->w_p_lcs_chars.multispace = NULL;
        }

        xfree(wp->w_p_lcs_chars.leadmultispace);
        if (lead_multispace_len > 0) {
          wp->w_p_lcs_chars.leadmultispace
            = xmalloc(((size_t)lead_multispace_len + 1) * sizeof(int));
          wp->w_p_lcs_chars.leadmultispace[lead_multispace_len] = NUL;
        } else {
          wp->w_p_lcs_chars.leadmultispace = NULL;
        }
      }
    }
    const char *p = value;
    while (*p) {
      int i;
      for (i = 0; i < entries; i++) {
        const size_t len = strlen(tab[i].name);
        if (strncmp(p, tab[i].name, len) == 0
            && p[len] == ':'
            && p[len + 1] != NUL) {
          const char_u *s = (char_u *)p + len + 1;
          int c1 = get_encoded_char_adv(&s);
          if (c1 == 0 || char2cells(c1) > 1) {
            return e_invarg;
          }
          int c2 = 0, c3 = 0;
          if (tab[i].cp == &wp->w_p_lcs_chars.tab2) {
            if (*s == NUL) {
              return e_invarg;
            }
            c2 = get_encoded_char_adv(&s);
            if (c2 == 0 || char2cells(c2) > 1) {
              return e_invarg;
            }
            if (!(*s == ',' || *s == NUL)) {
              c3 = get_encoded_char_adv(&s);
              if (c3 == 0 || char2cells(c3) > 1) {
                return e_invarg;
              }
            }
          }
          if (*s == ',' || *s == NUL) {
            if (round > 0) {
              if (tab[i].cp == &wp->w_p_lcs_chars.tab2) {
                wp->w_p_lcs_chars.tab1 = c1;
                wp->w_p_lcs_chars.tab2 = c2;
                wp->w_p_lcs_chars.tab3 = c3;
              } else if (tab[i].cp != NULL) {
                *(tab[i].cp) = c1;
              }
            }
            p = (char *)s;
            break;
          }
        }
      }

      if (i == entries) {
        const size_t len = strlen("multispace");
        const size_t len2 = strlen("leadmultispace");
        if (is_listchars
            && strncmp(p, "multispace", len) == 0
            && p[len] == ':'
            && p[len + 1] != NUL) {
          const char_u *s = (char_u *)p + len + 1;
          if (round == 0) {
            // Get length of lcs-multispace string in the first round
            last_multispace = p;
            multispace_len = 0;
            while (*s != NUL && *s != ',') {
              int c1 = get_encoded_char_adv(&s);
              if (c1 == 0 || char2cells(c1) > 1) {
                return e_invarg;
              }
              multispace_len++;
            }
            if (multispace_len == 0) {
              // lcs-multispace cannot be an empty string
              return e_invarg;
            }
            p = (char *)s;
          } else {
            int multispace_pos = 0;
            while (*s != NUL && *s != ',') {
              int c1 = get_encoded_char_adv(&s);
              if (p == last_multispace) {
                wp->w_p_lcs_chars.multispace[multispace_pos++] = c1;
              }
            }
            p = (char *)s;
          }
        } else if (is_listchars
                   && strncmp(p, "leadmultispace", len2) == 0
                   && p[len2] == ':'
                   && p[len2 + 1] != NUL) {
          const char_u *s = (char_u *)p + len2 + 1;
          if (round == 0) {
            // get length of lcs-leadmultispace string in first round
            last_lmultispace = p;
            lead_multispace_len = 0;
            while (*s != NUL && *s != ',') {
              int c1 = get_encoded_char_adv(&s);
              if (c1 == 0 || char2cells(c1) > 1) {
                return e_invarg;
              }
              lead_multispace_len++;
            }
            if (lead_multispace_len == 0) {
              // lcs-leadmultispace cannot be an empty string
              return e_invarg;
            }
            p = (char *)s;
          } else {
            int multispace_pos = 0;
            while (*s != NUL && *s != ',') {
              int c1 = get_encoded_char_adv(&s);
              if (p == last_lmultispace) {
                wp->w_p_lcs_chars.leadmultispace[multispace_pos++] = c1;
              }
            }
            p = (char *)s;
          }
        } else {
          return e_invarg;
        }
      }

      if (*p == ',') {
        p++;
      }
    }
  }

  return NULL;          // no error
}

/// Check all global and local values of 'listchars' and 'fillchars'.
/// May set different defaults in case character widths change.
///
/// @return  an untranslated error message if any of them is invalid, NULL otherwise.
char *check_chars_options(void)
{
  if (set_chars_option(curwin, &p_lcs, false) != NULL) {
    return e_conflicts_with_value_of_listchars;
  }
  if (set_chars_option(curwin, &p_fcs, false) != NULL) {
    return e_conflicts_with_value_of_fillchars;
  }
  FOR_ALL_TAB_WINDOWS(tp, wp) {
    if (set_chars_option(wp, &wp->w_p_lcs, true) != NULL) {
      return e_conflicts_with_value_of_listchars;
    }
    if (set_chars_option(wp, &wp->w_p_fcs, true) != NULL) {
      return e_conflicts_with_value_of_fillchars;
    }
  }
  return NULL;
}

/// Check if the new Nvim application "screen" dimensions are valid.
/// Correct it if it's too small or way too big.
void check_screensize(void)
{
  // Limit Rows and Columns to avoid an overflow in Rows * Columns.
  if (Rows < min_rows()) {
    // need room for one window and command line
    Rows = min_rows();
  } else if (Rows > 1000) {
    Rows = 1000;
  }

  if (Columns < MIN_COLUMNS) {
    Columns = MIN_COLUMNS;
  } else if (Columns > 10000) {
    Columns = 10000;
  }
}
