// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * edit.c: functions for Insert mode
 */

#include <assert.h>
#include <string.h>
#include <inttypes.h>
#include <stdbool.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/edit.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/digraph.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/farsi.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/getchar.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/keymap.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/path.h"
#include "nvim/popupmnu.h"
#include "nvim/quickfix.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/strings.h"
#include "nvim/state.h"
#include "nvim/syntax.h"
#include "nvim/tag.h"
#include "nvim/ui.h"
#include "nvim/mouse.h"
#include "nvim/terminal.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/event/loop.h"
#include "nvim/mark.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"

/*
 * definitions used for CTRL-X submode
 */
#define CTRL_X_WANT_IDENT       0x100

#define CTRL_X_NOT_DEFINED_YET  1
#define CTRL_X_SCROLL           2
#define CTRL_X_WHOLE_LINE       3
#define CTRL_X_FILES            4
#define CTRL_X_TAGS             (5 + CTRL_X_WANT_IDENT)
#define CTRL_X_PATH_PATTERNS    (6 + CTRL_X_WANT_IDENT)
#define CTRL_X_PATH_DEFINES     (7 + CTRL_X_WANT_IDENT)
#define CTRL_X_FINISHED         8
#define CTRL_X_DICTIONARY       (9 + CTRL_X_WANT_IDENT)
#define CTRL_X_THESAURUS        (10 + CTRL_X_WANT_IDENT)
#define CTRL_X_CMDLINE          11
#define CTRL_X_FUNCTION         12
#define CTRL_X_OMNI             13
#define CTRL_X_SPELL            14
#define CTRL_X_LOCAL_MSG        15      /* only used in "ctrl_x_msgs" */
#define CTRL_X_EVAL             16  ///< for builtin function complete()

#define CTRL_X_MSG(i) ctrl_x_msgs[(i) & ~CTRL_X_WANT_IDENT]
#define CTRL_X_MODE_LINE_OR_EVAL(m) (m == CTRL_X_WHOLE_LINE || m == CTRL_X_EVAL)

static char *ctrl_x_msgs[] =
{
  N_(" Keyword completion (^N^P)"),   /* ctrl_x_mode == 0, ^P/^N compl. */
  N_(" ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)"),
  NULL,
  N_(" Whole line completion (^L^N^P)"),
  N_(" File name completion (^F^N^P)"),
  N_(" Tag completion (^]^N^P)"),
  N_(" Path pattern completion (^N^P)"),
  N_(" Definition completion (^D^N^P)"),
  NULL,
  N_(" Dictionary completion (^K^N^P)"),
  N_(" Thesaurus completion (^T^N^P)"),
  N_(" Command-line completion (^V^N^P)"),
  N_(" User defined completion (^U^N^P)"),
  N_(" Omni completion (^O^N^P)"),
  N_(" Spelling suggestion (s^N^P)"),
  N_(" Keyword Local completion (^N^P)"),
  NULL,  // CTRL_X_EVAL doesn't use msg.
};

static char e_hitend[] = N_("Hit end of paragraph");
static char e_complwin[] = N_("E839: Completion function changed window");
static char e_compldel[] = N_("E840: Completion function deleted text");

/*
 * Structure used to store one match for insert completion.
 */
typedef struct compl_S compl_T;
struct compl_S {
  compl_T     *cp_next;
  compl_T     *cp_prev;
  char_u      *cp_str;          /* matched text */
  char cp_icase;                /* TRUE or FALSE: ignore case */
  char_u      *(cp_text[CPT_COUNT]);    /* text for the menu */
  char_u      *cp_fname;        /* file containing the match, allocated when
                                 * cp_flags has FREE_FNAME */
  int cp_flags;                 /* ORIGINAL_TEXT, CONT_S_IPOS or FREE_FNAME */
  int cp_number;                /* sequence number */
};

#define ORIGINAL_TEXT   (1)   /* the original text when the expansion begun */
#define FREE_FNAME      (2)

/*
 * All the current matches are stored in a list.
 * "compl_first_match" points to the start of the list.
 * "compl_curr_match" points to the currently selected entry.
 * "compl_shown_match" is different from compl_curr_match during
 * ins_compl_get_exp().
 */
static compl_T    *compl_first_match = NULL;
static compl_T    *compl_curr_match = NULL;
static compl_T    *compl_shown_match = NULL;
static compl_T    *compl_old_match = NULL;

/* After using a cursor key <Enter> selects a match in the popup menu,
 * otherwise it inserts a line break. */
static int compl_enter_selects = FALSE;

/* When "compl_leader" is not NULL only matches that start with this string
 * are used. */
static char_u     *compl_leader = NULL;

static int compl_get_longest = FALSE;           /* put longest common string
                                                   in compl_leader */

static int compl_no_insert = FALSE;             /* FALSE: select & insert
                                                   TRUE: noinsert */
static int compl_no_select = FALSE;             /* FALSE: select & insert
                                                   TRUE: noselect */

static int compl_used_match;            /* Selected one of the matches.  When
                                           FALSE the match was edited or using
                                           the longest common string. */

static int compl_was_interrupted = FALSE;         /* didn't finish finding
                                                     completions. */

static int compl_restarting = FALSE;            /* don't insert match */

/* When the first completion is done "compl_started" is set.  When it's
 * FALSE the word to be completed must be located. */
static int compl_started = FALSE;

static int compl_matches = 0;
static char_u     *compl_pattern = NULL;
static int compl_direction = FORWARD;
static int compl_shows_dir = FORWARD;
static int compl_pending = 0;               /* > 1 for postponed CTRL-N */
static pos_T compl_startpos;
static colnr_T compl_col = 0;               /* column where the text starts
                                             * that is being completed */
static char_u     *compl_orig_text = NULL;  /* text as it was before
                                             * completion started */
static int compl_cont_mode = 0;
static expand_T compl_xp;

static int compl_opt_refresh_always = FALSE;

typedef struct insert_state {
  VimState state;
  cmdarg_T *ca;
  int mincol;
  int cmdchar;
  int startln;
  long count;
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
  char_u *ptr;
} InsertState;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "edit.c.generated.h"
#endif
#define BACKSPACE_CHAR              1
#define BACKSPACE_WORD              2
#define BACKSPACE_WORD_NOT_SPACE    3
#define BACKSPACE_LINE              4

static size_t spell_bad_len = 0;   /* length of located bad word */

static colnr_T Insstart_textlen;        /* length of line when insert started */
static colnr_T Insstart_blank_vcol;     /* vcol for first inserted blank */
static bool update_Insstart_orig = true; /* set Insstart_orig to Insstart */

static char_u   *last_insert = NULL;    /* the text of the previous insert,
                                           K_SPECIAL and CSI are escaped */
static int last_insert_skip;      /* nr of chars in front of previous insert */
static int new_insert_skip;       /* nr of chars in front of current insert */
static int did_restart_edit;            /* "restart_edit" when calling edit() */

static bool can_cindent;                // may do cindenting on this line

static int old_indent = 0;              /* for ^^D command in insert mode */

static int revins_on;                   /* reverse insert mode on */
static int revins_chars;                /* how much to skip after edit */
static int revins_legal;                /* was the last char 'legal'? */
static int revins_scol;                 /* start column of revins session */

static int ins_need_undo;               /* call u_save() before inserting a
                                           char.  Set when edit() is called.
                                           after that arrow_used is used. */

static bool did_add_space = false;      // auto_format() added an extra space
                                        // under the cursor
static TriState dont_sync_undo = kFalse;  // CTRL-G U prevents syncing undo
                                          // for the next left/right cursor

static linenr_T o_lnum = 0;

static void insert_enter(InsertState *s)
{
  s->did_backspace = true;
  s->old_topfill = -1;
  s->replaceState = REPLACE;
  // Remember whether editing was restarted after CTRL-O
  did_restart_edit = restart_edit;
  // sleep before redrawing, needed for "CTRL-O :" that results in an
  // error message
  check_for_delay(true);
  // set Insstart_orig to Insstart
  update_Insstart_orig = true;

  ins_compl_clear();        // clear stuff for CTRL-X mode

  // Trigger InsertEnter autocommands.  Do not do this for "r<CR>" or "grx".
  if (s->cmdchar != 'r' && s->cmdchar != 'v') {
    pos_T save_cursor = curwin->w_cursor;

    if (s->cmdchar == 'R') {
      s->ptr = (char_u *)"r";
    } else if (s->cmdchar == 'V') {
      s->ptr = (char_u *)"v";
    } else {
      s->ptr = (char_u *)"i";
    }

    set_vim_var_string(VV_INSERTMODE, (char *) s->ptr, 1);
    set_vim_var_string(VV_CHAR, NULL, -1);
    ins_apply_autocmds(EVENT_INSERTENTER);

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
      State = INSERT;
      check_cursor_col();
      State = save_state;
    }
  }

  // Check if the cursor line needs redrawing before changing State. If
  // 'concealcursor' is "n" it needs to be redrawn without concealing.
  conceal_check_cursor_line();

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

  Insstart_textlen = (colnr_T)linetabsize(get_cursor_line_ptr());
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
    if (p_fkmap && p_ri) {
      beep_flush();
      EMSG(farsi_text_3);           // encoded in Farsi
      State = INSERT;
    } else {
      State = REPLACE;
    }
  } else if (s->cmdchar == 'V' || s->cmdchar == 'v') {
    State = VREPLACE;
    s->replaceState = VREPLACE;
    orig_line_count = curbuf->b_ml.ml_line_count;
    vr_lines_changed = 1;
  } else {
    State = INSERT;
  }

  stop_insert_mode = false;

  // Need to recompute the cursor position, it might move when the cursor is
  // on a TAB or special character.
  curs_columns(true);

  // Enable langmap or IME, indicated by 'iminsert'.
  // Note that IME may enabled/disabled without us noticing here, thus the
  // 'iminsert' value may not reflect what is actually used.  It is updated
  // when hitting <Esc>.
  if (curbuf->b_p_iminsert == B_IMODE_LMAP) {
    State |= LANGMAP;
  }

  setmouse();
  clear_showcmd();
  // there is no reverse replace mode
  revins_on = (State == INSERT && p_ri);
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
    if (where_paste_started.lnum) {
      arrow_used = false;
    } else {
      arrow_used = true;
    }
    restart_edit = 0;

    // If the cursor was after the end-of-line before the CTRL-O and it is
    // now at the end-of-line, put it after the end-of-line (this is not
    // correct in very rare cases).
    // Also do this if curswant is greater than the current virtual
    // column.  Eg after "^O$" or "^O80|".
    validate_virtcol();
    update_curswant();
    if (((ins_at_eol && curwin->w_cursor.lnum == o_lnum)
         || curwin->w_curswant > curwin->w_virtcol)
        && *(s->ptr = get_cursor_line_ptr() + curwin->w_cursor.col) != NUL) {
      if (s->ptr[1] == NUL) {
        ++curwin->w_cursor.col;
      } else if (has_mbyte) {
        s->i = (*mb_ptr2len)(s->ptr);
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
  // The cursor line is not in a closed fold, unless 'insertmode' is set or
  // restarting.
  if (!p_im && did_restart_edit == 0) {
    foldOpenCursor();
  }

  // If 'showmode' is set, show the current (insert/replace/..) mode.
  // A warning message for changing a readonly file is given here, before
  // actually changing anything.  It's put after the mode, if any.
  s->i = 0;
  if (p_smd && msg_silent == 0) {
    s->i = showmode();
  }

  if (!p_im && did_restart_edit == 0) {
    change_warning(s->i == 0 ? 0 : s->i + 1);
  }

  ui_cursor_shape();            /* may show different cursor shape */
  do_digraph(-1);               /* clear digraphs */

  // Get the current length of the redo buffer, those characters have to be
  // skipped if we want to get to the inserted characters.
  s->ptr = get_inserted();
  if (s->ptr == NULL) {
    new_insert_skip = 0;
  } else {
    new_insert_skip = (int)STRLEN(s->ptr);
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

  foldUpdateAfterInsert();
  if (s->cmdchar != 'r' && s->cmdchar != 'v') {
    ins_apply_autocmds(EVENT_INSERTLEAVE);
  }
  did_cursorhold = false;
}

static int insert_check(VimState *state)
{
  InsertState *s = (InsertState *)state;

  // If typed something may trigger CursorHoldI again.
  if (s->c != K_EVENT
      // but not in CTRL-X mode, a script can't restore the state
      && ctrl_x_mode == 0) {
    did_cursorhold = false;
  }

  // If the cursor was moved we didn't just insert a space */
  if (arrow_used) {
    s->inserted_space = false;
  }

  if (can_cindent && cindent_on() && ctrl_x_mode == 0) {
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

  if (stop_insert_mode && !pum_visible()) {
    // ":stopinsert" used or 'insertmode' reset
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
  if (fdo_flags & FDO_INSERT) {
    foldOpenCursor();
  }

  // Close folds where the cursor isn't, according to 'foldclose'
  if (!char_avail()) {
    foldCheckClose();
  }

  // If we inserted a character at the last position of the last line in the
  // window, scroll the window one line up. This avoids an extra redraw.  This
  // is detected when the cursor column is smaller after inserting something.
  // Don't do this when the topline changed already, it has already been
  // adjusted (by insertchar() calling open_line())).
  if (curbuf->b_mod_set
      && curwin->w_p_wrap
      && !s->did_backspace
      && curwin->w_topline == s->old_topline
      && curwin->w_topfill == s->old_topfill) {
    s->mincol = curwin->w_wcol;
    validate_cursor_col();

    if (curwin->w_wcol < s->mincol - curbuf->b_p_ts
        && curwin->w_wrow == curwin->w_winrow
        + curwin->w_height - 1 - p_so
        && (curwin->w_cursor.lnum != curwin->w_topline
            || curwin->w_topfill > 0)) {
      if (curwin->w_topfill > 0) {
        --curwin->w_topfill;
      } else if (hasFolding(curwin->w_topline, NULL, &s->old_topline)) {
        set_topline(curwin, s->old_topline + 1);
      } else {
        set_topline(curwin, curwin->w_topline + 1);
      }
    }
  }

  // May need to adjust w_topline to show the cursor.
  update_topline();

  s->did_backspace = false;

  validate_cursor();                  // may set must_redraw

  // Redraw the display when no characters are waiting.
  // Also shows mode, ruler and positions cursor.
  ins_redraw(true);

  if (curwin->w_p_scb) {
    do_check_scrollbind(true);
  }

  if (curwin->w_p_crb) {
    do_check_cursorbind();
  }

  update_curswant();
  s->old_topline = curwin->w_topline;
  s->old_topfill = curwin->w_topfill;
  s->lastc = s->c;   // remember previous char for CTRL-D

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
  if (key == K_IGNORE) {
    return -1;  // get another key
  }
  InsertState *s = (InsertState *)state;
  s->c = key;

  // Don't want K_EVENT with cursorhold for the second key, e.g., after CTRL-V.
  did_cursorhold = true;

  if (p_hkmap && KeyTyped) {
    s->c = hkmap(s->c);  // Hebrew mode mapping
  }

  if (p_fkmap && KeyTyped) {
    s->c = fkmap(s->c);  // Farsi mode mapping
  }

  // Special handling of keys while the popup menu is visible or wanted
  // and the cursor is still in the completed word.  Only when there is
  // a match, skip this when no matches were found.
  if (compl_started
      && pum_wanted()
      && curwin->w_cursor.col >= compl_col
      && (compl_shown_match == NULL
          || compl_shown_match != compl_shown_match->cp_next)) {
    // BS: Delete one character from "compl_leader".
    if ((s->c == K_BS || s->c == Ctrl_H)
        && curwin->w_cursor.col > compl_col
        && (s->c = ins_compl_bs()) == NUL) {
      return 1;  // continue
    }

    // When no match was selected or it was edited.
    if (!compl_used_match) {
      // CTRL-L: Add one character from the current match to
      // "compl_leader".  Except when at the original match and
      // there is nothing to add, CTRL-L works like CTRL-P then.
      if (s->c == Ctrl_L
          && (!CTRL_X_MODE_LINE_OR_EVAL(ctrl_x_mode)
              || (int)STRLEN(compl_shown_match->cp_str)
              > curwin->w_cursor.col - compl_col)) {
        ins_compl_addfrommatch();
        return 1;  // continue
      }

      // A non-white character that fits in with the current
      // completion: Add to "compl_leader".
      if (ins_compl_accept_char(s->c)) {
        // Trigger InsertCharPre.
        char_u *str = do_insert_char_pre(s->c);
        char_u *p;

        if (str != NULL) {
          for (p = str; *p != NUL; MB_PTR_ADV(p)) {
            ins_compl_addleader(PTR2CHAR(p));
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
           || (compl_enter_selects
               && (s->c == CAR || s->c == K_KENTER || s->c == NL)))
          && stop_arrow() == OK) {
        ins_compl_delete();
        ins_compl_insert(false);
      }
    }
  }

  // Prepare for or stop CTRL-X mode. This doesn't do completion, but it does
  // fix up the text when finishing completion.
  compl_get_longest = false;
  if (ins_compl_prep(s->c)) {
    return 1;  // continue
  }

  // CTRL-\ CTRL-N goes to Normal mode,
  // CTRL-\ CTRL-G goes to mode selected with 'insertmode',
  // CTRL-\ CTRL-O is like CTRL-O but without moving the cursor
  if (s->c == Ctrl_BSL) {
    // may need to redraw when no more chars available now
    ins_redraw(false);
    no_mapping++;
    s->c = plain_vgetc();
    no_mapping--;
    if (s->c != Ctrl_N && s->c != Ctrl_G && s->c != Ctrl_O) {
      // it's something else
      vungetc(s->c);
      s->c = Ctrl_BSL;
    } else if (s->c == Ctrl_G && p_im) {
      return 1;  // continue
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

  s->c = do_digraph(s->c);

  if ((s->c == Ctrl_V || s->c == Ctrl_Q) && ctrl_x_mode == CTRL_X_CMDLINE) {
    insert_do_complete(s);
    return 1;
  }

  if (s->c == Ctrl_V || s->c == Ctrl_Q) {
    ins_ctrl_v();
    s->c = Ctrl_V;       // pretend CTRL-V is last typed character
    return 1;  // continue
  }

  if (cindent_on()
      && ctrl_x_mode == 0) {
    // A key name preceded by a bang means this key is not to be
    // inserted.  Skip ahead to the re-indenting below.
    // A key name preceded by a star means that indenting has to be
    // done before inserting the key.
    s->line_is_white = inindent(0);
    if (in_cinkeys(s->c, '!', s->line_is_white)) {
      insert_do_cindent(s);
      return 1;  // continue
    }

    if (can_cindent && in_cinkeys(s->c, '*', s->line_is_white)
        && stop_arrow() == OK) {
      do_c_expr_indent();
    }
  }

  if (curwin->w_p_rl)
    switch (s->c) {
      case K_LEFT:    s->c = K_RIGHT; break;
      case K_S_LEFT:  s->c = K_S_RIGHT; break;
      case K_C_LEFT:  s->c = K_C_RIGHT; break;
      case K_RIGHT:   s->c = K_LEFT; break;
      case K_S_RIGHT: s->c = K_S_LEFT; break;
      case K_C_RIGHT: s->c = K_C_LEFT; break;
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
      // Close the cmdline window. */
      cmdwin_result = K_IGNORE;
      got_int = false;         // don't stop executing autocommands et al
      s->nomove = true;
      return 0;  // exit insert mode
    }

    // when 'insertmode' set, and not halfway through a mapping, don't leave
    // Insert mode
    if (goto_im()) {
      if (got_int) {
        (void)vgetc();                        // flush all buffers
        got_int = false;
      } else {
        vim_beep(BO_IM);
      }
      break;
    }
    return 0;  // exit insert mode

  case Ctrl_Z:        // suspend when 'insertmode' set
    if (!p_im) {
      goto normalchar;                // insert CTRL-Z as normal char
    }
    do_cmdline_cmd("stop");
    ui_cursor_shape();  // may need to update cursor shape
    break;

  case Ctrl_O:        // execute one command
    if (ctrl_x_mode == CTRL_X_OMNI) {
      insert_do_complete(s);
      break;
    }

    if (echeck_abbr(Ctrl_O + ABBR_OFF)) {
      break;
    }

    ins_ctrl_o();

    // don't move the cursor left when 'virtualedit' has "onemore".
    if (ve_flags & VE_ONEMORE) {
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
    if (p_im) {
      need_start_insertmode = true;
    }
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
    if (stuff_inserted(NUL, 1L, (s->c == Ctrl_A)) == FAIL
        && s->c != Ctrl_A && !p_im) {
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
    if (ctrl_x_mode == CTRL_X_PATH_DEFINES) {
      insert_do_complete(s);
      break;
    }
    FALLTHROUGH;

  case Ctrl_T:        // Make indent one shiftwidth greater.
    if (s->c == Ctrl_T && ctrl_x_mode == CTRL_X_THESAURUS) {
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
    s->did_backspace = ins_bs(s->c, BACKSPACE_WORD, &s->inserted_space);
    auto_format(false, true);
    break;

  case Ctrl_U:        // delete all inserted text in current line
    // CTRL-X CTRL-U completes with 'completefunc'.
    if (ctrl_x_mode == CTRL_X_FUNCTION) {
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

  case K_EVENT:       // some event
    multiqueue_process_events(main_loop.events);
    break;

  case K_COMMAND:       // some command
    do_cmdline(NULL, getcmdkeycmd, NULL, 0);
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
      ins_left(dont_sync_undo == kFalse);
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
      ins_right(dont_sync_undo == kFalse);
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
    if (ctrl_x_mode == CTRL_X_PATH_PATTERNS) {
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
    if (ins_eol(s->c) && !p_im) {
      return 0;  // out of memory
    }
    auto_format(false, false);
    s->inserted_space = false;
    break;

  case Ctrl_K:        // digraph or keyword completion
    if (ctrl_x_mode == CTRL_X_DICTIONARY) {
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
    if (ctrl_x_mode != CTRL_X_TAGS) {
      goto normalchar;
    } else {
      insert_do_complete(s);
    }
    break;

  case Ctrl_F:        // File name completion after ^X
    if (ctrl_x_mode != CTRL_X_FILES) {
      goto normalchar;
    } else {
      insert_do_complete(s);
    }
    break;

  case 's':           // Spelling completion after ^X
  case Ctrl_S:
    if (ctrl_x_mode != CTRL_X_SPELL) {
      goto normalchar;
    } else {
      insert_do_complete(s);
    }
    break;

  case Ctrl_L:        // Whole line completion after ^X
    if (ctrl_x_mode != CTRL_X_WHOLE_LINE) {
      // CTRL-L with 'insertmode' set: Leave Insert mode
      if (p_im) {
        if (echeck_abbr(Ctrl_L + ABBR_OFF)) {
          break;
        }
        return 0;  // exit insert mode
      }
      goto normalchar;
    }
    FALLTHROUGH;

  case Ctrl_P:        // Do previous/next pattern completion
  case Ctrl_N:
    // if 'complete' is empty then plain ^P is no longer special,
    // but it is under other ^X modes
    if (*curbuf->b_p_cpt == NUL
        && ctrl_x_mode != 0
        && !(compl_cont_status & CONT_LOCAL)) {
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

    if (mod_mask == MOD_MASK_ALT || mod_mask == MOD_MASK_META) {
      // Unmapped ALT/META chord behaves like ESC+c. #8213
      stuffcharReadbuff(ESC);
      stuffcharReadbuff(s->c);
      break;
    }

    if (!p_paste) {
      // Trigger InsertCharPre.
      char_u *str = do_insert_char_pre(s->c);
      char_u *p;

      if (str != NULL) {
        if (*str != NUL && stop_arrow() != FAIL) {
          // Insert the new value of v:char literally.
          for (p = str; *p != NUL; MB_PTR_ADV(p)) {
            s->c = PTR2CHAR(p);
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
      if (s->c == NUL)
        break;
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
        || (!echeck_abbr(
          // Add ABBR_OFF for characters above 0x100, this is
          // what check_abbr() expects.
          (has_mbyte && s->c >= 0x100) ? (s->c + ABBR_OFF) : s->c)
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
  if (ins_complete(s->c, true) == FAIL) {
    compl_cont_status = 0;
  }
  compl_busy = false;
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
bool edit(int cmdchar, bool startln, long count)
{
  if (curbuf->terminal) {
    if (ex_normal_busy) {
      // Do not enter terminal mode from ex_normal(), which would cause havoc
      // (such as terminal-mode recursiveness). Instead set a flag to force-set
      // the value of `restart_edit` before `ex_normal` returns.
      restart_edit = 'i';
      force_restart_edit = true;
    } else {
      terminal_enter();
    }
    return false;
  }

  // Don't allow inserting in the sandbox.
  if (sandbox != 0) {
    EMSG(_(e_sandbox));
    return false;
  }

  // Don't allow changes in the buffer while editing the cmdline.  The
  // caller of getcmdline() may get confused.
  if (textlock != 0) {
    EMSG(_(e_secure));
    return false;
  }

  // Don't allow recursive insert mode when busy with completion.
  if (compl_started || compl_busy || pum_visible()) {
    EMSG(_(e_secure));
    return false;
  }

  InsertState state, *s = &state;
  memset(s, 0, sizeof(InsertState));
  s->state.execute = insert_execute;
  s->state.check = insert_check;
  s->cmdchar = cmdchar;
  s->startln = startln;
  s->count = count;
  insert_enter(s);
  return s->c == Ctrl_O;
}

/*
 * Redraw for Insert mode.
 * This is postponed until getting the next character to make '$' in the 'cpo'
 * option work correctly.
 * Only redraw when there are no characters available.  This speeds up
 * inserting sequences of characters (e.g., for CTRL-R).
 */
static void
ins_redraw (
    int ready                   /* not busy with something */
)
{
  linenr_T conceal_old_cursor_line = 0;
  linenr_T conceal_new_cursor_line = 0;
  int conceal_update_lines = FALSE;

  if (char_avail())
    return;

  // Trigger CursorMoved if the cursor moved.  Not when the popup menu is
  // visible, the command might delete it.
  if (ready && (has_event(EVENT_CURSORMOVEDI) || curwin->w_p_cole > 0)
      && !equalpos(last_cursormoved, curwin->w_cursor)
      && !pum_visible()) {
    // Need to update the screen first, to make sure syntax
    // highlighting is correct after making a change (e.g., inserting
    // a "(".  The autocommand may also require a redraw, so it's done
    // again below, unfortunately.
    if (syntax_present(curwin) && must_redraw) {
      update_screen(0);
    }
    if (has_event(EVENT_CURSORMOVEDI)) {
      // Make sure curswant is correct, an autocommand may call
      // getcurpos()
      update_curswant();
      ins_apply_autocmds(EVENT_CURSORMOVEDI);
    }
    if (curwin->w_p_cole > 0) {
      conceal_old_cursor_line = last_cursormoved.lnum;
      conceal_new_cursor_line = curwin->w_cursor.lnum;
      conceal_update_lines = TRUE;
    }
    last_cursormoved = curwin->w_cursor;
  }

  // Trigger TextChangedI if changedtick differs.
  if (ready && has_event(EVENT_TEXTCHANGEDI)
      && curbuf->b_last_changedtick != buf_get_changedtick(curbuf)
      && !pum_visible()) {
    aco_save_T aco;
    varnumber_T tick = buf_get_changedtick(curbuf);

    // save and restore curwin and curbuf, in case the autocmd changes them
    aucmd_prepbuf(&aco, curbuf);
    apply_autocmds(EVENT_TEXTCHANGEDI, NULL, NULL, false, curbuf);
    aucmd_restbuf(&aco);
    curbuf->b_last_changedtick = buf_get_changedtick(curbuf);
    if (tick != buf_get_changedtick(curbuf)) {  // see ins_apply_autocmds()
      u_save(curwin->w_cursor.lnum,
             (linenr_T)(curwin->w_cursor.lnum + 1));
    }
  }

  // Trigger TextChangedP if changedtick differs. When the popupmenu closes
  // TextChangedI will need to trigger for backwards compatibility, thus use
  // different b_last_changedtick* variables.
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

  if (must_redraw)
    update_screen(0);
  else if (clear_cmdline || redraw_cmdline)
    showmode();                 /* clear cmdline and show mode */
  if ((conceal_update_lines
       && (conceal_old_cursor_line != conceal_new_cursor_line
           || conceal_cursor_line(curwin)))
      || need_cursor_line_redraw) {
    if (conceal_old_cursor_line != conceal_new_cursor_line)
      update_single_line(curwin, conceal_old_cursor_line);
    update_single_line(curwin, conceal_new_cursor_line == 0
        ? curwin->w_cursor.lnum : conceal_new_cursor_line);
    curwin->w_valid &= ~VALID_CROW;
  }
  showruler(FALSE);
  setcursor();
  emsg_on_display = FALSE;      /* may remove error message now */
}

/*
 * Handle a CTRL-V or CTRL-Q typed in Insert mode.
 */
static void ins_ctrl_v(void)
{
  int c;
  int did_putchar = FALSE;

  /* may need to redraw when no more chars available now */
  ins_redraw(FALSE);

  if (redrawing() && !char_avail()) {
    edit_putchar('^', TRUE);
    did_putchar = TRUE;
  }
  AppendToRedobuff(CTRL_V_STR);

  add_to_showcmd_c(Ctrl_V);

  c = get_literal();
  if (did_putchar)
    /* when the line fits in 'columns' the '^' is at the start of the next
     * line and will not removed by the redraw */
    edit_unputchar();
  clear_showcmd();
  insert_special(c, true, true);
  revins_chars++;
  revins_legal++;
}

/*
 * Put a character directly onto the screen.  It's not stored in a buffer.
 * Used while handling CTRL-K, CTRL-V, etc. in Insert mode.
 */
static int pc_status;
#define PC_STATUS_UNSET 0       /* pc_bytes was not set */
#define PC_STATUS_RIGHT 1       /* right halve of double-wide char */
#define PC_STATUS_LEFT  2       /* left halve of double-wide char */
#define PC_STATUS_SET   3       /* pc_bytes was filled */
static char_u pc_bytes[MB_MAXBYTES + 1]; /* saved bytes */
static int pc_attr;
static int pc_row;
static int pc_col;

void edit_putchar(int c, int highlight)
{
  int attr;

  if (ScreenLines != NULL) {
    update_topline();           /* just in case w_topline isn't valid */
    validate_cursor();
    if (highlight) {
      attr = HL_ATTR(HLF_8);
    } else {
      attr = 0;
    }
    pc_row = curwin->w_winrow + curwin->w_wrow;
    pc_col = curwin->w_wincol;
    pc_status = PC_STATUS_UNSET;
    if (curwin->w_p_rl) {
      pc_col += curwin->w_width - 1 - curwin->w_wcol;
      if (has_mbyte) {
        int fix_col = mb_fix_col(pc_col, pc_row);

        if (fix_col != pc_col) {
          screen_putchar(' ', pc_row, fix_col, attr);
          --curwin->w_wcol;
          pc_status = PC_STATUS_RIGHT;
        }
      }
    } else {
      pc_col += curwin->w_wcol;
      if (mb_lefthalve(pc_row, pc_col))
        pc_status = PC_STATUS_LEFT;
    }

    /* save the character to be able to put it back */
    if (pc_status == PC_STATUS_UNSET) {
      screen_getbytes(pc_row, pc_col, pc_bytes, &pc_attr);
      pc_status = PC_STATUS_SET;
    }
    screen_putchar(c, pc_row, pc_col, attr);
  }
}

/*
 * Undo the previous edit_putchar().
 */
void edit_unputchar(void)
{
  if (pc_status != PC_STATUS_UNSET && pc_row >= msg_scrolled) {
    if (pc_status == PC_STATUS_RIGHT) {
      curwin->w_wcol++;
    }
    if (pc_status == PC_STATUS_RIGHT || pc_status == PC_STATUS_LEFT) {
      redrawWinline(curwin, curwin->w_cursor.lnum, false);
    } else {
      screen_puts(pc_bytes, pc_row - msg_scrolled, pc_col, pc_attr);
    }
  }
}

/*
 * Called when p_dollar is set: display a '$' at the end of the changed text
 * Only works when cursor is in the line that changes.
 */
void display_dollar(colnr_T col)
{
  colnr_T save_col;

  if (!redrawing())
    return;

  save_col = curwin->w_cursor.col;
  curwin->w_cursor.col = col;

  // If on the last byte of a multi-byte move to the first byte.
  char_u *p = get_cursor_line_ptr();
  curwin->w_cursor.col -= utf_head_off(p, p + col);
  curs_columns(false);              // Recompute w_wrow and w_wcol
  if (curwin->w_wcol < curwin->w_width) {
    edit_putchar('$', FALSE);
    dollar_vcol = curwin->w_virtcol;
  }
  curwin->w_cursor.col = save_col;
}

/*
 * Call this function before moving the cursor from the normal insert position
 * in insert mode.
 */
static void undisplay_dollar(void)
{
  if (dollar_vcol >= 0) {
    dollar_vcol = -1;
    redrawWinline(curwin, curwin->w_cursor.lnum, false);
  }
}

/*
 * Insert an indent (for <Tab> or CTRL-T) or delete an indent (for CTRL-D).
 * Keep the cursor on the same character.
 * type == INDENT_INC	increase indent (for CTRL-T or <Tab>)
 * type == INDENT_DEC	decrease indent (for CTRL-D)
 * type == INDENT_SET	set indent to "amount"
 * if round is TRUE, round the indent to 'shiftwidth' (only with _INC and _Dec).
 */
void
change_indent (
    int type,
    int amount,
    int round,
    int replaced,                   /* replaced character, put on replace stack */
    int call_changed_bytes                 /* call changed_bytes() */
)
{
  int vcol;
  int last_vcol;
  int insstart_less;                    /* reduction for Insstart.col */
  int new_cursor_col;
  int i;
  char_u      *ptr;
  int save_p_list;
  int start_col;
  colnr_T vc;
  colnr_T orig_col = 0;                 /* init for GCC */
  char_u      *new_line, *orig_line = NULL;     /* init for GCC */

  /* VREPLACE mode needs to know what the line was like before changing */
  if (State & VREPLACE_FLAG) {
    orig_line = vim_strsave(get_cursor_line_ptr());   /* Deal with NULL below */
    orig_col = curwin->w_cursor.col;
  }

  /* for the following tricks we don't want list mode */
  save_p_list = curwin->w_p_list;
  curwin->w_p_list = FALSE;
  vc = getvcol_nolist(&curwin->w_cursor);
  vcol = vc;

  /*
   * For Replace mode we need to fix the replace stack later, which is only
   * possible when the cursor is in the indent.  Remember the number of
   * characters before the cursor if it's possible.
   */
  start_col = curwin->w_cursor.col;

  /* determine offset from first non-blank */
  new_cursor_col = curwin->w_cursor.col;
  beginline(BL_WHITE);
  new_cursor_col -= curwin->w_cursor.col;

  insstart_less = curwin->w_cursor.col;

  /*
   * If the cursor is in the indent, compute how many screen columns the
   * cursor is to the left of the first non-blank.
   */
  if (new_cursor_col < 0)
    vcol = get_indent() - vcol;

  if (new_cursor_col > 0)           /* can't fix replace stack */
    start_col = -1;

  /*
   * Set the new indent.  The cursor will be put on the first non-blank.
   */
  if (type == INDENT_SET)
    (void)set_indent(amount, call_changed_bytes ? SIN_CHANGED : 0);
  else {
    int save_State = State;

    /* Avoid being called recursively. */
    if (State & VREPLACE_FLAG)
      State = INSERT;
    shift_line(type == INDENT_DEC, round, 1, call_changed_bytes);
    State = save_State;
  }
  insstart_less -= curwin->w_cursor.col;

  /*
   * Try to put cursor on same character.
   * If the cursor is at or after the first non-blank in the line,
   * compute the cursor column relative to the column of the first
   * non-blank character.
   * If we are not in insert mode, leave the cursor on the first non-blank.
   * If the cursor is before the first non-blank, position it relative
   * to the first non-blank, counted in screen columns.
   */
  if (new_cursor_col >= 0) {
    /*
     * When changing the indent while the cursor is touching it, reset
     * Insstart_col to 0.
     */
    if (new_cursor_col == 0)
      insstart_less = MAXCOL;
    new_cursor_col += curwin->w_cursor.col;
  } else if (!(State & INSERT))
    new_cursor_col = curwin->w_cursor.col;
  else {
    /*
     * Compute the screen column where the cursor should be.
     */
    vcol = get_indent() - vcol;
    curwin->w_virtcol = (colnr_T)((vcol < 0) ? 0 : vcol);

    /*
     * Advance the cursor until we reach the right screen column.
     */
    vcol = last_vcol = 0;
    new_cursor_col = -1;
    ptr = get_cursor_line_ptr();
    while (vcol <= (int)curwin->w_virtcol) {
      last_vcol = vcol;
      if (has_mbyte && new_cursor_col >= 0)
        new_cursor_col += (*mb_ptr2len)(ptr + new_cursor_col);
      else
        ++new_cursor_col;
      vcol += lbr_chartabsize(ptr, ptr + new_cursor_col, (colnr_T)vcol);
    }
    vcol = last_vcol;

    /*
     * May need to insert spaces to be able to position the cursor on
     * the right screen column.
     */
    if (vcol != (int)curwin->w_virtcol) {
      curwin->w_cursor.col = (colnr_T)new_cursor_col;
      i = (int)curwin->w_virtcol - vcol;
      ptr = xmallocz(i);
      memset(ptr, ' ', i);
      new_cursor_col += i;
      ins_str(ptr);
      xfree(ptr);
    }

    /*
     * When changing the indent while the cursor is in it, reset
     * Insstart_col to 0.
     */
    insstart_less = MAXCOL;
  }

  curwin->w_p_list = save_p_list;

  if (new_cursor_col <= 0)
    curwin->w_cursor.col = 0;
  else
    curwin->w_cursor.col = (colnr_T)new_cursor_col;
  curwin->w_set_curswant = TRUE;
  changed_cline_bef_curs();

  /*
   * May have to adjust the start of the insert.
   */
  if (State & INSERT) {
    if (curwin->w_cursor.lnum == Insstart.lnum && Insstart.col != 0) {
      if ((int)Insstart.col <= insstart_less)
        Insstart.col = 0;
      else
        Insstart.col -= insstart_less;
    }
    if ((int)ai_col <= insstart_less)
      ai_col = 0;
    else
      ai_col -= insstart_less;
  }

  /*
   * For REPLACE mode, may have to fix the replace stack, if it's possible.
   * If the number of characters before the cursor decreased, need to pop a
   * few characters from the replace stack.
   * If the number of characters before the cursor increased, need to push a
   * few NULs onto the replace stack.
   */
  if (REPLACE_NORMAL(State) && start_col >= 0) {
    while (start_col > (int)curwin->w_cursor.col) {
      replace_join(0);              /* remove a NUL from the replace stack */
      --start_col;
    }
    while (start_col < (int)curwin->w_cursor.col || replaced) {
      replace_push(NUL);
      if (replaced) {
        replace_push(replaced);
        replaced = NUL;
      }
      ++start_col;
    }
  }

  /*
   * For VREPLACE mode, we also have to fix the replace stack.  In this case
   * it is always possible because we backspace over the whole line and then
   * put it back again the way we wanted it.
   */
  if (State & VREPLACE_FLAG) {
    /* Save new line */
    new_line = vim_strsave(get_cursor_line_ptr());

    /* We only put back the new line up to the cursor */
    new_line[curwin->w_cursor.col] = NUL;

    // Put back original line
    ml_replace(curwin->w_cursor.lnum, orig_line, false);
    curwin->w_cursor.col = orig_col;

    /* Backspace from cursor to start of line */
    backspace_until_column(0);

    /* Insert new stuff into line again */
    ins_bytes(new_line);

    xfree(new_line);
  }
}

/*
 * Truncate the space at the end of a line.  This is to be used only in an
 * insert mode.  It handles fixing the replace stack for REPLACE and VREPLACE
 * modes.
 */
void truncate_spaces(char_u *line)
{
  int i;

  /* find start of trailing white space */
  for (i = (int)STRLEN(line) - 1; i >= 0 && ascii_iswhite(line[i]); i--) {
    if (State & REPLACE_FLAG)
      replace_join(0);              /* remove a NUL from the replace stack */
  }
  line[i + 1] = NUL;
}

/*
 * Backspace the cursor until the given column.  Handles REPLACE and VREPLACE
 * modes correctly.  May also be used when not in insert mode at all.
 * Will attempt not to go before "col" even when there is a composing
 * character.
 */
void backspace_until_column(int col)
{
  while ((int)curwin->w_cursor.col > col) {
    curwin->w_cursor.col--;
    if (State & REPLACE_FLAG)
      replace_do_bs(col);
    else if (!del_char_after_col(col))
      break;
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
  if (enc_utf8 && limit_col >= 0) {
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

/*
 * CTRL-X pressed in Insert mode.
 */
static void ins_ctrl_x(void)
{
  /* CTRL-X after CTRL-X CTRL-V doesn't do anything, so that CTRL-X
   * CTRL-V works like CTRL-N */
  if (ctrl_x_mode != CTRL_X_CMDLINE) {
    /* if the next ^X<> won't ADD nothing, then reset
     * compl_cont_status */
    if (compl_cont_status & CONT_N_ADDS)
      compl_cont_status |= CONT_INTRPT;
    else
      compl_cont_status = 0;
    /* We're not sure which CTRL-X mode it will be yet */
    ctrl_x_mode = CTRL_X_NOT_DEFINED_YET;
    edit_submode = (char_u *)_(CTRL_X_MSG(ctrl_x_mode));
    edit_submode_pre = NULL;
    showmode();
  }
}

/// Check that the "dict" or "tsr" option can be used.
///
/// @param  dict_opt  check "dict" when true, "tsr" when false.
static bool check_compl_option(bool dict_opt)
{
  if (dict_opt
      ? (*curbuf->b_p_dict == NUL && *p_dict == NUL && !curwin->w_p_spell)
      : (*curbuf->b_p_tsr == NUL && *p_tsr == NUL)) {
    ctrl_x_mode = 0;
    edit_submode = NULL;
    msg_attr((dict_opt
              ? _("'dictionary' option is empty")
              : _("'thesaurus' option is empty")), HL_ATTR(HLF_E));
    if (emsg_silent == 0) {
      vim_beep(BO_COMPL);
      setcursor();
      ui_flush();
      os_delay(2000L, false);
    }
    return false;
  }
  return true;
}

/// Check that the character "c" a valid key to go to or keep us in CTRL-X mode?
/// This depends on the current mode.
///
/// @param  c  character to check
bool vim_is_ctrl_x_key(int c)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Always allow ^R - let its results then be checked
  if (c == Ctrl_R) {
    return true;
  }

  // Accept <PageUp> and <PageDown> if the popup menu is visible.
  if (ins_compl_pum_key(c)) {
    return true;
  }

  switch (ctrl_x_mode) {
  case 0:  // Not in any CTRL-X mode
    return c == Ctrl_N || c == Ctrl_P || c == Ctrl_X;
  case CTRL_X_NOT_DEFINED_YET:
    return c == Ctrl_X || c == Ctrl_Y || c == Ctrl_E
           || c == Ctrl_L || c == Ctrl_F || c == Ctrl_RSB
           || c == Ctrl_I || c == Ctrl_D || c == Ctrl_P
           || c == Ctrl_N || c == Ctrl_T || c == Ctrl_V
           || c == Ctrl_Q || c == Ctrl_U || c == Ctrl_O
           || c == Ctrl_S || c == Ctrl_K || c == 's';
  case CTRL_X_SCROLL:
    return c == Ctrl_Y || c == Ctrl_E;
  case CTRL_X_WHOLE_LINE:
    return c == Ctrl_L || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_FILES:
    return c == Ctrl_F || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_DICTIONARY:
    return c == Ctrl_K || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_THESAURUS:
    return c == Ctrl_T || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_TAGS:
    return c == Ctrl_RSB || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_PATH_PATTERNS:
    return c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_PATH_DEFINES:
    return c == Ctrl_D || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_CMDLINE:
    return c == Ctrl_V || c == Ctrl_Q || c == Ctrl_P || c == Ctrl_N
           || c == Ctrl_X;
  case CTRL_X_FUNCTION:
    return c == Ctrl_U || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_OMNI:
    return c == Ctrl_O || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_SPELL:
    return c == Ctrl_S || c == Ctrl_P || c == Ctrl_N;
  case CTRL_X_EVAL:
    return (c == Ctrl_P || c == Ctrl_N);
  }
  internal_error("vim_is_ctrl_x_key()");
  return false;
}

/// Check that character "c" is part of the item currently being
/// completed.  Used to decide whether to abandon complete mode when the menu
/// is visible.
///
/// @param  c  character to check
static bool ins_compl_accept_char(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (ctrl_x_mode & CTRL_X_WANT_IDENT) {
    // When expanding an identifier only accept identifier chars.
    return vim_isIDc(c);
  }

  switch (ctrl_x_mode) {
  case CTRL_X_FILES:
    // When expanding file name only accept file name chars. But not
    // path separators, so that "proto/<Tab>" expands files in
    // "proto", not "proto/" as a whole
    return vim_isfilec(c) && !vim_ispathsep(c);

  case CTRL_X_CMDLINE:
  case CTRL_X_OMNI:
    // Command line and Omni completion can work with just about any
    // printable character, but do stop at white space.
    return vim_isprintc(c) && !ascii_iswhite(c);

  case CTRL_X_WHOLE_LINE:
    // For while line completion a space can be part of the line.
    return vim_isprintc(c);
  }
  return vim_iswordc(c);
}

/*
 * This is like ins_compl_add(), but if 'ic' and 'inf' are set, then the
 * case of the originally typed text is used, and the case of the completed
 * text is inferred, ie this tries to work out what case you probably wanted
 * the rest of the word to be in -- webb
 */
int ins_compl_add_infercase(char_u *str, int len, int icase, char_u *fname, int dir, int flags)
{
  int i, c;
  int actual_len;                       /* Take multi-byte characters */
  int actual_compl_length;              /* into account. */
  int min_len;
  int         *wca;                     /* Wide character array. */
  int has_lower = FALSE;
  int was_letter = FALSE;

  if (p_ic && curbuf->b_p_inf && len > 0) {
    // Infer case of completed part.

    // Find actual length of completion.
    if (has_mbyte) {
      const char_u *p = str;
      actual_len = 0;
      while (*p != NUL) {
        MB_PTR_ADV(p);
        actual_len++;
      }
    } else
      actual_len = len;

    /* Find actual length of original text. */
    if (has_mbyte) {
      const char_u *p = compl_orig_text;
      actual_compl_length = 0;
      while (*p != NUL) {
        MB_PTR_ADV(p);
        actual_compl_length++;
      }
    } else
      actual_compl_length = compl_length;

    /* "actual_len" may be smaller than "actual_compl_length" when using
     * thesaurus, only use the minimum when comparing. */
    min_len = actual_len < actual_compl_length
              ? actual_len : actual_compl_length;

    /* Allocate wide character array for the completion and fill it. */
    wca = xmalloc(actual_len * sizeof(*wca));
    {
      const char_u *p = str;
      for (i = 0; i < actual_len; i++) {
        if (has_mbyte) {
          wca[i] = mb_ptr2char_adv(&p);
        } else {
          wca[i] = *(p++);
        }
      }
    }

    // Rule 1: Were any chars converted to lower?
    {
      const char_u *p = compl_orig_text;
      for (i = 0; i < min_len; i++) {
        if (has_mbyte) {
          c = mb_ptr2char_adv(&p);
        } else {
          c = *(p++);
        }
        if (mb_islower(c)) {
          has_lower = true;
          if (mb_isupper(wca[i])) {
            // Rule 1 is satisfied.
            for (i = actual_compl_length; i < actual_len; i++) {
              wca[i] = mb_tolower(wca[i]);
            }
            break;
          }
        }
      }
    }

    /*
     * Rule 2: No lower case, 2nd consecutive letter converted to
     * upper case.
     */
    if (!has_lower) {
      const char_u *p = compl_orig_text;
      for (i = 0; i < min_len; i++) {
        if (has_mbyte) {
          c = mb_ptr2char_adv(&p);
        } else {
          c = *(p++);
        }
        if (was_letter && mb_isupper(c) && mb_islower(wca[i])) {
          // Rule 2 is satisfied.
          for (i = actual_compl_length; i < actual_len; i++) {
            wca[i] = mb_toupper(wca[i]);
          }
          break;
        }
        was_letter = mb_islower(c) || mb_isupper(c);
      }
    }

    // Copy the original case of the part we typed.
    {
      const char_u *p = compl_orig_text;
      for (i = 0; i < min_len; i++) {
        if (has_mbyte) {
          c = mb_ptr2char_adv(&p);
        } else {
          c = *(p++);
        }
        if (mb_islower(c)) {
          wca[i] = mb_tolower(wca[i]);
        } else if (mb_isupper(c)) {
          wca[i] = mb_toupper(wca[i]);
        }
      }
    }

    // Generate encoding specific output from wide character array.
    // Multi-byte characters can occupy up to five bytes more than
    // ASCII characters, and we also need one byte for NUL, so stay
    // six bytes away from the edge of IObuff.
    {
      char_u *p = IObuff;
      i = 0;
      while (i < actual_len && (p - IObuff + 6) < IOSIZE) {
        p += utf_char2bytes(wca[i++], p);
      }
      *p = NUL;
    }

    xfree(wca);

    return ins_compl_add(IObuff, len, icase, fname, NULL, false, dir, flags,
                         false);
  }
  return ins_compl_add(str, len, icase, fname, NULL, false, dir, flags, false);
}

/// Add a match to the list of matches
///
/// @param[in]  str  Match to add.
/// @param[in]  len  Match length, -1 to use #STRLEN.
/// @param[in]  icase  Whether case is to be ignored.
/// @param[in]  fname  File name match comes from. May be NULL.
/// @param[in]  cptext  Extra text for popup menu. May be NULL. If not NULL,
///                     must have exactly #CPT_COUNT items.
/// @param[in]  cptext_allocated  If true, will not copy cptext strings.
///
///                               @note Will free strings in case of error.
///                                     cptext itself will not be freed.
/// @param[in]  cdir  Completion direction.
/// @param[in]  adup  True if duplicate matches are to be accepted.
///
/// @return NOTDONE if the given string is already in the list of completions,
///         otherwise it is added to the list and  OK is returned. FAIL will be
///         returned in case of error.
static int ins_compl_add(char_u *const str, int len,
                         const bool icase, char_u *const fname,
                         char_u *const *const cptext,
                         const bool cptext_allocated,
                         const Direction cdir, int flags, const bool adup)
  FUNC_ATTR_NONNULL_ARG(1)
{
  compl_T     *match;
  int dir = (cdir == kDirectionNotSet ? compl_direction : cdir);

  os_breakcheck();
#define FREE_CPTEXT(cptext, cptext_allocated) \
  do { \
    if (cptext != NULL && cptext_allocated) { \
      for (size_t i = 0; i < CPT_COUNT; i++) { \
        xfree(cptext[i]); \
      } \
    } \
  } while (0)
  if (got_int) {
    FREE_CPTEXT(cptext, cptext_allocated);
    return FAIL;
  }
  if (len < 0) {
    len = (int)STRLEN(str);
  }

  /*
   * If the same match is already present, don't add it.
   */
  if (compl_first_match != NULL && !adup) {
    match = compl_first_match;
    do {
      if (!(match->cp_flags & ORIGINAL_TEXT)
          && STRNCMP(match->cp_str, str, len) == 0
          && match->cp_str[len] == NUL) {
        FREE_CPTEXT(cptext, cptext_allocated);
        return NOTDONE;
      }
      match = match->cp_next;
    } while (match != NULL && match != compl_first_match);
  }

  /* Remove any popup menu before changing the list of matches. */
  ins_compl_del_pum();

  /*
   * Allocate a new match structure.
   * Copy the values to the new match structure.
   */
  match = xcalloc(1, sizeof(compl_T));
  match->cp_number = -1;
  if (flags & ORIGINAL_TEXT)
    match->cp_number = 0;
  match->cp_str = vim_strnsave(str, len);
  match->cp_icase = icase;

  /* match-fname is:
   * - compl_curr_match->cp_fname if it is a string equal to fname.
   * - a copy of fname, FREE_FNAME is set to free later THE allocated mem.
   * - NULL otherwise.	--Acevedo */
  if (fname != NULL
      && compl_curr_match != NULL
      && compl_curr_match->cp_fname != NULL
      && STRCMP(fname, compl_curr_match->cp_fname) == 0)
    match->cp_fname = compl_curr_match->cp_fname;
  else if (fname != NULL) {
    match->cp_fname = vim_strsave(fname);
    flags |= FREE_FNAME;
  } else {
    match->cp_fname = NULL;
  }
  match->cp_flags = flags;

  if (cptext != NULL) {
    int i;

    for (i = 0; i < CPT_COUNT; i++) {
      if (cptext[i] == NULL) {
        continue;
      }
      if (*cptext[i] != NUL) {
        match->cp_text[i] = (cptext_allocated
                             ? cptext[i]
                             : (char_u *)xstrdup((char *)cptext[i]));
      } else if (cptext_allocated) {
        xfree(cptext[i]);
      }
    }
  }

  /*
   * Link the new match structure in the list of matches.
   */
  if (compl_first_match == NULL)
    match->cp_next = match->cp_prev = NULL;
  else if (dir == FORWARD) {
    match->cp_next = compl_curr_match->cp_next;
    match->cp_prev = compl_curr_match;
  } else {    /* BACKWARD */
    match->cp_next = compl_curr_match;
    match->cp_prev = compl_curr_match->cp_prev;
  }
  if (match->cp_next)
    match->cp_next->cp_prev = match;
  if (match->cp_prev)
    match->cp_prev->cp_next = match;
  else          /* if there's nothing before, it is the first match */
    compl_first_match = match;
  compl_curr_match = match;

  /*
   * Find the longest common string if still doing that.
   */
  if (compl_get_longest && (flags & ORIGINAL_TEXT) == 0)
    ins_compl_longest_match(match);

  return OK;
}

/// Check that "str[len]" matches with "match->cp_str", considering
/// "match->cp_icase".
///
/// @param  match  completion match
/// @param  str    character string to check
/// @param  len    lenth of "str"
static bool ins_compl_equal(compl_T *match, char_u *str, size_t len)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (match->cp_icase) {
    return STRNICMP(match->cp_str, str, len) == 0;
  }
  return STRNCMP(match->cp_str, str, len) == 0;
}

/*
 * Reduce the longest common string for match "match".
 */
static void ins_compl_longest_match(compl_T *match)
{
  char_u      *p, *s;
  int c1, c2;
  int had_match;

  if (compl_leader == NULL) {
    /* First match, use it as a whole. */
    compl_leader = vim_strsave(match->cp_str);
    had_match = (curwin->w_cursor.col > compl_col);
    ins_compl_delete();
    ins_bytes(compl_leader + ins_compl_len());
    ins_redraw(FALSE);

    /* When the match isn't there (to avoid matching itself) remove it
     * again after redrawing. */
    if (!had_match)
      ins_compl_delete();
    compl_used_match = FALSE;
  } else {
    /* Reduce the text if this match differs from compl_leader. */
    p = compl_leader;
    s = match->cp_str;
    while (*p != NUL) {
      c1 = utf_ptr2char(p);
      c2 = utf_ptr2char(s);

      if (match->cp_icase ? (mb_tolower(c1) != mb_tolower(c2)) : (c1 != c2)) {
        break;
      }
      MB_PTR_ADV(p);
      MB_PTR_ADV(s);
    }

    if (*p != NUL) {
      /* Leader was shortened, need to change the inserted text. */
      *p = NUL;
      had_match = (curwin->w_cursor.col > compl_col);
      ins_compl_delete();
      ins_bytes(compl_leader + ins_compl_len());
      ins_redraw(FALSE);

      /* When the match isn't there (to avoid matching itself) remove it
       * again after redrawing. */
      if (!had_match)
        ins_compl_delete();
    }

    compl_used_match = FALSE;
  }
}

/*
 * Add an array of matches to the list of matches.
 * Frees matches[].
 */
static void ins_compl_add_matches(int num_matches, char_u **matches, int icase)
{
  int i;
  int add_r = OK;
  int dir = compl_direction;

  for (i = 0; i < num_matches && add_r != FAIL; i++)
    if ((add_r = ins_compl_add(matches[i], -1, icase,
                               NULL, NULL, false, dir, 0, false)) == OK) {
      // If dir was BACKWARD then honor it just once.
      dir = FORWARD;
    }
  FreeWild(num_matches, matches);
}

/* Make the completion list cyclic.
 * Return the number of matches (excluding the original).
 */
static int ins_compl_make_cyclic(void)
{
  compl_T *match;
  int count = 0;

  if (compl_first_match != NULL) {
    /*
     * Find the end of the list.
     */
    match = compl_first_match;
    /* there's always an entry for the compl_orig_text, it doesn't count. */
    while (match->cp_next != NULL && match->cp_next != compl_first_match) {
      match = match->cp_next;
      ++count;
    }
    match->cp_next = compl_first_match;
    compl_first_match->cp_prev = match;
  }
  return count;
}

// Set variables that store noselect and noinsert behavior from the
// 'completeopt' value.
void completeopt_was_set(void)
{
  compl_no_insert = false;
  compl_no_select = false;
  if (strstr((char *)p_cot, "noselect") != NULL) {
    compl_no_select = true;
  }
  if (strstr((char *)p_cot, "noinsert") != NULL) {
    compl_no_insert = true;
  }
}


/*
 * Start completion for the complete() function.
 * "startcol" is where the matched text starts (1 is first column).
 * "list" is the list of matches.
 */
void set_completion(colnr_T startcol, list_T *list)
{
  // If already doing completions stop it.
  if (ctrl_x_mode != 0) {
    ins_compl_prep(' ');
  }
  ins_compl_clear();
  ins_compl_free();

  compl_direction = FORWARD;
  if (startcol > curwin->w_cursor.col)
    startcol = curwin->w_cursor.col;
  compl_col = startcol;
  compl_length = (int)curwin->w_cursor.col - (int)startcol;
  /* compl_pattern doesn't need to be set */
  compl_orig_text = vim_strnsave(get_cursor_line_ptr() + compl_col,
                                 compl_length);
  if (ins_compl_add(compl_orig_text, -1, p_ic, NULL, NULL, false, 0,
                    ORIGINAL_TEXT, false) != OK) {
    return;
  }

  ctrl_x_mode = CTRL_X_EVAL;

  ins_compl_add_list(list);
  compl_matches = ins_compl_make_cyclic();
  compl_started = TRUE;
  compl_used_match = TRUE;
  compl_cont_status = 0;
  int save_w_wrow = curwin->w_wrow;
  int save_w_leftcol = curwin->w_leftcol;

  compl_curr_match = compl_first_match;
  if (compl_no_insert || compl_no_select) {
    ins_complete(K_DOWN, false);
    if (compl_no_select) {
      ins_complete(K_UP, false);
    }
  } else {
    ins_complete(Ctrl_N, false);
  }
  compl_enter_selects = compl_no_insert;

  // Lazily show the popup menu, unless we got interrupted.
  if (!compl_interrupted) {
    show_pum(save_w_wrow, save_w_leftcol);
  }

  ui_flush();
}


/* "compl_match_array" points the currently displayed list of entries in the
 * popup menu.  It is NULL when there is no popup menu. */
static pumitem_T *compl_match_array = NULL;
static int compl_match_arraysize;

/*
 * Update the screen and when there is any scrolling remove the popup menu.
 */
static void ins_compl_upd_pum(void)
{
  int h;

  if (compl_match_array != NULL) {
    h = curwin->w_cline_height;
    update_screen(0);
    if (h != curwin->w_cline_height)
      ins_compl_del_pum();
  }
}

/*
 * Remove any popup menu.
 */
static void ins_compl_del_pum(void)
{
  if (compl_match_array != NULL) {
    pum_undisplay();
    xfree(compl_match_array);
    compl_match_array = NULL;
  }
}

/// Check if the popup menu should be displayed.
static bool pum_wanted(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // "completeopt" must contain "menu" or "menuone"
  return vim_strchr(p_cot, 'm') != NULL;
}

/// Check that there are two or more matches to be shown in the popup menu.
/// One if "completopt" contains "menuone".
static bool pum_enough_matches(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Don't display the popup menu if there are no matches or there is only
  // one (ignoring the original text).
  compl_T *comp = compl_first_match;
  int i = 0;
  do {
    if (comp == NULL || ((comp->cp_flags & ORIGINAL_TEXT) == 0 && ++i == 2)) {
      break;
    }
    comp = comp->cp_next;
  } while (comp != compl_first_match);

  if (strstr((char *)p_cot, "menuone") != NULL) {
    return i >= 1;
  }
  return i >= 2;
}

/*
 * Show the popup menu for the list of matches.
 * Also adjusts "compl_shown_match" to an entry that is actually displayed.
 */
void ins_compl_show_pum(void)
{
  compl_T     *compl;
  compl_T     *shown_compl = NULL;
  int did_find_shown_match = FALSE;
  int shown_match_ok = FALSE;
  int i;
  int cur = -1;
  colnr_T col;
  int lead_len = 0;
  bool array_changed = false;

  if (!pum_wanted() || !pum_enough_matches())
    return;

  /* Dirty hard-coded hack: remove any matchparen highlighting. */
  do_cmdline_cmd("if exists('g:loaded_matchparen')|3match none|endif");

  /* Update the screen before drawing the popup menu over it. */
  update_screen(0);

  if (compl_match_array == NULL) {
    array_changed = true;
    // Need to build the popup menu list.
    compl_match_arraysize = 0;
    compl = compl_first_match;
    /*
     * If it's user complete function and refresh_always,
     * not use "compl_leader" as prefix filter.
     */
    if (ins_compl_need_restart()){
      xfree(compl_leader);
      compl_leader = NULL;
    }
    if (compl_leader != NULL)
      lead_len = (int)STRLEN(compl_leader);
    do {
      if ((compl->cp_flags & ORIGINAL_TEXT) == 0
          && (compl_leader == NULL
              || ins_compl_equal(compl, compl_leader, lead_len)))
        ++compl_match_arraysize;
      compl = compl->cp_next;
    } while (compl != NULL && compl != compl_first_match);
    if (compl_match_arraysize == 0)
      return;

    assert(compl_match_arraysize >= 0);
    compl_match_array = xcalloc(compl_match_arraysize, sizeof(pumitem_T));
    /* If the current match is the original text don't find the first
     * match after it, don't highlight anything. */
    if (compl_shown_match->cp_flags & ORIGINAL_TEXT)
      shown_match_ok = TRUE;

    i = 0;
    compl = compl_first_match;
    do {
      if ((compl->cp_flags & ORIGINAL_TEXT) == 0
          && (compl_leader == NULL
              || ins_compl_equal(compl, compl_leader, lead_len))) {
        if (!shown_match_ok) {
          if (compl == compl_shown_match || did_find_shown_match) {
            /* This item is the shown match or this is the
             * first displayed item after the shown match. */
            compl_shown_match = compl;
            did_find_shown_match = TRUE;
            shown_match_ok = TRUE;
          } else
            /* Remember this displayed match for when the
             * shown match is just below it. */
            shown_compl = compl;
          cur = i;
        }

        if (compl->cp_text[CPT_ABBR] != NULL)
          compl_match_array[i].pum_text =
            compl->cp_text[CPT_ABBR];
        else
          compl_match_array[i].pum_text = compl->cp_str;
        compl_match_array[i].pum_kind = compl->cp_text[CPT_KIND];
        compl_match_array[i].pum_info = compl->cp_text[CPT_INFO];
        if (compl->cp_text[CPT_MENU] != NULL)
          compl_match_array[i++].pum_extra =
            compl->cp_text[CPT_MENU];
        else
          compl_match_array[i++].pum_extra = compl->cp_fname;
      }

      if (compl == compl_shown_match) {
        did_find_shown_match = TRUE;

        /* When the original text is the shown match don't set
         * compl_shown_match. */
        if (compl->cp_flags & ORIGINAL_TEXT)
          shown_match_ok = TRUE;

        if (!shown_match_ok && shown_compl != NULL) {
          /* The shown match isn't displayed, set it to the
           * previously displayed match. */
          compl_shown_match = shown_compl;
          shown_match_ok = TRUE;
        }
      }
      compl = compl->cp_next;
    } while (compl != NULL && compl != compl_first_match);

    if (!shown_match_ok)          /* no displayed match at all */
      cur = -1;
  } else {
    /* popup menu already exists, only need to find the current item.*/
    for (i = 0; i < compl_match_arraysize; ++i)
      if (compl_match_array[i].pum_text == compl_shown_match->cp_str
          || compl_match_array[i].pum_text
          == compl_shown_match->cp_text[CPT_ABBR]) {
        cur = i;
        break;
      }
  }

  // In Replace mode when a $ is displayed at the end of the line only
  // part of the screen would be updated.  We do need to redraw here.
  dollar_vcol = -1;

  // Compute the screen column of the start of the completed text.
  // Use the cursor to get all wrapping and other settings right.
  col = curwin->w_cursor.col;
  curwin->w_cursor.col = compl_col;
  pum_display(compl_match_array, compl_match_arraysize, cur, array_changed);
  curwin->w_cursor.col = col;
}

#define DICT_FIRST      (1)     /* use just first element in "dict" */
#define DICT_EXACT      (2)     /* "dict" is the exact name of a file */

/*
 * Add any identifiers that match the given pattern in the list of dictionary
 * files "dict_start" to the list of completions.
 */
static void
ins_compl_dictionaries (
    char_u *dict_start,
    char_u *pat,
    int flags,                      /* DICT_FIRST and/or DICT_EXACT */
    int thesaurus                  /* Thesaurus completion */
)
{
  char_u      *dict = dict_start;
  char_u      *ptr;
  char_u      *buf;
  regmatch_T regmatch;
  char_u      **files;
  int count;
  int save_p_scs;
  int dir = compl_direction;

  if (*dict == NUL) {
    /* When 'dictionary' is empty and spell checking is enabled use
     * "spell". */
    if (!thesaurus && curwin->w_p_spell)
      dict = (char_u *)"spell";
    else
      return;
  }

  buf = xmalloc(LSIZE);
  regmatch.regprog = NULL;      /* so that we can goto theend */

  /* If 'infercase' is set, don't use 'smartcase' here */
  save_p_scs = p_scs;
  if (curbuf->b_p_inf)
    p_scs = FALSE;

  /* When invoked to match whole lines for CTRL-X CTRL-L adjust the pattern
   * to only match at the start of a line.  Otherwise just match the
   * pattern. Also need to double backslashes. */
  if (CTRL_X_MODE_LINE_OR_EVAL(ctrl_x_mode)) {
    char_u *pat_esc = vim_strsave_escaped(pat, (char_u *)"\\");

    size_t len = STRLEN(pat_esc) + 10;
    ptr = xmalloc(len);
    vim_snprintf((char *)ptr, len, "^\\s*\\zs\\V%s", pat_esc);
    regmatch.regprog = vim_regcomp(ptr, RE_MAGIC);
    xfree(pat_esc);
    xfree(ptr);
  } else {
    regmatch.regprog = vim_regcomp(pat, p_magic ? RE_MAGIC : 0);
    if (regmatch.regprog == NULL)
      goto theend;
  }

  /* ignore case depends on 'ignorecase', 'smartcase' and "pat" */
  regmatch.rm_ic = ignorecase(pat);
  while (*dict != NUL && !got_int && !compl_interrupted) {
    /* copy one dictionary file name into buf */
    if (flags == DICT_EXACT) {
      count = 1;
      files = &dict;
    } else {
      /* Expand wildcards in the dictionary name, but do not allow
       * backticks (for security, the 'dict' option may have been set in
       * a modeline). */
      copy_option_part(&dict, buf, LSIZE, ",");
      if (!thesaurus && STRCMP(buf, "spell") == 0)
        count = -1;
      else if (vim_strchr(buf, '`') != NULL
               || expand_wildcards(1, &buf, &count, &files,
                   EW_FILE|EW_SILENT) != OK)
        count = 0;
    }

    if (count == -1) {
      /* Complete from active spelling.  Skip "\<" in the pattern, we
       * don't use it as a RE. */
      if (pat[0] == '\\' && pat[1] == '<')
        ptr = pat + 2;
      else
        ptr = pat;
      spell_dump_compl(ptr, regmatch.rm_ic, &dir, 0);
    } else if (count > 0) {  /* avoid warning for using "files" uninit */
      ins_compl_files(count, files, thesaurus, flags,
          &regmatch, buf, &dir);
      if (flags != DICT_EXACT)
        FreeWild(count, files);
    }
    if (flags != 0)
      break;
  }

theend:
  p_scs = save_p_scs;
  vim_regfree(regmatch.regprog);
  xfree(buf);
}

static void ins_compl_files(int count, char_u **files, int thesaurus, int flags, regmatch_T *regmatch, char_u *buf, int *dir)
{
  char_u      *ptr;
  int i;
  FILE        *fp;
  int add_r;

  for (i = 0; i < count && !got_int && !compl_interrupted; i++) {
    fp = mch_fopen((char *)files[i], "r");      /* open dictionary file */
    if (flags != DICT_EXACT) {
      vim_snprintf((char *)IObuff, IOSIZE,
                   _("Scanning dictionary: %s"), (char *)files[i]);
      (void)msg_trunc_attr(IObuff, true, HL_ATTR(HLF_R));
    }

    if (fp == NULL) {
      continue;
    }
    /*
     * Read dictionary file line by line.
     * Check each line for a match.
     */
    while (!got_int && !compl_interrupted
           && !vim_fgets(buf, LSIZE, fp)) {
      ptr = buf;
      while (vim_regexec(regmatch, buf, (colnr_T)(ptr - buf))) {
        ptr = regmatch->startp[0];
        if (CTRL_X_MODE_LINE_OR_EVAL(ctrl_x_mode)) {
          ptr = find_line_end(ptr);
        } else {
          ptr = find_word_end(ptr);
        }
        add_r = ins_compl_add_infercase(regmatch->startp[0],
            (int)(ptr - regmatch->startp[0]),
            p_ic, files[i], *dir, 0);
        if (thesaurus) {
          char_u *wstart;

          /*
           * Add the other matches on the line
           */
          ptr = buf;
          while (!got_int) {
            /* Find start of the next word.  Skip white
             * space and punctuation. */
            ptr = find_word_start(ptr);
            if (*ptr == NUL || *ptr == NL)
              break;
            wstart = ptr;

            /* Find end of the word. */
            if (has_mbyte)
              /* Japanese words may have characters in
               * different classes, only separate words
               * with single-byte non-word characters. */
              while (*ptr != NUL) {
                int l = (*mb_ptr2len)(ptr);

                if (l < 2 && !vim_iswordc(*ptr))
                  break;
                ptr += l;
              }
            else
              ptr = find_word_end(ptr);

            /* Add the word. Skip the regexp match. */
            if (wstart != regmatch->startp[0])
              add_r = ins_compl_add_infercase(wstart,
                  (int)(ptr - wstart),
                  p_ic, files[i], *dir, 0);
          }
        }
        if (add_r == OK)
          /* if dir was BACKWARD then honor it just once */
          *dir = FORWARD;
        else if (add_r == FAIL)
          break;
        /* avoid expensive call to vim_regexec() when at end
         * of line */
        if (*ptr == '\n' || got_int)
          break;
      }
      line_breakcheck();
      ins_compl_check_keys(50, false);
    }
    fclose(fp);
  }
}

/*
 * Find the start of the next word.
 * Returns a pointer to the first char of the word.  Also stops at a NUL.
 */
char_u *find_word_start(char_u *ptr)
{
  if (has_mbyte)
    while (*ptr != NUL && *ptr != '\n' && mb_get_class(ptr) <= 1)
      ptr += (*mb_ptr2len)(ptr);
  else
    while (*ptr != NUL && *ptr != '\n' && !vim_iswordc(*ptr))
      ++ptr;
  return ptr;
}

/*
 * Find the end of the word.  Assumes it starts inside a word.
 * Returns a pointer to just after the word.
 */
char_u *find_word_end(char_u *ptr)
{
  int start_class;

  if (has_mbyte) {
    start_class = mb_get_class(ptr);
    if (start_class > 1)
      while (*ptr != NUL) {
        ptr += (*mb_ptr2len)(ptr);
        if (mb_get_class(ptr) != start_class)
          break;
      }
  } else
    while (vim_iswordc(*ptr))
      ++ptr;
  return ptr;
}

/*
 * Find the end of the line, omitting CR and NL at the end.
 * Returns a pointer to just after the line.
 */
static char_u *find_line_end(char_u *ptr)
{
  char_u      *s;

  s = ptr + STRLEN(ptr);
  while (s > ptr && (s[-1] == CAR || s[-1] == NL))
    --s;
  return s;
}

/*
 * Free the list of completions
 */
static void ins_compl_free(void)
{
  compl_T *match;
  int i;

  xfree(compl_pattern);
  compl_pattern = NULL;
  xfree(compl_leader);
  compl_leader = NULL;

  if (compl_first_match == NULL)
    return;

  ins_compl_del_pum();
  pum_clear();

  compl_curr_match = compl_first_match;
  do {
    match = compl_curr_match;
    compl_curr_match = compl_curr_match->cp_next;
    xfree(match->cp_str);
    /* several entries may use the same fname, free it just once. */
    if (match->cp_flags & FREE_FNAME)
      xfree(match->cp_fname);
    for (i = 0; i < CPT_COUNT; ++i)
      xfree(match->cp_text[i]);
    xfree(match);
  } while (compl_curr_match != NULL && compl_curr_match != compl_first_match);
  compl_first_match = compl_curr_match = NULL;
  compl_shown_match = NULL;
  compl_old_match = NULL;
}

static void ins_compl_clear(void)
{
  compl_cont_status = 0;
  compl_started = FALSE;
  compl_matches = 0;
  xfree(compl_pattern);
  compl_pattern = NULL;
  xfree(compl_leader);
  compl_leader = NULL;
  edit_submode_extra = NULL;
  xfree(compl_orig_text);
  compl_orig_text = NULL;
  compl_enter_selects = FALSE;
  // clear v:completed_item
  set_vim_var_dict(VV_COMPLETED_ITEM, tv_dict_alloc());
}

/// Check that Insert completion is active.
bool ins_compl_active(void)
  FUNC_ATTR_PURE
{
  return compl_started;
}

/*
 * Delete one character before the cursor and show the subset of the matches
 * that match the word that is now before the cursor.
 * Returns the character to be used, NUL if the work is done and another char
 * to be got from the user.
 */
static int ins_compl_bs(void)
{
  char_u      *line;
  char_u      *p;

  line = get_cursor_line_ptr();
  p = line + curwin->w_cursor.col;
  MB_PTR_BACK(line, p);

  // Stop completion when the whole word was deleted.  For Omni completion
  // allow the word to be deleted, we won't match everything.
  // Respect the 'backspace' option.
  if ((int)(p - line) - (int)compl_col < 0
      || ((int)(p - line) - (int)compl_col == 0
          && ctrl_x_mode != CTRL_X_OMNI) || ctrl_x_mode == CTRL_X_EVAL
      || (!can_bs(BS_START) && (int)(p - line) - (int)compl_col
          - compl_length < 0)) {
    return K_BS;
  }

  /* Deleted more than what was used to find matches or didn't finish
   * finding all matches: need to look for matches all over again. */
  if (curwin->w_cursor.col <= compl_col + compl_length
      || ins_compl_need_restart())
    ins_compl_restart();

  xfree(compl_leader);
  compl_leader = vim_strnsave(line + compl_col, (int)(p - line) - compl_col);
  ins_compl_new_leader();
  if (compl_shown_match != NULL)
    /* Make sure current match is not a hidden item. */
    compl_curr_match = compl_shown_match;

  return NUL;
}

/// Check that we need to find matches again, ins_compl_restart() is to
/// be called.
static bool ins_compl_need_restart(void)
  FUNC_ATTR_PURE
{
  // Return true if we didn't complete finding matches or when the
  // "completefunc" returned "always" in the "refresh" dictionary item.
  return compl_was_interrupted
         || ((ctrl_x_mode == CTRL_X_FUNCTION || ctrl_x_mode == CTRL_X_OMNI)
             && compl_opt_refresh_always);
}

/*
 * Called after changing "compl_leader".
 * Show the popup menu with a different set of matches.
 * May also search for matches again if the previous search was interrupted.
 */
static void ins_compl_new_leader(void)
{
  ins_compl_del_pum();
  ins_compl_delete();
  ins_bytes(compl_leader + ins_compl_len());
  compl_used_match = FALSE;

  if (compl_started) {
    ins_compl_set_original_text(compl_leader);
  } else {
    spell_bad_len = 0;  // need to redetect bad word
    // Matches were cleared, need to search for them now.
    // Set "compl_restarting" to avoid that the first match is inserted.
    compl_restarting = true;
    if (ins_complete(Ctrl_N, true) == FAIL) {
      compl_cont_status = 0;
    }
    compl_restarting = false;
  }

  compl_enter_selects = !compl_used_match;

  /* Show the popup menu with a different set of matches. */
  ins_compl_show_pum();

  /* Don't let Enter select the original text when there is no popup menu.
   * Don't let Enter select when use user function and refresh_always is set */
  if (compl_match_array == NULL || ins_compl_need_restart())
    compl_enter_selects = FALSE;
}

/*
 * Return the length of the completion, from the completion start column to
 * the cursor column.  Making sure it never goes below zero.
 */
static int ins_compl_len(void)
{
  int off = (int)curwin->w_cursor.col - (int)compl_col;

  if (off < 0)
    return 0;
  return off;
}

/*
 * Append one character to the match leader.  May reduce the number of
 * matches.
 */
static void ins_compl_addleader(int c)
{
  int cc;

  if (stop_arrow() == FAIL) {
        return;
  }
  if ((cc = utf_char2len(c)) > 1) {
    char_u buf[MB_MAXBYTES + 1];

    utf_char2bytes(c, buf);
    buf[cc] = NUL;
    ins_char_bytes(buf, cc);
  } else {
    ins_char(c);
  }

  /* If we didn't complete finding matches we must search again. */
  if (ins_compl_need_restart())
    ins_compl_restart();

  xfree(compl_leader);
  compl_leader = vim_strnsave(get_cursor_line_ptr() + compl_col,
      (int)(curwin->w_cursor.col - compl_col));
  ins_compl_new_leader();
}

/*
 * Setup for finding completions again without leaving CTRL-X mode.  Used when
 * BS or a key was typed while still searching for matches.
 */
static void ins_compl_restart(void)
{
  /* update screen before restart.
   * so if complete is blocked,
   * will stay to the last popup menu and reduce flicker */
  update_screen(0);
  ins_compl_free();
  compl_started = FALSE;
  compl_matches = 0;
  compl_cont_status = 0;
  compl_cont_mode = 0;
}

/*
 * Set the first match, the original text.
 */
static void ins_compl_set_original_text(char_u *str)
{
  /* Replace the original text entry. */
  if (compl_first_match->cp_flags & ORIGINAL_TEXT) {    /* safety check */
    xfree(compl_first_match->cp_str);
    compl_first_match->cp_str = vim_strsave(str);
  }
}

/*
 * Append one character to the match leader.  May reduce the number of
 * matches.
 */
static void ins_compl_addfrommatch(void)
{
  char_u      *p;
  int len = (int)curwin->w_cursor.col - (int)compl_col;
  int c;
  compl_T     *cp;

  p = compl_shown_match->cp_str;
  if ((int)STRLEN(p) <= len) {   /* the match is too short */
    /* When still at the original match use the first entry that matches
     * the leader. */
    if (compl_shown_match->cp_flags & ORIGINAL_TEXT) {
      p = NULL;
      for (cp = compl_shown_match->cp_next; cp != NULL
           && cp != compl_first_match; cp = cp->cp_next) {
        if (compl_leader == NULL
            || ins_compl_equal(cp, compl_leader,
                (int)STRLEN(compl_leader))) {
          p = cp->cp_str;
          break;
        }
      }
      if (p == NULL || (int)STRLEN(p) <= len)
        return;
    } else
      return;
  }
  p += len;
  c = PTR2CHAR(p);
  ins_compl_addleader(c);
}

/// Prepare for Insert mode completion, or stop it.
/// Called just after typing a character in Insert mode.
///
/// @param  c  character that was typed
///
/// @return true when the character is not to be inserted;
static bool ins_compl_prep(int c)
{
  char_u *ptr;
  bool retval = false;

  /* Forget any previous 'special' messages if this is actually
   * a ^X mode key - bar ^R, in which case we wait to see what it gives us.
   */
  if (c != Ctrl_R && vim_is_ctrl_x_key(c))
    edit_submode_extra = NULL;

  /* Ignore end of Select mode mapping and mouse scroll buttons. */
  if (c == K_SELECT || c == K_MOUSEDOWN || c == K_MOUSEUP
      || c == K_MOUSELEFT || c == K_MOUSERIGHT || c == K_EVENT) {
    return retval;
  }

  /* Set "compl_get_longest" when finding the first matches. */
  if (ctrl_x_mode == CTRL_X_NOT_DEFINED_YET
      || (ctrl_x_mode == 0 && !compl_started)) {
    compl_get_longest = (strstr((char *)p_cot, "longest") != NULL);
    compl_used_match = TRUE;

  }

  if (ctrl_x_mode == CTRL_X_NOT_DEFINED_YET) {
    /*
     * We have just typed CTRL-X and aren't quite sure which CTRL-X mode
     * it will be yet.  Now we decide.
     */
    switch (c) {
    case Ctrl_E:
    case Ctrl_Y:
      ctrl_x_mode = CTRL_X_SCROLL;
      if (!(State & REPLACE_FLAG))
        edit_submode = (char_u *)_(" (insert) Scroll (^E/^Y)");
      else
        edit_submode = (char_u *)_(" (replace) Scroll (^E/^Y)");
      edit_submode_pre = NULL;
      showmode();
      break;
    case Ctrl_L:
      ctrl_x_mode = CTRL_X_WHOLE_LINE;
      break;
    case Ctrl_F:
      ctrl_x_mode = CTRL_X_FILES;
      break;
    case Ctrl_K:
      ctrl_x_mode = CTRL_X_DICTIONARY;
      break;
    case Ctrl_R:
      /* Simply allow ^R to happen without affecting ^X mode */
      break;
    case Ctrl_T:
      ctrl_x_mode = CTRL_X_THESAURUS;
      break;
    case Ctrl_U:
      ctrl_x_mode = CTRL_X_FUNCTION;
      break;
    case Ctrl_O:
      ctrl_x_mode = CTRL_X_OMNI;
      break;
    case 's':
    case Ctrl_S:
      ctrl_x_mode = CTRL_X_SPELL;
      ++emsg_off;               /* Avoid getting the E756 error twice. */
      spell_back_to_badword();
      --emsg_off;
      break;
    case Ctrl_RSB:
      ctrl_x_mode = CTRL_X_TAGS;
      break;
    case Ctrl_I:
    case K_S_TAB:
      ctrl_x_mode = CTRL_X_PATH_PATTERNS;
      break;
    case Ctrl_D:
      ctrl_x_mode = CTRL_X_PATH_DEFINES;
      break;
    case Ctrl_V:
    case Ctrl_Q:
      ctrl_x_mode = CTRL_X_CMDLINE;
      break;
    case Ctrl_P:
    case Ctrl_N:
      /* ^X^P means LOCAL expansion if nothing interrupted (eg we
       * just started ^X mode, or there were enough ^X's to cancel
       * the previous mode, say ^X^F^X^X^P or ^P^X^X^X^P, see below)
       * do normal expansion when interrupting a different mode (say
       * ^X^F^X^P or ^P^X^X^P, see below)
       * nothing changes if interrupting mode 0, (eg, the flag
       * doesn't change when going to ADDING mode  -- Acevedo */
      if (!(compl_cont_status & CONT_INTRPT))
        compl_cont_status |= CONT_LOCAL;
      else if (compl_cont_mode != 0)
        compl_cont_status &= ~CONT_LOCAL;
      FALLTHROUGH;
    default:
      /* If we have typed at least 2 ^X's... for modes != 0, we set
       * compl_cont_status = 0 (eg, as if we had just started ^X
       * mode).
       * For mode 0, we set "compl_cont_mode" to an impossible
       * value, in both cases ^X^X can be used to restart the same
       * mode (avoiding ADDING mode).
       * Undocumented feature: In a mode != 0 ^X^P and ^X^X^P start
       * 'complete' and local ^P expansions respectively.
       * In mode 0 an extra ^X is needed since ^X^P goes to ADDING
       * mode  -- Acevedo */
      if (c == Ctrl_X) {
        if (compl_cont_mode != 0)
          compl_cont_status = 0;
        else
          compl_cont_mode = CTRL_X_NOT_DEFINED_YET;
      }
      ctrl_x_mode = 0;
      edit_submode = NULL;
      showmode();
      break;
    }
  } else if (ctrl_x_mode != 0) {
    /* We're already in CTRL-X mode, do we stay in it? */
    if (!vim_is_ctrl_x_key(c)) {
      if (ctrl_x_mode == CTRL_X_SCROLL)
        ctrl_x_mode = 0;
      else
        ctrl_x_mode = CTRL_X_FINISHED;
      edit_submode = NULL;
    }
    showmode();
  }

  if (compl_started || ctrl_x_mode == CTRL_X_FINISHED) {
    /* Show error message from attempted keyword completion (probably
     * 'Pattern not found') until another key is hit, then go back to
     * showing what mode we are in. */
    showmode();
    if ((ctrl_x_mode == 0 && c != Ctrl_N && c != Ctrl_P && c != Ctrl_R
         && !ins_compl_pum_key(c))
        || ctrl_x_mode == CTRL_X_FINISHED) {
      /* Get here when we have finished typing a sequence of ^N and
       * ^P or other completion characters in CTRL-X mode.  Free up
       * memory that was used, and make sure we can redo the insert. */
      if (compl_curr_match != NULL || compl_leader != NULL || c == Ctrl_E) {
        /*
         * If any of the original typed text has been changed, eg when
         * ignorecase is set, we must add back-spaces to the redo
         * buffer.  We add as few as necessary to delete just the part
         * of the original text that has changed.
         * When using the longest match, edited the match or used
         * CTRL-E then don't use the current match.
         */
        if (compl_curr_match != NULL && compl_used_match && c != Ctrl_E)
          ptr = compl_curr_match->cp_str;
        else
          ptr = NULL;
        ins_compl_fixRedoBufForLeader(ptr);
      }

      bool want_cindent = (can_cindent && cindent_on());
      // When completing whole lines: fix indent for 'cindent'.
      // Otherwise, break line if it's too long.
      if (compl_cont_mode == CTRL_X_WHOLE_LINE) {
        /* re-indent the current line */
        if (want_cindent) {
          do_c_expr_indent();
          want_cindent = FALSE;                 /* don't do it again */
        }
      } else {
        int prev_col = curwin->w_cursor.col;

        // put the cursor on the last char, for 'tw' formatting
        if (prev_col > 0) {
          dec_cursor();
        }

        if (!arrow_used && !ins_need_undo && c != Ctrl_E) {
          insertchar(NUL, 0, -1);
        }

        if (prev_col > 0
            && get_cursor_line_ptr()[curwin->w_cursor.col] != NUL) {
          inc_cursor();
        }
      }

      // If the popup menu is displayed pressing CTRL-Y means accepting
      // the selection without inserting anything.  When
      // compl_enter_selects is set the Enter key does the same.
      if ((c == Ctrl_Y || (compl_enter_selects
                           && (c == CAR || c == K_KENTER || c == NL)))
          && pum_visible()) {
        retval = true;
      }

      // CTRL-E means completion is Ended, go back to the typed text.
      // but only do this, if the Popup is still visible
      if (c == Ctrl_E) {
        ins_compl_delete();
        if (compl_leader != NULL) {
          ins_bytes(compl_leader + ins_compl_len());
        } else if (compl_first_match != NULL) {
          ins_bytes(compl_orig_text + ins_compl_len());
        }
        retval = true;
      }

      auto_format(FALSE, TRUE);

      ins_compl_free();
      compl_started = FALSE;
      compl_matches = 0;
      if (!shortmess(SHM_COMPLETIONMENU)) {
        msg_clr_cmdline();                // necessary for "noshowmode"
      }
      ctrl_x_mode = 0;
      compl_enter_selects = FALSE;
      if (edit_submode != NULL) {
        edit_submode = NULL;
        showmode();
      }

      // Avoid the popup menu remains displayed when leaving the
      // command line window.
      if (c == Ctrl_C && cmdwin_type != 0) {
        update_screen(0);
      }

      /*
       * Indent now if a key was typed that is in 'cinkeys'.
       */
      if (want_cindent && in_cinkeys(KEY_COMPLETE, ' ', inindent(0)))
        do_c_expr_indent();
      /* Trigger the CompleteDone event to give scripts a chance to act
       * upon the completion. */
      ins_apply_autocmds(EVENT_COMPLETEDONE);
    }
  } else if (ctrl_x_mode == CTRL_X_LOCAL_MSG)
    /* Trigger the CompleteDone event to give scripts a chance to act
     * upon the (possibly failed) completion. */
    ins_apply_autocmds(EVENT_COMPLETEDONE);

  /* reset continue_* if we left expansion-mode, if we stay they'll be
   * (re)set properly in ins_complete() */
  if (!vim_is_ctrl_x_key(c)) {
    compl_cont_status = 0;
    compl_cont_mode = 0;
  }

  return retval;
}

/*
 * Fix the redo buffer for the completion leader replacing some of the typed
 * text.  This inserts backspaces and appends the changed text.
 * "ptr" is the known leader text or NUL.
 */
static void ins_compl_fixRedoBufForLeader(char_u *ptr_arg)
{
  int len;
  char_u  *p;
  char_u  *ptr = ptr_arg;

  if (ptr == NULL) {
    if (compl_leader != NULL)
      ptr = compl_leader;
    else
      return;        /* nothing to do */
  }
  if (compl_orig_text != NULL) {
    p = compl_orig_text;
    for (len = 0; p[len] != NUL && p[len] == ptr[len]; len++) {}
    if (len > 0) {
      len -= utf_head_off(p, p + len);
    }
    for (p += len; *p != NUL; MB_PTR_ADV(p)) {
      AppendCharToRedobuff(K_BS);
    }
  } else {
    len = 0;
  }
  AppendToRedobuffLit(ptr + len, -1);
}

/*
 * Loops through the list of windows, loaded-buffers or non-loaded-buffers
 * (depending on flag) starting from buf and looking for a non-scanned
 * buffer (other than curbuf).	curbuf is special, if it is called with
 * buf=curbuf then it has to be the first call for a given flag/expansion.
 *
 * Returns the buffer to scan, if any, otherwise returns curbuf -- Acevedo
 */
static buf_T *ins_compl_next_buf(buf_T *buf, int flag)
{
  static win_T *wp;

  if (flag == 'w') {            /* just windows */
    if (buf == curbuf)          /* first call for this flag/expansion */
      wp = curwin;
    assert(wp);
    while ((wp = (wp->w_next != NULL ? wp->w_next : firstwin)) != curwin
           && wp->w_buffer->b_scanned)
      ;
    buf = wp->w_buffer;
  } else
    /* 'b' (just loaded buffers), 'u' (just non-loaded buffers) or 'U'
     * (unlisted buffers)
     * When completing whole lines skip unloaded buffers. */
    while ((buf = (buf->b_next != NULL ? buf->b_next : firstbuf)) != curbuf
           && ((flag == 'U'
                ? buf->b_p_bl
                : (!buf->b_p_bl
                   || (buf->b_ml.ml_mfp == NULL) != (flag == 'u')))
               || buf->b_scanned))
      ;
  return buf;
}


/*
 * Execute user defined complete function 'completefunc' or 'omnifunc', and
 * get matches in "matches".
 */
static void
expand_by_function (
    int type,                   /* CTRL_X_OMNI or CTRL_X_FUNCTION */
    char_u *base
)
{
  list_T      *matchlist = NULL;
  dict_T      *matchdict = NULL;
  char_u      *funcname;
  pos_T pos;
  win_T       *curwin_save;
  buf_T       *curbuf_save;
  typval_T rettv;

  funcname = (type == CTRL_X_FUNCTION) ? curbuf->b_p_cfu : curbuf->b_p_ofu;
  if (*funcname == NUL)
    return;

  // Call 'completefunc' to obtain the list of matches.
  const char_u *const args[2] = { (char_u *)"0", base };

  pos = curwin->w_cursor;
  curwin_save = curwin;
  curbuf_save = curbuf;

  /* Call a function, which returns a list or dict. */
  if (call_vim_function(funcname, 2, args, FALSE, FALSE, &rettv) == OK) {
    switch (rettv.v_type) {
    case VAR_LIST:
      matchlist = rettv.vval.v_list;
      break;
    case VAR_DICT:
      matchdict = rettv.vval.v_dict;
      break;
    default:
      // TODO(brammool): Give error message?
      tv_clear(&rettv);
      break;
    }
  }

  if (curwin_save != curwin || curbuf_save != curbuf) {
    EMSG(_(e_complwin));
    goto theend;
  }
  curwin->w_cursor = pos;       /* restore the cursor position */
  validate_cursor();
  if (!equalpos(curwin->w_cursor, pos)) {
    EMSG(_(e_compldel));
    goto theend;
  }

  if (matchlist != NULL)
    ins_compl_add_list(matchlist);
  else if (matchdict != NULL)
    ins_compl_add_dict(matchdict);

theend:
  if (matchdict != NULL) {
    tv_dict_unref(matchdict);
  }
  if (matchlist != NULL) {
    tv_list_unref(matchlist);
  }
}

/*
 * Add completions from a list.
 */
static void ins_compl_add_list(list_T *const list)
{
  int dir = compl_direction;

  // Go through the List with matches and add each of them.
  TV_LIST_ITER(list, li, {
    if (ins_compl_add_tv(TV_LIST_ITEM_TV(li), dir) == OK) {
      // If dir was BACKWARD then honor it just once.
      dir = FORWARD;
    } else if (did_emsg) {
      break;
    }
  });
}

/*
 * Add completions from a dict.
 */
static void ins_compl_add_dict(dict_T *dict)
{
  dictitem_T  *di_refresh;
  dictitem_T  *di_words;

  // Check for optional "refresh" item.
  compl_opt_refresh_always = false;
  di_refresh = tv_dict_find(dict, S_LEN("refresh"));
  if (di_refresh != NULL && di_refresh->di_tv.v_type == VAR_STRING) {
    const char *v = (const char *)di_refresh->di_tv.vval.v_string;

    if (v != NULL && strcmp(v, "always") == 0) {
      compl_opt_refresh_always = true;
    }
  }

  // Add completions from a "words" list.
  di_words = tv_dict_find(dict, S_LEN("words"));
  if (di_words != NULL && di_words->di_tv.v_type == VAR_LIST) {
    ins_compl_add_list(di_words->di_tv.vval.v_list);
  }
}

/// Add a match to the list of matches from VimL object
///
/// @param[in]  tv  Object to get matches from.
/// @param[in]  dir  Completion direction.
///
/// @return NOTDONE if the given string is already in the list of completions,
///         otherwise it is added to the list and  OK is returned. FAIL will be
///         returned in case of error.
int ins_compl_add_tv(typval_T *const tv, const Direction dir)
  FUNC_ATTR_NONNULL_ALL
{
  const char *word;
  bool icase = false;
  bool adup = false;
  bool aempty = false;
  char *(cptext[CPT_COUNT]);

  if (tv->v_type == VAR_DICT && tv->vval.v_dict != NULL) {
    word = tv_dict_get_string(tv->vval.v_dict, "word", false);
    cptext[CPT_ABBR] = tv_dict_get_string(tv->vval.v_dict, "abbr", true);
    cptext[CPT_MENU] = tv_dict_get_string(tv->vval.v_dict, "menu", true);
    cptext[CPT_KIND] = tv_dict_get_string(tv->vval.v_dict, "kind", true);
    cptext[CPT_INFO] = tv_dict_get_string(tv->vval.v_dict, "info", true);
    cptext[CPT_USER_DATA] = tv_dict_get_string(tv->vval.v_dict,
                                               "user_data", true);

    icase = (bool)tv_dict_get_number(tv->vval.v_dict, "icase");
    adup = (bool)tv_dict_get_number(tv->vval.v_dict, "dup");
    aempty = (bool)tv_dict_get_number(tv->vval.v_dict, "empty");
  } else {
    word = (const char *)tv_get_string_chk(tv);
    memset(cptext, 0, sizeof(cptext));
  }
  if (word == NULL || (!aempty && *word == NUL)) {
    for (size_t i = 0; i < CPT_COUNT; i++) {
      xfree(cptext[i]);
    }
    return FAIL;
  }
  return ins_compl_add((char_u *)word, -1, icase, NULL,
                       (char_u **)cptext, true, dir, 0, adup);
}

/*
 * Get the next expansion(s), using "compl_pattern".
 * The search starts at position "ini" in curbuf and in the direction
 * compl_direction.
 * When "compl_started" is FALSE start at that position, otherwise continue
 * where we stopped searching before.
 * This may return before finding all the matches.
 * Return the total number of matches or -1 if still unknown -- Acevedo
 */
static int ins_compl_get_exp(pos_T *ini)
{
  static pos_T first_match_pos;
  static pos_T last_match_pos;
  static char_u       *e_cpt = (char_u *)"";    /* curr. entry in 'complete' */
  static int found_all = FALSE;                 /* Found all matches of a
                                                   certain type. */
  static buf_T        *ins_buf = NULL;          /* buffer being scanned */

  pos_T       *pos;
  char_u      **matches;
  int save_p_scs;
  bool save_p_ws;
  int save_p_ic;
  int i;
  int num_matches;
  int len;
  int found_new_match;
  int type = ctrl_x_mode;
  char_u      *ptr;
  char_u      *dict = NULL;
  int dict_f = 0;
  int set_match_pos;
  int l_ctrl_x_mode = ctrl_x_mode;

  if (!compl_started) {
    FOR_ALL_BUFFERS(buf) {
      buf->b_scanned = false;
    }
    found_all = FALSE;
    ins_buf = curbuf;
    e_cpt = (compl_cont_status & CONT_LOCAL)
            ? (char_u *)"." : curbuf->b_p_cpt;
    last_match_pos = first_match_pos = *ini;
  }

  compl_old_match = compl_curr_match;   // remember the last current match
  pos = (compl_direction == FORWARD) ? &last_match_pos : &first_match_pos;
  /* For ^N/^P loop over all the flags/windows/buffers in 'complete' */
  for (;; ) {
    found_new_match = FAIL;
    set_match_pos = FALSE;

    assert(l_ctrl_x_mode == ctrl_x_mode);

    /* For ^N/^P pick a new entry from e_cpt if compl_started is off,
     * or if found_all says this entry is done.  For ^X^L only use the
     * entries from 'complete' that look in loaded buffers. */
    if ((l_ctrl_x_mode == 0 || CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode))
        && (!compl_started || found_all)) {
      found_all = FALSE;
      while (*e_cpt == ',' || *e_cpt == ' ')
        e_cpt++;
      if (*e_cpt == '.' && !curbuf->b_scanned) {
        ins_buf = curbuf;
        first_match_pos = *ini;
        // Move the cursor back one character so that ^N can match the
        // word immediately after the cursor.
        if (ctrl_x_mode == 0 && dec(&first_match_pos) < 0) {
          // Move the cursor to after the last character in the
          // buffer, so that word at start of buffer is found
          // correctly.
          first_match_pos.lnum = ins_buf->b_ml.ml_line_count;
          first_match_pos.col = (colnr_T)STRLEN(ml_get(first_match_pos.lnum));
        }
        last_match_pos = first_match_pos;
        type = 0;

        /* Remember the first match so that the loop stops when we
         * wrap and come back there a second time. */
        set_match_pos = TRUE;
      } else if (vim_strchr((char_u *)"buwU", *e_cpt) != NULL
                 && (ins_buf =
                       ins_compl_next_buf(ins_buf, *e_cpt)) != curbuf) {
        /* Scan a buffer, but not the current one. */
        if (ins_buf->b_ml.ml_mfp != NULL) {         /* loaded buffer */
          compl_started = TRUE;
          first_match_pos.col = last_match_pos.col = 0;
          first_match_pos.lnum = ins_buf->b_ml.ml_line_count + 1;
          last_match_pos.lnum = 0;
          type = 0;
        } else {      /* unloaded buffer, scan like dictionary */
          found_all = TRUE;
          if (ins_buf->b_fname == NULL)
            continue;
          type = CTRL_X_DICTIONARY;
          dict = ins_buf->b_fname;
          dict_f = DICT_EXACT;
        }
        vim_snprintf((char *)IObuff, IOSIZE, _("Scanning: %s"),
                     ins_buf->b_fname == NULL
                     ? buf_spname(ins_buf)
                     : ins_buf->b_sfname == NULL
                     ? ins_buf->b_fname
                     : ins_buf->b_sfname);
        (void)msg_trunc_attr(IObuff, true, HL_ATTR(HLF_R));
      } else if (*e_cpt == NUL) {
        break;
      } else {
        if (CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode)) {
          type = -1;
        } else if (*e_cpt == 'k' || *e_cpt == 's') {
          if (*e_cpt == 'k')
            type = CTRL_X_DICTIONARY;
          else
            type = CTRL_X_THESAURUS;
          if (*++e_cpt != ',' && *e_cpt != NUL) {
            dict = e_cpt;
            dict_f = DICT_FIRST;
          }
        } else if (*e_cpt == 'i')
          type = CTRL_X_PATH_PATTERNS;
        else if (*e_cpt == 'd')
          type = CTRL_X_PATH_DEFINES;
        else if (*e_cpt == ']' || *e_cpt == 't') {
          type = CTRL_X_TAGS;
          vim_snprintf((char *)IObuff, IOSIZE, _("Scanning tags."));
          (void)msg_trunc_attr(IObuff, true, HL_ATTR(HLF_R));
        } else {
          type = -1;
        }

        /* in any case e_cpt is advanced to the next entry */
        (void)copy_option_part(&e_cpt, IObuff, IOSIZE, ",");

        found_all = TRUE;
        if (type == -1)
          continue;
      }
    }

    // If complete() was called then compl_pattern has been reset.
    // The following won't work then, bail out.
    if (compl_pattern == NULL) {
      break;
    }

    switch (type) {
    case -1:
      break;
    case CTRL_X_PATH_PATTERNS:
    case CTRL_X_PATH_DEFINES:
      find_pattern_in_path(compl_pattern, compl_direction,
                           STRLEN(compl_pattern), FALSE, FALSE,
                           ((type == CTRL_X_PATH_DEFINES
                             && !(compl_cont_status & CONT_SOL))
                            ? FIND_DEFINE
                            : FIND_ANY),
                           1L, ACTION_EXPAND, 1, MAXLNUM);
      break;

    case CTRL_X_DICTIONARY:
    case CTRL_X_THESAURUS:
      ins_compl_dictionaries(
          dict != NULL ? dict
          : (type == CTRL_X_THESAURUS
             ? (*curbuf->b_p_tsr == NUL
                ? p_tsr
                : curbuf->b_p_tsr)
             : (*curbuf->b_p_dict == NUL
                ? p_dict
                : curbuf->b_p_dict)),
          compl_pattern,
          dict != NULL ? dict_f
          : 0, type == CTRL_X_THESAURUS);
      dict = NULL;
      break;

    case CTRL_X_TAGS:
      /* set p_ic according to p_ic, p_scs and pat for find_tags(). */
      save_p_ic = p_ic;
      p_ic = ignorecase(compl_pattern);

      /* Find up to TAG_MANY matches.  Avoids that an enormous number
       * of matches is found when compl_pattern is empty */
      if (find_tags(compl_pattern, &num_matches, &matches,
              TAG_REGEXP | TAG_NAMES | TAG_NOIC |
              TAG_INS_COMP | (l_ctrl_x_mode ? TAG_VERBOSE : 0),
              TAG_MANY, curbuf->b_ffname) == OK && num_matches > 0) {
        ins_compl_add_matches(num_matches, matches, p_ic);
      }
      p_ic = save_p_ic;
      break;

    case CTRL_X_FILES:
      if (expand_wildcards(1, &compl_pattern, &num_matches, &matches,
              EW_FILE|EW_DIR|EW_ADDSLASH|EW_SILENT) == OK) {

        /* May change home directory back to "~". */
        tilde_replace(compl_pattern, num_matches, matches);
        ins_compl_add_matches(num_matches, matches, p_fic || p_wic);
      }
      break;

    case CTRL_X_CMDLINE:
      if (expand_cmdline(&compl_xp, compl_pattern,
              (int)STRLEN(compl_pattern),
              &num_matches, &matches) == EXPAND_OK)
        ins_compl_add_matches(num_matches, matches, FALSE);
      break;

    case CTRL_X_FUNCTION:
    case CTRL_X_OMNI:
      expand_by_function(type, compl_pattern);
      break;

    case CTRL_X_SPELL:
      num_matches = expand_spelling(first_match_pos.lnum,
          compl_pattern, &matches);
      if (num_matches > 0)
        ins_compl_add_matches(num_matches, matches, p_ic);
      break;

    default:            /* normal ^P/^N and ^X^L */
      /*
       * If 'infercase' is set, don't use 'smartcase' here
       */
      save_p_scs = p_scs;
      assert(ins_buf);
      if (ins_buf->b_p_inf)
        p_scs = FALSE;

      /*	Buffers other than curbuf are scanned from the beginning or the
       *	end but never from the middle, thus setting nowrapscan in this
       *	buffers is a good idea, on the other hand, we always set
       *	wrapscan for curbuf to avoid missing matches -- Acevedo,Webb */
      save_p_ws = p_ws;
      if (ins_buf != curbuf)
        p_ws = false;
      else if (*e_cpt == '.')
        p_ws = true;
      for (;; ) {
        int flags = 0;

        ++msg_silent;          /* Don't want messages for wrapscan. */

        // CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode) || word-wise search that
        // has added a word that was at the beginning of the line.
        if (CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode)
            || (compl_cont_status & CONT_SOL)) {
          found_new_match = search_for_exact_line(ins_buf, pos,
              compl_direction, compl_pattern);
        } else
          found_new_match = searchit(NULL, ins_buf, pos,
              compl_direction,
              compl_pattern, 1L, SEARCH_KEEP + SEARCH_NFMSG,
              RE_LAST, (linenr_T)0, NULL);
        --msg_silent;
        if (!compl_started || set_match_pos) {
          /* set "compl_started" even on fail */
          compl_started = TRUE;
          first_match_pos = *pos;
          last_match_pos = *pos;
          set_match_pos = FALSE;
        } else if (first_match_pos.lnum == last_match_pos.lnum
                   && first_match_pos.col == last_match_pos.col)
          found_new_match = FAIL;
        if (found_new_match == FAIL) {
          if (ins_buf == curbuf)
            found_all = TRUE;
          break;
        }

        /* when ADDING, the text before the cursor matches, skip it */
        if (    (compl_cont_status & CONT_ADDING) && ins_buf == curbuf
                && ini->lnum == pos->lnum
                && ini->col  == pos->col)
          continue;
        ptr = ml_get_buf(ins_buf, pos->lnum, FALSE) + pos->col;
        if (CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode)) {
          if (compl_cont_status & CONT_ADDING) {
            if (pos->lnum >= ins_buf->b_ml.ml_line_count)
              continue;
            ptr = ml_get_buf(ins_buf, pos->lnum + 1, FALSE);
            if (!p_paste)
              ptr = skipwhite(ptr);
          }
          len = (int)STRLEN(ptr);
        } else {
          char_u      *tmp_ptr = ptr;

          if (compl_cont_status & CONT_ADDING) {
            tmp_ptr += compl_length;
            /* Skip if already inside a word. */
            if (vim_iswordp(tmp_ptr))
              continue;
            /* Find start of next word. */
            tmp_ptr = find_word_start(tmp_ptr);
          }
          /* Find end of this word. */
          tmp_ptr = find_word_end(tmp_ptr);
          len = (int)(tmp_ptr - ptr);

          if ((compl_cont_status & CONT_ADDING)
              && len == compl_length) {
            if (pos->lnum < ins_buf->b_ml.ml_line_count) {
              // Try next line, if any. the new word will be "join" as if the
              // normal command "J" was used. IOSIZE is always greater than
              // compl_length, so the next STRNCPY always works -- Acevedo
              STRNCPY(IObuff, ptr, len);
              ptr = ml_get_buf(ins_buf, pos->lnum + 1, false);
              tmp_ptr = ptr = skipwhite(ptr);
              /* Find start of next word. */
              tmp_ptr = find_word_start(tmp_ptr);
              /* Find end of next word. */
              tmp_ptr = find_word_end(tmp_ptr);
              if (tmp_ptr > ptr) {
                if (*ptr != ')' && IObuff[len - 1] != TAB) {
                  if (IObuff[len - 1] != ' ')
                    IObuff[len++] = ' ';
                  /* IObuf =~ "\k.* ", thus len >= 2 */
                  if (p_js
                      && (IObuff[len - 2] == '.'
                          || IObuff[len - 2] == '?'
                          || IObuff[len - 2] == '!')) {
                    IObuff[len++] = ' ';
                  }
                }
                /* copy as much as possible of the new word */
                if (tmp_ptr - ptr >= IOSIZE - len)
                  tmp_ptr = ptr + IOSIZE - len - 1;
                STRNCPY(IObuff + len, ptr, tmp_ptr - ptr);
                len += (int)(tmp_ptr - ptr);
                flags |= CONT_S_IPOS;
              }
              IObuff[len] = NUL;
              ptr = IObuff;
            }
            if (len == compl_length)
              continue;
          }
        }
        if (ins_compl_add_infercase(ptr, len, p_ic,
                ins_buf == curbuf ? NULL : ins_buf->b_sfname,
                0, flags) != NOTDONE) {
          found_new_match = OK;
          break;
        }
      }
      p_scs = save_p_scs;
      p_ws = save_p_ws;
    }

    // check if compl_curr_match has changed, (e.g. other type of
    // expansion added something)
    if (type != 0 && compl_curr_match != compl_old_match) {
      found_new_match = OK;
    }

    /* break the loop for specialized modes (use 'complete' just for the
     * generic l_ctrl_x_mode == 0) or when we've found a new match */
    if ((l_ctrl_x_mode != 0 && !CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode))
        || found_new_match != FAIL) {
      if (got_int)
        break;
      /* Fill the popup menu as soon as possible. */
      if (type != -1)
        ins_compl_check_keys(0, false);

      if ((l_ctrl_x_mode != 0 && !CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode))
          || compl_interrupted) {
        break;
      }
      compl_started = TRUE;
    } else {
      /* Mark a buffer scanned when it has been scanned completely */
      if (type == 0 || type == CTRL_X_PATH_PATTERNS) {
        assert(ins_buf);
        ins_buf->b_scanned = true;
      }

      compl_started = FALSE;
    }
  }
  compl_started = TRUE;

  if ((l_ctrl_x_mode == 0 || CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode))
      && *e_cpt == NUL) {  // Got to end of 'complete'
    found_new_match = FAIL;
  }

  i = -1;               /* total of matches, unknown */
  if (found_new_match == FAIL
      || (l_ctrl_x_mode != 0 && !CTRL_X_MODE_LINE_OR_EVAL(l_ctrl_x_mode))) {
    i = ins_compl_make_cyclic();
  }

  if (compl_old_match != NULL) {
    // If several matches were added (FORWARD) or the search failed and has
    // just been made cyclic then we have to move compl_curr_match to the
    // next or previous entry (if any) -- Acevedo
    compl_curr_match = compl_direction == FORWARD
                        ? compl_old_match->cp_next
                        : compl_old_match->cp_prev;
    if (compl_curr_match == NULL) {
      compl_curr_match = compl_old_match;
    }
  }
  return i;
}

/* Delete the old text being completed. */
static void ins_compl_delete(void)
{
  int col;

  // In insert mode: Delete the typed part.
  // In replace mode: Put the old characters back, if any.
  col = compl_col + (compl_cont_status & CONT_ADDING ? compl_length : 0);
  if ((int)curwin->w_cursor.col > col) {
    if (stop_arrow() == FAIL) {
      return;
    }
    backspace_until_column(col);
  }

  // TODO(vim): is this sufficient for redrawing?  Redrawing everything
  // causes flicker, thus we can't do that.
  changed_cline_bef_curs();
  // clear v:completed_item
  set_vim_var_dict(VV_COMPLETED_ITEM, tv_dict_alloc());
}

// Insert the new text being completed.
// "in_compl_func" is TRUE when called from complete_check().
static void ins_compl_insert(int in_compl_func)
{
  ins_bytes(compl_shown_match->cp_str + ins_compl_len());
  if (compl_shown_match->cp_flags & ORIGINAL_TEXT)
    compl_used_match = FALSE;
  else
    compl_used_match = TRUE;

  // Set completed item.
  // { word, abbr, menu, kind, info }
  dict_T *dict = tv_dict_alloc();
  tv_dict_add_str(
      dict, S_LEN("word"),
      (const char *)EMPTY_IF_NULL(compl_shown_match->cp_str));
  tv_dict_add_str(
      dict, S_LEN("abbr"),
      (const char *)EMPTY_IF_NULL(compl_shown_match->cp_text[CPT_ABBR]));
  tv_dict_add_str(
      dict, S_LEN("menu"),
      (const char *)EMPTY_IF_NULL(compl_shown_match->cp_text[CPT_MENU]));
  tv_dict_add_str(
      dict, S_LEN("kind"),
      (const char *)EMPTY_IF_NULL(compl_shown_match->cp_text[CPT_KIND]));
  tv_dict_add_str(
      dict, S_LEN("info"),
      (const char *)EMPTY_IF_NULL(compl_shown_match->cp_text[CPT_INFO]));
  tv_dict_add_str(
      dict, S_LEN("user_data"),
      (const char *)EMPTY_IF_NULL(compl_shown_match->cp_text[CPT_USER_DATA]));
  set_vim_var_dict(VV_COMPLETED_ITEM, dict);
  if (!in_compl_func) {
    compl_curr_match = compl_shown_match;
  }
}

/*
 * Fill in the next completion in the current direction.
 * If "allow_get_expansion" is TRUE, then we may call ins_compl_get_exp() to
 * get more completions.  If it is FALSE, then we just do nothing when there
 * are no more completions in a given direction.  The latter case is used when
 * we are still in the middle of finding completions, to allow browsing
 * through the ones found so far.
 * Return the total number of matches, or -1 if still unknown -- webb.
 *
 * compl_curr_match is currently being used by ins_compl_get_exp(), so we use
 * compl_shown_match here.
 *
 * Note that this function may be called recursively once only.  First with
 * "allow_get_expansion" TRUE, which calls ins_compl_get_exp(), which in turn
 * calls this function with "allow_get_expansion" FALSE.
 */
static int
ins_compl_next (
    int allow_get_expansion,
    int count,                // Repeat completion this many times; should
                              // be at least 1
    int insert_match,         // Insert the newly selected match
    int in_compl_func         // Called from complete_check()
)
{
  int num_matches = -1;
  int todo = count;
  compl_T *found_compl = NULL;
  int found_end = FALSE;
  int advance;
  int started = compl_started;

  /* When user complete function return -1 for findstart which is next
   * time of 'always', compl_shown_match become NULL. */
  if (compl_shown_match == NULL)
    return -1;

  if (compl_leader != NULL
      && (compl_shown_match->cp_flags & ORIGINAL_TEXT) == 0) {
    /* Set "compl_shown_match" to the actually shown match, it may differ
     * when "compl_leader" is used to omit some of the matches. */
    while (!ins_compl_equal(compl_shown_match,
               compl_leader, (int)STRLEN(compl_leader))
           && compl_shown_match->cp_next != NULL
           && compl_shown_match->cp_next != compl_first_match)
      compl_shown_match = compl_shown_match->cp_next;

    /* If we didn't find it searching forward, and compl_shows_dir is
     * backward, find the last match. */
    if (compl_shows_dir == BACKWARD
        && !ins_compl_equal(compl_shown_match,
            compl_leader, (int)STRLEN(compl_leader))
        && (compl_shown_match->cp_next == NULL
            || compl_shown_match->cp_next == compl_first_match)) {
      while (!ins_compl_equal(compl_shown_match,
                 compl_leader, (int)STRLEN(compl_leader))
             && compl_shown_match->cp_prev != NULL
             && compl_shown_match->cp_prev != compl_first_match)
        compl_shown_match = compl_shown_match->cp_prev;
    }
  }

  if (allow_get_expansion && insert_match
      && (!(compl_get_longest || compl_restarting) || compl_used_match))
    /* Delete old text to be replaced */
    ins_compl_delete();

  /* When finding the longest common text we stick at the original text,
   * don't let CTRL-N or CTRL-P move to the first match. */
  advance = count != 1 || !allow_get_expansion || !compl_get_longest;

  /* When restarting the search don't insert the first match either. */
  if (compl_restarting) {
    advance = FALSE;
    compl_restarting = FALSE;
  }

  /* Repeat this for when <PageUp> or <PageDown> is typed.  But don't wrap
   * around. */
  while (--todo >= 0) {
    if (compl_shows_dir == FORWARD && compl_shown_match->cp_next != NULL) {
      compl_shown_match = compl_shown_match->cp_next;
      found_end = (compl_first_match != NULL
                   && (compl_shown_match->cp_next == compl_first_match
                       || compl_shown_match == compl_first_match));
    } else if (compl_shows_dir == BACKWARD
               && compl_shown_match->cp_prev != NULL) {
      found_end = (compl_shown_match == compl_first_match);
      compl_shown_match = compl_shown_match->cp_prev;
      found_end |= (compl_shown_match == compl_first_match);
    } else {
      if (!allow_get_expansion) {
        if (advance) {
          if (compl_shows_dir == BACKWARD)
            compl_pending -= todo + 1;
          else
            compl_pending += todo + 1;
        }
        return -1;
      }

      if (!compl_no_select && advance) {
        if (compl_shows_dir == BACKWARD)
          --compl_pending;
        else
          ++compl_pending;
      }

      /* Find matches. */
      num_matches = ins_compl_get_exp(&compl_startpos);

      /* handle any pending completions */
      while (compl_pending != 0 && compl_direction == compl_shows_dir
             && advance) {
        if (compl_pending > 0 && compl_shown_match->cp_next != NULL) {
          compl_shown_match = compl_shown_match->cp_next;
          --compl_pending;
        }
        if (compl_pending < 0 && compl_shown_match->cp_prev != NULL) {
          compl_shown_match = compl_shown_match->cp_prev;
          ++compl_pending;
        } else
          break;
      }
      found_end = FALSE;
    }
    if ((compl_shown_match->cp_flags & ORIGINAL_TEXT) == 0
        && compl_leader != NULL
        && !ins_compl_equal(compl_shown_match,
            compl_leader, (int)STRLEN(compl_leader)))
      ++todo;
    else
      /* Remember a matching item. */
      found_compl = compl_shown_match;

    /* Stop at the end of the list when we found a usable match. */
    if (found_end) {
      if (found_compl != NULL) {
        compl_shown_match = found_compl;
        break;
      }
      todo = 1;             /* use first usable match after wrapping around */
    }
  }

  /* Insert the text of the new completion, or the compl_leader. */
  if (compl_no_insert && !started) {
    ins_bytes(compl_orig_text + ins_compl_len());
    compl_used_match = FALSE;
  } else if (insert_match) {
    if (!compl_get_longest || compl_used_match) {
      ins_compl_insert(in_compl_func);
    } else {
      ins_bytes(compl_leader + ins_compl_len());
    }
  } else {
    compl_used_match = FALSE;
  }

  if (!allow_get_expansion) {
    /* may undisplay the popup menu first */
    ins_compl_upd_pum();

    /* redraw to show the user what was inserted */
    update_screen(0);

    /* display the updated popup menu */
    ins_compl_show_pum();

    /* Delete old text to be replaced, since we're still searching and
     * don't want to match ourselves!  */
    ins_compl_delete();
  }

  /* Enter will select a match when the match wasn't inserted and the popup
   * menu is visible. */
  if (compl_no_insert && !started) {
    compl_enter_selects = TRUE;
  } else {
    compl_enter_selects = !insert_match && compl_match_array != NULL;
  }

  /*
   * Show the file name for the match (if any)
   * Truncate the file name to avoid a wait for return.
   */
  if (compl_shown_match->cp_fname != NULL) {
    char *lead = _("match in file");
    int space = sc_col - vim_strsize((char_u *)lead) - 2;
    char_u  *s;
    char_u  *e;

    if (space > 0) {
      // We need the tail that fits.  With double-byte encoding going
      // back from the end is very slow, thus go from the start and keep
      // the text that fits in "space" between "s" and "e".
      for (s = e = compl_shown_match->cp_fname; *e != NUL; MB_PTR_ADV(e)) {
        space -= ptr2cells(e);
        while (space < 0) {
          space += ptr2cells(s);
          MB_PTR_ADV(s);
        }
      }
      vim_snprintf((char *)IObuff, IOSIZE, "%s %s%s", lead,
                   s > compl_shown_match->cp_fname ? "<" : "", s);
      msg(IObuff);
      redraw_cmdline = false;     // don't overwrite!
    }
  }

  return num_matches;
}

// Call this while finding completions, to check whether the user has hit a key
// that should change the currently displayed completion, or exit completion
// mode.  Also, when compl_pending is not zero, show a completion as soon as
// possible. -- webb
// "frequency" specifies out of how many calls we actually check.
// "in_compl_func" is TRUE when called from complete_check(), don't set
// compl_curr_match.
void ins_compl_check_keys(int frequency, int in_compl_func)
{
  static int count = 0;

  int c;

  /* Don't check when reading keys from a script.  That would break the test
   * scripts */
  if (using_script())
    return;

  /* Only do this at regular intervals */
  if (++count < frequency)
    return;
  count = 0;

  /* Check for a typed key.  Do use mappings, otherwise vim_is_ctrl_x_key()
   * can't do its work correctly. */
  c = vpeekc_any();
  if (c != NUL) {
    if (vim_is_ctrl_x_key(c) && c != Ctrl_X && c != Ctrl_R) {
      c = safe_vgetc();         /* Eat the character */
      compl_shows_dir = ins_compl_key2dir(c);
      (void)ins_compl_next(false, ins_compl_key2count(c),
          c != K_UP && c != K_DOWN, in_compl_func);
    } else {
      /* Need to get the character to have KeyTyped set.  We'll put it
       * back with vungetc() below.  But skip K_IGNORE. */
      c = safe_vgetc();
      if (c != K_IGNORE) {
        /* Don't interrupt completion when the character wasn't typed,
         * e.g., when doing @q to replay keys. */
        if (c != Ctrl_R && KeyTyped)
          compl_interrupted = TRUE;

        vungetc(c);
      }
    }
  }
  if (compl_pending != 0 && !got_int && !compl_no_insert) {
    int todo = compl_pending > 0 ? compl_pending : -compl_pending;

    compl_pending = 0;
    (void)ins_compl_next(false, todo, true, in_compl_func);
  }
}

/*
 * Decide the direction of Insert mode complete from the key typed.
 * Returns BACKWARD or FORWARD.
 */
static int ins_compl_key2dir(int c)
{
  if (c == Ctrl_P || c == Ctrl_L
      || c == K_PAGEUP || c == K_KPAGEUP
      || c == K_S_UP || c == K_UP) {
    return BACKWARD;
  }
  return FORWARD;
}

/// Check that "c" is a valid completion key only while the popup menu is shown
///
/// @param  c  character to check
static bool ins_compl_pum_key(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return pum_visible() && (c == K_PAGEUP || c == K_KPAGEUP || c == K_S_UP
                           || c == K_PAGEDOWN || c == K_KPAGEDOWN
                           || c == K_S_DOWN || c == K_UP || c == K_DOWN);
}

/*
 * Decide the number of completions to move forward.
 * Returns 1 for most keys, height of the popup menu for page-up/down keys.
 */
static int ins_compl_key2count(int c)
{
  int h;

  if (ins_compl_pum_key(c) && c != K_UP && c != K_DOWN) {
    h = pum_get_height();
    if (h > 3)
      h -= 2;       /* keep some context */
    return h;
  }
  return 1;
}

/// Check that completion with "c" should insert the match, false if only
/// to change the currently selected completion.
///
/// @param  c  character to check
static bool ins_compl_use_match(int c)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (c) {
  case K_UP:
  case K_DOWN:
  case K_PAGEDOWN:
  case K_KPAGEDOWN:
  case K_S_DOWN:
  case K_PAGEUP:
  case K_KPAGEUP:
  case K_S_UP:
    return false;
  }
  return true;
}

/*
 * Do Insert mode completion.
 * Called when character "c" was typed, which has a meaning for completion.
 * Returns OK if completion was done, FAIL if something failed.
 */
static int ins_complete(int c, bool enable_pum)
{
  char_u      *line;
  int startcol = 0;                 /* column where searched text starts */
  colnr_T curs_col;                 /* cursor column */
  int n;
  int save_w_wrow;
  int save_w_leftcol;
  int insert_match;
  const bool save_did_ai = did_ai;

  compl_direction = ins_compl_key2dir(c);
  insert_match = ins_compl_use_match(c);

  if (!compl_started) {
    /* First time we hit ^N or ^P (in a row, I mean) */

    did_ai = false;
    did_si = false;
    can_si = false;
    can_si_back = false;
    if (stop_arrow() == FAIL) {
      return FAIL;
    }

    line = ml_get(curwin->w_cursor.lnum);
    curs_col = curwin->w_cursor.col;
    compl_pending = 0;

    /* If this same ctrl_x_mode has been interrupted use the text from
     * "compl_startpos" to the cursor as a pattern to add a new word
     * instead of expand the one before the cursor, in word-wise if
     * "compl_startpos" is not in the same line as the cursor then fix it
     * (the line has been split because it was longer than 'tw').  if SOL
     * is set then skip the previous pattern, a word at the beginning of
     * the line has been inserted, we'll look for that  -- Acevedo. */
    if ((compl_cont_status & CONT_INTRPT) == CONT_INTRPT
        && compl_cont_mode == ctrl_x_mode) {
      /*
       * it is a continued search
       */
      compl_cont_status &= ~CONT_INTRPT;        /* remove INTRPT */
      if (ctrl_x_mode == 0 || ctrl_x_mode == CTRL_X_PATH_PATTERNS
          || ctrl_x_mode == CTRL_X_PATH_DEFINES) {
        if (compl_startpos.lnum != curwin->w_cursor.lnum) {
          /* line (probably) wrapped, set compl_startpos to the
           * first non_blank in the line, if it is not a wordchar
           * include it to get a better pattern, but then we don't
           * want the "\\<" prefix, check it bellow */
          compl_col = (colnr_T)getwhitecols(line);
          compl_startpos.col = compl_col;
          compl_startpos.lnum = curwin->w_cursor.lnum;
          compl_cont_status &= ~CONT_SOL;             /* clear SOL if present */
        } else {
          /* S_IPOS was set when we inserted a word that was at the
           * beginning of the line, which means that we'll go to SOL
           * mode but first we need to redefine compl_startpos */
          if (compl_cont_status & CONT_S_IPOS) {
            compl_cont_status |= CONT_SOL;
            compl_startpos.col = (colnr_T)(skipwhite(
                                               line + compl_length
                                               + compl_startpos.col) - line);
          }
          compl_col = compl_startpos.col;
        }
        compl_length = curwin->w_cursor.col - (int)compl_col;
        /* IObuff is used to add a "word from the next line" would we
         * have enough space?  just being paranoid */
#define MIN_SPACE 75
        if (compl_length > (IOSIZE - MIN_SPACE)) {
          compl_cont_status &= ~CONT_SOL;
          compl_length = (IOSIZE - MIN_SPACE);
          compl_col = curwin->w_cursor.col - compl_length;
        }
        compl_cont_status |= CONT_ADDING | CONT_N_ADDS;
        if (compl_length < 1)
          compl_cont_status &= CONT_LOCAL;
      } else if (CTRL_X_MODE_LINE_OR_EVAL(ctrl_x_mode)) {
        compl_cont_status = CONT_ADDING | CONT_N_ADDS;
      } else
        compl_cont_status = 0;
    } else
      compl_cont_status &= CONT_LOCAL;

    if (!(compl_cont_status & CONT_ADDING)) {   /* normal expansion */
      compl_cont_mode = ctrl_x_mode;
      if (ctrl_x_mode != 0)             /* Remove LOCAL if ctrl_x_mode != 0 */
        compl_cont_status = 0;
      compl_cont_status |= CONT_N_ADDS;
      compl_startpos = curwin->w_cursor;
      startcol = (int)curs_col;
      compl_col = 0;
    }

    /* Work out completion pattern and original text -- webb */
    if (ctrl_x_mode == 0 || (ctrl_x_mode & CTRL_X_WANT_IDENT)) {
      if ((compl_cont_status & CONT_SOL)
          || ctrl_x_mode == CTRL_X_PATH_DEFINES) {
        if (!(compl_cont_status & CONT_ADDING)) {
          while (--startcol >= 0 && vim_isIDc(line[startcol]))
            ;
          compl_col += ++startcol;
          compl_length = curs_col - startcol;
        }
        if (p_ic)
          compl_pattern = str_foldcase(line + compl_col, compl_length, NULL, 0);
        else
          compl_pattern = vim_strnsave(line + compl_col, compl_length);
      } else if (compl_cont_status & CONT_ADDING) {
        char_u      *prefix = (char_u *)"\\<";

        /* we need up to 2 extra chars for the prefix */
        compl_pattern = xmalloc(quote_meta(NULL, line + compl_col,
                compl_length) + 2);
        if (!vim_iswordp(line + compl_col)
            || (compl_col > 0
                && (
                  vim_iswordp(mb_prevptr(line, line + compl_col))
                  )))
          prefix = (char_u *)"";
        STRCPY((char *)compl_pattern, prefix);
        (void)quote_meta(compl_pattern + STRLEN(prefix),
                         line + compl_col, compl_length);
      } else if (--startcol < 0
                 || !vim_iswordp(mb_prevptr(line, line + startcol + 1))) {
        // Match any word of at least two chars
        compl_pattern = vim_strsave((char_u *)"\\<\\k\\k");
        compl_col += curs_col;
        compl_length = 0;
      } else {
        // Search the point of change class of multibyte character
        // or not a word single byte character backward.
        startcol -= utf_head_off(line, line + startcol);
        int base_class = mb_get_class(line + startcol);
        while (--startcol >= 0) {
          int head_off = utf_head_off(line, line + startcol);
          if (base_class != mb_get_class(line + startcol - head_off)) {
            break;
          }
          startcol -= head_off;
        }
        compl_col += ++startcol;
        compl_length = (int)curs_col - startcol;
        if (compl_length == 1) {
          /* Only match word with at least two chars -- webb
           * there's no need to call quote_meta,
           * xmalloc(7) is enough  -- Acevedo
           */
          compl_pattern = xmalloc(7);
          STRCPY((char *)compl_pattern, "\\<");
          (void)quote_meta(compl_pattern + 2, line + compl_col, 1);
          STRCAT((char *)compl_pattern, "\\k");
        } else {
          compl_pattern = xmalloc(quote_meta(NULL, line + compl_col,
                  compl_length) + 2);
          STRCPY((char *)compl_pattern, "\\<");
          (void)quote_meta(compl_pattern + 2, line + compl_col,
              compl_length);
        }
      }
    } else if (CTRL_X_MODE_LINE_OR_EVAL(ctrl_x_mode)) {
      compl_col = (colnr_T)getwhitecols(line);
      compl_length = (int)curs_col - (int)compl_col;
      if (compl_length < 0)             /* cursor in indent: empty pattern */
        compl_length = 0;
      if (p_ic)
        compl_pattern = str_foldcase(line + compl_col, compl_length, NULL, 0);
      else
        compl_pattern = vim_strnsave(line + compl_col, compl_length);
    } else if (ctrl_x_mode == CTRL_X_FILES) {
      /* Go back to just before the first filename character. */
      if (startcol > 0) {
        char_u  *p = line + startcol;

        MB_PTR_BACK(line, p);
        while (p > line && vim_isfilec(PTR2CHAR(p))) {
          MB_PTR_BACK(line, p);
        }
        if (p == line && vim_isfilec(PTR2CHAR(p))) {
          startcol = 0;
        } else {
          startcol = (int)(p - line) + 1;
        }
      }

      compl_col += startcol;
      compl_length = (int)curs_col - startcol;
      compl_pattern = addstar(line + compl_col, compl_length, EXPAND_FILES);
    } else if (ctrl_x_mode == CTRL_X_CMDLINE) {
      compl_pattern = vim_strnsave(line, curs_col);
      set_cmd_context(&compl_xp, compl_pattern,
                      (int)STRLEN(compl_pattern), curs_col, false);
      if (compl_xp.xp_context == EXPAND_UNSUCCESSFUL
          || compl_xp.xp_context == EXPAND_NOTHING) {
        // No completion possible, use an empty pattern to get a
        // "pattern not found" message.
        compl_col = curs_col;
      } else {
        compl_col = (int)(compl_xp.xp_pattern - compl_pattern);
      }
      compl_length = curs_col - compl_col;
    } else if (ctrl_x_mode == CTRL_X_FUNCTION || ctrl_x_mode ==
               CTRL_X_OMNI) {
      /*
       * Call user defined function 'completefunc' with "a:findstart"
       * set to 1 to obtain the length of text to use for completion.
       */
      int col;
      char_u      *funcname;
      pos_T pos;
      win_T       *curwin_save;
      buf_T       *curbuf_save;

      /* Call 'completefunc' or 'omnifunc' and get pattern length as a
       * string */
      funcname = ctrl_x_mode == CTRL_X_FUNCTION
                 ? curbuf->b_p_cfu : curbuf->b_p_ofu;
      if (*funcname == NUL) {
        EMSG2(_(e_notset), ctrl_x_mode == CTRL_X_FUNCTION
            ? "completefunc" : "omnifunc");
        // restore did_ai, so that adding comment leader works
        did_ai = save_did_ai;
        return FAIL;
      }

      const char_u *const args[2] = { (char_u *)"1", NULL };
      pos = curwin->w_cursor;
      curwin_save = curwin;
      curbuf_save = curbuf;
      col = call_func_retnr(funcname, 2, args, FALSE);
      if (curwin_save != curwin || curbuf_save != curbuf) {
        EMSG(_(e_complwin));
        return FAIL;
      }
      curwin->w_cursor = pos;           /* restore the cursor position */
      validate_cursor();
      if (!equalpos(curwin->w_cursor, pos)) {
        EMSG(_(e_compldel));
        return FAIL;
      }

      /* Return value -2 means the user complete function wants to
       * cancel the complete without an error.
       * Return value -3 does the same as -2 and leaves CTRL-X mode.*/
      if (col == -2)
        return FAIL;
      if (col == -3) {
        ctrl_x_mode = 0;
        edit_submode = NULL;
        if (!shortmess(SHM_COMPLETIONMENU)) {
          msg_clr_cmdline();
        }
        return FAIL;
      }

      /*
       * Reset extended parameters of completion, when start new
       * completion.
       */
      compl_opt_refresh_always = FALSE;

      if (col < 0)
        col = curs_col;
      compl_col = col;
      if (compl_col > curs_col)
        compl_col = curs_col;

      /* Setup variables for completion.  Need to obtain "line" again,
       * it may have become invalid. */
      line = ml_get(curwin->w_cursor.lnum);
      compl_length = curs_col - compl_col;
      compl_pattern = vim_strnsave(line + compl_col, compl_length);
    } else if (ctrl_x_mode == CTRL_X_SPELL) {
      if (spell_bad_len > 0) {
        assert(spell_bad_len <= INT_MAX);
        compl_col = curs_col - (int)spell_bad_len;
      }
      else
        compl_col = spell_word_start(startcol);
      if (compl_col >= (colnr_T)startcol) {
        compl_length = 0;
        compl_col = curs_col;
      } else {
        spell_expand_check_cap(compl_col);
        compl_length = (int)curs_col - compl_col;
      }
      /* Need to obtain "line" again, it may have become invalid. */
      line = ml_get(curwin->w_cursor.lnum);
      compl_pattern = vim_strnsave(line + compl_col, compl_length);
    } else {
      internal_error("ins_complete()");
      return FAIL;
    }

    if (compl_cont_status & CONT_ADDING) {
      edit_submode_pre = (char_u *)_(" Adding");
      if (CTRL_X_MODE_LINE_OR_EVAL(ctrl_x_mode)) {
        /* Insert a new line, keep indentation but ignore 'comments' */
        char_u *old = curbuf->b_p_com;

        curbuf->b_p_com = (char_u *)"";
        compl_startpos.lnum = curwin->w_cursor.lnum;
        compl_startpos.col = compl_col;
        ins_eol('\r');
        curbuf->b_p_com = old;
        compl_length = 0;
        compl_col = curwin->w_cursor.col;
      }
    } else {
      edit_submode_pre = NULL;
      compl_startpos.col = compl_col;
    }

    if (compl_cont_status & CONT_LOCAL)
      edit_submode = (char_u *)_(ctrl_x_msgs[CTRL_X_LOCAL_MSG]);
    else
      edit_submode = (char_u *)_(CTRL_X_MSG(ctrl_x_mode));

    /* If any of the original typed text has been changed we need to fix
     * the redo buffer. */
    ins_compl_fixRedoBufForLeader(NULL);

    /* Always add completion for the original text. */
    xfree(compl_orig_text);
    compl_orig_text = vim_strnsave(line + compl_col, compl_length);
    if (ins_compl_add(compl_orig_text, -1, p_ic, NULL, NULL, false, 0,
                      ORIGINAL_TEXT, false) != OK) {
      xfree(compl_pattern);
      compl_pattern = NULL;
      xfree(compl_orig_text);
      compl_orig_text = NULL;
      return FAIL;
    }

    /* showmode might reset the internal line pointers, so it must
     * be called before line = ml_get(), or when this address is no
     * longer needed.  -- Acevedo.
     */
    edit_submode_extra = (char_u *)_("-- Searching...");
    edit_submode_highl = HLF_COUNT;
    showmode();
    edit_submode_extra = NULL;
    ui_flush();
  } else if (insert_match && stop_arrow() == FAIL) {
    return FAIL;
  }

  compl_shown_match = compl_curr_match;
  compl_shows_dir = compl_direction;

  /*
   * Find next match (and following matches).
   */
  save_w_wrow = curwin->w_wrow;
  save_w_leftcol = curwin->w_leftcol;
  n = ins_compl_next(true, ins_compl_key2count(c), insert_match, false);

  /* may undisplay the popup menu */
  ins_compl_upd_pum();

  if (n > 1)            /* all matches have been found */
    compl_matches = n;
  compl_curr_match = compl_shown_match;
  compl_direction = compl_shows_dir;

  /* Eat the ESC that vgetc() returns after a CTRL-C to avoid leaving Insert
   * mode. */
  if (got_int && !global_busy) {
    (void)vgetc();
    got_int = FALSE;
  }

  /* we found no match if the list has only the "compl_orig_text"-entry */
  if (compl_first_match == compl_first_match->cp_next) {
    edit_submode_extra = (compl_cont_status & CONT_ADDING)
                         && compl_length > 1
                         ? (char_u *)_(e_hitend) : (char_u *)_(e_patnotf);
    edit_submode_highl = HLF_E;
    /* remove N_ADDS flag, so next ^X<> won't try to go to ADDING mode,
     * because we couldn't expand anything at first place, but if we used
     * ^P, ^N, ^X^I or ^X^D we might want to add-expand a single-char-word
     * (such as M in M'exico) if not tried already.  -- Acevedo */
    if (       compl_length > 1
               || (compl_cont_status & CONT_ADDING)
               || (ctrl_x_mode != 0
                   && ctrl_x_mode != CTRL_X_PATH_PATTERNS
                   && ctrl_x_mode != CTRL_X_PATH_DEFINES))
      compl_cont_status &= ~CONT_N_ADDS;
  }

  if (compl_curr_match->cp_flags & CONT_S_IPOS)
    compl_cont_status |= CONT_S_IPOS;
  else
    compl_cont_status &= ~CONT_S_IPOS;

  if (edit_submode_extra == NULL) {
    if (compl_curr_match->cp_flags & ORIGINAL_TEXT) {
      edit_submode_extra = (char_u *)_("Back at original");
      edit_submode_highl = HLF_W;
    } else if (compl_cont_status & CONT_S_IPOS) {
      edit_submode_extra = (char_u *)_("Word from other line");
      edit_submode_highl = HLF_COUNT;
    } else if (compl_curr_match->cp_next == compl_curr_match->cp_prev) {
      edit_submode_extra = (char_u *)_("The only match");
      edit_submode_highl = HLF_COUNT;
    } else {
      /* Update completion sequence number when needed. */
      if (compl_curr_match->cp_number == -1) {
        int number = 0;
        compl_T         *match;

        if (compl_direction == FORWARD) {
          /* search backwards for the first valid (!= -1) number.
           * This should normally succeed already at the first loop
           * cycle, so it's fast! */
          for (match = compl_curr_match->cp_prev; match != NULL
               && match != compl_first_match;
               match = match->cp_prev)
            if (match->cp_number != -1) {
              number = match->cp_number;
              break;
            }
          if (match != NULL)
            /* go up and assign all numbers which are not assigned
             * yet */
            for (match = match->cp_next;
                 match != NULL && match->cp_number == -1;
                 match = match->cp_next)
              match->cp_number = ++number;
        } else {   /* BACKWARD */
                     /* search forwards (upwards) for the first valid (!= -1)
                      * number.  This should normally succeed already at the
                      * first loop cycle, so it's fast! */
          for (match = compl_curr_match->cp_next; match != NULL
               && match != compl_first_match;
               match = match->cp_next)
            if (match->cp_number != -1) {
              number = match->cp_number;
              break;
            }
          if (match != NULL)
            /* go down and assign all numbers which are not
             * assigned yet */
            for (match = match->cp_prev; match
                 && match->cp_number == -1;
                 match = match->cp_prev)
              match->cp_number = ++number;
        }
      }

      /* The match should always have a sequence number now, this is
       * just a safety check. */
      if (compl_curr_match->cp_number != -1) {
        /* Space for 10 text chars. + 2x10-digit no.s = 31.
         * Translations may need more than twice that. */
        static char_u match_ref[81];

        if (compl_matches > 0)
          vim_snprintf((char *)match_ref, sizeof(match_ref),
              _("match %d of %d"),
              compl_curr_match->cp_number, compl_matches);
        else
          vim_snprintf((char *)match_ref, sizeof(match_ref),
              _("match %d"),
              compl_curr_match->cp_number);
        edit_submode_extra = match_ref;
        edit_submode_highl = HLF_R;
        if (dollar_vcol >= 0)
          curs_columns(FALSE);
      }
    }
  }

  /* Show a message about what (completion) mode we're in. */
  showmode();
  if (!shortmess(SHM_COMPLETIONMENU)) {
    if (edit_submode_extra != NULL) {
      if (!p_smd) {
        msg_attr((const char *)edit_submode_extra,
                 (edit_submode_highl < HLF_COUNT
                  ? HL_ATTR(edit_submode_highl) : 0));
      }
    } else {
      msg_clr_cmdline();  // necessary for "noshowmode"
    }
  }

  // Show the popup menu, unless we got interrupted.
  if (enable_pum && !compl_interrupted) {
    show_pum(save_w_wrow, save_w_leftcol);
  }
  compl_was_interrupted = compl_interrupted;
  compl_interrupted = FALSE;

  return OK;
}

/*
 * Looks in the first "len" chars. of "src" for search-metachars.
 * If dest is not NULL the chars. are copied there quoting (with
 * a backslash) the metachars, and dest would be NUL terminated.
 * Returns the length (needed) of dest
 */
static unsigned quote_meta(char_u *dest, char_u *src, int len)
{
  unsigned m = (unsigned)len + 1;       /* one extra for the NUL */

  for (; --len >= 0; src++) {
    switch (*src) {
    case '.':
    case '*':
    case '[':
      if (ctrl_x_mode == CTRL_X_DICTIONARY
          || ctrl_x_mode == CTRL_X_THESAURUS)
        break;
      FALLTHROUGH;
    case '~':
      if (!p_magic)             /* quote these only if magic is set */
        break;
      FALLTHROUGH;
    case '\\':
      if (ctrl_x_mode == CTRL_X_DICTIONARY
          || ctrl_x_mode == CTRL_X_THESAURUS)
        break;
      FALLTHROUGH;
    case '^':                   // currently it's not needed.
    case '$':
      m++;
      if (dest != NULL)
        *dest++ = '\\';
      break;
    }
    if (dest != NULL)
      *dest++ = *src;
    /* Copy remaining bytes of a multibyte character. */
    if (has_mbyte) {
      int i, mb_len;

      mb_len = (*mb_ptr2len)(src) - 1;
      if (mb_len > 0 && len >= mb_len)
        for (i = 0; i < mb_len; ++i) {
          --len;
          ++src;
          if (dest != NULL)
            *dest++ = *src;
        }
    }
  }
  if (dest != NULL)
    *dest = NUL;

  return m;
}

/*
 * Next character is interpreted literally.
 * A one, two or three digit decimal number is interpreted as its byte value.
 * If one or two digits are entered, the next character is given to vungetc().
 * For Unicode a character > 255 may be returned.
 */
int get_literal(void)
{
  int cc;
  int nc;
  int i;
  int hex = FALSE;
  int octal = FALSE;
  int unicode = 0;

  if (got_int)
    return Ctrl_C;

  ++no_mapping;                 /* don't map the next key hits */
  cc = 0;
  i = 0;
  for (;; ) {
    nc = plain_vgetc();
    if (!(State & CMDLINE)
        && MB_BYTE2LEN_CHECK(nc) == 1
        )
      add_to_showcmd(nc);
    if (nc == 'x' || nc == 'X')
      hex = TRUE;
    else if (nc == 'o' || nc == 'O')
      octal = TRUE;
    else if (nc == 'u' || nc == 'U')
      unicode = nc;
    else {
      if (hex
          || unicode != 0
          ) {
        if (!ascii_isxdigit(nc))
          break;
        cc = cc * 16 + hex2nr(nc);
      } else if (octal) {
        if (nc < '0' || nc > '7')
          break;
        cc = cc * 8 + nc - '0';
      } else {
        if (!ascii_isdigit(nc))
          break;
        cc = cc * 10 + nc - '0';
      }

      ++i;
    }

    if (cc > 255
        && unicode == 0
        )
      cc = 255;                 /* limit range to 0-255 */
    nc = 0;

    if (hex) {                  /* hex: up to two chars */
      if (i >= 2)
        break;
    } else if (unicode) {     /* Unicode: up to four or eight chars */
      if ((unicode == 'u' && i >= 4) || (unicode == 'U' && i >= 8))
        break;
    } else if (i >= 3)          /* decimal or octal: up to three chars */
      break;
  }
  if (i == 0) {     /* no number entered */
    if (nc == K_ZERO) {     /* NUL is stored as NL */
      cc = '\n';
      nc = 0;
    } else {
      cc = nc;
      nc = 0;
    }
  }

  if (cc == 0)          /* NUL is stored as NL */
    cc = '\n';
  if (enc_dbcs && (cc & 0xff) == 0)
    cc = '?';           /* don't accept an illegal DBCS char, the NUL in the
                           second byte will cause trouble! */

  --no_mapping;
  if (nc)
    vungetc(nc);
  got_int = FALSE;          /* CTRL-C typed after CTRL-V is not an interrupt */
  return cc;
}

/// Insert character, taking care of special keys and mod_mask
///
/// @param ctrlv `c` was typed after CTRL-V
static void insert_special(int c, int allow_modmask, int ctrlv)
{
  char_u  *p;
  int len;

  // Special function key, translate into "<Key>". Up to the last '>' is
  // inserted with ins_str(), so as not to replace characters in replace
  // mode.
  // Only use mod_mask for special keys, to avoid things like <S-Space>,
  // unless 'allow_modmask' is TRUE.
  if (mod_mask & MOD_MASK_CMD) {  // Command-key never produces a normal key.
    allow_modmask = true;
  }
  if (IS_SPECIAL(c) || (mod_mask && allow_modmask)) {
    p = get_special_key_name(c, mod_mask);
    len = (int)STRLEN(p);
    c = p[len - 1];
    if (len > 2) {
      if (stop_arrow() == FAIL)
        return;
      p[len - 1] = NUL;
      ins_str(p);
      AppendToRedobuffLit(p, -1);
      ctrlv = FALSE;
    }
  }
  if (stop_arrow() == OK)
    insertchar(c, ctrlv ? INSCHAR_CTRLV : 0, -1);
}

/*
 * Special characters in this context are those that need processing other
 * than the simple insertion that can be performed here. This includes ESC
 * which terminates the insert, and CR/NL which need special processing to
 * open up a new line. This routine tries to optimize insertions performed by
 * the "redo", "undo" or "put" commands, so it needs to know when it should
 * stop and defer processing to the "normal" mechanism.
 * '0' and '^' are special, because they can be followed by CTRL-D.
 */
# define ISSPECIAL(c)   ((c) < ' ' || (c) >= DEL || (c) == '0' || (c) == '^')

# define WHITECHAR(cc) (ascii_iswhite(cc) && \
                        (!enc_utf8 || \
                         !utf_iscomposing( \
                           utf_ptr2char(get_cursor_pos_ptr() + 1))))

/*
 * "flags": INSCHAR_FORMAT - force formatting
 *	    INSCHAR_CTRLV  - char typed just after CTRL-V
 *	    INSCHAR_NO_FEX - don't use 'formatexpr'
 *
 *   NOTE: passes the flags value straight through to internal_format() which,
 *	   beside INSCHAR_FORMAT (above), is also looking for these:
 *	    INSCHAR_DO_COM   - format comments
 *	    INSCHAR_COM_LIST - format comments with num list or 2nd line indent
 */
void
insertchar (
    int c,                                  /* character to insert or NUL */
    int flags,                              /* INSCHAR_FORMAT, etc. */
    int second_indent                      /* indent for second line if >= 0 */
)
{
  int textwidth;
  char_u      *p;
  int fo_ins_blank;
  int force_format = flags & INSCHAR_FORMAT;

  textwidth = comp_textwidth(force_format);
  fo_ins_blank = has_format_option(FO_INS_BLANK);

  /*
   * Try to break the line in two or more pieces when:
   * - Always do this if we have been called to do formatting only.
   * - Always do this when 'formatoptions' has the 'a' flag and the line
   *   ends in white space.
   * - Otherwise:
   *	 - Don't do this if inserting a blank
   *	 - Don't do this if an existing character is being replaced, unless
   *	   we're in VREPLACE mode.
   *	 - Do this if the cursor is not on the line where insert started
   *	 or - 'formatoptions' doesn't have 'l' or the line was not too long
   *	       before the insert.
   *	    - 'formatoptions' doesn't have 'b' or a blank was inserted at or
   *	      before 'textwidth'
   */
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
                          || Insstart_blank_vcol <= (colnr_T)textwidth
                          )))))) {
    /* Format with 'formatexpr' when it's set.  Use internal formatting
     * when 'formatexpr' isn't set or it returns non-zero. */
    int do_internal = TRUE;
    colnr_T virtcol = get_nolist_virtcol()
                    + char2cells(c != NUL ? c : gchar_cursor());

    if (*curbuf->b_p_fex != NUL && (flags & INSCHAR_NO_FEX) == 0
        && (force_format || virtcol > (colnr_T)textwidth)) {
      do_internal = (fex_format(curwin->w_cursor.lnum, 1L, c) != 0);
      /* It may be required to save for undo again, e.g. when setline()
       * was called. */
      ins_need_undo = TRUE;
    }
    if (do_internal)
      internal_format(textwidth, second_indent, flags, c == NUL, c);
  }

  if (c == NUL)             /* only formatting was wanted */
    return;

  /* Check whether this character should end a comment. */
  if (did_ai && c == end_comment_pending) {
    char_u  *line;
    char_u lead_end[COM_MAX_LEN];           /* end-comment string */
    int middle_len, end_len;
    int i;

    /*
     * Need to remove existing (middle) comment leader and insert end
     * comment leader.  First, check what comment leader we can find.
     */
    i = get_leader_len(line = get_cursor_line_ptr(), &p, FALSE, TRUE);
    if (i > 0 && vim_strchr(p, COM_MIDDLE) != NULL) {   /* Just checking */
      /* Skip middle-comment string */
      while (*p && p[-1] != ':')        /* find end of middle flags */
        ++p;
      middle_len = copy_option_part(&p, lead_end, COM_MAX_LEN, ",");
      /* Don't count trailing white space for middle_len */
      while (middle_len > 0 && ascii_iswhite(lead_end[middle_len - 1]))
        --middle_len;

      /* Find the end-comment string */
      while (*p && p[-1] != ':')        /* find end of end flags */
        ++p;
      end_len = copy_option_part(&p, lead_end, COM_MAX_LEN, ",");

      /* Skip white space before the cursor */
      i = curwin->w_cursor.col;
      while (--i >= 0 && ascii_iswhite(line[i]))
        ;
      i++;

      /* Skip to before the middle leader */
      i -= middle_len;

      /* Check some expected things before we go on */
      if (i >= 0 && lead_end[end_len - 1] == end_comment_pending) {
        /* Backspace over all the stuff we want to replace */
        backspace_until_column(i);

        /*
         * Insert the end-comment string, except for the last
         * character, which will get inserted as normal later.
         */
        ins_bytes_len(lead_end, end_len - 1);
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
  if (!ISSPECIAL(c)
      && (!has_mbyte || (*mb_char2len)(c) == 1)
      && vpeekc() != NUL
      && !(State & REPLACE_FLAG)
      && !cindent_on()
      && !p_ri
      && !has_event(EVENT_INSERTCHARPRE)) {
#define INPUT_BUFLEN 100
    char_u buf[INPUT_BUFLEN + 1];
    int i;
    colnr_T virtcol = 0;

    buf[0] = c;
    i = 1;
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
           && !(p_fkmap && KeyTyped)  // Farsi mode mapping moves cursor
           && (textwidth == 0
               || (virtcol += byte2cells(buf[i - 1])) < (colnr_T)textwidth)
           && !(!no_abbr && !vim_iswordc(c) && vim_iswordc(buf[i - 1]))) {
      c = vgetc();
      if (p_hkmap && KeyTyped) {
        c = hkmap(c);                       // Hebrew mode mapping
      }
      buf[i++] = c;
    }

    do_digraph(-1);                     /* clear digraphs */
    do_digraph(buf[i-1]);               /* may be the start of a digraph */
    buf[i] = NUL;
    ins_str(buf);
    if (flags & INSCHAR_CTRLV) {
      redo_literal(*buf);
      i = 1;
    } else
      i = 0;
    if (buf[i] != NUL)
      AppendToRedobuffLit(buf + i, -1);
  } else {
    int cc;

    if ((cc = utf_char2len(c)) > 1) {
      char_u buf[MB_MAXBYTES + 1];

      utf_char2bytes(c, buf);
      buf[cc] = NUL;
      ins_char_bytes(buf, cc);
      AppendCharToRedobuff(c);
    } else {
      ins_char(c);
      if (flags & INSCHAR_CTRLV)
        redo_literal(c);
      else
        AppendCharToRedobuff(c);
    }
  }
}

/*
 * Format text at the current insert position.
 *
 * If the INSCHAR_COM_LIST flag is present, then the value of second_indent
 * will be the comment leader length sent to open_line().
 */
static void
internal_format (
    int textwidth,
    int second_indent,
    int flags,
    int format_only,
    int c             /* character to be inserted (can be NUL) */
)
{
  int cc;
  int save_char = NUL;
  bool haveto_redraw = false;
  int fo_ins_blank = has_format_option(FO_INS_BLANK);
  int fo_multibyte = has_format_option(FO_MBYTE_BREAK);
  int fo_white_par = has_format_option(FO_WHITE_PAR);
  int first_line = TRUE;
  colnr_T leader_len;
  int no_leader = FALSE;
  int do_comments = (flags & INSCHAR_DO_COM);
  int has_lbr = curwin->w_p_lbr;

  // make sure win_lbr_chartabsize() counts correctly
  curwin->w_p_lbr = false;

  /*
   * When 'ai' is off we don't want a space under the cursor to be
   * deleted.  Replace it with an 'x' temporarily.
   */
  if (!curbuf->b_p_ai
      && !(State & VREPLACE_FLAG)
      ) {
    cc = gchar_cursor();
    if (ascii_iswhite(cc)) {
      save_char = cc;
      pchar_cursor('x');
    }
  }

  /*
   * Repeat breaking lines, until the current line is not too long.
   */
  while (!got_int) {
    int startcol;                       /* Cursor column at entry */
    int wantcol;                        /* column at textwidth border */
    int foundcol;                       /* column for start of spaces */
    int end_foundcol = 0;               /* column for start of word */
    colnr_T len;
    colnr_T virtcol;
    int orig_col = 0;
    char_u  *saved_text = NULL;
    colnr_T col;
    colnr_T end_col;

    virtcol = get_nolist_virtcol()
              + char2cells(c != NUL ? c : gchar_cursor());
    if (virtcol <= (colnr_T)textwidth)
      break;

    if (no_leader)
      do_comments = FALSE;
    else if (!(flags & INSCHAR_FORMAT)
             && has_format_option(FO_WRAP_COMS))
      do_comments = TRUE;

    /* Don't break until after the comment leader */
    if (do_comments)
      leader_len = get_leader_len(get_cursor_line_ptr(), NULL, FALSE, TRUE);
    else
      leader_len = 0;

    /* If the line doesn't start with a comment leader, then don't
     * start one in a following broken line.  Avoids that a %word
     * moved to the start of the next line causes all following lines
     * to start with %. */
    if (leader_len == 0)
      no_leader = TRUE;
    if (!(flags & INSCHAR_FORMAT)
        && leader_len == 0
        && !has_format_option(FO_WRAP))

      break;
    if ((startcol = curwin->w_cursor.col) == 0)
      break;

    /* find column of textwidth border */
    coladvance((colnr_T)textwidth);
    wantcol = curwin->w_cursor.col;

    curwin->w_cursor.col = startcol;
    foundcol = 0;

    /*
     * Find position to break at.
     * Stop at first entered white when 'formatoptions' has 'v'
     */
    while ((!fo_ins_blank && !has_format_option(FO_INS_VI))
           || (flags & INSCHAR_FORMAT)
           || curwin->w_cursor.lnum != Insstart.lnum
           || curwin->w_cursor.col >= Insstart.col) {
      if (curwin->w_cursor.col == startcol && c != NUL)
        cc = c;
      else
        cc = gchar_cursor();
      if (WHITECHAR(cc)) {
        /* remember position of blank just before text */
        end_col = curwin->w_cursor.col;

        /* find start of sequence of blanks */
        while (curwin->w_cursor.col > 0 && WHITECHAR(cc)) {
          dec_cursor();
          cc = gchar_cursor();
        }
        if (curwin->w_cursor.col == 0 && WHITECHAR(cc))
          break;                        /* only spaces in front of text */
        /* Don't break until after the comment leader */
        if (curwin->w_cursor.col < leader_len)
          break;
        if (has_format_option(FO_ONE_LETTER)) {
          /* do not break after one-letter words */
          if (curwin->w_cursor.col == 0)
            break;              /* one-letter word at begin */
          /* do not break "#a b" when 'tw' is 2 */
          if (curwin->w_cursor.col <= leader_len)
            break;
          col = curwin->w_cursor.col;
          dec_cursor();
          cc = gchar_cursor();

          if (WHITECHAR(cc))
            continue;                   /* one-letter, continue */
          curwin->w_cursor.col = col;
        }

        inc_cursor();

        end_foundcol = end_col + 1;
        foundcol = curwin->w_cursor.col;
        if (curwin->w_cursor.col <= (colnr_T)wantcol)
          break;
      } else if (cc >= 0x100 && fo_multibyte) {
        /* Break after or before a multi-byte character. */
        if (curwin->w_cursor.col != startcol) {
          /* Don't break until after the comment leader */
          if (curwin->w_cursor.col < leader_len)
            break;
          col = curwin->w_cursor.col;
          inc_cursor();
          /* Don't change end_foundcol if already set. */
          if (foundcol != curwin->w_cursor.col) {
            foundcol = curwin->w_cursor.col;
            end_foundcol = foundcol;
            if (curwin->w_cursor.col <= (colnr_T)wantcol)
              break;
          }
          curwin->w_cursor.col = col;
        }

        if (curwin->w_cursor.col == 0)
          break;

        col = curwin->w_cursor.col;

        dec_cursor();
        cc = gchar_cursor();

        if (WHITECHAR(cc))
          continue;                     /* break with space */
        /* Don't break until after the comment leader */
        if (curwin->w_cursor.col < leader_len)
          break;

        curwin->w_cursor.col = col;

        foundcol = curwin->w_cursor.col;
        end_foundcol = foundcol;
        if (curwin->w_cursor.col <= (colnr_T)wantcol)
          break;
      }
      if (curwin->w_cursor.col == 0)
        break;
      dec_cursor();
    }

    if (foundcol == 0) {                /* no spaces, cannot break line */
      curwin->w_cursor.col = startcol;
      break;
    }

    /* Going to break the line, remove any "$" now. */
    undisplay_dollar();

    /*
     * Offset between cursor position and line break is used by replace
     * stack functions.  VREPLACE does not use this, and backspaces
     * over the text instead.
     */
    if (State & VREPLACE_FLAG)
      orig_col = startcol;              /* Will start backspacing from here */
    else
      replace_offset = startcol - end_foundcol;

    /*
     * adjust startcol for spaces that will be deleted and
     * characters that will remain on top line
     */
    curwin->w_cursor.col = foundcol;
    while ((cc = gchar_cursor(), WHITECHAR(cc))
           && (!fo_white_par || curwin->w_cursor.col < startcol))
      inc_cursor();
    startcol -= curwin->w_cursor.col;
    if (startcol < 0)
      startcol = 0;

    if (State & VREPLACE_FLAG) {
      /*
       * In VREPLACE mode, we will backspace over the text to be
       * wrapped, so save a copy now to put on the next line.
       */
      saved_text = vim_strsave(get_cursor_pos_ptr());
      curwin->w_cursor.col = orig_col;
      saved_text[startcol] = NUL;

      /* Backspace over characters that will move to the next line */
      if (!fo_white_par)
        backspace_until_column(foundcol);
    } else {
      /* put cursor after pos. to break line */
      if (!fo_white_par)
        curwin->w_cursor.col = foundcol;
    }

    /*
     * Split the line just before the margin.
     * Only insert/delete lines, but don't really redraw the window.
     */
    open_line(FORWARD, OPENLINE_DELSPACES + OPENLINE_MARKFIX
        + (fo_white_par ? OPENLINE_KEEPTRAIL : 0)
        + (do_comments ? OPENLINE_DO_COM : 0)
        + ((flags & INSCHAR_COM_LIST) ? OPENLINE_COM_LIST : 0)
        , ((flags & INSCHAR_COM_LIST) ? second_indent : old_indent));
    if (!(flags & INSCHAR_COM_LIST))
      old_indent = 0;

    replace_offset = 0;
    if (first_line) {
      if (!(flags & INSCHAR_COM_LIST)) {
        /*
         * This section is for auto-wrap of numeric lists.  When not
         * in insert mode (i.e. format_lines()), the INSCHAR_COM_LIST
         * flag will be set and open_line() will handle it (as seen
         * above).  The code here (and in get_number_indent()) will
         * recognize comments if needed...
         */
        if (second_indent < 0 && has_format_option(FO_Q_NUMBER))
          second_indent =
            get_number_indent(curwin->w_cursor.lnum - 1);
        if (second_indent >= 0) {
          if (State & VREPLACE_FLAG)
            change_indent(INDENT_SET, second_indent,
                FALSE, NUL, TRUE);
          else if (leader_len > 0 && second_indent - leader_len > 0) {
            int i;
            int padding = second_indent - leader_len;

            /* We started at the first_line of a numbered list
             * that has a comment.  the open_line() function has
             * inserted the proper comment leader and positioned
             * the cursor at the end of the split line.  Now we
             * add the additional whitespace needed after the
             * comment leader for the numbered list.  */
            for (i = 0; i < padding; i++)
              ins_str((char_u *)" ");
            changed_bytes(curwin->w_cursor.lnum, leader_len);
          } else {
            (void)set_indent(second_indent, SIN_CHANGED);
          }
        }
      }
      first_line = FALSE;
    }

    if (State & VREPLACE_FLAG) {
      /*
       * In VREPLACE mode we have backspaced over the text to be
       * moved, now we re-insert it into the new line.
       */
      ins_bytes(saved_text);
      xfree(saved_text);
    } else {
      /*
       * Check if cursor is not past the NUL off the line, cindent
       * may have added or removed indent.
       */
      curwin->w_cursor.col += startcol;
      len = (colnr_T)STRLEN(get_cursor_line_ptr());
      if (curwin->w_cursor.col > len)
        curwin->w_cursor.col = len;
    }

    haveto_redraw = true;
    can_cindent = true;
    // moved the cursor, don't autoindent or cindent now
    did_ai = false;
    did_si = false;
    can_si = false;
    can_si_back = false;
    line_breakcheck();
  }

  if (save_char != NUL)                 /* put back space after cursor */
    pchar_cursor(save_char);

  curwin->w_p_lbr = has_lbr;

  if (!format_only && haveto_redraw) {
    update_topline();
    redraw_curbuf_later(VALID);
  }
}

/*
 * Called after inserting or deleting text: When 'formatoptions' includes the
 * 'a' flag format from the current line until the end of the paragraph.
 * Keep the cursor at the same position relative to the text.
 * The caller must have saved the cursor line for undo, following ones will be
 * saved here.
 */
void
auto_format (
    int trailblank,                 /* when TRUE also format with trailing blank */
    int prev_line                  /* may start in previous line */
)
{
  pos_T pos;
  colnr_T len;
  char_u      *old;
  char_u      *new, *pnew;
  int wasatend;
  int cc;

  if (!has_format_option(FO_AUTO))
    return;

  pos = curwin->w_cursor;
  old = get_cursor_line_ptr();

  // may remove added space
  check_auto_format(false);

  /* Don't format in Insert mode when the cursor is on a trailing blank, the
   * user might insert normal text next.  Also skip formatting when "1" is
   * in 'formatoptions' and there is a single character before the cursor.
   * Otherwise the line would be broken and when typing another non-white
   * next they are not joined back together. */
  wasatend = (pos.col == (colnr_T)STRLEN(old));
  if (*old != NUL && !trailblank && wasatend) {
    dec_cursor();
    cc = gchar_cursor();
    if (!WHITECHAR(cc) && curwin->w_cursor.col > 0
        && has_format_option(FO_ONE_LETTER))
      dec_cursor();
    cc = gchar_cursor();
    if (WHITECHAR(cc)) {
      curwin->w_cursor = pos;
      return;
    }
    curwin->w_cursor = pos;
  }

  /* With the 'c' flag in 'formatoptions' and 't' missing: only format
   * comments. */
  if (has_format_option(FO_WRAP_COMS) && !has_format_option(FO_WRAP)
      && get_leader_len(old, NULL, FALSE, TRUE) == 0)
    return;

  /*
   * May start formatting in a previous line, so that after "x" a word is
   * moved to the previous line if it fits there now.  Only when this is not
   * the start of a paragraph.
   */
  if (prev_line && !paragraph_start(curwin->w_cursor.lnum)) {
    --curwin->w_cursor.lnum;
    if (u_save_cursor() == FAIL)
      return;
  }

  /*
   * Do the formatting and restore the cursor position.  "saved_cursor" will
   * be adjusted for the text formatting.
   */
  saved_cursor = pos;
  format_lines((linenr_T)-1, FALSE);
  curwin->w_cursor = saved_cursor;
  saved_cursor.lnum = 0;

  if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
    /* "cannot happen" */
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    coladvance((colnr_T)MAXCOL);
  } else
    check_cursor_col();

  /* Insert mode: If the cursor is now after the end of the line while it
   * previously wasn't, the line was broken.  Because of the rule above we
   * need to add a space when 'w' is in 'formatoptions' to keep a paragraph
   * formatted. */
  if (!wasatend && has_format_option(FO_WHITE_PAR)) {
    new = get_cursor_line_ptr();
    len = (colnr_T)STRLEN(new);
    if (curwin->w_cursor.col == len) {
      pnew = vim_strnsave(new, len + 2);
      pnew[len] = ' ';
      pnew[len + 1] = NUL;
      ml_replace(curwin->w_cursor.lnum, pnew, false);
      // remove the space later
      did_add_space = true;
    } else {
      // may remove added space
      check_auto_format(false);
    }
  }

  check_cursor();
}

/*
 * When an extra space was added to continue a paragraph for auto-formatting,
 * delete it now.  The space must be under the cursor, just after the insert
 * position.
 */
static void check_auto_format(
    bool end_insert                   // true when ending Insert mode
)
{
  int c = ' ';
  int cc;

  if (did_add_space) {
    cc = gchar_cursor();
    if (!WHITECHAR(cc)) {
      // Somehow the space was removed already.
      did_add_space = false;
    } else {
      if (!end_insert) {
        inc_cursor();
        c = gchar_cursor();
        dec_cursor();
      }
      if (c != NUL) {
        // The space is no longer at the end of the line, delete it.
        del_char(false);
        did_add_space = false;
      }
    }
  }
}

/*
 * Find out textwidth to be used for formatting:
 *	if 'textwidth' option is set, use it
 *	else if 'wrapmargin' option is set, use curwin->w_width - 'wrapmargin'
 *	if invalid value, use 0.
 *	Set default to window width (maximum 79) for "gq" operator.
 */
int
comp_textwidth (
    int ff                 /* force formatting (for "gq" command) */
)
{
  int textwidth;

  textwidth = curbuf->b_p_tw;
  if (textwidth == 0 && curbuf->b_p_wm) {
    /* The width is the window width minus 'wrapmargin' minus all the
     * things that add to the margin. */
    textwidth = curwin->w_width - curbuf->b_p_wm;
    if (cmdwin_type != 0)
      textwidth -= 1;
    textwidth -= curwin->w_p_fdc;

    if (signcolumn_on(curwin)) {
        textwidth -= 1;
    }

    if (curwin->w_p_nu || curwin->w_p_rnu)
      textwidth -= 8;
  }
  if (textwidth < 0)
    textwidth = 0;
  if (ff && textwidth == 0) {
    textwidth = curwin->w_width - 1;
    if (textwidth > 79)
      textwidth = 79;
  }
  return textwidth;
}

/*
 * Put a character in the redo buffer, for when just after a CTRL-V.
 */
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

// start_arrow() is called when an arrow key is used in insert mode.
// For undo/redo it resembles hitting the <ESC> key.
static void start_arrow(pos_T *end_insert_pos /* can be NULL */)
{
  start_arrow_common(end_insert_pos, true);
}

/// Like start_arrow() but with end_change argument.
/// Will prepare for redo of CTRL-G U if "end_change" is FALSE.
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

/*
 * If we skipped highlighting word at cursor, do it now.
 * It may be skipped again, thus reset spell_redraw_lnum first.
 */
static void check_spell_redraw(void)
{
  if (spell_redraw_lnum != 0) {
    linenr_T lnum = spell_redraw_lnum;

    spell_redraw_lnum = 0;
    redrawWinline(curwin, lnum, false);
  }
}

/*
 * Called when starting CTRL_X_SPELL mode: Move backwards to a previous badly
 * spelled word, if there is one.
 */
static void spell_back_to_badword(void)
{
  pos_T tpos = curwin->w_cursor;
  spell_bad_len = spell_move_to(curwin, BACKWARD, TRUE, TRUE, NULL);
  if (curwin->w_cursor.col != tpos.col)
    start_arrow(&tpos);
}

/*
 * stop_arrow() is called before a change is made in insert mode.
 * If an arrow key has been used, start a new insertion.
 * Returns FAIL if undo is impossible, shouldn't insert then.
 */
int stop_arrow(void)
{
  if (arrow_used) {
    Insstart = curwin->w_cursor;  //new insertion starts here
    if (Insstart.col > Insstart_orig.col && !ins_need_undo) {
      // Don't update the original insert position when moved to the
      // right, except when nothing was inserted yet.
      update_Insstart_orig = FALSE;
    }
    Insstart_textlen = (colnr_T)linetabsize(get_cursor_line_ptr());

    if (u_save_cursor() == OK) {
      arrow_used = FALSE;
      ins_need_undo = FALSE;
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
    if (u_save_cursor() == OK)
      ins_need_undo = FALSE;
  }

  /* Always open fold at the cursor line when inserting something. */
  foldOpenCursor();

  return arrow_used || ins_need_undo ? FAIL : OK;
}

/*
 * Do a few things to stop inserting.
 * "end_insert_pos" is where insert ended.  It is NULL when we already jumped
 * to another window/buffer.
 */
static void
stop_insert (
    pos_T *end_insert_pos,
    int esc,                                /* called by ins_esc() */
    int nomove                             /* <c-\><c-o>, don't move cursor */
)
{
  int cc;
  char_u      *ptr;

  stop_redo_ins();
  replace_flush();              /* abandon replace stack */

  /*
   * Save the inserted text for later redo with ^@ and CTRL-A.
   * Don't do it when "restart_edit" was set and nothing was inserted,
   * otherwise CTRL-O w and then <Left> will clear "last_insert".
   */
  ptr = get_inserted();
  if (did_restart_edit == 0 || (ptr != NULL
                                && (int)STRLEN(ptr) > new_insert_skip)) {
    xfree(last_insert);
    last_insert = ptr;
    last_insert_skip = new_insert_skip;
  } else
    xfree(ptr);

  if (!arrow_used && end_insert_pos != NULL) {
    /* Auto-format now.  It may seem strange to do this when stopping an
     * insertion (or moving the cursor), but it's required when appending
     * a line and having it end in a space.  But only do it when something
     * was actually inserted, otherwise undo won't work. */
    if (!ins_need_undo && has_format_option(FO_AUTO)) {
      pos_T tpos = curwin->w_cursor;

      /* When the cursor is at the end of the line after a space the
       * formatting will move it to the following word.  Avoid that by
       * moving the cursor onto the space. */
      cc = 'x';
      if (curwin->w_cursor.col > 0 && gchar_cursor() == NUL) {
        dec_cursor();
        cc = gchar_cursor();
        if (!ascii_iswhite(cc))
          curwin->w_cursor = tpos;
      }

      auto_format(TRUE, FALSE);

      if (ascii_iswhite(cc)) {
        if (gchar_cursor() != NUL)
          inc_cursor();
        /* If the cursor is still at the same character, also keep
         * the "coladd". */
        if (gchar_cursor() == NUL
            && curwin->w_cursor.lnum == tpos.lnum
            && curwin->w_cursor.col == tpos.col)
          curwin->w_cursor.coladd = tpos.coladd;
      }
    }

    // If a space was inserted for auto-formatting, remove it now.
    check_auto_format(true);

    /* If we just did an auto-indent, remove the white space from the end
     * of the line, and put the cursor back.
     * Do this when ESC was used or moving the cursor up/down.
     * Check for the old position still being valid, just in case the text
     * got changed unexpectedly. */
    if (!nomove && did_ai && (esc || (vim_strchr(p_cpo, CPO_INDENT) == NULL
                                      && curwin->w_cursor.lnum !=
                                      end_insert_pos->lnum))
        && end_insert_pos->lnum <= curbuf->b_ml.ml_line_count) {
      pos_T tpos = curwin->w_cursor;

      curwin->w_cursor = *end_insert_pos;
      check_cursor_col();        /* make sure it is not past the line */
      for (;; ) {
        if (gchar_cursor() == NUL && curwin->w_cursor.col > 0)
          --curwin->w_cursor.col;
        cc = gchar_cursor();
        if (!ascii_iswhite(cc)) {
          break;
        }
        if (del_char(true) == FAIL) {
          break;            // should not happen
        }
      }
      if (curwin->w_cursor.lnum != tpos.lnum)
        curwin->w_cursor = tpos;
      else {
        /* reset tpos, could have been invalidated in the loop above */
        tpos = curwin->w_cursor;
        tpos.col++;
        if (cc != NUL && gchar_pos(&tpos) == NUL) {
          ++curwin->w_cursor.col;         // put cursor back on the NUL
        }
      }

      /* <C-S-Right> may have started Visual mode, adjust the position for
       * deleted characters. */
      if (VIsual_active && VIsual.lnum == curwin->w_cursor.lnum) {
        int len = (int)STRLEN(get_cursor_line_ptr());

        if (VIsual.col > len) {
          VIsual.col = len;
          VIsual.coladd = 0;
        }
      }
    }
  }
  did_ai = false;
  did_si = false;
  can_si = false;
  can_si_back = false;

  /* Set '[ and '] to the inserted text.  When end_insert_pos is NULL we are
   * now in a different buffer. */
  if (end_insert_pos != NULL) {
    curbuf->b_op_start = Insstart;
    curbuf->b_op_start_orig = Insstart_orig;
    curbuf->b_op_end = *end_insert_pos;
  }
}

/*
 * Set the last inserted text to a single character.
 * Used for the replace command.
 */
void set_last_insert(int c)
{
  char_u      *s;

  xfree(last_insert);
  last_insert = xmalloc(MB_MAXBYTES * 3 + 5);
  s = last_insert;
  /* Use the CTRL-V only when entering a special char */
  if (c < ' ' || c == DEL)
    *s++ = Ctrl_V;
  s = add_char2buf(c, s);
  *s++ = ESC;
  *s++ = NUL;
  last_insert_skip = 0;
}

#if defined(EXITFREE)
void free_last_insert(void)
{
  xfree(last_insert);
  last_insert = NULL;
  xfree(compl_orig_text);
  compl_orig_text = NULL;
}

#endif

/// Add character "c" to buffer "s"
///
/// Escapes the special meaning of K_SPECIAL and CSI, handles multi-byte
/// characters.
///
/// @param[in]  c  Character to add.
/// @param[out]  s  Buffer to add to. Must have at least MB_MAXBYTES + 1 bytes.
///
/// @return Pointer to after the added bytes.
char_u *add_char2buf(int c, char_u *s)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  char_u temp[MB_MAXBYTES + 1];
  const int len = utf_char2bytes(c, temp);
  for (int i = 0; i < len; i++) {
    c = temp[i];
    // Need to escape K_SPECIAL and CSI like in the typeahead buffer.
    if (c == K_SPECIAL) {
      *s++ = K_SPECIAL;
      *s++ = KS_SPECIAL;
      *s++ = KE_FILLER;
    } else {
      *s++ = c;
    }
  }
  return s;
}

/*
 * move cursor to start of line
 * if flags & BL_WHITE	move to first non-white
 * if flags & BL_SOL	move to first non-white if startofline is set,
 *			    otherwise keep "curswant" column
 * if flags & BL_FIX	don't leave the cursor on a NUL.
 */
void beginline(int flags)
{
  if ((flags & BL_SOL) && !p_sol)
    coladvance(curwin->w_curswant);
  else {
    curwin->w_cursor.col = 0;
    curwin->w_cursor.coladd = 0;

    if (flags & (BL_WHITE | BL_SOL)) {
      char_u  *ptr;

      for (ptr = get_cursor_line_ptr(); ascii_iswhite(*ptr)
           && !((flags & BL_FIX) && ptr[1] == NUL); ++ptr)
        ++curwin->w_cursor.col;
    }
    curwin->w_set_curswant = TRUE;
  }
}

/*
 * oneright oneleft cursor_down cursor_up
 *
 * Move one char {right,left,down,up}.
 * Doesn't move onto the NUL past the end of the line, unless it is allowed.
 * Return OK when successful, FAIL when we hit a line of file boundary.
 */

int oneright(void)
{
  char_u      *ptr;
  int l;

  if (virtual_active()) {
    pos_T prevpos = curwin->w_cursor;

    /* Adjust for multi-wide char (excluding TAB) */
    ptr = get_cursor_pos_ptr();
    coladvance(getviscol() + ((*ptr != TAB && vim_isprintc(utf_ptr2char(ptr))) ?
                              ptr2cells(ptr) : 1));
    curwin->w_set_curswant = true;
    // Return OK if the cursor moved, FAIL otherwise (at window edge).
    return (prevpos.col != curwin->w_cursor.col
            || prevpos.coladd != curwin->w_cursor.coladd) ? OK : FAIL;
  }

  ptr = get_cursor_pos_ptr();
  if (*ptr == NUL)
    return FAIL;            /* already at the very end */

  if (has_mbyte)
    l = (*mb_ptr2len)(ptr);
  else
    l = 1;

  /* move "l" bytes right, but don't end up on the NUL, unless 'virtualedit'
   * contains "onemore". */
  if (ptr[l] == NUL
      && (ve_flags & VE_ONEMORE) == 0
      )
    return FAIL;
  curwin->w_cursor.col += l;

  curwin->w_set_curswant = TRUE;
  return OK;
}

int oneleft(void)
{
  if (virtual_active()) {
    int width;
    int v = getviscol();

    if (v == 0)
      return FAIL;

    /* We might get stuck on 'showbreak', skip over it. */
    width = 1;
    for (;; ) {
      coladvance(v - width);
      /* getviscol() is slow, skip it when 'showbreak' is empty,
         'breakindent' is not set and there are no multi-byte
         characters */
      if ((*p_sbr == NUL
           && !curwin->w_p_bri
           && !has_mbyte
           ) || getviscol() < v)
        break;
      ++width;
    }

    if (curwin->w_cursor.coladd == 1) {
      char_u *ptr;

      /* Adjust for multi-wide char (not a TAB) */
      ptr = get_cursor_pos_ptr();
      if (*ptr != TAB && vim_isprintc(utf_ptr2char(ptr))
          && ptr2cells(ptr) > 1) {
        curwin->w_cursor.coladd = 0;
      }
    }

    curwin->w_set_curswant = TRUE;
    return OK;
  }

  if (curwin->w_cursor.col == 0)
    return FAIL;

  curwin->w_set_curswant = TRUE;
  --curwin->w_cursor.col;

  /* if the character on the left of the current cursor is a multi-byte
   * character, move to its first byte */
  if (has_mbyte)
    mb_adjust_cursor();
  return OK;
}

int
cursor_up (
    long n,
    int upd_topline                    /* When TRUE: update topline */
)
{
  linenr_T lnum;

  if (n > 0) {
    lnum = curwin->w_cursor.lnum;

    // This fails if the cursor is already in the first line.
    if (lnum <= 1) {
      return FAIL;
    }
    if (n >= lnum)
      lnum = 1;
    else if (hasAnyFolding(curwin)) {
      /*
       * Count each sequence of folded lines as one logical line.
       */
      /* go to the start of the current fold */
      (void)hasFolding(lnum, &lnum, NULL);

      while (n--) {
        /* move up one line */
        --lnum;
        if (lnum <= 1)
          break;
        /* If we entered a fold, move to the beginning, unless in
         * Insert mode or when 'foldopen' contains "all": it will open
         * in a moment. */
        if (n > 0 || !((State & INSERT) || (fdo_flags & FDO_ALL)))
          (void)hasFolding(lnum, &lnum, NULL);
      }
      if (lnum < 1)
        lnum = 1;
    } else
      lnum -= n;
    curwin->w_cursor.lnum = lnum;
  }

  /* try to advance to the column we want to be at */
  coladvance(curwin->w_curswant);

  if (upd_topline)
    update_topline();           /* make sure curwin->w_topline is valid */

  return OK;
}

/*
 * Cursor down a number of logical lines.
 */
int
cursor_down (
    long n,
    int upd_topline                    /* When TRUE: update topline */
)
{
  linenr_T lnum;

  if (n > 0) {
    lnum = curwin->w_cursor.lnum;
    /* Move to last line of fold, will fail if it's the end-of-file. */
    (void)hasFolding(lnum, NULL, &lnum);

    // This fails if the cursor is already in the last line.
    if (lnum >= curbuf->b_ml.ml_line_count) {
      return FAIL;
    }
    if (lnum + n >= curbuf->b_ml.ml_line_count)
      lnum = curbuf->b_ml.ml_line_count;
    else if (hasAnyFolding(curwin)) {
      linenr_T last;

      /* count each sequence of folded lines as one logical line */
      while (n--) {
        if (hasFolding(lnum, NULL, &last))
          lnum = last + 1;
        else
          ++lnum;
        if (lnum >= curbuf->b_ml.ml_line_count)
          break;
      }
      if (lnum > curbuf->b_ml.ml_line_count)
        lnum = curbuf->b_ml.ml_line_count;
    } else
      lnum += n;
    curwin->w_cursor.lnum = lnum;
  }

  /* try to advance to the column we want to be at */
  coladvance(curwin->w_curswant);

  if (upd_topline)
    update_topline();           /* make sure curwin->w_topline is valid */

  return OK;
}

/*
 * Stuff the last inserted text in the read buffer.
 * Last_insert actually is a copy of the redo buffer, so we
 * first have to remove the command.
 */
int
stuff_inserted (
    int c,                  /* Command character to be inserted */
    long count,             /* Repeat this many times */
    int no_esc             /* Don't add an ESC at the end */
)
{
  char_u      *esc_ptr;
  char_u      *ptr;
  char_u      *last_ptr;
  char_u last = NUL;

  ptr = get_last_insert();
  if (ptr == NULL) {
    EMSG(_(e_noinstext));
    return FAIL;
  }

  /* may want to stuff the command character, to start Insert mode */
  if (c != NUL)
    stuffcharReadbuff(c);
  if ((esc_ptr = STRRCHR(ptr, ESC)) != NULL) {
    // remove the ESC.
    *esc_ptr = NUL;
  }

  /* when the last char is either "0" or "^" it will be quoted if no ESC
   * comes after it OR if it will inserted more than once and "ptr"
   * starts with ^D.	-- Acevedo
   */
  last_ptr = (esc_ptr ? esc_ptr : ptr + STRLEN(ptr)) - 1;
  if (last_ptr >= ptr && (*last_ptr == '0' || *last_ptr == '^')
      && (no_esc || (*ptr == Ctrl_D && count > 1))) {
    last = *last_ptr;
    *last_ptr = NUL;
  }

  do {
    stuffReadbuff((const char *)ptr);
    // A trailing "0" is inserted as "<C-V>048", "^" as "<C-V>^".
    if (last) {
      stuffReadbuff((last == '0'
                     ? "\026\060\064\070"
                     : "\026^"));
    }
  } while (--count > 0);

  if (last)
    *last_ptr = last;

  if (esc_ptr != NULL)
    *esc_ptr = ESC;         /* put the ESC back */

  /* may want to stuff a trailing ESC, to get out of Insert mode */
  if (!no_esc)
    stuffcharReadbuff(ESC);

  return OK;
}

char_u *get_last_insert(void)
{
  if (last_insert == NULL)
    return NULL;
  return last_insert + last_insert_skip;
}

/*
 * Get last inserted string, and remove trailing <Esc>.
 * Returns pointer to allocated memory (must be freed) or NULL.
 */
char_u *get_last_insert_save(void)
{
  char_u      *s;
  int len;

  if (last_insert == NULL)
    return NULL;
  s = vim_strsave(last_insert + last_insert_skip);
  len = (int)STRLEN(s);
  if (len > 0 && s[len - 1] == ESC)           /* remove trailing ESC */
    s[len - 1] = NUL;

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

/*
 * replace-stack functions
 *
 * When replacing characters, the replaced characters are remembered for each
 * new character.  This is used to re-insert the old text when backspacing.
 *
 * There is a NUL headed list of characters for each character that is
 * currently in the file after the insertion point.  When BS is used, one NUL
 * headed list is put back for the deleted character.
 *
 * For a newline, there are two NUL headed lists.  One contains the characters
 * that the NL replaced.  The extra one stores the characters after the cursor
 * that were deleted (always white space).
 */

static char_u   *replace_stack = NULL;
static ssize_t replace_stack_nr = 0;           /* next entry in replace stack */
static ssize_t replace_stack_len = 0;          /* max. number of entries */

/// Push character that is replaced onto the the replace stack.
///
/// replace_offset is normally 0, in which case replace_push will add a new
/// character at the end of the stack.  If replace_offset is not 0, that many
/// characters will be left on the stack above the newly inserted character.
///
/// @param c character that is replaced (NUL is none)
void replace_push(int c)
{
  if (replace_stack_nr < replace_offset) {  // nothing to do
    return;
  }

  if (replace_stack_len <= replace_stack_nr) {
    replace_stack_len += 50;
    replace_stack = xrealloc(replace_stack, replace_stack_len);
  }
  char_u *p = replace_stack + replace_stack_nr - replace_offset;
  if (replace_offset) {
    memmove(p + 1, p, replace_offset);
  }
  *p = (char_u)c;
  ++replace_stack_nr;
}

/*
 * Push a character onto the replace stack.  Handles a multi-byte character in
 * reverse byte order, so that the first byte is popped off first.
 * Return the number of bytes done (includes composing characters).
 */
int replace_push_mb(char_u *p)
{
  int l = (*mb_ptr2len)(p);
  int j;

  for (j = l - 1; j >= 0; --j)
    replace_push(p[j]);
  return l;
}

/// Pop one item from the replace stack.
///
/// @return -1 if stack is empty, replaced character or NUL otherwise
static int replace_pop(void)
{
  return (replace_stack_nr == 0) ? -1 : (int)replace_stack[--replace_stack_nr];
}

/*
 * Join the top two items on the replace stack.  This removes to "off"'th NUL
 * encountered.
 */
static void
replace_join (
    int off                /* offset for which NUL to remove */
)
{
  int i;

  for (i = replace_stack_nr; --i >= 0; )
    if (replace_stack[i] == NUL && off-- <= 0) {
      --replace_stack_nr;
      memmove(replace_stack + i, replace_stack + i + 1,
          (size_t)(replace_stack_nr - i));
      return;
    }
}

/*
 * Pop bytes from the replace stack until a NUL is found, and insert them
 * before the cursor.  Can only be used in REPLACE or VREPLACE mode.
 */
static void replace_pop_ins(void)
{
  int cc;
  int oldState = State;

  State = NORMAL;                       /* don't want REPLACE here */
  while ((cc = replace_pop()) > 0) {
    mb_replace_pop_ins(cc);
    dec_cursor();
  }
  State = oldState;
}

/*
 * Insert bytes popped from the replace stack. "cc" is the first byte.  If it
 * indicates a multi-byte char, pop the other bytes too.
 */
static void mb_replace_pop_ins(int cc)
{
  int n;
  char_u buf[MB_MAXBYTES + 1];
  int i;
  int c;

  if (has_mbyte && (n = MB_BYTE2LEN(cc)) > 1) {
    buf[0] = cc;
    for (i = 1; i < n; ++i)
      buf[i] = replace_pop();
    ins_bytes_len(buf, n);
  } else
    ins_char(cc);

  if (enc_utf8)
    /* Handle composing chars. */
    for (;; ) {
      c = replace_pop();
      if (c == -1)                  /* stack empty */
        break;
      if ((n = MB_BYTE2LEN(c)) == 1) {
        /* Not a multi-byte char, put it back. */
        replace_push(c);
        break;
      } else {
        buf[0] = c;
        assert(n > 1);
        for (i = 1; i < n; ++i)
          buf[i] = replace_pop();
        if (utf_iscomposing(utf_ptr2char(buf)))
          ins_bytes_len(buf, n);
        else {
          /* Not a composing char, put it back. */
          for (i = n - 1; i >= 0; --i)
            replace_push(buf[i]);
          break;
        }
      }
    }
}

/*
 * make the replace stack empty
 * (called when exiting replace mode)
 */
static void replace_flush(void)
{
  xfree(replace_stack);
  replace_stack = NULL;
  replace_stack_len = 0;
  replace_stack_nr = 0;
}

/*
 * Handle doing a BS for one character.
 * cc < 0: replace stack empty, just move cursor
 * cc == 0: character was inserted, delete it
 * cc > 0: character was replaced, put cc (first byte of original char) back
 * and check for more characters to be put back
 * When "limit_col" is >= 0, don't delete before this column.  Matters when
 * using composing characters, use del_char_after_col() instead of del_char().
 */
static void replace_do_bs(int limit_col)
{
  int cc;
  int orig_len = 0;
  int ins_len;
  int orig_vcols = 0;
  colnr_T start_vcol;
  char_u      *p;
  int i;
  int vcol;
  const int l_State = State;

  cc = replace_pop();
  if (cc > 0) {
    if (l_State & VREPLACE_FLAG) {
      /* Get the number of screen cells used by the character we are
       * going to delete. */
      getvcol(curwin, &curwin->w_cursor, NULL, &start_vcol, NULL);
      orig_vcols = chartabsize(get_cursor_pos_ptr(), start_vcol);
    }
    if (has_mbyte) {
      (void)del_char_after_col(limit_col);
      if (l_State & VREPLACE_FLAG)
        orig_len = (int)STRLEN(get_cursor_pos_ptr());
      replace_push(cc);
    } else {
      pchar_cursor(cc);
      if (l_State & VREPLACE_FLAG)
        orig_len = (int)STRLEN(get_cursor_pos_ptr()) - 1;
    }
    replace_pop_ins();

    if (l_State & VREPLACE_FLAG) {
      /* Get the number of screen cells used by the inserted characters */
      p = get_cursor_pos_ptr();
      ins_len = (int)STRLEN(p) - orig_len;
      vcol = start_vcol;
      for (i = 0; i < ins_len; ++i) {
        vcol += chartabsize(p + i, vcol);
        i += (*mb_ptr2len)(p) - 1;
      }
      vcol -= start_vcol;

      /* Delete spaces that were inserted after the cursor to keep the
       * text aligned. */
      curwin->w_cursor.col += ins_len;
      while (vcol > orig_vcols && gchar_cursor() == ' ') {
        del_char(false);
        orig_vcols++;
      }
      curwin->w_cursor.col -= ins_len;
    }

    /* mark the buffer as changed and prepare for displaying */
    changed_bytes(curwin->w_cursor.lnum, curwin->w_cursor.col);
  } else if (cc == 0)
    (void)del_char_after_col(limit_col);
}

/// Check that C-indenting is on.
static bool cindent_on(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return !p_paste && (curbuf->b_p_cin || *curbuf->b_p_inde != NUL);
}

/*
 * Re-indent the current line, based on the current contents of it and the
 * surrounding lines. Fixing the cursor position seems really easy -- I'm very
 * confused what all the part that handles Control-T is doing that I'm not.
 * "get_the_indent" should be get_c_indent, get_expr_indent or get_lisp_indent.
 */
void fixthisline(IndentGetter get_the_indent)
{
    int amount = get_the_indent();

    if (amount >= 0) {
        change_indent(INDENT_SET, amount, false, 0, true);
        if (linewhite(curwin->w_cursor.lnum)) {
            did_ai = true;  // delete the indent if the line stays empty
        }
    }
}

void fix_indent(void) {
  if (p_paste)
    return;
  if (curbuf->b_p_lisp && curbuf->b_p_ai)
    fixthisline(get_lisp_indent);
  else if (cindent_on())
    do_c_expr_indent();
}

/// Check that "cinkeys" contains the key "keytyped",
/// when == '*': Only if key is preceded with '*' (indent before insert)
/// when == '!': Only if key is preceded with '!' (don't insert)
/// when == ' ': Only if key is not preceded with '*' (indent afterwards)
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
  char_u *look;
  int try_match;
  int try_match_word;
  char_u *p;
  char_u *line;
  int icase;
  int i;

  if (keytyped == NUL) {
    // Can happen with CTRL-Y and CTRL-E on a short line.
    return false;
  }

  if (*curbuf->b_p_inde != NUL)
    look = curbuf->b_p_indk;            /* 'indentexpr' set: use 'indentkeys' */
  else
    look = curbuf->b_p_cink;            /* 'indentexpr' empty: use 'cinkeys' */
  while (*look) {
    /*
     * Find out if we want to try a match with this key, depending on
     * 'when' and a '*' or '!' before the key.
     */
    switch (when) {
    case '*': try_match = (*look == '*'); break;
    case '!': try_match = (*look == '!'); break;
    default: try_match = (*look != '*'); break;
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
      if (try_match && keytyped == Ctrl_chr(look[1])) {
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
            && STRNCMP(p + curwin->w_cursor.col - 4, "else", 4) == 0) {
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
          i = (cin_iscase(p, FALSE) || cin_isscopedecl(p)
               || cin_islabel());
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
        if (vim_strchr((char_u *)"<>!*oOe0:", look[1]) != NULL
            && keytyped == look[1]) {
          return true;
        }

        if (keytyped == get_special_key_code(look + 1)) {
          return true;
        }
      }
      while (*look && *look != '>')
        look++;
      while (*look == '>')
        look++;
    }
    /*
     * Is it a word: "=word"?
     */
    else if (*look == '=' && look[1] != ',' && look[1] != NUL) {
      ++look;
      if (*look == '~') {
        icase = TRUE;
        ++look;
      } else
        icase = FALSE;
      p = vim_strchr(look, ',');
      if (p == NULL)
        p = look + STRLEN(look);
      if ((try_match || try_match_word)
          && curwin->w_cursor.col >= (colnr_T)(p - look)) {
        bool match = false;

        if (keytyped == KEY_COMPLETE) {
          char_u      *s;

          /* Just completed a word, check if it starts with "look".
           * search back for the start of a word. */
          line = get_cursor_line_ptr();
          if (has_mbyte) {
            char_u  *n;

            for (s = line + curwin->w_cursor.col; s > line; s = n) {
              n = mb_prevptr(line, s);
              if (!vim_iswordp(n))
                break;
            }
          } else
            for (s = line + curwin->w_cursor.col; s > line; --s)
              if (!vim_iswordc(s[-1]))
                break;
          assert(p >= look && (uintmax_t)(p - look) <= SIZE_MAX);
          if (s + (p - look) <= line + curwin->w_cursor.col
              && (icase
                  ? mb_strnicmp(s, look, (size_t)(p - look))
                  : STRNCMP(s, look, p - look)) == 0)
            match = true;
        } else {
          // TODO(@brammool): multi-byte
          if (keytyped == (int)p[-1]
              || (icase && keytyped < 256
                  && TOLOWER_LOC(keytyped) == TOLOWER_LOC((int)p[-1]))) {
            line = get_cursor_pos_ptr();
            assert(p >= look && (uintmax_t)(p - look) <= SIZE_MAX);
            if ((curwin->w_cursor.col == (colnr_T)(p - look)
                 || !vim_iswordc(line[-(p - look) - 1]))
                && (icase
                    ? mb_strnicmp(line - (p - look), look, (size_t)(p - look))
                    : STRNCMP(line - (p - look), look, p - look)) == 0) {
              match = true;
            }
          }
        }
        if (match && try_match_word && !try_match) {
          /* "0=word": Check if there are only blanks before the
           * word. */
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
      if (try_match && *look == keytyped) {
        return true;
      }
      if (*look != NUL) {
        look++;
      }
    }

    /*
     * Skip over ", ".
     */
    look = skip_to_option_part(look);
  }
  return false;
}

/*
 * Map Hebrew keyboard when in hkmap mode.
 */
int hkmap(int c)
{
  if (p_hkmapp) {   /* phonetic mapping, by Ilya Dogolazky */
    enum {hALEF=0, BET, GIMEL, DALET, HEI, VAV, ZAIN, HET, TET, IUD,
          KAFsofit, hKAF, LAMED, MEMsofit, MEM, NUNsofit, NUN, SAMEH, AIN,
          PEIsofit, PEI, ZADIsofit, ZADI, KOF, RESH, hSHIN, TAV};
    static char_u map[26] =
    {(char_u)hALEF /*a*/, (char_u)BET /*b*/, (char_u)hKAF /*c*/,
     (char_u)DALET /*d*/, (char_u)-1 /*e*/, (char_u)PEIsofit /*f*/,
     (char_u)GIMEL /*g*/, (char_u)HEI /*h*/, (char_u)IUD /*i*/,
     (char_u)HET /*j*/, (char_u)KOF /*k*/, (char_u)LAMED /*l*/,
     (char_u)MEM /*m*/, (char_u)NUN /*n*/, (char_u)SAMEH /*o*/,
     (char_u)PEI /*p*/, (char_u)-1 /*q*/, (char_u)RESH /*r*/,
     (char_u)ZAIN /*s*/, (char_u)TAV /*t*/, (char_u)TET /*u*/,
     (char_u)VAV /*v*/, (char_u)hSHIN /*w*/, (char_u)-1 /*x*/,
     (char_u)AIN /*y*/, (char_u)ZADI /*z*/};

    if (c == 'N' || c == 'M' || c == 'P' || c == 'C' || c == 'Z')
      return (int)(map[CharOrd(c)] - 1 + p_aleph);
    /* '-1'='sofit' */
    else if (c == 'x')
      return 'X';
    else if (c == 'q')
      return '\'';       /* {geresh}={'} */
    else if (c == 246)
      return ' ';        /* \"o --> ' ' for a german keyboard */
    else if (c == 228)
      return ' ';        /* \"a --> ' '      -- / --	       */
    else if (c == 252)
      return ' ';        /* \"u --> ' '      -- / --	       */
    /* NOTE: islower() does not do the right thing for us on Linux so we
     * do this the same was as 5.7 and previous, so it works correctly on
     * all systems.  Specifically, the e.g. Delete and Arrow keys are
     * munged and won't work if e.g. searching for Hebrew text.
     */
    else if (c >= 'a' && c <= 'z')
      return (int)(map[CharOrdLow(c)] + p_aleph);
    else
      return c;
  } else {
    switch (c) {
    case '`':   return ';';
    case '/':   return '.';
    case '\'':  return ',';
    case 'q':   return '/';
    case 'w':   return '\'';

    /* Hebrew letters - set offset from 'a' */
    case ',':   c = '{'; break;
    case '.':   c = 'v'; break;
    case ';':   c = 't'; break;
    default: {
      static char str[] = "zqbcxlsjphmkwonu ydafe rig";

      if (c < 'a' || c > 'z')
        return c;
      c = str[CharOrdLow(c)];
      break;
    }
    }

    return (int)(CharOrdLow(c) + p_aleph);
  }
}

static void ins_reg(void)
{
  int need_redraw = FALSE;
  int regname;
  int literally = 0;
  int vis_active = VIsual_active;

  /*
   * If we are going to wait for a character, show a '"'.
   */
  pc_status = PC_STATUS_UNSET;
  if (redrawing() && !char_avail()) {
    /* may need to redraw when no more chars available now */
    ins_redraw(FALSE);

    edit_putchar('"', TRUE);
    add_to_showcmd_c(Ctrl_R);
  }


  /*
   * Don't map the register name. This also prevents the mode message to be
   * deleted when ESC is hit.
   */
  ++no_mapping;
  regname = plain_vgetc();
  LANGMAP_ADJUST(regname, TRUE);
  if (regname == Ctrl_R || regname == Ctrl_O || regname == Ctrl_P) {
    /* Get a third key for literal register insertion */
    literally = regname;
    add_to_showcmd_c(literally);
    regname = plain_vgetc();
    LANGMAP_ADJUST(regname, TRUE);
  }
  --no_mapping;

  /* Don't call u_sync() while typing the expression or giving an error
   * message for it. Only call it explicitly. */
  ++no_u_sync;
  if (regname == '=') {
    /* Sync undo when evaluating the expression calls setline() or
     * append(), so that it can be undone separately. */
    u_sync_once = 2;

    regname = get_expr_register();
  }
  if (regname == NUL || !valid_yank_reg(regname, false)) {
    vim_beep(BO_REG);
    need_redraw = true;  // remove the '"'
  } else {
    if (literally == Ctrl_O || literally == Ctrl_P) {
      /* Append the command to the redo buffer. */
      AppendCharToRedobuff(Ctrl_R);
      AppendCharToRedobuff(literally);
      AppendCharToRedobuff(regname);

      do_put(regname, NULL, BACKWARD, 1,
             (literally == Ctrl_P ? PUT_FIXINDENT : 0) | PUT_CURSEND);
    } else if (insert_reg(regname, literally) == FAIL) {
      vim_beep(BO_REG);
      need_redraw = true;  // remove the '"'
    } else if (stop_insert_mode) {
      // When the '=' register was used and a function was invoked that
      // did ":stopinsert" then stuff_empty() returns FALSE but we won't
      // insert anything, need to remove the '"'
      need_redraw = true;
    }
  }
  --no_u_sync;
  if (u_sync_once == 1)
    ins_need_undo = TRUE;
  u_sync_once = 0;
  clear_showcmd();

  /* If the inserted register is empty, we need to remove the '"' */
  if (need_redraw || stuff_empty())
    edit_unputchar();

  /* Disallow starting Visual mode here, would get a weird mode. */
  if (!vis_active && VIsual_active)
    end_visual_mode();
}

/*
 * CTRL-G commands in Insert mode.
 */
static void ins_ctrl_g(void)
{
  int c;

  /* Right after CTRL-X the cursor will be after the ruler. */
  setcursor();

  /*
   * Don't map the second key. This also prevents the mode message to be
   * deleted when ESC is hit.
   */
  ++no_mapping;
  c = plain_vgetc();
  --no_mapping;
  switch (c) {
  /* CTRL-G k and CTRL-G <Up>: cursor up to Insstart.col */
  case K_UP:
  case Ctrl_K:
  case 'k': ins_up(TRUE);
    break;

  /* CTRL-G j and CTRL-G <Down>: cursor down to Insstart.col */
  case K_DOWN:
  case Ctrl_J:
  case 'j': ins_down(TRUE);
    break;

  /* CTRL-G u: start new undoable edit */
  case 'u': u_sync(TRUE);
    ins_need_undo = TRUE;

    /* Need to reset Insstart, esp. because a BS that joins
     * a line to the previous one must save for undo. */
    update_Insstart_orig = false;
    Insstart = curwin->w_cursor;
    break;

  // CTRL-G U: do not break undo with the next char.
  case 'U':
    // Allow one left/right cursor movement with the next char,
    // without breaking undo.
    dont_sync_undo = kNone;
    break;

  /* Unknown CTRL-G command, reserved for future expansion. */
  default: vim_beep(BO_CTRLG);
  }
}

/*
 * CTRL-^ in Insert mode.
 */
static void ins_ctrl_hat(void)
{
  if (map_to_exists_mode("", LANGMAP, false)) {
    // ":lmap" mappings exists, Toggle use of ":lmap" mappings.
    if (State & LANGMAP) {
      curbuf->b_p_iminsert = B_IMODE_NONE;
      State &= ~LANGMAP;
    } else {
      curbuf->b_p_iminsert = B_IMODE_LMAP;
      State |= LANGMAP;
    }
  }
  set_iminsert_global();
  showmode();
  /* Show/unshow value of 'keymap' in status lines. */
  status_redraw_curbuf();
}

/// Handle ESC in insert mode.
///
/// @param[in,out]  count    repeat count of the insert command
/// @param          cmdchar  command that started the insert
/// @param          nomove   when true, don't move the cursor
///
/// @return true when leaving insert mode, false when repeating the insert.
static bool ins_esc(long *count, int cmdchar, bool nomove)
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
    // When 'insertmode' is set only CTRL-L stops Insert mode.  Needed for
    // when "count" is non-zero.
    if (cmdchar != 'r' && cmdchar != 'v') {
      AppendToRedobuff(p_im ? "\014" : ESC_STR);
    }

    /*
     * Repeating insert may take a long time.  Check for
     * interrupt now and then.
     */
    if (*count > 0) {
      line_breakcheck();
      if (got_int)
        *count = 0;
    }

    if (--*count > 0) {         /* repeat what was typed */
      /* Vi repeats the insert without replacing characters. */
      if (vim_strchr(p_cpo, CPO_REPLCNT) != NULL)
        State &= ~REPLACE_FLAG;

      (void)start_redo_ins();
      if (cmdchar == 'r' || cmdchar == 'v') {
        stuffRedoReadbuff(ESC_STR);  // No ESC in redo buffer
      }
      RedrawingDisabled++;
      disabled_redraw = true;
      // Repeat the insert
      return false;
    }
    stop_insert(&curwin->w_cursor, TRUE, nomove);
    undisplay_dollar();
  }

  /* When an autoindent was removed, curswant stays after the
   * indent */
  if (restart_edit == NUL && (colnr_T)temp == curwin->w_cursor.col)
    curwin->w_set_curswant = TRUE;

  /* Remember the last Insert position in the '^ mark. */
  if (!cmdmod.keepjumps) {
    RESET_FMARK(&curbuf->b_last_insert, curwin->w_cursor, curbuf->b_fnum);
  }

  /*
   * The cursor should end up on the last inserted character.
   * Don't do it for CTRL-O, unless past the end of the line.
   */
  if (!nomove
      && (curwin->w_cursor.col != 0
          || curwin->w_cursor.coladd > 0
          )
      && (restart_edit == NUL
          || (gchar_cursor() == NUL
              && !VIsual_active
              ))
      && !revins_on
      ) {
    if (curwin->w_cursor.coladd > 0 || ve_flags == VE_ALL) {
      oneleft();
      if (restart_edit != NUL)
        ++curwin->w_cursor.coladd;
    } else {
      --curwin->w_cursor.col;
      /* Correct cursor for multi-byte character. */
      if (has_mbyte)
        mb_adjust_cursor();
    }
  }


  State = NORMAL;
  /* need to position cursor again (e.g. when on a TAB ) */
  changed_cline_bef_curs();

  setmouse();
  ui_cursor_shape();            /* may show different cursor shape */

  // When recording or for CTRL-O, need to display the new mode.
  // Otherwise remove the mode message.
  if (Recording || restart_edit != NUL) {
    showmode();
  } else if (p_smd) {
    MSG("");
  }
  // Exit Insert mode
  return true;
}

/*
 * Toggle language: hkmap and revins_on.
 * Move to end of reverse inserted text.
 */
static void ins_ctrl_(void)
{
  if (revins_on && revins_chars && revins_scol >= 0) {
    while (gchar_cursor() != NUL && revins_chars--)
      ++curwin->w_cursor.col;
  }
  p_ri = !p_ri;
  revins_on = (State == INSERT && p_ri);
  if (revins_on) {
    revins_scol = curwin->w_cursor.col;
    revins_legal++;
    revins_chars = 0;
    undisplay_dollar();
  } else
    revins_scol = -1;
  if (p_altkeymap) {
    /*
     * to be consistent also for redo command, using '.'
     * set arrow_used to true and stop it - causing to redo
     * characters entered in one mode (normal/reverse insert).
     */
    arrow_used = TRUE;
    (void)stop_arrow();
    p_fkmap = curwin->w_p_rl ^ p_ri;
    if (p_fkmap && p_ri)
      State = INSERT;
  } else
    p_hkmap = curwin->w_p_rl ^ p_ri;        /* be consistent! */
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
    if (!(mod_mask & MOD_MASK_SHIFT))
      break;
    FALLTHROUGH;
  case K_S_LEFT:
  case K_S_RIGHT:
  case K_S_UP:
  case K_S_DOWN:
  case K_S_END:
  case K_S_HOME:
    // Start selection right away, the cursor can move with
    // CTRL-O when beyond the end of the line.
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

/*
 * <Insert> key in Insert mode: toggle insert/replace mode.
 */
static void ins_insert(int replaceState)
{
  if (p_fkmap && p_ri) {
    beep_flush();
    EMSG(farsi_text_3);         /* encoded in Farsi */
    return;
  }

  set_vim_var_string(VV_INSERTMODE, ((State & REPLACE_FLAG) ? "i" :
                                     replaceState == VREPLACE ? "v" :
                                     "r"), 1);
  ins_apply_autocmds(EVENT_INSERTCHANGE);
  if (State & REPLACE_FLAG) {
    State = INSERT | (State & LANGMAP);
  } else {
    State = replaceState | (State & LANGMAP);
  }
  AppendCharToRedobuff(K_INS);
  showmode();
  ui_cursor_shape();            /* may show different cursor shape */
}

/*
 * Pressed CTRL-O in Insert mode.
 */
static void ins_ctrl_o(void)
{
  if (State & VREPLACE_FLAG)
    restart_edit = 'V';
  else if (State & REPLACE_FLAG)
    restart_edit = 'R';
  else
    restart_edit = 'I';
  if (virtual_active())
    ins_at_eol = FALSE;         /* cursor always keeps its column */
  else
    ins_at_eol = (gchar_cursor() == NUL);
}

/*
 * If the cursor is on an indent, ^T/^D insert/delete one
 * shiftwidth.	Otherwise ^T/^D behave like a "<<" or ">>".
 * Always round the indent to 'shiftwidth', this is compatible
 * with vi.  But vi only supports ^T and ^D after an
 * autoindent, we support it everywhere.
 */
static void ins_shift(int c, int lastc)
{
  if (stop_arrow() == FAIL)
    return;
  AppendCharToRedobuff(c);

  /*
   * 0^D and ^^D: remove all indent.
   */
  if (c == Ctrl_D && (lastc == '0' || lastc == '^')
      && curwin->w_cursor.col > 0) {
    curwin->w_cursor.col--;
    (void)del_char(false);              // delete the '^' or '0'
    // In Replace mode, restore the characters that '^' or '0' replaced.
    if (State & REPLACE_FLAG) {
      replace_pop_ins();
    }
    if (lastc == '^') {
      old_indent = get_indent();        // remember curr. indent
    }
    change_indent(INDENT_SET, 0, TRUE, 0, TRUE);
  } else
    change_indent(c == Ctrl_D ? INDENT_DEC : INDENT_INC, 0, TRUE, 0, TRUE);

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
      vim_beep(BO_BS);
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
    vim_beep(BO_BS);
  }
  did_ai = false;
  did_si = false;
  can_si = false;
  can_si_back = false;
  AppendCharToRedobuff(K_DEL);
}


/*
 * Delete one character for ins_bs().
 */
static void ins_bs_one(colnr_T *vcolp)
{
  dec_cursor();
  getvcol(curwin, &curwin->w_cursor, vcolp, NULL, NULL);
  if (State & REPLACE_FLAG) {
    /* Don't delete characters before the insert point when in
     * Replace mode */
    if (curwin->w_cursor.lnum != Insstart.lnum
        || curwin->w_cursor.col >= Insstart.col)
      replace_do_bs(-1);
  } else {
    (void)del_char(false);
  }
}

/// Handle Backspace, delete-word and delete-line in Insert mode.
///
/// @param          c                 charcter that was typed
/// @param          mode              backspace mode to use
/// @param[in,out]  inserted_space_p  whether a space was the last
//                                    character inserted
///
/// @return true when backspace was actually used.
static bool ins_bs(int c, int mode, int *inserted_space_p)
  FUNC_ATTR_NONNULL_ARG(3)
{
  linenr_T lnum;
  int cc;
  int temp = 0;                     /* init for GCC */
  colnr_T save_col;
  colnr_T mincol;
  bool did_backspace = false;
  int in_indent;
  int oldState;
  int cpc[MAX_MCO];                 /* composing characters */

  // can't delete anything in an empty file
  // can't backup past first character in buffer
  // can't backup past starting point unless 'backspace' > 1
  // can backup to a previous line if 'backspace' == 0
  if (BUFEMPTY()
      || (!revins_on
          && ((curwin->w_cursor.lnum == 1 && curwin->w_cursor.col == 0)
              || (!can_bs(BS_START)
                  && (arrow_used
                      || (curwin->w_cursor.lnum == Insstart_orig.lnum
                          && curwin->w_cursor.col <= Insstart_orig.col)))
              || (!can_bs(BS_INDENT) && !arrow_used && ai_col > 0
                  && curwin->w_cursor.col <= ai_col)
              || (!can_bs(BS_EOL) && curwin->w_cursor.col == 0)))) {
    vim_beep(BO_BS);
    return false;
  }

  if (stop_arrow() == FAIL) {
    return false;
  }
  in_indent = inindent(0);
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
    lnum = Insstart.lnum;
    if (curwin->w_cursor.lnum == lnum || revins_on) {
      if (u_save((linenr_T)(curwin->w_cursor.lnum - 2),
                 (linenr_T)(curwin->w_cursor.lnum + 1)) == FAIL) {
        return false;
      }
      Insstart.lnum--;
      Insstart.col = (colnr_T)STRLEN(ml_get(Insstart.lnum));
    }
    /*
     * In replace mode:
     * cc < 0: NL was inserted, delete it
     * cc >= 0: NL was replaced, put original characters back
     */
    cc = -1;
    if (State & REPLACE_FLAG)
      cc = replace_pop();           /* returns -1 if NL was inserted */
    /*
     * In replace mode, in the line we started replacing, we only move the
     * cursor.
     */
    if ((State & REPLACE_FLAG) && curwin->w_cursor.lnum <= lnum) {
      dec_cursor();
    } else {
      if (!(State & VREPLACE_FLAG)
          || curwin->w_cursor.lnum > orig_line_count) {
        temp = gchar_cursor();          /* remember current char */
        --curwin->w_cursor.lnum;

        /* When "aw" is in 'formatoptions' we must delete the space at
         * the end of the line, otherwise the line will be broken
         * again when auto-formatting. */
        if (has_format_option(FO_AUTO)
            && has_format_option(FO_WHITE_PAR)) {
          char_u  *ptr = ml_get_buf(curbuf, curwin->w_cursor.lnum,
              TRUE);
          int len;

          len = (int)STRLEN(ptr);
          if (len > 0 && ptr[len - 1] == ' ')
            ptr[len - 1] = NUL;
        }

        do_join(2, FALSE, FALSE, FALSE, false);
        if (temp == NUL && gchar_cursor() != NUL)
          inc_cursor();
      } else
        dec_cursor();

      /*
       * In REPLACE mode we have to put back the text that was replaced
       * by the NL. On the replace stack is first a NUL-terminated
       * sequence of characters that were deleted and then the
       * characters that NL replaced.
       */
      if (State & REPLACE_FLAG) {
        /*
         * Do the next ins_char() in NORMAL state, to
         * prevent ins_char() from replacing characters and
         * avoiding showmatch().
         */
        oldState = State;
        State = NORMAL;
        /*
         * restore characters (blanks) deleted after cursor
         */
        while (cc > 0) {
          save_col = curwin->w_cursor.col;
          mb_replace_pop_ins(cc);
          curwin->w_cursor.col = save_col;
          cc = replace_pop();
        }
        /* restore the characters that NL replaced */
        replace_pop_ins();
        State = oldState;
      }
    }
    did_ai = false;
  } else {
    /*
     * Delete character(s) before the cursor.
     */
    if (revins_on)              /* put cursor on last inserted char */
      dec_cursor();
    mincol = 0;
    /* keep indent */
    if (mode == BACKSPACE_LINE
        && (curbuf->b_p_ai
            || cindent_on()
            )
        && !revins_on
        ) {
      save_col = curwin->w_cursor.col;
      beginline(BL_WHITE);
      if (curwin->w_cursor.col < save_col)
        mincol = curwin->w_cursor.col;
      curwin->w_cursor.col = save_col;
    }

    /*
     * Handle deleting one 'shiftwidth' or 'softtabstop'.
     */
    if (       mode == BACKSPACE_CHAR
               && ((p_sta && in_indent)
                   || (get_sts_value() != 0
                       && curwin->w_cursor.col > 0
                       && (*(get_cursor_pos_ptr() - 1) == TAB
                           || (*(get_cursor_pos_ptr() - 1) == ' '
                               && (!*inserted_space_p
                                   || arrow_used)))))) {
      int ts;
      colnr_T vcol;
      colnr_T want_vcol;
      colnr_T start_vcol;

      *inserted_space_p = FALSE;
      if (p_sta && in_indent)
        ts = get_sw_value(curbuf);
      else
        ts = get_sts_value();
      /* Compute the virtual column where we want to be.  Since
       * 'showbreak' may get in the way, need to get the last column of
       * the previous character. */
      getvcol(curwin, &curwin->w_cursor, &vcol, NULL, NULL);
      start_vcol = vcol;
      dec_cursor();
      getvcol(curwin, &curwin->w_cursor, NULL, NULL, &want_vcol);
      inc_cursor();
      want_vcol = (want_vcol / ts) * ts;

      /* delete characters until we are at or before want_vcol */
      while (vcol > want_vcol
             && (cc = *(get_cursor_pos_ptr() - 1), ascii_iswhite(cc)))
        ins_bs_one(&vcol);

      /* insert extra spaces until we are at want_vcol */
      while (vcol < want_vcol) {
        /* Remember the first char we inserted */
        if (curwin->w_cursor.lnum == Insstart_orig.lnum
            && curwin->w_cursor.col < Insstart_orig.col) {
          Insstart_orig.col = curwin->w_cursor.col;
        }

        if (State & VREPLACE_FLAG)
          ins_char(' ');
        else {
          ins_str((char_u *)" ");
          if ((State & REPLACE_FLAG))
            replace_push(NUL);
        }
        getvcol(curwin, &curwin->w_cursor, &vcol, NULL, NULL);
      }

      /* If we are now back where we started delete one character.  Can
       * happen when using 'sts' and 'linebreak'. */
      if (vcol >= start_vcol)
        ins_bs_one(&vcol);

    // Delete upto starting point, start of line or previous word.
    } else {
      int cclass = 0, prev_cclass = 0;

      if (has_mbyte) {
        cclass = mb_get_class(get_cursor_pos_ptr());
      }
      do {
        if (!revins_on) {   // put cursor on char to be deleted
          dec_cursor();
        }
        cc = gchar_cursor();
        // look multi-byte character class
        if (has_mbyte) {
          prev_cclass = cclass;
          cclass = mb_get_class(get_cursor_pos_ptr());
        }
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
        if (State & REPLACE_FLAG)
          replace_do_bs(-1);
        else {
          const bool l_enc_utf8 = enc_utf8;
          const int l_p_deco = p_deco;
          if (l_enc_utf8 && l_p_deco) {
            (void)utfc_ptr2char(get_cursor_pos_ptr(), cpc);
          }
          (void)del_char(false);
          // If there are combining characters and 'delcombine' is set
          // move the cursor back.  Don't back up before the base
          // character.
          if (l_enc_utf8 && l_p_deco && cpc[0] != NUL) {
            inc_cursor();
          }
          if (revins_chars) {
            revins_chars--;
            revins_legal++;
          }
          if (revins_on && gchar_cursor() == NUL)
            break;
        }
        // Just a single backspace?:
        if (mode == BACKSPACE_CHAR) {
          break;
        }
      } while (revins_on
               || (curwin->w_cursor.col > mincol
                   && (curwin->w_cursor.lnum != Insstart_orig.lnum
                       || curwin->w_cursor.col != Insstart_orig.col)));
    }
    did_backspace = true;
  }
  did_si = false;
  can_si = false;
  can_si_back = false;
  if (curwin->w_cursor.col <= 1) {
    did_ai = false;
  }
  // It's a little strange to put backspaces into the redo
  // buffer, but it makes auto-indent a lot easier to deal
  // with.
  AppendCharToRedobuff(c);

  /* If deleted before the insertion point, adjust it */
  if (curwin->w_cursor.lnum == Insstart_orig.lnum
      && curwin->w_cursor.col < Insstart_orig.col) {
    Insstart_orig.col = curwin->w_cursor.col;
  }

  /* vi behaviour: the cursor moves backward but the character that
   *		     was there remains visible
   * Vim behaviour: the cursor moves backward and the character that
   *		      was there is erased from the screen.
   * We can emulate the vi behaviour by pretending there is a dollar
   * displayed even when there isn't.
   *  --pkv Sun Jan 19 01:56:40 EST 2003 */
  if (vim_strchr(p_cpo, CPO_BACKSPACE) != NULL && dollar_vcol == -1)
    dollar_vcol = curwin->w_virtcol;

  // When deleting a char the cursor line must never be in a closed fold.
  // E.g., when 'foldmethod' is indent and deleting the first non-white
  // char before a Tab.
  if (did_backspace) {
    foldOpenCursor();
  }
  return did_backspace;
}

static void ins_mouse(int c)
{
  pos_T tpos;
  win_T       *old_curwin = curwin;

  if (!mouse_has(MOUSE_INSERT))
    return;

  undisplay_dollar();
  tpos = curwin->w_cursor;
  if (do_mouse(NULL, c, BACKWARD, 1, 0)) {
    win_T   *new_curwin = curwin;

    if (curwin != old_curwin && win_valid(old_curwin)) {
      /* Mouse took us to another window.  We need to go back to the
       * previous one to stop insert there properly. */
      curwin = old_curwin;
      curbuf = curwin->w_buffer;
    }
    start_arrow(curwin == old_curwin ? &tpos : NULL);
    if (curwin != new_curwin && win_valid(new_curwin)) {
      curwin = new_curwin;
      curbuf = curwin->w_buffer;
    }
    can_cindent = true;
  }

  /* redraw status lines (in case another window became active) */
  redraw_statuslines();
}

static void ins_mousescroll(int dir)
{
  win_T *const old_curwin = curwin;
  bool did_scroll = false;
  pos_T tpos = curwin->w_cursor;

  if (mouse_row >= 0 && mouse_col >= 0) {
    int row = mouse_row;
    int col = mouse_col;

    // find the window at the pointer coordinates
    win_T *const wp = mouse_find_win(&row, &col);
    if (wp == NULL) {
      return;
    }
    curwin = wp;
    curbuf = curwin->w_buffer;
  }
  if (curwin == old_curwin)
    undisplay_dollar();

  /* Don't scroll the window in which completion is being done. */
  if (!pum_visible()
      || curwin != old_curwin
      ) {
    if (dir == MSCR_DOWN || dir == MSCR_UP) {
      if (mod_mask & (MOD_MASK_SHIFT | MOD_MASK_CTRL))
        scroll_redraw(dir,
            (long)(curwin->w_botline - curwin->w_topline));
      else
        scroll_redraw(dir, 3L);
    } else {
        mouse_scroll_horiz(dir);
    }
    did_scroll = true;
  }

  curwin->w_redr_status = TRUE;

  curwin = old_curwin;
  curbuf = curwin->w_buffer;

  /* The popup menu may overlay the window, need to redraw it.
   * TODO: Would be more efficient to only redraw the windows that are
   * overlapped by the popup menu. */
  if (pum_visible() && did_scroll) {
    redraw_all_later(NOT_VALID);
    ins_compl_show_pum();
  }

  if (!equalpos(curwin->w_cursor, tpos)) {
    start_arrow(&tpos);
    can_cindent = true;
  }
}



static void ins_left(bool end_change)
{
  pos_T tpos;

  if ((fdo_flags & FDO_HOR) && KeyTyped)
    foldOpenCursor();
  undisplay_dollar();
  tpos = curwin->w_cursor;
  if (oneleft() == OK) {
    start_arrow_with_change(&tpos, end_change);
    if (!end_change) {
      AppendCharToRedobuff(K_LEFT);
    }
    /* If exit reversed string, position is fixed */
    if (revins_scol != -1 && (int)curwin->w_cursor.col >= revins_scol)
      revins_legal++;
    revins_chars++;
  } else if (vim_strchr(p_ww, '[') != NULL && curwin->w_cursor.lnum > 1) {
    // if 'whichwrap' set for cursor in insert mode may go to previous line.
    // always break undo when moving upwards/downwards, else undo may break
    start_arrow(&tpos);
    --(curwin->w_cursor.lnum);
    coladvance((colnr_T)MAXCOL);
    curwin->w_set_curswant = true;  // so we stay at the end
  } else {
    vim_beep(BO_CRSR);
  }
  dont_sync_undo = kFalse;
}

static void ins_home(int c)
{
  pos_T tpos;

  if ((fdo_flags & FDO_HOR) && KeyTyped)
    foldOpenCursor();
  undisplay_dollar();
  tpos = curwin->w_cursor;
  if (c == K_C_HOME)
    curwin->w_cursor.lnum = 1;
  curwin->w_cursor.col = 0;
  curwin->w_cursor.coladd = 0;
  curwin->w_curswant = 0;
  start_arrow(&tpos);
}

static void ins_end(int c)
{
  pos_T tpos;

  if ((fdo_flags & FDO_HOR) && KeyTyped)
    foldOpenCursor();
  undisplay_dollar();
  tpos = curwin->w_cursor;
  if (c == K_C_END)
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
  coladvance((colnr_T)MAXCOL);
  curwin->w_curswant = MAXCOL;

  start_arrow(&tpos);
}

static void ins_s_left(void)
{
  if ((fdo_flags & FDO_HOR) && KeyTyped)
    foldOpenCursor();
  undisplay_dollar();
  if (curwin->w_cursor.lnum > 1 || curwin->w_cursor.col > 0) {
    start_arrow(&curwin->w_cursor);
    (void)bck_word(1L, false, false);
    curwin->w_set_curswant = true;
  } else {
    vim_beep(BO_CRSR);
  }
}

/// @param end_change      end undoable change
static void ins_right(bool end_change)
{
  if ((fdo_flags & FDO_HOR) && KeyTyped)
    foldOpenCursor();
  undisplay_dollar();
  if (gchar_cursor() != NUL || virtual_active()) {
    start_arrow_with_change(&curwin->w_cursor, end_change);
    if (!end_change) {
      AppendCharToRedobuff(K_RIGHT);
    }
    curwin->w_set_curswant = true;
    if (virtual_active())
      oneright();
    else {
      if (has_mbyte)
        curwin->w_cursor.col += (*mb_ptr2len)(get_cursor_pos_ptr());
      else
        ++curwin->w_cursor.col;
    }

    revins_legal++;
    if (revins_chars)
      revins_chars--;
  }
  /* if 'whichwrap' set for cursor in insert mode, may move the
   * cursor to the next line */
  else if (vim_strchr(p_ww, ']') != NULL
           && curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count) {
    start_arrow(&curwin->w_cursor);
    curwin->w_set_curswant = TRUE;
    ++curwin->w_cursor.lnum;
    curwin->w_cursor.col = 0;
  } else {
    vim_beep(BO_CRSR);
  }
  dont_sync_undo = kFalse;
}

static void ins_s_right(void)
{
  if ((fdo_flags & FDO_HOR) && KeyTyped)
    foldOpenCursor();
  undisplay_dollar();
  if (curwin->w_cursor.lnum < curbuf->b_ml.ml_line_count
      || gchar_cursor() != NUL) {
    start_arrow(&curwin->w_cursor);
    (void)fwd_word(1L, false, 0);
    curwin->w_set_curswant = true;
  } else {
    vim_beep(BO_CRSR);
  }
}

static void
ins_up (
    int startcol                   /* when TRUE move to Insstart.col */
)
{
  pos_T tpos;
  linenr_T old_topline = curwin->w_topline;
  int old_topfill = curwin->w_topfill;

  undisplay_dollar();
  tpos = curwin->w_cursor;
  if (cursor_up(1L, TRUE) == OK) {
    if (startcol)
      coladvance(getvcol_nolist(&Insstart));
    if (old_topline != curwin->w_topline
        || old_topfill != curwin->w_topfill
        )
      redraw_later(VALID);
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(BO_CRSR);
  }
}

static void ins_pageup(void)
{
  pos_T tpos;

  undisplay_dollar();

  if (mod_mask & MOD_MASK_CTRL) {
    /* <C-PageUp>: tab page back */
    if (first_tabpage->tp_next != NULL) {
      start_arrow(&curwin->w_cursor);
      goto_tabpage(-1);
    }
    return;
  }

  tpos = curwin->w_cursor;
  if (onepage(BACKWARD, 1L) == OK) {
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(BO_CRSR);
  }
}

static void
ins_down (
    int startcol                   /* when TRUE move to Insstart.col */
)
{
  pos_T tpos;
  linenr_T old_topline = curwin->w_topline;
  int old_topfill = curwin->w_topfill;

  undisplay_dollar();
  tpos = curwin->w_cursor;
  if (cursor_down(1L, TRUE) == OK) {
    if (startcol)
      coladvance(getvcol_nolist(&Insstart));
    if (old_topline != curwin->w_topline
        || old_topfill != curwin->w_topfill
        )
      redraw_later(VALID);
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(BO_CRSR);
  }
}

static void ins_pagedown(void)
{
  pos_T tpos;

  undisplay_dollar();

  if (mod_mask & MOD_MASK_CTRL) {
    /* <C-PageDown>: tab page forward */
    if (first_tabpage->tp_next != NULL) {
      start_arrow(&curwin->w_cursor);
      goto_tabpage(0);
    }
    return;
  }

  tpos = curwin->w_cursor;
  if (onepage(FORWARD, 1L) == OK) {
    start_arrow(&tpos);
    can_cindent = true;
  } else {
    vim_beep(BO_CRSR);
  }
}

/// Handle TAB in Insert or Replace mode.
///
/// @return true when the TAB needs to be inserted like a normal character.
static bool ins_tab(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  int i;
  int temp;

  if (Insstart_blank_vcol == MAXCOL && curwin->w_cursor.lnum == Insstart.lnum) {
    Insstart_blank_vcol = get_nolist_virtcol();
  }
  if (echeck_abbr(TAB + ABBR_OFF)) {
    return false;
  }

  int ind = inindent(0);
  if (ind) {
    can_cindent = false;
  }

  // When nothing special, insert TAB like a normal character
  if (!curbuf->b_p_et
      && !(p_sta && ind && curbuf->b_p_ts != get_sw_value(curbuf))
      && get_sts_value() == 0) {
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

  if (p_sta && ind) {  // insert tab in indent, use "shiftwidth"
    temp = get_sw_value(curbuf);
  } else if (curbuf->b_p_sts != 0) {  // use "softtabstop" when set
    temp = get_sts_value();
  } else {  // otherwise use "tabstop"
    temp = (int)curbuf->b_p_ts;
  }
  temp -= get_nolist_virtcol() % temp;

  /*
   * Insert the first space with ins_char().	It will delete one char in
   * replace mode.  Insert the rest with ins_str(); it will not delete any
   * chars.  For VREPLACE mode, we use ins_char() for all characters.
   */
  ins_char(' ');
  while (--temp > 0) {
    if (State & VREPLACE_FLAG)
      ins_char(' ');
    else {
      ins_str((char_u *)" ");
      if (State & REPLACE_FLAG)             /* no char replaced */
        replace_push(NUL);
    }
  }

  /*
   * When 'expandtab' not set: Replace spaces by TABs where possible.
   */
  if (!curbuf->b_p_et && (get_sts_value() || (p_sta && ind))) {
    char_u          *ptr;
    char_u          *saved_line = NULL;         /* init for GCC */
    pos_T pos;
    pos_T fpos;
    pos_T           *cursor;
    colnr_T want_vcol, vcol;
    int change_col = -1;
    int save_list = curwin->w_p_list;

    /*
     * Get the current line.  For VREPLACE mode, don't make real changes
     * yet, just work on a copy of the line.
     */
    if (State & VREPLACE_FLAG) {
      pos = curwin->w_cursor;
      cursor = &pos;
      saved_line = vim_strsave(get_cursor_line_ptr());
      ptr = saved_line + pos.col;
    } else {
      ptr = get_cursor_pos_ptr();
      cursor = &curwin->w_cursor;
    }

    /* When 'L' is not in 'cpoptions' a tab always takes up 'ts' spaces. */
    if (vim_strchr(p_cpo, CPO_LISTWM) == NULL)
      curwin->w_p_list = FALSE;

    /* Find first white before the cursor */
    fpos = curwin->w_cursor;
    while (fpos.col > 0 && ascii_iswhite(ptr[-1])) {
      --fpos.col;
      --ptr;
    }

    /* In Replace mode, don't change characters before the insert point. */
    if ((State & REPLACE_FLAG)
        && fpos.lnum == Insstart.lnum
        && fpos.col < Insstart.col) {
      ptr += Insstart.col - fpos.col;
      fpos.col = Insstart.col;
    }

    /* compute virtual column numbers of first white and cursor */
    getvcol(curwin, &fpos, &vcol, NULL, NULL);
    getvcol(curwin, cursor, &want_vcol, NULL, NULL);

    /* Use as many TABs as possible.  Beware of 'breakindent', 'showbreak'
       and 'linebreak' adding extra virtual columns. */
    while (ascii_iswhite(*ptr)) {
      i = lbr_chartabsize(NULL, (char_u *)"\t", vcol);
      if (vcol + i > want_vcol)
        break;
      if (*ptr != TAB) {
        *ptr = TAB;
        if (change_col < 0) {
          change_col = fpos.col;            /* Column of first change */
          /* May have to adjust Insstart */
          if (fpos.lnum == Insstart.lnum && fpos.col < Insstart.col)
            Insstart.col = fpos.col;
        }
      }
      ++fpos.col;
      ++ptr;
      vcol += i;
    }

    if (change_col >= 0) {
      int repl_off = 0;
      char_u *line = ptr;

      /* Skip over the spaces we need. */
      while (vcol < want_vcol && *ptr == ' ') {
        vcol += lbr_chartabsize(line, ptr, vcol);
        ++ptr;
        ++repl_off;
      }
      if (vcol > want_vcol) {
        /* Must have a char with 'showbreak' just before it. */
        --ptr;
        --repl_off;
      }
      fpos.col += repl_off;

      /* Delete following spaces. */
      i = cursor->col - fpos.col;
      if (i > 0) {
        STRMOVE(ptr, ptr + i);
        /* correct replace stack. */
        if ((State & REPLACE_FLAG)
            && !(State & VREPLACE_FLAG)
            )
          for (temp = i; --temp >= 0; )
            replace_join(repl_off);
      }
      cursor->col -= i;

      /*
       * In VREPLACE mode, we haven't changed anything yet.  Do it now by
       * backspacing over the changed spacing and then inserting the new
       * spacing.
       */
      if (State & VREPLACE_FLAG) {
        /* Backspace from real cursor to change_col */
        backspace_until_column(change_col);

        /* Insert each char in saved_line from changed_col to
         * ptr-cursor */
        ins_bytes_len(saved_line + change_col,
            cursor->col - change_col);
      }
    }

    if (State & VREPLACE_FLAG)
      xfree(saved_line);
    curwin->w_p_list = save_list;
  }

  return false;
}

/// Handle CR or NL in insert mode.
///
/// @return true when it can't undo.
static bool ins_eol(int c)
{
  if (echeck_abbr(c + ABBR_OFF)) {
    return false;
  }
  if (stop_arrow() == FAIL) {
    return true;
  }
  undisplay_dollar();

  /*
   * Strange Vi behaviour: In Replace mode, typing a NL will not delete the
   * character under the cursor.  Only push a NUL on the replace stack,
   * nothing to put back when the NL is deleted.
   */
  if ((State & REPLACE_FLAG)
      && !(State & VREPLACE_FLAG)
      )
    replace_push(NUL);

  /*
   * In VREPLACE mode, a NL replaces the rest of the line, and starts
   * replacing the next line, so we push all of the characters left on the
   * line onto the replace stack.  This is not done here though, it is done
   * in open_line().
   */

  /* Put cursor on NUL if on the last char and coladd is 1 (happens after
   * CTRL-O). */
  if (virtual_active() && curwin->w_cursor.coladd > 0)
    coladvance(getviscol());

  if (p_altkeymap && p_fkmap)
    fkmap(NL);
  /* NL in reverse insert will always start in the end of
   * current line. */
  if (revins_on)
    curwin->w_cursor.col += (colnr_T)STRLEN(get_cursor_pos_ptr());

  AppendToRedobuff(NL_STR);
  bool i = open_line(FORWARD,
                     has_format_option(FO_RET_COMS) ? OPENLINE_DO_COM : 0,
                     old_indent);
  old_indent = 0;
  can_cindent = true;
  // When inserting a line the cursor line must never be in a closed fold.
  foldOpenCursor();

  return !i;
}

/*
 * Handle digraph in insert mode.
 * Returns character still to be inserted, or NUL when nothing remaining to be
 * done.
 */
static int ins_digraph(void)
{
  int c;
  int cc;
  int did_putchar = FALSE;

  pc_status = PC_STATUS_UNSET;
  if (redrawing() && !char_avail()) {
    /* may need to redraw when no more chars available now */
    ins_redraw(FALSE);

    edit_putchar('?', TRUE);
    did_putchar = TRUE;
    add_to_showcmd_c(Ctrl_K);
  }


  // don't map the digraph chars. This also prevents the
  // mode message to be deleted when ESC is hit
  no_mapping++;
  c = plain_vgetc();
  no_mapping--;
  if (did_putchar) {
    // when the line fits in 'columns' the '?' is at the start of the next
    // line and will not be removed by the redraw
    edit_unputchar();
  }

  if (IS_SPECIAL(c) || mod_mask) {          /* special key */
    clear_showcmd();
    insert_special(c, TRUE, FALSE);
    return NUL;
  }
  if (c != ESC) {
    did_putchar = FALSE;
    if (redrawing() && !char_avail()) {
      /* may need to redraw when no more chars available now */
      ins_redraw(FALSE);

      if (char2cells(c) == 1) {
        ins_redraw(FALSE);
        edit_putchar(c, TRUE);
        did_putchar = TRUE;
      }
      add_to_showcmd_c(c);
    }
    no_mapping++;
    cc = plain_vgetc();
    no_mapping--;
    if (did_putchar) {
      // when the line fits in 'columns' the '?' is at the start of the
      // next line and will not be removed by a redraw
      edit_unputchar();
    }
    if (cc != ESC) {
      AppendToRedobuff(CTRL_V_STR);
      c = getdigraph(c, cc, true);
      clear_showcmd();
      return c;
    }
  }
  clear_showcmd();
  return NUL;
}

/*
 * Handle CTRL-E and CTRL-Y in Insert mode: copy char from other line.
 * Returns the char to be inserted, or NUL if none found.
 */
int ins_copychar(linenr_T lnum)
{
  int c;
  int temp;
  char_u  *ptr, *prev_ptr;
  char_u  *line;

  if (lnum < 1 || lnum > curbuf->b_ml.ml_line_count) {
    vim_beep(BO_COPY);
    return NUL;
  }

  /* try to advance to the cursor column */
  temp = 0;
  line = ptr = ml_get(lnum);
  prev_ptr = ptr;
  validate_virtcol();
  while ((colnr_T)temp < curwin->w_virtcol && *ptr != NUL) {
    prev_ptr = ptr;
    temp += lbr_chartabsize_adv(line, &ptr, (colnr_T)temp);
  }
  if ((colnr_T)temp > curwin->w_virtcol)
    ptr = prev_ptr;

  c = utf_ptr2char(ptr);
  if (c == NUL) {
    vim_beep(BO_COPY);
  }
  return c;
}

/*
 * CTRL-Y or CTRL-E typed in Insert mode.
 */
static int ins_ctrl_ey(int tc)
{
  int c = tc;

  if (ctrl_x_mode == CTRL_X_SCROLL) {
    if (c == Ctrl_Y)
      scrolldown_clamp();
    else
      scrollup_clamp();
    redraw_later(VALID);
  } else {
    c = ins_copychar(curwin->w_cursor.lnum + (c == Ctrl_Y ? -1 : 1));
    if (c != NUL) {
      long tw_save;

      // The character must be taken literally, insert like it
      // was typed after a CTRL-V, and pretend 'textwidth'
      // wasn't set.  Digits, 'o' and 'x' are special after a
      // CTRL-V, don't use it for these.
      if (c < 256 && !isalnum(c)) {
        AppendToRedobuff(CTRL_V_STR);
      }
      tw_save = curbuf->b_p_tw;
      curbuf->b_p_tw = -1;
      insert_special(c, TRUE, FALSE);
      curbuf->b_p_tw = tw_save;
      revins_chars++;
      revins_legal++;
      c = Ctrl_V;       /* pretend CTRL-V is last character */
      auto_format(FALSE, TRUE);
    }
  }
  return c;
}

/*
 * Try to do some very smart auto-indenting.
 * Used when inserting a "normal" character.
 */
static void ins_try_si(int c)
{
  pos_T       *pos, old_pos;
  char_u      *ptr;
  int i;
  int temp;

  /*
   * do some very smart indenting when entering '{' or '}'
   */
  if (((did_si || can_si_back) && c == '{') || (can_si && c == '}')) {
    /*
     * for '}' set indent equal to indent of line containing matching '{'
     */
    if (c == '}' && (pos = findmatch(NULL, '{')) != NULL) {
      old_pos = curwin->w_cursor;
      /*
       * If the matching '{' has a ')' immediately before it (ignoring
       * white-space), then line up with the start of the line
       * containing the matching '(' if there is one.  This handles the
       * case where an "if (..\n..) {" statement continues over multiple
       * lines -- webb
       */
      ptr = ml_get(pos->lnum);
      i = pos->col;
      if (i > 0)                /* skip blanks before '{' */
        while (--i > 0 && ascii_iswhite(ptr[i]))
          ;
      curwin->w_cursor.lnum = pos->lnum;
      curwin->w_cursor.col = i;
      if (ptr[i] == ')' && (pos = findmatch(NULL, '(')) != NULL)
        curwin->w_cursor = *pos;
      i = get_indent();
      curwin->w_cursor = old_pos;
      if (State & VREPLACE_FLAG)
        change_indent(INDENT_SET, i, FALSE, NUL, TRUE);
      else
        (void)set_indent(i, SIN_CHANGED);
    } else if (curwin->w_cursor.col > 0) {
      /*
       * when inserting '{' after "O" reduce indent, but not
       * more than indent of previous line
       */
      temp = TRUE;
      if (c == '{' && can_si_back && curwin->w_cursor.lnum > 1) {
        old_pos = curwin->w_cursor;
        i = get_indent();
        while (curwin->w_cursor.lnum > 1) {
          ptr = skipwhite(ml_get(--(curwin->w_cursor.lnum)));

          /* ignore empty lines and lines starting with '#'. */
          if (*ptr != '#' && *ptr != NUL)
            break;
        }
        if (get_indent() >= i)
          temp = FALSE;
        curwin->w_cursor = old_pos;
      }
      if (temp)
        shift_line(TRUE, FALSE, 1, TRUE);
    }
  }

  /*
   * set indent of '#' always to 0
   */
  if (curwin->w_cursor.col > 0 && can_si && c == '#') {
    /* remember current indent for next line */
    old_indent = get_indent();
    (void)set_indent(0, SIN_CHANGED);
  }

  /* Adjust ai_col, the char at this position can be deleted. */
  if (ai_col > curwin->w_cursor.col)
    ai_col = curwin->w_cursor.col;
}

/*
 * Get the value that w_virtcol would have when 'list' is off.
 * Unless 'cpo' contains the 'L' flag.
 */
static colnr_T get_nolist_virtcol(void)
{
  if (curwin->w_p_list && vim_strchr(p_cpo, CPO_LISTWM) == NULL)
    return getvcol_nolist(&curwin->w_cursor);
  validate_virtcol();
  return curwin->w_virtcol;
}

/*
 * Handle the InsertCharPre autocommand.
 * "c" is the character that was typed.
 * Return a pointer to allocated memory with the replacement string.
 * Return NULL to continue inserting "c".
 */
static char_u *do_insert_char_pre(int c)
{
  char buf[MB_MAXBYTES + 1];

  // Return quickly when there is nothing to do.
  if (!has_event(EVENT_INSERTCHARPRE)) {
    return NULL;
  }
  buf[utf_char2bytes(c, (char_u *)buf)] = NUL;

  // Lock the text to avoid weird things from happening.
  textlock++;
  set_vim_var_string(VV_CHAR, buf, -1);

  char_u *res = NULL;
  if (ins_apply_autocmds(EVENT_INSERTCHARPRE)) {
    // Get the value of v:char.  It may be empty or more than one
    // character.  Only use it when changed, otherwise continue with the
    // original character to avoid breaking autoindent.
    if (STRCMP(buf, get_vim_var_str(VV_CHAR)) != 0) {
      res = vim_strsave(get_vim_var_str(VV_CHAR));
    }
  }

  set_vim_var_string(VV_CHAR, NULL, -1);
  textlock--;

  return res;
}

/// Trigger "event" and take care of fixing undo.
static int ins_apply_autocmds(event_T event)
{
  varnumber_T tick = buf_get_changedtick(curbuf);
  int r;

  r = apply_autocmds(event, NULL, NULL, false, curbuf);

  // If u_savesub() was called then we are not prepared to start
  // a new line.  Call u_save() with no contents to fix that.
  if (tick != buf_get_changedtick(curbuf)) {
    u_save(curwin->w_cursor.lnum, (linenr_T)(curwin->w_cursor.lnum + 1));
  }

  return r;
}

static void show_pum(int prev_w_wrow, int prev_w_leftcol)
{
  // RedrawingDisabled may be set when invoked through complete().
  int n = RedrawingDisabled;
  RedrawingDisabled = 0;

  // If the cursor moved or the display scrolled we need to remove the pum
  // first.
  setcursor();
  if (prev_w_wrow != curwin->w_wrow || prev_w_leftcol != curwin->w_leftcol) {
    ins_compl_del_pum();
  }

  ins_compl_show_pum();
  setcursor();
  RedrawingDisabled = n;
}
