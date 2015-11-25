#ifndef NVIM_EVENT_QUEUE_H
#define NVIM_EVENT_QUEUE_H

#include <uv.h>

#include "nvim/event/defs.h"
#include "nvim/lib/queue.h"

typedef struct queue Queue;
typedef void (*put_callback)(Queue *queue, void *data);

#define queue_put(q, h, ...) \
  queue_put_event(q, event_create(1, h, __VA_ARGS__));


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/queue.h.generated.h"
#endif
#endif  // NVIM_EVENT_QUEUE_H
