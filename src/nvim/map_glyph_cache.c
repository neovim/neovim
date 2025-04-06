// Specialized version of Set() where interned strings is stored in a compact,
// NUL-separated char array.
// `String key` lookup keys don't need to be NULL terminated, but they
// must not contain embedded NUL:s. When reading a key from set->keys, they
// are always NUL terminated, though. Thus, it is enough to store an index into
// this array, and use strlen(), to retrieve an interned key.

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/memory.h"

uint32_t mh_find_bucket_glyph(Set(glyph) *set, String key, bool put)
{
  MapHash *h = &set->h;
  uint32_t step = 0;
  uint32_t mask = h->n_buckets - 1;
  uint32_t k = hash_String(key);
  uint32_t i = k & mask;
  uint32_t last = i;
  uint32_t site = put ? last : MH_TOMBSTONE;
  while (!mh_is_empty(h, i)) {
    if (mh_is_del(h, i)) {
      if (site == last) {
        site = i;
      }
    } else if (equal_String(cstr_as_string(&set->keys[h->hash[i] - 1]), key)) {
      return i;
    }
    i = (i + (++step)) & mask;
    if (i == last) {
      abort();
    }
  }
  if (site == last) {
    site = i;
  }
  return site;
}

/// @return index into set->keys if found, MH_TOMBSTONE otherwise
uint32_t mh_get_glyph(Set(glyph) *set, String key)
{
  if (set->h.n_buckets == 0) {
    return MH_TOMBSTONE;
  }
  uint32_t idx = mh_find_bucket_glyph(set, key, false);
  return (idx != MH_TOMBSTONE) ? set->h.hash[idx] - 1 : MH_TOMBSTONE;
}

void mh_rehash_glyph(Set(glyph) *set)
{
  // assume the format of set->keys, i e NUL terminated strings
  for (uint32_t k = 0; k < set->h.n_keys; k += (uint32_t)strlen(&set->keys[k]) + 1) {
    uint32_t idx = mh_find_bucket_glyph(set, cstr_as_string(&set->keys[k]), true);
    // there must be tombstones when we do a rehash
    if (!mh_is_empty((&set->h), idx)) {
      abort();
    }
    set->h.hash[idx] = k + 1;
  }
  set->h.n_occupied = set->h.size = set->h.n_keys;
}

uint32_t mh_put_glyph(Set(glyph) *set, String key, MHPutStatus *new)
{
  MapHash *h = &set->h;
  // Might rehash ahead of time if "key" already existed. But it was
  // going to happen soon anyway.
  if (h->n_occupied >= h->upper_bound) {
    mh_realloc(h, h->n_buckets + 1);
    mh_rehash_glyph(set);
  }

  uint32_t idx = mh_find_bucket_glyph(set, key, true);

  if (mh_is_either(h, idx)) {
    h->size++;
    h->n_occupied++;

    uint32_t size = (uint32_t)key.size + 1;  // NUL takes space
    uint32_t pos = h->n_keys;
    h->n_keys += size;
    if (h->n_keys > h->keys_capacity) {
      h->keys_capacity = MAX(h->keys_capacity * 2, 64);
      set->keys = xrealloc(set->keys, h->keys_capacity * sizeof(char));
      *new = kMHNewKeyRealloc;
    } else {
      *new = kMHNewKeyDidFit;
    }
    memcpy(&set->keys[pos], key.data, key.size);
    set->keys[pos + key.size] = NUL;
    h->hash[idx] = pos + 1;
    return pos;
  } else {
    *new = kMHExisting;
    uint32_t pos = h->hash[idx] - 1;
    assert(equal_String(cstr_as_string(&set->keys[pos]), key));
    return pos;
  }
}
