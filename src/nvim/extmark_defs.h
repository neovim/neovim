#ifndef NVIM_EXTMARK_DEFS_H
#define NVIM_EXTMARK_DEFS_H

#include "nvim/lib/kvec.h"
#include "nvim/types.h"

typedef struct Decoration Decoration;

typedef struct {
  char *text;
  int hl_id;
} VirtTextChunk;


typedef struct
{
  uint64_t ns_id;
  uint64_t mark_id;
  // TODO(bfredl): a lot of small allocations. Should probably use
  // kvec_t(Decoration) as an arena. Alternatively, store ns_id/mark_id
  // _inline_ in MarkTree and use the map only for decorations.
  Decoration *decor;
} ExtmarkItem;

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
