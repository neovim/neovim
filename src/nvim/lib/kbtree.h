/*-
 * Copyright 1997-1999, 2001, John-Mark Gurney.
 *           2008-2009, Attractive Chaos <attractor@live.co.uk>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef NVIM_LIB_KBTREE_H
#define NVIM_LIB_KBTREE_H

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "nvim/memory.h"

#define KB_MAX_DEPTH 64

#define	__KB_KEY(type, x)	(x->key)
#define __KB_PTR(btr, x)	(x->ptr)

#define __KB_TREE_T(name,key_t,T)						\
    typedef struct kbnode_##name##_s kbnode_##name##_t;     \
    struct kbnode_##name##_s {              \
      int32_t n; \
      bool is_internal; \
      key_t key[2*T-1]; \
      kbnode_##name##_t *ptr[]; \
    } ; \
    \
    typedef struct { \
        kbnode_##name##_t *root; \
        int	n_keys, n_nodes; \
    } kbtree_##name##_t; \
    \
    typedef struct { \
        kbnode_##name##_t *x; \
        int i; \
    } kbpos_##name##_t; \
    typedef struct { \
        kbpos_##name##_t stack[KB_MAX_DEPTH], *p; \
    } kbitr_##name##_t; \


#define __kb_destroy(kbnode_t,b) do {											\
		int i;                                                          \
        unsigned int max = 8;											\
		kbnode_t *x, **top, **stack = 0;								\
		if (b->root) {													\
			top = stack = (kbnode_t**)xcalloc(max, sizeof(kbnode_t*));	\
			*top++ = (b)->root;											\
			while (top != stack) {										\
				x = *--top;												\
				if (x->is_internal == 0) { xfree(x); continue; }			\
				for (i = 0; i <= x->n; ++i)								\
					if (__KB_PTR(b, x)[i]) {							\
						if (top - stack == (int)max) {		        	\
							max <<= 1;									\
							stack = (kbnode_t**)xrealloc(stack, max * sizeof(kbnode_t*)); \
							top = stack + (max>>1);						\
						}												\
						*top++ = __KB_PTR(b, x)[i];						\
					}													\
				xfree(x);												\
			}															\
		}																\
		xfree(stack);											\
	} while (0)

#define __KB_GET_AUX1(name, key_t, kbnode_t, __cmp)								\
	static inline int __kb_getp_aux_##name(const kbnode_t * __restrict x, key_t * __restrict k, int *r) \
	{																	\
		int tr, *rr, begin = 0, end = x->n;								\
		if (x->n == 0) return -1;										\
		rr = r? r : &tr;												\
		while (begin < end) {											\
			int mid = (begin + end) >> 1;								\
			if (__cmp(__KB_KEY(key_t, x)[mid], *k) < 0) begin = mid + 1; \
			else end = mid;												\
		}																\
		if (begin == x->n) { *rr = 1; return x->n - 1; }				\
		if ((*rr = __cmp(*k, __KB_KEY(key_t, x)[begin])) < 0) --begin;	\
		return begin;													\
	}

#define __KB_GET(name, key_t, kbnode_t)											\
	static key_t *kb_getp_##name(kbtree_##name##_t *b, key_t * __restrict k) \
	{																	\
		if (!b->root) { \
		    return 0; \
		} \
		int i, r = 0;													\
		kbnode_t *x = b->root;											\
		while (x) {														\
			i = __kb_getp_aux_##name(x, k, &r);							\
			if (i >= 0 && r == 0) return &__KB_KEY(key_t, x)[i];		\
			if (x->is_internal == 0) return 0;							\
			x = __KB_PTR(b, x)[i + 1];									\
		}																\
		return 0;														\
	}																	\
	static inline key_t *kb_get_##name(kbtree_##name##_t *b, key_t k) \
	{																	\
		return kb_getp_##name(b, &k);									\
	}

#define __KB_INTERVAL(name, key_t, kbnode_t)										\
	static inline void kb_intervalp_##name(kbtree_##name##_t *b, key_t * __restrict k, key_t **lower, key_t **upper)	\
	{																	\
		if (!b->root) { \
		    return; \
		} \
		int i, r = 0;													\
		kbnode_t *x = b->root;											\
		*lower = *upper = 0;											\
		while (x) {														\
			i = __kb_getp_aux_##name(x, k, &r);							\
			if (i >= 0 && r == 0) {										\
				*lower = *upper = &__KB_KEY(key_t, x)[i];				\
				return;													\
			}															\
			if (i >= 0) *lower = &__KB_KEY(key_t, x)[i];				\
			if (i < x->n - 1) *upper = &__KB_KEY(key_t, x)[i + 1];		\
			if (x->is_internal == 0) return;							\
			x = __KB_PTR(b, x)[i + 1];									\
		}																\
	}																	\
	static inline void kb_interval_##name(kbtree_##name##_t *b, key_t k, key_t **lower, key_t **upper) \
	{																	\
		kb_intervalp_##name(b, &k, lower, upper);						\
	}

#define __KB_PUT(name, key_t, kbnode_t, __cmp, T, ILEN)									\
	/* x must be an internal node */									\
	static inline void __kb_split_##name(kbtree_##name##_t *b, kbnode_t *x, int i, kbnode_t *y) \
	{																	\
		kbnode_t *z;													\
		z = (kbnode_t*)xcalloc(1, y->is_internal? ILEN : sizeof(kbnode_##name##_t));	\
		++b->n_nodes;													\
		z->is_internal = y->is_internal;								\
		z->n = T - 1;												\
		memcpy(__KB_KEY(key_t, z), &__KB_KEY(key_t, y)[T], sizeof(key_t) * (T - 1)); \
		if (y->is_internal) memcpy(__KB_PTR(b, z), &__KB_PTR(b, y)[T], sizeof(void*) * T); \
		y->n = T - 1;												\
		memmove(&__KB_PTR(b, x)[i + 2], &__KB_PTR(b, x)[i + 1], sizeof(void*) * (unsigned int)(x->n - i)); \
		__KB_PTR(b, x)[i + 1] = z;										\
		memmove(&__KB_KEY(key_t, x)[i + 1], &__KB_KEY(key_t, x)[i], sizeof(key_t) * (unsigned int)(x->n - i)); \
		__KB_KEY(key_t, x)[i] = __KB_KEY(key_t, y)[T - 1];			\
		++x->n;															\
	}																	\
	static inline key_t *__kb_putp_aux_##name(kbtree_##name##_t *b, kbnode_t *x, key_t * __restrict k) \
	{																	\
		int i = x->n - 1;												\
		key_t *ret;														\
		if (x->is_internal == 0) {										\
			i = __kb_getp_aux_##name(x, k, 0);							\
			if (i != x->n - 1)											\
				memmove(&__KB_KEY(key_t, x)[i + 2], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t)); \
			ret = &__KB_KEY(key_t, x)[i + 1];							\
			*ret = *k;													\
			++x->n;														\
		} else {														\
			i = __kb_getp_aux_##name(x, k, 0) + 1;						\
			if (__KB_PTR(b, x)[i]->n == 2 * T - 1) {					\
				__kb_split_##name(b, x, i, __KB_PTR(b, x)[i]);			\
				if (__cmp(*k, __KB_KEY(key_t, x)[i]) > 0) ++i;			\
			}															\
			ret = __kb_putp_aux_##name(b, __KB_PTR(b, x)[i], k);		\
		}																\
		return ret; 													\
	}																	\
	static inline key_t *kb_putp_##name(kbtree_##name##_t *b, key_t * __restrict k) \
	{																	\
		if (!b->root) { \
			b->root = (kbnode_t*)xcalloc(1, ILEN);						\
			++b->n_nodes;													\
		} \
		kbnode_t *r, *s;												\
		++b->n_keys;													\
		r = b->root;													\
		if (r->n == 2 * T - 1) {										\
			++b->n_nodes;												\
			s = (kbnode_t*)xcalloc(1, ILEN);							\
			b->root = s; s->is_internal = 1; s->n = 0;					\
			__KB_PTR(b, s)[0] = r;										\
			__kb_split_##name(b, s, 0, r);								\
			r = s;														\
		}																\
		return __kb_putp_aux_##name(b, r, k);							\
	}																	\
	static inline void kb_put_##name(kbtree_##name##_t *b, key_t k) \
	{																	\
		kb_putp_##name(b, &k);											\
	}


#define __KB_DEL(name, key_t, kbnode_t, T)											\
	static inline key_t __kb_delp_aux_##name(kbtree_##name##_t *b, kbnode_t *x, key_t * __restrict k, int s) \
	{																	\
		int yn, zn, i, r = 0;											\
		kbnode_t *xp, *y, *z;											\
		key_t kp;														\
		if (x == 0) return *k;											\
		if (s) { /* s can only be 0, 1 or 2 */							\
			r = x->is_internal == 0? 0 : s == 1? 1 : -1;				\
			i = s == 1? x->n - 1 : -1;									\
		} else i = __kb_getp_aux_##name(x, k, &r);						\
		if (x->is_internal == 0) {										\
			if (s == 2) ++i;											\
			kp = __KB_KEY(key_t, x)[i];									\
			memmove(&__KB_KEY(key_t, x)[i], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t)); \
			--x->n;														\
			return kp;													\
		}																\
		if (r == 0) {													\
			if ((yn = __KB_PTR(b, x)[i]->n) >= T) {					\
				xp = __KB_PTR(b, x)[i];									\
				kp = __KB_KEY(key_t, x)[i];								\
				__KB_KEY(key_t, x)[i] = __kb_delp_aux_##name(b, xp, 0, 1); \
				return kp;												\
			} else if ((zn = __KB_PTR(b, x)[i + 1]->n) >= T) {		\
				xp = __KB_PTR(b, x)[i + 1];								\
				kp = __KB_KEY(key_t, x)[i];								\
				__KB_KEY(key_t, x)[i] = __kb_delp_aux_##name(b, xp, 0, 2); \
				return kp;												\
			} else if (yn == T - 1 && zn == T - 1) {				\
				y = __KB_PTR(b, x)[i]; z = __KB_PTR(b, x)[i + 1];		\
				__KB_KEY(key_t, y)[y->n++] = *k;						\
				memmove(&__KB_KEY(key_t, y)[y->n], __KB_KEY(key_t, z), (unsigned int)z->n * sizeof(key_t)); \
				if (y->is_internal) memmove(&__KB_PTR(b, y)[y->n], __KB_PTR(b, z), (unsigned int)(z->n + 1) * sizeof(void*)); \
				y->n += z->n;											\
				memmove(&__KB_KEY(key_t, x)[i], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t)); \
				memmove(&__KB_PTR(b, x)[i + 1], &__KB_PTR(b, x)[i + 2], (unsigned int)(x->n - i - 1) * sizeof(void*)); \
				--x->n;													\
				xfree(z);												\
				return __kb_delp_aux_##name(b, y, k, s);				\
			}															\
		}																\
		++i;															\
		if ((xp = __KB_PTR(b, x)[i])->n == T - 1) {					\
			if (i > 0 && (y = __KB_PTR(b, x)[i - 1])->n >= T) {		\
				memmove(&__KB_KEY(key_t, xp)[1], __KB_KEY(key_t, xp), (unsigned int)xp->n * sizeof(key_t)); \
				if (xp->is_internal) memmove(&__KB_PTR(b, xp)[1], __KB_PTR(b, xp), (unsigned int)(xp->n + 1) * sizeof(void*)); \
				__KB_KEY(key_t, xp)[0] = __KB_KEY(key_t, x)[i - 1];		\
				__KB_KEY(key_t, x)[i - 1] = __KB_KEY(key_t, y)[y->n - 1]; \
				if (xp->is_internal) __KB_PTR(b, xp)[0] = __KB_PTR(b, y)[y->n]; \
				--y->n; ++xp->n;										\
			} else if (i < x->n && (y = __KB_PTR(b, x)[i + 1])->n >= T) { \
				__KB_KEY(key_t, xp)[xp->n++] = __KB_KEY(key_t, x)[i];	\
				__KB_KEY(key_t, x)[i] = __KB_KEY(key_t, y)[0];			\
				if (xp->is_internal) __KB_PTR(b, xp)[xp->n] = __KB_PTR(b, y)[0]; \
				--y->n;													\
				memmove(__KB_KEY(key_t, y), &__KB_KEY(key_t, y)[1], (unsigned int)y->n * sizeof(key_t)); \
				if (y->is_internal) memmove(__KB_PTR(b, y), &__KB_PTR(b, y)[1], (unsigned int)(y->n + 1) * sizeof(void*)); \
			} else if (i > 0 && (y = __KB_PTR(b, x)[i - 1])->n == T - 1) { \
				__KB_KEY(key_t, y)[y->n++] = __KB_KEY(key_t, x)[i - 1];	\
				memmove(&__KB_KEY(key_t, y)[y->n], __KB_KEY(key_t, xp), (unsigned int)xp->n * sizeof(key_t));	\
				if (y->is_internal) memmove(&__KB_PTR(b, y)[y->n], __KB_PTR(b, xp), (unsigned int)(xp->n + 1) * sizeof(void*)); \
				y->n += xp->n;											\
				memmove(&__KB_KEY(key_t, x)[i - 1], &__KB_KEY(key_t, x)[i], (unsigned int)(x->n - i) * sizeof(key_t)); \
				memmove(&__KB_PTR(b, x)[i], &__KB_PTR(b, x)[i + 1], (unsigned int)(x->n - i) * sizeof(void*)); \
				--x->n;													\
				xfree(xp);												\
				xp = y;													\
			} else if (i < x->n && (y = __KB_PTR(b, x)[i + 1])->n == T - 1) { \
				__KB_KEY(key_t, xp)[xp->n++] = __KB_KEY(key_t, x)[i];	\
				memmove(&__KB_KEY(key_t, xp)[xp->n], __KB_KEY(key_t, y), (unsigned int)y->n * sizeof(key_t));	\
				if (xp->is_internal) memmove(&__KB_PTR(b, xp)[xp->n], __KB_PTR(b, y), (unsigned int)(y->n + 1) * sizeof(void*)); \
				xp->n += y->n;											\
				memmove(&__KB_KEY(key_t, x)[i], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t)); \
				memmove(&__KB_PTR(b, x)[i + 1], &__KB_PTR(b, x)[i + 2], (unsigned int)(x->n - i - 1) * sizeof(void*)); \
				--x->n;													\
				xfree(y);												\
			}															\
		}																\
		return __kb_delp_aux_##name(b, xp, k, s);						\
	}																	\
	static inline key_t kb_delp_##name(kbtree_##name##_t *b, key_t * __restrict k) \
	{																	\
		kbnode_t *x;													\
		key_t ret;														\
		ret = __kb_delp_aux_##name(b, b->root, k, 0);					\
		--b->n_keys;													\
		if (b->root->n == 0 && b->root->is_internal) {					\
			--b->n_nodes;												\
			x = b->root;												\
			b->root = __KB_PTR(b, x)[0];								\
			xfree(x);													\
		}																\
		return ret;														\
	}																	\
	static inline key_t kb_del_##name(kbtree_##name##_t *b, key_t k) \
	{																	\
		return kb_delp_##name(b, &k);									\
	}

#define __KB_ITR(name, key_t, kbnode_t) \
	static inline void kb_itr_first_##name(kbtree_##name##_t *b, kbitr_##name##_t *itr) \
	{ \
		itr->p = 0; \
		if (b->n_keys == 0) return; \
		itr->p = itr->stack; \
		itr->p->x = b->root; itr->p->i = 0; \
		while (itr->p->x->is_internal && __KB_PTR(b, itr->p->x)[0] != 0) { \
			kbnode_t *x = itr->p->x; \
			++itr->p; \
			itr->p->x = __KB_PTR(b, x)[0]; itr->p->i = 0; \
		} \
	} \
	static inline int kb_itr_next_##name(kbtree_##name##_t *b, kbitr_##name##_t *itr) \
	{ \
		if (itr->p < itr->stack) return 0; \
		for (;;) { \
			++itr->p->i; \
			while (itr->p->x && itr->p->i <= itr->p->x->n) { \
				itr->p[1].i = 0; \
				itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[itr->p->i] : 0; \
				++itr->p; \
			} \
			--itr->p; \
			if (itr->p < itr->stack) return 0; \
			if (itr->p->x && itr->p->i < itr->p->x->n) return 1; \
		} \
	} \
	static inline int kb_itr_prev_##name(kbtree_##name##_t *b, kbitr_##name##_t *itr) \
	{ \
		if (itr->p < itr->stack) return 0; \
		for (;;) { \
			while (itr->p->x && itr->p->i >= 0) { \
				itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[itr->p->i] : 0; \
				itr->p[1].i = itr->p[1].x ? itr->p[1].x->n : -1; \
				++itr->p; \
			} \
			--itr->p; \
			if (itr->p < itr->stack) return 0; \
			--itr->p->i; \
			if (itr->p->x && itr->p->i >= 0) return 1; \
		} \
	} \
	static inline int kb_itr_getp_##name(kbtree_##name##_t *b, key_t * __restrict k, kbitr_##name##_t *itr) \
	{ \
		if (b->n_keys == 0) { \
            itr->p = NULL; \
            return 0; \
        } \
		int i, r = 0; \
		itr->p = itr->stack; \
		itr->p->x = b->root; \
		while (itr->p->x) { \
			i = __kb_getp_aux_##name(itr->p->x, k, &r); \
			itr->p->i = i; \
			if (i >= 0 && r == 0) return 1; \
			++itr->p->i; \
			itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[i + 1] : 0; \
			++itr->p; \
		} \
		return 0; \
	} \
	static inline int kb_itr_get_##name(kbtree_##name##_t *b, key_t k, kbitr_##name##_t *itr) \
	{																	\
		return kb_itr_getp_##name(b,&k,itr); \
	} \
	static inline void kb_del_itr_##name(kbtree_##name##_t *b, kbitr_##name##_t *itr) \
	{ \
		key_t k = kb_itr_key(itr); \
		kb_delp_##name(b, &k); \
		kb_itr_getp_##name(b, &k, itr); \
	} 

#define KBTREE_INIT(name, key_t, __cmp, T) \
  KBTREE_INIT_IMPL(name, key_t, kbnode_##name##_t, __cmp, T, (sizeof(kbnode_##name##_t)+(2*T)*sizeof(void *)))

#define KBTREE_INIT_IMPL(name, key_t, kbnode_t, __cmp, T, ILEN)			\
	__KB_TREE_T(name, key_t, T)							\
	__KB_GET_AUX1(name, key_t, kbnode_t, __cmp)			\
	__KB_GET(name, key_t, kbnode_t)						\
	__KB_INTERVAL(name, key_t, kbnode_t)					\
	__KB_PUT(name, key_t, kbnode_t, __cmp, T, ILEN)				\
	__KB_DEL(name, key_t, kbnode_t, T) \
	__KB_ITR(name, key_t, kbnode_t)

#define KB_DEFAULT_SIZE 512

#define kbtree_t(name) kbtree_##name##_t
#define kbitr_t(name) kbitr_##name##_t
#define kb_init(b) ((b)->n_keys = (b)->n_nodes = 0, (b)->root = 0)
#define kb_destroy(name, b) __kb_destroy(kbnode_##name##_t, b)
#define kb_get(name, b, k) kb_get_##name(b, k)
#define kb_put(name, b, k) kb_put_##name(b, k)
#define kb_del(name, b, k) kb_del_##name(b, k)
#define kb_interval(name, b, k, l, u) kb_interval_##name(b, k, l, u)
#define kb_getp(name, b, k) kb_getp_##name(b, k)
#define kb_putp(name, b, k) kb_putp_##name(b, k)
#define kb_delp(name, b, k) kb_delp_##name(b, k)
#define kb_intervalp(name, b, k, l, u) kb_intervalp_##name(b, k, l, u)

#define kb_itr_first(name, b, i) kb_itr_first_##name(b, i)
#define kb_itr_get(name, b, k, i) kb_itr_get_##name(b, k, i)
#define kb_itr_getp(name, b, k, i) kb_itr_getp_##name(b, k, i)
#define kb_itr_next(name, b, i) kb_itr_next_##name(b, i)
#define kb_itr_prev(name, b, i) kb_itr_prev_##name(b, i)
#define kb_del_itr(name, b, i) kb_del_itr_##name(b, i)
#define kb_itr_key(itr) __KB_KEY(dummy, (itr)->p->x)[(itr)->p->i]
#define kb_itr_valid(itr) ((itr)->p >= (itr)->stack)

#define kb_size(b) ((b)->n_keys)

#define kb_generic_cmp(a, b) (((b) < (a)) - ((a) < (b)))
#define kb_str_cmp(a, b) strcmp(a, b)

#endif  // NVIM_LIB_KBTREE_H
