#include "nvim/ascii.h"
#include "nvim/globals.h"
#include "nvim/mbyte.h"
#include "nvim/types.h"
#include "nvim/vim.h"

void dbcs_init_mb_bytelen_tab(uint8_t table[256])
{
  for (size_t i = 0; i < 256; i++) {
    char buf[MB_MAXBYTES + 1];
    uint8_t n;
    if (i == NUL)             /* just in case mblen() can't handle "" */
      n = 1;
    else {
      buf[0] = i;
      buf[1] = 0;
#ifdef LEN_FROM_CONV
      if (vimconv.vc_type != CONV_NONE) {
        /*
         * string_convert() should fail when converting the first
         * byte of a double-byte character.
         */
        char_u *p = string_convert(&vimconv, (char_u *)buf, NULL);
        if (p != NULL) {
          xfree(p);
          n = 1;
        } else
          n = 2;
      } else
#endif
      {
        /*
         * mblen() should return -1 for invalid (means the leading
         * multibyte) character.  However there are some platforms
         * where mblen() returns 0 for invalid character.
         * Therefore, following condition includes 0.
         */
        ignored = mblen(NULL, 0);             /* First reset the state. */
        if (mblen(buf, (size_t)1) <= 0)
          n = 2;
        else
          n = 1;
      }
    }

    table[i] = n;
  }
}

/*
 * mb_char2len() function pointer.
 * Return length in bytes of character "c".
 * Returns 1 for a single-byte character.
 */
int dbcs_char2len(int c)
{
  if (c >= 0x100)
    return 2;
  return 1;
}

/*
 * mb_char2bytes() function pointer.
 * Convert a character to its bytes.
 * Returns the length in bytes.
 */
int dbcs_char2bytes(int c, char_u *buf)
{
  if (c >= 0x100) {
    buf[0] = (unsigned)c >> 8;
    buf[1] = c;
    /* Never use a NUL byte, it causes lots of trouble.  It's an invalid
     * character anyway. */
    if (buf[1] == NUL)
      buf[1] = '\n';
    return 2;
  }
  buf[0] = c;
  return 1;
}

/*
 * mb_ptr2len() function pointer.
 * Get byte length of character at "*p" but stop at a NUL.
 * For UTF-8 this includes following composing characters.
 * Returns 0 when *p is NUL.
 */
int dbcs_ptr2len(const char_u *p)
{
  int len;

  /* Check if second byte is not missing. */
  len = MB_BYTE2LEN(*p);
  if (len == 2 && p[1] == NUL)
    len = 1;
  return len;
}

/*
 * mb_ptr2len_len() function pointer.
 * Like mb_ptr2len(), but limit to read "size" bytes.
 * Returns 0 for an empty string.
 * Returns 1 for an illegal char or an incomplete byte sequence.
 */
int dbcs_ptr2len_len(const char_u *p, int size)
{
  int len;

  if (size < 1 || *p == NUL)
    return 0;
  if (size == 1)
    return 1;
  /* Check that second byte is not missing. */
  len = MB_BYTE2LEN(*p);
  if (len == 2 && p[1] == NUL)
    len = 1;
  return len;
}

/*
 * mb_ptr2cells() function pointer.
 * Return the number of display cells character at "*p" occupies.
 * This doesn't take care of unprintable characters, use ptr2cells() for that.
 */
int dbcs_ptr2cells(const char_u *p)
{
  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (enc_dbcs == DBCS_JPNU && *p == 0x8e)
    return 1;
  return MB_BYTE2LEN(*p);
}

/*
 * mb_ptr2cells_len() function pointer.
 * Like mb_ptr2cells(), but limit string length to "size".
 * For an empty string or truncated character returns 1.
 */
int dbcs_ptr2cells_len(const char_u *p, int size)
{
  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (size <= 1 || (enc_dbcs == DBCS_JPNU && *p == 0x8e))
    return 1;
  return MB_BYTE2LEN(*p);
}

/*
 * mb_char2cells() function pointer.
 * Return the number of display cells character "c" occupies.
 * Only takes care of multi-byte chars, not "^C" and such.
 */
int dbcs_char2cells(int c)
{
  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (enc_dbcs == DBCS_JPNU && ((unsigned)c >> 8) == 0x8e)
    return 1;
  /* use the first byte */
  return MB_BYTE2LEN((unsigned)c >> 8);
}

/*
 * mb_off2cells() function pointer.
 * Return number of display cells for char at ScreenLines[off].
 * We make sure that the offset used is less than "max_off".
 */
int dbcs_off2cells(unsigned off, unsigned max_off)
{
  /* never check beyond end of the line */
  if (off >= max_off)
    return 1;

  /* Number of cells is equal to number of bytes, except for euc-jp when
   * the first byte is 0x8e. */
  if (enc_dbcs == DBCS_JPNU && ScreenLines[off] == 0x8e)
    return 1;
  return MB_BYTE2LEN(ScreenLines[off]);
}

/*
 * mb_ptr2char() function pointer.
 * Convert a byte sequence into a character.
 */
int dbcs_ptr2char(const char_u *p)
{
  if (MB_BYTE2LEN(*p) > 1 && p[1] != NUL)
    return (p[0] << 8) + p[1];
  return *p;
}

/*
 * mb_head_off() function pointer.
 * Return offset from "p" to the first byte of the character it points into.
 * If "p" points to the NUL at the end of the string return 0.
 * Returns 0 when already at the first byte of a character.
 */
int dbcs_head_off(const char_u *base, const char_u *p)
{
  /* It can't be a trailing byte when not using DBCS, at the start of the
   * string or the previous byte can't start a double-byte. */
  if (p <= base || MB_BYTE2LEN(p[-1]) == 1 || *p == NUL) {
    return 0;
  }

  /* This is slow: need to start at the base and go forward until the
   * byte we are looking for.  Return 1 when we went past it, 0 otherwise. */
  const char_u *q = base;
  while (q < p) {
    q += dbcs_ptr2len(q);
  }

  return (q == p) ? 0 : 1;
}

/*
 * Special version of dbcs_head_off() that works for ScreenLines[], where
 * single-width DBCS_JPNU characters are stored separately.
 */
int dbcs_screen_head_off(const char_u *base, const char_u *p)
{
  /* It can't be a trailing byte when not using DBCS, at the start of the
   * string or the previous byte can't start a double-byte.
   * For euc-jp an 0x8e byte in the previous cell always means we have a
   * lead byte in the current cell. */
  if (p <= base
      || (enc_dbcs == DBCS_JPNU && p[-1] == 0x8e)
      || MB_BYTE2LEN(p[-1]) == 1
      || *p == NUL)
    return 0;

  /* This is slow: need to start at the base and go forward until the
   * byte we are looking for.  Return 1 when we went past it, 0 otherwise.
   * For DBCS_JPNU look out for 0x8e, which means the second byte is not
   * stored as the next byte. */
  const char_u *q = base;
  while (q < p) {
    if (enc_dbcs == DBCS_JPNU && *q == 0x8e) {
      ++q;
    }
    else {
      q += dbcs_ptr2len(q);
    }
  }

  return (q == p) ? 0 : 1;
}

