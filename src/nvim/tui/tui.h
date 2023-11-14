#pragma once

#include "nvim/cursor_shape.h"
#include "nvim/ui.h"

typedef struct TUIData TUIData;

typedef enum {
  kDecModeSynchronizedOutput = 2026,
} TerminalDecMode;

typedef enum {
  kTerminalModeNotRecognized = 0,
  kTerminalModeSet = 1,
  kTerminalModeReset = 2,
  kTerminalModePermanentlySet = 3,
  kTerminalModePermanentlyReset = 4,
} TerminalModeState;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "tui/tui.h.generated.h"
#endif
