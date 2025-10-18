#pragma once

#include "nvim/ex_cmds_defs.h"

/// All recognized msgpack types
typedef enum {
  kMPNil,
  kMPBoolean,
  kMPInteger,
  kMPFloat,
  kMPString,
  kMPArray,
  kMPMap,
  kMPExt,
} MessagePackType;
#define NUM_MSGPACK_TYPES (kMPExt + 1)

/// Struct passed through eval() functions.
/// See EVALARG_EVALUATE for a fixed value with eval_flags set to EVAL_EVALUATE.
typedef struct {
  int eval_flags;     ///< EVAL_ flag values below

  /// copied from exarg_T when "getline" is "getsourceline". Can be NULL.
  LineGetter eval_getline;
  void *eval_cookie;  ///< argument for eval_getline()

  /// pointer to the last line obtained with getsourceline()
  char *eval_tofree;
} evalarg_T;

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
  VV_VERSIONLONG,
  VV_ECHOSPACE,
  VV_ARGF,
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
