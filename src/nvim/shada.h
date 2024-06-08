#pragma once

#include <msgpack.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"

/// Flags for shada_read_file and children
typedef enum {
  kShaDaWantInfo = 1,       ///< Load non-mark information
  kShaDaWantMarks = 2,      ///< Load local file marks and change list
  kShaDaForceit = 4,        ///< Overwrite info already read
  kShaDaGetOldfiles = 8,    ///< Load v:oldfiles.
  kShaDaMissingError = 16,  ///< Error out when os_open returns -ENOENT.
} ShaDaReadFileFlags;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "shada.h.generated.h"
#endif
