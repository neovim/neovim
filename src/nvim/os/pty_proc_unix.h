#pragma once
// IWYU pragma: private, include "nvim/os/pty_proc.h"

#include <stdint.h>
#include <sys/ioctl.h>

#include "nvim/event/defs.h"

typedef struct {
  Proc proc;
  uint16_t width, height;
  uint16_t xpixel, ypixel;
  struct winsize winsize;
  int tty_fd;
} PtyProc;

void pty_proc_set_pixel_size(PtyProc *ptyproc, uint16_t xpixel, uint16_t ypixel);

#include "os/pty_proc_unix.h.generated.h"
