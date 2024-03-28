#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"

/// NW -> 0
/// NE -> kFloatAnchorEast
/// SW -> kFloatAnchorSouth
/// SE -> kFloatAnchorSouth | kFloatAnchorEast
EXTERN const char *const float_anchor_str[] INIT( = { "NW", "NE", "SW", "SE" });

#define FOR_ALL_FLOAT_WINDOWS(wp) \
  for (win_T *wp = lastwin; wp && wp->w_floating; wp = wp->w_prev)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "winfloat.h.generated.h"
#endif
