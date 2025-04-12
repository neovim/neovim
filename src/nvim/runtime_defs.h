#pragma once

#include <stdbool.h>

#include "nvim/autocmd_defs.h"

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
  bool sn_lua;                  ///< true for a lua script
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

typedef bool (*DoInRuntimepathCB)(int, char **, bool, void *);
