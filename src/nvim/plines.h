#ifndef NVIM_PLINES_H
#define NVIM_PLINES_H

#include <stdbool.h>

#include "nvim/buffer_defs.h"
#include "nvim/vim.h"

// Argument for lbr_chartabsize().
typedef struct {
  win_T *cts_win;
  char *cts_line;    // start of the line
  char *cts_ptr;     // current position in line

  bool cts_has_virt_text;  // true if if a property inserts text
  int cts_cur_text_width;     // width of current inserted text
  // TODO(bfredl): iterator in to the marktree for scanning virt text

  int cts_vcol;    // virtual column at current position
} chartabsize_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "plines.h.generated.h"
#endif
#endif  // NVIM_PLINES_H
