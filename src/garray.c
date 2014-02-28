/**
 * Functions for handling growing arrays.
 */
#include <assert.h>

#include "vim.h"
#include "ascii.h"
#include "misc2.h"
#include "garray.h"
#include "memline.h"

/**
 * Clear an allocated growing array.
 *
 * The allocated memory will be freed, and it's size set to zero.
 * Note that this does not reset the current itemsize and growsize.
 *
 * It's bug to call this on an array that hasn't been initialized with ga_init
 * or ga_init2.
 */
void ga_clear(garray_T *gap)
{
  assert(gap);
  vim_free(gap->ga_data);
  ga_init(gap);
}

/**
 * Clear a growing array that contains a list of strings.
 *
 * It's a bug to call this function if gap isn't a list of strings.
 */
void ga_clear_strings(garray_T *gap)
{
  assert(gap);
  for (int i = 0; i < gap->ga_len; ++i)
    vim_free(((char_u **)(gap->ga_data))[i]);
  ga_clear(gap);
}

/**
 * Initialize a growing array.
 *
 * Don't forget to set ga_itemsize and ga_growsize! Or use \sa ga_init2().
 */
void ga_init(garray_T *gap)
{
  assert(gap);
  gap->ga_data   = NULL;
  gap->ga_maxlen = 0;
  gap->ga_len    = 0;
}

/**
 * Initialize a growing array.
 * */
void ga_init2(garray_T *gap, int itemsize, int growsize)
{
  assert(gap);
  ga_init(gap);
  gap->ga_itemsize = itemsize;
  gap->ga_growsize = growsize;
}

/**
 * Grow array to be able to hold at least 'n' new items.
 *
 * \returns FAIL if it fails to allocate enough memory. OK otherwise.
 */
int ga_grow(garray_T *gap, int n)
{
  assert(gap);
  assert(n >= 0);

  if (gap->ga_maxlen - gap->ga_len >= n)
    return OK; // We already have enough room

  if (n < gap->ga_growsize)
    n = gap->ga_growsize;
  size_t new_len = gap->ga_itemsize * (gap->ga_len + n);

  char_u *pp = (gap->ga_data == NULL)
       ? alloc((unsigned)new_len) : vim_realloc(gap->ga_data, new_len);
  if (!pp)
    return FAIL;

  size_t old_len = gap->ga_itemsize * gap->ga_maxlen;
  vim_memset(pp + old_len, 0, new_len - old_len);
  gap->ga_maxlen = gap->ga_len + n;
  gap->ga_data   = pp;

  return OK;
}

/**
 * Concatenate a list of strings by ","
 *
 * A rewly allocated string will be returned.
 *
 * Examples:
 *   NULL -> NULL
 *   [] -> NULL
 *   [""] -> ""
 *   ["", ""] -> ","
 *   ["a"] -> "a"
 *   ["a", "b"] -> "a,b"
 *   ["", "a", ""] -> ",a,"
 *
 * \returns NULL when out of memory, or the list was empty.
 */
char_u *ga_concat_strings(garray_T const *const gap)
{
  if (!gap || gap->ga_len == 0)
    return NULL; // nothing to do

#define GAP_STR ((char_u **)(gap->ga_data))
  int len = 0;
  for (int i = 0; i < gap->ga_len; ++i)
    len += (int)STRLEN(GAP_STR[i]);
  // make room for "," between each string.
  // -1 because we won't add a trailing "," on the last item.
  len += gap->ga_len - 1;

  char_u *s = alloc(len);
  // TODO (simensdjo): We've run out of memory, but we're not notifying anyone.
  if (!s)
    return NULL;

  *s = NUL;
  STRCAT(s, GAP_STR[0]);
  for (int i = 1; i < gap->ga_len; ++i) {
    STRCAT(s, ",");
    STRCAT(s, GAP_STR[i]);
  }
#undef GAP_STR
  return s;
}

/**
 * Concatenate a string to a growarray which contains characters.
 *
 * Note: Does NOT copy the NUL at the end!
 */
void ga_concat(garray_T *gap, char_u const *const s)
{
  assert(gap);
  int len = (int)STRLEN(s);
  if (len == 0)
    return; // nothing to do

  if (ga_grow(gap, len) == OK) {
    mch_memmove((char *)gap->ga_data + gap->ga_len, s, (size_t)len);
    gap->ga_len += len;
  }
}

/**
 * Append one byte to a growarray which contains bytes.
 */
void ga_append(garray_T *gap, int c)
{
  assert(gap);
  if (ga_grow(gap, 1) == OK) {
    *((char *)gap->ga_data + gap->ga_len) = c;
    ++gap->ga_len;
  }
}

#if (defined(UNIX) && !defined(USE_SYSTEM)) || defined(WIN3264)
/**
 * Append the text in "gap" below the cursor line.
 *
 * Note: Sets "gap" length to 0, but does not clear the associated memory
 * If gap includes a trailing CR, it will not be added to the cursor line.
 */
void append_ga_line(garray_T *gap)
{
  assert(gap);
  assert(curbuf);
  /* Remove trailing CR. */
  if (gap->ga_len > 0
      && !curbuf->b_p_bin
      && ((char_u *)gap->ga_data)[gap->ga_len - 1] == CAR)
  {
    --gap->ga_len;
  }

  ga_append(gap, NUL);
  ml_append(curwin->w_cursor.lnum++, gap->ga_data, 0, FALSE);
  gap->ga_len = 0;
}
#endif

