#pragma once

#include <uv.h>

#include "nvim/event/defs.h"
#include "nvim/lib/queue.h"

typedef struct multiqueue MultiQueue;
typedef void (*PutCallback)(MultiQueue *multiq, void *data);

#define multiqueue_put(q, h, ...) \
  do { \
    multiqueue_put_event(q, event_create(h, __VA_ARGS__)); \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/multiqueue.h.generated.h"
#endif
