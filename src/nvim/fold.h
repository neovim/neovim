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

void foldRemoveManual(buf_T *buf, linenr_T top, linenr_T bot);

#include "fold.h.generated.h"
