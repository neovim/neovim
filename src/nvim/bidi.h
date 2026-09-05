#pragma once
// Bidirectional text support.  See bidi.c.

#include <stdbool.h>

#include "nvim/buffer_defs.h"

/// Bidirectional character classes, the subset of UAX #9 table 4 that is
/// resolved.  The explicit formatting and isolate classes read as kBidiON.
typedef enum {
  kBidiL,    ///< strong left-to-right
  kBidiR,    ///< strong right-to-left
  kBidiAL,   ///< strong right-to-left, Arabic
  kBidiEN,   ///< European number
  kBidiES,   ///< European separator
  kBidiET,   ///< European terminator
  kBidiAN,   ///< Arabic number
  kBidiCS,   ///< common separator
  kBidiS,    ///< segment separator
  kBidiB,    ///< paragraph separator
  kBidiWS,   ///< whitespace
  kBidiON,   ///< other neutral
} BidiClass;

/// What 'bidi' does with the lines of a window.
typedef enum {
  kBidiOff,   ///< nothing
  kBidiAuto,  ///< reorder, taking the direction of a paragraph from its text
  kBidiLtr,   ///< reorder, every paragraph reading left to right
  kBidiRtl,   ///< reorder, every paragraph reading right to left
} BidiMode;

#include "bidi.h.generated.h"
