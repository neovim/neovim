#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "auto/config.h"  // IWYU pragma: keep
#include "nvim/base64.h"
#include "nvim/memory.h"

#ifdef HAVE_BE64TOH
# include ENDIAN_INCLUDE_FILE
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "base64.c.generated.h"
#endif

static const char alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Indices are 1-based because we use 0 to indicate a letter that is not part of the alphabet
static const uint8_t char_to_index[256] = {
  ['A'] = 1,  ['B'] = 2,  ['C'] = 3, ['D'] = 4,  ['E'] = 5,  ['F'] = 6,  ['G'] = 7,  ['H'] = 8,
  ['I'] = 9,  ['J'] = 10, ['K'] = 11, ['L'] = 12, ['M'] = 13, ['N'] = 14, ['O'] = 15, ['P'] = 16,
  ['Q'] = 17, ['R'] = 18, ['S'] = 19, ['T'] = 20, ['U'] = 21, ['V'] = 22, ['W'] = 23, ['X'] = 24,
  ['Y'] = 25, ['Z'] = 26, ['a'] = 27, ['b'] = 28, ['c'] = 29, ['d'] = 30, ['e'] = 31, ['f'] = 32,
  ['g'] = 33, ['h'] = 34, ['i'] = 35, ['j'] = 36, ['k'] = 37, ['l'] = 38, ['m'] = 39, ['n'] = 40,
  ['o'] = 41, ['p'] = 42, ['q'] = 43, ['r'] = 44, ['s'] = 45, ['t'] = 46, ['u'] = 47, ['v'] = 48,
  ['w'] = 49, ['x'] = 50, ['y'] = 51, ['z'] = 52, ['0'] = 53, ['1'] = 54, ['2'] = 55, ['3'] = 56,
  ['4'] = 57, ['5'] = 58, ['6'] = 59, ['7'] = 60, ['8'] = 61, ['9'] = 62, ['+'] = 63, ['/'] = 64,
};

#ifndef HAVE_BE64TOH
static inline uint64_t htobe64(uint64_t host_64bits)
{
# ifdef ORDER_BIG_ENDIAN
  return host_64bits;
# else
  uint8_t *buf = (uint8_t *)&host_64bits;
  uint64_t ret = 0;
  for (size_t i = 8; i; i--) {
    ret |= ((uint64_t)buf[i - 1]) << ((8 - i) * 8);
  }
  return ret;
# endif
}

static inline uint32_t htobe32(uint32_t host_32bits)
{
# ifdef ORDER_BIG_ENDIAN
  return host_32bits;
# else
  uint8_t *buf = (uint8_t *)&host_32bits;
  uint32_t ret = 0;
  for (size_t i = 4; i; i--) {
    ret |= ((uint32_t)buf[i - 1]) << ((4 - i) * 8);
  }
  return ret;
# endif
}
#endif

/// Encode a string using Base64.
///
/// @param src String to encode
/// @param src_len Length of the string
/// @return Base64 encoded string
char *base64_encode(const char *src, size_t src_len)
  FUNC_ATTR_NONNULL_ALL
{
  assert(src != NULL);

  const size_t out_len = ((src_len + 2) / 3) * 4;
  char *dest = xmalloc(out_len + 1);

  size_t src_i = 0;
  size_t out_i = 0;

  const uint8_t *s = (const uint8_t *)src;

  // Read 8 bytes at a time as much as we can
  for (; src_i + 7 < src_len; src_i += 6) {
    uint64_t bits_h;
    memcpy(&bits_h, &s[src_i], sizeof(uint64_t));
    const uint64_t bits_be = htobe64(bits_h);
    dest[out_i + 0] = alphabet[(bits_be >> 58) & 0x3F];
    dest[out_i + 1] = alphabet[(bits_be >> 52) & 0x3F];
    dest[out_i + 2] = alphabet[(bits_be >> 46) & 0x3F];
    dest[out_i + 3] = alphabet[(bits_be >> 40) & 0x3F];
    dest[out_i + 4] = alphabet[(bits_be >> 34) & 0x3F];
    dest[out_i + 5] = alphabet[(bits_be >> 28) & 0x3F];
    dest[out_i + 6] = alphabet[(bits_be >> 22) & 0x3F];
    dest[out_i + 7] = alphabet[(bits_be >> 16) & 0x3F];
    out_i += sizeof(uint64_t);
  }

  for (; src_i + 3 < src_len; src_i += 3) {
    uint32_t bits_h;
    memcpy(&bits_h, &s[src_i], sizeof(uint32_t));
    const uint32_t bits_be = htobe32(bits_h);
    dest[out_i + 0] = alphabet[(bits_be >> 26) & 0x3F];
    dest[out_i + 1] = alphabet[(bits_be >> 20) & 0x3F];
    dest[out_i + 2] = alphabet[(bits_be >> 14) & 0x3F];
    dest[out_i + 3] = alphabet[(bits_be >> 8) & 0x3F];
    out_i += sizeof(uint32_t);
  }

  if (src_i + 2 < src_len) {
    dest[out_i + 0] = alphabet[s[src_i] >> 2];
    dest[out_i + 1] = alphabet[((s[src_i] & 0x3) << 4) | (s[src_i + 1] >> 4)];
    dest[out_i + 2] = alphabet[(s[src_i + 1] & 0xF) << 2 | (s[src_i + 2] >> 6)];
    dest[out_i + 3] = alphabet[(s[src_i + 2] & 0x3F)];
    out_i += 4;
  } else if (src_i + 1 < src_len) {
    dest[out_i + 0] = alphabet[s[src_i] >> 2];
    dest[out_i + 1] = alphabet[((s[src_i] & 0x3) << 4) | (s[src_i + 1] >> 4)];
    dest[out_i + 2] = alphabet[(s[src_i + 1] & 0xF) << 2];
    out_i += 3;
  } else if (src_i < src_len) {
    dest[out_i + 0] = alphabet[s[src_i] >> 2];
    dest[out_i + 1] = alphabet[(s[src_i] & 0x3) << 4];
    out_i += 2;
  }

  for (; out_i < out_len; out_i++) {
    dest[out_i] = '=';
  }

  dest[out_len] = '\0';

  return dest;
}

/// Decode a Base64 encoded string.
///
/// The returned string is NOT null-terminated, because the decoded string may
/// contain embedded NULLs. Use the output parameter out_lenp to determine the
/// length of the returned string.
///
/// @param src Base64 encoded string
/// @param src_len Length of {src}
/// @param [out] out_lenp Returns the length of the decoded string
/// @return Decoded string
char *base64_decode(const char *src, size_t src_len, size_t *out_lenp)
{
  assert(src != NULL);
  assert(out_lenp != NULL);

  char *dest = NULL;

  if (src_len % 4 != 0) {
    goto invalid;
  }

  size_t out_len = (src_len / 4) * 3;
  if (src_len >= 1 && src[src_len - 1] == '=') {
    out_len--;
  }
  if (src_len >= 2 && src[src_len - 2] == '=') {
    out_len--;
  }

  const uint8_t *s = (const uint8_t *)src;

  dest = xmalloc(out_len);

  int acc = 0;
  int acc_len = 0;
  size_t out_i = 0;
  size_t src_i = 0;
  int leftover_i = -1;

  for (; src_i < src_len; src_i++) {
    const uint8_t c = s[src_i];
    const uint8_t d = char_to_index[c];
    if (d == 0) {
      if (c == '=') {
        leftover_i = (int)src_i;
        break;
      }
      goto invalid;
    }

    acc = ((acc << 6) & 0xFFF) + (d - 1);
    acc_len += 6;
    if (acc_len >= 8) {
      acc_len -= 8;
      dest[out_i] = (char)(acc >> acc_len);
      out_i += 1;
    }
  }

  if (acc_len > 4 || ((acc & ((1 << acc_len) - 1)) != 0)) {
    goto invalid;
  }

  if (leftover_i > -1) {
    int padding_len = acc_len / 2;
    int padding_chars = 0;
    for (; (size_t)leftover_i < src_len; leftover_i++) {
      const uint8_t c = s[leftover_i];
      if (c != '=') {
        goto invalid;
      }
      padding_chars += 1;
    }

    if (padding_chars != padding_len) {
      goto invalid;
    }
  }

  *out_lenp = out_len;

  return dest;

invalid:
  if (dest) {
    xfree((void *)dest);
  }

  *out_lenp = 0;

  return NULL;
}
