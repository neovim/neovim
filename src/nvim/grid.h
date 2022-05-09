#ifndef NVIM_GRID_H
#define NVIM_GRID_H

#include <stdbool.h>

#include "nvim/ascii.h"
#include "nvim/buffer_defs.h"
#include "nvim/grid_defs.h"

/// By default, all windows are drawn on a single rectangular grid, represented by
/// this ScreenGrid instance. In multigrid mode each window will have its own
/// grid, then this is only used for global screen elements that hasn't been
/// externalized.
///
/// Note: before the screen is initialized and when out of memory these can be
/// NULL.
EXTERN ScreenGrid default_grid INIT(= SCREEN_GRID_INIT);

#define DEFAULT_GRID_HANDLE 1  // handle for the default_grid

EXTERN schar_T *linebuf_char INIT(= NULL);
EXTERN sattr_T *linebuf_attr INIT(= NULL);

// Low-level functions to manipulate individual character cells on the
// screen grid.

/// Put a ASCII character in a screen cell.
static inline void schar_from_ascii(char_u *p, const char c)
{
  p[0] = (char_u)c;
  p[1] = 0;
}

/// Put a unicode character in a screen cell.
static inline int schar_from_char(char_u *p, int c)
{
  int len = utf_char2bytes(c, (char *)p);
  p[len] = NUL;
  return len;
}

/// compare the contents of two screen cells.
static inline int schar_cmp(char_u *sc1, char_u *sc2)
{
  return strncmp((char *)sc1, (char *)sc2, sizeof(schar_T));
}

/// copy the contents of screen cell `sc2` into cell `sc1`
static inline void schar_copy(char_u *sc1, char_u *sc2)
{
  xstrlcpy((char *)sc1, (char *)sc2, sizeof(schar_T));
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "grid.h.generated.h"
#endif
#endif  // NVIM_GRID_H
