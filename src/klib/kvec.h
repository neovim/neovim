// The MIT License
//
// Copyright (c) 2008, by Attractive Chaos <attractor@live.co.uk>
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// An example:
//
//     #include "kvec.h"
//     int main() {
//       kvec_t(int) array = KV_INITIAL_VALUE;
//       kv_push(array, 10); // append
//       kv_a(array, 20) = 5; // dynamic
//       kv_A(array, 20) = 4; // static
//       kv_destroy(array);
//       return 0;
//     }

#ifndef NVIM_LIB_KVEC_H
#define NVIM_LIB_KVEC_H

#include <stdlib.h>
#include <string.h>

#include "nvim/memory.h"
#include "nvim/os/os_defs.h"

#define kv_roundup32(x) \
  ((--(x)), \
   ((x)|=(x)>>1, (x)|=(x)>>2, (x)|=(x)>>4, (x)|=(x)>>8, (x)|=(x)>>16), \
   (++(x)))

#define KV_INITIAL_VALUE { .size = 0, .capacity = 0, .items = NULL }

#define kvec_t(type) \
  struct { \
    size_t size; \
    size_t capacity; \
    type *items; \
  }

#define kv_init(v) ((v).size = (v).capacity = 0, (v).items = 0)
#define kv_destroy(v) \
  do { \
    xfree((v).items); \
    kv_init(v); \
  } while (0)
#define kv_A(v, i) ((v).items[(i)])
#define kv_pop(v) ((v).items[--(v).size])
#define kv_size(v) ((v).size)
#define kv_max(v) ((v).capacity)
#define kv_Z(v, i) kv_A(v, kv_size(v) - (i) - 1)
#define kv_last(v) kv_Z(v, 0)

/// Drop last n items from kvec without resizing
///
/// Previously spelled as `(void)kv_pop(v)`, repeated n times.
///
/// @param[out]  v  Kvec to drop items from.
/// @param[in]  n  Number of elements to drop.
#define kv_drop(v, n) ((v).size -= (n))

#define kv_resize(v, s) \
  ((v).capacity = (s), \
   (v).items = xrealloc((v).items, sizeof((v).items[0]) * (v).capacity))

#define kv_resize_full(v) \
  kv_resize(v, (v).capacity ? (v).capacity << 1 : 8)

#define kv_copy(v1, v0) \
  do { \
    if ((v1).capacity < (v0).size) { \
      kv_resize(v1, (v0).size); \
    } \
    (v1).size = (v0).size; \
    memcpy((v1).items, (v0).items, sizeof((v1).items[0]) * (v0).size); \
  } while (0)

/// fit at least "len" more items
#define kv_ensure_space(v, len) \
  do { \
    if ((v).capacity < (v).size + len) { \
      (v).capacity = (v).size + len; \
      kv_roundup32((v).capacity); \
      kv_resize((v), (v).capacity); \
    } \
  } while (0)

#define kv_concat_len(v, data, len) \
  if (len > 0) { \
    kv_ensure_space(v, len); \
    assert((v).items); \
    memcpy((v).items + (v).size, data, sizeof((v).items[0]) * len); \
    (v).size = (v).size + len; \
  }

#define kv_concat(v, str) kv_concat_len(v, str, strlen(str))
#define kv_splice(v1, v0) kv_concat_len(v1, (v0).items, (v0).size)

#define kv_pushp(v) \
  ((((v).size == (v).capacity) ? (kv_resize_full(v), 0) : 0), \
   ((v).items + ((v).size++)))

#define kv_push(v, x) \
  (*kv_pushp(v) = (x))

#define kv_pushp_c(v) ((v).items + ((v).size++))
#define kv_push_c(v, x) (*kv_pushp_c(v) = (x))

#define kv_a(v, i) \
  (*(((v).capacity <= (size_t)(i) \
      ? ((v).capacity = (v).size = (i) + 1, \
         kv_roundup32((v).capacity), \
         kv_resize((v), (v).capacity), 0UL) \
      : ((v).size <= (size_t)(i) \
         ? (v).size = (i) + 1 \
         : 0UL)), \
     &(v).items[(i)]))

#define kv_printf(v, ...) kv_do_printf(&(v), __VA_ARGS__)

/// Type of a vector with a few first members allocated on stack
///
/// Is compatible with #kv_A, #kv_pop, #kv_size, #kv_max, #kv_last.
/// Is not compatible with #kv_resize, #kv_resize_full, #kv_copy, #kv_push,
/// #kv_pushp, #kv_a, #kv_destroy.
///
/// @param[in]  type  Type of vector elements.
/// @param[in]  init_size  Number of the elements in the initial array.
#define kvec_withinit_t(type, INIT_SIZE) \
  struct { \
    size_t size; \
    size_t capacity; \
    type *items; \
    type init_array[INIT_SIZE]; \
  }

#define KVI_INITIAL_VALUE(v) { \
  .size = 0, \
  .capacity = ARRAY_SIZE((v).init_array), \
  .items = (v).init_array \
}

/// Initialize vector with preallocated array
///
/// @param[out]  v  Vector to initialize.
#define kvi_init(v) \
  ((v).capacity = ARRAY_SIZE((v).init_array), \
   (v).size = 0, \
   (v).items = (v).init_array)

static inline void *_memcpy_free(void *restrict dest, void *restrict src, size_t size)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_NONNULL_RET REAL_FATTR_ALWAYS_INLINE;

/// Move data to a new destination and free source
static inline void *_memcpy_free(void *const restrict dest, void *const restrict src,
                                 const size_t size)
{
  memcpy(dest, src, size);
  XFREE_CLEAR(src);
  return dest;
}

/// Resize vector with preallocated array
///
/// @note May not resize to an array smaller then init_array: if requested,
///       init_array will be used.
///
/// @param[out]  v  Vector to resize.
/// @param[in]  s  New size.
#define kvi_resize(v, s) \
  ((v).capacity = ((s) > ARRAY_SIZE((v).init_array) \
                     ? (s) \
                     : ARRAY_SIZE((v).init_array)), \
   (v).items = ((v).capacity == ARRAY_SIZE((v).init_array) \
                  ? ((v).items == (v).init_array \
                     ? (v).items \
                     : _memcpy_free((v).init_array, (v).items, \
                                    (v).size * sizeof((v).items[0]))) \
                     : ((v).items == (v).init_array \
                     ? memcpy(xmalloc((v).capacity * sizeof((v).items[0])), \
                              (v).items, \
                              (v).size * sizeof((v).items[0])) \
                     : xrealloc((v).items, \
                                (v).capacity * sizeof((v).items[0])))))

/// Resize vector with preallocated array when it is full
///
/// @param[out]  v  Vector to resize.
#define kvi_resize_full(v) \
  /* ARRAY_SIZE((v).init_array) is the minimal capacity of this vector. */ \
  /* Thus when vector is full capacity may not be zero and it is safe */ \
  /* not to bother with checking whether (v).capacity is 0. But now */ \
  /* capacity is not guaranteed to have size that is a power of 2, it is */ \
  /* hard to fix this here and is not very necessary if users will use */ \
  /* 2^x initial array size. */ \
  kvi_resize(v, (v).capacity << 1)

/// fit at least "len" more items
#define kvi_ensure_more_space(v, len) \
  do { \
    if ((v).capacity < (v).size + len) { \
      (v).capacity = (v).size + len; \
      kv_roundup32((v).capacity); \
      kvi_resize((v), (v).capacity); \
    } \
  } while (0)

#define kvi_concat_len(v, data, len) \
  if (len > 0) { \
    kvi_ensure_more_space(v, len); \
    assert((v).items); \
    memcpy((v).items + (v).size, data, sizeof((v).items[0]) * len); \
    (v).size = (v).size + len; \
  }

#define kvi_concat(v, str) kvi_concat_len(v, str, strlen(str))
#define kvi_splice(v1, v0) kvi_concat_len(v1, (v0).items, (v0).size)

/// Get location where to store new element to a vector with preallocated array
///
/// @param[in,out]  v  Vector to push to.
///
/// @return Pointer to the place where new value should be stored.
#define kvi_pushp(v) \
  ((((v).size == (v).capacity) ? (kvi_resize_full(v), 0) : 0), \
   ((v).items + ((v).size++)))

/// Push value to a vector with preallocated array
///
/// @param[out]  v  Vector to push to.
/// @param[in]  x  Value to push.
#define kvi_push(v, x) \
  (*kvi_pushp(v) = (x))

/// Copy a vector to a preallocated vector
///
/// @param[out] v1 destination
/// @param[in] v0 source (can be either vector or preallocated vector)
#define kvi_copy(v1, v0) \
    do { \
      if ((v1).capacity < (v0).size) { \
        kvi_resize(v1, (v0).size); \
      } \
      (v1).size = (v0).size; \
      memcpy((v1).items, (v0).items, sizeof((v1).items[0]) * (v0).size); \
    } while (0)

/// Free array of elements of a vector with preallocated array if needed
///
/// @param[out]  v  Vector to free.
#define kvi_destroy(v) \
  do { \
    if ((v).items != (v).init_array) { \
      XFREE_CLEAR((v).items); \
    } \
  } while (0)

#endif  // NVIM_LIB_KVEC_H
