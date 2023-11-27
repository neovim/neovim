#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/autocmd_defs.h"  // IWYU pragma: export
#include "nvim/buffer_defs.h"
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/macros.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

// Set by the apply_autocmds_group function if the given event is equal to
// EVENT_FILETYPE. Used by the readfile function in order to determine if
// EVENT_BUFREADPOST triggered the EVENT_FILETYPE.
//
// Relying on this value requires one to reset it prior calling
// apply_autocmds_group.
EXTERN bool au_did_filetype INIT( = false);

/// For CursorMoved event
EXTERN win_T *last_cursormoved_win INIT( = NULL);
/// For CursorMoved event, only used when last_cursormoved_win == curwin
EXTERN pos_T last_cursormoved INIT( = { 0, 0, 0 });

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "autocmd.h.generated.h"
#endif

#define AUGROUP_DEFAULT    (-1)      // default autocmd group
#define AUGROUP_ERROR      (-2)      // erroneous autocmd group
#define AUGROUP_ALL        (-3)      // all autocmd groups
#define AUGROUP_DELETED    (-4)      // all autocmd groups
// #define AUGROUP_NS       -5      // TODO(tjdevries): Support namespaced based augroups

#define BUFLOCAL_PAT_LEN 25

/// Iterates over all the events for auto commands
#define FOR_ALL_AUEVENTS(event) \
  for (event_T event = (event_T)0; (int)event < (int)NUM_EVENTS; event = (event_T)((int)event + 1))  // NOLINT
