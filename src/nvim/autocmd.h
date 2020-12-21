#ifndef NVIM_AUTOCMD_H
#define NVIM_AUTOCMD_H

#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"

// Struct to save values in before executing autocommands for a buffer that is
// not the current buffer.
typedef struct {
  buf_T *save_curbuf;             ///< saved curbuf
  bool use_aucmd_win;             ///< using aucmd_win
  handle_T save_curwin_handle;    ///< ID of saved curwin
  handle_T new_curwin_handle;     ///< ID of new curwin
  handle_T save_prevwin_handle;   ///< ID of saved prevwin
  bufref_T new_curbuf;            ///< new curbuf
  char_u *globaldir;              ///< saved value of globaldir
} aco_save_T;

typedef struct AutoCmd {
  char_u          *cmd;                 // Command to be executed (NULL when
                                        // command has been removed)
  bool once;                            // "One shot": removed after execution
  bool nested;                          // If autocommands nest here
  bool last;                            // last command in list
  sctx_T script_ctx;                    // script context where defined
  struct AutoCmd  *next;                // Next AutoCmd in list
} AutoCmd;

typedef struct AutoPat {
  struct AutoPat  *next;                // next AutoPat in AutoPat list; MUST
                                        // be the first entry
  char_u          *pat;                 // pattern as typed (NULL when pattern
                                        // has been removed)
  regprog_T       *reg_prog;            // compiled regprog for pattern
  AutoCmd         *cmds;                // list of commands to do
  int group;                            // group ID
  int patlen;                           // strlen() of pat
  int buflocal_nr;                      // !=0 for buffer-local AutoPat
  char allow_dirs;                      // Pattern may match whole path
  char last;                            // last pattern for apply_autocmds()
} AutoPat;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "auevents_enum.generated.h"
#endif

///
/// Struct used to keep status while executing autocommands for an event.
///
typedef struct AutoPatCmd {
  AutoPat     *curpat;          // next AutoPat to examine
  AutoCmd     *nextcmd;         // next AutoCmd to execute
  int group;                    // group being used
  char_u      *fname;           // fname to match with
  char_u      *sfname;          // sfname to match with
  char_u      *tail;            // tail of fname
  event_T event;                // current event
  int arg_bufnr;                // initially equal to <abuf>, set to zero when
                                // buf is deleted
  struct AutoPatCmd   *next;    // chain of active apc-s for auto-invalidation
} AutoPatCmd;


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

#define AUGROUP_DEFAULT    -1      // default autocmd group
#define AUGROUP_ERROR      -2      // erroneous autocmd group
#define AUGROUP_ALL        -3      // all autocmd groups

#endif  // NVIM_AUTOCMD_H
