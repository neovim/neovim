#pragma once

#include "nvim/ascii_defs.h"
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/memline_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

#include "memline.h.generated.h"

/// LINEEMPTY() - return true if the line is empty
#define LINEEMPTY(p) (*ml_get(p) == NUL)

// Values for the flags argument of ml_delete_flags().
enum {
  ML_DEL_MESSAGE = 1,  // may give a "No lines in buffer" message
  // ML_DEL_UNDO = 2,  // called from undo
};

// Values for the flags argument of ml_append_int().
enum {
  ML_APPEND_NEW = 1,   // starting to edit a new file
  ML_APPEND_MARK = 2,  // mark the new line
  // ML_APPEND_UNDO = 4,  // called from undo
};
