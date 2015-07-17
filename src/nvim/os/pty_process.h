#ifndef NVIM_OS_PTY_PROCESS_H
#define NVIM_OS_PTY_PROCESS_H

#include <sys/ioctl.h>

#include <uv.h>

typedef struct {
  struct winsize winsize;
  uv_pipe_t proc_stdin, proc_stdout, proc_stderr;
  int tty_fd;
} PtyProcess;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process.h.generated.h"
#endif
#endif  // NVIM_OS_PTY_PROCESS_H
