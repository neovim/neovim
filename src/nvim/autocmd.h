#ifndef NVIM_AUTOCMD_H
#define NVIM_AUTOCMD_H

#include <stdbool.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/macros.h"
#include "nvim/regexp_defs.h"
#include "nvim/types.h"

struct AutoPatCmd_S;

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
  int save_State;                 ///< saved State
} aco_save_T;

typedef struct {
  size_t refcount;          ///< Reference count (freed when reaches zero)
  char *pat;                ///< Pattern as typed
  regprog_T *reg_prog;      ///< Compiled regprog for pattern
  int group;                ///< Group ID
  int patlen;               ///< strlen() of pat
  int buflocal_nr;          ///< !=0 for buffer-local AutoPat
  char allow_dirs;          ///< Pattern may match whole path
} AutoPat;

typedef struct {
  AucmdExecutable exec;     ///< Command or callback function
  AutoPat *pat;             ///< Pattern reference (NULL when autocmd was removed)
  int64_t id;               ///< ID used for uniquely tracking an autocmd
  char *desc;               ///< Description for the autocmd
  sctx_T script_ctx;        ///< Script context where it is defined
  bool once;                ///< "One shot": removed after execution
  bool nested;              ///< If autocommands nest here
} AutoCmd;

/// Struct used to keep status while executing autocommands for an event.
typedef struct AutoPatCmd_S AutoPatCmd;
struct AutoPatCmd_S {
  AutoPat *lastpat;         ///< Last matched AutoPat
  size_t auidx;             ///< Current autocmd index to execute
  size_t ausize;            ///< Saved AutoCmd vector size
  char *fname;              ///< Fname to match with
  char *sfname;             ///< Sfname to match with
  char *tail;               ///< Tail of fname
  int group;                ///< Group being used
  event_T event;            ///< Current event
  sctx_T script_ctx;        ///< Script context where it is defined
  int arg_bufnr;            ///< Initially equal to <abuf>, set to zero when buf is deleted
  Object *data;             ///< Arbitrary data
  AutoPatCmd *next;         ///< Chain of active apc-s for auto-invalidation
};

typedef kvec_t(AutoCmd) AutoCmdVec;

// Set by the apply_autocmds_group function if the given event is equal to
// EVENT_FILETYPE. Used by the readfile function in order to determine if
// EVENT_BUFREADPOST triggered the EVENT_FILETYPE.
//
// Relying on this value requires one to reset it prior calling
// apply_autocmds_group.
EXTERN bool au_did_filetype INIT(= false);

/// For CursorMoved event
EXTERN win_T *last_cursormoved_win INIT(= NULL);
/// For CursorMoved event, only used when last_cursormoved_win == curwin
EXTERN pos_T last_cursormoved INIT(= { 0, 0, 0 });

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
