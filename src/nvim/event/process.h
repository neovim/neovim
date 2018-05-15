#ifndef NVIM_EVENT_PROCESS_H
#define NVIM_EVENT_PROCESS_H

#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"
#include "nvim/types.h"

typedef enum {
  kProcessTypeUv,
  kProcessTypePty
} ProcessType;

typedef struct process Process;
typedef void (*process_exit_cb)(Process *proc, int status, void *data);
typedef void (*internal_process_cb)(Process *proc);

struct process {
  ProcessType type;
  Loop *loop;
  void *data;
  int pid, status, refcount;
  uint64_t stopped_time;  // process_stop() timestamp
  const char *cwd;
  char **argv;
  Stream in, out, err;
  process_exit_cb cb;
  internal_process_cb internal_exit_cb, internal_close_cb;
  bool closed;
  TriState detach;  // None=no_setsid, False=setsid, True=setsid+forget
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
    .in = { .closed = false },
    .out = { .closed = false },
    .err = { .closed = false },
    .cb = NULL,
    .closed = false,
    .internal_close_cb = NULL,
    .internal_exit_cb = NULL,
    .detach = kFalse,
  };
}

static inline bool process_is_stopped(Process *proc)
{
  return proc->stopped_time != 0;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/process.h.generated.h"
#endif
#endif  // NVIM_EVENT_PROCESS_H
