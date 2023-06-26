// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file charset.c
///
/// Code related to character sets.

#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "auto/config.h"
#include "klib/kvec.h"
#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/garray.h"
#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/indent.h"
#include "nvim/keycodes.h"
#include "nvim/macros.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/path.h"
#include "nvim/plines.h"
#include "nvim/pos.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "charset.c.generated.h"
#endif

static bool chartab_initialized = false;

// b_chartab[] is an array with 256 bits, each bit representing one of the
// characters 0-255.
#define SET_CHARTAB(buf, c) \
  (buf)->b_chartab[(unsigned)(c) >> 6] |= (1ull << ((c) & 0x3f))
#define RESET_CHARTAB(buf, c) \
  (buf)->b_chartab[(unsigned)(c) >> 6] &= ~(1ull << ((c) & 0x3f))
#define GET_CHARTAB_TAB(chartab, c) \
  ((chartab)[(unsigned)(c) >> 6] & (1ull << ((c) & 0x3f)))

// Table used below, see init_chartab() for an explanation
static uint8_t g_chartab[256];

// Flags for g_chartab[].
#define CT_CELL_MASK  0x07  ///< mask: nr of display cells (1, 2 or 4)
#define CT_PRINT_CHAR 0x10  ///< flag: set for printable chars
#define CT_ID_CHAR    0x20  ///< flag: set for ID chars
#define CT_FNAME_CHAR 0x40  ///< flag: set for file name chars

/// Fill g_chartab[].  Also fills curbuf->b_chartab[] with flags for keyword
/// characters for current buffer.
///
/// Depends on the option settings 'iskeyword', 'isident', 'isfname',
/// 'isprint' and 'encoding'.
///
/// The index in g_chartab[] is the character when first byte is up to 0x80,
/// if the first byte is 0x80 and above it depends on further bytes.
///
/// The contents of g_chartab[]:
/// - The lower two bits, masked by CT_CELL_MASK, give the number of display
///   cells the character occupies (1 or 2).  Not valid for UTF-8 above 0x80.
/// - CT_PRINT_CHAR bit is set when the character is printable (no need to
///   translate the character before displaying it).  Note that only DBCS
///   characters can have 2 display cells and still be printable.
/// - CT_FNAME_CHAR bit is set when the character can be in a file name.
/// - CT_ID_CHAR bit is set when the character can be in an identifier.
///
/// @return FAIL if 'iskeyword', 'isident', 'isfname' or 'isprint' option has
/// an error, OK otherwise.
int init_chartab(void)
{
  return buf_init_chartab(curbuf, true);
}

/// Helper for init_chartab
///
/// @param global false: only set buf->b_chartab[]
///
/// @return FAIL if 'iskeyword', 'isident', 'isfname' or 'isprint' option has
/// an error, OK otherwise.
int buf_init_chartab(buf_T *buf, int global)
{
  int c;
  int c2;
  int i;
  bool tilde;
  bool do_isalpha;

  if (global) {
    // Set the default size for printable characters:
    // From <Space> to '~' is 1 (printable), others are 2 (not printable).
    // This also inits all 'isident' and 'isfname' flags to false.
    c = 0;

    while (c < ' ') {
      g_chartab[c++] = (dy_flags & DY_UHEX) ? 4 : 2;
    }

    while (c <= '~') {
      g_chartab[c++] = 1 + CT_PRINT_CHAR;
    }

    while (c < 256) {
      if (c >= 0xa0) {
        // UTF-8: bytes 0xa0 - 0xff are printable (latin1)
        g_chartab[c++] = CT_PRINT_CHAR + 1;
      } else {
        // the rest is unprintable by default
        g_chartab[c++] = (dy_flags & DY_UHEX) ? 4 : 2;
      }
    }

    // Assume that every multi-byte char is a filename character.
    for (c = 1; c < 256; c++) {
      if (c >= 0xa0) {
        g_chartab[c] |= CT_FNAME_CHAR;
      }
    }
  }

  // Init word char flags all to false
  CLEAR_FIELD(buf->b_chartab);

  // In lisp mode the '-' character is included in keywords.
  if (buf->b_p_lisp) {
    SET_CHARTAB(buf, '-');
  }

  // Walk through the 'isident', 'iskeyword', 'isfname' and 'isprint'
  // options Each option is a list of characters, character numbers or
  // ranges, separated by commas, e.g.: "200-210,x,#-178,-"
  for (i = global ? 0 : 3; i <= 3; i++) {
    const char *p;
    if (i == 0) {
      // first round: 'isident'
      p = p_isi;
    } else if (i == 1) {
      // second round: 'isprint'
      p = p_isp;
    } else if (i == 2) {
      // third round: 'isfname'
      p = p_isf;
    } else {  // i == 3
      // fourth round: 'iskeyword'
      p = buf->b_p_isk;
    }

    while (*p) {
      tilde = false;
      do_isalpha = false;

      if ((*p == '^') && (p[1] != NUL)) {
        tilde = true;
        p++;
      }

      if (ascii_isdigit(*p)) {
        c = getdigits_int((char **)&p, true, 0);
      } else {
        c = mb_ptr2char_adv(&p);
      }
      c2 = -1;

      if ((*p == '-') && (p[1] != NUL)) {
        p++;

        if (ascii_isdigit(*p)) {
          c2 = getdigits_int((char **)&p, true, 0);
        } else {
          c2 = mb_ptr2char_adv(&p);
        }
      }

      if ((c <= 0)
          || (c >= 256)
          || ((c2 < c) && (c2 != -1))
          || (c2 >= 256)
          || !((*p == NUL) || (*p == ','))) {
        return FAIL;
      }

      if (c2 == -1) {  // not a range
        // A single '@' (not "@-@"):
        // Decide on letters being ID/printable/keyword chars with
        // standard function isalpha(). This takes care of locale for
        // single-byte characters).
        if (c == '@') {
          do_isalpha = true;
          c = 1;
          c2 = 255;
        } else {
          c2 = c;
        }
      }

      while (c <= c2) {
        // Use the MB_ functions here, because isalpha() doesn't
        // work properly when 'encoding' is "latin1" and the locale is
        // "C".
        if (!do_isalpha
            || mb_islower(c)
            || mb_isupper(c)) {
          if (i == 0) {
            // (re)set ID flag
            if (tilde) {
              g_chartab[c] &= (uint8_t) ~CT_ID_CHAR;
            } else {
              g_chartab[c] |= CT_ID_CHAR;
            }
          } else if (i == 1) {
            // (re)set printable
            if (c < ' ' || c > '~') {
              if (tilde) {
                g_chartab[c] = (uint8_t)((g_chartab[c] & ~CT_CELL_MASK)
                                         + ((dy_flags & DY_UHEX) ? 4 : 2));
                g_chartab[c] &= (uint8_t) ~CT_PRINT_CHAR;
              } else {
                g_chartab[c] = (uint8_t)((g_chartab[c] & ~CT_CELL_MASK) + 1);
                g_chartab[c] |= CT_PRINT_CHAR;
              }
            }
          } else if (i == 2) {
            // (re)set fname flag
            if (tilde) {
              g_chartab[c] &= (uint8_t) ~CT_FNAME_CHAR;
            } else {
              g_chartab[c] |= CT_FNAME_CHAR;
            }
          } else {  // i == 3
            // (re)set keyword flag
            if (tilde) {
              RESET_CHARTAB(buf, c);
            } else {
              SET_CHARTAB(buf, c);
            }
          }
        }
        c++;
      }

      c = (uint8_t)(*p);
      p = skip_to_option_part(p);

      if ((c == ',') && (*p == NUL)) {
        // Trailing comma is not allowed.
        return FAIL;
      }
    }
  }
  chartab_initialized = true;
  return OK;
}

/// Translate any special characters in buf[bufsize] in-place.
///
/// The result is a string with only printable characters, but if there is not
/// enough room, not all characters will be translated.
///
/// @param buf
/// @param bufsize
void trans_characters(char *buf, int bufsize)
{
  char *trs;                   // translated character
  int len = (int)strlen(buf);  // length of string needing translation
  int room = bufsize - len;    // room in buffer after string

  while (*buf != 0) {
    int trs_len;      // length of trs[]
    // Assume a multi-byte character doesn't need translation.
    if ((trs_len = utfc_ptr2len(buf)) > 1) {
      len -= trs_len;
    } else {
      trs = transchar_byte((uint8_t)(*buf));
      trs_len = (int)strlen(trs);

      if (trs_len > 1) {
        room -= trs_len - 1;
        if (room <= 0) {
          return;
        }
        memmove(buf + trs_len, buf + 1, (size_t)len);
      }
      memmove(buf, trs, (size_t)trs_len);
      len--;
    }
    buf += trs_len;
  }
}

/// Find length of a string capable of holding s with all specials replaced
///
/// Assumes replacing special characters with printable ones just like
/// strtrans() does.
///
/// @param[in]  s  String to check.
///
/// @return number of bytes needed to hold a translation of `s`, NUL byte not
///         included.
size_t transstr_len(const char *const s, bool untab)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  const char *p = s;
  size_t len = 0;

  while (*p) {
    const size_t l = (size_t)utfc_ptr2len(p);
    if (l > 1) {
      int pcc[MAX_MCO + 1];
      pcc[0] = utfc_ptr2char(p, &pcc[1]);

      if (vim_isprintc(pcc[0])) {
        len += l;
      } else {
        for (size_t i = 0; i < ARRAY_SIZE(pcc) && pcc[i]; i++) {
          char hexbuf[9];
          len += transchar_hex(hexbuf, pcc[i]);
        }
      }
      p += l;
    } else if (*p == TAB && !untab) {
      len += 1;
      p++;
    } else {
      const int b2c_l = byte2cells((uint8_t)(*p++));
      // Illegal byte sequence may occupy up to 4 characters.
      len += (size_t)(b2c_l > 0 ? b2c_l : 4);
    }
  }
  return len;
}

/// Replace special characters with printable ones
///
/// @param[in]  s  String to replace characters from.
/// @param[out]  buf  Buffer to which result should be saved.
/// @param[in]  len  Buffer length. Resulting string may not occupy more then
///                  len - 1 bytes (one for trailing NUL byte).
/// @param[in]  untab  remove tab characters
///
/// @return length of the resulting string, without the NUL byte.
size_t transstr_buf(const char *const s, const ssize_t slen, char *const buf, const size_t buflen,
                    bool untab)
  FUNC_ATTR_NONNULL_ALL
{
  const char *p = s;
  char *buf_p = buf;
  char *const buf_e = buf_p + buflen - 1;

  while ((slen < 0 || (p - s) < slen) && *p != NUL && buf_p < buf_e) {
    const size_t l = (size_t)utfc_ptr2len(p);
    if (l > 1) {
      if (buf_p + l > buf_e) {
        break;  // Exceeded `buf` size.
      }
      int pcc[MAX_MCO + 1];
      pcc[0] = utfc_ptr2char(p, &pcc[1]);

      if (vim_isprintc(pcc[0])) {
        memmove(buf_p, p, l);
        buf_p += l;
      } else {
        for (size_t i = 0; i < ARRAY_SIZE(pcc) && pcc[i]; i++) {
          char hexbuf[9];  // <up to 6 bytes>NUL
          const size_t hexlen = transchar_hex(hexbuf, pcc[i]);
          if (buf_p + hexlen > buf_e) {
            break;
          }
          memmove(buf_p, hexbuf, hexlen);
          buf_p += hexlen;
        }
      }
      p += l;
    } else if (*p == TAB && !untab) {
      *buf_p++ = *p++;
    } else {
      const char *const tb = transchar_byte((uint8_t)(*p++));
      const size_t tb_len = strlen(tb);
      if (buf_p + tb_len > buf_e) {
        break;  // Exceeded `buf` size.
      }
      memmove(buf_p, tb, tb_len);
      buf_p += tb_len;
    }
  }
  *buf_p = NUL;
  assert(buf_p <= buf_e);
  return (size_t)(buf_p - buf);
}

/// Copy string and replace special characters with printable characters
///
/// Works like `strtrans()` does, used for that and in some other places.
///
/// @param[in]  s  String to replace characters from.
///
/// @return [allocated] translated string
char *transstr(const char *const s, bool untab)
  FUNC_ATTR_NONNULL_RET
{
  // Compute the length of the result, taking account of unprintable
  // multi-byte characters.
  const size_t len = transstr_len(s, untab) + 1;
  char *const buf = xmalloc(len);
  transstr_buf(s, -1, buf, len, untab);
  return buf;
}

size_t kv_transstr(StringBuilder *str, const char *const s, bool untab)
  FUNC_ATTR_NONNULL_ARG(1)
{
  if (!s) {
    return 0;
  }

  // Compute the length of the result, taking account of unprintable
  // multi-byte characters.
  const size_t len = transstr_len(s, untab);
  kv_ensure_space(*str, len + 1);
  transstr_buf(s, -1, str->items + str->size, len + 1, untab);
  str->size += len;  // do not include NUL byte
  return len;
}

/// Convert the string "str[orglen]" to do ignore-case comparing.
/// Use the current locale.
///
/// When "buf" is NULL, return an allocated string.
/// Otherwise, put the result in buf, limited by buflen, and return buf.
char *str_foldcase(char *str, int orglen, char *buf, int buflen)
  FUNC_ATTR_NONNULL_RET
{
  garray_T ga;
  int i;
  int len = orglen;

#define GA_CHAR(i) ((char *)ga.ga_data)[i]
#define GA_PTR(i) ((char *)ga.ga_data + (i))
#define STR_CHAR(i) (buf == NULL ? GA_CHAR(i) : buf[i])
#define STR_PTR(i) (buf == NULL ? GA_PTR(i) : buf + (i))

  // Copy "str" into "buf" or allocated memory, unmodified.
  if (buf == NULL) {
    ga_init(&ga, 1, 10);

    ga_grow(&ga, len + 1);
    memmove(ga.ga_data, str, (size_t)len);
    ga.ga_len = len;
  } else {
    if (len >= buflen) {
      // Ugly!
      len = buflen - 1;
    }
    memmove(buf, str, (size_t)len);
  }

  if (buf == NULL) {
    GA_CHAR(len) = NUL;
  } else {
    buf[len] = NUL;
  }

  // Make each character lower case.
  i = 0;
  while (STR_CHAR(i) != NUL) {
    int c = utf_ptr2char(STR_PTR(i));
    int olen = utf_ptr2len(STR_PTR(i));
    int lc = mb_tolower(c);

    // Only replace the character when it is not an invalid
    // sequence (ASCII character or more than one byte) and
    // mb_tolower() doesn't return the original character.
    if (((c < 0x80) || (olen > 1)) && (c != lc)) {
      int nlen = utf_char2len(lc);

      // If the byte length changes need to shift the following
      // characters forward or backward.
      if (olen != nlen) {
        if (nlen > olen) {
          if (buf == NULL) {
            ga_grow(&ga, nlen - olen + 1);
          } else {
            if (len + nlen - olen >= buflen) {
              // out of memory, keep old char
              lc = c;
              nlen = olen;
            }
          }
        }

        if (olen != nlen) {
          if (buf == NULL) {
            STRMOVE(GA_PTR(i) + nlen, GA_PTR(i) + olen);
            ga.ga_len += nlen - olen;
          } else {
            STRMOVE(buf + i + nlen, buf + i + olen);
            len += nlen - olen;
          }
        }
      }
      (void)utf_char2bytes(lc, STR_PTR(i));
    }

    // skip to next multi-byte char
    i += utfc_ptr2len(STR_PTR(i));
  }

  if (buf == NULL) {
    return ga.ga_data;
  }
  return buf;
}

// Catch 22: g_chartab[] can't be initialized before the options are
// initialized, and initializing options may cause transchar() to be called!
// When chartab_initialized == false don't use g_chartab[].
// Does NOT work for multi-byte characters, c must be <= 255.
// Also doesn't work for the first byte of a multi-byte, "c" must be a
// character!
static uint8_t transchar_charbuf[11];

/// Translate a character into a printable one, leaving printable ASCII intact
///
/// All unicode characters are considered non-printable in this function.
///
/// @param[in]  c  Character to translate.
///
/// @return translated character into a static buffer.
char *transchar(int c)
{
  return transchar_buf(curbuf, c);
}

char *transchar_buf(const buf_T *buf, int c)
{
  int i = 0;
  if (IS_SPECIAL(c)) {
    // special key code, display as ~@ char
    transchar_charbuf[0] = '~';
    transchar_charbuf[1] = '@';
    i = 2;
    c = K_SECOND(c);
  }

  if ((!chartab_initialized && (c >= ' ' && c <= '~'))
      || ((c <= 0xFF) && vim_isprintc_strict(c))) {
    // printable character
    transchar_charbuf[i] = (uint8_t)c;
    transchar_charbuf[i + 1] = NUL;
  } else if (c <= 0xFF) {
    transchar_nonprint(buf, (char *)transchar_charbuf + i, c);
  } else {
    transchar_hex((char *)transchar_charbuf + i, c);
  }
  return (char *)transchar_charbuf;
}

/// Like transchar(), but called with a byte instead of a character.
///
/// Checks for an illegal UTF-8 byte.  Uses 'fileformat' of the current buffer.
///
/// @param[in]  c  Byte to translate.
///
/// @return pointer to translated character in transchar_charbuf.
char *transchar_byte(const int c)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return transchar_byte_buf(curbuf, c);
}

/// Like transchar_buf(), but called with a byte instead of a character.
///
/// Checks for an illegal UTF-8 byte.  Uses 'fileformat' of "buf", unless it is NULL.
///
/// @param[in]  c  Byte to translate.
///
/// @return pointer to translated character in transchar_charbuf.
char *transchar_byte_buf(const buf_T *buf, const int c)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (c >= 0x80) {
    transchar_nonprint(buf, (char *)transchar_charbuf, c);
    return (char *)transchar_charbuf;
  }
  return transchar_buf(buf, c);
}

/// Convert non-printable characters to 2..4 printable ones
///
/// @warning Does not work for multi-byte characters, c must be <= 255.
///
/// @param[in]  buf  Required to check the file format
/// @param[out]  charbuf  Buffer to store result in, must be able to hold
///                       at least 5 bytes (conversion result + NUL).
/// @param[in]  c  Character to convert. NUL is assumed to be NL according to
///                `:h NL-used-for-NUL`.
void transchar_nonprint(const buf_T *buf, char *charbuf, int c)
{
  if (c == NL) {
    // we use newline in place of a NUL
    c = NUL;
  } else if (buf != NULL && c == CAR && get_fileformat(buf) == EOL_MAC) {
    // we use CR in place of  NL in this case
    c = NL;
  }
  assert(c <= 0xff);

  if (dy_flags & DY_UHEX || c > 0x7f) {
    // 'display' has "uhex"
    transchar_hex(charbuf, c);
  } else {
    // 0x00 - 0x1f and 0x7f
    charbuf[0] = '^';
    // DEL displayed as ^?
    charbuf[1] = (char)(uint8_t)(c ^ 0x40);

    charbuf[2] = NUL;
  }
}

/// Convert a non-printable character to hex C string like "<FFFF>"
///
/// @param[out]  buf  Buffer to store result in.
/// @param[in]  c  Character to convert.
///
/// @return Number of bytes stored in buffer, excluding trailing NUL byte.
size_t transchar_hex(char *const buf, const int c)
  FUNC_ATTR_NONNULL_ALL
{
  size_t i = 0;

  buf[i++] = '<';
  if (c > 0xFF) {
    if (c > 0xFFFF) {
      buf[i++] = (char)nr2hex((unsigned)c >> 20);
      buf[i++] = (char)nr2hex((unsigned)c >> 16);
    }
    buf[i++] = (char)nr2hex((unsigned)c >> 12);
    buf[i++] = (char)nr2hex((unsigned)c >> 8);
  }
  buf[i++] = (char)(nr2hex((unsigned)c >> 4));
  buf[i++] = (char)(nr2hex((unsigned)c));
  buf[i++] = '>';
  buf[i] = NUL;
  return i;
}

/// Mirror text "str" for right-left displaying.
/// Only works for single-byte characters (e.g., numbers).
void rl_mirror_ascii(char *str)
{
  for (char *p1 = str, *p2 = str + strlen(str) - 1; p1 < p2; p1++, p2--) {
    char t = *p1;
    *p1 = *p2;
    *p2 = t;
  }
}

/// Convert the lower 4 bits of byte "c" to its hex character
///
/// Lower case letters are used to avoid the confusion of <F1> being 0xf1 or
/// function key 1.
///
/// @param[in]  n  Number to convert.
///
/// @return the hex character.
static inline unsigned nr2hex(unsigned n)
  FUNC_ATTR_CONST FUNC_ATTR_WARN_UNUSED_RESULT
{
  if ((n & 0xf) <= 9) {
    return (n & 0xf) + '0';
  }
  return (n & 0xf) - 10 + 'a';
}

/// Return number of display cells occupied by byte "b".
///
/// Caller must make sure 0 <= b <= 255.
/// For multi-byte mode "b" must be the first byte of a character.
/// A TAB is counted as two cells: "^I".
/// This will return 0 for bytes >= 0x80, because the number of
/// cells depends on further bytes in UTF-8.
///
/// @param b
///
/// @return Number of display cells.
int byte2cells(int b)
  FUNC_ATTR_PURE
{
  if (b >= 0x80) {
    return 0;
  }
  return g_chartab[b] & CT_CELL_MASK;
}

/// Return number of display cells occupied by character "c".
///
/// "c" can be a special key (negative number) in which case 3 or 4 is returned.
/// A TAB is counted as two cells: "^I" or four: "<09>".
///
/// @param c
///
/// @return Number of display cells.
int char2cells(int c)
{
  if (IS_SPECIAL(c)) {
    return char2cells(K_SECOND(c)) + 2;
  }

  if (c >= 0x80) {
    // UTF-8: above 0x80 need to check the value
    return utf_char2cells(c);
  }
  return g_chartab[c & 0xff] & CT_CELL_MASK;
}

/// Return number of display cells occupied by character at "*p".
/// A TAB is counted as two cells: "^I" or four: "<09>".
///
/// @param p
///
/// @return number of display cells.
int ptr2cells(const char *p_in)
{
  uint8_t *p = (uint8_t *)p_in;
  // For UTF-8 we need to look at more bytes if the first byte is >= 0x80.
  if (*p >= 0x80) {
    return utf_ptr2cells(p_in);
  }

  // For DBCS we can tell the cell count from the first byte.
  return g_chartab[*p] & CT_CELL_MASK;
}

/// Return the number of character cells string "s" will take on the screen,
/// counting TABs as two characters: "^I".
///
/// 's' must be non-null.
///
/// @param s
///
/// @return number of character cells.
int vim_strsize(const char *s)
{
  return vim_strnsize(s, MAXCOL);
}

/// Return the number of character cells string "s[len]" will take on the
/// screen, counting TABs as two characters: "^I".
///
/// 's' must be non-null.
///
/// @param s
/// @param len
///
/// @return Number of character cells.
int vim_strnsize(const char *s, int len)
{
  assert(s != NULL);
  int size = 0;
  while (*s != NUL && --len >= 0) {
    int l = utfc_ptr2len(s);
    size += ptr2cells(s);
    s += l;
    len -= l - 1;
  }
  return size;
}

/// Check that "c" is a normal identifier character:
/// Letters and characters from the 'isident' option.
///
/// @param  c  character to check
bool vim_isIDc(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return c > 0 && c < 0x100 && (g_chartab[c] & CT_ID_CHAR);
}

/// Check that "c" is a keyword character:
/// Letters and characters from 'iskeyword' option for the current buffer.
/// For multi-byte characters mb_get_class() is used (builtin rules).
///
/// @param  c  character to check
bool vim_iswordc(const int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return vim_iswordc_buf(c, curbuf);
}

/// Check that "c" is a keyword character
/// Letters and characters from 'iskeyword' option for given buffer.
/// For multi-byte characters mb_get_class() is used (builtin rules).
///
/// @param[in]  c  Character to check.
/// @param[in]  chartab  Buffer chartab.
bool vim_iswordc_tab(const int c, const uint64_t *const chartab)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return (c >= 0x100
          ? (utf_class_tab(c, chartab) >= 2)
          : (c > 0 && GET_CHARTAB_TAB(chartab, c) != 0));
}

/// Check that "c" is a keyword character:
/// Letters and characters from 'iskeyword' option for given buffer.
/// For multi-byte characters mb_get_class() is used (builtin rules).
///
/// @param  c    character to check
/// @param  buf  buffer whose keywords to use
bool vim_iswordc_buf(const int c, buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(2)
{
  return vim_iswordc_tab(c, buf->b_chartab);
}

/// Just like vim_iswordc() but uses a pointer to the (multi-byte) character.
///
/// @param  p  pointer to the multi-byte character
///
/// @return true if "p" points to a keyword character.
bool vim_iswordp(const char *const p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  return vim_iswordp_buf(p, curbuf);
}

/// Just like vim_iswordc_buf() but uses a pointer to the (multi-byte)
/// character.
///
/// @param  p    pointer to the multi-byte character
/// @param  buf  buffer whose keywords to use
///
/// @return true if "p" points to a keyword character.
bool vim_iswordp_buf(const char *const p, buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  int c = (uint8_t)(*p);

  if (MB_BYTE2LEN(c) > 1) {
    c = utf_ptr2char(p);
  }
  return vim_iswordc_buf(c, buf);
}

/// Check that "c" is a valid file-name character as specified with the
/// 'isfname' option.
/// Assume characters above 0x100 are valid (multi-byte).
/// To be used for commands like "gf".
///
/// @param  c  character to check
bool vim_isfilec(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return c >= 0x100 || (c > 0 && (g_chartab[c] & CT_FNAME_CHAR));
}

/// Check if "c" is a valid file-name character, including characters left
/// out of 'isfname' to make "gf" work, such as comma, space, '@', etc.
bool vim_is_fname_char(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return vim_isfilec(c) || c == ',' || c == ' ' || c == '@';
}

/// Check that "c" is a valid file-name character or a wildcard character
/// Assume characters above 0x100 are valid (multi-byte).
/// Explicitly interpret ']' as a wildcard character as path_has_wildcard("]")
/// returns false.
///
/// @param  c  character to check
bool vim_isfilec_or_wc(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char buf[2];
  buf[0] = (char)c;
  buf[1] = NUL;
  return vim_isfilec(c) || c == ']' || path_has_wildcard(buf);
}

/// Check that "c" is a printable character.
/// Assume characters above 0x100 are printable for double-byte encodings.
///
/// @param  c  character to check
bool vim_isprintc(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (c >= 0x100) {
    return utf_printable(c);
  }
  return c > 0 && (g_chartab[c] & CT_PRINT_CHAR);
}

/// Strict version of vim_isprintc(c), don't return true if "c" is the head
/// byte of a double-byte character.
///
/// @param  c  character to check
///
/// @return true if "c" is a printable character.
bool vim_isprintc_strict(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (c >= 0x100) {
    return utf_printable(c);
  }
  return c > 0 && (g_chartab[c] & CT_PRINT_CHAR);
}

/// Check that virtual column "vcol" is in the rightmost column of window "wp".
///
/// @param  wp    window
/// @param  vcol  column number
bool in_win_border(win_T *wp, colnr_T vcol)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  if (wp->w_width_inner == 0) {
    // there is no border
    return false;
  }
  int width1 = wp->w_width_inner - win_col_off(wp);  // width of first line (after line number)

  if ((int)vcol < width1 - 1) {
    return false;
  }

  if ((int)vcol == width1 - 1) {
    return true;
  }
  int width2 = width1 + win_col_off2(wp);  // width of further lines

  if (width2 <= 0) {
    return false;
  }
  return (vcol - width1) % width2 == width2 - 1;
}

/// Get virtual column number of pos.
///  start: on the first position of this character (TAB, ctrl)
/// cursor: where the cursor is on this character (first char, except for TAB)
///    end: on the last position of this character (TAB, ctrl)
///
/// This is used very often, keep it fast!
///
/// @param wp
/// @param pos
/// @param start
/// @param cursor
/// @param end
void getvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end)
{
  char *ptr;     // points to current char
  char *posptr;  // points to char at pos->col
  int incr;
  int head;
  long *vts = wp->w_buffer->b_p_vts_array;
  int ts = (int)wp->w_buffer->b_p_ts;

  colnr_T vcol = 0;
  char *line = ptr = ml_get_buf(wp->w_buffer, pos->lnum, false);  // start of the line

  if (pos->col == MAXCOL) {
    // continue until the NUL
    posptr = NULL;
  } else {
    // In a few cases the position can be beyond the end of the line.
    for (colnr_T i = 0; i < pos->col; i++) {
      if (ptr[i] == NUL) {
        pos->col = i;
        break;
      }
    }
    posptr = ptr + pos->col;
    posptr -= utf_head_off(line, posptr);
  }

  chartabsize_T cts;
  bool on_NUL = false;
  init_chartabsize_arg(&cts, wp, pos->lnum, 0, line, line);

  // This function is used very often, do some speed optimizations.
  // When 'list', 'linebreak', 'showbreak' and 'breakindent' are not set
  // and there are no virtual text use a simple loop.
  // Also use this when 'list' is set but tabs take their normal size.
  if ((!wp->w_p_list || (wp->w_p_lcs_chars.tab1 != NUL))
      && !wp->w_p_lbr
      && *get_showbreak_value(wp) == NUL
      && !wp->w_p_bri
      && !cts.cts_has_virt_text) {
    while (true) {
      head = 0;
      int c = (uint8_t)(*ptr);

      // make sure we don't go past the end of the line
      if (c == NUL) {
        // NUL at end of line only takes one column
        incr = 1;
        break;
      }

      // A tab gets expanded, depending on the current column
      if (c == TAB) {
        incr = tabstop_padding(vcol, ts, vts);
      } else {
        // For utf-8, if the byte is >= 0x80, need to look at
        // further bytes to find the cell width.
        if (c >= 0x80) {
          incr = utf_ptr2cells(ptr);
        } else {
          incr = g_chartab[c] & CT_CELL_MASK;
        }

        // If a double-cell char doesn't fit at the end of a line
        // it wraps to the next line, it's like this char is three
        // cells wide.
        if ((incr == 2)
            && wp->w_p_wrap
            && (MB_BYTE2LEN((uint8_t)(*ptr)) > 1)
            && in_win_border(wp, vcol)) {
          incr++;
          head = 1;
        }
      }

      if ((posptr != NULL) && (ptr >= posptr)) {
        // character at pos->col
        break;
      }

      vcol += incr;
      MB_PTR_ADV(ptr);
    }
  } else {
    while (true) {
      // A tab gets expanded, depending on the current column
      // Other things also take up space.
      head = 0;
      incr = win_lbr_chartabsize(&cts, &head);

      // make sure we don't go past the end of the line
      if (*cts.cts_ptr == NUL) {
        // NUL at end of line only takes one column, unless there is virtual text
        incr = MAX(1, cts.cts_cur_text_width_left + cts.cts_cur_text_width_right);
        on_NUL = true;
        break;
      }

      if ((posptr != NULL) && (cts.cts_ptr >= posptr)) {
        // character at pos->col
        break;
      }

      cts.cts_vcol += incr;
      MB_PTR_ADV(cts.cts_ptr);
    }
    vcol = cts.cts_vcol;
    ptr = cts.cts_ptr;
  }
  clear_chartabsize_arg(&cts);

  if (start != NULL) {
    *start = vcol + head;
  }

  if (end != NULL) {
    *end = vcol + incr - 1;
  }

  if (cursor != NULL) {
    if ((*ptr == TAB)
        && (State & MODE_NORMAL)
        && !wp->w_p_list
        && !virtual_active()
        && !(VIsual_active && ((*p_sel == 'e') || ltoreq(*pos, VIsual)))) {
      // cursor at end
      *cursor = vcol + incr - 1;
    } else {
      if (!on_NUL) {
        // cursor is after inserted text, unless on the NUL
        vcol += cts.cts_cur_text_width_left;
        if ((State & MODE_INSERT) == 0) {
          vcol += cts.cts_cur_text_width_right;
        }
      }
      // cursor at start
      *cursor = vcol + head;
    }
  }
}

/// Get virtual cursor column in the current window, pretending 'list' is off.
///
/// @param posp
///
/// @retujrn The virtual cursor column.
colnr_T getvcol_nolist(pos_T *posp)
{
  int list_save = curwin->w_p_list;
  colnr_T vcol;

  curwin->w_p_list = false;
  if (posp->coladd) {
    getvvcol(curwin, posp, NULL, &vcol, NULL);
  } else {
    getvcol(curwin, posp, NULL, &vcol, NULL);
  }
  curwin->w_p_list = list_save;
  return vcol;
}

/// Get virtual column in virtual mode.
///
/// @param wp
/// @param pos
/// @param start
/// @param cursor
/// @param end
void getvvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end)
{
  colnr_T col;

  if (virtual_active()) {
    // For virtual mode, only want one value
    getvcol(wp, pos, &col, NULL, NULL);

    colnr_T coladd = pos->coladd;
    colnr_T endadd = 0;

    // Cannot put the cursor on part of a wide character.
    char *ptr = ml_get_buf(wp->w_buffer, pos->lnum, false);

    if (pos->col < (colnr_T)strlen(ptr)) {
      int c = utf_ptr2char(ptr + pos->col);
      if ((c != TAB) && vim_isprintc(c)) {
        endadd = (colnr_T)(char2cells(c) - 1);
        if (coladd > endadd) {
          // past end of line
          endadd = 0;
        } else {
          coladd = 0;
        }
      }
    }
    col += coladd;

    if (start != NULL) {
      *start = col;
    }

    if (cursor != NULL) {
      *cursor = col;
    }

    if (end != NULL) {
      *end = col + endadd;
    }
  } else {
    getvcol(wp, pos, start, cursor, end);
  }
}

/// Get the leftmost and rightmost virtual column of pos1 and pos2.
/// Used for Visual block mode.
///
/// @param wp
/// @param pos1
/// @param pos2
/// @param left
/// @param right
void getvcols(win_T *wp, pos_T *pos1, pos_T *pos2, colnr_T *left, colnr_T *right)
{
  colnr_T from1;
  colnr_T from2;
  colnr_T to1;
  colnr_T to2;

  if (lt(*pos1, *pos2)) {
    getvvcol(wp, pos1, &from1, NULL, &to1);
    getvvcol(wp, pos2, &from2, NULL, &to2);
  } else {
    getvvcol(wp, pos2, &from1, NULL, &to1);
    getvvcol(wp, pos1, &from2, NULL, &to2);
  }

  if (from2 < from1) {
    *left = from2;
  } else {
    *left = from1;
  }

  if (to2 > to1) {
    if ((*p_sel == 'e') && (from2 - 1 >= to1)) {
      *right = from2 - 1;
    } else {
      *right = to2;
    }
  } else {
    *right = to1;
  }
}

/// skipwhite: skip over ' ' and '\t'.
///
/// @param[in]  p  String to skip in.
///
/// @return Pointer to character after the skipped whitespace.
char *skipwhite(const char *const p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  return skipwhite_len(p, strlen(p));
}

/// Like `skipwhite`, but skip up to `len` characters.
/// @see skipwhite
///
/// @param[in]  p    String to skip in.
/// @param[in]  len  Max length to skip.
///
/// @return Pointer to character after the skipped whitespace, or the `len`-th
///         character in the string.
char *skipwhite_len(const char *p, size_t len)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  for (; len > 0 && ascii_iswhite(*p); len--) {
    p++;
  }
  return (char *)p;
}

// getwhitecols: return the number of whitespace
// columns (bytes) at the start of a given line
intptr_t getwhitecols_curline(void)
{
  return getwhitecols(get_cursor_line_ptr());
}

intptr_t getwhitecols(const char *p)
  FUNC_ATTR_PURE
{
  return skipwhite(p) - p;
}

/// Skip over digits
///
/// @param[in]  q  String to skip digits in.
///
/// @return Pointer to the character after the skipped digits.
char *skipdigits(const char *q)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  const char *p = q;
  while (ascii_isdigit(*p)) {
    // skip to next non-digit
    p++;
  }
  return (char *)p;
}

/// skip over binary digits
///
/// @param q pointer to string
///
/// @return Pointer to the character after the skipped digits.
const char *skipbin(const char *q)
  FUNC_ATTR_PURE
  FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  const char *p = q;
  while (ascii_isbdigit(*p)) {
    // skip to next non-digit
    p++;
  }
  return p;
}

/// skip over digits and hex characters
///
/// @param q
///
/// @return Pointer to the character after the skipped digits and hex
///         characters.
char *skiphex(char *q)
  FUNC_ATTR_PURE
{
  char *p = q;
  while (ascii_isxdigit(*p)) {
    // skip to next non-digit
    p++;
  }
  return p;
}

/// skip to digit (or NUL after the string)
///
/// @param q
///
/// @return Pointer to the digit or (NUL after the string).
char *skiptodigit(char *q)
  FUNC_ATTR_PURE
{
  char *p = q;
  while (*p != NUL && !ascii_isdigit(*p)) {
    // skip to next digit
    p++;
  }
  return p;
}

/// skip to binary character (or NUL after the string)
///
/// @param q pointer to string
///
/// @return Pointer to the binary character or (NUL after the string).
const char *skiptobin(const char *q)
  FUNC_ATTR_PURE
  FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  const char *p = q;
  while (*p != NUL && !ascii_isbdigit(*p)) {
    // skip to next digit
    p++;
  }
  return p;
}

/// skip to hex character (or NUL after the string)
///
/// @param q
///
/// @return Pointer to the hex character or (NUL after the string).
char *skiptohex(char *q)
  FUNC_ATTR_PURE
{
  char *p = q;
  while (*p != NUL && !ascii_isxdigit(*p)) {
    // skip to next digit
    p++;
  }
  return p;
}

/// Skip over text until ' ' or '\t' or NUL
///
/// @param[in]  p  Text to skip over.
///
/// @return Pointer to the next whitespace or NUL character.
char *skiptowhite(const char *p)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_PURE
{
  while (*p != ' ' && *p != '\t' && *p != NUL) {
    p++;
  }
  return (char *)p;
}

/// skiptowhite_esc: Like skiptowhite(), but also skip escaped chars
///
/// @param p
///
/// @return Pointer to the next whitespace character.
char *skiptowhite_esc(char *p)
  FUNC_ATTR_PURE
{
  while (*p != ' ' && *p != '\t' && *p != NUL) {
    if (((*p == '\\') || (*p == Ctrl_V)) && (*(p + 1) != NUL)) {
      p++;
    }
    p++;
  }
  return p;
}

/// Skip over text until '\n' or NUL.
///
/// @param[in]  p  Text to skip over.
///
/// @return Pointer to the next '\n' or NUL character.
char *skip_to_newline(const char *const p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  return xstrchrnul(p, NL);
}

/// Gets a number from a string and skips over it, signalling overflow.
///
/// @param[out]  pp  A pointer to a pointer to char.
///                  It will be advanced past the read number.
/// @param[out]  nr  Number read from the string.
///
/// @return true on success, false on error/overflow
bool try_getdigits(char **pp, intmax_t *nr)
{
  errno = 0;
  *nr = strtoimax(*pp, pp, 10);
  if (errno == ERANGE && (*nr == INTMAX_MIN || *nr == INTMAX_MAX)) {
    return false;
  }
  return true;
}

/// Gets a number from a string and skips over it.
///
/// @param[out]  pp  Pointer to a pointer to char.
///                  It will be advanced past the read number.
/// @param strict    Abort on overflow.
/// @param def       Default value, if parsing fails or overflow occurs.
///
/// @return Number read from the string, or `def` on parse failure or overflow.
intmax_t getdigits(char **pp, bool strict, intmax_t def)
{
  intmax_t number;
  int ok = try_getdigits(pp, &number);
  if (strict && !ok) {
    abort();
  }
  return ok ? number : def;
}

/// Gets an int number from a string.
///
/// @see getdigits
int getdigits_int(char **pp, bool strict, int def)
{
  intmax_t number = getdigits(pp, strict, def);
#if SIZEOF_INTMAX_T > SIZEOF_INT
  if (strict) {
    assert(number >= INT_MIN && number <= INT_MAX);
  } else if (!(number >= INT_MIN && number <= INT_MAX)) {
    return def;
  }
#endif
  return (int)number;
}

/// Gets a long number from a string.
///
/// @see getdigits
long getdigits_long(char **pp, bool strict, long def)
{
  intmax_t number = getdigits(pp, strict, def);
#if SIZEOF_INTMAX_T > SIZEOF_LONG
  if (strict) {
    assert(number >= LONG_MIN && number <= LONG_MAX);
  } else if (!(number >= LONG_MIN && number <= LONG_MAX)) {
    return def;
  }
#endif
  return (long)number;
}

/// Gets a int32_t number from a string.
///
/// @see getdigits
int32_t getdigits_int32(char **pp, bool strict, long def)
{
  intmax_t number = getdigits(pp, strict, def);
#if SIZEOF_INTMAX_T > 4
  if (strict) {
    assert(number >= INT32_MIN && number <= INT32_MAX);
  } else if (!(number >= INT32_MIN && number <= INT32_MAX)) {
    return (int32_t)def;
  }
#endif
  return (int32_t)number;
}

/// Check that "lbuf" is empty or only contains blanks.
///
/// @param  lbuf  line buffer to check
bool vim_isblankline(char *lbuf)
  FUNC_ATTR_PURE
{
  char *p = skipwhite(lbuf);
  return *p == NUL || *p == '\r' || *p == '\n';
}

/// Convert a string into a long and/or unsigned long, taking care of
/// hexadecimal, octal and binary numbers.  Accepts a '-' sign.
/// If "prep" is not NULL, returns a flag to indicate the type of the number:
///   0      decimal
///   '0'    octal
///   'O'    octal
///   'o'    octal
///   'B'    bin
///   'b'    bin
///   'X'    hex
///   'x'    hex
/// If "len" is not NULL, the length of the number in characters is returned.
/// If "nptr" is not NULL, the signed result is returned in it.
/// If "unptr" is not NULL, the unsigned result is returned in it.
/// If "what" contains STR2NR_BIN recognize binary numbers.
/// If "what" contains STR2NR_OCT recognize octal numbers.
/// If "what" contains STR2NR_HEX recognize hex numbers.
/// If "what" contains STR2NR_FORCE always assume bin/oct/hex.
/// If "what" contains STR2NR_QUOTE ignore embedded single quotes
/// If maxlen > 0, check at a maximum maxlen chars.
/// If strict is true, check the number strictly. return *len = 0 if fail.
///
/// @param start
/// @param prep Returns guessed type of number 0 = decimal, 'x' or 'X' is
///             hexadecimal, '0', 'o' or 'O' is octal, 'b' or 'B' is binary.
///             When using STR2NR_FORCE is always zero.
/// @param len Returns the detected length of number.
/// @param what Recognizes what number passed, @see ChStr2NrFlags.
/// @param nptr Returns the signed result.
/// @param unptr Returns the unsigned result.
/// @param maxlen Max length of string to check.
/// @param strict If true, fail if the number has unexpected trailing
///               alphanumeric chars: *len is set to 0 and nothing else is
///               returned.
/// @param overflow When not NULL, set to true for overflow.
void vim_str2nr(const char *const start, int *const prep, int *const len, const int what,
                varnumber_T *const nptr, uvarnumber_T *const unptr, const int maxlen,
                const bool strict, bool *const overflow)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const char *ptr = start;
#define STRING_ENDED(ptr) \
  (!(maxlen == 0 || (int)((ptr) - start) < maxlen))
  int pre = 0;  // default is decimal
  const bool negative = (ptr[0] == '-');
  uvarnumber_T un = 0;

  if (len != NULL) {
    *len = 0;
  }

  if (negative) {
    ptr++;
  }

  if (what & STR2NR_FORCE) {
    // When forcing main consideration is skipping the prefix. Decimal numbers
    // have no prefixes to skip. pre is not set.
    switch (what & ~(STR2NR_FORCE | STR2NR_QUOTE)) {
    case STR2NR_HEX:
      if (!STRING_ENDED(ptr + 2)
          && ptr[0] == '0'
          && (ptr[1] == 'x' || ptr[1] == 'X')
          && ascii_isxdigit(ptr[2])) {
        ptr += 2;
      }
      goto vim_str2nr_hex;
    case STR2NR_BIN:
      if (!STRING_ENDED(ptr + 2)
          && ptr[0] == '0'
          && (ptr[1] == 'b' || ptr[1] == 'B')
          && ascii_isbdigit(ptr[2])) {
        ptr += 2;
      }
      goto vim_str2nr_bin;
    // Make STR2NR_OOCT work the same as STR2NR_OCT when forcing.
    case STR2NR_OCT:
    case STR2NR_OOCT:
    case STR2NR_OCT | STR2NR_OOCT:
      if (!STRING_ENDED(ptr + 2)
          && ptr[0] == '0'
          && (ptr[1] == 'o' || ptr[1] == 'O')
          && ascii_isodigit(ptr[2])) {
        ptr += 2;
      }
      goto vim_str2nr_oct;
    case 0:
      goto vim_str2nr_dec;
    default:
      abort();
    }
  } else if ((what & (STR2NR_HEX | STR2NR_OCT | STR2NR_OOCT | STR2NR_BIN))
             && !STRING_ENDED(ptr + 1) && ptr[0] == '0' && ptr[1] != '8'
             && ptr[1] != '9') {
    pre = (uint8_t)ptr[1];
    // Detect hexadecimal: 0x or 0X followed by hex digit.
    if ((what & STR2NR_HEX)
        && !STRING_ENDED(ptr + 2)
        && (pre == 'X' || pre == 'x')
        && ascii_isxdigit(ptr[2])) {
      ptr += 2;
      goto vim_str2nr_hex;
    }
    // Detect binary: 0b or 0B followed by 0 or 1.
    if ((what & STR2NR_BIN)
        && !STRING_ENDED(ptr + 2)
        && (pre == 'B' || pre == 'b')
        && ascii_isbdigit(ptr[2])) {
      ptr += 2;
      goto vim_str2nr_bin;
    }
    // Detect octal: 0o or 0O followed by octal digits (without '8' or '9').
    if ((what & STR2NR_OOCT)
        && !STRING_ENDED(ptr + 2)
        && (pre == 'O' || pre == 'o')
        && ascii_isodigit(ptr[2])) {
      ptr += 2;
      goto vim_str2nr_oct;
    }
    // Detect old octal format: 0 followed by octal digits.
    pre = 0;
    if (!(what & STR2NR_OCT)
        || !ascii_isodigit(ptr[1])) {
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

  // Do the conversion manually to avoid sscanf() quirks.
  abort();  // Should’ve used goto earlier.
  // -V:PARSE_NUMBER:560
#define PARSE_NUMBER(base, cond, conv) \
  do { \
    const char *const after_prefix = ptr; \
    while (!STRING_ENDED(ptr)) { \
      if ((what & STR2NR_QUOTE) && ptr > after_prefix && *ptr == '\'') { \
        ptr++; \
        if (!STRING_ENDED(ptr) && (cond)) { \
          continue; \
        } \
        ptr--; \
      } \
      if (!(cond)) { \
        break; \
      } \
      const uvarnumber_T digit = (uvarnumber_T)(conv); \
      /* avoid ubsan error for overflow */ \
      if (un < UVARNUMBER_MAX / (base) \
          || (un == UVARNUMBER_MAX / (base) \
              && ((base) != 10 || digit <= UVARNUMBER_MAX % 10))) { \
        un = (base) * un + digit; \
      } else { \
        un = UVARNUMBER_MAX; \
        if (overflow != NULL) { \
          *overflow = true; \
        } \
      } \
      ptr++; \
    } \
  } while (0)
vim_str2nr_bin:
  PARSE_NUMBER(2, (*ptr == '0' || *ptr == '1'), (*ptr - '0'));
  goto vim_str2nr_proceed;
vim_str2nr_oct:
  PARSE_NUMBER(8, (ascii_isodigit(*ptr)), (*ptr - '0'));
  goto vim_str2nr_proceed;
vim_str2nr_dec:
  PARSE_NUMBER(10, (ascii_isdigit(*ptr)), (*ptr - '0'));
  goto vim_str2nr_proceed;
vim_str2nr_hex:
  PARSE_NUMBER(16, (ascii_isxdigit(*ptr)), (hex2nr(*ptr)));
  goto vim_str2nr_proceed;
#undef PARSE_NUMBER

vim_str2nr_proceed:
  // Check for an alphanumeric character immediately following, that is
  // most likely a typo.
  if (strict && ptr - start != maxlen && ASCII_ISALNUM(*ptr)) {
    return;
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
        if (overflow != NULL) {
          *overflow = true;
        }
      } else {
        *nptr = -(varnumber_T)un;
      }
    } else {
      if (un > VARNUMBER_MAX) {
        un = VARNUMBER_MAX;
        if (overflow != NULL) {
          *overflow = true;
        }
      }
      *nptr = (varnumber_T)un;
    }
  }

  if (unptr != NULL) {
    *unptr = un;
  }
#undef STRING_ENDED
}

/// Return the value of a single hex character.
/// Only valid when the argument is '0' - '9', 'A' - 'F' or 'a' - 'f'.
///
/// @param c
///
/// @return The value of the hex character.
int hex2nr(int c)
  FUNC_ATTR_CONST
{
  if ((c >= 'a') && (c <= 'f')) {
    return c - 'a' + 10;
  }

  if ((c >= 'A') && (c <= 'F')) {
    return c - 'A' + 10;
  }
  return c - '0';
}

/// Convert two hex characters to a byte.
///
/// @return  -1 if one of the characters is not hex.
int hexhex2nr(const char *p)
  FUNC_ATTR_PURE
{
  if (!ascii_isxdigit(p[0]) || !ascii_isxdigit(p[1])) {
    return -1;
  }
  return (hex2nr(p[0]) << 4) + hex2nr(p[1]);
}

/// Check that "str" starts with a backslash that should be removed.
/// For Windows this is only done when the character after the
/// backslash is not a normal file name character.
/// '$' is a valid file name character, we don't remove the backslash before
/// it.  This means it is not possible to use an environment variable after a
/// backslash.  "C:\$VIM\doc" is taken literally, only "$VIM\doc" works.
/// Although "\ name" is valid, the backslash in "Program\ files" must be
/// removed.  Assume a file name doesn't start with a space.
/// For multi-byte names, never remove a backslash before a non-ascii
/// character, assume that all multi-byte characters are valid file name
/// characters.
///
/// @param  str  file path string to check
bool rem_backslash(const char *str)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
#ifdef BACKSLASH_IN_FILENAME
  return str[0] == '\\'
         && (uint8_t)str[1] < 0x80
         && (str[1] == ' '
             || (str[1] != NUL
                 && str[1] != '*'
                 && str[1] != '?'
                 && !vim_isfilec((uint8_t)str[1])));

#else  // ifdef BACKSLASH_IN_FILENAME
  return str[0] == '\\' && str[1] != NUL;
#endif  // ifdef BACKSLASH_IN_FILENAME
}

/// Halve the number of backslashes in a file name argument.
///
/// @param p
void backslash_halve(char *p)
{
  for (; *p; p++) {
    if (rem_backslash(p)) {
      STRMOVE(p, p + 1);
    }
  }
}

/// backslash_halve() plus save the result in allocated memory.
///
/// @param p
///
/// @return String with the number of backslashes halved.
char *backslash_halve_save(const char *p)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET
{
  // TODO(philix): simplify and improve backslash_halve_save algorithm
  char *res = xstrdup(p);
  backslash_halve(res);
  return res;
}
