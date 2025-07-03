#pragma once

#include <stddef.h>  // IWYU pragma: keep
#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/getchar_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Argument for flush_buffers().
typedef enum {
  FLUSH_MINIMAL,
  FLUSH_TYPEAHEAD,  ///< flush current typebuf contents
  FLUSH_INPUT,      ///< flush typebuf and inchar() input
} flush_buffers_T;

enum { NSCRIPT = 15, };  ///< Maximum number of streams to read script from

EXTERN bool disable_char_avail_for_testing INIT( = false);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "getchar.h.generated.h"
#endif
