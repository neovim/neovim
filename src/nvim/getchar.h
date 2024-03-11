#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/getchar_defs.h"  // IWYU pragma: keep
#include "nvim/os/fileio_defs.h"
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Argument for flush_buffers().
typedef enum {
  FLUSH_MINIMAL,
  FLUSH_TYPEAHEAD,  ///< flush current typebuf contents
  FLUSH_INPUT,      ///< flush typebuf and inchar() input
} flush_buffers_T;

enum { NSCRIPT = 15, };  ///< Maximum number of streams to read script from

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "getchar.h.generated.h"
#endif
