#ifndef NVIM_OS_EVENT_DEFS_H
#define NVIM_OS_EVENT_DEFS_H

#include <stdbool.h>

#include "nvim/os/job_defs.h"
#include "nvim/os/rstream_defs.h"

typedef void * EventSource;
typedef struct event Event;
typedef void (*event_handler)(Event event);

struct event {
  EventSource source;
  event_handler handler;
  union {
    int signum;
    struct {
      RStream *ptr;
      bool eof;
    } rstream;
    Job *job;
  } data;
}; 

#endif  // NVIM_OS_EVENT_DEFS_H
