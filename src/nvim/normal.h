#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/macros_defs.h"
#include "nvim/normal_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Values for find_ident_under_cursor()
enum {
  FIND_IDENT  = 1,  ///< find identifier (word)
  FIND_STRING = 2,  ///< find any string (WORD)
  FIND_EVAL   = 4,  ///< include "->", "[]" and "."
};

/// 'showcmd' buffer shared between normal.c and statusline.c
EXTERN char showcmd_buf[SHOWCMD_BUFLEN];

#include "normal.h.generated.h"
