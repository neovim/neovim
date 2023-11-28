#pragma once

#include "nvim/ex_cmds_defs.h"
#include "nvim/mark_defs.h"  // IWYU pragma: export

/// Global marks (marks with file number or name)
EXTERN xfmark_T namedfm[NGLOBALMARKS] INIT( = { 0 });

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark.h.generated.h"
#endif
