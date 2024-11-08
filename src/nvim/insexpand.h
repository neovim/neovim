#pragma once

#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "insexpand.h.generated.h"
#endif

/// Array indexes used for cp_text[].
typedef enum {
  CPT_ABBR,   ///< "abbr"
  CPT_KIND,   ///< "kind"
  CPT_MENU,   ///< "menu"
  CPT_INFO,   ///< "info"
  CPT_COUNT,  ///< Number of entries
} cpitem_T;
