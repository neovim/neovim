#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/grid_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/types_defs.h"
#include "nvim/ui_defs.h"  // IWYU pragma: keep

// Temporary buffer for converting a single grid_line event
EXTERN size_t grid_line_buf_size INIT( = 0);
EXTERN schar_T *grid_line_buf_char INIT( = NULL);
EXTERN sattr_T *grid_line_buf_attr INIT( = NULL);

// Client-side UI channel. Zero during early startup or if not a (--remote-ui) UI client.
EXTERN uint64_t ui_client_channel_id INIT( = 0);

// exit status from embedded nvim process
EXTERN int ui_client_exit_status INIT( = 0);

/// Whether ui client has sent nvim_ui_attach yet
EXTERN bool ui_client_attached INIT( = false);

/// The ui client should forward its stdin to the nvim process
/// by convention, this uses fd=3 (next free number after stdio)
EXTERN bool ui_client_forward_stdin INIT( = false);

#define UI_CLIENT_STDIN_FD 3
// uncrustify:off
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_client.h.generated.h"
# include "ui_events_client.h.generated.h"
#endif
// uncrustify:on
