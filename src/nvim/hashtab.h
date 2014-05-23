#ifndef NVIM_HASHTAB_H
#define NVIM_HASHTAB_H

#include "nvim/vim.h"

/// Type for hash number (hash calculation result).
typedef long_u hash_T;          

/// The address of "hash_removed" is used as a magic number
/// for hi_key to indicate a removed item. 
#define HI_KEY_REMOVED &hash_removed
#define HASHITEM_EMPTY(hi) ((hi)->hi_key == NULL \
                            || (hi)->hi_key == &hash_removed)

/// A hastable item.
///
/// Each item has a NUL terminated string key.
/// A key can appear only once in the table.
///
/// A hash number is computed from the key for quick lookup.  When the hashes
/// of two different keys point to the same entry an algorithm is used to
/// iterate over other entries in the table until the right one is found.
/// To make the iteration work removed keys are different from entries where a
/// key was never present.
///
/// Note that this does not contain a pointer to the key and another pointer to
/// the value. Instead, it is assumed that the key is contained within the
/// value, so that you can get a pointer to the value subtracting an offset from
/// the pointer to the key.
/// This reduces the size of this item by 1/3.
typedef struct hashitem_S {
  /// Cached hash number for hi_key.
  hash_T hi_hash;

  /// Item key.
  /// 
  /// Possible values mean the following:
  /// NULL                      : Item was never used.
  /// HI_KEY_REMOVED            : Item was removed.
  /// (Any other pointer value) : Item is currently being used.
  char_u *hi_key;
} hashitem_T;

/// Initial size for a hashtable.
/// Our items are relatively small and growing is expensive, thus start with 16.
/// Must be a power of 2. 
#define HT_INIT_SIZE 16

/// An array-based hashtable.
///
/// Keys are NUL terminated strings. They cannot be repeated within a table.
/// Values are of any type.
///
/// The hashtable grows to accommodate more entries when needed.
typedef struct hashtable_S {
  long_u ht_mask;               /// mask used for hash value
                                /// (nr of items in array is "ht_mask" + 1)
  long_u ht_used;               /// number of items used
  long_u ht_filled;             /// number of items used or removed
  int ht_locked;                /// counter for hash_lock()
  int ht_error;                 /// when set growing failed, can't add more
                                /// items before growing works
  hashitem_T *ht_array;         /// points to the array, allocated when it's
                                /// not "ht_smallarray"
  hashitem_T ht_smallarray[HT_INIT_SIZE];      /// initial array
} hashtab_T;

// hashtab.c
void hash_init(hashtab_T *ht);
void hash_clear(hashtab_T *ht);
void hash_clear_all(hashtab_T *ht, int off);
hashitem_T *hash_find(hashtab_T *ht, char_u *key);
hashitem_T *hash_lookup(hashtab_T *ht, char_u *key, hash_T hash);
void hash_debug_results(void);
int hash_add(hashtab_T *ht, char_u *key);
int hash_add_item(hashtab_T *ht, hashitem_T *hi, char_u *key, hash_T hash);
void hash_remove(hashtab_T *ht, hashitem_T *hi);
void hash_lock(hashtab_T *ht);
void hash_unlock(hashtab_T *ht);
hash_T hash_hash(char_u *key);

#endif /* NVIM_HASHTAB_H */
