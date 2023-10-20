#ifndef NVIM_STATUSLINE_H
#define NVIM_STATUSLINE_H

#include <stddef.h>

#include "nvim/buffer_defs.h"
#include "nvim/macros.h"
#include "nvim/statusline_defs.h"

/// Array defining what should be done when tabline is clicked
EXTERN StlClickDefinition *tab_page_click_defs INIT( = NULL);
/// Size of the tab_page_click_defs array
EXTERN size_t tab_page_click_defs_size INIT( = 0);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "statusline.h.generated.h"
#endif

#endif  // NVIM_STATUSLINE_H
