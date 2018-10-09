// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <limits.h>

#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/ugrid.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ugrid.c.generated.h"
#endif

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
  clear_region(grid, 0, grid->height-1, 0, grid->width-1, 0);
}

void ugrid_clear_chunk(UGrid *grid, int row, int col, int endcol, sattr_T attr)
{
  clear_region(grid, row, row, col, endcol-1, attr);
}

void ugrid_goto(UGrid *grid, int row, int col)
{
  grid->row = row;
  grid->col = col;
}

void ugrid_scroll(UGrid *grid, int top, int bot, int left, int right,
                  int count, int *clear_top, int *clear_bot)
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

  int i;

  // Copy cell data
  for (i = start; i != stop; i += step) {
    UCell *target_row = grid->cells[i] + left;
    UCell *source_row = grid->cells[i + count] + left;
    memcpy(target_row, source_row,
           sizeof(UCell) * (size_t)(right - left + 1));
  }

  // clear cells in the emptied region,
  if (count > 0) {
    *clear_top = stop;
    *clear_bot = stop + count - 1;
  } else {
    *clear_bot = stop;
    *clear_top = stop + count + 1;
  }
  clear_region(grid, *clear_top, *clear_bot, left, right, 0);
}

static void clear_region(UGrid *grid, int top, int bot, int left, int right,
                         sattr_T attr)
{
  UGRID_FOREACH_CELL(grid, top, bot, left, right, {
    cell->data[0] = ' ';
    cell->data[1] = 0;
    cell->attr = attr;
  });
}

static void destroy_cells(UGrid *grid)
{
  if (grid->cells) {
    for (int i = 0; i < grid->height; i++) {
      xfree(grid->cells[i]);
    }
    xfree(grid->cells);
    grid->cells = NULL;
  }
}

