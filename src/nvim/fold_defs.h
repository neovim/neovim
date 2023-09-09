#ifndef NVIM_FOLD_DEFS_H
#define NVIM_FOLD_DEFS_H

#include "nvim/pos.h"

// Info used to pass info about a fold from the fold-detection code to the
// code that displays the foldcolumn.
typedef struct foldinfo {
  linenr_T fi_lnum;             // line number where fold starts
  int fi_level;                 // level of the fold; when this is zero the
                                // other fields are invalid
  int fi_low_level;             // lowest fold level that starts in the same
                                // line
  linenr_T fi_lines;
} foldinfo_T;

#endif  // NVIM_FOLD_DEFS_H
