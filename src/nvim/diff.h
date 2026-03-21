#pragma once

#include <stdbool.h>

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep

// Value set from 'diffopt'.
EXTERN int diff_context INIT( = 6);  ///< context for folds
EXTERN int diff_foldcolumn INIT( = 2);  ///< 'foldcolumn' for diff mode
EXTERN bool diff_need_scrollbind INIT( = false);

EXTERN bool need_diff_redraw INIT( = false);  ///< need to call diff_redraw()

#include "diff.h.generated.h"
