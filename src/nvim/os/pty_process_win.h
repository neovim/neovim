#pragma once

#include <uv.h>

#include "nvim/event/process.h"
#include "nvim/lib/queue.h"
#include "nvim/os/pty_conpty_win.h"

typedef struct pty_process {
  Process process;
  uint16_t width, height;
  conpty_t *conpty;
  HANDLE finish_wait;
  HANDLE process_handle;
  uv_timer_t wait_eof_timer;
} PtyProcess;

// Structure used by build_cmd_line()
typedef struct arg_node {
  char *arg;  // pointer to argument.
  QUEUE node;  // QUEUE structure.
} ArgNode;

static inline PtyProcess pty_process_init(Loop *loop, void *data)
{
  PtyProcess rv;
  rv.process = process_init(loop, kProcessTypePty, data);
  rv.width = 80;
  rv.height = 24;
  rv.conpty = NULL;
  rv.finish_wait = NULL;
  rv.process_handle = NULL;
  return rv;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_process_win.h.generated.h"
#endif
