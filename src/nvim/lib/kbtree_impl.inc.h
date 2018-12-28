
/// input:
/// #define KB_TYPENAME name of tree-type
/// #define KB_KEY_TYPE type of key
/// #define KB_KEY_CMP comparator between keys
/// #define KB_BRANCH_FACTOR branch factor (at least 2)

#ifndef KB_NAME_SUFFIX
#define KB_NAME_SUFFIX(X) X##_x_typecheck_x
typedef struct {
   int kb_dummy_field;
} kb_dummy_key;
#define KB_KEY_TYPE kb_dummy_key
#define KB_KEY_CMP(x,y) (kb_generic_cmp((x).kb_dummy_field, (y).kb_dummy_field))
#define KB_BRANCH_FACTOR 10
#endif

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "nvim/memory.h"
#include "nvim/lib/kbtree.h"

#define __KB_KEY(type, x) (x->key)
#define __KB_PTR(btr, x) (x->ptr)


#define kbtree_impl_t KB_NAME_SUFFIX(kbtree_t)
#define kbitr_impl_t KB_NAME_SUFFIX(kbitr_t)
#define kbnode_t KB_NAME_SUFFIX(kbnode_t)
#define kbnode_s KB_NAME_SUFFIX(kbnode_t)
#define kbpos_t KB_NAME_SUFFIX(kbpos_t)
#define key_t KB_KEY_TYPE

#define T KB_BRANCH_FACTOR
#define __cmp(x, y) KB_KEY_CMP(x, y)
#define ILEN (sizeof(kbnode_t)+(2*T)*sizeof(void *))

#define KB_MAX_DEPTH 64

typedef struct kbnode_s kbnode_t;
struct kbnode_s {
  int32_t n;
  bool is_internal;
  key_t key[2 * T - 1];
  kbnode_t *ptr[];
};

typedef struct {
  kbnode_t *root;
  int n_keys, n_nodes;
} kbtree_impl_t;

typedef struct {
  kbnode_t *x;
  int i;
} kbpos_t;

typedef struct {
  kbpos_t stack[KB_MAX_DEPTH], *p;
} kbitr_impl_t;

#define IMPL(name) KB_NAME_SUFFIX(name)

static inline void IMPL(kb_destroy)(kbtree_impl_t *b)
{
  int i;
  unsigned int max = 8;
  kbnode_t *x, **top, **stack = 0;
  if (b->root) {
    top = stack = (kbnode_t**)xcalloc(max, sizeof(kbnode_t*));
    *top++ = (b)->root;
    while (top != stack) {
      x = *--top;
      if (x->is_internal == 0) { xfree(x); continue; }
      for (i = 0; i <= x->n; ++i)
        if (__KB_PTR(b, x)[i]) {
          if (top - stack == (int)max) {
            max <<= 1;
            stack = (kbnode_t**)xrealloc(stack, max * sizeof(kbnode_t*));
            top = stack + (max>>1);
          }
          *top++ = __KB_PTR(b, x)[i];
        }
      xfree(x);
    }
  }
  xfree(stack);
}

static inline int IMPL(__kb_getp_aux)(const kbnode_t * __restrict x,
                                            key_t * __restrict k, int *r)
{
  int tr, *rr, begin = 0, end = x->n;
  if (x->n == 0) return -1;
  rr = r? r : &tr;
  while (begin < end) {
    int mid = (begin + end) >> 1;
    if (__cmp(__KB_KEY(key_t, x)[mid], *k) < 0) begin = mid + 1;
    else end = mid;
  }
  if (begin == x->n) { *rr = 1; return x->n - 1; }
  if ((*rr = __cmp(*k, __KB_KEY(key_t, x)[begin])) < 0) --begin;
  return begin;
}

static key_t *IMPL(kb_getp)(kbtree_impl_t *b, key_t * __restrict k)
{
  if (!b->root) {
    return 0;
  }
  int i, r = 0;
  kbnode_t *x = b->root;
  while (x) {
    i = IMPL(__kb_getp_aux)(x, k, &r);
    if (i >= 0 && r == 0) return &__KB_KEY(key_t, x)[i];
    if (x->is_internal == 0) return 0;
    x = __KB_PTR(b, x)[i + 1];
  }
  return 0;
}

static inline key_t *IMPL(kb_get)(kbtree_impl_t *b, key_t k)
{
  return IMPL(kb_getp)(b, &k);
}

static inline void IMPL(kb_intervalp)(kbtree_impl_t *b, key_t * __restrict k, key_t **lower, key_t **upper)
{
  if (!b->root) {
    return;
  }
  int i, r = 0;
  kbnode_t *x = b->root;
  *lower = *upper = 0;
  while (x) {
    i = IMPL(__kb_getp_aux)(x, k, &r);
    if (i >= 0 && r == 0) {
      *lower = *upper = &__KB_KEY(key_t, x)[i];
      return;
    }
    if (i >= 0) *lower = &__KB_KEY(key_t, x)[i];
    if (i < x->n - 1) *upper = &__KB_KEY(key_t, x)[i + 1];
    if (x->is_internal == 0) return;
    x = __KB_PTR(b, x)[i + 1];
  }
}

static inline void IMPL(kb_interval)(kbtree_impl_t *b, key_t k, key_t **lower, key_t **upper)
{
    IMPL(kb_intervalp)(b, &k, lower, upper);
}

// x must be an internal node
static inline void IMPL(__kb_split)(kbtree_impl_t *b, kbnode_t *x, int i, kbnode_t *y)
{
  kbnode_t *z;
  z = (kbnode_t*)xcalloc(1, y->is_internal? ILEN : sizeof(kbnode_t));
  ++b->n_nodes;
  z->is_internal = y->is_internal;
  z->n = T - 1;
  memcpy(__KB_KEY(key_t, z), &__KB_KEY(key_t, y)[T], sizeof(key_t) * (T - 1));
  if (y->is_internal) memcpy(__KB_PTR(b, z), &__KB_PTR(b, y)[T], sizeof(void*) * T);
  y->n = T - 1;
  memmove(&__KB_PTR(b, x)[i + 2], &__KB_PTR(b, x)[i + 1], sizeof(void*) * (unsigned int)(x->n - i));
  __KB_PTR(b, x)[i + 1] = z;
  memmove(&__KB_KEY(key_t, x)[i + 1], &__KB_KEY(key_t, x)[i], sizeof(key_t) * (unsigned int)(x->n - i));
  __KB_KEY(key_t, x)[i] = __KB_KEY(key_t, y)[T - 1];
  ++x->n;
}

static inline key_t *IMPL(__kb_putp_aux)(kbtree_impl_t *b, kbnode_t *x, key_t * __restrict k)
{
  int i = x->n - 1;
  key_t *ret;
  if (x->is_internal == 0) {
    i = IMPL(__kb_getp_aux)(x, k, 0);
    if (i != x->n - 1)
      memmove(&__KB_KEY(key_t, x)[i + 2], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t));
    ret = &__KB_KEY(key_t, x)[i + 1];
    *ret = *k;
    ++x->n;
  } else {
    i = IMPL(__kb_getp_aux)(x, k, 0) + 1;
    if (__KB_PTR(b, x)[i]->n == 2 * T - 1) {
      IMPL(__kb_split)(b, x, i, __KB_PTR(b, x)[i]);
      if (__cmp(*k, __KB_KEY(key_t, x)[i]) > 0) ++i;
    }
    ret = IMPL(__kb_putp_aux)(b, __KB_PTR(b, x)[i], k);
  }
  return ret;
}

static inline key_t *IMPL(kb_putp)(kbtree_impl_t *b, key_t * __restrict k)
{
  if (!b->root) {
    b->root = (kbnode_t*)xcalloc(1, ILEN);
    ++b->n_nodes;
  }
  kbnode_t *r, *s;
  ++b->n_keys;
  r = b->root;
  if (r->n == 2 * T - 1) {
    ++b->n_nodes;
    s = (kbnode_t*)xcalloc(1, ILEN);
    b->root = s; s->is_internal = 1; s->n = 0;
    __KB_PTR(b, s)[0] = r;
    IMPL(__kb_split)(b, s, 0, r);
    r = s;
  }
  return IMPL(__kb_putp_aux)(b, r, k);
}

static inline void IMPL(kb_put)(kbtree_impl_t *b, key_t k)
{
  IMPL(kb_putp)(b, &k);
}


static inline key_t IMPL(__kb_delp_aux)(kbtree_impl_t *b, kbnode_t *x, key_t * __restrict k, int s)
{
  int yn, zn, i, r = 0;
  kbnode_t *xp, *y, *z;
  key_t kp;
  if (x == 0) return *k;
  if (s) { /* s can only be 0, 1 or 2 */
    r = x->is_internal == 0? 0 : s == 1? 1 : -1;
    i = s == 1? x->n - 1 : -1;
  } else i = IMPL(__kb_getp_aux)(x, k, &r);
  if (x->is_internal == 0) {
    if (s == 2) ++i;
    kp = __KB_KEY(key_t, x)[i];
    memmove(&__KB_KEY(key_t, x)[i], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t));
    --x->n;
    return kp;
  }
  if (r == 0) {
    if ((yn = __KB_PTR(b, x)[i]->n) >= T) {
      xp = __KB_PTR(b, x)[i];
      kp = __KB_KEY(key_t, x)[i];
      __KB_KEY(key_t, x)[i] = IMPL(__kb_delp_aux)(b, xp, 0, 1);
      return kp;
    } else if ((zn = __KB_PTR(b, x)[i + 1]->n) >= T) {
      xp = __KB_PTR(b, x)[i + 1];
      kp = __KB_KEY(key_t, x)[i];
      __KB_KEY(key_t, x)[i] = IMPL(__kb_delp_aux)(b, xp, 0, 2);
      return kp;
    } else if (yn == T - 1 && zn == T - 1) {
      y = __KB_PTR(b, x)[i]; z = __KB_PTR(b, x)[i + 1];
      __KB_KEY(key_t, y)[y->n++] = *k;
      memmove(&__KB_KEY(key_t, y)[y->n], __KB_KEY(key_t, z), (unsigned int)z->n * sizeof(key_t));
      if (y->is_internal) memmove(&__KB_PTR(b, y)[y->n], __KB_PTR(b, z), (unsigned int)(z->n + 1) * sizeof(void*));
      y->n += z->n;
      memmove(&__KB_KEY(key_t, x)[i], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t));
      memmove(&__KB_PTR(b, x)[i + 1], &__KB_PTR(b, x)[i + 2], (unsigned int)(x->n - i - 1) * sizeof(void*));
      --x->n;
      xfree(z);
      return IMPL(__kb_delp_aux)(b, y, k, s);
    }
  }
  ++i;
  if ((xp = __KB_PTR(b, x)[i])->n == T - 1) {
    if (i > 0 && (y = __KB_PTR(b, x)[i - 1])->n >= T) {
      memmove(&__KB_KEY(key_t, xp)[1], __KB_KEY(key_t, xp), (unsigned int)xp->n * sizeof(key_t));
      if (xp->is_internal) memmove(&__KB_PTR(b, xp)[1], __KB_PTR(b, xp), (unsigned int)(xp->n + 1) * sizeof(void*));
      __KB_KEY(key_t, xp)[0] = __KB_KEY(key_t, x)[i - 1];
      __KB_KEY(key_t, x)[i - 1] = __KB_KEY(key_t, y)[y->n - 1];
      if (xp->is_internal) __KB_PTR(b, xp)[0] = __KB_PTR(b, y)[y->n];
      --y->n; ++xp->n;
    } else if (i < x->n && (y = __KB_PTR(b, x)[i + 1])->n >= T) {
      __KB_KEY(key_t, xp)[xp->n++] = __KB_KEY(key_t, x)[i];
      __KB_KEY(key_t, x)[i] = __KB_KEY(key_t, y)[0];
      if (xp->is_internal) __KB_PTR(b, xp)[xp->n] = __KB_PTR(b, y)[0];
      --y->n;
      memmove(__KB_KEY(key_t, y), &__KB_KEY(key_t, y)[1], (unsigned int)y->n * sizeof(key_t));
      if (y->is_internal) memmove(__KB_PTR(b, y), &__KB_PTR(b, y)[1], (unsigned int)(y->n + 1) * sizeof(void*));
    } else if (i > 0 && (y = __KB_PTR(b, x)[i - 1])->n == T - 1) {
      __KB_KEY(key_t, y)[y->n++] = __KB_KEY(key_t, x)[i - 1];
      memmove(&__KB_KEY(key_t, y)[y->n], __KB_KEY(key_t, xp), (unsigned int)xp->n * sizeof(key_t));
      if (y->is_internal) memmove(&__KB_PTR(b, y)[y->n], __KB_PTR(b, xp), (unsigned int)(xp->n + 1) * sizeof(void*));
      y->n += xp->n;
      memmove(&__KB_KEY(key_t, x)[i - 1], &__KB_KEY(key_t, x)[i], (unsigned int)(x->n - i) * sizeof(key_t));
      memmove(&__KB_PTR(b, x)[i], &__KB_PTR(b, x)[i + 1], (unsigned int)(x->n - i) * sizeof(void*));
      --x->n;
      xfree(xp);
      xp = y;
    } else if (i < x->n && (y = __KB_PTR(b, x)[i + 1])->n == T - 1) {
      __KB_KEY(key_t, xp)[xp->n++] = __KB_KEY(key_t, x)[i];
      memmove(&__KB_KEY(key_t, xp)[xp->n], __KB_KEY(key_t, y), (unsigned int)y->n * sizeof(key_t));
      if (xp->is_internal) memmove(&__KB_PTR(b, xp)[xp->n], __KB_PTR(b, y), (unsigned int)(y->n + 1) * sizeof(void*));
      xp->n += y->n;
      memmove(&__KB_KEY(key_t, x)[i], &__KB_KEY(key_t, x)[i + 1], (unsigned int)(x->n - i - 1) * sizeof(key_t));
      memmove(&__KB_PTR(b, x)[i + 1], &__KB_PTR(b, x)[i + 2], (unsigned int)(x->n - i - 1) * sizeof(void*));
      --x->n;
      xfree(y);
    }
  }
  return IMPL(__kb_delp_aux)(b, xp, k, s);
}

static inline key_t IMPL(kb_delp)(kbtree_impl_t *b, key_t * __restrict k)
{
  kbnode_t *x;
  key_t ret;
  ret = IMPL(__kb_delp_aux)(b, b->root, k, 0);
  --b->n_keys;
  if (b->root->n == 0 && b->root->is_internal) {
    --b->n_nodes;
    x = b->root;
    b->root = __KB_PTR(b, x)[0];
    xfree(x);
  }
  return ret;
}

static inline key_t IMPL(kb_del)(kbtree_impl_t *b, key_t k)
{
    return IMPL(kb_delp)(b, &k);
}

static inline void IMPL(kb_itr_first)(kbtree_impl_t *b, kbitr_impl_t *itr)
{
  itr->p = 0;
  if (b->n_keys == 0) return;
  itr->p = itr->stack;
  itr->p->x = b->root; itr->p->i = 0;
  while (itr->p->x->is_internal && __KB_PTR(b, itr->p->x)[0] != 0) {
    kbnode_t *x = itr->p->x;
    ++itr->p;
    itr->p->x = __KB_PTR(b, x)[0]; itr->p->i = 0;
  }
}

static inline int IMPL(kb_itr_next)(kbtree_impl_t *b, kbitr_impl_t *itr)
{
  if (itr->p < itr->stack) return 0;
  for (;;) {
    ++itr->p->i;
    while (itr->p->x && itr->p->i <= itr->p->x->n) {
      itr->p[1].i = 0;
      itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[itr->p->i] : 0;
      ++itr->p;
    }
    --itr->p;
    if (itr->p < itr->stack) return 0;
    if (itr->p->x && itr->p->i < itr->p->x->n) return 1;
  }
}
static inline int IMPL(kb_itr_prev)(kbtree_impl_t *b, kbitr_impl_t *itr)
{
  if (itr->p < itr->stack) return 0;
  for (;;) {
    while (itr->p->x && itr->p->i >= 0) {
      itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[itr->p->i] : 0;
      itr->p[1].i = itr->p[1].x ? itr->p[1].x->n : -1;
      ++itr->p;
    }
    --itr->p;
    if (itr->p < itr->stack) return 0;
    --itr->p->i;
    if (itr->p->x && itr->p->i >= 0) return 1;
  }
}
static inline int IMPL(kb_itr_getp)(kbtree_impl_t *b, key_t * __restrict k, kbitr_impl_t *itr)
{
  if (b->n_keys == 0) {
    itr->p = NULL;
    return 0;
  }
  int i, r = 0;
  itr->p = itr->stack;
  itr->p->x = b->root;
  while (itr->p->x) {
    i = IMPL(__kb_getp_aux)(itr->p->x, k, &r);
    itr->p->i = i;
    if (i >= 0 && r == 0) return 1;
    ++itr->p->i;
    itr->p[1].x = itr->p->x->is_internal? __KB_PTR(b, itr->p->x)[i + 1] : 0;
    ++itr->p;
  }
  return 0;
}
static inline int IMPL(kb_itr_get)(kbtree_impl_t *b, key_t k, kbitr_impl_t *itr)
{
  return IMPL(kb_itr_getp)(b,&k,itr);
}
static inline void IMPL(kb_del_itr)(kbtree_impl_t *b, kbitr_impl_t *itr)
{
  key_t k = kb_itr_key(itr);
  IMPL(kb_delp)(b, &k);
  IMPL(kb_itr_getp)(b, &k, itr);
} 


#undef kbnode_t
#undef kbnode_s
#undef kbpos_t

#undef T
#undef IMPL
