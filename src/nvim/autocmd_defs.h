#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "auevents_enum.generated.h"
#endif

/// Struct to save values in before executing autocommands for a buffer that is
/// not the current buffer.
typedef struct {
  int use_aucmd_win_idx;          ///< index in aucmd_win[] if >= 0
  handle_T save_curwin_handle;    ///< ID of saved curwin
  handle_T new_curwin_handle;     ///< ID of new curwin
  handle_T save_prevwin_handle;   ///< ID of saved prevwin
  bufref_T new_curbuf;            ///< new curbuf
  char *tp_localdir;              ///< saved value of tp_localdir
  char *globaldir;                ///< saved value of globaldir
  bool save_VIsual_active;        ///< saved VIsual_active
  int save_State;                 ///< saved State
  int save_prompt_insert;         ///< saved b_prompt_insert
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
  char *afile_orig;         ///< Unexpanded <afile>
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
