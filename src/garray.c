/*
 * Functions for handling growing arrays.
 */

#include "vim.h"
#include "ascii.h"
#include "misc2.h"
#include "garray.h"
//#include "globals.h"
#include "memline.h"

/*
 * Clear an allocated growing array.
 */
void ga_clear(garray_T *gap)
{
  vim_free(gap->ga_data);
  ga_init(gap);
}

/*
 * Clear a growing array that contains a list of strings.
 */
void ga_clear_strings(garray_T *gap)
{
  int i;

  for (i = 0; i < gap->ga_len; ++i)
    vim_free(((char_u **)(gap->ga_data))[i]);
  ga_clear(gap);
}

/*
 * Initialize a growing array.	Don't forget to set ga_itemsize and
 * ga_growsize!  Or use ga_init2().
 */
void ga_init(garray_T *gap)
{
  gap->ga_data = NULL;
  gap->ga_maxlen = 0;
  gap->ga_len = 0;
}

void ga_init2(garray_T *gap, int itemsize, int growsize)
{
  ga_init(gap);
  gap->ga_itemsize = itemsize;
  gap->ga_growsize = growsize;
}

/*
 * Make room in growing array "gap" for at least "n" items.
 * Return FAIL for failure, OK otherwise.
 */
int ga_grow(garray_T *gap, int n)
{
  size_t old_len;
  size_t new_len;
  char_u      *pp;

  if (gap->ga_maxlen - gap->ga_len < n) {
    if (n < gap->ga_growsize)
      n = gap->ga_growsize;
    new_len = gap->ga_itemsize * (gap->ga_len + n);
    pp = (gap->ga_data == NULL)
         ? alloc((unsigned)new_len) : vim_realloc(gap->ga_data, new_len);
    if (pp == NULL)
      return FAIL;
    old_len = gap->ga_itemsize * gap->ga_maxlen;
    vim_memset(pp + old_len, 0, new_len - old_len);
    gap->ga_maxlen = gap->ga_len + n;
    gap->ga_data = pp;
  }
  return OK;
}

/*
 * For a growing array that contains a list of strings: concatenate all the
 * strings with a separating comma.
 * Returns NULL when out of memory.
 */
char_u *ga_concat_strings(garray_T *gap)
{
  int i;
  int len = 0;
  char_u      *s;

  for (i = 0; i < gap->ga_len; ++i)
    len += (int)STRLEN(((char_u **)(gap->ga_data))[i]) + 1;

  s = alloc(len + 1);
  if (s != NULL) {
    *s = NUL;
    for (i = 0; i < gap->ga_len; ++i) {
      if (*s != NUL)
        STRCAT(s, ",");
      STRCAT(s, ((char_u **)(gap->ga_data))[i]);
    }
  }
  return s;
}

/*
 * Concatenate a string to a growarray which contains characters.
 * Note: Does NOT copy the NUL at the end!
 */
void ga_concat(garray_T *gap, char_u *s)
{
  int len = (int)STRLEN(s);

  if (ga_grow(gap, len) == OK) {
    mch_memmove((char *)gap->ga_data + gap->ga_len, s, (size_t)len);
    gap->ga_len += len;
  }
}

/*
 * Append one byte to a growarray which contains bytes.
 */
void ga_append(garray_T *gap, int c)
{
  if (ga_grow(gap, 1) == OK) {
    *((char *)gap->ga_data + gap->ga_len) = c;
    ++gap->ga_len;
  }
}

#if defined(UNIX) || defined(WIN3264)
/*
 * Append the text in "gap" below the cursor line and clear "gap".
 */
void append_ga_line(garray_T *gap)
{
  /* Remove trailing CR. */
  if (gap->ga_len > 0
      && !curbuf->b_p_bin
      && ((char_u *)gap->ga_data)[gap->ga_len - 1] == CAR)
    --gap->ga_len;
  ga_append(gap, NUL);
  ml_append(curwin->w_cursor.lnum++, gap->ga_data, 0, FALSE);
  gap->ga_len = 0;
}
#endif

