#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/channel_defs.h"  // IWYU pragma: keep
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/eval_defs.h"  // IWYU pragma: keep
#include "nvim/event/defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/grid_defs.h"  // IWYU pragma: keep
#include "nvim/hashtab_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte_defs.h"  // IWYU pragma: keep
#include "nvim/msgpack_rpc/channel_defs.h"  // IWYU pragma: keep
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/os/fileio_defs.h"  // IWYU pragma: keep
#include "nvim/os/stdpaths_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

#define COPYID_INC 2
#define COPYID_MASK (~0x1)

// Structure returned by get_lval() and used by set_var_lval().
// For a plain name:
//      "name"      points to the variable name.
//      "exp_name"  is NULL.
//      "tv"        is NULL
// For a magic braces name:
//      "name"      points to the expanded variable name.
//      "exp_name"  is non-NULL, to be freed later.
//      "tv"        is NULL
// For an index in a list:
//      "name"      points to the (expanded) variable name.
//      "exp_name"  NULL or non-NULL, to be freed later.
//      "tv"        points to the (first) list item value
//      "li"        points to the (first) list item
//      "range", "n1", "n2" and "empty2" indicate what items are used.
// For an existing Dict item:
//      "name"      points to the (expanded) variable name.
//      "exp_name"  NULL or non-NULL, to be freed later.
//      "tv"        points to the dict item value
//      "newkey"    is NULL
// For a non-existing Dict item:
//      "name"      points to the (expanded) variable name.
//      "exp_name"  NULL or non-NULL, to be freed later.
//      "tv"        points to the Dictionary typval_T
//      "newkey"    is the key for the new item.
typedef struct {
  const char *ll_name;  ///< Start of variable name (can be NULL).
  size_t ll_name_len;   ///< Length of the .ll_name.
  char *ll_exp_name;    ///< NULL or expanded name in allocated memory.
  typval_T *ll_tv;      ///< Typeval of item being used.  If "newkey"
  ///< isn't NULL it's the Dict to which to add the item.
  listitem_T *ll_li;  ///< The list item or NULL.
  list_T *ll_list;    ///< The list or NULL.
  bool ll_range;      ///< true when a [i:j] range was used.
  bool ll_empty2;     ///< Second index is empty: [i:].
  int ll_n1;          ///< First index for list.
  int ll_n2;          ///< Second index for list range.
  dict_T *ll_dict;    ///< The Dict or NULL.
  dictitem_T *ll_di;  ///< The dictitem or NULL.
  char *ll_newkey;    ///< New key for Dict in allocated memory or NULL.
  blob_T *ll_blob;    ///< The Blob or NULL.
} lval_T;

/// enum used by var_flavour()
typedef enum {
  VAR_FLAVOUR_DEFAULT = 1,   // doesn't start with uppercase
  VAR_FLAVOUR_SESSION = 2,   // starts with uppercase, some lower
  VAR_FLAVOUR_SHADA   = 4,  // all uppercase
} var_flavour_T;

/// Defines for Vim variables
typedef enum {
  VV_COUNT,
  VV_COUNT1,
  VV_PREVCOUNT,
  VV_ERRMSG,
  VV_WARNINGMSG,
  VV_STATUSMSG,
  VV_SHELL_ERROR,
  VV_THIS_SESSION,
  VV_VERSION,
  VV_LNUM,
  VV_TERMREQUEST,
  VV_TERMRESPONSE,
  VV_FNAME,
  VV_LANG,
  VV_LC_TIME,
  VV_CTYPE,
  VV_CC_FROM,
  VV_CC_TO,
  VV_FNAME_IN,
  VV_FNAME_OUT,
  VV_FNAME_NEW,
  VV_FNAME_DIFF,
  VV_CMDARG,
  VV_FOLDSTART,
  VV_FOLDEND,
  VV_FOLDDASHES,
  VV_FOLDLEVEL,
  VV_PROGNAME,
  VV_SEND_SERVER,
  VV_DYING,
  VV_EXCEPTION,
  VV_THROWPOINT,
  VV_REG,
  VV_CMDBANG,
  VV_INSERTMODE,
  VV_VAL,
  VV_KEY,
  VV_PROFILING,
  VV_FCS_REASON,
  VV_FCS_CHOICE,
  VV_BEVAL_BUFNR,
  VV_BEVAL_WINNR,
  VV_BEVAL_WINID,
  VV_BEVAL_LNUM,
  VV_BEVAL_COL,
  VV_BEVAL_TEXT,
  VV_SCROLLSTART,
  VV_SWAPNAME,
  VV_SWAPCHOICE,
  VV_SWAPCOMMAND,
  VV_CHAR,
  VV_MOUSE_WIN,
  VV_MOUSE_WINID,
  VV_MOUSE_LNUM,
  VV_MOUSE_COL,
  VV_OP,
  VV_SEARCHFORWARD,
  VV_HLSEARCH,
  VV_OLDFILES,
  VV_WINDOWID,
  VV_PROGPATH,
  VV_COMPLETED_ITEM,
  VV_OPTION_NEW,
  VV_OPTION_OLD,
  VV_OPTION_OLDLOCAL,
  VV_OPTION_OLDGLOBAL,
  VV_OPTION_COMMAND,
  VV_OPTION_TYPE,
  VV_ERRORS,
  VV_FALSE,
  VV_TRUE,
  VV_NULL,
  VV_NUMBERMAX,
  VV_NUMBERMIN,
  VV_NUMBERSIZE,
  VV_VIM_DID_ENTER,
  VV_TESTING,
  VV_TYPE_NUMBER,
  VV_TYPE_STRING,
  VV_TYPE_FUNC,
  VV_TYPE_LIST,
  VV_TYPE_DICT,
  VV_TYPE_FLOAT,
  VV_TYPE_BOOL,
  VV_TYPE_BLOB,
  VV_EVENT,
  VV_ECHOSPACE,
  VV_ARGV,
  VV_COLLATE,
  VV_EXITING,
  VV_MAXCOL,
  VV_STACKTRACE,
  // Nvim
  VV_STDERR,
  VV_MSGPACK_TYPES,
  VV__NULL_STRING,  // String with NULL value. For test purposes only.
  VV__NULL_LIST,  // List with NULL value. For test purposes only.
  VV__NULL_DICT,  // Dict with NULL value. For test purposes only.
  VV__NULL_BLOB,  // Blob with NULL value. For test purposes only.
  VV_LUA,
  VV_RELNUM,
  VV_VIRTNUM,
} VimVarIndex;

/// Array mapping values from MessagePackType to corresponding list pointers
extern const list_T *eval_msgpack_type_lists[NUM_MSGPACK_TYPES];

// Struct passed to get_v_event() and restore_v_event().
typedef struct {
  bool sve_did_save;
  hashtab_T sve_hashtab;
} save_v_event_T;

/// trans_function_name() flags
typedef enum {
  TFN_INT = 1,  ///< May use internal function name
  TFN_QUIET = 2,  ///< Do not emit error messages.
  TFN_NO_AUTOLOAD = 4,  ///< Do not use script autoloading.
  TFN_NO_DEREF = 8,  ///< Do not dereference a Funcref.
  TFN_READ_ONLY = 16,  ///< Will not change the variable.
} TransFunctionNameFlags;

/// get_lval() flags
typedef enum {
  GLV_QUIET = TFN_QUIET,  ///< Do not emit error messages.
  GLV_NO_AUTOLOAD = TFN_NO_AUTOLOAD,  ///< Do not use script autoloading.
  GLV_READ_ONLY = TFN_READ_ONLY,  ///< Indicates that caller will not change
                                  ///< the value (prevents error message).
} GetLvalFlags;

/// flags for find_name_end()
#define FNE_INCL_BR     1       // find_name_end(): include [] in name
#define FNE_CHECK_START 2       // find_name_end(): check name starts with
                                // valid character

typedef struct {
  TimeWatcher tw;
  int timer_id;
  int repeat_count;
  int refcount;
  int emsg_count;  ///< Errors in a repeating timer.
  int64_t timeout;
  bool stopped;
  bool paused;
  Callback callback;
} timer_T;

/// types for expressions.
typedef enum {
  EXPR_UNKNOWN = 0,
  EXPR_EQUAL,         ///< ==
  EXPR_NEQUAL,        ///< !=
  EXPR_GREATER,       ///< >
  EXPR_GEQUAL,        ///< >=
  EXPR_SMALLER,       ///< <
  EXPR_SEQUAL,        ///< <=
  EXPR_MATCH,         ///< =~
  EXPR_NOMATCH,       ///< !~
  EXPR_IS,            ///< is
  EXPR_ISNOT,         ///< isnot
} exprtype_T;

// Used for checking if local variables or arguments used in a lambda.
extern bool *eval_lavars_used;

// Character used as separated in autoload function/variable names.
#define AUTOLOAD_CHAR '#'

/// Flag for expression evaluation.
enum {
  EVAL_EVALUATE = 1,  ///< when missing don't actually evaluate
};

/// Passed to an eval() function to enable evaluation.
EXTERN evalarg_T EVALARG_EVALUATE INIT( = { EVAL_EVALUATE, NULL, NULL, NULL });

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval.h.generated.h"
#endif
