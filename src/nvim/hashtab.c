// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file hashtab.c
///
/// Handling of a hashtable with Vim-specific properties.
///
/// Each item in a hashtable has a NUL terminated string key. A key can appear
/// only once in the table.
///
/// A hash number is computed from the key for quick lookup. When the hashes
/// of two different keys point to the same entry an algorithm is used to
/// iterate over other entries in the table until the right one is found.
/// To make the iteration work removed keys are different from entries where a
/// key was never present.
///
/// The mechanism has been partly based on how Python Dictionaries are
/// implemented. The algorithm is from Knuth Vol. 3, Sec. 6.4.
///
/// The hashtable grows to accommodate more entries when needed. At least 1/3
/// of the entries is empty to keep the lookup efficient (at the cost of extra
/// memory).

#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include <inttypes.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/hashtab.h"
#include "nvim/message.h"
#include "nvim/memory.h"

// Magic value for algorithm that walks through the array.
#define PERTURB_SHIFT 5

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "hashtab.c.generated.h"
#endif

char hash_removed;

/// Initialize an empty hash table.
void hash_init(hashtab_T *ht)
{
  // This zeroes all "ht_" entries and all the "hi_key" in "ht_smallarray".
  memset(ht, 0, sizeof(hashtab_T));
  ht->ht_array = ht->ht_smallarray;
  ht->ht_mask = HT_INIT_SIZE - 1;
}

/// Free the array of a hash table without freeing contained values.
///
/// If "ht" is not freed (after calling this) then you should call hash_init()
/// right next!
void hash_clear(hashtab_T *ht)
{
  if (ht->ht_array != ht->ht_smallarray) {
    xfree(ht->ht_array);
  }
}

/// Free the array of a hash table and all contained values.
///
/// @param off the offset from start of value to start of key (@see hashitem_T).
void hash_clear_all(hashtab_T *ht, unsigned int off)
{
  size_t todo = ht->ht_used;
  for (hashitem_T *hi = ht->ht_array; todo > 0; ++hi) {
    if (!HASHITEM_EMPTY(hi)) {
      xfree(hi->hi_key - off);
      todo--;
    }
  }
  hash_clear(ht);
}

/// Find item for given "key" in hashtable "ht".
///
/// @param key The key of the looked-for item. Must not be NULL.
///
/// @return Pointer to the hash item corresponding to the given key.
///         If not found, then return pointer to the empty item that would be
///         used for that key.
///         WARNING: Returned pointer becomes invalid as soon as the hash table
///                  is changed in any way.
hashitem_T *hash_find(const hashtab_T *const ht, const char_u *const key)
{
  return hash_lookup(ht, (const char *)key, STRLEN(key), hash_hash(key));
}

/// Like hash_find, but key is not NUL-terminated
///
/// @param[in]  ht  Hashtab to look in.
/// @param[in]  key  Key of the looked-for item. Must not be NULL.
/// @param[in]  len  Key length.
///
/// @return Pointer to the hash item corresponding to the given key.
///         If not found, then return pointer to the empty item that would be
///         used for that key.
///
///         @warning Returned pointer becomes invalid as soon as the hash table
///                  is changed in any way.
hashitem_T *hash_find_len(const hashtab_T *const ht, const char *const key,
                          const size_t len)
{
  return hash_lookup(ht, key, len, hash_hash_len(key, len));
}

/// Like hash_find(), but caller computes "hash".
///
/// @param[in]  key  The key of the looked-for item. Must not be NULL.
/// @param[in]  key_len  Key length.
/// @param[in]  hash  The precomputed hash for the key.
///
/// @return Pointer to the hashitem corresponding to the given key.
///         If not found, then return pointer to the empty item that would be
///         used for that key.
///         WARNING: Returned pointer becomes invalid as soon as the hash table
///                  is changed in any way.
hashitem_T *hash_lookup(const hashtab_T *const ht,
                        const char *const key, const size_t key_len,
                        const hash_T hash)
{
#ifdef HT_DEBUG
  hash_count_lookup++;
#endif  // ifdef HT_DEBUG

  // Quickly handle the most common situations:
  // - return if there is no item at all
  // - skip over a removed item
  // - return if the item matches
  hash_T idx = hash & ht->ht_mask;
  hashitem_T *hi = &ht->ht_array[idx];

  if (hi->hi_key == NULL) {
    return hi;
  }

  hashitem_T *freeitem = NULL;
  if (hi->hi_key == HI_KEY_REMOVED) {
    freeitem = hi;
  } else if ((hi->hi_hash == hash)
             && (STRNCMP(hi->hi_key, key, key_len) == 0)
             && hi->hi_key[key_len] == NUL) {
    return hi;
  }

  // Need to search through the table to find the key. The algorithm
  // to step through the table starts with large steps, gradually becoming
  // smaller down to (1/4 table size + 1). This means it goes through all
  // table entries in the end.
  // When we run into a NULL key it's clear that the key isn't there.
  // Return the first available slot found (can be a slot of a removed
  // item).
  for (hash_T perturb = hash;; perturb >>= PERTURB_SHIFT) {
#ifdef HT_DEBUG
    // count a "miss" for hashtab lookup
    hash_count_perturb++;
#endif  // ifdef HT_DEBUG
    idx = 5 * idx + perturb + 1;
    hi = &ht->ht_array[idx & ht->ht_mask];

    if (hi->hi_key == NULL) {
      return freeitem == NULL ? hi : freeitem;
    }

    if ((hi->hi_hash == hash)
        && (hi->hi_key != HI_KEY_REMOVED)
        && (STRNCMP(hi->hi_key, key, key_len) == 0)
        && hi->hi_key[key_len] == NUL) {
      return hi;
    }

    if ((hi->hi_key == HI_KEY_REMOVED) && (freeitem == NULL)) {
      freeitem = hi;
    }
  }
}

/// Print the efficiency of hashtable lookups.
///
/// Useful when trying different hash algorithms.
/// Called when exiting.
void hash_debug_results(void)
{
#ifdef HT_DEBUG
  fprintf(stderr, "\r\n\r\n\r\n\r\n");
  fprintf(stderr, "Number of hashtable lookups: %" PRId64 "\r\n",
          (int64_t)hash_count_lookup);
  fprintf(stderr, "Number of perturb loops: %" PRId64 "\r\n",
          (int64_t)hash_count_perturb);
  fprintf(stderr, "Percentage of perturb loops: %" PRId64 "%%\r\n",
          (int64_t)(hash_count_perturb * 100 / hash_count_lookup));
#endif  // ifdef HT_DEBUG
}

/// Add item for key "key" to hashtable "ht".
///
/// @param key Pointer to the key for the new item. The key has to be contained
///            in the new item (@see hashitem_T). Must not be NULL.
///
/// @return OK   if success.
///         FAIL if key already present
int hash_add(hashtab_T *ht, char_u *key)
{
  hash_T hash = hash_hash(key);
  hashitem_T *hi = hash_lookup(ht, (const char *)key, STRLEN(key), hash);
  if (!HASHITEM_EMPTY(hi)) {
    internal_error("hash_add()");
    return FAIL;
  }
  hash_add_item(ht, hi, key, hash);
  return OK;
}

/// Add item "hi" for key "key" to hashtable "ht".
///
/// @param hi   The hash item to be used. Must have been obtained through
///             hash_lookup() and point to an empty item.
/// @param key  Pointer to the key for the new item. The key has to be contained
///             in the new item (@see hashitem_T). Must not be NULL.
/// @param hash The precomputed hash value for the key.
void hash_add_item(hashtab_T *ht, hashitem_T *hi, char_u *key, hash_T hash)
{
  ht->ht_used++;
  if (hi->hi_key == NULL) {
    ht->ht_filled++;
  }
  hi->hi_key = key;
  hi->hi_hash = hash;

  // When the space gets low may resize the array.
  hash_may_resize(ht, 0);
}

/// Remove item "hi" from hashtable "ht".
///
/// Caller must take care of freeing the item itself.
///
/// @param hi The hash item to be removed.
///           It must have been obtained with hash_lookup().
void hash_remove(hashtab_T *ht, hashitem_T *hi)
{
  ht->ht_used--;
  hi->hi_key = HI_KEY_REMOVED;
  hash_may_resize(ht, 0);
}

/// Lock hashtable (prevent changes in ht_array).
///
/// Don't use this when items are to be added!
/// Must call hash_unlock() later.
void hash_lock(hashtab_T *ht)
{
  ht->ht_locked++;
}

/// Unlock hashtable (allow changes in ht_array again).
///
/// Table will be resized (shrunk) when necessary.
/// This must balance a call to hash_lock().
void hash_unlock(hashtab_T *ht)
{
  ht->ht_locked--;
  hash_may_resize(ht, 0);
}

/// Resize hastable (new size can be given or automatically computed).
///
/// @param minitems Minimum number of items the new table should hold.
///                 If zero, new size will depend on currently used items:
///                 - Shrink when too much empty space.
///                 - Grow when not enough empty space.
///                 If non-zero, passed minitems will be used.
static void hash_may_resize(hashtab_T *ht, size_t minitems)
{
  // Don't resize a locked table.
  if (ht->ht_locked > 0) {
    return;
  }

#ifdef HT_DEBUG
  if (ht->ht_used > ht->ht_filled) {
    EMSG("hash_may_resize(): more used than filled");
  }

  if (ht->ht_filled >= ht->ht_mask + 1) {
    EMSG("hash_may_resize(): table completely filled");
  }
#endif  // ifdef HT_DEBUG

  size_t minsize;
  if (minitems == 0) {
    // Return quickly for small tables with at least two NULL items.
    // items are required for the lookup to decide a key isn't there.
    if ((ht->ht_filled < HT_INIT_SIZE - 1)
        && (ht->ht_array == ht->ht_smallarray)) {
      return;
    }

    // Grow or refill the array when it's more than 2/3 full (including
    // removed items, so that they get cleaned up).
    // Shrink the array when it's less than 1/5 full. When growing it is
    // at least 1/4 full (avoids repeated grow-shrink operations)
    size_t oldsize = ht->ht_mask + 1;
    if ((ht->ht_filled * 3 < oldsize * 2) && (ht->ht_used > oldsize / 5)) {
      return;
    }

    if (ht->ht_used > 1000) {
      // it's big, don't make too much room
      minsize = ht->ht_used * 2;
    } else {
      // make plenty of room
      minsize = ht->ht_used * 4;
    }
  } else {
    // Use specified size.
    if (minitems < ht->ht_used) {
      // just in case...
      minitems = ht->ht_used;
    }
    // array is up to 2/3 full
    minsize = minitems * 3 / 2;
  }

  size_t newsize = HT_INIT_SIZE;
  while (newsize < minsize) {
    // make sure it's always a power of 2
    newsize <<= 1;
    // assert newsize didn't overflow
    assert(newsize != 0);
  }

  bool newarray_is_small = newsize == HT_INIT_SIZE;
  bool keep_smallarray = newarray_is_small
    && ht->ht_array == ht->ht_smallarray;

  // Make sure that oldarray and newarray do not overlap,
  // so that copying is possible.
  hashitem_T temparray[HT_INIT_SIZE];
  hashitem_T *oldarray = keep_smallarray
    ? memcpy(temparray, ht->ht_smallarray, sizeof(temparray))
    : ht->ht_array;
  hashitem_T *newarray = newarray_is_small
    ? ht->ht_smallarray
    : xmalloc(sizeof(hashitem_T) * newsize);

  memset(newarray, 0, sizeof(hashitem_T) * newsize);

  // Move all the items from the old array to the new one, placing them in
  // the right spot. The new array won't have any removed items, thus this
  // is also a cleanup action.
  hash_T newmask = newsize - 1;
  size_t todo = ht->ht_used;

  for (hashitem_T *olditem = oldarray; todo > 0; ++olditem) {
    if (HASHITEM_EMPTY(olditem)) {
      continue;
    }
    // The algorithm to find the spot to add the item is identical to
    // the algorithm to find an item in hash_lookup(). But we only
    // need to search for a NULL key, thus it's simpler.
    hash_T newi = olditem->hi_hash & newmask;
    hashitem_T *newitem = &newarray[newi];
    if (newitem->hi_key != NULL) {
      for (hash_T perturb = olditem->hi_hash;; perturb >>= PERTURB_SHIFT) {
        newi = 5 * newi + perturb + 1;
        newitem = &newarray[newi & newmask];
        if (newitem->hi_key == NULL) {
          break;
        }
      }
    }
    *newitem = *olditem;
    todo--;
  }

  if (ht->ht_array != ht->ht_smallarray) {
    xfree(ht->ht_array);
  }
  ht->ht_array = newarray;
  ht->ht_mask = newmask;
  ht->ht_filled = ht->ht_used;
}

#define HASH_CYCLE_BODY(hash, p) \
    hash = hash * 101 + *p++

/// Get the hash number for a key.
///
/// If you think you know a better hash function: Compile with HT_DEBUG set and
/// run a script that uses hashtables a lot. Vim will then print statistics
/// when exiting. Try that with the current hash algorithm and yours. The
/// lower the percentage the better.
hash_T hash_hash(const char_u *key)
{
  hash_T hash = *key;

  if (hash == 0) {
    return (hash_T)0;
  }

  // A simplistic algorithm that appears to do very well.
  // Suggested by George Reilly.
  const uint8_t *p = key + 1;
  while (*p != NUL) {
    HASH_CYCLE_BODY(hash, p);
  }

  return hash;
}

/// Get the hash number for a key that is not a NUL-terminated string
///
/// @warning Function does not check whether key contains NUL. But you will not
///          be able to get hash entry in this case.
///
/// @param[in]  key  Key.
/// @param[in]  len  Key length.
///
/// @return Key hash.
hash_T hash_hash_len(const char *key, const size_t len)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (len == 0) {
    return 0;
  }

  hash_T hash = *(uint8_t *)key;
  const uint8_t *end = (uint8_t *)key + len;

  const uint8_t *p = (const uint8_t *)key + 1;
  while (p < end) {
    HASH_CYCLE_BODY(hash, p);
  }

  return hash;
}

#undef HASH_CYCLE_BODY

/// Function to get HI_KEY_REMOVED value
///
/// Used for testing because luajit ffi does not allow getting addresses of
/// globals.
const char_u *_hash_key_removed(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return HI_KEY_REMOVED;
}
