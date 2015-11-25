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
  grid->attrs = EMPTY_ATTRS;
  grid->fg = grid->bg = -1;
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

  grid->top = 0;
  grid->bot = height - 1;
  grid->left = 0;
  grid->right = width - 1;
  grid->row = grid->col = 0;
  grid->width = width;
  grid->height = height;
}

void ugrid_clear(UGrid *grid)
{
  clear_region(grid, grid->top, grid->bot, grid->left, grid->right);
}

void ugrid_eol_clear(UGrid *grid)
{
  clear_region(grid, grid->row, grid->row, grid->col, grid->right);
}

void ugrid_goto(UGrid *grid, int row, int col)
{
  grid->row = row;
  grid->col = col;
}

void ugrid_set_scroll_region(UGrid *grid, int top, int bot, int left, int right)
{
  grid->top = top;
  grid->bot = bot;
  grid->left = left;
  grid->right = right;
}

void ugrid_scroll(UGrid *grid, int count, int *clear_top, int *clear_bot)
{
  // Compute start/stop/step for the loop below
  int start, stop, step;
  if (count > 0) {
    start = grid->top;
    stop = grid->bot - count + 1;
    step = 1;
  } else {
    start = grid->bot;
    stop = grid->top - count - 1;
    step = -1;
  }

  int i;

  // Copy cell data
  for (i = start; i != stop; i += step) {
    UCell *target_row = grid->cells[i] + grid->left;
    UCell *source_row = grid->cells[i + count] + grid->left;
    memcpy(target_row, source_row,
        sizeof(UCell) * (size_t)(grid->right - grid->left + 1));
  }

  // clear cells in the emptied region,
  if (count > 0) {
    *clear_top = stop;
    *clear_bot = stop + count - 1;
  } else {
    *clear_bot = stop;
    *clear_top = stop + count + 1;
  }
  clear_region(grid, *clear_top, *clear_bot, grid->left, grid->right);
}

UCell *ugrid_put(UGrid *grid, uint8_t *text, size_t size)
{
  UCell *cell = grid->cells[grid->row] + grid->col;
  cell->data[size] = 0;
  cell->attrs = grid->attrs;

  if (text) {
    memcpy(cell->data, text, size);
  }

  grid->col += 1;
  return cell;
}

static void clear_region(UGrid *grid, int top, int bot, int left, int right)
{
  HlAttrs clear_attrs = EMPTY_ATTRS;
  clear_attrs.foreground = grid->fg;
  clear_attrs.background = grid->bg;
  UGRID_FOREACH_CELL(grid, top, bot, left, right, {
    cell->data[0] = ' ';
    cell->data[1] = 0;
    cell->attrs = clear_attrs;
  });
}

static void destroy_cells(UGrid *grid)
{
  if (grid->cells) {
    for (int i = 0; i < grid->height; i++) {
      xfree(grid->cells[i]);
    }
    xfree(grid->cells);
  }
}

