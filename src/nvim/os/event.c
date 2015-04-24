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
#include "nvim/os/signal.h"
#include "nvim/os/rstream.h"
#include "nvim/os/wstream.h"
#include "nvim/os/job.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/misc2.h"
#include "nvim/ui.h"
#include "nvim/screen.h"
#include "nvim/terminal.h"

#include "nvim/lib/klist.h"

// event will be cleaned up after it gets processed
#define _destroy_event(x)  // do nothing
KLIST_INIT(Event, Event, _destroy_event)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/event.c.generated.h"
#endif
// deferred_events:  Events that should be processed as the K_EVENT special key
// immediate_events: Events that should be processed after exiting libuv event
//                   loop(to avoid recursion), but before returning from
//                   `event_poll`
static klist_t(Event) *deferred_events = NULL, *immediate_events = NULL;
static int deferred_events_allowed = 0;

void event_init(void)
{
  // Initialize the event queues
  deferred_events = kl_init(Event);
  immediate_events = kl_init(Event);
  // early msgpack-rpc initialization
  msgpack_rpc_init_method_table();
  msgpack_rpc_helpers_init();
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
  terminal_init();
}

void event_teardown(void)
{
  if (!deferred_events) {
    // Not initialized(possibly a --version invocation)
    return;
  }

  process_events_from(immediate_events);
  process_events_from(deferred_events);
  // reset the stop_flag to ensure `uv_run` below won't exit early. This hack
  // is required because the `process_events_from` above may call `event_push`
  // which will set the stop_flag to 1(uv_stop)
  uv_default_loop()->stop_flag = 0;
  input_stop_stdin();
  channel_teardown();
  job_teardown();
  server_teardown();
  signal_teardown();
  terminal_teardown();
  // this last `uv_run` will return after all handles are stopped, it will
  // also take care of finishing any uv_close calls made by other *_teardown
  // functions.
  uv_run(uv_default_loop(), UV_RUN_DEFAULT);
  // abort that if we left unclosed handles
  if (uv_loop_close(uv_default_loop())) {
    abort();
  }
}

/// Wait for an event.
///
/// @param ms  0: non-blocking poll. >0: timeout after `ms`.
void event_poll(size_t ms)
{
  static int recursive = 0;

  if (recursive++) {
    abort();  // Should not re-enter uv_run
  }

  uv_run_mode run_mode = UV_RUN_ONCE;
  uv_timer_t timer;

  if (ms > 0) {
    uv_timer_init(uv_default_loop(), &timer);
    // Use a repeating timeout of ms milliseconds to make sure
    // we do not block indefinitely for I/O.
    uv_timer_start(&timer, timer_cb, (uint64_t)ms, (uint64_t)ms);
  } else if (ms == 0) {
    // For ms == 0, we need to do a non-blocking event poll by
    // setting the run mode to UV_RUN_NOWAIT.
    run_mode = UV_RUN_NOWAIT;
  }

  loop(run_mode);

  if (ms > 0) {
    // Ensure the timer handle is closed and run the event loop
    // once more to let libuv perform its cleanup.
    uv_timer_stop(&timer);
    uv_close((uv_handle_t *)&timer, NULL);
    loop(UV_RUN_NOWAIT);
  }

  recursive--;  // Can re-enter uv_run now

  if (immediate_events) {  // May be NULL before event_init.
    process_events_from(immediate_events);
  }
}

bool event_has_deferred(void)
{
  return deferred_events_allowed && !kl_empty(deferred_events);
}

void event_enable_deferred(void)
{
  ++deferred_events_allowed;
}

void event_disable_deferred(void)
{
  --deferred_events_allowed;
}

// Queue an event
void event_push(Event event, bool deferred)
{
  // Sometimes libuv will run pending callbacks(timer for example) before
  // blocking for a poll. If this happens and the callback pushes a event to one
  // of the queues, the event would only be processed after the poll
  // returns(user hits a key for example). To avoid this scenario, we call
  // uv_stop when a event is enqueued.
  uv_stop(uv_default_loop());
  *kl_pushp(Event, deferred ? deferred_events : immediate_events) = event;
}

void event_process(void)
{
  process_events_from(deferred_events);
}

static void process_events_from(klist_t(Event) *queue)
{
  Event event;

  while (kl_shift(Event, queue, &event) == 0) {
    event.handler(event);
  }
}

static void timer_cb(uv_timer_t *handle)
{
}

static void loop(uv_run_mode run_mode)
{
  DLOG("Enter event loop");
  uv_run(uv_default_loop(), run_mode);
  DLOG("Exit event loop");
}
