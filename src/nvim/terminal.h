#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vterm/vterm_defs.h"  // IWYU pragma: keep

typedef void (*terminal_read_pause_cb)(bool pause, void *data);
typedef void (*terminal_write_cb)(const char *buffer, size_t size, void *data);
typedef void (*terminal_resize_cb)(uint16_t width, uint16_t height, void *data);
typedef void (*terminal_resume_cb)(void *data);
typedef void (*terminal_close_cb)(void *data);

typedef struct {
  void *data;  // PTY process channel
  uint16_t width, height;
  terminal_read_pause_cb read_pause_cb;
  terminal_write_cb write_cb;
  terminal_resize_cb resize_cb;
  terminal_resume_cb resume_cb;
  terminal_close_cb close_cb;
  bool force_crlf;
} TerminalOptions;

/// Called once per logical line by `terminal_foreach_row()`. `cells`/`cols` are
/// owned by the caller and valid only for the duration of the call.
typedef void (*TerminalRowCb)(const VTermScreenCell *cells, size_t cols, void *data);

#include "terminal.h.generated.h"
