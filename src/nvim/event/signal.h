#pragma once

#include <uv.h>

#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"

struct signal_watcher;

typedef struct signal_watcher SignalWatcher;
typedef void (*signal_cb)(SignalWatcher *watcher, int signum, void *data);
typedef void (*signal_close_cb)(SignalWatcher *watcher, void *data);

struct signal_watcher {
  uv_signal_t uv;
  void *data;
  signal_cb cb;
  signal_close_cb close_cb;
  MultiQueue *events;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/signal.h.generated.h"
#endif
