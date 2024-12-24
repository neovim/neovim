// insexpand.c: functions for Insert mode completion

#include <assert.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/extmark_defs.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/popupmenu.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/textformat.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

// Definitions used for CTRL-X submode.
// Note: If you change CTRL-X submode, you must also maintain ctrl_x_msgs[]
// and ctrl_x_mode_names[].

#define CTRL_X_WANT_IDENT       0x100

enum {
  CTRL_X_NORMAL = 0,  ///< CTRL-N CTRL-P completion, default
  CTRL_X_NOT_DEFINED_YET = 1,
  CTRL_X_SCROLL = 2,
  CTRL_X_WHOLE_LINE = 3,
  CTRL_X_FILES = 4,
  CTRL_X_TAGS = (5 + CTRL_X_WANT_IDENT),
  CTRL_X_PATH_PATTERNS = (6 + CTRL_X_WANT_IDENT),
  CTRL_X_PATH_DEFINES = (7 + CTRL_X_WANT_IDENT),
  CTRL_X_FINISHED = 8,
  CTRL_X_DICTIONARY = (9 + CTRL_X_WANT_IDENT),
  CTRL_X_THESAURUS = (10 + CTRL_X_WANT_IDENT),
  CTRL_X_CMDLINE = 11,
  CTRL_X_FUNCTION = 12,
  CTRL_X_OMNI = 13,
  CTRL_X_SPELL = 14,
  CTRL_X_LOCAL_MSG = 15,       ///< only used in "ctrl_x_msgs"
  CTRL_X_EVAL = 16,            ///< for builtin function complete()
  CTRL_X_CMDLINE_CTRL_X = 17,  ///< CTRL-X typed in CTRL_X_CMDLINE
  CTRL_X_BUFNAMES = 18,
};

#define CTRL_X_MSG(i) ctrl_x_msgs[(i) & ~CTRL_X_WANT_IDENT]

/// Message for CTRL-X mode, index is ctrl_x_mode.
static char *ctrl_x_msgs[] = {
  N_(" Keyword completion (^N^P)"),  // CTRL_X_NORMAL, ^P/^N compl.
  N_(" ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)"),
  NULL,  // CTRL_X_SCROLL: depends on state
  N_(" Whole line completion (^L^N^P)"),
  N_(" File name completion (^F^N^P)"),
  N_(" Tag completion (^]^N^P)"),
  N_(" Path pattern completion (^N^P)"),
  N_(" Definition completion (^D^N^P)"),
  NULL,  // CTRL_X_FINISHED
  N_(" Dictionary completion (^K^N^P)"),
  N_(" Thesaurus completion (^T^N^P)"),
  N_(" Command-line completion (^V^N^P)"),
  N_(" User defined completion (^U^N^P)"),
  N_(" Omni completion (^O^N^P)"),
  N_(" Spelling suggestion (^S^N^P)"),
  N_(" Keyword Local completion (^N^P)"),
  NULL,  // CTRL_X_EVAL doesn't use msg.
  N_(" Command-line completion (^V^N^P)"),
};

static char *ctrl_x_mode_names[] = {
  "keyword",
  "ctrl_x",
  "scroll",
  "whole_line",
  "files",
  "tags",
  "path_patterns",
  "path_defines",
  "unknown",          // CTRL_X_FINISHED
  "dictionary",
  "thesaurus",
  "cmdline",
  "function",
  "omni",
  "spell",
  NULL,               // CTRL_X_LOCAL_MSG only used in "ctrl_x_msgs"
  "eval",
  "cmdline",
};

/// Structure used to store one match for insert completion.
typedef struct compl_S compl_T;
struct compl_S {
  compl_T *cp_next;
  compl_T *cp_prev;
  compl_T *cp_match_next;        ///< matched next compl_T
  char *cp_str;                  ///< matched text
  char *(cp_text[CPT_COUNT]);    ///< text for the menu
  typval_T cp_user_data;
  char *cp_fname;                ///< file containing the match, allocated when
                                 ///< cp_flags has CP_FREE_FNAME
  int cp_flags;                  ///< CP_ values
  int cp_number;                 ///< sequence number
  int cp_score;                  ///< fuzzy match score
  int cp_user_abbr_hlattr;       ///< highlight attribute for abbr
  int cp_user_kind_hlattr;       ///< highlight attribute for kind
};

/// state information used for getting the next set of insert completion
/// matches.
typedef struct {
  char *e_cpt_copy;       ///< copy of 'complete'
  char *e_cpt;            ///< current entry in "e_cpt_copy"
  buf_T *ins_buf;         ///< buffer being scanned
  pos_T *cur_match_pos;   ///< current match position
  pos_T prev_match_pos;   ///< previous match position
  bool set_match_pos;     ///< save first_match_pos/last_match_pos
  pos_T first_match_pos;  ///< first match position
  pos_T last_match_pos;   ///< last match position
  bool found_all;         ///< found all matches of a certain type.
  char *dict;             ///< dictionary file to search
  int dict_f;             ///< "dict" is an exact file name or not
} ins_compl_next_state_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "insexpand.c.generated.h"
#endif

/// values for cp_flags
typedef enum {
  CP_ORIGINAL_TEXT = 1,  ///< the original text when the expansion begun
  CP_FREE_FNAME = 2,     ///< cp_fname is allocated
  CP_CONT_S_IPOS = 4,    ///< use CONT_S_IPOS for compl_cont_status
  CP_EQUAL = 8,          ///< ins_compl_equal() always returns true
  CP_ICASE = 16,         ///< ins_compl_equal ignores case
  CP_FAST = 32,          ///< use fast_breakcheck instead of os_breakcheck
} cp_flags_T;

static const char e_hitend[] = N_("Hit end of paragraph");
static const char e_compldel[] = N_("E840: Completion function deleted text");

// All the current matches are stored in a list.
// "compl_first_match" points to the start of the list.
// "compl_curr_match" points to the currently selected entry.
// "compl_shown_match" is different from compl_curr_match during
// ins_compl_get_exp().
// "compl_old_match" points to previous "compl_curr_match".

static compl_T *compl_first_match = NULL;
static compl_T *compl_curr_match = NULL;
static compl_T *compl_shown_match = NULL;
static compl_T *compl_old_match = NULL;

/// After using a cursor key <Enter> selects a match in the popup menu,
/// otherwise it inserts a line break.
static bool compl_enter_selects = false;

/// When "compl_leader" is not NULL only matches that start with this string
/// are used.
static char *compl_leader = NULL;

static bool compl_get_longest = false;  ///< put longest common string in compl_leader

/// Selected one of the matches. When false the match was edited or using the
/// longest common string.
static bool compl_used_match;

/// didn't finish finding completions.
static bool compl_was_interrupted = false;

// Set when character typed while looking for matches and it means we should
// stop looking for matches.
static bool compl_interrupted = false;

static bool compl_restarting = false;   ///< don't insert match

/// When the first completion is done "compl_started" is set.  When it's
/// false the word to be completed must be located.
static bool compl_started = false;

/// Which Ctrl-X mode are we in?
static int ctrl_x_mode = CTRL_X_NORMAL;

static int compl_matches = 0;           ///< number of completion matches
static char *compl_pattern = NULL;
static size_t compl_patternlen = 0;
static Direction compl_direction = FORWARD;
static Direction compl_shows_dir = FORWARD;
static int compl_pending = 0;           ///< > 1 for postponed CTRL-N
static pos_T compl_startpos;
/// Length in bytes of the text being completed (this is deleted to be replaced
/// by the match.)
static int compl_length = 0;
static colnr_T compl_col = 0;           ///< column where the text starts
                                        ///< that is being completed
static colnr_T compl_ins_end_col = 0;
static char *compl_orig_text = NULL;    ///< text as it was before
                                        ///< completion started
/// Undo information to restore extmarks for original text.
static extmark_undo_vec_t compl_orig_extmarks;
static int compl_cont_mode = 0;
static expand_T compl_xp;

// List of flags for method of completion.
static int compl_cont_status = 0;
#define CONT_ADDING    1        ///< "normal" or "adding" expansion
#define CONT_INTRPT    (2 + 4)  ///< a ^X interrupted the current expansion
                                ///< it's set only iff N_ADDS is set
#define CONT_N_ADDS    4        ///< next ^X<> will add-new or expand-current
#define CONT_S_IPOS    8        ///< next ^X<> will set initial_pos?
                                ///< if so, word-wise-expansion will set SOL
#define CONT_SOL       16       ///< pattern includes start of line, just for
                                ///< word-wise expansion, not set for ^X^L
#define CONT_LOCAL     32       ///< for ctrl_x_mode 0, ^X^P/^X^N do a local
                                ///< expansion, (eg use complete=.)

static bool compl_opt_refresh_always = false;

static size_t spell_bad_len = 0;   // length of located bad word

static int compl_selected_item = -1;

// "compl_match_array" points the currently displayed list of entries in the
// popup menu.  It is NULL when there is no popup menu.
static pumitem_T *compl_match_array = NULL;
static int compl_match_arraysize;

/// CTRL-X pressed in Insert mode.
void ins_ctrl_x(void)
{
  if (!ctrl_x_mode_cmdline()) {
    // if the next ^X<> won't ADD nothing, then reset compl_cont_status
    if (compl_cont_status & CONT_N_ADDS) {
      compl_cont_status |= CONT_INTRPT;
    } else {
      compl_cont_status = 0;
    }
    // We're not sure which CTRL-X mode it will be yet
    ctrl_x_mode = CTRL_X_NOT_DEFINED_YET;
    edit_submode = _(CTRL_X_MSG(ctrl_x_mode));
    edit_submode_pre = NULL;
    showmode();
  } else {
    // CTRL-X in CTRL-X CTRL-V mode behaves differently to make CTRL-X
    // CTRL-V look like CTRL-N
    ctrl_x_mode = CTRL_X_CMDLINE_CTRL_X;
  }

  may_trigger_modechanged();
}

// Functions to check the current CTRL-X mode.

bool ctrl_x_mode_none(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == 0;
}

bool ctrl_x_mode_normal(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_NORMAL;
}

bool ctrl_x_mode_scroll(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_SCROLL;
}

bool ctrl_x_mode_whole_line(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_WHOLE_LINE;
}

bool ctrl_x_mode_files(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_FILES;
}

bool ctrl_x_mode_tags(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_TAGS;
}

bool ctrl_x_mode_path_patterns(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_PATH_PATTERNS;
}

bool ctrl_x_mode_path_defines(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_PATH_DEFINES;
}

bool ctrl_x_mode_dictionary(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_DICTIONARY;
}

bool ctrl_x_mode_thesaurus(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_THESAURUS;
}

bool ctrl_x_mode_cmdline(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_CMDLINE || ctrl_x_mode == CTRL_X_CMDLINE_CTRL_X;
}

bool ctrl_x_mode_function(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_FUNCTION;
}

bool ctrl_x_mode_omni(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_OMNI;
}

bool ctrl_x_mode_spell(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_SPELL;
}

static bool ctrl_x_mode_eval(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_EVAL;
}

bool ctrl_x_mode_line_or_eval(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_WHOLE_LINE || ctrl_x_mode == CTRL_X_EVAL;
}

/// Whether other than default completion has been selected.
bool ctrl_x_mode_not_default(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode != CTRL_X_NORMAL;
}

/// Whether CTRL-X was typed without a following character,
/// not including when in CTRL-X CTRL-V mode.
bool ctrl_x_mode_not_defined_yet(void)
  FUNC_ATTR_PURE
{
  return ctrl_x_mode == CTRL_X_NOT_DEFINED_YET;
}

/// @return  true if currently in "normal" or "adding" insert completion matches state
bool compl_status_adding(void)
{
  return compl_cont_status & CONT_ADDING;
}

/// @return  true if the completion pattern includes start of line, just for
///          word-wise expansion.
bool compl_status_sol(void)
{
  return compl_cont_status & CONT_SOL;
}

/// @return  true if ^X^P/^X^N will do a local completion (i.e. use complete=.)
bool compl_status_local(void)
{
  return compl_cont_status & CONT_LOCAL;
}

/// Clear the completion status flags
void compl_status_clear(void)
{
  compl_cont_status = 0;
}

/// @return  true if completion is using the forward direction matches
static bool compl_dir_forward(void)
{
  return compl_direction == FORWARD;
}

/// @return  true if currently showing forward completion matches
static bool compl_shows_dir_forward(void)
{
  return compl_shows_dir == FORWARD;
}

/// @return  true if currently showing backward completion matches
static bool compl_shows_dir_backward(void)
{
  return compl_shows_dir == BACKWARD;
}

/// Check that the 'dictionary' or 'thesaurus' option can be used.
///
/// @param  dict_opt  check 'dictionary' when true, 'thesaurus' when false.
bool check_compl_option(bool dict_opt)
{
  if (dict_opt
      ? (*curbuf->b_p_dict == NUL && *p_dict == NUL && !curwin->w_p_spell)
      : (*curbuf->b_p_tsr == NUL && *p_tsr == NUL
         && *curbuf->b_p_tsrfu == NUL && *p_tsrfu == NUL)) {
    ctrl_x_mode = CTRL_X_NORMAL;
    edit_submode = NULL;
    msg((dict_opt ? _("'dictionary' option is empty") : _("'thesaurus' option is empty")),
        HLF_E);
    if (emsg_silent == 0 && !in_assert_fails) {
      vim_beep(kOptBoFlagComplete);
      setcursor();
      ui_flush();
      os_delay(2004, false);
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
  case CTRL_X_CMDLINE_CTRL_X:
    return c == Ctrl_X || c == Ctrl_Y || c == Ctrl_E
           || c == Ctrl_L || c == Ctrl_F || c == Ctrl_RSB
           || c == Ctrl_I || c == Ctrl_D || c == Ctrl_P
           || c == Ctrl_N || c == Ctrl_T || c == Ctrl_V
           || c == Ctrl_Q || c == Ctrl_U || c == Ctrl_O
           || c == Ctrl_S || c == Ctrl_K || c == 's'
           || c == Ctrl_Z;
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
  case CTRL_X_BUFNAMES:
    return (c == Ctrl_P || c == Ctrl_N);
  }
  internal_error("vim_is_ctrl_x_key()");
  return false;
}

/// @return  true if "match" is the original text when the completion began.
static bool match_at_original_text(const compl_T *const match)
{
  return match->cp_flags & CP_ORIGINAL_TEXT;
}

/// @return  true if "match" is the first match in the completion list.
static bool is_first_match(const compl_T *const match)
{
  return match == compl_first_match;
}

static void do_autocmd_completedone(int c, int mode, char *word)
{
  save_v_event_T save_v_event;
  dict_T *v_event = get_v_event(&save_v_event);

  mode = mode & ~CTRL_X_WANT_IDENT;
  char *mode_str = NULL;
  if (ctrl_x_mode_names[mode]) {
    mode_str = ctrl_x_mode_names[mode];
  }
  tv_dict_add_str(v_event, S_LEN("complete_word"), word != NULL ? word : "");
  tv_dict_add_str(v_event, S_LEN("complete_type"), mode_str != NULL ? mode_str : "");

  tv_dict_add_str(v_event, S_LEN("reason"), (c == Ctrl_Y ? "accept" : "cancel"));
  tv_dict_set_keys_readonly(v_event);

  ins_apply_autocmds(EVENT_COMPLETEDONE);
  restore_v_event(v_event, &save_v_event);
}

/// Check that character "c" is part of the item currently being
/// completed.  Used to decide whether to abandon complete mode when the menu
/// is visible.
///
/// @param  c  character to check
bool ins_compl_accept_char(int c)
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
  case CTRL_X_CMDLINE_CTRL_X:
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

/// Get the completed text by inferring the case of the originally typed text.
/// If the result is in allocated memory "tofree" is set to it.
static char *ins_compl_infercase_gettext(const char *str, int char_len, int compl_char_len,
                                         int min_len, char **tofree)
{
  bool has_lower = false;

  // Allocate wide character array for the completion and fill it.
  int *const wca = xmalloc((size_t)char_len * sizeof(*wca));
  {
    const char *p = str;
    for (int i = 0; i < char_len; i++) {
      wca[i] = mb_ptr2char_adv(&p);
    }
  }

  // Rule 1: Were any chars converted to lower?
  {
    const char *p = compl_orig_text;
    for (int i = 0; i < min_len; i++) {
      const int c = mb_ptr2char_adv(&p);
      if (mb_islower(c)) {
        has_lower = true;
        if (mb_isupper(wca[i])) {
          // Rule 1 is satisfied.
          for (i = compl_char_len; i < char_len; i++) {
            wca[i] = mb_tolower(wca[i]);
          }
          break;
        }
      }
    }
  }

  // Rule 2: No lower case, 2nd consecutive letter converted to
  // upper case.
  if (!has_lower) {
    bool was_letter = false;
    const char *p = compl_orig_text;
    for (int i = 0; i < min_len; i++) {
      const int c = mb_ptr2char_adv(&p);
      if (was_letter && mb_isupper(c) && mb_islower(wca[i])) {
        // Rule 2 is satisfied.
        for (i = compl_char_len; i < char_len; i++) {
          wca[i] = mb_toupper(wca[i]);
        }
        break;
      }
      was_letter = mb_islower(c) || mb_isupper(c);
    }
  }

  // Copy the original case of the part we typed.
  {
    const char *p = compl_orig_text;
    for (int i = 0; i < min_len; i++) {
      const int c = mb_ptr2char_adv(&p);
      if (mb_islower(c)) {
        wca[i] = mb_tolower(wca[i]);
      } else if (mb_isupper(c)) {
        wca[i] = mb_toupper(wca[i]);
      }
    }
  }

  // Generate encoding specific output from wide character array.
  garray_T gap;
  char *p = IObuff;
  int i = 0;
  ga_init(&gap, 1, 500);
  while (i < char_len) {
    if (gap.ga_data != NULL) {
      ga_grow(&gap, 10);
      assert(gap.ga_data != NULL);  // suppress clang "Dereference of NULL pointer"
      p = (char *)gap.ga_data + gap.ga_len;
      gap.ga_len += utf_char2bytes(wca[i++], p);
    } else if ((p - IObuff) + 6 >= IOSIZE) {
      // Multi-byte characters can occupy up to five bytes more than
      // ASCII characters, and we also need one byte for NUL, so when
      // getting to six bytes from the edge of IObuff switch to using a
      // growarray.  Add the character in the next round.
      ga_grow(&gap, IOSIZE);
      *p = NUL;
      STRCPY(gap.ga_data, IObuff);
      gap.ga_len = (int)strlen(IObuff);
    } else {
      p += utf_char2bytes(wca[i++], p);
    }
  }
  xfree(wca);

  if (gap.ga_data != NULL) {
    *tofree = gap.ga_data;
    return gap.ga_data;
  }

  *p = NUL;
  return IObuff;
}

/// This is like ins_compl_add(), but if 'ic' and 'inf' are set, then the
/// case of the originally typed text is used, and the case of the completed
/// text is inferred, ie this tries to work out what case you probably wanted
/// the rest of the word to be in -- webb
///
/// @param[in]  cont_s_ipos  next ^X<> will set initial_pos
int ins_compl_add_infercase(char *str_arg, int len, bool icase, char *fname, Direction dir,
                            bool cont_s_ipos)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char *str = str_arg;
  int char_len;  // count multi-byte characters
  int compl_char_len;
  int flags = 0;
  char *tofree = NULL;

  if (p_ic && curbuf->b_p_inf && len > 0) {
    // Infer case of completed part.

    // Find actual length of completion.
    {
      const char *p = str;
      char_len = 0;
      while (*p != NUL) {
        MB_PTR_ADV(p);
        char_len++;
      }
    }

    // Find actual length of original text.
    {
      const char *p = compl_orig_text;
      compl_char_len = 0;
      while (*p != NUL) {
        MB_PTR_ADV(p);
        compl_char_len++;
      }
    }

    // "char_len" may be smaller than "compl_char_len" when using
    // thesaurus, only use the minimum when comparing.
    int min_len = MIN(char_len, compl_char_len);

    str = ins_compl_infercase_gettext(str, char_len, compl_char_len, min_len, &tofree);
  }
  if (cont_s_ipos) {
    flags |= CP_CONT_S_IPOS;
  }
  if (icase) {
    flags |= CP_ICASE;
  }

  int res = ins_compl_add(str, len, fname, NULL, false, NULL, dir, flags, false, NULL);
  xfree(tofree);
  return res;
}

/// free cptext
static inline void free_cptext(char *const *const cptext)
{
  if (cptext != NULL) {
    for (size_t i = 0; i < CPT_COUNT; i++) {
      xfree(cptext[i]);
    }
  }
}

/// Add a match to the list of matches
///
/// @param[in]  str     text of the match to add
/// @param[in]  len     length of "str". If -1, then the length of "str" is computed.
/// @param[in]  fname   file name to associate with this match. May be NULL.
/// @param[in]  cptext  list of strings to use with this match (for abbr, menu, info
///                     and kind). May be NULL.
///                     If not NULL, must have exactly #CPT_COUNT items.
/// @param[in]  cptext_allocated  If true, will not copy cptext strings.
///
///                               @note Will free strings in case of error.
///                                     cptext itself will not be freed.
/// @param[in]  user_data  user supplied data (any vim type) for this match
/// @param[in]  cdir       match direction. If 0, use "compl_direction".
/// @param[in]  flags_arg  match flags (cp_flags)
/// @param[in]  adup       accept this match even if it is already present.
/// @param[in]  user_hl    list of extra highlight attributes for abbr kind.
///
/// If "cdir" is FORWARD, then the match is added after the current match.
/// Otherwise, it is added before the current match.
///
/// @return NOTDONE if the given string is already in the list of completions,
///         otherwise it is added to the list and  OK is returned. FAIL will be
///         returned in case of error.
static int ins_compl_add(char *const str, int len, char *const fname, char *const *const cptext,
                         const bool cptext_allocated, typval_T *user_data, const Direction cdir,
                         int flags_arg, const bool adup, const int *user_hl)
  FUNC_ATTR_NONNULL_ARG(1)
{
  compl_T *match;
  const Direction dir = (cdir == kDirectionNotSet ? compl_direction : cdir);
  int flags = flags_arg;

  if (flags & CP_FAST) {
    fast_breakcheck();
  } else {
    os_breakcheck();
  }
  if (got_int) {
    if (cptext_allocated) {
      free_cptext(cptext);
    }
    return FAIL;
  }
  if (len < 0) {
    len = (int)strlen(str);
  }

  // If the same match is already present, don't add it.
  if (compl_first_match != NULL && !adup) {
    match = compl_first_match;
    do {
      if (!match_at_original_text(match)
          && strncmp(match->cp_str, str, (size_t)len) == 0
          && ((int)strlen(match->cp_str) <= len || match->cp_str[len] == NUL)) {
        if (cptext_allocated) {
          free_cptext(cptext);
        }
        return NOTDONE;
      }
      match = match->cp_next;
    } while (match != NULL && !is_first_match(match));
  }

  // Remove any popup menu before changing the list of matches.
  ins_compl_del_pum();

  // Allocate a new match structure.
  // Copy the values to the new match structure.
  match = xcalloc(1, sizeof(compl_T));
  match->cp_number = -1;
  if (flags & CP_ORIGINAL_TEXT) {
    match->cp_number = 0;
  }
  match->cp_str = xstrnsave(str, (size_t)len);

  // match-fname is:
  // - compl_curr_match->cp_fname if it is a string equal to fname.
  // - a copy of fname, CP_FREE_FNAME is set to free later THE allocated mem.
  // - NULL otherwise.  --Acevedo
  if (fname != NULL
      && compl_curr_match != NULL
      && compl_curr_match->cp_fname != NULL
      && strcmp(fname, compl_curr_match->cp_fname) == 0) {
    match->cp_fname = compl_curr_match->cp_fname;
  } else if (fname != NULL) {
    match->cp_fname = xstrdup(fname);
    flags |= CP_FREE_FNAME;
  } else {
    match->cp_fname = NULL;
  }
  match->cp_flags = flags;
  match->cp_user_abbr_hlattr = user_hl ? user_hl[0] : -1;
  match->cp_user_kind_hlattr = user_hl ? user_hl[1] : -1;

  if (cptext != NULL) {
    int i;

    for (i = 0; i < CPT_COUNT; i++) {
      if (cptext[i] == NULL) {
        continue;
      }
      if (*cptext[i] != NUL) {
        match->cp_text[i] = (cptext_allocated ? cptext[i] : xstrdup(cptext[i]));
      } else if (cptext_allocated) {
        xfree(cptext[i]);
      }
    }
  }

  if (user_data != NULL) {
    match->cp_user_data = *user_data;
  }

  // Link the new match structure after (FORWARD) or before (BACKWARD) the
  // current match in the list of matches .
  if (compl_first_match == NULL) {
    match->cp_next = match->cp_prev = NULL;
  } else if (dir == FORWARD) {
    match->cp_next = compl_curr_match->cp_next;
    match->cp_prev = compl_curr_match;
  } else {    // BACKWARD
    match->cp_next = compl_curr_match;
    match->cp_prev = compl_curr_match->cp_prev;
  }
  if (match->cp_next) {
    match->cp_next->cp_prev = match;
  }
  if (match->cp_prev) {
    match->cp_prev->cp_next = match;
  } else {        // if there's nothing before, it is the first match
    compl_first_match = match;
  }
  compl_curr_match = match;

  // Find the longest common string if still doing that.
  if (compl_get_longest && (flags & CP_ORIGINAL_TEXT) == 0) {
    ins_compl_longest_match(match);
  }

  return OK;
}

/// Check that "str[len]" matches with "match->cp_str", considering
/// "match->cp_flags".
///
/// @param  match  completion match
/// @param  str    character string to check
/// @param  len    length of "str"
static bool ins_compl_equal(compl_T *match, char *str, size_t len)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (match->cp_flags & CP_EQUAL) {
    return true;
  }
  if (match->cp_flags & CP_ICASE) {
    return STRNICMP(match->cp_str, str, len) == 0;
  }
  return strncmp(match->cp_str, str, len) == 0;
}

/// when len is -1 mean use whole length of p otherwise part of p
static void ins_compl_insert_bytes(char *p, int len)
  FUNC_ATTR_NONNULL_ALL
{
  if (len == -1) {
    len = (int)strlen(p);
  }
  assert(len >= 0);
  ins_bytes_len(p, (size_t)len);
  compl_ins_end_col = curwin->w_cursor.col;
}

/// Checks if the column is within the currently inserted completion text
/// column range. If it is, it returns a special highlight attribute.
/// -1 mean normal item.
int ins_compl_col_range_attr(int col)
{
  if (col >= compl_col && col < compl_ins_end_col) {
    return syn_name2attr("ComplMatchIns");
  }

  return -1;
}

/// Reduce the longest common string for match "match".
static void ins_compl_longest_match(compl_T *match)
{
  if (compl_leader == NULL) {
    // First match, use it as a whole.
    compl_leader = xstrdup(match->cp_str);

    bool had_match = (curwin->w_cursor.col > compl_col);
    ins_compl_delete(false);
    ins_compl_insert_bytes(compl_leader + get_compl_len(), -1);
    ins_redraw(false);

    // When the match isn't there (to avoid matching itself) remove it
    // again after redrawing.
    if (!had_match) {
      ins_compl_delete(false);
    }
    compl_used_match = false;

    return;
  }

  // Reduce the text if this match differs from compl_leader.
  char *p = compl_leader;
  char *s = match->cp_str;
  while (*p != NUL) {
    int c1 = utf_ptr2char(p);
    int c2 = utf_ptr2char(s);

    if ((match->cp_flags & CP_ICASE)
        ? (mb_tolower(c1) != mb_tolower(c2))
        : (c1 != c2)) {
      break;
    }
    MB_PTR_ADV(p);
    MB_PTR_ADV(s);
  }

  if (*p != NUL) {
    // Leader was shortened, need to change the inserted text.
    *p = NUL;
    bool had_match = (curwin->w_cursor.col > compl_col);
    ins_compl_delete(false);
    ins_compl_insert_bytes(compl_leader + get_compl_len(), -1);
    ins_redraw(false);

    // When the match isn't there (to avoid matching itself) remove it
    // again after redrawing.
    if (!had_match) {
      ins_compl_delete(false);
    }
  }

  compl_used_match = false;
}

/// Add an array of matches to the list of matches.
/// Frees matches[].
static void ins_compl_add_matches(int num_matches, char **matches, int icase)
{
  int add_r = OK;
  Direction dir = compl_direction;

  for (int i = 0; i < num_matches && add_r != FAIL; i++) {
    add_r = ins_compl_add(matches[i], -1, NULL, NULL, false, NULL, dir,
                          CP_FAST | (icase ? CP_ICASE : 0), false, NULL);
    if (add_r == OK) {
      // If dir was BACKWARD then honor it just once.
      dir = FORWARD;
    }
  }
  FreeWild(num_matches, matches);
}

/// Make the completion list cyclic.
/// Return the number of matches (excluding the original).
static int ins_compl_make_cyclic(void)
{
  if (compl_first_match == NULL) {
    return 0;
  }

  // Find the end of the list.
  compl_T *match = compl_first_match;
  int count = 0;
  // there's always an entry for the compl_orig_text, it doesn't count.
  while (match->cp_next != NULL && !is_first_match(match->cp_next)) {
    match = match->cp_next;
    count++;
  }
  match->cp_next = compl_first_match;
  compl_first_match->cp_prev = match;

  return count;
}

/// Return whether there currently is a shown match.
bool ins_compl_has_shown_match(void)
{
  return compl_shown_match == NULL || compl_shown_match != compl_shown_match->cp_next;
}

/// Return whether the shown match is long enough.
bool ins_compl_long_shown_match(void)
{
  return compl_shown_match != NULL && compl_shown_match->cp_str != NULL
         && (colnr_T)strlen(compl_shown_match->cp_str) > curwin->w_cursor.col - compl_col;
}

/// Get the local or global value of 'completeopt' flags.
unsigned get_cot_flags(void)
{
  return curbuf->b_cot_flags != 0 ? curbuf->b_cot_flags : cot_flags;
}

/// Remove any popup menu.
static void ins_compl_del_pum(void)
{
  if (compl_match_array == NULL) {
    return;
  }

  pum_undisplay(false);
  XFREE_CLEAR(compl_match_array);
}

/// Check if the popup menu should be displayed.
bool pum_wanted(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // "completeopt" must contain "menu" or "menuone"
  return (get_cot_flags() & (kOptCotFlagMenu | kOptCotFlagMenuone)) != 0;
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
    if (comp == NULL || (!match_at_original_text(comp) && ++i == 2)) {
      break;
    }
    comp = comp->cp_next;
  } while (!is_first_match(comp));

  if (get_cot_flags() & kOptCotFlagMenuone) {
    return i >= 1;
  }
  return i >= 2;
}

/// Convert to complete item dict
static dict_T *ins_compl_dict_alloc(compl_T *match)
{
  // { word, abbr, menu, kind, info }
  dict_T *dict = tv_dict_alloc_lock(VAR_FIXED);
  tv_dict_add_str(dict, S_LEN("word"), match->cp_str);
  tv_dict_add_str(dict, S_LEN("abbr"), match->cp_text[CPT_ABBR]);
  tv_dict_add_str(dict, S_LEN("menu"), match->cp_text[CPT_MENU]);
  tv_dict_add_str(dict, S_LEN("kind"), match->cp_text[CPT_KIND]);
  tv_dict_add_str(dict, S_LEN("info"), match->cp_text[CPT_INFO]);
  if (match->cp_user_data.v_type == VAR_UNKNOWN) {
    tv_dict_add_str(dict, S_LEN("user_data"), "");
  } else {
    tv_dict_add_tv(dict, S_LEN("user_data"), &match->cp_user_data);
  }
  return dict;
}

/// Trigger the CompleteChanged autocmd event. Invoked each time the Insert mode
/// completion menu is changed.
static void trigger_complete_changed_event(int cur)
{
  static bool recursive = false;
  save_v_event_T save_v_event;

  if (recursive) {
    return;
  }

  dict_T *v_event = get_v_event(&save_v_event);
  if (cur < 0) {
    tv_dict_add_dict(v_event, S_LEN("completed_item"), tv_dict_alloc());
  } else {
    dict_T *item = ins_compl_dict_alloc(compl_curr_match);
    tv_dict_add_dict(v_event, S_LEN("completed_item"), item);
  }
  pum_set_event_info(v_event);
  tv_dict_set_keys_readonly(v_event);

  recursive = true;
  textlock++;
  apply_autocmds(EVENT_COMPLETECHANGED, NULL, NULL, false, curbuf);
  textlock--;
  recursive = false;

  restore_v_event(v_event, &save_v_event);
}

/// pumitem qsort compare func
static int ins_compl_fuzzy_cmp(const void *a, const void *b)
{
  const int sa = (*(pumitem_T *)a).pum_score;
  const int sb = (*(pumitem_T *)b).pum_score;
  const int ia = (*(pumitem_T *)a).pum_idx;
  const int ib = (*(pumitem_T *)b).pum_idx;
  return sa == sb ? (ia == ib ? 0 : (ia < ib ? -1 : 1)) : (sa < sb ? 1 : -1);
}

/// Build a popup menu to show the completion matches.
///
/// @return  the popup menu entry that should be selected,
///          -1 if nothing should be selected.
static int ins_compl_build_pum(void)
{
  // Need to build the popup menu list.
  compl_match_arraysize = 0;
  compl_T *comp = compl_first_match;

  // If it's user complete function and refresh_always,
  // do not use "compl_leader" as prefix filter.
  if (ins_compl_need_restart()) {
    XFREE_CLEAR(compl_leader);
  }

  const int lead_len = compl_leader != NULL ? (int)strlen(compl_leader) : 0;
  int max_fuzzy_score = 0;
  unsigned cur_cot_flags = get_cot_flags();
  bool compl_no_select = (cur_cot_flags & kOptCotFlagNoselect) != 0;
  bool compl_fuzzy_match = (cur_cot_flags & kOptCotFlagFuzzy) != 0;
  compl_T *match_head = NULL, *match_tail = NULL;

  // If the current match is the original text don't find the first
  // match after it, don't highlight anything.
  bool shown_match_ok = match_at_original_text(compl_shown_match);

  if (strequal(compl_leader, compl_orig_text) && !shown_match_ok) {
    compl_shown_match = compl_no_select ? compl_first_match : compl_first_match->cp_next;
  }

  bool did_find_shown_match = false;
  compl_T *shown_compl = NULL;
  int i = 0;
  int cur = -1;

  do {
    // When 'completeopt' contains "fuzzy" and leader is not NULL or empty,
    // set the cp_score for later comparisons.
    if (compl_fuzzy_match && compl_leader != NULL && lead_len > 0) {
      comp->cp_score = fuzzy_match_str(comp->cp_str, compl_leader);
    }

    if (!match_at_original_text(comp)
        && (compl_leader == NULL
            || ins_compl_equal(comp, compl_leader, (size_t)lead_len)
            || (compl_fuzzy_match && comp->cp_score > 0))) {
      compl_match_arraysize++;
      if (match_head == NULL) {
        match_head = comp;
      } else {
        match_tail->cp_match_next = comp;
      }
      match_tail = comp;
      if (!shown_match_ok && !compl_fuzzy_match) {
        if (comp == compl_shown_match || did_find_shown_match) {
          // This item is the shown match or this is the
          // first displayed item after the shown match.
          compl_shown_match = comp;
          did_find_shown_match = true;
          shown_match_ok = true;
        } else {
          // Remember this displayed match for when the
          // shown match is just below it.
          shown_compl = comp;
        }
        cur = i;
      } else if (compl_fuzzy_match) {
        if (i == 0) {
          shown_compl = comp;
        }
        // Update the maximum fuzzy score and the shown match
        // if the current item's score is higher
        if (comp->cp_score > max_fuzzy_score) {
          did_find_shown_match = true;
          max_fuzzy_score = comp->cp_score;
          if (!compl_no_select) {
            compl_shown_match = comp;
          }
        }
        if (!shown_match_ok && comp == compl_shown_match && !compl_no_select) {
          cur = i;
          shown_match_ok = true;
        }
      }
      i++;
    }

    if (comp == compl_shown_match && !compl_fuzzy_match) {
      did_find_shown_match = true;
      // When the original text is the shown match don't set
      // compl_shown_match.
      if (match_at_original_text(comp)) {
        shown_match_ok = true;
      }
      if (!shown_match_ok && shown_compl != NULL) {
        // The shown match isn't displayed, set it to the
        // previously displayed match.
        compl_shown_match = shown_compl;
        shown_match_ok = true;
      }
    }
    comp = comp->cp_next;
  } while (comp != NULL && !is_first_match(comp));

  if (compl_match_arraysize == 0) {
    return -1;
  }

  assert(compl_match_arraysize >= 0);
  compl_match_array = xcalloc((size_t)compl_match_arraysize, sizeof(pumitem_T));

  i = 0;
  comp = match_head;
  while (comp != NULL) {
    compl_match_array[i].pum_text = comp->cp_text[CPT_ABBR] != NULL
                                    ? comp->cp_text[CPT_ABBR] : comp->cp_str;
    compl_match_array[i].pum_kind = comp->cp_text[CPT_KIND];
    compl_match_array[i].pum_info = comp->cp_text[CPT_INFO];
    compl_match_array[i].pum_score = comp->cp_score;
    compl_match_array[i].pum_user_abbr_hlattr = comp->cp_user_abbr_hlattr;
    compl_match_array[i].pum_user_kind_hlattr = comp->cp_user_kind_hlattr;
    compl_match_array[i++].pum_extra = comp->cp_text[CPT_MENU] != NULL
                                       ? comp->cp_text[CPT_MENU] : comp->cp_fname;
    compl_T *match_next = comp->cp_match_next;
    comp->cp_match_next = NULL;
    comp = match_next;
  }

  if (compl_fuzzy_match && compl_leader != NULL && lead_len > 0) {
    for (i = 0; i < compl_match_arraysize; i++) {
      compl_match_array[i].pum_idx = i;
    }
    // sort by the largest score of fuzzy match
    qsort(compl_match_array, (size_t)compl_match_arraysize, sizeof(pumitem_T),
          ins_compl_fuzzy_cmp);
    shown_match_ok = true;
  }

  if (!shown_match_ok) {  // no displayed match at all
    cur = -1;
  }

  return cur;
}

/// Show the popup menu for the list of matches.
/// Also adjusts "compl_shown_match" to an entry that is actually displayed.
void ins_compl_show_pum(void)
{
  if (!pum_wanted() || !pum_enough_matches()) {
    return;
  }

  // Update the screen before drawing the popup menu over it.
  update_screen();

  int cur = -1;
  bool array_changed = false;

  if (compl_match_array == NULL) {
    array_changed = true;
    // Need to build the popup menu list.
    cur = ins_compl_build_pum();
  } else {
    // popup menu already exists, only need to find the current item.
    for (int i = 0; i < compl_match_arraysize; i++) {
      if (compl_match_array[i].pum_text == compl_shown_match->cp_str
          || compl_match_array[i].pum_text == compl_shown_match->cp_text[CPT_ABBR]) {
        cur = i;
        break;
      }
    }
  }

  if (compl_match_array == NULL) {
    if (compl_started && has_event(EVENT_COMPLETECHANGED)) {
      trigger_complete_changed_event(cur);
    }
    return;
  }

  // In Replace mode when a $ is displayed at the end of the line only
  // part of the screen would be updated.  We do need to redraw here.
  dollar_vcol = -1;

  // Compute the screen column of the start of the completed text.
  // Use the cursor to get all wrapping and other settings right.
  const colnr_T col = curwin->w_cursor.col;
  curwin->w_cursor.col = compl_col;
  compl_selected_item = cur;
  pum_display(compl_match_array, compl_match_arraysize, cur, array_changed, 0);
  curwin->w_cursor.col = col;

  // After adding leader, set the current match to shown match.
  if (compl_started && compl_curr_match != compl_shown_match) {
    compl_curr_match = compl_shown_match;
  }

  if (has_event(EVENT_COMPLETECHANGED)) {
    trigger_complete_changed_event(cur);
  }
}

/// check selected is current match.
///
/// @param selected the item which is selected.
/// @return bool    return true when is current match otherwise is false.
bool compl_match_curr_select(int selected)
{
  if (selected < 0) {
    return false;
  }
  compl_T *match = compl_first_match;
  int selected_idx = -1, list_idx = 0;
  do {
    if (!match_at_original_text(match)) {
      if (compl_curr_match != NULL
          && compl_curr_match->cp_number == match->cp_number) {
        selected_idx = list_idx;
        break;
      }
      list_idx += 1;
    }
    match = match->cp_next;
  } while (match != NULL && !is_first_match(match));

  return selected == selected_idx;
}

#define DICT_FIRST      (1)     ///< use just first element in "dict"
#define DICT_EXACT      (2)     ///< "dict" is the exact name of a file

/// Get current completion leader
char *ins_compl_leader(void)
{
  return compl_leader != NULL ? compl_leader : compl_orig_text;
}

/// Add any identifiers that match the given pattern "pat" in the list of
/// dictionary files "dict_start" to the list of completions.
///
/// @param flags      DICT_FIRST and/or DICT_EXACT
/// @param thesaurus  Thesaurus completion
static void ins_compl_dictionaries(char *dict_start, char *pat, int flags, bool thesaurus)
{
  char *dict = dict_start;
  char *ptr;
  regmatch_T regmatch;
  char **files;
  int count;
  Direction dir = compl_direction;

  if (*dict == NUL) {
    // When 'dictionary' is empty and spell checking is enabled use
    // "spell".
    if (!thesaurus && curwin->w_p_spell) {
      dict = "spell";
    } else {
      return;
    }
  }

  char *buf = xmalloc(LSIZE);
  regmatch.regprog = NULL;      // so that we can goto theend

  // If 'infercase' is set, don't use 'smartcase' here
  int save_p_scs = p_scs;
  if (curbuf->b_p_inf) {
    p_scs = false;
  }

  // When invoked to match whole lines for CTRL-X CTRL-L adjust the pattern
  // to only match at the start of a line.  Otherwise just match the
  // pattern. Also need to double backslashes.
  if (ctrl_x_mode_line_or_eval()) {
    char *pat_esc = vim_strsave_escaped(pat, "\\");

    size_t len = strlen(pat_esc) + 10;
    ptr = xmalloc(len);
    vim_snprintf(ptr, len, "^\\s*\\zs\\V%s", pat_esc);
    regmatch.regprog = vim_regcomp(ptr, RE_MAGIC);
    xfree(pat_esc);
    xfree(ptr);
  } else {
    regmatch.regprog = vim_regcomp(pat, magic_isset() ? RE_MAGIC : 0);
    if (regmatch.regprog == NULL) {
      goto theend;
    }
  }

  // ignore case depends on 'ignorecase', 'smartcase' and "pat"
  regmatch.rm_ic = ignorecase(pat);
  while (*dict != NUL && !got_int && !compl_interrupted) {
    // copy one dictionary file name into buf
    if (flags == DICT_EXACT) {
      count = 1;
      files = &dict;
    } else {
      // Expand wildcards in the dictionary name, but do not allow
      // backticks (for security, the 'dict' option may have been set in
      // a modeline).
      copy_option_part(&dict, buf, LSIZE, ",");
      if (!thesaurus && strcmp(buf, "spell") == 0) {
        count = -1;
      } else if (vim_strchr(buf, '`') != NULL
                 || expand_wildcards(1, &buf, &count, &files,
                                     EW_FILE|EW_SILENT) != OK) {
        count = 0;
      }
    }

    if (count == -1) {
      // Complete from active spelling.  Skip "\<" in the pattern, we
      // don't use it as a RE.
      if (pat[0] == '\\' && pat[1] == '<') {
        ptr = pat + 2;
      } else {
        ptr = pat;
      }
      spell_dump_compl(ptr, regmatch.rm_ic, &dir, 0);
    } else if (count > 0) {  // avoid warning for using "files" uninit
      ins_compl_files(count, files, thesaurus, flags,
                      &regmatch, buf, &dir);
      if (flags != DICT_EXACT) {
        FreeWild(count, files);
      }
    }
    if (flags != 0) {
      break;
    }
  }

theend:
  p_scs = save_p_scs;
  vim_regfree(regmatch.regprog);
  xfree(buf);
}

/// Add all the words in the line "*buf_arg" from the thesaurus file "fname"
/// skipping the word at 'skip_word'.
///
/// @return  OK on success.
static int thesaurus_add_words_in_line(char *fname, char **buf_arg, int dir, const char *skip_word)
{
  int status = OK;

  // Add the other matches on the line
  char *ptr = *buf_arg;
  while (!got_int) {
    // Find start of the next word.  Skip white
    // space and punctuation.
    ptr = find_word_start(ptr);
    if (*ptr == NUL || *ptr == NL) {
      break;
    }
    char *wstart = ptr;

    // Find end of the word.
    // Japanese words may have characters in
    // different classes, only separate words
    // with single-byte non-word characters.
    while (*ptr != NUL) {
      const int l = utfc_ptr2len(ptr);

      if (l < 2 && !vim_iswordc((uint8_t)(*ptr))) {
        break;
      }
      ptr += l;
    }

    // Add the word. Skip the regexp match.
    if (wstart != skip_word) {
      status = ins_compl_add_infercase(wstart, (int)(ptr - wstart), p_ic,
                                       fname, dir, false);
      if (status == FAIL) {
        break;
      }
    }
  }

  *buf_arg = ptr;
  return status;
}

/// Process "count" dictionary/thesaurus "files" and add the text matching
/// "regmatch".
static void ins_compl_files(int count, char **files, bool thesaurus, int flags,
                            regmatch_T *regmatch, char *buf, Direction *dir)
  FUNC_ATTR_NONNULL_ARG(2, 7)
{
  for (int i = 0; i < count && !got_int && !compl_interrupted; i++) {
    FILE *fp = os_fopen(files[i], "r");  // open dictionary file
    if (flags != DICT_EXACT && !shortmess(SHM_COMPLETIONSCAN)) {
      msg_hist_off = true;  // reset in msg_trunc()
      msg_ext_set_kind("completion");
      vim_snprintf(IObuff, IOSIZE,
                   _("Scanning dictionary: %s"), files[i]);
      msg_trunc(IObuff, true, HLF_R);
    }

    if (fp == NULL) {
      continue;
    }

    // Read dictionary file line by line.
    // Check each line for a match.
    while (!got_int && !compl_interrupted && !vim_fgets(buf, LSIZE, fp)) {
      char *ptr = buf;
      while (vim_regexec(regmatch, buf, (colnr_T)(ptr - buf))) {
        ptr = regmatch->startp[0];
        ptr = ctrl_x_mode_line_or_eval() ? find_line_end(ptr) : find_word_end(ptr);
        int add_r = ins_compl_add_infercase(regmatch->startp[0],
                                            (int)(ptr - regmatch->startp[0]),
                                            p_ic, files[i], *dir, false);
        if (thesaurus) {
          // For a thesaurus, add all the words in the line
          ptr = buf;
          add_r = thesaurus_add_words_in_line(files[i], &ptr, *dir, regmatch->startp[0]);
        }
        if (add_r == OK) {
          // if dir was BACKWARD then honor it just once
          *dir = FORWARD;
        } else if (add_r == FAIL) {
          break;
        }
        // avoid expensive call to vim_regexec() when at end
        // of line
        if (*ptr == '\n' || got_int) {
          break;
        }
      }
      line_breakcheck();
      ins_compl_check_keys(50, false);
    }
    fclose(fp);
  }
}

/// Find the start of the next word.
/// Returns a pointer to the first char of the word.  Also stops at a NUL.
char *find_word_start(char *ptr)
  FUNC_ATTR_PURE
{
  while (*ptr != NUL && *ptr != '\n' && mb_get_class(ptr) <= 1) {
    ptr += utfc_ptr2len(ptr);
  }
  return ptr;
}

/// Find the end of the word.  Assumes it starts inside a word.
/// Returns a pointer to just after the word.
char *find_word_end(char *ptr)
  FUNC_ATTR_PURE
{
  const int start_class = mb_get_class(ptr);
  if (start_class > 1) {
    while (*ptr != NUL) {
      ptr += utfc_ptr2len(ptr);
      if (mb_get_class(ptr) != start_class) {
        break;
      }
    }
  }
  return ptr;
}

/// Find the end of the line, omitting CR and NL at the end.
///
/// @return  a pointer to just after the line.
static char *find_line_end(char *ptr)
{
  char *s = ptr + strlen(ptr);
  while (s > ptr && (s[-1] == CAR || s[-1] == NL)) {
    s--;
  }
  return s;
}

/// Free the list of completions
static void ins_compl_free(void)
{
  XFREE_CLEAR(compl_pattern);
  compl_patternlen = 0;
  XFREE_CLEAR(compl_leader);

  if (compl_first_match == NULL) {
    return;
  }

  ins_compl_del_pum();
  pum_clear();

  compl_curr_match = compl_first_match;
  do {
    compl_T *match = compl_curr_match;
    compl_curr_match = compl_curr_match->cp_next;
    xfree(match->cp_str);
    // several entries may use the same fname, free it just once.
    if (match->cp_flags & CP_FREE_FNAME) {
      xfree(match->cp_fname);
    }
    free_cptext(match->cp_text);
    tv_clear(&match->cp_user_data);
    xfree(match);
  } while (compl_curr_match != NULL && !is_first_match(compl_curr_match));
  compl_first_match = compl_curr_match = NULL;
  compl_shown_match = NULL;
  compl_old_match = NULL;
}

/// Reset/clear the completion state.
void ins_compl_clear(void)
{
  compl_cont_status = 0;
  compl_started = false;
  compl_matches = 0;
  compl_ins_end_col = 0;
  XFREE_CLEAR(compl_pattern);
  compl_patternlen = 0;
  XFREE_CLEAR(compl_leader);
  edit_submode_extra = NULL;
  kv_destroy(compl_orig_extmarks);
  XFREE_CLEAR(compl_orig_text);
  compl_enter_selects = false;
  // clear v:completed_item
  set_vim_var_dict(VV_COMPLETED_ITEM, tv_dict_alloc_lock(VAR_FIXED));
}

/// Check that Insert completion is active.
bool ins_compl_active(void)
  FUNC_ATTR_PURE
{
  return compl_started;
}

/// Return true when wp is the actual completion window
bool ins_compl_win_active(win_T *wp)
{
  return ins_compl_active() && !(wp->w_p_pvw || wp->w_float_is_info);
}

/// Selected one of the matches.  When false the match was edited or using the
/// longest common string.
bool ins_compl_used_match(void)
{
  return compl_used_match;
}

/// Initialize get longest common string.
void ins_compl_init_get_longest(void)
{
  compl_get_longest = false;
}

/// Returns true when insert completion is interrupted.
bool ins_compl_interrupted(void)
{
  return compl_interrupted;
}

/// Returns true if the <Enter> key selects a match in the completion popup
/// menu.
bool ins_compl_enter_selects(void)
{
  return compl_enter_selects;
}

/// Return the column where the text starts that is being completed
colnr_T ins_compl_col(void)
{
  return compl_col;
}

/// Return the length in bytes of the text being completed
int ins_compl_len(void)
{
  return compl_length;
}

/// Delete one character before the cursor and show the subset of the matches
/// that match the word that is now before the cursor.
/// Returns the character to be used, NUL if the work is done and another char
/// to be got from the user.
int ins_compl_bs(void)
{
  char *line = get_cursor_line_ptr();
  char *p = line + curwin->w_cursor.col;
  MB_PTR_BACK(line, p);
  ptrdiff_t p_off = p - line;

  // Stop completion when the whole word was deleted.  For Omni completion
  // allow the word to be deleted, we won't match everything.
  // Respect the 'backspace' option.
  if ((int)(p - line) - (int)compl_col < 0
      || ((int)(p - line) - (int)compl_col == 0 && !ctrl_x_mode_omni())
      || ctrl_x_mode_eval()
      || (!can_bs(BS_START) && (int)(p - line) - (int)compl_col
          - compl_length < 0)) {
    return K_BS;
  }

  // Deleted more than what was used to find matches or didn't finish
  // finding all matches: need to look for matches all over again.
  if (curwin->w_cursor.col <= compl_col + compl_length
      || ins_compl_need_restart()) {
    ins_compl_restart();
  }

  // ins_compl_restart() calls update_screen() which may invalidate the pointer
  // TODO(bfredl): get rid of random update_screen() calls deep inside completion logic
  line = get_cursor_line_ptr();

  xfree(compl_leader);
  compl_leader = xstrnsave(line + compl_col, (size_t)(p_off - (ptrdiff_t)compl_col));

  ins_compl_new_leader();
  if (compl_shown_match != NULL) {
    // Make sure current match is not a hidden item.
    compl_curr_match = compl_shown_match;
  }
  return NUL;
}

/// Check if the complete function returned "always" in the "refresh" dictionary item.
static bool ins_compl_refresh_always(void)
  FUNC_ATTR_PURE
{
  return (ctrl_x_mode_function() || ctrl_x_mode_omni()) && compl_opt_refresh_always;
}

/// Check that we need to find matches again, ins_compl_restart() is to
/// be called.
static bool ins_compl_need_restart(void)
  FUNC_ATTR_PURE
{
  // Return true if we didn't complete finding matches or when the
  // "completefunc" returned "always" in the "refresh" dictionary item.
  return compl_was_interrupted || ins_compl_refresh_always();
}

/// Called after changing "compl_leader".
/// Show the popup menu with a different set of matches.
/// May also search for matches again if the previous search was interrupted.
static void ins_compl_new_leader(void)
{
  ins_compl_del_pum();
  ins_compl_delete(true);
  ins_compl_insert_bytes(compl_leader + get_compl_len(), -1);
  compl_used_match = false;

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

  // Show the popup menu with a different set of matches.
  ins_compl_show_pum();

  // Don't let Enter select the original text when there is no popup menu.
  // Don't let Enter select when use user function and refresh_always is set
  if (compl_match_array == NULL || ins_compl_refresh_always()) {
    compl_enter_selects = false;
  }
}

/// Return the length of the completion, from the completion start column to
/// the cursor column.  Making sure it never goes below zero.
static int get_compl_len(void)
{
  int off = (int)curwin->w_cursor.col - (int)compl_col;

  if (off < 0) {
    return 0;
  }
  return off;
}

/// Append one character to the match leader.  May reduce the number of
/// matches.
void ins_compl_addleader(int c)
{
  int cc;

  if (stop_arrow() == FAIL) {
    return;
  }
  if ((cc = utf_char2len(c)) > 1) {
    char buf[MB_MAXCHAR + 1];

    utf_char2bytes(c, buf);
    buf[cc] = NUL;
    ins_char_bytes(buf, (size_t)cc);
  } else {
    ins_char(c);
  }

  // If we didn't complete finding matches we must search again.
  if (ins_compl_need_restart()) {
    ins_compl_restart();
  }

  xfree(compl_leader);
  compl_leader = xstrnsave(get_cursor_line_ptr() + compl_col,
                           (size_t)(curwin->w_cursor.col - compl_col));
  ins_compl_new_leader();
}

/// Setup for finding completions again without leaving CTRL-X mode.  Used when
/// BS or a key was typed while still searching for matches.
static void ins_compl_restart(void)
{
  // update screen before restart.
  // so if complete is blocked,
  // will stay to the last popup menu and reduce flicker
  update_screen();  // TODO(bfredl): no.
  ins_compl_free();
  compl_started = false;
  compl_matches = 0;
  compl_cont_status = 0;
  compl_cont_mode = 0;
}

/// Set the first match, the original text.
static void ins_compl_set_original_text(char *str)
  FUNC_ATTR_NONNULL_ALL
{
  // Replace the original text entry.
  // The CP_ORIGINAL_TEXT flag is either at the first item or might possibly
  // be at the last item for backward completion
  if (match_at_original_text(compl_first_match)) {  // safety check
    xfree(compl_first_match->cp_str);
    compl_first_match->cp_str = xstrdup(str);
  } else if (compl_first_match->cp_prev != NULL
             && match_at_original_text(compl_first_match->cp_prev)) {
    xfree(compl_first_match->cp_prev->cp_str);
    compl_first_match->cp_prev->cp_str = xstrdup(str);
  }
}

/// Append one character to the match leader.  May reduce the number of
/// matches.
void ins_compl_addfrommatch(void)
{
  int len = (int)curwin->w_cursor.col - (int)compl_col;
  assert(compl_shown_match != NULL);
  char *p = compl_shown_match->cp_str;
  if ((int)strlen(p) <= len) {   // the match is too short
    // When still at the original match use the first entry that matches
    // the leader.
    if (!match_at_original_text(compl_shown_match)) {
      return;
    }

    p = NULL;
    for (compl_T *cp = compl_shown_match->cp_next; cp != NULL
         && !is_first_match(cp); cp = cp->cp_next) {
      if (compl_leader == NULL
          || ins_compl_equal(cp, compl_leader, strlen(compl_leader))) {
        p = cp->cp_str;
        break;
      }
    }
    if (p == NULL || (int)strlen(p) <= len) {
      return;
    }
  }
  p += len;
  int c = utf_ptr2char(p);
  ins_compl_addleader(c);
}

/// Set the CTRL-X completion mode based on the key "c" typed after a CTRL-X.
/// Uses the global variables: ctrl_x_mode, edit_submode, edit_submode_pre,
/// compl_cont_mode and compl_cont_status.
///
/// @return  true when the character is not to be inserted.
static bool set_ctrl_x_mode(const int c)
{
  bool retval = false;

  switch (c) {
  case Ctrl_E:
  case Ctrl_Y:
    // scroll the window one line up or down
    ctrl_x_mode = CTRL_X_SCROLL;
    if (!(State & REPLACE_FLAG)) {
      edit_submode = _(" (insert) Scroll (^E/^Y)");
    } else {
      edit_submode = _(" (replace) Scroll (^E/^Y)");
    }
    edit_submode_pre = NULL;
    showmode();
    break;
  case Ctrl_L:
    // complete whole line
    ctrl_x_mode = CTRL_X_WHOLE_LINE;
    break;
  case Ctrl_F:
    // complete filenames
    ctrl_x_mode = CTRL_X_FILES;
    break;
  case Ctrl_K:
    // complete words from a dictionary
    ctrl_x_mode = CTRL_X_DICTIONARY;
    break;
  case Ctrl_R:
    // Register insertion without exiting CTRL-X mode
    // Simply allow ^R to happen without affecting ^X mode
    break;
  case Ctrl_T:
    // complete words from a thesaurus
    ctrl_x_mode = CTRL_X_THESAURUS;
    break;
  case Ctrl_U:
    // user defined completion
    ctrl_x_mode = CTRL_X_FUNCTION;
    break;
  case Ctrl_O:
    // omni completion
    ctrl_x_mode = CTRL_X_OMNI;
    break;
  case 's':
  case Ctrl_S:
    // complete spelling suggestions
    ctrl_x_mode = CTRL_X_SPELL;
    emsg_off++;  // Avoid getting the E756 error twice.
    spell_back_to_badword();
    emsg_off--;
    break;
  case Ctrl_RSB:
    // complete tag names
    ctrl_x_mode = CTRL_X_TAGS;
    break;
  case Ctrl_I:
  case K_S_TAB:
    // complete keywords from included files
    ctrl_x_mode = CTRL_X_PATH_PATTERNS;
    break;
  case Ctrl_D:
    // complete definitions from included files
    ctrl_x_mode = CTRL_X_PATH_DEFINES;
    break;
  case Ctrl_V:
  case Ctrl_Q:
    // complete vim commands
    ctrl_x_mode = CTRL_X_CMDLINE;
    break;
  case Ctrl_Z:
    // stop completion
    ctrl_x_mode = CTRL_X_NORMAL;
    edit_submode = NULL;
    showmode();
    retval = true;
    break;
  case Ctrl_P:
  case Ctrl_N:
    // ^X^P means LOCAL expansion if nothing interrupted (eg we
    // just started ^X mode, or there were enough ^X's to cancel
    // the previous mode, say ^X^F^X^X^P or ^P^X^X^X^P, see below)
    // do normal expansion when interrupting a different mode (say
    // ^X^F^X^P or ^P^X^X^P, see below)
    // nothing changes if interrupting mode 0, (eg, the flag
    // doesn't change when going to ADDING mode  -- Acevedo
    if (!(compl_cont_status & CONT_INTRPT)) {
      compl_cont_status |= CONT_LOCAL;
    } else if (compl_cont_mode != 0) {
      compl_cont_status &= ~CONT_LOCAL;
    }
    FALLTHROUGH;
  default:
    // If we have typed at least 2 ^X's... for modes != 0, we set
    // compl_cont_status = 0 (eg, as if we had just started ^X
    // mode).
    // For mode 0, we set "compl_cont_mode" to an impossible
    // value, in both cases ^X^X can be used to restart the same
    // mode (avoiding ADDING mode).
    // Undocumented feature: In a mode != 0 ^X^P and ^X^X^P start
    // 'complete' and local ^P expansions respectively.
    // In mode 0 an extra ^X is needed since ^X^P goes to ADDING
    // mode  -- Acevedo
    if (c == Ctrl_X) {
      if (compl_cont_mode != 0) {
        compl_cont_status = 0;
      } else {
        compl_cont_mode = CTRL_X_NOT_DEFINED_YET;
      }
    }
    ctrl_x_mode = CTRL_X_NORMAL;
    edit_submode = NULL;
    showmode();
    break;
  }

  return retval;
}

/// Stop insert completion mode
static bool ins_compl_stop(const int c, const int prev_mode, bool retval)
{
  // Get here when we have finished typing a sequence of ^N and
  // ^P or other completion characters in CTRL-X mode.  Free up
  // memory that was used, and make sure we can redo the insert.
  if (compl_curr_match != NULL || compl_leader != NULL || c == Ctrl_E) {
    // If any of the original typed text has been changed, eg when
    // ignorecase is set, we must add back-spaces to the redo
    // buffer.  We add as few as necessary to delete just the part
    // of the original text that has changed.
    // When using the longest match, edited the match or used
    // CTRL-E then don't use the current match.
    char *ptr;
    if (compl_curr_match != NULL && compl_used_match && c != Ctrl_E) {
      ptr = compl_curr_match->cp_str;
    } else {
      ptr = NULL;
    }
    ins_compl_fixRedoBufForLeader(ptr);
  }

  bool want_cindent = (get_can_cindent() && cindent_on());

  // When completing whole lines: fix indent for 'cindent'.
  // Otherwise, break line if it's too long.
  if (compl_cont_mode == CTRL_X_WHOLE_LINE) {
    // re-indent the current line
    if (want_cindent) {
      do_c_expr_indent();
      want_cindent = false;                 // don't do it again
    }
  } else {
    const int prev_col = curwin->w_cursor.col;

    // put the cursor on the last char, for 'tw' formatting
    if (prev_col > 0) {
      dec_cursor();
    }

    // only format when something was inserted
    if (!arrow_used && !ins_need_undo_get() && c != Ctrl_E) {
      insertchar(NUL, 0, -1);
    }

    if (prev_col > 0
        && get_cursor_line_ptr()[curwin->w_cursor.col] != NUL) {
      inc_cursor();
    }
  }

  char *word = NULL;
  // If the popup menu is displayed pressing CTRL-Y means accepting
  // the selection without inserting anything.  When
  // compl_enter_selects is set the Enter key does the same.
  if ((c == Ctrl_Y || (compl_enter_selects
                       && (c == CAR || c == K_KENTER || c == NL)))
      && pum_visible()) {
    word = xstrdup(compl_shown_match->cp_str);
    retval = true;
    // May need to remove ComplMatchIns highlight.
    redrawWinline(curwin, curwin->w_cursor.lnum);
  }

  // CTRL-E means completion is Ended, go back to the typed text.
  // but only do this, if the Popup is still visible
  if (c == Ctrl_E) {
    ins_compl_delete(false);
    char *p = NULL;
    if (compl_leader != NULL) {
      p = compl_leader;
    } else if (compl_first_match != NULL) {
      p = compl_orig_text;
    }
    if (p != NULL) {
      const int compl_len = get_compl_len();
      const int len = (int)strlen(p);
      if (len > compl_len) {
        ins_compl_insert_bytes(p + compl_len, len - compl_len);
      }
    }
    restore_orig_extmarks();
    retval = true;
  }

  auto_format(false, true);

  // Trigger the CompleteDonePre event to give scripts a chance to
  // act upon the completion before clearing the info, and restore
  // ctrl_x_mode, so that complete_info() can be used.
  ctrl_x_mode = prev_mode;
  ins_apply_autocmds(EVENT_COMPLETEDONEPRE);

  ins_compl_free();
  compl_started = false;
  compl_matches = 0;
  if (!shortmess(SHM_COMPLETIONMENU)) {
    msg_clr_cmdline();  // necessary for "noshowmode"
  }
  ctrl_x_mode = CTRL_X_NORMAL;
  compl_enter_selects = false;
  if (edit_submode != NULL) {
    edit_submode = NULL;
    showmode();
  }

  if (c == Ctrl_C && cmdwin_type != 0) {
    // Avoid the popup menu remains displayed when leaving the
    // command line window.
    update_screen();
  }

  // Indent now if a key was typed that is in 'cinkeys'.
  if (want_cindent && in_cinkeys(KEY_COMPLETE, ' ', inindent(0))) {
    do_c_expr_indent();
  }
  // Trigger the CompleteDone event to give scripts a chance to act
  // upon the end of completion.
  do_autocmd_completedone(c, prev_mode, word);
  xfree(word);

  return retval;
}

/// Prepare for Insert mode completion, or stop it.
/// Called just after typing a character in Insert mode.
///
/// @param  c  character that was typed
///
/// @return true when the character is not to be inserted;
bool ins_compl_prep(int c)
{
  bool retval = false;
  const int prev_mode = ctrl_x_mode;

  // Forget any previous 'special' messages if this is actually
  // a ^X mode key - bar ^R, in which case we wait to see what it gives us.
  if (c != Ctrl_R && vim_is_ctrl_x_key(c)) {
    edit_submode_extra = NULL;
  }

  // Ignore end of Select mode mapping and mouse scroll/movement.
  if (c == K_SELECT || c == K_MOUSEDOWN || c == K_MOUSEUP
      || c == K_MOUSELEFT || c == K_MOUSERIGHT || c == K_MOUSEMOVE
      || c == K_EVENT || c == K_COMMAND || c == K_LUA) {
    return retval;
  }

  if (ctrl_x_mode == CTRL_X_CMDLINE_CTRL_X && c != Ctrl_X) {
    if (c == Ctrl_V || c == Ctrl_Q || c == Ctrl_Z || ins_compl_pum_key(c)
        || !vim_is_ctrl_x_key(c)) {
      // Not starting another completion mode.
      ctrl_x_mode = CTRL_X_CMDLINE;

      // CTRL-X CTRL-Z should stop completion without inserting anything
      if (c == Ctrl_Z) {
        retval = true;
      }
    } else {
      ctrl_x_mode = CTRL_X_CMDLINE;

      // Other CTRL-X keys first stop completion, then start another
      // completion mode.
      ins_compl_prep(' ');
      ctrl_x_mode = CTRL_X_NOT_DEFINED_YET;
    }
  }

  // Set "compl_get_longest" when finding the first matches.
  if (ctrl_x_mode_not_defined_yet()
      || (ctrl_x_mode_normal() && !compl_started)) {
    compl_get_longest = (get_cot_flags() & kOptCotFlagLongest) != 0;
    compl_used_match = true;
  }

  if (ctrl_x_mode_not_defined_yet()) {
    // We have just typed CTRL-X and aren't quite sure which CTRL-X mode
    // it will be yet.  Now we decide.
    retval = set_ctrl_x_mode(c);
  } else if (ctrl_x_mode_not_default()) {
    // We're already in CTRL-X mode, do we stay in it?
    if (!vim_is_ctrl_x_key(c)) {
      if (ctrl_x_mode_scroll()) {
        ctrl_x_mode = CTRL_X_NORMAL;
      } else {
        ctrl_x_mode = CTRL_X_FINISHED;
      }
      edit_submode = NULL;
    }
    showmode();
  }

  if (compl_started || ctrl_x_mode == CTRL_X_FINISHED) {
    // Show error message from attempted keyword completion (probably
    // 'Pattern not found') until another key is hit, then go back to
    // showing what mode we are in.
    showmode();
    if ((ctrl_x_mode_normal()
         && c != Ctrl_N
         && c != Ctrl_P
         && c != Ctrl_R
         && !ins_compl_pum_key(c))
        || ctrl_x_mode == CTRL_X_FINISHED) {
      retval = ins_compl_stop(c, prev_mode, retval);
    }
  } else if (ctrl_x_mode == CTRL_X_LOCAL_MSG) {
    // Trigger the CompleteDone event to give scripts a chance to act
    // upon the (possibly failed) completion.
    do_autocmd_completedone(c, ctrl_x_mode, NULL);
  }

  may_trigger_modechanged();

  // reset continue_* if we left expansion-mode, if we stay they'll be
  // (re)set properly in ins_complete()
  if (!vim_is_ctrl_x_key(c)) {
    compl_cont_status = 0;
    compl_cont_mode = 0;
  }

  return retval;
}

/// Fix the redo buffer for the completion leader replacing some of the typed
/// text.  This inserts backspaces and appends the changed text.
/// "ptr" is the known leader text or NUL.
static void ins_compl_fixRedoBufForLeader(char *ptr_arg)
{
  int len;
  char *ptr = ptr_arg;

  if (ptr == NULL) {
    if (compl_leader != NULL) {
      ptr = compl_leader;
    } else {
      return;        // nothing to do
    }
  }
  if (compl_orig_text != NULL) {
    char *p = compl_orig_text;
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

/// Loops through the list of windows, loaded-buffers or non-loaded-buffers
/// (depending on flag) starting from buf and looking for a non-scanned
/// buffer (other than curbuf).  curbuf is special, if it is called with
/// buf=curbuf then it has to be the first call for a given flag/expansion.
///
/// Returns the buffer to scan, if any, otherwise returns curbuf -- Acevedo
static buf_T *ins_compl_next_buf(buf_T *buf, int flag)
{
  static win_T *wp = NULL;

  if (flag == 'w') {            // just windows
    if (buf == curbuf || !win_valid(wp)) {
      // first call for this flag/expansion or window was closed
      wp = curwin;
    }
    assert(wp);
    while ((wp = (wp->w_next != NULL ? wp->w_next : firstwin)) != curwin
           && wp->w_buffer->b_scanned) {}
    buf = wp->w_buffer;
  } else {
    // 'b' (just loaded buffers), 'u' (just non-loaded buffers) or 'U'
    // (unlisted buffers)
    // When completing whole lines skip unloaded buffers.
    while ((buf = (buf->b_next != NULL ? buf->b_next : firstbuf)) != curbuf
           && ((flag == 'U'
                ? buf->b_p_bl
                : (!buf->b_p_bl
                   || (buf->b_ml.ml_mfp == NULL) != (flag == 'u')))
               || buf->b_scanned)) {}
  }
  return buf;
}

static Callback cfu_cb;    ///< 'completefunc' callback function
static Callback ofu_cb;    ///< 'omnifunc' callback function
static Callback tsrfu_cb;  ///< 'thesaurusfunc' callback function

/// Copy a global callback function to a buffer local callback.
static void copy_global_to_buflocal_cb(Callback *globcb, Callback *bufcb)
{
  callback_free(bufcb);
  if (globcb->type != kCallbackNone) {
    callback_copy(bufcb, globcb);
  }
}

/// Parse the 'completefunc' option value and set the callback function.
/// Invoked when the 'completefunc' option is set. The option value can be a
/// name of a function (string), or function(<name>) or funcref(<name>) or a
/// lambda expression.
const char *did_set_completefunc(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  if (option_set_callback_func(buf->b_p_cfu, &cfu_cb) == FAIL) {
    return e_invarg;
  }
  set_buflocal_cfu_callback(buf);
  return NULL;
}

/// Copy the global 'completefunc' callback function to the buffer-local
/// 'completefunc' callback for "buf".
void set_buflocal_cfu_callback(buf_T *buf)
{
  copy_global_to_buflocal_cb(&cfu_cb, &buf->b_cfu_cb);
}

/// Parse the 'omnifunc' option value and set the callback function.
/// Invoked when the 'omnifunc' option is set. The option value can be a
/// name of a function (string), or function(<name>) or funcref(<name>) or a
/// lambda expression.
const char *did_set_omnifunc(optset_T *args)
{
  buf_T *buf = (buf_T *)args->os_buf;
  if (option_set_callback_func(buf->b_p_ofu, &ofu_cb) == FAIL) {
    return e_invarg;
  }
  set_buflocal_ofu_callback(buf);
  return NULL;
}

/// Copy the global 'omnifunc' callback function to the buffer-local 'omnifunc'
/// callback for "buf".
void set_buflocal_ofu_callback(buf_T *buf)
{
  copy_global_to_buflocal_cb(&ofu_cb, &buf->b_ofu_cb);
}

/// Parse the 'thesaurusfunc' option value and set the callback function.
/// Invoked when the 'thesaurusfunc' option is set. The option value can be a
/// name of a function (string), or function(<name>) or funcref(<name>) or a
/// lambda expression.
const char *did_set_thesaurusfunc(optset_T *args FUNC_ATTR_UNUSED)
{
  buf_T *buf = (buf_T *)args->os_buf;
  int retval;

  if (args->os_flags & OPT_LOCAL) {
    // buffer-local option set
    retval = option_set_callback_func(buf->b_p_tsrfu, &buf->b_tsrfu_cb);
  } else {
    // global option set
    retval = option_set_callback_func(p_tsrfu, &tsrfu_cb);
    // when using :set, free the local callback
    if (!(args->os_flags & OPT_GLOBAL)) {
      callback_free(&buf->b_tsrfu_cb);
    }
  }

  return retval == FAIL ? e_invarg : NULL;
}

/// Mark the global 'completefunc' 'omnifunc' and 'thesaurusfunc' callbacks with
/// "copyID" so that they are not garbage collected.
bool set_ref_in_insexpand_funcs(int copyID)
{
  bool abort = set_ref_in_callback(&cfu_cb, copyID, NULL, NULL);
  abort = abort || set_ref_in_callback(&ofu_cb, copyID, NULL, NULL);
  abort = abort || set_ref_in_callback(&tsrfu_cb, copyID, NULL, NULL);

  return abort;
}

/// Get the user-defined completion function name for completion "type"
static char *get_complete_funcname(int type)
{
  switch (type) {
  case CTRL_X_FUNCTION:
    return curbuf->b_p_cfu;
  case CTRL_X_OMNI:
    return curbuf->b_p_ofu;
  case CTRL_X_THESAURUS:
    return *curbuf->b_p_tsrfu == NUL ? p_tsrfu : curbuf->b_p_tsrfu;
  default:
    return "";
  }
}

/// Get the callback to use for insert mode completion.
static Callback *get_insert_callback(int type)
{
  if (type == CTRL_X_FUNCTION) {
    return &curbuf->b_cfu_cb;
  }
  if (type == CTRL_X_OMNI) {
    return &curbuf->b_ofu_cb;
  }
  // CTRL_X_THESAURUS
  return (*curbuf->b_p_tsrfu != NUL) ? &curbuf->b_tsrfu_cb : &tsrfu_cb;
}

/// Execute user defined complete function 'completefunc', 'omnifunc' or
/// 'thesaurusfunc', and get matches in "matches".
///
/// @param type  either CTRL_X_OMNI or CTRL_X_FUNCTION or CTRL_X_THESAURUS
static void expand_by_function(int type, char *base)
{
  list_T *matchlist = NULL;
  dict_T *matchdict = NULL;
  typval_T rettv;
  const int save_State = State;

  assert(curbuf != NULL);
  char *funcname = get_complete_funcname(type);
  if (*funcname == NUL) {
    return;
  }

  // Call 'completefunc' to obtain the list of matches.
  typval_T args[3];
  args[0].v_type = VAR_NUMBER;
  args[1].v_type = VAR_STRING;
  args[2].v_type = VAR_UNKNOWN;
  args[0].vval.v_number = 0;
  args[1].vval.v_string = base != NULL ? base : "";

  pos_T pos = curwin->w_cursor;
  // Lock the text to avoid weird things from happening.  Also disallow
  // switching to another window, it should not be needed and may end up in
  // Insert mode in another buffer.
  textlock++;

  Callback *cb = get_insert_callback(type);

  // Call a function, which returns a list or dict.
  if (callback_call(cb, 2, args, &rettv)) {
    switch (rettv.v_type) {
    case VAR_LIST:
      matchlist = rettv.vval.v_list;
      break;
    case VAR_DICT:
      matchdict = rettv.vval.v_dict;
      break;
    case VAR_SPECIAL:
      FALLTHROUGH;
    default:
      // TODO(brammool): Give error message?
      tv_clear(&rettv);
      break;
    }
  }
  textlock--;

  curwin->w_cursor = pos;  // restore the cursor position
  check_cursor(curwin);  // make sure cursor position is valid, just in case
  validate_cursor(curwin);
  if (!equalpos(curwin->w_cursor, pos)) {
    emsg(_(e_compldel));
    goto theend;
  }

  if (matchlist != NULL) {
    ins_compl_add_list(matchlist);
  } else if (matchdict != NULL) {
    ins_compl_add_dict(matchdict);
  }

theend:
  // Restore State, it might have been changed.
  State = save_State;

  if (matchdict != NULL) {
    tv_dict_unref(matchdict);
  }
  if (matchlist != NULL) {
    tv_list_unref(matchlist);
  }
}

static inline int get_user_highlight_attr(const char *hlname)
{
  if (hlname != NULL && *hlname != NUL) {
    return syn_name2attr(hlname);
  }
  return -1;
}

/// Add a match to the list of matches from Vimscript object
///
/// @param[in]  tv  Object to get matches from.
/// @param[in]  dir  Completion direction.
/// @param[in]  fast  use fast_breakcheck() instead of os_breakcheck().
///
/// @return NOTDONE if the given string is already in the list of completions,
///         otherwise it is added to the list and  OK is returned. FAIL will be
///         returned in case of error.
static int ins_compl_add_tv(typval_T *const tv, const Direction dir, bool fast)
  FUNC_ATTR_NONNULL_ALL
{
  const char *word;
  bool dup = false;
  bool empty = false;
  int flags = fast ? CP_FAST : 0;
  char *(cptext[CPT_COUNT]);
  char *user_abbr_hlname = NULL;
  char *user_kind_hlname = NULL;
  int user_hl[2] = { -1, -1 };
  typval_T user_data;

  user_data.v_type = VAR_UNKNOWN;
  if (tv->v_type == VAR_DICT && tv->vval.v_dict != NULL) {
    word = tv_dict_get_string(tv->vval.v_dict, "word", false);
    cptext[CPT_ABBR] = tv_dict_get_string(tv->vval.v_dict, "abbr", true);
    cptext[CPT_MENU] = tv_dict_get_string(tv->vval.v_dict, "menu", true);
    cptext[CPT_KIND] = tv_dict_get_string(tv->vval.v_dict, "kind", true);
    cptext[CPT_INFO] = tv_dict_get_string(tv->vval.v_dict, "info", true);

    user_abbr_hlname = tv_dict_get_string(tv->vval.v_dict, "abbr_hlgroup", false);
    user_hl[0] = get_user_highlight_attr(user_abbr_hlname);

    user_kind_hlname = tv_dict_get_string(tv->vval.v_dict, "kind_hlgroup", false);
    user_hl[1] = get_user_highlight_attr(user_kind_hlname);

    tv_dict_get_tv(tv->vval.v_dict, "user_data", &user_data);

    if (tv_dict_get_number(tv->vval.v_dict, "icase")) {
      flags |= CP_ICASE;
    }
    dup = (bool)tv_dict_get_number(tv->vval.v_dict, "dup");
    empty = (bool)tv_dict_get_number(tv->vval.v_dict, "empty");
    if (tv_dict_get_string(tv->vval.v_dict, "equal", false) != NULL
        && tv_dict_get_number(tv->vval.v_dict, "equal")) {
      flags |= CP_EQUAL;
    }
  } else {
    word = tv_get_string_chk(tv);
    CLEAR_FIELD(cptext);
  }
  if (word == NULL || (!empty && *word == NUL)) {
    free_cptext(cptext);
    tv_clear(&user_data);
    return FAIL;
  }
  int status = ins_compl_add((char *)word, -1, NULL, cptext, true,
                             &user_data, dir, flags, dup, user_hl);
  if (status != OK) {
    tv_clear(&user_data);
  }
  return status;
}

/// Add completions from a list.
static void ins_compl_add_list(list_T *const list)
{
  Direction dir = compl_direction;

  // Go through the List with matches and add each of them.
  TV_LIST_ITER(list, li, {
    if (ins_compl_add_tv(TV_LIST_ITEM_TV(li), dir, true) == OK) {
      // If dir was BACKWARD then honor it just once.
      dir = FORWARD;
    } else if (did_emsg) {
      break;
    }
  });
}

/// Add completions from a dict.
static void ins_compl_add_dict(dict_T *dict)
{
  // Check for optional "refresh" item.
  compl_opt_refresh_always = false;
  dictitem_T *di_refresh = tv_dict_find(dict, S_LEN("refresh"));
  if (di_refresh != NULL && di_refresh->di_tv.v_type == VAR_STRING) {
    const char *v = di_refresh->di_tv.vval.v_string;

    if (v != NULL && strcmp(v, "always") == 0) {
      compl_opt_refresh_always = true;
    }
  }

  // Add completions from a "words" list.
  dictitem_T *di_words = tv_dict_find(dict, S_LEN("words"));
  if (di_words != NULL && di_words->di_tv.v_type == VAR_LIST) {
    ins_compl_add_list(di_words->di_tv.vval.v_list);
  }
}

/// Save extmarks in "compl_orig_text" so that they may be restored when the
/// completion is cancelled, or the original text is completed.
static void save_orig_extmarks(void)
{
  extmark_splice_delete(curbuf, curwin->w_cursor.lnum - 1, compl_col, curwin->w_cursor.lnum - 1,
                        compl_col + compl_length, &compl_orig_extmarks, true, kExtmarkUndo);
}

static void restore_orig_extmarks(void)
{
  for (long i = (int)kv_size(compl_orig_extmarks) - 1; i > -1; i--) {
    ExtmarkUndoObject undo_info = kv_A(compl_orig_extmarks, i);
    extmark_apply_undo(undo_info, true);
  }
}

/// Start completion for the complete() function.
///
/// @param startcol  where the matched text starts (1 is first column).
/// @param list      the list of matches.
static void set_completion(colnr_T startcol, list_T *list)
{
  int flags = CP_ORIGINAL_TEXT;
  unsigned cur_cot_flags = get_cot_flags();
  bool compl_longest = (cur_cot_flags & kOptCotFlagLongest) != 0;
  bool compl_no_insert = (cur_cot_flags & kOptCotFlagNoinsert) != 0;
  bool compl_no_select = (cur_cot_flags & kOptCotFlagNoselect) != 0;

  // If already doing completions stop it.
  if (ctrl_x_mode_not_default()) {
    ins_compl_prep(' ');
  }
  ins_compl_clear();
  ins_compl_free();
  compl_get_longest = compl_longest;

  compl_direction = FORWARD;
  if (startcol > curwin->w_cursor.col) {
    startcol = curwin->w_cursor.col;
  }
  compl_col = startcol;
  compl_length = curwin->w_cursor.col - startcol;
  // compl_pattern doesn't need to be set
  compl_orig_text = xstrnsave(get_cursor_line_ptr() + compl_col, (size_t)compl_length);
  save_orig_extmarks();
  if (p_ic) {
    flags |= CP_ICASE;
  }
  if (ins_compl_add(compl_orig_text, -1, NULL, NULL, false, NULL, 0,
                    flags | CP_FAST, false, NULL) != OK) {
    return;
  }

  ctrl_x_mode = CTRL_X_EVAL;

  ins_compl_add_list(list);
  compl_matches = ins_compl_make_cyclic();
  compl_started = true;
  compl_used_match = true;
  compl_cont_status = 0;
  int save_w_wrow = curwin->w_wrow;
  int save_w_leftcol = curwin->w_leftcol;

  compl_curr_match = compl_first_match;
  bool no_select = compl_no_select || compl_longest;
  if (compl_no_insert || no_select) {
    ins_complete(K_DOWN, false);
    if (no_select) {
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

  may_trigger_modechanged();
  ui_flush();
}

/// "complete()" function
void f_complete(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if ((State & MODE_INSERT) == 0) {
    emsg(_("E785: complete() can only be used in Insert mode"));
    return;
  }

  // Check for undo allowed here, because if something was already inserted
  // the line was already saved for undo and this check isn't done.
  if (!undo_allowed(curbuf)) {
    return;
  }

  if (argvars[1].v_type != VAR_LIST) {
    emsg(_(e_invarg));
  } else {
    const colnr_T startcol = (colnr_T)tv_get_number_chk(&argvars[0], NULL);
    if (startcol > 0) {
      set_completion(startcol - 1, argvars[1].vval.v_list);
    }
  }
}

/// "complete_add()" function
void f_complete_add(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->vval.v_number = ins_compl_add_tv(&argvars[0], 0, false);
}

/// "complete_check()" function
void f_complete_check(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int saved = RedrawingDisabled;

  RedrawingDisabled = 0;
  ins_compl_check_keys(0, true);
  rettv->vval.v_number = ins_compl_interrupted();
  RedrawingDisabled = saved;
}

/// Return Insert completion mode name string
static char *ins_compl_mode(void)
{
  if (ctrl_x_mode_not_defined_yet() || ctrl_x_mode_scroll() || compl_started) {
    return ctrl_x_mode_names[ctrl_x_mode & ~CTRL_X_WANT_IDENT];
  }
  return "";
}

/// Assign the sequence number to all the completion matches which don't have
/// one assigned yet.
static void ins_compl_update_sequence_numbers(void)
{
  int number = 0;
  compl_T *match;

  if (compl_dir_forward()) {
    // Search backwards for the first valid (!= -1) number.
    // This should normally succeed already at the first loop
    // cycle, so it's fast!
    for (match = compl_curr_match->cp_prev;
         match != NULL && !is_first_match(match); match = match->cp_prev) {
      if (match->cp_number != -1) {
        number = match->cp_number;
        break;
      }
    }
    if (match != NULL) {
      // go up and assign all numbers which are not assigned yet
      for (match = match->cp_next;
           match != NULL && match->cp_number == -1;
           match = match->cp_next) {
        match->cp_number = ++number;
      }
    }
  } else {  // BACKWARD
    assert(compl_direction == BACKWARD);
    // Search forwards (upwards) for the first valid (!= -1)
    // number.  This should normally succeed already at the
    // first loop cycle, so it's fast!
    for (match = compl_curr_match->cp_next;
         match != NULL && !is_first_match(match); match = match->cp_next) {
      if (match->cp_number != -1) {
        number = match->cp_number;
        break;
      }
    }
    if (match != NULL) {
      // go down and assign all numbers which are not assigned yet
      for (match = match->cp_prev;
           match && match->cp_number == -1;
           match = match->cp_prev) {
        match->cp_number = ++number;
      }
    }
  }
}

/// Get complete information
static void get_complete_info(list_T *what_list, dict_T *retdict)
{
#define CI_WHAT_MODE            0x01
#define CI_WHAT_PUM_VISIBLE     0x02
#define CI_WHAT_ITEMS           0x04
#define CI_WHAT_SELECTED        0x08
#define CI_WHAT_INSERTED        0x10
#define CI_WHAT_ALL             0xff
  int what_flag;

  if (what_list == NULL) {
    what_flag = CI_WHAT_ALL;
  } else {
    what_flag = 0;
    for (listitem_T *item = tv_list_first(what_list)
         ; item != NULL
         ; item = TV_LIST_ITEM_NEXT(what_list, item)) {
      const char *what = tv_get_string(TV_LIST_ITEM_TV(item));

      if (strcmp(what, "mode") == 0) {
        what_flag |= CI_WHAT_MODE;
      } else if (strcmp(what, "pum_visible") == 0) {
        what_flag |= CI_WHAT_PUM_VISIBLE;
      } else if (strcmp(what, "items") == 0) {
        what_flag |= CI_WHAT_ITEMS;
      } else if (strcmp(what, "selected") == 0) {
        what_flag |= CI_WHAT_SELECTED;
      } else if (strcmp(what, "inserted") == 0) {
        what_flag |= CI_WHAT_INSERTED;
      }
    }
  }

  int ret = OK;
  if (what_flag & CI_WHAT_MODE) {
    ret = tv_dict_add_str(retdict, S_LEN("mode"), ins_compl_mode());
  }

  if (ret == OK && (what_flag & CI_WHAT_PUM_VISIBLE)) {
    ret = tv_dict_add_nr(retdict, S_LEN("pum_visible"), pum_visible());
  }

  if (ret == OK && (what_flag & CI_WHAT_ITEMS || what_flag & CI_WHAT_SELECTED)) {
    list_T *li = NULL;
    int selected_idx = -1;
    if (what_flag & CI_WHAT_ITEMS) {
      li = tv_list_alloc(kListLenMayKnow);
      ret = tv_dict_add_list(retdict, S_LEN("items"), li);
    }
    if (ret == OK && what_flag & CI_WHAT_SELECTED) {
      if (compl_curr_match != NULL && compl_curr_match->cp_number == -1) {
        ins_compl_update_sequence_numbers();
      }
    }
    if (ret == OK && compl_first_match != NULL) {
      int list_idx = 0;
      compl_T *match = compl_first_match;
      do {
        if (!match_at_original_text(match)) {
          if (what_flag & CI_WHAT_ITEMS) {
            dict_T *di = tv_dict_alloc();
            tv_list_append_dict(li, di);
            tv_dict_add_str(di, S_LEN("word"), match->cp_str);
            tv_dict_add_str(di, S_LEN("abbr"), match->cp_text[CPT_ABBR]);
            tv_dict_add_str(di, S_LEN("menu"), match->cp_text[CPT_MENU]);
            tv_dict_add_str(di, S_LEN("kind"), match->cp_text[CPT_KIND]);
            tv_dict_add_str(di, S_LEN("info"), match->cp_text[CPT_INFO]);
            if (match->cp_user_data.v_type == VAR_UNKNOWN) {
              // Add an empty string for backwards compatibility
              tv_dict_add_str(di, S_LEN("user_data"), "");
            } else {
              tv_dict_add_tv(di, S_LEN("user_data"), &match->cp_user_data);
            }
          }
          if (compl_curr_match != NULL
              && compl_curr_match->cp_number == match->cp_number) {
            selected_idx = list_idx;
          }
          list_idx += 1;
        }
        match = match->cp_next;
      } while (match != NULL && !is_first_match(match));
    }
    if (ret == OK && (what_flag & CI_WHAT_SELECTED)) {
      ret = tv_dict_add_nr(retdict, S_LEN("selected"), selected_idx);
      win_T *wp = win_float_find_preview();
      if (wp != NULL) {
        tv_dict_add_nr(retdict, S_LEN("preview_winid"), wp->handle);
        tv_dict_add_nr(retdict, S_LEN("preview_bufnr"), wp->w_buffer->handle);
      }
    }
  }

  (void)ret;
  // TODO(vim):
  // if (ret == OK && (what_flag & CI_WHAT_INSERTED))
}

/// "complete_info()" function
void f_complete_info(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_dict_alloc_ret(rettv);

  list_T *what_list = NULL;

  if (argvars[0].v_type != VAR_UNKNOWN) {
    if (argvars[0].v_type != VAR_LIST) {
      emsg(_(e_listreq));
      return;
    }
    what_list = argvars[0].vval.v_list;
  }
  get_complete_info(what_list, rettv->vval.v_dict);
}

/// Returns true when using a user-defined function for thesaurus completion.
static bool thesaurus_func_complete(int type)
{
  return type == CTRL_X_THESAURUS
         && (*curbuf->b_p_tsrfu != NUL || *p_tsrfu != NUL);
}

/// Return value of process_next_cpt_value()
enum {
  INS_COMPL_CPT_OK = 1,
  INS_COMPL_CPT_CONT,
  INS_COMPL_CPT_END,
};

/// Process the next 'complete' option value in st->e_cpt.
///
/// If successful, the arguments are set as below:
///   st->cpt - pointer to the next option value in "st->cpt"
///   compl_type_arg - type of insert mode completion to use
///   st->found_all - all matches of this type are found
///   st->ins_buf - search for completions in this buffer
///   st->first_match_pos - position of the first completion match
///   st->last_match_pos - position of the last completion match
///   st->set_match_pos - true if the first match position should be saved to
///                       avoid loops after the search wraps around.
///   st->dict - name of the dictionary or thesaurus file to search
///   st->dict_f - flag specifying whether "dict" is an exact file name or not
///
/// @return  INS_COMPL_CPT_OK if the next value is processed successfully.
///          INS_COMPL_CPT_CONT to skip the current completion source matching
///          the "st->e_cpt" option value and process the next matching source.
///          INS_COMPL_CPT_END if all the values in "st->e_cpt" are processed.
static int process_next_cpt_value(ins_compl_next_state_T *st, int *compl_type_arg,
                                  pos_T *start_match_pos)
{
  int compl_type = -1;
  int status = INS_COMPL_CPT_OK;

  st->found_all = false;

  while (*st->e_cpt == ',' || *st->e_cpt == ' ') {
    st->e_cpt++;
  }

  if (*st->e_cpt == '.' && !curbuf->b_scanned) {
    st->ins_buf = curbuf;
    st->first_match_pos = *start_match_pos;
    // Move the cursor back one character so that ^N can match the
    // word immediately after the cursor.
    if (ctrl_x_mode_normal() && dec(&st->first_match_pos) < 0) {
      // Move the cursor to after the last character in the
      // buffer, so that word at start of buffer is found
      // correctly.
      st->first_match_pos.lnum = st->ins_buf->b_ml.ml_line_count;
      st->first_match_pos.col = ml_get_len(st->first_match_pos.lnum);
    }
    st->last_match_pos = st->first_match_pos;
    compl_type = 0;

    // Remember the first match so that the loop stops when we
    // wrap and come back there a second time.
    st->set_match_pos = true;
  } else if (vim_strchr("buwU", (uint8_t)(*st->e_cpt)) != NULL
             && (st->ins_buf = ins_compl_next_buf(st->ins_buf, *st->e_cpt)) != curbuf) {
    // Scan a buffer, but not the current one.
    if (st->ins_buf->b_ml.ml_mfp != NULL) {  // loaded buffer
      compl_started = true;
      st->first_match_pos.col = st->last_match_pos.col = 0;
      st->first_match_pos.lnum = st->ins_buf->b_ml.ml_line_count + 1;
      st->last_match_pos.lnum = 0;
      compl_type = 0;
    } else {  // unloaded buffer, scan like dictionary
      st->found_all = true;
      if (st->ins_buf->b_fname == NULL) {
        status = INS_COMPL_CPT_CONT;
        goto done;
      }
      compl_type = CTRL_X_DICTIONARY;
      st->dict = st->ins_buf->b_fname;
      st->dict_f = DICT_EXACT;
    }
    if (!shortmess(SHM_COMPLETIONSCAN)) {
      msg_hist_off = true;  // reset in msg_trunc()
      msg_ext_set_kind("completion");
      vim_snprintf(IObuff, IOSIZE, _("Scanning: %s"),
                   st->ins_buf->b_fname == NULL
                   ? buf_spname(st->ins_buf)
                   : st->ins_buf->b_sfname == NULL
                   ? st->ins_buf->b_fname
                   : st->ins_buf->b_sfname);
      msg_trunc(IObuff, true, HLF_R);
    }
  } else if (*st->e_cpt == NUL) {
    status = INS_COMPL_CPT_END;
  } else {
    if (ctrl_x_mode_line_or_eval()) {
      // compl_type = -1;
    } else if (*st->e_cpt == 'k' || *st->e_cpt == 's') {
      if (*st->e_cpt == 'k') {
        compl_type = CTRL_X_DICTIONARY;
      } else {
        compl_type = CTRL_X_THESAURUS;
      }
      if (*++st->e_cpt != ',' && *st->e_cpt != NUL) {
        st->dict = st->e_cpt;
        st->dict_f = DICT_FIRST;
      }
    } else if (*st->e_cpt == 'i') {
      compl_type = CTRL_X_PATH_PATTERNS;
    } else if (*st->e_cpt == 'd') {
      compl_type = CTRL_X_PATH_DEFINES;
    } else if (*st->e_cpt == 'f') {
      compl_type = CTRL_X_BUFNAMES;
    } else if (*st->e_cpt == ']' || *st->e_cpt == 't') {
      compl_type = CTRL_X_TAGS;
      if (!shortmess(SHM_COMPLETIONSCAN)) {
        msg_ext_set_kind("completion");
        msg_hist_off = true;  // reset in msg_trunc()
        vim_snprintf(IObuff, IOSIZE, "%s", _("Scanning tags."));
        msg_trunc(IObuff, true, HLF_R);
      }
    }

    // in any case e_cpt is advanced to the next entry
    copy_option_part(&st->e_cpt, IObuff, IOSIZE, ",");

    st->found_all = true;
    if (compl_type == -1) {
      status = INS_COMPL_CPT_CONT;
    }
  }

done:
  *compl_type_arg = compl_type;
  return status;
}

/// Get the next set of identifiers or defines matching "compl_pattern" in
/// included files.
static void get_next_include_file_completion(int compl_type)
{
  find_pattern_in_path(compl_pattern, compl_direction,
                       compl_patternlen, false, false,
                       ((compl_type == CTRL_X_PATH_DEFINES
                         && !(compl_cont_status & CONT_SOL))
                        ? FIND_DEFINE : FIND_ANY),
                       1, ACTION_EXPAND, 1, MAXLNUM, false);
}

/// Get the next set of words matching "compl_pattern" in dictionary or
/// thesaurus files.
static void get_next_dict_tsr_completion(int compl_type, char *dict, int dict_f)
{
  if (thesaurus_func_complete(compl_type)) {
    expand_by_function(compl_type, compl_pattern);
  } else {
    ins_compl_dictionaries(dict != NULL
                           ? dict
                           : (compl_type == CTRL_X_THESAURUS
                              ? (*curbuf->b_p_tsr == NUL ? p_tsr : curbuf->b_p_tsr)
                              : (*curbuf->b_p_dict == NUL ? p_dict : curbuf->b_p_dict)),
                           compl_pattern,
                           dict != NULL ? dict_f : 0,
                           compl_type == CTRL_X_THESAURUS);
  }
}

/// Get the next set of tag names matching "compl_pattern".
static void get_next_tag_completion(void)
{
  // set p_ic according to p_ic, p_scs and pat for find_tags().
  const int save_p_ic = p_ic;
  p_ic = ignorecase(compl_pattern);

  // Find up to TAG_MANY matches.  Avoids that an enormous number
  // of matches is found when compl_pattern is empty
  g_tag_at_cursor = true;
  char **matches;
  int num_matches;
  if (find_tags(compl_pattern, &num_matches, &matches,
                TAG_REGEXP | TAG_NAMES | TAG_NOIC | TAG_INS_COMP
                | (ctrl_x_mode_not_default() ? TAG_VERBOSE : 0),
                TAG_MANY, curbuf->b_ffname) == OK && num_matches > 0) {
    ins_compl_add_matches(num_matches, matches, p_ic);
  }
  g_tag_at_cursor = false;
  p_ic = save_p_ic;
}

/// Get the next set of filename matching "compl_pattern".
static void get_next_filename_completion(void)
{
  char **matches;
  int num_matches;
  if (expand_wildcards(1, &compl_pattern, &num_matches, &matches,
                       EW_FILE|EW_DIR|EW_ADDSLASH|EW_SILENT) != OK) {
    return;
  }

  // May change home directory back to "~".
  tilde_replace(compl_pattern, num_matches, matches);
#ifdef BACKSLASH_IN_FILENAME
  if (curbuf->b_p_csl[0] != NUL) {
    for (int i = 0; i < num_matches; i++) {
      char *ptr = matches[i];
      while (*ptr != NUL) {
        if (curbuf->b_p_csl[0] == 's' && *ptr == '\\') {
          *ptr = '/';
        } else if (curbuf->b_p_csl[0] == 'b' && *ptr == '/') {
          *ptr = '\\';
        }
        ptr += utfc_ptr2len(ptr);
      }
    }
  }
#endif
  ins_compl_add_matches(num_matches, matches, p_fic || p_wic);
}

/// Get the next set of command-line completions matching "compl_pattern".
static void get_next_cmdline_completion(void)
{
  char **matches;
  int num_matches;
  if (expand_cmdline(&compl_xp, compl_pattern,
                     (int)compl_patternlen, &num_matches, &matches) == EXPAND_OK) {
    ins_compl_add_matches(num_matches, matches, false);
  }
}

/// Get the next set of spell suggestions matching "compl_pattern".
static void get_next_spell_completion(linenr_T lnum)
{
  char **matches;
  int num_matches = expand_spelling(lnum, compl_pattern, &matches);
  if (num_matches > 0) {
    ins_compl_add_matches(num_matches, matches, p_ic);
  } else {
    xfree(matches);
  }
}

/// Return the next word or line from buffer "ins_buf" at position
/// "cur_match_pos" for completion.  The length of the match is set in "len".
/// @param ins_buf        buffer being scanned
/// @param cur_match_pos  current match position
/// @param match_len
/// @param cont_s_ipos    next ^X<> will set initial_pos
static char *ins_compl_get_next_word_or_line(buf_T *ins_buf, pos_T *cur_match_pos, int *match_len,
                                             bool *cont_s_ipos)
{
  *match_len = 0;
  char *ptr = ml_get_buf(ins_buf, cur_match_pos->lnum) + cur_match_pos->col;
  int len;
  if (ctrl_x_mode_line_or_eval()) {
    if (compl_status_adding()) {
      if (cur_match_pos->lnum >= ins_buf->b_ml.ml_line_count) {
        return NULL;
      }
      ptr = ml_get_buf(ins_buf, cur_match_pos->lnum + 1);
      if (!p_paste) {
        ptr = skipwhite(ptr);
      }
    }
    len = (int)strlen(ptr);
  } else {
    char *tmp_ptr = ptr;

    if (compl_status_adding() && compl_length <= (int)strlen(tmp_ptr)) {
      tmp_ptr += compl_length;
      // Skip if already inside a word.
      if (vim_iswordp(tmp_ptr)) {
        return NULL;
      }
      // Find start of next word.
      tmp_ptr = find_word_start(tmp_ptr);
    }
    // Find end of this word.
    tmp_ptr = find_word_end(tmp_ptr);
    len = (int)(tmp_ptr - ptr);

    if (compl_status_adding() && len == compl_length) {
      if (cur_match_pos->lnum < ins_buf->b_ml.ml_line_count) {
        // Try next line, if any. the new word will be "join" as if the
        // normal command "J" was used. IOSIZE is always greater than
        // compl_length, so the next strncpy always works -- Acevedo
        strncpy(IObuff, ptr, (size_t)len);  // NOLINT(runtime/printf)
        ptr = ml_get_buf(ins_buf, cur_match_pos->lnum + 1);
        tmp_ptr = ptr = skipwhite(ptr);
        // Find start of next word.
        tmp_ptr = find_word_start(tmp_ptr);
        // Find end of next word.
        tmp_ptr = find_word_end(tmp_ptr);
        if (tmp_ptr > ptr) {
          if (*ptr != ')' && IObuff[len - 1] != TAB) {
            if (IObuff[len - 1] != ' ') {
              IObuff[len++] = ' ';
            }
            // IObuf =~ "\k.* ", thus len >= 2
            if (p_js
                && (IObuff[len - 2] == '.'
                    || IObuff[len - 2] == '?'
                    || IObuff[len - 2] == '!')) {
              IObuff[len++] = ' ';
            }
          }
          // copy as much as possible of the new word
          if (tmp_ptr - ptr >= IOSIZE - len) {
            tmp_ptr = ptr + IOSIZE - len - 1;
          }
          xstrlcpy(IObuff + len, ptr, (size_t)(IOSIZE - len));
          len += (int)(tmp_ptr - ptr);
          *cont_s_ipos = true;
        }
        IObuff[len] = NUL;
        ptr = IObuff;
      }
      if (len == compl_length) {
        return NULL;
      }
    }
  }

  *match_len = len;
  return ptr;
}

/// Get the next set of words matching "compl_pattern" for default completion(s)
/// (normal ^P/^N and ^X^L).
/// Search for "compl_pattern" in the buffer "st->ins_buf" starting from the
/// position "st->start_pos" in the "compl_direction" direction. If
/// "st->set_match_pos" is true, then set the "st->first_match_pos" and
/// "st->last_match_pos".
///
/// @return  OK if a new next match is found, otherwise FAIL.
static int get_next_default_completion(ins_compl_next_state_T *st, pos_T *start_pos)
{
  // If 'infercase' is set, don't use 'smartcase' here
  const int save_p_scs = p_scs;
  assert(st->ins_buf);
  if (st->ins_buf->b_p_inf) {
    p_scs = false;
  }

  // Buffers other than curbuf are scanned from the beginning or the
  // end but never from the middle, thus setting nowrapscan in this
  // buffers is a good idea, on the other hand, we always set
  // wrapscan for curbuf to avoid missing matches -- Acevedo,Webb
  const int save_p_ws = p_ws;
  if (st->ins_buf != curbuf) {
    p_ws = false;
  } else if (*st->e_cpt == '.') {
    p_ws = true;
  }
  bool looped_around = false;
  int found_new_match = FAIL;
  while (true) {
    bool cont_s_ipos = false;

    msg_silent++;  // Don't want messages for wrapscan.
    // ctrl_x_mode_line_or_eval() || word-wise search that
    // has added a word that was at the beginning of the line.
    if (ctrl_x_mode_line_or_eval() || (compl_cont_status & CONT_SOL)) {
      found_new_match = search_for_exact_line(st->ins_buf, st->cur_match_pos,
                                              compl_direction, compl_pattern);
    } else {
      found_new_match = searchit(NULL, st->ins_buf, st->cur_match_pos,
                                 NULL, compl_direction, compl_pattern, compl_patternlen,
                                 1, SEARCH_KEEP + SEARCH_NFMSG, RE_LAST, NULL);
    }
    msg_silent--;
    if (!compl_started || st->set_match_pos) {
      // set "compl_started" even on fail
      compl_started = true;
      st->first_match_pos = *st->cur_match_pos;
      st->last_match_pos = *st->cur_match_pos;
      st->set_match_pos = false;
    } else if (st->first_match_pos.lnum == st->last_match_pos.lnum
               && st->first_match_pos.col == st->last_match_pos.col) {
      found_new_match = FAIL;
    } else if (compl_dir_forward()
               && (st->prev_match_pos.lnum > st->cur_match_pos->lnum
                   || (st->prev_match_pos.lnum == st->cur_match_pos->lnum
                       && st->prev_match_pos.col >= st->cur_match_pos->col))) {
      if (looped_around) {
        found_new_match = FAIL;
      } else {
        looped_around = true;
      }
    } else if (!compl_dir_forward()
               && (st->prev_match_pos.lnum < st->cur_match_pos->lnum
                   || (st->prev_match_pos.lnum == st->cur_match_pos->lnum
                       && st->prev_match_pos.col <= st->cur_match_pos->col))) {
      if (looped_around) {
        found_new_match = FAIL;
      } else {
        looped_around = true;
      }
    }
    st->prev_match_pos = *st->cur_match_pos;
    if (found_new_match == FAIL) {
      break;
    }

    // when ADDING, the text before the cursor matches, skip it
    if (compl_status_adding() && st->ins_buf == curbuf
        && start_pos->lnum == st->cur_match_pos->lnum
        && start_pos->col == st->cur_match_pos->col) {
      continue;
    }
    int len;
    char *ptr = ins_compl_get_next_word_or_line(st->ins_buf, st->cur_match_pos,
                                                &len, &cont_s_ipos);
    if (ptr == NULL) {
      continue;
    }
    if (ins_compl_add_infercase(ptr, len, p_ic,
                                st->ins_buf == curbuf ? NULL : st->ins_buf->b_sfname,
                                0, cont_s_ipos) != NOTDONE) {
      found_new_match = OK;
      break;
    }
  }
  p_scs = save_p_scs;
  p_ws = save_p_ws;

  return found_new_match;
}

/// get the next set of completion matches for "type".
/// @return  true if a new match is found, otherwise false.
static bool get_next_completion_match(int type, ins_compl_next_state_T *st, pos_T *ini)
{
  int found_new_match = FAIL;

  switch (type) {
  case -1:
    break;
  case CTRL_X_PATH_PATTERNS:
  case CTRL_X_PATH_DEFINES:
    get_next_include_file_completion(type);
    break;

  case CTRL_X_DICTIONARY:
  case CTRL_X_THESAURUS:
    get_next_dict_tsr_completion(type, st->dict, st->dict_f);
    st->dict = NULL;
    break;

  case CTRL_X_TAGS:
    get_next_tag_completion();
    break;

  case CTRL_X_FILES:
    get_next_filename_completion();
    break;

  case CTRL_X_CMDLINE:
  case CTRL_X_CMDLINE_CTRL_X:
    get_next_cmdline_completion();
    break;

  case CTRL_X_FUNCTION:
  case CTRL_X_OMNI:
    expand_by_function(type, compl_pattern);
    break;

  case CTRL_X_SPELL:
    get_next_spell_completion(st->first_match_pos.lnum);
    break;
  case CTRL_X_BUFNAMES:
    get_next_bufname_token();
    break;

  default:            // normal ^P/^N and ^X^L
    found_new_match = get_next_default_completion(st, ini);
    if (found_new_match == FAIL && st->ins_buf == curbuf) {
      st->found_all = true;
    }
  }

  // check if compl_curr_match has changed, (e.g. other type of
  // expansion added something)
  if (type != 0 && compl_curr_match != compl_old_match) {
    found_new_match = OK;
  }

  return found_new_match;
}

static void get_next_bufname_token(void)
{
  FOR_ALL_BUFFERS(b) {
    if (b->b_p_bl && b->b_sfname != NULL) {
      char *tail = path_tail(b->b_sfname);
      if (strncmp(tail, compl_orig_text, strlen(compl_orig_text)) == 0) {
        ins_compl_add(tail, (int)strlen(tail), NULL, NULL, false, NULL, 0,
                      p_ic ? CP_ICASE : 0, false, NULL);
      }
    }
  }
}

/// Get the next expansion(s), using "compl_pattern".
/// The search starts at position "ini" in curbuf and in the direction
/// compl_direction.
/// When "compl_started" is false start at that position, otherwise continue
/// where we stopped searching before.
/// This may return before finding all the matches.
/// Return the total number of matches or -1 if still unknown -- Acevedo
static int ins_compl_get_exp(pos_T *ini)
{
  static ins_compl_next_state_T st;
  static bool st_cleared = false;
  int found_new_match;
  int type = ctrl_x_mode;

  assert(curbuf != NULL);

  if (!compl_started) {
    FOR_ALL_BUFFERS(buf) {
      buf->b_scanned = false;
    }
    if (!st_cleared) {
      CLEAR_FIELD(st);
      st_cleared = true;
    }
    st.found_all = false;
    st.ins_buf = curbuf;
    xfree(st.e_cpt_copy);
    // Make a copy of 'complete', in case the buffer is wiped out.
    st.e_cpt_copy = xstrdup((compl_cont_status & CONT_LOCAL) ? "." : curbuf->b_p_cpt);
    st.e_cpt = st.e_cpt_copy;
    st.last_match_pos = st.first_match_pos = *ini;
  } else if (st.ins_buf != curbuf && !buf_valid(st.ins_buf)) {
    st.ins_buf = curbuf;  // In case the buffer was wiped out.
  }
  assert(st.ins_buf != NULL);

  compl_old_match = compl_curr_match;   // remember the last current match
  st.cur_match_pos = compl_dir_forward() ? &st.last_match_pos : &st.first_match_pos;

  // For ^N/^P loop over all the flags/windows/buffers in 'complete'
  while (true) {
    found_new_match = FAIL;
    st.set_match_pos = false;

    // For ^N/^P pick a new entry from e_cpt if compl_started is off,
    // or if found_all says this entry is done.  For ^X^L only use the
    // entries from 'complete' that look in loaded buffers.
    if ((ctrl_x_mode_normal() || ctrl_x_mode_line_or_eval())
        && (!compl_started || st.found_all)) {
      int status = process_next_cpt_value(&st, &type, ini);
      if (status == INS_COMPL_CPT_END) {
        break;
      }
      if (status == INS_COMPL_CPT_CONT) {
        continue;
      }
    }

    // If complete() was called then compl_pattern has been reset.
    // The following won't work then, bail out.
    if (compl_pattern == NULL) {
      break;
    }

    // get the next set of completion matches
    found_new_match = get_next_completion_match(type, &st, ini);

    // break the loop for specialized modes (use 'complete' just for the
    // generic ctrl_x_mode == CTRL_X_NORMAL) or when we've found a new match
    if ((ctrl_x_mode_not_default() && !ctrl_x_mode_line_or_eval())
        || found_new_match != FAIL) {
      if (got_int) {
        break;
      }
      // Fill the popup menu as soon as possible.
      if (type != -1) {
        ins_compl_check_keys(0, false);
      }

      if ((ctrl_x_mode_not_default() && !ctrl_x_mode_line_or_eval())
          || compl_interrupted) {
        break;
      }
      compl_started = true;
    } else {
      // Mark a buffer scanned when it has been scanned completely
      if (buf_valid(st.ins_buf) && (type == 0 || type == CTRL_X_PATH_PATTERNS)) {
        assert(st.ins_buf);
        st.ins_buf->b_scanned = true;
      }

      compl_started = false;
    }
  }
  compl_started = true;

  if ((ctrl_x_mode_normal() || ctrl_x_mode_line_or_eval())
      && *st.e_cpt == NUL) {  // Got to end of 'complete'
    found_new_match = FAIL;
  }

  int i = -1;               // total of matches, unknown
  if (found_new_match == FAIL
      || (ctrl_x_mode_not_default() && !ctrl_x_mode_line_or_eval())) {
    i = ins_compl_make_cyclic();
  }

  if (compl_old_match != NULL) {
    // If several matches were added (FORWARD) or the search failed and has
    // just been made cyclic then we have to move compl_curr_match to the
    // next or previous entry (if any) -- Acevedo
    compl_curr_match = compl_dir_forward()
                       ? compl_old_match->cp_next
                       : compl_old_match->cp_prev;
    if (compl_curr_match == NULL) {
      compl_curr_match = compl_old_match;
    }
  }
  may_trigger_modechanged();

  return i;
}

/// Update "compl_shown_match" to the actually shown match, it may differ when
/// "compl_leader" is used to omit some of the matches.
static void ins_compl_update_shown_match(void)
{
  while (!ins_compl_equal(compl_shown_match,
                          compl_leader, strlen(compl_leader))
         && compl_shown_match->cp_next != NULL
         && !is_first_match(compl_shown_match->cp_next)) {
    compl_shown_match = compl_shown_match->cp_next;
  }

  // If we didn't find it searching forward, and compl_shows_dir is
  // backward, find the last match.
  if (compl_shows_dir_backward()
      && !ins_compl_equal(compl_shown_match, compl_leader, strlen(compl_leader))
      && (compl_shown_match->cp_next == NULL
          || is_first_match(compl_shown_match->cp_next))) {
    while (!ins_compl_equal(compl_shown_match, compl_leader, strlen(compl_leader))
           && compl_shown_match->cp_prev != NULL
           && !is_first_match(compl_shown_match->cp_prev)) {
      compl_shown_match = compl_shown_match->cp_prev;
    }
  }
}

/// Delete the old text being completed.
void ins_compl_delete(bool new_leader)
{
  // Avoid deleting text that will be reinserted when changing leader. This
  // allows marks present on the original text to shrink/grow appropriately.
  int orig_col = 0;
  if (new_leader) {
    char *orig = compl_orig_text;
    char *leader = ins_compl_leader();
    while (*orig != NUL && utf_ptr2char(orig) == utf_ptr2char(leader)) {
      leader += utf_ptr2len(leader);
      orig += utf_ptr2len(orig);
    }
    orig_col = (int)(orig - compl_orig_text);
  }

  // In insert mode: Delete the typed part.
  // In replace mode: Put the old characters back, if any.
  int col = compl_col + (compl_status_adding() ? compl_length : orig_col);
  if ((int)curwin->w_cursor.col > col) {
    if (stop_arrow() == FAIL) {
      return;
    }
    backspace_until_column(col);
    compl_ins_end_col = curwin->w_cursor.col;
  }

  // TODO(vim): is this sufficient for redrawing?  Redrawing everything
  // causes flicker, thus we can't do that.
  changed_cline_bef_curs(curwin);
  // clear v:completed_item
  set_vim_var_dict(VV_COMPLETED_ITEM, tv_dict_alloc_lock(VAR_FIXED));
}

/// Insert the new text being completed.
/// "in_compl_func" is true when called from complete_check().
void ins_compl_insert(bool in_compl_func)
{
  int compl_len = get_compl_len();
  // Make sure we don't go over the end of the string, this can happen with
  // illegal bytes.
  if (compl_len < (int)strlen(compl_shown_match->cp_str)) {
    ins_compl_insert_bytes(compl_shown_match->cp_str + compl_len, -1);
  }
  compl_used_match = !match_at_original_text(compl_shown_match);

  dict_T *dict = ins_compl_dict_alloc(compl_shown_match);
  set_vim_var_dict(VV_COMPLETED_ITEM, dict);
  if (!in_compl_func) {
    compl_curr_match = compl_shown_match;
  }
}

/// show the file name for the completion match (if any).  Truncate the file
/// name to avoid a wait for return.
static void ins_compl_show_filename(void)
{
  char *const lead = _("match in file");
  int space = sc_col - vim_strsize(lead) - 2;
  if (space <= 0) {
    return;
  }

  // We need the tail that fits.  With double-byte encoding going
  // back from the end is very slow, thus go from the start and keep
  // the text that fits in "space" between "s" and "e".
  char *s;
  char *e;
  for (s = e = compl_shown_match->cp_fname; *e != NUL; MB_PTR_ADV(e)) {
    space -= ptr2cells(e);
    while (space < 0) {
      space += ptr2cells(s);
      MB_PTR_ADV(s);
    }
  }
  msg_hist_off = true;
  vim_snprintf(IObuff, IOSIZE, "%s %s%s", lead,
               s > compl_shown_match->cp_fname ? "<" : "", s);
  msg(IObuff, 0);
  msg_hist_off = false;
  redraw_cmdline = false;  // don't overwrite!
}

/// Find a completion item when 'completeopt' contains "fuzzy".
static compl_T *find_comp_when_fuzzy(void)
{
  int target_idx = -1;
  const bool is_forward = compl_shows_dir_forward();
  const bool is_backward = compl_shows_dir_backward();
  compl_T *comp = NULL;

  assert(compl_match_array != NULL);
  if ((is_forward && compl_selected_item == compl_match_arraysize - 1)
      || (is_backward && compl_selected_item == 0)) {
    return compl_first_match != compl_shown_match
           ? compl_first_match
           : (compl_first_match->cp_prev ? compl_first_match->cp_prev : NULL);
  }

  if (is_forward) {
    target_idx = compl_selected_item + 1;
  } else if (is_backward) {
    target_idx = compl_selected_item == -1 ? compl_match_arraysize - 1
                                           : compl_selected_item - 1;
  }

  const int score = compl_match_array[target_idx].pum_score;
  char *const str = compl_match_array[target_idx].pum_text;

  comp = compl_first_match;
  do {
    if (comp->cp_score == score
        && (str == comp->cp_str || str == comp->cp_text[CPT_ABBR])) {
      return comp;
    }
    comp = comp->cp_next;
  } while (comp != NULL && !is_first_match(comp));

  return NULL;
}

/// Find the next set of matches for completion. Repeat the completion "todo"
/// times.  The number of matches found is returned in 'num_matches'.
///
/// @param allow_get_expansion  If true, then ins_compl_get_exp() may be called to
///                             get more completions.
///                             If false, then do nothing when there are no more
///                             completions in the given direction.
/// @param todo  repeat completion this many times
/// @param advance  If true, then completion will move to the first match.
///                 Otherwise, the original text will be shown.
///
/// @return  OK on success and -1 if the number of matches are unknown.
static int find_next_completion_match(bool allow_get_expansion, int todo, bool advance,
                                      int *num_matches)
{
  bool found_end = false;
  compl_T *found_compl = NULL;
  unsigned cur_cot_flags = get_cot_flags();
  bool compl_no_select = (cur_cot_flags & kOptCotFlagNoselect) != 0;
  bool compl_fuzzy_match = (cur_cot_flags & kOptCotFlagFuzzy) != 0;

  while (--todo >= 0) {
    if (compl_shows_dir_forward() && compl_shown_match->cp_next != NULL) {
      compl_shown_match = compl_fuzzy_match && compl_match_array != NULL
                          ? find_comp_when_fuzzy() : compl_shown_match->cp_next;
      found_end = (compl_first_match != NULL
                   && (is_first_match(compl_shown_match->cp_next)
                       || is_first_match(compl_shown_match)));
    } else if (compl_shows_dir_backward()
               && compl_shown_match->cp_prev != NULL) {
      found_end = is_first_match(compl_shown_match);
      compl_shown_match = compl_fuzzy_match && compl_match_array != NULL
                          ? find_comp_when_fuzzy() : compl_shown_match->cp_prev;
      found_end |= is_first_match(compl_shown_match);
    } else {
      if (!allow_get_expansion) {
        if (advance) {
          if (compl_shows_dir_backward()) {
            compl_pending -= todo + 1;
          } else {
            compl_pending += todo + 1;
          }
        }
        return -1;
      }

      if (!compl_no_select && advance) {
        if (compl_shows_dir_backward()) {
          compl_pending--;
        } else {
          compl_pending++;
        }
      }

      // Find matches.
      *num_matches = ins_compl_get_exp(&compl_startpos);

      // handle any pending completions
      while (compl_pending != 0 && compl_direction == compl_shows_dir
             && advance) {
        if (compl_pending > 0 && compl_shown_match->cp_next != NULL) {
          compl_shown_match = compl_shown_match->cp_next;
          compl_pending--;
        }
        if (compl_pending < 0 && compl_shown_match->cp_prev != NULL) {
          compl_shown_match = compl_shown_match->cp_prev;
          compl_pending++;
        } else {
          break;
        }
      }
      found_end = false;
    }
    if (!match_at_original_text(compl_shown_match)
        && compl_leader != NULL
        && !ins_compl_equal(compl_shown_match,
                            compl_leader, strlen(compl_leader))
        && !(compl_fuzzy_match && compl_shown_match->cp_score > 0)) {
      todo++;
    } else {
      // Remember a matching item.
      found_compl = compl_shown_match;
    }

    // Stop at the end of the list when we found a usable match.
    if (found_end) {
      if (found_compl != NULL) {
        compl_shown_match = found_compl;
        break;
      }
      todo = 1;             // use first usable match after wrapping around
    }
  }

  return OK;
}

/// Fill in the next completion in the current direction.
/// If "allow_get_expansion" is true, then we may call ins_compl_get_exp() to
/// get more completions.  If it is false, then we just do nothing when there
/// are no more completions in a given direction.  The latter case is used when
/// we are still in the middle of finding completions, to allow browsing
/// through the ones found so far.
/// @return  the total number of matches, or -1 if still unknown -- webb.
///
/// compl_curr_match is currently being used by ins_compl_get_exp(), so we use
/// compl_shown_match here.
///
/// Note that this function may be called recursively once only.  First with
/// "allow_get_expansion" true, which calls ins_compl_get_exp(), which in turn
/// calls this function with "allow_get_expansion" false.
///
/// @param count          Repeat completion this many times; should be at least 1
/// @param insert_match   Insert the newly selected match
/// @param in_compl_func  Called from complete_check()
static int ins_compl_next(bool allow_get_expansion, int count, bool insert_match,
                          bool in_compl_func)
{
  int num_matches = -1;
  int todo = count;
  const bool started = compl_started;
  buf_T *const orig_curbuf = curbuf;
  unsigned cur_cot_flags = get_cot_flags();
  bool compl_no_insert = (cur_cot_flags & kOptCotFlagNoinsert) != 0;
  bool compl_fuzzy_match = (cur_cot_flags & kOptCotFlagFuzzy) != 0;

  // When user complete function return -1 for findstart which is next
  // time of 'always', compl_shown_match become NULL.
  if (compl_shown_match == NULL) {
    return -1;
  }

  if (compl_leader != NULL
      && !match_at_original_text(compl_shown_match)
      && !compl_fuzzy_match) {
    // Update "compl_shown_match" to the actually shown match
    ins_compl_update_shown_match();
  }

  if (allow_get_expansion && insert_match
      && (!compl_get_longest || compl_used_match)) {
    // Delete old text to be replaced
    ins_compl_delete(false);
  }

  // When finding the longest common text we stick at the original text,
  // don't let CTRL-N or CTRL-P move to the first match.
  bool advance = count != 1 || !allow_get_expansion || !compl_get_longest;

  // When restarting the search don't insert the first match either.
  if (compl_restarting) {
    advance = false;
    compl_restarting = false;
  }

  // Repeat this for when <PageUp> or <PageDown> is typed.  But don't wrap
  // around.
  if (find_next_completion_match(allow_get_expansion, todo, advance,
                                 &num_matches) == -1) {
    return -1;
  }

  if (curbuf != orig_curbuf) {
    // In case some completion function switched buffer, don't want to
    // insert the completion elsewhere.
    return -1;
  }

  // Insert the text of the new completion, or the compl_leader.
  if (compl_no_insert && !started) {
    ins_compl_insert_bytes(compl_orig_text + get_compl_len(), -1);
    compl_used_match = false;
    restore_orig_extmarks();
  } else if (insert_match) {
    if (!compl_get_longest || compl_used_match) {
      ins_compl_insert(in_compl_func);
    } else {
      assert(compl_leader != NULL);
      ins_compl_insert_bytes(compl_leader + get_compl_len(), -1);
    }
    if (!strcmp(compl_curr_match->cp_str, compl_orig_text)) {
      restore_orig_extmarks();
    }
  } else {
    compl_used_match = false;
  }

  if (!allow_get_expansion) {
    // redraw to show the user what was inserted
    update_screen();  // TODO(bfredl): no!

    // display the updated popup menu
    ins_compl_show_pum();

    // Delete old text to be replaced, since we're still searching and
    // don't want to match ourselves!
    ins_compl_delete(false);
  }

  // Enter will select a match when the match wasn't inserted and the popup
  // menu is visible.
  if (compl_no_insert && !started) {
    compl_enter_selects = true;
  } else {
    compl_enter_selects = !insert_match && compl_match_array != NULL;
  }

  // Show the file name for the match (if any)
  if (compl_shown_match->cp_fname != NULL) {
    ins_compl_show_filename();
  }

  return num_matches;
}

/// Call this while finding completions, to check whether the user has hit a key
/// that should change the currently displayed completion, or exit completion
/// mode.  Also, when compl_pending is not zero, show a completion as soon as
/// possible. -- webb
///
/// @param frequency      specifies out of how many calls we actually check.
/// @param in_compl_func  true when called from complete_check(), don't set
///                       compl_curr_match.
void ins_compl_check_keys(int frequency, bool in_compl_func)
{
  static int count = 0;

  // Don't check when reading keys from a script, :normal or feedkeys().
  // That would break the test scripts.  But do check for keys when called
  // from complete_check().
  if (!in_compl_func && (using_script() || ex_normal_busy)) {
    return;
  }

  // Only do this at regular intervals
  if (++count < frequency) {
    return;
  }
  count = 0;

  // Check for a typed key.  Do use mappings, otherwise vim_is_ctrl_x_key()
  // can't do its work correctly.
  int c = vpeekc_any();
  if (c != NUL) {
    if (vim_is_ctrl_x_key(c) && c != Ctrl_X && c != Ctrl_R) {
      c = safe_vgetc();         // Eat the character
      compl_shows_dir = ins_compl_key2dir(c);
      ins_compl_next(false, ins_compl_key2count(c),
                     c != K_UP && c != K_DOWN, in_compl_func);
    } else {
      // Need to get the character to have KeyTyped set.  We'll put it
      // back with vungetc() below.  But skip K_IGNORE.
      c = safe_vgetc();
      if (c != K_IGNORE) {
        // Don't interrupt completion when the character wasn't typed,
        // e.g., when doing @q to replay keys.
        if (c != Ctrl_R && KeyTyped) {
          compl_interrupted = true;
        }

        vungetc(c);
      }
    }
  }
  if (compl_pending != 0 && !got_int && !(cot_flags & kOptCotFlagNoinsert)) {
    int todo = compl_pending > 0 ? compl_pending : -compl_pending;

    compl_pending = 0;
    ins_compl_next(false, todo, true, in_compl_func);
  }
}

/// Decide the direction of Insert mode complete from the key typed.
/// Returns BACKWARD or FORWARD.
static int ins_compl_key2dir(int c)
{
  if (c == K_EVENT || c == K_COMMAND || c == K_LUA) {
    return pum_want.item < compl_selected_item ? BACKWARD : FORWARD;
  }
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

/// Decide the number of completions to move forward.
/// Returns 1 for most keys, height of the popup menu for page-up/down keys.
static int ins_compl_key2count(int c)
{
  if (c == K_EVENT || c == K_COMMAND || c == K_LUA) {
    int offset = pum_want.item - compl_selected_item;
    return abs(offset);
  }

  if (ins_compl_pum_key(c) && c != K_UP && c != K_DOWN) {
    int h = pum_get_height();
    if (h > 3) {
      h -= 2;       // keep some context
    }
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
  case K_EVENT:
  case K_COMMAND:
  case K_LUA:
    return pum_want.active && pum_want.insert;
  }
  return true;
}

/// Get the pattern, column and length for normal completion (CTRL-N CTRL-P
/// completion)
/// Sets the global variables: compl_col, compl_length, compl_pattern and
/// compl_patternlen.
/// Uses the global variables: compl_cont_status and ctrl_x_mode
static int get_normal_compl_info(char *line, int startcol, colnr_T curs_col)
{
  if ((compl_cont_status & CONT_SOL) || ctrl_x_mode_path_defines()) {
    if (!compl_status_adding()) {
      while (--startcol >= 0 && vim_isIDc((uint8_t)line[startcol])) {}
      compl_col += ++startcol;
      compl_length = curs_col - startcol;
    }
    if (p_ic) {
      compl_pattern = str_foldcase(line + compl_col, compl_length, NULL, 0);
    } else {
      compl_pattern = xstrnsave(line + compl_col, (size_t)compl_length);
    }
  } else if (compl_status_adding()) {
    char *prefix = "\\<";
    size_t prefixlen = STRLEN_LITERAL("\\<");

    // we need up to 2 extra chars for the prefix
    compl_pattern = xmalloc(quote_meta(NULL, line + compl_col,
                                       compl_length) + prefixlen);
    if (!vim_iswordp(line + compl_col)
        || (compl_col > 0
            && (vim_iswordp(mb_prevptr(line, line + compl_col))))) {
      prefix = "";
      prefixlen = 0;
    }
    STRCPY(compl_pattern, prefix);
    quote_meta(compl_pattern + prefixlen, line + compl_col, compl_length);
  } else if (--startcol < 0
             || !vim_iswordp(mb_prevptr(line, line + startcol + 1))) {
    // Match any word of at least two chars
    compl_pattern = xstrnsave(S_LEN("\\<\\k\\k"));
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
      // Only match word with at least two chars -- webb
      // there's no need to call quote_meta,
      // xmalloc(7) is enough  -- Acevedo
      compl_pattern = xmalloc(7);
      STRCPY(compl_pattern, "\\<");
      quote_meta(compl_pattern + 2, line + compl_col, 1);
      strcat(compl_pattern, "\\k");
    } else {
      compl_pattern = xmalloc(quote_meta(NULL, line + compl_col, compl_length) + 2);
      STRCPY(compl_pattern, "\\<");
      quote_meta(compl_pattern + 2, line + compl_col, compl_length);
    }
  }

  compl_patternlen = strlen(compl_pattern);

  return OK;
}

/// Get the pattern, column and length for whole line completion or for the
/// complete() function.
/// Sets the global variables: compl_col, compl_length and compl_pattern.
static int get_wholeline_compl_info(char *line, colnr_T curs_col)
{
  compl_col = (colnr_T)getwhitecols(line);
  compl_length = (int)curs_col - (int)compl_col;
  if (compl_length < 0) {  // cursor in indent: empty pattern
    compl_length = 0;
  }
  if (p_ic) {
    compl_pattern = str_foldcase(line + compl_col, compl_length, NULL, 0);
  } else {
    compl_pattern = xstrnsave(line + compl_col, (size_t)compl_length);
  }

  compl_patternlen = strlen(compl_pattern);

  return OK;
}

/// Get the pattern, column and length for filename completion.
/// Sets the global variables: compl_col, compl_length and compl_pattern.
static int get_filename_compl_info(char *line, int startcol, colnr_T curs_col)
{
  // Go back to just before the first filename character.
  if (startcol > 0) {
    char *p = line + startcol;

    MB_PTR_BACK(line, p);
    while (p > line && vim_isfilec(utf_ptr2char(p))) {
      MB_PTR_BACK(line, p);
    }
    if (p == line && vim_isfilec(utf_ptr2char(p))) {
      startcol = 0;
    } else {
      startcol = (int)(p - line) + 1;
    }
  }

  compl_col += startcol;
  compl_length = (int)curs_col - startcol;
  compl_pattern = addstar(line + compl_col, (size_t)compl_length, EXPAND_FILES);
  compl_patternlen = strlen(compl_pattern);

  return OK;
}

/// Get the pattern, column and length for command-line completion.
/// Sets the global variables: compl_col, compl_length and compl_pattern.
static int get_cmdline_compl_info(char *line, colnr_T curs_col)
{
  compl_pattern = xstrnsave(line, (size_t)curs_col);
  compl_patternlen = (size_t)curs_col;
  set_cmd_context(&compl_xp, compl_pattern, (int)compl_patternlen, curs_col, false);
  if (compl_xp.xp_context == EXPAND_LUA) {
    nlua_expand_pat(&compl_xp);
  }
  if (compl_xp.xp_context == EXPAND_UNSUCCESSFUL
      || compl_xp.xp_context == EXPAND_NOTHING) {
    // No completion possible, use an empty pattern to get a
    // "pattern not found" message.
    compl_col = curs_col;
  } else {
    compl_col = (int)(compl_xp.xp_pattern - compl_pattern);
  }
  compl_length = curs_col - compl_col;

  return OK;
}

/// Get the pattern, column and length for user defined completion ('omnifunc',
/// 'completefunc' and 'thesaurusfunc')
/// Sets the global variables: compl_col, compl_length and compl_pattern.
/// Uses the global variable: spell_bad_len
static int get_userdefined_compl_info(colnr_T curs_col)
{
  // Call user defined function 'completefunc' with "a:findstart"
  // set to 1 to obtain the length of text to use for completion.
  const int save_State = State;

  // Call 'completefunc' or 'omnifunc' and get pattern length as a string
  char *funcname = get_complete_funcname(ctrl_x_mode);
  if (*funcname == NUL) {
    semsg(_(e_notset), ctrl_x_mode_function() ? "completefunc" : "omnifunc");
    return FAIL;
  }

  typval_T args[3];
  args[0].v_type = VAR_NUMBER;
  args[1].v_type = VAR_STRING;
  args[2].v_type = VAR_UNKNOWN;
  args[0].vval.v_number = 1;
  args[1].vval.v_string = "";

  pos_T pos = curwin->w_cursor;
  textlock++;
  Callback *cb = get_insert_callback(ctrl_x_mode);
  colnr_T col = (colnr_T)callback_call_retnr(cb, 2, args);
  textlock--;

  State = save_State;
  curwin->w_cursor = pos;  // restore the cursor position
  check_cursor(curwin);  // make sure cursor position is valid, just in case
  validate_cursor(curwin);
  if (!equalpos(curwin->w_cursor, pos)) {
    emsg(_(e_compldel));
    return FAIL;
  }

  // Return value -2 means the user complete function wants to cancel the
  // complete without an error, do the same if the function did not execute
  // successfully.
  if (col == -2 || aborting()) {
    return FAIL;
  }
  // Return value -3 does the same as -2 and leaves CTRL-X mode.
  if (col == -3) {
    ctrl_x_mode = CTRL_X_NORMAL;
    edit_submode = NULL;
    if (!shortmess(SHM_COMPLETIONMENU)) {
      msg_clr_cmdline();
    }
    return FAIL;
  }

  // Reset extended parameters of completion, when starting new
  // completion.
  compl_opt_refresh_always = false;

  if (col < 0) {
    col = curs_col;
  }
  compl_col = col;
  if (compl_col > curs_col) {
    compl_col = curs_col;
  }

  // Setup variables for completion.  Need to obtain "line" again,
  // it may have become invalid.
  char *line = ml_get(curwin->w_cursor.lnum);
  compl_length = curs_col - compl_col;
  compl_pattern = xstrnsave(line + compl_col, (size_t)compl_length);
  compl_patternlen = (size_t)compl_length;

  return OK;
}

/// Get the pattern, column and length for spell completion.
/// Sets the global variables: compl_col, compl_length and compl_pattern.
/// Uses the global variable: spell_bad_len
static int get_spell_compl_info(int startcol, colnr_T curs_col)
{
  if (spell_bad_len > 0) {
    assert(spell_bad_len <= INT_MAX);
    compl_col = curs_col - (int)spell_bad_len;
  } else {
    compl_col = spell_word_start(startcol);
  }
  if (compl_col >= (colnr_T)startcol) {
    compl_length = 0;
    compl_col = curs_col;
  } else {
    spell_expand_check_cap(compl_col);
    compl_length = (int)curs_col - compl_col;
  }
  // Need to obtain "line" again, it may have become invalid.
  char *line = ml_get(curwin->w_cursor.lnum);
  compl_pattern = xstrnsave(line + compl_col, (size_t)compl_length);
  compl_patternlen = (size_t)compl_length;

  return OK;
}

/// Get the completion pattern, column and length.
///
/// @param startcol  start column number of the completion pattern/text
/// @param cur_col   current cursor column
///
/// On return, "line_invalid" is set to true, if the current line may have
/// become invalid and needs to be fetched again.
///
/// @return  OK on success.
static int compl_get_info(char *line, int startcol, colnr_T curs_col, bool *line_invalid)
{
  if (ctrl_x_mode_normal()
      || ((ctrl_x_mode & CTRL_X_WANT_IDENT)
          && !thesaurus_func_complete(ctrl_x_mode))) {
    return get_normal_compl_info(line, startcol, curs_col);
  } else if (ctrl_x_mode_line_or_eval()) {
    return get_wholeline_compl_info(line, curs_col);
  } else if (ctrl_x_mode_files()) {
    return get_filename_compl_info(line, startcol, curs_col);
  } else if (ctrl_x_mode == CTRL_X_CMDLINE) {
    return get_cmdline_compl_info(line, curs_col);
  } else if (ctrl_x_mode_function() || ctrl_x_mode_omni()
             || thesaurus_func_complete(ctrl_x_mode)) {
    if (get_userdefined_compl_info(curs_col) == FAIL) {
      return FAIL;
    }
    *line_invalid = true;  // "line" may have become invalid
  } else if (ctrl_x_mode_spell()) {
    if (get_spell_compl_info(startcol, curs_col) == FAIL) {
      return FAIL;
    }
    *line_invalid = true;  // "line" may have become invalid
  } else {
    internal_error("ins_complete()");
    return FAIL;
  }

  return OK;
}

/// Continue an interrupted completion mode search in "line".
///
/// If this same ctrl_x_mode has been interrupted use the text from
/// "compl_startpos" to the cursor as a pattern to add a new word instead of
/// expand the one before the cursor, in word-wise if "compl_startpos" is not in
/// the same line as the cursor then fix it (the line has been split because it
/// was longer than 'tw').  if SOL is set then skip the previous pattern, a word
/// at the beginning of the line has been inserted, we'll look for that.
static void ins_compl_continue_search(char *line)
{
  // it is a continued search
  compl_cont_status &= ~CONT_INTRPT;  // remove INTRPT
  if (ctrl_x_mode_normal()
      || ctrl_x_mode_path_patterns()
      || ctrl_x_mode_path_defines()) {
    if (compl_startpos.lnum != curwin->w_cursor.lnum) {
      // line (probably) wrapped, set compl_startpos to the
      // first non_blank in the line, if it is not a wordchar
      // include it to get a better pattern, but then we don't
      // want the "\\<" prefix, check it below.
      compl_col = (colnr_T)getwhitecols(line);
      compl_startpos.col = compl_col;
      compl_startpos.lnum = curwin->w_cursor.lnum;
      compl_cont_status &= ~CONT_SOL;  // clear SOL if present
    } else {
      // S_IPOS was set when we inserted a word that was at the
      // beginning of the line, which means that we'll go to SOL
      // mode but first we need to redefine compl_startpos
      if (compl_cont_status & CONT_S_IPOS) {
        compl_cont_status |= CONT_SOL;
        compl_startpos.col = (colnr_T)(skipwhite(line + compl_length + compl_startpos.col) - line);
      }
      compl_col = compl_startpos.col;
    }
    compl_length = curwin->w_cursor.col - (int)compl_col;
    // IObuff is used to add a "word from the next line" would we
    // have enough space?  just being paranoid
#define MIN_SPACE 75
    if (compl_length > (IOSIZE - MIN_SPACE)) {
      compl_cont_status &= ~CONT_SOL;
      compl_length = (IOSIZE - MIN_SPACE);
      compl_col = curwin->w_cursor.col - compl_length;
    }
    compl_cont_status |= CONT_ADDING | CONT_N_ADDS;
    if (compl_length < 1) {
      compl_cont_status &= CONT_LOCAL;
    }
  } else if (ctrl_x_mode_line_or_eval()) {
    compl_cont_status = CONT_ADDING | CONT_N_ADDS;
  } else {
    compl_cont_status = 0;
  }
}

/// start insert mode completion
static int ins_compl_start(void)
{
  const bool save_did_ai = did_ai;

  // First time we hit ^N or ^P (in a row, I mean)

  did_ai = false;
  did_si = false;
  can_si = false;
  can_si_back = false;
  if (stop_arrow() == FAIL) {
    return FAIL;
  }

  char *line = ml_get(curwin->w_cursor.lnum);
  colnr_T curs_col = curwin->w_cursor.col;
  compl_pending = 0;

  if ((compl_cont_status & CONT_INTRPT) == CONT_INTRPT
      && compl_cont_mode == ctrl_x_mode) {
    // this same ctrl-x_mode was interrupted previously. Continue the
    // completion.
    ins_compl_continue_search(line);
  } else {
    compl_cont_status &= CONT_LOCAL;
  }

  int startcol = 0;  // column where searched text starts
  if (!compl_status_adding()) {   // normal expansion
    compl_cont_mode = ctrl_x_mode;
    if (ctrl_x_mode_not_default()) {
      // Remove LOCAL if ctrl_x_mode != CTRL_X_NORMAL
      compl_cont_status = 0;
    }
    compl_cont_status |= CONT_N_ADDS;
    compl_startpos = curwin->w_cursor;
    startcol = (int)curs_col;
    compl_col = 0;
  }

  // Work out completion pattern and original text -- webb
  bool line_invalid = false;
  if (compl_get_info(line, startcol, curs_col, &line_invalid) == FAIL) {
    if (ctrl_x_mode_function() || ctrl_x_mode_omni()
        || thesaurus_func_complete(ctrl_x_mode)) {
      // restore did_ai, so that adding comment leader works
      did_ai = save_did_ai;
    }
    return FAIL;
  }
  // If "line" was changed while getting completion info get it again.
  if (line_invalid) {
    line = ml_get(curwin->w_cursor.lnum);
  }

  if (compl_status_adding()) {
    edit_submode_pre = _(" Adding");
    if (ctrl_x_mode_line_or_eval()) {
      // Insert a new line, keep indentation but ignore 'comments'.
      char *old = curbuf->b_p_com;

      curbuf->b_p_com = "";
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

  if (compl_cont_status & CONT_LOCAL) {
    edit_submode = _(ctrl_x_msgs[CTRL_X_LOCAL_MSG]);
  } else {
    edit_submode = _(CTRL_X_MSG(ctrl_x_mode));
  }

  // If any of the original typed text has been changed we need to fix
  // the redo buffer.
  ins_compl_fixRedoBufForLeader(NULL);

  // Always add completion for the original text.
  xfree(compl_orig_text);
  kv_destroy(compl_orig_extmarks);
  compl_orig_text = xstrnsave(line + compl_col, (size_t)compl_length);
  save_orig_extmarks();
  int flags = CP_ORIGINAL_TEXT;
  if (p_ic) {
    flags |= CP_ICASE;
  }
  if (ins_compl_add(compl_orig_text, -1, NULL, NULL, false, NULL, 0,
                    flags, false, NULL) != OK) {
    XFREE_CLEAR(compl_pattern);
    compl_patternlen = 0;
    XFREE_CLEAR(compl_orig_text);
    kv_destroy(compl_orig_extmarks);
    return FAIL;
  }

  // showmode might reset the internal line pointers, so it must
  // be called before line = ml_get(), or when this address is no
  // longer needed.  -- Acevedo.
  edit_submode_extra = _("-- Searching...");
  edit_submode_highl = HLF_COUNT;
  showmode();
  edit_submode_extra = NULL;
  ui_flush();

  return OK;
}

/// display the completion status message
static void ins_compl_show_statusmsg(void)
{
  // we found no match if the list has only the "compl_orig_text"-entry
  if (is_first_match(compl_first_match->cp_next)) {
    edit_submode_extra = compl_status_adding() && compl_length > 1 ? _(e_hitend) : _(e_patnotf);
    edit_submode_highl = HLF_E;
  }

  if (edit_submode_extra == NULL) {
    if (match_at_original_text(compl_curr_match)) {
      edit_submode_extra = _("Back at original");
      edit_submode_highl = HLF_W;
    } else if (compl_cont_status & CONT_S_IPOS) {
      edit_submode_extra = _("Word from other line");
      edit_submode_highl = HLF_COUNT;
    } else if (compl_curr_match->cp_next == compl_curr_match->cp_prev) {
      edit_submode_extra = _("The only match");
      edit_submode_highl = HLF_COUNT;
      compl_curr_match->cp_number = 1;
    } else {
      // Update completion sequence number when needed.
      if (compl_curr_match->cp_number == -1) {
        ins_compl_update_sequence_numbers();
      }

      // The match should always have a sequence number now, this is
      // just a safety check.
      if (compl_curr_match->cp_number != -1) {
        // Space for 10 text chars. + 2x10-digit no.s = 31.
        // Translations may need more than twice that.
        static char match_ref[81];

        if (compl_matches > 0) {
          vim_snprintf(match_ref, sizeof(match_ref),
                       _("match %d of %d"),
                       compl_curr_match->cp_number, compl_matches);
        } else {
          vim_snprintf(match_ref, sizeof(match_ref),
                       _("match %d"),
                       compl_curr_match->cp_number);
        }
        edit_submode_extra = match_ref;
        edit_submode_highl = HLF_R;
        if (dollar_vcol >= 0) {
          curs_columns(curwin, false);
        }
      }
    }
  }

  // Show a message about what (completion) mode we're in.
  showmode();
  if (!shortmess(SHM_COMPLETIONMENU)) {
    if (edit_submode_extra != NULL) {
      if (!p_smd) {
        msg_hist_off = true;
        msg_ext_set_kind("completion");
        msg(edit_submode_extra, (edit_submode_highl < HLF_COUNT
                                 ? (int)edit_submode_highl + 1 : 0));
        msg_hist_off = false;
      }
    } else {
      msg_clr_cmdline();  // necessary for "noshowmode"
    }
  }
}

/// Do Insert mode completion.
/// Called when character "c" was typed, which has a meaning for completion.
/// Returns OK if completion was done, FAIL if something failed.
int ins_complete(int c, bool enable_pum)
{
  compl_direction = ins_compl_key2dir(c);
  int insert_match = ins_compl_use_match(c);

  if (!compl_started) {
    if (ins_compl_start() == FAIL) {
      return FAIL;
    }
  } else if (insert_match && stop_arrow() == FAIL) {
    return FAIL;
  }

  compl_shown_match = compl_curr_match;
  compl_shows_dir = compl_direction;

  // Find next match (and following matches).
  int save_w_wrow = curwin->w_wrow;
  int save_w_leftcol = curwin->w_leftcol;
  int n = ins_compl_next(true, ins_compl_key2count(c), insert_match, false);

  if (n > 1) {          // all matches have been found
    compl_matches = n;
  }
  compl_curr_match = compl_shown_match;
  compl_direction = compl_shows_dir;

  // Eat the ESC that vgetc() returns after a CTRL-C to avoid leaving Insert
  // mode.
  if (got_int && !global_busy) {
    vgetc();
    got_int = false;
  }

  // we found no match if the list has only the "compl_orig_text"-entry
  if (is_first_match(compl_first_match->cp_next)) {
    // remove N_ADDS flag, so next ^X<> won't try to go to ADDING mode,
    // because we couldn't expand anything at first place, but if we used
    // ^P, ^N, ^X^I or ^X^D we might want to add-expand a single-char-word
    // (such as M in M'exico) if not tried already.  -- Acevedo
    if (compl_length > 1
        || compl_status_adding()
        || (ctrl_x_mode_not_default()
            && !ctrl_x_mode_path_patterns()
            && !ctrl_x_mode_path_defines())) {
      compl_cont_status &= ~CONT_N_ADDS;
    }
  }

  if (compl_curr_match->cp_flags & CP_CONT_S_IPOS) {
    compl_cont_status |= CONT_S_IPOS;
  } else {
    compl_cont_status &= ~CONT_S_IPOS;
  }

  ins_compl_show_statusmsg();

  // Show the popup menu, unless we got interrupted.
  if (enable_pum && !compl_interrupted) {
    show_pum(save_w_wrow, save_w_leftcol);
  }
  compl_was_interrupted = compl_interrupted;
  compl_interrupted = false;

  return OK;
}

/// Remove (if needed) and show the popup menu
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

// Looks in the first "len" chars. of "src" for search-metachars.
// If dest is not NULL the chars. are copied there quoting (with
// a backslash) the metachars, and dest would be NUL terminated.
// Returns the length (needed) of dest
static unsigned quote_meta(char *dest, char *src, int len)
{
  unsigned m = (unsigned)len + 1;       // one extra for the NUL

  for (; --len >= 0; src++) {
    switch (*src) {
    case '.':
    case '*':
    case '[':
      if (ctrl_x_mode_dictionary() || ctrl_x_mode_thesaurus()) {
        break;
      }
      FALLTHROUGH;
    case '~':
      if (!magic_isset()) {  // quote these only if magic is set
        break;
      }
      FALLTHROUGH;
    case '\\':
      if (ctrl_x_mode_dictionary() || ctrl_x_mode_thesaurus()) {
        break;
      }
      FALLTHROUGH;
    case '^':                   // currently it's not needed.
    case '$':
      m++;
      if (dest != NULL) {
        *dest++ = '\\';
      }
      break;
    }
    if (dest != NULL) {
      *dest++ = *src;
    }
    // Copy remaining bytes of a multibyte character.
    const int mb_len = utfc_ptr2len(src) - 1;
    if (mb_len > 0 && len >= mb_len) {
      for (int i = 0; i < mb_len; i++) {
        len--;
        src++;
        if (dest != NULL) {
          *dest++ = *src;
        }
      }
    }
  }
  if (dest != NULL) {
    *dest = NUL;
  }

  return m;
}

#if defined(EXITFREE)
void free_insexpand_stuff(void)
{
  XFREE_CLEAR(compl_orig_text);
  kv_destroy(compl_orig_extmarks);
  callback_free(&cfu_cb);
  callback_free(&ofu_cb);
  callback_free(&tsrfu_cb);
}
#endif

/// Called when starting CTRL_X_SPELL mode: Move backwards to a previous badly
/// spelled word, if there is one.
static void spell_back_to_badword(void)
{
  pos_T tpos = curwin->w_cursor;
  spell_bad_len = spell_move_to(curwin, BACKWARD, SMT_ALL, true, NULL);
  if (curwin->w_cursor.col != tpos.col) {
    start_arrow(&tpos);
  }
}
