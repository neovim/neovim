#include "nvim/ascii.h"
#include "nvim/globals.h"
#include "nvim/mbyte.h"
#include "nvim/types.h"

void latin_init_mb_bytelen_tab(uint8_t table[256]) {
    for (size_t i = 0; i < 256; ++i) {
        table[i] = 1;
    }
}

/*
 * mb_char2len() function pointer.
 * Return length in bytes of character "c".
 * Returns 1 for a single-byte character.
 */
int latin_char2len(int c)
{
  return 1;
}

/*
 * mb_char2bytes() function pointer.
 * Convert a character to its bytes.
 * Returns the length in bytes.
 */
int latin_char2bytes(int c, char_u *buf)
{
  buf[0] = c;
  return 1;
}

/*
 * mb_ptr2len() function pointer.
 * Get byte length of character at "*p" but stop at a NUL.
 * For UTF-8 this includes following composing characters.
 * Returns 0 when *p is NUL.
 */
int latin_ptr2len(const char_u *p)
{
  return MB_BYTE2LEN(*p);
}

/*
 * mb_ptr2len_len() function pointer.
 * Like mb_ptr2len(), but limit to read "size" bytes.
 * Returns 0 for an empty string.
 * Returns 1 for an illegal char or an incomplete byte sequence.
 */
int latin_ptr2len_len(const char_u *p, int size)
{
  if (size < 1 || *p == NUL)
    return 0;
  return 1;
}

/*
 * mb_ptr2cells() function pointer.
 * Return the number of display cells character at "*p" occupies.
 * This doesn't take care of unprintable characters, use ptr2cells() for that.
 */
int latin_ptr2cells(const char_u *p)
{
  return 1;
}

/*
 * mb_ptr2cells_len() function pointer.
 * Like mb_ptr2cells(), but limit string length to "size".
 * For an empty string or truncated character returns 1.
 */
int latin_ptr2cells_len(const char_u *p, int size)
{
  return 1;
}

/*
 * mb_char2cells() function pointer.
 * Return the number of display cells character "c" occupies.
 * Only takes care of multi-byte chars, not "^C" and such.
 */
int latin_char2cells(int c)
{
  return 1;
}

/*
 * mb_off2cells() function pointer.
 * Return number of display cells for char at ScreenLines[off].
 * We make sure that the offset used is less than "max_off".
 */
int latin_off2cells(unsigned off, unsigned max_off)
{
  return 1;
}

/*
 * mb_ptr2char() function pointer.
 * Convert a byte sequence into a character.
 */
int latin_ptr2char(const char_u *p)
{
  return *p;
}

/*
 * mb_head_off() function pointer.
 * Return offset from "p" to the first byte of the character it points into.
 * If "p" points to the NUL at the end of the string return 0.
 * Returns 0 when already at the first byte of a character.
 */
int latin_head_off(const char_u *base, const char_u *p)
{
  return 0;
}

