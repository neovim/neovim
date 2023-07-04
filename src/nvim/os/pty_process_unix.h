#ifndef NVIM_OS_PTY_PROCESS_UNIX_H
#define NVIM_OS_PTY_PROCESS_UNIX_H

#include <stdint.h>
#include <sys/ioctl.h>

#include "nvim/event/loop.h"
#include "nvim/event/process.h"

typedef struct pty_process {
  Process process;
  uint16_t width, height;
  struct winsize winsize;
  int master_fd;
  int slave_fd;  ///< only set for kChannelStreamPty
} PtyProcess;

static inline PtyProcess pty_process_init(Loop *loop, void *data, bool process)
{
  // TODO: if pty_process_win don't need this either,
  (void)process;
  PtyProcess rv;
  rv.process = process_init(loop, kProcessTypePty, data);
  rv.width = 80;
  rv.height = 24;
  rv.master_fd = -1;
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process_unix.h.generated.h"
#endif

#endif  // NVIM_OS_PTY_PROCESS_UNIX_H
