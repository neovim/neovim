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

// -V:UGRID_FOREACH_CELL:625

#define UGRID_FOREACH_CELL(grid, top, bot, left, right, code) \
  do { \
    for (int row = top; row <= bot; row++) { \
      UCell *row_cells = (grid)->cells[row]; \
      for (int col = left; col <= right; col++) { \
        UCell *cell = row_cells + col; \
        (void)(cell); \
        code; \
      } \
    } \
  } while (0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ugrid.h.generated.h"
#endif
#endif  // NVIM_UGRID_H
