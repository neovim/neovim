#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/buffer_defs.h"
#include "nvim/marktree.h"
#include "nvim/pos.h"

/// Argument for lbr_chartabsize().
typedef struct {
  win_T *cts_win;
  char *cts_line;                ///< start of the line
  char *cts_ptr;                 ///< current position in line
  int cts_row;

  bool cts_has_virt_text;        ///< true if if there is inline virtual text
  int cts_cur_text_width_left;   ///< width of virtual text left of cursor
  int cts_cur_text_width_right;  ///< width of virtual text right of cursor
  MarkTreeIter cts_iter[1];

  int cts_vcol;                  ///< virtual column at current position
  int cts_max_head_vcol;         ///< see win_lbr_chartabsize()
} chartabsize_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "plines.h.generated.h"
#endif
