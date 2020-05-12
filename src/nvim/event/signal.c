// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/signal.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/signal.c.generated.h"
#endif


void signal_watcher_init(Loop *loop, SignalWatcher *watcher, void *data)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_NONNULL_ARG(2)
{
  uv_signal_init(&loop->uv, &watcher->uv);
  watcher->uv.data = watcher;
  watcher->data = data;
  watcher->cb = NULL;
  watcher->events = loop->fast_events;
}

void signal_watcher_start(SignalWatcher *watcher, signal_cb cb, int signum)
  FUNC_ATTR_NONNULL_ALL
{
  watcher->cb = cb;
  uv_signal_start(&watcher->uv, signal_watcher_cb, signum);
}

void signal_watcher_stop(SignalWatcher *watcher)
  FUNC_ATTR_NONNULL_ALL
{
  uv_signal_stop(&watcher->uv);
}

void signal_watcher_close(SignalWatcher *watcher, signal_close_cb cb)
  FUNC_ATTR_NONNULL_ARG(1)
{
  watcher->close_cb = cb;
  uv_close((uv_handle_t *)&watcher->uv, close_cb);
}

static void signal_event(void **argv)
{
  SignalWatcher *watcher = argv[0];
  watcher->cb(watcher, watcher->uv.signum, watcher->data);
}

static void signal_watcher_cb(uv_signal_t *handle, int signum)
{
  SignalWatcher *watcher = handle->data;
  CREATE_EVENT(watcher->events, signal_event, 1, watcher);
}

static void close_cb(uv_handle_t *handle)
{
  SignalWatcher *watcher = handle->data;
  if (watcher->close_cb) {
    watcher->close_cb(watcher, watcher->data);
  }
}
