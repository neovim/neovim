#pragma once

#include <stdbool.h>

#include "nvim/pos_defs.h"

/// Encapsulates the mutable state owned by the search subsystem.
///
/// Previously these were bare EXTERN symbols in globals.h, visible to every
/// translation unit.  Grouping them here makes subsystem ownership explicit
/// and creates a seam for future per-thread or per-context instantiation.
typedef struct {
  /// True while a search match should be highlighted at the cursor position.
  bool highlight_match;
  /// Number of extra lines spanned by the current search match (0 = single line).
  linenr_T search_match_lines;
  /// Column just past the end of the match on its last line.
  colnr_T search_match_endcol;
  /// First line of the restricted search range (0 = whole buffer).
  linenr_T search_first_line;
  /// Last line of the restricted search range.
  linenr_T search_last_line;
  /// When true, ignore 'smartcase' for the next search.
  bool no_smartcase;
  /// Byte length of the search command that was just parsed (used by ex_docmd
  /// to advance past the pattern in a range-qualified :s command).
  int searchcmdlen;
  /// When true, suppress 'hlsearch' highlighting (mirrors v:hlsearch == 0).
  bool no_hlsearch;
} SearchState;
