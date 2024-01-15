#pragma once

#include <stddef.h>

/// Structure used for growing arrays.
/// This is used to store information that only grows, is deleted all at
/// once, and needs to be accessed by index.  See ga_clear() and ga_grow().
typedef struct {
  int ga_len;                       // current number of items used
  int ga_maxlen;                    // maximum number of items possible
  int ga_itemsize;                  // sizeof(item)
  int ga_growsize;                  // number of items to grow each time
  void *ga_data;                    // pointer to the first item
} garray_T;

#define GA_EMPTY_INIT_VALUE { 0, 0, 0, 1, NULL }
#define GA_INIT(itemsize, growsize) { 0, 0, (itemsize), (growsize), NULL }
