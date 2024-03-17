#pragma once

#include <stdbool.h>
#include <stddef.h>  // IWYU pragma: keep

#include "nvim/grid_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

/// By default, all windows are drawn on a single rectangular grid, represented by
/// this ScreenGrid instance. In multigrid mode each window will have its own
/// grid, then this is only used for global screen elements that hasn't been
/// externalized.
///
/// Note: before the screen is initialized and when out of memory these can be
/// NULL.
EXTERN ScreenGrid default_grid INIT( = SCREEN_GRID_INIT);

#define DEFAULT_GRID_HANDLE 1  // handle for the default_grid

/// While resizing the screen this flag is set.
EXTERN bool resizing_screen INIT( = 0);

EXTERN schar_T *linebuf_char INIT( = NULL);
EXTERN sattr_T *linebuf_attr INIT( = NULL);
EXTERN colnr_T *linebuf_vcol INIT( = NULL);
EXTERN char *linebuf_scratch INIT( = NULL);

/// flags for grid_put_linebuf()
enum {
  SLF_RIGHTLEFT = 1,
  SLF_WRAP      = 2,
  SLF_INC_VCOL  = 4,
};

/// Put a ASCII character in a screen cell.
///
/// If `x` is a compile time constant, schar_from_ascii(x) will also be.
/// But the specific value varies per platform.
#ifdef ORDER_BIG_ENDIAN
# define schar_from_ascii(x) ((schar_T)((x) << 24))
#else
# define schar_from_ascii(x) ((schar_T)(x))
#endif

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "grid.h.generated.h"
#endif
