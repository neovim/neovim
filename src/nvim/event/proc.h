#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/event/defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"

static inline Proc proc_init(Loop *loop, ProcType type, void *data)
{
  return (Proc) {
    .type = type,
    .data = data,
    .loop = loop,
    .events = NULL,
    .pid = 0,
    .status = -1,
    .refcount = 0,
    .stopped_time = 0,
    .cwd = NULL,
    .argv = NULL,
    .exepath = NULL,
    .in = { .closed = false },
    .out = { .s.closed = false },
    .err = { .s.closed = false },
    .cb = NULL,
    .closed = false,
    .internal_close_cb = NULL,
    .internal_exit_cb = NULL,
    .detach = false,
    .fwd_err = false,
  };
}

/// Get the path to the executable of the process.
static inline const char *proc_get_exepath(Proc *proc)
{
  return proc->exepath != NULL ? proc->exepath : proc->argv[0];
}

static inline bool proc_is_stopped(Proc *proc)
{
  bool exited = (proc->status >= 0);
  return exited || (proc->stopped_time != 0);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/proc.h.generated.h"
#endif
