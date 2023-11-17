#pragma once

#include "nvim/cursor_shape.h"
#include "nvim/ui.h"

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
