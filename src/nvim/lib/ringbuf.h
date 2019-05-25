/// Macros-based ring buffer implementation.
///
/// Supported functions:
///
/// - new: allocates new ring buffer.
/// - dealloc: free ring buffer itself.
/// - free: free ring buffer and all its elements.
/// - push: adds element to the end of the buffer.
/// - length: get buffer length.
/// - size: size of the ring buffer.
/// - idx: get element at given index.
/// - idx_p: get pointer to the element at given index.
/// - insert: insert element at given position.
/// - remove: remove element from given position.
#ifndef NVIM_LIB_RINGBUF_H
#define NVIM_LIB_RINGBUF_H

#include <stddef.h>
#include <string.h>
#include <assert.h>
#include <stdint.h>

#include "nvim/memory.h"
#include "nvim/func_attr.h"

#define _RINGBUF_LENGTH(rb) \
    ((rb)->first == NULL ? 0 \
     : ((rb)->next == (rb)->first) ? (size_t) ((rb)->buf_end - (rb)->buf) + 1 \
     : ((rb)->next > (rb)->first) ? (size_t) ((rb)->next - (rb)->first) \
     : (size_t) ((rb)->next - (rb)->buf + (rb)->buf_end - (rb)->first + 1))

#define _RINGBUF_NEXT(rb, var) \
    ((var) == (rb)->buf_end ? (rb)->buf : (var) + 1)
#define _RINGBUF_PREV(rb, var) \
    ((var) == (rb)->buf ? (rb)->buf_end : (var) - 1)

/// Iterate over all ringbuf values
///
/// @param  rb       Ring buffer to iterate over.
/// @param  RBType   Type of the ring buffer element.
/// @param  varname  Variable name.
#define RINGBUF_FORALL(rb, RBType, varname) \
    size_t varname##_length_fa_ = _RINGBUF_LENGTH(rb); \
    for (RBType *varname = ((rb)->first == NULL ? (rb)->next : (rb)->first); \
         varname##_length_fa_; \
         (varname = _RINGBUF_NEXT(rb, varname)), \
         varname##_length_fa_--)

/// Iterate over all ringbuf values, from end to the beginning
///
/// Unlike previous RINGBUF_FORALL uses already defined variable, in place of
/// defining variable in the cycle body.
///
/// @param  rb       Ring buffer to iterate over.
/// @param  RBType   Type of the ring buffer element.
/// @param  varname  Variable name.
#define RINGBUF_ITER_BACK(rb, RBType, varname) \
    size_t varname##_length_ib_ = _RINGBUF_LENGTH(rb); \
    for (varname = ((rb)->next == (rb)->buf ? (rb)->buf_end : (rb)->next - 1); \
         varname##_length_ib_; \
         (varname = _RINGBUF_PREV(rb, varname)), \
         varname##_length_ib_--)

/// Define a ring buffer structure
///
/// @param TypeName    Ring buffer type name. Actual type name will be
///                    `{TypeName}RingBuffer`.
/// @param RBType      Type of the single ring buffer element.
#define RINGBUF_TYPEDEF(TypeName, RBType) \
typedef struct { \
  RBType *buf; \
  RBType *next; \
  RBType *first; \
  RBType *buf_end; \
} TypeName##RingBuffer;

/// Dummy item free macros, for use in RINGBUF_INIT
///
/// This macros actually does nothing.
///
/// @param[in]  item  Item to be freed.
#define RINGBUF_DUMMY_FREE(item)

/// Static ring buffer
///
/// @warning Ring buffers created with this macros must neither be freed nor
///          deallocated.
///
/// @param  scope  Ring buffer scope.
/// @param  TypeName  Ring buffer type name.
/// @param  RBType  Type of the single ring buffer element.
/// @param  varname  Variable name.
/// @param  rbsize  Ring buffer size.
#define RINGBUF_STATIC(scope, TypeName, RBType, varname, rbsize) \
static RBType _##varname##_buf[rbsize]; \
scope TypeName##RingBuffer varname = { \
  .buf = _##varname##_buf, \
  .next = _##varname##_buf, \
  .first = NULL, \
  .buf_end = _##varname##_buf + rbsize - 1, \
};

/// Initialize a new ring buffer
///
/// @param TypeName    Ring buffer type name. Actual type name will be
///                    `{TypeName}RingBuffer`.
/// @param funcprefix  Prefix for all ring buffer functions. Function name will
///                    look like `{funcprefix}_rb_{function_name}`.
/// @param RBType      Type of the single ring buffer element.
/// @param rbfree      Function used to free ring buffer element. May be
///                    a macros like `#define RBFREE(item)` (to skip freeing).
///
///                    Intended function signature: `void *rbfree(RBType *)`;
#define RINGBUF_INIT(TypeName, funcprefix, RBType, rbfree) \
static inline TypeName##RingBuffer funcprefix##_rb_new(const size_t size) \
  REAL_FATTR_WARN_UNUSED_RESULT; \
static inline TypeName##RingBuffer funcprefix##_rb_new(const size_t size) \
{ \
  assert(size != 0); \
  RBType *buf = xmalloc(size * sizeof(RBType)); \
  return (TypeName##RingBuffer) { \
    .buf = buf, \
    .next = buf, \
    .first = NULL, \
    .buf_end = buf + size - 1, \
  }; \
} \
\
static inline void funcprefix##_rb_free(TypeName##RingBuffer *const rb) \
  REAL_FATTR_UNUSED; \
static inline void funcprefix##_rb_free(TypeName##RingBuffer *const rb) \
{ \
  if (rb == NULL) { \
    return; \
  } \
  RINGBUF_FORALL(rb, RBType, rbitem) { \
    rbfree(rbitem); \
  } \
  XFREE_CLEAR(rb->buf); \
} \
\
static inline void funcprefix##_rb_dealloc(TypeName##RingBuffer *const rb) \
  REAL_FATTR_UNUSED; \
static inline void funcprefix##_rb_dealloc(TypeName##RingBuffer *const rb) \
{ \
  XFREE_CLEAR(rb->buf); \
} \
\
static inline void funcprefix##_rb_push(TypeName##RingBuffer *const rb, \
                                        RBType item) \
  REAL_FATTR_NONNULL_ARG(1); \
static inline void funcprefix##_rb_push(TypeName##RingBuffer *const rb, \
                                        RBType item) \
{ \
  if (rb->next == rb->first) { \
    rbfree(rb->first); \
    rb->first = _RINGBUF_NEXT(rb, rb->first); \
  } else if (rb->first == NULL) { \
    rb->first = rb->next; \
  } \
  *rb->next = item; \
  rb->next = _RINGBUF_NEXT(rb, rb->next); \
} \
\
static inline ptrdiff_t funcprefix##_rb_find_idx( \
    const TypeName##RingBuffer *const rb, const RBType *const item_p) \
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE REAL_FATTR_UNUSED; \
static inline ptrdiff_t funcprefix##_rb_find_idx( \
    const TypeName##RingBuffer *const rb, const RBType *const item_p) \
{ \
  assert(rb->buf <= item_p); \
  assert(rb->buf_end >= item_p); \
  if (rb->first == NULL) { \
    return -1; \
  } else if (item_p >= rb->first) { \
    return item_p - rb->first; \
  } else { \
    return item_p - rb->buf + rb->buf_end - rb->first + 1; \
  } \
} \
\
static inline size_t funcprefix##_rb_size( \
    const TypeName##RingBuffer *const rb) \
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE; \
static inline size_t funcprefix##_rb_size( \
    const TypeName##RingBuffer *const rb) \
{ \
  return (size_t) (rb->buf_end - rb->buf) + 1; \
} \
\
static inline size_t funcprefix##_rb_length( \
    const TypeName##RingBuffer *const rb) \
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE; \
static inline size_t funcprefix##_rb_length( \
    const TypeName##RingBuffer *const rb) \
{ \
  return _RINGBUF_LENGTH(rb); \
} \
\
static inline RBType *funcprefix##_rb_idx_p( \
    const TypeName##RingBuffer *const rb, const size_t idx) \
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE; \
static inline RBType *funcprefix##_rb_idx_p( \
    const TypeName##RingBuffer *const rb, const size_t idx) \
{ \
  assert(idx <= funcprefix##_rb_size(rb)); \
  assert(idx <= funcprefix##_rb_length(rb)); \
  if (rb->first + idx > rb->buf_end) { \
    return rb->buf + ((rb->first + idx) - (rb->buf_end + 1)); \
  } else { \
    return rb->first + idx; \
  } \
} \
\
static inline RBType funcprefix##_rb_idx(const TypeName##RingBuffer *const rb, \
                                         const size_t idx) \
  REAL_FATTR_NONNULL_ALL REAL_FATTR_PURE REAL_FATTR_UNUSED; \
static inline RBType funcprefix##_rb_idx(const TypeName##RingBuffer *const rb, \
                                         const size_t idx) \
{ \
  return *funcprefix##_rb_idx_p(rb, idx); \
} \
\
static inline void funcprefix##_rb_insert(TypeName##RingBuffer *const rb, \
                                          const size_t idx, \
                                          RBType item) \
  REAL_FATTR_NONNULL_ARG(1) REAL_FATTR_UNUSED; \
static inline void funcprefix##_rb_insert(TypeName##RingBuffer *const rb, \
                                          const size_t idx, \
                                          RBType item) \
{ \
  assert(idx <= funcprefix##_rb_size(rb)); \
  assert(idx <= funcprefix##_rb_length(rb)); \
  const size_t length = funcprefix##_rb_length(rb); \
  if (idx == length) { \
    funcprefix##_rb_push(rb, item); \
    return; \
  } \
  RBType *const insertpos = funcprefix##_rb_idx_p(rb, idx); \
  if (insertpos == rb->next) { \
    funcprefix##_rb_push(rb, item); \
    return; \
  } \
  if (length == funcprefix##_rb_size(rb)) { \
    rbfree(rb->first); \
  } \
  if (insertpos < rb->next) { \
    memmove(insertpos + 1, insertpos, \
            (size_t) ((uintptr_t) rb->next - (uintptr_t) insertpos)); \
  } else { \
    assert(insertpos > rb->first); \
    assert(rb->next <= rb->first); \
    memmove(rb->buf + 1, rb->buf, \
            (size_t) ((uintptr_t) rb->next - (uintptr_t) rb->buf)); \
    *rb->buf = *rb->buf_end; \
    memmove(insertpos + 1, insertpos, \
            (size_t) ((uintptr_t) (rb->buf_end + 1) - (uintptr_t) insertpos)); \
  } \
  *insertpos = item; \
  if (length == funcprefix##_rb_size(rb)) { \
    rb->first = _RINGBUF_NEXT(rb, rb->first); \
  } \
  rb->next = _RINGBUF_NEXT(rb, rb->next); \
} \
\
static inline void funcprefix##_rb_remove(TypeName##RingBuffer *const rb, \
                                          const size_t idx) \
  REAL_FATTR_NONNULL_ARG(1) REAL_FATTR_UNUSED; \
static inline void funcprefix##_rb_remove(TypeName##RingBuffer *const rb, \
                                          const size_t idx) \
{ \
  assert(idx < funcprefix##_rb_size(rb)); \
  assert(idx < funcprefix##_rb_length(rb)); \
  RBType *const rmpos = funcprefix##_rb_idx_p(rb, idx); \
  rbfree(rmpos); \
  if (rmpos == rb->next - 1) { \
    rb->next--; \
    if (rb->first == rb->next) { \
      rb->first = NULL; \
      rb->next = rb->buf; \
    } \
  } else if (rmpos == rb->first) { \
    rb->first = _RINGBUF_NEXT(rb, rb->first); \
    if (rb->first == rb->next) { \
      rb->first = NULL; \
      rb->next = rb->buf; \
    } \
  } else if (rb->first < rb->next || rb->next == rb->buf) { \
    assert(rmpos > rb->first); \
    assert(rmpos <= _RINGBUF_PREV(rb, rb->next)); \
    memmove(rb->first + 1, rb->first, \
            (size_t) ((uintptr_t) rmpos - (uintptr_t) rb->first)); \
    rb->first = _RINGBUF_NEXT(rb, rb->first); \
  } else if (rmpos < rb->next) { \
    memmove(rmpos, rmpos + 1, \
            (size_t) ((uintptr_t) rb->next - (uintptr_t) rmpos)); \
    rb->next = _RINGBUF_PREV(rb, rb->next); \
  } else { \
    assert(rb->first < rb->buf_end); \
    memmove(rb->first + 1, rb->first, \
            (size_t) ((uintptr_t) rmpos - (uintptr_t) rb->first)); \
    rb->first = _RINGBUF_NEXT(rb, rb->first); \
  } \
}

#endif  // NVIM_LIB_RINGBUF_H
