#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/os/os_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

typedef struct {
  pos_T pos;         ///< Current cursor position (cache, see `mark`).
  uint32_t mark;     ///< Extmark id tracking `pos` across buffer edits.
  colnr_T curswant;  ///< Preferred column ("curswant"); -1 if unset.
  handle_T buf;      ///< Current buffer handle.
  String regs;       ///< Registers (shada msgpack string).
  String jumps;      ///< Jumplist (shada msgpack string).
  String bufs;       ///< Buffer list (shada msgpack string).
  String gvars;      ///< Global variables (shada msgpack string).
  Array funcs;       ///< Functions.
} Context;
typedef kvec_t(Context) ContextVec;

#define CONTEXT_INIT { \
  .pos = { 0 }, \
  .mark = 0, \
  .curswant = -1, \
  .buf = 0, \
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
  kCtxAll = kCtxRegs | kCtxJumps | kCtxBufs | kCtxGVars | kCtxSFuncs | kCtxFuncs,
} CtxStateFlags;

/// "How" to load, orthogonal to "what" (CtxStateFlags).
typedef enum {
  kCtxMergeReg = 1,  ///< Merge incoming registers with existing.
} CtxLoadFlags;

/// Temporary, hidden window (fka "autocmd window"): a pooled window created to temporarily show
/// a buffer that has no window (ctx_switch() on a buffer target), to handle the side effects.  When
/// switches nest we may need more than one.
typedef struct {
  win_T *cw_win;   ///< The window, or NULL if not yet allocated.
  bool cw_used;    ///< Not currently in use.
} CtxWin;

/// Flags for ctx_switch().
typedef enum {
  /// Restore process CWD: undo incidental chdir ('autochdir', "leaked" win/tab-local CWD).
  ///
  /// Note: this flag only exists for performance. Semantically every ctx-switch wants this, but the
  /// getcwd() bookkeeping is costly for internal switches that don't run user code.
  kCtxKeepCwd = 1,
  /// Restore the target's full CWD state: undo all "chdir" operations on ctx_restore(), including
  /// explicit :cd/:tcd/:bcd (which otherwise persist).
  /// - Note: :lcd targeting a hidden buffer (temp window) is always discarded.
  kCtxKeepDirs = 2,
  /// Don't affect the display (no redraw; limits access to another tabpage).
  kCtxNoDisplay = 4,
  /// Block autocommands until ctx_restore().
  kCtxNoEvents = 8,
  /// Validate cursor/Visual around the switch; update display (statusline) if the target window's
  /// cursor moved.
  kCtxValidate = 16,
} CtxSwitchFlags;

/// What ctx_switch() switched (set internally).
enum {
  kCtxSwitchNone = 0,  ///< Zero-initialized: ctx_restore() is a no-op.
  kCtxSwitchWin,       ///< Window target.
  kCtxSwitchBuf,       ///< Buffer target.
  kCtxSwitchDirs,      ///< No target: only CWD state is saved.
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
  int cs_ctxwin_idx;              ///< "autocmd" window in the ctx_win pool, or -1.
  // Target tracking (kCtxValidate):
  handle_T cs_target_win;         ///< the window switched to
  pos_T cs_target_old_pos;        ///< its cursor before the switch
  // State kept across the switch:
  bool cs_did_chdir;              ///< saved `ctx_did_chdir` of the enclosing context
  handle_T cs_dirs_tab;           ///< kCtxKeepDirs: tabpage that owns cs_tp_localdir.
  // Saved dir state. Three users:
  // 1. hidden-buffer target always saves b/tp/globaldir (so the temp context starts dir-neutral)
  // 2. kCtxKeepCwd saves globaldir.
  // 3. kCtxKeepDirs also saves w/b/tp-localdir.
  char *cs_w_localdir;            ///< Saved w_localdir of the target window
  char *cs_b_localdir;            ///< Saved b_localdir of the target buffer
  char *cs_tp_localdir;           ///< Saved tp_localdir
  char *cs_globaldir;             ///< Saved globaldir
  char *cs_cwd;                   ///< Saved CWD (kCtxKeepCwd/kCtxKeepDirs).
  bool cs_apply_acd;              ///< Re-apply 'autochdir' on ctx_restore().
} CtxSwitch;
