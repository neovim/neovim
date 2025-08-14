#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/event/defs.h"  // IWYU pragma: keep
#include "nvim/os/time.h"  // IWYU pragma: keep

#include "event/multiqueue.h.generated.h"

#define multiqueue_put(q, h, ...) \
  do { \
    multiqueue_put_event(q, event_create(h, __VA_ARGS__)); \
  } while (0)

#define CREATE_EVENT(multiqueue, handler, ...) \
  do { \
    if (multiqueue) { \
      multiqueue_put((multiqueue), (handler), __VA_ARGS__); \
    } else { \
      void *argv[] = { __VA_ARGS__ }; \
      (handler)(argv); \
    } \
  } while (0)

// Poll for events until a condition or timeout
#define LOOP_PROCESS_EVENTS_UNTIL(loop, multiqueue, timeout, condition) \
  do { \
    int64_t remaining = timeout; \
    uint64_t before = (remaining > 0) ? os_hrtime() : 0; \
    while (!(condition)) { \
      LOOP_PROCESS_EVENTS(loop, multiqueue, remaining); \
      if (remaining == 0) { \
        break; \
      } else if (remaining > 0) { \
        uint64_t now = os_hrtime(); \
        remaining -= (int64_t)((now - before) / 1000000); \
        before = now; \
        if (remaining <= 0) { \
          break; \
        } \
      } \
    } \
  } while (0)

#define LOOP_PROCESS_EVENTS(loop, multiqueue, timeout) \
  do { \
    if (multiqueue && !multiqueue_empty(multiqueue)) { \
      multiqueue_process_events(multiqueue); \
    } else { \
      loop_poll_events(loop, timeout); \
    } \
  } while (0)
