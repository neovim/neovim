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
// VimL function is called on job1, the main loop will temporarily stop polling
// the event loop queue and poll job1 queue instead. Same with channels, when
// calling `rpcrequest` we want to temporarily stop processing events from
// other sources and focus on a specific channel.

#include <assert.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>


#include <uv.h>

#include "nvim/event/multiqueue.h"
#include "nvim/memory.h"
#include "nvim/os/time.h"

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
  put_callback put_cb;
  void *data;
  size_t size;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "event/multiqueue.c.generated.h"
#endif

static Event NILEVENT = { .handler = NULL, .argv = {NULL} };

MultiQueue *multiqueue_new_parent(put_callback put_cb, void *data)
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

static MultiQueue *multiqueue_new(MultiQueue *parent, put_callback put_cb,
                                  void *data)
{
  MultiQueue *rv = xmalloc(sizeof(MultiQueue));
  QUEUE_INIT(&rv->headtail);
  rv->size = 0;
  rv->parent = parent;
  rv->put_cb = put_cb;
  rv->data = data;
  return rv;
}

void multiqueue_free(MultiQueue *this)
{
  assert(this);
  while (!QUEUE_EMPTY(&this->headtail)) {
    QUEUE *q = QUEUE_HEAD(&this->headtail);
    MultiQueueItem *item = multiqueue_node_data(q);
    if (this->parent) {
      QUEUE_REMOVE(&item->data.item.parent_item->node);
      xfree(item->data.item.parent_item);
    }
    QUEUE_REMOVE(q);
    xfree(item);
  }

  xfree(this);
}

Event multiqueue_get(MultiQueue *this)
{
  return multiqueue_empty(this) ? NILEVENT : multiqueue_remove(this);
}

void multiqueue_put_event(MultiQueue *this, Event event)
{
  assert(this);
  multiqueue_push(this, event);
  if (this->parent && this->parent->put_cb) {
    this->parent->put_cb(this->parent, this->parent->data);
  }
}

void multiqueue_process_events(MultiQueue *this)
{
  assert(this);
  while (!multiqueue_empty(this)) {
    Event event = multiqueue_get(this);
    if (event.handler) {
      event.handler(event.argv);
    }
  }
}

/// Removes all events without processing them.
void multiqueue_purge_events(MultiQueue *this)
{
  assert(this);
  while (!multiqueue_empty(this)) {
    (void)multiqueue_remove(this);
  }
}

bool multiqueue_empty(MultiQueue *this)
{
  assert(this);
  return QUEUE_EMPTY(&this->headtail);
}

void multiqueue_replace_parent(MultiQueue *this, MultiQueue *new_parent)
{
  assert(multiqueue_empty(this));
  this->parent = new_parent;
}

/// Gets the count of all events currently in the queue.
size_t multiqueue_size(MultiQueue *this)
{
  return this->size;
}

static Event multiqueue_remove(MultiQueue *this)
{
  assert(!multiqueue_empty(this));
  QUEUE *h = QUEUE_HEAD(&this->headtail);
  QUEUE_REMOVE(h);
  MultiQueueItem *item = multiqueue_node_data(h);
  Event rv;

  if (item->link) {
    assert(!this->parent);
    // remove the next node in the linked queue
    MultiQueue *linked = item->data.queue;
    assert(!multiqueue_empty(linked));
    MultiQueueItem *child =
      multiqueue_node_data(QUEUE_HEAD(&linked->headtail));
    QUEUE_REMOVE(&child->node);
    rv = child->data.item.event;
    xfree(child);
  } else {
    if (this->parent) {
      // remove the corresponding link node in the parent queue
      QUEUE_REMOVE(&item->data.item.parent_item->node);
      xfree(item->data.item.parent_item);
    }
    rv = item->data.item.event;
  }

  this->size--;
  xfree(item);
  return rv;
}

static void multiqueue_push(MultiQueue *this, Event event)
{
  MultiQueueItem *item = xmalloc(sizeof(MultiQueueItem));
  item->link = false;
  item->data.item.event = event;
  QUEUE_INSERT_TAIL(&this->headtail, &item->node);
  if (this->parent) {
    // push link node to the parent queue
    item->data.item.parent_item = xmalloc(sizeof(MultiQueueItem));
    item->data.item.parent_item->link = true;
    item->data.item.parent_item->data.queue = this;
    QUEUE_INSERT_TAIL(&this->parent->headtail,
                      &item->data.item.parent_item->node);
  }
  this->size++;
}

static MultiQueueItem *multiqueue_node_data(QUEUE *q)
{
  return QUEUE_DATA(q, MultiQueueItem, node);
}
