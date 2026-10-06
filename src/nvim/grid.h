#pragma once

#include <stdbool.h>
#include <stddef.h>  // IWYU pragma: keep

#include "nvim/buffer_defs.h"  // IWYU pragma: keep
#include "nvim/grid_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/mbyte_defs.h"
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
EXTERN GridView default_gridview INIT( = { .target = &default_grid });

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
static const schar_T braille_space = 0xe2a08000;
#else
# define schar_from_ascii(x) ((schar_T)(x))
static const schar_T braille_space = 0x0080a0e2;
#endif

#include "grid.h.generated.h"

/// Get the screen char from a valid cluster
///
/// Caller is expected to check for things like unprintable chars etc
/// If first char in cur.str is a composing char, prepend a space to display it correctly.
static inline schar_T schar_from_cluster(StrCharInfo ci, ClusterInfo cli)
{
  assert(ci.chr.value >= 0);  // did you eat your vegetables?
  ptrdiff_t len = cli.next.ptr - ci.ptr;
  // be fast and furious for ASCII
  if (EXPECT(len == 1, true)) {
    return schar_from_ascii(ci.chr.value);
  }

  if (cli.first_compose || len > 4) {
    return schar_from_cluster_impl(ci.ptr, (size_t)len, cli.first_compose);
  }

  schar_T sc = 0;
  memcpy((char *)&sc, ci.ptr, (size_t)len);
  return sc;
}

static inline bool schar_invisible(schar_T sc)
{
  return sc == schar_from_ascii(' ') || sc == braille_space;
}
