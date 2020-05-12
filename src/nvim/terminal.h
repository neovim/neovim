#ifndef NVIM_TERMINAL_H
#define NVIM_TERMINAL_H

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct terminal Terminal;
typedef void (*terminal_write_cb)(char *buffer, size_t size, void *data);
typedef void (*terminal_resize_cb)(uint16_t width, uint16_t height, void *data);
typedef void (*terminal_close_cb)(void *data);

#include "nvim/buffer_defs.h"

typedef struct {
  void *data;
  uint16_t width, height;
  terminal_write_cb write_cb;
  terminal_resize_cb resize_cb;
  terminal_close_cb close_cb;
} TerminalOptions;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "terminal.h.generated.h"
#endif
#endif  // NVIM_TERMINAL_H
