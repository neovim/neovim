#ifndef NVIM_EXTMARK_DEFS_H
#define NVIM_EXTMARK_DEFS_H

#include "klib/kvec.h"
#include "nvim/types.h"

typedef struct {
  char *text;
  int hl_id;
} VirtTextChunk;

typedef struct undo_object ExtmarkUndoObject;
typedef kvec_t(ExtmarkUndoObject) extmark_undo_vec_t;

// Undo/redo extmarks

typedef enum {
  kExtmarkNOOP,        // Extmarks shouldn't be moved
  kExtmarkUndo,        // Operation should be reversible/undoable
  kExtmarkNoUndo,      // Operation should not be reversible
  kExtmarkUndoNoRedo,  // Operation should be undoable, but not redoable
} ExtmarkOp;

typedef enum {
  kDecorLevelNone = 0,
  kDecorLevelVisible = 1,
  kDecorLevelVirtLine = 2,
} DecorLevel;

#endif  // NVIM_EXTMARK_DEFS_H
