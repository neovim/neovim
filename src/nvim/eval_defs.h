#ifndef NVIM_EVAL_DEFS_H
#define NVIM_EVAL_DEFS_H

#include <limits.h>
#include <stddef.h>

#include "nvim/hashtab.h"
#include "nvim/lib/queue.h"
#include "nvim/garray.h"   // for garray_T
#include "nvim/profile.h"  // for proftime_T
#include "nvim/pos.h"      // for linenr_T

typedef int varnumber_T;
typedef double float_T;

#define VARNUMBER_MAX INT_MAX
#define VARNUMBER_MIN INT_MIN

typedef struct listvar_S list_T;
typedef struct dictvar_S dict_T;
typedef struct partial_S partial_T;

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

// Static list with 10 items. Use init_static_list() to initialize.
typedef struct {
  list_T sl_list;  // must be first
  listitem_T sl_items[10];
} staticList10_T;

// Structure to hold an item of a Dictionary.
// Also used for a variable.
// The key is copied into "di_key" to avoid an extra alloc/free for it.
struct dictitem_S {
  typval_T di_tv;               ///< type and value of the variable
  char_u di_flags;              ///< flags (only used for variable)
  char_u di_key[1];             ///< key (actually longer!)
};

typedef struct dictitem_S dictitem_T;

/// A dictitem with a 16 character key (plus NUL)
struct dictitem16_S {
  typval_T di_tv;     ///< type and value of the variable
  char_u di_flags;    ///< flags (only used for variable)
  char_u di_key[17];  ///< key
};

typedef struct dictitem16_S dictitem16_T;


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

typedef int scid_T;                     // script ID
typedef struct funccall_S funccall_T;

// Structure to hold info for a user function.
typedef struct ufunc ufunc_T;

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
                                 //   used for s: variables
  int          uf_refcount;      ///< reference count, see func_name_refcount()
  funccall_T   *uf_scoped;       ///< l: local variables for closure
  char_u       uf_name[1];       ///< name of function (actually longer); can
                                 //   start with <SNR>123_ (<SNR> is K_SPECIAL
                                 //   KS_EXTRA KE_SNR)
};

/// Maximum number of function arguments
#define MAX_FUNC_ARGS   20
#define VAR_SHORT_LEN   20      // short variable name length
#define FIXVAR_CNT      12      // number of fixed variables

// structure to hold info for a function that is currently being executed.
struct funccall_S {
  ufunc_T     *func;            ///< function being called
  int linenr;                   ///< next line to be executed
  int returned;                 ///< ":return" used
  struct {                      ///< fixed variables for arguments
    dictitem_T var;                     ///< variable (without room for name)
    char_u room[VAR_SHORT_LEN];         ///< room for the name
  } fixvar[FIXVAR_CNT];
  dict_T l_vars;                ///< l: local function variables
  dictitem_T l_vars_var;        ///< variable for l: scope
  dict_T l_avars;               ///< a: argument variables
  dictitem_T l_avars_var;       ///< variable for a: scope
  list_T l_varlist;             ///< list for a:000
  listitem_T l_listitems[MAX_FUNC_ARGS];        ///< listitems for a:000
  typval_T    *rettv;           ///< return value
  linenr_T breakpoint;          ///< next line with breakpoint or zero
  int dbg_tick;                 ///< debug_tick when breakpoint was set
  int level;                    ///< top nesting level of executed function
  proftime_T prof_child;        ///< time spent in a child
  funccall_T  *caller;          ///< calling function or NULL
  int fc_refcount;              ///< number of user functions that reference
                                // this funccal
  int fc_copyID;                ///< for garbage collection
  garray_T fc_funcs;            ///< list of ufunc_T* which keep a reference
                                // to "func"
};

// structure used by trans_function_name()
typedef struct {
  dict_T      *fd_dict;         ///< Dictionary used.
  char_u      *fd_newkey;       ///< New key in "dict" in allocated memory.
  dictitem_T  *fd_di;           ///< Dictionary item used.
} funcdict_T;

struct partial_S {
  int pt_refcount;        ///< Reference count.
  char_u *pt_name;        ///< Function name; when NULL use pt_func->name.
  ufunc_T *pt_func;       ///< Function pointer; when NULL lookup function
                          ///< with pt_name.
  bool pt_auto;           ///< when true the partial was created for using
                          ///< dict.member in handle_subscript().
  int pt_argc;            ///< Number of arguments.
  typval_T *pt_argv;      ///< Arguments in allocated array.
  dict_T *pt_dict;        ///< Dict for "self".
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

/// Convert a hashitem value pointer to a dictitem pointer
#define HIVAL2DI(p) \
    ((dictitem_T *)(((char *)p) - offsetof(dictitem_T, di_tv)))

/// Convert a hashitem pointer to a dictitem pointer
#define HI2DI(hi)     HIKEY2DI((hi)->hi_key)

/// Type of assert_* check being performed
typedef enum
{
  ASSERT_EQUAL,
  ASSERT_NOTEQUAL,
  ASSERT_MATCH,
  ASSERT_NOTMATCH,
  ASSERT_OTHER,
} assert_type_T;

#endif  // NVIM_EVAL_DEFS_H
