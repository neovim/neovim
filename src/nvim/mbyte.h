#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>  // IWYU pragma: keep
#include <utf8proc.h>
#include <uv.h>  // IWYU pragma: keep

#include "nvim/ascii_defs.h"
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/mbyte_defs.h"  // IWYU pragma: keep
#include "nvim/option_vars.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

#define GRAPHEME_STATE_INIT 0

#include "mbyte.h.generated.h"
#include "mbyte.h.inline.generated.h"

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

/// Check whether a given UTF-8 byte is a trailing byte (10xx.xxxx).

static inline bool utf_is_trail_byte(uint8_t const byte)
  FUNC_ATTR_CONST FUNC_ATTR_ALWAYS_INLINE
{
  // uint8_t is for clang to use smaller cmp
  return (uint8_t)(byte & 0xC0U) == 0x80U;
}

/// Convert a UTF-8 byte sequence to a Unicode code point.
/// Handles ascii, multibyte sequiences and illegal sequences.
///
/// @param[in]  p_in  String to convert.
///
/// @return information abouth the character. When the sequence is illegal,
/// "value" is negative, "len" is 1.
static inline CharInfo utf_ptr2CharInfo(char const *const p_in)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
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

static inline StrCharInfo utf_ptr2StrCharInfo(const char *ptr)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_PURE
{
  return (StrCharInfo){ .ptr = ptr, .chr = utf_ptr2CharInfo(ptr) };
}

// only c.value is used here but it is a hint that it is the return value of ptr2CharInfo
// that is expected
static inline int basechar_cells_impl(CharInfo c)
{
  return c.value < 0 ? 4 : (c.value < 0x80 ? ascii2cells(c.value) : utf_char2cells(c.value));
}

/// Return information about the cluster width next character.
/// Composing and combining characters are considered a part of the current character.
///
/// @param[in] cur  Information about the current character in the string.
static inline ClusterInfo utf_ClusterInfo(StrCharInfo cur)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_PURE
{
  // most of the time time caller should already have checked for NUL, so
  // this will be inlined to nothing. But always be NUL safe.
  if (EXPECT(*cur.ptr == NUL, false)) {
    return (ClusterInfo) {
      .next = cur,
      .cells = dy_escape_width,
    };
  }

  uint8_t *next = (uint8_t *)(cur.ptr + cur.chr.len);
  // handle ASCII case inline
  if (EXPECT(*next < 0x80U, true)) {
    return (ClusterInfo) {
      .next = (StrCharInfo){
        .ptr = (char *)next,
        .chr = (CharInfo){ .value = *next, .len = 1 },
      },
      .cells = basechar_cells_impl(cur.chr)
    };
  }
  return utf_ClusterInfo_impl(cur, INT_MAX);
}

/// Return number of display cells occupied by ASCII byte "b".
///
/// chars outside of the range 0 <= b <= 127 is considered unprintable.
/// Use a proper wrapper for multibyte chars depending on the context, like
/// char2cells() or ptr2cells()
/// A TAB is counted as two or four cells: "^I" or "<09>".
///
/// @param b
///
/// @return Number of display cells.
static inline int ascii2cells(int b)
  FUNC_ATTR_PURE
{
  return (b >= ' ' && b <= '~') ? 1 : dy_escape_width;
}
