#pragma once
// IWYU pragma: private, include "nvim/os/pty_process.h"

#include <stdint.h>
#include <sys/ioctl.h>

#include "nvim/event/defs.h"

typedef struct {
  Process process;
  uint16_t width, height;
  struct winsize winsize;
  int tty_fd;
} PtyProcess;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process_unix.h.generated.h"
#endif
