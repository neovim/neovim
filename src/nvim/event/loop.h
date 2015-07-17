#ifndef NVIM_EVENT_LOOP_H
#define NVIM_EVENT_LOOP_H

#include <stdint.h>

#include <uv.h>

#include "nvim/lib/klist.h"
#include "nvim/os/time.h"

typedef struct event Event;
typedef void (*event_handler)(Event event);

struct event {
  void *data;
  event_handler handler;
};

typedef void * WatcherPtr;

#define _noop(x)
KLIST_INIT(WatcherPtr, WatcherPtr, _noop)
KLIST_INIT(Event, Event, _noop)

typedef struct loop {
  uv_loop_t uv;
  klist_t(Event) *deferred_events, *immediate_events;
  int deferred_events_allowed;
  klist_t(WatcherPtr) *children;
  uv_signal_t children_watcher;
  uv_timer_t children_kill_timer;
  size_t children_stop_requests;
} Loop;

// Poll for events until a condition or timeout
#define LOOP_POLL_EVENTS_UNTIL(loop, timeout, condition)                     \
  do {                                                                       \
    int remaining = timeout;                                                 \
    uint64_t before = (remaining > 0) ? os_hrtime() : 0;                     \
    while (!(condition)) {                                                   \
      loop_poll_events(loop, remaining);                                     \
      if (remaining == 0) {                                                  \
        break;                                                               \
      } else if (remaining > 0) {                                            \
        uint64_t now = os_hrtime();                                          \
        remaining -= (int) ((now - before) / 1000000);                       \
        before = now;                                                        \
        if (remaining <= 0) {                                                \
          break;                                                             \
        }                                                                    \
      }                                                                      \
    }                                                                        \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/loop.h.generated.h"
#endif

#endif  // NVIM_EVENT_LOOP_H
