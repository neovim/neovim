/* The MIT License

   Copyright (c) 2008-2009, by Attractive Chaos <attractor@live.co.uk>

   Permission is hereby granted, free of charge, to any person obtaining
   a copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
*/

#ifndef _AC_KLIST_H
#define _AC_KLIST_H

#include <stdlib.h>
#include <assert.h>

#include "nvim/memory.h"
#include "nvim/func_attr.h"


#define KMEMPOOL_INIT(name, kmptype_t, kmpfree_f) \
    typedef struct { \
        size_t cnt, n, max; \
        kmptype_t **buf; \
    } kmp_##name##_t; \
    static inline kmp_##name##_t *kmp_init_##name(void) { \
        return xcalloc(1, sizeof(kmp_##name##_t)); \
    } \
    static inline void kmp_destroy_##name(kmp_##name##_t *mp) \
        REAL_FATTR_UNUSED; \
    static inline void kmp_destroy_##name(kmp_##name##_t *mp) { \
        size_t k; \
        for (k = 0; k < mp->n; k++) { \
            kmpfree_f(mp->buf[k]); XFREE_CLEAR(mp->buf[k]); \
        } \
        XFREE_CLEAR(mp->buf); XFREE_CLEAR(mp); \
    } \
    static inline kmptype_t *kmp_alloc_##name(kmp_##name##_t *mp) { \
        mp->cnt++; \
        if (mp->n == 0) { \
          return xcalloc(1, sizeof(kmptype_t)); \
        } \
        return mp->buf[--mp->n]; \
    } \
    static inline void kmp_free_##name(kmp_##name##_t *mp, kmptype_t *p) { \
        mp->cnt--; \
        if (mp->n == mp->max) { \
            mp->max = mp->max ? (mp->max << 1) : 16; \
            mp->buf = xrealloc(mp->buf, sizeof(kmptype_t *) * mp->max); \
        } \
        mp->buf[mp->n++] = p; \
    }

#define kmempool_t(name) kmp_##name##_t
#define kmp_init(name) kmp_init_##name()
#define kmp_destroy(name, mp) kmp_destroy_##name(mp)
#define kmp_alloc(name, mp) kmp_alloc_##name(mp)
#define kmp_free(name, mp, p) kmp_free_##name(mp, p)

#define KLIST_INIT(name, kltype_t, kmpfree_t) \
    struct __kl1_##name { \
        kltype_t data; \
        struct __kl1_##name *next; \
    }; \
    typedef struct __kl1_##name kl1_##name; \
    KMEMPOOL_INIT(name, kl1_##name, kmpfree_t) \
    typedef struct { \
        kl1_##name *head, *tail; \
        kmp_##name##_t *mp; \
        size_t size; \
    } kl_##name##_t; \
    static inline kl_##name##_t *kl_init_##name(void) { \
        kl_##name##_t *kl = xcalloc(1, sizeof(kl_##name##_t)); \
        kl->mp = kmp_init(name); \
        kl->head = kl->tail = kmp_alloc(name, kl->mp); \
        kl->head->next = 0; \
        return kl; \
    } \
    static inline void kl_destroy_##name(kl_##name##_t *kl) \
        REAL_FATTR_UNUSED; \
    static inline void kl_destroy_##name(kl_##name##_t *kl) { \
        kl1_##name *p; \
        for (p = kl->head; p != kl->tail; p = p->next) { \
            kmp_free(name, kl->mp, p); \
        } \
        kmp_free(name, kl->mp, p); \
        kmp_destroy(name, kl->mp); \
        XFREE_CLEAR(kl); \
    } \
    static inline void kl_push_##name(kl_##name##_t *kl, kltype_t d) { \
        kl1_##name *q, *p = kmp_alloc(name, kl->mp); \
        q = kl->tail; p->next = 0; kl->tail->next = p; kl->tail = p; \
        kl->size++; \
        q->data = d; \
    } \
    static inline kltype_t kl_shift_at_##name(kl_##name##_t *kl, \
                                              kl1_##name **n) { \
        assert((*n)->next); \
        kl1_##name *p; \
        kl->size--; \
        p = *n; \
        *n = (*n)->next; \
        if (p == kl->head) { \
          kl->head = *n; \
        } \
        kltype_t d = p->data; \
        kmp_free(name, kl->mp, p); \
        return d; \
    }

#define kliter_t(name) kl1_##name
#define klist_t(name) kl_##name##_t
#define kl_val(iter) ((iter)->data)
#define kl_next(iter) ((iter)->next)
#define kl_begin(kl) ((kl)->head)
#define kl_end(kl) ((kl)->tail)

#define kl_init(name) kl_init_##name()
#define kl_destroy(name, kl) kl_destroy_##name(kl)
#define kl_push(name, kl, d) kl_push_##name(kl, d)
#define kl_shift_at(name, kl, node) kl_shift_at_##name(kl, node)
#define kl_shift(name, kl) kl_shift_at(name, kl, &kl->head)
#define kl_empty(kl) ((kl)->size == 0)
// Iteration macros. It's ok to modify the list while iterating as long as a
// `break` statement is executed before the next iteration.
#define kl_iter(name, kl, p) kl_iter_at(name, kl, p, NULL)
#define kl_iter_at(name, kl, p, h) \
  for (kl1_##name **p = h ? h : &kl->head; *p != kl->tail; p = &(*p)->next)

#endif
