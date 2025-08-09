#pragma once

#include <stddef.h>

#include "nvim/hashtab_defs.h"  // IWYU pragma: keep

/// Magic number used for hashitem "hi_key" value indicating a deleted item
///
/// Only the address is used.
extern char hash_removed;

/// The address of "hash_removed" is used as a magic number
/// for hi_key to indicate a removed item.
#define HI_KEY_REMOVED (&hash_removed)
#define HASHITEM_EMPTY(hi) ((hi)->hi_key == NULL || (hi)->hi_key == &hash_removed)

/// Iterate over a hashtab
///
/// @param[in]  ht  Hashtab to iterate over.
/// @param  hi  Name of the variable with current hashtab entry.
/// @param  code  Cycle body.
#define HASHTAB_ITER(ht, hi, code) \
  do { \
    hashtab_T *const hi##ht_ = (ht); \
    size_t hi##todo_ = hi##ht_->ht_used; \
    for (hashitem_T *hi = hi##ht_->ht_array; hi##todo_; hi++) { \
      if (!HASHITEM_EMPTY(hi)) { \
        hi##todo_--; \
        { \
          code \
        } \
      } \
    } \
  } while (0)

#include "hashtab.h.generated.h"
