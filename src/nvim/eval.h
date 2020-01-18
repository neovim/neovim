#ifndef NVIM_EVAL_H
#define NVIM_EVAL_H

#include "nvim/hashtab.h"  // For hashtab_T
#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"  // For exarg_T
#include "nvim/eval/typval.h"
#include "nvim/profile.h"
#include "nvim/garray.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/channel.h"
#include "nvim/os/stdpaths_defs.h"

#define COPYID_INC 2
#define COPYID_MASK (~0x1)

// All user-defined functions are found in this hashtable.
extern hashtab_T func_hashtab;

// From user function to hashitem and back.
EXTERN ufunc_T dumuf;
#define UF2HIKEY(fp) ((fp)->uf_name)
#define HIKEY2UF(p)  ((ufunc_T *)(p - offsetof(ufunc_T, uf_name)))
#define HI2UF(hi)    HIKEY2UF((hi)->hi_key)

/// enum used by var_flavour()
typedef enum {
  VAR_FLAVOUR_DEFAULT = 1,   // doesn't start with uppercase
  VAR_FLAVOUR_SESSION = 2,   // starts with uppercase, some lower
  VAR_FLAVOUR_SHADA   = 4    // all uppercase
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
    VV_STDERR,
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
    VV_TESTING,
    VV_TYPE_NUMBER,
    VV_TYPE_STRING,
    VV_TYPE_FUNC,
    VV_TYPE_LIST,
    VV_TYPE_DICT,
    VV_TYPE_FLOAT,
    VV_TYPE_BOOL,
    VV_ECHOSPACE,
    VV_EXITING,
    VV_LUA,
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

typedef int (*ArgvFunc)(int current_argcount, typval_T *argv,
                        int called_func_argcount);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval.h.generated.h"
#endif
#endif  // NVIM_EVAL_H
