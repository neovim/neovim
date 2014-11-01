#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <uv.h>

#include "nvim/os/event.h"
#include "nvim/os/input.h"
#include "nvim/msgpack_rpc/defs.h"
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/msgpack_rpc/server.h"
#include "nvim/msgpack_rpc/helpers.h"
#include "nvim/os/provider.h"
#include "nvim/os/signal.h"
#include "nvim/os/rstream.h"
#include "nvim/os/wstream.h"
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
  int ms;
  uv_timer_t *timer;
} TimerData;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/event.c.generated.h"
#endif
static klist_t(Event) *pending_events;

void event_init(void)
{
  // early msgpack-rpc initialization
  msgpack_rpc_init_method_table();
  msgpack_rpc_helpers_init();
  // Initialize the event queues
  pending_events = kl_init(Event);
  wstream_init();
  // Initialize input events
  input_init();
  // Timer to wake the event loop if a timeout argument is passed to
  // `event_poll`
  // Signals
  signal_init();
  // Jobs
  job_init();
  // finish mspgack-rpc initialization
  channel_init();
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
void event_poll(int ms)
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

  loop(run_mode);

  if (!(--recursive)) {
    // Again, only stop when we leave the top-level invocation
    input_stop();
  }

  if (ms > 0) {
    // Ensure the timer-related handles are closed and run the event loop
    // once more to let libuv perform it's cleanup
    uv_close((uv_handle_t *)&timer, NULL);
    uv_close((uv_handle_t *)&timer_prepare, NULL);
    loop(UV_RUN_NOWAIT);
  }
}

bool event_has_deferred(void)
{
  return !kl_empty(pending_events);
}

// Queue an event
void event_push(Event event)
{
  *kl_pushp(Event, pending_events) = event;
}


void event_process(void)
{
  Event event;

  while (kl_shift(Event, pending_events, &event) == 0) {
    event.handler(event);
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

static void loop(uv_run_mode run_mode)
{
  DLOG("Enter event loop");
  uv_run(uv_default_loop(), run_mode);
  DLOG("Exit event loop");
}
