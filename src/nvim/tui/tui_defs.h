#pragma once

typedef struct TUIData TUIData;

typedef enum {
  kTermModeLeftAndRightMargins = 69,
  kTermModeMouseButtonEvent = 1002,
  kTermModeMouseAnyEvent = 1003,
  kTermModeMouseSGRExt = 1006,
  kTermModeBracketedPaste = 2004,
  kTermModeSynchronizedOutput = 2026,
  kTermModeGraphemeClusters = 2027,
  kTermModeThemeUpdates = 2031,
  kTermModeResizeEvents = 2048,
} TermMode;

typedef enum {
  kTermModeNotRecognized = 0,
  kTermModeSet = 1,
  kTermModeReset = 2,
  kTermModePermanentlySet = 3,
  kTermModePermanentlyReset = 4,
} TermModeState;
