#ifndef NVIM_EVAL_TYPVAL_H
#define NVIM_EVAL_TYPVAL_H

#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <limits.h>

#include "nvim/types.h"
#include "nvim/hashtab.h"
#include "nvim/garray.h"
#include "nvim/mbyte.h"
#include "nvim/func_attr.h"
#include "nvim/lib/queue.h"
#include "nvim/profile.h"  // for proftime_T
#include "nvim/pos.h"      // for linenr_T
#include "nvim/gettext.h"
#include "nvim/message.h"
#include "nvim/macros.h"

/// Type used for VimL VAR_NUMBER values
typedef int64_t varnumber_T;
typedef uint64_t uvarnumber_T;

/// Type used for VimL VAR_FLOAT values
typedef double float_T;

/// Refcount for dict or list that should not be freed
enum { DO_NOT_FREE_CNT = (INT_MAX / 2) };

/// Maximal possible value of varnumber_T variable
#define VARNUMBER_MAX INT64_MAX
#define UVARNUMBER_MAX UINT64_MAX

/// Mimimal possible value of varnumber_T variable
#define VARNUMBER_MIN INT64_MIN

/// %d printf format specifier for varnumber_T
#define PRIdVARNUMBER PRId64

typedef struct listvar_S list_T;
typedef struct dictvar_S dict_T;
typedef struct partial_S partial_T;

typedef struct ufunc ufunc_T;

typedef enum {
  kCallbackNone = 0,
  kCallbackFuncref,
  kCallbackPartial,
} CallbackType;

typedef struct {
  union {
    char_u *funcref;
    partial_T *partial;
  } data;
  CallbackType type;
} Callback;
#define CALLBACK_NONE ((Callback){ .type = kCallbackNone })

/// Structure holding dictionary watcher
typedef struct dict_watcher {
  Callback callback;
  char *key_pattern;
  size_t key_pattern_len;
  QUEUE node;
  bool busy;  // prevent recursion if the dict is changed in the callback
} DictWatcher;

/// Special variable values
typedef enum {
  kSpecialVarFalse,  ///< v:false
  kSpecialVarTrue,   ///< v:true
  kSpecialVarNull,   ///< v:null
} SpecialVarValue;

/// Variable lock status for typval_T.v_lock
typedef enum {
  VAR_UNLOCKED = 0,  ///< Not locked.
  VAR_LOCKED = 1,    ///< User lock, can be unlocked.
  VAR_FIXED = 2,     ///< Locked forever.
} VarLockStatus;

/// VimL variable types, for use in typval_T.v_type
typedef enum {
  VAR_UNKNOWN = 0,  ///< Unknown (unspecified) value.
  VAR_NUMBER,       ///< Number, .v_number is used.
  VAR_STRING,       ///< String, .v_string is used.
  VAR_FUNC,         ///< Function reference, .v_string is used as function name.
  VAR_LIST,         ///< List, .v_list is used.
  VAR_DICT,         ///< Dictionary, .v_dict is used.
  VAR_FLOAT,        ///< Floating-point value, .v_float is used.
  VAR_SPECIAL,      ///< Special value (true, false, null), .v_special
                    ///< is used.
  VAR_PARTIAL,      ///< Partial, .v_partial is used.
} VarType;

/// Structure that holds an internal variable value
typedef struct {
  VarType v_type;  ///< Variable type.
  VarLockStatus v_lock;  ///< Variable lock status.
  union typval_vval_union {
    varnumber_T v_number;  ///< Number, for VAR_NUMBER.
    SpecialVarValue v_special;  ///< Special value, for VAR_SPECIAL.
    float_T v_float;  ///< Floating-point number, for VAR_FLOAT.
    char_u *v_string;  ///< String, for VAR_STRING and VAR_FUNC, can be NULL.
    list_T *v_list;  ///< List for VAR_LIST, can be NULL.
    dict_T *v_dict;  ///< Dictionary for VAR_DICT, can be NULL.
    partial_T *v_partial;  ///< Closure: function with args.
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
  listitem_T *lv_first;  ///< First item, NULL if none.
  listitem_T *lv_last;  ///< Last item, NULL if none.
  int lv_refcount;  ///< Reference count.
  int lv_len;  ///< Number of items.
  listwatch_T *lv_watch;  ///< First watcher, NULL if none.
  int lv_idx;  ///< Index of a cached item, used for optimising repeated l[idx].
  listitem_T *lv_idx_item;  ///< When not NULL item at index "lv_idx".
  int lv_copyID;  ///< ID used by deepcopy().
  list_T *lv_copylist;  ///< Copied list used by deepcopy().
  VarLockStatus lv_lock;  ///< Zero, VAR_LOCKED, VAR_FIXED.
  list_T *lv_used_next;  ///< next list in used lists list.
  list_T *lv_used_prev;  ///< Previous list in used lists list.
};

// Static list with 10 items. Use tv_list_init_static10() to initialize.
typedef struct {
  list_T sl_list;  // must be first
  listitem_T sl_items[10];
} staticList10_T;

#define TV_LIST_STATIC10_INIT { \
    .sl_list = { \
      .lv_first = NULL, \
      .lv_last = NULL, \
      .lv_refcount = 0, \
      .lv_len = 0, \
      .lv_watch = NULL, \
      .lv_idx_item = NULL, \
      .lv_lock = VAR_FIXED, \
      .lv_used_next = NULL, \
      .lv_used_prev = NULL, \
    }, \
  }

// Structure to hold an item of a Dictionary.
// Also used for a variable.
// The key is copied into "di_key" to avoid an extra alloc/free for it.
struct dictitem_S {
  typval_T di_tv;               ///< type and value of the variable
  char_u di_flags;              ///< flags (only used for variable)
  char_u di_key[1];             ///< key (actually longer!)
};

#define TV_DICTITEM_STRUCT(KEY_LEN) \
    struct { \
      typval_T di_tv;  /* Structure that holds scope dictionary itself. */ \
      uint8_t di_flags;  /* Flags. */ \
      char_u di_key[KEY_LEN];  /* Key value. */ \
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

/// Type used for script ID
typedef int scid_T;
/// Format argument for scid_T
#define PRIdSCID "d"

// Structure to hold info for a function that is currently being executed.
typedef struct funccall_S funccall_T;

/// Structure to hold info for a user function.
struct ufunc {
  int          uf_varargs;       ///< variable nr of arguments
  int          uf_flags;
  int          uf_calls;         ///< nr of active calls
  bool         uf_cleared;       ///< func_clear() was already called
  garray_T     uf_args;          ///< arguments
  garray_T     uf_lines;         ///< function lines
  int          uf_profiling;     ///< true when func is being profiled
  // Profiling the function as a whole.
  int          uf_tm_count;      ///< nr of calls
  proftime_T   uf_tm_total;      ///< time spent in function + children
  proftime_T   uf_tm_self;       ///< time spent in function itself
  proftime_T   uf_tm_children;   ///< time spent in children this call
  // Profiling the function per line.
  int         *uf_tml_count;     ///< nr of times line was executed
  proftime_T  *uf_tml_total;     ///< time spent in a line + children
  proftime_T  *uf_tml_self;      ///< time spent in a line itself
  proftime_T   uf_tml_start;     ///< start time for current line
  proftime_T   uf_tml_children;  ///< time spent in children for this line
  proftime_T   uf_tml_wait;      ///< start wait time for current line
  int          uf_tml_idx;       ///< index of line being timed; -1 if none
  int          uf_tml_execed;    ///< line being timed was executed
  scid_T       uf_script_ID;     ///< ID of script where function was defined,
                                 ///< used for s: variables
  int          uf_refcount;      ///< reference count, see func_name_refcount()
  funccall_T   *uf_scoped;       ///< l: local variables for closure
  char_u       uf_name[1];       ///< name of function (actually longer); can
                                 ///< start with <SNR>123_ (<SNR> is K_SPECIAL
                                 ///< KS_EXTRA KE_SNR)
};

/// Maximum number of function arguments
#define MAX_FUNC_ARGS   20

struct partial_S {
  int pt_refcount;  ///< Reference count.
  char_u *pt_name;  ///< Function name; when NULL use pt_func->name.
  ufunc_T *pt_func;  ///< Function pointer; when NULL lookup function with
                     ///< pt_name.
  bool pt_auto;  ///< When true the partial was created by using dict.member
                 ///< in handle_subscript().
  int pt_argc;  ///< Number of arguments.
  typval_T *pt_argv;  ///< Arguments in allocated array.
  dict_T *pt_dict;  ///< Dict for "self".
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

/// Structure representing one list item, used for sort array.
typedef struct {
  listitem_T *item;  ///< Sorted list item.
  int idx;  ///< Sorted list item index.
} ListSortItem;

typedef int (*ListSorter)(const void *, const void *);

// In a hashtab item "hi_key" points to "di_key" in a dictitem.
// This avoids adding a pointer to the hashtab item.

/// Convert a hashitem pointer to a dictitem pointer
#define TV_DICT_HI2DI(hi) \
    ((dictitem_T *)((hi)->hi_key - offsetof(dictitem_T, di_key)))

/// Increase reference count for a given list
///
/// Does nothing for NULL lists.
///
/// @param[in]  l  List to modify.
static inline void tv_list_ref(list_T *const l)
{
  if (l == NULL) {
    return;
  }
  l->lv_refcount++;
}

static inline VarLockStatus tv_list_locked(const list_T *const l)
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
static inline void tv_list_set_lock(list_T *const l,
                                    const VarLockStatus lock)
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
static inline void tv_list_set_copyid(list_T *const l,
                                      const int copyid)
  FUNC_ATTR_NONNULL_ALL
{
  l->lv_copyID = copyid;
}

static inline int tv_list_len(const list_T *const l)
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

static inline int tv_list_copyid(const list_T *const l)
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

static inline list_T *tv_list_latest_copy(const list_T *const l)
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

static inline int tv_list_uidx(const list_T *const l, int n)
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

static inline bool tv_list_has_watchers(const list_T *const l)
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

static inline listitem_T *tv_list_first(const list_T *const l)
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

static inline listitem_T *tv_list_last(const list_T *const l)
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
    _TV_LIST_ITER_MOD(, l, li, code)

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

static inline bool tv_get_float_chk(const typval_T *const tv,
                                    float_T *const ret_f)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_WARN_UNUSED_RESULT;

// FIXME circular dependency, cannot import message.h.
bool emsgf(const char *const fmt, ...);

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

static inline DictWatcher *tv_dict_watcher_node_data(QUEUE *q)
  REAL_FATTR_NONNULL_ALL REAL_FATTR_NONNULL_RET REAL_FATTR_PURE
  REAL_FATTR_WARN_UNUSED_RESULT REAL_FATTR_ALWAYS_INLINE;

/// Compute the `DictWatcher` address from a QUEUE node.
///
/// This only exists for .asan-blacklist (ASAN doesn't handle QUEUE_DATA pointer
/// arithmetic).
static inline DictWatcher *tv_dict_watcher_node_data(QUEUE *q)
{
  return QUEUE_DATA(q, DictWatcher, node);
}

static inline bool tv_is_func(const typval_T tv)
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
