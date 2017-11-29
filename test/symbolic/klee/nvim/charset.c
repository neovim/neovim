#include <stdbool.h>

#include "nvim/ascii.h"
#include "nvim/macros.h"
#include "nvim/charset.h"
#include "nvim/eval/typval.h"
#include "nvim/vim.h"

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
  const bool negative = (ptr[0] == '-');
  uvarnumber_T un = 0;

  if (negative) {
    ptr++;
  }

  if (what & STR2NR_FORCE) {
    // When forcing main consideration is skipping the prefix. Octal and decimal
    // numbers have no prefixes to skip. pre is not set.
    switch ((unsigned)what & (~(unsigned)STR2NR_FORCE)) {
      case STR2NR_HEX: {
        if (!STRING_ENDED(ptr + 2)
            && ptr[0] == '0'
            && (ptr[1] == 'x' || ptr[1] == 'X')
            && ascii_isxdigit(ptr[2])) {
          ptr += 2;
        }
        goto vim_str2nr_hex;
      }
      case STR2NR_BIN: {
        if (!STRING_ENDED(ptr + 2)
            && ptr[0] == '0'
            && (ptr[1] == 'b' || ptr[1] == 'B')
            && ascii_isbdigit(ptr[2])) {
          ptr += 2;
        }
        goto vim_str2nr_bin;
      }
      case STR2NR_OCT: {
        goto vim_str2nr_oct;
      }
      case 0: {
        goto vim_str2nr_dec;
      }
      default: {
        assert(false);
      }
    }
  } else if ((what & (STR2NR_HEX|STR2NR_OCT|STR2NR_BIN))
             && !STRING_ENDED(ptr + 1)
             && ptr[0] == '0' && ptr[1] != '8' && ptr[1] != '9') {
    pre = ptr[1];
    // Detect hexadecimal: 0x or 0X follwed by hex digit
    if ((what & STR2NR_HEX)
        && !STRING_ENDED(ptr + 2)
        && (pre == 'X' || pre == 'x')
        && ascii_isxdigit(ptr[2])) {
      ptr += 2;
      goto vim_str2nr_hex;
    }
    // Detect binary: 0b or 0B follwed by 0 or 1
    if ((what & STR2NR_BIN)
        && !STRING_ENDED(ptr + 2)
        && (pre == 'B' || pre == 'b')
        && ascii_isbdigit(ptr[2])) {
      ptr += 2;
      goto vim_str2nr_bin;
    }
    // Detect octal number: zero followed by octal digits without '8' or '9'
    pre = 0;
    if (!(what & STR2NR_OCT)) {
      goto vim_str2nr_dec;
    }
    for (int i = 2; !STRING_ENDED(ptr + i) && ascii_isdigit(ptr[i]); i++) {
      if (ptr[i] > '7') {
        goto vim_str2nr_dec;
      }
    }
    pre = '0';
    goto vim_str2nr_oct;
  } else {
    goto vim_str2nr_dec;
  }

  // Do the string-to-numeric conversion "manually" to avoid sscanf quirks.
  assert(false);  // Should’ve used goto earlier.
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
  switch (pre) {
    case 'b':
    case 'B': {
vim_str2nr_bin:
      PARSE_NUMBER(2, (*ptr == '0' || *ptr == '1'), (*ptr - '0'));
      break;
    }
    case '0': {
vim_str2nr_oct:
      PARSE_NUMBER(8, ('0' <= *ptr && *ptr <= '7'), (*ptr - '0'));
      break;
    }
    case 0: {
vim_str2nr_dec:
      PARSE_NUMBER(10, (ascii_isdigit(*ptr)), (*ptr - '0'));
      break;
    }
    case 'x':
    case 'X': {
vim_str2nr_hex:
      PARSE_NUMBER(16, (ascii_isxdigit(*ptr)), (hex2nr(*ptr)));
      break;
    }
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
