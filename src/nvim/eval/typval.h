#ifndef NVIM_EVAL_TYPVAL_H
#define NVIM_EVAL_TYPVAL_H

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/func_attr.h"
#include "nvim/garray.h"
#include "nvim/gettext.h"
#include "nvim/hashtab.h"
#include "nvim/lib/queue.h"
#include "nvim/macros.h"
#include "nvim/mbyte_defs.h"
#include "nvim/message.h"
#include "nvim/types.h"

// In a hashtab item "hi_key" points to "di_key" in a dictitem.
// This avoids adding a pointer to the hashtab item.

/// Convert a hashitem pointer to a dictitem pointer
#define TV_DICT_HI2DI(hi) \
  ((dictitem_T *)((hi)->hi_key - offsetof(dictitem_T, di_key)))

static inline void tv_list_ref(list_T *l)
  REAL_FATTR_ALWAYS_INLINE;

/// Increase reference count for a given list
///
/// Does nothing for NULL lists.
///
/// @param[in,out]  l  List to modify.
static inline void tv_list_ref(list_T *const l)
{
  if (l == NULL) {
    return;
  }
  l->lv_refcount++;
}

static inline void tv_list_set_ret(typval_T *tv, list_T *l)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ARG(1);

/// Set a list as the return value.  Increments the reference count.
///
/// @param[out]  tv  Object to receive the list
/// @param[in,out]  l  List to pass to the object
static inline void tv_list_set_ret(typval_T *const tv, list_T *const l)
{
  tv->v_type = VAR_LIST;
  tv->vval.v_list = l;
  tv_list_ref(l);
}

static inline VarLockStatus tv_list_locked(const list_T *l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Get list lock status
///
/// Returns VAR_FIXED for NULL lists.
///
/// @param[in]  l  List to check.
static inline VarLockStatus tv_list_locked(const list_T *const l)
{
  if (l == NULL) {
    return VAR_FIXED;
  }
  return l->lv_lock;
}

/// Set list lock status
///
/// May only “set” VAR_FIXED for NULL lists.
///
/// @param[out]  l  List to modify.
/// @param[in]  lock  New lock status.
static inline void tv_list_set_lock(list_T *const l, const VarLockStatus lock)
{
  if (l == NULL) {
    assert(lock == VAR_FIXED);
    return;
  }
  l->lv_lock = lock;
}

/// Set list copyID
///
/// Does not expect NULL list, be careful.
///
/// @param[out]  l  List to modify.
/// @param[in]  copyid  New copyID.
static inline void tv_list_set_copyid(list_T *const l, const int copyid)
  FUNC_ATTR_NONNULL_ALL
{
  l->lv_copyID = copyid;
}

static inline int tv_list_len(const list_T *l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Get the number of items in a list
///
/// @param[in]  l  List to check.
static inline int tv_list_len(const list_T *const l)
{
  if (l == NULL) {
    return 0;
  }
  return l->lv_len;
}

static inline int tv_list_copyid(const list_T *l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_NONNULL_ALL;

/// Get list copyID
///
/// Does not expect NULL list, be careful.
///
/// @param[in]  l  List to check.
static inline int tv_list_copyid(const list_T *const l)
{
  return l->lv_copyID;
}

static inline list_T *tv_list_latest_copy(const list_T *l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_NONNULL_ALL;

/// Get latest list copy
///
/// Gets lv_copylist field assigned by tv_list_copy() earlier.
///
/// Does not expect NULL list, be careful.
///
/// @param[in]  l  List to check.
static inline list_T *tv_list_latest_copy(const list_T *const l)
{
  return l->lv_copylist;
}

static inline int tv_list_uidx(const list_T *l, int n)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Normalize index: that is, return either -1 or non-negative index
///
/// @param[in]  l  List to index. Used to get length.
/// @param[in]  n  List index, possibly negative.
///
/// @return -1 or list index in range [0, tv_list_len(l)).
static inline int tv_list_uidx(const list_T *const l, int n)
{
  // Negative index is relative to the end.
  if (n < 0) {
    n += tv_list_len(l);
  }

  // Check for index out of range.
  if (n < 0 || n >= tv_list_len(l)) {
    return -1;
  }
  return n;
}

static inline bool tv_list_has_watchers(const list_T *l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Check whether list has watchers
///
/// E.g. is referenced by a :for loop.
///
/// @param[in]  l  List to check.
///
/// @return true if there are watchers, false otherwise.
static inline bool tv_list_has_watchers(const list_T *const l)
{
  return l && l->lv_watch;
}

static inline listitem_T *tv_list_first(const list_T *l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Get first list item
///
/// @param[in]  l  List to get item from.
///
/// @return List item or NULL in case of an empty list.
static inline listitem_T *tv_list_first(const list_T *const l)
{
  if (l == NULL) {
    return NULL;
  }
  return l->lv_first;
}

static inline listitem_T *tv_list_last(const list_T *l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Get last list item
///
/// @param[in]  l  List to get item from.
///
/// @return List item or NULL in case of an empty list.
static inline listitem_T *tv_list_last(const list_T *const l)
{
  if (l == NULL) {
    return NULL;
  }
  return l->lv_last;
}

static inline void tv_dict_set_ret(typval_T *tv, dict_T *d)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ARG(1);

/// Set a dictionary as the return value
///
/// @param[out]  tv  Object to receive the dictionary
/// @param[in,out]  d  Dictionary to pass to the object
static inline void tv_dict_set_ret(typval_T *const tv, dict_T *const d)
{
  tv->v_type = VAR_DICT;
  tv->vval.v_dict = d;
  if (d != NULL) {
    d->dv_refcount++;
  }
}

static inline long tv_dict_len(const dict_T *d)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Get the number of items in a Dictionary
///
/// @param[in]  d  Dictionary to check.
static inline long tv_dict_len(const dict_T *const d)
{
  if (d == NULL) {
    return 0L;
  }
  return (long)d->dv_hashtab.ht_used;
}

static inline bool tv_dict_is_watched(const dict_T *d)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Check if dictionary is watched
///
/// @param[in]  d  Dictionary to check.
///
/// @return true if there is at least one watcher.
static inline bool tv_dict_is_watched(const dict_T *const d)
{
  return d && !QUEUE_EMPTY(&d->watchers);
}

static inline void tv_blob_set_ret(typval_T *tv, blob_T *b)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ARG(1);

/// Set a blob as the return value.
///
/// Increments the reference count.
///
/// @param[out]  tv  Object to receive the blob.
/// @param[in,out]  b  Blob to pass to the object.
static inline void tv_blob_set_ret(typval_T *const tv, blob_T *const b)
{
  tv->v_type = VAR_BLOB;
  tv->vval.v_blob = b;
  if (b != NULL) {
    b->bv_refcount++;
  }
}

static inline int tv_blob_len(const blob_T *b)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Get the length of the data in the blob, in bytes.
///
/// @param[in]  b  Blob to check.
static inline int tv_blob_len(const blob_T *const b)
{
  if (b == NULL) {
    return 0;
  }
  return b->bv_ga.ga_len;
}

static inline uint8_t tv_blob_get(const blob_T *b, int idx)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Get the byte at index `idx` in the blob.
///
/// @param[in]  b  Blob to index. Cannot be NULL.
/// @param[in]  idx  Index in a blob. Must be valid.
///
/// @return Byte value at the given index.
static inline uint8_t tv_blob_get(const blob_T *const b, int idx)
{
  return ((uint8_t *)b->bv_ga.ga_data)[idx];
}

static inline void tv_blob_set(blob_T *blob, int idx, uint8_t c)
  REAL_FATTR_ALWAYS_INLINE REAL_FATTR_NONNULL_ALL;

/// Store the byte `c` at index `idx` in the blob.
///
/// @param[in]  b  Blob to index. Cannot be NULL.
/// @param[in]  idx  Index in a blob. Must be valid.
/// @param[in]  c  Value to store.
static inline void tv_blob_set(blob_T *const blob, int idx, uint8_t c)
{
  ((uint8_t *)blob->bv_ga.ga_data)[idx] = c;
}

/// Initialize Vimscript object
///
/// Initializes to unlocked VAR_UNKNOWN object.
///
/// @param[out]  tv  Object to initialize.
static inline void tv_init(typval_T *const tv)
{
  if (tv != NULL) {
    memset(tv, 0, sizeof(*tv));
  }
}

/// Empty string
///
/// Needed for hack which allows not allocating empty string and still not
/// crashing when freeing it.
extern const char *const tv_empty_string;

/// Specifies that free_unref_items() function has (not) been entered
extern bool tv_in_free_unref_items;

/// Iterate over a list
///
/// @param  modifier  Modifier: expected to be const or nothing, volatile should
///                   also work if you have any uses for the volatile list.
/// @param[in]  l  List to iterate over.
/// @param  li  Name of the variable with current listitem_T entry.
/// @param  code  Cycle body.
#define _TV_LIST_ITER_MOD(modifier, l, li, code) \
  do { \
    modifier list_T *const l_ = (l); \
    if (l_ != NULL) { \
      for (modifier listitem_T *li = l_->lv_first; \
           li != NULL; li = li->li_next) { \
        code \
      } \
    } \
  } while (0)

/// Iterate over a list
///
/// To be used when you need to modify list or values you iterate over, use
/// #TV_LIST_ITER_CONST if you don’t.
///
/// @param[in]  l  List to iterate over.
/// @param  li  Name of the variable with current listitem_T entry.
/// @param  code  Cycle body.
#define TV_LIST_ITER(l, li, code) \
  _TV_LIST_ITER_MOD( , l, li, code)  // NOLINT(whitespace/parens)

/// Iterate over a list
///
/// To be used when you don’t need to modify list or values you iterate over,
/// use #TV_LIST_ITER if you do.
///
/// @param[in]  l  List to iterate over.
/// @param  li  Name of the variable with current listitem_T entry.
/// @param  code  Cycle body.
#define TV_LIST_ITER_CONST(l, li, code) \
  _TV_LIST_ITER_MOD(const, l, li, code)

// Below macros are macros to avoid duplicating code for functionally identical
// const and non-const function variants.

/// Get typval_T out of list item
///
/// @param[in]  li  List item to get typval_T from, must not be NULL.
///
/// @return Pointer to typval_T.
#define TV_LIST_ITEM_TV(li) (&(li)->li_tv)

/// Get next list item given the current one
///
/// @param[in]  l  List to get item from.
/// @param[in]  li  List item to get typval_T from.
///
/// @return Pointer to the next item or NULL.
#define TV_LIST_ITEM_NEXT(l, li) ((li)->li_next)

/// Get previous list item given the current one
///
/// @param[in]  l  List to get item from.
/// @param[in]  li  List item to get typval_T from.
///
/// @return Pointer to the previous item or NULL.
#define TV_LIST_ITEM_PREV(l, li) ((li)->li_prev)
// List argument is not used currently, but it is a must for lists implemented
// as a pair (size(in list), array) without terminator - basically for lists on
// top of kvec.

/// Iterate over a dictionary
///
/// @param[in]  d  Dictionary to iterate over.
/// @param  di  Name of the variable with current dictitem_T entry.
/// @param  code  Cycle body.
#define TV_DICT_ITER(d, di, code) \
  HASHTAB_ITER(&(d)->dv_hashtab, di##hi_, { \
    { \
      dictitem_T *const di = TV_DICT_HI2DI(di##hi_); \
      { \
        code \
      } \
    } \
  })

static inline bool tv_get_float_chk(const typval_T *tv, float_T *ret_f)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Get the float value
///
/// Raises an error if object is not number or floating-point.
///
/// @param[in]  tv  Vimscript object to get value from.
/// @param[out]  ret_f  Location where resulting float is stored.
///
/// @return true in case of success, false if tv is not a number or float.
static inline bool tv_get_float_chk(const typval_T *const tv, float_T *const ret_f)
{
  if (tv->v_type == VAR_FLOAT) {
    *ret_f = tv->vval.v_float;
    return true;
  }
  if (tv->v_type == VAR_NUMBER) {
    *ret_f = (float_T)tv->vval.v_number;
    return true;
  }
  semsg("%s", _("E808: Number or Float required"));
  return false;
}

static inline DictWatcher *tv_dict_watcher_node_data(QUEUE *q)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_NONNULL_RET REAL_FATTR_PURE
  REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_ALWAYS_INLINE
  FUNC_ATTR_NO_SANITIZE_ADDRESS;

/// Compute the `DictWatcher` address from a QUEUE node.
///
/// This only exists for .asan-blacklist (ASAN doesn't handle QUEUE_DATA pointer
/// arithmetic).
static inline DictWatcher *tv_dict_watcher_node_data(QUEUE *q)
  FUNC_ATTR_NO_SANITIZE_ADDRESS
{
  return QUEUE_DATA(q, DictWatcher, node);
}

static inline bool tv_is_func(typval_T tv)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE FUNC_ATTR_CONST;

/// Check whether given typval_T contains a function
///
/// That is, whether it contains VAR_FUNC or VAR_PARTIAL.
///
/// @param[in]  tv  Typval to check.
///
/// @return True if it is a function or a partial, false otherwise.
static inline bool tv_is_func(const typval_T tv)
{
  return tv.v_type == VAR_FUNC || tv.v_type == VAR_PARTIAL;
}

/// Specify that argument needs to be translated
///
/// Used for size_t length arguments to avoid calling gettext() and strlen()
/// unless needed.
#define TV_TRANSLATE (SIZE_MAX)

/// Specify that argument is a NUL-terminated C string
///
/// Used for size_t length arguments to avoid calling strlen() unless needed.
#define TV_CSTRING (SIZE_MAX - 1)

#ifdef UNIT_TESTING
// Do not use enum constants, see commit message.
EXTERN const size_t kTVCstring INIT(= TV_CSTRING);
EXTERN const size_t kTVTranslate INIT(= TV_TRANSLATE);
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/typval.h.generated.h"
#endif

#endif  // NVIM_EVAL_TYPVAL_H
