#ifndef NVIM_FOLD_H
#define NVIM_FOLD_H

#include <stdio.h>

#include "nvim/pos.h"
#include "nvim/garray.h"
#include "nvim/types.h"
#include "nvim/buffer_defs.h"

/*
 * Info used to pass info about a fold from the fold-detection code to the
 * code that displays the foldcolumn.
 */
typedef struct foldinfo {
  linenr_T fi_lnum;             /* line number where fold starts */
  int fi_level;                 /* level of the fold; when this is zero the
                                   other fields are invalid */
  int fi_low_level;             /* lowest fold level that starts in the same
                                   line */
  long fi_lines;
  colnr_T fi_startcol;             /* starting column of the fold */
  colnr_T fi_endcol;               /* end column of the fold */
} foldinfo_T;

/*
 * The toplevel folds for each window are stored in the w_folds growarray.
 * Each toplevel fold can contain an array of second level folds in the
 * fd_nested growarray.
 * The info stored in both growarrays is the same: An array of fold_T.
 */
typedef struct {
  linenr_T fd_top;              // first line of fold; for nested fold
                                // relative to parent
  colnr_T fd_startcol;         // just for test/startcol
  colnr_T fd_endcol;         // just for test/startcol
  linenr_T fd_len;              // number of lines in the fold
  garray_T fd_nested;           // array of nested folds
  char fd_flags;                // see below
  TriState fd_small;            // kTrue, kFalse, or kNone: fold smaller than
                                // 'foldminlines'; kNone applies to nested
                                // folds too
} fold_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.h.generated.h"
#endif
#endif  // NVIM_FOLD_H
