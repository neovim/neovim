#ifndef NVIM_EVAL_DEFS_H
#define NVIM_EVAL_DEFS_H

#include <limits.h>
#include <stddef.h>

#include "nvim/hashtab.h"
#include "nvim/lib/queue.h"

typedef int varnumber_T;
typedef double float_T;

#define VARNUMBER_MAX INT_MAX
#define VARNUMBER_MIN INT_MIN

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

/* Values for "dv_scope". */
#define VAR_SCOPE     1 /* a:, v:, s:, etc. scope dictionaries */
#define VAR_DEF_SCOPE 2 /* l:, g: scope dictionaries: here funcrefs are not
                           allowed to mask existing functions */

/*
 * Structure to hold an item of a list: an internal variable without a name.
 */
typedef struct listitem_S listitem_T;

struct listitem_S {
  listitem_T  *li_next;         /* next item in list */
  listitem_T  *li_prev;         /* previous item in list */
  typval_T li_tv;               /* type and value of the variable */
};

/*
 * Struct used by those that are using an item in a list.
 */
typedef struct listwatch_S listwatch_T;

struct listwatch_S {
  listitem_T          *lw_item;         /* item being watched */
  listwatch_T         *lw_next;         /* next watcher */
};

/*
 * Structure to hold info about a list.
 */
struct listvar_S {
  listitem_T  *lv_first;        /* first item, NULL if none */
  listitem_T  *lv_last;         /* last item, NULL if none */
  int lv_refcount;              /* reference count */
  int lv_len;                   /* number of items */
  listwatch_T *lv_watch;        /* first watcher, NULL if none */
  int lv_idx;                   /* cached index of an item */
  listitem_T  *lv_idx_item;     /* when not NULL item at index "lv_idx" */
  int lv_copyID;                /* ID used by deepcopy() */
  list_T      *lv_copylist;     /* copied list used by deepcopy() */
  char lv_lock;                 /* zero, VAR_LOCKED, VAR_FIXED */
  list_T      *lv_used_next;    /* next list in used lists list */
  list_T      *lv_used_prev;    /* previous list in used lists list */
};

/*
 * Structure to hold an item of a Dictionary.
 * Also used for a variable.
 * The key is copied into "di_key" to avoid an extra alloc/free for it.
 */
struct dictitem_S {
  typval_T di_tv;               /* type and value of the variable */
  char_u di_flags;              /* flags (only used for variable) */
  char_u di_key[1];             /* key (actually longer!) */
};

typedef struct dictitem_S dictitem_T;

#define DI_FLAGS_RO     1   // "di_flags" value: read-only variable
#define DI_FLAGS_RO_SBX 2   // "di_flags" value: read-only in the sandbox
#define DI_FLAGS_FIX    4   // "di_flags" value: fixed: no :unlet or remove()
#define DI_FLAGS_LOCK   8   // "di_flags" value: locked variable
#define DI_FLAGS_ALLOC  16  // "di_flags" value: separately allocated

/// Structure representing a Dictionary
struct dictvar_S {
  VarLockStatus dv_lock;  ///< Whole dictionary lock status.
  char dv_scope;          ///< Non-zero (#VAR_SCOPE, #VAR_DEF_SCOPE) if
                          ///< dictionary represents a scope (i.e. g:, l: …).
  int dv_refcount;        ///< Reference count.
  int dv_copyID;          ///< ID used when recursivery traversing a value.
  hashtab_T dv_hashtab;   ///< Hashtab containing all items.
  dict_T *dv_copydict;    ///< Copied dict used by deepcopy().
  dict_T *dv_used_next;   ///< Next dictionary in used dictionaries list.
  dict_T *dv_used_prev;   ///< Previous dictionary in used dictionaries list.
  QUEUE watchers;         ///< Dictionary key watchers set by user code.
};

// structure used for explicit stack while garbage collecting hash tables
typedef struct ht_stack_S {
  hashtab_T *ht;
  struct ht_stack_S *prev;
} ht_stack_T;

// structure used for explicit stack while garbage collecting lists
typedef struct list_stack_S {
  list_T *list;
  struct list_stack_S *prev;
} list_stack_T;

// In a hashtab item "hi_key" points to "di_key" in a dictitem.
// This avoids adding a pointer to the hashtab item.

/// Convert a dictitem pointer to a hashitem key pointer
#define DI2HIKEY(di) ((di)->di_key)

/// Convert a hashitem key pointer to a dictitem pointer
#define HIKEY2DI(p)  ((dictitem_T *)(p - offsetof(dictitem_T, di_key)))

/// Convert a hashitem pointer to a dictitem pointer
#define HI2DI(hi)     HIKEY2DI((hi)->hi_key)

#endif  // NVIM_EVAL_DEFS_H
