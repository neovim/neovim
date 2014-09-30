#ifndef NVIM_OS_EVENT_DEFS_H
#define NVIM_OS_EVENT_DEFS_H

#include <stdbool.h>

#include "nvim/os/job_defs.h"
#include "nvim/os/rstream_defs.h"

typedef void * EventSource;

typedef enum {
  kEventSignal,
  kEventRStreamData,
  kEventJobExit
} EventType;

typedef struct {
  EventSource source;
  EventType type;
  union {
    int signum;
    struct {
      RStream *ptr;
      bool eof;
    } rstream;
    Job *job;
  } data;
} Event;

#endif  // NVIM_OS_EVENT_DEFS_H
