#pragma once

#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

// Array indexes used for cp_text[].
typedef enum {
  CPT_ABBR = 0,  ///< "abbr"
  CPT_MENU,      ///< "menu"
  CPT_KIND,      ///< "kind"
  CPT_INFO,      ///< "info"
  CPT_COUNT,     ///< Number of entries
} cp_text_T;

/// Structure used to store one match for insert completion.
typedef struct compl_S compl_T;
struct compl_S {
  compl_T *cp_next;
  compl_T *cp_prev;
  char *cp_str;                  ///< matched text
  char *(cp_text[CPT_COUNT]);    ///< text for the menu
  typval_T cp_user_data;
  char *cp_fname;                ///< file containing the match, allocated when
                                 ///< cp_flags has CP_FREE_FNAME
  int cp_flags;                  ///< CP_ values
  int cp_number;                 ///< sequence number
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

/// values for cp_flags
typedef enum {
  CP_ORIGINAL_TEXT = 1,  ///< the original text when the expansion begun
  CP_FREE_FNAME = 2,     ///< cp_fname is allocated
  CP_CONT_S_IPOS = 4,    ///< use CONT_S_IPOS for compl_cont_status
  CP_EQUAL = 8,          ///< ins_compl_equal() always returns true
  CP_ICASE = 16,         ///< ins_compl_equal ignores case
  CP_FAST = 32,          ///< use fast_breakcheck instead of os_breakcheck
} cp_flags_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "insexpand.h.generated.h"
#endif
