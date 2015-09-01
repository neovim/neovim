// Queue for selective async event processing. Instances of this queue support a
// parent/child relationship with the following properties:
//
// - pushing a node to a child queue will push a corresponding link node to the
//   parent queue
// - removing a link node from a parent queue will remove the next node
//   in the linked child queue
// - removing a node from a child queue will remove the corresponding link node
//   in the parent queue
//
// These properties allow neovim to organize and process events from different
// sources with a certain degree of control. Here's how the queue is used:
//
//                         +----------------+
//                         |   Main loop    |
//                         +----------------+
//                                  ^
//                                  |
//                         +----------------+
//         +-------------->|   Event loop   |<------------+
//         |               +--+-------------+             |
//         |                  ^           ^               |
//         |                  |           |               |
//    +-----------+   +-----------+    +---------+    +---------+
//    | Channel 1 |   | Channel 2 |    |  Job 1  |    |  Job 2  |
//    +-----------+   +-----------+    +---------+    +---------+
//
//
// In the above diagram, the lower boxes represents event emitters, each with
// it's own private queue that have the event loop queue as the parent.
//
// When idle, the main loop spins the event loop which queues events from many
// sources(channels, jobs, user...). Each event emitter pushes events to its own
// private queue which is propagated to the event loop queue. When the main loop
// consumes an event, the corresponding event is removed from the emitter's
// queue.
//
// The main reason for this queue hierarchy is to allow focusing on a single
// event emitter while blocking the main loop. For example, if the `jobwait`
// vimscript function is called on job1, the main loop will temporarily stop
// polling the event loop queue and poll job1 queue instead. Same with channels,
// when calling `rpcrequest`, we want to temporarily stop processing events from
// other sources and focus on a specific channel.

#include <assert.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>


#include <uv.h>

#include "nvim/event/queue.h"
#include "nvim/memory.h"
#include "nvim/os/time.h"

typedef struct queue_item QueueItem;
struct queue_item {
  union {
    Queue *queue;
    struct {
      Event event;
      QueueItem *parent;
    } item;
  } data;
  bool link;  // this is just a link to a node in a child queue
  QUEUE node;
};

struct queue {
  Queue *parent;
  QUEUE headtail;
  put_callback put_cb;
  void *data;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/queue.c.generated.h"
#endif

static Event NILEVENT = {.handler = NULL, .argv = {NULL}};

Queue *queue_new_parent(put_callback put_cb, void *data)
{
  return queue_new(NULL, put_cb, data);
}

Queue *queue_new_child(Queue *parent)
  FUNC_ATTR_NONNULL_ALL
{
  assert(!parent->parent);
  return queue_new(parent, NULL, NULL);
}

static Queue *queue_new(Queue *parent, put_callback put_cb, void *data)
{
  Queue *rv = xmalloc(sizeof(Queue));
  QUEUE_INIT(&rv->headtail);
  rv->parent = parent;
  rv->put_cb = put_cb;
  rv->data = data;
  return rv;
}

void queue_free(Queue *queue)
{
  assert(queue);
  while (!QUEUE_EMPTY(&queue->headtail)) {
    QUEUE *q = QUEUE_HEAD(&queue->headtail);
    QueueItem *item = queue_node_data(q);
    if (queue->parent) {
      QUEUE_REMOVE(&item->data.item.parent->node);
      xfree(item->data.item.parent);
    }
    QUEUE_REMOVE(q);
    xfree(item);
  }

  xfree(queue);
}

Event queue_get(Queue *queue)
{
  return queue_empty(queue) ? NILEVENT : queue_remove(queue);
}

void queue_put_event(Queue *queue, Event event)
{
  assert(queue);
  queue_push(queue, event);
  if (queue->parent && queue->parent->put_cb) {
    queue->parent->put_cb(queue->parent, queue->parent->data);
  }
}

void queue_process_events(Queue *queue)
{
  assert(queue);
  while (!queue_empty(queue)) {
    Event event = queue_get(queue);
    if (event.handler) {
      event.handler(event.argv);
    }
  }
}

bool queue_empty(Queue *queue)
{
  assert(queue);
  return QUEUE_EMPTY(&queue->headtail);
}

void queue_replace_parent(Queue *queue, Queue *new_parent)
{
  assert(queue_empty(queue));
  queue->parent = new_parent;
}

static Event queue_remove(Queue *queue)
{
  assert(!queue_empty(queue));
  QUEUE *h = QUEUE_HEAD(&queue->headtail);
  QUEUE_REMOVE(h);
  QueueItem *item = queue_node_data(h);
  Event rv;

  if (item->link) {
    assert(!queue->parent);
    // remove the next node in the linked queue
    Queue *linked = item->data.queue;
    assert(!queue_empty(linked));
    QueueItem *child =
      queue_node_data(QUEUE_HEAD(&linked->headtail));
    QUEUE_REMOVE(&child->node);
    rv = child->data.item.event;
    xfree(child);
  } else {
    if (queue->parent) {
      // remove the corresponding link node in the parent queue
      QUEUE_REMOVE(&item->data.item.parent->node);
      xfree(item->data.item.parent);
    }
    rv = item->data.item.event;
  }

  xfree(item);
  return rv;
}

static void queue_push(Queue *queue, Event event)
{
  QueueItem *item = xmalloc(sizeof(QueueItem));
  item->link = false;
  item->data.item.event = event;
  QUEUE_INSERT_TAIL(&queue->headtail, &item->node);
  if (queue->parent) {
    // push link node to the parent queue
    item->data.item.parent = xmalloc(sizeof(QueueItem));
    item->data.item.parent->link = true;
    item->data.item.parent->data.queue = queue;
    QUEUE_INSERT_TAIL(&queue->parent->headtail, &item->data.item.parent->node);
  }
}

static QueueItem *queue_node_data(QUEUE *q)
{
  return QUEUE_DATA(q, QueueItem, node);
}
