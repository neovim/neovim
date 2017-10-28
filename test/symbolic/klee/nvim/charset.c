#include <stdbool.h>

#include "nvim/ascii.h"
#include "nvim/macros.h"
#include "nvim/charset.h"
#include "nvim/eval/typval.h"
#include "nvim/vim.h"

bool vim_isIDc(int c)
{
  return ASCII_ISALNUM(c);
}

int hex2nr(int c)
{
  if ((c >= 'a') && (c <= 'f')) {
    return c - 'a' + 10;
  }

  if ((c >= 'A') && (c <= 'F')) {
    return c - 'A' + 10;
  }
  return c - '0';
}

void vim_str2nr(const char_u *const start, int *const prep, int *const len,
                const int what, varnumber_T *const nptr,
                uvarnumber_T *const unptr, const int maxlen)
{
  const char *ptr = (const char *)start;
#define STRING_ENDED(ptr) \
    (!(maxlen == 0 || (int)((ptr) - (const char *)start) < maxlen))
  int pre = 0;  // default is decimal
  bool negative = false;

  if (ptr[0] == '-') {
    negative = true;
    ptr++;
  }

  // Recognize hex, octal and bin.
  if ((what & (STR2NR_HEX|STR2NR_OCT|STR2NR_BIN))
      && !STRING_ENDED(ptr + 1)
      && ptr[0] == '0' && ptr[1] != '8' && ptr[1] != '9') {
    pre = ptr[1];

    if ((what & STR2NR_HEX)
        && !STRING_ENDED(ptr + 2)
        && (pre == 'X' || pre == 'x')
        && ascii_isxdigit(ptr[2])) {
      // hexadecimal
      ptr += 2;
    } else if ((what & STR2NR_BIN)
               && !STRING_ENDED(ptr + 2)
               && (pre == 'B' || pre == 'b')
               && ascii_isbdigit(ptr[2])) {
      // binary
      ptr += 2;
    } else {
      // decimal or octal, default is decimal
      pre = 0;

      if (what & STR2NR_OCT
          && !STRING_ENDED(ptr + 1)
          && ('0' <= ptr[1] && ptr[1] <= '7')) {
        // Assume octal now: what we already know is that string starts with
        // zero and some octal digit.
        pre = '0';
        // Don’t interpret "0", "008" or "0129" as octal.
        for (int i = 2; !STRING_ENDED(ptr + i) && ascii_isdigit(ptr[i]); i++) {
          if (ptr[i] > '7') {
            // Can’t be octal.
            pre = 0;
            break;
          }
        }
      }
    }
  }

  // Do the string-to-numeric conversion "manually" to avoid sscanf quirks.
  uvarnumber_T un = 0;
#define PARSE_NUMBER(base, cond, conv) \
  do { \
    while (!STRING_ENDED(ptr) && (cond)) { \
      /* avoid ubsan error for overflow */ \
      if (un < UVARNUMBER_MAX / base) { \
        un = base * un + (uvarnumber_T)(conv); \
      } else { \
        un = UVARNUMBER_MAX; \
      } \
      ptr++; \
    } \
  } while (0)
  if (pre == 'B' || pre == 'b' || what == (STR2NR_BIN|STR2NR_FORCE)) {
    // Binary number.
    PARSE_NUMBER(2, (*ptr == '0' || *ptr == '1'), (*ptr - '0'));
  } else if (pre == '0' || what == (STR2NR_OCT|STR2NR_FORCE)) {
    // Octal number.
    PARSE_NUMBER(8, ('0' <= *ptr && *ptr <= '7'), (*ptr - '0'));
  } else if (pre == 'X' || pre == 'x' || what == (STR2NR_HEX|STR2NR_FORCE)) {
    // Hexadecimal number.
    PARSE_NUMBER(16, (ascii_isxdigit(*ptr)), (hex2nr(*ptr)));
  } else {
    // Decimal number.
    PARSE_NUMBER(10, (ascii_isdigit(*ptr)), (*ptr - '0'));
  }
#undef PARSE_NUMBER

  if (prep != NULL) {
    *prep = pre;
  }

  if (len != NULL) {
    *len = (int)(ptr - (const char *)start);
  }

  if (nptr != NULL) {
    if (negative) {  // account for leading '-' for decimal numbers
      // avoid ubsan error for overflow
      if (un > VARNUMBER_MAX) {
        *nptr = VARNUMBER_MIN;
      } else {
        *nptr = -(varnumber_T)un;
      }
    } else {
      if (un > VARNUMBER_MAX) {
        un = VARNUMBER_MAX;
      }
      *nptr = (varnumber_T)un;
    }
  }

  if (unptr != NULL) {
    *unptr = un;
  }
#undef STRING_ENDED
}
