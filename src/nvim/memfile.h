#pragma once

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/memfile_defs.h"  // IWYU pragma: export

/// flags for mf_sync()
enum {
  MFS_ALL   = 1,  ///< also sync blocks with negative numbers
  MFS_STOP  = 2,  ///< stop syncing when a character is available
  MFS_FLUSH = 4,  ///< flushed file to disk
  MFS_ZERO  = 8,  ///< only write block 0
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memfile.h.generated.h"
#endif
