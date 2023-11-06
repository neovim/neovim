#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "nvim/cmdexpand_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/func_attr.h"
#include "nvim/grid_defs.h"
#include "nvim/mbyte_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/types.h"

// Return byte length of character that starts with byte "b".
// Returns 1 for a single-byte character.
// MB_BYTE2LEN_CHECK() can be used to count a special key as one byte.
// Don't call MB_BYTE2LEN(b) with b < 0 or b > 255!
#define MB_BYTE2LEN(b)         utf8len_tab[b]
#define MB_BYTE2LEN_CHECK(b)   (((b) < 0 || (b) > 255) ? 1 : utf8len_tab[b])

extern const uint8_t utf8len_tab_zero[256];

extern const uint8_t utf8len_tab[256];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.h.generated.h"
#endif

static inline int mb_strcmp_ic(bool ic, const char *s1, const char *s2)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Compare strings
///
/// @param[in]  ic  True if case is to be ignored.
///
/// @return 0 if s1 == s2, <0 if s1 < s2, >0 if s1 > s2.
static inline int mb_strcmp_ic(bool ic, const char *s1, const char *s2)
{
  return (ic ? mb_stricmp(s1, s2) : strcmp(s1, s2));
}
