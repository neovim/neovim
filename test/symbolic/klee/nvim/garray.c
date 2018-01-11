// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file garray.c
///
/// Functions for handling growing arrays.

#include <string.h>
#include <inttypes.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/log.h"
#include "nvim/memory.h"
#include "nvim/path.h"
#include "nvim/garray.h"
#include "nvim/strings.h"

// #include "nvim/globals.h"
#include "nvim/memline.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "garray.c.generated.h"
#endif

/// Clear an allocated growing array.
void ga_clear(garray_T *gap)
{
  xfree(gap->ga_data);

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
  GA_DEEP_CLEAR_PTR(gap);
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
  ga_set_growsize(gap, growsize);
}

/// A setter for the growsize that guarantees it will be at least 1.
///
/// @param gap
/// @param growsize
void ga_set_growsize(garray_T *gap, int growsize)
{
  if (growsize < 1) {
    WLOG("trying to set an invalid ga_growsize: %d", growsize);
    gap->ga_growsize = 1;
  } else {
    gap->ga_growsize = growsize;
  }
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

  if (gap->ga_growsize < 1) {
    WLOG("ga_growsize(%d) is less than 1", gap->ga_growsize);
  }

  // the garray grows by at least growsize
  if (n < gap->ga_growsize) {
    n = gap->ga_growsize;
  }
  int new_maxlen = gap->ga_len + n;

  size_t new_size = (size_t)(gap->ga_itemsize * new_maxlen);
  size_t old_size = (size_t)(gap->ga_itemsize * gap->ga_maxlen);

  // reallocate and clear the new memory
  char *pp = xrealloc(gap->ga_data, new_size);
  memset(pp + old_size, 0, new_size - old_size);

  gap->ga_maxlen = new_maxlen;
  gap->ga_data = pp;
}

/// For a growing array that contains a list of strings: concatenate all the
/// strings with sep as separator.
///
/// @param gap
/// @param sep
///
/// @returns the concatenated strings
char_u *ga_concat_strings_sep(const garray_T *gap, const char *sep)
  FUNC_ATTR_NONNULL_RET
{
  const size_t nelem = (size_t) gap->ga_len;
  const char **strings = gap->ga_data;

  if (nelem == 0) {
    return (char_u *) xstrdup("");
  }

  size_t len = 0;
  for (size_t i = 0; i < nelem; i++) {
    len += strlen(strings[i]);
  }

  // add some space for the (num - 1) separators
  len += (nelem - 1) * strlen(sep);
  char *const ret = xmallocz(len);

  char *s = ret;
  for (size_t i = 0; i < nelem - 1; i++) {
    s = xstpcpy(s, strings[i]);
    s = xstpcpy(s, sep);
  }
  strcpy(s, strings[nelem - 1]);

  return (char_u *) ret;
}

/// For a growing array that contains a list of strings: concatenate all the
/// strings with a separating comma.
///
/// @param gap
///
/// @returns the concatenated strings
char_u* ga_concat_strings(const garray_T *gap) FUNC_ATTR_NONNULL_RET
{
  return ga_concat_strings_sep(gap, ",");
}

/// Concatenate a string to a growarray which contains characters.
/// When "s" is NULL does not do anything.
///
/// WARNING:
/// - Does NOT copy the NUL at the end!
/// - The parameter may not overlap with the growing array
///
/// @param gap
/// @param s
void ga_concat(garray_T *gap, const char_u *restrict s)
{
  if (s == NULL) {
    return;
  }

  ga_concat_len(gap, (const char *restrict) s, strlen((char *) s));
}

/// Concatenate a string to a growarray which contains characters
///
/// @param[out]  gap  Growarray to modify.
/// @param[in]  s  String to concatenate.
/// @param[in]  len  String length.
void ga_concat_len(garray_T *const gap, const char *restrict s,
                   const size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  if (len) {
    ga_grow(gap, (int) len);
    char *data = gap->ga_data;
    memcpy(data + gap->ga_len, s, len);
    gap->ga_len += (int) len;
  }
}

/// Append one byte to a growarray which contains bytes.
///
/// @param gap
/// @param c
void ga_append(garray_T *gap, char c)
{
  GA_APPEND(char, gap, c);
}

