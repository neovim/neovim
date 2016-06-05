#ifndef NVIM_OS_PTY_PROCESS_WIN_H
#define NVIM_OS_PTY_PROCESS_WIN_H

#include "nvim/event/libuv_process.h"

typedef struct pty_process {
  Process process;
  char *term_name;
  uint16_t width, height;
} PtyProcess;

#define pty_process_spawn(job) libuv_process_spawn((LibuvProcess *)job)
#define pty_process_close(job) libuv_process_close((LibuvProcess *)job)
#define pty_process_close_master(job) libuv_process_close((LibuvProcess *)job)
#define pty_process_resize(job, width, height)
#define pty_process_teardown(loop)

static inline PtyProcess pty_process_init(Loop *loop, void *data)
{
  PtyProcess rv;
  rv.process = process_init(loop, kProcessTypePty, data);
  rv.term_name = NULL;
  rv.width = 80;
  rv.height = 24;
  return rv;
}

#endif  // NVIM_OS_PTY_PROCESS_WIN_H
