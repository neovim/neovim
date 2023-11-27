#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/getchar_defs.h"  // IWYU pragma: export
#include "nvim/os/fileio.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Argument for flush_buffers().
typedef enum {
  FLUSH_MINIMAL,
  FLUSH_TYPEAHEAD,  ///< flush current typebuf contents
  FLUSH_INPUT,      ///< flush typebuf and inchar() input
} flush_buffers_T;

/// Maximum number of streams to read script from
enum { NSCRIPT = 15, };

/// Streams to read script from
extern FileDescriptor *scriptin[NSCRIPT];

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "getchar.h.generated.h"
#endif
