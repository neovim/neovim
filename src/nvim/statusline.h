#pragma once

#include <stddef.h>

#include "nvim/highlight_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/statusline_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Array defining what should be done when tabline is clicked
EXTERN StlClickDefinition *tab_page_click_defs INIT( = NULL);
/// Size of the tab_page_click_defs array
EXTERN size_t tab_page_click_defs_size INIT( = 0);

#include "statusline.h.generated.h"
