#ifndef NEOVIM_OS_EVENT_DEFS_H
#define NEOVIM_OS_EVENT_DEFS_H

#include "os/job_defs.h"
#include "os/rstream_defs.h"

typedef enum {
  kEventSignal,
  kEventJobActivity,
  kEventRStreamData
} EventType;

typedef struct {
  EventType type;
  union {
    int signum;
    struct {
      RStream *ptr;
      bool eof;
    } rstream;
    struct {
      Job *ptr;
      RStream *target;
      bool from_stdout;
    } job;
  } data;
} Event;

#endif  // NEOVIM_OS_EVENT_DEFS_H
