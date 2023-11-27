#pragma once

#include <stdio.h>

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/fold_defs.h"  // IWYU pragma: export
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/macros.h"
#include "nvim/pos_defs.h"
#include "nvim/types.h"

EXTERN int disable_fold_update INIT( = 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.h.generated.h"
#endif
