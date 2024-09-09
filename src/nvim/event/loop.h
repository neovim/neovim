#pragma once

#include <stdbool.h>
#include <uv.h>

#include "klib/klist.h"
#include "nvim/event/defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

typedef void *WatcherPtr;

#define _NOOP(x)
KLIST_INIT(WatcherPtr, WatcherPtr, _NOOP)

struct loop {
  uv_loop_t uv;
  MultiQueue *events;
  MultiQueue *thread_events;
  // Immediate events.
  // - "Processed after exiting `uv_run()` (to avoid recursion), but before returning from
  //   `loop_poll_events()`." 502aee690c98
  // - Practical consequence (for `main_loop`):
  //    - these are processed by `state_enter()..input_get()` whereas "regular" events
  //      (`main_loop.events`) are processed by `state_enter()..VimState.execute()`
  //    - `state_enter()..input_get()` can be "too early" if you want the event to trigger UI
  //      updates and other user-activity-related side-effects.
  MultiQueue *fast_events;

  // used by process/job-control subsystem
  klist_t(WatcherPtr) *children;
  uv_signal_t children_watcher;
  uv_timer_t children_kill_timer;

  // generic timer, used by loop_poll_events()
  uv_timer_t poll_timer;

  uv_timer_t exit_delay_timer;

  uv_async_t async;
  uv_mutex_t mutex;
  int recursive;
  bool closing;  ///< Set to true if loop_close() has been called
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/loop.h.generated.h"
#endif
