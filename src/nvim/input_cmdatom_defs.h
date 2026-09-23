#pragma once

#include <stdbool.h>

#include "klib/kvec.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/input_defs.h"

// Concepts (see :help dev-cmdatom):
// - atom, span, composite (atom with subatoms)
// - insert-session, insertion
// - payload
// - replay, cascade, insert-cascade

typedef enum CmdAtomType {
  kAComp,          ///< Composite: complex mapping/macro. >=2 subatoms, or 0 (captured nothing).
  kAExcmd,         ///< Ex command (":cnext<CR>"): the typed cmdline is the payload.
  kAInsert,        ///< Insert session: entry command + text + <Esc>.
  kAInsertSpan,    ///< Span (chunk) of an ongoing insert-session, cascaded mid-session.
  kAJump,          ///< Cursor movement by absolute/shared navigation (jumplist, marks, `*`):
                   ///< not followable (its target would collapse cursors onto one position).
  kAMotion,        ///< Motion (cascades in "q=" follow-motion mode).
  kAMouse,         ///< Mouse action: emit-only (not replayable).
  kANormal,        ///< Normal-mode command that is not a motion or jump ("u", CTRL-R, "za", …).
                   ///< Never cascades, except as part of a mapping's composite.
  kAOperator,      ///< Operator+motion, or a self-contained edit command.
  kAScroll,        ///< Scroll (CTRL-Y/D/…, wheel): emit-only, like kAMouse.
  kAVisual,        ///< Visual-mode sequence ("viwee" + operator). Captures subatoms.
  kAVisualSpan,    ///< Span (chunk) of an ongoing Visual session, cascaded mid-session.
} CmdAtomType;

/// State gathered at start of a command, composite, or insert. For calculating the "delta" at end.
typedef struct {
  bufref_T buf;       ///< Buffer.
  const win_T *win;   ///< Window.
  pos_T pos;          ///< Cursor position. Stored here bc the window might be closed.
  varnumber_T tick;   ///< b:changedtick.
  int maptick;        ///< Advances on typed input (globals.h:maptick).
} CmdOrigin;

/// How an insert-session was entered from Visual mode.
typedef enum {
  kVInsNone,    ///< Not entered from Visual mode.
  kVInsKeys,    ///< Redo opens with the selection's captured keys: replayable.
  kVInsMotion,  ///< Motion selected the region: Ex/Lua omap ("c" + Lua textobj), "gn". Replayable.
  kVInsOther,   ///< Redo without captured keys: forced motion, "gv", or "1v"
                ///< fixed-size fallback.
} VisualIns;

/// The insert-session delimited by atom_ins_start()/atom_ins_end().
typedef struct {
  bool typed;        ///< Session is user input (typed, or via mapping/macro).
  VisualIns vis;     ///< Session was entered from Visual mode.
  CmdOrigin origin;  ///< State at start.
} InsSession;

typedef struct CmdAtom CmdAtom;
typedef kvec_t(CmdAtom) CmdAtomVec;

/// One repeatable operation. `keys` is the replay bytes; `spec` is the structured form.
struct CmdAtom {
  CmdAtomType type;
  CmdSpec spec;   ///< Structured fields.
  CmdOrigin origin;  ///< Pre-command state.
  CmdAtomVec atoms;  ///< Composite (multi-command mapping, Visual sequence): its subatoms,
                     ///< in order; their keys concatenate to `keys`. Empty: non-composite.
  char *keys;     ///< Resolved keysequence (typeahead encoding), including `["x][count]` prefix
                  ///< (unlike `CmdSpec.body`, the raw unprefixed form).
  char *text;     ///< Insert-session text, or Ex/search cmdline payload.
  char *lhs;      ///< Unresolved user input: mapping LHS, macro ("@q"), Visual op, or translation
                  ///< ("x" => "dl"). NULL: untranslated, same as `keys`.
  int undoseq;    ///< Undo state at settlement. Not monotonic (decreases on undo).
  bool changed;   ///< The command changed the buffer.
  bool moved;     ///< The command moved the cursor.
  bool remap;     ///< True if `keys` cannot replay (lossy/empty capture). Replay `lhs` instead.
  bool cascaded;  ///< This atom already cascaded as spans: emit-only.
};

/// Key classes (atom_key_class()).
/// Flags, bc same char can mean different things per mode (CTRL-T: tag-jump vs i_CTRL-T indent).
enum {
  kKeyOpaque     = 1 << 0,  ///< Cmds not reified from subatoms (<Cmd>, K_LUA), plus kKeySynthetic.
                            ///< The cmd itself is the atom, else its only trace is its effect.
  kKeySynthetic  = 1 << 1,  ///< Not a user keystroke (K_EVENT, K_IGNORE): unlike <Cmd>/K_LUA, never
                            ///< reaches us from a mapping.
  kKeyPayload    = 1 << 2,  ///< Interactively-typed payload (/, ?, :, !).
  kKeyScrollMove = 1 << 3,  ///< Scroll may move cursor (C-D/…): viewport-dependent, unreplayable.
  kKeyScrollView = 1 << 4,  ///< Viewport-only scroll (C-Y,wheel): cursor stays, unless 'scrolloff'.
  kKeyJump       = 1 << 5,  ///< Absolute motion (multiplexed "gg", "g;", …), see NV_JUMP.
  kKeyMotion     = 1 << 6,  ///< Cursor-relative motion (multiplexed, special keys), see NV_MOTION.
  kKeyInsFlush   = 1 << 7,  ///< Insert-mode cmd a literal preview cannot represent:
                            ///< - deletions/indent-shifts (<Del>, CTRL-W, …) may edit text
                            ///<   outside the tracked region by per-cursor amounts;
                            ///< - cursor-moves (start_arrow()) move the insertion point itself.
  kKeyMouse      = 1 << 8,  ///< Mouse button press (<LeftMouse>, …). Drag/release/move are the
                            ///< press's continuation: no class, invisible to capture.
};
