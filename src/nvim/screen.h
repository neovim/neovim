#ifndef NVIM_SCREEN_H
#define NVIM_SCREEN_H

#include <stdbool.h>

#include "nvim/buffer_defs.h"
#include "nvim/fold.h"
#include "nvim/grid_defs.h"
#include "nvim/macros.h"

EXTERN match_T screen_search_hl;       // used for 'hlsearch' highlight matching

#define W_ENDCOL(wp)   ((wp)->w_wincol + (wp)->w_width)
#define W_ENDROW(wp)   ((wp)->w_winrow + (wp)->w_height)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "screen.h.generated.h"
#endif
#endif  // NVIM_SCREEN_H
