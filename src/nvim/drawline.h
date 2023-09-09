#ifndef NVIM_DRAWLINE_H
#define NVIM_DRAWLINE_H

#include <stdbool.h>
#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/decoration_provider.h"
#include "nvim/fold.h"
#include "nvim/macros.h"
#include "nvim/types.h"

// Maximum columns for terminal highlight attributes
#define TERM_ATTRS_MAX 1024

typedef struct {
  NS ns_id;
  uint64_t mark_id;
  int win_row;
  int win_col;
} WinExtmark;
EXTERN kvec_t(WinExtmark) win_extmark_arr INIT(= KV_INITIAL_VALUE);

EXTERN bool conceal_cursor_used INIT(= false);

// Spell checking variables passed from win_update() to win_line().
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
#endif  // NVIM_DRAWLINE_H
