#ifndef NVIM_EVAL_H
#define NVIM_EVAL_H

#include "nvim/profile.h"
#include "nvim/hashtab.h"  // For hashtab_T
#include "nvim/garray.h"  // For garray_T
#include "nvim/buffer_defs.h"  // For scid_T
#include "nvim/ex_cmds_defs.h"  // For exarg_T

#define COPYID_INC 2
#define COPYID_MASK (~0x1)

// All user-defined functions are found in this hashtable.
extern hashtab_T func_hashtab;

// Structure to hold info for a user function.
typedef struct ufunc ufunc_T;

struct ufunc {
  int          uf_varargs;       ///< variable nr of arguments
  int          uf_flags;
  int          uf_calls;         ///< nr of active calls
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
  int          uf_refcount;      ///< for numbered function: reference count
  char_u       uf_name[1];       ///< name of function (actually longer); can
                                 //   start with <SNR>123_ (<SNR> is K_SPECIAL
                                 //   KS_EXTRA KE_SNR)
};

// From user function to hashitem and back.
EXTERN ufunc_T dumuf;
#define UF2HIKEY(fp) ((fp)->uf_name)
#define HIKEY2UF(p)  ((ufunc_T *)(p - (dumuf.uf_name - (char_u *)&dumuf)))
#define HI2UF(hi)    HIKEY2UF((hi)->hi_key)

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
    VV_COMMAND_OUTPUT,
    VV_COMPLETED_ITEM,
    VV_OPTION_NEW,
    VV_OPTION_OLD,
    VV_OPTION_TYPE,
    VV_ERRORS,
    VV_MSGPACK_TYPES,
    VV_EVENT,
    VV_FALSE,
    VV_TRUE,
    VV_NULL,
    VV__NULL_LIST,  // List with NULL value. For test purposes only.
    VV__NULL_DICT,  // Dictionary with NULL value. For test purposes only.
    VV_VIM_DID_ENTER,
    VV_TYPE_NUMBER,
    VV_TYPE_STRING,
    VV_TYPE_FUNC,
    VV_TYPE_LIST,
    VV_TYPE_DICT,
    VV_TYPE_FLOAT,
    VV_TYPE_BOOL,
    VV_EXITING,
} VimVarIndex;

/// All recognized msgpack types
typedef enum {
  kMPNil,
  kMPBoolean,
  kMPInteger,
  kMPFloat,
  kMPString,
  kMPBinary,
  kMPArray,
  kMPMap,
  kMPExt,
#define LAST_MSGPACK_TYPE kMPExt
} MessagePackType;

/// Array mapping values from MessagePackType to corresponding list pointers
extern const list_T *eval_msgpack_type_lists[LAST_MSGPACK_TYPE + 1];

#undef LAST_MSGPACK_TYPE

/// Maximum number of function arguments
#define MAX_FUNC_ARGS   20

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval.h.generated.h"
#endif
#endif  // NVIM_EVAL_H
