#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/event.h"
#include "nvim/os/input.h"
#include "nvim/os/channel.h"
#include "nvim/os/server.h"
#include "nvim/os/provider.h"
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
// NULL-terminated array of event sources that we should process immediately.
//
// Events from sources that are not contained in this array are processed
// later when `event_process` is called
static EventSource *immediate_sources = NULL;

void event_init(void)
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
  // Providers
  provider_init();
}

void event_teardown(void)
{
  channel_teardown();
  job_teardown();
  server_teardown();
}

// Wait for some event
bool event_poll(int32_t ms, EventSource sources[])
  FUNC_ATTR_NONNULL_ARG(2)
{
  uv_run_mode run_mode = UV_RUN_ONCE;

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

  size_t processed_events;

  do {
    // Run one event loop iteration, blocking for events if run_mode is
    // UV_RUN_ONCE
    processed_events = loop(run_mode, sources);
  } while (
      // Continue running if ...
      !processed_events &&   // we didn't process any immediate events
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
    processed_events += loop(UV_RUN_NOWAIT, sources);
  }

  return !timer_data.timed_out && (processed_events || event_has_deferred());
}

bool event_has_deferred(void)
{
  return !kl_empty(deferred_events);
}

// Queue an event
void event_push(Event event)
{
  bool defer = true;

  if (immediate_sources) {
    size_t i;
    EventSource src;

    for (src = immediate_sources[i = 0]; src; src = immediate_sources[++i]) {
      if (src == event.source) {
        defer = false;
        break;
      }
    }
  }

  *kl_pushp(Event, defer ? deferred_events : immediate_events) = event;
}

void event_process(void)
{
  process_from(deferred_events);
}

// Runs the appropriate action for each queued event
static size_t process_from(klist_t(Event) *queue)
{
  size_t count = 0;
  Event event;

  while (kl_shift(Event, queue, &event) == 0) {
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
    count++;
  }

  DLOG("Processed %u events", count);

  return count;
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

static void requeue_deferred_events(void)
{
  size_t remaining = deferred_events->size;

  DLOG("Number of deferred events: %u", remaining);

  while (remaining--) {
    // Re-push each deferred event to ensure it will be in the right queue
    Event event;
    kl_shift(Event, deferred_events, &event);
    event_push(event);
    DLOG("Re-queueing event");
  }

  DLOG("Number of deferred events: %u", deferred_events->size);
}

static size_t loop(uv_run_mode run_mode, EventSource *sources)
{
  size_t count;
  immediate_sources = sources;
  // It's possible that some events from the immediate sources are waiting
  // in the deferred queue. If so, move them to the immediate queue so they
  // will be processed in order of arrival by the next `process_from` call.
  requeue_deferred_events();
  count = process_from(immediate_events);

  if (count) {
    // No need to enter libuv, events were already processed
    return count;
  }

  DLOG("Enter event loop");
  uv_run(uv_default_loop(), run_mode);
  DLOG("Exit event loop");
  immediate_sources = NULL;
  count = process_from(immediate_events);
  return count;
}
