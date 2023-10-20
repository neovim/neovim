#ifndef NVIM_UI_CLIENT_H
#define NVIM_UI_CLIENT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/grid_defs.h"
#include "nvim/macros.h"
#include "nvim/types.h"

typedef struct {
  const char *name;
  void (*fn)(Array args);
} UIClientHandler;

// Temporary buffer for converting a single grid_line event
EXTERN size_t grid_line_buf_size INIT( = 0);
EXTERN schar_T *grid_line_buf_char INIT( = NULL);
EXTERN sattr_T *grid_line_buf_attr INIT( = NULL);

// ID of the ui client channel. If zero, the client is not running.
EXTERN uint64_t ui_client_channel_id INIT( = 0);

// exit status from embedded nvim process
EXTERN int ui_client_exit_status INIT( = 0);

// TODO(bfredl): the current structure for how tui and ui_client.c communicate is a bit awkward.
// This will be restructured as part of The UI Devirtualization Project.

/// Whether ui client has sent nvim_ui_attach yet
EXTERN bool ui_client_attached INIT( = false);

/// Whether ui client has gotten a response about the bg color of the terminal,
/// kTrue=dark, kFalse=light, kNone=no response yet
EXTERN TriState ui_client_bg_response INIT( = kNone);

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

#endif  // NVIM_UI_CLIENT_H
