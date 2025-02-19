#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

/// Flags for find_file_*() functions.
enum {
  FINDFILE_FILE = 0,  ///< only files
  FINDFILE_DIR  = 1,  ///< only directories
  FINDFILE_BOTH = 2,  ///< files and directories
};

/// Values for file_name_in_line()
enum {
  FNAME_MESS  = 1,   ///< give error message
  FNAME_EXP   = 2,   ///< expand to path
  FNAME_HYP   = 4,   ///< check for hypertext link
  FNAME_INCL  = 8,   ///< apply 'includeexpr'
  FNAME_REL   = 16,  ///< ".." and "./" are relative to the (current)
                     ///< file instead of the current directory
  FNAME_UNESC = 32,  ///< remove backslashes used for escaping
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file_search.h.generated.h"
#endif
