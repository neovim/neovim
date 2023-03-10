#ifndef NVIM_DRAWLINE_H
#define NVIM_DRAWLINE_H

#include <stdbool.h>
#include <stdint.h>

#include "klib/kvec.h"
#include "nvim/decoration_provider.h"
#include "nvim/fold.h"
#include "nvim/macros.h"
#include "nvim/screen.h"
#include "nvim/types.h"

// Maximum columns for terminal highlight attributes
#define TERM_ATTRS_MAX 1024

typedef struct {
  NS ns_id;
  uint64_t mark_id;
  int win_row;
  int win_col;
} WinExtmark;
EXTERN kvec_t(WinExtmark) win_extmark_arr INIT(= KV_INITIAL_VALUE);

EXTERN bool conceal_cursor_used INIT(= false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "drawline.h.generated.h"
#endif
#endif  // NVIM_DRAWLINE_H
