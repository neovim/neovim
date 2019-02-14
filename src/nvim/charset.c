// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file charset.c
///
/// Code related to character sets.

#include <assert.h>
#include <string.h>
#include <wctype.h>
#include <wchar.h>  // for towupper() and towlower()
#include <inttypes.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/farsi.h"
#include "nvim/func_attr.h"
#include "nvim/indent.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/path.h"
#include "nvim/cursor.h"

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
#define GET_CHARTAB(buf, c) \
    GET_CHARTAB_TAB((buf)->b_chartab, c)

// Table used below, see init_chartab() for an explanation
static char_u g_chartab[256];

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

    if (p_altkeymap) {
      while (c < YE) {
        g_chartab[c++] = 1 + CT_PRINT_CHAR;
      }
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
  memset(buf->b_chartab, 0, (size_t)32);

  // In lisp mode the '-' character is included in keywords.
  if (buf->b_p_lisp) {
    SET_CHARTAB(buf, '-');
  }

  // Walk through the 'isident', 'iskeyword', 'isfname' and 'isprint'
  // options Each option is a list of characters, character numbers or
  // ranges, separated by commas, e.g.: "200-210,x,#-178,-"
  for (i = global ? 0 : 3; i <= 3; i++) {
    const char_u *p;
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
        ++p;
      }

      if (ascii_isdigit(*p)) {
        c = getdigits_int((char_u **)&p);
      } else {
        c = mb_ptr2char_adv(&p);
      }
      c2 = -1;

      if ((*p == '-') && (p[1] != NUL)) {
        ++p;

        if (ascii_isdigit(*p)) {
          c2 = getdigits_int((char_u **)&p);
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
            || mb_isupper(c)
            || (p_altkeymap && (F_isalpha(c) || F_isdigit(c)))) {
          if (i == 0) {
            // (re)set ID flag
            if (tilde) {
              g_chartab[c] &= (uint8_t)~CT_ID_CHAR;
            } else {
              g_chartab[c] |= CT_ID_CHAR;
            }
          } else if (i == 1) {
            // (re)set printable
            // For double-byte we keep the cell width, so
            // that we can detect it from the first byte.
            if (((c < ' ')
                 || (c > '~')
                 || (p_altkeymap && (F_isalpha(c) || F_isdigit(c))))) {
              if (tilde) {
                g_chartab[c] = (uint8_t)((g_chartab[c] & ~CT_CELL_MASK)
                                         + ((dy_flags & DY_UHEX) ? 4 : 2));
                g_chartab[c] &= (uint8_t)~CT_PRINT_CHAR;
              } else {
                g_chartab[c] = (uint8_t)((g_chartab[c] & ~CT_CELL_MASK) + 1);
                g_chartab[c] |= CT_PRINT_CHAR;
              }
            }
          } else if (i == 2) {
            // (re)set fname flag
            if (tilde) {
              g_chartab[c] &= (uint8_t)~CT_FNAME_CHAR;
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
        ++c;
      }

      c = *p;
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
void trans_characters(char_u *buf, int bufsize)
{
  int len;          // length of string needing translation
  int room;         // room in buffer after string
  char_u *trs;      // translated character
  int trs_len;      // length of trs[]

  len = (int)STRLEN(buf);
  room = bufsize - len;

  while (*buf != 0) {
    // Assume a multi-byte character doesn't need translation.
    if ((trs_len = (*mb_ptr2len)(buf)) > 1) {
      len -= trs_len;
    } else {
      trs = transchar_byte(*buf);
      trs_len = (int)STRLEN(trs);

      if (trs_len > 1) {
        room -= trs_len - 1;
        if (room <= 0) {
          return;
        }
        memmove(buf + trs_len, buf + 1, (size_t)len);
      }
      memmove(buf, trs, (size_t)trs_len);
      --len;
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
size_t transstr_len(const char *const s)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  const char *p = s;
  size_t len = 0;

  while (*p) {
    const size_t l = (size_t)utfc_ptr2len((const char_u *)p);
    if (l > 1) {
      int pcc[MAX_MCO + 1];
      pcc[0] = utfc_ptr2char((const char_u *)p, &pcc[1]);

      if (vim_isprintc(pcc[0])) {
        len += l;
      } else {
        for (size_t i = 0; i < ARRAY_SIZE(pcc) && pcc[i]; i++) {
          char hexbuf[9];
          len += transchar_hex(hexbuf, pcc[i]);
        }
      }
      p += l;
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
///
/// @return length of the resulting string, without the NUL byte.
size_t transstr_buf(const char *const s, char *const buf, const size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  const char *p = s;
  char *buf_p = buf;
  char *const buf_e = buf_p + len - 1;

  while (*p != NUL && buf_p < buf_e) {
    const size_t l = (size_t)utfc_ptr2len((const char_u *)p);
    if (l > 1) {
      if (buf_p + l > buf_e) {
        break;  // Exceeded `buf` size.
      }
      int pcc[MAX_MCO + 1];
      pcc[0] = utfc_ptr2char((const char_u *)p, &pcc[1]);

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
    } else {
      const char *const tb = (const char *)transchar_byte((uint8_t)(*p++));
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
char *transstr(const char *const s)
  FUNC_ATTR_NONNULL_RET
{
  // Compute the length of the result, taking account of unprintable
  // multi-byte characters.
  const size_t len = transstr_len((const char *)s) + 1;
  char *const buf = xmalloc(len);
  transstr_buf(s, buf, len);
  return buf;
}

/// Convert the string "str[orglen]" to do ignore-case comparing.
/// Use the current locale.
///
/// When "buf" is NULL, return an allocated string.
/// Otherwise, put the result in buf, limited by buflen, and return buf.
char_u* str_foldcase(char_u *str, int orglen, char_u *buf, int buflen)
  FUNC_ATTR_NONNULL_RET
{
  garray_T ga;
  int i;
  int len = orglen;

#define GA_CHAR(i) ((char_u *)ga.ga_data)[i]
#define GA_PTR(i) ((char_u *)ga.ga_data + i)
#define STR_CHAR(i) (buf == NULL ? GA_CHAR(i) : buf[i])
#define STR_PTR(i) (buf == NULL ? GA_PTR(i) : buf + i)

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
    i += (*mb_ptr2len)(STR_PTR(i));
  }


  if (buf == NULL) {
    return (char_u *)ga.ga_data;
  }
  return buf;
}

// Catch 22: g_chartab[] can't be initialized before the options are
// initialized, and initializing options may cause transchar() to be called!
// When chartab_initialized == false don't use g_chartab[].
// Does NOT work for multi-byte characters, c must be <= 255.
// Also doesn't work for the first byte of a multi-byte, "c" must be a
// character!
static char_u transchar_buf[11];

/// Translate a character into a printable one, leaving printable ASCII intact
///
/// All unicode characters are considered non-printable in this function.
///
/// @param[in]  c  Character to translate.
///
/// @return translated character into a static buffer.
char_u *transchar(int c)
{
  int i = 0;
  if (IS_SPECIAL(c)) {
    // special key code, display as ~@ char
    transchar_buf[0] = '~';
    transchar_buf[1] = '@';
    i = 2;
    c = K_SECOND(c);
  }

  if ((!chartab_initialized && (((c >= ' ') && (c <= '~'))
                                || (p_altkeymap && F_ischar(c))))
      || ((c <= 0xFF) && vim_isprintc_strict(c))) {
    // printable character
    transchar_buf[i] = (char_u)c;
    transchar_buf[i + 1] = NUL;
  } else if (c <= 0xFF) {
    transchar_nonprint(transchar_buf + i, c);
  } else {
    transchar_hex((char *)transchar_buf + i, c);
  }
  return transchar_buf;
}

/// Like transchar(), but called with a byte instead of a character
///
/// Checks for an illegal UTF-8 byte.
///
/// @param[in]  c  Byte to translate.
///
/// @return pointer to translated character in transchar_buf.
char_u *transchar_byte(const int c)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (c >= 0x80) {
    transchar_nonprint(transchar_buf, c);
    return transchar_buf;
  }
  return transchar(c);
}

/// Convert non-printable characters to 2..4 printable ones
///
/// @warning Does not work for multi-byte characters, c must be <= 255.
///
/// @param[out]  buf  Buffer to store result in, must be able to hold at least
///                   5 bytes (conversion result + NUL).
/// @param[in]  c  Character to convert. NUL is assumed to be NL according to
///                `:h NL-used-for-NUL`.
void transchar_nonprint(char_u *buf, int c)
{
  if (c == NL) {
    // we use newline in place of a NUL
    c = NUL;
  } else if ((c == CAR) && (get_fileformat(curbuf) == EOL_MAC)) {
    // we use CR in place of  NL in this case
    c = NL;
  }
  assert(c <= 0xff);

  if (dy_flags & DY_UHEX || c > 0x7f) {
    // 'display' has "uhex"
    transchar_hex((char *)buf, c);
  } else {
    // 0x00 - 0x1f and 0x7f
    buf[0] = '^';
    // DEL displayed as ^?
    buf[1] = (char_u)(c ^ 0x40);

    buf[2] = NUL;
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
  if (c > 255) {
    if (c > 255 * 256) {
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
/// @reeturn Number of display cells.
int byte2cells(int b)
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
int ptr2cells(const char_u *p)
{
  // For UTF-8 we need to look at more bytes if the first byte is >= 0x80.
  if (*p >= 0x80) {
    return utf_ptr2cells(p);
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
int vim_strsize(char_u *s)
{
  return vim_strnsize(s, (int)MAXCOL);
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
int vim_strnsize(char_u *s, int len)
{
  assert(s != NULL);
  int size = 0;
  while (*s != NUL && --len >= 0) {
    int l = (*mb_ptr2len)(s);
    size += ptr2cells(s);
    s += l;
    len -= l - 1;
  }
  return size;
}

/// Return the number of characters 'c' will take on the screen, taking
/// into account the size of a tab.
/// Use a define to make it fast, this is used very often!!!
/// Also see getvcol() below.
///
/// @param p
/// @param col
///
/// @return Number of characters.
#define RET_WIN_BUF_CHARTABSIZE(wp, buf, p, col) \
  if (*(p) == TAB && (!(wp)->w_p_list || wp->w_p_lcs_chars.tab1)) { \
    const int ts = (int)(buf)->b_p_ts; \
    return (ts - (int)(col % ts)); \
  } else { \
    return ptr2cells(p); \
  }

int chartabsize(char_u *p, colnr_T col)
{
  RET_WIN_BUF_CHARTABSIZE(curwin, curbuf, p, col)
}

static int win_chartabsize(win_T *wp, char_u *p, colnr_T col)
{
  RET_WIN_BUF_CHARTABSIZE(wp, wp->w_buffer, p, col)
}

/// Return the number of characters the string 's' will take on the screen,
/// taking into account the size of a tab.
///
/// @param s
///
/// @return Number of characters the string will take on the screen.
int linetabsize(char_u *s)
{
  return linetabsize_col(0, s);
}

/// Like linetabsize(), but starting at column "startcol".
///
/// @param startcol
/// @param s
///
/// @return Number of characters the string will take on the screen.
int linetabsize_col(int startcol, char_u *s)
{
  colnr_T col = startcol;
  char_u *line = s; /* pointer to start of line, for breakindent */

  while (*s != NUL) {
    col += lbr_chartabsize_adv(line, &s, col);
  }
  return (int)col;
}

/// Like linetabsize(), but for a given window instead of the current one.
///
/// @param wp
/// @param line
/// @param len
///
/// @return Number of characters the string will take on the screen.
unsigned int win_linetabsize(win_T *wp, char_u *line, colnr_T len)
{
  colnr_T col = 0;

  for (char_u *s = line;
       *s != NUL && (len == MAXCOL || s < line + len);
       MB_PTR_ADV(s)) {
    col += win_lbr_chartabsize(wp, line, s, col, NULL);
  }

  return (unsigned int)col;
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
bool vim_iswordp(const char_u *const p)
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
bool vim_iswordp_buf(const char_u *const p, buf_T *const buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  int c = *p;

  if (MB_BYTE2LEN(c) > 1) {
    c = utf_ptr2char(p);
  }
  return vim_iswordc_buf(c, buf);
}

/// Check that "c" is a valid file-name character.
/// Assume characters above 0x100 are valid (multi-byte).
///
/// @param  c  character to check
bool vim_isfilec(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return c >= 0x100 || (c > 0 && (g_chartab[c] & CT_FNAME_CHAR));
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
  char_u buf[2];
  buf[0] = (char_u)c;
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

/// like chartabsize(), but also check for line breaks on the screen
///
/// @param line
/// @param s
/// @param col
///
/// @return The number of characters taken up on the screen.
int lbr_chartabsize(char_u *line, unsigned char *s, colnr_T col)
{
  if (!curwin->w_p_lbr && (*p_sbr == NUL) && !curwin->w_p_bri) {
    if (curwin->w_p_wrap) {
      return win_nolbr_chartabsize(curwin, s, col, NULL);
    }
    RET_WIN_BUF_CHARTABSIZE(curwin, curbuf, s, col)
  }
  return win_lbr_chartabsize(curwin, line == NULL ? s: line, s, col, NULL);
}

/// Call lbr_chartabsize() and advance the pointer.
///
/// @param line
/// @param s
/// @param col
///
/// @return The number of characters take up on the screen.
int lbr_chartabsize_adv(char_u *line, char_u **s, colnr_T col)
{
  int retval;

  retval = lbr_chartabsize(line, *s, col);
  MB_PTR_ADV(*s);
  return retval;
}

/// This function is used very often, keep it fast!!!!
///
/// If "headp" not NULL, set *headp to the size of what we for 'showbreak'
/// string at start of line.  Warning: *headp is only set if it's a non-zero
/// value, init to 0 before calling.
///
/// @param wp
/// @param line
/// @param s
/// @param col
/// @param headp
///
/// @return The number of characters taken up on the screen.
int win_lbr_chartabsize(win_T *wp, char_u *line, char_u *s, colnr_T col, int *headp)
{
  colnr_T col2;
  colnr_T col_adj = 0; /* col + screen size of tab */
  colnr_T colmax;
  int added;
  int mb_added = 0;
  int numberextra;
  char_u *ps;
  int n;

  // No 'linebreak', 'showbreak' and 'breakindent': return quickly.
  if (!wp->w_p_lbr && !wp->w_p_bri && (*p_sbr == NUL)) {
    if (wp->w_p_wrap) {
      return win_nolbr_chartabsize(wp, s, col, headp);
    }
    RET_WIN_BUF_CHARTABSIZE(wp, wp->w_buffer, s, col)
  }

  // First get normal size, without 'linebreak'
  int size = win_chartabsize(wp, s, col);
  int c = *s;
  if (*s == TAB) {
      col_adj = size - 1;
  }

  // If 'linebreak' set check at a blank before a non-blank if the line
  // needs a break here
  if (wp->w_p_lbr
      && vim_isbreak(c)
      && !vim_isbreak((int)s[1])
      && wp->w_p_wrap
      && (wp->w_width_inner != 0)) {
    // Count all characters from first non-blank after a blank up to next
    // non-blank after a blank.
    numberextra = win_col_off(wp);
    col2 = col;
    colmax = (colnr_T)(wp->w_width_inner - numberextra - col_adj);

    if (col >= colmax) {
        colmax += col_adj;
        n = colmax + win_col_off2(wp);

      if (n > 0) {
        colmax += (((col - colmax) / n) + 1) * n - col_adj;
      }
    }

    for (;;) {
      ps = s;
      MB_PTR_ADV(s);
      c = *s;

      if (!(c != NUL
            && (vim_isbreak(c) || col2 == col || !vim_isbreak((int)(*ps))))) {
        break;
      }

      col2 += win_chartabsize(wp, s, col2);

      if (col2 >= colmax) { /* doesn't fit */
        size = colmax - col + col_adj;
        break;
      }
    }
  } else if ((size == 2)
             && (MB_BYTE2LEN(*s) > 1)
             && wp->w_p_wrap
             && in_win_border(wp, col)) {
    // Count the ">" in the last column.
    ++size;
    mb_added = 1;
  }

  // May have to add something for 'breakindent' and/or 'showbreak'
  // string at start of line.
  // Set *headp to the size of what we add.
  added = 0;

  if ((*p_sbr != NUL || wp->w_p_bri) && wp->w_p_wrap && (col != 0)) {
    colnr_T sbrlen = 0;
    int numberwidth = win_col_off(wp);

    numberextra = numberwidth;
    col += numberextra + mb_added;

    if (col >= (colnr_T)wp->w_width_inner) {
      col -= wp->w_width_inner;
      numberextra = wp->w_width_inner - (numberextra - win_col_off2(wp));
      if (col >= numberextra && numberextra > 0) {
        col %= numberextra;
      }
      if (*p_sbr != NUL) {
        sbrlen = (colnr_T)MB_CHARLEN(p_sbr);
        if (col >= sbrlen) {
          col -= sbrlen;
        }
      }
      if (col >= numberextra && numberextra > 0) {
        col %= numberextra;
      } else if (col > 0 && numberextra > 0) {
        col += numberwidth - win_col_off2(wp);
      }

      numberwidth -= win_col_off2(wp);
    }

    if (col == 0 || (col + size + sbrlen > (colnr_T)wp->w_width_inner)) {
      added = 0;

      if (*p_sbr != NUL) {
        if (size + sbrlen + numberwidth > (colnr_T)wp->w_width_inner) {
          // Calculate effective window width.
          int width = (colnr_T)wp->w_width_inner - sbrlen - numberwidth;
          int prev_width = col ? ((colnr_T)wp->w_width_inner - (sbrlen + col))
                               : 0;
          if (width == 0) {
            width = (colnr_T)wp->w_width_inner;
          }
          added += ((size - prev_width) / width) * vim_strsize(p_sbr);
          if ((size - prev_width) % width) {
            // Wrapped, add another length of 'sbr'.
            added += vim_strsize(p_sbr);
          }
        } else {
          added += vim_strsize(p_sbr);
        }
      }

      if (wp->w_p_bri)
        added += get_breakindent_win(wp, line);

      size += added;
      if (col != 0) {
        added = 0;
      }
    }
  }

  if (headp != NULL) {
    *headp = added + mb_added;
  }
  return size;
}

/// Like win_lbr_chartabsize(), except that we know 'linebreak' is off and
/// 'wrap' is on.  This means we need to check for a double-byte character that
/// doesn't fit at the end of the screen line.
///
/// @param wp
/// @param s
/// @param col
/// @param headp
///
/// @return The number of characters take up on the screen.
static int win_nolbr_chartabsize(win_T *wp, char_u *s, colnr_T col, int *headp)
{
  int n;

  if ((*s == TAB) && (!wp->w_p_list || wp->w_p_lcs_chars.tab1)) {
    n = (int)wp->w_buffer->b_p_ts;
    return n - (col % n);
  }
  n = ptr2cells(s);

  // Add one cell for a double-width character in the last column of the
  // window, displayed with a ">".
  if ((n == 2) && (MB_BYTE2LEN(*s) > 1) && in_win_border(wp, col)) {
    if (headp != NULL) {
      *headp = 1;
    }
    return 3;
  }
  return n;
}

/// Check that virtual column "vcol" is in the rightmost column of window "wp".
///
/// @param  wp    window
/// @param  vcol  column number
bool in_win_border(win_T *wp, colnr_T vcol)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1)
{
  int width1;             // width of first line (after line number)
  int width2;             // width of further lines

  if (wp->w_width_inner == 0) {
    // there is no border
    return false;
  }
  width1 = wp->w_width_inner - win_col_off(wp);

  if ((int)vcol < width1 - 1) {
    return false;
  }

  if ((int)vcol == width1 - 1) {
    return true;
  }
  width2 = width1 + win_col_off2(wp);

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
void getvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor,
             colnr_T *end)
{
  colnr_T vcol;
  char_u *ptr;    // points to current char
  char_u *posptr; // points to char at pos->col
  char_u *line;   // start of the line
  int incr;
  int head;
  int ts = (int)wp->w_buffer->b_p_ts;
  int c;

  vcol = 0;
  line = ptr = ml_get_buf(wp->w_buffer, pos->lnum, false);

  if (pos->col == MAXCOL) {
    // continue until the NUL
    posptr = NULL;
  } else {
    // Special check for an empty line, which can happen on exit, when
    // ml_get_buf() always returns an empty string.
    if (*ptr == NUL) {
      pos->col = 0;
    }
    posptr = ptr + pos->col;
    posptr -= utf_head_off(line, posptr);
  }

  // This function is used very often, do some speed optimizations.
  // When 'list', 'linebreak', 'showbreak' and 'breakindent' are not set
  // use a simple loop.
  // Also use this when 'list' is set but tabs take their normal size.
  if ((!wp->w_p_list || (wp->w_p_lcs_chars.tab1 != NUL))
      && !wp->w_p_lbr
      && (*p_sbr == NUL)
      && !wp->w_p_bri ) {
    for (;;) {
      head = 0;
      c = *ptr;

      // make sure we don't go past the end of the line
      if (c == NUL) {
        // NUL at end of line only takes one column
        incr = 1;
        break;
      }

      // A tab gets expanded, depending on the current column
      if (c == TAB) {
        incr = ts - (vcol % ts);
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
            && (MB_BYTE2LEN(*ptr) > 1)
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
    for (;;) {
      // A tab gets expanded, depending on the current column
      head = 0;
      incr = win_lbr_chartabsize(wp, line, ptr, vcol, &head);

      // make sure we don't go past the end of the line
      if (*ptr == NUL) {
        // NUL at end of line only takes one column
        incr = 1;
        break;
      }

      if ((posptr != NULL) && (ptr >= posptr)) {
        // character at pos->col
        break;
      }

      vcol += incr;
      MB_PTR_ADV(ptr);
    }
  }

  if (start != NULL) {
    *start = vcol + head;
  }

  if (end != NULL) {
    *end = vcol + incr - 1;
  }

  if (cursor != NULL) {
    if ((*ptr == TAB)
        && (State & NORMAL)
        && !wp->w_p_list
        && !virtual_active()
        && !(VIsual_active && ((*p_sel == 'e') || ltoreq(*pos, VIsual)))) {
      // cursor at end
      *cursor = vcol + incr - 1;
    } else {
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
void getvvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor,
              colnr_T *end)
{
  colnr_T col;
  colnr_T coladd;
  colnr_T endadd;
  char_u *ptr;

  if (virtual_active()) {
    // For virtual mode, only want one value
    getvcol(wp, pos, &col, NULL, NULL);

    coladd = pos->coladd;
    endadd = 0;

    // Cannot put the cursor on part of a wide character.
    ptr = ml_get_buf(wp->w_buffer, pos->lnum, false);

    if (pos->col < (colnr_T)STRLEN(ptr)) {
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
void getvcols(win_T *wp, pos_T *pos1, pos_T *pos2, colnr_T *left,
              colnr_T *right)
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
/// @param[in]  q  String to skip in.
///
/// @return Pointer to character after the skipped whitespace.
char_u *skipwhite(const char_u *q)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  const char_u *p = q;
  while (ascii_iswhite(*p)) {
    p++;
  }
  return (char_u *)p;
}

// getwhitecols: return the number of whitespace
// columns (bytes) at the start of a given line
intptr_t getwhitecols_curline(void)
{
  return getwhitecols(get_cursor_line_ptr());
}

intptr_t getwhitecols(const char_u *p)
{
  return skipwhite(p) - p;
}

/// Skip over digits
///
/// @param[in]  q  String to skip digits in.
///
/// @return Pointer to the character after the skipped digits.
char_u *skipdigits(const char_u *q)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
  FUNC_ATTR_NONNULL_RET
{
  const char_u *p = q;
  while (ascii_isdigit(*p)) {
    // skip to next non-digit
    p++;
  }
  return (char_u *)p;
}

/// skip over binary digits
///
/// @param q pointer to string
///
/// @return Pointer to the character after the skipped digits.
const char* skipbin(const char *q)
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
char_u* skiphex(char_u *q)
{
  char_u *p = q;
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
char_u* skiptodigit(char_u *q)
{
  char_u *p = q;
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
const char* skiptobin(const char *q)
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
char_u* skiptohex(char_u *q)
{
  char_u *p = q;
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
char_u *skiptowhite(const char_u *p)
{
  while (*p != ' ' && *p != '\t' && *p != NUL) {
    p++;
  }
  return (char_u *)p;
}

/// skiptowhite_esc: Like skiptowhite(), but also skip escaped chars
///
/// @param p
///
/// @return Pointer to the next whitespace character.
char_u* skiptowhite_esc(char_u *p) {
  while (*p != ' ' && *p != '\t' && *p != NUL) {
    if (((*p == '\\') || (*p == Ctrl_V)) && (*(p + 1) != NUL)) {
      ++p;
    }
    ++p;
  }
  return p;
}

/// Get a number from a string and skip over it, signalling overflows
///
/// @param[out]  pp  A pointer to a pointer to char_u.
///                  It will be advanced past the read number.
/// @param[out]  nr  Number read from the string.
///
/// @return OK on success, FAIL on error/overflow
int getdigits_safe(char_u **pp, intmax_t *nr)
{
  errno = 0;
  *nr = strtoimax((char *)(*pp), (char **)pp, 10);

  if ((*nr == INTMAX_MIN || *nr == INTMAX_MAX)
      && errno == ERANGE) {
    return FAIL;
  }

  return OK;
}

/// Get a number from a string and skip over it.
///
/// @param[out]  pp  A pointer to a pointer to char_u.
///                  It will be advanced past the read number.
///
/// @return Number read from the string.
intmax_t getdigits(char_u **pp)
{
  intmax_t number;
  int ret = getdigits_safe(pp, &number);

  (void)ret;  // Avoid "unused variable" warning in Release build
  assert(ret == OK);

  return number;
}

/// Get an int number from a string. Like getdigits(), but restricted to `int`.
int getdigits_int(char_u **pp)
{
  intmax_t number = getdigits(pp);
#if SIZEOF_INTMAX_T > SIZEOF_INT
  assert(number >= INT_MIN && number <= INT_MAX);
#endif
  return (int)number;
}

/// Get a long number from a string. Like getdigits(), but restricted to `long`.
long getdigits_long(char_u **pp)
{
  intmax_t number = getdigits(pp);
#if SIZEOF_INTMAX_T > SIZEOF_LONG
  assert(number >= LONG_MIN && number <= LONG_MAX);
#endif
  return (long)number;
}

/// Check that "lbuf" is empty or only contains blanks.
///
/// @param  lbuf  line buffer to check
bool vim_isblankline(char_u *lbuf)
{
  char_u *p = skipwhite(lbuf);
  return *p == NUL || *p == '\r' || *p == '\n';
}

/// Convert a string into a long and/or unsigned long, taking care of
/// hexadecimal, octal and binary numbers.  Accepts a '-' sign.
/// If "prep" is not NULL, returns a flag to indicate the type of the number:
///   0      decimal
///   '0'    octal
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
/// If maxlen > 0, check at a maximum maxlen chars.
///
/// @param start
/// @param prep Returns guessed type of number 0 = decimal, 'x' or 'X' is
///             hexadecimal, '0' = octal, 'b' or 'B' is binary. When using
///             STR2NR_FORCE is always zero.
/// @param len Returns the detected length of number.
/// @param what Recognizes what number passed, @see ChStr2NrFlags.
/// @param nptr Returns the signed result.
/// @param unptr Returns the unsigned result.
/// @param maxlen Max length of string to check.
void vim_str2nr(const char_u *const start, int *const prep, int *const len,
                const int what, varnumber_T *const nptr,
                uvarnumber_T *const unptr, const int maxlen)
  FUNC_ATTR_NONNULL_ARG(1)
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
    // Detect octal number: zero followed by octal digits without '8' or '9'.
    pre = 0;
    if (!(what & STR2NR_OCT)
        || !('0' <= ptr[1] && ptr[1] <= '7')) {
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
vim_str2nr_bin:
  PARSE_NUMBER(2, (*ptr == '0' || *ptr == '1'), (*ptr - '0'));
  goto vim_str2nr_proceed;
vim_str2nr_oct:
  PARSE_NUMBER(8, ('0' <= *ptr && *ptr <= '7'), (*ptr - '0'));
  goto vim_str2nr_proceed;
vim_str2nr_dec:
  PARSE_NUMBER(10, (ascii_isdigit(*ptr)), (*ptr - '0'));
  goto vim_str2nr_proceed;
vim_str2nr_hex:
  PARSE_NUMBER(16, (ascii_isxdigit(*ptr)), (hex2nr(*ptr)));
  goto vim_str2nr_proceed;
#undef PARSE_NUMBER

vim_str2nr_proceed:
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

/// Return the value of a single hex character.
/// Only valid when the argument is '0' - '9', 'A' - 'F' or 'a' - 'f'.
///
/// @param c
///
/// @return The value of the hex character.
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
bool rem_backslash(const char_u *str)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
#ifdef BACKSLASH_IN_FILENAME
  return str[0] == '\\'
         && str[1] < 0x80
         && (str[1] == ' '
             || (str[1] != NUL
                 && str[1] != '*'
                 && str[1] != '?'
                 && !vim_isfilec(str[1])));

#else  // ifdef BACKSLASH_IN_FILENAME
  return str[0] == '\\' && str[1] != NUL;
#endif  // ifdef BACKSLASH_IN_FILENAME
}

/// Halve the number of backslashes in a file name argument.
///
/// @param p
void backslash_halve(char_u *p)
{
  for (; *p; ++p) {
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
char_u* backslash_halve_save(char_u *p)
{
  // TODO(philix): simplify and improve backslash_halve_save algorithm
  char_u *res = vim_strsave(p);
  backslash_halve(res);
  return res;
}
