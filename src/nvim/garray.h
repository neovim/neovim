#ifndef NVIM_GARRAY_H
#define NVIM_GARRAY_H

#include <stddef.h>  // for size_t

#include "nvim/types.h"  // for char_u
#include "nvim/log.h"

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

#define GA_EMPTY_INIT_VALUE { 0, 0, 0, 1, NULL }
#define GA_INIT(itemsize, growsize) { 0, 0, (itemsize), (growsize), NULL }

#define GA_EMPTY(ga_ptr) ((ga_ptr)->ga_len <= 0)

#define GA_APPEND(item_type, gap, item) \
  do { \
    ga_grow(gap, 1); \
    ((item_type *)(gap)->ga_data)[(gap)->ga_len++] = (item); \
  } while (0)

#define GA_APPEND_VIA_PTR(item_type, gap) \
  ga_append_via_ptr(gap, sizeof(item_type))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "garray.h.generated.h"
#endif

static inline void *ga_append_via_ptr(garray_T *gap, size_t item_size)
{
  if ((int)item_size != gap->ga_itemsize) {
    WLOG("wrong item size (%zu), should be %d", item_size, gap->ga_itemsize);
  }
  ga_grow(gap, 1);
  return ((char *)gap->ga_data) + (item_size * (size_t)gap->ga_len++);
}

/// Deep free a garray of specific type using a custom free function.
/// Items in the array as well as the array itself are freed.
///
/// @param gap the garray to be freed
/// @param item_type type of the item in the garray
/// @param free_item_fn free function that takes (*item_type) as parameter
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
#define GA_DEEP_CLEAR_PTR(gap) GA_DEEP_CLEAR(gap, void*, FREE_PTR_PTR)

#endif  // NVIM_GARRAY_H
