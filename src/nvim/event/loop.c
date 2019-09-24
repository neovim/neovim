// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <stdarg.h>
#include <stdint.h>

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/process.h"
#include "nvim/log.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/loop.c.generated.h"
#endif


void loop_init(Loop *loop, void *data)
{
  uv_loop_init(&loop->uv);
  loop->recursive = 0;
  loop->uv.data = loop;
  loop->children = kl_init(WatcherPtr);
  loop->events = multiqueue_new_parent(loop_on_put, loop);
  loop->fast_events = multiqueue_new_child(loop->events);
  loop->thread_events = multiqueue_new_parent(NULL, NULL);
  uv_mutex_init(&loop->mutex);
  uv_async_init(&loop->uv, &loop->async, async_cb);
  uv_signal_init(&loop->uv, &loop->children_watcher);
  uv_timer_init(&loop->uv, &loop->children_kill_timer);
  uv_timer_init(&loop->uv, &loop->poll_timer);
  loop->poll_timer.data = xmalloc(sizeof(bool));  // "timeout expired" flag
}

/// Processes one `Loop.uv` event (at most).
/// Processes all `Loop.fast_events` events.
/// Does NOT process `Loop.events`, that is an application-specific decision.
///
/// @param loop
/// @param ms   0: non-blocking poll.
///            >0: timeout after `ms`.
///            <0: wait forever.
/// @returns true if `ms` timeout was reached
bool loop_poll_events(Loop *loop, int ms)
{
  if (loop->recursive++) {
    abort();  // Should not re-enter uv_run
  }

  uv_run_mode mode = UV_RUN_ONCE;
  bool timeout_expired = false;

  if (ms > 0) {
    *((bool *)loop->poll_timer.data) = false;  // reset "timeout expired" flag
    // Dummy timer to ensure UV_RUN_ONCE does not block indefinitely for I/O.
    uv_timer_start(&loop->poll_timer, timer_cb, (uint64_t)ms, (uint64_t)ms);
  } else if (ms == 0) {
    // For ms == 0, do a non-blocking event poll.
    mode = UV_RUN_NOWAIT;
  }

  uv_run(&loop->uv, mode);

  if (ms > 0) {
    timeout_expired = *((bool *)loop->poll_timer.data);
    uv_timer_stop(&loop->poll_timer);
  }

  loop->recursive--;  // Can re-enter uv_run now
  multiqueue_process_events(loop->fast_events);
  return timeout_expired;
}

/// Schedules a fast event from another thread.
///
/// @note Event is queued into `fast_events`, which is processed outside of the
///       primary `events` queue by loop_poll_events(). For `main_loop`, that
///       means `fast_events` is NOT processed in an "editor mode"
///       (VimState.execute), so redraw and other side-effects are likely to be
///       skipped.
/// @see loop_schedule_deferred
void loop_schedule_fast(Loop *loop, Event event)
{
  uv_mutex_lock(&loop->mutex);
  multiqueue_put_event(loop->thread_events, event);
  uv_async_send(&loop->async);
  uv_mutex_unlock(&loop->mutex);
}

/// Schedules an event from another thread. Unlike loop_schedule_fast(), the
/// event is forwarded to `Loop.events`, instead of being processed immediately.
///
/// @see loop_schedule_fast
void loop_schedule_deferred(Loop *loop, Event event)
{
  Event *eventp = xmalloc(sizeof(*eventp));
  *eventp = event;
  loop_schedule_fast(loop, event_create(loop_deferred_event, 2, loop, eventp));
}
static void loop_deferred_event(void **argv)
{
  Loop *loop = argv[0];
  Event *eventp = argv[1];
  multiqueue_put_event(loop->events, *eventp);
  xfree(eventp);
}

void loop_on_put(MultiQueue *queue, void *data)
{
  Loop *loop = data;
  // Sometimes libuv will run pending callbacks (timer for example) before
  // blocking for a poll. If this happens and the callback pushes a event to one
  // of the queues, the event would only be processed after the poll
  // returns (user hits a key for example). To avoid this scenario, we call
  // uv_stop when a event is enqueued.
  uv_stop(&loop->uv);
}

/// @returns false if the loop could not be closed gracefully
bool loop_close(Loop *loop, bool wait)
{
  bool rv = true;
  uv_mutex_destroy(&loop->mutex);
  uv_close((uv_handle_t *)&loop->children_watcher, NULL);
  uv_close((uv_handle_t *)&loop->children_kill_timer, NULL);
  uv_close((uv_handle_t *)&loop->poll_timer, timer_close_cb);
  uv_close((uv_handle_t *)&loop->async, NULL);
  uint64_t start = wait ? os_hrtime() : 0;
  while (true) {
    uv_run(&loop->uv, wait ? UV_RUN_DEFAULT : UV_RUN_NOWAIT);
    if (!uv_loop_close(&loop->uv) || !wait) {
      break;
    }
    if (os_hrtime() - start >= 2 * 1000000000) {
      // Some libuv resource was not correctly deref'd. Log and bail.
      rv = false;
      ELOG("uv_loop_close() hang?");
      log_uv_handles(&loop->uv);
      break;
    }
  }
  multiqueue_free(loop->fast_events);
  multiqueue_free(loop->thread_events);
  multiqueue_free(loop->events);
  kl_destroy(WatcherPtr, loop->children);
  return rv;
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
  // Flush thread_events to fast_events for processing on main loop.
  while (!multiqueue_empty(l->thread_events)) {
    Event ev = multiqueue_get(l->thread_events);
    multiqueue_put_event(l->fast_events, ev);
  }
  uv_mutex_unlock(&l->mutex);
}

static void timer_cb(uv_timer_t *handle)
{
  bool *timeout_expired = handle->data;
  *timeout_expired = true;
}

static void timer_close_cb(uv_handle_t *handle)
{
  xfree(handle->data);
}
