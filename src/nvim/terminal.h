#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct terminal Terminal;
typedef void (*terminal_write_cb)(const char *buffer, size_t size, void *data);
typedef void (*terminal_resize_cb)(uint16_t width, uint16_t height, void *data);
typedef void (*terminal_close_cb)(void *data);

#include "nvim/buffer_defs.h"  // IWYU pragma: keep

typedef struct {
  void *data;  // PTY process channel
  uint16_t width, height;
  terminal_write_cb write_cb;
  terminal_resize_cb resize_cb;
  terminal_close_cb close_cb;
  bool force_crlf;
} TerminalOptions;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "terminal.h.generated.h"
#endif
