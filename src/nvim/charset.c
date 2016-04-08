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
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/misc2.h"
#include "nvim/garray.h"
#include "nvim/move.h"
#include "nvim/os_unix.h"
#include "nvim/strings.h"
#include "nvim/path.h"


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
#define GET_CHARTAB(buf, c) \
    ((buf)->b_chartab[(unsigned)(c) >> 6] & (1ull << ((c) & 0x3f)))

/// Fill chartab[].  Also fills curbuf->b_chartab[] with flags for keyword
/// characters for current buffer.
///
/// Depends on the option settings 'iskeyword', 'isident', 'isfname',
/// 'isprint' and 'encoding'.
///
/// The index in chartab[] depends on 'encoding':
/// - For non-multi-byte index with the byte (same as the character).
/// - For DBCS index with the first byte.
/// - For UTF-8 index with the character (when first byte is up to 0x80 it is
///   the same as the character, if the first byte is 0x80 and above it depends
///   on further bytes).
///
/// The contents of chartab[]:
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
  char_u *p;
  int i;
  bool tilde;
  bool do_isalpha;

  if (global) {
    // Set the default size for printable characters:
    // From <Space> to '~' is 1 (printable), others are 2 (not printable).
    // This also inits all 'isident' and 'isfname' flags to false.
    c = 0;

    while (c < ' ') {
      chartab[c++] = (dy_flags & DY_UHEX) ? 4 : 2;
    }

    while (c <= '~') {
      chartab[c++] = 1 + CT_PRINT_CHAR;
    }

    if (p_altkeymap) {
      while (c < YE) {
        chartab[c++] = 1 + CT_PRINT_CHAR;
      }
    }

    while (c < 256) {
      if (enc_utf8 && (c >= 0xa0)) {
        // UTF-8: bytes 0xa0 - 0xff are printable (latin1)
        chartab[c++] = CT_PRINT_CHAR + 1;
      } else if ((enc_dbcs == DBCS_JPNU) && (c == 0x8e)) {
        // euc-jp characters starting with 0x8e are single width
        chartab[c++] = CT_PRINT_CHAR + 1;
      } else if ((enc_dbcs != 0) && (MB_BYTE2LEN(c) == 2)) {
        // other double-byte chars can be printable AND double-width
        chartab[c++] = CT_PRINT_CHAR + 2;
      } else {
        // the rest is unprintable by default
        chartab[c++] = (dy_flags & DY_UHEX) ? 4 : 2;
      }
    }

    // Assume that every multi-byte char is a filename character.
    for (c = 1; c < 256; ++c) {
      if (((enc_dbcs != 0) && (MB_BYTE2LEN(c) > 1))
          || ((enc_dbcs == DBCS_JPNU) && (c == 0x8e))
          || (enc_utf8 && (c >= 0xa0))) {
        chartab[c] |= CT_FNAME_CHAR;
      }
    }
  }

  // Init word char flags all to false
  memset(buf->b_chartab, 0, (size_t)32);

  if (enc_dbcs != 0) {
    for (c = 0; c < 256; ++c) {
      // double-byte characters are probably word characters
      if (MB_BYTE2LEN(c) == 2) {
        SET_CHARTAB(buf, c);
      }
    }
  }

  // In lisp mode the '-' character is included in keywords.
  if (buf->b_p_lisp) {
    SET_CHARTAB(buf, '-');
  }

  // Walk through the 'isident', 'iskeyword', 'isfname' and 'isprint'
  // options Each option is a list of characters, character numbers or
  // ranges, separated by commas, e.g.: "200-210,x,#-178,-"
  for (i = global ? 0 : 3; i <= 3; ++i) {
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
        c = getdigits_int(&p);
      } else if (has_mbyte) {
        c = mb_ptr2char_adv(&p);
      } else {
        c = *p++;
      }
      c2 = -1;

      if ((*p == '-') && (p[1] != NUL)) {
        ++p;

        if (ascii_isdigit(*p)) {
          c2 = getdigits_int(&p);
        } else if (has_mbyte) {
          c2 = mb_ptr2char_adv(&p);
        } else {
          c2 = *p++;
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
            || vim_islower(c)
            || vim_isupper(c)
            || (p_altkeymap && (F_isalpha(c) || F_isdigit(c)))) {
          if (i == 0) {
            // (re)set ID flag
            if (tilde) {
              chartab[c] &= (uint8_t)~CT_ID_CHAR;
            } else {
              chartab[c] |= CT_ID_CHAR;
            }
          } else if (i == 1) {
            // (re)set printable
            // For double-byte we keep the cell width, so
            // that we can detect it from the first byte.
            if (((c < ' ')
                 || (c > '~')
                 || (p_altkeymap && (F_isalpha(c) || F_isdigit(c))))
                && !(enc_dbcs && (MB_BYTE2LEN(c) == 2))) {
              if (tilde) {
                chartab[c] = (uint8_t)((chartab[c] & ~CT_CELL_MASK)
                                       + ((dy_flags & DY_UHEX) ? 4 : 2));
                chartab[c] &= (uint8_t)~CT_PRINT_CHAR;
              } else {
                chartab[c] = (uint8_t)((chartab[c] & ~CT_CELL_MASK) + 1);
                chartab[c] |= CT_PRINT_CHAR;
              }
            }
          } else if (i == 2) {
            // (re)set fname flag
            if (tilde) {
              chartab[c] &= (uint8_t)~CT_FNAME_CHAR;
            } else {
              chartab[c] |= CT_FNAME_CHAR;
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
    if (has_mbyte && ((trs_len = (*mb_ptr2len)(buf)) > 1)) {
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

/// Translate a string into allocated memory, replacing special chars with
/// printable chars.
///
/// @param s
///
/// @return translated string
char_u *transstr(char_u *s) FUNC_ATTR_NONNULL_RET
{
  char_u *res;
  char_u *p;
  int c;
  size_t l;
  char_u hexbuf[11];

  if (has_mbyte) {
    // Compute the length of the result, taking account of unprintable
    // multi-byte characters.
    size_t len = 0;
    p = s;

    while (*p != NUL) {
      if ((l = (size_t)(*mb_ptr2len)(p)) > 1) {
        c = (*mb_ptr2char)(p);
        p += l;

        if (vim_isprintc(c)) {
          len += l;
        } else {
          transchar_hex(hexbuf, c);
          len += STRLEN(hexbuf);
        }
      } else {
        l = (size_t)byte2cells(*p++);

        if (l > 0) {
          len += l;
        } else {
          // illegal byte sequence
          len += 4;
        }
      }
    }
    res = xmallocz(len);
  } else {
    res = xmallocz((size_t)vim_strsize(s));
  }

  *res = NUL;
  p = s;

  while (*p != NUL) {
    if (has_mbyte && ((l = (size_t)(*mb_ptr2len)(p)) > 1)) {
      c = (*mb_ptr2char)(p);

      if (vim_isprintc(c)) {
        // append printable multi-byte char
        STRNCAT(res, p, l);
      } else {
        transchar_hex(res + STRLEN(res), c);
      }
      p += l;
    } else {
      STRCAT(res, transchar_byte(*p++));
    }
  }

  return res;
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
    if (enc_utf8 || (has_mbyte && (MB_BYTE2LEN(STR_CHAR(i)) > 1))) {
      if (enc_utf8) {
        int c = utf_ptr2char(STR_PTR(i));
        int olen = utf_ptr2len(STR_PTR(i));
        int lc = utf_tolower(c);

        // Only replace the character when it is not an invalid
        // sequence (ASCII character or more than one byte) and
        // utf_tolower() doesn't return the original character.
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
      }

      // skip to next multi-byte char
      i += (*mb_ptr2len)(STR_PTR(i));
    } else {
      if (buf == NULL) {
        GA_CHAR(i) = (char_u)TOLOWER_LOC(GA_CHAR(i));
      } else {
        buf[i] = (char_u)TOLOWER_LOC(buf[i]);
      }
      ++i;
    }
  }

  if (buf == NULL) {
    return (char_u *)ga.ga_data;
  }
  return buf;
}

// Catch 22: chartab[] can't be initialized before the options are
// initialized, and initializing options may cause transchar() to be called!
// When chartab_initialized == false don't use chartab[].
// Does NOT work for multi-byte characters, c must be <= 255.
// Also doesn't work for the first byte of a multi-byte, "c" must be a
// character!
static char_u transchar_buf[7];

/// Translates a character
///
/// @param c
///
/// @return translated character.
char_u* transchar(int c)
{
  int i = 0;
  if (IS_SPECIAL(c)) {
    // special key code, display as ~@ char
    transchar_buf[0] = '~';
    transchar_buf[1] = '@';
    i = 2;
    c = K_SECOND(c);
  }

  if ((!chartab_initialized && (((c >= ' ') && (c <= '~')) || F_ischar(c)))
      || ((c < 256) && vim_isprintc_strict(c))) {
    // printable character
    transchar_buf[i] = (char_u)c;
    transchar_buf[i + 1] = NUL;
  } else {
    transchar_nonprint(transchar_buf + i, c);
  }
  return transchar_buf;
}

/// Like transchar(), but called with a byte instead of a character.  Checks
/// for an illegal UTF-8 byte.
///
/// @param c
///
/// @return pointer to translated character in transchar_buf.
char_u* transchar_byte(int c)
{
  if (enc_utf8 && (c >= 0x80)) {
    transchar_nonprint(transchar_buf, c);
    return transchar_buf;
  }
  return transchar(c);
}

/// Convert non-printable character to two or more printable characters in
/// "buf[]".  "buf" needs to be able to hold five bytes.
/// Does NOT work for multi-byte characters, c must be <= 255.
///
/// @param buf
/// @param c
void transchar_nonprint(char_u *buf, int c)
{
  if (c == NL) {
    // we use newline in place of a NUL
    c = NUL;
  } else if ((c == CAR) && (get_fileformat(curbuf) == EOL_MAC)) {
    // we use CR in place of  NL in this case
    c = NL;
  }

  if (dy_flags & DY_UHEX) {
    // 'display' has "uhex"
    transchar_hex(buf, c);
  } else if (c <= 0x7f) {
    // 0x00 - 0x1f and 0x7f
    buf[0] = '^';
    // DEL displayed as ^?
    buf[1] = (char_u)(c ^ 0x40);

    buf[2] = NUL;
  } else if (enc_utf8 && (c >= 0x80)) {
    transchar_hex(buf, c);
  } else if ((c >= ' ' + 0x80) && (c <= '~' + 0x80)) {
    // 0xa0 - 0xfe
    buf[0] = '|';
    buf[1] = (char_u)(c - 0x80);
    buf[2] = NUL;
  } else {
    // 0x80 - 0x9f and 0xff
    buf[0] = '~';
    buf[1] = (char_u)((c - 0x80) ^ 0x40);
    buf[2] = NUL;
  }
}

/// Convert a non-printable character to hex.
///
/// @param buf
/// @param c
void transchar_hex(char_u *buf, int c)
{
  int i = 0;

  buf[0] = '<';
  if (c > 255) {
    buf[++i] = (char_u)nr2hex((unsigned)c >> 12);
    buf[++i] = (char_u)nr2hex((unsigned)c >> 8);
  }
  buf[++i] = (char_u)(nr2hex((unsigned)c >> 4));
  buf[++i] = (char_u)(nr2hex((unsigned)c));
  buf[++i] = '>';
  buf[++i] = NUL;
}

/// Convert the lower 4 bits of byte "c" to its hex character.
/// Lower case letters are used to avoid the confusion of <F1> being 0xf1 or
/// function key 1.
///
/// @param c
///
/// @return the hex character.
static unsigned nr2hex(unsigned c)
{
  if ((c & 0xf) <= 9) {
    return (c & 0xf) + '0';
  }
  return (c & 0xf) - 10 + 'a';
}

/// Return number of display cells occupied by byte "b".
///
/// Caller must make sure 0 <= b <= 255.
/// For multi-byte mode "b" must be the first byte of a character.
/// A TAB is counted as two cells: "^I".
/// For UTF-8 mode this will return 0 for bytes >= 0x80, because the number of
/// cells depends on further bytes.
///
/// @param b
///
/// @reeturn Number of display cells.
int byte2cells(int b)
{
  if (enc_utf8 && (b >= 0x80)) {
    return 0;
  }
  return chartab[b] & CT_CELL_MASK;
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
    if (enc_utf8) {
      return utf_char2cells(c);
    }

    // DBCS: double-byte means double-width, except for euc-jp with first
    // byte 0x8e
    if ((enc_dbcs != 0) && (c >= 0x100)) {
      if ((enc_dbcs == DBCS_JPNU) && (((unsigned)c >> 8) == 0x8e)) {
        return 1;
      }
      return 2;
    }
  }
  return chartab[c & 0xff] & CT_CELL_MASK;
}

/// Return number of display cells occupied by character at "*p".
/// A TAB is counted as two cells: "^I" or four: "<09>".
///
/// @param p
///
/// @return number of display cells.
int ptr2cells(char_u *p)
{
  // For UTF-8 we need to look at more bytes if the first byte is >= 0x80.
  if (enc_utf8 && (*p >= 0x80)) {
    return utf_ptr2cells(p);
  }

  // For DBCS we can tell the cell count from the first byte.
  return chartab[*p] & CT_CELL_MASK;
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
    if (has_mbyte) {
      int l = (*mb_ptr2len)(s);
      size += ptr2cells(s);
      s += l;
      len -= l - 1;
    } else {
      size += byte2cells(*s++);
    }
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
  if (*(p) == TAB && (!(wp)->w_p_list || lcs_tab1)) { \
    const int ts = (int) (buf)->b_p_ts; \
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
       mb_ptr_adv(s)) {
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
  return c > 0 && c < 0x100 && (chartab[c] & CT_ID_CHAR);
}

/// Check that "c" is a keyword character:
/// Letters and characters from 'iskeyword' option for current buffer.
/// For multi-byte characters mb_get_class() is used (builtin rules).
///
/// @param  c  character to check
bool vim_iswordc(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return vim_iswordc_buf(c, curbuf);
}

/// Check that "c" is a keyword character:
/// Letters and characters from 'iskeyword' option for given buffer.
/// For multi-byte characters mb_get_class() is used (builtin rules).
///
/// @param  c    character to check
/// @param  buf  buffer whose keywords to use
bool vim_iswordc_buf(int c, buf_T *buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(2)
{
  if (c >= 0x100) {
    if (enc_dbcs != 0) {
      return dbcs_class((unsigned)c >> 8, (unsigned)(c & 0xff)) >= 2;
    }

    if (enc_utf8) {
      return utf_class(c) >= 2;
    }
  }
  return c > 0 && c < 0x100 && GET_CHARTAB(buf, c) != 0;
}

/// Just like vim_iswordc() but uses a pointer to the (multi-byte) character.
///
/// @param  p  pointer to the multi-byte character
///
/// @return true if "p" points to a keyword character.
bool vim_iswordp(char_u *p)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (has_mbyte && (MB_BYTE2LEN(*p) > 1)) {
    return mb_get_class(p) >= 2;
  }
  return GET_CHARTAB(curbuf, *p) != 0;
}

/// Just like vim_iswordc_buf() but uses a pointer to the (multi-byte)
/// character.
///
/// @param  p    pointer to the multi-byte character
/// @param  buf  buffer whose keywords to use
///
/// @return true if "p" points to a keyword character.
bool vim_iswordp_buf(char_u *p, buf_T *buf)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (has_mbyte && (MB_BYTE2LEN(*p) > 1)) {
    return mb_get_class(p) >= 2;
  }
  return GET_CHARTAB(buf, *p) != 0;
}

/// Check that "c" is a valid file-name character.
/// Assume characters above 0x100 are valid (multi-byte).
///
/// @param  c  character to check
bool vim_isfilec(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return c >= 0x100 || (c > 0 && (chartab[c] & CT_FNAME_CHAR));
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
  if (enc_utf8 && (c >= 0x100)) {
    return utf_printable(c);
  }
  return c >= 0x100 || (c > 0 && (chartab[c] & CT_PRINT_CHAR));
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
  if ((enc_dbcs != 0) && (c < 0x100) && (MB_BYTE2LEN(c) > 1)) {
    return false;
  }

  if (enc_utf8 && (c >= 0x100)) {
    return utf_printable(c);
  }
  return c >= 0x100 || (c > 0 && (chartab[c] & CT_PRINT_CHAR));
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
  mb_ptr_adv(*s);
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
      && !vim_isbreak(s[1])
      && wp->w_p_wrap
      && (wp->w_width != 0)) {
    // Count all characters from first non-blank after a blank up to next
    // non-blank after a blank.
    numberextra = win_col_off(wp);
    col2 = col;
    colmax = (colnr_T)(wp->w_width - numberextra - col_adj);

    if (col >= colmax) {
        colmax += col_adj;
        n = colmax + win_col_off2(wp);

      if (n > 0) {
        colmax += (((col - colmax) / n) + 1) * n - col_adj;
      }
    }

    for (;;) {
      ps = s;
      mb_ptr_adv(s);
      c = *s;

      if (!((c != NUL)
            && (vim_isbreak(c)
                || (!vim_isbreak(c)
                    && ((col2 == col) || !vim_isbreak(*ps)))))) {
        break;
      }

      col2 += win_chartabsize(wp, s, col2);

      if (col2 >= colmax) { /* doesn't fit */
        size = colmax - col + col_adj;
        break;
      }
    }
  } else if (has_mbyte
             && (size == 2)
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

    if (col >= (colnr_T)wp->w_width) {
      col -= wp->w_width;
      numberextra = wp->w_width - (numberextra - win_col_off2(wp));
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

    if (col == 0 || (col + size + sbrlen > (colnr_T)wp->w_width)) {
      added = 0;

      if (*p_sbr != NUL) {
        if (size + sbrlen + numberwidth > (colnr_T)wp->w_width) {
          // Calculate effective window width.
          int width = (colnr_T)wp->w_width - sbrlen - numberwidth;
          int prev_width = col ? ((colnr_T)wp->w_width - (sbrlen + col)) : 0;
          if (width == 0) {
            width = (colnr_T)wp->w_width;
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

  if ((*s == TAB) && (!wp->w_p_list || lcs_tab1)) {
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

  if (wp->w_width == 0) {
    // there is no border
    return false;
  }
  width1 = wp->w_width - win_col_off(wp);

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
    posptr = ptr + pos->col;
  }

  // This function is used very often, do some speed optimizations.
  // When 'list', 'linebreak', 'showbreak' and 'breakindent' are not set
  // use a simple loop.
  // Also use this when 'list' is set but tabs take their normal size.
  if ((!wp->w_p_list || (lcs_tab1 != NUL))
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
        if (has_mbyte) {
          // For utf-8, if the byte is >= 0x80, need to look at
          // further bytes to find the cell width.
          if (enc_utf8 && (c >= 0x80)) {
            incr = utf_ptr2cells(ptr);
          } else {
            incr = CHARSIZE(c);
          }

          // If a double-cell char doesn't fit at the end of a line
          // it wraps to the next line, it's like this char is three
          // cells wide.
          if ((incr == 2)
              && wp->w_p_wrap
              && (MB_BYTE2LEN(*ptr) > 1)
              && in_win_border(wp, vcol)) {
            ++incr;
            head = 1;
          }
        } else {
          incr = CHARSIZE(c);
        }
      }

      if ((posptr != NULL) && (ptr >= posptr)) {
        // character at pos->col
        break;
      }

      vcol += incr;
      mb_ptr_adv(ptr);
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
      mb_ptr_adv(ptr);
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
  getvcol(curwin, posp, NULL, &vcol, NULL);
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
      int c = (*mb_ptr2char)(ptr + pos->col);
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

  if (ltp(pos1, pos2)) {
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
/// @param q
///
/// @return Pointer to character after the skipped whitespace.
char_u* skipwhite(char_u *q)
{
  char_u *p = q;
  while (ascii_iswhite(*p)) {
    // skip to next non-white
    p++;
  }
  return p;
}

/// skip over digits
///
/// @param q
///
/// @return Pointer to the character after the skipped digits.
char_u* skipdigits(char_u *q)
{
  char_u *p = q;
  while (ascii_isdigit(*p)) {
    // skip to next non-digit
    p++;
  }
  return p;
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

// Vim's own character class functions.  These exist because many library
// islower()/toupper() etc. do not work properly: they crash when used with
// invalid values or can't handle latin1 when the locale is C.
// Speed is most important here.
#define LATIN1LOWER 'l'
#define LATIN1UPPER 'U'

static char_u latin1flags[257] =
    "                                                                "
    " UUUUUUUUUUUUUUUUUUUUUUUUUU      llllllllllllllllllllllllll     "
    "                                                                "
    "UUUUUUUUUUUUUUUUUUUUUUU UUUUUUUllllllllllllllllllllllll llllllll";
static char_u latin1upper[257] =
    "                                 !\"#$%&'()*+,-./0123456789:;<=>"
    "?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{|}~"
    "\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e"
    "\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e"
    "\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae"
    "\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe"
    "\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce"
    "\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde"
    "\xdf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce"
    "\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xf7\xd8\xd9\xda\xdb\xdc\xdd\xde\xff";
static char_u latin1lower[257] =
    "                                 !\"#$%&'()*+,-./0123456789:;<=>"
    "?@abcdefghijklmnopqrstuvwxyz[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    "\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e"
    "\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e"
    "\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae"
    "\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe"
    "\xbf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee"
    "\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xd7\xf8\xf9\xfa\xfb\xfc\xfd\xfe"
    "\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee"
    "\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff";

/// Check that the character is lower-case
///
/// @param  c  character to check
bool vim_islower(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (c <= '@') {
    return false;
  }

  if (c >= 0x80) {
    if (enc_utf8) {
      return utf_islower(c);
    }

    if (c >= 0x100) {
      if (has_mbyte) {
        return iswlower((wint_t)c);
      }

      // islower() can't handle these chars and may crash
      return false;
    }

    if (enc_latin1like) {
      return (latin1flags[c] & LATIN1LOWER) == LATIN1LOWER;
    }
  }
  return islower(c);
}

/// Check that the character is upper-case
///
/// @param  c  character to check
bool vim_isupper(int c)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ALL
{
  if (c <= '@') {
    return false;
  }

  if (c >= 0x80) {
    if (enc_utf8) {
      return utf_isupper(c);
    }

    if (c >= 0x100) {
      if (has_mbyte) {
        return iswupper((wint_t)c);
      }

      // isupper() can't handle these chars and may crash
      return false;
    }

    if (enc_latin1like) {
      return (latin1flags[c] & LATIN1UPPER) == LATIN1UPPER;
    }
  }
  return isupper(c);
}

int vim_toupper(int c)
{
  if (c <= '@') {
    return c;
  }

  if (c >= 0x80) {
    if (enc_utf8) {
      return utf_toupper(c);
    }

    if (c >= 0x100) {
      if (has_mbyte) {
        return (int)towupper((wint_t)c);
      }

      // toupper() can't handle these chars and may crash
      return c;
    }

    if (enc_latin1like) {
      return latin1upper[c];
    }
  }
  return TOUPPER_LOC(c);
}

int vim_tolower(int c)
{
  if (c <= '@') {
    return c;
  }

  if (c >= 0x80) {
    if (enc_utf8) {
      return utf_tolower(c);
    }

    if (c >= 0x100) {
      if (has_mbyte) {
        return (int)towlower((wint_t)c);
      }

      // tolower() can't handle these chars and may crash
      return c;
    }

    if (enc_latin1like) {
      return latin1lower[c];
    }
  }
  return TOLOWER_LOC(c);
}

/// skiptowhite: skip over text until ' ' or '\t' or NUL.
///
/// @param p
///
/// @return Pointer to the next whitespace or NUL character.
char_u* skiptowhite(char_u *p)
{
  while (*p != ' ' && *p != '\t' && *p != NUL) {
    p++;
  }
  return p;
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

/// Get a number from a string and skip over it.
///
/// @param[out]  pp  A pointer to a pointer to char_u.
///                  It will be advanced past the read number.
///
/// @return Number read from the string.
intmax_t getdigits(char_u **pp)
{
  intmax_t number = strtoimax((char *)*pp, (char **)pp, 10);
  assert(errno != ERANGE);
  return number;
}

/// Get an int number from a string.
///
/// A getdigits wrapper restricted to int values.
int getdigits_int(char_u **pp)
{
  intmax_t number = getdigits(pp);
#if SIZEOF_INTMAX_T > SIZEOF_INT
  assert(number >= INT_MIN && number <= INT_MAX);
#endif
  return (int)number;
}

/// Get a long number from a string.
///
/// A getdigits wrapper restricted to long values.
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
/// @param prep Returns type of number 0 = decimal, 'x' or 'X' is hex,
///        '0' = octal, 'b' or 'B' is bin
/// @param len Returns the detected length of number.
/// @param what Recognizes what number passed.
/// @param nptr Returns the signed result.
/// @param unptr Returns the unsigned result.
/// @param maxlen Max length of string to check.
void vim_str2nr(char_u *start, int *prep, int *len, int what,
                long *nptr, unsigned long *unptr, int maxlen)
{
  char_u *ptr = start;
  int pre = 0;  // default is decimal
  bool negative = false;
  unsigned long un = 0;

  if (ptr[0] == '-') {
    negative = true;
    ptr++;
  }

  // Recognize hex, octal and bin.
  if ((ptr[0] == '0') && (ptr[1] != '8') && (ptr[1] != '9')
      && (maxlen == 0 || maxlen > 1)) {
    pre = ptr[1];

    if ((what & STR2NR_HEX)
        && ((pre == 'X') || (pre == 'x'))
        && ascii_isxdigit(ptr[2])
        && (maxlen == 0 || maxlen > 2)) {
      // hexadecimal
      ptr += 2;
    } else if ((what & STR2NR_BIN)
               && ((pre == 'B') || (pre == 'b'))
               && ascii_isbdigit(ptr[2])
               && (maxlen == 0 || maxlen > 2)) {
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
  if ((pre == 'B') || (pre == 'b') || what == STR2NR_BIN + STR2NR_FORCE) {
    // bin
    if (pre != 0) {
      n += 2;  // skip over "0b"
    }
    while ('0' <= *ptr && *ptr <= '1') {
      un = 2 * un + (unsigned long)(*ptr - '0');
      ptr++;
      if (n++ == maxlen) {
        break;
      }
    }
  } else if ((pre == '0') || what == STR2NR_OCT + STR2NR_FORCE) {
    // octal
    while ('0' <= *ptr && *ptr <= '7') {
      un = 8 * un + (unsigned long)(*ptr - '0');
      ptr++;
      if (n++ == maxlen) {
        break;
      }
    }
  } else if ((pre == 'X') || (pre == 'x')
             || what == STR2NR_HEX + STR2NR_FORCE) {
    // hex
    if (pre != 0) {
      n += 2;  // skip over "0x"
    }
    while (ascii_isxdigit(*ptr)) {
      un = 16 * un + (unsigned long)hex2nr(*ptr);
      ptr++;
      if (n++ == maxlen) {
        break;
      }
    }
  } else {
    // decimal
    while (ascii_isdigit(*ptr)) {
      un = 10 * un + (unsigned long)(*ptr - '0');
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
    if (negative) {
      // account for leading '-' for decimal numbers
      *nptr = -(long)un;
    } else {
      *nptr = (long)un;
    }
  }

  if (unptr != NULL) {
    *unptr = un;
  }
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
