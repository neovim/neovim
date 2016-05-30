// Copyright (c) 2013, Ben Noordhuis <info@bnoordhuis.nl>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

#ifndef NVIM_LIB_QUEUE_H
#define NVIM_LIB_QUEUE_H

#include <stddef.h>

#include "nvim/func_attr.h"

typedef struct _queue {
  struct _queue *next;
  struct _queue *prev;
} QUEUE;

// Private macros.
#define _QUEUE_NEXT(q)       ((q)->next)
#define _QUEUE_PREV(q)       ((q)->prev)
#define _QUEUE_PREV_NEXT(q)  (_QUEUE_NEXT(_QUEUE_PREV(q)))
#define _QUEUE_NEXT_PREV(q)  (_QUEUE_PREV(_QUEUE_NEXT(q)))

// Public macros.
#define QUEUE_DATA(ptr, type, field)  \
  ((type *)((char *)(ptr) - offsetof(type, field)))

#define QUEUE_FOREACH(q, h) \
  for (  /* NOLINT(readability/braces) */ \
      (q) = _QUEUE_NEXT(h); (q) != (h); (q) = _QUEUE_NEXT(q))

// ffi.cdef is unable to swallow `bool` in place of `int` here.
static inline int QUEUE_EMPTY(const QUEUE *const q)
  FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return q == _QUEUE_NEXT(q);
}

#define QUEUE_HEAD _QUEUE_NEXT

static inline void QUEUE_INIT(QUEUE *const q) FUNC_ATTR_ALWAYS_INLINE
{
  _QUEUE_NEXT(q) = q;
  _QUEUE_PREV(q) = q;
}

static inline void QUEUE_ADD(QUEUE *const h, QUEUE *const n)
  FUNC_ATTR_ALWAYS_INLINE
{
  _QUEUE_PREV_NEXT(h) = _QUEUE_NEXT(n);
  _QUEUE_NEXT_PREV(n) = _QUEUE_PREV(h);
  _QUEUE_PREV(h) = _QUEUE_PREV(n);
  _QUEUE_PREV_NEXT(h) = h;
}

static inline void QUEUE_SPLIT(QUEUE *const h, QUEUE *const q, QUEUE *const n)
  FUNC_ATTR_ALWAYS_INLINE
{
  _QUEUE_PREV(n) = _QUEUE_PREV(h);
  _QUEUE_PREV_NEXT(n) = n;
  _QUEUE_NEXT(n) = q;
  _QUEUE_PREV(h) = _QUEUE_PREV(q);
  _QUEUE_PREV_NEXT(h) = h;
  _QUEUE_PREV(q) = n;
}

static inline void QUEUE_INSERT_HEAD(QUEUE *const h, QUEUE *const q)
  FUNC_ATTR_ALWAYS_INLINE
{
  _QUEUE_NEXT(q) = _QUEUE_NEXT(h);
  _QUEUE_PREV(q) = h;
  _QUEUE_NEXT_PREV(q) = q;
  _QUEUE_NEXT(h) = q;
}

static inline void QUEUE_INSERT_TAIL(QUEUE *const h, QUEUE *const q)
  FUNC_ATTR_ALWAYS_INLINE
{
  _QUEUE_NEXT(q) = h;
  _QUEUE_PREV(q) = _QUEUE_PREV(h);
  _QUEUE_PREV_NEXT(q) = q;
  _QUEUE_PREV(h) = q;
}

static inline void QUEUE_REMOVE(QUEUE *const q) FUNC_ATTR_ALWAYS_INLINE
{
  _QUEUE_PREV_NEXT(q) = _QUEUE_NEXT(q);
  _QUEUE_NEXT_PREV(q) = _QUEUE_PREV(q);
}

#endif  // NVIM_LIB_QUEUE_H
