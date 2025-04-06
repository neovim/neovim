#pragma once

#include <stddef.h>

/// Type for hash number (hash calculation result).
typedef size_t hash_T;

/// Hashtable item.
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
typedef struct {
  /// Cached hash number for hi_key.
  hash_T hi_hash;

  /// Item key.
  ///
  /// Possible values mean the following:
  /// NULL                      : Item was never used.
  /// HI_KEY_REMOVED            : Item was removed.
  /// (Any other pointer value) : Item is currently being used.
  char *hi_key;
} hashitem_T;

enum {
  /// Initial size for a hashtable.
  /// Our items are relatively small and growing is expensive, thus start with 16.
  /// Must be a power of 2.
  /// This allows for storing 10 items (2/3 of 16) before a resize is needed.
  HT_INIT_SIZE = 16,
};

/// An array-based hashtable.
///
/// Keys are NUL terminated strings. They cannot be repeated within a table.
/// Values are of any type.
///
/// The hashtable grows to accommodate more entries when needed.
typedef struct {
  hash_T ht_mask;        ///< mask used for hash value
                         ///< (nr of items in array is "ht_mask" + 1)
  size_t ht_used;        ///< number of items used
  size_t ht_filled;      ///< number of items used or removed
  int ht_changed;        ///< incremented when adding or removing an item
  int ht_locked;         ///< counter for hash_lock()
  hashitem_T *ht_array;  ///< points to the array, allocated when it's
                         ///< not "ht_smallarray"
  hashitem_T ht_smallarray[HT_INIT_SIZE];  ///< initial array
} hashtab_T;
