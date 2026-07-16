#pragma once

#include <stdbool.h>

#include "nvim/pos_defs.h"

/// Search/highlight subsystem state.
typedef struct {
  bool hl_match;         ///< Highlight the match, starting at cursor pos.
  linenr_T match_lines;  ///< Lines after the match (0 for a match within one line).
  colnr_T match_endcol;  ///< Column just after the match in the last line.
  linenr_T first_line;   ///< For :{FIRST},{last}s/pat.
  linenr_T last_line;    ///< For :{first},{LAST}s/pat.
  bool no_smartcase;     ///< Don't use 'smartcase' once.
  int cmdlen;            ///< Length of previous search cmd.
  bool no_hlsearch;      ///< Don't use 'hlsearch' temporarily.
} SearchState;
