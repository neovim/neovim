#include <stdint.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/process.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/loop.c.generated.h"
#endif


void loop_init(Loop *loop, void *data)
{
  uv_loop_init(&loop->uv);
  loop->uv.data = loop;
  loop->deferred_events = kl_init(Event);
  loop->immediate_events = kl_init(Event);
  loop->children = kl_init(WatcherPtr);
  loop->children_stop_requests = 0;
  uv_signal_init(&loop->uv, &loop->children_watcher);
  uv_timer_init(&loop->uv, &loop->children_kill_timer);
  uv_timer_init(&loop->uv, &loop->poll_timer);
}

void loop_poll_events(Loop *loop, int ms)
{
  static int recursive = 0;

  if (recursive++) {
    abort();  // Should not re-enter uv_run
  }

  uv_run_mode mode = UV_RUN_ONCE;

  if (ms > 0) {
    // Use a repeating timeout of ms milliseconds to make sure
    // we do not block indefinitely for I/O.
    uv_timer_start(&loop->poll_timer, timer_cb, (uint64_t)ms, (uint64_t)ms);
  } else if (ms == 0) {
    // For ms == 0, we need to do a non-blocking event poll by
    // setting the run mode to UV_RUN_NOWAIT.
    mode = UV_RUN_NOWAIT;
  }

  uv_run(&loop->uv, mode);

  if (ms > 0) {
    uv_timer_stop(&loop->poll_timer);
  }

  recursive--;  // Can re-enter uv_run now
  process_events_from(loop->immediate_events);
}


// Queue an event
void loop_push_event(Loop *loop, Event event, bool deferred)
{
  // Sometimes libuv will run pending callbacks(timer for example) before
  // blocking for a poll. If this happens and the callback pushes a event to one
  // of the queues, the event would only be processed after the poll
  // returns(user hits a key for example). To avoid this scenario, we call
  // uv_stop when a event is enqueued.
  uv_stop(&loop->uv);
  kl_push(Event, deferred ? loop->deferred_events : loop->immediate_events,
      event);
}

void loop_process_event(Loop *loop)
{
  process_events_from(loop->deferred_events);
}


void loop_close(Loop *loop)
{
  uv_close((uv_handle_t *)&loop->children_watcher, NULL);
  uv_close((uv_handle_t *)&loop->children_kill_timer, NULL);
  uv_close((uv_handle_t *)&loop->poll_timer, NULL);
  do {
    uv_run(&loop->uv, UV_RUN_DEFAULT);
  } while (uv_loop_close(&loop->uv));
}

void loop_process_all_events(Loop *loop)
{
  process_events_from(loop->immediate_events);
  process_events_from(loop->deferred_events);
}

static void process_events_from(klist_t(Event) *queue)
{
  while (!kl_empty(queue)) {
    Event event = kl_shift(Event, queue);
    event.handler(event);
  }
}

static void timer_cb(uv_timer_t *handle)
{
}
