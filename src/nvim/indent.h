#pragma once

#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/normal_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

typedef int (*IndentGetter)(void);

/// flags for set_indent()
enum {
  SIN_CHANGED = 1,  ///< call changed_bytes() when line changed
  SIN_INSERT  = 2,  ///< insert indent before existing text
  SIN_UNDO    = 4,  ///< save line for undo before changing it
  SIN_NOMARK  = 8,  ///< don't adjust extmarks
};

typedef int (*Indenter)(void);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "indent.h.generated.h"
#endif
