#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/ex_getln_defs.h"  // IWYU pragma: keep
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// flags used by vim_strsave_fnameescape()
enum {
  VSE_NONE   = 0,
  VSE_SHELL  = 1,  ///< escape for a shell command
  VSE_BUFFER = 2,  ///< escape for a ":buffer" command
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_getln.h.generated.h"
#endif
