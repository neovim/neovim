#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/ascii_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_docmd.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/statusline.h"
#include "nvim/statusline_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mouse.c.generated.h"
#endif

static linenr_T orig_topline = 0;
static int orig_topfill = 0;

/// Get class of a character for selection: same class means same word.
/// 0: blank
/// 1: punctuation groups
/// 2: normal word character
/// >2: multi-byte word character.
static int get_mouse_class(char *p)
{
  if (MB_BYTE2LEN((uint8_t)p[0]) > 1) {
    return mb_get_class(p);
  }

  const int c = (uint8_t)(*p);
  if (c == ' ' || c == '\t') {
    return 0;
  }
  if (vim_iswordc(c)) {
    return 2;
  }

  // There are a few special cases where we want certain combinations of
  // characters to be considered as a single word.  These are things like
  // "->", "/ *", "*=", "+=", "&=", "<=", ">=", "!=" etc.  Otherwise, each
  // character is in its own class.
  if (c != NUL && vim_strchr("-+*/%<>&|^!=", c) != NULL) {
    return 1;
  }
  return c;
}

/// Move "pos" back to the start of the word it's in.
static void find_start_of_word(pos_T *pos)
{
  char *line = ml_get(pos->lnum);
  int cclass = get_mouse_class(line + pos->col);

  while (pos->col > 0) {
    int col = pos->col - 1;
    col -= utf_head_off(line, line + col);
    if (get_mouse_class(line + col) != cclass) {
      break;
    }
    pos->col = col;
  }
}

/// Move "pos" forward to the end of the word it's in.
/// When 'selection' is "exclusive", the position is just after the word.
static void find_end_of_word(pos_T *pos)
{
  char *line = ml_get(pos->lnum);
  if (*p_sel == 'e' && pos->col > 0) {
    pos->col--;
    pos->col -= utf_head_off(line, line + pos->col);
  }
  int cclass = get_mouse_class(line + pos->col);
  while (line[pos->col] != NUL) {
    int col = pos->col + utfc_ptr2len(line + pos->col);
    if (get_mouse_class(line + col) != cclass) {
      if (*p_sel == 'e') {
        pos->col = col;
      }
      break;
    }
    pos->col = col;
  }
}

/// Move the current tab to tab in same column as mouse or to end of the
/// tabline if there is no tab there.
static void move_tab_to_mouse(void)
{
  int tabnr = tab_page_click_defs[mouse_col].tabnr;
  if (tabnr <= 0) {
    tabpage_move(9999);
  } else if (tabnr < tabpage_index(curtab)) {
    tabpage_move(tabnr - 1);
  } else {
    tabpage_move(tabnr);
  }
}
/// Close the current or specified tab page.
///
/// @param c1  tabpage number, or 999 for the current tabpage
static void mouse_tab_close(int c1)
{
  tabpage_T *tp;

  if (c1 == 999) {
    tp = curtab;
  } else {
    tp = find_tabpage(c1);
  }
  if (tp == curtab) {
    if (first_tabpage->tp_next != NULL) {
      tabpage_close(false);
    }
  } else if (tp != NULL) {
    tabpage_close_other(tp, false);
  }
}

static bool got_click = false;  // got a click some time back

/// Call click definition function for column "col" in the "click_defs" array for button
/// "which_button".
static void call_click_def_func(StlClickDefinition *click_defs, int col, int which_button)
{
  typval_T argv[] = {
    {
      .v_lock = VAR_FIXED,
      .v_type = VAR_NUMBER,
      .vval = {
        .v_number = (varnumber_T)click_defs[col].tabnr
      },
    },
    {
      .v_lock = VAR_FIXED,
      .v_type = VAR_NUMBER,
      .vval = {
        .v_number = ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_4CLICK
                     ? 4
                     : ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_3CLICK
                        ? 3
                        : ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK
                           ? 2
                           : 1)))
      },
    },
    {
      .v_lock = VAR_FIXED,
      .v_type = VAR_STRING,
      .vval = {
        .v_string = (which_button == MOUSE_LEFT
                     ? "l"
                     : (which_button == MOUSE_RIGHT
                        ? "r"
                        : (which_button == MOUSE_MIDDLE
                           ? "m"
                           : "?")))
      },
    },
    {
      .v_lock = VAR_FIXED,
      .v_type = VAR_STRING,
      .vval = {
        .v_string = (char[]) {
          (char)(mod_mask & MOD_MASK_SHIFT ? 's' : ' '),
          (char)(mod_mask & MOD_MASK_CTRL ? 'c' : ' '),
          (char)(mod_mask & MOD_MASK_ALT ? 'a' : ' '),
          (char)(mod_mask & MOD_MASK_META ? 'm' : ' '),
          NUL
        }
      },
    }
  };
  typval_T rettv;
  call_vim_function(click_defs[col].func, ARRAY_SIZE(argv), argv, &rettv);
  tv_clear(&rettv);
  // Make sure next click does not register as drag when callback absorbs the release event.
  got_click = false;
}

/// Translate window coordinates to buffer position without any side effects.
/// Returns IN_BUFFER and sets "mpos->col" to the column when in buffer text.
/// The column is one for the first column.
static int get_fpos_of_mouse(pos_T *mpos)
{
  int grid = mouse_grid;
  int row = mouse_row;
  int col = mouse_col;

  if (row < 0 || col < 0) {  // check if it makes sense
    return IN_UNKNOWN;
  }

  // find the window where the row is in
  win_T *wp = mouse_find_win(&grid, &row, &col);
  if (wp == NULL) {
    return IN_UNKNOWN;
  }
  int winrow = row;
  int wincol = col;

  // compute the position in the buffer line from the posn on the screen
  bool below_buffer = mouse_comp_pos(wp, &row, &col, &mpos->lnum);

  if (!below_buffer && *wp->w_p_stc != NUL
      && (wp->w_p_rl
          ? wincol >= wp->w_width_inner - win_col_off(wp)
          : wincol < win_col_off(wp))) {
    return MOUSE_STATUSCOL;
  }

  // winpos and height may change in win_enter()!
  if (winrow >= wp->w_height_inner) {  // In (or below) status line
    return IN_STATUS_LINE;
  }

  if (winrow < 0 && winrow + wp->w_winbar_height >= 0) {
    return MOUSE_WINBAR;
  }

  if (wincol >= wp->w_width_inner) {  // In vertical separator line
    return IN_SEP_LINE;
  }

  if (wp != curwin || below_buffer) {
    return IN_UNKNOWN;
  }

  mpos->col = vcol2col(wp, mpos->lnum, col, &mpos->coladd);
  return IN_BUFFER;
}

/// Do the appropriate action for the current mouse click in the current mode.
/// Not used for Command-line mode.
///
/// Normal and Visual Mode:
/// event         modi-  position      visual       change   action
///               fier   cursor                     window
/// left press     -     yes         end             yes
/// left press     C     yes         end             yes     "^]" (2)
/// left press     S     yes     end (popup: extend) yes     "*" (2)
/// left drag      -     yes     start if moved      no
/// left relse     -     yes     start if moved      no
/// middle press   -     yes      if not active      no      put register
/// middle press   -     yes      if active          no      yank and put
/// right press    -     yes     start or extend     yes
/// right press    S     yes     no change           yes     "#" (2)
/// right drag     -     yes     extend              no
/// right relse    -     yes     extend              no
///
/// Insert or Replace Mode:
/// event         modi-  position      visual       change   action
///               fier   cursor                     window
/// left press     -     yes     (cannot be active)  yes
/// left press     C     yes     (cannot be active)  yes     "CTRL-O^]" (2)
/// left press     S     yes     (cannot be active)  yes     "CTRL-O*" (2)
/// left drag      -     yes     start or extend (1) no      CTRL-O (1)
/// left relse     -     yes     start or extend (1) no      CTRL-O (1)
/// middle press   -     no      (cannot be active)  no      put register
/// right press    -     yes     start or extend     yes     CTRL-O
/// right press    S     yes     (cannot be active)  yes     "CTRL-O#" (2)
///
/// (1) only if mouse pointer moved since press
/// (2) only if click is in same buffer
///
/// @param oap        operator argument, can be NULL
/// @param c          K_LEFTMOUSE, etc
/// @param dir        Direction to 'put' if necessary
/// @param fixindent  PUT_FIXINDENT if fixing indent necessary
///
/// @return           true if start_arrow() should be called for edit mode.
bool do_mouse(oparg_T *oap, int c, int dir, int count, bool fixindent)
{
  int which_button;             // MOUSE_LEFT, _MIDDLE or _RIGHT
  bool is_click;                // If false it's a drag or release event
  bool is_drag;                 // If true it's a drag event
  int jump_flags = 0;           // flags for jump_to_mouse()
  pos_T start_visual;
  bool moved;                   // Has cursor moved?
  bool in_winbar;               // mouse in window bar
  bool in_statuscol;            // mouse in status column
  bool in_status_line;          // mouse in status line
  static bool in_tab_line = false;   // mouse clicked in tab line
  bool in_sep_line;             // mouse in vertical separator line
  int c1;
  win_T *old_curwin = curwin;
  static pos_T orig_cursor;
  colnr_T leftcol, rightcol;
  pos_T end_visual;
  int old_active = VIsual_active;
  int old_mode = VIsual_mode;
  int regname;

  pos_T save_cursor = curwin->w_cursor;

  while (true) {
    which_button = get_mouse_button(KEY2TERMCAP1(c), &is_click, &is_drag);
    if (is_drag) {
      // If the next character is the same mouse event then use that
      // one. Speeds up dragging the status line.
      // Note: Since characters added to the stuff buffer in the code
      // below need to come before the next character, do not do this
      // when the current character was stuffed.
      if (!KeyStuffed && vpeekc() != NUL) {
        int nc;
        int save_mouse_grid = mouse_grid;
        int save_mouse_row = mouse_row;
        int save_mouse_col = mouse_col;

        // Need to get the character, peeking doesn't get the actual one.
        nc = safe_vgetc();
        if (c == nc) {
          continue;
        }
        vungetc(nc);
        mouse_grid = save_mouse_grid;
        mouse_row = save_mouse_row;
        mouse_col = save_mouse_col;
      }
    }
    break;
  }

  if (c == K_MOUSEMOVE) {
    // Mouse moved without a button pressed.
    return false;
  }

  // Ignore drag and release events if we didn't get a click.
  if (is_click) {
    got_click = true;
  } else {
    if (!got_click) {                   // didn't get click, ignore
      return false;
    }
    if (!is_drag) {                     // release, reset got_click
      got_click = false;
      if (in_tab_line) {
        in_tab_line = false;
        return false;
      }
    }
  }

  // CTRL right mouse button does CTRL-T
  if (is_click && (mod_mask & MOD_MASK_CTRL) && which_button == MOUSE_RIGHT) {
    if (State & MODE_INSERT) {
      stuffcharReadbuff(Ctrl_O);
    }
    if (count > 1) {
      stuffnumReadbuff(count);
    }
    stuffcharReadbuff(Ctrl_T);
    got_click = false;            // ignore drag&release now
    return false;
  }

  // CTRL only works with left mouse button
  if ((mod_mask & MOD_MASK_CTRL) && which_button != MOUSE_LEFT) {
    return false;
  }

  // When a modifier is down, ignore drag and release events, as well as
  // multiple clicks and the middle mouse button.
  // Accept shift-leftmouse drags when 'mousemodel' is "popup.*".
  if ((mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL | MOD_MASK_ALT
                   | MOD_MASK_META))
      && (!is_click
          || (mod_mask & MOD_MASK_MULTI_CLICK)
          || which_button == MOUSE_MIDDLE)
      && !((mod_mask & (MOD_MASK_SHIFT|MOD_MASK_ALT))
           && mouse_model_popup()
           && which_button == MOUSE_LEFT)
      && !((mod_mask & MOD_MASK_ALT)
           && !mouse_model_popup()
           && which_button == MOUSE_RIGHT)) {
    return false;
  }

  // If the button press was used as the movement command for an operator (eg
  // "d<MOUSE>"), or it is the middle button that is held down, ignore
  // drag/release events.
  if (!is_click && which_button == MOUSE_MIDDLE) {
    return false;
  }

  if (oap != NULL) {
    regname = oap->regname;
  } else {
    regname = 0;
  }

  // Middle mouse button does a 'put' of the selected text
  if (which_button == MOUSE_MIDDLE) {
    if (State == MODE_NORMAL) {
      // If an operator was pending, we don't know what the user wanted to do.
      // Go back to normal mode: Clear the operator and beep().
      if (oap != NULL && oap->op_type != OP_NOP) {
        clearopbeep(oap);
        return false;
      }

      // If visual was active, yank the highlighted text and put it
      // before the mouse pointer position.
      // In Select mode replace the highlighted text with the clipboard.
      if (VIsual_active) {
        if (VIsual_select) {
          stuffcharReadbuff(Ctrl_G);
          stuffReadbuff("\"+p");
        } else {
          stuffcharReadbuff('y');
          stuffcharReadbuff(K_MIDDLEMOUSE);
        }
        return false;
      }
      // The rest is below jump_to_mouse()
    } else if ((State & MODE_INSERT) == 0) {
      return false;
    }

    // Middle click in insert mode doesn't move the mouse, just insert the
    // contents of a register.  '.' register is special, can't insert that
    // with do_put().
    // Also paste at the cursor if the current mode isn't in 'mouse' (only
    // happens for the GUI).
    if ((State & MODE_INSERT)) {
      if (regname == '.') {
        insert_reg(regname, true);
      } else {
        if (regname == 0 && eval_has_provider("clipboard", false)) {
          regname = '*';
        }
        if ((State & REPLACE_FLAG) && !yank_register_mline(regname)) {
          insert_reg(regname, true);
        } else {
          do_put(regname, NULL, BACKWARD, 1,
                 (fixindent ? PUT_FIXINDENT : 0) | PUT_CURSEND);

          // Repeat it with CTRL-R CTRL-O r or CTRL-R CTRL-P r
          AppendCharToRedobuff(Ctrl_R);
          AppendCharToRedobuff(fixindent ? Ctrl_P : Ctrl_O);
          AppendCharToRedobuff(regname == 0 ? '"' : regname);
        }
      }
      return false;
    }
  }

  // When dragging or button-up stay in the same window.
  if (!is_click) {
    jump_flags |= MOUSE_FOCUS | MOUSE_DID_MOVE;
  }

  start_visual.lnum = 0;

  if (tab_page_click_defs != NULL) {  // only when initialized
    // Check for clicking in the tab page line.
    if (mouse_grid <= 1 && mouse_row == 0 && firstwin->w_winrow > 0) {
      if (is_drag) {
        if (in_tab_line) {
          move_tab_to_mouse();
        }
        return false;
      }

      // click in a tab selects that tab page
      if (is_click && cmdwin_type == 0 && mouse_col < Columns) {
        in_tab_line = true;
        c1 = tab_page_click_defs[mouse_col].tabnr;

        switch (tab_page_click_defs[mouse_col].type) {
        case kStlClickDisabled:
          break;
        case kStlClickTabSwitch:
          if (which_button != MOUSE_MIDDLE) {
            if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK) {
              // double click opens new page
              end_visual_mode();
              tabpage_new();
              tabpage_move(c1 == 0 ? 9999 : c1 - 1);
            } else {
              // Go to specified tab page, or next one if not clicking
              // on a label.
              goto_tabpage(c1);

              // It's like clicking on the status line of a window.
              if (curwin != old_curwin) {
                end_visual_mode();
              }
            }
            break;
          }
          FALLTHROUGH;
        case kStlClickTabClose:
          mouse_tab_close(c1);
          break;
        case kStlClickFuncRun:
          call_click_def_func(tab_page_click_defs, mouse_col, which_button);
          break;
        }
      }
      return true;
    } else if (is_drag && in_tab_line) {
      move_tab_to_mouse();
      return false;
    }
  }

  // When 'mousemodel' is "popup" or "popup_setpos", translate mouse events:
  // right button up   -> pop-up menu
  // shift-left button -> right button
  // alt-left button   -> alt-right button
  if (mouse_model_popup()) {
    pos_T m_pos;
    int m_pos_flag = get_fpos_of_mouse(&m_pos);
    if (m_pos_flag & (IN_STATUS_LINE|MOUSE_WINBAR|MOUSE_STATUSCOL)) {
      goto popupexit;
    }
    if (which_button == MOUSE_RIGHT
        && !(mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL))) {
      if (!is_click) {
        // Ignore right button release events, only shows the popup
        // menu on the button down event.
        return false;
      }
      jump_flags = 0;
      if (strcmp(p_mousem, "popup_setpos") == 0) {
        // First set the cursor position before showing the popup menu.
        if (VIsual_active) {
          // set MOUSE_MAY_STOP_VIS if we are outside the selection
          // or the current window (might have false negative here)
          if (m_pos_flag != IN_BUFFER) {
            jump_flags = MOUSE_MAY_STOP_VIS;
          } else {
            if (VIsual_mode == 'V') {
              if ((curwin->w_cursor.lnum <= VIsual.lnum
                   && (m_pos.lnum < curwin->w_cursor.lnum || VIsual.lnum < m_pos.lnum))
                  || (VIsual.lnum < curwin->w_cursor.lnum
                      && (m_pos.lnum < VIsual.lnum || curwin->w_cursor.lnum < m_pos.lnum))) {
                jump_flags = MOUSE_MAY_STOP_VIS;
              }
            } else if ((ltoreq(curwin->w_cursor, VIsual)
                        && (lt(m_pos, curwin->w_cursor) || lt(VIsual, m_pos)))
                       || (lt(VIsual, curwin->w_cursor)
                           && (lt(m_pos, VIsual) || lt(curwin->w_cursor, m_pos)))) {
              jump_flags = MOUSE_MAY_STOP_VIS;
            } else if (VIsual_mode == Ctrl_V) {
              getvcols(curwin, &curwin->w_cursor, &VIsual, &leftcol, &rightcol);
              getvcol(curwin, &m_pos, NULL, &m_pos.col, NULL);
              if (m_pos.col < leftcol || m_pos.col > rightcol) {
                jump_flags = MOUSE_MAY_STOP_VIS;
              }
            }
          }
        } else {
          jump_flags = MOUSE_MAY_STOP_VIS;
        }
      }
      if (jump_flags) {
        jump_flags = jump_to_mouse(jump_flags, NULL, which_button);
        redraw_curbuf_later(VIsual_active ? UPD_INVERTED : UPD_VALID);
        update_screen();
        setcursor();
        ui_flush();  // Update before showing popup menu
      }
      show_popupmenu();
      got_click = false;  // ignore release events
      return (jump_flags & CURSOR_MOVED) != 0;
    }
    if (which_button == MOUSE_LEFT
        && (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_ALT))) {
      which_button = MOUSE_RIGHT;
      mod_mask &= ~MOD_MASK_SHIFT;
    }
  }
popupexit:

  if ((State & (MODE_NORMAL | MODE_INSERT))
      && !(mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL))) {
    if (which_button == MOUSE_LEFT) {
      if (is_click) {
        // stop Visual mode for a left click in a window, but not when on a status line
        if (VIsual_active) {
          jump_flags |= MOUSE_MAY_STOP_VIS;
        }
      } else {
        jump_flags |= MOUSE_MAY_VIS;
      }
    } else if (which_button == MOUSE_RIGHT) {
      if (is_click && VIsual_active) {
        // Remember the start and end of visual before moving the cursor.
        if (lt(curwin->w_cursor, VIsual)) {
          start_visual = curwin->w_cursor;
          end_visual = VIsual;
        } else {
          start_visual = VIsual;
          end_visual = curwin->w_cursor;
        }
      }
      jump_flags |= MOUSE_FOCUS;
      jump_flags |= MOUSE_MAY_VIS;
    }
  }

  // If an operator is pending, ignore all drags and releases until the next mouse click.
  if (!is_drag && oap != NULL && oap->op_type != OP_NOP) {
    got_click = false;
    oap->motion_type = kMTCharWise;
  }

  // When releasing the button let jump_to_mouse() know.
  if (!is_click && !is_drag) {
    jump_flags |= MOUSE_RELEASED;
  }

  // JUMP!
  jump_flags = jump_to_mouse(jump_flags,
                             oap == NULL ? NULL : &(oap->inclusive),
                             which_button);

  moved = (jump_flags & CURSOR_MOVED);
  in_winbar = (jump_flags & MOUSE_WINBAR);
  in_statuscol = (jump_flags & MOUSE_STATUSCOL);
  in_status_line = (jump_flags & IN_STATUS_LINE);
  in_sep_line = (jump_flags & IN_SEP_LINE);

  if ((in_winbar || in_status_line || in_statuscol) && is_click) {
    // Handle click event on window bar, status line or status column
    int click_grid = mouse_grid;
    int click_row = mouse_row;
    int click_col = mouse_col;
    win_T *wp = mouse_find_win(&click_grid, &click_row, &click_col);
    if (wp == NULL) {
      return false;
    }

    StlClickDefinition *click_defs = in_status_line ? wp->w_status_click_defs
                                                    : in_winbar ? wp->w_winbar_click_defs
                                                                : wp->w_statuscol_click_defs;

    if (in_status_line && global_stl_height() > 0) {
      // global statusline is displayed for the current window,
      // and spans the whole screen.
      click_defs = curwin->w_status_click_defs;
      click_col = mouse_col;
    }

    if (in_statuscol && wp->w_p_rl) {
      click_col = wp->w_width_inner - click_col - 1;
    }

    if (click_defs != NULL) {
      switch (click_defs[click_col].type) {
      case kStlClickDisabled:
        break;
      case kStlClickFuncRun:
        call_click_def_func(click_defs, click_col, which_button);
        break;
      default:
        assert(false && "winbar, statusline and statuscolumn only support %@ for clicks");
        break;
      }
    }

    return false;
  } else if (in_winbar || in_statuscol) {
    // A drag or release event in the window bar and status column has no side effects.
    return false;
  }

  // When jumping to another window, clear a pending operator.  That's a bit
  // friendlier than beeping and not jumping to that window.
  if (curwin != old_curwin && oap != NULL && oap->op_type != OP_NOP) {
    clearop(oap);
  }

  if (mod_mask == 0
      && !is_drag
      && (jump_flags & (MOUSE_FOLD_CLOSE | MOUSE_FOLD_OPEN))
      && which_button == MOUSE_LEFT) {
    // open or close a fold at this line
    if (jump_flags & MOUSE_FOLD_OPEN) {
      openFold(curwin->w_cursor, 1);
    } else {
      closeFold(curwin->w_cursor, 1);
    }
    // don't move the cursor if still in the same window
    if (curwin == old_curwin) {
      curwin->w_cursor = save_cursor;
    }
  }

  // Set global flag that we are extending the Visual area with mouse dragging;
  // temporarily minimize 'scrolloff'.
  if (VIsual_active && is_drag && get_scrolloff_value(curwin)) {
    // In the very first line, allow scrolling one line
    if (mouse_row == 0) {
      mouse_dragging = 2;
    } else {
      mouse_dragging = 1;
    }
  }

  // When dragging the mouse above the window, scroll down.
  if (is_drag && mouse_row < 0 && !in_status_line) {
    scroll_redraw(false, 1);
    mouse_row = 0;
  }

  if (start_visual.lnum) {              // right click in visual mode
    linenr_T diff;
    // When ALT is pressed make Visual mode blockwise.
    if (mod_mask & MOD_MASK_ALT) {
      VIsual_mode = Ctrl_V;
    }

    // In Visual-block mode, divide the area in four, pick up the corner
    // that is in the quarter that the cursor is in.
    if (VIsual_mode == Ctrl_V) {
      getvcols(curwin, &start_visual, &end_visual, &leftcol, &rightcol);
      if (curwin->w_curswant > (leftcol + rightcol) / 2) {
        end_visual.col = leftcol;
      } else {
        end_visual.col = rightcol;
      }
      if (curwin->w_cursor.lnum >=
          (start_visual.lnum + end_visual.lnum) / 2) {
        end_visual.lnum = start_visual.lnum;
      }

      // move VIsual to the right column
      start_visual = curwin->w_cursor;              // save the cursor pos
      curwin->w_cursor = end_visual;
      coladvance(curwin, end_visual.col);
      VIsual = curwin->w_cursor;
      curwin->w_cursor = start_visual;              // restore the cursor
    } else {
      // If the click is before the start of visual, change the start.
      // If the click is after the end of visual, change the end.  If
      // the click is inside the visual, change the closest side.
      if (lt(curwin->w_cursor, start_visual)) {
        VIsual = end_visual;
      } else if (lt(end_visual, curwin->w_cursor)) {
        VIsual = start_visual;
      } else {
        // In the same line, compare column number
        if (end_visual.lnum == start_visual.lnum) {
          if (curwin->w_cursor.col - start_visual.col >
              end_visual.col - curwin->w_cursor.col) {
            VIsual = start_visual;
          } else {
            VIsual = end_visual;
          }
        } else {
          // In different lines, compare line number
          diff = (curwin->w_cursor.lnum - start_visual.lnum) -
                 (end_visual.lnum - curwin->w_cursor.lnum);

          if (diff > 0) {                       // closest to end
            VIsual = start_visual;
          } else if (diff < 0) {                   // closest to start
            VIsual = end_visual;
          } else {                                // in the middle line
            if (curwin->w_cursor.col <
                (start_visual.col + end_visual.col) / 2) {
              VIsual = end_visual;
            } else {
              VIsual = start_visual;
            }
          }
        }
      }
    }
  } else if ((State & MODE_INSERT) && VIsual_active) {
    // If Visual mode started in insert mode, execute "CTRL-O"
    stuffcharReadbuff(Ctrl_O);
  }

  // Middle mouse click: Put text before cursor.
  if (which_button == MOUSE_MIDDLE) {
    int c2;
    if (regname == 0 && eval_has_provider("clipboard", false)) {
      regname = '*';
    }
    if (yank_register_mline(regname)) {
      if (mouse_past_bottom) {
        dir = FORWARD;
      }
    } else if (mouse_past_eol) {
      dir = FORWARD;
    }

    if (fixindent) {
      c1 = (dir == BACKWARD) ? '[' : ']';
      c2 = 'p';
    } else {
      c1 = (dir == FORWARD) ? 'p' : 'P';
      c2 = NUL;
    }
    prep_redo(regname, count, NUL, c1, NUL, c2, NUL);

    // Remember where the paste started, so in edit() Insstart can be set to this position
    if (restart_edit != 0) {
      where_paste_started = curwin->w_cursor;
    }
    do_put(regname, NULL, dir, count,
           (fixindent ? PUT_FIXINDENT : 0)| PUT_CURSEND);
  } else if (((mod_mask & MOD_MASK_CTRL) || (mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK)
             && bt_quickfix(curbuf)) {
    // Ctrl-Mouse click or double click in a quickfix window jumps to the
    // error under the mouse pointer.
    if (curwin->w_llist_ref == NULL) {          // quickfix window
      do_cmdline_cmd(".cc");
    } else {                                    // location list window
      do_cmdline_cmd(".ll");
    }
    got_click = false;                          // ignore drag&release now
  } else if ((mod_mask & MOD_MASK_CTRL)
             || (curbuf->b_help && (mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK)) {
    // Ctrl-Mouse click (or double click in a help window) jumps to the tag
    // under the mouse pointer.
    if (State & MODE_INSERT) {
      stuffcharReadbuff(Ctrl_O);
    }
    stuffcharReadbuff(Ctrl_RSB);
    got_click = false;                          // ignore drag&release now
  } else if ((mod_mask & MOD_MASK_SHIFT)) {
    // Shift-Mouse click searches for the next occurrence of the word under
    // the mouse pointer
    if (State & MODE_INSERT || (VIsual_active && VIsual_select)) {
      stuffcharReadbuff(Ctrl_O);
    }
    if (which_button == MOUSE_LEFT) {
      stuffcharReadbuff('*');
    } else {  // MOUSE_RIGHT
      stuffcharReadbuff('#');
    }
  } else if (in_status_line || in_sep_line) {
    // Do nothing if on status line or vertical separator
    // Handle double clicks otherwise
  } else if ((mod_mask & MOD_MASK_MULTI_CLICK) && (State & (MODE_NORMAL | MODE_INSERT))) {
    if (is_click || !VIsual_active) {
      if (VIsual_active) {
        orig_cursor = VIsual;
      } else {
        VIsual = curwin->w_cursor;
        orig_cursor = VIsual;
        VIsual_active = true;
        VIsual_reselect = true;
        // start Select mode if 'selectmode' contains "mouse"
        may_start_select('o');
        setmouse();
      }
      if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK) {
        // Double click with ALT pressed makes it blockwise.
        if (mod_mask & MOD_MASK_ALT) {
          VIsual_mode = Ctrl_V;
        } else {
          VIsual_mode = 'v';
        }
      } else if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_3CLICK) {
        VIsual_mode = 'V';
      } else if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_4CLICK) {
        VIsual_mode = Ctrl_V;
      }
    }
    // A double click selects a word or a block.
    if ((mod_mask & MOD_MASK_MULTI_CLICK) == MOD_MASK_2CLICK) {
      pos_T *pos = NULL;

      if (is_click) {
        // If the character under the cursor (skipping white space) is
        // not a word character, try finding a match and select a (),
        // {}, [], #if/#endif, etc. block.
        end_visual = curwin->w_cursor;
        int gc;
        while (gc = gchar_pos(&end_visual), ascii_iswhite(gc)) {
          inc(&end_visual);
        }
        if (oap != NULL) {
          oap->motion_type = kMTCharWise;
        }
        if (oap != NULL
            && VIsual_mode == 'v'
            && !vim_iswordc(gchar_pos(&end_visual))
            && equalpos(curwin->w_cursor, VIsual)
            && (pos = findmatch(oap, NUL)) != NULL) {
          curwin->w_cursor = *pos;
          if (oap->motion_type == kMTLineWise) {
            VIsual_mode = 'V';
          } else if (*p_sel == 'e') {
            if (lt(curwin->w_cursor, VIsual)) {
              VIsual.col++;
            } else {
              curwin->w_cursor.col++;
            }
          }
        }
      }

      if (pos == NULL && (is_click || is_drag)) {
        // When not found a match or when dragging: extend to include a word.
        if (lt(curwin->w_cursor, orig_cursor)) {
          find_start_of_word(&curwin->w_cursor);
          find_end_of_word(&VIsual);
        } else {
          find_start_of_word(&VIsual);
          if (*p_sel == 'e' && *get_cursor_pos_ptr() != NUL) {
            curwin->w_cursor.col +=
              utfc_ptr2len(get_cursor_pos_ptr());
          }
          find_end_of_word(&curwin->w_cursor);
        }
      }
      curwin->w_set_curswant = true;
    }
    if (is_click) {
      redraw_curbuf_later(UPD_INVERTED);  // update the inversion
    }
  } else if (VIsual_active && !old_active) {
    if (mod_mask & MOD_MASK_ALT) {
      VIsual_mode = Ctrl_V;
    } else {
      VIsual_mode = 'v';
    }
  }

  // If Visual mode changed show it later.
  if ((!VIsual_active && old_active && mode_displayed)
      || (VIsual_active && p_smd && msg_silent == 0
          && (!old_active || VIsual_mode != old_mode))) {
    redraw_cmdline = true;
  }

  return moved;
}

void ins_mouse(int c)
{
  win_T *old_curwin = curwin;

  undisplay_dollar();
  pos_T tpos = curwin->w_cursor;
  if (do_mouse(NULL, c, BACKWARD, 1, 0)) {
    win_T *new_curwin = curwin;

    if (curwin != old_curwin && win_valid(old_curwin)) {
      // Mouse took us to another window.  We need to go back to the
      // previous one to stop insert there properly.
      curwin = old_curwin;
      curbuf = curwin->w_buffer;
      if (bt_prompt(curbuf)) {
        // Restart Insert mode when re-entering the prompt buffer.
        curbuf->b_prompt_insert = 'A';
      }
    }
    start_arrow(curwin == old_curwin ? &tpos : NULL);
    if (curwin != new_curwin && win_valid(new_curwin)) {
      curwin = new_curwin;
      curbuf = curwin->w_buffer;
    }
    set_can_cindent(true);
  }

  // redraw status lines (in case another window became active)
  redraw_statuslines();
}

/// Common mouse wheel scrolling, shared between Insert mode and NV modes.
/// Default action is to scroll mouse_vert_step lines (or mouse_hor_step columns
/// depending on the scroll direction) or one page when Shift or Ctrl is used.
/// Direction is indicated by "cap->arg":
///    K_MOUSEUP    - MSCR_UP
///    K_MOUSEDOWN  - MSCR_DOWN
///    K_MOUSELEFT  - MSCR_LEFT
///    K_MOUSERIGHT - MSCR_RIGHT
/// "curwin" may have been changed to the window that should be scrolled and
/// differ from the window that actually has focus.
void do_mousescroll(cmdarg_T *cap)
{
  bool shift_or_ctrl = mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL);

  if (cap->arg == MSCR_UP || cap->arg == MSCR_DOWN) {
    // Vertical scrolling
    if ((State & MODE_NORMAL) && shift_or_ctrl) {
      // whole page up or down
      pagescroll(cap->arg ? FORWARD : BACKWARD, 1, false);
    } else {
      if (shift_or_ctrl) {
        // whole page up or down
        cap->count1 = curwin->w_botline - curwin->w_topline;
      } else {
        cap->count1 = (int)p_mousescroll_vert;
      }
      if (cap->count1 > 0) {
        cap->count0 = cap->count1;
        nv_scroll_line(cap);
      }
    }
  } else {
    // Horizontal scrolling
    int step = shift_or_ctrl ? curwin->w_width_inner : (int)p_mousescroll_hor;
    colnr_T leftcol = curwin->w_leftcol + (cap->arg == MSCR_RIGHT ? -step : +step);
    if (leftcol < 0) {
      leftcol = 0;
    }
    do_mousescroll_horiz(leftcol);
  }
}

/// Implementation for scrolling in Insert mode in direction "dir", which is one
/// of the MSCR_ values.
void ins_mousescroll(int dir)
{
  cmdarg_T cap;
  oparg_T oa;
  CLEAR_FIELD(cap);
  clear_oparg(&oa);
  cap.oap = &oa;
  cap.arg = dir;

  switch (dir) {
  case MSCR_UP:
    cap.cmdchar = K_MOUSEUP;
    break;
  case MSCR_DOWN:
    cap.cmdchar = K_MOUSEDOWN;
    break;
  case MSCR_LEFT:
    cap.cmdchar = K_MOUSELEFT;
    break;
  case MSCR_RIGHT:
    cap.cmdchar = K_MOUSERIGHT;
    break;
  default:
    siemsg("Invalid ins_mousescroll() argument: %d", dir);
  }

  win_T *old_curwin = curwin;
  if (mouse_row >= 0 && mouse_col >= 0) {
    // Find the window at the mouse pointer coordinates.
    // NOTE: Must restore "curwin" to "old_curwin" before returning!
    int grid = mouse_grid;
    int row = mouse_row;
    int col = mouse_col;
    curwin = mouse_find_win(&grid, &row, &col);
    if (curwin == NULL) {
      curwin = old_curwin;
      return;
    }
    curbuf = curwin->w_buffer;
  }

  if (curwin == old_curwin) {
    // Don't scroll the current window if the popup menu is visible.
    if (pum_visible()) {
      return;
    }

    undisplay_dollar();
  }

  pos_T orig_cursor = curwin->w_cursor;

  // Call the common mouse scroll function shared with other modes.
  do_mousescroll(&cap);

  curwin->w_redr_status = true;
  curwin = old_curwin;
  curbuf = curwin->w_buffer;

  if (!equalpos(curwin->w_cursor, orig_cursor)) {
    start_arrow(&orig_cursor);
    set_can_cindent(true);
  }
}

/// Return true if "c" is a mouse key.
bool is_mouse_key(int c)
{
  return c == K_LEFTMOUSE
         || c == K_LEFTMOUSE_NM
         || c == K_LEFTDRAG
         || c == K_LEFTRELEASE
         || c == K_LEFTRELEASE_NM
         || c == K_MOUSEMOVE
         || c == K_MIDDLEMOUSE
         || c == K_MIDDLEDRAG
         || c == K_MIDDLERELEASE
         || c == K_RIGHTMOUSE
         || c == K_RIGHTDRAG
         || c == K_RIGHTRELEASE
         || c == K_MOUSEDOWN
         || c == K_MOUSEUP
         || c == K_MOUSELEFT
         || c == K_MOUSERIGHT
         || c == K_X1MOUSE
         || c == K_X1DRAG
         || c == K_X1RELEASE
         || c == K_X2MOUSE
         || c == K_X2DRAG
         || c == K_X2RELEASE;
}

/// @return  true when 'mousemodel' is set to "popup" or "popup_setpos".
static bool mouse_model_popup(void)
{
  return p_mousem[0] == 'p';
}

static win_T *dragwin = NULL;  ///< window being dragged

/// Reset the window being dragged.  To be called when switching tab page.
void reset_dragwin(void)
{
  dragwin = NULL;
}

/// Move the cursor to the specified row and column on the screen.
/// Change current window if necessary. Returns an integer with the
/// CURSOR_MOVED bit set if the cursor has moved or unset otherwise.
///
/// The MOUSE_FOLD_CLOSE bit is set when clicked on the '-' in a fold column.
/// The MOUSE_FOLD_OPEN bit is set when clicked on the '+' in a fold column.
///
/// If flags has MOUSE_FOCUS, then the current window will not be changed, and
/// if the mouse is outside the window then the text will scroll, or if the
/// mouse was previously on a status line, then the status line may be dragged.
///
/// If flags has MOUSE_MAY_VIS, then VIsual mode will be started before the
/// cursor is moved unless the cursor was on a status line or window bar.
/// This function returns one of IN_UNKNOWN, IN_BUFFER, IN_STATUS_LINE or
/// IN_SEP_LINE depending on where the cursor was clicked.
///
/// If flags has MOUSE_MAY_STOP_VIS, then Visual mode will be stopped, unless
/// the mouse is on the status line or window bar of the same window.
///
/// If flags has MOUSE_DID_MOVE, nothing is done if the mouse didn't move since
/// the last call.
///
/// If flags has MOUSE_SETPOS, nothing is done, only the current position is
/// remembered.
///
/// @param inclusive  used for inclusive operator, can be NULL
/// @param which_button  MOUSE_LEFT, MOUSE_RIGHT, MOUSE_MIDDLE
int jump_to_mouse(int flags, bool *inclusive, int which_button)
{
  static int status_line_offset = 0;        // #lines offset from status line
  static int sep_line_offset = 0;           // #cols offset from sep line
  static bool on_status_line = false;
  static bool on_sep_line = false;
  static bool on_winbar = false;
  static bool on_statuscol = false;
  static int prev_row = -1;
  static int prev_col = -1;
  static int did_drag = false;          // drag was noticed

  int count;
  bool first;
  int row = mouse_row;
  int col = mouse_col;
  int grid = mouse_grid;
  int fdc = 0;
  bool keep_focus = flags & MOUSE_FOCUS;

  mouse_past_bottom = false;
  mouse_past_eol = false;

  if (flags & MOUSE_RELEASED) {
    // On button release we may change window focus if positioned on a
    // status line and no dragging happened.
    if (dragwin != NULL && !did_drag) {
      flags &= ~(MOUSE_FOCUS | MOUSE_DID_MOVE);
    }
    dragwin = NULL;
    did_drag = false;
  }

  if ((flags & MOUSE_DID_MOVE)
      && prev_row == mouse_row
      && prev_col == mouse_col) {
retnomove:
    // before moving the cursor for a left click which is NOT in a status
    // line, stop Visual mode
    if (status_line_offset) {
      return IN_STATUS_LINE;
    }
    if (sep_line_offset) {
      return IN_SEP_LINE;
    }
    if (on_winbar) {
      return IN_OTHER_WIN | MOUSE_WINBAR;
    }
    if (on_statuscol) {
      return IN_OTHER_WIN | MOUSE_STATUSCOL;
    }
    if (flags & MOUSE_MAY_STOP_VIS) {
      end_visual_mode();
      redraw_curbuf_later(UPD_INVERTED);  // delete the inversion
    }
    return IN_BUFFER;
  }

  prev_row = mouse_row;
  prev_col = mouse_col;

  if (flags & MOUSE_SETPOS) {
    goto retnomove;                             // ugly goto...
  }
  win_T *old_curwin = curwin;
  pos_T old_cursor = curwin->w_cursor;

  if (row < 0 || col < 0) {                   // check if it makes sense
    return IN_UNKNOWN;
  }

  // find the window where the row is in
  win_T *wp = mouse_find_win(&grid, &row, &col);
  if (wp == NULL) {
    return IN_UNKNOWN;
  }

  bool below_window = grid == DEFAULT_GRID_HANDLE && row + wp->w_winbar_height >= wp->w_height;
  on_status_line = below_window && row + wp->w_winbar_height - wp->w_height + 1 == 1;
  on_sep_line = grid == DEFAULT_GRID_HANDLE && col >= wp->w_width && col - wp->w_width + 1 == 1;
  on_winbar = row < 0 && row + wp->w_winbar_height >= 0;
  on_statuscol = !below_window && !on_status_line && !on_sep_line && !on_winbar
                 && *wp->w_p_stc != NUL
                 && (wp->w_p_rl
                     ? col >= wp->w_width_inner - win_col_off(wp)
                     : col < win_col_off(wp));

  // The rightmost character of the status line might be a vertical
  // separator character if there is no connecting window to the right.
  if (on_status_line && on_sep_line) {
    if (stl_connected(wp)) {
      on_sep_line = false;
    } else {
      on_status_line = false;
    }
  }

  if (keep_focus) {
    // If we can't change focus, set the value of row, col and grid back to absolute values
    // since the values relative to the window are only used when keep_focus is false
    row = mouse_row;
    col = mouse_col;
    grid = mouse_grid;
  }

  if (!keep_focus) {
    if (on_winbar) {
      return IN_OTHER_WIN | MOUSE_WINBAR;
    }

    if (on_statuscol) {
      return IN_OTHER_WIN | MOUSE_STATUSCOL;
    }

    fdc = win_fdccol_count(wp);
    dragwin = NULL;

    // winpos and height may change in win_enter()!
    if (below_window) {
      // In (or below) status line
      status_line_offset = row + wp->w_winbar_height - wp->w_height + 1;
      dragwin = wp;
    } else {
      status_line_offset = 0;
    }

    if (grid == DEFAULT_GRID_HANDLE && col >= wp->w_width) {
      // In separator line
      sep_line_offset = col - wp->w_width + 1;
      dragwin = wp;
    } else {
      sep_line_offset = 0;
    }

    // The rightmost character of the status line might be a vertical
    // separator character if there is no connecting window to the right.
    if (status_line_offset && sep_line_offset) {
      if (stl_connected(wp)) {
        sep_line_offset = 0;
      } else {
        status_line_offset = 0;
      }
    }

    // Before jumping to another buffer, or moving the cursor for a left
    // click, stop Visual mode.
    if (VIsual_active
        && (wp->w_buffer != curwin->w_buffer
            || (!status_line_offset
                && !sep_line_offset
                && (wp->w_p_rl
                    ? col < wp->w_width_inner - fdc
                    : col >= fdc + (wp != cmdwin_win ? 0 : 1))
                && (flags & MOUSE_MAY_STOP_VIS)))) {
      end_visual_mode();
      redraw_curbuf_later(UPD_INVERTED);  // delete the inversion
    }
    if (cmdwin_type != 0 && wp != cmdwin_win) {
      // A click outside the command-line window: Use modeless
      // selection if possible.  Allow dragging the status lines.
      sep_line_offset = 0;
      row = 0;
      col += wp->w_wincol;
      wp = cmdwin_win;
    }
    // Only change window focus when not clicking on or dragging the
    // status line.  Do change focus when releasing the mouse button
    // (MOUSE_FOCUS was set above if we dragged first).
    if (dragwin == NULL || (flags & MOUSE_RELEASED)) {
      win_enter(wp, true);                      // can make wp invalid!
    }
    // set topline, to be able to check for double click ourselves
    if (curwin != old_curwin) {
      set_mouse_topline(curwin);
    }
    if (status_line_offset) {                       // In (or below) status line
      // Don't use start_arrow() if we're in the same window
      if (curwin == old_curwin) {
        return IN_STATUS_LINE;
      }
      return IN_STATUS_LINE | CURSOR_MOVED;
    }
    if (sep_line_offset) {                          // In (or below) status line
      // Don't use start_arrow() if we're in the same window
      if (curwin == old_curwin) {
        return IN_SEP_LINE;
      }
      return IN_SEP_LINE | CURSOR_MOVED;
    }

    curwin->w_cursor.lnum = curwin->w_topline;
  } else if (status_line_offset) {
    if (which_button == MOUSE_LEFT && dragwin != NULL) {
      // Drag the status line
      count = row - dragwin->w_winrow - dragwin->w_height + 1
              - status_line_offset;
      win_drag_status_line(dragwin, count);
      did_drag |= count;
    }
    return IN_STATUS_LINE;                      // Cursor didn't move
  } else if (sep_line_offset && which_button == MOUSE_LEFT) {
    if (dragwin != NULL) {
      // Drag the separator column
      count = col - dragwin->w_wincol - dragwin->w_width + 1
              - sep_line_offset;
      win_drag_vsep_line(dragwin, count);
      did_drag |= count;
    }
    return IN_SEP_LINE;                         // Cursor didn't move
  } else if (on_status_line && which_button == MOUSE_RIGHT) {
    return IN_STATUS_LINE;
  } else if (on_winbar && which_button == MOUSE_RIGHT) {
    // After a click on the window bar don't start Visual mode.
    return IN_OTHER_WIN | MOUSE_WINBAR;
  } else if (on_statuscol && which_button == MOUSE_RIGHT) {
    // After a click on the status column don't start Visual mode.
    return IN_OTHER_WIN | MOUSE_STATUSCOL;
  } else {
    // keep_window_focus must be true
    // before moving the cursor for a left click, stop Visual mode
    if (flags & MOUSE_MAY_STOP_VIS) {
      end_visual_mode();
      redraw_curbuf_later(UPD_INVERTED);  // delete the inversion
    }

    if (grid == 0) {
      row -= curwin->w_grid_alloc.comp_row + curwin->w_grid.row_offset;
      col -= curwin->w_grid_alloc.comp_col + curwin->w_grid.col_offset;
    } else if (grid != DEFAULT_GRID_HANDLE) {
      row -= curwin->w_grid.row_offset;
      col -= curwin->w_grid.col_offset;
    }

    // When clicking beyond the end of the window, scroll the screen.
    // Scroll by however many rows outside the window we are.
    if (row < 0) {
      count = 0;
      for (first = true; curwin->w_topline > 1;) {
        if (curwin->w_topfill < win_get_fill(curwin, curwin->w_topline)) {
          count++;
        } else {
          count += plines_win(curwin, curwin->w_topline - 1, true);
        }
        if (!first && count > -row) {
          break;
        }
        first = false;
        hasFolding(curwin, curwin->w_topline, &curwin->w_topline, NULL);
        if (curwin->w_topfill < win_get_fill(curwin, curwin->w_topline)) {
          curwin->w_topfill++;
        } else {
          curwin->w_topline--;
          curwin->w_topfill = 0;
        }
      }
      check_topfill(curwin, false);
      curwin->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
      redraw_later(curwin, UPD_VALID);
      row = 0;
    } else if (row >= curwin->w_height_inner) {
      count = 0;
      for (first = true; curwin->w_topline < curbuf->b_ml.ml_line_count;) {
        if (curwin->w_topfill > 0) {
          count++;
        } else {
          count += plines_win(curwin, curwin->w_topline, true);
        }

        if (!first && count > row - curwin->w_height_inner + 1) {
          break;
        }
        first = false;

        if (curwin->w_topfill > 0) {
          curwin->w_topfill--;
        } else {
          if (hasFolding(curwin, curwin->w_topline, NULL, &curwin->w_topline)
              && curwin->w_topline == curbuf->b_ml.ml_line_count) {
            break;
          }
          curwin->w_topline++;
          curwin->w_topfill = win_get_fill(curwin, curwin->w_topline);
        }
      }
      check_topfill(curwin, false);
      redraw_later(curwin, UPD_VALID);
      curwin->w_valid &=
        ~(VALID_WROW|VALID_CROW|VALID_BOTLINE|VALID_BOTLINE_AP);
      row = curwin->w_height_inner - 1;
    } else if (row == 0) {
      // When dragging the mouse, while the text has been scrolled up as
      // far as it goes, moving the mouse in the top line should scroll
      // the text down (done later when recomputing w_topline).
      if (mouse_dragging > 0
          && curwin->w_cursor.lnum
          == curwin->w_buffer->b_ml.ml_line_count
          && curwin->w_cursor.lnum == curwin->w_topline) {
        curwin->w_valid &= ~(VALID_TOPLINE);
      }
    }
  }

  colnr_T col_from_screen = -1;
  int mouse_fold_flags = 0;
  mouse_check_grid(&col_from_screen, &mouse_fold_flags);

  // compute the position in the buffer line from the posn on the screen
  if (mouse_comp_pos(curwin, &row, &col, &curwin->w_cursor.lnum)) {
    mouse_past_bottom = true;
  }

  // Start Visual mode before coladvance(), for when 'sel' != "old"
  if ((flags & MOUSE_MAY_VIS) && !VIsual_active) {
    VIsual = old_cursor;
    VIsual_active = true;
    VIsual_reselect = true;
    // if 'selectmode' contains "mouse", start Select mode
    may_start_select('o');
    setmouse();

    if (p_smd && msg_silent == 0) {
      redraw_cmdline = true;            // show visual mode later
    }
  }

  if (col_from_screen >= 0) {
    col = col_from_screen;
  }

  curwin->w_curswant = col;
  curwin->w_set_curswant = false;       // May still have been true
  if (coladvance(curwin, col) == FAIL) {        // Mouse click beyond end of line
    if (inclusive != NULL) {
      *inclusive = true;
    }
    mouse_past_eol = true;
  } else if (inclusive != NULL) {
    *inclusive = false;
  }

  count = IN_BUFFER;
  if (curwin != old_curwin || curwin->w_cursor.lnum != old_cursor.lnum
      || curwin->w_cursor.col != old_cursor.col) {
    count |= CURSOR_MOVED;              // Cursor has moved
  }

  count |= mouse_fold_flags;

  return count;
}

/// Make a horizontal scroll to "leftcol".
/// @return true if the cursor moved, false otherwise.
static bool do_mousescroll_horiz(colnr_T leftcol)
{
  if (curwin->w_p_wrap) {
    return false;  // no horizontal scrolling when wrapping
  }
  if (curwin->w_leftcol == leftcol) {
    return false;  // already there
  }

  // When the line of the cursor is too short, move the cursor to the
  // longest visible line.
  if (!virtual_active(curwin)
      && leftcol > scroll_line_len(curwin->w_cursor.lnum)) {
    curwin->w_cursor.lnum = find_longest_lnum();
    curwin->w_cursor.col = 0;
  }

  return set_leftcol(leftcol);
}

/// Normal and Visual modes implementation for scrolling in direction
/// "cap->arg", which is one of the MSCR_ values.
void nv_mousescroll(cmdarg_T *cap)
{
  win_T *const old_curwin = curwin;

  if (mouse_row >= 0 && mouse_col >= 0) {
    // Find the window at the mouse pointer coordinates.
    // NOTE: Must restore "curwin" to "old_curwin" before returning!
    int grid = mouse_grid;
    int row = mouse_row;
    int col = mouse_col;
    curwin = mouse_find_win(&grid, &row, &col);
    if (curwin == NULL) {
      curwin = old_curwin;
      return;
    }
    curbuf = curwin->w_buffer;
  }

  // Call the common mouse scroll function shared with other modes.
  do_mousescroll(cap);

  curwin->w_redr_status = true;
  curwin = old_curwin;
  curbuf = curwin->w_buffer;
}

/// Mouse clicks and drags.
void nv_mouse(cmdarg_T *cap)
{
  do_mouse(cap->oap, cap->cmdchar, BACKWARD, cap->count1, 0);
}

/// Compute the position in the buffer line from the posn on the screen in
/// window "win".
/// Returns true if the position is below the last line.
bool mouse_comp_pos(win_T *win, int *rowp, int *colp, linenr_T *lnump)
{
  int col = *colp;
  int row = *rowp;
  bool retval = false;
  int count;

  if (win->w_p_rl) {
    col = win->w_width_inner - 1 - col;
  }

  linenr_T lnum = win->w_topline;

  while (row > 0) {
    // Don't include filler lines in "count"
    if (win_may_fill(win)) {
      if (lnum == win->w_topline) {
        row -= win->w_topfill;
      } else {
        row -= win_get_fill(win, lnum);
      }
      count = plines_win_nofill(win, lnum, false);
    } else {
      count = plines_win(win, lnum, false);
    }

    if (win->w_skipcol > 0 && lnum == win->w_topline) {
      // Adjust for 'smoothscroll' clipping the top screen lines.
      // A similar formula is used in curs_columns().
      int width1 = win->w_width_inner - win_col_off(win);
      int skip_lines = 0;
      if (win->w_skipcol > width1) {
        skip_lines = (win->w_skipcol - width1) / (width1 + win_col_off2(win)) + 1;
      } else if (win->w_skipcol > 0) {
        skip_lines = 1;
      }
      count -= skip_lines;
    }

    if (count > row) {
      break;            // Position is in this buffer line.
    }

    hasFolding(win, lnum, NULL, &lnum);

    if (lnum == win->w_buffer->b_ml.ml_line_count) {
      retval = true;
      break;                    // past end of file
    }
    row -= count;
    lnum++;
  }

  if (!retval) {
    // Compute the column without wrapping.
    int off = win_col_off(win) - win_col_off2(win);
    if (col < off) {
      col = off;
    }
    col += row * (win->w_width_inner - off);

    // Add skip column for the topline.
    if (lnum == win->w_topline) {
      col += win->w_skipcol;
    }
  }

  if (!win->w_p_wrap) {
    col += win->w_leftcol;
  }

  // skip line number and fold column in front of the line
  col -= win_col_off(win);
  if (col <= 0) {
    col = 0;
  }

  *colp = col;
  *rowp = row;
  *lnump = lnum;
  return retval;
}

/// Find the window at "grid" position "*rowp" and "*colp".  The positions are
/// updated to become relative to the top-left of the window.
///
/// @return NULL when something is wrong.
win_T *mouse_find_win(int *gridp, int *rowp, int *colp)
{
  win_T *wp_grid = mouse_find_grid_win(gridp, rowp, colp);
  if (wp_grid) {
    return wp_grid;
  } else if (*gridp > 1) {
    return NULL;
  }

  frame_T *fp = topframe;
  *rowp -= firstwin->w_winrow;
  while (true) {
    if (fp->fr_layout == FR_LEAF) {
      break;
    }
    if (fp->fr_layout == FR_ROW) {
      for (fp = fp->fr_child; fp->fr_next != NULL; fp = fp->fr_next) {
        if (*colp < fp->fr_width) {
          break;
        }
        *colp -= fp->fr_width;
      }
    } else {  // fr_layout == FR_COL
      for (fp = fp->fr_child; fp->fr_next != NULL; fp = fp->fr_next) {
        if (*rowp < fp->fr_height) {
          break;
        }
        *rowp -= fp->fr_height;
      }
    }
  }
  // When using a timer that closes a window the window might not actually
  // exist.
  FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
    if (wp == fp->fr_win) {
      *rowp -= wp->w_winbar_height;
      return wp;
    }
  }
  return NULL;
}

static win_T *mouse_find_grid_win(int *gridp, int *rowp, int *colp)
{
  if (*gridp == msg_grid.handle) {
    *rowp += msg_grid_pos;
    *gridp = DEFAULT_GRID_HANDLE;
  } else if (*gridp > 1) {
    win_T *wp = get_win_by_grid_handle(*gridp);
    if (wp && wp->w_grid_alloc.chars
        && !(wp->w_floating && !wp->w_config.focusable)) {
      *rowp = MIN(*rowp - wp->w_grid.row_offset, wp->w_grid.rows - 1);
      *colp = MIN(*colp - wp->w_grid.col_offset, wp->w_grid.cols - 1);
      return wp;
    }
  } else if (*gridp == 0) {
    ScreenGrid *grid = ui_comp_mouse_focus(*rowp, *colp);
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (&wp->w_grid_alloc != grid) {
        continue;
      }
      *gridp = grid->handle;
      *rowp -= grid->comp_row + wp->w_grid.row_offset;
      *colp -= grid->comp_col + wp->w_grid.col_offset;
      return wp;
    }

    // no float found, click on the default grid
    // TODO(bfredl): grid can be &pum_grid, allow select pum items by mouse?
    *gridp = DEFAULT_GRID_HANDLE;
  }
  return NULL;
}

/// Convert a virtual (screen) column to a character column.
/// The first column is zero.
colnr_T vcol2col(win_T *wp, linenr_T lnum, colnr_T vcol, colnr_T *coladdp)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  // try to advance to the specified column
  char *line = ml_get_buf(wp->w_buffer, lnum);
  CharsizeArg csarg;
  CSType cstype = init_charsize_arg(&csarg, wp, lnum, line);
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  int cur_vcol = 0;
  while (cur_vcol < vcol && *ci.ptr != NUL) {
    int next_vcol = cur_vcol + win_charsize(cstype, cur_vcol, ci.ptr, ci.chr.value, &csarg).width;
    if (next_vcol > vcol) {
      break;
    }
    cur_vcol = next_vcol;
    ci = utfc_next(ci);
  }

  if (coladdp != NULL) {
    *coladdp = vcol - cur_vcol;
  }
  return (colnr_T)(ci.ptr - line);
}

/// Set UI mouse depending on current mode and 'mouse'.
///
/// Emits mouse_on/mouse_off UI event (unless 'mouse' is empty).
void setmouse(void)
{
  ui_cursor_shape();
  ui_check_mouse();
}

// Set orig_topline.  Used when jumping to another window, so that a double
// click still works.
static void set_mouse_topline(win_T *wp)
{
  orig_topline = wp->w_topline;
  orig_topfill = wp->w_topfill;
}

/// Return length of line "lnum" for horizontal scrolling.
static colnr_T scroll_line_len(linenr_T lnum)
{
  colnr_T col = 0;
  char *line = ml_get(lnum);
  if (*line != NUL) {
    while (true) {
      int numchar = win_chartabsize(curwin, line, col);
      MB_PTR_ADV(line);
      if (*line == NUL) {    // don't count the last character
        break;
      }
      col += numchar;
    }
  }
  return col;
}

/// Find longest visible line number.
static linenr_T find_longest_lnum(void)
{
  linenr_T ret = 0;

  // Calculate maximum for horizontal scrollbar.  Check for reasonable
  // line numbers, topline and botline can be invalid when displaying is
  // postponed.
  if (curwin->w_topline <= curwin->w_cursor.lnum
      && curwin->w_botline > curwin->w_cursor.lnum
      && curwin->w_botline <= curbuf->b_ml.ml_line_count + 1) {
    colnr_T max = 0;

    // Use maximum of all visible lines.  Remember the lnum of the
    // longest line, closest to the cursor line.  Used when scrolling
    // below.
    for (linenr_T lnum = curwin->w_topline; lnum < curwin->w_botline; lnum++) {
      colnr_T len = scroll_line_len(lnum);
      if (len > max) {
        max = len;
        ret = lnum;
      } else if (len == max
                 && abs(lnum - curwin->w_cursor.lnum)
                 < abs(ret - curwin->w_cursor.lnum)) {
        ret = lnum;
      }
    }
  } else {
    // Use cursor line only.
    ret = curwin->w_cursor.lnum;
  }

  return ret;
}

/// Check clicked cell on its grid
static void mouse_check_grid(colnr_T *vcolp, int *flagsp)
  FUNC_ATTR_NONNULL_ALL
{
  int click_grid = mouse_grid;
  int click_row = mouse_row;
  int click_col = mouse_col;

  // XXX: this doesn't change click_grid if it is 1, even with multigrid
  if (mouse_find_win(&click_grid, &click_row, &click_col) != curwin
      // Only use vcols[] after the window was redrawn.  Mainly matters
      // for tests, a user would not click before redrawing.
      || curwin->w_redr_type != 0) {
    return;
  }
  ScreenGrid *gp = &curwin->w_grid;
  int start_row = 0;
  int start_col = 0;
  grid_adjust(&gp, &start_row, &start_col);
  if (gp->handle != click_grid || gp->chars == NULL) {
    return;
  }
  click_row += start_row;
  click_col += start_col;
  if (click_row < 0 || click_row >= gp->rows
      || click_col < 0 || click_col >= gp->cols) {
    return;
  }

  const size_t off = gp->line_offset[click_row] + (size_t)click_col;
  colnr_T col_from_screen = gp->vcols[off];

  if (col_from_screen >= 0) {
    // Use the virtual column from vcols[], it is accurate also after
    // concealed characters.
    *vcolp = col_from_screen;
  }

  if (col_from_screen == -2) {
    *flagsp |= MOUSE_FOLD_OPEN;
  } else if (col_from_screen == -3) {
    *flagsp |= MOUSE_FOLD_CLOSE;
  }
}

/// "getmousepos()" function
void f_getmousepos(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int row = mouse_row;
  int col = mouse_col;
  int grid = mouse_grid;
  varnumber_T winid = 0;
  varnumber_T winrow = 0;
  varnumber_T wincol = 0;
  linenr_T lnum = 0;
  varnumber_T column = 0;
  colnr_T coladd = 0;

  tv_dict_alloc_ret(rettv);
  dict_T *d = rettv->vval.v_dict;

  tv_dict_add_nr(d, S_LEN("screenrow"), (varnumber_T)mouse_row + 1);
  tv_dict_add_nr(d, S_LEN("screencol"), (varnumber_T)mouse_col + 1);

  win_T *wp = mouse_find_win(&grid, &row, &col);
  if (wp != NULL) {
    int height = wp->w_height + wp->w_hsep_height + wp->w_status_height;
    // The height is adjusted by 1 when there is a bottom border. This is not
    // necessary for a top border since `row` starts at -1 in that case.
    if (row < height + wp->w_border_adj[2]) {
      winid = wp->handle;
      winrow = row + 1 + wp->w_winrow_off;  // Adjust by 1 for top border
      wincol = col + 1 + wp->w_wincol_off;  // Adjust by 1 for left border
      if (row >= 0 && row < wp->w_height && col >= 0 && col < wp->w_width) {
        mouse_comp_pos(wp, &row, &col, &lnum);
        col = vcol2col(wp, lnum, col, &coladd);
        column = col + 1;
      }
    }
  }
  tv_dict_add_nr(d, S_LEN("winid"), winid);
  tv_dict_add_nr(d, S_LEN("winrow"), winrow);
  tv_dict_add_nr(d, S_LEN("wincol"), wincol);
  tv_dict_add_nr(d, S_LEN("line"), (varnumber_T)lnum);
  tv_dict_add_nr(d, S_LEN("column"), column);
  tv_dict_add_nr(d, S_LEN("coladd"), coladd);
}
