#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/func_attr.h"
#include "nvim/option_vars.h"
#include "nvim/strings.h"  // IWYU pragma: keep

/// Flags for vim_str2nr()
typedef enum {
  STR2NR_DEC = 0,
  STR2NR_BIN = (1 << 0),  ///< Allow binary numbers.
  STR2NR_OCT = (1 << 1),  ///< Allow octal numbers.
  STR2NR_HEX = (1 << 2),  ///< Allow hexadecimal numbers.
  STR2NR_OOCT = (1 << 3),  ///< Octal with prefix "0o": 0o777
  /// Force one of the above variants.
  ///
  /// STR2NR_FORCE|STR2NR_DEC is actually not different from supplying zero
  /// as flags, but still present for completeness.
  ///
  /// STR2NR_FORCE|STR2NR_OCT|STR2NR_OOCT is the same as STR2NR_FORCE|STR2NR_OCT
  /// or STR2NR_FORCE|STR2NR_OOCT.
  STR2NR_FORCE = (1 << 7),
  /// Recognize all formats vim_str2nr() can recognize.
  STR2NR_ALL = STR2NR_BIN | STR2NR_OCT | STR2NR_HEX | STR2NR_OOCT,
  /// Disallow octals numbers without the 0o prefix.
  STR2NR_NO_OCT = STR2NR_BIN | STR2NR_HEX | STR2NR_OOCT,
  STR2NR_QUOTE = (1 << 4),  ///< Ignore embedded single quotes.
} ChStr2NrFlags;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "charset.h.generated.h"
#endif

static inline bool vim_isbreak(int c)
  REAL_FATTR_CONST
  REAL_FATTR_ALWAYS_INLINE;

/// Check if `c` is one of the characters in 'breakat'.
/// Used very often if 'linebreak' is set
static inline bool vim_isbreak(int c)
{
  return breakat_flags[(uint8_t)c];
}
