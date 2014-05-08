#ifndef NVIM_GARRAY_H
#define NVIM_GARRAY_H

#include "nvim/func_attr.h"

/// Structure used for growing arrays.
/// This is used to store information that only grows, is deleted all at
/// once, and needs to be accessed by index.  See ga_clear() and ga_grow().
typedef struct growarray {
  int ga_len;                       // current number of items used
  int ga_maxlen;                    // maximum number of items possible
  int ga_itemsize;                  // sizeof(item)
  int ga_growsize;                  // number of items to grow each time
  void *ga_data;                    // pointer to the first item
} garray_T;

#define GA_EMPTY_INIT_VALUE { 0, 0, 0, 0, NULL }

#define GA_EMPTY(ga_ptr) ((ga_ptr)->ga_len <= 0)

void ga_clear(garray_T *gap);
void ga_clear_strings(garray_T *gap);
void ga_init(garray_T *gap, int itemsize, int growsize);
void ga_grow(garray_T *gap, int n);
char_u *ga_concat_strings_sep(const garray_T *gap, const char *sep)
  FUNC_ATTR_NONNULL_RET;
char_u *ga_concat_strings(const garray_T *gap) FUNC_ATTR_NONNULL_RET;
void ga_remove_duplicate_strings(garray_T *gap);
void ga_concat(garray_T *gap, const char_u *restrict s);
void ga_append(garray_T *gap, char c);
void append_ga_line(garray_T *gap);

#endif  // NVIM_GARRAY_H
