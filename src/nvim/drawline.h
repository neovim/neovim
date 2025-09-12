#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/fold_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

enum { TERM_ATTRS_MAX = 1024, };  ///< Maximum columns for terminal highlight attributes

typedef struct {
  NS ns_id;
  uint64_t mark_id;
  int win_row;
  int win_col;
} WinExtmark;
EXTERN kvec_t(WinExtmark) win_extmark_arr INIT( = KV_INITIAL_VALUE);

/// Spell checking variables passed from win_update() to win_line().
typedef struct {
  bool spv_has_spell;         ///< drawn window has spell checking
  bool spv_unchanged;         ///< not updating for changed text
  int spv_checked_col;        ///< column in "checked_lnum" up to
                              ///< which there are no spell errors
  linenr_T spv_checked_lnum;  ///< line number for "checked_col"
  int spv_cap_col;            ///< column to check for Cap word
  linenr_T spv_capcol_lnum;   ///< line number for "cap_col"
} spellvars_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "drawline.h.generated.h"
#endif
