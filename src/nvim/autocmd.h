#ifndef NVIM_AUTOCMD_H
#define NVIM_AUTOCMD_H

#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"

// TODO(tjdevries): Are we going to use these?
typedef enum {
  CALLABLE_CMD,
  CALLABLE_VIM,
  CALLABLE_LUA,
} AutocmdCallableType;

typedef struct callable_s AutocmdCallable;
struct callable_s {
  AutocmdCallableType type;
  union {
    char  *c_cmd;
    char  *c_vim;
    LuaRef c_lua;
  } callable;
};

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

typedef enum {
  COMMAND_EX,
  COMMAND_VIML_FUNC,
  COMMAND_LUA,
} AutocmdCommandType;

typedef struct command_s AutocmdCommand;
struct command_s {
  AutocmdCommandType type;
  union {
    char_u  *c_cmd;
    char_u  *c_vim;
    LuaRef   c_lua;
  } callable;
};

typedef struct AutoCmd {
  // TODO(tjdevries): Remove
  // This is the original storage method.
  // -> just stores a string of what to execute
  char_u          *cmd;  // Command to be executed
                         // (NULL when command has been removed)

  // This is the new storage method.
  // -> can store a string, or a lua ref!
  // -> will choose which to execute based on it's type.
  AutocmdCommand command;

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
  bool allow_dirs;                      // Pattern may match whole path
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

#define BUFLOCAL_PAT_LEN 25


// Iterates over all the events for auto commands
#define FOR_ALL_AUEVENTS(event) \
  for (event_T event = (event_T)0; (int)event < (int)NUM_EVENTS; event = (event_T)((int)event + 1)) // NOLINT

#define FOR_ALL_AUPATS_IN_EVENT(event, ap) \
  for (AutoPat *ap = first_autopat[event]; ap != NULL; ap = ap->next) // NOLINT

#endif  // NVIM_AUTOCMD_H
