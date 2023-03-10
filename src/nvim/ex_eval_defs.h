#ifndef NVIM_EX_EVAL_DEFS_H
#define NVIM_EX_EVAL_DEFS_H

#include "nvim/pos.h"

/// There is no CSF_IF, the lack of CSF_WHILE, CSF_FOR and CSF_TRY means ":if"
/// was used.
enum {
  CSF_TRUE     = 0x0001,  ///< condition was TRUE
  CSF_ACTIVE   = 0x0002,  ///< current state is active
  CSF_ELSE     = 0x0004,  ///< ":else" has been passed
  CSF_WHILE    = 0x0008,  ///< is a ":while"
  CSF_FOR      = 0x0010,  ///< is a ":for"

  CSF_TRY      = 0x0100,  ///< is a ":try"
  CSF_FINALLY  = 0x0200,  ///< ":finally" has been passed
  CSF_THROWN   = 0x0800,  ///< exception thrown to this try conditional
  CSF_CAUGHT   = 0x1000,  ///< exception caught by this try conditional
  CSF_FINISHED = 0x2000,  ///< CSF_CAUGHT was handled by finish_exception()
  CSF_SILENT   = 0x4000,  ///< "emsg_silent" reset by ":try"
};
// Note that CSF_ELSE is only used when CSF_TRY and CSF_WHILE are unset
// (an ":if"), and CSF_SILENT is only used when CSF_TRY is set.

/// What's pending for being reactivated at the ":endtry" of this try
/// conditional:
enum {
  CSTP_NONE      = 0,   ///< nothing pending in ":finally" clause
  CSTP_ERROR     = 1,   ///< an error is pending
  CSTP_INTERRUPT = 2,   ///< an interrupt is pending
  CSTP_THROW     = 4,   ///< a throw is pending
  CSTP_BREAK     = 8,   ///< ":break" is pending
  CSTP_CONTINUE  = 16,  ///< ":continue" is pending
  CSTP_RETURN    = 24,  ///< ":return" is pending
  CSTP_FINISH    = 32,  ///< ":finish" is pending
};

/// A list of error messages that can be converted to an exception.  "throw_msg"
/// is only set in the first element of the list.  Usually, it points to the
/// original message stored in that element, but sometimes it points to a later
/// message in the list.  See cause_errthrow().
typedef struct msglist msglist_T;
struct msglist {
  char *msg;        ///< original message, allocated
  char *throw_msg;  ///< msg to throw: usually original one
  char *sfile;      ///< value from estack_sfile(), allocated
  linenr_T slnum;   ///< line number for "sfile"
  msglist_T *next;  ///< next of several messages in a row
};

/// The exception types.
typedef enum {
  ET_USER,       ///< exception caused by ":throw" command
  ET_ERROR,      ///< error exception
  ET_INTERRUPT,  ///< interrupt exception triggered by Ctrl-C
} except_type_T;

/// Structure describing an exception.
/// (don't use "struct exception", it's used by the math library).
typedef struct vim_exception except_T;
struct vim_exception {
  except_type_T type;   ///< exception type
  char *value;          ///< exception value
  msglist_T *messages;  ///< message(s) causing error exception
  char *throw_name;     ///< name of the throw point
  linenr_T throw_lnum;  ///< line number of the throw point
  except_T *caught;     ///< next exception on the caught stack
};

/// Structure to save the error/interrupt/exception state between calls to
/// enter_cleanup() and leave_cleanup().  Must be allocated as an automatic
/// variable by the (common) caller of these functions.
typedef struct cleanup_stuff cleanup_T;
struct cleanup_stuff {
  int pending;          ///< error/interrupt/exception state
  except_T *exception;  ///< exception value
};

#endif  // NVIM_EX_EVAL_DEFS_H
