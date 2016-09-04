#ifndef NVIM_EVAL_TYPVAL_H
#define NVIM_EVAL_TYPVAL_H

#include <limits.h>
#include <stddef.h>
#include <string.h>

#include "nvim/hashtab.h"
#include "nvim/garray.h"
#include "nvim/mbyte.h"
#include "nvim/func_attr.h"
#include "nvim/lib/queue.h"
#include "nvim/gettext.h"
#include "nvim/message.h"
#include "nvim/pos.h"

/// Structure to hold info for a user function.
typedef struct ufunc ufunc_T;

typedef int varnumber_T;
typedef double float_T;

#define VARNUMBER_MAX INT_MAX
#define VARNUMBER_MIN INT_MIN
#define PRIdVARNUMBER "d"

/// Structure holding dictionary watcher
typedef struct dict_watcher {
  ufunc_T *callback;
  char *key_pattern;
  QUEUE node;
  bool busy;  // prevent recursion if the dict is changed in the callback
} DictWatcher;

typedef struct listvar_S list_T;
typedef struct dictvar_S dict_T;

/// Special variable values
typedef enum {
  kSpecialVarFalse,  ///< v:false
  kSpecialVarTrue,   ///< v:true
  kSpecialVarNull,   ///< v:null
} SpecialVarValue;

/// Variable lock status for typval_T.v_lock
typedef enum {
  VAR_UNLOCKED = 0,  ///< Not locked.
  VAR_LOCKED,        ///< User lock, can be unlocked.
  VAR_FIXED,         ///< Locked forever.
} VarLockStatus;

/// VimL variable types, for use in typval_T.v_type
typedef enum {
  VAR_UNKNOWN = 0,  ///< Unknown (unspecified) value.
  VAR_NUMBER,       ///< Number, .v_number is used.
  VAR_STRING,       ///< String, .v_string is used.
  VAR_FUNC,         ///< Function referene, .v_string is used for function name.
  VAR_LIST,         ///< List, .v_list is used.
  VAR_DICT,         ///< Dictionary, .v_dict is used.
  VAR_FLOAT,        ///< Floating-point value, .v_float is used.
  VAR_SPECIAL,      ///< Special value (true, false, null), .v_special
                    ///< is used.
} VarType;

/// Structure that holds an internal variable value
typedef struct {
  VarType v_type;  ///< Variable type.
  VarLockStatus v_lock;  ///< Variable lock status.
  union {
    varnumber_T v_number;  ///< Number, for VAR_NUMBER.
    SpecialVarValue v_special;  ///< Special value, for VAR_SPECIAL.
    float_T v_float;  ///< Floating-point number, for VAR_FLOAT.
    char_u *v_string;  ///< String, for VAR_STRING and VAR_FUNC, can be NULL.
    list_T *v_list;  ///< List for VAR_LIST, can be NULL.
    dict_T *v_dict;  ///< Dictionary for VAR_DICT, can be NULL.
  }           vval;  ///< Actual value.
} typval_T;

/// Values for (struct dictvar_S).dv_scope
typedef enum {
  VAR_NO_SCOPE = 0,  ///< Not a scope dictionary.
  VAR_SCOPE = 1,  ///< Scope dictionary which requires prefix (a:, v:, …).
  VAR_DEF_SCOPE = 2,  ///< Scope dictionary which may be accessed without prefix
                      ///< (l:, g:).
} ScopeType;

/// Structure to hold an item of a list
typedef struct listitem_S listitem_T;

struct listitem_S {
  listitem_T  *li_next;  ///< Next item in list.
  listitem_T  *li_prev;  ///< Previous item in list.
  typval_T li_tv;  ///< Item value.
};

/// Structure used by those that are using an item in a list
typedef struct listwatch_S listwatch_T;

struct listwatch_S {
  listitem_T *lw_item;  ///< Item being watched.
  listwatch_T *lw_next;  ///< Next watcher.
};

/// Structure to hold info about a list
struct listvar_S {
  listitem_T  *lv_first;        ///< First item, NULL if none.
  listitem_T  *lv_last;         ///< Last item, NULL if none.
  int lv_refcount;              ///< Reference count.
  int lv_len;                   ///< Number of items.
  listwatch_T *lv_watch;        ///< First watcher, NULL if none.
  int lv_idx;                   ///< Cached index of an item.
  listitem_T  *lv_idx_item;     ///< When not NULL item at index "lv_idx"..
  int lv_copyID;                ///< ID used by deepcopy().
  list_T      *lv_copylist;     ///< Copied list used by deepcopy().
  VarLockStatus lv_lock;        ///< Zero, VAR_LOCKED, VAR_FIXED.
  list_T      *lv_used_next;    ///< Next list in used lists list.
  list_T      *lv_used_prev;    ///< Previous list in used lists list.
};

#define TV_DICTITEM_STRUCT(key_len) \
    struct { \
      typval_T di_tv;  /* Structure that holds scope dictionary itself. */ \
      uint8_t di_flags;  /* Flags. */ \
      char_u di_key[key_len];  /* Key value. */ /* NOLINT(runtime/arrays) */ \
    }

/// Structure to hold a scope dictionary
///
/// @warning Must be compatible with dictitem_T.
///
/// For use in find_var_in_ht to pretend that it found dictionary item when it
/// finds scope dictionary.
typedef TV_DICTITEM_STRUCT(1) ScopeDictDictItem;

/// Structure to hold an item of a Dictionary
///
/// @warning Must be compatible with ScopeDictDictItem.
///
/// Also used for a variable.
typedef TV_DICTITEM_STRUCT() dictitem_T;

/// Flags for dictitem_T.di_flags
typedef enum {
  DI_FLAGS_RO = 1,  ///< Read-only value
  DI_FLAGS_RO_SBX = 2,  ///< Value, read-only in the sandbox
  DI_FLAGS_FIX = 4,  ///< Fixed value: cannot be :unlet or remove()d.
  DI_FLAGS_LOCK = 8,  ///< Locked value.
  DI_FLAGS_ALLOC = 16,  ///< Separately allocated.
} DictItemFlags;

/// Structure representing a Dictionary
struct dictvar_S {
  VarLockStatus dv_lock;  ///< Whole dictionary lock status.
  ScopeType dv_scope;     ///< Non-zero (#VAR_SCOPE, #VAR_DEF_SCOPE) if
                          ///< dictionary represents a scope (i.e. g:, l: …).
  int dv_refcount;        ///< Reference count.
  int dv_copyID;          ///< ID used when recursivery traversing a value.
  hashtab_T dv_hashtab;   ///< Hashtab containing all items.
  dict_T *dv_copydict;    ///< Copied dict used by deepcopy().
  dict_T *dv_used_next;   ///< Next dictionary in used dictionaries list.
  dict_T *dv_used_prev;   ///< Previous dictionary in used dictionaries list.
  QUEUE watchers;         ///< Dictionary key watchers set by user code.
};

/// Structure used for explicit stack while garbage collecting hash tables
typedef struct ht_stack_S {
  hashtab_T *ht;
  struct ht_stack_S *prev;
} ht_stack_T;

/// Structure used for explicit stack while garbage collecting lists
typedef struct list_stack_S {
  list_T *list;
  struct list_stack_S *prev;
} list_stack_T;

// In a hashtab item "hi_key" points to "di_key" in a dictitem.
// This avoids adding a pointer to the hashtab item.

/// Convert a hashitem pointer to a dictitem pointer
#define TV_DICT_HI2DI(hi) \
    ((dictitem_T *)((hi)->hi_key - offsetof(dictitem_T, di_key)))

static inline long tv_list_len(const list_T *const l)
  REAL_FATTR_PURE REAL_FATTR_WARN_UNUSED_RESULT;

/// Get the number of items in a list
///
/// @param[in]  l  List to check.
static inline long tv_list_len(const list_T *const l)
{
  if (l == NULL) {
    return 0;
  }
  return l->lv_len;
}

static inline long tv_dict_len(const dict_T *const d)
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

static inline bool tv_dict_is_watched(const dict_T *const d)
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

static inline DictWatcher *tv_dict_watcher_node_data(QUEUE *q)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_NONNULL_RET REAL_FATTR_PURE
  REAL_FATTR_WARN_UNUSED_RESULT;

/// Compute the `DictWatcher` address from a QUEUE node.
///
/// This only exists for .asan-blacklist (ASAN doesn't handle QUEUE_DATA pointer
/// arithmetic).
static inline DictWatcher *tv_dict_watcher_node_data(QUEUE *q)
{
  return QUEUE_DATA(q, DictWatcher, node);
}

/// Initialize VimL object
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

#define TV_INITIAL_VALUE \
    ((typval_T) { \
      .v_type = VAR_UNKNOWN, \
      .v_lock = VAR_UNLOCKED, \
    })

extern const char *const tv_empty_string;

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

static inline bool tv_get_float_chk(const typval_T *const tv,
                                    float_T *const ret_f)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

/// Get the float value
///
/// Raises an error if object is not number or floating-point.
///
/// @param[in]  tv  VimL object to get value from.
/// @param[out]  ret_f  Location where resulting float is stored.
///
/// @return true in case of success, false if tv is not a number or float.
static inline bool tv_get_float_chk(const typval_T *const tv,
                                    float_T *const ret_f)
{
  if (tv->v_type == VAR_FLOAT) {
    *ret_f = tv->vval.v_float;
    return true;
  }
  if (tv->v_type == VAR_NUMBER) {
    *ret_f = (float_T)tv->vval.v_number;
    return true;
  }
  emsgf(_("E808: Number or Float required"));
  return false;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/typval.h.generated.h"
#endif
#endif  // NVIM_EVAL_TYPVAL_H
