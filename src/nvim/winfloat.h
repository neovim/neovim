#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"

/// NW -> 0
/// NE -> kFloatAnchorEast
/// SW -> kFloatAnchorSouth
/// SE -> kFloatAnchorSouth | kFloatAnchorEast
EXTERN const char *const float_anchor_str[] INIT( = { "NW", "NE", "SW", "SE" });

/// Keep in sync with FloatRelative in buffer_defs.h
EXTERN const char *const float_relative_str[]
INIT( = { "editor", "win", "cursor", "mouse" });

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "winfloat.h.generated.h"
#endif
