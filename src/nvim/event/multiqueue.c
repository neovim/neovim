// Multi-level queue for selective async event processing.
// Not threadsafe; access must be synchronized externally.
//
// Multiqueue supports a parent-child relationship with these properties:
// - pushing a node to a child queue will push a corresponding link node to the
//   parent queue
// - removing a link node from a parent queue will remove the next node
//   in the linked child queue
// - removing a node from a child queue will remove the corresponding link node
//   in the parent queue
//
// These properties allow Nvim to organize and process events from different
// sources with a certain degree of control. How the multiqueue is used:
//
//                         +----------------+
//                         |   Main loop    |
//                         +----------------+
//
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
// The lower boxes represent event emitters, each with its own private queue
// having the event loop queue as the parent.
//
// When idle, the main loop spins the event loop which queues events from many
// sources (channels, jobs, user...). Each event emitter pushes events to its
// private queue which is propagated to the event loop queue. When the main loop
// consumes an event, the corresponding event is removed from the emitter's
// queue.
//
// The main reason for this queue hierarchy is to allow focusing on a single
// event emitter while blocking the main loop. For example, if the `jobwait`
// Vimscript function is called on job1, the main loop will temporarily stop polling
// the event loop queue and poll job1 queue instead. Same with channels, when
// calling `rpcrequest` we want to temporarily stop processing events from
// other sources and focus on a specific channel.

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>

#include "nvim/event/defs.h"
#include "nvim/event/multiqueue.h"
#include "nvim/lib/queue_defs.h"
#include "nvim/memory.h"

typedef struct multiqueue_item MultiQueueItem;
struct multiqueue_item {
  union {
    MultiQueue *queue;
    struct {
      Event event;
      MultiQueueItem *parent_item;
    } item;
  } data;
  bool link;  // true: current item is just a link to a node in a child queue
  QUEUE node;
};

struct multiqueue {
  MultiQueue *parent;
  QUEUE headtail;  // circularly-linked
  PutCallback put_cb;
  void *data;
  size_t size;
};

typedef struct {
  Event event;
  bool fired;
  int refcount;
} MulticastEvent;  ///< Event present on multiple queues.

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/multiqueue.c.generated.h"
#endif

static Event NILEVENT = { .handler = NULL, .argv = { NULL } };

MultiQueue *multiqueue_new_parent(PutCallback put_cb, void *data)
{
  return multiqueue_new(NULL, put_cb, data);
}

MultiQueue *multiqueue_new_child(MultiQueue *parent)
  FUNC_ATTR_NONNULL_ALL
{
  assert(!parent->parent);  // parent cannot have a parent, more like a "root"
  parent->size++;
  return multiqueue_new(parent, NULL, NULL);
}

static MultiQueue *multiqueue_new(MultiQueue *parent, PutCallback put_cb, void *data)
{
  MultiQueue *rv = xmalloc(sizeof(MultiQueue));
  QUEUE_INIT(&rv->headtail);
  rv->size = 0;
  rv->parent = parent;
  rv->put_cb = put_cb;
  rv->data = data;
  return rv;
}

void multiqueue_free(MultiQueue *self)
{
  assert(self);
  QUEUE *q;
  QUEUE_FOREACH(q, &self->headtail, {
    MultiQueueItem *item = multiqueue_node_data(q);
    if (self->parent) {
      QUEUE_REMOVE(&item->data.item.parent_item->node);
      xfree(item->data.item.parent_item);
    }
    QUEUE_REMOVE(q);
    xfree(item);
  })

  xfree(self);
}

/// Removes the next item and returns its Event.
Event multiqueue_get(MultiQueue *self)
{
  return multiqueue_empty(self) ? NILEVENT : multiqueue_remove(self);
}

void multiqueue_put_event(MultiQueue *self, Event event)
{
  assert(self);
  multiqueue_push(self, event);
  if (self->parent && self->parent->put_cb) {
    self->parent->put_cb(self->parent, self->parent->data);
  }
}

/// Move events from src to dest.
void multiqueue_move_events(MultiQueue *dest, MultiQueue *src)
  FUNC_ATTR_NONNULL_ALL
{
  while (!multiqueue_empty(src)) {
    Event event = multiqueue_get(src);
    multiqueue_put_event(dest, event);
  }
}

void multiqueue_process_events(MultiQueue *self)
{
  assert(self);
  while (!multiqueue_empty(self)) {
    Event event = multiqueue_remove(self);
    if (event.handler) {
      event.handler(event.argv);
    }
  }
}

/// Removes all events without processing them.
void multiqueue_purge_events(MultiQueue *self)
{
  assert(self);
  while (!multiqueue_empty(self)) {
    multiqueue_remove(self);
  }
}

bool multiqueue_empty(MultiQueue *self)
{
  assert(self);
  return QUEUE_EMPTY(&self->headtail);
}

void multiqueue_replace_parent(MultiQueue *self, MultiQueue *new_parent)
{
  assert(multiqueue_empty(self));
  self->parent = new_parent;
}

/// Gets the count of all events currently in the queue.
size_t multiqueue_size(MultiQueue *self)
{
  return self->size;
}

/// Gets an Event from an item.
///
/// @param remove   Remove the node from its queue, and free it.
static Event multiqueueitem_get_event(MultiQueueItem *item, bool remove)
{
  assert(item != NULL);
  Event ev;
  if (item->link) {
    // get the next node in the linked queue
    MultiQueue *linked = item->data.queue;
    assert(!multiqueue_empty(linked));
    MultiQueueItem *child =
      multiqueue_node_data(QUEUE_HEAD(&linked->headtail));
    ev = child->data.item.event;
    // remove the child node
    if (remove) {
      QUEUE_REMOVE(&child->node);
      xfree(child);
    }
  } else {
    // remove the corresponding link node in the parent queue
    if (remove && item->data.item.parent_item) {
      QUEUE_REMOVE(&item->data.item.parent_item->node);
      xfree(item->data.item.parent_item);
      item->data.item.parent_item = NULL;
    }
    ev = item->data.item.event;
  }
  return ev;
}

static Event multiqueue_remove(MultiQueue *self)
{
  assert(!multiqueue_empty(self));
  QUEUE *h = QUEUE_HEAD(&self->headtail);
  QUEUE_REMOVE(h);
  MultiQueueItem *item = multiqueue_node_data(h);
  assert(!item->link || !self->parent);  // Only a parent queue has link-nodes
  Event ev = multiqueueitem_get_event(item, true);
  self->size--;
  xfree(item);
  return ev;
}

static void multiqueue_push(MultiQueue *self, Event event)
{
  MultiQueueItem *item = xmalloc(sizeof(MultiQueueItem));
  item->link = false;
  item->data.item.event = event;
  item->data.item.parent_item = NULL;
  QUEUE_INSERT_TAIL(&self->headtail, &item->node);
  if (self->parent) {
    // push link node to the parent queue
    item->data.item.parent_item = xmalloc(sizeof(MultiQueueItem));
    item->data.item.parent_item->link = true;
    item->data.item.parent_item->data.queue = self;
    QUEUE_INSERT_TAIL(&self->parent->headtail,
                      &item->data.item.parent_item->node);
  }
  self->size++;
}

static MultiQueueItem *multiqueue_node_data(QUEUE *q)
  FUNC_ATTR_NO_SANITIZE_ADDRESS
{
  return QUEUE_DATA(q, MultiQueueItem, node);
}

/// Multicasts a one-shot event to multiple queues.
///
/// The handler will be invoked once by the _first_ queue that consumes the
/// event. Later processing will do nothing (just memory cleanup).
///
/// @param ev  Event
/// @param num  Number of queues that the event will be put on
/// @return Event that is safe to put onto `num` queues
Event event_create_oneshot(Event ev, int num)
{
  MulticastEvent *data = xmalloc(sizeof(*data));
  data->event = ev;
  data->fired = false;
  data->refcount = num;
  return event_create(multiqueue_oneshot_event, data);
}
static void multiqueue_oneshot_event(void **argv)
{
  MulticastEvent *data = argv[0];
  if (!data->fired) {
    data->fired = true;
    if (data->event.handler) {
      data->event.handler(data->event.argv);
    }
  }
  if ((--data->refcount) == 0) {
    xfree(data);
  }
}
