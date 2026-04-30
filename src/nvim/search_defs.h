#pragma once

#include <stdbool.h>

#include "nvim/pos_defs.h"

/// State owned by the search subsystem.  Previously declared as bare EXTERN
/// symbols in globals.h; grouped here to make subsystem ownership explicit.
typedef struct {
  // When highlight_match is true, highlight a match, starting at the cursor
  // position.  search_match_lines is the number of lines after the match (0
  // for a match within one line), search_match_endcol the column number of
  // the character just after the match in the last line.
  bool highlight_match;            // show search match pos
  linenr_T search_match_lines;     // lines of matched string
  colnr_T search_match_endcol;     // col nr of match end
  linenr_T search_first_line;      // for :{FIRST},{last}s/pat
  linenr_T search_last_line;       // for :{first},{LAST}s/pat

  bool no_smartcase;               // don't use 'smartcase' once

  int searchcmdlen;                // length of previous search cmd

  bool no_hlsearch;                // don't use 'hlsearch' temporarily
} SearchState;
