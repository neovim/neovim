#ifndef NVIM_UGRID_H
#define NVIM_UGRID_H

#include "nvim/ui.h"
#include "nvim/globals.h"

typedef struct ucell UCell;
typedef struct ugrid UGrid;

#define CELLBYTES (sizeof(schar_T))

struct ucell {
  char data[CELLBYTES + 1];
  sattr_T attr;
};

struct ugrid {
  int row, col;
  int width, height;
  UCell **cells;
};

static inline UCell *ugrid_get_cell(UGrid *grid, int row, int col)
{
  if (row >= 0 && row < grid->height && col >= 0 && col < grid->width) {
    return &grid->cells[row][col];
  }
  return NULL;
}

// -V:UGRID_FOREACH_CELL:625

#define UGRID_FOREACH_CELL(grid, row, startcol, endcol, code) \
  do { \
    if (row >= 0 && row < (grid)->height) { \
      UCell *row_cells = (grid)->cells[row]; \
      for (int curcol = startcol < 0 ? 0 : \
           startcol >= (grid)->width ? (grid)->width - 1 : \
           startcol; curcol < endcol && curcol < (grid)->width; curcol++) { \
        UCell *cell = row_cells + curcol; \
        (void)(cell); \
        code; \
      } \
    } \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ugrid.h.generated.h"
#endif
#endif  // NVIM_UGRID_H
