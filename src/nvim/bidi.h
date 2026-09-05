#pragma once
// Bidirectional text support.  See bidi.c.

#include <stdbool.h>

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

#include "bidi.h.generated.h"
