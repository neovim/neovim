#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <sys/types.h>  // IWYU pragma: keep
#include <uv.h>  // IWYU pragma: keep

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/func_attr.h"
#include "nvim/mbyte_defs.h"  // IWYU pragma: export
#include "nvim/types_defs.h"  // IWYU pragma: keep

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.h.generated.h"
#endif

// Return byte length of character that starts with byte "b".
// Returns 1 for a single-byte character.
// MB_BYTE2LEN_CHECK() can be used to count a special key as one byte.
// Don't call MB_BYTE2LEN(b) with b < 0 or b > 255!
#define MB_BYTE2LEN(b)         utf8len_tab[b]
#define MB_BYTE2LEN_CHECK(b)   (((b) < 0 || (b) > 255) ? 1 : utf8len_tab[b])

extern const uint8_t utf8len_tab_zero[256];

extern const uint8_t utf8len_tab[256];

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

// Use our own character-case definitions, because the current locale may
// differ from what the .spl file uses.
// These must not be called with negative number!
// Multi-byte implementation.  For Unicode we can call utf_*(), but don't do
// that for ASCII, because we don't want to use 'casemap' here.  Otherwise use
// the "w" library function for characters above 255.
#define SPELL_TOFOLD(c) ((c) >= 128 ? utf_fold(c) : (int)spelltab.st_fold[c])

#define SPELL_TOUPPER(c) ((c) >= 128 ? mb_toupper(c) : (int)spelltab.st_upper[c])

#define SPELL_ISUPPER(c) ((c) >= 128 ? mb_isupper(c) : spelltab.st_isu[c])

// MB_PTR_ADV(): advance a pointer to the next character, taking care of
// multi-byte characters if needed. Skip over composing chars.
#define MB_PTR_ADV(p)      (p += utfc_ptr2len((char *)p))

// MB_PTR_BACK(): backup a pointer to the previous character, taking care of
// multi-byte characters if needed. Only use with "p" > "s" !
#define MB_PTR_BACK(s, p) \
  (p -= utf_head_off((char *)(s), (char *)(p) - 1) + 1)
