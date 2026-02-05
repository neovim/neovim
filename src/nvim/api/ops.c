#include <assert.h>
#include <math.h>

#include "nvim/api/ops.h"
#include "nvim/api/private/helpers.h"
#include "nvim/lib/queue_defs.h"
#include "nvim/memory.h"

// Global operation registry
OpRegistry op_registry = {
  .next_id = 0,
};

//
// Internal Helpers
//

static Object nil_object(void)
{
  return (Object)OBJECT_INIT;
}

static float clamp_progress(float p)
{
  if (isnan(p)) {
    return 0.0f;
  }
  if (p < 0.0f) {
    return 0.0f;
  }
  if (p > 1.0f) {
    return 1.0f;
  }
  return p;
}

// One-time initialization (called at startup)
void ops_init(void)
{
  QUEUE_INIT(&op_registry.ops);
}

// Transition to terminal state and remove from registry.
// Idempotent: only transitions if currently running.
static void op_enter_terminal_state(Operation *op, OperationState new_state)
{
  if (op->state != OP_RUNNING) {
    return;
  }

  op->state = new_state;

  // Remove from registry so vim.op.list() returns only running ops
  QUEUE_REMOVE(&op->node);
  QUEUE_INIT(&op->node);

  // Release the registry's refcount
  op->refcount--;
}

//
// Core Lifecycle
//

Operation *op_create(const char *title)
{
  Operation *op = xcalloc(1, sizeof(*op));

  op->id = ++op_registry.next_id;
  op->title = xstrdup(title);
  op->state = OP_RUNNING;
  op->has_progress = false;
  op->progress = 0.0f;
  op->result = nil_object();
  op->error = nil_object();
  op->refcount = 2;  // 1 for registry, 1 for caller

  QUEUE_INIT(&op->node);
  QUEUE_INSERT_TAIL(&op_registry.ops, &op->node);

  return op;
}

void op_retain(Operation *op)
{
  if (op) {
    op->refcount++;
  }
}

void op_release(Operation *op)
{
  if (!op) {
    return;
  }

  assert(op->refcount > 0);
  op->refcount--;

  if (op->refcount == 0) {
    xfree(op->title);
    api_free_object(op->result);
    api_free_object(op->error);
    xfree(op);
  }
}

//
// State Transitions
//

void op_finish(Operation *op, Object result)
{
  if (op->state != OP_RUNNING) {
    return;
  }

  op->result = result;
  op_enter_terminal_state(op, OP_FINISHED);
}

void op_fail(Operation *op, Object error)
{
  if (op->state != OP_RUNNING) {
    return;
  }

  op->error = error;
  op_enter_terminal_state(op, OP_FAILED);
}

void op_cancel(Operation *op)
{
  op_enter_terminal_state(op, OP_CANCELED);
}

//
// Queries
//

OperationState op_state(Operation *op)
{
  return op->state;
}

bool op_is_canceled(Operation *op)
{
  return op->state == OP_CANCELED;
}

const char *op_title(Operation *op)
{
  return op->title;
}

bool op_has_progress(Operation *op)
{
  return op->has_progress;
}

float op_progress(Operation *op)
{
  return op->has_progress ? op->progress : 0.0f;
}

Object op_result(Operation *op)
{
  return op->state == OP_FINISHED ? op->result : nil_object();
}

Object op_error(Operation *op)
{
  return op->state == OP_FAILED ? op->error : nil_object();
}

//
// Progress Update
//

void op_set_progress(Operation *op, float progress)
{
  if (op->state != OP_RUNNING) {
    return;
  }

  op->has_progress = true;
  op->progress = clamp_progress(progress);
}

//
// Registry Query
//

size_t op_list(Operation ***out)
{
  assert(out != NULL);

  // Count running ops
  size_t count = 0;
  QUEUE *q;
  QUEUE_FOREACH(q, &op_registry.ops, {
    count++;
  });

  // Allocate array
  Operation **arr = xmalloc(sizeof(Operation *) * (count + 1));

  // Fill array and retain each
  size_t i = 0;
  QUEUE_FOREACH(q, &op_registry.ops, {
    Operation *op = QUEUE_DATA(q, Operation, node);
    op_retain(op);
    arr[i++] = op;
  });
  arr[i] = NULL;  // Null-terminate for safety

  *out = arr;
  return count;
}
