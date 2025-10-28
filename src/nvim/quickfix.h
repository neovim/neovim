#pragma once

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// flags for skip_vimgrep_pat()
enum {
  VGR_GLOBAL = 1,
  VGR_NOJUMP = 2,
  VGR_FUZZY  = 4,
};

#include "quickfix.h.generated.h"
