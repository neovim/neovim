#pragma once

#include <stdio.h>  // IWYU pragma: keep

#include "nvim/decoration_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/fold_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

EXTERN int disable_fold_update INIT( = 0);

// local declarations. {{{1
// typedef fold_T {{{2

// The toplevel folds for each window are stored in the w_folds growarray.
// Each toplevel fold can contain an array of second level folds in the
// fd_nested growarray.
// The info stored in both growarrays is the same: An array of fold_T.

typedef struct {
  linenr_T fd_top;              // first line of fold; for nested fold
                                // relative to parent
  linenr_T fd_len;              // number of lines in the fold
  garray_T fd_nested;           // array of nested folds
  char fd_flags;                // see below
  TriState fd_small;            // kTrue, kFalse, or kNone: fold smaller than
                                // 'foldminlines'; kNone applies to nested
                                // folds too
} fold_T;

enum {
  FD_OPEN = 0,    // fold is open (nested ones can be closed)
  FD_CLOSED = 1,  // fold is closed
  FD_LEVEL = 2,   // depends on 'foldlevel' (nested folds too)
};

#define MAX_LEVEL       20      // maximum fold depth

// Define "fline_T", passed to get fold level for a line. {{{2
typedef struct {
  win_T *wp;              // window
  linenr_T lnum;                // current line number
  linenr_T off;                 // offset between lnum and real line number
  linenr_T lnum_save;           // line nr used by foldUpdateIEMSRecurse()
  int lvl;                      // current level (-1 for undefined)
  int lvl_next;                 // level used for next line
  int start;                    // number of folds that are forced to start at
                                // this line.
  int end;                      // level of fold that is forced to end below
                                // this line
  int had_end;                  // level of fold that is forced to end above
                                // this line (copy of "end" of prev. line)
} fline_T;

int foldLevelWin(win_T *wp, linenr_T lnum);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.h.generated.h"
#endif
