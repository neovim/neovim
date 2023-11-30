#pragma once

#include <stdio.h>  // IWYU pragma: keep

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/fold_defs.h"  // IWYU pragma: export
#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

EXTERN int disable_fold_update INIT( = 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.h.generated.h"
#endif
