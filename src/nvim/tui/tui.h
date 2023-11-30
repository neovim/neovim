#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/highlight_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/ui_defs.h"  // IWYU pragma: keep

typedef struct TUIData TUIData;

typedef enum {
  kTermModeSynchronizedOutput = 2026,
} TermMode;

typedef enum {
  kTermModeNotRecognized = 0,
  kTermModeSet = 1,
  kTermModeReset = 2,
  kTermModePermanentlySet = 3,
  kTermModePermanentlyReset = 4,
} TermModeState;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/tui.h.generated.h"
#endif
