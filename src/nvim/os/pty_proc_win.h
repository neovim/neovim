#pragma once
// IWYU pragma: private, include "nvim/os/pty_proc.h"

#include <uv.h>

#include "nvim/event/proc.h"
#include "nvim/lib/queue_defs.h"
#include "nvim/os/pty_conpty_win.h"

typedef struct pty_process {
  Proc proc;
  uint16_t width, height;
  conpty_t *conpty;
  HANDLE finish_wait;
  HANDLE proc_handle;
  uv_timer_t wait_eof_timer;
} PtyProc;

// Structure used by build_cmd_line()
typedef struct arg_node {
  char *arg;  // pointer to argument.
  QUEUE node;  // QUEUE structure.
} ArgNode;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/pty_proc_win.h.generated.h"
#endif
