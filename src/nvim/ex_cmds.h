#ifndef NVIM_EX_CMDS_H
#define NVIM_EX_CMDS_H

#include <stdbool.h>

#include "nvim/os/time.h"
#include "nvim/eval_defs.h"

/* flags for do_ecmd() */
#define ECMD_HIDE       0x01    /* don't free the current buffer */
#define ECMD_SET_HELP   0x02    /* set b_help flag of (new) buffer before
                                   opening file */
#define ECMD_OLDBUF     0x04    /* use existing buffer if it exists */
#define ECMD_FORCEIT    0x08    /* ! used in Ex command */
#define ECMD_ADDBUF     0x10    /* don't edit, just add to buffer list */

/* for lnum argument in do_ecmd() */
#define ECMD_LASTL      (linenr_T)0     /* use last position in loaded file */
#define ECMD_LAST       (linenr_T)-1    /* use last position in all files */
#define ECMD_ONE        (linenr_T)1     /* use first line */

/// for cmdl_progress in live substitution
typedef enum {
  LS_NO_WD,                 /// state of the command line when none of the words are typed : 
                              /// ":%s" or ":%s/"
  LS_ONE_WD,                /// state of the command line when only the pattern word has began 
                              /// to be typed : ":%s/patt"
  LS_TWO_SLASH_ONE_WD,      /// sentry case : the second slash has been typed on but not the second
                              /// word yet : "%s/pattern/"
  LS_TWO_WD                /// state of the command line when the pattern has been completed 
                            /// and the substitue is being typed : ":%s/pattern/subs"
} LiveSub_state;

/// Previous :substitute replacement string definition
typedef struct {
  char *sub;            ///< Previous replacement string.
  Timestamp timestamp;  ///< Time when it was last set.
  list_T *additional_elements;  ///< Additional data left from ShaDa file.
} SubReplacementString;

/// Defs for live_sub functionality
#define _noop(x)
/// initializer for a list of match in a line
KLIST_INIT(colnr_T, colnr_T,_noop)

/// structure to backup and display matched lines in live_substitution
typedef struct {
  linenr_T lnum;
  long nmatch;
  char_u *line;
  klist_t(colnr_T) *start_col;
} matchedline_T;

/// initializer for a list of matched lines
KLIST_INIT(matchedline_T, matchedline_T, _noop)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds.h.generated.h"
#endif
#endif  // NVIM_EX_CMDS_H
