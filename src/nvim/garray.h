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

#define GA_EMPTY(ga_ptr) ((ga_ptr)->ga_len <= 0)

#define GA_APPEND(item_type, gap, item)                                    \
  do {                                                                     \
    ga_grow(gap, 1);                                                       \
    ((item_type *)(gap)->ga_data)[(gap)->ga_len++] = (item);               \
  } while (0)

#define GA_APPEND_VIA_PTR(item_type, gap) \
  ga_append_via_ptr(gap, sizeof(item_type))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "garray.h.generated.h"
#endif

static inline void *ga_append_via_ptr(garray_T *gap, size_t item_size)
{
  if ((int)item_size != gap->ga_itemsize) {
    ELOG("wrong item size in garray(%d), should be %d", item_size);
  }
  ga_grow(gap, 1);
  return ((char *)gap->ga_data) + (item_size * (size_t)gap->ga_len++);
}

#endif  // NVIM_GARRAY_H
