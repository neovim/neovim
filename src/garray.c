/// @file garray.c
///
/// Functions for handling growing arrays.

#include <string.h>

#include "vim.h"
#include "ascii.h"
#include "misc2.h"
#include "memory.h"
#include "path.h"
#include "garray.h"

// #include "globals.h"
#include "memline.h"

/// Clear an allocated growing array.
void ga_clear(garray_T *gap)
{
  vim_free(gap->ga_data);

  // Initialize growing array without resetting itemsize or growsize
  gap->ga_data = NULL;
  gap->ga_maxlen = 0;
  gap->ga_len = 0;
}

/// Clear a growing array that contains a list of strings.
///
/// @param gap
void ga_clear_strings(garray_T *gap)
{
  int i;
  for (i = 0; i < gap->ga_len; ++i) {
    vim_free(((char_u **)(gap->ga_data))[i]);
  }
  ga_clear(gap);
}

/// Initialize a growing array.
///
/// @param gap
/// @param itemsize
/// @param growsize
void ga_init(garray_T *gap, int itemsize, int growsize)
{
  gap->ga_data = NULL;
  gap->ga_maxlen = 0;
  gap->ga_len = 0;
  gap->ga_itemsize = itemsize;
  gap->ga_growsize = growsize;
}

/// Make room in growing array "gap" for at least "n" items.
///
/// @param gap
/// @param n
void ga_grow(garray_T *gap, int n)
{
  if (gap->ga_maxlen - gap->ga_len >= n) {
    // the garray still has enough space, do nothing
    return;
  }

  // the garray grows by at least growsize (do we have a MIN macro somewhere?)
  n = (n < gap->ga_growsize) ? gap->ga_growsize : n;

  size_t new_size = (size_t)(gap->ga_itemsize * (gap->ga_len + n));
  size_t old_size = (size_t)(gap->ga_itemsize * gap->ga_maxlen);

  // reallocate and clear the new memory
  char_u *pp = xrealloc(gap->ga_data, new_size);
  memset(pp + old_size, 0, new_size - old_size);

  gap->ga_maxlen = gap->ga_len + n;
  gap->ga_data = pp;
}

/// Sort "gap" and remove duplicate entries.  "gap" is expected to contain a
/// list of file names in allocated memory.
///
/// @param gap
void ga_remove_duplicate_strings(garray_T *gap)
{
  int i;
  int j;
  char_u  **fnames = (char_u **)gap->ga_data;

  sort_strings(fnames, gap->ga_len);
  for (i = gap->ga_len - 1; i > 0; --i)
    if (fnamecmp(fnames[i - 1], fnames[i]) == 0) {
      vim_free(fnames[i]);
      for (j = i + 1; j < gap->ga_len; ++j)
        fnames[j - 1] = fnames[j];
      --gap->ga_len;
    }
}

/// For a growing array that contains a list of strings: concatenate all the
/// strings with a separating comma.
///
/// @param gap
///
/// @returns the concatenated strings
char_u* ga_concat_strings(garray_T *gap)
{
  size_t len = 0;

  for (int i = 0; i < gap->ga_len; ++i) {
    len += strlen(((char **)(gap->ga_data))[i]) + 1;
  }

  char *s = xmallocz(len);

  *s = NUL;
  for (int i = 0; i < gap->ga_len; ++i) {
    if (*s != NUL) {
      strcat(s, ",");
    }
    strcat(s, ((char **)(gap->ga_data))[i]);
  }

  return (char_u *)s;
}

/// Concatenate a string to a growarray which contains characters.
/// Note: Does NOT copy the NUL at the end!
///
/// @param gap
/// @param s
void ga_concat(garray_T *gap, char_u *s)
{
  int len = (int)STRLEN(s);
  ga_grow(gap, len);
  memmove((char *)gap->ga_data + gap->ga_len, s, (size_t)len);
  gap->ga_len += len;
}

/// Append one byte to a growarray which contains bytes.
///
/// @param gap
/// @param c
void ga_append(garray_T *gap, char c)
{
  ga_grow(gap, 1);
  *((char *)gap->ga_data + gap->ga_len) = c;
  ++gap->ga_len;
}

#if defined(UNIX) || defined(WIN3264)

/// Append the text in "gap" below the cursor line and clear "gap".
///
/// @param gap
void append_ga_line(garray_T *gap)
{
  // Remove trailing CR.
  if ((gap->ga_len > 0)
      && !curbuf->b_p_bin
      && (((char_u *)gap->ga_data)[gap->ga_len - 1] == CAR)) {
    gap->ga_len--;
  }
  ga_append(gap, NUL);
  ml_append(curwin->w_cursor.lnum++, gap->ga_data, 0, FALSE);
  gap->ga_len = 0;
}

#endif  // if defined(UNIX) || defined(WIN3264)
