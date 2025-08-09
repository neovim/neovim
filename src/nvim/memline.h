#pragma once

#include "nvim/ascii_defs.h"
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/memline_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

#include "memline.h.generated.h"

/// LINEEMPTY() - return true if the line is empty
#define LINEEMPTY(p) (*ml_get(p) == NUL)
