#ifndef NVIM_EVENT_TIME_H
#define NVIM_EVENT_TIME_H

#include <uv.h>

#include "nvim/event/loop.h"

typedef struct time_watcher TimeWatcher;
typedef void (*time_cb)(TimeWatcher *watcher, void *data);

struct time_watcher {
  uv_timer_t uv;
  void *data;
  time_cb cb, close_cb;
  MultiQueue *events;
  bool blockable;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/time.h.generated.h"
#endif
#endif  // NVIM_EVENT_TIME_H
