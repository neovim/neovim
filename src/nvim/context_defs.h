#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

typedef struct {
  String regs;     ///< Registers.
  String jumps;    ///< Jumplist.
  String bufs;     ///< Buffer list.
  String gvars;    ///< Global variables.
  Array funcs;              ///< Functions.
} Context;
typedef kvec_t(Context) ContextVec;

#define CONTEXT_INIT (Context) { \
  .regs = STRING_INIT, \
  .jumps = STRING_INIT, \
  .bufs = STRING_INIT, \
  .gvars = STRING_INIT, \
  .funcs = ARRAY_DICT_INIT, \
}

typedef enum {
  kCtxRegs = 1,       ///< Registers
  kCtxJumps = 2,      ///< Jumplist
  kCtxBufs = 4,       ///< Buffer list
  kCtxGVars = 8,      ///< Global variables
  kCtxSFuncs = 16,    ///< Script functions
  kCtxFuncs = 32,     ///< Functions
} CtxStateFlags;

/// Temporary, hidden window (fka "autocmd window"): a pooled window created to temporarily show
/// a buffer that has no window (ctx_switch() on a buffer target), to handle the side effects.  When
/// switches nest we may need more than one.
typedef struct {
  win_T *cw_win;   ///< The window, or NULL if not yet allocated.
  bool cw_used;    ///< Not currently in use.
} CtxWin;

/// Flags for ctx_switch().
typedef enum {
  /// Don't affect the display (no redraw; limits access to another tabpage).
  kCtxNoDisplay = 1,
  /// Block autocommands until ctx_restore().
  kCtxNoEvents = 2,
  /// Undo any chdir caused by the switch ('autochdir', win/tab-local CWD) on ctx_restore().
  kCtxKeepCwd = 4,
  /// Validate cursor/Visual around the switch; update display (statusline) if the target window's
  /// cursor moved.
  kCtxValidate = 8,
} CtxSwitchFlags;

/// What ctx_switch() switched (set internally).
enum {
  kCtxSwitchNone = 0,  ///< zero-initialized: ctx_restore() is a no-op
  kCtxSwitchWin,       ///< window target
  kCtxSwitchBuf,       ///< buffer target
};

/// Context before a temporary switch of current window/buffer. Undone by ctx_restore().
typedef struct {
  CtxSwitchFlags cs_flags;        ///< kCtx* flags of the switch
  int cs_mode;                    ///< kCtxSwitch* (what was switched)
  // Saved location:
  handle_T cs_curwin;             ///< saved curwin
  handle_T cs_prevwin;            ///< saved prevwin (ctx_switch())
  tabpage_T *cs_curtab;           ///< saved curtab (NULL: tabpage unchanged)
  bool cs_same_win;               ///< Visual.active was not reset
  bool cs_visual_active;          ///< saved Visual.active
  int cs_prompt_insert;           ///< saved b_prompt_insert
  // Temporary location (ctx_switch()):
  handle_T cs_new_curwin;         ///< ID of new curwin
  bufref_T cs_new_curbuf;         ///< new curbuf
  int cs_ctxwin_idx;              ///< autocmd window in ctx_win[], or -1
  // Target tracking (kCtxValidate):
  handle_T cs_target_win;         ///< the window switched to
  pos_T cs_target_old_pos;        ///< its cursor before the switch
  // State kept across the switch:
  char *cs_tp_localdir;           ///< saved tp_localdir (autocmd window)
  char *cs_globaldir;             ///< saved globaldir (autocmd window)
  char *cs_cwd;                   ///< saved cwd (kCtxKeepCwd; allocated on demand)
  int cs_cwd_status;              ///< OK if cs_cwd is valid
  bool cs_apply_acd;              ///< re-apply 'autochdir' on ctx_restore()
  char *cs_save_sfname;           ///< saved b_sfname (kCtxKeepCwd)
} CtxSwitch;
