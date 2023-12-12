#pragma once

#include <stdbool.h>
#include <stddef.h>  // IWYU pragma: keep

#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/grid_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/message_defs.h"  // IWYU pragma: export

/// First message
extern MessageHistoryEntry *first_msg_hist;
/// Last message
extern MessageHistoryEntry *last_msg_hist;

EXTERN bool msg_ext_need_clear INIT( = false);

/// allocated grid for messages. Used when display+=msgsep is set, or
/// ext_multigrid is active. See also the description at msg_scroll_flush()
EXTERN ScreenGrid msg_grid INIT( = SCREEN_GRID_INIT);
EXTERN int msg_grid_pos INIT( = 0);

/// "adjusted" message grid. This grid accepts positions relative to
/// default_grid. Internally it will be translated to a position on msg_grid
/// relative to the start of the message area, or directly mapped to default_grid
/// for legacy (display-=msgsep) message scroll behavior.
/// TODO(bfredl): refactor "internal" message logic, msg_row etc
/// to use the correct positions already.
EXTERN ScreenGrid msg_grid_adj INIT( = SCREEN_GRID_INIT);

/// value of msg_scrolled at latest msg_scroll_flush.
EXTERN int msg_scrolled_at_flush INIT( = 0);

EXTERN int msg_grid_scroll_discount INIT( = 0);

EXTERN int msg_listdo_overwrite INIT( = 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.h.generated.h"
#endif
