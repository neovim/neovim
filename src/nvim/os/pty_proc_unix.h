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
  bool stdin_pipe;   ///< If set, child stdin (fd 0) is a separate pipe, not the tty. #40407
  int stdin_rfd;     ///< Child read-end of that pipe (passed across fork); -1 if none.
  bool stdout_pipe;  ///< If set, child stdout (fd 1) is a separate capture pipe (-> proc->err). #40407
  int stdout_wfd;    ///< Child write-end of that pipe (passed across fork); -1 if none.
} PtyProc;

#include "os/pty_proc_unix.h.generated.h"
