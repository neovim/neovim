#pragma once

#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/event/defs.h"
#include "nvim/grid_defs.h"  // IWYU pragma: keep
#include "nvim/highlight_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/ui_defs.h"  // IWYU pragma: keep

// uncrustify:off
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui.h.generated.h"
# include "ui_events_call.h.generated.h"
EXTERN Array noargs INIT(= ARRAY_DICT_INIT);
#endif
// uncrustify:on

// vim.ui_attach() namespace of currently executed callback.
EXTERN uint32_t ui_event_ns_id INIT( = 0);
EXTERN MultiQueue *resize_events INIT( = NULL);
EXTERN bool ui_refresh_cmdheight INIT( = true);
