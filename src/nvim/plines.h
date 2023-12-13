#pragma once

#include <stdbool.h>
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/marktree_defs.h"
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"

/// Argument for lbr_chartabsize().
typedef struct {
  win_T *cts_win;
  char *cts_line;                ///< start of the line
  char *cts_ptr;                 ///< current position in line
  int cts_vcol;                  ///< virtual column at current position
  int indent_width;              ///< width of showbreak and breakindent on wrapped lines
                                 ///  INT_MIN if not yet calculated

  int virt_row;                  ///< line number, -1 if no virtual text
  int cts_cur_text_width_left;   ///< width of virtual text left of cursor
  int cts_cur_text_width_right;  ///< width of virtual text right of cursor

  int cts_max_head_vcol;         ///< see win_lbr_chartabsize()
  MarkTreeIter cts_iter[1];
} chartabsize_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "plines.h.generated.h"
#endif
