#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

/// Flags for find_file_*() functions.
enum {
  FINDFILE_FILE = 0,  ///< only files
  FINDFILE_DIR  = 1,  ///< only directories
  FINDFILE_BOTH = 2,  ///< files and directories
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file_search.h.generated.h"
#endif
