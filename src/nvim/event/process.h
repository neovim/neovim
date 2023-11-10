#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/event/rstream.h"
#include "nvim/event/stream.h"
#include "nvim/event/wstream.h"

struct process;

typedef enum {
  kProcessTypeUv,
  kProcessTypePty,
} ProcessType;

typedef struct process Process;
typedef void (*process_exit_cb)(Process *proc, int status, void *data);
typedef void (*internal_process_cb)(Process *proc);

struct process {
  ProcessType type;
  Loop *loop;
  void *data;
  int pid, status, refcount;
  uint8_t exit_signal;  // Signal used when killing (on Windows).
  uint64_t stopped_time;  // process_stop() timestamp
  const char *cwd;
  char **argv;
  const char *exepath;
  dict_T *env;
  Stream in, out, err;
  /// Exit handler. If set, user must call process_free().
  process_exit_cb cb;
  internal_process_cb internal_exit_cb, internal_close_cb;
  bool closed, detach, overlapped, fwd_err;
  MultiQueue *events;
};

static inline Process process_init(Loop *loop, ProcessType type, void *data)
{
  return (Process) {
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
    .out = { .closed = false },
    .err = { .closed = false },
    .cb = NULL,
    .closed = false,
    .internal_close_cb = NULL,
    .internal_exit_cb = NULL,
    .detach = false,
    .fwd_err = false,
  };
}

/// Get the path to the executable of the process.
static inline const char *process_get_exepath(Process *proc)
{
  return proc->exepath != NULL ? proc->exepath : proc->argv[0];
}

static inline bool process_is_stopped(Process *proc)
{
  bool exited = (proc->status >= 0);
  return exited || (proc->stopped_time != 0);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/process.h.generated.h"
#endif
