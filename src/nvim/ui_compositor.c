// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Compositor: merge floating grids with the main grid for display in
// TUI and non-multigrid UIs.

#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <limits.h>

#include "nvim/lib/kvec.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/ui.h"
#include "nvim/memory.h"
#include "nvim/ui_compositor.h"
#include "nvim/ugrid.h"
#include "nvim/screen.h"
#include "nvim/syntax.h"
#include "nvim/api/private/helpers.h"
#include "nvim/os/os.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ui_compositor.c.generated.h"
#endif

static UI *compositor = NULL;
static int composed_uis = 0;
kvec_t(ScreenGrid *) layers = KV_INITIAL_VALUE;

static size_t bufsize = 0;
static schar_T *linebuf;
static sattr_T *attrbuf;

#ifndef NDEBUG
static int chk_width = 0, chk_height = 0;
#endif

static ScreenGrid *curgrid;

static bool valid_screen = true;
static bool msg_scroll_mode = false;
static int msg_first_invalid = 0;

void ui_comp_init(void)
{
  if (compositor != NULL) {
    return;
  }
  compositor = xcalloc(1, sizeof(UI));

  compositor->rgb = true;
  compositor->grid_resize = ui_comp_grid_resize;
  compositor->grid_clear = ui_comp_grid_clear;
  compositor->grid_scroll = ui_comp_grid_scroll;
  compositor->grid_cursor_goto = ui_comp_grid_cursor_goto;
  compositor->raw_line = ui_comp_raw_line;
  compositor->win_scroll_over_start = ui_comp_win_scroll_over_start;
  compositor->win_scroll_over_reset = ui_comp_win_scroll_over_reset;

  // Be unopinionated: will be attached together with a "real" ui anyway
  compositor->width = INT_MAX;
  compositor->height = INT_MAX;
  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {
    compositor->ui_ext[i] = true;
  }

  // TODO(bfredl): this will be more complicated if we implement
  // hlstate per UI (i e reduce hl ids for non-hlstate UIs)
  compositor->ui_ext[kUIHlState] = false;

  kv_push(layers, &default_grid);
  curgrid = &default_grid;

  ui_attach_impl(compositor);
}


void ui_comp_attach(UI *ui)
{
  composed_uis++;
  ui->composed = true;
}

void ui_comp_detach(UI *ui)
{
  composed_uis--;
  if (composed_uis == 0) {
    xfree(linebuf);
    xfree(attrbuf);
    linebuf = NULL;
    attrbuf = NULL;
    bufsize = 0;
  }
  ui->composed = false;
}

bool ui_comp_should_draw(void)
{
  return composed_uis != 0 && valid_screen;
}

/// TODO(bfredl): later on the compositor should just use win_float_pos events,
/// though that will require slight event order adjustment: emit the win_pos
/// events in the beginning of  update_screen(0), rather than in ui_flush()
bool ui_comp_put_grid(ScreenGrid *grid, int row, int col, int height, int width)
{
  if (grid->comp_index != 0) {
    bool moved = (row != grid->comp_row) || (col != grid->comp_col);
    if (ui_comp_should_draw()) {
      // Redraw the area covered by the old position, and is not covered
      // by the new position. Disable the grid so that compose_area() will not
      // use it.
      grid->comp_disabled = true;
      compose_area(grid->comp_row, row,
                   grid->comp_col, grid->comp_col + grid->Columns);
      if (grid->comp_col < col) {
        compose_area(MAX(row, grid->comp_row),
                     MIN(row+height, grid->comp_row+grid->Rows),
                     grid->comp_col, col);
      }
      if (col+width < grid->comp_col+grid->Columns) {
        compose_area(MAX(row, grid->comp_row),
                     MIN(row+height, grid->comp_row+grid->Rows),
                     col+width, grid->comp_col+grid->Columns);
      }
      compose_area(row+height, grid->comp_row+grid->Rows,
                   grid->comp_col, grid->comp_col + grid->Columns);
      grid->comp_disabled = false;
    }
    grid->comp_row = row;
    grid->comp_col = col;
    return moved;
  }
#ifndef NDEBUG
  for (size_t i = 0; i < kv_size(layers); i++) {
    if (kv_A(layers, i) == grid) {
      assert(false);
    }
  }
#endif
  // not found: new grid
  kv_push(layers, grid);
  grid->comp_row = row;
  grid->comp_col = col;
  grid->comp_index = kv_size(layers)-1;
  return true;
}

void ui_comp_remove_grid(ScreenGrid *grid)
{
  assert(grid != &default_grid);
  if (grid->comp_index == 0) {
    // grid wasn't present
    return;
  }

  if (curgrid == grid) {
    curgrid = &default_grid;
  }

  for (size_t i = grid->comp_index; i < kv_size(layers)-1; i++) {
    kv_A(layers, i) = kv_A(layers, i+1);
    kv_A(layers, i)->comp_index = i;
  }
  (void)kv_pop(layers);
  grid->comp_index = 0;

  if (ui_comp_should_draw()) {
    // inefficent: only draw up to grid->comp_index
    compose_area(grid->comp_row, grid->comp_row+grid->Rows,
                 grid->comp_col, grid->comp_col+grid->Columns);
  }
}

bool ui_comp_set_grid(handle_T handle)
{
  if (curgrid->handle == handle) {
    return true;
  }
  ScreenGrid *grid = NULL;
  for (size_t i = 0; i < kv_size(layers); i++) {
    if (kv_A(layers, i)->handle == handle) {
      grid = kv_A(layers, i);
      break;
    }
  }
  if (grid != NULL) {
    curgrid = grid;
    return true;
  }
  return false;
}

static void ui_comp_grid_cursor_goto(UI *ui, Integer grid_handle,
                                     Integer r, Integer c)
{
  if (!ui_comp_should_draw() || !ui_comp_set_grid((int)grid_handle)) {
    return;
  }
  int cursor_row = curgrid->comp_row+(int)r;
  int cursor_col = curgrid->comp_col+(int)c;

  if (cursor_col >= default_grid.Columns || cursor_row >= default_grid.Rows) {
    // TODO(bfredl): this happens with 'writedelay', refactor?
    // abort();
    return;
  }
  ui_composed_call_grid_cursor_goto(1, cursor_row, cursor_col);
}


/// Baseline implementation. This is always correct, but we can sometimes
/// do something more efficient (where efficiency means smaller deltas to
/// the downstream UI.)
static void compose_line(Integer row, Integer startcol, Integer endcol,
                         LineFlags flags)
{
  // in case we start on the right half of a double-width char, we need to
  // check the left half. But skip it in output if it wasn't doublewidth.
  int skip = 0;
  if (startcol > 0 && (flags & kLineFlagInvalid)) {
    startcol--;
    skip = 1;
  }

  int col = (int)startcol;
  ScreenGrid *grid = NULL;

  while (col < endcol) {
    int until = 0;
    for (size_t i = 0; i < kv_size(layers); i++) {
      ScreenGrid *g = kv_A(layers, i);
      if (g->comp_row > row || row >= g->comp_row + g->Rows
          || g->comp_disabled) {
        continue;
      }
      if (g->comp_col <= col && col < g->comp_col+g->Columns) {
        grid = g;
        until = g->comp_col+g->Columns;
      } else if (g->comp_col > col) {
        until = MIN(until, g->comp_col);
      }
    }
    until = MIN(until, (int)endcol);

    assert(grid != NULL);
    assert(until > col);
    assert(until <= default_grid.Columns);
    size_t n = (size_t)(until-col);
    size_t off = grid->line_offset[row-grid->comp_row]
                 + (size_t)(col-grid->comp_col);
    memcpy(linebuf+(col-startcol), grid->chars+off, n * sizeof(*linebuf));
    memcpy(attrbuf+(col-startcol), grid->attrs+off, n * sizeof(*attrbuf));

    // Tricky: if overlap caused a doublewidth char to get cut-off, must
    // replace the visible half with a space.
    if (linebuf[col-startcol][0] == NUL) {
      linebuf[col-startcol][0] = ' ';
      linebuf[col-startcol][1] = NUL;
    } else if (n > 1 && linebuf[col-startcol+1][0] == NUL) {
      skip = 0;
    }
    if (grid->comp_col+grid->Columns > until
        && grid->chars[off+n][0] == NUL) {
      linebuf[until-1-startcol][0] = ' ';
      linebuf[until-1-startcol][1] = '\0';
      if (col == startcol && n == 1) {
        skip = 0;
      }
    }
    col = until;
  }
  assert(endcol <= chk_width);
  assert(row < chk_height);

  if (!(grid && grid == &default_grid)) {
    // TODO(bfredl): too conservative, need check
    // grid->line_wraps if grid->Width == Width
    flags = flags & ~kLineFlagWrap;
  }

  ui_composed_call_raw_line(1, row, startcol+skip, endcol, endcol, 0, flags,
                            (const schar_T *)linebuf+skip,
                            (const sattr_T *)attrbuf+skip);
}

static void compose_area(Integer startrow, Integer endrow,
                         Integer startcol, Integer endcol)
{
  endrow = MIN(endrow, default_grid.Rows);
  endcol = MIN(endcol, default_grid.Columns);
  for (int r = (int)startrow; r < endrow; r++) {
    compose_line(r, startcol, endcol, kLineFlagInvalid);
  }
}


static void ui_comp_raw_line(UI *ui, Integer grid, Integer row,
                             Integer startcol, Integer endcol,
                             Integer clearcol, Integer clearattr,
                             LineFlags flags, const schar_T *chunk,
                             const sattr_T *attrs)
{
  if (!ui_comp_should_draw() || !ui_comp_set_grid((int)grid)) {
    return;
  }

  row += curgrid->comp_row;
  startcol += curgrid->comp_col;
  endcol += curgrid->comp_col;
  clearcol += curgrid->comp_col;
  if (curgrid != &default_grid) {
    flags = flags & ~kLineFlagWrap;
  }
  assert(clearcol <= default_grid.Columns);
  if (flags & kLineFlagInvalid || kv_size(layers) > curgrid->comp_index+1) {
    compose_line(row, startcol, clearcol, flags);
  } else {
    ui_composed_call_raw_line(1, row, startcol, endcol, clearcol, clearattr,
                              flags, chunk, attrs);
  }
}

/// The screen is invalid and will soon be cleared
///
/// Don't redraw floats until screen is cleared
void ui_comp_invalidate_screen(void)
{
  valid_screen = false;
}

static void ui_comp_grid_clear(UI *ui, Integer grid)
{
  // By design, only first grid uses clearing.
  assert(grid == 1);
  ui_composed_call_grid_clear(1);
  valid_screen = true;
}

// TODO(bfredl): These events are somewhat of a hack. multiline messages
// should later on be a separate grid, then this would just be ordinary
// ui_comp_put_grid and ui_comp_remove_grid calls.
static void ui_comp_win_scroll_over_start(UI *ui)
{
  msg_scroll_mode = true;
  msg_first_invalid = ui->height;
}

static void ui_comp_win_scroll_over_reset(UI *ui)
{
  msg_scroll_mode = false;
  for (size_t i = 1; i < kv_size(layers); i++) {
    ScreenGrid *grid = kv_A(layers, i);
    if (grid->comp_row+grid->Rows > msg_first_invalid) {
      compose_area(msg_first_invalid, grid->comp_row+grid->Rows,
                   grid->comp_col, grid->comp_col+grid->Columns);
    }
  }
}

static void ui_comp_grid_scroll(UI *ui, Integer grid, Integer top,
                                Integer bot, Integer left, Integer right,
                                Integer rows, Integer cols)
{
  if (!ui_comp_should_draw() || !ui_comp_set_grid((int)grid)) {
    return;
  }
  top += curgrid->comp_row;
  bot += curgrid->comp_row;
  left += curgrid->comp_col;
  right += curgrid->comp_col;
  if (!msg_scroll_mode && kv_size(layers) > curgrid->comp_index+1) {
    // TODO(bfredl):
    // 1. check if rectangles actually overlap
    // 2. calulate subareas that can scroll.
    if (rows > 0) {
      bot -= rows;
    } else {
      top += (-rows);
    }
    compose_area(top, bot, left, right);
  } else {
    msg_first_invalid = MIN(msg_first_invalid, (int)top);
    ui_composed_call_grid_scroll(1, top, bot, left, right, rows, cols);
  }
}

static void ui_comp_grid_resize(UI *ui, Integer grid,
                                Integer width, Integer height)
{
  if (grid == 1) {
    ui_composed_call_grid_resize(1, width, height);
#ifndef NDEBUG
    chk_width = (int)width;
    chk_height = (int)height;
#endif
    size_t new_bufsize = (size_t)width;
    if (bufsize != new_bufsize) {
      xfree(linebuf);
      xfree(attrbuf);
      linebuf = xmalloc(new_bufsize * sizeof(*linebuf));
      attrbuf = xmalloc(new_bufsize * sizeof(*attrbuf));
      bufsize = new_bufsize;
    }
  }
}

