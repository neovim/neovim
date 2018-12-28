
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
        if (x->ptr[i]) {
          if (top - stack == (int)max) {
            max <<= 1;
            stack = (kbnode_t**)xrealloc(stack, max * sizeof(kbnode_t*));
            top = stack + (max>>1);
          }
          *top++ = x->ptr[i];
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
    if (__cmp(x->key[mid], *k) < 0) begin = mid + 1;
    else end = mid;
  }
  if (begin == x->n) { *rr = 1; return x->n - 1; }
  if ((*rr = __cmp(*k, x->key[begin])) < 0) --begin;
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
    if (i >= 0 && r == 0) return &x->key[i];
    if (x->is_internal == 0) return 0;
    x = x->ptr[i + 1];
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
      *lower = *upper = &x->key[i];
      return;
    }
    if (i >= 0) *lower = &x->key[i];
    if (i < x->n - 1) *upper = &x->key[i + 1];
    if (x->is_internal == 0) return;
    x = x->ptr[i + 1];
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
  memcpy(z->key, &y->key[T], sizeof(key_t) * (T - 1));
  if (y->is_internal) memcpy(z->ptr, &y->ptr[T], sizeof(void*) * T);
  y->n = T - 1;
  memmove(&x->ptr[i + 2], &x->ptr[i + 1], sizeof(void*) * (size_t)(x->n - i));
  x->ptr[i + 1] = z;
  memmove(&x->key[i + 1], &x->key[i], sizeof(key_t) * (size_t)(x->n - i));
  x->key[i] = y->key[T - 1];
  ++x->n;
}

static inline key_t *IMPL(__kb_putp_aux)(kbtree_impl_t *b, kbnode_t *x, key_t * __restrict k)
{
  int i = x->n - 1;
  key_t *ret;
  if (x->is_internal == 0) {
    i = IMPL(__kb_getp_aux)(x, k, 0);
    if (i != x->n - 1)
      memmove(&x->key[i + 2], &x->key[i + 1], (size_t)(x->n - i - 1) * sizeof(key_t));
    ret = &x->key[i + 1];
    *ret = *k;
    ++x->n;
  } else {
    i = IMPL(__kb_getp_aux)(x, k, 0) + 1;
    if (x->ptr[i]->n == 2 * T - 1) {
      IMPL(__kb_split)(b, x, i, x->ptr[i]);
      if (__cmp(*k, x->key[i]) > 0) ++i;
    }
    ret = IMPL(__kb_putp_aux)(b, x->ptr[i], k);
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
    s->ptr[0] = r;
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
    kp = x->key[i];
    memmove(&x->key[i], &x->key[i + 1], (size_t)(x->n - i - 1) * sizeof(key_t));
    --x->n;
    return kp;
  }
  if (r == 0) {
    if ((yn = x->ptr[i]->n) >= T) {
      xp = x->ptr[i];
      kp = x->key[i];
      x->key[i] = IMPL(__kb_delp_aux)(b, xp, 0, 1);
      return kp;
    } else if ((zn = x->ptr[i + 1]->n) >= T) {
      xp = x->ptr[i + 1];
      kp = x->key[i];
      x->key[i] = IMPL(__kb_delp_aux)(b, xp, 0, 2);
      return kp;
    } else if (yn == T - 1 && zn == T - 1) {
      y = x->ptr[i]; z = x->ptr[i + 1];
      y->key[y->n++] = *k;
      memmove(&y->key[y->n], z->key, (size_t)z->n * sizeof(key_t));
      if (y->is_internal) memmove(&y->ptr[y->n], z->ptr, (size_t)(z->n + 1) * sizeof(void*));
      y->n += z->n;
      memmove(&x->key[i], &x->key[i + 1], (size_t)(x->n - i - 1) * sizeof(key_t));
      memmove(&x->ptr[i + 1], &x->ptr[i + 2], (size_t)(x->n - i - 1) * sizeof(void*));
      --x->n;
      xfree(z);
      return IMPL(__kb_delp_aux)(b, y, k, s);
    }
  }
  ++i;
  if ((xp = x->ptr[i])->n == T - 1) {
    if (i > 0 && (y = x->ptr[i - 1])->n >= T) {
      memmove(&xp->key[1], xp->key, (size_t)xp->n * sizeof(key_t));
      if (xp->is_internal) memmove(&xp->ptr[1], xp->ptr, (size_t)(xp->n + 1) * sizeof(void*));
      xp->key[0] = x->key[i - 1];
      x->key[i - 1] = y->key[y->n - 1];
      if (xp->is_internal) xp->ptr[0] = y->ptr[y->n];
      --y->n; ++xp->n;
    } else if (i < x->n && (y = x->ptr[i + 1])->n >= T) {
      xp->key[xp->n++] = x->key[i];
      x->key[i] = y->key[0];
      if (xp->is_internal) xp->ptr[xp->n] = y->ptr[0];
      --y->n;
      memmove(y->key, &y->key[1], (size_t)y->n * sizeof(key_t));
      if (y->is_internal) memmove(y->ptr, &y->ptr[1], (size_t)(y->n + 1) * sizeof(void*));
    } else if (i > 0 && (y = x->ptr[i - 1])->n == T - 1) {
      y->key[y->n++] = x->key[i - 1];
      memmove(&y->key[y->n], xp->key, (size_t)xp->n * sizeof(key_t));
      if (y->is_internal) memmove(&y->ptr[y->n], xp->ptr, (size_t)(xp->n + 1) * sizeof(void*));
      y->n += xp->n;
      memmove(&x->key[i - 1], &x->key[i], (size_t)(x->n - i) * sizeof(key_t));
      memmove(&x->ptr[i], &x->ptr[i + 1], (size_t)(x->n - i) * sizeof(void*));
      --x->n;
      xfree(xp);
      xp = y;
    } else if (i < x->n && (y = x->ptr[i + 1])->n == T - 1) {
      xp->key[xp->n++] = x->key[i];
      memmove(&xp->key[xp->n], y->key, (size_t)y->n * sizeof(key_t));
      if (xp->is_internal) memmove(&xp->ptr[xp->n], y->ptr, (size_t)(y->n + 1) * sizeof(void*));
      xp->n += y->n;
      memmove(&x->key[i], &x->key[i + 1], (size_t)(x->n - i - 1) * sizeof(key_t));
      memmove(&x->ptr[i + 1], &x->ptr[i + 2], (size_t)(x->n - i - 1) * sizeof(void*));
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
    b->root = x->ptr[0];
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
  while (itr->p->x->is_internal && itr->p->x->ptr[0] != 0) {
    kbnode_t *x = itr->p->x;
    ++itr->p;
    itr->p->x = x->ptr[0]; itr->p->i = 0;
  }
}

static inline int IMPL(kb_itr_next)(kbtree_impl_t *b, kbitr_impl_t *itr)
{
  if (itr->p < itr->stack) return 0;
  for (;;) {
    ++itr->p->i;
    while (itr->p->x && itr->p->i <= itr->p->x->n) {
      itr->p[1].i = 0;
      itr->p[1].x = itr->p->x->is_internal? itr->p->x->ptr[itr->p->i] : 0;
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
      itr->p[1].x = itr->p->x->is_internal? itr->p->x->ptr[itr->p->i] : 0;
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
    itr->p[1].x = itr->p->x->is_internal? itr->p->x->ptr[i + 1] : 0;
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
