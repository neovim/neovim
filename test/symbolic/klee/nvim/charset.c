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
  const char_u *ptr = start;
  int pre = 0;  // default is decimal
  bool negative = false;
  uvarnumber_T un = 0;

  if (ptr[0] == '-') {
    negative = true;
    ptr++;
  }

  // Recognize hex, octal and bin.
  if ((what & (STR2NR_HEX|STR2NR_OCT|STR2NR_BIN))
      && (maxlen == 0 || maxlen > 1)
      && (ptr[0] == '0') && (ptr[1] != '8') && (ptr[1] != '9')) {
    pre = ptr[1];

    if ((what & STR2NR_HEX)
        && (maxlen == 0 || maxlen > 2)
        && ((pre == 'X') || (pre == 'x'))
        && ascii_isxdigit(ptr[2])) {
      // hexadecimal
      ptr += 2;
    } else if ((what & STR2NR_BIN)
               && (maxlen == 0 || maxlen > 2)
               && ((pre == 'B') || (pre == 'b'))
               && ascii_isbdigit(ptr[2])) {
      // binary
      ptr += 2;
    } else {
      // decimal or octal, default is decimal
      pre = 0;

      if (what & STR2NR_OCT) {
        // Don't interpret "0", "08" or "0129" as octal.
        for (int n = 1; ascii_isdigit(ptr[n]); ++n) {
          if (ptr[n] > '7') {
            // can't be octal
            pre = 0;
            break;
          }
          if (ptr[n] >= '0') {
            // assume octal
            pre = '0';
          }
          if (n == maxlen) {
            break;
          }
        }
      }
    }
  }

  // Do the string-to-numeric conversion "manually" to avoid sscanf quirks.
  int n = 1;
  if (pre == 'B' || pre == 'b' || what == (STR2NR_BIN|STR2NR_FORCE)) {
    // bin
    if (pre != 0) {
      n += 2;  // skip over "0b"
    }
    while ('0' <= *ptr && *ptr <= '1') {
      // avoid ubsan error for overflow
      if (un < UVARNUMBER_MAX / 2) {
        un = 2 * un + (uvarnumber_T)(*ptr - '0');
      } else {
        un = UVARNUMBER_MAX;
      }
      ptr++;
      if (n++ == maxlen) {
        break;
      }
    }
  } else if (pre == '0' || what == (STR2NR_OCT|STR2NR_FORCE)) {
    // octal
    while ('0' <= *ptr && *ptr <= '7') {
      // avoid ubsan error for overflow
      if (un < UVARNUMBER_MAX / 8) {
        un = 8 * un + (uvarnumber_T)(*ptr - '0');
      } else {
        un = UVARNUMBER_MAX;
      }
      ptr++;
      if (n++ == maxlen) {
        break;
      }
    }
  } else if (pre == 'X' || pre == 'x' || what == (STR2NR_HEX|STR2NR_FORCE)) {
    // hex
    if (pre != 0) {
      n += 2;  // skip over "0x"
    }
    while (ascii_isxdigit(*ptr)) {
      // avoid ubsan error for overflow
      if (un < UVARNUMBER_MAX / 16) {
        un = 16 * un + (uvarnumber_T)hex2nr(*ptr);
      } else {
        un = UVARNUMBER_MAX;
      }
      ptr++;
      if (n++ == maxlen) {
        break;
      }
    }
  } else {
    // decimal
    while (ascii_isdigit(*ptr)) {
      // avoid ubsan error for overflow
      if (un < UVARNUMBER_MAX / 10) {
        un = 10 * un + (uvarnumber_T)(*ptr - '0');
      } else {
        un = UVARNUMBER_MAX;
      }
      ptr++;
      if (n++ == maxlen) {
        break;
      }
    }
  }

  if (prep != NULL) {
    *prep = pre;
  }

  if (len != NULL) {
    *len = (int)(ptr - start);
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
}
