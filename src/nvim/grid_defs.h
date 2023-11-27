#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

// Includes final NUL. MAX_MCO is no longer used, but at least 4*(MAX_MCO+1)+1=29
// ensures we can fit all composed chars which did fit before.
#define MAX_SCHAR_SIZE 32

// if data[0] is 0xFF, then data[1..4] is a 24-bit index (in machine endianness)
// otherwise it must be a UTF-8 string of length maximum 4 (no NUL when n=4)

typedef uint32_t schar_T;
typedef int32_t sattr_T;
// must be at least as big as the biggest of schar_T, sattr_T, col_T
typedef int32_t sscratch_T;

enum {
  kZIndexDefaultGrid = 0,
  kZIndexFloatDefault = 50,
  kZIndexPopupMenu = 100,
  kZIndexMessages = 200,
  kZIndexCmdlinePopupMenu = 250,
};

/// ScreenGrid represents a resizable rectuangular grid displayed by UI clients.
///
/// chars[] contains the UTF-8 text that is currently displayed on the grid.
/// It is stored as a single block of cells. When redrawing a part of the grid,
/// the new state can be compared with the existing state of the grid. This way
/// we can avoid sending bigger updates than necessary to the Ul layer.
///
/// Screen cells are stored as NUL-terminated UTF-8 strings, and a cell can
/// contain composing characters as many as fits in MAX_SCHAR_SIZE-1 bytes
/// The composing characters are to be drawn on top of the original character.
/// The content after the NUL is not defined (so comparison must be done a
/// single cell at a time). Double-width characters are stored in the left cell,
/// and the right cell should only contain the empty string. When a part of the
/// screen is cleared, the cells should be filled with a single whitespace char.
///
/// attrs[] contains the highlighting attribute for each cell.
///
/// vcols[] contains the virtual columns in the line. -1 means not available
/// or before buffer text, MAXCOL means after the end of the line.
/// -2 or -3 means in fold column and a mouse click should:
///  -2: open a fold
///  -3: close a fold
///
/// line_offset[n] is the offset from chars[], attrs[] and vcols[] for the start
/// of line 'n'. These offsets are in general not linear, as full screen scrolling
/// is implemented by rotating the offsets in the line_offset array.
typedef struct ScreenGrid ScreenGrid;
struct ScreenGrid {
  handle_T handle;

  schar_T *chars;
  sattr_T *attrs;
  colnr_T *vcols;
  size_t *line_offset;

  // last column that was drawn (not cleared with the default background).
  // only used when "throttled" is set. Not allocated by grid_alloc!
  int *dirty_col;

  // the size of the allocated grid.
  int rows;
  int cols;

  // The state of the grid is valid. Otherwise it needs to be redrawn.
  bool valid;

  // only draw internally and don't send updates yet to the compositor or
  // external UI.
  bool throttled;

  // TODO(bfredl): maybe physical grids and "views" (i e drawing
  // specifications) should be two separate types?
  // offsets for the grid relative to another grid. Used for grids
  // that are views into another, actually allocated grid 'target'
  int row_offset;
  int col_offset;
  ScreenGrid *target;

  // whether the compositor should blend the grid with the background grid
  bool blending;

  // whether the grid can be focused with mouse clicks.
  bool focusable;

  // z-index: the order in the stack of grids.
  int zindex;

  // Below is state owned by the compositor. Should generally not be set/read
  // outside this module, except for specific compatibility hacks

  // position of the grid on the composed screen.
  int comp_row;
  int comp_col;

  // Requested width and height of the grid upon resize. Used by
  // `ui_compositor` to correctly determine which regions need to
  // be redrawn.
  int comp_width;
  int comp_height;

  // z-index of the grid. Grids with higher index is draw on top.
  // default_grid.comp_index is always zero.
  size_t comp_index;

  // compositor should momentarily ignore the grid. Used internally when
  // moving around grids etc.
  bool comp_disabled;
};

#define SCREEN_GRID_INIT { 0, NULL, NULL, NULL, NULL, NULL, 0, 0, false, \
                           false, 0, 0, NULL, false, true, 0, \
                           0, 0, 0, 0, 0,  false }

typedef struct {
  int args[3];
  int icell;
  int ncells;
  int coloff;
  int cur_attr;
  int clear_width;
  bool wrap;
} GridLineEvent;
