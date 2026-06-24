// map.c: Hash maps and sets
//
// parts of the implementation derived from khash.h as part of klib (MIT license)
//
// NOTE: Callers must manage memory (allocate) for keys and values.
//       Map and Set does not make its own copy of the key or value.

#include <stdbool.h>
#include <string.h>

#include "auto/config.h"
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
/// str_foldcase, the same fold used by mb_stricmp/path_fnamencmp) so the hash↔equality invariant
/// holds.
///
/// On Windows we additionally:
///   - fold '\\' -> '/'   (path_fnamencmp treats them as equal)
///   - drop a leading drive letter "[A-Za-z]:" so that "C:\foo" and "\foo" land in the same bucket
///     (path_fnamencmp considers them equal when the current drive matches the explicit drive
///     letter). Two paths with *different* explicit drives ("C:\foo" vs "D:\foo") may now
///     share a bucket — that's a permitted collision; equal_path_t still rejects them.
///
/// path_fnamencmp's non-Windows branch consults &fileignorecase, which is runtime-mutable and would
/// break the hash invariant if flipped. So the macOS branch deliberately bypasses path_fnamencmp
/// and uses the compile-time CASE_INSENSITIVE_FILENAME switch instead.
static inline uint32_t hash_path_t(const char *p)
{
#ifdef BACKSLASH_IN_FILENAME
  if (p[1] == ':' && ASCII_ISALPHA(p[0])) {
    p += 2;
  }
#endif
#ifdef CASE_INSENSITIVE_FILENAME
  char *folded = str_foldcase((char *)p, (int)strlen(p), NULL, 0);
  uint32_t h = hash_cstr_t(folded);
  xfree(folded);
  return h;
#else
  return hash_cstr_t(p);
#endif
}

static inline bool equal_path_t(const char *a, const char *b)
{
  if (a == b) {
    return true;
  }
  if (a == NULL || b == NULL) {
    return false;
  }
#ifdef BACKSLASH_IN_FILENAME
  // Inherit Windows-mode slash, drive-letter, and case folding.
  size_t la = strlen(a);
  size_t lb = strlen(b);
  return path_fnamencmp(a, b, MAX(la, lb)) == 0;
#elif defined(CASE_INSENSITIVE_FILENAME)
  return mb_stricmp(a, b) == 0;
#else
  return strequal(a, b);
#endif
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
