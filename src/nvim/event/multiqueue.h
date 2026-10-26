#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>  // IWYU pragma: keep

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

// Poll for events until a condition or timeout.
//
// "before" advances only by the whole milliseconds subtracted from "remaining", so each pass's
// sub-millisecond remainder is carried into the next one. Dropping it lets a loop that never
// blocks, e.g. a wait() condition that closes a libuv handle or schedules a callback on every
// call, count 0 ms per pass and never reach the timeout. Adding only measured time cannot
// overflow, whatever the timeout.
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
        int64_t elapsed = (int64_t)((now - before) / 1000000); \
        before += (uint64_t)elapsed * 1000000; \
        remaining -= elapsed; \
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
