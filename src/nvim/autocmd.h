#ifndef NVIM_AUTOCMD_H
#define NVIM_AUTOCMD_H

#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/macros.h"
#include "nvim/regexp_defs.h"
#include "nvim/types.h"

struct AutoCmd_S;
struct AutoPatCmd_S;
struct AutoPat_S;

// event_T definition
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "auevents_enum.generated.h"
#endif

// Struct to save values in before executing autocommands for a buffer that is
// not the current buffer.
typedef struct {
  buf_T *save_curbuf;             ///< saved curbuf
  int use_aucmd_win_idx;          ///< index in aucmd_win[] if >= 0
  handle_T save_curwin_handle;    ///< ID of saved curwin
  handle_T new_curwin_handle;     ///< ID of new curwin
  handle_T save_prevwin_handle;   ///< ID of saved prevwin
  bufref_T new_curbuf;            ///< new curbuf
  char *globaldir;                ///< saved value of globaldir
  bool save_VIsual_active;        ///< saved VIsual_active
} aco_save_T;

typedef struct AutoCmd_S AutoCmd;
struct AutoCmd_S {
  AucmdExecutable exec;
  bool once;                            // "One shot": removed after execution
  bool nested;                          // If autocommands nest here
  bool last;                            // last command in list
  int64_t id;                           // ID used for uniquely tracking an autocmd.
  sctx_T script_ctx;                    // script context where it is defined
  char *desc;                           // Description for the autocmd.
  AutoCmd *next;                        // Next AutoCmd in list
};

typedef struct AutoPat_S AutoPat;
struct AutoPat_S {
  AutoPat *next;                        // next AutoPat in AutoPat list; MUST
                                        // be the first entry
  char *pat;                            // pattern as typed (NULL when pattern
                                        // has been removed)
  regprog_T *reg_prog;                  // compiled regprog for pattern
  AutoCmd *cmds;                        // list of commands to do
  int group;                            // group ID
  int patlen;                           // strlen() of pat
  int buflocal_nr;                      // !=0 for buffer-local AutoPat
  char allow_dirs;                      // Pattern may match whole path
  char last;                            // last pattern for apply_autocmds()
};

/// Struct used to keep status while executing autocommands for an event.
typedef struct AutoPatCmd_S AutoPatCmd;
struct AutoPatCmd_S {
  AutoPat *curpat;          // next AutoPat to examine
  AutoCmd *nextcmd;         // next AutoCmd to execute
  int group;                // group being used
  char *fname;              // fname to match with
  char *sfname;             // sfname to match with
  char *tail;               // tail of fname
  event_T event;            // current event
  sctx_T script_ctx;        // script context where it is defined
  int arg_bufnr;            // initially equal to <abuf>, set to zero when buf is deleted
  Object *data;             // arbitrary data
  AutoPatCmd *next;         // chain of active apc-s for auto-invalidation
};

// Set by the apply_autocmds_group function if the given event is equal to
// EVENT_FILETYPE. Used by the readfile function in order to determine if
// EVENT_BUFREADPOST triggered the EVENT_FILETYPE.
//
// Relying on this value requires one to reset it prior calling
// apply_autocmds_group.
EXTERN bool au_did_filetype INIT(= false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "autocmd.h.generated.h"
#endif

#define AUGROUP_DEFAULT    (-1)      // default autocmd group
#define AUGROUP_ERROR      (-2)      // erroneous autocmd group
#define AUGROUP_ALL        (-3)      // all autocmd groups
#define AUGROUP_DELETED    (-4)      // all autocmd groups
// #define AUGROUP_NS       -5      // TODO(tjdevries): Support namespaced based augroups

#define BUFLOCAL_PAT_LEN 25

/// Iterates over all the events for auto commands
#define FOR_ALL_AUEVENTS(event) \
  for (event_T event = (event_T)0; (int)event < (int)NUM_EVENTS; event = (event_T)((int)event + 1))  // NOLINT

#endif  // NVIM_AUTOCMD_H
