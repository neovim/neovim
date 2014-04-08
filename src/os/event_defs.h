#ifndef NEOVIM_OS_EVENT_DEFS_H
#define NEOVIM_OS_EVENT_DEFS_H

#include "os/job_defs.h"

typedef enum {
  kEventSignal,
  kEventJobActivity
} EventType;

typedef struct {
  EventType type;
  union {
    int signum;
    Job *job;
  } data;
} Event;

#endif  // NEOVIM_OS_EVENT_DEFS_H
