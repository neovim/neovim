#ifndef NVIM_EX_DOCMD_H
#define NVIM_EX_DOCMD_H

#include "nvim/ex_cmds_defs.h"
#include "nvim/globals.h"

// flags for do_cmdline()
#define DOCMD_VERBOSE   0x01      // included command in error message
#define DOCMD_NOWAIT    0x02      // don't call wait_return() and friends
#define DOCMD_REPEAT    0x04      // repeat exec. until getline() returns NULL
#define DOCMD_KEYTYPED  0x08      // don't reset KeyTyped
#define DOCMD_EXCRESET  0x10      // reset exception environment (for debugging
#define DOCMD_KEEPLINE  0x20      // keep typed line for repeating with "."
#define DOCMD_PREVIEW   0x40      // during 'inccommand' preview

/* defines for eval_vars() */
#define VALID_PATH              1
#define VALID_HEAD              2

// Structure used to save the current state.  Used when executing Normal mode
// commands while in any other mode.
typedef struct {
  int save_msg_scroll;
  int save_restart_edit;
  bool save_msg_didout;
  int save_State;
  int save_insertmode;
  bool save_finish_op;
  long save_opcount;
  int save_reg_executing;
  tasave_T tabuf;
} save_state_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_docmd.h.generated.h"
#endif
#endif  // NVIM_EX_DOCMD_H
