#pragma once

#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/highlight_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/ui_defs.h"  // IWYU pragma: keep

/// Keep in sync with UIExtension in ui_defs.h
EXTERN const char *ui_ext_names[] INIT( = {
  "ext_cmdline",
  "ext_popupmenu",
  "ext_tabline",
  "ext_wildmenu",
  "ext_messages",
  "ext_linegrid",
  "ext_multigrid",
  "ext_hlstate",
  "ext_termcolors",
  "_debug_float",
});

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/ui.h.generated.h"
# include "ui_events_remote.h.generated.h"
#endif
