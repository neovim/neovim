#pragma once

#include "nvim/types_defs.h"

typedef struct {
  schar_T data;
  sattr_T attr;
} UCell;

typedef struct {
  int row, col;
  int width, height;
  UCell **cells;
} UGrid;

#define UGRID_FOREACH_CELL(grid, row, startcol, endcol, code) \
  do { \
    UCell *row_cells = (grid)->cells[row]; \
    for (int curcol = startcol; curcol < endcol; curcol++) { \
      UCell *cell = row_cells + curcol; \
      (void)(cell); \
      code; \
    } \
  } while (0)

#include "ugrid.h.generated.h"
