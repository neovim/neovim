#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/autocmd.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/garray.h"
#include "nvim/option_defs.h"
#include "nvim/pos.h"
#include "nvim/types.h"

typedef enum {
  ETYPE_TOP,       ///< toplevel
  ETYPE_SCRIPT,    ///< sourcing script, use es_info.sctx
  ETYPE_UFUNC,     ///< user function, use es_info.ufunc
  ETYPE_AUCMD,     ///< autocomand, use es_info.aucmd
  ETYPE_MODELINE,  ///< modeline, use es_info.sctx
  ETYPE_EXCEPT,    ///< exception, use es_info.exception
  ETYPE_ARGS,      ///< command line argument
  ETYPE_ENV,       ///< environment variable
  ETYPE_INTERNAL,  ///< internal operation
  ETYPE_SPELL,     ///< loading spell file
} etype_T;

/// Entry in the execution stack "exestack".
typedef struct {
  linenr_T es_lnum;     ///< replaces "sourcing_lnum"
  char *es_name;        ///< replaces "sourcing_name"
  etype_T es_type;
  union {
    sctx_T *sctx;       ///< script and modeline info
    ufunc_T *ufunc;     ///< function info
    AutoPatCmd *aucmd;  ///< autocommand info
    except_T *except;   ///< exception info
  } es_info;
} estack_T;

/// Stack of execution contexts.  Each entry is an estack_T.
/// Current context is at ga_len - 1.
extern garray_T exestack;
/// name of error message source
#define SOURCING_NAME (((estack_T *)exestack.ga_data)[exestack.ga_len - 1].es_name)
/// line number in the message source or zero
#define SOURCING_LNUM (((estack_T *)exestack.ga_data)[exestack.ga_len - 1].es_lnum)

/// Argument for estack_sfile().
typedef enum {
  ESTACK_NONE,
  ESTACK_SFILE,
  ESTACK_STACK,
  ESTACK_SCRIPT,
} estack_arg_T;

/// Holds the hashtab with variables local to each sourced script.
/// Each item holds a variable (nameless) that points to the dict_T.
typedef struct {
  ScopeDictDictItem sv_var;
  dict_T sv_dict;
} scriptvar_T;

typedef struct {
  scriptvar_T *sn_vars;         ///< stores s: variables for this script

  char *sn_name;
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
#define SCRIPT_ITEM(id) (((scriptitem_T **)script_items.ga_data)[(id) - 1])
#define SCRIPT_ID_VALID(id) ((id) > 0 && (id) <= script_items.ga_len)

typedef bool (*DoInRuntimepathCB)(int, char **, bool, void *);

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
#define DIP_DIRFILE 0x200  // find both files and directories

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "runtime.h.generated.h"
#endif
