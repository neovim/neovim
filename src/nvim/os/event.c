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

typedef struct {
  bool timed_out;
  int32_t ms;
  uv_timer_t *timer;
} TimerData;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/event.c.generated.h"
#endif
static klist_t(Event) *deferred_events, *immediate_events;

void event_init()
{
  // Initialize the event queues
  deferred_events = kl_init(Event);
  immediate_events = kl_init(Event);
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
  uv_run_mode run_mode = UV_RUN_ONCE;

  if (input_ready()) {
    // If there's a pending input event to be consumed, do it now
    return true;
  }

  static int recursive = 0;

  if (!(recursive++)) {
    // Only needs to start the libuv handle the first time we enter here
    input_start();
  }

  uv_timer_t timer;
  uv_prepare_t timer_prepare;
  TimerData timer_data = {.ms = ms, .timed_out = false, .timer = &timer};

  if (ms > 0) {
    uv_timer_init(uv_default_loop(), &timer);
    // This prepare handle that actually starts the timer
    uv_prepare_init(uv_default_loop(), &timer_prepare);
    // Timeout passed as argument to the timer
    timer.data = &timer_data;
    // We only start the timer after the loop is running, for that we
    // use a prepare handle(pass the interval as data to it)
    timer_prepare.data = &timer_data;
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
    // Process immediate events outside uv_run since libuv event loop not
    // support recursion(processing events may cause a recursive event_poll
    // call)
    event_process(false);
  } while (
      // Continue running if ...
      !input_ready() &&   // we have no input
      !event_has_deferred() &&   // no events are waiting to be processed
      run_mode != UV_RUN_NOWAIT &&   // ms != 0
      !timer_data.timed_out);  // we didn't get a timeout

  if (!(--recursive)) {
    // Again, only stop when we leave the top-level invocation
    input_stop();
  }

  if (ms > 0) {
    // Ensure the timer-related handles are closed and run the event loop
    // once more to let libuv perform it's cleanup
    uv_close((uv_handle_t *)&timer, NULL);
    uv_close((uv_handle_t *)&timer_prepare, NULL);
    uv_run(uv_default_loop(), UV_RUN_NOWAIT);
    event_process(false);
  }

  return input_ready() || event_has_deferred();
}

bool event_has_deferred()
{
  return !kl_empty(get_queue(true));
}

// Push an event to the queue
void event_push(Event event, bool deferred)
{
  *kl_pushp(Event, get_queue(deferred)) = event;
}

// Runs the appropriate action for each queued event
void event_process(bool deferred)
{
  Event event;

  while (kl_shift(Event, get_queue(deferred), &event) == 0) {
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
  TimerData *data = handle->data;
  data->timed_out = true;
}

static void timer_prepare_cb(uv_prepare_t *handle)
{
  TimerData *data = handle->data;
  assert(data->ms > 0);
  uv_timer_start(data->timer, timer_cb, (uint32_t)data->ms, 0);
  uv_prepare_stop(handle);
}

static klist_t(Event) *get_queue(bool deferred)
{
  return deferred ? deferred_events : immediate_events;
}
