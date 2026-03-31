#pragma once
// IWYU pragma: private, include "nvim/os/pty_proc.h"

#include <stdint.h>
#include <sys/ioctl.h>

#include "nvim/event/defs.h"

typedef struct {
  Proc proc;
  uint16_t width, height;
  struct winsize winsize;
  int tty_fd;
} PtyProc;

#include "os/pty_proc_unix.h.generated.h"
