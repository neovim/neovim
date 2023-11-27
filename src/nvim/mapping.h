#pragma once

#include <stdint.h>  // IWYU pragma: keep
#include <stdio.h>  // IWYU pragma: keep

#include "nvim/api/keysets_defs.h"  // IWYU pragma: keep
#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/mapping_defs.h"  // IWYU pragma: export
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/regexp_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Used for the first argument of do_map()
enum {
  MAPTYPE_MAP     = 0,
  MAPTYPE_UNMAP   = 1,
  MAPTYPE_NOREMAP = 2,
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mapping.h.generated.h"
#endif
