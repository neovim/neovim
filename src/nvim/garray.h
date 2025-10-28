#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/memory.h"

#define GA_EMPTY(ga_ptr) ((ga_ptr)->ga_len <= 0)

#define GA_APPEND(item_type, gap, item) \
  do { \
    ga_grow(gap, 1); \
    ((item_type *)(gap)->ga_data)[(gap)->ga_len] = (item); \
    (gap)->ga_len++; \
  } while (0)

#define GA_APPEND_VIA_PTR(item_type, gap) \
  ga_append_via_ptr(gap, sizeof(item_type))

#include "garray.h.generated.h"

/// Deep free a garray of specific type using a custom free function.
/// Items in the array as well as the array itself are freed.
///
/// @param gap the garray to be freed
/// @param item_type type of the item in the garray
/// @param free_item_fn free function that takes (item_type *) as parameter
#define GA_DEEP_CLEAR(gap, item_type, free_item_fn) \
  do { \
    garray_T *_gap = (gap); \
    if (_gap->ga_data != NULL) { \
      for (int i = 0; i < _gap->ga_len; i++) { \
        item_type *_item = &(((item_type *)_gap->ga_data)[i]); \
        free_item_fn(_item); \
      } \
    } \
    ga_clear(_gap); \
  } while (false)

#define FREE_PTR_PTR(ptr) xfree(*(ptr))

/// Call `free` for every pointer stored in the garray and then frees the
/// garray.
///
/// @param gap the garray to be freed
#define GA_DEEP_CLEAR_PTR(gap) GA_DEEP_CLEAR(gap, void *, FREE_PTR_PTR)
