// Queue implemented by circularly-linked list.
//
// Adapted from libuv. Simpler and more efficient than klist.h for implementing
// queues that support arbitrary insertion/removal.
//
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

#pragma once

#include <stddef.h>

#include "nvim/func_attr.h"

typedef struct queue {
  struct queue *next;
  struct queue *prev;
} QUEUE;

// Public macros.
#define QUEUE_DATA(ptr, type, field) \
  ((type *)((char *)(ptr) - offsetof(type, field)))

// Important note: the node currently being processed can be safely deleted.
// otherwise, mutating the list while QUEUE_FOREACH is iterating over its
// elements results in undefined behavior.
#define QUEUE_FOREACH(q, h, code) \
  (q) = (h)->next; \
  while ((q) != (h)) { \
    QUEUE *next = q->next; \
    code \
      (q) = next; \
  }

// ffi.cdef is unable to swallow `bool` in place of `int` here.
static inline int QUEUE_EMPTY(const QUEUE *q)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

static inline int QUEUE_EMPTY(const QUEUE *const q)
{
  return q == q->next;
}

#define QUEUE_HEAD(q) (q)->next

static inline void QUEUE_INIT(QUEUE *q)
  REAL_FATTR_ALWAYS_INLINE;

static inline void QUEUE_INIT(QUEUE *const q)
{
  q->next = q;
  q->prev = q;
}

static inline void QUEUE_ADD(QUEUE *h, QUEUE *n)
  REAL_FATTR_ALWAYS_INLINE;

static inline void QUEUE_ADD(QUEUE *const h, QUEUE *const n)
{
  h->prev->next = n->next;
  n->next->prev = h->prev;
  h->prev = n->prev;
  h->prev->next = h;
}

static inline void QUEUE_INSERT_HEAD(QUEUE *h, QUEUE *q)
  REAL_FATTR_ALWAYS_INLINE;

static inline void QUEUE_INSERT_HEAD(QUEUE *const h, QUEUE *const q)
{
  q->next = h->next;
  q->prev = h;
  q->next->prev = q;
  h->next = q;
}

static inline void QUEUE_INSERT_TAIL(QUEUE *h, QUEUE *q)
  REAL_FATTR_ALWAYS_INLINE;

static inline void QUEUE_INSERT_TAIL(QUEUE *const h, QUEUE *const q)
{
  q->next = h;
  q->prev = h->prev;
  q->prev->next = q;
  h->prev = q;
}

static inline void QUEUE_REMOVE(QUEUE *q)
  REAL_FATTR_ALWAYS_INLINE;

static inline void QUEUE_REMOVE(QUEUE *const q)
{
  q->prev->next = q->next;
  q->next->prev = q->prev;
}
