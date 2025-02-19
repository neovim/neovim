#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/extmark_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/marktree_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

EXTERN int curbuf_splice_pending INIT( = 0);

typedef kvec_t(MTPair) ExtmarkInfoArray;

// delete the columns between mincol and endcol
typedef struct {
  int start_row;
  colnr_T start_col;
  int old_row;
  colnr_T old_col;
  int new_row;
  colnr_T new_col;
  bcount_t start_byte;
  bcount_t old_byte;
  bcount_t new_byte;
} ExtmarkSplice;

// adjust marks after :move operation
typedef struct {
  int start_row;
  int start_col;
  int extent_row;
  int extent_col;
  int new_row;
  int new_col;
  bcount_t start_byte;
  bcount_t extent_byte;
  bcount_t new_byte;
} ExtmarkMove;

// extmark was updated
typedef struct {
  uint64_t mark;  // raw mark id of the marktree
  int old_row;
  colnr_T old_col;
  bool invalidated;
} ExtmarkSavePos;

typedef enum {
  kExtmarkSplice,
  kExtmarkMove,
  kExtmarkUpdate,
  kExtmarkSavePos,
  kExtmarkClear,
} UndoObjectType;

// TODO(bfredl): if possible unify these with marktree flags,
// so it is possible to filter extmarks directly on top-level flags
typedef enum {
  kExtmarkNone = 0x1,
  kExtmarkSign = 0x2,
  kExtmarkSignHL = 0x4,
  kExtmarkVirtText = 0x8,
  kExtmarkVirtLines = 0x10,
  kExtmarkHighlight = 0x20,
} ExtmarkType;

// TODO(bfredl): reduce the number of undo action types
struct undo_object {
  UndoObjectType type;
  union {
    ExtmarkSplice splice;
    ExtmarkMove move;
    ExtmarkSavePos savepos;
  } data;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "extmark.h.generated.h"
#endif
