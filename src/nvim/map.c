// map.c: Hash maps and sets
//
// parts of the implementation derived from khash.h as part of klib (MIT license)
//
// NOTE: Callers must manage memory (allocate) for keys and values.
//       Map and Set does not make its own copy of the key or value.

#include <stdbool.h>
#include <string.h>

#include "auto/config.h"
#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/map_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/path.h"

#define equal_simple(x, y) ((x) == (y))

#define hash_uint64_t(key) (uint32_t)((key) >> 33^(key)^(key) << 11)
#define equal_uint64_t equal_simple
#define hash_uint32_t(x) (x)
#define equal_uint32_t equal_simple
#define hash_int(x) hash_uint32_t((uint32_t)(x))
#define equal_int equal_simple
#define hash_int64_t(key) hash_uint64_t((uint64_t)key)
#define equal_int64_t equal_simple

#ifdef ARCH_64
# define hash_ptr_t(key) hash_uint64_t((uint64_t)(key))
# define equal_ptr_t(a, b) equal_uint64_t((uint64_t)(a), (uint64_t)(b))
#elif defined(ARCH_32)
# define hash_ptr_t(key) hash_uint32_t((uint32_t)(key))
# define equal_ptr_t(a, b) equal_uint32_t((uint32_t)(a), (uint32_t)(b))
#endif

static inline uint32_t hash_cstr_t(const char *s)
{
  uint32_t h = 0;
  for (size_t i = 0; s[i]; i++) {
    h = (h << 5) - h + (uint8_t)s[i];
  }
  return h;
}

#define equal_cstr_t strequal

/// Hash/equality for path strings. On case-insensitive platforms, case-fold first (via
/// path_fold_char, the same fold used by path_cmp) so the hash↔equality invariant holds.
///
/// We additionally:
///   - drop a leading drive letter "[A-Za-z]:" on Windows, so that "C:\foo" and "\foo" land in
///     the same bucket (path_cmp considers them equal when the current drive matches the
///     explicit drive letter). Two paths with *different* explicit drives ("C:\foo" vs "D:\foo")
///     may now share a bucket — that's a permitted collision; equal_path_t still rejects them.
///   - ignore a single trailing path separator.
static inline uint32_t hash_path_t(const char *p)
{
  uint32_t h = 0;
#ifdef MSWIN
  if (ASCII_ISALPHA(*p) && p[1] == ':') {
    p += 2;
  }
#endif
  bool ic = false;
#ifdef CASE_INSENSITIVE_FILENAME
  ic = true;
#endif
  const char *start = p;
  for (int len = 0; *p; p += len) {
    if (vim_ispathsep_nocolon(*p)
        && p[1] == NUL
        && start != p
        && !vim_ispathsep(p[-1])) {
      break;
    }
    int c = path_fold_char(ic, p, &len);
    h = (h << 5) - h + (uint32_t)c;
  }
  return h;
}

static inline bool equal_path_t(const char *a, const char *b)
{
  if (a == b) {
    return true;
  }
  if (a == NULL || b == NULL) {
    return false;
  }
  bool ic = false;
#ifdef CASE_INSENSITIVE_FILENAME
  ic = true;
#endif
  return path_cmp(ic, a, b, MAXPATHL) == 0;
}

static inline uint32_t hash_HlEntry(HlEntry ae)
{
  const uint8_t *data = (const uint8_t *)&ae;
  uint32_t h = 0;
  for (size_t i = 0; i < sizeof(ae); i++) {
    h = (h << 5) - h + data[i];
  }
  return h;
}

static inline bool equal_HlEntry(HlEntry ae1, HlEntry ae2)
{
  return memcmp(&ae1, &ae2, sizeof(ae1)) == 0;
}

static inline uint32_t hash_ColorKey(ColorKey ae)
{
  const uint8_t *data = (const uint8_t *)&ae;
  uint32_t h = 0;
  for (size_t i = 0; i < sizeof(ae); i++) {
    h = (h << 5) - h + data[i];
  }
  return h;
}

static inline bool equal_ColorKey(ColorKey ae1, ColorKey ae2)
{
  return memcmp(&ae1, &ae2, sizeof(ae1)) == 0;
}

// TODO(bfredl): this could be _less_ for the h->hash part as this is now small (4 bytes per value)
#define UPPER_FILL 0.77

#define roundup32(x) (--(x), (x) |= (x)>>1, (x) |= (x)>>2, (x) |= (x)>>4, (x) |= (x)>>8, \
                      (x) |= (x)>>16, ++(x))

// h->hash must either be NULL or an already valid pointer
void mh_realloc(MapHash *h, uint32_t n_min_buckets)
{
  xfree(h->hash);
  uint32_t n_buckets = n_min_buckets < 16 ? 16 : n_min_buckets;
  roundup32(n_buckets);
  // sets all buckets to EMPTY
  h->hash = xcalloc(n_buckets, sizeof *h->hash);
  h->n_occupied = h->size = 0;
  h->n_buckets = n_buckets;
  h->upper_bound = (uint32_t)(h->n_buckets * UPPER_FILL + 0.5);
}

void mh_clear(MapHash *h)
{
  if (h->hash) {
    memset(h->hash, 0, h->n_buckets * sizeof(*h->hash));
    h->size = h->n_occupied = 0;
    h->n_keys = 0;
  }
}

#define KEY_NAME(x) x##int
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, ptr_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, String)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, StcClick)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, StcClicks)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

#define KEY_NAME(x) x##ptr_t
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, ptr_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

#define KEY_NAME(x) x##cstr_t
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, ptr_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, int)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

#define KEY_NAME(x) x##path_t
#include "nvim/map_key_impl.c.h"
#undef KEY_NAME

#define KEY_NAME(x) x##String
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, int)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

#define KEY_NAME(x) x##uint32_t
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, ptr_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, uint32_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

#define KEY_NAME(x) x##uint64_t
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, ptr_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, int)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, MTDamagePair)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

#define KEY_NAME(x) x##int64_t
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, ptr_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#define VAL_NAME(x) quasiquote(x, int64_t)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

#define KEY_NAME(x) x##HlEntry
#include "nvim/map_key_impl.c.h"
#undef KEY_NAME

#define KEY_NAME(x) x##ColorKey
#include "nvim/map_key_impl.c.h"
#define VAL_NAME(x) quasiquote(x, ColorItem)
#include "nvim/map_value_impl.c.h"
#undef VAL_NAME
#undef KEY_NAME

/// Deletes a key:value pair from a string:pointer map, and frees the
/// storage of both key and value.
///
void pmap_del2(PMap(cstr_t) *map, const char *key)
{
  cstr_t key_alloc = NULL;
  ptr_t val = pmap_del(cstr_t)(map, key, &key_alloc);
  xfree((void *)key_alloc);
  xfree(val);
}
