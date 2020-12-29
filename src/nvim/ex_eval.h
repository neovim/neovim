#ifndef NVIM_EX_EVAL_H
#define NVIM_EX_EVAL_H

#include "nvim/pos.h"           // for linenr_T
#include "nvim/ex_cmds_defs.h"  // for exarg_T

/* There is no CSF_IF, the lack of CSF_WHILE, CSF_FOR and CSF_TRY means ":if"
 * was used. */
# define CSF_TRUE       0x0001  /* condition was TRUE */
# define CSF_ACTIVE     0x0002  /* current state is active */
# define CSF_ELSE       0x0004  /* ":else" has been passed */
# define CSF_WHILE      0x0008  /* is a ":while" */
# define CSF_FOR        0x0010  /* is a ":for" */

# define CSF_TRY        0x0100  /* is a ":try" */
# define CSF_FINALLY    0x0200  /* ":finally" has been passed */
# define CSF_THROWN     0x0400  /* exception thrown to this try conditional */
# define CSF_CAUGHT     0x0800  /* exception caught by this try conditional */
# define CSF_SILENT     0x1000  /* "emsg_silent" reset by ":try" */
/* Note that CSF_ELSE is only used when CSF_TRY and CSF_WHILE are unset
 * (an ":if"), and CSF_SILENT is only used when CSF_TRY is set. */

/*
 * What's pending for being reactivated at the ":endtry" of this try
 * conditional:
 */
# define CSTP_NONE      0       /* nothing pending in ":finally" clause */
# define CSTP_ERROR     1       /* an error is pending */
# define CSTP_INTERRUPT 2       /* an interrupt is pending */
# define CSTP_THROW     4       /* a throw is pending */
# define CSTP_BREAK     8       /* ":break" is pending */
# define CSTP_CONTINUE  16      /* ":continue" is pending */
# define CSTP_RETURN    24      /* ":return" is pending */
# define CSTP_FINISH    32      /* ":finish" is pending */

/*
 * A list of error messages that can be converted to an exception.  "throw_msg"
 * is only set in the first element of the list.  Usually, it points to the
 * original message stored in that element, but sometimes it points to a later
 * message in the list.  See cause_errthrow() below.
 */
struct msglist {
  char_u              *msg;             /* original message */
  char_u              *throw_msg;       /* msg to throw: usually original one */
  struct msglist      *next;            /* next of several messages in a row */
};

// The exception types.
typedef enum
{
  ET_USER,       // exception caused by ":throw" command
  ET_ERROR,      // error exception
  ET_INTERRUPT,  // interrupt exception triggered by Ctrl-C
} except_type_T;

/*
 * Structure describing an exception.
 * (don't use "struct exception", it's used by the math library).
 */
typedef struct vim_exception except_T;
struct vim_exception {
  except_type_T type;                   // exception type
  char_u              *value;           // exception value
  struct msglist      *messages;        // message(s) causing error exception
  char_u              *throw_name;      // name of the throw point
  linenr_T throw_lnum;                  // line number of the throw point
  except_T            *caught;          // next exception on the caught stack
};

/*
 * Structure to save the error/interrupt/exception state between calls to
 * enter_cleanup() and leave_cleanup().  Must be allocated as an automatic
 * variable by the (common) caller of these functions.
 */
typedef struct cleanup_stuff cleanup_T;
struct cleanup_stuff {
  int pending;                  /* error/interrupt/exception state */
  except_T *exception;          /* exception value */
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_eval.h.generated.h"
#endif
#endif  // NVIM_EX_EVAL_H
