#ifndef NVIM_GRID_DEFS_H
#define NVIM_GRID_DEFS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/types.h"

#define MAX_MCO  6  // maximum value for 'maxcombine'

// The characters and attributes drawn on grids.
typedef char_u schar_T[(MAX_MCO+1) * 4 + 1];
typedef int16_t sattr_T;

/// ScreenGrid represents a resizable rectuangular grid displayed by UI clients.
///
/// chars[] contains the UTF-8 text that is currently displayed on the grid.
/// It is stored as a single block of cells. When redrawing a part of the grid,
/// the new state can be compared with the existing state of the grid. This way
/// we can avoid sending bigger updates than neccessary to the Ul layer.
///
/// Screen cells are stored as NUL-terminated UTF-8 strings, and a cell can
/// contain up to MAX_MCO composing characters after the base character.
/// The composing characters are to be drawn on top of the original character.
/// The content after the NUL is not defined (so comparison must be done a
/// single cell at a time). Double-width characters are stored in the left cell,
/// and the right cell should only contain the empty string. When a part of the
/// screen is cleared, the cells should be filled with a single whitespace char.
///
/// attrs[] contains the highlighting attribute for each cell.
/// line_offset[n] is the offset from chars[] and attrs[] for the
/// start of line 'n'. These offsets are in general not linear, as full screen
/// scrolling is implemented by rotating the offsets in the line_offset array.
/// line_wraps[] is an array of boolean flags indicating if the screen line
/// wraps to the next line. It can only be true if a window occupies the entire
/// screen width.
typedef struct {
  handle_T handle;

  schar_T  *chars;
  sattr_T  *attrs;
  unsigned *line_offset;
  char_u   *line_wraps;

  // last column that was drawn (not cleared with the default background).
  // only used when "throttled" is set. Not allocated by grid_alloc!
  int *dirty_col;

  // the size of the allocated grid.
  int Rows;
  int Columns;

  // The state of the grid is valid. Otherwise it needs to be redrawn.
  bool valid;

  // only draw internally and don't send updates yet to the compositor or
  // external UI.
  bool throttled;

  // offsets for the grid relative to the global screen. Used by screen.c
  // for windows that don't have w_grid->chars etc allocated
  int row_offset;
  int col_offset;

  // whether the compositor should blend the grid with the background grid
  bool blending;

  // whether the grid can be focused with mouse clicks.
  bool focusable;

  // Below is state owned by the compositor. Should generally not be set/read
  // outside this module, except for specific compatibilty hacks

  // position of the grid on the composed screen.
  int comp_row;
  int comp_col;

  // z-index of the grid. Grids with higher index is draw on top.
  // default_grid.comp_index is always zero.
  size_t comp_index;

  // compositor should momentarily ignore the grid. Used internally when
  // moving around grids etc.
  bool comp_disabled;
} ScreenGrid;

#define SCREEN_GRID_INIT { 0, NULL, NULL, NULL, NULL, NULL, 0, 0, false, \
                           false, 0, 0, false, true, 0, 0, 0,  false }

#endif  // NVIM_GRID_DEFS_H
