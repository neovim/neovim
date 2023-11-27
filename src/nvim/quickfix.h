#pragma once

#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

// flags for skip_vimgrep_pat()
#define VGR_GLOBAL      1
#define VGR_NOJUMP      2
#define VGR_FUZZY       4

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "quickfix.h.generated.h"
#endif
