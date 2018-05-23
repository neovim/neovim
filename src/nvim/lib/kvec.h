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
#define KVI_INITIAL_VALUE(v) { \
    .size = 0, \
    .capacity = ARRAY_SIZE((v).init_array), \
    .items = (v).init_array \
  }

#define kvec_t(type) \
    struct { \
      size_t size; \
      size_t capacity; \
      type *items; \
    }

#define kv_init(v) ((v).size = (v).capacity = 0, (v).items = 0)
#define kv_destroy(v) xfree((v).items)
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

/// Resize vector when it is full
///
/// @param[out]  v  Vector to resize.
#define kv_resize_full(v) \
    kv_resize(v, (v).capacity ? (v).capacity << 1 : 8)

/// Copy one vector into another
///
/// @warning Works only on vectors of the same item type, use kv or kvi variant
///          of macros depending on destination vector.
///
/// @param  pref  Prefix: kv or kvi. Selects type of the destination vector to
///               use.
/// @param[out]  dv  Destination vector.
/// @param[in]  sv  Source vector.
#define _kv_copy(pref, v1, v0) \
    do { \
      if ((v1).capacity < (v0).size) { \
        pref##_resize(v1, (v0).size); \
      } \
      (v1).size = (v0).size; \
      memcpy((v1).items, (v0).items, sizeof((v1).items[0]) * (v0).size); \
    } while (0)

/// Copy one vector into another
///
/// @warning Works only on vectors of the same item type, use kv or kvi variant
///          of macros depending on destination vector.
///
/// @param[out]  dv  Destination vector.
/// @param[in]  sv  Source vector.
#define kv_copy(v1, v0) _kv_copy(kv, v1, v0)

/// Make space for one more item if there is no
///
/// @param  pref  Prefix: kv or kvi. Selects type of the vector to use.
/// @param  v  Vector to resize.
#define _kv_makespaceforone(pref, v) \
    (((v).size == (v).capacity) ? (pref##_resize_full(v), 0) : 0)

/// Get push pointer: pointer to the destination item
///
/// Increases vector size if necessary. Does not initialize new element.
///
/// @param  pref  Prefix: kv or kvi. Selects type of the vector to use.
/// @param  v  Vector to push to.
#define _kv_pushp(pref, v) \
    (_kv_makespaceforone(pref, v), \
     ((v).items + ((v).size++)))

/// Get push pointer: pointer to the destination item
///
/// Increases vector size if necessary. Does not initialize new element.
///
/// @param  v  Vector to push to.
#define kv_pushp(v) _kv_pushp(kv, v)

#define kv_push(v, x) \
    (*kv_pushp(v) = (x))

/// Resize vector with rounding
///
/// @param  pref  Prefix: kv or kvi. Selects type of the vector to use.
/// @param[out]  v  Vector to resize.
/// @param[in]  s  New size (not rounded).
#define _kv_resize_round(pref, v, s) \
    ((v).capacity = (s), \
     kv_roundup32((v).capacity), \
     pref##_resize((v), (v).capacity))

/// Resize vector with rounding
///
/// @param[out]  v  Vector to resize.
/// @param[in]  s  New size (not rounded).
#define kv_resize_round(v, s) _kv_resize_round(kv, v, s)

#define kv_a(v, i) \
    (((v).capacity <= (size_t) (i) \
      ? ((v).size = (i) + 1, \
         kv_resize_round(v, (v).size), 0) \
      : ((v).size <= (size_t) (i) \
         ? (v).size = (i) + 1 \
         : 0)), \
     (v).items[(i)])

/// Shrink vector by removing some of the elements in the middle or at the end
///
/// Does not do resizing though.
///
/// @param[out]  v  Vector to modify.
/// @param[in]  idx  First element to remove.
/// @param[in]  len  Number of items to remove. `idx + len` must be less
///                  or equal to #kv_size.
#define kv_shrink(v, idx, len) \
    (kv_memmove(v, idx, (idx) + (len), kv_size(v) - (idx) - (len)), \
     (v).size -= (len))

/// Expand vector by moving some of the elements further
///
/// @param  pref  Prefix: kv or kvi. Selects type of the vector to use.
/// @param[out]  v  Vector to modify.
/// @param[in]  idx  Where to create the gap.
/// @param[in]  len  How many new elements to create.
#define _kv_expand(pref, v, idx, len) \
    (pref##_resize_round(v, kv_size(v) + len), \
     kv_memmove(v, idx + len, idx, kv_size(v) - idx), \
     (v).size += len)

/// Expand vector by moving some of the elements further
///
/// @param[out]  v  Vector to modify.
/// @param[in]  idx  Where to create the gap.
/// @param[in]  len  How many new elements to create.
#define kv_expand(v, idx, len) _kv_expand(kv, v, idx, len)

/// Insert entry at the start or to the middle of the vector
///
/// @param  pref  Prefix: kv or kvi. Selects type of the vector to use.
/// @param[out]  v  Vector to modify.
/// @param[in]  idx  Index of element to insert.
/// @param[in]  x  Entry to insert.
#define _kv_insert(pref, v, idx, x) \
    (_kv_makespaceforone(pref, v), \
     kv_memmove(v, (idx) + 1, idx, kv_size(v) - (idx)), \
     kv_A(v, (idx)) = (x), \
     (v).size++)

/// Insert entry at the start or to the middle of the vector
///
/// @param[out]  v  Vector to modify.
/// @param[in]  idx  Index of element to insert.
/// @param[in]  x  Entry to insert.
#define kv_insert(v, idx, x) _kv_insert(kv, v, idx, x)

/// Copy part of one vector to another vector
///
/// Unsafe, does not do resizing or moving existing vector elements around.
///
/// @param[out]  dv  Vector to copy to.
/// @param[in]  sv  Vector to copy from.
/// @param[in]  di  Index to copy to.
/// @param[in]  si  Index to copy from.
/// @param[in]  s  Number of elements to copy.
#define kv_memcpy(dv, sv, di, si, s) \
    memcpy((dv).items + (di), (sv).items + (si), sizeof((dv).items[0]) * (s))

/// Copy part of one vector onto itself
///
/// Unsafe, does not do resizing or moving existing vector elements around.
///
/// @param[out]  v  Vector to work with.
/// @param[in]  di  Index to copy to.
/// @param[in]  si  Index to copy from.
/// @param[in]  s  Number of elements to move.
#define kv_memmove(v, di, si, s) \
    memmove((v).items + (di), (v).items + (si), sizeof((v).items[0]) * (s))

/// Type of a vector with a few first members allocated on stack
///
/// Is compatible with #kv_A, #kv_pop, #kv_size, #kv_max, #kv_last,
/// #kv_shrink, #kv_memcpy.
/// Is not compatible with #kv_resize, #kv_resize_full, #kv_copy, #kv_push,
/// #kv_pushp, #kv_a, #kv_destroy, #kv_insert, #kv_expand, #kv_resize_round.
///
/// It is essential that references to vectors with the same type, but different
/// sizes are compatible as long as they are not resized.
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

/// Initialize vector with preallocated array
///
/// @param[out]  v  Vector to initialize.
#define kvi_init(v) \
    ((v).capacity = ARRAY_SIZE((v).init_array), \
     (v).size = 0, \
     (v).items = (v).init_array)

/// Move data to a new destination and free source
static inline void *_memcpy_free(void *const restrict dest,
                                 void *const restrict src,
                                 const size_t size)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_NONNULL_RET FUNC_ATTR_ALWAYS_INLINE
{
  memcpy(dest, src, size);
  xfree(src);
  return dest;
}

// -V:kvi_push:512

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

/// Get location where to store new element to a vector with preallocated array
///
/// @param[in,out]  v  Vector to push to.
///
/// @return Pointer to the place where new value should be stored.
#define kvi_pushp(v) _kv_pushp(kvi, v)

/// Push value to a vector with preallocated array
///
/// @param[out]  v  Vector to push to.
/// @param[in]  x  Value to push.
#define kvi_push(v, x) \
    (*kvi_pushp(v) = (x))

/// Free array of elements of a vector with preallocated array if needed
///
/// @param[out]  v  Vector to free.
#define kvi_destroy(v) \
    do { \
      if ((v).items != (v).init_array) { \
        xfree((v).items); \
      } \
    } while (0)

/// Copy one vector into another
///
/// @warning Works only on vectors of the same item type, use kv or kvi variant
///          of macros depending on destination vector.
///
/// @param[out]  dv  Destination vector.
/// @param[in]  sv  Source vector.
#define kvi_copy(dv, sv) _kv_copy(kvi, dv, sv)

/// Resize vector with rounding
///
/// @param[out]  v  Vector to resize.
/// @param[in]  s  New size (not rounded).
#define kvi_resize_round(v, s) _kv_resize_round(kvi, v, s)

/// Expand vector by moving some of the elements further
///
/// @param[out]  v  Vector to modify.
/// @param[in]  idx  Where to create the gap.
/// @param[in]  len  How many new elements to create.
#define kvi_expand(v, idx, len) _kv_expand(kvi, v, idx, len)

/// Insert entry at the start or to the middle of the vector
///
/// @param[out]  v  Vector to modify.
/// @param[in]  idx  Index of element to insert.
/// @param[in]  x  Entry to insert.
#define kvi_insert(v, idx, x) _kv_insert(kvi, v, idx, x)

#endif  // NVIM_LIB_KVEC_H
