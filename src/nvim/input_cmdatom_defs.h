#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/input_defs.h"

// Concepts (see :help dev-cmdatom):
// - atom, composite (atom with subatoms)
// - insert-session
// - INSERTION
// - span
// - replay, cascade, insert-cascade

typedef enum CmdAtomType {
  kACommand,       ///< Not an (operator) edit, nor a cursor-move (u zz <c-w>l …). Never cascades,
                   ///< except as part of a mapping's composite.
  kAEx,            ///< Ex command (":cnext<CR>"): the typed cmdline is the payload.
  kAInsert,        ///< Insert session: entry command + text + <Esc>.
  kAInsertSpan,    ///< Span (chunk) of an ongoing insert-session, cascaded mid-session.
  kAJump,          ///< Cursor movement by absolute/shared navigation (jumplist, marks, `*`):
                   ///< not followable (its target would collapse cursors onto one position).
  kAMapping,       ///< Subcommands of a mapping/macro, collapsed into one atom (`lhs`).
  kAMotion,        ///< Motion (cascades in "q=" follow-motion mode).
  kAMouse,         ///< Mouse action: emit-only (not replayable).
  kAOperator,      ///< Operator+motion, or a self-contained edit command.
  kAScroll,        ///< Scroll (CTRL-Y/D/…, wheel): emit-only, like kAMouse.
  kAVisual,        ///< Visual-mode sequence ("viwee" + operator).
} CmdAtomType;

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
  varnumber_T tick;  ///< b:changedtick at start (the session atom's `changed` baseline).
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
  char *lhs;      ///< Mapping LHS or macro register ("gj", "@q") that produced this atom, or NULL.
                  ///< Label/hint, not replayed.
  CmdAtomType type;
  bool changed;   ///< The command changed the buffer.
  bool remap;     ///< Replay `keys` w/ remap. For replay of a payload mapping (vim-surround "ds'"),
                  ///< which edits invisibly (:norm/Ex) and must rerun LHS instead of resolved keys.
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
