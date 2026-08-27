#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/input_defs.h"

// Concepts (see :help dev-cmdatom):
// - atom, composite (atom with subatoms)
// - insert-session
// - INSERTION
// - span
// - replay, cascade, insert-cascade

typedef enum CmdAtomType {
  kAExcmd,         ///< Ex command (":cnext<CR>"): the typed cmdline is the payload.
  kAInsert,        ///< Insert session: entry command + text + <Esc>.
  kAInsertSpan,    ///< Span (chunk) of an ongoing insert-session, cascaded mid-session.
  kAJump,          ///< Cursor movement by absolute/shared navigation (jumplist, marks, `*`):
                   ///< not followable (its target would collapse cursors onto one position).
  kAMapping,       ///< Subcommands of a mapping/macro, collapsed into one atom (`lhs`).
  kAMotion,        ///< Motion (cascades in "q=" follow-motion mode).
  kAMouse,         ///< Mouse action: emit-only (not replayable).
  kANormal,        ///< Normal-mode command that is not a motion or jump ("u", CTRL-R, "za", …).
                   ///< Never cascades, except as part of a mapping's composite.
  kAOperator,      ///< Operator+motion, or a self-contained edit command.
  kAScroll,        ///< Scroll (CTRL-Y/D/…, wheel): emit-only, like kAMouse.
  kAVisual,        ///< Visual-mode sequence ("viwee" + operator).
} CmdAtomType;

/// State gathered at start of a command, composite, or insert. For calculating the "delta" at end.
typedef struct {
  bufref_T buf;       ///< Buffer.
  const win_T *win;   ///< Window.
  pos_T pos;          ///< Cursor position. Stored here bc the window might be closed.
  varnumber_T tick;   ///< b:changedtick.
} CmdOrigin;

/// How an insert-session was entered from Visual mode.
typedef enum {
  kVInsNone,   ///< Not entered from Visual mode.
  kVInsKeys,   ///< Redo opens with the selection's captured keys: replayable.
  kVInsOther,  ///< Redo without the captured keys (Ex/Lua-motion selection, forced
               ///< motion, or the "1v" fixed-size fallback for a void selection).
} VisualIns;

/// The insert-session delimited by atom_ins_start()/atom_ins_end().
typedef struct {
  bool typed;        ///< Session is user input (typed, or via mapping/macro).
  VisualIns vis;     ///< Session was entered from Visual mode.
  CmdOrigin origin;  ///< State at start.
} InsSession;

typedef struct CmdAtom CmdAtom;
typedef kvec_t(CmdAtom) CmdAtomVec;

/// One repeatable operation. `keys` is the replay payload; `spec` is the structured form.
struct CmdAtom {
  CmdSpec spec;   ///< Structured fields.
  CmdAtomVec atoms;  ///< Composite (multi-command mapping, Visual sequence): its subatoms,
                     ///< in order; their keys concatenate to `keys`. Empty for non-composite.
  char *keys;     ///< Resolved keysequence (typeahead encoding), including `["x][count]` prefix
                  ///< (unlike `CmdSpec.body`, the raw unprefixed form).
  char *text;     ///< Payload: insert-session text, or Ex/search cmdline.
  char *lhs;      ///< Unresolved user input: mapping LHS or macro register ("@q"), or Visual op.
                  ///< Label/hint, not replayed. NULL: untranslated, same as `keys`.
  CmdOrigin origin;  ///< Pre-command state.
  CmdAtomType type;
  int undoseq;    ///< Undo state at settlement. Not monotonic (decreases on undo).
  bool changed;   ///< The command changed the buffer.
  bool moved;     ///< The command moved the cursor.
  bool remap;     ///< If true, `keys` cannot replay: payload mapping (vim-surround "ds'") edits
                  ///< invisibly (:norm/Ex). Must replay `lhs` instead.
};

/// Key classes (atom_key_class()).
/// Flags, bc same char can mean different things per mode (CTRL-T: tag-jump vs i_CTRL-T indent).
enum {
  kKeyOpaque     = 1 << 0,  ///< Uncapturable keys (<Cmd>, K_LUA, plus kKeySynthetic): its only
                            ///< trace is its effect.
  kKeySynthetic  = 1 << 1,  ///< Not a user keystroke (K_EVENT, K_IGNORE): unlike <Cmd>/K_LUA, never
                            ///< reaches us from a mapping.
  kKeyPayload    = 1 << 2,  ///< Interactively-typed payload (/, ?, :, !).
  kKeyScrollMove = 1 << 3,  ///< Scroll may move cursor (C-D/…): viewport-dependent, unreplayable.
  kKeyScrollView = 1 << 4,  ///< Viewport-only scroll (C-Y,wheel): cursor stays, unless 'scrolloff'.
  kKeyJump       = 1 << 5,  ///< Moves to absolute pos from primary cursor's shared nav state
                            ///< (jumplist C-O/I, CTRL-T, "g;"): not followable.
  kKeyMotion     = 1 << 6,  ///< Replayable special-key motion (arrows, <Home>, …).
  kKeyInsFlush   = 1 << 7,  ///< Insert-mode cmd a literal preview cannot represent:
                            ///< - deletions/indent-shifts (<Del>, CTRL-W, …) may edit text
                            ///<   outside the tracked region by per-cursor amounts;
                            ///< - cursor-moves (start_arrow()) move the insertion point itself.
  kKeyMouse      = 1 << 8,  ///< Mouse button press (<LeftMouse>, …). Drag/release/move are the
                            ///< press's continuation: no class, invisible to capture.
};
