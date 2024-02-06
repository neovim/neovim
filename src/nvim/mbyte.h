#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>  // IWYU pragma: keep
#include <uv.h>  // IWYU pragma: keep

#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/func_attr.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mbyte.h.generated.h"
#endif

enum {
  kInvalidByteCells = 4,
};

// Return byte length of character that starts with byte "b".
// Returns 1 for a single-byte character.
// MB_BYTE2LEN_CHECK() can be used to count a special key as one byte.
// Don't call MB_BYTE2LEN(b) with b < 0 or b > 255!
#define MB_BYTE2LEN(b)         utf8len_tab[b]
#define MB_BYTE2LEN_CHECK(b)   (((b) < 0 || (b) > 255) ? 1 : utf8len_tab[b])

extern const uint8_t utf8len_tab_zero[256];

extern const uint8_t utf8len_tab[256];

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

static inline CharInfo utf_ptr2CharInfo(char const *p_in)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_ALWAYS_INLINE;

/// Convert a UTF-8 byte sequence to a Unicode code point.
/// Handles ascii, multibyte sequiences and illegal sequences.
///
/// @param[in]  p_in  String to convert.
///
/// @return information abouth the character. When the sequence is illegal,
/// "value" is negative, "len" is 1.
static inline CharInfo utf_ptr2CharInfo(char const *const p_in)
{
  uint8_t const *const p = (uint8_t const *)p_in;
  uint8_t const first = *p;
  if (first < 0x80) {
    return (CharInfo){ .value = first, .len = 1 };
  } else {
    int len = utf8len_tab[first];
    int32_t const code_point = utf_ptr2CharInfo_impl(p, (uintptr_t)len);
    if (code_point < 0) {
      len = 1;
    }
    return (CharInfo){ .value = code_point, .len = len };
  }
}

static inline StrCharInfo utfc_next(StrCharInfo cur)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_ALWAYS_INLINE REAL_FATTR_PURE;

/// Return information about the next character.
/// Composing and combining characters are considered a part of the current character.
///
/// @param[in] cur  Information about the current character in the string.
static inline StrCharInfo utfc_next(StrCharInfo cur)
{
  int32_t prev_code = cur.chr.value;
  uint8_t *next = (uint8_t *)(cur.ptr + cur.chr.len);

  while (true) {
    if (EXPECT(*next < 0x80U, true)) {
      return (StrCharInfo){
        .ptr = (char *)next,
        .chr = (CharInfo){ .value = *next, .len = 1 },
      };
    }
    uint8_t const next_len = utf8len_tab[*next];
    int32_t const next_code = utf_ptr2CharInfo_impl(next, (uintptr_t)next_len);
    if (!utf_char_composinglike(prev_code, next_code)) {
      return (StrCharInfo){
        .ptr = (char *)next,
        .chr = (CharInfo){ .value = next_code, .len = (next_code < 0 ? 1 : next_len) },
      };
    }

    prev_code = next_code;
    next += next_len;
  }
}

static inline StrCharInfo utf_ptr2StrCharInfo(char *ptr)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_ALWAYS_INLINE REAL_FATTR_PURE;

static inline StrCharInfo utf_ptr2StrCharInfo(char *ptr)
{
  return (StrCharInfo){ .ptr = ptr, .chr = utf_ptr2CharInfo(ptr) };
}
