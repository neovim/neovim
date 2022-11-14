#ifndef NVIM_EVENT_PROCESS_H
#define NVIM_EVENT_PROCESS_H

#include "nvim/eval/typval.h"
#include "nvim/event/loop.h"
#include "nvim/event/rstream.h"
#include "nvim/event/wstream.h"

typedef enum {
  kProcessTypeUv,
  kProcessTypePty,
} ProcessType;

typedef struct process Process;
typedef void (*process_exit_cb)(Process *proc, int status, void *data);
typedef void (*internal_process_cb)(Process *proc);

struct process {
  ProcessType type;
  int pid;
  Loop *loop;
  void *data;
  int status;
  int refcount;
  uint8_t exit_signal;  // Signal used when killing (on Windows).
  bool closed;
  bool detach;
  bool overlapped;
  char __pad0[4];
  uint64_t stopped_time;  // process_stop() timestamp
  const char *cwd;
  char **argv;
  dict_T *env;
  Stream in, out, err;
  /// Exit handler. If set, user must call process_free().
  process_exit_cb cb;
  internal_process_cb internal_exit_cb, internal_close_cb;
  MultiQueue *events;
};

static inline Process process_init(Loop *loop, ProcessType type, void *data)
{
  return (Process) {
    .type = type,
    .pid = 0,
    .data = data,
    .loop = loop,
    .events = NULL,
    .status = -1,
    .refcount = 0,
    .closed = false,
    .detach = false,
    .overlapped = false,
    .stopped_time = 0,
    .cwd = NULL,
    .argv = NULL,
    .in = { .closed = false },
    .out = { .closed = false },
    .err = { .closed = false },
    .cb = NULL,
    .internal_close_cb = NULL,
    .internal_exit_cb = NULL,
  };
}

static inline bool process_is_stopped(Process *proc)
{
  bool exited = (proc->status >= 0);
  return exited || (proc->stopped_time != 0);
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/process.h.generated.h"
#endif
#endif  // NVIM_EVENT_PROCESS_H
