#ifndef NVIM_RUNTIME_H
#define NVIM_RUNTIME_H

#include <stdbool.h>

#include "nvim/ex_cmds_defs.h"

typedef struct scriptitem_S {
  char_u *sn_name;
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

/// Growarray to store info about already sourced scripts.
extern garray_T script_items;
#define SCRIPT_ITEM(id) (((scriptitem_T *)script_items.ga_data)[(id) - 1])

typedef void (*DoInRuntimepathCB)(char *, void *);

typedef struct {
  char *path;
  bool after;
  TriState has_lua;
} SearchPathItem;

typedef kvec_t(SearchPathItem) RuntimeSearchPath;
typedef kvec_t(char *) CharVec;

// last argument for do_source()
#define DOSO_NONE       0
#define DOSO_VIMRC      1       // loading vimrc file

// Used for flags in do_in_path()
#define DIP_ALL 0x01    // all matches, not just the first one
#define DIP_DIR 0x02    // find directories instead of files
#define DIP_ERR 0x04    // give an error message when none found
#define DIP_START 0x08  // also use "start" directory in 'packpath'
#define DIP_OPT 0x10    // also use "opt" directory in 'packpath'
#define DIP_NORTP 0x20  // do not use 'runtimepath'
#define DIP_NOAFTER 0x40  // skip "after" directories
#define DIP_AFTER   0x80  // only use "after" directories
#define DIP_LUA  0x100    // also use ".lua" files
#define DIP_DIRFILE 0x200  // find both files and directories

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "runtime.h.generated.h"
#endif
#endif  // NVIM_RUNTIME_H
