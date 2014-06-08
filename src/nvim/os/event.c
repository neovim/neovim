#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/event.h"
#include "nvim/os/input.h"
#include "nvim/os/channel.h"
#include "nvim/os/server.h"
#include "nvim/os/signal.h"
#include "nvim/os/rstream.h"
#include "nvim/os/job.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/misc2.h"

#include "nvim/lib/klist.h"

// event will be cleaned up after it gets processed
#define _destroy_event(x)  // do nothing
KLIST_INIT(Event, Event, _destroy_event)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/event.c.generated.h"
#endif
static klist_t(Event) *event_queue;
static uv_timer_t timer;
static uv_prepare_t timer_prepare;

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
  // Channels
  channel_init();
  // Servers
  server_init();
  uv_timer_init(uv_default_loop(), &timer);
  // This prepare handle that actually starts the timer
  uv_prepare_init(uv_default_loop(), &timer_prepare);
}

void event_teardown()
{
  channel_teardown();
  job_teardown();
  server_teardown();
}

// Wait for some event
bool event_poll(int32_t ms)
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
    // use a prepare handle(pass the interval as data to it)
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

  return input_ready() || event_is_pending();
}

bool event_is_pending()
{
  return !kl_empty(event_queue);
}

// Push an event to the queue
void event_push(Event event)
{
  *kl_pushp(Event, event_queue) = event;
}

// Runs the appropriate action for each queued event
void event_process()
{
  Event event;

  while (kl_shift(Event, event_queue, &event) == 0) {
    switch (event.type) {
      case kEventSignal:
        signal_handle(event);
        break;
      case kEventRStreamData:
        rstream_read_event(event);
        break;
      case kEventJobExit:
        job_exit_event(event);
        break;
      default:
        abort();
    }
  }
}

// Set a flag in the `event_poll` loop for signaling of a timeout
static void timer_cb(uv_timer_t *handle)
{
  *((bool *)handle->data) = true;
}

static void timer_prepare_cb(uv_prepare_t *handle)
{
  uv_timer_start(&timer, timer_cb, *(uint32_t *)timer_prepare.data, 0);
  uv_prepare_stop(&timer_prepare);
}
