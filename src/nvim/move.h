#pragma once

#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

#include "move.h.generated.h"

/// Restore filler lines provided by decoration virtual lines after a view
/// operation cleared the window's top filler. Diff filler is intentionally
/// excluded because querying it may evaluate user code.
void reconcile_topfill(win_T *wp);
