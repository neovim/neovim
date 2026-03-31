#include "nvim/map_defs.h"
#include "nvim/memory.h"

#ifndef KEY_NAME
// Don't error out. it is nice to type-check the file in isolation, in clangd or otherwise
# define KEY_NAME(x) x##int
# define hash_int(x) ((uint32_t)x)
# define equal_int(x, y) ((x) == (y))
#endif

#define SET_TYPE KEY_NAME(Set_)
#define KEY_TYPE KEY_NAME()

/// find bucket to get or put "key"
///
/// set->h.hash assumed already allocated!
///
/// @return bucket index, or MH_TOMBSTONE if not found and `put` was false
///         mh_is_either(hash[rv]) : not found, but this is the place to put
///         otherwise: hash[rv]-1 is index into key/value arrays
uint32_t KEY_NAME(mh_find_bucket_)(SET_TYPE *set, KEY_TYPE key, bool put)
{
  MapHash *h = &set->h;
  uint32_t step = 0;
  uint32_t mask = h->n_buckets - 1;
  uint32_t k = KEY_NAME(hash_)(key);
  uint32_t i = k & mask;
  uint32_t last = i;
  uint32_t site = put ? last : MH_TOMBSTONE;
  while (!mh_is_empty(h, i)) {
    if (mh_is_del(h, i)) {
      if (site == last) {
        site = i;
      }
    } else if (KEY_NAME(equal_)(set->keys[h->hash[i] - 1], key)) {
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
uint32_t KEY_NAME(mh_get_)(SET_TYPE *set, KEY_TYPE key)
{
  if (set->h.n_buckets == 0) {
    return MH_TOMBSTONE;
  }
  uint32_t idx = KEY_NAME(mh_find_bucket_)(set, key, false);
  return (idx != MH_TOMBSTONE) ? set->h.hash[idx] - 1 : MH_TOMBSTONE;
}

/// Rebuild hash from keys[] array
///
/// set->h.hash must be allocated and empty before&alling!
void KEY_NAME(mh_rehash_)(SET_TYPE *set)
{
  for (uint32_t k = 0; k < set->h.n_keys; k++) {
    uint32_t idx = KEY_NAME(mh_find_bucket_)(set, set->keys[k], true);
    // there must be tombstones when we do a rehash
    if (!mh_is_empty((&set->h), idx)) {
      abort();
    }
    set->h.hash[idx] = k + 1;
  }
  set->h.n_occupied = set->h.size = set->h.n_keys;
}

/// Put a key. Return the existing item if found
///
/// Allocates/resizes the hash table and/or keys[] table if needed.
///
/// @param[out] new mandatory. Reveals if an existing key was found. In addition,
///                 if new item, indicates if keys[] was resized.
///
/// @return keys index
uint32_t KEY_NAME(mh_put_)(SET_TYPE *set, KEY_TYPE key, MHPutStatus *new)
{
  MapHash *h = &set->h;
  // Might rehash ahead of time if "key" already existed. But it was
  // going to happen soon anyway.
  if (h->n_occupied >= h->upper_bound) {
    // If we likely were to resize soon, do it now to avoid extra rehash
    // TODO(bfredl): we never shrink. but maybe that's fine
    if (h->size >= h->upper_bound * 0.9) {
      mh_realloc(h, h->n_buckets + 1);
    } else {
      // Just a lot of tombstones from deleted items, start all over again
      memset(h->hash, 0, h->n_buckets * sizeof(*h->hash));
      h->size = h->n_occupied = 0;
    }
    KEY_NAME(mh_rehash_)(set);
  }

  uint32_t idx = KEY_NAME(mh_find_bucket_)(set, key, true);

  if (mh_is_either(h, idx)) {
    h->size++;
    if (mh_is_empty(h, idx)) {
      h->n_occupied++;
    }

    uint32_t pos = h->n_keys++;
    if (pos >= h->keys_capacity) {
      h->keys_capacity = MAX(h->keys_capacity * 2, 8);
      set->keys = xrealloc(set->keys, h->keys_capacity * sizeof(KEY_TYPE));
      *new = kMHNewKeyRealloc;
    } else {
      *new = kMHNewKeyDidFit;
    }
    set->keys[pos] = key;
    h->hash[idx] = pos + 1;
    return pos;
  } else {
    *new = kMHExisting;
    uint32_t pos = h->hash[idx] - 1;
    if (!KEY_NAME(equal_)(set->keys[pos], key)) {
      abort();
    }
    return pos;
  }
}

/// Deletes `*key` if found, do nothing otherwise
///
/// @param[in, out] key modified to the value contained in the set
/// @return the index the item used to have in keys[]
///         MH_TOMBSTONE if key was not found
uint32_t KEY_NAME(mh_delete_)(SET_TYPE *set, KEY_TYPE *key)
{
  if (set->h.size == 0) {
    return MH_TOMBSTONE;
  }
  uint32_t idx = KEY_NAME(mh_find_bucket_)(set, *key, false);
  if (idx != MH_TOMBSTONE) {
    uint32_t k = set->h.hash[idx] - 1;
    set->h.hash[idx] = MH_TOMBSTONE;

    uint32_t last = --set->h.n_keys;
    *key = set->keys[k];
    set->h.size--;
    if (last != k) {
      uint32_t idx2 = KEY_NAME(mh_find_bucket_)(set, set->keys[last], false);
      if (set->h.hash[idx2] != last + 1) {
        abort();
      }
      set->h.hash[idx2] = k + 1;
      set->keys[k] = set->keys[last];
    }
    return k;
  }
  return MH_TOMBSTONE;
}
