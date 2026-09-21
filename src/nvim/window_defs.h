#pragma once

#include <stdbool.h>

#include "nvim/pos_defs.h"

/// A window's viewport (scroll position and curswant, not the cursor). Reported by winsaveview().
/// Used for save/restore before temporary work ('incsearch', 'inccommand', multicursor replay).
typedef struct {
  colnr_T vs_curswant;
  bool vs_set_curswant;  ///< `w_set_curswant`: `vs_curswant` is stale, derive it from the cursor.
  colnr_T vs_leftcol;
  colnr_T vs_skipcol;
  linenr_T vs_topline;
  int vs_topfill;
  linenr_T vs_botline;
  int vs_empty_rows;
} viewstate_T;
