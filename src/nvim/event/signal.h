#ifndef NVIM_EVENT_SIGNAL_H
#define NVIM_EVENT_SIGNAL_H

#include <uv.h>

#include "nvim/event/loop.h"

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
#endif  // NVIM_EVENT_SIGNAL_H
