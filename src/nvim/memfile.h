#ifndef NVIM_MEMFILE_H
#define NVIM_MEMFILE_H

#include "nvim/buffer_defs.h"
#include "nvim/memfile_defs.h"

/// flags for mf_sync()
#define MFS_ALL         1       /// also sync blocks with negative numbers
#define MFS_STOP        2       /// stop syncing when a character is available
#define MFS_FLUSH       4       /// flushed file to disk
#define MFS_ZERO        8       /// only write block 0

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memfile.h.generated.h"
#endif
#endif  // NVIM_MEMFILE_H
