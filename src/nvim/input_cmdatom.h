#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/buffer_defs.h"  // buf_T
#include "nvim/eval/typval_defs.h"  // varnumber_T
#include "nvim/input_cmdatom_defs.h"  // IWYU pragma: export
#include "nvim/normal_defs.h"  // VisualState, cmdarg_T
#include "nvim/pos_defs.h"
#include "nvim/register_defs.h"  // Timestamp

/// Multicursor: pending atoms; they cascade as a batch (mc_clock_edge).
extern CmdAtomVec g_atoms;

/// Pre-command state sampled at entry + storage for its "staged" atom. atom_cmd_end() finalizes it.
typedef struct CmdFrame CmdFrame;
struct CmdFrame {
  CmdOrigin origin;    ///< State at entry.
  VisualState visual;  ///< Visual-mode state (active/start/mode are diffed).
  bool keytyped;       ///< KeyTyped
  uint64_t captures;   ///< Capture counter.
  uint64_t id;         ///< Identifies this frame (see `composite.frame`).
  bool follow;         ///< mc_following() ("q=")
  bool consumers;      ///< Capture is skipped if there are no consumers (for performance).
  Timestamp reg_ts;    ///< Max register timestamp (to detect a per-cursor register write).
  CmdAtom staged;      ///< Atom staged in this frame (`keys=NULL`: none).
  size_t payload_start;  ///< Payload slice of key stream (`SIZE_MAX`: none):
  size_t payload_end;    ///< `typed.keys[payload_start..payload_end)`
  CmdFrame *parent;    ///< Enclosing frame (nested normal_execute()); NULL at toplevel.
};

#include "input_cmdatom.h.generated.h"
