#ifndef NVIM_UGRID_H
#define NVIM_UGRID_H

#include "nvim/globals.h"
#include "nvim/grid_defs.h"
#include "nvim/ui.h"

struct ucell;
struct ugrid;

typedef struct ucell UCell;
typedef struct ugrid UGrid;

struct ucell {
  schar_T data;
  sattr_T attr;
};

struct ugrid {
  int row, col;
  int width, height;
  UCell **cells;
};

// -V:UGRID_FOREACH_CELL:625

#define UGRID_FOREACH_CELL(grid, row, startcol, endcol, code) \
  do { \
    UCell *row_cells = (grid)->cells[row]; \
    for (int curcol = startcol; curcol < endcol; curcol++) { \
      UCell *cell = row_cells + curcol; \
      (void)(cell); \
      code; \
    } \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ugrid.h.generated.h"
#endif
#endif  // NVIM_UGRID_H
