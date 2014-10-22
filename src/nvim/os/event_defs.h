#ifndef NVIM_OS_EVENT_DEFS_H
#define NVIM_OS_EVENT_DEFS_H

#include <stdbool.h>

#include "nvim/os/job_defs.h"
#include "nvim/os/rstream_defs.h"

typedef struct event Event;
typedef void (*event_handler)(Event event);

struct event {
  void *data;
  event_handler handler;
};

#endif  // NVIM_OS_EVENT_DEFS_H
