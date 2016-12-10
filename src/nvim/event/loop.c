#include <stdarg.h>
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
  loop->recursive = 0;
  loop->uv.data = loop;
  loop->children = kl_init(WatcherPtr);
  loop->children_stop_requests = 0;
  loop->events = multiqueue_new_parent(loop_on_put, loop);
  loop->fast_events = multiqueue_new_child(loop->events);
  loop->thread_events = multiqueue_new_parent(NULL, NULL);
  uv_mutex_init(&loop->mutex);
  uv_async_init(&loop->uv, &loop->async, async_cb);
  uv_signal_init(&loop->uv, &loop->children_watcher);
  uv_timer_init(&loop->uv, &loop->children_kill_timer);
  uv_timer_init(&loop->uv, &loop->poll_timer);
}

void loop_poll_events(Loop *loop, int ms)
{
  if (loop->recursive++) {
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

  loop->recursive--;  // Can re-enter uv_run now
  multiqueue_process_events(loop->fast_events);
}

// Schedule an event from another thread
void loop_schedule(Loop *loop, Event event)
{
  uv_mutex_lock(&loop->mutex);
  multiqueue_put_event(loop->thread_events, event);
  uv_async_send(&loop->async);
  uv_mutex_unlock(&loop->mutex);
}

void loop_on_put(MultiQueue *queue, void *data)
{
  Loop *loop = data;
  // Sometimes libuv will run pending callbacks(timer for example) before
  // blocking for a poll. If this happens and the callback pushes a event to one
  // of the queues, the event would only be processed after the poll
  // returns(user hits a key for example). To avoid this scenario, we call
  // uv_stop when a event is enqueued.
  uv_stop(&loop->uv);
}

void loop_close(Loop *loop, bool wait)
{
  uv_mutex_destroy(&loop->mutex);
  uv_close((uv_handle_t *)&loop->children_watcher, NULL);
  uv_close((uv_handle_t *)&loop->children_kill_timer, NULL);
  uv_close((uv_handle_t *)&loop->poll_timer, NULL);
  uv_close((uv_handle_t *)&loop->async, NULL);
  do {
    uv_run(&loop->uv, wait ? UV_RUN_DEFAULT : UV_RUN_NOWAIT);
  } while (uv_loop_close(&loop->uv) && wait);
  multiqueue_free(loop->fast_events);
  multiqueue_free(loop->thread_events);
  multiqueue_free(loop->events);
  kl_destroy(WatcherPtr, loop->children);
}

void loop_purge(Loop *loop)
{
  uv_mutex_lock(&loop->mutex);
  multiqueue_purge_events(loop->thread_events);
  multiqueue_purge_events(loop->fast_events);
  uv_mutex_unlock(&loop->mutex);
}

size_t loop_size(Loop *loop)
{
  uv_mutex_lock(&loop->mutex);
  size_t rv = multiqueue_size(loop->thread_events);
  uv_mutex_unlock(&loop->mutex);
  return rv;
}

static void async_cb(uv_async_t *handle)
{
  Loop *l = handle->loop->data;
  uv_mutex_lock(&l->mutex);
  while (!multiqueue_empty(l->thread_events)) {
    Event ev = multiqueue_get(l->thread_events);
    multiqueue_put_event(l->fast_events, ev);
  }
  uv_mutex_unlock(&l->mutex);
}

static void timer_cb(uv_timer_t *handle)
{
}

