#ifndef NVIM_EX_EVAL_H
#define NVIM_EX_EVAL_H

#include "nvim/ex_cmds_defs.h"  // for exarg_T

/* There is no CSF_IF, the lack of CSF_WHILE, CSF_FOR and CSF_TRY means ":if"
 * was used. */
#define CSF_TRUE       0x0001  // condition was TRUE
#define CSF_ACTIVE     0x0002  // current state is active
#define CSF_ELSE       0x0004  // ":else" has been passed
#define CSF_WHILE      0x0008  // is a ":while"
#define CSF_FOR        0x0010  // is a ":for"

#define CSF_TRY        0x0100  // is a ":try"
#define CSF_FINALLY    0x0200  // ":finally" has been passed
#define CSF_THROWN     0x0400  // exception thrown to this try conditional
#define CSF_CAUGHT     0x0800  // exception caught by this try conditional
#define CSF_SILENT     0x1000  // "emsg_silent" reset by ":try"
// Note that CSF_ELSE is only used when CSF_TRY and CSF_WHILE are unset
// (an ":if"), and CSF_SILENT is only used when CSF_TRY is set.

/*
 * What's pending for being reactivated at the ":endtry" of this try
 * conditional:
 */
#define CSTP_NONE      0       // nothing pending in ":finally" clause
#define CSTP_ERROR     1       // an error is pending
#define CSTP_INTERRUPT 2       // an interrupt is pending
#define CSTP_THROW     4       // a throw is pending
#define CSTP_BREAK     8       // ":break" is pending
#define CSTP_CONTINUE  16      // ":continue" is pending
#define CSTP_RETURN    24      // ":return" is pending
#define CSTP_FINISH    32      // ":finish" is pending

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_eval.h.generated.h"
#endif
#endif  // NVIM_EX_EVAL_H
