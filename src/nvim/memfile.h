#pragma once

#include "nvim/memfile_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// flags for mf_sync()
enum {
  MFS_ALL   = 1,  ///< also sync blocks with negative numbers
  MFS_STOP  = 2,  ///< stop syncing when a character is available
  MFS_FLUSH = 4,  ///< flushed file to disk
  MFS_ZERO  = 8,  ///< only write block 0
};

enum {
  /// Minimal size for block 0 of a swap file.
  /// NOTE: This depends on size of struct block0! It's not done with a sizeof(),
  /// because struct block0 is defined in memline.c (Sorry).
  /// The maximal block size is arbitrary.
  MIN_SWAP_PAGE_SIZE = 1048,
  MAX_SWAP_PAGE_SIZE = 50000,
};

#include "memfile.h.generated.h"
