#ifndef NVIM_MAPPING_H
#define NVIM_MAPPING_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/api/keysets.h"
#include "nvim/api/private/defs.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/mapping_defs.h"
#include "nvim/option_defs.h"
#include "nvim/regexp_defs.h"
#include "nvim/types.h"

/// Used for the first argument of do_map()
enum {
  MAPTYPE_MAP     = 0,
  MAPTYPE_UNMAP   = 1,
  MAPTYPE_NOREMAP = 2,
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mapping.h.generated.h"
#endif
#endif  // NVIM_MAPPING_H
