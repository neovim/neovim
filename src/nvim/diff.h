#ifndef NVIM_DIFF_H
#define NVIM_DIFF_H

#include "nvim/pos.h"
#include "nvim/ex_cmds_defs.h"

// Value set from 'diffopt'.
EXTERN int diff_context INIT(= 6);  // context for folds
EXTERN int diff_foldcolumn INIT(= 2);  // 'foldcolumn' for diff mode
EXTERN bool diff_need_scrollbind INIT(= false);

EXTERN bool need_diff_redraw INIT(= false);  // need to call diff_redraw()

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "diff.h.generated.h"
#endif
#endif  // NVIM_DIFF_H
