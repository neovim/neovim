// Cancelable Operations API
//
// Provides a minimal, deterministic contract for long-running operations
// that can report progress, be canceled, and have observable state.
//
// THREADING GUARANTEE:
// All Operation APIs must be called on the main event loop thread.
// Operation state mutation is NOT thread-safe.

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/private/defs.h"  // Object
#include "nvim/lib/queue_defs.h"

typedef enum {
  OP_RUNNING = 0,
  OP_FINISHED = 1,
  OP_CANCELED = 2,
  OP_FAILED = 3,
} OperationState;

typedef struct Operation {
  uint64_t id;           // Unique stable handle
  char *title;           // malloc'd, stable

  OperationState state;  // Current lifecycle state

  bool has_progress;     // Whether progress has been set
  float progress;        // [0.0, 1.0] (only valid if has_progress)

  Object result;         // Valid only if state == OP_FINISHED
  Object error;          // Valid only if state == OP_FAILED

  int refcount;          // Registry + Lua refs
  QUEUE node;            // Intrusive registry list (only for OP_RUNNING)
} Operation;

typedef struct {
  QUEUE ops;             // Only OP_RUNNING operations
  uint64_t next_id;
} OpRegistry;

extern OpRegistry op_registry;

//
// Core Initialization
//

/// Initialize the operation registry.
/// Called once at startup from event_init().
void ops_init(void);

//
// Core Lifecycle
//

/// Creates a new running operation with the given title.
/// Returns a handle that can be retained by Lua callbacks.
Operation *op_create(const char *title);

/// Increment refcount (for Lua refs).
void op_retain(Operation *op);

/// Decrement refcount and free if zero.
void op_release(Operation *op);

//
// State Transitions (all idempotent)
//

/// Transition to FINISHED and store result.
/// Idempotent: second call is a no-op.
void op_finish(Operation *op, Object result);

/// Transition to FAILED and store error.
/// Idempotent: second call is a no-op.
void op_fail(Operation *op, Object error);

/// Transition to CANCELED.
/// Idempotent: second call is a no-op.
void op_cancel(Operation *op);

//
// Queries (all safe from any thread that has a valid ref)
//

/// Returns the current state.
OperationState op_state(Operation *op) FUNC_ATTR_PURE;

/// Returns true if state is CANCELED.
bool op_is_canceled(Operation *op) FUNC_ATTR_PURE;

/// Returns the title string.
const char *op_title(Operation *op) FUNC_ATTR_PURE;

/// Returns true if progress has been set.
bool op_has_progress(Operation *op) FUNC_ATTR_PURE;

/// Returns progress value [0.0, 1.0] if set, else 0.0.
/// Check has_progress() first if you need to distinguish "never set" from 0.0.
float op_progress(Operation *op) FUNC_ATTR_PURE;

/// Returns the result (nil until finished).
Object op_result(Operation *op) FUNC_ATTR_PURE;

/// Returns the error (nil unless failed).
Object op_error(Operation *op) FUNC_ATTR_PURE;

//
// Progress Update
//

/// Sets progress [0.0, 1.0], clamped.
/// Ignored if operation is not running.
void op_set_progress(Operation *op, float progress);

//
// Registry Query
//

/// Returns a snapshot of all running operations.
/// The array must be freed; each operation is retained and must be released by caller.
size_t op_list(Operation ***out);
