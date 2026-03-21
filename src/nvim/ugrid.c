#include <assert.h>
#include <string.h>

#include "nvim/grid.h"
#include "nvim/memory.h"
#include "nvim/ugrid.h"

#include "ugrid.c.generated.h"

void ugrid_init(UGrid *grid)
{
  grid->cells = NULL;
}

void ugrid_free(UGrid *grid)
{
  destroy_cells(grid);
}

void ugrid_resize(UGrid *grid, int width, int height)
{
  destroy_cells(grid);
  grid->cells = xmalloc((size_t)height * sizeof(UCell *));
  for (int i = 0; i < height; i++) {
    grid->cells[i] = xcalloc((size_t)width, sizeof(UCell));
  }

  grid->width = width;
  grid->height = height;
}

void ugrid_clear(UGrid *grid)
{
  clear_region(grid, 0, grid->height - 1, 0, grid->width - 1, 0);
}

void ugrid_clear_chunk(UGrid *grid, int row, int col, int endcol, sattr_T attr)
{
  clear_region(grid, row, row, col, endcol - 1, attr);
}

void ugrid_goto(UGrid *grid, int row, int col)
{
  grid->row = row;
  grid->col = col;
}

void ugrid_scroll(UGrid *grid, int top, int bot, int left, int right, int count)
{
  // Compute start/stop/step for the loop below
  int start, stop, step;
  if (count > 0) {
    start = top;
    stop = bot - count + 1;
    step = 1;
  } else {
    start = bot;
    stop = top - count - 1;
    step = -1;
  }

  // Copy cell data
  for (int i = start; i != stop; i += step) {
    UCell *target_row = grid->cells[i] + left;
    UCell *source_row = grid->cells[i + count] + left;
    assert(right >= left && left >= 0);
    memcpy(target_row, source_row,
           sizeof(UCell) * ((size_t)right - (size_t)left + 1));
  }
}

static void clear_region(UGrid *grid, int top, int bot, int left, int right, sattr_T attr)
{
  for (int row = top; row <= bot; row++) {
    UGRID_FOREACH_CELL(grid, row, left, right + 1, {
      cell->data = schar_from_ascii(' ');
      cell->attr = attr;
    });
  }
}

static void destroy_cells(UGrid *grid)
{
  if (grid->cells) {
    for (int i = 0; i < grid->height; i++) {
      xfree(grid->cells[i]);
    }
    XFREE_CLEAR(grid->cells);
  }
}
