// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Compositor: merge floating grids with the main grid for display in
// TUI and non-multigrid UIs.
//
// Layer-based compositing: https://en.wikipedia.org/wiki/Digital_compositing

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
#include "nvim/highlight.h"
#include "nvim/memory.h"
#include "nvim/popupmnu.h"
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

static int dbghl_normal, dbghl_clear, dbghl_composed, dbghl_recompose;

void ui_comp_init(void)
{
  if (compositor != NULL) {
    return;
  }
  compositor = xcalloc(1, sizeof(UI));

  compositor->rgb = true;
  compositor->grid_resize = ui_comp_grid_resize;
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

void ui_comp_syn_init(void)
{
  dbghl_normal = syn_check_group((char_u *)S_LEN("RedrawDebugNormal"));
  dbghl_clear = syn_check_group((char_u *)S_LEN("RedrawDebugClear"));
  dbghl_composed = syn_check_group((char_u *)S_LEN("RedrawDebugComposed"));
  dbghl_recompose = syn_check_group((char_u *)S_LEN("RedrawDebugRecompose"));
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
    XFREE_CLEAR(linebuf);
    XFREE_CLEAR(attrbuf);
    bufsize = 0;
  }
  ui->composed = false;
}

bool ui_comp_should_draw(void)
{
  return composed_uis != 0 && valid_screen;
}

/// Places `grid` at (col,row) position with (width * height) size.
/// Adds `grid` as the top layer if it is a new layer.
///
/// TODO(bfredl): later on the compositor should just use win_float_pos events,
/// though that will require slight event order adjustment: emit the win_pos
/// events in the beginning of  update_screen(0), rather than in ui_flush()
bool ui_comp_put_grid(ScreenGrid *grid, int row, int col, int height, int width,
                      bool valid, bool on_top)
{
  bool moved;
  if (grid->comp_index != 0) {
    moved = (row != grid->comp_row) || (col != grid->comp_col);
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
  } else {
    moved = true;
#ifndef NDEBUG
    for (size_t i = 0; i < kv_size(layers); i++) {
      if (kv_A(layers, i) == grid) {
        assert(false);
      }
    }
#endif

    size_t insert_at = kv_size(layers);
    if (kv_A(layers, insert_at-1) == &pum_grid) {
      insert_at--;
    }
    if (insert_at > 1 && !on_top) {
      insert_at--;
    }
    // not found: new grid
    kv_push(layers, grid);
    if (insert_at < kv_size(layers)-1) {
      for (size_t i = kv_size(layers)-1; i > insert_at; i--) {
        kv_A(layers, i) = kv_A(layers, i-1);
        kv_A(layers, i)->comp_index = i;
      }
      kv_A(layers, insert_at) = grid;
    }

    grid->comp_row = row;
    grid->comp_col = col;
    grid->comp_index = insert_at;
  }
  if (moved && valid && ui_comp_should_draw()) {
    compose_area(grid->comp_row, grid->comp_row+grid->Rows,
                 grid->comp_col, grid->comp_col+grid->Columns);
  }
  return moved;
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

  // recompose the area under the grid
  // inefficent when being overlapped: only draw up to grid->comp_index
  ui_comp_compose_grid(grid);
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

static void ui_comp_raise_grid(ScreenGrid *grid, size_t new_index)
{
  size_t old_index = grid->comp_index;
  for (size_t i = old_index; i < new_index; i++) {
    kv_A(layers, i) = kv_A(layers, i+1);
    kv_A(layers, i)->comp_index = i;
  }
  kv_A(layers, new_index) = grid;
  grid->comp_index = new_index;
  for (size_t i = old_index; i < new_index; i++) {
    ScreenGrid *grid2 = kv_A(layers, i);
    int startcol = MAX(grid->comp_col, grid2->comp_col);
    int endcol = MIN(grid->comp_col+grid->Columns,
                     grid2->comp_col+grid2->Columns);
    compose_area(MAX(grid->comp_row, grid2->comp_row),
                 MIN(grid->comp_row+grid->Rows, grid2->comp_row+grid2->Rows),
                 startcol, endcol);
  }
}

static void ui_comp_grid_cursor_goto(UI *ui, Integer grid_handle,
                                     Integer r, Integer c)
{
  if (!ui_comp_should_draw() || !ui_comp_set_grid((int)grid_handle)) {
    return;
  }
  int cursor_row = curgrid->comp_row+(int)r;
  int cursor_col = curgrid->comp_col+(int)c;

  // TODO(bfredl): maybe not the best time to do this, for efficiency we
  // should configure all grids before entering win_update()
  if (curgrid != &default_grid) {
    size_t new_index = kv_size(layers)-1;
    if (kv_A(layers, new_index) == &pum_grid) {
      new_index--;
    }
    if (curgrid->comp_index < new_index) {
      ui_comp_raise_grid(curgrid, new_index);
    }
  }

  if (cursor_col >= default_grid.Columns || cursor_row >= default_grid.Rows) {
    // TODO(bfredl): this happens with 'writedelay', refactor?
    // abort();
    return;
  }
  ui_composed_call_grid_cursor_goto(1, cursor_row, cursor_col);
}

ScreenGrid *ui_comp_mouse_focus(int row, int col)
{
  // TODO(bfredl): click "through" unfocusable grids?
  for (ssize_t i = (ssize_t)kv_size(layers)-1; i > 0; i--) {
    ScreenGrid *grid = kv_A(layers, i);
    if (row >= grid->comp_row && row < grid->comp_row+grid->Rows
        && col >= grid->comp_col && col < grid->comp_col+grid->Columns) {
      return grid;
    }
  }
  return NULL;
}

/// Baseline implementation. This is always correct, but we can sometimes
/// do something more efficient (where efficiency means smaller deltas to
/// the downstream UI.)
static void compose_line(Integer row, Integer startcol, Integer endcol,
                         LineFlags flags)
{
  // in case we start on the right half of a double-width char, we need to
  // check the left half. But skip it in output if it wasn't doublewidth.
  int skipstart = 0, skipend = 0;
  if (startcol > 0 && (flags & kLineFlagInvalid)) {
    startcol--;
    skipstart = 1;
  }
  if (endcol < default_grid.Columns && (flags & kLineFlagInvalid)) {
    endcol++;
    skipend = 1;
  }

  int col = (int)startcol;
  ScreenGrid *grid = NULL;
  schar_T *bg_line = &default_grid.chars[default_grid.line_offset[row]
                                         +(size_t)startcol];
  sattr_T *bg_attrs = &default_grid.attrs[default_grid.line_offset[row]
                                          +(size_t)startcol];

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

    // 'pumblend' and 'winblend'
    if (grid->blending) {
      int width;
      for (int i = col-(int)startcol; i < until-startcol; i += width) {
        width = 1;
        // negative space
        bool thru = strequal((char *)linebuf[i], " ") && bg_line[i][0] != NUL;
        if (i+1 < endcol-startcol && bg_line[i+1][0] == NUL) {
          width = 2;
          thru &= strequal((char *)linebuf[i+1], " ");
        }
        attrbuf[i] = (sattr_T)hl_blend_attrs(bg_attrs[i], attrbuf[i], &thru);
        if (width == 2) {
          attrbuf[i+1] = (sattr_T)hl_blend_attrs(bg_attrs[i+1],
                                                 attrbuf[i+1], &thru);
        }
        if (thru) {
          memcpy(linebuf + i, bg_line + i, (size_t)width * sizeof(linebuf[i]));
        }
      }
    }

    // Tricky: if overlap caused a doublewidth char to get cut-off, must
    // replace the visible half with a space.
    if (linebuf[col-startcol][0] == NUL) {
      linebuf[col-startcol][0] = ' ';
      linebuf[col-startcol][1] = NUL;
      if (col == endcol-1) {
        skipend = 0;
      }
    } else if (n > 1 && linebuf[col-startcol+1][0] == NUL) {
      skipstart = 0;
    }
    if (grid->comp_col+grid->Columns > until
        && grid->chars[off+n][0] == NUL) {
      linebuf[until-1-startcol][0] = ' ';
      linebuf[until-1-startcol][1] = '\0';
      if (col == startcol && n == 1) {
        skipstart = 0;
      }
    }

    col = until;
  }
  if (linebuf[endcol-startcol-1][0] == NUL) {
    skipend = 0;
  }

  assert(endcol <= chk_width);
  assert(row < chk_height);

  if (!(grid && grid == &default_grid)) {
    // TODO(bfredl): too conservative, need check
    // grid->line_wraps if grid->Width == Width
    flags = flags & ~kLineFlagWrap;
  }

  ui_composed_call_raw_line(1, row, startcol+skipstart,
                            endcol-skipend, endcol-skipend, 0, flags,
                            (const schar_T *)linebuf+skipstart,
                            (const sattr_T *)attrbuf+skipstart);
}

static void compose_debug(Integer startrow, Integer endrow, Integer startcol,
                          Integer endcol, int syn_id, bool delay)
{
  if (!(rdb_flags & RDB_COMPOSITOR)) {
    return;
  }

  endrow = MIN(endrow, default_grid.Rows);
  endcol = MIN(endcol, default_grid.Columns);
  int attr = syn_id2attr(syn_id);

  for (int row = (int)startrow; row < endrow; row++) {
    ui_composed_call_raw_line(1, row, startcol, startcol, endcol, attr, false,
                              (const schar_T *)linebuf,
                              (const sattr_T *)attrbuf);
  }


  if (delay) {
    debug_delay(endrow-startrow);
  }
}

static void debug_delay(Integer lines)
{
  ui_call_flush();
  uint64_t wd = (uint64_t)labs(p_wd);
  uint64_t factor = (uint64_t)MAX(MIN(lines, 5), 1);
  os_microdelay(factor * wd * 1000u, true);
}


static void compose_area(Integer startrow, Integer endrow,
                         Integer startcol, Integer endcol)
{
  compose_debug(startrow, endrow, startcol, endcol, dbghl_recompose, true);
  endrow = MIN(endrow, default_grid.Rows);
  endcol = MIN(endcol, default_grid.Columns);
  if (endcol <= startcol) {
    return;
  }
  for (int r = (int)startrow; r < endrow; r++) {
    compose_line(r, startcol, endcol, kLineFlagInvalid);
  }
}

/// compose the area under the grid.
///
/// This is needed when some option affecting composition is changed,
/// such as 'pumblend' for popupmenu grid.
void ui_comp_compose_grid(ScreenGrid *grid)
{
  if (ui_comp_should_draw()) {
    compose_area(grid->comp_row, grid->comp_row+grid->Rows,
                 grid->comp_col, grid->comp_col+grid->Columns);
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
  assert(row < default_grid.Rows);
  assert(clearcol <= default_grid.Columns);
  if (flags & kLineFlagInvalid
      || kv_size(layers) > curgrid->comp_index+1
      || curgrid->blending) {
    compose_debug(row, row+1, startcol, clearcol, dbghl_composed, true);
    compose_line(row, startcol, clearcol, flags);
  } else {
    compose_debug(row, row+1, startcol, endcol, dbghl_normal, false);
    compose_debug(row, row+1, endcol, clearcol, dbghl_clear, true);
    ui_composed_call_raw_line(1, row, startcol, endcol, clearcol, clearattr,
                              flags, chunk, attrs);
  }
}

/// The screen is invalid and will soon be cleared
///
/// Don't redraw floats until screen is cleared
void ui_comp_set_screen_valid(bool valid)
{
  valid_screen = valid;
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
  bool covered = kv_size(layers) > curgrid->comp_index+1 || curgrid->blending;
  if (!msg_scroll_mode && covered) {
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
    if (rdb_flags & RDB_COMPOSITOR) {
      debug_delay(2);
    }
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

