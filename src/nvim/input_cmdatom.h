#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/buffer_defs.h"  // buf_T
#include "nvim/eval/typval_defs.h"  // varnumber_T
#include "nvim/input_cmdatom_defs.h"  // IWYU pragma: export
#include "nvim/normal_defs.h"  // VisualState, cmdarg_T
#include "nvim/pos_defs.h"
#include "nvim/register_defs.h"  // Timestamp

/// Pending atom(s). Multiple atoms may queue; they cascade as a batch (mc_clock_edge).
extern CmdAtomVec g_atoms;

/// Pre-command state sampled at normal_execute() entry; atom_cmd_end() diffs it to classify.
typedef struct {
  pos_T pos;           ///< Cursor position.
  const buf_T *buf;    ///< Current buffer.
  varnumber_T tick;    ///< b:changedtick
  VisualState visual;  ///< Visual-mode state (active/start/mode are diffed).
  bool keytyped;       ///< KeyTyped
  uint64_t pushes;     ///< `atom_pushes` (total atoms ever pushed).
  bool follow;         ///< mc_following() ("q=")
  bool consumers;      ///< Capture is skipped if there are no consumers (for performance).
  Timestamp reg_ts;    ///< Max register timestamp (to detect a per-cursor register write).
  bool staged;         ///< atom_staged()
} CmdBaseline;

#include "input_cmdatom.h.generated.h"
