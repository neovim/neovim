/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#include "vim.h"
#include "charset.h"
#include "main.h"
#include "mbyte.h"
#include "memline.h"
#include "misc1.h"
#include "misc2.h"
#include "garray.h"
#include "move.h"
#include "os_unix.h"

static int win_chartabsize(win_T *wp, char_u *p, colnr_T col);

# if defined(HAVE_WCHAR_H)
#  include <wchar.h>        /* for towupper() and towlower() */
# endif
static int win_nolbr_chartabsize(win_T *wp, char_u *s, colnr_T col,
                                 int *headp);

static unsigned nr2hex(unsigned c);

static int chartab_initialized = FALSE;

/* b_chartab[] is an array of 32 bytes, each bit representing one of the
 * characters 0-255. */
#define SET_CHARTAB(buf, c) (buf)->b_chartab[(unsigned)(c) >> \
                                             3] |= (1 << ((c) & 0x7))
#define RESET_CHARTAB(buf, c) (buf)->b_chartab[(unsigned)(c) >> \
                                               3] &= ~(1 << ((c) & 0x7))
#define GET_CHARTAB(buf, \
                    c) ((buf)->b_chartab[(unsigned)(c) >> 3] & (1 << ((c) & 0x7)))

/*
 * Fill chartab[].  Also fills curbuf->b_chartab[] with flags for keyword
 * characters for current buffer.
 *
 * Depends on the option settings 'iskeyword', 'isident', 'isfname',
 * 'isprint' and 'encoding'.
 *
 * The index in chartab[] depends on 'encoding':
 * - For non-multi-byte index with the byte (same as the character).
 * - For DBCS index with the first byte.
 * - For UTF-8 index with the character (when first byte is up to 0x80 it is
 *   the same as the character, if the first byte is 0x80 and above it depends
 *   on further bytes).
 *
 * The contents of chartab[]:
 * - The lower two bits, masked by CT_CELL_MASK, give the number of display
 *   cells the character occupies (1 or 2).  Not valid for UTF-8 above 0x80.
 * - CT_PRINT_CHAR bit is set when the character is printable (no need to
 *   translate the character before displaying it).  Note that only DBCS
 *   characters can have 2 display cells and still be printable.
 * - CT_FNAME_CHAR bit is set when the character can be in a file name.
 * - CT_ID_CHAR bit is set when the character can be in an identifier.
 *
 * Return FAIL if 'iskeyword', 'isident', 'isfname' or 'isprint' option has an
 * error, OK otherwise.
 */
int init_chartab(void)         {
  return buf_init_chartab(curbuf, TRUE);
}

int 
buf_init_chartab (
    buf_T *buf,
    int global                     /* FALSE: only set buf->b_chartab[] */
)
{
  int c;
  int c2;
  char_u      *p;
  int i;
  int tilde;
  int do_isalpha;

  if (global) {
    /*
     * Set the default size for printable characters:
     * From <Space> to '~' is 1 (printable), others are 2 (not printable).
     * This also inits all 'isident' and 'isfname' flags to FALSE.
     *
     * EBCDIC: all chars below ' ' are not printable, all others are
     * printable.
     */
    c = 0;
    while (c < ' ')
      chartab[c++] = (dy_flags & DY_UHEX) ? 4 : 2;
    while (c <= '~')
      chartab[c++] = 1 + CT_PRINT_CHAR;
    if (p_altkeymap) {
      while (c < YE)
        chartab[c++] = 1 + CT_PRINT_CHAR;
    }
    while (c < 256) {
      /* UTF-8: bytes 0xa0 - 0xff are printable (latin1) */
      if (enc_utf8 && c >= 0xa0)
        chartab[c++] = CT_PRINT_CHAR + 1;
      /* euc-jp characters starting with 0x8e are single width */
      else if (enc_dbcs == DBCS_JPNU && c == 0x8e)
        chartab[c++] = CT_PRINT_CHAR + 1;
      /* other double-byte chars can be printable AND double-width */
      else if (enc_dbcs != 0 && MB_BYTE2LEN(c) == 2)
        chartab[c++] = CT_PRINT_CHAR + 2;
      else
        /* the rest is unprintable by default */
        chartab[c++] = (dy_flags & DY_UHEX) ? 4 : 2;
    }

    /* Assume that every multi-byte char is a filename character. */
    for (c = 1; c < 256; ++c)
      if ((enc_dbcs != 0 && MB_BYTE2LEN(c) > 1)
          || (enc_dbcs == DBCS_JPNU && c == 0x8e)
          || (enc_utf8 && c >= 0xa0))
        chartab[c] |= CT_FNAME_CHAR;
  }

  /*
   * Init word char flags all to FALSE
   */
  vim_memset(buf->b_chartab, 0, (size_t)32);
  if (enc_dbcs != 0)
    for (c = 0; c < 256; ++c) {
      /* double-byte characters are probably word characters */
      if (MB_BYTE2LEN(c) == 2)
        SET_CHARTAB(buf, c);
    }

  /*
   * In lisp mode the '-' character is included in keywords.
   */
  if (buf->b_p_lisp)
    SET_CHARTAB(buf, '-');

  /* Walk through the 'isident', 'iskeyword', 'isfname' and 'isprint'
   * options Each option is a list of characters, character numbers or
   * ranges, separated by commas, e.g.: "200-210,x,#-178,-"
   */
  for (i = global ? 0 : 3; i <= 3; ++i) {
    if (i == 0)
      p = p_isi;                /* first round: 'isident' */
    else if (i == 1)
      p = p_isp;                /* second round: 'isprint' */
    else if (i == 2)
      p = p_isf;                /* third round: 'isfname' */
    else        /* i == 3 */
      p = buf->b_p_isk;         /* fourth round: 'iskeyword' */

    while (*p) {
      tilde = FALSE;
      do_isalpha = FALSE;
      if (*p == '^' && p[1] != NUL) {
        tilde = TRUE;
        ++p;
      }
      if (VIM_ISDIGIT(*p))
        c = getdigits(&p);
      else if (has_mbyte)
        c = mb_ptr2char_adv(&p);
      else
        c = *p++;
      c2 = -1;
      if (*p == '-' && p[1] != NUL) {
        ++p;
        if (VIM_ISDIGIT(*p))
          c2 = getdigits(&p);
        else if (has_mbyte)
          c2 = mb_ptr2char_adv(&p);
        else
          c2 = *p++;
      }
      if (c <= 0 || c >= 256 || (c2 < c && c2 != -1) || c2 >= 256
          || !(*p == NUL || *p == ','))
        return FAIL;

      if (c2 == -1) {           /* not a range */
        /*
         * A single '@' (not "@-@"):
         * Decide on letters being ID/printable/keyword chars with
         * standard function isalpha(). This takes care of locale for
         * single-byte characters).
         */
        if (c == '@') {
          do_isalpha = TRUE;
          c = 1;
          c2 = 255;
        } else
          c2 = c;
      }
      while (c <= c2) {
        /* Use the MB_ functions here, because isalpha() doesn't
         * work properly when 'encoding' is "latin1" and the locale is
         * "C".  */
        if (!do_isalpha || MB_ISLOWER(c) || MB_ISUPPER(c)
            || (p_altkeymap && (F_isalpha(c) || F_isdigit(c)))
            ) {
          if (i == 0) {                         /* (re)set ID flag */
            if (tilde)
              chartab[c] &= ~CT_ID_CHAR;
            else
              chartab[c] |= CT_ID_CHAR;
          } else if (i == 1)   {                /* (re)set printable */
            if ((c < ' '
                 || c > '~'
                 || (p_altkeymap
                     && (F_isalpha(c) || F_isdigit(c)))
                 )
                /* For double-byte we keep the cell width, so
                 * that we can detect it from the first byte. */
                && !(enc_dbcs && MB_BYTE2LEN(c) == 2)
                ) {
              if (tilde) {
                chartab[c] = (chartab[c] & ~CT_CELL_MASK)
                             + ((dy_flags & DY_UHEX) ? 4 : 2);
                chartab[c] &= ~CT_PRINT_CHAR;
              } else   {
                chartab[c] = (chartab[c] & ~CT_CELL_MASK) + 1;
                chartab[c] |= CT_PRINT_CHAR;
              }
            }
          } else if (i == 2)   {                /* (re)set fname flag */
            if (tilde)
              chartab[c] &= ~CT_FNAME_CHAR;
            else
              chartab[c] |= CT_FNAME_CHAR;
          } else   {     /* i == 3 */		/* (re)set keyword flag */
            if (tilde)
              RESET_CHARTAB(buf, c);
            else
              SET_CHARTAB(buf, c);
          }
        }
        ++c;
      }

      c = *p;
      p = skip_to_option_part(p);
      if (c == ',' && *p == NUL)
        /* Trailing comma is not allowed. */
        return FAIL;
    }
  }
  chartab_initialized = TRUE;
  return OK;
}

/*
 * Translate any special characters in buf[bufsize] in-place.
 * The result is a string with only printable characters, but if there is not
 * enough room, not all characters will be translated.
 */
void trans_characters(char_u *buf, int bufsize)
{
  int len;                      /* length of string needing translation */
  int room;                     /* room in buffer after string */
  char_u      *trs;             /* translated character */
  int trs_len;                  /* length of trs[] */

  len = (int)STRLEN(buf);
  room = bufsize - len;
  while (*buf != 0) {
    /* Assume a multi-byte character doesn't need translation. */
    if (has_mbyte && (trs_len = (*mb_ptr2len)(buf)) > 1)
      len -= trs_len;
    else {
      trs = transchar_byte(*buf);
      trs_len = (int)STRLEN(trs);
      if (trs_len > 1) {
        room -= trs_len - 1;
        if (room <= 0)
          return;
        mch_memmove(buf + trs_len, buf + 1, (size_t)len);
      }
      mch_memmove(buf, trs, (size_t)trs_len);
      --len;
    }
    buf += trs_len;
  }
}

#if defined(FEAT_EVAL) || defined(FEAT_TITLE) || defined(FEAT_INS_EXPAND) \
  || defined(PROTO)
/*
 * Translate a string into allocated memory, replacing special chars with
 * printable chars.  Returns NULL when out of memory.
 */
char_u *transstr(char_u *s)
{
  char_u      *res;
  char_u      *p;
  int l, len, c;
  char_u hexbuf[11];

  if (has_mbyte) {
    /* Compute the length of the result, taking account of unprintable
     * multi-byte characters. */
    len = 0;
    p = s;
    while (*p != NUL) {
      if ((l = (*mb_ptr2len)(p)) > 1) {
        c = (*mb_ptr2char)(p);
        p += l;
        if (vim_isprintc(c))
          len += l;
        else {
          transchar_hex(hexbuf, c);
          len += (int)STRLEN(hexbuf);
        }
      } else   {
        l = byte2cells(*p++);
        if (l > 0)
          len += l;
        else
          len += 4;             /* illegal byte sequence */
      }
    }
    res = alloc((unsigned)(len + 1));
  } else
    res = alloc((unsigned)(vim_strsize(s) + 1));
  if (res != NULL) {
    *res = NUL;
    p = s;
    while (*p != NUL) {
      if (has_mbyte && (l = (*mb_ptr2len)(p)) > 1) {
        c = (*mb_ptr2char)(p);
        if (vim_isprintc(c))
          STRNCAT(res, p, l);           /* append printable multi-byte char */
        else
          transchar_hex(res + STRLEN(res), c);
        p += l;
      } else
        STRCAT(res, transchar_byte(*p++));
    }
  }
  return res;
}
#endif

/*
 * Convert the string "str[orglen]" to do ignore-case comparing.  Uses the
 * current locale.
 * When "buf" is NULL returns an allocated string (NULL for out-of-memory).
 * Otherwise puts the result in "buf[buflen]".
 */
char_u *str_foldcase(char_u *str, int orglen, char_u *buf, int buflen)
{
  garray_T ga;
  int i;
  int len = orglen;

#define GA_CHAR(i)  ((char_u *)ga.ga_data)[i]
#define GA_PTR(i)   ((char_u *)ga.ga_data + i)
#define STR_CHAR(i)  (buf == NULL ? GA_CHAR(i) : buf[i])
#define STR_PTR(i)   (buf == NULL ? GA_PTR(i) : buf + i)

  /* Copy "str" into "buf" or allocated memory, unmodified. */
  if (buf == NULL) {
    ga_init2(&ga, 1, 10);
    if (ga_grow(&ga, len + 1) == FAIL)
      return NULL;
    mch_memmove(ga.ga_data, str, (size_t)len);
    ga.ga_len = len;
  } else   {
    if (len >= buflen)              /* Ugly! */
      len = buflen - 1;
    mch_memmove(buf, str, (size_t)len);
  }
  if (buf == NULL)
    GA_CHAR(len) = NUL;
  else
    buf[len] = NUL;

  /* Make each character lower case. */
  i = 0;
  while (STR_CHAR(i) != NUL) {
    if (enc_utf8 || (has_mbyte && MB_BYTE2LEN(STR_CHAR(i)) > 1)) {
      if (enc_utf8) {
        int c = utf_ptr2char(STR_PTR(i));
        int olen = utf_ptr2len(STR_PTR(i));
        int lc = utf_tolower(c);

        /* Only replace the character when it is not an invalid
         * sequence (ASCII character or more than one byte) and
         * utf_tolower() doesn't return the original character. */
        if ((c < 0x80 || olen > 1) && c != lc) {
          int nlen = utf_char2len(lc);

          /* If the byte length changes need to shift the following
           * characters forward or backward. */
          if (olen != nlen) {
            if (nlen > olen) {
              if (buf == NULL
                  ? ga_grow(&ga, nlen - olen + 1) == FAIL
                  : len + nlen - olen >= buflen) {
                /* out of memory, keep old char */
                lc = c;
                nlen = olen;
              }
            }
            if (olen != nlen) {
              if (buf == NULL) {
                STRMOVE(GA_PTR(i) + nlen, GA_PTR(i) + olen);
                ga.ga_len += nlen - olen;
              } else   {
                STRMOVE(buf + i + nlen, buf + i + olen);
                len += nlen - olen;
              }
            }
          }
          (void)utf_char2bytes(lc, STR_PTR(i));
        }
      }
      /* skip to next multi-byte char */
      i += (*mb_ptr2len)(STR_PTR(i));
    } else   {
      if (buf == NULL)
        GA_CHAR(i) = TOLOWER_LOC(GA_CHAR(i));
      else
        buf[i] = TOLOWER_LOC(buf[i]);
      ++i;
    }
  }

  if (buf == NULL)
    return (char_u *)ga.ga_data;
  return buf;
}

/*
 * Catch 22: chartab[] can't be initialized before the options are
 * initialized, and initializing options may cause transchar() to be called!
 * When chartab_initialized == FALSE don't use chartab[].
 * Does NOT work for multi-byte characters, c must be <= 255.
 * Also doesn't work for the first byte of a multi-byte, "c" must be a
 * character!
 */
static char_u transchar_buf[7];

char_u *transchar(int c)
{
  int i;

  i = 0;
  if (IS_SPECIAL(c)) {      /* special key code, display as ~@ char */
    transchar_buf[0] = '~';
    transchar_buf[1] = '@';
    i = 2;
    c = K_SECOND(c);
  }

  if ((!chartab_initialized && (
         (c >= ' ' && c <= '~')
         || F_ischar(c)
         )) || (c < 256 && vim_isprintc_strict(c))) {
    /* printable character */
    transchar_buf[i] = c;
    transchar_buf[i + 1] = NUL;
  } else
    transchar_nonprint(transchar_buf + i, c);
  return transchar_buf;
}

/*
 * Like transchar(), but called with a byte instead of a character.  Checks
 * for an illegal UTF-8 byte.
 */
char_u *transchar_byte(int c)
{
  if (enc_utf8 && c >= 0x80) {
    transchar_nonprint(transchar_buf, c);
    return transchar_buf;
  }
  return transchar(c);
}

/*
 * Convert non-printable character to two or more printable characters in
 * "buf[]".  "buf" needs to be able to hold five bytes.
 * Does NOT work for multi-byte characters, c must be <= 255.
 */
void transchar_nonprint(char_u *buf, int c)
{
  if (c == NL)
    c = NUL;                    /* we use newline in place of a NUL */
  else if (c == CAR && get_fileformat(curbuf) == EOL_MAC)
    c = NL;                     /* we use CR in place of  NL in this case */

  if (dy_flags & DY_UHEX)               /* 'display' has "uhex" */
    transchar_hex(buf, c);

  else if (c <= 0x7f) {                         /* 0x00 - 0x1f and 0x7f */
    buf[0] = '^';
    buf[1] = c ^ 0x40;                  /* DEL displayed as ^? */

    buf[2] = NUL;
  } else if (enc_utf8 && c >= 0x80)   {
    transchar_hex(buf, c);
  } else if (c >= ' ' + 0x80 && c <= '~' + 0x80)   { /* 0xa0 - 0xfe */
    buf[0] = '|';
    buf[1] = c - 0x80;
    buf[2] = NUL;
  } else   {                                        /* 0x80 - 0x9f and 0xff */
    /*
     * TODO: EBCDIC I don't know what to do with this chars, so I display
     * them as '~?' for now
     */
    buf[0] = '~';
    buf[1] = (c - 0x80) ^ 0x40;         /* 0xff displayed as ~? */
    buf[2] = NUL;
  }
}

void transchar_hex(char_u *buf, int c)
{
  int i = 0;

  buf[0] = '<';
  if (c > 255) {
    buf[++i] = nr2hex((unsigned)c >> 12);
    buf[++i] = nr2hex((unsigned)c >> 8);
  }
  buf[++i] = nr2hex((unsigned)c >> 4);
  buf[++i] = nr2hex((unsigned)c);
  buf[++i] = '>';
  buf[++i] = NUL;
}

/*
 * Convert the lower 4 bits of byte "c" to its hex character.
 * Lower case letters are used to avoid the confusion of <F1> being 0xf1 or
 * function key 1.
 */
static unsigned nr2hex(unsigned c)
{
  if ((c & 0xf) <= 9)
    return (c & 0xf) + '0';
  return (c & 0xf) - 10 + 'a';
}

/*
 * Return number of display cells occupied by byte "b".
 * Caller must make sure 0 <= b <= 255.
 * For multi-byte mode "b" must be the first byte of a character.
 * A TAB is counted as two cells: "^I".
 * For UTF-8 mode this will return 0 for bytes >= 0x80, because the number of
 * cells depends on further bytes.
 */
int byte2cells(int b)
{
  if (enc_utf8 && b >= 0x80)
    return 0;
  return chartab[b] & CT_CELL_MASK;
}

/*
 * Return number of display cells occupied by character "c".
 * "c" can be a special key (negative number) in which case 3 or 4 is returned.
 * A TAB is counted as two cells: "^I" or four: "<09>".
 */
int char2cells(int c)
{
  if (IS_SPECIAL(c))
    return char2cells(K_SECOND(c)) + 2;
  if (c >= 0x80) {
    /* UTF-8: above 0x80 need to check the value */
    if (enc_utf8)
      return utf_char2cells(c);
    /* DBCS: double-byte means double-width, except for euc-jp with first
     * byte 0x8e */
    if (enc_dbcs != 0 && c >= 0x100) {
      if (enc_dbcs == DBCS_JPNU && ((unsigned)c >> 8) == 0x8e)
        return 1;
      return 2;
    }
  }
  return chartab[c & 0xff] & CT_CELL_MASK;
}

/*
 * Return number of display cells occupied by character at "*p".
 * A TAB is counted as two cells: "^I" or four: "<09>".
 */
int ptr2cells(char_u *p)
{
  /* For UTF-8 we need to look at more bytes if the first byte is >= 0x80. */
  if (enc_utf8 && *p >= 0x80)
    return utf_ptr2cells(p);
  /* For DBCS we can tell the cell count from the first byte. */
  return chartab[*p] & CT_CELL_MASK;
}

/*
 * Return the number of character cells string "s" will take on the screen,
 * counting TABs as two characters: "^I".
 *
 * 's' must be non-null.
 */
int vim_strsize(char_u *s)
{
  return vim_strnsize(s, (int)MAXCOL);
}

/*
 * Return the number of character cells string "s[len]" will take on the
 * screen, counting TABs as two characters: "^I".
 *
 * 's' must be non-null.
 */
int vim_strnsize(char_u *s, int len)
{
  assert(s);
  int size = 0;

  while (*s != NUL && --len >= 0) {
    if (has_mbyte) {
      int l = (*mb_ptr2len)(s);

      size += ptr2cells(s);
      s += l;
      len -= l - 1;
    } else
      size += byte2cells(*s++);
  }
  return size;
}

/*
 * Return the number of characters 'c' will take on the screen, taking
 * into account the size of a tab.
 * Use a define to make it fast, this is used very often!!!
 * Also see getvcol() below.
 */

#define RET_WIN_BUF_CHARTABSIZE(wp, buf, p, col) \
  if (*(p) == TAB && (!(wp)->w_p_list || lcs_tab1)) \
  { \
    int ts; \
    ts = (buf)->b_p_ts; \
    return (int)(ts - (col % ts)); \
  } \
  else \
    return ptr2cells(p);

#if defined(FEAT_VREPLACE) || defined(FEAT_EX_EXTRA) || defined(FEAT_GUI) \
  || defined(FEAT_VIRTUALEDIT) || defined(PROTO)
int chartabsize(char_u *p, colnr_T col)
{
  RET_WIN_BUF_CHARTABSIZE(curwin, curbuf, p, col)
}
#endif

static int win_chartabsize(win_T *wp, char_u *p, colnr_T col)
{
  RET_WIN_BUF_CHARTABSIZE(wp, wp->w_buffer, p, col)
}

/*
 * Return the number of characters the string 's' will take on the screen,
 * taking into account the size of a tab.
 */
int linetabsize(char_u *s)
{
  return linetabsize_col(0, s);
}

/*
 * Like linetabsize(), but starting at column "startcol".
 */
int linetabsize_col(int startcol, char_u *s)
{
  colnr_T col = startcol;

  while (*s != NUL)
    col += lbr_chartabsize_adv(&s, col);
  return (int)col;
}

/*
 * Like linetabsize(), but for a given window instead of the current one.
 */
int win_linetabsize(win_T *wp, char_u *p, colnr_T len)
{
  colnr_T col = 0;
  char_u      *s;

  for (s = p; *s != NUL && (len == MAXCOL || s < p + len); mb_ptr_adv(s))
    col += win_lbr_chartabsize(wp, s, col, NULL);
  return (int)col;
}

/*
 * Return TRUE if 'c' is a normal identifier character:
 * Letters and characters from the 'isident' option.
 */
int vim_isIDc(int c)
{
  return c > 0 && c < 0x100 && (chartab[c] & CT_ID_CHAR);
}

/*
 * return TRUE if 'c' is a keyword character: Letters and characters from
 * 'iskeyword' option for current buffer.
 * For multi-byte characters mb_get_class() is used (builtin rules).
 */
int vim_iswordc(int c)
{
  return vim_iswordc_buf(c, curbuf);
}

int vim_iswordc_buf(int c, buf_T *buf)
{
  if (c >= 0x100) {
    if (enc_dbcs != 0)
      return dbcs_class((unsigned)c >> 8, (unsigned)(c & 0xff)) >= 2;
    if (enc_utf8)
      return utf_class(c) >= 2;
  }
  return c > 0 && c < 0x100 && GET_CHARTAB(buf, c) != 0;
}

/*
 * Just like vim_iswordc() but uses a pointer to the (multi-byte) character.
 */
int vim_iswordp(char_u *p)
{
  if (has_mbyte && MB_BYTE2LEN(*p) > 1)
    return mb_get_class(p) >= 2;
  return GET_CHARTAB(curbuf, *p) != 0;
}

int vim_iswordp_buf(char_u *p, buf_T *buf)
{
  if (has_mbyte && MB_BYTE2LEN(*p) > 1)
    return mb_get_class(p) >= 2;
  return GET_CHARTAB(buf, *p) != 0;
}

/*
 * return TRUE if 'c' is a valid file-name character
 * Assume characters above 0x100 are valid (multi-byte).
 */
int vim_isfilec(int c)
{
  return c >= 0x100 || (c > 0 && (chartab[c] & CT_FNAME_CHAR));
}

/*
 * return TRUE if 'c' is a valid file-name character or a wildcard character
 * Assume characters above 0x100 are valid (multi-byte).
 * Explicitly interpret ']' as a wildcard character as mch_has_wildcard("]")
 * returns false.
 */
int vim_isfilec_or_wc(int c)
{
  char_u buf[2];

  buf[0] = (char_u)c;
  buf[1] = NUL;
  return vim_isfilec(c) || c == ']' || mch_has_wildcard(buf);
}

/*
 * return TRUE if 'c' is a printable character
 * Assume characters above 0x100 are printable (multi-byte), except for
 * Unicode.
 */
int vim_isprintc(int c)
{
  if (enc_utf8 && c >= 0x100)
    return utf_printable(c);
  return c >= 0x100 || (c > 0 && (chartab[c] & CT_PRINT_CHAR));
}

/*
 * Strict version of vim_isprintc(c), don't return TRUE if "c" is the head
 * byte of a double-byte character.
 */
int vim_isprintc_strict(int c)
{
  if (enc_dbcs != 0 && c < 0x100 && MB_BYTE2LEN(c) > 1)
    return FALSE;
  if (enc_utf8 && c >= 0x100)
    return utf_printable(c);
  return c >= 0x100 || (c > 0 && (chartab[c] & CT_PRINT_CHAR));
}

/*
 * like chartabsize(), but also check for line breaks on the screen
 */
int lbr_chartabsize(unsigned char *s, colnr_T col)
{
  if (!curwin->w_p_lbr && *p_sbr == NUL) {
    if (curwin->w_p_wrap)
      return win_nolbr_chartabsize(curwin, s, col, NULL);
    RET_WIN_BUF_CHARTABSIZE(curwin, curbuf, s, col)
  }
  return win_lbr_chartabsize(curwin, s, col, NULL);
}

/*
 * Call lbr_chartabsize() and advance the pointer.
 */
int lbr_chartabsize_adv(char_u **s, colnr_T col)
{
  int retval;

  retval = lbr_chartabsize(*s, col);
  mb_ptr_adv(*s);
  return retval;
}

/*
 * This function is used very often, keep it fast!!!!
 *
 * If "headp" not NULL, set *headp to the size of what we for 'showbreak'
 * string at start of line.  Warning: *headp is only set if it's a non-zero
 * value, init to 0 before calling.
 */
int win_lbr_chartabsize(win_T *wp, char_u *s, colnr_T col, int *headp)
{
  int c;
  int size;
  colnr_T col2;
  colnr_T colmax;
  int added;
  int mb_added = 0;
  int numberextra;
  char_u      *ps;
  int tab_corr = (*s == TAB);
  int n;

  /*
   * No 'linebreak' and 'showbreak': return quickly.
   */
  if (!wp->w_p_lbr && *p_sbr == NUL) {
    if (wp->w_p_wrap)
      return win_nolbr_chartabsize(wp, s, col, headp);
    RET_WIN_BUF_CHARTABSIZE(wp, wp->w_buffer, s, col)
  }

  /*
   * First get normal size, without 'linebreak'
   */
  size = win_chartabsize(wp, s, col);
  c = *s;

  /*
   * If 'linebreak' set check at a blank before a non-blank if the line
   * needs a break here
   */
  if (wp->w_p_lbr
      && vim_isbreak(c)
      && !vim_isbreak(s[1])
      && !wp->w_p_list
      && wp->w_p_wrap
      && wp->w_width != 0
      ) {
    /*
     * Count all characters from first non-blank after a blank up to next
     * non-blank after a blank.
     */
    numberextra = win_col_off(wp);
    col2 = col;
    colmax = (colnr_T)(W_WIDTH(wp) - numberextra);
    if (col >= colmax) {
      n = colmax + win_col_off2(wp);
      if (n > 0)
        colmax += (((col - colmax) / n) + 1) * n;
    }

    for (;; ) {
      ps = s;
      mb_ptr_adv(s);
      c = *s;
      if (!(c != NUL
            && (vim_isbreak(c)
                || (!vim_isbreak(c)
                    && (col2 == col || !vim_isbreak(*ps))))))
        break;

      col2 += win_chartabsize(wp, s, col2);
      if (col2 >= colmax) {             /* doesn't fit */
        size = colmax - col;
        tab_corr = FALSE;
        break;
      }
    }
  } else if (has_mbyte && size == 2 && MB_BYTE2LEN(*s) > 1
             && wp->w_p_wrap && in_win_border(wp, col)) {
    ++size;             /* Count the ">" in the last column. */
    mb_added = 1;
  }

  /*
   * May have to add something for 'showbreak' string at start of line
   * Set *headp to the size of what we add.
   */
  added = 0;
  if (*p_sbr != NUL && wp->w_p_wrap && col != 0) {
    numberextra = win_col_off(wp);
    col += numberextra + mb_added;
    if (col >= (colnr_T)W_WIDTH(wp)) {
      col -= W_WIDTH(wp);
      numberextra = W_WIDTH(wp) - (numberextra - win_col_off2(wp));
      if (numberextra > 0)
        col = col % numberextra;
    }
    if (col == 0 || col + size > (colnr_T)W_WIDTH(wp)) {
      added = vim_strsize(p_sbr);
      if (tab_corr)
        size += (added / wp->w_buffer->b_p_ts) * wp->w_buffer->b_p_ts;
      else
        size += added;
      if (col != 0)
        added = 0;
    }
  }
  if (headp != NULL)
    *headp = added + mb_added;
  return size;
}

/*
 * Like win_lbr_chartabsize(), except that we know 'linebreak' is off and
 * 'wrap' is on.  This means we need to check for a double-byte character that
 * doesn't fit at the end of the screen line.
 */
static int win_nolbr_chartabsize(win_T *wp, char_u *s, colnr_T col, int *headp)
{
  int n;

  if (*s == TAB && (!wp->w_p_list || lcs_tab1)) {
    n = wp->w_buffer->b_p_ts;
    return (int)(n - (col % n));
  }
  n = ptr2cells(s);
  /* Add one cell for a double-width character in the last column of the
   * window, displayed with a ">". */
  if (n == 2 && MB_BYTE2LEN(*s) > 1 && in_win_border(wp, col)) {
    if (headp != NULL)
      *headp = 1;
    return 3;
  }
  return n;
}

/*
 * Return TRUE if virtual column "vcol" is in the rightmost column of window
 * "wp".
 */
int in_win_border(win_T *wp, colnr_T vcol)
{
  int width1;                   /* width of first line (after line number) */
  int width2;                   /* width of further lines */

  if (wp->w_width == 0)         /* there is no border */
    return FALSE;
  width1 = W_WIDTH(wp) - win_col_off(wp);
  if ((int)vcol < width1 - 1)
    return FALSE;
  if ((int)vcol == width1 - 1)
    return TRUE;
  width2 = width1 + win_col_off2(wp);
  if (width2 <= 0)
    return FALSE;
  return (vcol - width1) % width2 == width2 - 1;
}

/*
 * Get virtual column number of pos.
 *  start: on the first position of this character (TAB, ctrl)
 * cursor: where the cursor is on this character (first char, except for TAB)
 *    end: on the last position of this character (TAB, ctrl)
 *
 * This is used very often, keep it fast!
 */
void getvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end)
{
  colnr_T vcol;
  char_u      *ptr;             /* points to current char */
  char_u      *posptr;          /* points to char at pos->col */
  int incr;
  int head;
  int ts = wp->w_buffer->b_p_ts;
  int c;

  vcol = 0;
  ptr = ml_get_buf(wp->w_buffer, pos->lnum, FALSE);
  if (pos->col == MAXCOL)
    posptr = NULL;      /* continue until the NUL */
  else
    posptr = ptr + pos->col;

  /*
   * This function is used very often, do some speed optimizations.
   * When 'list', 'linebreak' and 'showbreak' are not set use a simple loop.
   * Also use this when 'list' is set but tabs take their normal size.
   */
  if ((!wp->w_p_list || lcs_tab1 != NUL)
      && !wp->w_p_lbr && *p_sbr == NUL
      ) {
    for (;; ) {
      head = 0;
      c = *ptr;
      /* make sure we don't go past the end of the line */
      if (c == NUL) {
        incr = 1;               /* NUL at end of line only takes one column */
        break;
      }
      /* A tab gets expanded, depending on the current column */
      if (c == TAB)
        incr = ts - (vcol % ts);
      else {
        if (has_mbyte) {
          /* For utf-8, if the byte is >= 0x80, need to look at
           * further bytes to find the cell width. */
          if (enc_utf8 && c >= 0x80)
            incr = utf_ptr2cells(ptr);
          else
            incr = CHARSIZE(c);

          /* If a double-cell char doesn't fit at the end of a line
           * it wraps to the next line, it's like this char is three
           * cells wide. */
          if (incr == 2 && wp->w_p_wrap && MB_BYTE2LEN(*ptr) > 1
              && in_win_border(wp, vcol)) {
            ++incr;
            head = 1;
          }
        } else
          incr = CHARSIZE(c);
      }

      if (posptr != NULL && ptr >= posptr)       /* character at pos->col */
        break;

      vcol += incr;
      mb_ptr_adv(ptr);
    }
  } else   {
    for (;; ) {
      /* A tab gets expanded, depending on the current column */
      head = 0;
      incr = win_lbr_chartabsize(wp, ptr, vcol, &head);
      /* make sure we don't go past the end of the line */
      if (*ptr == NUL) {
        incr = 1;               /* NUL at end of line only takes one column */
        break;
      }

      if (posptr != NULL && ptr >= posptr)       /* character at pos->col */
        break;

      vcol += incr;
      mb_ptr_adv(ptr);
    }
  }
  if (start != NULL)
    *start = vcol + head;
  if (end != NULL)
    *end = vcol + incr - 1;
  if (cursor != NULL) {
    if (*ptr == TAB
        && (State & NORMAL)
        && !wp->w_p_list
        && !virtual_active()
        && !(VIsual_active
             && (*p_sel == 'e' || ltoreq(*pos, VIsual)))
        )
      *cursor = vcol + incr - 1;            /* cursor at end */
    else
      *cursor = vcol + head;                /* cursor at start */
  }
}

/*
 * Get virtual cursor column in the current window, pretending 'list' is off.
 */
colnr_T getvcol_nolist(pos_T *posp)
{
  int list_save = curwin->w_p_list;
  colnr_T vcol;

  curwin->w_p_list = FALSE;
  getvcol(curwin, posp, NULL, &vcol, NULL);
  curwin->w_p_list = list_save;
  return vcol;
}

/*
 * Get virtual column in virtual mode.
 */
void getvvcol(win_T *wp, pos_T *pos, colnr_T *start, colnr_T *cursor, colnr_T *end)
{
  colnr_T col;
  colnr_T coladd;
  colnr_T endadd;
  char_u      *ptr;

  if (virtual_active()) {
    /* For virtual mode, only want one value */
    getvcol(wp, pos, &col, NULL, NULL);

    coladd = pos->coladd;
    endadd = 0;
    /* Cannot put the cursor on part of a wide character. */
    ptr = ml_get_buf(wp->w_buffer, pos->lnum, FALSE);
    if (pos->col < (colnr_T)STRLEN(ptr)) {
      int c = (*mb_ptr2char)(ptr + pos->col);

      if (c != TAB && vim_isprintc(c)) {
        endadd = (colnr_T)(char2cells(c) - 1);
        if (coladd > endadd)            /* past end of line */
          endadd = 0;
        else
          coladd = 0;
      }
    }
    col += coladd;
    if (start != NULL)
      *start = col;
    if (cursor != NULL)
      *cursor = col;
    if (end != NULL)
      *end = col + endadd;
  } else
    getvcol(wp, pos, start, cursor, end);
}

/*
 * Get the leftmost and rightmost virtual column of pos1 and pos2.
 * Used for Visual block mode.
 */
void getvcols(win_T *wp, pos_T *pos1, pos_T *pos2, colnr_T *left, colnr_T *right)
{
  colnr_T from1, from2, to1, to2;

  if (ltp(pos1, pos2)) {
    getvvcol(wp, pos1, &from1, NULL, &to1);
    getvvcol(wp, pos2, &from2, NULL, &to2);
  } else   {
    getvvcol(wp, pos2, &from1, NULL, &to1);
    getvvcol(wp, pos1, &from2, NULL, &to2);
  }
  if (from2 < from1)
    *left = from2;
  else
    *left = from1;
  if (to2 > to1) {
    if (*p_sel == 'e' && from2 - 1 >= to1)
      *right = from2 - 1;
    else
      *right = to2;
  } else
    *right = to1;
}

/*
 * skipwhite: skip over ' ' and '\t'.
 */
char_u *skipwhite(char_u *q)
{
  char_u      *p = q;

  while (vim_iswhite(*p))   /* skip to next non-white */
    ++p;
  return p;
}

/*
 * skip over digits
 */
char_u *skipdigits(char_u *q)
{
  char_u      *p = q;

  while (VIM_ISDIGIT(*p))       /* skip to next non-digit */
    ++p;
  return p;
}

/*
 * skip over digits and hex characters
 */
char_u *skiphex(char_u *q)
{
  char_u      *p = q;

  while (vim_isxdigit(*p))      /* skip to next non-digit */
    ++p;
  return p;
}

/*
 * skip to digit (or NUL after the string)
 */
char_u *skiptodigit(char_u *q)
{
  char_u      *p = q;

  while (*p != NUL && !VIM_ISDIGIT(*p))         /* skip to next digit */
    ++p;
  return p;
}

/*
 * skip to hex character (or NUL after the string)
 */
char_u *skiptohex(char_u *q)
{
  char_u      *p = q;

  while (*p != NUL && !vim_isxdigit(*p))        /* skip to next digit */
    ++p;
  return p;
}

/*
 * Variant of isdigit() that can handle characters > 0x100.
 * We don't use isdigit() here, because on some systems it also considers
 * superscript 1 to be a digit.
 * Use the VIM_ISDIGIT() macro for simple arguments.
 */
int vim_isdigit(int c)
{
  return c >= '0' && c <= '9';
}

/*
 * Variant of isxdigit() that can handle characters > 0x100.
 * We don't use isxdigit() here, because on some systems it also considers
 * superscript 1 to be a digit.
 */
int vim_isxdigit(int c)
{
  return (c >= '0' && c <= '9')
         || (c >= 'a' && c <= 'f')
         || (c >= 'A' && c <= 'F');
}

/*
 * Vim's own character class functions.  These exist because many library
 * islower()/toupper() etc. do not work properly: they crash when used with
 * invalid values or can't handle latin1 when the locale is C.
 * Speed is most important here.
 */
#define LATIN1LOWER 'l'
#define LATIN1UPPER 'U'

static char_u latin1flags[257] =
  "                                                                 UUUUUUUUUUUUUUUUUUUUUUUUUU      llllllllllllllllllllllllll                                                                     UUUUUUUUUUUUUUUUUUUUUUU UUUUUUUllllllllllllllllllllllll llllllll";
static char_u latin1upper[257] =
  "                                 !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`ABCDEFGHIJKLMNOPQRSTUVWXYZ{|}~\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xf7\xd8\xd9\xda\xdb\xdc\xdd\xde\xff";
static char_u latin1lower[257] =
  "                                 !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xd7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff";

int vim_islower(int c)
{
  if (c <= '@')
    return FALSE;
  if (c >= 0x80) {
    if (enc_utf8)
      return utf_islower(c);
    if (c >= 0x100) {
#ifdef HAVE_ISWLOWER
      if (has_mbyte)
        return iswlower(c);
#endif
      /* islower() can't handle these chars and may crash */
      return FALSE;
    }
    if (enc_latin1like)
      return (latin1flags[c] & LATIN1LOWER) == LATIN1LOWER;
  }
  return islower(c);
}

int vim_isupper(int c)
{
  if (c <= '@')
    return FALSE;
  if (c >= 0x80) {
    if (enc_utf8)
      return utf_isupper(c);
    if (c >= 0x100) {
#ifdef HAVE_ISWUPPER
      if (has_mbyte)
        return iswupper(c);
#endif
      /* islower() can't handle these chars and may crash */
      return FALSE;
    }
    if (enc_latin1like)
      return (latin1flags[c] & LATIN1UPPER) == LATIN1UPPER;
  }
  return isupper(c);
}

int vim_toupper(int c)
{
  if (c <= '@')
    return c;
  if (c >= 0x80) {
    if (enc_utf8)
      return utf_toupper(c);
    if (c >= 0x100) {
#ifdef HAVE_TOWUPPER
      if (has_mbyte)
        return towupper(c);
#endif
      /* toupper() can't handle these chars and may crash */
      return c;
    }
    if (enc_latin1like)
      return latin1upper[c];
  }
  return TOUPPER_LOC(c);
}

int vim_tolower(int c)
{
  if (c <= '@')
    return c;
  if (c >= 0x80) {
    if (enc_utf8)
      return utf_tolower(c);
    if (c >= 0x100) {
#ifdef HAVE_TOWLOWER
      if (has_mbyte)
        return towlower(c);
#endif
      /* tolower() can't handle these chars and may crash */
      return c;
    }
    if (enc_latin1like)
      return latin1lower[c];
  }
  return TOLOWER_LOC(c);
}

/*
 * skiptowhite: skip over text until ' ' or '\t' or NUL.
 */
char_u *skiptowhite(char_u *p)
{
  while (*p != ' ' && *p != '\t' && *p != NUL)
    ++p;
  return p;
}

#if defined(FEAT_LISTCMDS) || defined(FEAT_SIGNS) || defined(FEAT_SNIFF) \
  || defined(PROTO)
/*
 * skiptowhite_esc: Like skiptowhite(), but also skip escaped chars
 */
char_u *skiptowhite_esc(char_u *p)
{
  while (*p != ' ' && *p != '\t' && *p != NUL) {
    if ((*p == '\\' || *p == Ctrl_V) && *(p + 1) != NUL)
      ++p;
    ++p;
  }
  return p;
}
#endif

/*
 * Getdigits: Get a number from a string and skip over it.
 * Note: the argument is a pointer to a char_u pointer!
 */
long getdigits(char_u **pp)
{
  char_u      *p;
  long retval;

  p = *pp;
  retval = atol((char *)p);
  if (*p == '-')                /* skip negative sign */
    ++p;
  p = skipdigits(p);            /* skip to next non-digit */
  *pp = p;
  return retval;
}

/*
 * Return TRUE if "lbuf" is empty or only contains blanks.
 */
int vim_isblankline(char_u *lbuf)
{
  char_u      *p;

  p = skipwhite(lbuf);
  return *p == NUL || *p == '\r' || *p == '\n';
}

/*
 * Convert a string into a long and/or unsigned long, taking care of
 * hexadecimal and octal numbers.  Accepts a '-' sign.
 * If "hexp" is not NULL, returns a flag to indicate the type of the number:
 *  0	    decimal
 *  '0'	    octal
 *  'X'	    hex
 *  'x'	    hex
 * If "len" is not NULL, the length of the number in characters is returned.
 * If "nptr" is not NULL, the signed result is returned in it.
 * If "unptr" is not NULL, the unsigned result is returned in it.
 * If "dooct" is non-zero recognize octal numbers, when > 1 always assume
 * octal number.
 * If "dohex" is non-zero recognize hex numbers, when > 1 always assume
 * hex number.
 */
void 
vim_str2nr (
    char_u *start,
    int *hexp,          /* return: type of number 0 = decimal, 'x'
                                       or 'X' is hex, '0' = octal */
    int *len,           /* return: detected length of number */
    int dooct,                          /* recognize octal number */
    int dohex,                          /* recognize hex number */
    long *nptr,          /* return: signed result */
    unsigned long *unptr         /* return: unsigned result */
)
{
  char_u          *ptr = start;
  int hex = 0;                          /* default is decimal */
  int negative = FALSE;
  unsigned long un = 0;
  int n;

  if (ptr[0] == '-') {
    negative = TRUE;
    ++ptr;
  }

  /* Recognize hex and octal. */
  if (ptr[0] == '0' && ptr[1] != '8' && ptr[1] != '9') {
    hex = ptr[1];
    if (dohex && (hex == 'X' || hex == 'x') && vim_isxdigit(ptr[2]))
      ptr += 2;                         /* hexadecimal */
    else {
      hex = 0;                          /* default is decimal */
      if (dooct) {
        /* Don't interpret "0", "08" or "0129" as octal. */
        for (n = 1; VIM_ISDIGIT(ptr[n]); ++n) {
          if (ptr[n] > '7') {
            hex = 0;                    /* can't be octal */
            break;
          }
          if (ptr[n] >= '0')
            hex = '0';                  /* assume octal */
        }
      }
    }
  }

  /*
   * Do the string-to-numeric conversion "manually" to avoid sscanf quirks.
   */
  if (hex == '0' || dooct > 1) {
    /* octal */
    while ('0' <= *ptr && *ptr <= '7') {
      un = 8 * un + (unsigned long)(*ptr - '0');
      ++ptr;
    }
  } else if (hex != 0 || dohex > 1)   {
    /* hex */
    while (vim_isxdigit(*ptr)) {
      un = 16 * un + (unsigned long)hex2nr(*ptr);
      ++ptr;
    }
  } else   {
    /* decimal */
    while (VIM_ISDIGIT(*ptr)) {
      un = 10 * un + (unsigned long)(*ptr - '0');
      ++ptr;
    }
  }

  if (hexp != NULL)
    *hexp = hex;
  if (len != NULL)
    *len = (int)(ptr - start);
  if (nptr != NULL) {
    if (negative)       /* account for leading '-' for decimal numbers */
      *nptr = -(long)un;
    else
      *nptr = (long)un;
  }
  if (unptr != NULL)
    *unptr = un;
}

/*
 * Return the value of a single hex character.
 * Only valid when the argument is '0' - '9', 'A' - 'F' or 'a' - 'f'.
 */
int hex2nr(int c)
{
  if (c >= 'a' && c <= 'f')
    return c - 'a' + 10;
  if (c >= 'A' && c <= 'F')
    return c - 'A' + 10;
  return c - '0';
}

#if defined(FEAT_TERMRESPONSE) \
  || (defined(FEAT_GUI_GTK) && defined(FEAT_WINDOWS)) || defined(PROTO)
/*
 * Convert two hex characters to a byte.
 * Return -1 if one of the characters is not hex.
 */
int hexhex2nr(char_u *p)
{
  if (!vim_isxdigit(p[0]) || !vim_isxdigit(p[1]))
    return -1;
  return (hex2nr(p[0]) << 4) + hex2nr(p[1]);
}
#endif

/*
 * Return TRUE if "str" starts with a backslash that should be removed.
 * For MS-DOS, WIN32 and OS/2 this is only done when the character after the
 * backslash is not a normal file name character.
 * '$' is a valid file name character, we don't remove the backslash before
 * it.  This means it is not possible to use an environment variable after a
 * backslash.  "C:\$VIM\doc" is taken literally, only "$VIM\doc" works.
 * Although "\ name" is valid, the backslash in "Program\ files" must be
 * removed.  Assume a file name doesn't start with a space.
 * For multi-byte names, never remove a backslash before a non-ascii
 * character, assume that all multi-byte characters are valid file name
 * characters.
 */
int rem_backslash(char_u *str)
{
#ifdef BACKSLASH_IN_FILENAME
  return str[0] == '\\'
         && str[1] < 0x80
         && (str[1] == ' '
             || (str[1] != NUL
                 && str[1] != '*'
                 && str[1] != '?'
                 && !vim_isfilec(str[1])));
#else
  return str[0] == '\\' && str[1] != NUL;
#endif
}

/*
 * Halve the number of backslashes in a file name argument.
 * For MS-DOS we only do this if the character after the backslash
 * is not a normal file character.
 */
void backslash_halve(char_u *p)
{
  for (; *p; ++p)
    if (rem_backslash(p))
      STRMOVE(p, p + 1);
}

/*
 * backslash_halve() plus save the result in allocated memory.
 */
char_u *backslash_halve_save(char_u *p)
{
  char_u      *res;

  res = vim_strsave(p);
  if (res == NULL)
    return p;
  backslash_halve(res);
  return res;
}

