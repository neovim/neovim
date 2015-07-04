#ifndef NVIM_SHADA_H
#define NVIM_SHADA_H

typedef long ShadaPosition;

/// Flags for shada_read_file and children
enum {
  kShaDaWantInfo = 1,     ///< Load non-mark information
  kShaDaWantMarks = 2,    ///< Load local file marks and change list
  kShaDaForceit = 4,      ///< Overwrite info already read
  kShaDaGetOldfiles = 8,  ///< Load v:oldfiles.
  kShaDaWantHeader = 16,  ///< Do not skip header (shada_read_next_item).
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "shada.h.generated.h"
#endif

#endif  // NVIM_SHADA_H
