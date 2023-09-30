#ifndef NVIM_FOLD_H
#define NVIM_FOLD_H

#include <stdio.h>

#include "nvim/buffer_defs.h"
#include "nvim/fold_defs.h"
#include "nvim/garray.h"
#include "nvim/macros.h"
#include "nvim/pos.h"
#include "nvim/types.h"

EXTERN int disable_fold_update INIT(= 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "fold.h.generated.h"
#endif
#endif  // NVIM_FOLD_H
