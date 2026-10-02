#pragma once

#include <stdbool.h>

#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

/// Change-delimiting cursor-move in insert-mode (start_arrow()): undo, Ins.start and last_insert
/// (the ". register) restart at next edit (stop_arrow()); typed keys sync undo (may_sync_undo()).
typedef enum {
  kInsNone = 0,  ///< No cursor-move since last edit: contiguous insert-session.
  kInsArrow,     ///< Cursor-move captured in the atom.
  kInsJump,      ///< Non-replayable jump (mouse, <PageUp>, …): atom terminated (<Esc>).
} InsArrow;

/// Insert-mode session state: the in-progress insert session, as one global "group" (Ins), so it
/// can be saved/restored around nested edit() sessions (mc_ins_save_state).
typedef struct {
  pos_T start;               ///< Start of current INSERTION: from here to cursor is the unit that
                             ///< undo, '[ and ". treat as one. Reanchored after cursor-move, C-G u.
  pos_T start_orig;          ///< Where insert by the user started (for op_insert): follows `start`
                             ///< until insertion starts right of it; <bs> before it pulls back.
  colnr_T start_textlen;     ///< length of line when insert started
  colnr_T start_blank_vcol;  ///< vcol for first inserted blank
  InsArrow moved;            ///< Cursor moved since the last edit; see InsArrow.
  bool stop_insert_mode;     ///< for ":stopinsert"
  bool can_cindent;          ///< may do cindenting on this line
  bool need_undo;            ///< call u_save() before inserting a char. Set when edit() is
                             ///< called; after that `moved` is used.
  bool did_ai;               ///< Makes auto-indent work right on lines where only a <CR> or
                             ///< <Esc> is typed: set when an auto-indent is done, reset when any
                             ///< other editing is done on the line. If an <Esc> or <CR> is
                             ///< received and did_ai is true, the line is truncated.
  colnr_T ai_col;            ///< Column of first char after autoindent. 0 when no autoindent
                             ///< done. Used when 'backspace' is 0, to avoid backspacing over
                             ///< autoindent.
  int end_comment_pending;   ///< A character which will end a start-middle-end comment when
                             ///< typed as the first character on a new line. Taken from the last
                             ///< character of the "end" comment leader when the COM_AUTO_END
                             ///< flag is given for that comment end in 'comments'. Only valid
                             ///< when did_ai is true.
  bool did_si;               ///< Set when a smart indent has been performed: when the next
                             ///< typed character is a '{' the inserted tab will be deleted again.
  bool can_si;               ///< after an auto indent: a typed '}' removes one indent
  bool can_si_back;          ///< after an "O" command: a typed '{' removes one indent
  bool update_start_orig;    ///< set start_orig to start
  int new_insert_skip;       ///< number of chars in front of the current insert
  int did_restart_edit;      ///< "restart_edit" when edit() was called
  bool revins_on;            ///< reverse insert mode on
  int revins_chars;          ///< how much to skip after edit
  int revins_legal;          ///< was the last char "legal"?
  int revins_scol;           ///< start column of revins session
  TriState dont_sync_undo;   ///< CTRL-G U prevents syncing undo for the next left/right cursor key
  linenr_T o_lnum;           ///< "o" command's line, for "CTRL-O ." that adds a line (ins_at_eol)
} InsState;
