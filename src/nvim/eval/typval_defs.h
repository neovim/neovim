#pragma once

#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>

#include "nvim/garray_defs.h"
#include "nvim/hashtab_defs.h"
#include "nvim/lib/queue_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

/// Type used for Vimscript VAR_NUMBER values
typedef int64_t varnumber_T;
typedef uint64_t uvarnumber_T;

enum {
  /// Refcount for dict or list that should not be freed
  DO_NOT_FREE_CNT = (INT_MAX / 2),
};

/// Additional values for tv_list_alloc() len argument
enum ListLenSpecials {
  /// List length is not known in advance
  ///
  /// To be used when there is neither a way to know how many elements will be
  /// needed nor are any educated guesses.
  kListLenUnknown = -1,
  /// List length *should* be known, but is actually not
  ///
  /// All occurrences of this value should be eventually removed. This is for
  /// the case when the only reason why list length is not known is that it
  /// would be hard to code without refactoring, but refactoring is needed.
  kListLenShouldKnow = -2,
  /// List length may be known in advance, but it requires too much effort
  ///
  /// To be used when it looks impractical to determine list length.
  kListLenMayKnow = -3,
};

/// Maximal possible value of varnumber_T variable
#define VARNUMBER_MAX INT64_MAX
#define UVARNUMBER_MAX UINT64_MAX

/// Minimal possible value of varnumber_T variable
#define VARNUMBER_MIN INT64_MIN

/// %d printf format specifier for varnumber_T
#define PRIdVARNUMBER PRId64

typedef struct listvar_S list_T;
typedef struct dictvar_S dict_T;
typedef struct partial_S partial_T;
typedef struct blobvar_S blob_T;

typedef struct ufunc ufunc_T;

typedef enum {
  kCallbackNone = 0,
  kCallbackFuncref,
  kCallbackPartial,
  kCallbackLua,
} CallbackType;

typedef struct {
  union {
    char *funcref;
    partial_T *partial;
    LuaRef luaref;
  } data;
  CallbackType type;
} Callback;

#define CALLBACK_INIT { .type = kCallbackNone }
#define CALLBACK_NONE ((Callback)CALLBACK_INIT)

/// Structure holding dictionary watcher
typedef struct {
  Callback callback;
  char *key_pattern;
  size_t key_pattern_len;
  QUEUE node;
  bool busy;  // prevent recursion if the dict is changed in the callback
  bool needs_free;
} DictWatcher;

/// Bool variable values
typedef enum {
  kBoolVarFalse,         ///< v:false
  kBoolVarTrue,          ///< v:true
} BoolVarValue;

/// Special variable values
typedef enum {
  kSpecialVarNull,   ///< v:null
} SpecialVarValue;

/// Variable lock status for typval_T.v_lock
typedef enum {
  VAR_UNLOCKED = 0,  ///< Not locked.
  VAR_LOCKED = 1,    ///< User lock, can be unlocked.
  VAR_FIXED = 2,     ///< Locked forever.
} VarLockStatus;

/// Vimscript variable types, for use in typval_T.v_type
typedef enum {
  VAR_UNKNOWN = 0,  ///< Unknown (unspecified) value.
  VAR_NUMBER,       ///< Number, .v_number is used.
  VAR_STRING,       ///< String, .v_string is used.
  VAR_FUNC,         ///< Function reference, .v_string is used as function name.
  VAR_LIST,         ///< List, .v_list is used.
  VAR_DICT,         ///< Dict, .v_dict is used.
  VAR_FLOAT,        ///< Floating-point value, .v_float is used.
  VAR_BOOL,         ///< true, false
  VAR_SPECIAL,      ///< Special value (null), .v_special is used.
  VAR_PARTIAL,      ///< Partial, .v_partial is used.
  VAR_BLOB,         ///< Blob, .v_blob is used.
} VarType;

/// Type values for type().
enum {
  VAR_TYPE_NUMBER  = 0,
  VAR_TYPE_STRING  = 1,
  VAR_TYPE_FUNC    = 2,
  VAR_TYPE_LIST    = 3,
  VAR_TYPE_DICT    = 4,
  VAR_TYPE_FLOAT   = 5,
  VAR_TYPE_BOOL    = 6,
  VAR_TYPE_SPECIAL = 7,
  VAR_TYPE_BLOB    = 10,
};

/// Structure that holds an internal variable value
typedef struct {
  VarType v_type;               ///< Variable type.
  VarLockStatus v_lock;         ///< Variable lock status.
  union typval_vval_union {
    varnumber_T v_number;       ///< Number, for VAR_NUMBER.
    BoolVarValue v_bool;        ///< Bool value, for VAR_BOOL
    SpecialVarValue v_special;  ///< Special value, for VAR_SPECIAL.
    float_T v_float;            ///< Floating-point number, for VAR_FLOAT.
    char *v_string;             ///< String, for VAR_STRING and VAR_FUNC, can be NULL.
    list_T *v_list;             ///< List for VAR_LIST, can be NULL.
    dict_T *v_dict;             ///< Dict for VAR_DICT, can be NULL.
    partial_T *v_partial;       ///< Closure: function with args.
    blob_T *v_blob;             ///< Blob for VAR_BLOB, can be NULL.
  } vval;                       ///< Actual value.
} typval_T;

#define TV_INITIAL_VALUE \
  ((typval_T) { \
    .v_type = VAR_UNKNOWN, \
    .v_lock = VAR_UNLOCKED, \
  })

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
  listitem_T *li_next;  ///< Next item in list.
  listitem_T *li_prev;  ///< Previous item in list.
  typval_T li_tv;  ///< Item value.
};

/// Structure used by those that are using an item in a list
typedef struct listwatch_S listwatch_T;

struct listwatch_S {
  listitem_T *lw_item;  ///< Item being watched.
  listwatch_T *lw_next;  ///< Next watcher.
};

/// Structure to hold info about a list
/// Order of members is optimized to reduce padding.
struct listvar_S {
  listitem_T *lv_first;  ///< First item, NULL if none.
  listitem_T *lv_last;  ///< Last item, NULL if none.
  listwatch_T *lv_watch;  ///< First watcher, NULL if none.
  listitem_T *lv_idx_item;  ///< When not NULL item at index "lv_idx".
  list_T *lv_copylist;  ///< Copied list used by deepcopy().
  list_T *lv_used_next;  ///< next list in used lists list.
  list_T *lv_used_prev;  ///< Previous list in used lists list.
  int lv_refcount;  ///< Reference count.
  int lv_len;  ///< Number of items.
  int lv_idx;  ///< Index of a cached item, used for optimising repeated l[idx].
  int lv_copyID;  ///< ID used by deepcopy().
  VarLockStatus lv_lock;  ///< Zero, VAR_LOCKED, VAR_FIXED.

  LuaRef lua_table_ref;
};

/// Static list with 10 items. Use tv_list_init_static10() to initialize.
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

#define TV_DICTITEM_STRUCT(...) \
  struct { \
    typval_T di_tv;  /* Structure that holds scope dictionary itself. */ \
    uint8_t di_flags;  /* Flags. */ \
    char di_key[__VA_ARGS__];  /* Key value. */  /* NOLINT(runtime/arrays)*/ \
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
  QUEUE watchers;         ///< Dict key watchers set by user code.

  LuaRef lua_table_ref;
};

/// Structure to hold info about a Blob
struct blobvar_S {
  garray_T bv_ga;         ///< Growarray with the data.
  int bv_refcount;        ///< Reference count.
  VarLockStatus bv_lock;  ///< VAR_UNLOCKED, VAR_LOCKED, VAR_FIXED.
};

/// Type used for script ID
typedef int scid_T;
/// Format argument for scid_T
#define PRIdSCID "d"

/// SCript ConteXt (SCTX): identifies a script line.
/// When sourcing a script "sc_lnum" is zero, "sourcing_lnum" is the current
/// line number. When executing a user function "sc_lnum" is the line where the
/// function was defined, "sourcing_lnum" is the line number inside the
/// function.  When stored with a function, mapping, option, etc. "sc_lnum" is
/// the line number in the script "sc_sid".
typedef struct {
  scid_T sc_sid;     ///< script ID
  int sc_seq;        ///< sourcing sequence number
  linenr_T sc_lnum;  ///< line number
} sctx_T;

/// Stores an identifier of a script or channel that last set an option.
typedef struct {
  sctx_T script_ctx;       /// script context where the option was last set
  uint64_t channel_id;     /// Only used when script_id is SID_API_CLIENT.
} LastSet;

enum { MAX_FUNC_ARGS = 20, };  ///< Maximum number of function arguments
enum { VAR_SHORT_LEN = 20, };  ///< Short variable name length
enum { FIXVAR_CNT = 12, };     ///< Number of fixed variables used for arguments

/// Structure to hold info for a function that is currently being executed.
typedef struct funccall_S funccall_T;

struct funccall_S {
  ufunc_T *fc_func;                  ///< Function being called.
  int fc_linenr;                     ///< Next line to be executed.
  int fc_returned;                   ///< ":return" used.
  TV_DICTITEM_STRUCT(VAR_SHORT_LEN + 1) fc_fixvar[FIXVAR_CNT];  ///< Fixed variables for arguments.
  dict_T fc_l_vars;                  ///< l: local function variables.
  ScopeDictDictItem fc_l_vars_var;   ///< Variable for l: scope.
  dict_T fc_l_avars;                 ///< a: argument variables.
  ScopeDictDictItem fc_l_avars_var;  ///< Variable for a: scope.
  list_T fc_l_varlist;                       ///< List for a:000.
  listitem_T fc_l_listitems[MAX_FUNC_ARGS];  ///< List items for a:000.
  typval_T *fc_rettv;                ///< Return value.
  linenr_T fc_breakpoint;            ///< Next line with breakpoint or zero.
  int fc_dbg_tick;                   ///< "debug_tick" when breakpoint was set.
  int fc_level;                      ///< Top nesting level of executed function.
  garray_T fc_defer;                 ///< Functions to be called on return.
  proftime_T fc_prof_child;          ///< Time spent in a child.
  funccall_T *fc_caller;             ///< Calling function or NULL; or next funccal in
                                     ///< list pointed to by previous_funccal.
  int fc_refcount;                   ///< Number of user functions that reference this funccall.
  int fc_copyID;                     ///< CopyID used for garbage collection.
  garray_T fc_ufuncs;                ///< List of ufunc_T* which keep a reference to "fc_func".
};

/// Structure to hold info for a user function.
struct ufunc {
  int uf_varargs;       ///< variable nr of arguments
  int uf_flags;
  int uf_calls;         ///< nr of active calls
  bool uf_cleared;       ///< func_clear() was already called
  garray_T uf_args;          ///< arguments
  garray_T uf_def_args;      ///< default argument expressions
  garray_T uf_lines;         ///< function lines
  int uf_profiling;     ///< true when func is being profiled
  int uf_prof_initialized;
  LuaRef uf_luaref;      ///< lua callback, used if (uf_flags & FC_LUAREF)
  // Profiling the function as a whole.
  int uf_tm_count;      ///< nr of calls
  proftime_T uf_tm_total;      ///< time spent in function + children
  proftime_T uf_tm_self;       ///< time spent in function itself
  proftime_T uf_tm_children;   ///< time spent in children this call
  // Profiling the function per line.
  int *uf_tml_count;     ///< nr of times line was executed
  proftime_T *uf_tml_total;     ///< time spent in a line + children
  proftime_T *uf_tml_self;      ///< time spent in a line itself
  proftime_T uf_tml_start;     ///< start time for current line
  proftime_T uf_tml_children;  ///< time spent in children for this line
  proftime_T uf_tml_wait;      ///< start wait time for current line
  int uf_tml_idx;       ///< index of line being timed; -1 if none
  int uf_tml_execed;    ///< line being timed was executed
  sctx_T uf_script_ctx;    ///< SCTX where function was defined,
                           ///< used for s: variables
  int uf_refcount;      ///< reference count, see func_name_refcount()
  funccall_T *uf_scoped;       ///< l: local variables for closure
  char *uf_name_exp;    ///< if "uf_name[]" starts with SNR the name with
                        ///< "<SNR>" as a string, otherwise NULL
  char uf_name[];    ///< Name of function (actual size equals name);
                     ///< can start with <SNR>123_
                     ///< (<SNR> is K_SPECIAL KS_EXTRA KE_SNR)
};

struct partial_S {
  int pt_refcount;    ///< Reference count.
  int pt_copyID;
  char *pt_name;      ///< Function name; when NULL use pt_func->name.
  ufunc_T *pt_func;   ///< Function pointer; when NULL lookup function with pt_name.
  bool pt_auto;       ///< When true the partial was created by using dict.member
                      ///< in handle_subscript().
  int pt_argc;        ///< Number of arguments.
  typval_T *pt_argv;  ///< Arguments in allocated array.
  dict_T *pt_dict;    ///< Dict for "self".
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
