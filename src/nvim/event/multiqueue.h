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

// Poll for events until `condition` or timeout. Checks `condition` after the last poll, which may
// have run past the timeout.
#define LOOP_PROCESS_EVENTS_UNTIL(loop, multiqueue, timeout, condition) \
  do { \
    const int64_t timeout_ms = (timeout); \
    const uint64_t start = (timeout_ms >= 0) ? os_hrtime() : 0; \
    int64_t remaining = timeout_ms; \
    bool expired = false; \
    while (!(condition) && !expired) { \
      LOOP_PROCESS_EVENTS(loop, multiqueue, remaining); \
      if (timeout_ms >= 0) { \
        remaining = timeout_ms - (int64_t)((os_hrtime() - start) / 1000000); \
        expired = remaining <= 0; \
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
