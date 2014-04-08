#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "lib/klist.h"
#include "os/event.h"
#include "os/input.h"
#include "os/signal.h"
#include "os/job.h"
#include "vim.h"
#include "memory.h"
#include "misc2.h"

// event will be cleaned up after it gets processed
#define _destroy_event(x)  // do nothing
KLIST_INIT(Event, Event, _destroy_event)

static klist_t(Event) *event_queue;
static uv_timer_t timer;
static uv_prepare_t timer_prepare;
static bool poll_uv_loop(int ms);
static void process_all_events(void);
static void timer_cb(uv_timer_t *handle, int);
static void timer_prepare_cb(uv_prepare_t *, int);

void event_init()
{
  // Initialize the event queue
  event_queue = kl_init(Event);
  // Initialize input events
  input_init();
  // Timer to wake the event loop if a timeout argument is passed to
  // `event_poll`
  // Signals
  signal_init();
  // Jobs
  job_init();
  uv_timer_init(uv_default_loop(), &timer);
  // This prepare handle that actually starts the timer
  uv_prepare_init(uv_default_loop(), &timer_prepare);
}

bool event_poll(int32_t ms)
{
  int64_t remaining = ms;
  uint64_t end;
  bool result;

  if (ms > 0) {
    // Calculate end time in nanoseconds
    end = uv_hrtime() + ms * 1e6;
  }

  for (;;) {
    result = poll_uv_loop((int32_t)remaining);
    // Process queued events
    process_all_events();

    if (ms > 0) {
      // Calculate remaining time in milliseconds
      remaining = (end - uv_hrtime()) / 1e6;
    }

    if (input_ready() || got_int) {
      // Bail out if we have pending input
      return true;
    }

    if (!result || (ms >= 0 && remaining <= 0)) {
      // Or if we timed out
      return false;
    }
  }
}

// Push an event to the queue
void event_push(Event event)
{
  *kl_pushp(Event, event_queue) = event;
}

// Runs the appropriate action for each queued event
static void process_all_events()
{
  Event event;

  while (kl_shift(Event, event_queue, &event) == 0) {
    switch (event.type) {
      case kEventSignal:
        signal_handle(event);
        break;
      case kEventJobActivity:
        job_handle(event);
        break;
      default:
        abort();
    }
  }
}

// Wait for some event
static bool poll_uv_loop(int32_t ms)
{
  bool timed_out;
  uv_run_mode run_mode = UV_RUN_ONCE;

  if (input_ready()) {
    // If there's a pending input event to be consumed, do it now
    return true;
  }

  input_start();
  timed_out = false;

  if (ms > 0) {
    // Timeout passed as argument to the timer
    timer.data = &timed_out;
    // We only start the timer after the loop is running, for that we
    // use an prepare handle(pass the interval as data to it)
    timer_prepare.data = &ms;
    uv_prepare_start(&timer_prepare, timer_prepare_cb);
  } else if (ms == 0) {
    // For ms == 0, we need to do a non-blocking event poll by
    // setting the run mode to UV_RUN_NOWAIT.
    run_mode = UV_RUN_NOWAIT;
  }

  do {
    // Run one event loop iteration, blocking for events if run_mode is
    // UV_RUN_ONCE
    uv_run(uv_default_loop(), run_mode);
  } while (
      // Continue running if ...
      !input_ready() &&   // we have no input
      kl_empty(event_queue) &&   // no events are waiting to be processed
      run_mode != UV_RUN_NOWAIT &&   // ms != 0
      !timed_out);  // we didn't get a timeout

  input_stop();

  if (ms > 0) {
    // Stop the timer
    uv_timer_stop(&timer);
  }

  return input_ready() || !kl_empty(event_queue);
}

// Set a flag in the `event_poll` loop for signaling of a timeout
static void timer_cb(uv_timer_t *handle, int status)
{
  *((bool *)handle->data) = true;
}

static void timer_prepare_cb(uv_prepare_t *handle, int status)
{
  uv_timer_start(&timer, timer_cb, *(uint32_t *)timer_prepare.data, 0);
  uv_prepare_stop(&timer_prepare);
}
