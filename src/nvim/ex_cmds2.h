#ifndef NVIM_EX_CMDS2_H
#define NVIM_EX_CMDS2_H

#include <stdbool.h>

#include "nvim/ex_docmd.h"
#include "nvim/runtime.h"

//
// flags for check_changed()
//
#define CCGD_AW         1       // do autowrite if buffer was changed
#define CCGD_MULTWIN    2       // check also when several wins for the buf
#define CCGD_FORCEIT    4       // ! used
#define CCGD_ALLBUF     8       // may write all buffers
#define CCGD_EXCMD      16      // may suggest using !

/// Also store the dev/ino, so that we don't have to stat() each
/// script when going through the list.
typedef struct scriptitem_S {
  char_u *sn_name;
  bool file_id_valid;
  FileID file_id;
  bool sn_prof_on;              ///< true when script is/was profiled
  bool sn_pr_force;             ///< forceit: profile functions in this script
  proftime_T sn_pr_child;       ///< time set when going into first child
  int sn_pr_nest;               ///< nesting for sn_pr_child
  // profiling the script as a whole
  int sn_pr_count;              ///< nr of times sourced
  proftime_T sn_pr_total;       ///< time spent in script + children
  proftime_T sn_pr_self;        ///< time spent in script itself
  proftime_T sn_pr_start;       ///< time at script start
  proftime_T sn_pr_children;    ///< time in children after script start
  // profiling the script per line
  garray_T sn_prl_ga;           ///< things stored for every line
  proftime_T sn_prl_start;      ///< start time for current line
  proftime_T sn_prl_children;   ///< time spent in children for this line
  proftime_T sn_prl_wait;       ///< wait start time for current line
  linenr_T sn_prl_idx;          ///< index of line being timed; -1 if none
  int sn_prl_execed;            ///< line being timed was executed
} scriptitem_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_cmds2.h.generated.h"
#endif
#endif  // NVIM_EX_CMDS2_H
