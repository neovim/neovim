#ifndef NVIM_EVENT_PTY_PROCESS_H
#define NVIM_EVENT_PTY_PROCESS_H

#include <sys/ioctl.h>

#include "nvim/event/process.h"

typedef struct pty_process {
  Process process;
  char *term_name;
  uint16_t width, height;
  struct winsize winsize;
  int tty_fd;
} PtyProcess;

static inline PtyProcess pty_process_init(Loop *loop, void *data)
{
  PtyProcess rv;
  rv.process = process_init(loop, kProcessTypePty, data);
  rv.term_name = NULL;
  rv.width = 80;
  rv.height = 24;
  rv.tty_fd = -1;
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/pty_process.h.generated.h"
#endif
#endif  // NVIM_EVENT_PTY_PROCESS_H
