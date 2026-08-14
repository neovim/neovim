#pragma once

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/os/time_defs.h"  // IWYU pragma: keep

/// Flags for shada_read_file and children
typedef enum {
  kShaDaWantInfo = 1,       ///< Load non-mark information
  kShaDaWantMarks = 2,      ///< Load local file marks and change list
  kShaDaForceit = 4,        ///< Overwrite info already read
  kShaDaGetOldfiles = 8,    ///< Load v:oldfiles.
  kShaDaMissingError = 16,  ///< Error out when os_open returns -ENOENT.
  kShaDaNanos = 32,         ///< Timestamps are ns (Context), instead of seconds (shada legacy).
  kShaDaNoHistory = 64,     ///< Skip cmdline/search history merge (perf: O(history) per read).
  kShaDaNoOpt = 128,        ///< Ignore 'shada': only these flags decide what is read.
} ShaDaReadFileFlags;

#include "shada.h.generated.h"
