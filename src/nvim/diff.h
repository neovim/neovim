#ifndef NVIM_DIFF_H
#define NVIM_DIFF_H

#include "nvim/ex_cmds_defs.h"
#include "nvim/pos.h"

// Value set from 'diffopt'.
EXTERN int diff_context INIT(= 6);  // context for folds
EXTERN int diff_foldcolumn INIT(= 2);  // 'foldcolumn' for diff mode
EXTERN bool diff_need_scrollbind INIT(= false);

EXTERN bool need_diff_redraw INIT(= false);  // need to call diff_redraw()

// used for diff result
typedef struct {
    char_u   *dout_fname;  // used for external diff
    garray_T  dout_ga;     // used for internal diff
} diffout_T;

// Diff2Hunk represents a forward linked list of diff hunks as defined by
// unified or ed-style diff formats.
typedef struct diff2_hunk Diff2Hunk;
struct diff2_hunk {
  Diff2Hunk  *next;
  linenr_T       lstart_orig;
  linenr_T       count_orig;
  long           lstart_dest;
  long           count_dest;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "diff.h.generated.h"
#endif
#endif  // NVIM_DIFF_H
