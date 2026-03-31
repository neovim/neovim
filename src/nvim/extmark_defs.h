#pragma once

#include "klib/kvec.h"

// TODO(bfredl): good enough name for now.
typedef ptrdiff_t bcount_t;

typedef struct undo_object ExtmarkUndoObject;
typedef kvec_t(ExtmarkUndoObject) extmark_undo_vec_t;

// Undo/redo extmarks

typedef enum {
  kExtmarkNOOP,        // Extmarks shouldn't be moved
  kExtmarkUndo,        // Operation should be reversible/undoable
  kExtmarkNoUndo,      // Operation should not be reversible
  kExtmarkUndoNoRedo,  // Operation should be undoable, but not redoable
} ExtmarkOp;
