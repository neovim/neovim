// edit.c: functions for Insert mode

#include <assert.h>
#include <ctype.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <uv.h>

#include "klib/kvec.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/digraph.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/macros_defs.h"
#include "nvim/mapping.h"
#include "nvim/mark.h"
#include "nvim/mark_defs.h"
#include "nvim/marktree_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memline_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/normal_defs.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/plines.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"
#include "nvim/terminal.h"
#include "nvim/textformat.h"
#include "nvim/textobject.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

typedef struct {
  VimState state;
  cmdarg_T *ca;
  int mincol;
  int cmdchar;
  int cmdchar_todo;                  // cmdchar to handle once in init_prompt
  int startln;
  int count;
  int c;
  int lastc;
  int i;
  bool did_backspace;                // previous char was backspace
  bool line_is_white;                // line is empty before insert
  linenr_T old_topline;              // topline before insertion
  int old_topfill;
  int inserted_space;                // just inserted a space
  int replaceState;
  int did_restart_edit;              // remember if insert mode was restarted
                                     // after a ctrl+o
  bool nomove;
  char *ptr;
} InsertState;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "edit.c.generated.h"
#endif
enum {
  BACKSPACE_CHAR = 1,
  BACKSPACE_WORD = 2,
  BACKSPACE_WORD_NOT_SPACE = 3,
  BACKSPACE_LINE = 4,
};

/// Set when doing something for completion that may call edit() recursively,
/// which is not allowed.
static bool compl_busy = false;

static colnr_T Insstart_textlen;        // length of line when insert started
static colnr_T Insstart_blank_vcol;     // vcol for first inserted blank
static bool update_Insstart_orig = true;  // set Insstart_orig to Insstart

static char *last_insert = NULL;        // the text of the previous insert, K_SPECIAL is escaped
static int last_insert_skip;            // nr of chars in front of previous insert
static int new_insert_skip;             // nr of chars in front of current insert
static int did_restart_edit;            // "restart_edit" when calling edit()

static bool can_cindent;                // may do cindenting on this line

static bool revins_on;                  // reverse insert mode on
static int revins_chars;                // how much to skip after edit
static int revins_legal;                // was the last char 'legal'?
static int revins_scol;                 // start column of revins session

static bool ins_need_undo;              // call u_save() before inserting a
                                        // char.  Set when edit() is called.
                                        // after that arrow_used is used.

static TriState dont_sync_undo = kFalse;  // CTRL-G U prevents syncing undo
                                          // for the next left/right cursor key

static linenr_T o_lnum = 0;

static kvec_t(char) replace_stack = KV_INITIAL_VALUE;

static void insert_enter(InsertState *s)
{
  s->did_backspace = true;
  s->old_topfill = -1;
  s->replaceState = MODE_REPLACE;
  s->cmdchar_todo = s->cmdchar;
  // Remember whether editing was restarted after CTRL-O
  did_restart_edit = restart_edit;
  // sleep before redrawing, needed for "CTRL-O :" that results in an
  // error message
  msg_check_for_delay(true);
  // set Insstart_orig to Insstart
  update_Insstart_orig = true;

  ins_compl_clear();        // clear stuff for CTRL-X mode

  // Trigger InsertEnter autocommands.  Do not do this for "r<CR>" or "grx".
  if (s->cmdchar != 'r' && s->cmdchar != 'v') {
    pos_T save_cursor = curwin->w_cursor;

    if (s->cmdchar == 'R') {
      s->ptr = "r";
    } else if (s->cmdchar == 'V') {
      s->ptr = "v";
    } else {
      s->ptr = "i";
    }

    set_vim_var_string(VV_INSERTMODE, s->ptr, 1);
    set_vim_var_string(VV_CHAR, NULL, -1);
    ins_apply_autocmds(EVENT_INSERTENTER);

    // Check for changed highlighting, e.g. for ModeMsg.
    if (need_highlight_changed) {
      highlight_changed();
    }

    // Make sure the cursor didn't move.  Do call check_cursor_col() in
    // case the text was modified.  Since Insert mode was not started yet
    // a call to check_cursor_col() may move the cursor, especially with
    // the "A" command, thus set State to avoid that. Also check that the
    // line number is still valid (lines may have been deleted).
    // Do not restore if v:char was set to a non-empty string.
    if (!equalpos(curwin->w_cursor, save_cursor)
        && *get_vim_var_str(VV_CHAR) == NUL
        && save_cursor.lnum <= curbuf->b_ml.ml_line_count) {
      int save_state = State;

      curwin->w_cursor = save_cursor;
      State = MODE_INSERT;
      check_cursor_col(curwin);
      State = save_state;
    }
  }

  // When doing a paste with the middle mouse button, Insstart is set to
  // where the paste started.
  if (where_paste_started.lnum != 0) {
    Insstart = where_paste_started;
  } else {
    Insstart = curwin->w_cursor;
    if (s->startln) {
      Insstart.col = 0;
    }
  }

  Insstart_textlen = linetabsize_str(get_cursor_line_ptr());
  Insstart_blank_vcol = MAXCOL;

  if (!did_ai) {
    ai_col = 0;
  }

  if (s->cmdchar != NUL && restart_edit == 0) {
    ResetRedobuff();
    AppendNumberToRedobuff(s->count);
    if (s->cmdchar == 'V' || s->cmdchar == 'v') {
      // "gR" or "gr" command
      AppendCharToRedobuff('g');
      AppendCharToRedobuff((s->cmdchar == 'v') ? 'r' : 'R');
    } else {
      AppendCharToRedobuff(s->cmdchar);
      if (s->cmdchar == 'g') {          // "gI" command
        AppendCharToRedobuff('I');
      } else if (s->cmdchar == 'r') {  // "r<CR>" command
        s->count = 1;                  // insert only one <CR>
      }
    }
  }

  if (s->cmdchar == 'R') {
    State = MODE_REPLACE;
  } else if (s->cmdchar == 'V' || s->cmdchar == 'v') {
    State = MODE_VREPLACE;
    s->replaceState = MODE_VREPLACE;
    orig_line_count = curbuf->b_ml.ml_line_count;
    vr_lines_changed = 1;
  } else {
    State = MODE_INSERT;
  }

  may_trigger_modechanged();
  stop_insert_mode = false;

  // need to position cursor again when on a TAB and
  // when on a char with inline virtual text
  if (gchar_cursor() == TAB || buf_meta_total(curbuf, kMTMetaInline) > 0) {
    curwin->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL);
  }

  // Enable langmap or IME, indicated by 'iminsert'.
  // Note that IME may enabled/disabled without us noticing here, thus the
  // 'iminsert' value may not reflect what is actually used.  It is updated
  // when hitting <Esc>.
  if (curbuf->b_p_iminsert == B_IMODE_LMAP) {
    State |= MODE_LANGMAP;
  }

  setmouse();
  clear_showcmd();
  // there is no reverse replace mode
  revins_on = (State == MODE_INSERT && p_ri);
  if (revins_on) {
    undisplay_dollar();
  }
  revins_chars = 0;
  revins_legal = 0;
  revins_scol = -1;

  // Handle restarting Insert mode.
  // Don't do this for "CTRL-O ." (repeat an insert): we get here with
  // restart_edit non-zero, and something in the stuff buffer.
  if (restart_edit != 0 && stuff_empty()) {
    // After a paste we consider text typed to be part of the insert for
    // the pasted text. You can backspace over the pasted text too.
    arrow_used = where_paste_started.lnum == 0;
    restart_edit = 0;

    // If the cursor was after the end-of-line before the CTRL-O and it is
    // now at the end-of-line, put it after the end-of-line (this is not
    // correct in very rare cases).
    // Also do this if curswant is greater than the current virtual
    // column.  Eg after "^O$" or "^O80|".
    validate_virtcol(curwin);
    update_curswant();
    if (((ins_at_eol && curwin->w_cursor.lnum == o_lnum)
         || curwin->w_curswant > curwin->w_virtcol)
        && *(s->ptr = get_cursor_line_ptr() + curwin->w_cursor.col) != NUL) {
      if (s->ptr[1] == NUL) {
        curwin->w_cursor.col++;
      } else {
        s->i = utfc_ptr2len(s->ptr);
        if (s->ptr[s->i] == NUL) {
          curwin->w_cursor.col += s->i;
        }
      }
    }
    ins_at_eol = false;
  } else {
    arrow_used = false;
  }

  // we are in insert mode now, don't need to start it anymore
  need_start_insertmode = false;

  // Need to save the line for undo before inserting the first char.
  ins_need_undo = true;

  where_paste_started.lnum = 0;
  can_cindent = true;
  // The cursor line is not in a closed fold, unless restarting.
  if (did_restart_edit == 0) {
    foldOpenCursor();
  }

  // If 'showmode' is set, show the current (insert/replace/..) mode.
  // A warning message for changing a readonly file is given here, before
  // actually changing anything.  It's put after the mode, if any.
  s->i = 0;
  if (p_smd && msg_silent == 0) {
    s->i = showmode();
  }

  if (did_restart_edit == 0) {
    change_warning(curbuf, s->i == 0 ? 0 : s->i + 1);
  }

  ui_cursor_shape();            // may show different cursor shape
  do_digraph(-1);               // clear digraphs

  // Get the current length of the redo buffer, those characters have to be
  // skipped if we want to get to the inserted characters.
  s->ptr = get_inserted();
  if (s->ptr == NULL) {
    new_insert_skip = 0;
  } else {
    new_insert_skip = (int)strlen(s->ptr);
    xfree(s->ptr);
  }

  old_indent = 0;

  do {
    state_enter(&s->state);
    // If s->count != 0, `ins_esc` will prepare the redo buffer for reprocessing
    // and return false, causing `state_enter` to be called again.
  } while (!ins_esc(&s->count, s->cmdchar, s->nomove));

  // Always update o_lnum, so that a "CTRL-O ." that adds a line
  // still puts the cursor back after the inserted text.
  if (ins_at_eol) {
    o_lnum = curwin->w_cursor.lnum;
  }

  pum_check_clear();

  foldUpdateAfterInsert();
  // When CTRL-C was typed got_int will be set, with the result
  // that the autocommands won't be executed. When mapped got_int
  // is not set, but let's keep the behavior the same.
  if (s->cmdchar != 'r' && s->cmdchar != 'v' && s->c != Ctrl_C) {
    ins_apply_autocmds(EVENT_INSERTLEAVE);
  }
  did_cursorhold = false;

  // ins_redraw() triggers TextChangedI only when no characters
  // are in the typeahead buffer, so reset curbuf->b_last_changedtick
  // if the TextChangedI was not blocked by char_avail() (e.g. using :norm!)
  // and the TextChangedI autocommand has been triggered.
  if (!char_avail() && curbuf->b_last_changedtick_i == buf_get_changedtick(curbuf)) {
    curbuf->b_last_changedtick = buf_get_changedtick(curbuf);
  }
}

static int insert_check(VimState *state)
{
  InsertState *s = (InsertState *)state;

  // If typed something may trigger CursorHoldI again.
  if (s->c != K_EVENT
      // but not in CTRL-X mode, a script can't restore the state
      && ctrl_x_mode_normal()) {
    did_cursorhold = false;
  }

  // If the cursor was moved we didn't just insert a space
  if (arrow_used) {
    s->inserted_space = false;
  }

  if (can_cindent
      && cindent_on()
      && ctrl_x_mode_normal()
      && !ins_compl_active()) {
    insert_do_cindent(s);
  }

  if (!revins_legal) {
    revins_scol = -1;     // reset on illegal motions
  } else {
    revins_legal = 0;
  }

  if (arrow_used) {       // don't repeat insert when arrow key used
    s->count = 0;
  }

  if (update_Insstart_orig) {
    Insstart_orig = Insstart;
  }

  if (curbuf->terminal && !stop_insert_mode) {
    // Exit Insert mode and go to Terminal mode.
    stop_insert_mode = true;
    restart_edit = 'I';
    stuffcharReadbuff(K_NOP);
  }

  if (stop_insert_mode && !ins_compl_active()) {
    // ":stopinsert" used
    s->count = 0;
    return 0;  // exit insert mode
  }

  // set curwin->w_curswant for next K_DOWN or K_UP
  if (!arrow_used) {
    curwin->w_set_curswant = true;
  }

  // If there is no typeahead may check for timestamps (e.g., for when a
  // menu invoked a shell command).
  if (stuff_empty()) {
    did_check_timestamps = false;
    if (need_check_timestamps) {
      check_timestamps(false);
    }
  }

  // When emsg() was called msg_scroll will have been set.
  msg_scroll = false;

  // Open fold at the cursor line, according to 'foldopen'.
  if (fdo_flags & kOptFdoFlagInsert) {
    foldOpenCursor();
  }

  // Close folds where the cursor isn't, according to 'foldclose'
  if (!char_avail()) {
    foldCheckClose();
  }

  if (bt_prompt(curbuf)) {
    init_prompt(s->cmdchar_todo);
    s->cmdchar_todo = NUL;
  }

  // If we inserted a character at the last position of the last line in the
  // window, scroll the window one line up. This avoids an extra redraw.  This
  // is detected when the cursor column is smaller after inserting something.
  // Don't do this when the topline changed already, it has already been
  // adjusted (by insertchar() calling open_line())).
  // Also don't do this when 'smoothscroll' is set, as the window should then
  // be scrolled by screen lines.
  if (curbuf->b_mod_set
      && curwin->w_p_wrap
      && !curwin->w_p_sms
      && !s->did_backspace
      && curwin->w_topline == s->old_topline
      && curwin->w_topfill == s->old_topfill
      && s->count <= 1) {
    s->mincol = curwin->w_wcol;
    validate_cursor_col(curwin);

    if (curwin->w_wcol < s->mincol - tabstop_at(get_nolist_virtcol(),
                                                curbuf->b_p_ts,
                                                curbuf->b_p_vts_array,
                                                false)
        && curwin->w_wrow == curwin->w_height_inner - 1 - get_scrolloff_value(curwin)
        && (curwin->w_cursor.lnum != curwin->w_topline
            || curwin->w_topfill > 0)) {
      if (curwin->w_topfill > 0) {
        curwin->w_topfill--;
      } else if (hasFolding(curwin, curwin->w_topline, NULL, &s->old_topline)) {
        set_topline(curwin, s->old_topline + 1);
      } else {
        set_topline(curwin, curwin->w_topline + 1);
      }
    }
  }

  // May need to adjust w_topline to show the cursor.
  if (s->count <= 1) {
    update_topline(curwin);
  }

  s->did_backspace = false;

  if (s->count <= 1) {
    validate_cursor(curwin);  // may set must_redraw
  }

  // Redraw the display when no characters are waiting.
  // Also shows mode, ruler and positions cursor.
  ins_redraw(true);

  if (curwin->w_p_scb) {
    do_check_scrollbind(true);
  }

  if (curwin->w_p_crb) {
    do_check_cursorbind();
  }

  if (s->count <= 1) {
    update_curswant();
  }
  s->old_topline = curwin->w_topline;
  s->old_topfill = curwin->w_topfill;

  if (s->c != K_EVENT) {
    s->lastc = s->c;  // remember previous char for CTRL-D
  }

  // After using CTRL-G U the next cursor key will not break undo.
  if (dont_sync_undo == kNone) {
    dont_sync_undo = kTrue;
  } else {
    dont_sync_undo = kFalse;
  }

  return 1;
}

static int insert_execute(VimState *state, int key)
{
  InsertState *const s = (InsertState *)state;
  if (stop_insert_mode) {
    // Insert mode ended, possibly from a callback.
    if (key != K_IGNORE && key != K_NOP) {
      vungetc(key);
    }
    s->count = 0;
    s->nomove = true;
    ins_compl_prep(ESC);
    return 0;
  }

  if (key == K_IGNORE || key == K_NOP) {
    return -1;  // get another key
  }
  s->c = key;

  // Don't want K_EVENT with cursorhold for the second key, e.g., after CTRL-V.
  if (key != K_EVENT) {
    did_cursorhold = true;
  }

  // Special handling of keys while the popup menu is visible or wanted
  // and the cursor is still in the completed word.  Only when there is
  // a match, skip this when no matches were found.
  if (ins_compl_active()
      && pum_wanted()
      && curwin->w_cursor.col >= ins_compl_col()
      && ins_compl_has_shown_match()) {
    // BS: Delete one character from "compl_leader".
    if ((s->c == K_BS || s->c == Ctrl_H)
        && curwin->w_cursor.col > ins_compl_col()
        && (s->c = ins_compl_bs()) == NUL) {
      return 1;  // continue
    }

    // When no match was selected or it was edited.
    if (!ins_compl_used_match()) {
      // CTRL-L: Add one character from the current match to
      // "compl_leader".  Except when at the original match and
      // there is nothing to add, CTRL-L works like CTRL-P then.
      if (s->c == Ctrl_L
          && (!ctrl_x_mode_line_or_eval()
              || ins_compl_long_shown_match())) {
        ins_compl_addfrommatch();
        return 1;  // continue
      }

      // A non-white character that fits in with the current
      // completion: Add to "compl_leader".
      if (ins_compl_accept_char(s->c)) {
        // Trigger InsertCharPre.
        char *str = do_insert_char_pre(s->c);

        if (str != NULL) {
          for (char *p = str; *p != NUL; MB_PTR_ADV(p)) {
            ins_compl_addleader(utf_ptr2char(p));
          }
          xfree(str);
        } else {
          ins_compl_addleader(s->c);
        }
        return 1;  // continue
      }

      // Pressing CTRL-Y selects the current match.  When
      // compl_enter_selects is set the Enter key does the same.
      if ((s->c == Ctrl_Y
           || (ins_compl_enter_selects()
               && (s->c == CAR || s->c == K_KENTER || s->c == NL)))
          && stop_arrow() == OK) {
        ins_compl_delete(false);
        ins_compl_insert(false);
      }
    }
  }

  // Prepare for or stop CTRL-X mode. This doesn't do completion, but it does
  // fix up the text when finishing completion.
  ins_compl_init_get_longest();
  if (ins_compl_prep(s->c)) {
    return 1;  // continue
  }

  // CTRL-\ CTRL-N goes to Normal mode,
  // CTRL-\ CTRL-O is like CTRL-O but without moving the cursor
  if (s->c == Ctrl_BSL) {
    // may need to redraw when no more chars available now
    ins_redraw(false);
    no_mapping++;
    allow_keys++;
    s->c = plain_vgetc();
    no_mapping--;
    allow_keys--;
    if (s->c != Ctrl_N && s->c != Ctrl_G && s->c != Ctrl_O) {
      // it's something else
      vungetc(s->c);
      s->c = Ctrl_BSL;
    } else {
      if (s->c == Ctrl_O) {
        ins_ctrl_o();
        ins_at_eol = false;  // cursor keeps its column
        s->nomove = true;
      }
      s->count = 0;
      return 0;
    }
  }

  if (s->c != K_EVENT) {
    s->c = do_digraph(s->c);
  }

  if ((s->c == Ctrl_V || s->c == Ctrl_Q) && ctrl_x_mode_cmdline()) {
    insert_do_complete(s);
    return 1;
  }

  if (s->c == Ctrl_V || s->c == Ctrl_Q) {
    ins_ctrl_v();
    s->c = Ctrl_V;       // pretend CTRL-V is last typed character
    return 1;  // continue
  }

  if (cindent_on() && ctrl_x_mode_none()) {
    s->line_is_white = inindent(0);
    // A key name preceded by a bang means this key is not to be
    // inserted.  Skip ahead to the re-indenting below.
    if (in_cinkeys(s->c, '!', s->line_is_white)
        && stop_arrow() == OK) {
      do_c_expr_indent();
      return 1;  // continue
    }

    // A key name preceded by a star means that indenting has to be
    // done before inserting the key.
    if (can_cindent && in_cinkeys(s->c, '*', s->line_is_white)
        && stop_arrow() == OK) {
      do_c_expr_indent();
    }
  }

  if (curwin->w_p_rl) {
    switch (s->c) {
    case K_LEFT:
      s->c = K_RIGHT; break;
    case K_S_LEFT:
      s->c = K_S_RIGHT; break;
    case K_C_LEFT:
      s->c = K_C_RIGHT; break;
    case K_RIGHT:
      s->c = K_LEFT; break;
    case K_S_RIGHT:
      s->c = K_S_LEFT; break;
    case K_C_RIGHT:
      s->c = K_C_LEFT; break;
    }
  }

  // If 'keymodel' contains "startsel", may start selection.  If it
  // does, a CTRL-O and c will be stuffed, we need to get these
  // characters.
  if (ins_start_select(s->c)) {
    return 1;  // continue
  }

  return insert_handle_key(s);
}

static int insert_handle_key(InsertState *s)
{
  // The big switch to handle a character in insert mode.
  // TODO(tarruda): This could look better if a lookup table is used.
  // (similar to normal mode `nv_cmds[]`)
  switch (s->c) {
  case ESC:           // End input mode
    if (echeck_abbr(ESC + ABBR_OFF)) {
      break;
    }
    FALLTHROUGH;

  case Ctrl_C:        // End input mode
    if (s->c == Ctrl_C && cmdwin_type != 0) {
      // Close the cmdline window.
      cmdwin_result = K_IGNORE;
      got_int = false;         // don't stop executing autocommands et al
      s->nomove = true;
      return 0;  // exit insert mode
    }
    if (s->c == Ctrl_C && bt_prompt(curbuf)) {
      if (invoke_prompt_interrupt()) {
        if (!bt_prompt(curbuf)) {
          // buffer changed to a non-prompt buffer, get out of
          // Insert mode
          return 0;
        }
        break;
      }
    }

    return 0;  // exit insert mode

  case Ctrl_Z:
    goto normalchar;                // insert CTRL-Z as normal char

  case Ctrl_O:        // execute one command
    if (ctrl_x_mode_omni()) {
      insert_do_complete(s);
      break;
    }

    if (echeck_abbr(Ctrl_O + ABBR_OFF)) {
      break;
    }

    ins_ctrl_o();

    // don't move the cursor left when 'virtualedit' has "onemore".
    if (get_ve_flags(curwin) & kOptVeFlagOnemore) {
      ins_at_eol = false;
      s->nomove = true;
    }

    s->count = 0;
    return 0;  // exit insert mode

  case K_INS:         // toggle insert/replace mode
  case K_KINS:
    ins_insert(s->replaceState);
    break;

  case K_SELECT:      // end of Select mode mapping - ignore
    break;

  case K_HELP:        // Help key works like <ESC> <Help>
  case K_F1:
  case K_XF1:
    stuffcharReadbuff(K_HELP);
    return 0;  // exit insert mode

  case ' ':
    if (mod_mask != MOD_MASK_CTRL) {
      goto normalchar;
    }
    FALLTHROUGH;
  case K_ZERO:        // Insert the previously inserted text.
  case NUL:
  case Ctrl_A:
    // For ^@ the trailing ESC will end the insert, unless there is an
    // error.
    if (stuff_inserted(NUL, 1, (s->c == Ctrl_A)) == FAIL
        && s->c != Ctrl_A) {
      return 0;  // exit insert mode
    }
    s->inserted_space = false;
    break;

  case Ctrl_R:        // insert the contents of a register
    ins_reg();
    auto_format(false, true);
    s->inserted_space = false;
    break;

  case Ctrl_G:        // commands starting with CTRL-G
    ins_ctrl_g();
    break;

  case Ctrl_HAT:      // switch input mode and/or langmap
    ins_ctrl_hat();
    break;

  case Ctrl__:        // switch between languages
    if (!p_ari) {
      goto normalchar;
    }
    ins_ctrl_();
    break;

  case Ctrl_D:        // Make indent one shiftwidth smaller.
    if (ctrl_x_mode_path_defines()) {
      insert_do_complete(s);
      break;
    }
    FALLTHROUGH;

  case Ctrl_T:        // Make indent one shiftwidth greater.
    if (s->c == Ctrl_T && ctrl_x_mode_thesaurus()) {
      if (check_compl_option(false)) {
        insert_do_complete(s);
      }
      break;
    }
    ins_shift(s->c, s->lastc);
    auto_format(false, true);
    s->inserted_space = false;
    break;

  case K_DEL:         // delete character under the cursor
  case K_KDEL:
    ins_del();
    auto_format(false, true);
    break;

  case K_BS:          // delete character before the cursor
  case Ctrl_H:
    s->did_backspace = ins_bs(s->c, BACKSPACE_CHAR, &s->inserted_space);
    auto_format(false, true);
    break;

  case Ctrl_W:        // delete word before the cursor
    if (bt_prompt(curbuf) && (mod_mask & MOD_MASK_SHIFT) == 0) {
      // In a prompt window CTRL-W is used for window commands.
      // Use Shift-CTRL-W to delete a word.
      stuffcharReadbuff(Ctrl_W);
      restart_edit = 'A';
      s->nomove = true;
      s->count = 0;
      return 0;
    }
    s->did_backspace = ins_bs(s->c, BACKSPACE_WORD, &s->inserted_space);
    auto_format(false, true);
    break;

  case Ctrl_U:        // delete all inserted text in current line
    // CTRL-X CTRL-U completes with 'completefunc'.
    if (ctrl_x_mode_function()) {
      insert_do_complete(s);
    } else {
      s->did_backspace = ins_bs(s->c, BACKSPACE_LINE, &s->inserted_space);
      auto_format(false, true);
      s->inserted_space = false;
    }
    break;

  case K_LEFTMOUSE:     // mouse keys
  case K_LEFTMOUSE_NM:
  case K_LEFTDRAG:
  case K_LEFTRELEASE:
  case K_LEFTRELEASE_NM:
  case K_MOUSEMOVE:
  case K_MIDDLEMOUSE:
  case K_MIDDLEDRAG:
  case K_MIDDLERELEASE:
  case K_RIGHTMOUSE:
  case K_RIGHTDRAG:
  case K_RIGHTRELEASE:
  case K_X1MOUSE:
  case K_X1DRAG:
  case K_X1RELEASE:
  case K_X2MOUSE:
  case K_X2DRAG:
  case K_X2RELEASE:
    ins_mouse(s->c);
    break;

  case K_MOUSEDOWN:   // Default action for scroll wheel up: scroll up
    ins_mousescroll(MSCR_DOWN);
    break;

  case K_MOUSEUP:     // Default action for scroll wheel down: scroll down
    ins_mousescroll(MSCR_UP);
    break;

  case K_MOUSELEFT:   // Scroll wheel left
    ins_mousescroll(MSCR_LEFT);
    break;

  case K_MOUSERIGHT:  // Scroll wheel right
    ins_mousescroll(MSCR_RIGHT);
    break;

  case K_IGNORE:      // Something mapped to nothing
    break;

  case K_PASTE_START:
    paste_repeat(1);
    goto check_pum;

  case K_EVENT:       // some event
    state_handle_k_event();
    // If CTRL-G U was used apply it to the next typed key.
    if (dont_sync_undo == kTrue) {
      dont_sync_undo = kNone;
    }
    goto check_pum;

  case K_COMMAND:     // <Cmd>command<CR>
    do_cmdline(NULL, getcmdkeycmd, NULL, 0);
    goto check_pum;

  case K_LUA:
    map_execute_lua(false);

check_pum:
    // nvim_select_popupmenu_item() can be called from the handling of
    // K_EVENT, K_COMMAND, or K_LUA.
    // TODO(bfredl): Not entirely sure this indirection is necessary
    // but doing like this ensures using nvim_select_popupmenu_item is
    // equivalent to selecting the item with a typed key.
    if (pum_want.active) {
      if (pum_visible()) {
        // Set this to NULL so that ins_complete() will update the message.
        edit_submode_extra = NULL;
        insert_do_complete(s);
        if (pum_want.finish) {
          // accept the item and stop completion
          ins_compl_prep(Ctrl_Y);
        }
      }
      pum_want.active = false;
    }

    if (curbuf->b_u_synced) {
      // The K_EVENT, K_COMMAND, or K_LUA caused undo to be synced.
      // Need to save the line for undo before inserting the next char.
      ins_need_undo = true;
    }
    break;

  case K_HOME:        // <Home>
  case K_KHOME:
  case K_S_HOME:
  case K_C_HOME:
    ins_home(s->c);
    break;

  case K_END:         // <End>
  case K_KEND:
  case K_S_END:
  case K_C_END:
    ins_end(s->c);
    break;

  case K_LEFT:        // <Left>
    if (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_CTRL)) {
      ins_s_left();
    } else {
      ins_left();
    }
    break;

  case K_S_LEFT:      // <S-Left>
  case K_C_LEFT:
    ins_s_left();
    break;

  case K_RIGHT:       // <Right>
    if (mod_mask & (MOD_MASK_SHIFT|MOD_MASK_CTRL)) {
      ins_s_right();
    } else {
      ins_right();
    }
    break;

  case K_S_RIGHT:     // <S-Right>
  case K_C_RIGHT:
    ins_s_right();
    break;

  case K_UP:          // <Up>
    if (pum_visible()) {
      insert_do_complete(s);
    } else if (mod_mask & MOD_MASK_SHIFT) {
      ins_pageup();
    } else {
      ins_up(false);
    }
    break;

  case K_S_UP:        // <S-Up>
  case K_PAGEUP:
  case K_KPAGEUP:
    if (pum_visible()) {
      insert_do_complete(s);
    } else {
      ins_pageup();
    }
    break;

  case K_DOWN:        // <Down>
    if (pum_visible()) {
      insert_do_complete(s);
    } else if (mod_mask & MOD_MASK_SHIFT) {
      ins_pagedown();
    } else {
      ins_down(false);
    }
    break;

  case K_S_DOWN:      // <S-Down>
  case K_PAGEDOWN:
  case K_KPAGEDOWN:
    if (pum_visible()) {
      insert_do_complete(s);
    } else {
      ins_pagedown();
    }
    break;

  case K_S_TAB:       // When not mapped, use like a normal TAB
    s->c = TAB;
    FALLTHROUGH;

  case TAB:           // TAB or Complete patterns along path
    if (ctrl_x_mode_path_patterns()) {
      insert_do_complete(s);
      break;
    }
    s->inserted_space = false;
    if (ins_tab()) {
      goto normalchar;                // insert TAB as a normal char
    }
    auto_format(false, true);
    break;

  case K_KENTER:      // <Enter>
    s->c = CAR;
    FALLTHROUGH;
  case CAR:
  case NL:
    // In a quickfix window a <CR> jumps to the error under the
    // cursor.
    if (bt_quickfix(curbuf) && s->c == CAR) {
      if (curwin->w_llist_ref == NULL) {          // quickfix window
        do_cmdline_cmd(".cc");
      } else {                                    // location list window
        do_cmdline_cmd(".ll");
      }
      break;
    }
    if (cmdwin_type != 0) {
      // Execute the command in the cmdline window.
      cmdwin_result = CAR;
      return 0;
    }
    if (bt_prompt(curbuf)) {
      invoke_prompt_callback();
      if (!bt_prompt(curbuf)) {
        // buffer changed to a non-prompt buffer, get out of
        // Insert mode
        return 0;
      }
      break;
    }
    if (!ins_eol(s->c)) {
      return 0;  // out of memory
    }
    auto_format(false, false);
    s->inserted_space = false;
    break;

  case Ctrl_K:        // digraph or keyword completion
    if (ctrl_x_mode_dictionary()) {
      if (check_compl_option(true)) {
        insert_do_complete(s);
      }
      break;
    }

    s->c = ins_digraph();
    if (s->c == NUL) {
      break;
    }
    goto normalchar;

  case Ctrl_X:        // Enter CTRL-X mode
    ins_ctrl_x();
    break;

  case Ctrl_RSB:      // Tag name completion after ^X
    if (!ctrl_x_mode_tags()) {
      goto normalchar;
    } else {
      insert_do_complete(s);
    }
    break;

  case Ctrl_F:        // File name completion after ^X
    if (!ctrl_x_mode_files()) {
      goto normalchar;
    } else {
      insert_do_complete(s);
    }
    break;

  case 's':           // Spelling completion after ^X
  case Ctrl_S:
    if (!ctrl_x_mode_spell()) {
      goto normalchar;
    } else {
      insert_do_complete(s);
    }
    break;

  case Ctrl_L:        // Whole line completion after ^X
    if (!ctrl_x_mode_whole_line()) {
      goto normalchar;
    }
    FALLTHROUGH;

  case Ctrl_P:        // Do previous/next pattern completion
  case Ctrl_N:
    // if 'complete' is empty then plain ^P is no longer special,
    // but it is under other ^X modes
    if (*curbuf->b_p_cpt == NUL
        && (ctrl_x_mode_normal() || ctrl_x_mode_whole_line())
        && !compl_status_local()) {
      goto normalchar;
    }

    insert_do_complete(s);
    break;

  case Ctrl_Y:        // copy from previous line or scroll down
  case Ctrl_E:        // copy from next line or scroll up
    s->c = ins_ctrl_ey(s->c);
    break;

  default:

normalchar:
    // Insert a normal character.

    if (!p_paste) {
      // Trigger InsertCharPre.
      char *str = do_insert_char_pre(s->c);

      if (str != NULL) {
        if (*str != NUL && stop_arrow() != FAIL) {
          // Insert the new value of v:char literally.
          for (char *p = str; *p != NUL; MB_PTR_ADV(p)) {
            s->c = utf_ptr2char(p);
            if (s->c == CAR || s->c == K_KENTER || s->c == NL) {
              ins_eol(s->c);
            } else {
              ins_char(s->c);
            }
          }
          AppendToRedobuffLit(str, -1);
        }
        xfree(str);
        s->c = NUL;
      }

      // If the new value is already inserted or an empty string
      // then don't insert any character.
      if (s->c == NUL) {
        break;
      }
    }
    // Try to perform smart-indenting.
    ins_try_si(s->c);

    if (s->c == ' ') {
      s->inserted_space = true;
      if (inindent(0)) {
        can_cindent = false;
      }
      if (Insstart_blank_vcol == MAXCOL
          && curwin->w_cursor.lnum == Insstart.lnum) {
        Insstart_blank_vcol = get_nolist_virtcol();
      }
    }

    // Insert a normal character and check for abbreviations on a
    // special character.  Let CTRL-] expand abbreviations without
    // inserting it.
    if (vim_iswordc(s->c)
        // Add ABBR_OFF for characters above 0x100, this is
        // what check_abbr() expects.
        || (!echeck_abbr((s->c >= 0x100) ? (s->c + ABBR_OFF) : s->c)
            && s->c != Ctrl_RSB)) {
      insert_special(s->c, false, false);
      revins_legal++;
      revins_chars++;
    }

    auto_format(false, true);

    // When inserting a character the cursor line must never be in a
    // closed fold.
    foldOpenCursor();
    break;
  }       // end of switch (s->c)

  return 1;  // continue
}

static void insert_do_complete(InsertState *s)
{
  compl_busy = true;
  disable_fold_update++;  // don't redraw folds here
  if (ins_complete(s->c, true) == FAIL) {
    compl_status_clear();
  }
  disable_fold_update--;
  compl_busy = false;
  can_si = may_do_si();  // allow smartindenting
}

static void insert_do_cindent(InsertState *s)
{
  // Indent now if a key was typed that is in 'cinkeys'.
  if (in_cinkeys(s->c, ' ', s->line_is_white)) {
    if (stop_arrow() == OK) {
      // re-indent the current line
      do_c_expr_indent();
    }
  }
}

/// edit(): Start inserting text.
///
/// "cmdchar" can be:
/// 'i' normal insert command
/// 'a' normal append command
/// 'R' replace command
/// 'r' "r<CR>" command: insert one <CR>.
///     Note: count can be > 1, for redo, but still only one <CR> is inserted.
///           <Esc> is not used for redo.
/// 'g' "gI" command.
/// 'V' "gR" command for Virtual Replace mode.
/// 'v' "gr" command for single character Virtual Replace mode.
///
/// This function is not called recursively.  For CTRL-O commands, it returns
/// and lets the caller handle the Normal-mode command.
///
/// @param  cmdchar  command that started the insert
/// @param  startln  if true, insert at start of line
/// @param  count    repeat count for the command
///
/// @return true if a CTRL-O command caused the return (insert mode pending).
bool edit(int cmdchar, bool startln, int count)
{
  if (curbuf->terminal) {
    if (ex_normal_busy) {
      // Do not enter terminal mode from ex_normal(), which would cause havoc
      // (such as terminal-mode recursiveness). Instead set a flag to force-set
      // the value of `restart_edit` before `ex_normal` returns.
      restart_edit = 'i';
      force_restart_edit = true;
      return false;
    }
    return terminal_enter();
  }

  // Don't allow inserting in the sandbox.
  if (sandbox != 0) {
    emsg(_(e_sandbox));
    return false;
  }

  // Don't allow changes in the buffer while editing the cmdline.  The
  // caller of getcmdline() may get confused.
  // Don't allow recursive insert mode when busy with completion.
  // Allow in dummy buffers since they are only used internally
  if (textlock != 0 || ins_compl_active() || compl_busy || pum_visible()
      || expr_map_locked()) {
    emsg(_(e_textlock));
    return false;
  }

  InsertState s[1];
  memset(s, 0, sizeof(InsertState));
  s->state.execute = insert_execute;
  s->state.check = insert_check;
  s->cmdchar = cmdchar;
  s->startln = startln;
  s->count = count;
  insert_enter(s);
  return s->c == Ctrl_O;
}

bool ins_need_undo_get(void)
{
  return ins_need_undo;
}

/// Redraw for Insert mode.
/// This is postponed until getting the next character to make '$' in the 'cpo'
/// option work correctly.
/// Only redraw when there are no characters available.  This speeds up
/// inserting sequences of characters (e.g., for CTRL-R).
///
/// @param ready  not busy with something
void ins_redraw(bool ready)
{
  if (char_avail()) {
    return;
  }

  // Trigger CursorMoved if the cursor moved.  Not when the popup menu is
  // visible, the command might delete it.
  if (ready && has_event(EVENT_CURSORMOVEDI)
      && (last_cursormoved_win != curwin
          || !equalpos(last_cursormoved, curwin->w_cursor))
      && !pum_visible()) {
    // Need to update the screen first, to make sure syntax
    // highlighting is correct after making a change (e.g., inserting
    // a "(".  The autocommand may also require a redraw, so it's done
    // again below, unfortunately.
    if (syntax_present(curwin) && must_redraw) {
      update_screen();
    }
    // Make sure curswant is correct, an autocommand may call
    // getcurpos()
    update_curswant();
    ins_apply_autocmds(EVENT_CURSORMOVEDI);
    last_cursormoved_win = curwin;
    last_cursormoved = curwin->w_cursor;
  }

  // Trigger TextChangedI if changedtick_i differs.
  if (ready && has_event(EVENT_TEXTCHANGEDI)
      && curbuf->b_last_changedtick_i != buf_get_changedtick(curbuf)
      && !pum_visible()) {
    aco_save_T aco;
    varnumber_T tick = buf_get_changedtick(curbuf);

    // save and restore curwin and curbuf, in case the autocmd changes them
    aucmd_prepbuf(&aco, curbuf);
    apply_autocmds(EVENT_TEXTCHANGEDI, NULL, NULL, false, curbuf);
    aucmd_restbuf(&aco);
    curbuf->b_last_changedtick_i = buf_get_changedtick(curbuf);
    if (tick != buf_get_changedtick(curbuf)) {  // see ins_apply_autocmds()
      u_save(curwin->w_cursor.lnum,
             (linenr_T)(curwin->w_cursor.lnum + 1));
    }
  }

  // Trigger TextChangedP if changedtick_pum differs. When the popupmenu
  // closes TextChangedI will need to trigger for backwards compatibility,
  // thus use different b_last_changedtick* variables.
  if (ready && has_event(EVENT_TEXTCHANGEDP)
      && curbuf->b_last_changedtick_pum != buf_get_changedtick(curbuf)
      && pum_visible()) {
    aco_save_T aco;
    varnumber_T tick = buf_get_changedtick(curbuf);

    // save and restore curwin and curbuf, in case the autocmd changes them
    aucmd_prepbuf(&aco, curbuf);
    apply_autocmds(EVENT_TEXTCHANGEDP, NULL, NULL, false, curbuf);
    aucmd_restbuf(&aco);
    curbuf->b_last_changedtick_pum = buf_get_changedtick(curbuf);
    if (tick != buf_get_changedtick(curbuf)) {  // see ins_apply_autocmds()
      u_save(curwin->w_cursor.lnum,
             (linenr_T)(curwin->w_cursor.lnum + 1));
    }
  }

  if (ready) {
    may_trigger_win_scrolled_resized();
  }

  // Trigger BufModified if b_changed_invalid is set.
  if (ready && has_event(EVENT_BUFMODIFIEDSET)
      && curbuf->b_changed_invalid == true
      && !pum_visible()) {
    apply_autocmds(EVENT_BUFMODIFIEDSET, NULL, NULL, false, curbuf);
    curbuf->b_changed_invalid = false;
  }

  // Trigger SafeState if nothing is pending.
  may_trigger_safestate(ready
                        && !ins_compl_active()
                        && !pum_visible());

  pum_check_clear();
  show_cursor_info_later(false);
  if (must_redraw) {
    update_screen();
  } else {
    redraw_statuslines();
    if (clear_cmdline || redraw_cmdline || redraw_mode) {
      showmode();  // clear cmdline and show mode
    }
  }
  setcursor();
  emsg_on_display = false;      // may remove error message now
}

// Handle a CTRL-V or CTRL-Q typed in Insert mode.
static void ins_ctrl_v(void)
{
  bool did_putchar = false;

  // may need to redraw when no more chars available now
  ins_redraw(false);

  if (redrawing() && !char_avail()) {
    edit_putchar('^', true);
    did_putchar = true;
  }
  AppendToRedobuff(CTRL_V_STR);

  add_to_showcmd_c(Ctrl_V);

  // Do not include modifiers into the key for CTRL-SHIFT-V.
  int c = get_literal(mod_mask & MOD_MASK_SHIFT);
  if (did_putchar) {
    // when the line fits in 'columns' the '^' is at the start of the next
    // line and will not removed by the redraw
    edit_unputchar();
  }
  clear_showcmd();
  insert_special(c, true, true);
  revins_chars++;
  revins_legal++;
}

// Put a character directly onto the screen.  It's not stored in a buffer.
// Used while handling CTRL-K, CTRL-V, etc. in Insert mode.
static int pc_status;
#define PC_STATUS_UNSET 0  // nothing was put on screen
#define PC_STATUS_RIGHT 1  // right half of double-wide char
#define PC_STATUS_LEFT  2  // left half of double-wide char
#define PC_STATUS_SET   3  // pc_schar was filled
static schar_T pc_schar;   // saved char
static int pc_attr;
static int pc_row;
static int pc_col;

void edit_putchar(int c, bool highlight)
{
  if (curwin->w_grid_alloc.chars == NULL && default_grid.chars == NULL) {
    return;
  }

  int attr;
  update_topline(curwin);  // just in case w_topline isn't valid
  validate_cursor(curwin);
  if (highlight) {
    attr = HL_ATTR(HLF_8);
  } else {
    attr = 0;
  }
  pc_row = curwin->w_wrow;
  pc_status = PC_STATUS_UNSET;
  grid_line_start(&curwin->w_grid, pc_row);
  if (curwin->w_p_rl) {
    pc_col = curwin->w_grid.cols - 1 - curwin->w_wcol;

    if (grid_line_getchar(pc_col, NULL) == NUL) {
      grid_line_put_schar(pc_col - 1, schar_from_ascii(' '), attr);
      curwin->w_wcol--;
      pc_status = PC_STATUS_RIGHT;
    }
  } else {
    pc_col = curwin->w_wcol;

    if (grid_line_getchar(pc_col + 1, NULL) == NUL) {
      // pc_col is the left half of a double-width char
      pc_status = PC_STATUS_LEFT;
    }
  }

  // save the character to be able to put it back
  if (pc_status == PC_STATUS_UNSET) {
    pc_schar = grid_line_getchar(pc_col, &pc_attr);
    pc_status = PC_STATUS_SET;
  }

  char buf[MB_MAXCHAR + 1];
  grid_line_puts(pc_col, buf, utf_char2bytes(c, buf), attr);
  grid_line_flush();
}

/// @return    the effective prompt for the specified buffer.
char *buf_prompt_text(const buf_T *const buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (buf->b_prompt_text == NULL) {
    return "% ";
  }
  return buf->b_prompt_text;
}

/// @return  the effective prompt for the current buffer.
char *prompt_text(void)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  return buf_prompt_text(curbuf);
}

// Prepare for prompt mode: Make sure the last line has the prompt text.
// Move the cursor to this line.
static void init_prompt(int cmdchar_todo)
{
  char *prompt = prompt_text();

  curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  char *text = get_cursor_line_ptr();
  if (strncmp(text, prompt, strlen(prompt)) != 0) {
    // prompt is missing, insert it or append a line with it
    if (*text == NUL) {
      ml_replace(curbuf->b_ml.ml_line_count, prompt, true);
    } else {
      ml_append(curbuf->b_ml.ml_line_count, prompt, 0, false);
    }
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    coladvance(curwin, MAXCOL);
    inserted_bytes(curbuf->b_ml.ml_line_count, 0, 0, (colnr_T)strlen(prompt));
  }

  // Insert always starts after the prompt, allow editing text after it.
  if (Insstart_orig.lnum != curwin->w_cursor.lnum || Insstart_orig.col != (colnr_T)strlen(prompt)) {
    Insstart.lnum = curwin->w_cursor.lnum;
    Insstart.col = (colnr_T)strlen(prompt);
    Insstart_orig = Insstart;
    Insstart_textlen = Insstart.col;
    Insstart_blank_vcol = MAXCOL;
    arrow_used = false;
  }

  if (cmdchar_todo == 'A') {
    coladvance(curwin, MAXCOL);
  }
  curwin->w_cursor.col = MAX(curwin->w_cursor.col, (colnr_T)strlen(prompt));
  // Make sure the cursor is in a valid position.
  check_cursor(curwin);
}

/// @return  true if the cursor is in the editable position of the prompt line.
bool prompt_curpos_editable(void)
  FUNC_ATTR_PURE
{
  return curwin->w_cursor.lnum == curbuf->b_ml.ml_line_count
         && curwin->w_cursor.col >= (int)strlen(prompt_text());
}

// Undo the previous edit_putchar().
void edit_unputchar(void)
{
  if (pc_status != PC_STATUS_UNSET) {
    if (pc_status == PC_STATUS_RIGHT) {
      curwin->w_wcol++;
    }
    if (pc_status == PC_STATUS_RIGHT || pc_status == PC_STATUS_LEFT) {
      redrawWinline(curwin, curwin->w_cursor.lnum);
    } else {
      // TODO(bfredl): this could be smarter and also handle the dubyawidth case
      grid_line_start(&curwin->w_grid, pc_row);
      grid_line_put_schar(pc_col, pc_schar, pc_attr);
      grid_line_flush();
    }
  }
}

/// Called when "$" is in 'cpoptions': display a '$' at the end of the changed
/// text.  Only works when cursor is in the line that changes.
void display_dollar(colnr_T col_arg)
{
  colnr_T col = MAX(col_arg, 0);

  if (!redrawing()) {
    return;
  }

  colnr_T save_col = curwin->w_cursor.col;
  curwin->w_cursor.col = col;

  // If on the last byte of a multi-byte move to the first byte.
  char *p = get_cursor_line_ptr();
  curwin->w_cursor.col -= utf_head_off(p, p + col);
  curs_columns(curwin, false);              // Recompute w_wrow and w_wcol
  if (curwin->w_wcol < curwin->w_grid.cols) {
    edit_putchar('$', false);
    dollar_vcol = curwin->w_virtcol;
  }
  curwin->w_cursor.col = save_col;
}

// Call this function before moving the cursor from the normal insert position
// in insert mode.
void undisplay_dollar(void)
{
  if (dollar_vcol < 0) {
    return;
  }

  dollar_vcol = -1;
  redrawWinline(curwin, curwin->w_cursor.lnum);
}

/// Insert an indent (for <Tab> or CTRL-T) or delete an indent (for CTRL-D).
/// Keep the cursor on the same character.
/// type == INDENT_INC   increase indent (for CTRL-T or <Tab>)
/// type == INDENT_DEC   decrease indent (for CTRL-D)
/// type == INDENT_SET   set indent to "amount"
///
/// @param round               if true, round the indent to 'shiftwidth' (only with _INC and _Dec).
/// @param call_changed_bytes  call changed_bytes()
void change_indent(int type, int amount, int round, bool call_changed_bytes)
{
  int insstart_less;                    // reduction for Insstart.col
  colnr_T orig_col = 0;                 // init for GCC
  char *orig_line = NULL;     // init for GCC

  // MODE_VREPLACE state needs to know what the line was like before changing
  if (State & VREPLACE_FLAG) {
    orig_line = xstrdup(get_cursor_line_ptr());   // Deal with NULL below
    orig_col = curwin->w_cursor.col;
  }

  // for the following tricks we don't want list mode
  int save_p_list = curwin->w_p_list;
  curwin->w_p_list = false;
  colnr_T vc = getvcol_nolist(&curwin->w_cursor);
  int vcol = vc;

  // For Replace mode we need to fix the replace stack later, which is only
  // possible when the cursor is in the indent.  Remember the number of
  // characters before the cursor if it's possible.
  int start_col = curwin->w_cursor.col;

  // determine offset from first non-blank
  int new_cursor_col = curwin->w_cursor.col;
  beginline(BL_WHITE);
  new_cursor_col -= curwin->w_cursor.col;

  insstart_less = curwin->w_cursor.col;

  // If the cursor is in the indent, compute how many screen columns the
  // cursor is to the left of the first non-blank.
  if (new_cursor_col < 0) {
    vcol = get_indent() - vcol;
  }

  if (new_cursor_col > 0) {         // can't fix replace stack
    start_col = -1;
  }

  // Set the new indent.  The cursor will be put on the first non-blank.
  if (type == INDENT_SET) {
    set_indent(amount, call_changed_bytes ? SIN_CHANGED : 0);
  } else {
    int save_State = State;

    // Avoid being called recursively.
    if (State & VREPLACE_FLAG) {
      State = MODE_INSERT;
    }
    shift_line(type == INDENT_DEC, round, 1, call_changed_bytes);
    State = save_State;
  }
  insstart_less -= curwin->w_cursor.col;

  // Try to put cursor on same character.
  // If the cursor is at or after the first non-blank in the line,
  // compute the cursor column relative to the column of the first
  // non-blank character.
  // If we are not in insert mode, leave the cursor on the first non-blank.
  // If the cursor is before the first non-blank, position it relative
  // to the first non-blank, counted in screen columns.
  if (new_cursor_col >= 0) {
    // When changing the indent while the cursor is touching it, reset
    // Insstart_col to 0.
    if (new_cursor_col == 0) {
      insstart_less = MAXCOL;
    }
    new_cursor_col += curwin->w_cursor.col;
  } else if (!(State & MODE_INSERT)) {
    new_cursor_col = curwin->w_cursor.col;
  } else {
    // Compute the screen column where the cursor should be.
    vcol = get_indent() - vcol;
    int const end_vcol = (colnr_T)((vcol < 0) ? 0 : vcol);
    curwin->w_virtcol = end_vcol;

    // Advance the cursor until we reach the right screen column.
    new_cursor_col = 0;
    char *const line = get_cursor_line_ptr();
    vcol = 0;
    if (*line != NUL) {
      CharsizeArg csarg;
      CSType cstype = init_charsize_arg(&csarg, curwin, 0, line);
      StrCharInfo ci = utf_ptr2StrCharInfo(line);
      while (true) {
        int next_vcol = vcol + win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
        if (next_vcol > end_vcol) {
          break;
        }
        vcol = next_vcol;
        ci = utfc_next(ci);
        if (*ci.ptr == NUL) {
          break;
        }
      }
      new_cursor_col = (int)(ci.ptr - line);
    }

    // May need to insert spaces to be able to position the cursor on
    // the right screen column.
    if (vcol != (int)curwin->w_virtcol) {
      curwin->w_cursor.col = (colnr_T)new_cursor_col;
      size_t i = (size_t)(curwin->w_virtcol - vcol);
      char *ptr = xmallocz(i);
      memset(ptr, ' ', i);
      new_cursor_col += (int)i;
      ins_str(ptr);
      xfree(ptr);
    }

    // When changing the indent while the cursor is in it, reset
    // Insstart_col to 0.
    insstart_less = MAXCOL;
  }

  curwin->w_p_list = save_p_list;
  curwin->w_cursor.col = MAX(0, (colnr_T)new_cursor_col);
  curwin->w_set_curswant = true;
  changed_cline_bef_curs(curwin);

  // May have to adjust the start of the insert.
  if (State & MODE_INSERT) {
    if (curwin->w_cursor.lnum == Insstart.lnum && Insstart.col != 0) {
      if ((int)Insstart.col <= insstart_less) {
        Insstart.col = 0;
      } else {
        Insstart.col -= insstart_less;
      }
    }
    if ((int)ai_col <= insstart_less) {
      ai_col = 0;
    } else {
      ai_col -= insstart_less;
    }
  }

  // For MODE_REPLACE state, may have to fix the replace stack, if it's
  // possible.  If the number of characters before the cursor decreased, need
  // to pop a few characters from the replace stack.
  // If the number of characters before the cursor increased, need to push a
  // few NULs onto the replace stack.
  if (REPLACE_NORMAL(State) && start_col >= 0) {
    while (start_col > (int)curwin->w_cursor.col) {
      replace_join(0);              // remove a NUL from the replace stack
      start_col--;
    }
    while (start_col < (int)curwin->w_cursor.col) {
      replace_push_nul();
      start_col++;
    }
  }

  // For MODE_VREPLACE state, we also have to fix the replace stack.  In this
  // case it is always possible because we backspace over the whole line and
  // then put it back again the way we wanted it.
  if (State & VREPLACE_FLAG) {
    // Save new line
    char *new_line = xstrdup(get_cursor_line_ptr());

    // We only put back the new line up to the cursor
    new_line[curwin->w_cursor.col] = NUL;
    int new_col = curwin->w_cursor.col;

    // Put back original line
    ml_replace(curwin->w_cursor.lnum, orig_line, false);
    curwin->w_cursor.col = orig_col;

    curbuf_splice_pending++;

    // Backspace from cursor to start of line
    backspace_until_column(0);

    // Insert new stuff into line again
    ins_bytes(new_line);

    xfree(new_line);

    curbuf_splice_pending--;

    // TODO(bfredl): test for crazy edge cases, like we stand on a TAB or
    // something? does this even do the right text change then?
    int delta = orig_col - new_col;
    extmark_splice_cols(curbuf, (int)curwin->w_cursor.lnum - 1, new_col,
                        delta < 0 ? -delta : 0,
                        delta > 0 ? delta : 0,
                        kExtmarkUndo);
  }
}

/// Truncate the space at the end of a line.  This is to be used only in an
/// insert mode.  It handles fixing the replace stack for MODE_REPLACE and
/// MODE_VREPLACE modes.
void truncate_spaces(char *line)
{
  int i;

  // find start of trailing white space
  for (i = (int)strlen(line) - 1; i >= 0 && ascii_iswhite(line[i]); i--) {
    if (State & REPLACE_FLAG) {
      replace_join(0);              // remove a NUL from the replace stack
    }
  }
  line[i + 1] = NUL;
}

/// Backspace the cursor until the given column.  Handles MODE_REPLACE and
/// MODE_VREPLACE modes correctly.  May also be used when not in insert mode at
/// all.  Will attempt not to go before "col" even when there is a composing
/// character.
void backspace_until_column(int col)
{
  while ((int)curwin->w_cursor.col > col) {
    curwin->w_cursor.col--;
    if (State & REPLACE_FLAG) {
      replace_do_bs(col);
    } else if (!del_char_after_col(col)) {
      break;
    }
  }
}

/// Like del_char(), but make sure not to go before column "limit_col".
/// Only matters when there are composing characters.
///
/// @param  limit_col  only delete the character if it is after this column
//
/// @return true when something was deleted.
static bool del_char_after_col(int limit_col)
{
  if (limit_col >= 0) {
    colnr_T ecol = curwin->w_cursor.col + 1;

    // Make sure the cursor is at the start of a character, but
    // skip forward again when going too far back because of a
    // composing character.
    mb_adjust_cursor();
    while (curwin->w_cursor.col < (colnr_T)limit_col) {
      int l = utf_ptr2len(get_cursor_pos_ptr());

      if (l == 0) {  // end of line
        break;
      }
      curwin->w_cursor.col += l;
    }
    if (*get_cursor_pos_ptr() == NUL || curwin->w_cursor.col == ecol) {
      return false;
    }
    del_bytes(ecol - curwin->w_cursor.col, false, true);
  } else {
    del_char(false);
  }
  return true;
}

/// Next character is interpreted literally.
/// A one, two or three digit decimal number is interpreted as its byte value.
/// If one or two digits are entered, the next character is given to vungetc().
/// For Unicode a character > 255 may be returned.
///
/// @param  no_simplify  do not include modifiers into the key
int get_literal(bool no_simplify)
{
  int nc;
  bool hex = false;
  bool octal = false;
  int unicode = 0;

  if (got_int) {
    return Ctrl_C;
  }

  no_mapping++;                 // don't map the next key hits
  int cc = 0;
  int i = 0;
  while (true) {
    nc = plain_vgetc();
    if (!no_simplify) {
      nc = merge_modifiers(nc, &mod_mask);
    }
    if ((mod_mask & ~MOD_MASK_SHIFT) != 0) {
      // A character with non-Shift modifiers should not be a valid
      // character for i_CTRL-V_digit.
      break;
    }
    if ((State & MODE_CMDLINE) == 0 && MB_BYTE2LEN_CHECK(nc) == 1) {
      add_to_showcmd(nc);
    }
    if (nc == 'x' || nc == 'X') {
      hex = true;
    } else if (nc == 'o' || nc == 'O') {
      octal = true;
    } else if (nc == 'u' || nc == 'U') {
      unicode = nc;
    } else {
      if (hex
          || unicode != 0) {
        if (!ascii_isxdigit(nc)) {
          break;
        }
        cc = cc * 16 + hex2nr(nc);
      } else if (octal) {
        if (nc < '0' || nc > '7') {
          break;
        }
        cc = cc * 8 + nc - '0';
      } else {
        if (!ascii_isdigit(nc)) {
          break;
        }
        cc = cc * 10 + nc - '0';
      }

      i++;
    }

    if (cc > 255
        && unicode == 0) {
      cc = 255;                 // limit range to 0-255
    }
    nc = 0;

    if (hex) {                  // hex: up to two chars
      if (i >= 2) {
        break;
      }
    } else if (unicode) {     // Unicode: up to four or eight chars
      if ((unicode == 'u' && i >= 4) || (unicode == 'U' && i >= 8)) {
        break;
      }
    } else if (i >= 3) {        // decimal or octal: up to three chars
      break;
    }
  }
  if (i == 0) {     // no number entered
    if (nc == K_ZERO) {     // NUL is stored as NL
      cc = '\n';
      nc = 0;
    } else {
      cc = nc;
      nc = 0;
    }
  }

  if (cc == 0) {        // NUL is stored as NL
    cc = '\n';
  }

  no_mapping--;
  if (nc) {
    vungetc(nc);
    // A character typed with i_CTRL-V_digit cannot have modifiers.
    mod_mask = 0;
  }
  got_int = false;          // CTRL-C typed after CTRL-V is not an interrupt
  return cc;
}

/// Insert character, taking care of special keys and mod_mask
///
/// @param ctrlv `c` was typed after CTRL-V
static void insert_special(int c, int allow_modmask, int ctrlv)
{
  // Special function key, translate into "<Key>". Up to the last '>' is
  // inserted with ins_str(), so as not to replace characters in replace
  // mode.
  // Only use mod_mask for special keys, to avoid things like <S-Space>,
  // unless 'allow_modmask' is true.
  if (mod_mask & MOD_MASK_CMD) {  // Command-key never produces a normal key.
    allow_modmask = true;
  }
  if (IS_SPECIAL(c) || (mod_mask && allow_modmask)) {
    char *p = get_special_key_name(c, mod_mask);
    int len = (int)strlen(p);
    c = (uint8_t)p[len - 1];
    if (len > 2) {
      if (stop_arrow() == FAIL) {
        return;
      }
      p[len - 1] = NUL;
      ins_str(p);
      AppendToRedobuffLit(p, -1);
      ctrlv = false;
    }
  }
  if (stop_arrow() == OK) {
    insertchar(c, ctrlv ? INSCHAR_CTRLV : 0, -1);
  }
}

// Special characters in this context are those that need processing other
// than the simple insertion that can be performed here. This includes ESC
// which terminates the insert, and CR/NL which need special processing to
// open up a new line. This routine tries to optimize insertions performed by
// the "redo", "undo" or "put" commands, so it needs to know when it should
// stop and defer processing to the "normal" mechanism.
// '0' and '^' are special, because they can be followed by CTRL-D.
#define ISSPECIAL(c)   ((c) < ' ' || (c) >= DEL || (c) == '0' || (c) == '^')

/// "flags": INSCHAR_FORMAT - force formatting
///          INSCHAR_CTRLV  - char typed just after CTRL-V
///          INSCHAR_NO_FEX - don't use 'formatexpr'
///
///   NOTE: passes the flags value straight through to internal_format() which,
///         beside INSCHAR_FORMAT (above), is also looking for these:
///          INSCHAR_DO_COM   - format comments
///          INSCHAR_COM_LIST - format comments with num list or 2nd line indent
///
/// @param c              character to insert or NUL
/// @param flags          INSCHAR_FORMAT, etc.
/// @param second_indent  indent for second line if >= 0
void insertchar(int c, int flags, int second_indent)
{
  char *p;
  int force_format = flags & INSCHAR_FORMAT;

  const int textwidth = comp_textwidth(force_format);
  const bool fo_ins_blank = has_format_option(FO_INS_BLANK);

  // Try to break the line in two or more pieces when:
  // - Always do this if we have been called to do formatting only.
  // - Always do this when 'formatoptions' has the 'a' flag and the line
  //   ends in white space.
  // - Otherwise:
  //     - Don't do this if inserting a blank
  //     - Don't do this if an existing character is being replaced, unless
  //       we're in MODE_VREPLACE state.
  //     - Do this if the cursor is not on the line where insert started
  //     or - 'formatoptions' doesn't have 'l' or the line was not too long
  //           before the insert.
  //        - 'formatoptions' doesn't have 'b' or a blank was inserted at or
  //          before 'textwidth'
  if (textwidth > 0
      && (force_format
          || (!ascii_iswhite(c)
              && !((State & REPLACE_FLAG)
                   && !(State & VREPLACE_FLAG)
                   && *get_cursor_pos_ptr() != NUL)
              && (curwin->w_cursor.lnum != Insstart.lnum
                  || ((!has_format_option(FO_INS_LONG)
                       || Insstart_textlen <= (colnr_T)textwidth)
                      && (!fo_ins_blank
                          || Insstart_blank_vcol <= (colnr_T)textwidth)))))) {
    // Format with 'formatexpr' when it's set.  Use internal formatting
    // when 'formatexpr' isn't set or it returns non-zero.
    bool do_internal = true;
    colnr_T virtcol = get_nolist_virtcol()
                      + char2cells(c != NUL ? c : gchar_cursor());

    if (*curbuf->b_p_fex != NUL && (flags & INSCHAR_NO_FEX) == 0
        && (force_format || virtcol > (colnr_T)textwidth)) {
      do_internal = (fex_format(curwin->w_cursor.lnum, 1, c) != 0);
      // It may be required to save for undo again, e.g. when setline()
      // was called.
      ins_need_undo = true;
    }
    if (do_internal) {
      internal_format(textwidth, second_indent, flags, c == NUL, c);
    }
  }

  if (c == NUL) {           // only formatting was wanted
    return;
  }

  // Check whether this character should end a comment.
  if (did_ai && c == end_comment_pending) {
    char lead_end[COM_MAX_LEN];  // end-comment string

    // Need to remove existing (middle) comment leader and insert end
    // comment leader.  First, check what comment leader we can find.
    char *line = get_cursor_line_ptr();
    int i = get_leader_len(line, &p, false, true);
    if (i > 0 && vim_strchr(p, COM_MIDDLE) != NULL) {  // Just checking
      // Skip middle-comment string
      while (*p && p[-1] != ':') {  // find end of middle flags
        p++;
      }
      int middle_len = (int)copy_option_part(&p, lead_end, COM_MAX_LEN, ",");
      // Don't count trailing white space for middle_len
      while (middle_len > 0 && ascii_iswhite(lead_end[middle_len - 1])) {
        middle_len--;
      }

      // Find the end-comment string
      while (*p && p[-1] != ':') {  // find end of end flags
        p++;
      }
      int end_len = (int)copy_option_part(&p, lead_end, COM_MAX_LEN, ",");

      // Skip white space before the cursor
      i = curwin->w_cursor.col;
      while (--i >= 0 && ascii_iswhite(line[i])) {}
      i++;

      // Skip to before the middle leader
      i -= middle_len;

      // Check some expected things before we go on
      if (i >= 0 && (uint8_t)lead_end[end_len - 1] == end_comment_pending) {
        // Backspace over all the stuff we want to replace
        backspace_until_column(i);

        // Insert the end-comment string, except for the last
        // character, which will get inserted as normal later.
        ins_bytes_len(lead_end, (size_t)(end_len - 1));
      }
    }
  }
  end_comment_pending = NUL;

  did_ai = false;
  did_si = false;
  can_si = false;
  can_si_back = false;

  // If there's any pending input, grab up to INPUT_BUFLEN at once.
  // This speeds up normal text input considerably.
  // Don't do this when 'cindent' or 'indentexpr' is set, because we might
  // need to re-indent at a ':', or any other character (but not what
  // 'paste' is set)..
  // Don't do this when there an InsertCharPre autocommand is defined,
  // because we need to fire the event for every character.
  // Do the check for InsertCharPre before the call to vpeekc() because the
  // InsertCharPre autocommand could change the input buffer.
  if (!ISSPECIAL(c)
      && (utf_char2len(c) == 1)
      && !has_event(EVENT_INSERTCHARPRE)
      && vpeekc() != NUL
      && !(State & REPLACE_FLAG)
      && !cindent_on()
      && !p_ri) {
#define INPUT_BUFLEN 100
    char buf[INPUT_BUFLEN + 1];
    colnr_T virtcol = 0;

    buf[0] = (char)c;
    int i = 1;
    if (textwidth > 0) {
      virtcol = get_nolist_virtcol();
    }
    // Stop the string when:
    // - no more chars available
    // - finding a special character (command key)
    // - buffer is full
    // - running into the 'textwidth' boundary
    // - need to check for abbreviation: A non-word char after a word-char
    while ((c = vpeekc()) != NUL
           && !ISSPECIAL(c)
           && MB_BYTE2LEN(c) == 1
           && i < INPUT_BUFLEN
           && (textwidth == 0
               || (virtcol += byte2cells((uint8_t)buf[i - 1])) < (colnr_T)textwidth)
           && !(!no_abbr && !vim_iswordc(c) && vim_iswordc((uint8_t)buf[i - 1]))) {
      c = vgetc();
      buf[i++] = (char)c;
    }

    do_digraph(-1);                     // clear digraphs
    do_digraph((uint8_t)buf[i - 1]);               // may be the start of a digraph
    buf[i] = NUL;
    ins_str(buf);
    if (flags & INSCHAR_CTRLV) {
      redo_literal((uint8_t)(*buf));
      i = 1;
    } else {
      i = 0;
    }
    if (buf[i] != NUL) {
      AppendToRedobuffLit(buf + i, -1);
    }
  } else {
    int cc;

    if ((cc = utf_char2len(c)) > 1) {
      char buf[MB_MAXCHAR + 1];

      utf_char2bytes(c, buf);
      buf[cc] = NUL;
      ins_char_bytes(buf, (size_t)cc);
      AppendCharToRedobuff(c);
    } else {
      ins_char(c);
      if (flags & INSCHAR_CTRLV) {
        redo_literal(c);
      } else {
        AppendCharToRedobuff(c);
      }
    }
  }
}

// Put a character in the redo buffer, for when just after a CTRL-V.
static void redo_literal(int c)
{
  char buf[10];

  // Only digits need special treatment.  Translate them into a string of
  // three digits.
  if (ascii_isdigit(c)) {
    vim_snprintf(buf, sizeof(buf), "%03d", c);
    AppendToRedobuff(buf);
  } else {
    AppendCharToRedobuff(c);
  }
}

/// start_arrow() is called when an arrow key is used in insert mode.
/// For undo/redo it resembles hitting the <ESC> key.
///
/// @param end_insert_pos  can be NULL
void start_arrow(pos_T *end_insert_pos)
{
  start_arrow_common(end_insert_pos, true);
}

/// Like start_arrow() but with end_change argument.
/// Will prepare for redo of CTRL-G U if "end_change" is false.
///
/// @param end_insert_pos  can be NULL
/// @param end_change      end undoable change
static void start_arrow_with_change(pos_T *end_insert_pos, bool end_change)
{
  start_arrow_common(end_insert_pos, end_change);
  if (!end_change) {
    AppendCharToRedobuff(Ctrl_G);
    AppendCharToRedobuff('U');
  }
}

/// @param end_insert_pos  can be NULL
/// @param end_change      end undoable change
static void start_arrow_common(pos_T *end_insert_pos, bool end_change)
{
  if (!arrow_used && end_change) {  // something has been inserted
    AppendToRedobuff(ESC_STR);
    stop_insert(end_insert_pos, false, false);
    arrow_used = true;  // This means we stopped the current insert.
  }
  check_spell_redraw();
}

// If we skipped highlighting word at cursor, do it now.
// It may be skipped again, thus reset spell_redraw_lnum first.
static void check_spell_redraw(void)
{
  if (spell_redraw_lnum != 0) {
    linenr_T lnum = spell_redraw_lnum;

    spell_redraw_lnum = 0;
    redrawWinline(curwin, lnum);
  }
}

// stop_arrow() is called before a change is made in insert mode.
// If an arrow key has been used, start a new insertion.
// Returns FAIL if undo is impossible, shouldn't insert then.
int stop_arrow(void)
{
  if (arrow_used) {
    Insstart = curwin->w_cursor;  // new insertion starts here
    if (Insstart.col > Insstart_orig.col && !ins_need_undo) {
      // Don't update the original insert position when moved to the
      // right, except when nothing was inserted yet.
      update_Insstart_orig = false;
    }
    Insstart_textlen = linetabsize_str(get_cursor_line_ptr());

    if (u_save_cursor() == OK) {
      arrow_used = false;
      ins_need_undo = false;
    }
    ai_col = 0;
    if (State & VREPLACE_FLAG) {
      orig_line_count = curbuf->b_ml.ml_line_count;
      vr_lines_changed = 1;
    }
    ResetRedobuff();
    AppendToRedobuff("1i");  // Pretend we start an insertion.
    new_insert_skip = 2;
  } else if (ins_need_undo) {
    if (u_save_cursor() == OK) {
      ins_need_undo = false;
    }
  }

  // Always open fold at the cursor line when inserting something.
  foldOpenCursor();

  return arrow_used || ins_need_undo ? FAIL : OK;
}

/// Do a few things to stop inserting.
/// "end_insert_pos" is where insert ended.  It is NULL when we already jumped
/// to another window/buffer.
///
/// @param esc     called by ins_esc()
/// @param nomove  <c-\><c-o>, don't move cursor
static void stop_insert(pos_T *end_insert_pos, int esc, int nomove)
{
  stop_redo_ins();
  kv_destroy(replace_stack);  // abandon replace stack (reinitializes)

  // Save the inserted text for later redo with ^@ and CTRL-A.
  // Don't do it when "restart_edit" was set and nothing was inserted,
  // otherwise CTRL-O w and then <Left> will clear "last_insert".
  char *ptr = get_inserted();
  int added = ptr == NULL ? 0 : (int)strlen(ptr) - new_insert_skip;
  if (did_restart_edit == 0 || added > 0) {
    xfree(last_insert);
    last_insert = ptr;
    last_insert_skip = added < 0 ? 0 : new_insert_skip;
  } else {
    xfree(ptr);
  }

  if (!arrow_used && end_insert_pos != NULL) {
    int cc;
    // Auto-format now.  It may seem strange to do this when stopping an
    // insertion (or moving the cursor), but it's required when appending
    // a line and having it end in a space.  But only do it when something
    // was actually inserted, otherwise undo won't work.
    if (!ins_need_undo && has_format_option(FO_AUTO)) {
      pos_T tpos = curwin->w_cursor;

      // When the cursor is at the end of the line after a space the
      // formatting will move it to the following word.  Avoid that by
      // moving the cursor onto the space.
      cc = 'x';
      if (curwin->w_cursor.col > 0 && gchar_cursor() == NUL) {
        dec_cursor();
        cc = gchar_cursor();
        if (!ascii_iswhite(cc)) {
          curwin->w_cursor = tpos;
        }
      }

      auto_format(true, false);

      if (ascii_iswhite(cc)) {
        if (gchar_cursor() != NUL) {
          inc_cursor();
        }
        // If the cursor is still at the same character, also keep
        // the "coladd".
        if (gchar_cursor() == NUL
            && curwin->w_cursor.lnum == tpos.lnum
            && curwin->w_cursor.col == tpos.col) {
          curwin->w_cursor.coladd = tpos.coladd;
        }
      }
    }

    // If a space was inserted for auto-formatting, remove it now.
    check_auto_format(true);

    // If we just did an auto-indent, remove the white space from the end
    // of the line, and put the cursor back.
    // Do this when ESC was used or moving the cursor up/down.
    // Check for the old position still being valid, just in case the text
    // got changed unexpectedly.
    if (!nomove && did_ai && (esc || (vim_strchr(p_cpo, CPO_INDENT) == NULL
                                      && curwin->w_cursor.lnum !=
                                      end_insert_pos->lnum))
        && end_insert_pos->lnum <= curbuf->b_ml.ml_line_count) {
      pos_T tpos = curwin->w_cursor;

      curwin->w_cursor = *end_insert_pos;
      check_cursor_col(curwin);        // make sure it is not past the line
      while (true) {
        if (gchar_cursor() == NUL && curwin->w_cursor.col > 0) {
          curwin->w_cursor.col--;
        }
        cc = gchar_cursor();
        if (!ascii_iswhite(cc)) {
          break;
        }
        if (del_char(true) == FAIL) {
          break;            // should not happen
        }
      }
      if (curwin->w_cursor.lnum != tpos.lnum) {
        curwin->w_cursor = tpos;
      } else {
        // reset tpos, could have been invalidated in the loop above
        tpos = curwin->w_cursor;
        tpos.col++;
        if (cc != NUL && gchar_pos(&tpos) == NUL) {
          curwin->w_cursor.col++;         // put cursor back on the NUL
        }
      }

      // <C-S-Right> may have started Visual mode, adjust the position for
      // deleted characters.
      if (VIsual_active) {
        check_visual_pos();
      }
    }
  }
  did_ai = false;
  did_si = false;
  can_si = false;
  can_si_back = false;

  // Set '[ and '] to the inserted text.  When end_insert_pos is NULL we are
  // now in a different buffer.
  if (end_insert_pos != NULL) {
    curbuf->b_op_start = Insstart;
    curbuf->b_op_start_orig = Insstart_orig;
    curbuf->b_op_end = *end_insert_pos;
  }
}

// Set the last inserted text to a single character.
// Used for the replace command.
void set_last_insert(int c)
{
  xfree(last_insert);
  last_insert = xmalloc(MB_MAXBYTES * 3 + 5);
  char *s = last_insert;
  // Use the CTRL-V only when entering a special char
  if (c < ' ' || c == DEL) {
    *s++ = Ctrl_V;
  }
  s = add_char2buf(c, s);
  *s++ = ESC;
  *s++ = NUL;
  last_insert_skip = 0;
}

#if defined(EXITFREE)
void free_last_insert(void)
{
  XFREE_CLEAR(last_insert);
}
#endif

// move cursor to start of line
// if flags & BL_WHITE  move to first non-white
// if flags & BL_SOL    move to first non-white if startofline is set,
//                          otherwise keep "curswant" column
// if flags & BL_FIX    don't leave the cursor on a NUL.
void beginline(int flags)
{
  if ((flags & BL_SOL) && !p_sol) {
    coladvance(curwin, curwin->w_curswant);
  } else {
    curwin->w_cursor.col = 0;
    curwin->w_cursor.coladd = 0;

    if (flags & (BL_WHITE | BL_SOL)) {
      for (char *ptr = get_cursor_line_ptr(); ascii_iswhite(*ptr)
           && !((flags & BL_FIX) && ptr[1] == NUL); ptr++) {
        curwin->w_cursor.col++;
      }
    }
    curwin->w_set_curswant = true;
  }
  adjust_skipcol();
}

// oneright oneleft cursor_down cursor_up
//
// Move one char {right,left,down,up}.
// Doesn't move onto the NUL past the end of the line, unless it is allowed.
// Return OK when successful, FAIL when we hit a line of file boundary.

int oneright(void)
{
  char *ptr;

  if (virtual_active(curwin)) {
    pos_T prevpos = curwin->w_cursor;

    // Adjust for multi-wide char (excluding TAB)
    ptr = get_cursor_pos_ptr();
    coladvance(curwin, getviscol() + ((*ptr != TAB && vim_isprintc(utf_ptr2char(ptr)))
                                      ? ptr2cells(ptr) : 1));
    curwin->w_set_curswant = true;
    // Return OK if the cursor moved, FAIL otherwise (at window edge).
    return (prevpos.col != curwin->w_cursor.col
            || prevpos.coladd != curwin->w_cursor.coladd) ? OK : FAIL;
  }

  ptr = get_cursor_pos_ptr();
  if (*ptr == NUL) {
    return FAIL;            // already at the very end
  }

  int l = utfc_ptr2len(ptr);

  // move "l" bytes right, but don't end up on the NUL, unless 'virtualedit'
  // contains "onemore".
  if (ptr[l] == NUL && (get_ve_flags(curwin) & kOptVeFlagOnemore) == 0) {
    return FAIL;
  }
  curwin->w_cursor.col += l;

  curwin->w_set_curswant = true;
  adjust_skipcol();
  return OK;
}

int oneleft(void)
{
  if (virtual_active(curwin)) {
    int v = getviscol();

    if (v == 0) {
      return FAIL;
    }

    // We might get stuck on 'showbreak', skip over it.
    int width = 1;
    while (true) {
      coladvance(curwin, v - width);
      // getviscol() is slow, skip it when 'showbreak' is empty,
      // 'breakindent' is not set and there are no multi-byte
      // characters
      if (getviscol() < v) {
        break;
      }
      width++;
    }

    if (curwin->w_cursor.coladd == 1) {
      // Adjust for multi-wide char (not a TAB)
      char *ptr = get_cursor_pos_ptr();
      if (*ptr != TAB && vim_isprintc(utf_ptr2char(ptr)) && ptr2cells(ptr) > 1) {
        curwin->w_cursor.coladd = 0;
      }
    }

    curwin->w_set_curswant = true;
    adjust_skipcol();
    return OK;
  }

  if (curwin->w_cursor.col == 0) {
    return FAIL;
  }

  curwin->w_set_curswant = true;
  curwin->w_cursor.col--;

  // if the character on the left of the current cursor is a multi-byte
  // character, move to its first byte
  mb_adjust_cursor();
  adjust_skipcol();
  return OK;
}

/// Move the cursor up "n" lines in window "wp".
/// Takes care of closed folds.
void cursor_up_inner(win_T *wp, linenr_T n)
{
  linenr_T lnum = wp->w_cursor.lnum;

  if (n >= lnum) {
    lnum = 1;
  } else if (hasAnyFolding(wp)) {
    // Count each sequence of folded lines as one logical line.

    // go to the start of the current fold
    hasFolding(wp, lnum, &lnum, NULL);

    while (n--) {
      // move up one line
      lnum--;
      if (lnum <= 1) {
        break;
      }
      // If we entered a fold, move to the beginning, unless in
      // Insert mode or when 'foldopen' contains "all": it will open
      // in a moment.
      if (n > 0 || !((State & MODE_INSERT) || (fdo_flags & kOptFdoFlagAll))) {
        hasFolding(wp, lnum, &lnum, NULL);
      }
    }
    lnum = MAX(lnum, 1);
  } else {
    lnum -= n;
  }

  wp->w_cursor.lnum = lnum;
}

/// @param upd_topline  When true: update topline
int cursor_up(linenr_T n, bool upd_topline)
{
  // This fails if the cursor is already in the first line.
  if (n > 0 && curwin->w_cursor.lnum <= 1) {
    return FAIL;
  }
  cursor_up_inner(curwin, n);

  // try to advance to the column we want to be at
  coladvance(curwin, curwin->w_curswant);

  if (upd_topline) {
    update_topline(curwin);  // make sure curwin->w_topline is valid
  }

  return OK;
}

/// Move the cursor down "n" lines in window "wp".
/// Takes care of closed folds.
void cursor_down_inner(win_T *wp, int n)
{
  linenr_T lnum = wp->w_cursor.lnum;
  linenr_T line_count = wp->w_buffer->b_ml.ml_line_count;

  if (lnum + n >= line_count) {
    lnum = line_count;
  } else if (hasAnyFolding(wp)) {
    linenr_T last;

    // count each sequence of folded lines as one logical line
    while (n--) {
      if (hasFoldingWin(wp, lnum, NULL, &last, true, NULL)) {
        lnum = last + 1;
      } else {
        lnum++;
      }
      if (lnum >= line_count) {
        break;
      }
    }
    lnum = MIN(lnum, line_count);
  } else {
    lnum += (linenr_T)n;
  }

  wp->w_cursor.lnum = lnum;
}

/// @param upd_topline  When true: update topline
int cursor_down(int n, bool upd_topline)
{
  linenr_T lnum = curwin->w_cursor.lnum;
  // This fails if the cursor is already in the last (folded) line.
  hasFoldingWin(curwin, lnum, NULL, &lnum, true, NULL);
  if (n > 0 && lnum >= curwin->w_buffer->b_ml.ml_line_count) {
    return FAIL;
  }
  cursor_down_inner(curwin, n);

  // try to advance to the column we want to be at
  coladvance(curwin, curwin->w_curswant);

  if (upd_topline) {
    update_topline(curwin);           // make sure curwin->w_topline is valid
  }

  return OK;
}

/// Stuff the last inserted text in the read buffer.
/// Last_insert actually is a copy of the redo buffer, so we
/// first have to remove the command.
///
/// @param c       Command character to be inserted
/// @param count   Repeat this many times
/// @param no_esc  Don't add an ESC at the end
int stuff_inserted(int c, int count, int no_esc)
{
  char *esc_ptr;
  char last = NUL;

  char *ptr = get_last_insert();
  if (ptr == NULL) {
    emsg(_(e_noinstext));
    return FAIL;
  }

  // may want to stuff the command character, to start Insert mode
  if (c != NUL) {
    stuffcharReadbuff(c);
  }
  if ((esc_ptr = strrchr(ptr, ESC)) != NULL) {
    // remove the ESC.
    *esc_ptr = NUL;
  }

  // when the last char is either "0" or "^" it will be quoted if no ESC
  // comes after it OR if it will inserted more than once and "ptr"
  // starts with ^D.  -- Acevedo
  char *last_ptr = (esc_ptr ? esc_ptr : ptr + strlen(ptr)) - 1;
  if (last_ptr >= ptr && (*last_ptr == '0' || *last_ptr == '^')
      && (no_esc || (*ptr == Ctrl_D && count > 1))) {
    last = *last_ptr;
    *last_ptr = NUL;
  }

  do {
    stuffReadbuff(ptr);
    // A trailing "0" is inserted as "<C-V>048", "^" as "<C-V>^".
    if (last) {
      stuffReadbuff(last == '0' ? "\026\060\064\070" : "\026^");
    }
  } while (--count > 0);

  if (last) {
    *last_ptr = last;
  }

  if (esc_ptr != NULL) {
    *esc_ptr = ESC;         // put the ESC back
  }

  // may want to stuff a trailing ESC, to get out of Insert mode
  if (!no_esc) {
    stuffcharReadbuff(ESC);
  }

  return OK;
}

char *get_last_insert(void)
  FUNC_ATTR_PURE
{
  if (last_insert == NULL) {
    return NULL;
  }
  return last_insert + last_insert_skip;
}

// Get last inserted string, and remove trailing <Esc>.
// Returns pointer to allocated memory (must be freed) or NULL.
char *get_last_insert_save(void)
{
  if (last_insert == NULL) {
    return NULL;
  }
  char *s = xstrdup(last_insert + last_insert_skip);
  int len = (int)strlen(s);
  if (len > 0 && s[len - 1] == ESC) {         // remove trailing ESC
    s[len - 1] = NUL;
  }

  return s;
}

/// Check the word in front of the cursor for an abbreviation.
/// Called when the non-id character "c" has been entered.
/// When an abbreviation is recognized it is removed from the text and
/// the replacement string is inserted in typebuf.tb_buf[], followed by "c".
///
/// @param  c  character
///
/// @return true if the word is a known abbreviation.
static bool echeck_abbr(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Don't check for abbreviation in paste mode, when disabled and just
  // after moving around with cursor keys.
  if (p_paste || no_abbr || arrow_used) {
    return false;
  }

  return check_abbr(c, get_cursor_line_ptr(), curwin->w_cursor.col,
                    curwin->w_cursor.lnum == Insstart.lnum ? Insstart.col : 0);
}

// replace-stack functions
//
// When replacing characters, the replaced characters are remembered for each
// new character.  This is used to re-insert the old text when backspacing.
//
// There is a NUL headed list of characters for each character that is
// currently in the file after the insertion point.  When BS is used, one NUL
// headed list is put back for the deleted character.
//
// For a newline, there are two NUL headed lists.  One contains the characters
// that the NL replaced.  The extra one stores the characters after the cursor
// that were deleted (always white space).

/// Push character that is replaced onto the replace stack.
///
/// replace_offset is normally 0, in which case replace_push will add a new
/// character at the end of the stack.  If replace_offset is not 0, that many
/// characters will be left on the stack above the newly inserted character.
///
/// @param str character that is replaced (NUL is none)
/// @param len length of character in bytes
void replace_push(char *str, size_t len)
{
  // TODO(bfredl): replace_offset is suss af, if we don't need it, this
  // function is just kv_concat() :p
  if (kv_size(replace_stack) < (size_t)replace_offset) {  // nothing to do
    return;
  }

  kv_ensure_space(replace_stack, len);

  char *p = replace_stack.items + kv_size(replace_stack) - replace_offset;
  if (replace_offset) {
    memmove(p + len, p, (size_t)replace_offset);
  }
  memcpy(p, str, len);
  kv_size(replace_stack) += len;
}

/// push NUL as separator between entries in the stack
void replace_push_nul(void)
{
  replace_push("", 1);
}

/// Check top of replace stack, pop it if it was NUL
///
/// when a non-NUL byte is found, use mb_replace_pop_ins() to
/// pop one complete multibyte character.
///
/// @return -1 if stack is empty, last byte of char or NUL otherwise
static int replace_pop_if_nul(void)
{
  int ch = (kv_size(replace_stack)) ? (uint8_t)kv_A(replace_stack, kv_size(replace_stack) - 1) : -1;
  if (ch == NUL) {
    kv_size(replace_stack)--;
  }
  return ch;
}

/// Join the top two items on the replace stack.  This removes to "off"'th NUL
/// encountered.
///
/// @param off  offset for which NUL to remove
static void replace_join(int off)
{
  for (ssize_t i = (ssize_t)kv_size(replace_stack); --i >= 0;) {
    if (kv_A(replace_stack, i) == NUL && off-- <= 0) {
      kv_size(replace_stack)--;
      memmove(&kv_A(replace_stack, i), &kv_A(replace_stack, i + 1),
              (kv_size(replace_stack) - (size_t)i));
      return;
    }
  }
}

/// Pop bytes from the replace stack until a NUL is found, and insert them
/// before the cursor.  Can only be used in MODE_REPLACE or MODE_VREPLACE state.
static void replace_pop_ins(void)
{
  int oldState = State;

  State = MODE_NORMAL;                       // don't want MODE_REPLACE here
  while ((replace_pop_if_nul()) > 0) {
    mb_replace_pop_ins();
    dec_cursor();
  }
  State = oldState;
}

/// Insert multibyte char popped from the replace stack.
///
/// caller must already have checked the top of the stack is not NUL!!
static void mb_replace_pop_ins(void)
{
  int len = utf_head_off(&kv_A(replace_stack, 0),
                         &kv_A(replace_stack, kv_size(replace_stack) - 1)) + 1;
  kv_size(replace_stack) -= (size_t)len;
  ins_bytes_len(&kv_A(replace_stack, kv_size(replace_stack)), (size_t)len);
}

// Handle doing a BS for one character.
// cc < 0: replace stack empty, just move cursor
// cc == 0: character was inserted, delete it
// cc > 0: character was replaced, put cc (first byte of original char) back
// and check for more characters to be put back
// When "limit_col" is >= 0, don't delete before this column.  Matters when
// using composing characters, use del_char_after_col() instead of del_char().
static void replace_do_bs(int limit_col)
{
  colnr_T start_vcol;
  const int l_State = State;

  int cc = replace_pop_if_nul();
  if (cc > 0) {
    int orig_len = 0;
    int orig_vcols = 0;
    if (l_State & VREPLACE_FLAG) {
      // Get the number of screen cells used by the character we are
      // going to delete.
      getvcol(curwin, &curwin->w_cursor, NULL, &start_vcol, NULL);
      orig_vcols = win_chartabsize(curwin, get_cursor_pos_ptr(), start_vcol);
    }
    del_char_after_col(limit_col);
    if (l_State & VREPLACE_FLAG) {
      orig_len = get_cursor_pos_len();
    }
    replace_pop_ins();

    if (l_State & VREPLACE_FLAG) {
      // Get the number of screen cells used by the inserted characters
      char *p = get_cursor_pos_ptr();
      int ins_len = get_cursor_pos_len() - orig_len;
      int vcol = start_vcol;
      for (int i = 0; i < ins_len; i++) {
        vcol += win_chartabsize(curwin, p + i, vcol);
        i += utfc_ptr2len(p) - 1;
      }
      vcol -= start_vcol;

      // Delete spaces that were inserted after the cursor to keep the
      // text aligned.
      curwin->w_cursor.col += ins_len;
      while (vcol > orig_vcols && gchar_cursor() == ' ') {
        del_char(false);
        orig_vcols++;
      }
      curwin->w_cursor.col -= ins_len;
    }

    // mark the buffer as changed and prepare for displaying
    changed_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col);
  } else if (cc == 0) {
    del_char_after_col(limit_col);
  }
}

/// Check that C-indenting is on.
bool cindent_on(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return !p_paste && (curbuf->b_p_cin || *curbuf->b_p_inde != NUL);
}

/// Check that "cinkeys" contains the key "keytyped",
/// when == '*': Only if key is preceded with '*' (indent before insert)
/// when == '!': Only if key is preceded with '!' (don't insert)
/// when == ' ': Only if key is not preceded with '*' or '!' (indent afterwards)
///
/// "keytyped" can have a few special values:
/// KEY_OPEN_FORW :
/// KEY_OPEN_BACK :
/// KEY_COMPLETE  : Just finished completion.
///
/// @param  keytyped       key that was typed
/// @param  when           condition on when to perform the check
/// @param  line_is_empty  when true, accept keys with '0' before them.
bool in_cinkeys(int keytyped, int when, bool line_is_empty)
{
  char *look;
  bool try_match;
  bool try_match_word;
  char *p;
  bool icase;

  if (keytyped == NUL) {
    // Can happen with CTRL-Y and CTRL-E on a short line.
    return false;
  }

  if (*curbuf->b_p_inde != NUL) {
    look = curbuf->b_p_indk;            // 'indentexpr' set: use 'indentkeys'
  } else {
    look = curbuf->b_p_cink;            // 'indentexpr' empty: use 'cinkeys'
  }
  while (*look) {
    // Find out if we want to try a match with this key, depending on
    // 'when' and a '*' or '!' before the key.
    switch (when) {
    case '*':
      try_match = (*look == '*'); break;
    case '!':
      try_match = (*look == '!'); break;
    default:
      try_match = (*look != '*') && (*look != '!'); break;
    }
    if (*look == '*' || *look == '!') {
      look++;
    }

    // If there is a '0', only accept a match if the line is empty.
    // But may still match when typing last char of a word.
    if (*look == '0') {
      try_match_word = try_match;
      if (!line_is_empty) {
        try_match = false;
      }
      look++;
    } else {
      try_match_word = false;
    }

    // Does it look like a control character?
    if (*look == '^' && look[1] >= '?' && look[1] <= '_') {
      if (try_match && keytyped == CTRL_CHR(look[1])) {
        return true;
      }
      look += 2;

      // 'o' means "o" command, open forward.
      // 'O' means "O" command, open backward.
    } else if (*look == 'o') {
      if (try_match && keytyped == KEY_OPEN_FORW) {
        return true;
      }
      look++;
    } else if (*look == 'O') {
      if (try_match && keytyped == KEY_OPEN_BACK) {
        return true;
      }
      look++;

      // 'e' means to check for "else" at start of line and just before the
      // cursor.
    } else if (*look == 'e') {
      if (try_match && keytyped == 'e' && curwin->w_cursor.col >= 4) {
        p = get_cursor_line_ptr();
        if (skipwhite(p) == p + curwin->w_cursor.col - 4
            && strncmp(p + curwin->w_cursor.col - 4, "else", 4) == 0) {
          return true;
        }
      }
      look++;

      // ':' only causes an indent if it is at the end of a label or case
      // statement, or when it was before typing the ':' (to fix
      // class::method for C++).
    } else if (*look == ':') {
      if (try_match && keytyped == ':') {
        p = get_cursor_line_ptr();
        if (cin_iscase(p, false) || cin_isscopedecl(p) || cin_islabel()) {
          return true;
        }
        // Need to get the line again after cin_islabel().
        p = get_cursor_line_ptr();
        if (curwin->w_cursor.col > 2
            && p[curwin->w_cursor.col - 1] == ':'
            && p[curwin->w_cursor.col - 2] == ':') {
          p[curwin->w_cursor.col - 1] = ' ';
          const bool i = cin_iscase(p, false)
                         || cin_isscopedecl(p)
                         || cin_islabel();
          p = get_cursor_line_ptr();
          p[curwin->w_cursor.col - 1] = ':';
          if (i) {
            return true;
          }
        }
      }
      look++;

      // Is it a key in <>, maybe?
    } else if (*look == '<') {
      if (try_match) {
        // make up some named keys <o>, <O>, <e>, <0>, <>>, <<>, <*>,
        // <:> and <!> so that people can re-indent on o, O, e, 0, <,
        // >, *, : and ! keys if they really really want to.
        if (vim_strchr("<>!*oOe0:", (uint8_t)look[1]) != NULL
            && keytyped == look[1]) {
          return true;
        }

        if (keytyped == get_special_key_code(look + 1)) {
          return true;
        }
      }
      while (*look && *look != '>') {
        look++;
      }
      while (*look == '>') {
        look++;
      }
      // Is it a word: "=word"?
    } else if (*look == '=' && look[1] != ',' && look[1] != NUL) {
      look++;
      if (*look == '~') {
        icase = true;
        look++;
      } else {
        icase = false;
      }
      p = vim_strchr(look, ',');
      if (p == NULL) {
        p = look + strlen(look);
      }
      if ((try_match || try_match_word)
          && curwin->w_cursor.col >= (colnr_T)(p - look)) {
        bool match = false;

        if (keytyped == KEY_COMPLETE) {
          char *n, *s;

          // Just completed a word, check if it starts with "look".
          // search back for the start of a word.
          char *line = get_cursor_line_ptr();
          for (s = line + curwin->w_cursor.col; s > line; s = n) {
            n = mb_prevptr(line, s);
            if (!vim_iswordp(n)) {
              break;
            }
          }
          assert(p >= look && (uintmax_t)(p - look) <= SIZE_MAX);
          if (s + (p - look) <= line + curwin->w_cursor.col
              && (icase
                  ? mb_strnicmp(s, look, (size_t)(p - look))
                  : strncmp(s, look, (size_t)(p - look))) == 0) {
            match = true;
          }
        } else {
          // TODO(@brammool): multi-byte
          if (keytyped == (int)(uint8_t)p[-1]
              || (icase && keytyped < 256 && keytyped >= 0
                  && TOLOWER_LOC(keytyped) == TOLOWER_LOC((uint8_t)p[-1]))) {
            char *line = get_cursor_pos_ptr();
            assert(p >= look && (uintmax_t)(p - look) <= SIZE_MAX);
            if ((curwin->w_cursor.col == (colnr_T)(p - look)
                 || !vim_iswordc((uint8_t)line[-(p - look) - 1]))
                && (icase
                    ? mb_strnicmp(line - (p - look), look, (size_t)(p - look))
                    : strncmp(line - (p - look), look, (size_t)(p - look))) == 0) {
              match = true;
            }
          }
        }
        if (match && try_match_word && !try_match) {
          // "0=word": Check if there are only blanks before the
          // word.
          if (getwhitecols_curline() !=
              (int)(curwin->w_cursor.col - (p - look))) {
            match = false;
          }
        }
        if (match) {
          return true;
        }
      }
      look = p;

      // Ok, it's a boring generic character.
    } else {
      if (try_match && (uint8_t)(*look) == keytyped) {
        return true;
      }
      if (*look != NUL) {
        look++;
      }
    }

    // Skip over ", ".
    look = skip_to_option_part(look);
  }
  return false;
}

static void ins_reg(void)
{
  bool need_redraw = false;
  int literally = 0;
  int vis_active = VIsual_active;

  // If we are going to wait for a character, show a '"'.
  pc_status = PC_STATUS_UNSET;
  if (redrawing() && !char_avail()) {
    // may need to redraw when no more chars available now
    ins_redraw(false);

    edit_putchar('"', true);
    add_to_showcmd_c(Ctrl_R);
  }

  // Don't map the register name. This also prevents the mode message to be
  // deleted when ESC is hit.
  no_mapping++;
  allow_keys++;
  int regname = plain_vgetc();
  LANGMAP_ADJUST(regname, true);
  if (regname == Ctrl_R || regname == Ctrl_O || regname == Ctrl_P) {
    // Get a third key for literal register insertion
    literally = regname;
    add_to_showcmd_c(literally);
    regname = plain_vgetc();
    LANGMAP_ADJUST(regname, true);
  }
  no_mapping--;
  allow_keys--;

  // Don't call u_sync() while typing the expression or giving an error
  // message for it. Only call it explicitly.
  no_u_sync++;
  if (regname == '=') {
    pos_T curpos = curwin->w_cursor;

    // Sync undo when evaluating the expression calls setline() or
    // append(), so that it can be undone separately.
    u_sync_once = 2;

    regname = get_expr_register();

    // Cursor may be moved back a column.
    curwin->w_cursor = curpos;
    check_cursor(curwin);
  }
  if (regname == NUL || !valid_yank_reg(regname, false)) {
    vim_beep(kOptBoFlagRegister);
    need_redraw = true;  // remove the '"'
  } else {
    if (literally == Ctrl_O || literally == Ctrl_P) {
      // Append the command to the redo buffer.
      AppendCharToRedobuff(Ctrl_R);
      AppendCharToRedobuff(literally);
      AppendCharToRedobuff(regname);

      do_put(regname, NULL, BACKWARD, 1,
             (literally == Ctrl_P ? PUT_FIXINDENT : 0) | PUT_CURSEND);
    } else if (insert_reg(regname, literally) == FAIL) {
      vim_beep(kOptBoFlagRegister);
      need_redraw = true;  // remove the '"'
    } else if (stop_insert_mode) {
      // When the '=' register was used and a function was invoked that
      // did ":stopinsert" then stuff_empty() returns false but we won't
      // insert anything, need to remove the '"'
      need_redraw = true;
    }
  }
  no_u_sync--;
  if (u_sync_once == 1) {
    ins_need_undo = true;
  }
  u_sync_once = 0;
  clear_showcmd();

  // If the inserted register is empty, we need to remove the '"'
  if (need_redraw || stuff_empty()) {
    edit_unputchar();
  }

  // Disallow starting Visual mode here, would get a weird mode.
  if (!vis_active && VIsual_active) {
    end_visual_mode();
  }
}

// CTRL-G commands in Insert mode.
static void ins_ctrl_g(void)
{
  // Right after CTRL-X the cursor will be after the ruler.
  setcursor();

  // Don't map the second key. This also prevents the mode message to be
  // deleted when ESC is hit.
  no_mapping++;
  allow_keys++;
  int c = plain_vgetc();
  no_mapping--;
  allow_keys--;
  switch (c) {
  // CTRL-G k and CTRL-G <Up>: cursor up to Insstart.col
  case K_UP:
  case Ctrl_K:
  case 'k':
    ins_up(true);
    break;

  // CTRL-G j and CTRL-G <Down>: cursor down to Insstart.col
  case K_DOWN:
  case Ctrl_J:
  case 'j':
    ins_down(true);
    break;

  // CTRL-G u: start new undoable edit
  case 'u':
    u_sync(true);
    ins_need_undo = true;

    // Need to reset Insstart, esp. because a BS that joins
    // a line to the previous one must save for undo.
    update_Insstart_orig = false;
    Insstart = curwin->w_cursor;
    break;

  // CTRL-G U: do not break undo with the next char.
  case 'U':
    // Allow one left/right cursor movement with the next char,
    // without breaking undo.
    dont_sync_undo = kNone;
    break;

  case ESC:
    // Esc after CTRL-G cancels it.
    break;

  // Unknown CTRL-G command, reserved for future expansion.
  default:
    vim_beep(kOptBoFlagCtrlg);
  }
}

// CTRL-^ in Insert mode.
static void ins_ctrl_hat(void)
{
  if (map_to_exists_mode("", MODE_LANGMAP, false)) {
    // ":lmap" mappings exists, Toggle use of ":lmap" mappings.
    if (State & MODE_LANGMAP) {
      curbuf->b_p_iminsert = B_IMODE_NONE;
      State &= ~MODE_LANGMAP;
    } else {
      curbuf->b_p_iminsert = B_IMODE_LMAP;
      State |= MODE_LANGMAP;
    }
  }
  set_iminsert_global(curbuf);
  showmode();
  // Show/unshow value of 'keymap' in status lines.
  status_redraw_curbuf();
}

/// Handle ESC in insert mode.
///
/// @param[in,out]  count    repeat count of the insert command
/// @param          cmdchar  command that started the insert
/// @param          nomove   when true, don't move the cursor
///
/// @return true when leaving insert mode, false when repeating the insert.
static bool ins_esc(int *count, int cmdchar, bool nomove)
  FUNC_ATTR_NONNULL_ARG(1)
{
  static bool disabled_redraw = false;

  check_spell_redraw();

  int temp = curwin->w_cursor.col;
  if (disabled_redraw) {
    RedrawingDisabled--;
    disabled_redraw = false;
  }
  if (!arrow_used) {
    // Don't append the ESC for "r<CR>" and "grx".
    if (cmdchar != 'r' && cmdchar != 'v') {
      AppendToRedobuff(ESC_STR);
    }

    // Repeating insert may take a long time.  Check for
    // interrupt now and then.
    if (*count > 0) {
      line_breakcheck();
      if (got_int) {
        *count = 0;
      }
    }

    if (--*count > 0) {         // repeat what was typed
      // Vi repeats the insert without replacing characters.
      if (vim_strchr(p_cpo, CPO_REPLCNT) != NULL) {
        State &= ~REPLACE_FLAG;
      }

      start_redo_ins();
      if (cmdchar == 'r' || cmdchar == 'v') {
        stuffRedoReadbuff(ESC_STR);  // No ESC in redo buffer
      }
      RedrawingDisabled++;
      disabled_redraw = true;
      // Repeat the insert
      return false;
    }
    stop_insert(&curwin->w_cursor, true, nomove);
    undisplay_dollar();
  }

  if (cmdchar != 'r' && cmdchar != 'v') {
    ins_apply_autocmds(EVENT_INSERTLEAVEPRE);
  }

  // When an autoindent was removed, curswant stays after the
  // indent
  if (restart_edit == NUL && (colnr_T)temp == curwin->w_cursor.col) {
    curwin->w_set_curswant = true;
  }

  // Remember the last Insert position in the '^ mark.
  if ((cmdmod.cmod_flags & CMOD_KEEPJUMPS) == 0) {
    fmarkv_T view = mark_view_make(curwin->w_topline, curwin->w_cursor);
    RESET_FMARK(&curbuf->b_last_insert, curwin->w_cursor, curbuf->b_fnum, view);
  }

  // The cursor should end up on the last inserted character.
  // Don't do it for CTRL-O, unless past the end of the line.
  if (!nomove
      && (curwin->w_cursor.col != 0 || curwin->w_cursor.coladd > 0)
      && (restart_edit == NUL || (gchar_cursor() == NUL && !VIsual_active))
      && !revins_on) {
    if (curwin->w_cursor.coladd > 0 || get_ve_flags(curwin) == kOptVeFlagAll) {
      oneleft();
      if (restart_edit != NUL) {
        curwin->w_cursor.coladd++;
      }
    } else {
      curwin->w_cursor.col--;
      curwin->w_valid &= ~(VALID_WCOL|VALID_VIRTCOL);
      // Correct cursor for multi-byte character.
      mb_adjust_cursor();
    }
  }

  State = MODE_NORMAL;
  may_trigger_modechanged();
  // need to position cursor again when on a TAB and
  // when on a char with inline virtual text
  if (gchar_cursor() == TAB || buf_meta_total(curbuf, kMTMetaInline) > 0) {
    curwin->w_valid &= ~(VALID_WROW|VALID_WCOL|VALID_VIRTCOL);
  }

  setmouse();
  ui_cursor_shape();            // may show different cursor shape

  // When recording or for CTRL-O, need to display the new mode.
  // Otherwise remove the mode message.
  if (reg_recording != 0 || restart_edit != NUL) {
    showmode();
  } else if (p_smd && (got_int || !skip_showmode())
             && !(p_ch == 0 && !ui_has(kUIMessages))) {
    msg("", 0);
  }
  // Exit Insert mode
  return true;
}

// Toggle language: revins_on.
// Move to end of reverse inserted text.
static void ins_ctrl_(void)
{
  if (revins_on && revins_chars && revins_scol >= 0) {
    while (gchar_cursor() != NUL && revins_chars--) {
      curwin->w_cursor.col++;
    }
  }
  p_ri = !p_ri;
  revins_on = (State == MODE_INSERT && p_ri);
  if (revins_on) {
    revins_scol = curwin->w_cursor.col;
    revins_legal++;
    revins_chars = 0;
    undisplay_dollar();
  } else {
    revins_scol = -1;
  }
  showmode();
}

/// If 'keymodel' contains "startsel", may start selection.
///
/// @param  c  character to check
//
/// @return true when a CTRL-O and other keys stuffed.
static bool ins_start_select(int c)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (!km_startsel) {
    return false;
  }
  switch (c) {
  case K_KHOME:
  case K_KEND:
  case K_PAGEUP:
  case K_KPAGEUP:
  case K_PAGEDOWN:
  case K_KPAGEDOWN:
    if (!(mod_mask & MOD_MASK_SHIFT)) {
      break;
    }
    FALLTHROUGH;
  case K_S_LEFT:
  case K_S_RIGHT:
  case K_S_UP:
  case K_S_DOWN:
  case K_S_END:
  case K_S_HOME:
    // Start selection right away, the cursor can move with CTRL-O when
    // beyond the end of the line.
    start_selection();

    // Execute the key in (insert) Select mode.
    stuffcharReadbuff(Ctrl_O);
    if (mod_mask) {
      const char buf[] = { (char)K_SPECIAL, (char)KS_MODIFIER,
                           (char)(uint8_t)mod_mask, NUL };
      stuffReadbuff(buf);
    }
    stuffcharReadbuff(c);
    return true;
  }
  return false;
}

// <Insert> key in Insert mode: toggle insert/replace mode.
static void ins_insert(int replaceState)
{
  set_vim_var_string(VV_INSERTMODE, ((State & REPLACE_FLAG)
                                     ? "i"
                                     : replaceState == MODE_VREPLACE ? "v" : "r"), 1);
  ins_apply_autocmds(EVENT_INSERTCHANGE);
  if (State & REPLACE_FLAG) {
    State = MODE_INSERT | (State & MODE_LANGMAP);
  } else {
    State = replaceState | (State & MODE_LANGMAP);
  }
  may_trigger_modechanged();
  AppendCharToRedobuff(K_INS);
  showmode();
  ui_cursor_shape();            // may show different cursor shape
}

// Pressed CTRL-O in Insert mode.
static void ins_ctrl_o(void)
{
  restart_VIsual_select = 0;
  if (State & VREPLACE_FLAG) {
    restart_edit = 'V';
  } else if (State & REPLACE_FLAG) {
    restart_edit = 'R';
  } else {
    restart_edit = 'I';
  }
  if (virtual_active(curwin)) {
    ins_at_eol = false;         // cursor always keeps its column
  } else {
    ins_at_eol = (gchar_cursor() == NUL);
  }
}

// If the cursor is on an indent, ^T/^D insert/delete one
// shiftwidth.  Otherwise ^T/^D behave like a "<<" or ">>".
// Always round the indent to 'shiftwidth', this is compatible
// with vi.  But vi only supports ^T and ^D after an
// autoindent, we support it everywhere.
static void ins_shift(int c, int lastc)
{
  if (stop_arrow() == FAIL) {
    return;
  }
  AppendCharToRedobuff(c);

  // 0^D and ^^D: remove all indent.
  if (c == Ctrl_D && (lastc == '0' || lastc == '^')
      && curwin->w_cursor.col > 0) {
    curwin->w_cursor.col--;
    del_char(false);              // delete the '^' or '0'
    // In Replace mode, restore the characters that '^' or '0' replaced.
    if (State & REPLACE_FLAG) {
      replace_pop_ins();
    }
    if (lastc == '^') {
      old_indent = get_indent();        // remember curr. indent
    }
    change_indent(INDENT_SET, 0, true, true);
  } else {
    change_indent(c == Ctrl_D ? INDENT_DEC : INDENT_INC, 0, true, true);
  }

  if (did_ai && *skipwhite(get_cursor_line_ptr()) != NUL) {
    did_ai = false;
  }
  did_si = false;
  can_si = false;
  can_si_back = false;
  can_cindent = false;          // no cindenting after ^D or ^T
}

static void ins_del(void)
{
  if (stop_arrow() == FAIL) {
    return;
  }
  if (gchar_cursor() == NUL) {          // delete newline
    const int temp = curwin->w_cursor.col;
    if (!can_bs(BS_EOL)  // only if "eol" included
        || do_join(2, false, true, false, false) == FAIL) {
      vim_beep(kOptBoFlagBackspace);
    } else {
      curwin->w_cursor.col = temp;
      // Adjust orig_line_count in case more lines have been deleted than
      // have been added. That makes sure, that open_line() later
      // can access all buffer lines correctly
      if (State & VREPLACE_FLAG
          && orig_line_count > curbuf->b_ml.ml_line_count) {
        orig_line_count = curbuf->b_ml.ml_line_count;
      }
    }
  } else if (del_char(false) == FAIL) {  // delete char under cursor
    vim_beep(kOptBoFlagBackspace);
  }
  did_ai = false;
  did_si = false;
  can_si = false;
  can_si_back = false;
  AppendCharToRedobuff(K_DEL);
}

/// Handle Backspace, delete-word and delete-line in Insert mode.
///
/// @param          c                 character that was typed
/// @param          mode              backspace mode to use
/// @param[in,out]  inserted_space_p  whether a space was the last
//                                    character inserted
///
/// @return true when backspace was actually used.
static bool ins_bs(int c, int mode, int *inserted_space_p)
  FUNC_ATTR_NONNULL_ARG(3)
{
  int cc;
  int temp = 0;                     // init for GCC
  bool did_backspace = false;
  bool call_fix_indent = false;

  // can't delete anything in an empty file
  // can't backup past first character in buffer
  // can't backup past starting point unless 'backspace' > 1
  // can backup to a previous line if 'backspace' == 0
  if (buf_is_empty(curbuf)
      || (!revins_on
          && ((curwin->w_cursor.lnum == 1 && curwin->w_cursor.col == 0)
              || (!can_bs(BS_START)
                  && ((arrow_used && !bt_prompt(curbuf))
                      || (curwin->w_cursor.lnum == Insstart_orig.lnum
                          && curwin->w_cursor.col <= Insstart_orig.col)))
              || (!can_bs(BS_INDENT) && !arrow_used && ai_col > 0
                  && curwin->w_cursor.col <= ai_col)
              || (!can_bs(BS_EOL) && curwin->w_cursor.col == 0)))) {
    vim_beep(kOptBoFlagBackspace);
    return false;
  }

  if (stop_arrow() == FAIL) {
    return false;
  }
  bool in_indent = inindent(0);
  if (in_indent) {
    can_cindent = false;
  }
  end_comment_pending = NUL;  // After BS, don't auto-end comment
  if (revins_on) {            // put cursor after last inserted char
    inc_cursor();
  }
  // Virtualedit:
  //    BACKSPACE_CHAR eats a virtual space
  //    BACKSPACE_WORD eats all coladd
  //    BACKSPACE_LINE eats all coladd and keeps going
  if (curwin->w_cursor.coladd > 0) {
    if (mode == BACKSPACE_CHAR) {
      curwin->w_cursor.coladd--;
      return true;
    }
    if (mode == BACKSPACE_WORD) {
      curwin->w_cursor.coladd = 0;
      return true;
    }
    curwin->w_cursor.coladd = 0;
  }

  // Delete newline!
  if (curwin->w_cursor.col == 0) {
    linenr_T lnum = Insstart.lnum;
    if (curwin->w_cursor.lnum == lnum || revins_on) {
      if (u_save((linenr_T)(curwin->w_cursor.lnum - 2),
                 (linenr_T)(curwin->w_cursor.lnum + 1)) == FAIL) {
        return false;
      }
      Insstart.lnum--;
      Insstart.col = ml_get_len(Insstart.lnum);
    }
    // In replace mode:
    // cc < 0: NL was inserted, delete it
    // cc >= 0: NL was replaced, put original characters back
    cc = -1;
    if (State & REPLACE_FLAG) {
      cc = replace_pop_if_nul();  // returns -1 if NL was inserted
    }
    // In replace mode, in the line we started replacing, we only move the
    // cursor.
    if ((State & REPLACE_FLAG) && curwin->w_cursor.lnum <= lnum) {
      dec_cursor();
    } else {
      if (!(State & VREPLACE_FLAG)
          || curwin->w_cursor.lnum > orig_line_count) {
        temp = gchar_cursor();          // remember current char
        curwin->w_cursor.lnum--;

        // When "aw" is in 'formatoptions' we must delete the space at
        // the end of the line, otherwise the line will be broken
        // again when auto-formatting.
        if (has_format_option(FO_AUTO)
            && has_format_option(FO_WHITE_PAR)) {
          char *ptr = ml_get_buf_mut(curbuf, curwin->w_cursor.lnum);
          int len = get_cursor_line_len();
          if (len > 0 && ptr[len - 1] == ' ') {
            ptr[len - 1] = NUL;
            curbuf->b_ml.ml_line_len--;
          }
        }

        do_join(2, false, false, false, false);
        if (temp == NUL && gchar_cursor() != NUL) {
          inc_cursor();
        }
      } else {
        dec_cursor();
      }

      // In MODE_REPLACE mode we have to put back the text that was
      // replaced by the NL. On the replace stack is first a
      // NUL-terminated sequence of characters that were deleted and then
      // the characters that NL replaced.
      if (State & REPLACE_FLAG) {
        // Do the next ins_char() in MODE_NORMAL state, to
        // prevent ins_char() from replacing characters and
        // avoiding showmatch().
        int oldState = State;
        State = MODE_NORMAL;
        // restore characters (blanks) deleted after cursor
        while (cc > 0) {
          colnr_T save_col = curwin->w_cursor.col;
          mb_replace_pop_ins();
          curwin->w_cursor.col = save_col;
          cc = replace_pop_if_nul();
        }
        // restore the characters that NL replaced
        replace_pop_ins();
        State = oldState;
      }
    }
    did_ai = false;
  } else {
    // Delete character(s) before the cursor.
    if (revins_on) {            // put cursor on last inserted char
      dec_cursor();
    }
    colnr_T mincol = 0;
    // keep indent
    if (mode == BACKSPACE_LINE
        && (curbuf->b_p_ai || cindent_on())
        && !revins_on) {
      colnr_T save_col = curwin->w_cursor.col;
      beginline(BL_WHITE);
      if (curwin->w_cursor.col < save_col) {
        mincol = curwin->w_cursor.col;
        // should now fix the indent to match with the previous line
        call_fix_indent = true;
      }
      curwin->w_cursor.col = save_col;
    }

    // Handle deleting one 'shiftwidth' or 'softtabstop'.
    if (mode == BACKSPACE_CHAR
        && ((p_sta && in_indent)
            || ((get_sts_value() != 0 || tabstop_count(curbuf->b_p_vsts_array))
                && curwin->w_cursor.col > 0
                && (*(get_cursor_pos_ptr() - 1) == TAB
                    || (*(get_cursor_pos_ptr() - 1) == ' '
                        && (!*inserted_space_p || arrow_used)))))) {
      *inserted_space_p = false;

      bool const use_ts = !curwin->w_p_list || curwin->w_p_lcs_chars.tab1;
      char *const line = get_cursor_line_ptr();
      char *const cursor_ptr = line + curwin->w_cursor.col;

      colnr_T vcol = 0;
      colnr_T space_vcol = 0;
      StrCharInfo sci = utf_ptr2StrCharInfo(line);
      StrCharInfo space_sci = sci;
      bool prev_space = false;

      // Compute virtual column of cursor position, and find the last
      // whitespace before cursor that is preceded by non-whitespace.
      // Use charsize_nowrap() so that virtual text and wrapping are ignored.
      while (sci.ptr < cursor_ptr) {
        bool cur_space = ascii_iswhite(sci.chr.value);
        if (!prev_space && cur_space) {
          space_sci = sci;
          space_vcol = vcol;
        }
        vcol += charsize_nowrap(curbuf, sci.ptr, use_ts, vcol, sci.chr.value);
        sci = utfc_next(sci);
        prev_space = cur_space;
      }

      // Compute the virtual column where we want to be.
      colnr_T want_vcol = vcol > 0 ? vcol - 1 : 0;
      if (p_sta && in_indent) {
        want_vcol -= want_vcol % get_sw_value(curbuf);
      } else {
        want_vcol = tabstop_start(want_vcol, get_sts_value(), curbuf->b_p_vsts_array);
      }

      // Find the position to stop backspacing.
      // Use charsize_nowrap() so that virtual text and wrapping are ignored.
      while (true) {
        int size = charsize_nowrap(curbuf, space_sci.ptr, use_ts, space_vcol, space_sci.chr.value);
        if (space_vcol + size > want_vcol) {
          break;
        }
        space_vcol += size;
        space_sci = utfc_next(space_sci);
      }
      colnr_T const want_col = (int)(space_sci.ptr - line);

      // Delete characters until we are at or before want_col.
      while (curwin->w_cursor.col > want_col) {
        dec_cursor();
        if (State & REPLACE_FLAG) {
          // Don't delete characters before the insert point when in Replace mode.
          if (curwin->w_cursor.lnum != Insstart.lnum
              || curwin->w_cursor.col >= Insstart.col) {
            replace_do_bs(-1);
          }
        } else {
          del_char(false);
        }
      }

      // Insert extra spaces until we are at want_vcol.
      for (; space_vcol < want_vcol; space_vcol++) {
        // Remember the first char we inserted.
        if (curwin->w_cursor.lnum == Insstart_orig.lnum
            && curwin->w_cursor.col < Insstart_orig.col) {
          Insstart_orig.col = curwin->w_cursor.col;
        }

        if (State & VREPLACE_FLAG) {
          ins_char(' ');
        } else {
          ins_str(" ");
          if ((State & REPLACE_FLAG)) {
            replace_push_nul();
          }
        }
      }
    } else {
      // Delete up to starting point, start of line or previous word.

      int cclass = mb_get_class(get_cursor_pos_ptr());
      do {
        if (!revins_on) {   // put cursor on char to be deleted
          dec_cursor();
        }
        cc = gchar_cursor();
        // look multi-byte character class
        int prev_cclass = cclass;
        cclass = mb_get_class(get_cursor_pos_ptr());
        if (mode == BACKSPACE_WORD && !ascii_isspace(cc)) {   // start of word?
          mode = BACKSPACE_WORD_NOT_SPACE;
          temp = vim_iswordc(cc);
        } else if (mode == BACKSPACE_WORD_NOT_SPACE
                   && ((ascii_isspace(cc) || vim_iswordc(cc) != temp)
                       || prev_cclass != cclass)) {   // end of word?
          if (!revins_on) {
            inc_cursor();
          } else if (State & REPLACE_FLAG) {
            dec_cursor();
          }
          break;
        }
        if (State & REPLACE_FLAG) {
          replace_do_bs(-1);
        } else {
          bool has_composing = false;
          if (p_deco) {
            char *p0 = get_cursor_pos_ptr();
            has_composing = utf_composinglike(p0, p0 + utf_ptr2len(p0), NULL);
          }
          del_char(false);
          // If there are combining characters and 'delcombine' is set
          // move the cursor back.  Don't back up before the base character.
          if (has_composing) {
            inc_cursor();
          }
          if (revins_chars) {
            revins_chars--;
            revins_legal++;
          }
          if (revins_on && gchar_cursor() == NUL) {
            break;
          }
        }
        // Just a single backspace?:
        if (mode == BACKSPACE_CHAR) {
          break;
        }
      } while (revins_on
               || (curwin->w_cursor.col > mincol
                   && (can_bs(BS_NOSTOP)
                       || (curwin->w_cursor.lnum != Insstart_orig.lnum
                           || curwin->w_cursor.col != Insstart_orig.col))));
    }
    did_backspace = true;
  }
  did_si = false;
  can_si = false;
  can_si_back = false;
  if (curwin->w_cursor.col <= 1) {
    did_ai = false;
  }

  if (call_fix_indent) {
    fix_indent();
  }

  // It's a little strange to put backspaces into the redo
  // buffer, but it makes auto-indent a lot easier to deal
  // with.
  AppendCharToRedobuff(c);

  // If deleted before the insertion point, adjust it
  if (curwin->w_cursor.lnum == Insstart_orig.lnum
      && curwin->w_cursor.col < Insstart_orig.col) {
    Insstart_orig.col = curwin->w_cursor.col;
  }

  // vi behaviour: the cursor moves backward but the character that
  //               was there remains visible
  // Vim behaviour: the cursor moves backward and the character that
  //                was there is erased from the screen.
  // We can emulate the vi behaviour by pretending there is a dollar
  // displayed even when there isn't.
  //  --pkv Sun Jan 19 01:56:40 EST 2003
  if (vim_strchr(p_cpo, CPO_BACKSPACE) != NULL && dollar_vcol == -1) {
    dollar_vcol = curwin->w_virtcol;
  }

  // When deleting a char the cursor line must never be in a closed fold.
  // E.g., when 'foldmethod' is indent and deleting the first non-white
  // char before a Tab.
  if (did_backspace) {
    foldOpenCursor();
  }
  return did_backspace;
}

static void ins_left(void)
{
  const bool end_change = dont_sync_undo == kFalse;  // end undoable change

  if ((fdo_flags & kOptFdoFlagHor) && KeyTyped) {
    foldOpenCursor();
  }
  undisplay_dollar();
  pos_T tpos = curwin->w_cursor;
  if (oneleft() == OK) {
    start_arrow_with_change(&tpos, end_change);
    if (!end_change) {
      AppendCharToRedobuff(K_LEFT);
    }
    // If exit reversed string, position is fixed
    if (revins_scol != -1 && (int)curwin->w_cursor.col >= revins_scol) {
      revins_legal++;
    }
    revins_chars++;
  } else if (vim_strchr(p_ww, '[') != NULL && curwin->w_cursor.lnum > 1) {
    // if 'whichwrap' set for cursor in insert mode may go to previous line.
    // always break undo when moving upwards/downwards, else undo may break
    start_arrow(&tpos);
    curwin->w_cursor.lnum--;
    coladvance(curwin, MAXCOL);
    curwin->w_set_curswant = true;  // so we stay at the end
  } else {
    vim_beep(kOptBoFlagCursor);
  }
  dont_sync_undo = kFalse;
}

static void ins_home(int c)
{
  if ((fdo_flags & kOptFdoFlagHor) && KeyTyped) {
    foldOpenCursor();
  }
  undisplay_dollar();
  pos_T tpos = curwin->w_cursor;
  if (c == K_C_HOME) {
    curwin->w_cursor.lnum = 1;
  }
  curwin->w_cursor.col = 0;
  curwin->w_cursor.coladd = 0;
  curwin->w_curswant = 0;
  start_arrow(&tpos);
}

static void ins_end(int c)
{
  if ((fdo_flags & kOptFdoFlagHor) && KeyTyped) {
    foldOpenCursor();
  }
  undisplay_dollar();
  pos_T tpos = curwin->w_cursor;
  if (c == K_C_END) {
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  }
  coladvance(curwin, MAXCOL);
  curwin->w_curswant = MAXCOL;

  start_arrow(&tpos);
}

static void ins_s_left(void)
{
  const bool end_change = dont_sync_undo == kFalse;  // end undoable change
  if ((fdo_flags & kOptFdoFlagHor) && KeyTyped) {
    foldOpenCursor();
  }
  undisplay_dollar();
  if (curwin->w_cursor.lnum > 1 || curwin->w_cursor.col > 0) {
    start_arrow_with_change(&curwin->w_cursor, end_change);
    if (!end_change) {
      AppendCharToRedobuff(K_S_LEFT);
    }
    bck_word(1, false, false);
    curwin->w_set_curswant = true;
  } else {
    vim_beep(kOptBoFlagCursor);
  }
  dont_sync_undo = kFalse;
}

/// @param end_change      end undoable change
static void ins_right(void)
{
  const bool end_change = dont_sync_undo == kFalse;  // end undoable change
  if ((fdo_flags & kOptFdoFlagHor) && KeyTyped) {
    foldOpenCursor();
  }
  undisplay_dollar();
  if (gchar_cursor() != NUL || virtual_active(curwin)) {
    start_arrow_with_change(&curwin->w_cursor, end_change);
    if (!end_change) {
      AppendCharToRedobuff(K_RIGHT);
    }
    curwin->w_set_curswant = true;
    if (virtual_active(curwin)) {
      oneright();
    } else {
      curwin->w_cursor.col += utfc_ptr2len(get_cursor_pos_ptr());
    }

    revins_legal++;
    if (revins_chars) {
      revins_chars--;
    }
  } else if (vim_strchr(p_ww, ']') != NULL
             && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
    // if 'whichwrap' set for cursor in insert mode, may move the
    // cursor to the next line
    start_arrow(&curwin->w_cursor);
    curwin->w_set_curswant = true;
    curwin->w_cursor.lnum++;
    curwin->w_cursor.col = 0;
  } else {
    vim_beep(kOptBoFlagCursor);
  }
  dont_sync_undo = kFalse;
}

static void ins_s_right(void)
{
  const bool end_change = dont_sync_undo == kFalse;  // end undoable change
  if ((fdo_flags & kOptFdoFlagHor) && KeyTyped) {
    foldOpenCursor();
  }
  undisplay_dollar();
  if (curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count
      || gchar_cursor() != NUL) {
    start_arrow_with_change(&curwin->w_cursor, end_change);
    if (!end_change) {
      AppendCharToRedobuff(K_S_RIGHT);
    }
    fwd_word(1, false, 0);
    curwin->w_set_curswant = true;
  } else {
    vim_beep(kOptBoFlagCursor);
  }
  dont_sync_undo = kFalse;
}

/// @param startcol  when true move to Insstart.col
static void ins_up(bool startcol)
{
  linenr_T old_topline = curwin->w_topline;
  int old_topfill = curwin->w_topfill;

  undisplay_dollar();
  pos_T tpos = curwin->w_cursor;
  if (cursor_up(1, true) == OK) {
    if (startcol) {
      coladvance(curwin, getvcol_nolist(&Insstart));
    }
    if (old_topline != curwin->w_topline
        || old_topfill != curwin->w_topfill) {
      redraw_later(curwin, UPD_VALID);
    }
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(kOptBoFlagCursor);
  }
}

static void ins_pageup(void)
{
  undisplay_dollar();

  if (mod_mask & MOD_MASK_CTRL) {
    // <C-PageUp>: tab page back
    if (first_tabpage->tp_next != NULL) {
      start_arrow(&curwin->w_cursor);
      goto_tabpage(-1);
    }
    return;
  }

  pos_T tpos = curwin->w_cursor;
  if (pagescroll(BACKWARD, 1, false) == OK) {
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(kOptBoFlagCursor);
  }
}

/// @param startcol  when true move to Insstart.col
static void ins_down(bool startcol)
{
  linenr_T old_topline = curwin->w_topline;
  int old_topfill = curwin->w_topfill;

  undisplay_dollar();
  pos_T tpos = curwin->w_cursor;
  if (cursor_down(1, true) == OK) {
    if (startcol) {
      coladvance(curwin, getvcol_nolist(&Insstart));
    }
    if (old_topline != curwin->w_topline
        || old_topfill != curwin->w_topfill) {
      redraw_later(curwin, UPD_VALID);
    }
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(kOptBoFlagCursor);
  }
}

static void ins_pagedown(void)
{
  undisplay_dollar();

  if (mod_mask & MOD_MASK_CTRL) {
    // <C-PageDown>: tab page forward
    if (first_tabpage->tp_next != NULL) {
      start_arrow(&curwin->w_cursor);
      goto_tabpage(0);
    }
    return;
  }

  pos_T tpos = curwin->w_cursor;
  if (pagescroll(FORWARD, 1, false) == OK) {
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(kOptBoFlagCursor);
  }
}

/// Handle TAB in Insert or Replace mode.
///
/// @return true when the TAB needs to be inserted like a normal character.
static bool ins_tab(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  int temp;

  if (Insstart_blank_vcol == MAXCOL && curwin->w_cursor.lnum == Insstart.lnum) {
    Insstart_blank_vcol = get_nolist_virtcol();
  }
  if (echeck_abbr(TAB + ABBR_OFF)) {
    return false;
  }

  bool ind = inindent(0);
  if (ind) {
    can_cindent = false;
  }

  // When nothing special, insert TAB like a normal character.
  if (!curbuf->b_p_et
      && !(
           p_sta
           && ind
           // These five lines mean 'tabstop' != 'shiftwidth'
           && ((tabstop_count(curbuf->b_p_vts_array) > 1)
               || (tabstop_count(curbuf->b_p_vts_array) == 1
                   && tabstop_first(curbuf->b_p_vts_array)
                   != get_sw_value(curbuf))
               || (tabstop_count(curbuf->b_p_vts_array) == 0
                   && curbuf->b_p_ts != get_sw_value(curbuf))))
      && tabstop_count(curbuf->b_p_vsts_array) == 0 && get_sts_value() == 0) {
    return true;
  }

  if (stop_arrow() == FAIL) {
    return true;
  }

  did_ai = false;
  did_si = false;
  can_si = false;
  can_si_back = false;
  AppendToRedobuff("\t");

  if (p_sta && ind) {  // insert tab in indent, use 'shiftwidth'
    temp = get_sw_value(curbuf);
    temp -= get_nolist_virtcol() % temp;
  } else if (tabstop_count(curbuf->b_p_vsts_array) > 0
             || curbuf->b_p_sts != 0) {
    // use 'softtabstop' when set
    temp = tabstop_padding(get_nolist_virtcol(),
                           get_sts_value(),
                           curbuf->b_p_vsts_array);
  } else {
    // otherwise use 'tabstop'
    temp = tabstop_padding(get_nolist_virtcol(),
                           curbuf->b_p_ts,
                           curbuf->b_p_vts_array);
  }

  // Insert the first space with ins_char().    It will delete one char in
  // replace mode.  Insert the rest with ins_str(); it will not delete any
  // chars.  For MODE_VREPLACE state, we use ins_char() for all characters.
  ins_char(' ');
  while (--temp > 0) {
    if (State & VREPLACE_FLAG) {
      ins_char(' ');
    } else {
      ins_str(" ");
      if (State & REPLACE_FLAG) {            // no char replaced
        replace_push_nul();
      }
    }
  }

  // When 'expandtab' not set: Replace spaces by TABs where possible.
  if (!curbuf->b_p_et && (tabstop_count(curbuf->b_p_vsts_array) > 0
                          || get_sts_value() > 0
                          || (p_sta && ind))) {
    char *ptr;
    char *saved_line = NULL;         // init for GCC
    pos_T pos;
    pos_T *cursor;
    colnr_T want_vcol, vcol;
    int change_col = -1;
    int save_list = curwin->w_p_list;

    // Get the current line.  For MODE_VREPLACE state, don't make real
    // changes yet, just work on a copy of the line.
    if (State & VREPLACE_FLAG) {
      pos = curwin->w_cursor;
      cursor = &pos;
      saved_line = xstrnsave(get_cursor_line_ptr(), (size_t)get_cursor_line_len());
      ptr = saved_line + pos.col;
    } else {
      ptr = get_cursor_pos_ptr();
      cursor = &curwin->w_cursor;
    }

    // When 'L' is not in 'cpoptions' a tab always takes up 'ts' spaces.
    if (vim_strchr(p_cpo, CPO_LISTWM) == NULL) {
      curwin->w_p_list = false;
    }

    // Find first white before the cursor
    pos_T fpos = curwin->w_cursor;
    while (fpos.col > 0 && ascii_iswhite(ptr[-1])) {
      fpos.col--;
      ptr--;
    }

    // In Replace mode, don't change characters before the insert point.
    if ((State & REPLACE_FLAG)
        && fpos.lnum == Insstart.lnum
        && fpos.col < Insstart.col) {
      ptr += Insstart.col - fpos.col;
      fpos.col = Insstart.col;
    }

    // compute virtual column numbers of first white and cursor
    getvcol(curwin, &fpos, &vcol, NULL, NULL);
    getvcol(curwin, cursor, &want_vcol, NULL, NULL);

    char *tab = "\t";
    int32_t tab_v = (uint8_t)(*tab);

    CharsizeArg csarg;
    CSType cstype = init_charsize_arg(&csarg, curwin, 0, tab);

    // Use as many TABs as possible.  Beware of 'breakindent', 'showbreak'
    // and 'linebreak' adding extra virtual columns.
    while (ascii_iswhite(*ptr)) {
      int i = win_charsize(cstype, vcol, tab, tab_v, &csarg).width;
      if (vcol + i > want_vcol) {
        break;
      }
      if (*ptr != TAB) {
        *ptr = TAB;
        if (change_col < 0) {
          change_col = fpos.col;            // Column of first change
          // May have to adjust Insstart
          if (fpos.lnum == Insstart.lnum && fpos.col < Insstart.col) {
            Insstart.col = fpos.col;
          }
        }
      }
      fpos.col++;
      ptr++;
      vcol += i;
    }

    if (change_col >= 0) {
      int repl_off = 0;
      // Skip over the spaces we need.
      cstype = init_charsize_arg(&csarg, curwin, 0, ptr);
      while (vcol < want_vcol && *ptr == ' ') {
        vcol += win_charsize(cstype, vcol, ptr, (uint8_t)(' '), &csarg).width;
        ptr++;
        repl_off++;
      }

      if (vcol > want_vcol) {
        // Must have a char with 'showbreak' just before it.
        ptr--;
        repl_off--;
      }
      fpos.col += repl_off;

      // Delete following spaces.
      int i = cursor->col - fpos.col;
      if (i > 0) {
        if (!(State & VREPLACE_FLAG)) {
          char *newp = xmalloc((size_t)(curbuf->b_ml.ml_line_len - i));
          ptrdiff_t col = ptr - curbuf->b_ml.ml_line_ptr;
          if (col > 0) {
            memmove(newp, ptr - col, (size_t)col);
          }
          memmove(newp + col, ptr + i, (size_t)(curbuf->b_ml.ml_line_len - col - i));
          if (curbuf->b_ml.ml_flags & (ML_LINE_DIRTY | ML_ALLOCATED)) {
            xfree(curbuf->b_ml.ml_line_ptr);
          }
          curbuf->b_ml.ml_line_ptr = newp;
          curbuf->b_ml.ml_line_len -= i;
          curbuf->b_ml.ml_flags = (curbuf->b_ml.ml_flags | ML_LINE_DIRTY) & ~ML_EMPTY;
          inserted_bytes(fpos.lnum, change_col,
                         cursor->col - change_col, fpos.col - change_col);
        } else {
          STRMOVE(ptr, ptr + i);
        }
        // correct replace stack.
        if ((State & REPLACE_FLAG) && !(State & VREPLACE_FLAG)) {
          for (temp = i; --temp >= 0;) {
            replace_join(repl_off);
          }
        }
      }
      cursor->col -= i;

      // In MODE_VREPLACE state, we haven't changed anything yet.  Do it
      // now by backspacing over the changed spacing and then inserting
      // the new spacing.
      if (State & VREPLACE_FLAG) {
        // Backspace from real cursor to change_col
        backspace_until_column(change_col);

        // Insert each char in saved_line from changed_col to
        // ptr-cursor
        ins_bytes_len(saved_line + change_col, (size_t)(cursor->col - change_col));
      }
    }

    if (State & VREPLACE_FLAG) {
      xfree(saved_line);
    }
    curwin->w_p_list = save_list;
  }

  return false;
}

/// Handle CR or NL in insert mode.
///
/// @return false when it can't undo.
bool ins_eol(int c)
{
  if (echeck_abbr(c + ABBR_OFF)) {
    return true;
  }
  if (stop_arrow() == FAIL) {
    return false;
  }
  undisplay_dollar();

  // Strange Vi behaviour: In Replace mode, typing a NL will not delete the
  // character under the cursor.  Only push a NUL on the replace stack,
  // nothing to put back when the NL is deleted.
  if ((State & REPLACE_FLAG) && !(State & VREPLACE_FLAG)) {
    replace_push_nul();
  }

  // In MODE_VREPLACE state, a NL replaces the rest of the line, and starts
  // replacing the next line, so we push all of the characters left on the
  // line onto the replace stack.  This is not done here though, it is done
  // in open_line().

  // Put cursor on NUL if on the last char and coladd is 1 (happens after
  // CTRL-O).
  if (virtual_active(curwin) && curwin->w_cursor.coladd > 0) {
    coladvance(curwin, getviscol());
  }

  // NL in reverse insert will always start in the end of current line.
  if (revins_on) {
    curwin->w_cursor.col += get_cursor_pos_len();
  }

  AppendToRedobuff(NL_STR);
  bool i = open_line(FORWARD,
                     has_format_option(FO_RET_COMS) ? OPENLINE_DO_COM : 0,
                     old_indent, NULL);
  old_indent = 0;
  can_cindent = true;
  // When inserting a line the cursor line must never be in a closed fold.
  foldOpenCursor();

  return i;
}

// Handle digraph in insert mode.
// Returns character still to be inserted, or NUL when nothing remaining to be
// done.
static int ins_digraph(void)
{
  bool did_putchar = false;

  pc_status = PC_STATUS_UNSET;
  if (redrawing() && !char_avail()) {
    // may need to redraw when no more chars available now
    ins_redraw(false);

    edit_putchar('?', true);
    did_putchar = true;
    add_to_showcmd_c(Ctrl_K);
  }

  // don't map the digraph chars. This also prevents the
  // mode message to be deleted when ESC is hit
  no_mapping++;
  allow_keys++;
  int c = plain_vgetc();
  no_mapping--;
  allow_keys--;
  if (did_putchar) {
    // when the line fits in 'columns' the '?' is at the start of the next
    // line and will not be removed by the redraw
    edit_unputchar();
  }

  if (IS_SPECIAL(c) || mod_mask) {          // special key
    clear_showcmd();
    insert_special(c, true, false);
    return NUL;
  }
  if (c != ESC) {
    did_putchar = false;
    if (redrawing() && !char_avail()) {
      // may need to redraw when no more chars available now
      ins_redraw(false);

      if (char2cells(c) == 1) {
        ins_redraw(false);
        edit_putchar(c, true);
        did_putchar = true;
      }
      add_to_showcmd_c(c);
    }
    no_mapping++;
    allow_keys++;
    int cc = plain_vgetc();
    no_mapping--;
    allow_keys--;
    if (did_putchar) {
      // when the line fits in 'columns' the '?' is at the start of the
      // next line and will not be removed by a redraw
      edit_unputchar();
    }
    if (cc != ESC) {
      AppendToRedobuff(CTRL_V_STR);
      c = digraph_get(c, cc, true);
      clear_showcmd();
      return c;
    }
  }
  clear_showcmd();
  return NUL;
}

// Handle CTRL-E and CTRL-Y in Insert mode: copy char from other line.
// Returns the char to be inserted, or NUL if none found.
int ins_copychar(linenr_T lnum)
{
  if (lnum < 1 || lnum > curbuf->b_ml.ml_line_count) {
    vim_beep(kOptBoFlagCopy);
    return NUL;
  }

  // try to advance to the cursor column
  validate_virtcol(curwin);
  int const end_vcol = curwin->w_virtcol;
  char *line = ml_get(lnum);

  CharsizeArg csarg;
  CSType cstype = init_charsize_arg(&csarg, curwin, lnum, line);
  StrCharInfo ci = utf_ptr2StrCharInfo(line);
  int vcol = 0;
  while (vcol < end_vcol && *ci.ptr != NUL) {
    vcol += win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
    if (vcol > end_vcol) {
      break;
    }
    ci = utfc_next(ci);
  }

  int c = ci.chr.value < 0 ? (uint8_t)(*ci.ptr) : ci.chr.value;
  if (c == NUL) {
    vim_beep(kOptBoFlagCopy);
  }
  return c;
}

// CTRL-Y or CTRL-E typed in Insert mode.
static int ins_ctrl_ey(int tc)
{
  int c = tc;

  if (ctrl_x_mode_scroll()) {
    if (c == Ctrl_Y) {
      scrolldown_clamp();
    } else {
      scrollup_clamp();
    }
    redraw_later(curwin, UPD_VALID);
  } else {
    c = ins_copychar(curwin->w_cursor.lnum + (c == Ctrl_Y ? -1 : 1));
    if (c != NUL) {
      // The character must be taken literally, insert like it
      // was typed after a CTRL-V, and pretend 'textwidth'
      // wasn't set.  Digits, 'o' and 'x' are special after a
      // CTRL-V, don't use it for these.
      if (c < 256 && !isalnum(c)) {
        AppendToRedobuff(CTRL_V_STR);
      }
      OptInt tw_save = curbuf->b_p_tw;
      curbuf->b_p_tw = -1;
      insert_special(c, true, false);
      curbuf->b_p_tw = tw_save;
      revins_chars++;
      revins_legal++;
      c = Ctrl_V;       // pretend CTRL-V is last character
      auto_format(false, true);
    }
  }
  return c;
}

// Try to do some very smart auto-indenting.
// Used when inserting a "normal" character.
static void ins_try_si(int c)
{
  pos_T *pos;

  // do some very smart indenting when entering '{' or '}'
  if (((did_si || can_si_back) && c == '{') || (can_si && c == '}' && inindent(0))) {
    pos_T old_pos;
    char *ptr;
    int i;
    bool temp;
    // for '}' set indent equal to indent of line containing matching '{'
    if (c == '}' && (pos = findmatch(NULL, '{')) != NULL) {
      old_pos = curwin->w_cursor;
      // If the matching '{' has a ')' immediately before it (ignoring
      // white-space), then line up with the start of the line
      // containing the matching '(' if there is one.  This handles the
      // case where an "if (..\n..) {" statement continues over multiple
      // lines -- webb
      ptr = ml_get(pos->lnum);
      i = pos->col;
      if (i > 0) {              // skip blanks before '{'
        while (--i > 0 && ascii_iswhite(ptr[i])) {}
      }
      curwin->w_cursor.lnum = pos->lnum;
      curwin->w_cursor.col = i;
      if (ptr[i] == ')' && (pos = findmatch(NULL, '(')) != NULL) {
        curwin->w_cursor = *pos;
      }
      i = get_indent();
      curwin->w_cursor = old_pos;
      if (State & VREPLACE_FLAG) {
        change_indent(INDENT_SET, i, false, true);
      } else {
        set_indent(i, SIN_CHANGED);
      }
    } else if (curwin->w_cursor.col > 0) {
      // when inserting '{' after "O" reduce indent, but not
      // more than indent of previous line
      temp = true;
      if (c == '{' && can_si_back && curwin->w_cursor.lnum > 1) {
        old_pos = curwin->w_cursor;
        i = get_indent();
        while (curwin->w_cursor.lnum > 1) {
          ptr = skipwhite(ml_get(--(curwin->w_cursor.lnum)));

          // ignore empty lines and lines starting with '#'.
          if (*ptr != '#' && *ptr != NUL) {
            break;
          }
        }
        if (get_indent() >= i) {
          temp = false;
        }
        curwin->w_cursor = old_pos;
      }
      if (temp) {
        shift_line(true, false, 1, true);
      }
    }
  }

  // set indent of '#' always to 0
  if (curwin->w_cursor.col > 0 && can_si && c == '#' && inindent(0)) {
    // remember current indent for next line
    old_indent = get_indent();
    set_indent(0, SIN_CHANGED);
  }

  // Adjust ai_col, the char at this position can be deleted.
  ai_col = MIN(ai_col, curwin->w_cursor.col);
}

// Get the value that w_virtcol would have when 'list' is off.
// Unless 'cpo' contains the 'L' flag.
colnr_T get_nolist_virtcol(void)
{
  // check validity of cursor in current buffer
  if (curwin->w_buffer == NULL || curwin->w_buffer->b_ml.ml_mfp == NULL
      || curwin->w_cursor.lnum > curwin->w_buffer->b_ml.ml_line_count) {
    return 0;
  }
  if (curwin->w_p_list && vim_strchr(p_cpo, CPO_LISTWM) == NULL) {
    return getvcol_nolist(&curwin->w_cursor);
  }
  validate_virtcol(curwin);
  return curwin->w_virtcol;
}

// Handle the InsertCharPre autocommand.
// "c" is the character that was typed.
// Return a pointer to allocated memory with the replacement string.
// Return NULL to continue inserting "c".
static char *do_insert_char_pre(int c)
{
  char buf[MB_MAXBYTES + 1];
  const int save_State = State;

  if (c == Ctrl_RSB) {
    return NULL;
  }

  // Return quickly when there is nothing to do.
  if (!has_event(EVENT_INSERTCHARPRE)) {
    return NULL;
  }
  buf[utf_char2bytes(c, buf)] = NUL;

  // Lock the text to avoid weird things from happening.
  textlock++;
  set_vim_var_string(VV_CHAR, buf, -1);

  char *res = NULL;
  if (ins_apply_autocmds(EVENT_INSERTCHARPRE)) {
    // Get the value of v:char.  It may be empty or more than one
    // character.  Only use it when changed, otherwise continue with the
    // original character to avoid breaking autoindent.
    if (strcmp(buf, get_vim_var_str(VV_CHAR)) != 0) {
      res = xstrdup(get_vim_var_str(VV_CHAR));
    }
  }

  set_vim_var_string(VV_CHAR, NULL, -1);
  textlock--;

  // Restore the State, it may have been changed.
  State = save_State;

  return res;
}

bool get_can_cindent(void)
{
  return can_cindent;
}

void set_can_cindent(bool val)
{
  can_cindent = val;
}

/// Trigger "event" and take care of fixing undo.
int ins_apply_autocmds(event_T event)
{
  varnumber_T tick = buf_get_changedtick(curbuf);

  int r = apply_autocmds(event, NULL, NULL, false, curbuf);

  // If u_savesub() was called then we are not prepared to start
  // a new line.  Call u_save() with no contents to fix that.
  // Except when leaving Insert mode.
  if (event != EVENT_INSERTLEAVE && tick != buf_get_changedtick(curbuf)) {
    u_save(curwin->w_cursor.lnum, (linenr_T)(curwin->w_cursor.lnum + 1));
  }

  return r;
}
